-- Color.lua
-- Color utilities and gradient calculations

local FenCore = _G.FenCore
local Math = FenCore.Math
local Catalog = FenCore.Catalog

local Color = {}

--- Create a color table from RGB values.
---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param a? number Alpha (0-1, default 1)
---@return table {r, g, b, a}
function Color.Create(r, g, b, a)
    return {
        r = Math.Clamp(r or 0, 0, 1),
        g = Math.Clamp(g or 0, 0, 1),
        b = Math.Clamp(b or 0, 0, 1),
        a = Math.Clamp(a or 1, 0, 1),
    }
end

--- Interpolate between two colors.
---@param c1 table First color {r, g, b, a?}
---@param c2 table Second color {r, g, b, a?}
---@param t number Interpolation factor (0-1)
---@return table Interpolated color
function Color.Lerp(c1, c2, t)
    t = Math.Clamp(t, 0, 1)
    return {
        r = Math.Lerp(c1.r or 0, c2.r or 0, t),
        g = Math.Lerp(c1.g or 0, c2.g or 0, t),
        b = Math.Lerp(c1.b or 0, c2.b or 0, t),
        a = Math.Lerp(c1.a or 1, c2.a or 1, t),
    }
end

--- Get color from gradient stops.
---@param pct number Position in gradient (0-1)
---@param stops table[] Array of {pct, color} stops
---@return table Color at position
function Color.Gradient(pct, stops)
    if not stops or #stops == 0 then
        return Color.Create(1, 1, 1)
    end

    pct = Math.Clamp(pct, 0, 1)

    -- Sort stops by percentage
    table.sort(stops, function(a, b) return a.pct < b.pct end)

    -- Find surrounding stops
    local prevStop = stops[1]
    local nextStop = stops[#stops]

    for i, stop in ipairs(stops) do
        if stop.pct <= pct then
            prevStop = stop
        end
        if stop.pct >= pct and stops[i - 1] then
            nextStop = stop
            break
        end
    end

    -- Exact match or at boundary
    if prevStop.pct == nextStop.pct then
        return prevStop.color
    end

    -- Interpolate between stops
    local range = nextStop.pct - prevStop.pct
    local localPct = (pct - prevStop.pct) / range

    return Color.Lerp(prevStop.color, nextStop.color, localPct)
end

--- Get health-based color (Red → Yellow → Green).
---@param pct number Health percentage (0-1)
---@return table Color
function Color.ForHealth(pct)
    local stops = {
        { pct = 0, color = { r = 1, g = 0, b = 0 } },       -- Red
        { pct = 0.5, color = { r = 1, g = 1, b = 0 } },     -- Yellow
        { pct = 1, color = { r = 0, g = 1, b = 0 } },       -- Green
    }
    return Color.Gradient(pct, stops)
end

--- Get progress-based color (same as health).
---@param pct number Progress (0-1)
---@return table Color
function Color.ForProgress(pct)
    return Color.ForHealth(pct)
end

--- Convert hex string to RGB color.
---@param hex string Hex color (e.g., "#FF0000" or "FF0000")
---@return table Color {r, g, b, a}
function Color.HexToRGB(hex)
    hex = hex:gsub("#", "")

    local r, g, b, a = 1, 1, 1, 1

    if #hex >= 6 then
        r = tonumber(hex:sub(1, 2), 16) / 255
        g = tonumber(hex:sub(3, 4), 16) / 255
        b = tonumber(hex:sub(5, 6), 16) / 255
    end

    if #hex >= 8 then
        a = tonumber(hex:sub(7, 8), 16) / 255
    end

    return Color.Create(r, g, b, a)
end

--- Convert RGB color to hex string.
---@param color table {r, g, b, a?}
---@param includeAlpha? boolean Include alpha in output
---@return string Hex string
function Color.RGBToHex(color, includeAlpha)
    local r = math.floor((color.r or 0) * 255)
    local g = math.floor((color.g or 0) * 255)
    local b = math.floor((color.b or 0) * 255)

    if includeAlpha then
        local a = math.floor((color.a or 1) * 255)
        return string.format("%02X%02X%02X%02X", r, g, b, a)
    end

    return string.format("%02X%02X%02X", r, g, b)
end

--- Darken a color by a factor.
---@param color table {r, g, b, a?}
---@param factor number Darkening factor (0-1, where 0=black)
---@return table Darkened color
function Color.Darken(color, factor)
    factor = Math.Clamp(factor, 0, 1)
    return Color.Create(
        color.r * factor,
        color.g * factor,
        color.b * factor,
        color.a
    )
end

--- Lighten a color by a factor.
---@param color table {r, g, b, a?}
---@param factor number Lightening factor (0-1, where 1=white)
---@return table Lightened color
function Color.Lighten(color, factor)
    factor = Math.Clamp(factor, 0, 1)
    return Color.Create(
        color.r + (1 - color.r) * factor,
        color.g + (1 - color.g) * factor,
        color.b + (1 - color.b) * factor,
        color.a
    )
end

-- Register with catalog
Catalog:RegisterDomain("Color", {
    Create = {
        handler = Color.Create,
        description = "Create a color table from RGB values",
        params = {
            { name = "r", type = "number", required = true, description = "0-1" },
            { name = "g", type = "number", required = true, description = "0-1" },
            { name = "b", type = "number", required = true, description = "0-1" },
            { name = "a", type = "number", required = false, default = 1 },
        },
        returns = { type = "table" },
        example = "Color.Create(1, 0, 0) → {r=1, g=0, b=0, a=1}",
    },
    Lerp = {
        handler = Color.Lerp,
        description = "Interpolate between two colors",
        params = {
            { name = "c1", type = "table", required = true },
            { name = "c2", type = "table", required = true },
            { name = "t", type = "number", required = true, description = "0-1" },
        },
        returns = { type = "table" },
        example = "Color.Lerp({r=1,g=0,b=0}, {r=0,g=1,b=0}, 0.5) → {r=0.5,g=0.5,b=0}",
    },
    Gradient = {
        handler = Color.Gradient,
        description = "Get color from gradient stops",
        params = {
            { name = "pct", type = "number", required = true, description = "0-1" },
            { name = "stops", type = "table[]", required = true, description = "Array of {pct, color}" },
        },
        returns = { type = "table" },
    },
    ForHealth = {
        handler = Color.ForHealth,
        description = "Get health-based color (Red → Yellow → Green)",
        params = {
            { name = "pct", type = "number", required = true, description = "0-1" },
        },
        returns = { type = "table" },
        example = "Color.ForHealth(0.5) → Yellow",
    },
    ForProgress = {
        handler = Color.ForProgress,
        description = "Get progress-based color (same as health)",
        params = {
            { name = "pct", type = "number", required = true, description = "0-1" },
        },
        returns = { type = "table" },
    },
    HexToRGB = {
        handler = Color.HexToRGB,
        description = "Convert hex string to RGB color",
        params = {
            { name = "hex", type = "string", required = true, description = '"#FF0000" or "FF0000"' },
        },
        returns = { type = "table" },
        example = 'Color.HexToRGB("#FF0000") → {r=1, g=0, b=0, a=1}',
    },
    RGBToHex = {
        handler = Color.RGBToHex,
        description = "Convert RGB color to hex string",
        params = {
            { name = "color", type = "table", required = true },
            { name = "includeAlpha", type = "boolean", required = false },
        },
        returns = { type = "string" },
        example = 'Color.RGBToHex({r=1, g=0, b=0}) → "FF0000"',
    },
    Darken = {
        handler = Color.Darken,
        description = "Darken a color by a factor",
        params = {
            { name = "color", type = "table", required = true },
            { name = "factor", type = "number", required = true, description = "0-1" },
        },
        returns = { type = "table" },
    },
    Lighten = {
        handler = Color.Lighten,
        description = "Lighten a color by a factor",
        params = {
            { name = "color", type = "table", required = true },
            { name = "factor", type = "number", required = true, description = "0-1" },
        },
        returns = { type = "table" },
    },
})

FenCore.Color = Color
return Color
