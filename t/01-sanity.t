use Test::Nginx::Socket;
use Cwd qw(cwd);

plan tests => repeat_each() * 33;

my $pwd = cwd();

$ENV{TEST_LEDGE_REDIS_DATABASE} ||= 1;

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
};

no_long_string();
run_tests();

__DATA__
=== TEST 1: Module loads in init_by_lua
--- http_config eval
"$::HttpConfig"
. q{
    init_by_lua_block {
        local vhost = require("resty.vhost")
        local my_vhost, err = vhost:new(10)
        local ok, err = my_vhost:insert(".example2.com", "example2.com suffix match")
    }
}
--- config
    location /a {
        content_by_lua_block {
            ngx.say("OK")
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
OK

=== TEST 2: Simple match
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost, err = vhost:new(10)
            local ok, err = my_vhost:insert("www.example.com", "www.example.com simple match")
            local val = my_vhost:lookup("www.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
www.example.com simple match

=== TEST 3: Suffix match
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost, err = vhost:new(10)
            local ok, err = my_vhost:insert(".example.com", ".example.com suffix match")
            local val = my_vhost:lookup("foobar.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
.example.com suffix match

=== TEST 4: Simple matches take priority
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost, err = vhost:new(10)
            local ok, err = my_vhost:insert("www.example.com", "www.example.com simple match")
            local ok, err = my_vhost:insert(".example.com", ".example.com suffix match")
            local val = my_vhost:lookup("www.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
www.example.com simple match

=== TEST 5: Simple matches take priority, regardless of order
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost, err = vhost:new(10)
            local ok, err = my_vhost:insert(".example.com", ".example.com suffix match")
            local ok, err = my_vhost:insert("www.example.com", "www.example.com simple match")
            local val = my_vhost:lookup("www.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
www.example.com simple match

=== TEST 6: Suffix matches work alongside absolute matches
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost, err = vhost:new(10)
            local ok, err = my_vhost:insert("www.example.com", "www.example.com simple match")
            local ok, err = my_vhost:insert(".example.com", ".example.com suffix match")
            local val = my_vhost:lookup("foo.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
.example.com suffix match

=== TEST 7: Longest suffix match wins
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost, err = vhost:new(10)
            local ok, err = my_vhost:insert("www.example.com", "www.example.com simple match")
            local ok, err = my_vhost:insert(".example.com", ".example.com suffix match")
            local ok, err = my_vhost:insert(".foo.example.com", ".foo.example.com suffix match")
            local val = my_vhost:lookup("bar.foo.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
.foo.example.com suffix match

=== TEST 8: Suffix entries match apex
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost, err = vhost:new(10)
            local ok, err = my_vhost:insert("www.example.com", "www.example.com simple match")
            local ok, err = my_vhost:insert(".example.com", ".example.com suffix match")
            local val = my_vhost:lookup("example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
.example.com suffix match

=== TEST 9: *. wildcards match
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost, err = vhost:new(10)
            local ok, err = my_vhost:insert("www.example.com", "www.example.com simple match")
            local ok, err = my_vhost:insert("*.example.com", "*.example.com suffix match")
            local val = my_vhost:lookup("sub.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
*.example.com suffix match

=== TEST 10: *. wildcards clash with .wildcards
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost, err = vhost:new(10)
            local ok, err = my_vhost:insert("*.example.com", "*.example.com suffix match")
            local ok, err = my_vhost:insert(".example.com", ".example.com suffix match")
            if not ok then
                ngx.say(err)
            else
                ngx.say("OK")
            end

            local my_vhost, err = vhost:new(10)
            local ok, err = my_vhost:insert(".example.com", ".example.com suffix match")
            local ok, err = my_vhost:insert("*.example.com", "*.example.com suffix match")
            if not ok then
                ngx.say(err)
            else
                ngx.say("OK")
            end
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
key exists
key exists

=== TEST 10: wildcards only work on label boundaries
--- http_config eval
"$::HttpConfig"
. q{

}
--- config
    location /a {
        content_by_lua_block {
            local vhost = require("resty.vhost")
            local my_vhost, err = vhost:new(10)
            local ok, err = my_vhost:insert("www.example.com", "www.example.com simple match")
            local ok, err = my_vhost:insert("*badexample.com", "*badexample.com suffix match")
            local val = my_vhost:lookup("sub.example.com")
            ngx.say(val)
        }
    }
--- request
GET /a
--- no_error_log
[error]
--- response_body
nil
