fs      = require("fs")
knox    = require("knox")
program = require("commander")

program
  .version('0.0.1')
  .option('-a, --access <id>',     'aws access id, defaults to $AWS_ACCESS')
  .option('-s, --secret <key>',    'aws secret key, defaults to $AWS_SECRET')
  .option('-b, --bucket <bucket>', 'the bucket to use, defaults to $S3_BUCKET')

program.knox = (program) ->
  knox.createClient
    key:    program.access || process.env.AWS_ACCESS
    secret: program.secret || process.env.AWS_SECRET
    bucket: program.bucket || process.env.S3_BUCKET

program.command("put <local> <remote>")
  .action (local, remote) ->
    headers =
      "x-amz-acl": "public-read"
    program.knox(program).putStream fs.createReadStream(local), remote, headers, (err) ->
      console.log if err then "error: #{err}" else "success"

module.exports.execute = (args) ->
  program.parse(args)
