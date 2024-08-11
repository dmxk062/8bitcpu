local M = {}

---@param string string
---@param prefix string
---@return boolean
function M.startswith(string, prefix)
    return string:sub(#prefix) == prefix
end

---@param literal string
---@param range {[1]: integer, [2]: integer}
---@return integer? int
---@return string? err_msg
function M.parse_integer_literal(literal, range)
    local val = nil
    if M.startswith(literal, "0x") or M.startswith(literal, "0b") or M.startswith(literal, "0o") or literal:match("%d+") then
        val = tonumber(literal)
        if not val then
            return nil, "Invalid numeric constant: " .. literal
        elseif val < range[1] or val > range[2] then
            return nil, "Out of range numeric constant: " .. literal .. string.format(", 0x%X not in [0x00, 0xFF]", val)
        end
    else
        local charlit = literal:match("'(.)'")
        if charlit then
            val = tonumber(string.byte(charlit))
        else
            return nil, nil
        end
    end

    return val
end

---@param string string
---@param delim string
---@return string[]
function M.split(string, delim)
    local res = {}
    for part in string.gmatch(string, "([^" .. delim .. "]+)") do
        table.insert(res, part)
    end
    return res
end

---@param line string
---@param endpos integer
---@return string
function M.advance(line, endpos)
    local new = line:sub(endpos):gsub("^%s+", "")
    return new
end

---@param line string
---@return integer? reg
---@return integer? endpos
---@return string? error_msg
function M.get_register(line)
    local r_start, r_end, r_text = line:find("([%w]+)%s?,?")
    if not r_text then
        return nil, nil, nil
    end
    local r1_num = tonumber(r_text:match("r(%d)"))
    if not r1_num or r1_num > 3 then
        return nil, nil, "Invalid register: " .. r_text
    end

    return r1_num, r_end, nil
end

return M
