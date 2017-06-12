-- route request from url to s3
-- download and eval code from s3
local sandbox           = require "sngin.sandbox"
local ngin              = require "sngin.ngin"
local cc                = require "sngin.codecache"
local utils             = require "sngin.utils"

local _M  = {}

local codeCache = cc:new(ngin.config.sngin_app_path)

function _M.run()
  local path = utils.sanitizePath(string.format("%s/%s", ngx.var.host, ngx.var.uri))
  local fn = codeCache.get(path)
  if (fn ~= nil ) then
    local rsp = sandbox.exec(fn)
    if (rsp ~= nil) then
      return ngin.handleResponse(rsp[1], rsp[2])
    end
  end
end

function _M.purge()
  local path = utils.sanitizePath(string.format("%s/%s", ngx.var.host, ngx.var.uri))
  -- move local file path to some temp path
    -- this purges code cache
  -- change cache timestamp to purge nginx cache
end

return _M