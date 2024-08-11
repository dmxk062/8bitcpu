#!/usr/bin/luajit

local os = require("os")
local io = require("io")

local isa = require("isa")


USAGE_INFO = [[
Usage: as.lua [OPTION]... FILE
Assemble FILE

Options:
    -o, --output FILE       Write machine code to FILE instead of a.out
    -p, --pack              Zero fill the output
]]

---@param argv string[]
---@return integer
function Main(argv)
    if #argv == 0 then
        print(USAGE_INFO)
        return 1
    end
    local input_file
    local pack = false
    local output_file = "a.out"
    for i = 1, #argv, 1 do
        local param = argv[i]
        if param == "-o" or param == "--output" then
            output_file = argv[i + 1]
            i = i + 1
        elseif param:sub(1, #"--output=") == "--output=" then
            output_file = param:sub(#"--output=" + 1)
        elseif param == "-p" or param == "--pack" then
            pack = true
        else
            input_file = param
        end
    end

    if not input_file then
        print(USAGE_INFO)
        return 1
    end

    local input, err = io.open(input_file, "r")
    if not input then
        print(err)
        return 1
    end
    local output, err = io.open(output_file, "w+b")
    if not output then
        print(err)
        return 1
    end

    local code = input:read("*a")
    local machine_code, errmsg, errline = isa.assemble(code)
    if not machine_code or errmsg then
        print(tostring(errline) .. ": " .. errmsg)
        return 1
    end
    output:write(tostring(machine_code))

    return 0
end

os.exit(Main(arg))
