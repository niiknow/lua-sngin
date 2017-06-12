Name
====

lua-sngin - dynamic lua scripting that scales

Run your own multi-tenant lua microservice with code hosted on s3.

Note
====

Currently, I'm a one man operation so updates will be slow.  Please feel free to enter issue and/or create pull requests.  

## Project Philosophy
1. For each feature
2. Get it to work
3. Write tests and optimize
4. Rinse and repeat

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Description](#description)
* [Synopsis](#synopsis)
* [Running](#running)
* [Benchmarks](#benchmarks)

Status
======

This library is considered experimental and still under active development.

The API is still in flux and may change without notice.

Description
===========

This library requires an nginx build with OpenSSL,
the [ngx_lua module](http://wiki.nginx.org/HttpLuaModule), and [LuaJIT 2.1](http://luajit.org/luajit.html).

Synopsis
========
Example below show how you can build an API to delete log table older than 60 days on Azure Table Storage.

* Hit the site: http://example.com/deletelog
> Code from s3://bucketname/folder/example.com/deletelog/index.lua
```lua
-- private s3 allow you to store your secret
local ACCOUNT='youraccount'
local KEY='yourkey'

-- reference public code/library on your github repo
-- by convention, use a path that is browser friendly.  it should
-- include both refs of github.com/ and blob/master/ like so
local azure = require('github.com/niiknow/webslib/blob/master/azure.lua')

-- build up your api request arguments
local now = os.time()
local today = os.date("%Y%m%d", now)
local sixtyDaysAgo = os.date("%Y%m%d", now - 59*60*24*60)
local tableSixtyDaysAgo = string.format("logtableprefix%s", sixtyDaysAgo)
local path = string.format("Tables('%s')", tableSixtyDaysAgo)
local url = string.format("http://%s.table.core.windows.net/%s", ACCOUNT, path)

local skl = azure.util.sharedkeylite({
        account = ACCOUNT, 
        key = KEY, 
        table = path })

local headers = azure.table.getHeader('DELETE', skl)

-- make the api call
local response = http.request {
    method = 'DELETE',
    url = url,
    headers = headers
}

-- return data
return tableSixtyDaysAgo
```

# Benefits of storing your code on s3
* codes are protected by private bucket
* versioning and replication
* aws provided s3 browser UI to edit your code
* s3 events can be use to trigger lua code cache purging

See wiki for more info...

Environment Variables
=====================
* AWS_ACCESS_KEY_ID=your access id
* AWS_SECRET_ACCESS_KEY=your access key
* AWS_S3_CODE_PATH=bucket-name/src-folder (bucket name/follow by base folder)

* AWS_DEFAULT_REGION=us-east-1
* SNGIN_CODECACHE_SIZE=10000 (number or lru cache items)
* SNGIN_APP_PATH=/app (sngin app path)

Running
=======

build:
```
docker build -t niiknow/lua-sngin .
```

run and debug:
```
docker run -it \
-p 80:80 \
--env AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
--env AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
--env AWS_S3_CODE_PATH=bucket-name/src-folder \
--env see above for more env variables \
niiknow/lua-sngin
```

Code Caching
============
Code caching knowledge will come in handy when working wih this module.  https://martinfowler.com/bliki/TwoHardThings.html

There are multiple levels of of code caching:
1. The code file is locally download/mirrored from s3.
2. A "If-Modified-Since" header is sent to the s3 server on an hourly interval.
3. The s3 proxy is setup to have a short cache to prevent accidental hammering of the backend server.
4. There is no need to worry about githubraw cache implementation because all code cache is done with the previous 3 step.

To prevent caching during development of script, you must do all of the following:
1. Send a post request to the /__purge endpoint like so: POST domain.com/purgecache/path-to-purge?type=file/folder
2. Request your action with the cache busting ($cb) query string parameter: domain.com/your-code?$cb=1234

This strategy allow you to simply send a purge to the root path with type=folder to perform wildcard like purges.  This is useful when debugging in development when you don't care about the caching of any endpoint.  Remember that you must also use the $cb query string when testing your code.

For multi-servers/horizontal scaling setup, you can create your own purge function that hit each of of your servers by ip-address like so: http://server-ip-address/purge/path and a Host header of the host you want to purge.  

Benchmarks
==========
Mid 2015 Macbook Pro i7 2.5ghz, macOS Sierra v10.15.5

Docker 1 core bench simple output of string - Hello World

## bench
hey -n 10000 -c 100 http://localhost/a

* nodejs - 8K
* lua - 10K
* lua github (not code cached) - 3.6K
* lua s3 (code cached) - 5K 

[Back to TOC](#table-of-contents)

TODO/ROADMAP
============
- [ ] create admin UI for editing file resides on s3 - php, easily hosted on cpanel?  use flysystem?
- [ ] strategy for storing and retrieving of additional server config in s3
- [ ] additional code store such as private github repo
- [ ] provide user with caching mechanism
- [ ] provide user with persistence storage
- [ ] additional static module
- [ ] support moonscript

# MIT
