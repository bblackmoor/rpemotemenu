local _, addon = ...

local JSON = {}
addon.JSON = JSON

local ARRAY_METATABLE = {}
local NULL = {}
local MAX_DEPTH = 32

JSON.Null = NULL

function JSON.Array(values)
    return setmetatable(values or {}, ARRAY_METATABLE)
end

function JSON.IsArray(value)
    return type(value) == "table" and getmetatable(value) == ARRAY_METATABLE
end

local ESCAPED_CHARACTERS = {
    ['"'] = '\\"',
    ["\\"] = "\\\\",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t"
}

local function EncodeString(value)
    return '"' .. value:gsub('[%z\1-\31\\"]', function(character)
        return ESCAPED_CHARACTERS[character]
            or string.format("\\u%04x", string.byte(character))
    end) .. '"'
end

local function EncodeValue(value, pretty, depth, ancestors)
    if depth > MAX_DEPTH then
        error("JSON exceeds the maximum nesting depth.", 0)
    end

    local valueType = type(value)

    if value == NULL then
        return "null"
    elseif valueType == "string" then
        return EncodeString(value)
    elseif valueType == "boolean" then
        return tostring(value)
    elseif valueType == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            error("JSON cannot represent non-finite numbers.", 0)
        end

        return string.format("%.17g", value)
    elseif valueType ~= "table" then
        error("JSON cannot represent " .. valueType .. " values.", 0)
    end

    if ancestors[value] then
        error("JSON cannot contain circular references.", 0)
    end

    ancestors[value] = true

    local isArray = JSON.IsArray(value)
    local keys = {}

    if not isArray then
        for key in pairs(value) do
            if type(key) == "number" then
                isArray = true
                break
            end
        end
    end

    local pieces = {}
    local childIndent = pretty and string.rep("  ", depth + 1) or ""
    local separator = pretty and ",\n" or ","

    if isArray then
        local count = #value

        for key in pairs(value) do
            if type(key) ~= "number" or key < 1 or key > count or key % 1 ~= 0 then
                error("JSON arrays must have consecutive integer indexes.", 0)
            end
        end

        for index = 1, count do
            pieces[index] = childIndent .. EncodeValue(value[index], pretty, depth + 1, ancestors)
        end
    else
        for key in pairs(value) do
            if type(key) ~= "string" then
                error("JSON object keys must be strings.", 0)
            end

            keys[#keys + 1] = key
        end

        table.sort(keys)

        for index, key in ipairs(keys) do
            pieces[index] = childIndent
                .. EncodeString(key)
                .. (pretty and ": " or ":")
                .. EncodeValue(value[key], pretty, depth + 1, ancestors)
        end
    end

    ancestors[value] = nil

    local opening = isArray and "[" or "{"
    local closing = isArray and "]" or "}"

    if #pieces == 0 then
        return opening .. closing
    end

    if pretty then
        return opening .. "\n" .. table.concat(pieces, separator)
            .. "\n" .. string.rep("  ", depth) .. closing
    end

    return opening .. table.concat(pieces, separator) .. closing
end

function JSON.Encode(value, pretty)
    local success, result = pcall(EncodeValue, value, pretty == true, 0, {})
    if not success then
        return nil, result
    end

    return result
end

local UNESCAPED_CHARACTERS = {
    ['"'] = '"',
    ["\\"] = "\\",
    ["/"] = "/",
    b = "\b",
    f = "\f",
    n = "\n",
    r = "\r",
    t = "\t"
}

local function EncodeCodepoint(codepoint)
    if codepoint <= 0x7F then
        return string.char(codepoint)
    elseif codepoint <= 0x7FF then
        return string.char(
            0xC0 + math.floor(codepoint / 0x40),
            0x80 + codepoint % 0x40
        )
    elseif codepoint <= 0xFFFF then
        return string.char(
            0xE0 + math.floor(codepoint / 0x1000),
            0x80 + math.floor(codepoint / 0x40) % 0x40,
            0x80 + codepoint % 0x40
        )
    end

    return string.char(
        0xF0 + math.floor(codepoint / 0x40000),
        0x80 + math.floor(codepoint / 0x1000) % 0x40,
        0x80 + math.floor(codepoint / 0x40) % 0x40,
        0x80 + codepoint % 0x40
    )
end

function JSON.Decode(text)
    if type(text) ~= "string" then
        return nil, "JSON input must be a string."
    end

    local position = 1
    local length = #text

    local function Fail(message)
        error(message .. " at character " .. position .. ".", 0)
    end

    local function SkipWhitespace()
        while position <= length and text:sub(position, position):match("^[ \t\r\n]$") do
            position = position + 1
        end
    end

    local function ParseString()
        position = position + 1
        local pieces = {}

        while position <= length do
            local character = text:sub(position, position)

            if character == '"' then
                position = position + 1
                return table.concat(pieces)
            elseif character == "\\" then
                position = position + 1
                local escaped = text:sub(position, position)

                if escaped == "u" then
                    local digits = text:sub(position + 1, position + 4)
                    if not digits:match("^%x%x%x%x$") then
                        Fail("Invalid Unicode escape")
                    end

                    local codepoint = tonumber(digits, 16)
                    position = position + 5

                    if codepoint >= 0xD800 and codepoint <= 0xDBFF then
                        if text:sub(position, position + 1) ~= "\\u" then
                            Fail("A Unicode high surrogate requires a low surrogate")
                        end

                        local lowDigits = text:sub(position + 2, position + 5)
                        if not lowDigits:match("^%x%x%x%x$") then
                            Fail("Invalid Unicode low surrogate")
                        end

                        local lowSurrogate = tonumber(lowDigits, 16)
                        if lowSurrogate < 0xDC00 or lowSurrogate > 0xDFFF then
                            Fail("Invalid Unicode low surrogate")
                        end

                        codepoint = 0x10000
                            + (codepoint - 0xD800) * 0x400
                            + (lowSurrogate - 0xDC00)
                        position = position + 6
                    elseif codepoint >= 0xDC00 and codepoint <= 0xDFFF then
                        Fail("A Unicode low surrogate requires a high surrogate")
                    end

                    pieces[#pieces + 1] = EncodeCodepoint(codepoint)
                else
                    local unescaped = UNESCAPED_CHARACTERS[escaped]
                    if not unescaped then
                        Fail("Invalid string escape")
                    end

                    pieces[#pieces + 1] = unescaped
                    position = position + 1
                end
            else
                if string.byte(character) < 32 then
                    Fail("Unescaped control character in string")
                end

                pieces[#pieces + 1] = character
                position = position + 1
            end
        end

        Fail("Unterminated string")
    end

    local ParseValue

    local function ParseArray(depth)
        position = position + 1
        SkipWhitespace()
        local values = JSON.Array()

        if text:sub(position, position) == "]" then
            position = position + 1
            return values
        end

        while true do
            values[#values + 1] = ParseValue(depth + 1)
            SkipWhitespace()

            local delimiter = text:sub(position, position)
            position = position + 1

            if delimiter == "]" then
                return values
            elseif delimiter ~= "," then
                Fail("Expected ',' or ']' in array")
            end

            SkipWhitespace()
        end
    end

    local function ParseObject(depth)
        position = position + 1
        SkipWhitespace()
        local values = {}

        if text:sub(position, position) == "}" then
            position = position + 1
            return values
        end

        while true do
            if text:sub(position, position) ~= '"' then
                Fail("Expected a quoted object key")
            end

            local key = ParseString()
            if values[key] ~= nil then
                Fail("Duplicate object key " .. EncodeString(key))
            end

            SkipWhitespace()
            if text:sub(position, position) ~= ":" then
                Fail("Expected ':' after an object key")
            end

            position = position + 1
            values[key] = ParseValue(depth + 1)
            SkipWhitespace()

            local delimiter = text:sub(position, position)
            position = position + 1

            if delimiter == "}" then
                return values
            elseif delimiter ~= "," then
                Fail("Expected ',' or '}' in object")
            end

            SkipWhitespace()
        end
    end

    local function ParseNumber()
        local start = position

        if text:sub(position, position) == "-" then
            position = position + 1
        end

        local first = text:sub(position, position)
        if first == "0" then
            position = position + 1
            if text:sub(position, position):match("^%d$") then
                Fail("JSON numbers cannot contain leading zeroes")
            end
        elseif first:match("^[1-9]$") then
            repeat
                position = position + 1
            until not text:sub(position, position):match("^%d$")
        else
            Fail("Invalid JSON number")
        end

        if text:sub(position, position) == "." then
            position = position + 1
            if not text:sub(position, position):match("^%d$") then
                Fail("A decimal point must be followed by a digit")
            end

            repeat
                position = position + 1
            until not text:sub(position, position):match("^%d$")
        end

        local exponent = text:sub(position, position)
        if exponent == "e" or exponent == "E" then
            position = position + 1
            local sign = text:sub(position, position)
            if sign == "+" or sign == "-" then
                position = position + 1
            end

            if not text:sub(position, position):match("^%d$") then
                Fail("An exponent must contain a digit")
            end

            repeat
                position = position + 1
            until not text:sub(position, position):match("^%d$")
        end

        local value = tonumber(text:sub(start, position - 1))
        if not value or value ~= value or value == math.huge or value == -math.huge then
            Fail("JSON number is outside the supported range")
        end

        return value
    end

    ParseValue = function(depth)
        if depth > MAX_DEPTH then
            Fail("JSON exceeds the maximum nesting depth")
        end

        SkipWhitespace()
        local character = text:sub(position, position)

        if character == '"' then
            return ParseString()
        elseif character == "{" then
            return ParseObject(depth)
        elseif character == "[" then
            return ParseArray(depth)
        elseif character == "-" or character:match("^%d$") then
            return ParseNumber()
        elseif text:sub(position, position + 3) == "true" then
            position = position + 4
            return true
        elseif text:sub(position, position + 4) == "false" then
            position = position + 5
            return false
        elseif text:sub(position, position + 3) == "null" then
            position = position + 4
            return NULL
        end

        Fail("Unexpected JSON value")
    end

    local success, result = pcall(function()
        local value = ParseValue(0)
        SkipWhitespace()

        if position <= length then
            Fail("Unexpected characters after the JSON value")
        end

        return value
    end)

    if not success then
        return nil, result
    end

    return result
end
