-- Text.lua
-- Text formatting utilities

local FenCore = _G.FenCore
local Math = FenCore.Math
local Catalog = FenCore.Catalog

local Text = {}

--- Truncate string with suffix.
---@param str string String to truncate
---@param maxLen number Maximum length
---@param suffix? string Suffix to add (default "...")
---@return string Truncated string
function Text.Truncate(str, maxLen, suffix)
    if str == nil then return "" end
    if maxLen == nil or maxLen <= 0 then return str end

    suffix = suffix or "..."

    if #str <= maxLen then
        return str
    end

    local truncLen = maxLen - #suffix
    if truncLen <= 0 then
        return suffix:sub(1, maxLen)
    end

    return str:sub(1, truncLen) .. suffix
end

--- Pluralize a word based on count.
---@param count number The count
---@param singular string Singular form
---@param plural? string Plural form (default: singular + "s")
---@return string Pluralized phrase
function Text.Pluralize(count, singular, plural)
    count = count or 0
    plural = plural or (singular .. "s")

    if count == 1 then
        return count .. " " .. singular
    else
        return count .. " " .. plural
    end
end

--- Format number with thousands separators.
---@param n number Number to format
---@param decimals? number Decimal places (default 0)
---@param sep? string Thousands separator (default ",")
---@return string Formatted number
function Text.FormatNumber(n, decimals, sep)
    if n == nil then return "0" end

    decimals = decimals or 0
    sep = sep or ","

    -- Round to specified decimals
    local mult = 10 ^ decimals
    n = math.floor(n * mult + 0.5) / mult

    -- Split integer and decimal parts
    local int, dec = math.modf(n)
    int = math.abs(int)

    -- Format integer with separators
    local formatted = tostring(int)
    local pos = #formatted % 3
    if pos == 0 then pos = 3 end

    local parts = {}
    table.insert(parts, formatted:sub(1, pos))
    for i = pos + 1, #formatted, 3 do
        table.insert(parts, formatted:sub(i, i + 2))
    end

    local result = table.concat(parts, sep)

    -- Add decimal part
    if decimals > 0 then
        dec = math.abs(dec)
        local decStr = string.format("%." .. decimals .. "f", dec):sub(2)
        result = result .. decStr
    end

    -- Add negative sign
    if n < 0 then
        result = "-" .. result
    end

    return result
end

--- Format number in compact form (1K, 1.2M, etc).
---@param n number Number to format
---@param decimals? number Decimal places (default 1)
---@return string Compact number
function Text.FormatCompact(n, decimals)
    if n == nil then return "0" end

    decimals = decimals or 1

    local absN = math.abs(n)
    local suffix = ""
    local divisor = 1

    if absN >= 1e12 then
        suffix = "T"
        divisor = 1e12
    elseif absN >= 1e9 then
        suffix = "B"
        divisor = 1e9
    elseif absN >= 1e6 then
        suffix = "M"
        divisor = 1e6
    elseif absN >= 1e3 then
        suffix = "K"
        divisor = 1e3
    end

    if divisor > 1 then
        local value = n / divisor
        return string.format("%." .. decimals .. "f", value) .. suffix
    end

    return tostring(math.floor(n))
end

--- Capitalize first letter of string.
---@param str string String to capitalize
---@return string Capitalized string
function Text.Capitalize(str)
    if str == nil or #str == 0 then return "" end
    return str:sub(1, 1):upper() .. str:sub(2):lower()
end

--- Capitalize first letter of each word.
---@param str string String to title case
---@return string Title cased string
function Text.TitleCase(str)
    if str == nil or #str == 0 then return "" end
    return str:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

--- Pad string to length.
---@param str string String to pad
---@param len number Target length
---@param char? string Padding character (default " ")
---@param right? boolean Pad on right side (default left)
---@return string Padded string
function Text.Pad(str, len, char, right)
    if str == nil then str = "" end
    char = char or " "
    len = len or 0

    local padding = len - #str
    if padding <= 0 then return str end

    local pad = string.rep(char, padding)
    if right then
        return str .. pad
    else
        return pad .. str
    end
end

--- Strip WoW color codes from string.
---@param str string String with color codes
---@return string Clean string
function Text.StripColors(str)
    if str == nil then return "" end
    -- Remove |c and |r codes
    str = str:gsub("|c%x%x%x%x%x%x%x%x", "")
    str = str:gsub("|r", "")
    -- Remove texture strings
    str = str:gsub("|T.-|t", "")
    return str
end

-- Register with catalog
Catalog:RegisterDomain("Text", {
    Truncate = {
        handler = Text.Truncate,
        description = "Truncate string with suffix",
        params = {
            { name = "str", type = "string", required = true },
            { name = "maxLen", type = "number", required = true },
            { name = "suffix", type = "string", required = false, default = "..." },
        },
        returns = { type = "string" },
        example = 'Text.Truncate("Hello World", 8) → "Hello..."',
    },
    Pluralize = {
        handler = Text.Pluralize,
        description = "Pluralize a word based on count",
        params = {
            { name = "count", type = "number", required = true },
            { name = "singular", type = "string", required = true },
            { name = "plural", type = "string", required = false },
        },
        returns = { type = "string" },
        example = 'Text.Pluralize(2, "item") → "2 items"',
    },
    FormatNumber = {
        handler = Text.FormatNumber,
        description = "Format number with thousands separators",
        params = {
            { name = "n", type = "number", required = true },
            { name = "decimals", type = "number", required = false, default = 0 },
            { name = "sep", type = "string", required = false, default = "," },
        },
        returns = { type = "string" },
        example = 'Text.FormatNumber(1234567) → "1,234,567"',
    },
    FormatCompact = {
        handler = Text.FormatCompact,
        description = "Format number in compact form (1K, 1.2M)",
        params = {
            { name = "n", type = "number", required = true },
            { name = "decimals", type = "number", required = false, default = 1 },
        },
        returns = { type = "string" },
        example = 'Text.FormatCompact(1234567) → "1.2M"',
    },
    Capitalize = {
        handler = Text.Capitalize,
        description = "Capitalize first letter of string",
        params = {
            { name = "str", type = "string", required = true },
        },
        returns = { type = "string" },
        example = 'Text.Capitalize("hello") → "Hello"',
    },
    TitleCase = {
        handler = Text.TitleCase,
        description = "Capitalize first letter of each word",
        params = {
            { name = "str", type = "string", required = true },
        },
        returns = { type = "string" },
        example = 'Text.TitleCase("hello world") → "Hello World"',
    },
    Pad = {
        handler = Text.Pad,
        description = "Pad string to length",
        params = {
            { name = "str", type = "string", required = true },
            { name = "len", type = "number", required = true },
            { name = "char", type = "string", required = false, default = " " },
            { name = "right", type = "boolean", required = false, default = false },
        },
        returns = { type = "string" },
        example = 'Text.Pad("42", 5, "0") → "00042"',
    },
    StripColors = {
        handler = Text.StripColors,
        description = "Strip WoW color codes from string",
        params = {
            { name = "str", type = "string", required = true },
        },
        returns = { type = "string" },
        example = 'Text.StripColors("|cFFFF0000Red|r") → "Red"',
    },
})

FenCore.Text = Text
return Text
