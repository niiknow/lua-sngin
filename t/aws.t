use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 4);

my $pwd = cwd();

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_COVERAGE} ||= 0;
$ENV{SNGIN_APP_PATH} = 't/servroot/html';

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;/usr/local/share/lua/5.1/?.lua;;";
    error_log logs/error.log debug;

    init_by_lua_block {
        if $ENV{TEST_COVERAGE} == 1 then
            jit.off()
            require("luacov.runner").init()
        end
    }

    resolver $ENV{TEST_NGINX_RESOLVER};
};

no_long_string();

run_tests();

__DATA__
=== TEST 1: aws s3 file
--- main_config
    env AWS_ACCESS_KEY_ID;
    env AWS_SECRET_ACCESS_KEY;
    env AWS_S3_CODE_PATH;
    env SNGIN_APP_PATH;

--- http_config eval: $::HttpConfig
--- config
    location = /a {
        content_by_lua '
            local router = require "sngin.router"
            router.init()
        ';
    }    

    location /__code {
        internal;
        set $clean_url "";
        set_unescape_uri $clean_url $arg_url;
        proxy_pass $clean_url;

        
        # Make connection to S3 using HTTP/1.1
        proxy_http_version 1.1;
    }
--- request
GET /a
--- response_body
Hello from S3
--- no_error_log
[error]
[warn]

