async   = require("async")
crypto  = require("crypto")
fs      = require("fs")
knox    = require("knox")
mkdirp  = require("mkdirp")
path    = require("path")
qs      = require("querystring")
spawn   = require("child_process").spawn
spawner = require("spawner").init()
temp    = require("temp")
uuid    = require("node-uuid")

knox_instance = knox.createClient
  key:    process.env.AWS_ACCESS
  secret: process.env.AWS_SECRET
  bucket: process.env.AWS_BUCKET

class Manifest

  constructor: (@manifest) ->
    @knox = knox_instance

  build: (options, cb) ->
    @save (id, manifest_url) =>
      @generate_put_url id, (err, slug_put_url) =>
        env =
          ANVIL_HOST:    process.env.ANVIL_HOST
          BUILDPACK_URL: @buildpack_with_default(options.buildpack)
          MANIFEST_TGZ:  "#{process.env.ANVIL_HOST}/manifest/#{id}.tgz"
          MANIFEST_URL:  "#{process.env.ANVIL_HOST}/manifest/#{id}.json"
          NODE_ENV:      process.env.NODE_ENV
          NODE_PATH:     process.env.NODE_PATH
          PATH:          process.env.PATH
          SLUG_ID:       id
          SLUG_URL:      "#{process.env.ANVIL_HOST}/slugs/#{id}.img"
          SLUG_PUT_URL:  slug_put_url
        for key, val of options.env
          env[key] = val
        builder = spawner.spawn("bin/compile \"#{id}\"", env:env)
        cb id, builder
        builder.emit "data", "Launching build process... "

  save: (cb) ->
    id     = uuid.v1()
    buffer = new Buffer(JSON.stringify(@manifest), "binary")

    put = @knox.put "/manifest/#{id}.json", "Content-Length":buffer.length, "Content-Type":"application/json"
    put.on "response", (res) ->
      manifest_url = "#{process.env.ANVIL_HOST}/manifest/#{id}.json"
      cb id, manifest_url
    put.end(buffer)

  buildpack_with_default: (buildpack) ->
    if (buildpack || "") is "" then "https://buildkit.herokuapp.com/buildkit/default.tgz" else buildpack

  create_hash: (hash, stream, cb) ->
    @knox.putStream stream, "/hash/#{hash}", (err, knox_res) ->
      cb null

  generate_tarball: (cb) ->
    temp.mkdir "compile", (err, path) =>
      async.parallel @datastore_fetchers(path), (err, results) ->
        cb spawn("tar", ["czf", "-", "."], cwd:path)

  generate_put_url: (id, cb) ->
    filename = "slug/#{id}.img"
    ttl = 3600
    expires = Math.floor((new Date).getTime() / 1000) + ttl
    bucket = process.env.AWS_BUCKET
    string_to_sign = "PUT\n\n\n#{expires}\n/#{bucket}/#{filename}"
    hmac = crypto.createHmac("sha1", process.env.AWS_SECRET)
    hmac.update string_to_sign
    digest = hmac.digest("base64")
    url = "http://#{bucket}.s3.amazonaws.com/#{filename}"
    put_url = "#{url}?AWSAccessKeyId=#{process.env.AWS_ACCESS}&Signature=#{qs.escape(digest)}&Expires=#{expires}"
    cb null, put_url

  missing_hashes: (cb) ->
    async.parallel @datastore_testers(), (err, results) ->
      missing = []
      for hash, exists of results
        missing.push(hash) unless exists
      cb missing

  test_datastore_presence: (hash, cb) ->
    @knox.headFile "/hash/#{hash}", (err, res) ->
      cb(res.statusCode != 404)

  datastore_fetchers: (dir) ->
    fetchers = {}
    for name, file_manifest of @manifest
      do (name, file_manifest) =>
        fetchers[file_manifest.hash] = (async_cb) =>
          filename = "#{dir}/#{name}"
          mkdirp path.dirname(filename), =>
            file = fs.createWriteStream filename
            @knox.getFile "/hash/#{file_manifest["hash"]}", (err, get) =>
              get.setEncoding "binary"
              get.on "data", (chunk) -> file.write chunk
              get.on "end", ->
                file.end()
                fs.chmod filename, file_manifest.mode, (err) ->
                  async_cb null, true

  datastore_testers: ->
    @hashes(@manifest).reduce (ax, hash) =>
      ax[hash] = (async_cb) =>
        @test_datastore_presence hash, (exists) ->
          async_cb(null, exists)
      ax
    ,{}

  hashes: (manifest) ->
    object.hash for name, object of manifest

module.exports.knox = knox_instance

module.exports.init = (manifest) ->
  new Manifest(manifest)

module.exports.init_with_id = (id, cb) ->
  manifest = ""

  subknox = knox.createClient
    key:    process.env.AWS_ACCESS,
    secret: process.env.AWS_SECRET,
    bucket: process.env.AWS_BUCKET

  subknox.getFile "/manifest/#{id}.json", (err, get) =>
    get.setEncoding "binary"
    get.on "data", (chunk)  -> manifest += chunk
    get.on "end", (success) ->
      cb(new Manifest(JSON.parse(manifest)))
