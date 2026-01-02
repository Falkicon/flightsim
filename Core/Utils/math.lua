-- Flightsim Core Math Utilities
-- Pure Lua 5.1 - No WoW dependencies

local Core = FlightsimCore
local Utils = Core.Utils

---@class MathUtils
local Math = {}

--- Clamp a number between min and max.
---@param n number Value to clamp
---@param minV number Minimum value
---@param maxV number Maximum value
---@return number Clamped value
function Math.Clamp(n, minV, maxV)
	if n < minV then
		return minV
	end
	if n > maxV then
		return maxV
	end
	return n
end

--- Smooth a delta value using exponential moving average.
--- Used for acceleration smoothing (avoids jitter).
---@param oldSmooth number Previous smoothed value
---@param newDelta number New raw delta
---@param oldWeight? number Weight for old value (default 0.7)
---@return number Smoothed delta
function Math.SmoothDelta(oldSmooth, newDelta, oldWeight)
	oldWeight = oldWeight or 0.7
	local newWeight = 1 - oldWeight
	return oldSmooth * oldWeight + newDelta * newWeight
end

--- Apply square root curve for sensitivity ramping.
--- More sensitive near zero, compressed at extremes.
---@param value number Normalized value (-1 to 1)
---@return number Curved value (-1 to 1)
function Math.ApplyCurve(value)
	if value >= 0 then
		return math.sqrt(value)
	else
		return -math.sqrt(-value)
	end
end

--- Normalize a delta value to a -1 to 1 range.
---@param delta number Raw delta value
---@param maxDelta number Maximum expected delta (for normalization)
---@return number Normalized value (-1 to 1)
function Math.NormalizeDelta(delta, maxDelta)
	if maxDelta <= 0 then
		return 0
	end
	return Math.Clamp(delta / maxDelta, -1, 1)
end

--- Linear interpolation between two values.
---@param a number Start value
---@param b number End value
---@param t number Interpolation factor (0-1)
---@return number Interpolated value
function Math.Lerp(a, b, t)
	t = Math.Clamp(t, 0, 1)
	return a + (b - a) * t
end

--- Calculate percentage from current/max values.
---@param current number Current value
---@param max number Maximum value
---@return number Percentage (0-100)
function Math.ToPercentage(current, max)
	if max <= 0 then
		return 0
	end
	return (current / max) * 100
end

--- Calculate fill fraction from current/max values.
---@param current number Current value
---@param max number Maximum value
---@return number Fraction (0-1)
function Math.ToFraction(current, max)
	if max <= 0 then
		return 0
	end
	return Math.Clamp(current / max, 0, 1)
end

Utils.Math = Math
return Math
