Name
====

lua-sngin - dynamic scripting for ngx_lua and LuaJIT

Run your own multi-tenant lua microservice with code hosted on s3.  Everything by convention.

Note
====

Currently, I'm a one man operation so updates may be slow.  Please feel free to enter issue and create pull requests.  

## Project Philosophy
1. For each feature
2. Get it to work
3. Write tests and optimize
4. Repeat

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

* Hit the site: http://example.com/deletelog
> Code from s3://bucketname/folder/example.com/deletelog/index.lua
```lua
-- private s3 allow you to store your secret
local ACCOUNT='youraccount'
local KEY='yourkey'

-- reference public code from your github repo
-- by convention, use a path that you can actually resolve with browser
-- so we require both refs of github.com/ and blob/master/ in path
local azure = require('github.com/niiknow/webslib/blob/master/azure.lua')

-- build you api call
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
* JWT_SECRET=some-secret (jwt secret)
* JWT_TTL=600 (ttl for token expires in seconds 600s/1h)

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
--env see above for more env variables \
niiknow/lua-sngin
```


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

TODO
====
- [ ] create admin UI for editing file resides on s3 - php, easily hosted on cpanel?  use flysystem?

# MIT
