local str_sub = string.sub
local str_find = string.find
local ngx_log = ngx.log
local ngx_DEBUG = ngx.DEBUG
local ngx_ERR = ngx.ERR
local ngx_INFO = ngx.INFO


local ok, tab_new = pcall(require, "table.new")
if not ok then
    tab_new = function (narr, nrec) return {} end
end

local _M = {
    _VERSION = "0.01",
}
local mt = { __index = _M }

local DEBUG = false
function _M._debug(debug)
    DEBUG = debug
end

function _M.new(_, size)
    size = size or 10
    local self = {
        trie = tab_new(0, size),
        map = tab_new(0, size)
    }

    return setmetatable(self, mt)
end

function _M.insert(self, key, val)
    if not key or type(key) ~= "string" then
        return nil, "invalid key"
    end

    -- "*.example.com" is equivalent to ".example.com"
    local prefix = str_sub(key, 1, 1)
    if prefix == '*' then
        key = str_sub(key, 2, -1)
        prefix = str_sub(key, 1, 1)
        if prefix ~= "." then
            return false, "wildcards must be on label boundary"
        end
    end

    -- Cannot have duplicate entries
    local map = self.map
    if map[key] then
        return false, "key exists"
    end

    -- Add to basic map
    map[key] = val

    return true
end

function _M.lookup(self, key)
    if not key or type(key) ~= "string" then
        return nil, "invalid key"
    end

    -- Attempt to match full string first
    local match = self.map[key]
    if match then
        return match
    end

    -- Search the wildcard patten
    if DEBUG then ngx_log(ngx_DEBUG, "Searching: ", key) end
    match = self.map["." .. key]
    if match then
        return match
    end
    local pos = 1
    while true do
        pos = str_find(key, ".", pos+1, true)
        if not pos then
            break
        end
        local parent = str_sub(key, pos)
        match = self.map[parent]
        if match then
            return match
        end
    end

    return nil
end

return _M

