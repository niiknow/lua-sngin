-- https://github.com/pintsized/lua-resty-http
local http_handle = require('resty.http')
local sha1 = require('sha1')

local escape_uri = ngx.escape_uri
local unescape_uri = ngx.unescape_uri
local encode_args = ngx.encode_args
local decode_args = ngx.decode_args
local encode_base64 = ngx.encode_base64
local ngx_re_match = ngx.re.match

-- perf
local setmetatable = setmetatable

local _M = {}

function qsencode(tab, delimiter, quote)
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

function normalizeParameters(parameters, body, query)
  local items = {qsencode(parameters, '&')}
  if body then
    mysplit(body, '&', items)
  end

  if query then
    mysplit(query, '&', items)
  end
  table.sort(items)
  return table.concat(items, '&')
end

function authHeader(opts)
  local auth = opts["auth"]
  if opts["auth"] then
    if auth["oauth"] then
      return oauthHeader(opts)
    end
    local cred = encode_base64(auth[0] .. ':' .. auth[1])
    opts.headers["Authorization"] = "Basic " .. cred
  end
end

function oauthHeader(opts)
  local oauth = opts["auth"]["oauth"]
  if oauth then
    local timestamp = ngx.time()
    local parameters = {
      oauth_consumer_key = oauth["consumerkey"],
      oauth_token = oauth["accesstoken"],
      oauth_signature_method = "HMAC-SHA1",
      oauth_timestamp = timestamp,
      oauth_nonce = sha1(timestamp .. ''),
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

function calculateBaseString(opts, parameters)
  local body = opts["body"]
  local url = opts["urlParsed"]
  local method = opts["method"]
  local parms = normalizeParameters(parameters, body, url.query)
  return escape_uri(method) .. "&" .. escape_uri(opts["base_uri"]) .. "&" .. escape_uri(parms)
end

function signature(opts, parameters)
  local strToSign = calculateBaseString(opts, parameters)
  opts.strToSign = strToSign
  local signedString = sha1.hmac_binary(secret(opts["auth"]), strToSign)
  opts.signature = resultparms
  return encode_base64(signedString)
end

function secret(auth)
  local oauth = auth["oauth"]
  return unescape_uri(oauth["consumersecret"]) .. '&' .. unescape_uri(oauth["tokensecret"] or '')
end

function mysplit(str, sep, dest)
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

function ngx_request(request_uri, opts)
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
      ngx.log(ngx.ERR, "failed to make request: ", err)
      return { statuscode = 0, err = err, req = opts }
  end

  return { content = rsp.body, statuscode = rsp.status, headers = rsp.header, req = opts, rsp = rsp }
end

-- convert a table of key/value pairs into a query string
_M.qsencode = qsencode

-- convert a query string into a table of key/value pairs
_M.qsparse =  decode_args


--[[
    url – The target URL, including scheme, e.g. http://example.com
    method (optional, default is "GET") – The HTTP verb, e.g. GET or POST
    data (optional) – Either a string (the raw bytes of the request body) or a table (converted to form POST parameters)
    params (optional) – A table that's converted into query string parameters. E.g. {color="red"} becomes ?color=red
    auth (optional) – Two possibilities:
        auth={'username', 'password'} means to use HTTP basic authentication
        auth={oauth={consumertoken='...', consumersecret='...', accesstoken='...', tokensecret='...'}} means to sign the request with OAuth. Only consumertoken and consumersecret are required (e.g. for obtaining a request token)
    headers (optional) – A table of the request header key/value pairs
call to http.request returns a table with the following fields:
    content – The raw bytes of the HTTP response body, after being decoded if necessary according to the response's Content-Encoding header.
    statuscode – The numeric status code of the HTTP response
    headers – A table of the response's headers
The function http.qsencode can be used to convert a table of key/value pairs into a query string. This function is rarely needed because the params field can be used to the same effect when making an HTTP request.
The function http.qsparse can be used to convert a query string into a table of key/value pairs. This function is rarely needed because request.query already contains the parsed query string for an incoming request. 
]]
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
  local args = { method = opts.method, body = opts.body, headers = opts.headers, ssl_verify = false }

  -- lua-resty-http issue, we have to reappend query to url
  if query then
    base_uri = base_uri .. '?' .. query
  end

  if (opts.use_capture) then
    return ngx_request(base_uri, args)
  end

  local rsp, err = httpc:request_uri(base_uri, args)

  if err then
      ngx.log(ngx.ERR, "failed to make request: ", err)
      return { statuscode = 0, err = err, req = opts }
  end
  
  return { content = rsp.body, statuscode = rsp.status, headers = rsp.headers, req = opts, rsp = rsp }
end

return _M
