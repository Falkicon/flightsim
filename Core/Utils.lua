-- Flightsim Core Utilities
-- Pure Lua 5.1 functions - no WoW dependencies
-- Can be tested in sandbox

local Core = {}
Core.Utils = {}

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

--- Clamp a number between min and max.
---@param n number Value to clamp
---@param minV number Minimum value
---@param maxV number Maximum value
---@return number Clamped value
function Core.Utils.Clamp(n, minV, maxV)
	if n < minV then
		return minV
	end
	if n > maxV then
		return maxV
	end
	return n
end

local Clamp = Core.Utils.Clamp

--- Get RGB color for a percentage (red -> yellow -> green).
---@param pct number Percentage (0-1)
---@return number r, number g, number b RGB values (0-1)
function Core.Utils.ColorForPct(pct)
	pct = Clamp(pct or 0, 0, 1)
	local r, g, b
	if pct < 0.5 then
		-- red -> yellow (0% to 50%)
		local t = pct * 2
		r = COLOR_RED[1] + (COLOR_YELLOW[1] - COLOR_RED[1]) * t
		g = COLOR_RED[2] + (COLOR_YELLOW[2] - COLOR_RED[2]) * t
		b = COLOR_RED[3] + (COLOR_YELLOW[3] - COLOR_RED[3]) * t
	else
		-- yellow -> green (50% to 100%)
		local t = (pct - 0.5) * 2
		r = COLOR_YELLOW[1] + (COLOR_GREEN[1] - COLOR_YELLOW[1]) * t
		g = COLOR_YELLOW[2] + (COLOR_GREEN[2] - COLOR_YELLOW[2]) * t
		b = COLOR_YELLOW[3] + (COLOR_GREEN[3] - COLOR_YELLOW[3]) * t
	end
	return r, g, b
end

--- Get RGB color for Whirling Surge ability bar.
---@param pct number Percentage (0-1)
---@return number r, number g, number b RGB values (0-1)
function Core.Utils.ColorForPctBlue(pct)
	pct = Clamp(pct or 0, 0, 1)
	local r = COLOR_WHIRLING_SURGE_EMPTY[1] + (COLOR_WHIRLING_SURGE[1] - COLOR_WHIRLING_SURGE_EMPTY[1]) * pct
	local g = COLOR_WHIRLING_SURGE_EMPTY[2] + (COLOR_WHIRLING_SURGE[2] - COLOR_WHIRLING_SURGE_EMPTY[2]) * pct
	local b = COLOR_WHIRLING_SURGE_EMPTY[3] + (COLOR_WHIRLING_SURGE[3] - COLOR_WHIRLING_SURGE_EMPTY[3]) * pct
	return r, g, b
end

--- Get RGB color for Second Wind ability bar.
---@param pct number Percentage (0-1)
---@return number r, number g, number b RGB values (0-1)
function Core.Utils.ColorForPctPurple(pct)
	pct = Clamp(pct or 0, 0, 1)
	local r = COLOR_SECOND_WIND_EMPTY[1] + (COLOR_SECOND_WIND[1] - COLOR_SECOND_WIND_EMPTY[1]) * pct
	local g = COLOR_SECOND_WIND_EMPTY[2] + (COLOR_SECOND_WIND[2] - COLOR_SECOND_WIND_EMPTY[2]) * pct
	local b = COLOR_SECOND_WIND_EMPTY[3] + (COLOR_SECOND_WIND[3] - COLOR_SECOND_WIND_EMPTY[3]) * pct
	return r, g, b
end

--- Get RGB color for Surge Forward ability bar.
---@param pct number Percentage (0-1)
---@return number r, number g, number b RGB values (0-1)
function Core.Utils.ColorForPctSurgeForward(pct)
	pct = Clamp(pct or 0, 0, 1)
	local r = COLOR_SURGE_FORWARD_EMPTY[1] + (COLOR_SURGE_FORWARD[1] - COLOR_SURGE_FORWARD_EMPTY[1]) * pct
	local g = COLOR_SURGE_FORWARD_EMPTY[2] + (COLOR_SURGE_FORWARD[2] - COLOR_SURGE_FORWARD_EMPTY[2]) * pct
	local b = COLOR_SURGE_FORWARD_EMPTY[3] + (COLOR_SURGE_FORWARD[3] - COLOR_SURGE_FORWARD_EMPTY[3]) * pct
	return r, g, b
end

-- Expose Core globally for sandbox testing
FlightsimCore = Core

return Core
