-- route request from url to s3
-- download and eval code from s3

local _M  = {}
local aws_auth          = require "sngin.aws"
local aws_s3_code_path  = os.getenv("AWS_S3_CODE_PATH")
local aws_region        = os.getenv("AWS_DEFAULT_REGION")
local access_key        = os.getenv("AWS_ACCESS_KEY_ID")
local secret_key        = os.getenv("AWS_SECRET_ACCESS_KEY")
local sandbox           = require "sngin.sandbox"
local ngin              = require "sngin.ngin"
local httpc             = require "sngin.httpclient"
local utils             = require "sngin.utils"

function _M.init(options)
  local opts = options or {}
  local capture_url = opts.capture_url or "/__code"
  local capture_variable = opts.capture_variable  or "url"

  -- get current request
  local host              = ngx.var.host
  local path              = ngx.var.uri

  -- ngx.log(ngx.ERR, "mydebug: " .. secret_key)
  local cleanPath, querystring = string.match(path, "([^?#]*)(.*)")
  local full_path         = string.format("/%s/%s/%s/index.lua", aws_s3_code_path, host, cleanPath)

  -- cleanup path, remove double forward slash and double periods from path
  full_path               = string.gsub(string.gsub(full_path, "%.%.", ""), "//", "/")

  -- Default to us-east-1 when AWS_DEFAULT_REGION is not
  -- set.
  if not aws_region then
      aws_region = "us-east-1"
  end

  -- setup config
  local config = {
    aws_host       = "s3.amazonaws.com",
    aws_key        = access_key,
    aws_secret     = secret_key,
    aws_region     = aws_region,
    aws_service    = "s3",
    content_type   = "",
    request_method = "GET",
    request_path   = full_path,
    request_body   = ""
  }

  -- get the signature
  local aws        = aws_auth:new(config)

  -- clear all browser headers
  local bh = ngx.req.get_headers()
  for k, v in pairs(bh) do
    ngx.req.clear_header(k)
  end

  local uri = string.format("https://%s%s", config.aws_host, config.request_path)

  req_t = {
    args    = {[capture_variable] = uri},
    method  = ngx["HTTP_GET"]
  }

  -- set request header
  ngx.req.set_header('Authorization', aws:get_authorization_header())
  ngx.req.set_header('X-Amz-Date', aws:get_date_header())
  ngx.req.set_header('x-amz-content-sha256', aws:get_content_sha256())

  local rsp, err = ngx.location.capture(capture_url, req_t)
  if (rsp ~= nil) then
    if (rsp.status == 200) then
      -- process response
     local env = {
        http = httpc,
        require = ngin.require_new,
        base64 = ngin.base64,
        json = ngin.json,
        dump = ngin.dump,
        log = ngin.log,
        utils = utils,
        loadstring = ngin.loadstring_new,
        __ghrawbase = __ghrawbase
      }

      local newEnv = sandbox.build_env(_G or _ENV, env, sandbox.whitelist)
      local ok, first, second = sandbox.eval(rsp.body, nil, newEnv)
      if ok then
        return ngin.handleResponse(first, second)
      end
      return ngin.handleResponse(500, ngin.dump(first))
    end

    return ngin.handleResponse(rsp.status, rsp.body)
  end

  return ngin.handleResponse(500, ngin.dump(err))
end

return _M