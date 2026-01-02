-- Flightsim Core Color Utilities
-- Pure Lua 5.1 - No WoW dependencies

local Core = FlightsimCore
local Utils = Core.Utils
local Math = Utils.Math

---@class ColorUtils
local Color = {}

-- Color constants (Blizzard-matching palette)
local COLOR_GREEN = { 0.169, 0.651, 0.016 } -- #2BA604
local COLOR_YELLOW = { 0.769, 0.651, 0.016 } -- #C4A604
local COLOR_RED = { 0.769, 0.169, 0.016 } -- #C42B04

local COLOR_SURGE_FORWARD = { 0.455, 0.686, 1.0 } -- #74AFFF
local COLOR_SURGE_FORWARD_EMPTY = { 0.18, 0.27, 0.4 }

local COLOR_SECOND_WIND = { 0.827, 0.475, 0.937 } -- #D379EF
local COLOR_SECOND_WIND_EMPTY = { 0.33, 0.19, 0.37 }

local COLOR_WHIRLING_SURGE = { 0.290, 0.780, 0.831 } -- #4AC7D4
local COLOR_WHIRLING_SURGE_EMPTY = { 0.12, 0.31, 0.33 }

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
		return lerpColor(COLOR_RED, COLOR_YELLOW, t)
	else
		-- yellow -> green (50% to 100%)
		local t = (pct - 0.5) * 2
		return lerpColor(COLOR_YELLOW, COLOR_GREEN, t)
	end
end

--- Get RGB color for Whirling Surge ability bar.
---@param pct number Percentage (0-1)
---@return number r, number g, number b RGB values (0-1)
function Color.ForWhirlingSurge(pct)
	return lerpColor(COLOR_WHIRLING_SURGE_EMPTY, COLOR_WHIRLING_SURGE, pct)
end

--- Get RGB color for Second Wind ability bar.
---@param pct number Percentage (0-1)
---@return number r, number g, number b RGB values (0-1)
function Color.ForSecondWind(pct)
	return lerpColor(COLOR_SECOND_WIND_EMPTY, COLOR_SECOND_WIND, pct)
end

--- Get RGB color for Surge Forward ability bar.
---@param pct number Percentage (0-1)
---@return number r, number g, number b RGB values (0-1)
function Color.ForSurgeForward(pct)
	return lerpColor(COLOR_SURGE_FORWARD_EMPTY, COLOR_SURGE_FORWARD, pct)
end

-- Legacy aliases for backwards compatibility with existing code
Color.ColorForPct = Color.ForSpeed
Color.ColorForPctBlue = Color.ForWhirlingSurge
Color.ColorForPctPurple = Color.ForSecondWind
Color.ColorForPctSurgeForward = Color.ForSurgeForward

-- Expose color constants for testing
Color.Colors = {
	GREEN = COLOR_GREEN,
	YELLOW = COLOR_YELLOW,
	RED = COLOR_RED,
	SURGE_FORWARD = COLOR_SURGE_FORWARD,
	SURGE_FORWARD_EMPTY = COLOR_SURGE_FORWARD_EMPTY,
	SECOND_WIND = COLOR_SECOND_WIND,
	SECOND_WIND_EMPTY = COLOR_SECOND_WIND_EMPTY,
	WHIRLING_SURGE = COLOR_WHIRLING_SURGE,
	WHIRLING_SURGE_EMPTY = COLOR_WHIRLING_SURGE_EMPTY,
}

Utils.Color = Color
return Color
