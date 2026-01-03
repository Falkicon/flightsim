-- Progress.lua
-- Progress bar and fill calculations

local FenCore = _G.FenCore
local Result = FenCore.ActionResult
local Math = FenCore.Math
local Catalog = FenCore.Catalog

local Progress = {}

--- Calculate bar fill percentage.
---@param current number Current value
---@param max number Maximum value
---@return ActionResult<{fillPct: number, isAtMax: boolean}>
function Progress.CalculateFill(current, max)
    if current == nil then
        return Result.error("INVALID_INPUT", "current is required")
    end
    if max == nil or max <= 0 then
        max = 100
    end

    local fillPct = Math.Clamp(current / max, 0, 1)
    local isAtMax = fillPct >= 0.99

    return Result.success({
        fillPct = fillPct,
        isAtMax = isAtMax,
    })
end

--- Calculate fill with effective max (session max override).
---@param current number Current value
---@param configuredMax number User-configured maximum
---@param sessionMax? number Session observed maximum
---@return ActionResult<{fillPct: number, effectiveMax: number, usedSession: boolean}>
function Progress.CalculateFillWithSessionMax(current, configuredMax, sessionMax)
    if current == nil then
        return Result.error("INVALID_INPUT", "current is required")
    end

    configuredMax = configuredMax or 100
    local effectiveMax = configuredMax
    local usedSession = false

    if sessionMax and sessionMax > configuredMax then
        effectiveMax = sessionMax
        usedSession = true
    end

    if effectiveMax <= 0 then
        effectiveMax = 1
    end

    local fillPct = Math.Clamp(current / effectiveMax, 0, 1)

    return Result.success({
        fillPct = fillPct,
        effectiveMax = effectiveMax,
        usedSession = usedSession,
    })
end

--- Calculate marker position on a progress bar.
---@param markerValue number Value for the marker
---@param max number Maximum value
---@return ActionResult<{markerPct: number, shouldShow: boolean}>
function Progress.CalculateMarker(markerValue, max)
    if markerValue == nil or markerValue <= 0 then
        return Result.success({
            markerPct = 0,
            shouldShow = false,
        })
    end

    if max == nil or max <= 0 then
        max = 100
    end

    local markerPct = Math.Clamp(markerValue / max, 0, 1)

    return Result.success({
        markerPct = markerPct,
        shouldShow = true,
    })
end

--- Normalize a raw value to percentage.
---@param rawValue number Raw value
---@param baseValue number Value that equals 100%
---@return ActionResult<{percentage: number}>
function Progress.ToPercentage(rawValue, baseValue)
    if rawValue == nil then
        return Result.error("INVALID_INPUT", "rawValue is required")
    end

    baseValue = baseValue or 1
    if baseValue <= 0 then
        baseValue = 1
    end

    local pct = (rawValue / baseValue) * 100

    return Result.success({
        percentage = pct,
    })
end

-- Register with catalog
Catalog:RegisterDomain("Progress", {
    CalculateFill = {
        handler = Progress.CalculateFill,
        description = "Calculate bar fill percentage from current/max",
        params = {
            { name = "current", type = "number", required = true },
            { name = "max", type = "number", required = true },
        },
        returns = { type = "ActionResult<{fillPct, isAtMax}>" },
        example = "Progress.CalculateFill(75, 100) → {fillPct: 0.75, isAtMax: false}",
    },
    CalculateFillWithSessionMax = {
        handler = Progress.CalculateFillWithSessionMax,
        description = "Calculate fill with session max override",
        params = {
            { name = "current", type = "number", required = true },
            { name = "configuredMax", type = "number", required = true },
            { name = "sessionMax", type = "number", required = false },
        },
        returns = { type = "ActionResult<{fillPct, effectiveMax, usedSession}>" },
    },
    CalculateMarker = {
        handler = Progress.CalculateMarker,
        description = "Calculate marker position on progress bar",
        params = {
            { name = "markerValue", type = "number", required = true },
            { name = "max", type = "number", required = true },
        },
        returns = { type = "ActionResult<{markerPct, shouldShow}>" },
    },
    ToPercentage = {
        handler = Progress.ToPercentage,
        description = "Convert raw value to percentage",
        params = {
            { name = "rawValue", type = "number", required = true },
            { name = "baseValue", type = "number", required = true, description = "Value that equals 100%" },
        },
        returns = { type = "ActionResult<{percentage}>" },
    },
})

FenCore.Progress = Progress
return Progress
