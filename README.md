# anvil

Alternate Heroku push/deploy workflow.

## Installation

    $ heroku plugins:install https://github.com/ddollar/heroku-anvil

## Usage

#### Create a slug

	$ cd myapp; heroku push
	Generating application manifest... done
	Computing diff for upload... done, 2 files needed
	Uploading new files... done
	Launching build process... done  
	Recreating app from manifest...  done  
	Fetching buildpack...  done  
	Detecting buildpack...  done, Buildkit+Node.js  
	Compiling application...
	  Compiling for Node.js
	  ...
	Success, slug is https://anvil.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img

#### Create a slug and release it

	$ heroku push -r
	Generating application manifest... done
	Computing diff for upload... done, 2 files needed
	Uploading new files... done
	Launching build process... done  
	Recreating app from manifest...  done  
	Fetching buildpack...  done  
	Detecting buildpack...  done, Buildkit+Node.js  
	Compiling application...
	  Compiling for Node.js
	  ...
	Success, slug is https://anvil.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img
	Downloading slug... done
	Uploading slug for release... done
	Releasing to myapp... done, v30

#### Release an existing slug

	$ heroku release https://anvil.herokuapp.com/slugs/00000000-0000-0000-0000-000000000000.img
	Downloading slug... done
	Uploading slug for release... done
	Releasing to myapp... done, v31
