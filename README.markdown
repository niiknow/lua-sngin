Name
====

lua-sngin - dynamic scripting for ngx_lua and LuaJIT

Run your own multi-tenant lua microservice with code hosted on s3.  Everything by convention.

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Description](#description)
* [Synopsis](#synopsis)
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

Benchmarks
==========
## bench1
* Mid 2015 Macbook Pro i7 2.5ghz macOS Sierra 10.15.5
* Docker 1 core - Hello World
* Local - 2365 req/s
* Github root - 517 req/s
* NodeJs Directly - 6498 req/s

[Back to TOC](#table-of-contents)

# MIT
