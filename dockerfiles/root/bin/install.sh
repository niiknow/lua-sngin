#!/bin/bash
#

/usr/local/openresty/luajit/bin/luarocks install lua-resty-http 0.08-0
/usr/local/openresty/luajit/bin/luarocks install sha1 0.5-1
/usr/local/openresty/luajit/bin/luarocks install penlight 1.4.1
/usr/local/openresty/luajit/bin/luarocks install lua-cjson 2.1.0-1
/usr/local/openresty/luajit/bin/luarocks install lua-lru 1.0-1
/usr/local/openresty/luajit/bin/luarocks install lua-lru luacrypto 0.3.2-2