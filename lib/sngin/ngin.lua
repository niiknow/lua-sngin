local cjson_safe        = require "cjson.safe"
local plpretty          = require "pl.pretty"
local aws_auth          = require "sngin.aws"
local crypto            = require "sngin.crypto"
local httpc				      = require "sngin.httpclient"
local sandbox           = require "sngin.sandbox"
local utils             = require "sngin.utils"

local aws_s3_code_path  = os.getenv("AWS_S3_CODE_PATH")
local aws_region        = os.getenv("AWS_DEFAULT_REGION")
local access_key        = os.getenv("AWS_ACCESS_KEY_ID")
local secret_key        = os.getenv("AWS_SECRET_ACCESS_KEY")

local loadfile          = loadfile
local loadstring        = loadstring

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
    request = _M.getRequest(),
    __ghrawbase = __ghrawbase
  }
  return sandbox.build_env(_G or _ENV, env, sandbox.whitelist)
end

function _M.getRequest()
  ngx.req.read_body()
  local req_wrapper = {
    referer = ngx.var.http_referer or "",
    form = ngx.req.get_post_args(),
    body = ngx.req.get_body_data(),
    query = ngx.req.get_uri_args(),
    querystring = ngx.req.args,
    method = ngx.req.get_method(),
    remote_addr = ngx.var.remote_addr,
    scheme = ngx.var.scheme,
    port = ngx.var.server_port,
    server_addr = ngx.var.server_addr,
    path = ngx.var.uri,
    headers = ngx.req.get_headers()
  }
  return req_wrapper
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
      local fn, err = sandbox.loadstring(code, nil, newEnv)
      return sandbox.exec(fn)
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
  local req_method = string.lower(ngx.req.get_method())

  if type(first) == 'number' then
    statusCode = first

    if type(second) == 'string' then
      msg = second
    end
  elseif type(first) == 'string' then
    msg = first
  elseif type(first) == 'table' then

    -- attempt to execute the method that is required
    local func = first[req_method]
    if (type(func) == 'function') then
      -- execute the function in sandbox
      local env = _M.getSandboxEnv()
      setfenv(func, env)

      local rsp, err = func()
      second = rsp.headers or {}
      msg = rsp.content
      statusCode = rsp.statuscode or statusCode
    else  
      statusCode = 404
    end
  end


  if type(second) == 'table' then
    for k, v in pairs(second) do
      ngx.req.set_header(k, v)
    end

    if second["Content-Type"] == nil then
      ngx.req.set_header('Content-Type', contentType)
    end
  else
    ngx.req.set_header('Content-Type', contentType)
  end

  ngx.status = statusCode
  ngx.say(msg)
  ngx.exit(statusCode)
end

function _M.getCodeFromS3(options)
  local opts                    = options or {}
  local capture_url             = opts.capture_url or "/__code"
  local capture_variable        = opts.capture_variable  or "url"

  -- get options or default to current request host and uri
  local host                    = opts.host or ngx.var.host
  local path                    = opts.uri or ngx.var.uri

  -- ngx.log(ngx.ERR, "mydebug: " .. secret_key)
  local cleanPath, querystring  = string.match(path, "([^?#]*)(.*)")
  local full_path               = string.format("/%s/%s/%s/index.lua", aws_s3_code_path, host, cleanPath)

  -- cleanup path, remove double forward slash and double periods from path
  full_path                     = string.gsub(string.gsub(full_path, "%.%.", ""), "//", "/")

  -- setup config
  local config = {
    aws_key        = access_key,
    aws_secret     = secret_key,
    aws_region     = aws_region,
    request_path   = full_path
  }

  -- get the signature
  local aws          = aws_auth:new(config)
  
  -- clear all browser headers
  local bh = ngx.req.get_headers()
  for k, v in pairs(bh) do
    ngx.req.clear_header(k)
  end

  local uri = string.format("https://%s%s", config.aws_host, config.request_path)

  -- set request header
  aws:set_ngx_auth_headers()

  local req_t = {
    args    = {[capture_variable] = uri},
    method  = ngx["HTTP_GET"]
  }
  
  return ngx.location.capture(capture_url, req_t)
end

return _M