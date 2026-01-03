-- Time.lua
-- Time formatting utilities

local FenCore = _G.FenCore
local Math = FenCore.Math
local Catalog = FenCore.Catalog

local Time = {}

--- Format duration to human-readable string.
---@param seconds number Duration in seconds
---@param opts? table {showSeconds?: boolean, compact?: boolean}
---@return string Formatted duration
function Time.FormatDuration(seconds, opts)
    if seconds == nil or seconds < 0 then
        return "0s"
    end

    opts = opts or {}
    local showSeconds = opts.showSeconds ~= false
    local compact = opts.compact == true

    seconds = math.floor(seconds)

    local days = math.floor(seconds / 86400)
    seconds = seconds % 86400
    local hours = math.floor(seconds / 3600)
    seconds = seconds % 3600
    local minutes = math.floor(seconds / 60)
    seconds = seconds % 60

    local parts = {}

    if days > 0 then
        table.insert(parts, days .. (compact and "d" or " day" .. (days > 1 and "s" or "")))
    end
    if hours > 0 then
        table.insert(parts, hours .. (compact and "h" or " hour" .. (hours > 1 and "s" or "")))
    end
    if minutes > 0 then
        table.insert(parts, minutes .. (compact and "m" or " min"))
    end
    if showSeconds and (seconds > 0 or #parts == 0) then
        table.insert(parts, seconds .. (compact and "s" or " sec"))
    end

    if compact then
        return table.concat(parts, " ")
    else
        return table.concat(parts, " ")
    end
end

--- Format seconds as cooldown display (MM:SS or just seconds).
---@param seconds number Duration in seconds
---@return string Formatted cooldown
function Time.FormatCooldown(seconds)
    if seconds == nil or seconds <= 0 then
        return "0"
    end

    seconds = math.ceil(seconds)

    if seconds < 60 then
        return tostring(seconds)
    end

    if seconds < 3600 then
        local m = math.floor(seconds / 60)
        local s = seconds % 60
        return string.format("%d:%02d", m, s)
    end

    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    return string.format("%d:%02d:%02d", h, m, seconds % 60)
end

--- Format seconds as short cooldown (1.5, 30, 2m, 1h).
---@param seconds number Duration in seconds
---@param decimals? number Decimal places for small values (default 1)
---@return string Formatted short cooldown
function Time.FormatCooldownShort(seconds, decimals)
    if seconds == nil or seconds <= 0 then
        return "0"
    end

    decimals = decimals or 1

    if seconds < 10 then
        return string.format("%." .. decimals .. "f", seconds)
    end

    if seconds < 60 then
        return tostring(math.ceil(seconds))
    end

    if seconds < 3600 then
        return math.ceil(seconds / 60) .. "m"
    end

    return math.ceil(seconds / 3600) .. "h"
end

--- Parse duration string to seconds.
---@param str string Duration string (e.g., "1h 30m", "90s", "2d")
---@return number|nil seconds, string|nil error
function Time.ParseDuration(str)
    if str == nil or str == "" then
        return nil, "Empty string"
    end

    str = str:lower():gsub("%s+", "")

    local total = 0
    local foundAny = false

    -- Match patterns like "1d", "2h", "30m", "45s"
    for value, unit in str:gmatch("(%d+)([dhms])") do
        foundAny = true
        value = tonumber(value)
        if unit == "d" then
            total = total + value * 86400
        elseif unit == "h" then
            total = total + value * 3600
        elseif unit == "m" then
            total = total + value * 60
        elseif unit == "s" then
            total = total + value
        end
    end

    -- Try plain number (assume seconds)
    if not foundAny then
        local num = tonumber(str)
        if num then
            return num, nil
        end
        return nil, "Invalid format"
    end

    return total, nil
end

--- Get relative time description.
---@param seconds number Seconds ago (positive) or in future (negative)
---@return string Relative description
function Time.FormatRelative(seconds)
    if seconds == nil then
        return "unknown"
    end

    local abs = math.abs(seconds)
    local suffix = seconds >= 0 and " ago" or " from now"

    if abs < 60 then
        return "just now"
    elseif abs < 3600 then
        local m = math.floor(abs / 60)
        return m .. " min" .. suffix
    elseif abs < 86400 then
        local h = math.floor(abs / 3600)
        return h .. " hour" .. (h > 1 and "s" or "") .. suffix
    else
        local d = math.floor(abs / 86400)
        return d .. " day" .. (d > 1 and "s" or "") .. suffix
    end
end

-- Register with catalog
Catalog:RegisterDomain("Time", {
    FormatDuration = {
        handler = Time.FormatDuration,
        description = "Format duration to human-readable string",
        params = {
            { name = "seconds", type = "number", required = true },
            { name = "opts", type = "table", required = false, description = "{showSeconds?, compact?}" },
        },
        returns = { type = "string" },
        example = 'Time.FormatDuration(3661) → "1 hour 1 min 1 sec"',
    },
    FormatCooldown = {
        handler = Time.FormatCooldown,
        description = "Format seconds as cooldown display (MM:SS)",
        params = {
            { name = "seconds", type = "number", required = true },
        },
        returns = { type = "string" },
        example = 'Time.FormatCooldown(90) → "1:30"',
    },
    FormatCooldownShort = {
        handler = Time.FormatCooldownShort,
        description = "Format seconds as short cooldown (1.5, 30, 2m, 1h)",
        params = {
            { name = "seconds", type = "number", required = true },
            { name = "decimals", type = "number", required = false, default = 1 },
        },
        returns = { type = "string" },
        example = 'Time.FormatCooldownShort(90) → "2m"',
    },
    ParseDuration = {
        handler = Time.ParseDuration,
        description = 'Parse duration string to seconds',
        params = {
            { name = "str", type = "string", required = true, description = '"1h 30m", "90s", "2d"' },
        },
        returns = { type = "number|nil, string|nil" },
        example = 'Time.ParseDuration("1h 30m") → 5400',
    },
    FormatRelative = {
        handler = Time.FormatRelative,
        description = "Get relative time description",
        params = {
            { name = "seconds", type = "number", required = true, description = "Seconds ago (+) or future (-)" },
        },
        returns = { type = "string" },
        example = 'Time.FormatRelative(3600) → "1 hour ago"',
    },
})

FenCore.Time = Time
return Time
