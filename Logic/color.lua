-- Flightsim Color Logic
-- Uses FenCore.Color for color math, defines Flightsim-specific palettes

local FenCore = _G.FenCore
local FenColor = FenCore.Color
local Math = FenCore.Math

---@class FlightsimColor
local Color = {}

-- Color constants (Blizzard-matching palette)
Color.Colors = {
    -- Speed bar gradient
    GREEN = { 0.169, 0.651, 0.016 },   -- #2BA604
    YELLOW = { 0.769, 0.651, 0.016 },  -- #C4A604
    RED = { 0.769, 0.169, 0.016 },     -- #C42B04

    -- Surge Forward
    SURGE_FORWARD = { 0.455, 0.686, 1.0 },       -- #74AFFF
    SURGE_FORWARD_EMPTY = { 0.18, 0.27, 0.4 },

    -- Second Wind
    SECOND_WIND = { 0.827, 0.475, 0.937 },       -- #D379EF
    SECOND_WIND_EMPTY = { 0.33, 0.19, 0.37 },

    -- Whirling Surge
    WHIRLING_SURGE = { 0.290, 0.780, 0.831 },    -- #4AC7D4
    WHIRLING_SURGE_EMPTY = { 0.12, 0.31, 0.33 },
}

--- Linearly interpolate between two colors.
---@param c1 table RGB table {r, g, b}
---@param c2 table RGB table {r, g, b}
---@param t number Interpolation factor (0-1)
---@return number r, number g, number b
local function lerpColor(c1, c2, t)
    t = Math.Clamp(t or 0, 0, 1)
    local r = c1[1] + (c2[1] - c1[1]) * t
    local g = c1[2] + (c2[2] - c1[2]) * t
    local b = c1[3] + (c2[3] - c1[3]) * t
    return r, g, b
end

--- Get RGB color for speed bar (red -> yellow -> green).
---@param pct number Percentage (0-1)
---@return number r, number g, number b RGB values (0-1)
function Color.ForSpeed(pct)
    pct = Math.Clamp(pct or 0, 0, 1)
    if pct < 0.5 then
        -- red -> yellow (0% to 50%)
        local t = pct * 2
        return lerpColor(Color.Colors.RED, Color.Colors.YELLOW, t)
    else
        -- yellow -> green (50% to 100%)
        local t = (pct - 0.5) * 2
        return lerpColor(Color.Colors.YELLOW, Color.Colors.GREEN, t)
    end
end

--- Get RGB color for Whirling Surge ability bar.
---@param pct number Percentage (0-1)
---@return number r, number g, number b RGB values (0-1)
function Color.ForWhirlingSurge(pct)
    return lerpColor(Color.Colors.WHIRLING_SURGE_EMPTY, Color.Colors.WHIRLING_SURGE, pct)
end

--- Get RGB color for Second Wind ability bar.
---@param pct number Percentage (0-1)
---@return number r, number g, number b RGB values (0-1)
function Color.ForSecondWind(pct)
    return lerpColor(Color.Colors.SECOND_WIND_EMPTY, Color.Colors.SECOND_WIND, pct)
end

--- Get RGB color for Surge Forward ability bar.
---@param pct number Percentage (0-1)
---@return number r, number g, number b RGB values (0-1)
function Color.ForSurgeForward(pct)
    return lerpColor(Color.Colors.SURGE_FORWARD_EMPTY, Color.Colors.SURGE_FORWARD, pct)
end

-- Legacy aliases for backwards compatibility with existing code
Color.ColorForPct = Color.ForSpeed
Color.ColorForPctBlue = Color.ForWhirlingSurge
Color.ColorForPctPurple = Color.ForSecondWind
Color.ColorForPctSurgeForward = Color.ForSurgeForward

FlightsimLogic = FlightsimLogic or {}
FlightsimLogic.Color = Color
return Color
