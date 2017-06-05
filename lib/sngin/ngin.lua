local cjson_safe        = require "cjson.safe"
local plpretty          = require "pl.pretty"
local crypto            = require "sngin.crypto"
local httpc				      = require "sngin.httpclient"
local sandbox           = require "sngin.sandbox"
local utils             = require "sngin.utils"

local capture           = ngx.location.capture
local encode_base64     = ngx.encode_base64
local decode_base64     = ngx.decode_base64
local escape_uri        = ngx.escape_uri
local parseghrlua       = utils.parseGithubRawLua

local _M = {}

_M.base64 = {
  encode = encode_base64,
  decode = decode_base64
}

_M.json = {
  encode = cjson_safe.encode,
  decode = cjson_safe.decode
}

_M.dump = plpretty.write

local function loadngx(url)
    local res = httpc.request({ url = url, method = "GET", capture_url = "/__githubraw" })
    if res.statuscode == 200 then return res.content end
    return "nil"
end

function _M.getSandboxEnv()
  local env = {
    http = httpc,
    require = _M.require_new,
    base64 = _M.base64,
    json = _M.json,
    dump = _M.dump,
    log = _M.log,
    utils = utils,
    loadstring = _M.loadstring_new,
    crypto = crypto,
    __ghrawbase = __ghrawbase
  }
  return sandbox.build_env(_G or _ENV, env, sandbox.whitelist)
end

function _M.require_new(modname)
  local newEnv = _M.getSandboxEnv()
	if newEnv[modname] then
		return newEnv[modname]
  else
    local base, file, query = parseghrlua(modname)
    if base then
      local code = loadngx(base .. file .. query)
      -- return code

      -- todo: redo sandbox to cache compiled code somewhere
      newEnv.__ghrawbase = base
      local ok, ret = sandbox.eval(code, nil, newEnv)
      if ok then
        return ret
      end
    end
	end

	return nil, "unable to load module [" .. modname .. "]"
end

function _M.log(msg)
  -- ngx capture to /__log
  return nil
end

function _M.handleResponse(first, second)
  local statusCode = 200
  local msg = ""
  local contentType = "text/plain"
  local opts = {}

  if type(first) == 'number' then
    statusCode = first

    if type(second) == 'string' then
      msg = second
    end
  elseif type(first) == 'string' then
    msg = first
  elseif type(first) == 'table' then
    contentType = "application/json"
    msg = cjson_safe.encode(first)
  end

  ngx.req.set_header('Content-Type', contentType)

  if type(second) == 'table' then
    for k, v in pairs(second) do
      ngx.req.set_header(k, v)
    end
  end

  ngx.status = statusCode
  ngx.say(msg)
  ngx.exit(statusCode)
end

return _M