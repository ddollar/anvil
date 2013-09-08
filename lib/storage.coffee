crypto = require("crypto")
fs     = require("fs")
knox   = require("knox")
qs     = require("querystring")
uuid   = require("node-uuid")

class Storage

  constructor: () ->
    @knox = knox.createClient
      key:      process.env.AWS_ACCESS
      secret:   process.env.AWS_SECRET
      bucket:   process.env.S3_BUCKET
      endpoint: process.env.S3_ENDPOINT

  get: (filename, cb) ->
    @knox.getFile filename, (err, get) ->
      cb null, get

  get_file: (filename, cb) ->
    @get filename, (err, get) ->
      data = ""
      get.setEncoding "binary"
      get.on "data", (chunk)   -> data += chunk
      get.on "end",  (success) -> cb null, data

  exists: (filename, cb) ->
    @knox.headFile filename, (err, res) ->
      cb err, (res.statusCode != 404)

  create: (filename, data, options, cb) ->
    put = @knox.put filename, options
    put.on "response", (res) -> cb null
    put.end data

  create_stream: (filename, stream, cb) ->
    @knox.putStream stream, filename, (err, res) ->
      cb null

  verify_hash: (filename, hash, cb) ->
    sha  = crypto.createHash("sha256")
    file = fs.createReadStream(filename)
    file.on "data", (data) ->
      sha.update data
    file.on "end", ->
      if hash == sha.digest("hex")
        cb null
      else
        cb "file does not match hash"

  generate_put_url: (filename, cb) ->
    ttl = 3600
    expires = Math.floor((new Date).getTime() / 1000) + ttl
    bucket = process.env.S3_BUCKET
    string_to_sign = "PUT\n\n\n#{expires}\n/#{bucket}/#{filename}"
    hmac = crypto.createHmac("sha1", process.env.AWS_SECRET)
    hmac.update string_to_sign
    digest = hmac.digest("base64")
    url = "http://#{bucket}.s3.amazonaws.com/#{filename}"
    put_url = "#{url}?AWSAccessKeyId=#{process.env.AWS_ACCESS}&Signature=#{qs.escape(digest)}&Expires=#{expires}"
    cb null, put_url

  create_cache: ->
    id = uuid.v4()
    url = "#{process.env.ANVIL_HOST}/cache/#{id}.tgz"

module.exports.init = () ->
  new Storage()
