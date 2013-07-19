events  = require("events")
https   = require("https")
net     = require("net")
qs      = require("querystring")
restler = require("restler")
spawn   = require("child_process").spawn
tls     = require("tls")

class Spawner

  constructor: (env) ->
    @env = env or process.env.SPAWN_ENV or "local"

  spawn: (command, options) ->
    spawner = this["spawn_#{@env}"]
    spawner command, options

  spawn_local: (command, options) ->
    proc    = spawn "bash", ["-c", command], env:(options.env || {})
    emitter = new events.EventEmitter()

    proc.stdout.on "data", (data) -> emitter.emit("data", data)
    proc.stderr.on "data", (data) -> emitter.emit("data", data)
    proc.on        "exit", (code) -> emitter.emit("end", code)
    emitter

  spawn_heroku: (command, options) ->
    host    = process.env.HEROKU_HOST
    api_key = process.env.HEROKU_API_KEY
    app     = process.env.HEROKU_APP
    emitter = new events.EventEmitter()

    data = {}
    data["ps_env[#{key}]"] = ""  for key, val of process.env # nullify parent env
    data["ps_env[#{key}]"] = val for key, val of options.env # only add desired env
    data["attach"] = "true"
    data["command"] = command
    data["size"] = (process.env.DYNO_SIZE || "2")

    request = restler.post "https://#{host}/apps/#{app}/ps",
      headers:
        "Authorization": new Buffer(":" + api_key).toString("base64")
        "Accept":        "application/json"
        "User-Agent":    "anvil/0.0"
      data: data

    request.on "success", (data) ->
      url = require("url").parse(data.rendezvous_url)
      rendezvous = tls.connect url.port, url.hostname, ->
        # work around invalid cert
        if true || rendezvous.authorized
          console.log "valid socket"
          rendezvous.write url.pathname.substring(1) + "\n"
        else
          console.log "invalid socket"

      ping = setInterval (->
        try
          rendezvous.write " "
        catch error
          console.log "error writing to rendezvous"
          clearInterval ping
      ), 1000

      rendezvous.on "data", (data) -> emitter.emit("data", data) unless data.toString() is "rendezvous\r\n"
      rendezvous.on "end",         -> emitter.emit "end"; clearInterval ping

    request.on "error", (error) ->
      emitter.emit "error", error

    emitter

module.exports.init = (env) ->
  new Spawner(env)
