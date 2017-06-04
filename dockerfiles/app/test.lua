local ngin = require "sngin.ngin"

local rsp = ngin.require_new("github.com/anvaka/redis-load-scripts/test/scripts/nested/main.lua")
ngx.say(rsp)