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

app.post "/file/:hash", (req, res) ->
  manifest.init().create_hash req.params.hash, fs.createReadStream(req.files.data.path), (err) ->
    res.send("ok")

app.post "/manifest/build", (req, res) ->
  res.writeHead 200, "Content-Type":"text/plain", "Transfer-Encoding":"chunked"
  res.write "Launching build slave... "
  manifest.init(JSON.parse(req.body.manifest)).build (builder) ->
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

app.listen process.env.PORT || 5000
