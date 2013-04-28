async   = require("async")
uuid    = require("node-uuid")

class Manifest

  constructor: (@manifest) ->
    @builder = require("./builder").init()
    @storage = require("./storage").init()
    @id      = uuid.v4()

  hashes: ->
    object.hash for name, object of @manifest when object.hash

  save: (cb) ->
    manifest = new Buffer(JSON.stringify(@manifest), "binary")
    options  =
      "Content-Length": manifest.length,
      "Content-Type":  "application/json"
    @storage.create "/manifest/#{@id}.json", manifest, options, (err) =>
      cb err, @manifest_url()

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

  manifest_url: ->
    "#{process.env.ANVIL_HOST}/manifest/#{@id}.json"

module.exports.init = (manifest) ->
  new Manifest(manifest)
