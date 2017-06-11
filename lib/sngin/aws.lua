-- derived from https://github.com/paragasu/lua-resty-aws-auth
-- modified to use our own crypto

local crypto            = require "sngin.crypto"

local _M = {
  _VERSION = '0.1.0'
}

-- init new aws auth
function _M.new(self, options)
  local microtime = ngx.time()

  options = options or {}   -- create object if user does not provide one
  options.aws_host        = options.aws_host       or "s3.amazonaws.com"
  options.aws_region      = options.aws_region     or "us-east-1"
  options.aws_service     = options.aws_service    or "s3"
  options.content_type    = options.content_type   or "application/x-www-form-urlencoded" 
  options.request_method  = options.request_method or "GET"
  options.request_path    = options.request_path   or "/"
  options.request_body    = options.request_body   or ""
  options.iso_date        = os.date('!%Y%m%d', microtime)
  options.iso_tz          = os.date('!%Y%m%dT%H%M%SZ', microtime)
  
  setmetatable(options, self)
  self.__index = self
  return options
end

-- create canonical headers
-- header must be sorted asc
function _M.get_canonical_header(self)
  local h = {
    'content-type:' .. self.content_type,
    'host:' .. self.aws_host,
    'x-amz-date:' .. self.iso_tz
  }
  return table.concat(h, '\n')
end


function _M.get_signed_request_body(self)
  local params = self.request_body
  if type(self.request_body) == 'table' then
    table.sort(params)
    params = ngx.encode_args(params)
  end
  local digest = self:get_sha256_digest(params or '')
  return string.lower(digest) -- hash must be in lowercase hex string
end


-- get canonical request
-- https://docs.aws.amazon.com/general/latest/gr/sigv4-create-canonical-request.html
function _M.get_canonical_request(self)
  local signed_header = 'content-type;host;x-amz-date'
  local canonical_header = self:get_canonical_header()
  local signed_body = self:get_signed_request_body()
  local param  = {
    self.request_method,
    self.request_path,
    '', -- canonical querystr
    canonical_header,
    '',   -- required
    signed_header,
    signed_body
  }
  local canonical_request = table.concat(param, '\n')
  return self:get_sha256_digest(canonical_request)
end


-- generate sha256 from the given string
function _M.get_sha256_digest(self, s)
  return crypto.sha256(s).hex()
end


function _M.hmac(self, secret, message)
  return crypto.hmac(secret, message, crypto.sha256)
end


-- get signing key
-- https://docs.aws.amazon.com/general/latest/gr/sigv4-calculate-signature.html
function _M.get_signing_key(self)
  local  k_date    = self:hmac('AWS4' .. self.aws_secret, self.iso_date).digest()
  local  k_region  = self:hmac(k_date, self.aws_region).digest()
  local  k_service = self:hmac(k_region, self.aws_service).digest()
  local  k_signing = self:hmac(k_service, 'aws4_request').digest()
  return k_signing
end


-- get string
function _M.get_string_to_sign(self)
  local param = { self.iso_date, self.aws_region, self.aws_service, 'aws4_request' }
  local cred  = table.concat(param, '/')
  local req   = self:get_canonical_request()
  return table.concat({ 'AWS4-HMAC-SHA256', self.iso_tz, cred, req}, '\n')
end


-- generate signature
function _M.get_signature(self)
  local  signing_key = self:get_signing_key()
  local  string_to_sign = self:get_string_to_sign()
  return self:hmac(signing_key, string_to_sign).hex()
end


-- get authorization string
-- x-amz-content-sha256 required by s3
function _M.get_authorization_header(self)
  local  param = { self.aws_key, self.iso_date, self.aws_region, self.aws_service, 'aws4_request' }
  local header = {
    'AWS4-HMAC-SHA256 Credential=' .. table.concat(param, '/'),
    'SignedHeaders=content-type;host;x-amz-date',
    'Signature=' .. self:get_signature()
  }
  return table.concat(header, ', ')
end


-- update ngx.request.headers
-- will all the necessary aws required headers
-- for authentication
function _M.set_ngx_auth_headers(self)
  ngx.req.set_header('Authorization', self:get_authorization_header())
  ngx.req.set_header('X-Amz-Date', self:get_date_header())
  ngx.req.set_header('x-amz-content-sha256', self:get_content_sha256())
  ngx.req.set_header('Content-Type', self.content_type)

end


-- get the current timestamp in iso8601 basic format
function _M.get_date_header(self)
  return self.iso_tz
end

function _M.get_content_sha256(self)
  local digest = self:get_sha256_digest('')
  return digest
end

return _M
