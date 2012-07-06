async   = require("async")
spawner = require("spawner").init()
uuid    = require("node-uuid")

class Manifest

  constructor: (@manifest) ->
    @storage = require("storage").init()
    @id      = uuid.v1()

  hashes: ->
    object.hash for name, object of @manifest when object.hash

  build: (options, cb) ->
    @save (err) =>
      @storage.generate_put_url "slug/#{@id}.img", (err, slug_put_url) =>
        env =
          ANVIL_HOST:    process.env.ANVIL_HOST
          BUILDPACK_URL: @buildpack_with_default(options.buildpack)
          CACHE_URL:     @cache_with_default(options.cache)
          MANIFEST_URL:  @manifest_url()
          NODE_ENV:      process.env.NODE_ENV
          NODE_PATH:     process.env.NODE_PATH
          PATH:          process.env.PATH
          SLUG_ID:       @id
          SLUG_URL:      @slug_url()
          SLUG_PUT_URL:  slug_put_url
        env[key] = val for key, val of options.env
        builder  = spawner.spawn("bin/compile $(bin/fetch \"#{@id}\")", env:env)
        cb builder, this
        builder.emit "data", "Launching build process... "

  save: (cb) ->
    manifest = new Buffer(JSON.stringify(@manifest), "binary")
    options  = "Content-Length":manifest.length, "Content-Type":"application/json"
    @storage.create "/manifest/#{@id}.json", manifest, options, (err) =>
      cb err, @id

  missing_hashes: (cb) ->
    async.parallel @datastore_testers(), (err, results) ->
      missing = []
      for hash, exists of results
        missing.push(hash) unless exists
      cb missing

  test_datastore_presence: (hash, cb) ->
    @storage.exists "/hash/#{hash}", (err, exists) ->
      cb(exists)

  datastore_testers: ->
    @hashes().reduce (ax, hash) =>
      ax[hash] = (async_cb) =>
        @test_datastore_presence hash, (exists) ->
          async_cb(null, exists)
      ax
    ,{}

  buildpack_with_default: (buildpack) ->
    if (buildpack || "") is "" then "https://buildkits.herokuapp.com/buildkit/default.tgz" else buildpack

  cache_with_default: (cache) ->
    @cache_url = cache
    if (cache || "") is "" then @cache_url = @storage.create_cache()
    @cache_url

  manifest_url: ->
    "#{process.env.ANVIL_HOST}/manifest/#{@id}.json"

  slug_url: ->
    "#{process.env.ANVIL_HOST}/slugs/#{@id}.img"

module.exports.init = (manifest) ->
  new Manifest(manifest)

module.exports.init_with_id = (id, cb) ->
  storage = require("storage").init()
  storage.get_file "/manifest/#{id}.json", (err, get) ->
    cb null, new Manifest(manifest)
