local M = {}

local bit = require("bit")
local ffi = require("ffi")
local strbuf = require("string.buffer")

---@alias instkind "none"|"short"|"dual"|"long"
---@alias register 0|1|2|3

---@class opspec
---@field kind instkind
---@field code integer
---@field noreg boolean?

---@type opspec[]
M.instructions = {
    ["noop"] = { kind = "none", code = 0x00, noreg = true },

    -- memory and register access
    ["st"]   = { kind = "long", code = 0x01 },
    ["str"]  = { kind = "dual", code = 0x02 },
    ["ld"]   = { kind = "long", code = 0x03 },
    ["ldr"]  = { kind = "dual", code = 0x04 },
    ["li"]   = { kind = "long", code = 0x05 },
    ["cp"]   = { kind = "dual", code = 0x06 },

    -- math
    ["sub"]  = { kind = "dual", code = 0x08 },
    ["add"]  = { kind = "dual", code = 0x09 },
    ["subi"] = { kind = "long", code = 0x0a },
    ["addi"] = { kind = "long", code = 0x0b },
    ["clc"]  = { kind = "none", code = 0x0c, noreg = true },
    ["cli"]  = { kind = "none", code = 0x0d, noreg = true },
    ["cln"]  = { kind = "none", code = 0x0e, noreg = true },

    -- bitwise logic
    ["and"]  = { kind = "dual", code = 0x10 },
    ["or"]   = { kind = "dual", code = 0x11 },
    ["xor"]  = { kind = "dual", code = 0x12 },
    ["not"]  = { kind = "short", code = 0x13 },
    ["shl"]  = { kind = "short", code = 0x14 },
    ["shr"]  = { kind = "short", code = 0x15 },
    ["andi"] = { kind = "long", code = 0x18 },
    ["ori"]  = { kind = "long", code = 0x19 },
    ["xori"] = { kind = "long", code = 0x1a },

    -- control flow
    ["jmp"]  = { kind = "long", code = 0x20, noreg = true },
    ["jiz"]  = { kind = "long", code = 0x21 },
    ["jnz"]  = { kind = "long", code = 0x22 },
    ["jic"]  = { kind = "long", code = 0x23, noreg = true },
    ["jnc"]  = { kind = "long", code = 0x24, noreg = true },
    ["jii"]  = { kind = "long", code = 0x25, noreg = true },
    ["jni"]  = { kind = "long", code = 0x26, noreg = true },
    ["jmr"]  = { kind = "short", code = 0x27 },

    -- meta
    ["ldpr"] = { kind = "short", code = 0x28 },
    ["ldfl"] = { kind = "short", code = 0x29 },
    ["stfl"] = { kind = "short", code = 0x2a },

    -- I/O
    ["rd"]   = { kind = "short", code = 0x39 },
    ["wr"]   = { kind = "short", code = 0x3a },

}

ffi.cdef [[
typedef struct {
    uint8_t opcode;
    uint8_t data;
} __attribute__((packed)) instruction;
]]
local lshift, rshift = bit.lshift, bit.rshift

---@param table table
---@param key string
---@return boolean
local function contains(table, key)
    for k, v in pairs(table) do
        if k == key then
            return true
        end
    end
    return false
end

---@param string string
---@param prefix string
---@return boolean
local function startswith(string, prefix)
    return string:sub(#prefix) == prefix
end


---@class instruction
---@field kind instkind
---@field opcode integer
---@field reg1 register?
---@field reg2 register?
---@field data integer?

---@param inst instruction
local function encode(inst)
    local opcode = lshift(inst.opcode, 2) + (inst.reg1 or 0)
    local data
    if inst.kind == "none" or inst.kind == "short" then
        data = 0x00
    elseif inst.kind == "dual" then
        data = inst.reg2
    else
        data = inst.data
    end

    return ffi.new("instruction", { data = data, opcode = opcode })
end

---@param line string
---@param endpos integer
---@return string
local function advance(line, endpos)
    local new = line:sub(endpos):gsub("^%s+", "")
    return new
end

---@param line string
---@return integer? reg
---@return integer? endpos
---@return string? error_msg
local function get_register(line)
    local r_start, r_end, r_text = line:find("^%s?([%w]+)%s?,?")
    if not r_text then
        return nil, nil, nil
    end
    local r1_num = tonumber(r_text:match("r(%d)"))
    if not r1_num or r1_num > 3 then
        return nil, nil, "Invalid register: " .. r_text
    end

    return r1_num, r_end, nil
end

---@class synobj
---@field kind "instruction"|"label"
---@field linenr integer
---@field mnemonic string?
---@field label string?
---@field reg1 register?
---@field reg2 register?
---@field data integer?
---@field datatype "label"|"int"

---@param _line string
---@return synobj?
---@return string? error_msg
---@return boolean? skip
local function parse_line(_line)
    -- remove leading indent and comments
    local line = _line:gsub("^%s+", ""):gsub(";.*", "")
    if line == "" then
        return nil, nil, true
    end

    local label_match = line:match("^([%w_]+):")
    if label_match then
        return {
            label = label_match,
            kind  = "label"
        }
    end

    local mn_start, mn_end, mn_text = line:find("^([%w]+)%s?")
    ---@TODO more robust error handling
    if not mn_text then
        return nil, nil, true
    end

    if not contains(M.instructions, mn_text) then
        return nil, "Unknown mnemonic: " .. mn_text, false
    end

    line = advance(line, mn_end)
    local inst = M.instructions[mn_text]

    -- get first register
    local r1, r2, data, datatype = nil, nil, nil, nil
    if not (inst.kind == "none" or (inst.kind == "long" and inst.noreg)) then
        local r, r1_end, error_msg = get_register(line)
        if not r then
            if not error_msg then
                return nil, "Missing r1 for " .. inst.kind .. " " .. mn_text, nil
            end
            return nil, error_msg, nil
        end
        r1 = r
        line = advance(line, r1_end)
    end

    -- get second register
    if inst.kind == "dual" then
        local r, r2_end, error_msg = get_register(line)
        if not r then
            if not error_msg then
                return nil, "Missing r2 for " .. inst.kind .. " " .. mn_text, nil
            end
            return nil, error_msg, nil
        end
        r2 = r
        line = advance(line, r2_end)
    end

    -- get additional data
    if inst.kind == "long" then
        local param = line:match(",?%s?([%w_]+)$")
        if not param then
            return nil, "Missing param for " .. inst.kind .. " " .. mn_text, nil
        end
        local val = nil
        if startswith(param, "0x") or startswith(param, "0b") or startswith(param, "0o") or param:match("%d+") then
            val = tonumber(param)
            if not val then
                return nil, "Invalid numeric constant: " .. param, nil
            elseif val < 0 or val > 256 then
                return nil, "Out of range numeric constant: " .. param .. string.format(", 0x%X not in [0x00, 0xFF]", val), nil
            end
            datatype = "int"
            data = val
        else
            datatype = "label"
            data = param
        end
    end

    return {
        kind = "instruction",
        mnemonic = mn_text,
        reg1 = r1,
        reg2 = r2,
        data = data,
        datatype = datatype,
    }
end

---parse code
---@param code string
---@return synobj? code
---@return string? error_msg
---@return integer? error_line
local function parse_code(code)
    local lines = {}
    for line in code:gmatch("([^\n]+)") do
        table.insert(lines, line)
    end

    local syntax = {}
    for index = 1, #lines do
        local line = lines[index]
        local syn, error_msg, skip = parse_line(line)
        if skip then
        elseif error_msg and not skip then
            return nil, error_msg, index
        else
            syn.linenr = index
            table.insert(syntax, syn)
        end

    end

    return syntax
end

---assemble and link code
---@param code string
---@return string.buffer? machine_code
---@return string? error_msg
---@return integer? error_line
function M.assemble(code)
    local syns, error_msg, error_line = parse_code(code)
    if not syns or error_msg then
        return nil, error_msg, error_line
    end

    local symbol_table = {}
    local instr_index = 0 -- codepoint
    local was_label = false

    local labels = {}
    local statements = {}

    -- link *first*
    for synindex = 1, #syns do
        local obj = syns[synindex]
        if obj.kind == "label" then
            while syns[synindex].kind == "label" do
                table.insert(labels, syns[synindex].label)
                synindex = synindex + 1
            end
            was_label = true
        else
            if was_label then
                for _, label in ipairs(labels) do
                    symbol_table[label] = instr_index
                end
                labels = {}
            end
            table.insert(statements, obj)
            instr_index = instr_index + 1
        end
    end
    if #statements > 256 then
        return nil, string.format("Too many operations (0x%X > 0xFF)", #statements), 0
    end

    -- assemble, finally
    local machine_code = ffi.new("instruction[?]", #statements, {})
    local codepoint = 0
    for i, st in pairs(statements) do
        local data
        if st.datatype == "label" then
            data = symbol_table[st.data]
            if not data then
                return nil, "Undefined symbol: " .. st.data, st.linenr
            end
        else
            data = st.data
        end

        local instruction = encode {
            kind = st.kind,
            data = data,
            reg1 = st.reg1,
            reg2 = st.reg2,
            opcode = M.instructions[st.mnemonic].code
        }
        machine_code[codepoint] = instruction
        codepoint = codepoint + 1
    end

    for i = 0, codepoint - 1 do
        print(machine_code[i].opcode)
    end
    local buf = strbuf.new(512)
    buf:putcdata(machine_code, codepoint + 4)

    return buf, nil, nil

end

return M
