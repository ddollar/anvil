coffee = require("coffee-script")

class Logger

  constructor: (@subject, @options={}) ->

  write: (subject, options={}) ->
    message = ("#{key}=\"#{val}\"" for key, val of coffee.helpers.merge(subject:subject, options))
    console.log message.join(" ")

  log: (opts={}, cb) ->
    options = coffee.helpers.merge(@options, opts)
    if cb?
      logger = new Logger(@subject, options)
      start  = new Date().getTime()
      @write @subject, coffee.helpers.merge(options, start:start)
      cb(logger.log)
      finish  = new Date().getTime()
      elapsed = (finish - start)
      @write @subject, coffee.helpers.merge(options, finish:finish, elapsed:elapsed)
    else
      @write @subject, options

module.exports = (subject, options={}, cb=null) ->
  new Logger(subject).log(options, cb)
