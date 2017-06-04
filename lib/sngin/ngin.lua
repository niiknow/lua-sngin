local cjson_safe        = require "cjson.safe"
local plpretty          = require "pl.pretty"
local crypto            = require "crypto"
local bcrypt            = require "bcrypt" 
local hmac              = require "crypto.hmac"
local httpc				      = require "sngin.httpclient"
local sandbox           = require "sngin.sandbox"
local utils             = require "sngin.utils"

local capture           = ngx.location.capture
local encode_base64     = ngx.encode_base64
local decode_base64     = ngx.decode_base64
local escape_uri        = ngx.escape_uri
local parseghrlua       = utils.parseGithubRawLua

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

local function loadngx(url)
    local res = httpc.request({ url = url, method = "GET", capture_url = "/__githubraw" })
    if res.statuscode == 200 then return res.content end
    return "nil"
end

function _M.require_new(modname)
	local env = {
		http = httpclient,
		require = _M.require_new,
		base64 = _M.base64,
		json = _M.json,
		dump = _M.dump,
		log = _M.log,
		utils = utils,
		loadstring = _M.loadstring_new,
    __ghrawbase = __ghrawbase
	}
	local newEnv = sandbox.build_env(_G or _ENV, env, sandbox.whitelist)

	if newEnv[modname] then
		return newEnv[modname]
  else
    local base, file, query = parseghrlua(modname)
    if base then
      local code = loadngx(base .. file .. query)
      -- return code

      -- todo: redo sandbox to cache compiled code somewhere
      env.__ghrawbase = base
      local ok, ret = sandbox.eval(code, nil, newEnv)
      if ok then
        return ret
      end
    end
	end

	return nil, "unable to load module [" .. modname .. "]"
end

return _M