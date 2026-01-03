-- Math.lua
-- Pure math utilities - no WoW dependencies

local FenCore = _G.FenCore
local Catalog = FenCore.Catalog

local Math = {}

--- Clamp a number between min and max.
---@param n number Value to clamp
---@param minValue number Minimum value
---@param maxValue number Maximum value
---@return number Clamped value
function Math.Clamp(n, minValue, maxValue)
    if n < minValue then return minValue end
    if n > maxValue then return maxValue end
    return n
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

--- Smooth a delta value using exponential moving average.
---@param oldSmooth number Previous smoothed value
---@param newDelta number New raw delta
---@param oldWeight? number Weight for old value (default 0.7)
---@return number Smoothed delta
function Math.SmoothDelta(oldSmooth, newDelta, oldWeight)
    oldWeight = oldWeight or 0.7
    local newWeight = 1 - oldWeight
    return oldSmooth * oldWeight + newDelta * newWeight
end

--- Calculate percentage from current/max values.
---@param current number Current value
---@param max number Maximum value
---@return number Percentage (0-100)
function Math.ToPercentage(current, max)
    if max <= 0 then return 0 end
    return (current / max) * 100
end

--- Calculate fill fraction from current/max values.
---@param current number Current value
---@param max number Maximum value
---@return number Fraction (0-1)
function Math.ToFraction(current, max)
    if max <= 0 then return 0 end
    return Math.Clamp(current / max, 0, 1)
end

--- Normalize a value to a -1 to 1 range.
---@param value number Raw value
---@param maxValue number Maximum expected value
---@return number Normalized value (-1 to 1)
function Math.NormalizeDelta(value, maxValue)
    if maxValue <= 0 then return 0 end
    return Math.Clamp(value / maxValue, -1, 1)
end

--- Round a number to N decimal places.
---@param n number Value to round
---@param decimals? number Decimal places (default 0)
---@return number Rounded value
function Math.Round(n, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(n * mult + 0.5) / mult
end

--- Map a value from one range to another.
---@param value number Input value
---@param options table {inMin, inMax, outMin, outMax}
---@return number Mapped value
function Math.MapRange(value, options)
    local inMin = options.inMin or 0
    local inMax = options.inMax or 1
    local outMin = options.outMin or 0
    local outMax = options.outMax or 1

    if inMax == inMin then return outMin end
    local normalized = (value - inMin) / (inMax - inMin)
    return outMin + normalized * (outMax - outMin)
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

-- Register with catalog
Catalog:RegisterDomain("Math", {
    Clamp = {
        handler = Math.Clamp,
        description = "Clamp a number between min and max",
        params = {
            { name = "n", type = "number", required = true },
            { name = "minValue", type = "number", required = true },
            { name = "maxValue", type = "number", required = true },
        },
        returns = { type = "number" },
        example = "Math.Clamp(150, 0, 100) → 100",
    },
    Lerp = {
        handler = Math.Lerp,
        description = "Linear interpolation between two values",
        params = {
            { name = "a", type = "number", required = true },
            { name = "b", type = "number", required = true },
            { name = "t", type = "number", required = true, description = "0-1" },
        },
        returns = { type = "number" },
        example = "Math.Lerp(0, 100, 0.5) → 50",
    },
    SmoothDelta = {
        handler = Math.SmoothDelta,
        description = "Smooth a delta using exponential moving average",
        params = {
            { name = "oldSmooth", type = "number", required = true },
            { name = "newDelta", type = "number", required = true },
            { name = "oldWeight", type = "number", required = false, default = 0.7 },
        },
        returns = { type = "number" },
        example = "Math.SmoothDelta(5, 10, 0.7) → 6.5",
    },
    ToFraction = {
        handler = Math.ToFraction,
        description = "Calculate fill fraction from current/max",
        params = {
            { name = "current", type = "number", required = true },
            { name = "max", type = "number", required = true },
        },
        returns = { type = "number", description = "0-1" },
        example = "Math.ToFraction(75, 100) → 0.75",
    },
    ToPercentage = {
        handler = Math.ToPercentage,
        description = "Calculate percentage from current/max",
        params = {
            { name = "current", type = "number", required = true },
            { name = "max", type = "number", required = true },
        },
        returns = { type = "number", description = "0-100" },
        example = "Math.ToPercentage(75, 100) → 75",
    },
    NormalizeDelta = {
        handler = Math.NormalizeDelta,
        description = "Normalize a value to -1 to 1 range",
        params = {
            { name = "value", type = "number", required = true },
            { name = "maxValue", type = "number", required = true },
        },
        returns = { type = "number", description = "-1 to 1" },
        example = "Math.NormalizeDelta(5, 10) → 0.5",
    },
    Round = {
        handler = Math.Round,
        description = "Round to N decimal places",
        params = {
            { name = "n", type = "number", required = true },
            { name = "decimals", type = "number", required = false, default = 0 },
        },
        returns = { type = "number" },
        example = "Math.Round(3.14159, 2) → 3.14",
    },
    MapRange = {
        handler = Math.MapRange,
        description = "Map value from one range to another",
        params = {
            { name = "value", type = "number", required = true },
            { name = "options", type = "table", required = true, description = "{inMin, inMax, outMin, outMax}" },
        },
        returns = { type = "number" },
        example = "Math.MapRange(50, {inMin=0, inMax=100, outMin=0, outMax=1}) → 0.5",
    },
    ApplyCurve = {
        handler = Math.ApplyCurve,
        description = "Apply square root curve for sensitivity ramping",
        params = {
            { name = "value", type = "number", required = true, description = "-1 to 1" },
        },
        returns = { type = "number", description = "-1 to 1" },
        example = "Math.ApplyCurve(0.25) → 0.5",
    },
})

FenCore.Math = Math
return Math
