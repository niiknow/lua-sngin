local _M = {}

local cjson_safe        = require "cjson.safe"
local plpretty          = require "pl.pretty"
local crypto            = require "crypto"
local bcrypt            = require "bcrypt" 
local hmac              = require "crypto.hmac"
local httpc				= require "sngin.httpclient"
local sandbox           = require "sngin.sandbox"
local utils             = require "sngin.utils"

local capture           = ngx.location.capture
local encode_base64     = ngx.encode_base64
local decode_base64     = ngx.decode_base64
local escape_uri        = ngx.escape_uri

local _M = {}

function crypto_wrapper(dtype)
  local rst = {
    digest = function(str)
      return crypto.digest(dtype, str, true)
    end,
    hex = function(str)
      return crypto.digest(dtype, string, false)
    end
  }
end

function hmac_wrapper(key, str, hasher)
  local rst = {
    digest = function()
      return hmac.digest(hasher, str, key, true)
    end,
    hex = function()
      hmac.digest(hasher, str, key, false)
    end
  }
end

local bcrypt_hash = function(str, rounds)
  return bcrypt.digest(str, rounds or 12)
end

_M.base64 = {
  encode = encode_base64,
  decode = decode_base64
}

_M.json = {
  encode = cjson_safe.encode,
  decode = cjson_safe.decode
}

_M.crypto = {
  bcrypt = bcrypt_hash,
  md5 = crypto_wrapper("md5"),
  sha1 = crypto_wrapper("sha1"),
  sha256 = crypto_wrapper("sha256"),
  hmac = function(key, str, hasher)
    if hasher == self.md5 then
      return hmac_wrapper(key, str, "md5")
    elseif hasher == self.sha1 then
      return hmac_wrapper(key, str, "sha1")
    elseif hasher == self.sha256 then
      return hmac_wrapper(key, str, "sha256")
    end
  end
}

_M.crypto = crypto

_M.dump = plpretty.write

local function convertPeriodToSlash(path)
	path = string.gsub(path, "\.lua$", "")
	path = string.gsub(path, "[\.]", "/")
	return path
end

local function resolvePath(modname)	
    if string.find(modname, "github.com") then
		local host, user, repo, pathx, query = string.match(modname, "([^/?#]*)(/[^/]+)(/[^/]+)(/[^?#]*)(.*)")
		local path, file = string.match(pathx, "^(.*/)([^/]*)$")
		host = '/proxy/githubraw'

		local prefix = host..user..repo..'/master'..path
	  return prefix..convertPeriodToSlash(file)..".lua"..query
	end
	return modname
end

local function loadngx(url)
    local res = httpc.request({ url = url, method = "GET", capture_uri = "__githubraw" })
    if res.status == 200 then return res.body end
    return "nil"
end

function _M.require_new(nodename)
	local env = {
		http = httpclient,
		require = self.require_new,
		base64 = self.base64,
		json = self.json,
		dump = self.dump,
		log = self.log,
		utils = utils,
		loadstring = self.loadstring_new
	}
	local newEnv = sandbox.build_env(_G or _ENV, env, sandbox.whitelist)

	if (string.find(modname, "/")) then
		local path = resolvePath(modname)
		local code = loadngx(path)

		-- todo: redo sandbox to cache code somewhere
		return sandbox.eval(code, nil, newEnv)
	elseif newEnv[modname]
		return newEnv, newEnv[modname]
	else
		return nil, "unable to load module [" .. nodename .. "]"
	end
 
end

return _M