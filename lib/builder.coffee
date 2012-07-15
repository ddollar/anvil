uuid = require("node-uuid")

class Builder

  constructor: () ->
    @id      = uuid.v1()
    @spawner = require("spawner").init()
    @storage = require("storage").init()

  build: (source, options, cb) ->
    @storage.generate_put_url "slug/#{@id}.img", (err, slug_put_url) =>
      env =
        ANVIL_HOST:    process.env.ANVIL_HOST
        BUILDPACK_URL: @buildpack_with_default(options.buildpack)
        CACHE_URL:     @cache_with_default(options.cache)
        NODE_ENV:      process.env.NODE_ENV
        NODE_PATH:     process.env.NODE_PATH
        PATH:          process.env.PATH
        SLUG_ID:       @id
        SLUG_URL:      @slug_url()
        SLUG_PUT_URL:  slug_put_url
        SOURCE_URL:    source
      env[key] = val for key, val of options.env
      builder  = @spawner.spawn("bin/compile $(bin/fetch $SOURCE_URL)", env:env)
      cb builder, this
      builder.emit "data", "Launching build process... "

  buildpack_with_default: (buildpack) ->
    if (buildpack || "") is "" then "https://buildkits.herokuapp.com/buildkit/default.tgz" else buildpack

  cache_with_default: (cache) ->
    @cache_url = cache
    if (cache || "") is "" then @cache_url = @storage.create_cache()
    @cache_url

  slug_url: ->
    "#{process.env.ANVIL_HOST}/slugs/#{@id}.img"

module.exports.init = () ->
  new Builder()
