local crypto            = require "crypto"
local bcrypt            = require "bcrypt" 
local hmac              = require "crypto.hmac"

local _M = {}

local function crypto_wrapper(dtype, str)
  local rst = {
    digest = function()
      return crypto.digest(dtype, str, true)
    end,
    hex = function()
      return crypto.digest(dtype, str, false)
    end
  }

  return rst
end

local function hmac_wrapper(key, str, hasher)
  local rst = {
    digest = function()
      return hmac.digest(hasher, str, key, true)
    end,
    hex = function()
      return hmac.digest(hasher, str, key, false)
    end
  }

  return rst
end

_M.bcrypt = function(str, rounds) 
	return bcrypt.digest(str, rounds or 12)
end

_M.md5 = function(str) 
	return crypto_wrapper("md5", str)
end
_M.sha1 = function(str) 
	return crypto_wrapper("sha1", str)
end

_M.sha256 = function(str)
	return crypto_wrapper("sha256", str)
end

function _M.hmac(key, str, hasher)
	if hasher == _M.md5 then
	  return hmac_wrapper(key, str, "md5")
	elseif hasher == _M.sha1 then
	  return hmac_wrapper(key, str, "sha1")
	elseif hasher == _M.sha256 then
	  return hmac_wrapper(key, str, "sha256")
	end
end

return _M
