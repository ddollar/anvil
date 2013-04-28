crypto = require("crypto")
fs     = require("fs")
knox   = require("knox")
log    = require("./logger")
qs     = require("querystring")
redis  = require("redis-url").connect(process.env.OPENREDIS_URL)
uuid   = require("node-uuid")

class Storage

  constructor: () ->
    @knox = knox.createClient
      key:    process.env.AWS_ACCESS
      secret: process.env.AWS_SECRET
      bucket: process.env.S3_BUCKET

  get: (filename, cb) ->
    @knox.getFile filename, (err, get) ->
      cb null, get

  get_with_cache: (filename, cb) ->
    log "storage.get", (logger) =>
      redis.sismember "file:exists", filename, (err, exists) =>
        if exists is 1
          logger.log redis:"exists", (logger) ->
            redis.get "file:#{filename}", (err, data) ->
              emit = new (require("events").EventEmitter)()
              emit.statusCode = 200
              emit.headers = "content-length":(if data then data.length else 0)
              cb null, emit
              emit.emit "data", data
              emit.emit "end"
              logger.finish()
        else
          redis.multi()
            .setnx("file:working:#{filename}", (new Date()).getTime() + 300000)
            .expire("file:working:#{filename}", 300)
            .exec (err, res) =>
              if res[0] is 0
                logger.log redis:"working", (logger) =>
                  @knox.getFile filename, (err, get) ->
                    get.setEncoding "binary"
                    cb null, get
                    logger.finish()
              else
                logger.log redis:"missing", (logger) =>
                  redis.del "file:#{filename}", (err, res) =>
                    @knox.getFile filename, (err, get) ->
                      get.setEncoding "binary"
                      get.on "data", (data) -> redis.append "file:#{filename}", data
                      get.on "end", ->
                        redis.multi()
                          .expire("file:#{filename}", 7200)
                          .del("file:working:#{filename}")
                          .sadd("file:exists", filename)
                          .exec (err, res) ->
                      cb null, get
                      logger.finish()

  exists: (filename, cb) ->
    redis.sismember "exists", filename, (err, exists) =>
      if exists is 1
        cb err, true
      else
        @knox.headFile filename, (err, res) ->
          if res.statusCode is 404
            cb err, false
          else
            redis.sadd "exists", filename, (err, res) ->
              cb err, true

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
