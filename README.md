# lua-resty-vhost

Library for matching hostnames to values.
Supports wildcard and `.hostname.tld` syntax in the same way as Nginx's [server_name](http://nginx.org/en/docs/http/ngx_http_core_module.html#server_name) directive.

Keys beginning with `.` or `*.` will match apex and all sub-domains, longest match wins. Non-wildcard matches always win.

Regex matches and prefix wildcards are not supported.

# Overview

```
lua_package_path "/path/to/lua-resty-vhost/lib/?.lua;;";

init_by_lua_block {
    local vhost = require("resty.vhost")
    my_vhost = vhost:new()
    local ok, err = my_vhost:insert("example.com",      { key = "example.com.key",          cert = "example.com.crt" })
    local ok, err = my_vhost:insert("www.example.com",  { key = "example.com.key",          cert = "example.com.crt" })
    local ok, err = my_vhost:insert(".sub.example.com", { key = "star.sub.example.com.key", cert = "star.sub.example.com.crt" })
    local ok, err = my_vhost:insert("www.example2.com", { key = "www.example2.com.key",     cert = "www.example2.com.crt" })
}

server {
    listen 80 default_server;
    listen 443 ssl default_server;
    server_name vhost;

    ssl_certificate         /path/to/default/cert.crt;
    ssl_certificate_key     /path/to/default/key.crt;

    ssl_certificate_by_lua_block {
        local val, err = my_vhost:lookup(require("ngx.ssl").server_name())
        if not val then
            ngx.log(ngx.ERR, err)
        else
            ngx.log(ngx.DEBUG, "Match, setting certs: ", val.cert, " ", val.key)
            -- set_certs_somehow(val)
        end
    }

    location / {
        content_by_lua_block {
            local val, err = my_vhost:lookup(ngx.var.host)
            if val then
                -- do something based on val
                ngx.say("Matched: ", val.cert)
            else
                if err then
                    ngx.log(ngx.ERR, err)
                end
                ngx.exit(404)
            end
        }
    }
}
```

# Methods
### new
`syntax: my_vhost, err = vhost:new(size?)`

Creates a new instance of resty-vhost with an optional initial size

### insert
`syntax: ok, err = my_vhost:insert(key, value)`

Adds a new hostname key with associated value.

Keys must be strings.

Returns false and an error message on failure.

### lookup
`syntax: val, err = my_vhost:lookup(hostname)`

Retrieves value for best matching hostname entry.

Returns nil and an error message on failure

## TODO
 * Regex matches
 * Prefix matches
 * Trie compression
