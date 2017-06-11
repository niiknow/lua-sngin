-- derived from https://github.com/pintsized/lua-resty-http
-- add ability to use capture and authenticate with oauth1.0

local http_handle       = require "resty.http"
local utils             = require "sngin.utils"

local escape_uri        = ngx.escape_uri
local unescape_uri      = ngx.unescape_uri
local encode_args       = ngx.encode_args
local decode_args       = ngx.decode_args
local encode_base64     = ngx.encode_base64
local ngx_re_match      = ngx.re.match
local string_split      = utils.split
local digest_hmac_sha1  = ngx.hmac_sha1
local digest_md5        = ngx.md5
local encodeURIComponent= utils.encodeURIComponent

-- perf
local setmetatable = setmetatable

local _M = {}

local function qsencode(tab, delimiter, quote)
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
    name = encodeURIComponent(tostring(name))

    local value = encodeURIComponent(tostring(value))
    if value ~= "" then
      query[#query+1] = string.format('%s=%s', name, q .. value .. q)
    else
      query[#query+1] = name
    end  
  end
  return table.concat(query, sep)
end

-- local functions: are executed and placed in sequential orders
local function normalizeParameters(parameters, body, query)
  local items = {qsencode(parameters, '&')}
  if body then
    string_split(body, '&', items)
  end

  if query then
    string_split(query, '&', items)
  end
  table.sort(items)
  return table.concat(items, '&')
end

local function calculateBaseString(opts, parameters)
  local body = opts["body"]
  local url = opts["urlParsed"]
  local method = opts["method"]
  local parms = normalizeParameters(parameters, body, url.query)
  return escape_uri(method) .. "&" .. escape_uri(opts["base_uri"]) .. "&" .. escape_uri(parms)
end

local function secret(auth)
  local oauth = auth["oauth"]
  return unescape_uri(oauth["consumersecret"]) .. '&' .. unescape_uri(oauth["tokensecret"] or '')
end

local function signature(opts, parameters)
  local strToSign = calculateBaseString(opts, parameters)
  opts.strToSign = strToSign
  local signedString = digest_hmac_sha1(secret(opts["auth"]), strToSign)
  opts.signature = resultparms
  return encode_base64(signedString)
end

local function oauthHeader(opts)
  local oauth = opts["auth"]["oauth"]
  if oauth then
    local timestamp = ngx.time()
    local parameters = {
      oauth_consumer_key = oauth["consumerkey"],
      oauth_token = oauth["accesstoken"],
      oauth_signature_method = "HMAC-SHA1",
      oauth_timestamp = timestamp,
      oauth_nonce = digest_md5(timestamp .. ''),
      oauth_version = oauth["version"] or '1.0'
    }

    if (oauth["accesstoken"]) then
      parameters["oauth_token"] = oauth["accesstoken"]
    end

    if (oauth["callback"]) then
      parameters["oauth_callback"] = unescape_uri(oauth["callback"])
    end

    parameters["oauth_signature"] = signature(opts, parameters)
    opts["headers"]["Authorization"] =  "OAuth " .. qsencode(parameters, ',', '"')
  end
end

local function authHeader(opts)
  local auth = opts["auth"]
  if opts["auth"] then
    if auth["oauth"] then
      return oauthHeader(opts)
    end
    local cred = encode_base64(auth[0] .. ':' .. auth[1])
    opts.headers["Authorization"] = "Basic " .. cred
  end
end

local function ngx_request(request_uri, opts)
  local capture_url = opts.capture_url or "/__capture"
  local capture_variable = opts.capture_variable  or "url"

  local method = opts.method
  local uri = request_uri
  local req_t = {}
  local new_method = ngx["HTTP_" .. method]

  req_t = {
    args    = {[capture_variable] = uri},
    method  = new_method
  }

  -- clear all browser headers
  local bh = ngx.req.get_headers()
  for k, v in pairs(bh) do
    ngx.req.clear_header(k)
  end
  local h = opts.headers or {["Accept"] = "*/*"}
  for k,v in pairs(h) do
    ngx.req.set_header(k, v)
  end
  if opts.body then req_t.body = opts.body end

  local rsp, err = ngx.location.capture(capture_url, req_t)

  if not rsp then
      ngx.log(ngx.DEBUG, "failed to make request: ", err)
      return { statuscode = 0, err = err, req = opts }
  end

  return { content = rsp.body, statuscode = rsp.status, headers = rsp.header, req = opts, rsp = rsp }
end

-- convert a table of key/value pairs into a query string
_M.qsencode = qsencode

-- convert a query string into a table of key/value pairs
_M.qsparse =  decode_args

-- make a request
function _M.request(options)
  local opts = options or {}
  if type(opts) ~= 'table' then
    opts = { url = options }
  end

  if opts.url == nil then
    return { statuscode = 0, err = "url is required" }
  end

  local httpc = http_handle.new()
  local scheme, host, port, path, query = unpack(httpc.parse_uri(httpc, opts.url, true))
  local m, err = ngx_re_match(path, [[^([^\?]*)\?*(.*)$]], "jo")
  path = m[1] or '/'
  query = m[2]

  port = ':' .. port
  if port == ":443" or port == ":80" then
    port = ''
  end

  local url = {
    scheme = scheme,
    host = host,
    path = path,
    port = port,
    query = query
  }
  local rsp, err

  opts["urlParsed"] = url
  opts["headers"] = opts["headers"] or {["Accept"] = "*/*"}
  opts["method"] = opts["method"] or "GET"
  opts["method"] = string.upper(opts["method"] .. '')
  opts["headers"]["User-Agent"]    = "Mozilla/5.0"

  if opts["data"] then
    opts["body"] = (type(opts["data"]) == "table") and encode_args(opts["data"]) or opts["data"] 
    opts["Content-Length"] = strlen(opts["body"] or '')
  end
  local base_uri = url.scheme .. "://" .. url.host .. url.port .. url.path
  opts.base_uri = base_uri
  opts.query = url.query

  authHeader(opts)
  local args = { 
    method = opts.method, 
    body = opts.body, 
    headers = opts.headers, 
    ssl_verify = false, 
    capture_url = opts.capture_url,
    capture_variable = opts.capture_variable
  }

  -- lua-resty-http issue, we have to reappend query to url
  if query then
    base_uri = base_uri .. '?' .. query
  end

  if (opts.capture_url or opts.use_capture) then
    return ngx_request(base_uri, args)
  end

  local rsp, err = httpc:request_uri(base_uri, args)

  if err then
      ngx.log(ngx.DEBUG, "failed to make request: ", err)
      return { statuscode = 0, err = err, req = opts }
  end
  
  return { content = rsp.body, statuscode = rsp.status, headers = rsp.headers, req = opts, rsp = rsp }
end

return _M
