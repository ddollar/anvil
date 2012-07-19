coffee = require("coffee-script")

class Logger

  constructor: (@subject, @options={}) ->

  write: (subject, options={}) ->
    message = subject
    message = "foo #{message} #{key}=\"#{val}\"" for key, val of options
    console.log message

  log: (opts={}, cb) ->
    options = coffee.helpers.merge(@options, opts)
    if cb?
      logger = new Logger(@subject, options)
      start  = new Date().getTime()
      write @subject, coffee.helpers.merge(options, start:start)
      cb(logger.log)
      finish  = new Date().getTime()
      elapsed = (finish - start)
      write subject, coffee.helpers.merge(options, finish:finish, elapsed:elapsed)
    else
      write subject, options

log = (subject, options={}) ->
  message = subject
  message = "#{message} #{key}=\"#{val}\"" for key, val of options
  console.log message

module.exports = (subject, options={}, cb=null) ->
  new Logger(subject).log(options, cb)
