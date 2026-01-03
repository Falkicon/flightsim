-- Flightsim Speed Logic
-- Uses FenCore for generic progress/math, adds Flightsim-specific constants

local FenCore = _G.FenCore
local Result = FenCore.ActionResult
local Math = FenCore.Math
local Progress = FenCore.Progress

---@class FlightsimSpeed
local Speed = {}

-- Constants (matching WA-style calculations)
Speed.BASE_SPEED_FOR_PCT = 8.24 -- Approx 100% mounted ground speed in y/s
Speed.SLOW_SKYRIDING_RATIO = 705 / 830 -- Speed reduction in Dragon Isles

-- Zone IDs where skyriding is slower (Dragon Isles, Zaralek, etc.)
Speed.FAST_FLYING_ZONES = {
    [2444] = true, -- Dragon Isles
    [2454] = true, -- Zaralek Cavern
    [2548] = true, -- Emerald Dream
    [2516] = true, -- Nokhud Offensive
    [2522] = true, -- Vault of the Incarnates
    [2569] = true, -- Aberrus, the Shadowed Crucible
}

--- Check if a zone is a slow skyriding zone.
---@param zoneID number Instance/zone ID
---@return boolean
function Speed.IsSlowSkyridingZone(zoneID)
    return Speed.FAST_FLYING_ZONES[zoneID] == true
end

--- Calculate speed percentage from raw yards/sec.
---@param rawSpeed number Raw speed in yards/second
---@param baseSpeed? number Base speed for 100% (default 8.24)
---@return ActionResult<{percentage: number, rawSpeed: number}>
function Speed.CalculatePercentage(rawSpeed, baseSpeed)
    if rawSpeed == nil then
        return Result.error("INVALID_INPUT", "rawSpeed is required")
    end

    baseSpeed = baseSpeed or Speed.BASE_SPEED_FOR_PCT
    if baseSpeed <= 0 then
        baseSpeed = Speed.BASE_SPEED_FOR_PCT
    end

    local pct = (rawSpeed / baseSpeed) * 100

    return Result.success({
        percentage = pct,
        rawSpeed = rawSpeed,
    })
end

--- Adjust speed for slow skyriding zones (Dragon Isles).
---@param rawSpeed number Raw speed in yards/second
---@param isSlowZone boolean Whether current zone has slow skyriding
---@return ActionResult<{adjustedSpeed: number, wasAdjusted: boolean}>
function Speed.AdjustForZone(rawSpeed, isSlowZone)
    if rawSpeed == nil then
        return Result.error("INVALID_INPUT", "rawSpeed is required")
    end

    if isSlowZone then
        local adjusted = rawSpeed / Speed.SLOW_SKYRIDING_RATIO
        return Result.success({
            adjustedSpeed = adjusted,
            wasAdjusted = true,
        })
    end

    return Result.success({
        adjustedSpeed = rawSpeed,
        wasAdjusted = false,
    })
end

--- Full speed bar calculation.
---@param context table {rawSpeed, isSlowZone, configuredMax, sessionMax, sustainableSpeed}
---@return ActionResult<SpeedBarState>
function Speed.Calculate(context)
    if not context then
        return Result.error("INVALID_INPUT", "context is required")
    end

    local rawSpeed = context.rawSpeed or 0
    local isSlowZone = context.isSlowZone or false
    local configuredMax = context.configuredMax or 950
    local sessionMax = context.sessionMax
    local sustainableSpeed = context.sustainableSpeed or 0

    -- Adjust for zone
    local zoneResult = Speed.AdjustForZone(rawSpeed, isSlowZone)
    local adjustedSpeed = Result.unwrap(zoneResult).adjustedSpeed

    -- Calculate percentage
    local pctResult = Speed.CalculatePercentage(adjustedSpeed)
    local speedPct = Result.unwrap(pctResult).percentage

    -- Use FenCore.Progress for fill calculation with session max
    local fillResult = Progress.CalculateFillWithSessionMax(speedPct, configuredMax, sessionMax)
    local fillData = Result.unwrap(fillResult)

    -- Use FenCore.Progress for marker calculation
    local markerResult = Progress.CalculateMarker(sustainableSpeed, fillData.effectiveMax)
    local markerData = Result.unwrap(markerResult)

    return Result.success({
        rawSpeed = rawSpeed,
        adjustedSpeed = adjustedSpeed,
        speedPct = speedPct,
        effectiveMax = fillData.effectiveMax,
        fillPct = fillData.fillPct,
        markerPct = markerData.markerPct,
        showMarker = markerData.shouldShow,
        isSlowZone = isSlowZone,
    })
end

-- Export to Flightsim namespace
FlightsimLogic = FlightsimLogic or {}
FlightsimLogic.Speed = Speed
return Speed
