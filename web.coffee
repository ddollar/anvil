coffee   = require("coffee-script")
express  = require("express")
fs       = require("fs")
manifest = require("manifest")
storage  = require("storage").init()
util     = require("util")

app = express.createServer(
  express.logger(),
  express.cookieParser(),
  express.bodyParser())

app.get "/file/:hash", (req, res) ->
  storage.get "/hash/#{req.params.hash}", (err, get) =>
    get.on "data", (chunk) -> res.write chunk
    get.on "end",          -> res.end()

app.post "/file/:hash", (req, res) ->
  storage.create_stream "/hash/#{req.params.hash}", fs.createReadStream(req.files.data.path), (err) ->
    res.send("ok")

app.post "/manifest", (req, res) ->
  manifest.init(JSON.parse(req.body.manifest)).save (err, id) ->
    res.contentType "application/json"
    res.send JSON.stringify({ id:id })

app.post "/manifest/build", (req, res) ->
  options =
    buildpack: req.body.buildpack
    env:       req.body.env
  manifest.init(JSON.parse(req.body.manifest)).build options, (build, manifest) ->
    res.writeHead 200
      "Content-Type":      "text/plain"
      "Transfer-Encoding": "chunked"
      "X-Slug-Url":        manifest.slug_url()
    build.on "data", (data)   -> res.write(data)
    build.on "end", (success) -> res.end()

app.post "/manifest/diff", (req, res) ->
  manifest.init(JSON.parse(req.body.manifest)).missing_hashes (hashes) ->
    res.contentType "application/json"
    res.send JSON.stringify(hashes)

app.get "/manifest/:id.json", (req, res) ->
  storage.get "/manifest/#{req.params.id}.json", (err, get) =>
    get.on "data", (chunk) -> res.write chunk
    get.on "end",          -> res.end()

app.get "/slugs/:id.img", (req, res) ->
  storage.get "/slug/#{req.params.id}.img", (err, get) ->
    get.on "data", (chunk) -> res.write chunk
    get.on "end",          -> res.end()

app.listen process.env.PORT || 5000
