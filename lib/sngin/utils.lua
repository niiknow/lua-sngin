local cjson_safe        = require "cjson.safe"
local plpretty          = require "pl.pretty"
local crypto            = require "crypto"
local bcrypt            = require "bcrypt" 
local hmac              = require "crypto.hmac"

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
--[[
function resty_crypto_wrapper(dtype)
  local resty_crypto = require('resty.' .. dtype)
  local rstey_string = require "resty.string"
  local digest = function(str)
    local inst = resty_crypto:new()
    return inst:update(str).finall()
  end
  local rst = {
    digest = digest,
    hex = function(str)
      return rstey_string.to_hex(digest())
    end
  }
end

  -- sha256 = resty_crypto_wrapper("sha256"),
]]

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

function _M.trim(str)
	if (str == nil) then
		return nil
	end
	return string.match(str, '^%s*(.*%S)') or ''
end

function _M.slugify(str)
	if (str == nil) then
		return nil
	end
	str = self.trim(str)
	return string.lower(string.gsub(string.gsub(str,"[^ A-Za-z]"," "),"[ ]+","-"))
end

function _M.slugemail(str)
	if (str == nil) then
		return nil
	end
	str = trim(str)
	return string.lower(string.gsub(str,"[^@0-9A-Za-z]","-"))
end

function _M.split(str, sep, dest)
	if (str == nil) then
		return {}
	end

  if sep == nil then
    sep = "%s"
  end

  local t = dest or {}
  for str in string.gmatch(str, "([^"..sep.."]+)") do
    table.insert(t, str)
  end

  return t
end

function _M.qsencode(tab, delimiter, quote)
  local query = {}
  local q = quote or ''
  local sep = delimiter or ''
  local keys = {}
  for k in pairs(tab) do
    keys[#keys+1] = k
  end
  table.sort(keys)
  for _,name in ipairs(keys) do
    local value = tab[name]
    name = escape_uri(tostring(name))

    local value = escape_uri(tostring(value))
    if value ~= "" then
      query[#query+1] = string.format('%s=%s', name, q .. value .. q)
    else
      query[#query+1] = name
    end  
  end
  return table.concat(query, sep)
end

function _M.log(str)
  -- log remotely
  -- log locally
  ngx.log(ngx.INFO, str)
end


return _M