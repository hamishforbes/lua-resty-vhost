local str_sub = string.sub
local str_find = string.find
local str_rev = string.reverse
local tbl_insert = table.insert
local tbl_concat = table.concat
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

-- Splits domain name by . and adds to nested tables
local function trie_insert(trie, val)
    if val == "" then return end
    if DEBUG then ngx_log(ngx_DEBUG, "Insert: '", val, "'") end
    local pos = str_find(val, ".", 0, true)
    pos = pos or 0
    local first = str_sub(val, 0, pos-1)
    trie[first] = trie[first] or {}
    if first ~= val then
        trie_insert(trie[first], str_sub(val, pos+1))
    end
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

    -- Add reversed string to trie if this is a wildcard key
    if prefix == "." then
        trie_insert(self.trie, str_rev(key))
    end
    return true
end


local function trie_walk(trie, key, ret, tbl_pos)
    tbl_pos = tbl_pos or 1
    local pos = str_find(key, ".", 0, true)
    pos = pos or 0
    local first = str_sub(key, 0, pos-1)

    if first ~= "" and trie[first] then
        if DEBUG then ngx_log(ngx_DEBUG, "found ", first) end
        ret[tbl_pos] = first
        ret[tbl_pos+1] = "."
        tbl_pos = trie_walk(trie[first], str_sub(key, pos+1), ret, tbl_pos+2)
    end
    return tbl_pos
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

    -- Search the wildcard trie
    if DEBUG then ngx_log(ngx_DEBUG, "Searching: ", key) end
    local match = {}
    local tbl_pos = trie_walk(self.trie, str_rev(key), match)

    -- Partial matches don't count
    local len = tbl_pos -1
    if len == 0 or match[len] ~= "." then
        if DEBUG then ngx_log(ngx_DEBUG, "Partial match: ", str_rev(tbl_concat(match, ""))) end
        return nil
    end

    -- Convert back to a string and return the value
    match = str_rev(tbl_concat(match, ""))
    if DEBUG then ngx_log(ngx_DEBUG, "Found: ", match) end
    return self.map[match]
end

return _M

