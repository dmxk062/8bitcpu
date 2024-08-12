local M = {}

M.data_count = 256
M.code_count = 256

local bit = require("bit")
local ffi = require("ffi")
local strbuf = require("string.buffer")
local parser = require("parser")

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
        data = lshift(inst.reg2, 6)
    else
        data = inst.data
    end

    return ffi.new("instruction", { data = data, opcode = opcode })
end


---@class initdata
---@field size integer
---@field initial integer[]
---@field do_init boolean

---@class synobj
---@field kind "instruction"|"label"|"data"
---@field linenr integer
---@field static initdata
---@field mnemonic string?
---@field label string?
---@field reg1 register?
---@field reg2 register?
---@field data integer?
---@field datatype "label"|"int"

local function get_str_literal(str)
    local acc = {}
    for i = 1, #str do
        acc[i] = string.byte(str, i)
    end
    return acc
end

M.data_specs = {
    ---c style string(null terminated)
    ---@param line string
    ["zstr"] = function(line)
        local quoted_string = line:gsub("\\n", "\n"):match([["([^"]+)"]])
        if not quoted_string then
            return nil, nil, "Not a valid string literal: " .. line
        end
        local bytes = get_str_literal(quoted_string)
        table.insert(bytes, 0)
        return bytes, #bytes
    end,

    ---@param line string
    ["bytes"] = function(line)
        local size_start, size_end, size_txt = line:find("(%w+)")
        local parsed_size, error_msg = parser.parse_integer_literal(size_txt, {0, 255})
        if not parsed_size and error_msg then
            return nil, nil, error_msg
        end
        line = parser.advance(line, size_end+1)
        if line == "" then
            return nil, parsed_size
        end
        local values = parser.split(line, ",")
        local numbers = {}
        for _, value in pairs(values) do
            local val, error_msg = parser.parse_integer_literal(value, {0, 255})
            if not val then
                return nil, nil, error_msg or ("Not a bytes literal: " .. value)
            end
            table.insert(numbers, val)
        end

        -- if we get less than count, fill with last element
        if parsed_size > #numbers then
            local last = numbers[#numbers]
            for i = #numbers, parsed_size - 1 do
                table.insert(numbers, i, last)
            end
        end

        return numbers, (parsed_size > #numbers and parsed_size or #numbers)
    end,

    ---@param line string
    ["byte"] = function(line)
        local val, error_msg = parser.parse_integer_literal(line, {0, 255})
        if not val and error_msg then
            return nil, nil, error_msg
        end
    end
}

---@param line string
---@return string? label
---@return initdata?
---@return string? error_msg
local function parse_data_line(line)
    local spec_start, spec_end, spec_txt = line:find("^.([%w]+)")
    if not contains(M.data_specs, spec_txt) then
        return nil, nil, "No such data type: " .. spec_txt
    end
    line = parser.advance(line, spec_end + 1)

    local label_start, label_end, label_txt = line:find("^([%w_]+)")
    if not label_txt then
        return nil, nil, "Missing label in initializer"
    end
    line = parser.advance(line, label_end + 1)

    local val, size, error_msg = M.data_specs[spec_txt](line)
    if not val and error_msg then
        return nil, nil, error_msg
    end

    return label_txt, {
        size = size,
        initial = val,
    }
end


---@param _line string
---@return synobj?
---@return string? error_msg
---@return boolean? skip
local function parse_code_line(_line)
    -- remove leading indent and comments
    local line = _line:gsub("^%s+", ""):gsub(";.*", "")
    if line == "" then
        return nil, nil, true
    end

    local label_match = line:match("^([%w_]+):")
    -- line is a label
    if label_match then
        return {
            label = label_match,
            kind  = "label"
        }
    end

    -- line is a data definition
    if line:sub(1, 1) == "." then
        local label, val, error_msg = parse_data_line(line)
        if not label and error_msg then
            return nil, error_msg, nil
        end
        return {
            kind = "data",
            label = label,
            static = val,
        }
    end

    local mn_start, mn_end, mn_text = line:find("^,?%s?([%w]+)%s?")
    ---@TODO more robust error handling
    if not mn_text then
        return nil, nil, true
    end

    if not contains(M.instructions, mn_text) then
        return nil, "Unknown mnemonic: " .. mn_text, false
    end

    line = parser.advance(line, mn_end)
    local inst = M.instructions[mn_text]

    -- get first register
    local r1, r2, data, datatype = nil, nil, nil, nil
    if not (inst.kind == "none" or (inst.kind == "long" and inst.noreg)) then
        local r, r1_end, error_msg = parser.get_register(line)
        if not r then
            if not error_msg then
                return nil, "Missing r1 for " .. inst.kind .. " " .. mn_text, nil
            end
            return nil, error_msg, nil
        end
        r1 = r
        line = parser.advance(line, r1_end)
    end

    -- get second register
    if inst.kind == "dual" then
        local r, r2_end, error_msg = parser.get_register(line)
        if not r then
            if not error_msg then
                return nil, "Missing r2 for " .. inst.kind .. " " .. mn_text, nil
            end
            return nil, error_msg, nil
        end
        r2 = r
        line = parser.advance(line, r2_end)
    end

    -- get additional data
    if inst.kind == "long" then
        local param = line:match(",?%s?([%w_']+)$")
        if not param then
            return nil, "Missing param for " .. inst.kind .. " " .. mn_text, nil
        end
        datatype = "int"
        local val, error_msg = parser.parse_integer_literal(param, { 0, 255 })
        if not val and error_msg then
            return nil, error_msg, nil
        end
        if not val and not error_msg then
            val = param
            datatype = "label"
        end
        data = val
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
        if parser.startswith(line, ".data") then
            break
        end
        local syn, error_msg, skip = parse_code_line(line)
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
    local memory_index = 0
    local memory_image = ffi.new("uint8_t[?]", M.data_count)

    -- link *first*
    for synindex = 1, #syns do
        local obj = syns[synindex]
        if obj.kind == "label" then
            while syns[synindex].kind == "label" do
                table.insert(labels, syns[synindex].label)
                synindex = synindex + 1
            end
            was_label = true
        elseif obj.kind == "data" then
            if obj.static.size > M.data_count then
                return nil, string.format("Static object too large: %s (0x%X > 0xFF)", obj.label, obj.static.size), obj.linenr
            end
            if obj.static.size + memory_index > M.data_count then
                return nil, "Memory overflow: not enough space left", obj.linenr
            end
            if obj.static.initial then
                local bytearray = ffi.new("uint8_t[?]", obj.static.size, obj.static.initial)
                ffi.copy(memory_image + memory_index, bytearray, obj.static.size)
            end
            symbol_table[obj.label] = memory_index
            memory_index = memory_index + obj.static.size
        elseif obj.kind == "instruction" then
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
    local machine_code = ffi.new("instruction[?]", M.code_count * 2)
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
            kind = M.instructions[st.mnemonic].kind,
            data = data,
            reg1 = st.reg1,
            reg2 = st.reg2,
            opcode = M.instructions[st.mnemonic].code
        }
        machine_code[codepoint] = instruction
        codepoint = codepoint + 1
    end

    local buf = strbuf.new(M.code_count * 2 + M.data_count)
    buf:putcdata(machine_code, M.code_count * 2)
    buf:putcdata(memory_image, M.data_count)

    return buf, nil, nil
end

return M
