Name
====

lua-sngin - dynamic scripting for ngx_lua and LuaJIT

Table of Contents
=================

* [Name](#name)
* [Status](#status)
* [Description](#description)
* [Synopsis](#synopsis)

Status
======

This library is considered experimental and still under active development.

The API is still in flux and may change without notice.

Description
===========

This library requires an nginx build with OpenSSL,
the [ngx_lua module](http://wiki.nginx.org/HttpLuaModule), and [LuaJIT 2.0](http://luajit.org/luajit.html).

Synopsis
========

```lua
    # nginx.conf:

    lua_package_path "/path/to/lua-resty-string/lib/?.lua;;";

    server {
        location = /test {
            content_by_lua_file conf/test.lua;
        }
    }

    -- conf/test.lua:


```

[Back to TOC](#table-of-contents)

# Note
Mid 2015 Macbook Pro i7 2.5ghz macOS Sierra 10.15.5
Docker 1 core - Hello World
Local - 2365 req/s
Github root - 517 req/s

# MIT
