local aws_auth          = require "sngin.aws"
local aws_s3_code_path  = os.getenv('AWS_S3_CODE_PATH')
local access_key        = os.getenv('AWS_ACCESS_KEY_ID')
local secret_key        = os.getenv('AWS_SECRET_ACCESS_KEY')
local args              = ngx.req.get_uri_args()
local args_path         = args.path
local args_host         = args.host

local full_path         = string.format("/%s/%s/%s", aws_s3_code_path, args_host, args_path)

-- cleanup path, remove double forward slash and double periods from path
full_path               = string.gsub(string.gsub(full_path, "%.%.", ""), "//", "/")

-- setup config
local config = {
  aws_host       = "s3.amazonaws.com",
  aws_key        = access_key,
  aws_secret     = secret_key,
  aws_region     = "",
  aws_service    = "s3",
  content_type   = "application/x-www-form-urlencoded",
  request_method = "GET",
  request_path   = full_path,
  request_body   = ""
}

-- clear all args since we no longer need it
ngx.req.set_uri_args({});

-- get the signature
local aws        = aws_auth:new(config)

-- get the generated authorization header
-- eg: AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/iam/aws4_request,
---    SignedHeaders=content-type;host;x-amz-date, Signature=xxx
local auth       = aws:get_authorization_header()

-- get the x-amz-date header
local amz_date   = aws:get_amz_date_header()

-- set request header
ngx.req.set_header('Authorization', auth)
ngx.req.set_header('Host', config.aws_host)
ngx.req.set_header('x-amz-date', amz_date)

ngx.var.uri      = string.format("https://%s%s", config.host, config.request_path)
