async    = require("async")
fs       = require("fs")
http     = require("http")
https    = require("https")
mkdirp   = require("mkdirp")
os       = require("os")
path     = require("path")
program  = require("commander")
url      = require("url")
util     = require("util")

program
  .version(require("#{__dirname}/../package.json").version)
  .usage('[options] <slug url>')
  .option('-a, --auth <password>', 'admin password')
  .option('-c, --concurrency <num>', 'number of workers', os.cpus().length)
  .option('-e, --env <url>', 'environment file')
  .option('-p, --port <port>', 'port on which to listen', 3000)

datastore_fetchers = (manifest, dir) ->
  fetchers = {}
  for name, file_manifest of manifest
    do (name, file_manifest) =>
      fetchers[file_manifest.hash] = (async_cb) =>
        filename = "#{dir}/#{name}"
        mkdirp path.dirname(filename), =>
          fs.open filename, "w", (err, fd) =>
            options = url.parse("#{process.env.ANVIL_HOST}/file/#{file_manifest["hash"]}")
            client = if options.protocol is "https:" then https else http
            get = client.get(options)
            console.log "code", get.statusCode
            get.on "data", (chunk) -> fs.write fd, chunk
            get.on "end", ->
              fs.fchmod fd, file_manifest.mode
              fs.close fd
              async_cb null, true

module.exports.execute = (args) ->
  program.parse(args)
  fs.readFile program.args[0], (err, data) ->
    manifest = JSON.parse(data)
    mkdirp program.args[1]
    async.parallel datastore_fetchers(manifest, program.args[1]), (err, results) ->
      console.log "results", results
