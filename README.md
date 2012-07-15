# anvil

Generic Build Server

## Installation

    $ heroku plugins:install https://github.com/ddollar/heroku-anvil

## Usage

#### Create a slug

    $ heroku build
    Generating app manifest... done
    Uploading new files... done, 0 files needed
    Launching build process... done
    Recreating app from manifest... done
    Fetching buildpack... done
    Detecting buildpack... done, Buildkit+Node.js
    Compiling app...
      Compiling for Node.js
      ...
    Creating slug... done
    Uploading slug... done
    Success, slug is https://anvil.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img

#### Create a slug and release it

    $ heroku build -r
    Generating app manifest... done
    Uploading new files... done, 0 files needed
    Launching build process... done
    Recreating app from manifest... done
    Fetching buildpack... done
    Detecting buildpack... done, Buildkit+Node.js
    Compiling app...
      Compiling for Node.js
      ...
    Creating slug... done
    Uploading slug... done
    Success, slug is https://anvil.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img
    Downloading slug... done
    Releasing to anvil... done, v158

#### Release an existing slug

    $ heroku release https://anvil.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img
    Downloading slug... done
    Releasing to anvil... done, v158

## Advanced Usage

#### Build

    Usage: heroku build [DIR]

     deploy code

     -b, --buildpack URL  # use a custom buildpack
     -e, --runtime-env    # use runtime environment during build
     -r, --release        # release the slug to an app

#### Release

    Usage: heroku release SLUG_URL

      release a slug

## API

Applications are described by a manifest, in JSON format:

    {
      "README.md": {
        "mtime": 1339185087,
        "mode":  100644,
        "hash":  "0000000000000000000000000000000000000000000000000000000000000000"
      },
      "lib/web.rb": {
        "mtime": 1339185087,
        "mode":  100644,
        "hash":  "0000000000000000000000000000000000000000000000000000000000000000"
      }
    }

### POST /manifest
##### Store a manifest

###### Options
* `manifest`: an application manifest as json

###### Example
    $ curl -X POST https://anvil.herokuapp.com/manifest \
           -d "manifest=$(cat manifest.json)"
    {"id":"00000000-0000-0000-0000-000000000000"}

### POST /manifest/build
##### Build a manifest

###### Options
* `manifest`: an application manifest as json
* `buildpack`: a buildpack url (optional)
* `env`: a hash of environment variables to use during build

###### Example
    $ curl -v -X POST https://anvil.herokuapp.com/manifest \
           -d "manifest=$(cat manifest.json)" \
           -d "buildpack=https%3A%2F%2Fbuildkit.herokuapp.com%2Fbuildkit%2Fdefault.tgz" \
           -d "env[FOO]=bar"
	* Connected to anvil.herokuapp.com (107.20.215.233) port 443 (#0)
	> POST /manifest/build HTTP/1.1
	< HTTP/1.1 100 Continue
	< HTTP/1.1 200 OK
	< Content-Type: text/plain
	< Transfer-Encoding: chunked
	< X-Slug-Url: http://localhost:5000/slugs/00000000-0000-0000-0000-000000000000.img
	< Connection: keep-alive
	<
	Launching build process... done
	Recreating app from manifest... done
	Fetching buildpack... done
	Detecting buildpack... done, Buildkit+Ruby
	Compiling app...
	...

### POST /manifest/diff
##### Return a list of hashes that are unknown by the server

###### Options
* `manifest`: an application manifest as json

###### Example
    $ curl -X POST https://anvil.herokuapp.com/manifest
           -d "manifest=$(cat manifest.json)"
    ["0000000000000000000000000000000000000000000000000000000000000000"]

### GET /file/:hash
##### Retrieve a file by hash

###### Example
    $ curl -X GET https://anvil.herokuapp.com/file/0000000000000000000000000000000000000000000000000000000000000000
    file data here
    …

### POST /file/:hash
##### Store a file by hash

###### Example
    $ curl -X POST https://anvil.herokuapp.com/file/0000000000000000000000000000000000000000000000000000000000000000
           -F data=@myfile
    "ok"
