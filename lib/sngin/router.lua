-- route request from url to s3
-- download and eval code from s3
local sandbox           = require "sngin.sandbox"
local ngin              = require "sngin.ngin"
local cc                = require "sngin.codecache"
local _M  = {}

local codeCache = cc:new(ngin.config.sngin_app_path)

function _M.init()
  local fn = codeCache.get(string.format("%s/%s", ngx.var.host, ngx.var.uri))
  if (fn ~= nil ) then
    local rsp = sandbox.exec(fn)
    if (rsp ~= nil) then
      return ngin.handleResponse(rsp[1], rsp[2])
    end
  end
end

return _M