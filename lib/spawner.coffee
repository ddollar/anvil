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

  spawn: (command, options, cb) ->
    spawner = this["spawn_#{@env}"]
    spawner command, options, cb

  spawn_local: (command, options, cb) ->
    args    = command.match(/("[^"]*"|[^"]+)(\s+|$)/g)
    command = args.shift().replace(/\s+$/g, "")
    args    = args.map (arg) -> arg.match(/"?([^"]*)"?/)[1]
    proc    = spawn command, args, env:process.env
    emitter = new events.EventEmitter()

    proc.stdout.on "data", (data) -> emitter.emit("data", data)
    proc.stderr.on "data", (data) -> emitter.emit("data", data)
    proc.on        "exit", (code) -> emitter.emit("end", code)
    emitter

  spawn_heroku: (command, cb) ->
    api_key = process.env.HEROKU_API_KEY
    app = process.env.HEROKU_APP
    emitter = new events.EventEmitter()

    request = restler.post "https://api.heroku.com/apps/#{app}/ps",
      headers:
        "Authorization": new Buffer(":" + api_key).toString("base64")
        "Accept":        "application/json"
        "User-Agent":    "heroku-gem/2.5"
      data:
        attach:  true
        command: command

    request.on "success", (data) ->
      url = require("url").parse(data.rendezvous_url)
      rendezvous = tls.connect url.port, url.hostname, ->
        if rendezvous.authorized
          console.log "valid socket"
          rendezvous.write url.pathname.substring(1) + "\n"
        else
          console.log "invalid socket"
      rendezvous.on "data", (data) -> console.log "data", data; emitter.emit("data", data) unless data.toString() is "rendezvous\r\n"
      rendezvous.on "end",         -> emitter.emit "end"

    request.on "error", (error) ->
      emitter.emit "error", error

    emitter

module.exports.init = (env) ->
  new Spawner(env)
