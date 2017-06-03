use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * (blocks() * 4);

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
=== TEST 1: github require
--- http_config eval: $::HttpConfig
--- config
    location = /a {
        content_by_lua '
            local ngin = require "sngin.ngin"
            
            local rsp = ngin.require_new("github.com/anvaka/redis-load-scripts/test/scripts/nested/main.lua")
            ngx.say(rsp)
        ';
    }
    location /__githubraw {
        internal;
        set $clean_url "";
        set_unescape_uri $clean_url $arg_url;
        proxy_pass $clean_url;
    }
--- request
GET /a
--- response_body
Hello World

--- no_error_log
[error]
[warn]

