use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 4) - 1;

my $pwd = cwd();

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_COVERAGE} ||= 0;

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
=== TEST 1: Simple default get.
--- http_config eval: $::HttpConfig
--- config
    location = /a {
        content_by_lua '
            local http = require "sngin.httpclient"
            
            local rsp = http.request({ url = "http://127.0.0.1:" .. ngx.var.server_port .. "/b" })
            ngx.print(rsp.content)
        ';
    }
    location = /b {
        echo "OK";
    }
--- request
GET /a
--- response_body
OK
--- no_error_log
[error]
[warn]

=== TEST 2: Test dns - stub to test real twitter oauth
--- http_config eval: $::HttpConfig
--- config
    location = /a2 {
        content_by_lua '
            local http = require "sngin.httpclient"
            
            CONSUMER_KEY        = ""
            CONSUMER_SECRET     = ""
            ACCESS_TOKEN        = ""
            ACCESS_TOKEN_SECRET = ""
            API_URL             = "https://bogus.twitter.com/1.1/statuses/home_timeline.json"
            local ars = { 
                method = "GET",
                url = API_URL, 
                auth = { 
                    oauth = {
                        consumerkey = CONSUMER_KEY, 
                        consumersecret = CONSUMER_SECRET, 
                        accesstoken = ACCESS_TOKEN, 
                        tokensecret = ACCESS_TOKEN_SECRET
                    }
                }
            }

            local rsp, err = pcall(http.request, ars)
            ngx.say(rsp or err)
        ';
    }
--- request
GET /a2
--- response_body
true
--- error_log
[debug]

=== TEST 3: Simple capture get.
--- http_config eval: $::HttpConfig
--- config
    location = /a {
        content_by_lua '
            local http = require "sngin.httpclient"
            
            local rsp = http.request({ url = "https://niiknow.github.io", use_capture = true })
            ngx.say(rsp.statuscode .. "")
        ';
    }
    location /__capture {
        internal;
        set $clean_url "";
        set_unescape_uri $clean_url $arg_url;
        proxy_pass $clean_url;
    }
--- request
GET /a
--- response_body
200
--- no_error_log
[error]
[warn]


