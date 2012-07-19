uuid = require("node-uuid")

class Builder

  constructor: () ->
    @id      = uuid.v1()
    @spawner = require("spawner").init()
    @storage = require("storage").init()

  build: (source, options, cb) ->
    @storage.generate_put_url "slug/#{@id}.tgz", (err, slug_put_url) =>
      @storage.generate_put_url "exit/#{@id}", (err, exit_put_url) =>
        env =
          ANVIL_HOST:    process.env.ANVIL_HOST
          BUILDPACK_URL: @buildpack_with_default(options.buildpack)
          CACHE_URL:     @cache_with_default(options.cache)
          EXIT_PUT_URL:  exit_put_url
          NODE_ENV:      process.env.NODE_ENV
          NODE_PATH:     process.env.NODE_PATH
          PATH:          process.env.PATH
          SLUG_ID:       @id
          SLUG_URL:      @slug_url()
          SLUG_PUT_URL:  slug_put_url
          SOURCE_URL:    source
        env[key] = val for key, val of JSON.parse(options.env || "{}")
        builder  = @spawner.spawn("bin/compile $(bin/fetch $SOURCE_URL)", env:env)
        cb builder, this
        builder.emit "data", "Launching build process... "

  build_request: (req, res, logger) ->
    options =
      buildpack: req.body.buildpack
      cache:     req.body.cache
      env:       req.body.env
    require("builder").init().build req.body.source, options, (build, builder) ->
      res.writeHead 200
        "Content-Type":      "text/plain"
        "Transfer-Encoding": "chunked"
        "X-Cache-Url":       builder.cache_url
        "X-Manifest-Id":     builder.id
        "X-Slug-Url":        builder.slug_url()
      build.on "data", (data)   ->
        exit_header = "ANVIL!EXITCODE:"
        if (pos = data.toString().indexOf(exit_header)) > -1
          res.write data.slice(0, pos)
          code = data[pos + exit_header.length]
          res.addTrailers
            "X-Exit-Code": code.toString()
        else
          res.write(data)
      build.on "end", (success) ->
        logger.finish()
        res.end()

  buildpack_with_default: (buildpack) ->
    if (buildpack || "") is "" then "https://buildkits.herokuapp.com/buildkit/default.tgz" else buildpack

  cache_with_default: (cache) ->
    @cache_url = cache
    if (cache || "") is "" then @cache_url = @storage.create_cache()
    @cache_url

  slug_url: ->
    "#{process.env.ANVIL_HOST}/slugs/#{@id}.tgz"

module.exports.init = () ->
  new Builder()
