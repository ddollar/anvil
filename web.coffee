coffee   = require("coffee-script")
express  = require("express")
fs       = require("fs")
knox     = require("knox")
manifest = require("manifest")
util     = require("util")

app = express.createServer(
  express.logger(),
  express.cookieParser(),
  express.bodyParser())

app.get "/file/:hash", (req, res) ->
  manifest.knox.getFile "/hash/#{req.params.hash}", (err, get) =>
    get.on "data", (chunk) -> res.write chunk
    get.on "end",          -> res.end()

app.post "/file/:hash", (req, res) ->
  manifest.init().create_hash req.params.hash, fs.createReadStream(req.files.data.path), (err) ->
    res.send("ok")

app.post "/manifest/build", (req, res) ->
  options =
    buildpack: req.body.buildpack
  manifest.init(JSON.parse(req.body.manifest)).build options, (id, builder) ->
    res.writeHead 200
      "Content-Type":      "text/plain"
      "Transfer-Encoding": "chunked"
      "X-Slug-Url":        "#{process.env.ANVIL_HOST}/slugs/#{id}.img"
    builder.on "data", (data)   -> res.write(data)
    builder.on "end", (success) -> res.end()

app.post "/manifest/diff", (req, res) ->
  manifest.init(JSON.parse(req.body.manifest)).missing_hashes (hashes) ->
    res.contentType "application/json"
    res.send JSON.stringify(hashes)

app.get "/manifest/:id.tgz", (req, res) ->
  manifest.init_with_id req.params.id, (manifest) ->
    manifest.generate_tarball (stream) ->
      stream.stdout.on "data", (chunk) -> res.write(chunk)
      stream.on        "exit", (code)  -> res.end()

app.get "/manifest/:id.json", (req, res) ->
  manifest.knox.getFile "/manifest/#{req.params.id}.json", (err, get) =>
    get.on "data", (chunk) -> res.write chunk
    get.on "end",          -> res.end()

app.get "/slugs/:id.img", (req, res) ->
  manifest.knox.getFile "/slug/#{req.params.id}.img", (err, get) ->
    get.on "data", (chunk) -> res.write chunk
    get.on "end",          -> res.end()

app.listen process.env.PORT || 5000
