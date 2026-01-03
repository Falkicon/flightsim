-- Flightsim Acceleration Logic
-- Uses FenCore for math utilities

local FenCore = _G.FenCore
local Result = FenCore.ActionResult
local Math = FenCore.Math

---@class FlightsimAcceleration
local Acceleration = {}

-- Constants
Acceleration.MAX_DELTA = 30 -- Max delta per update for full bar extension
Acceleration.SMOOTH_OLD_WEIGHT = 0.7
Acceleration.SMOOTH_NEW_WEIGHT = 0.3
Acceleration.STABLE_THRESHOLD = 0.05

--- Calculate raw delta between speed values.
---@param currentSpeed number Current speed (percentage)
---@param lastSpeed number Previous speed (percentage)
---@return ActionResult<{delta: number}>
function Acceleration.CalculateDelta(currentSpeed, lastSpeed)
    if currentSpeed == nil then
        return Result.error("INVALID_INPUT", "currentSpeed is required")
    end
    lastSpeed = lastSpeed or currentSpeed
    return Result.success({ delta = currentSpeed - lastSpeed })
end

--- Smooth a delta value to reduce jitter.
---@param previousSmooth number Previous smoothed value
---@param newDelta number New raw delta
---@param oldWeight? number Weight for old value (default 0.7)
---@return ActionResult<{smoothDelta: number}>
function Acceleration.SmoothDelta(previousSmooth, newDelta, oldWeight)
    previousSmooth = previousSmooth or 0
    newDelta = newDelta or 0
    oldWeight = oldWeight or Acceleration.SMOOTH_OLD_WEIGHT
    local smoothed = Math.SmoothDelta(previousSmooth, newDelta, oldWeight)
    return Result.success({ smoothDelta = smoothed })
end

--- Normalize delta and apply curve.
---@param smoothDelta number Smoothed delta value
---@param maxDelta? number Maximum expected delta (default 30)
---@return ActionResult<{normalized: number, curved: number, direction: string}>
function Acceleration.NormalizeAndCurve(smoothDelta, maxDelta)
    smoothDelta = smoothDelta or 0
    maxDelta = maxDelta or Acceleration.MAX_DELTA

    local normalized = Math.NormalizeDelta(smoothDelta, maxDelta)
    local curved = Math.ApplyCurve(normalized)

    local direction = "stable"
    if math.abs(curved) < Acceleration.STABLE_THRESHOLD then
        direction = "stable"
    elseif curved > 0 then
        direction = "accelerating"
    else
        direction = "decelerating"
    end

    return Result.success({
        normalized = normalized,
        curved = curved,
        direction = direction,
    })
end

--- Calculate bar extent for rendering.
---@param curved number Curved acceleration value (-1 to 1)
---@param barWidth number Total bar width in pixels
---@param barHeight number Bar height in pixels
---@return ActionResult<{width: number, anchorSide: string, offsetX: number, isStable: boolean}>
function Acceleration.CalculateBarExtent(curved, barWidth, barHeight)
    if barWidth == nil or barHeight == nil then
        return Result.error("INVALID_INPUT", "barWidth and barHeight are required")
    end

    curved = curved or 0
    local centerX = barWidth / 2
    local minSize = math.max(barHeight, 2)

    local result = {
        isStable = false,
        width = minSize,
        anchorSide = "CENTER",
        offsetX = 0,
    }

    if math.abs(curved) < Acceleration.STABLE_THRESHOLD then
        result.isStable = true
        result.width = minSize
        result.anchorSide = "CENTER"
        result.offsetX = 0
    elseif curved >= 0 then
        local extentWidth = curved * centerX
        if extentWidth < minSize then extentWidth = minSize end
        result.width = extentWidth
        result.anchorSide = "LEFT"
        result.offsetX = centerX
    else
        local extentWidth = -curved * centerX
        if extentWidth < minSize then extentWidth = minSize end
        result.width = extentWidth
        result.anchorSide = "RIGHT"
        result.offsetX = centerX
    end

    return Result.success(result)
end

--- Full acceleration calculation.
---@param context table {currentSpeed, lastSpeed, previousSmooth, barWidth, barHeight}
---@return ActionResult<AccelBarState>
function Acceleration.Calculate(context)
    if not context then
        return Result.error("INVALID_INPUT", "context is required")
    end

    local currentSpeed = context.currentSpeed or 0
    local lastSpeed = context.lastSpeed
    local previousSmooth = context.previousSmooth or 0
    local barWidth = context.barWidth or 200
    local barHeight = context.barHeight or 4

    local deltaResult = Acceleration.CalculateDelta(currentSpeed, lastSpeed)
    local delta = Result.unwrap(deltaResult).delta

    local smoothResult = Acceleration.SmoothDelta(previousSmooth, delta)
    local smoothDelta = Result.unwrap(smoothResult).smoothDelta

    local curveResult = Acceleration.NormalizeAndCurve(smoothDelta)
    local curveData = Result.unwrap(curveResult)

    local extentResult = Acceleration.CalculateBarExtent(curveData.curved, barWidth, barHeight)
    local extentData = Result.unwrap(extentResult)

    return Result.success({
        delta = delta,
        smoothDelta = smoothDelta,
        normalized = curveData.normalized,
        curved = curveData.curved,
        direction = curveData.direction,
        barWidth = extentData.width,
        anchorSide = extentData.anchorSide,
        offsetX = extentData.offsetX,
        isStable = extentData.isStable,
    })
end

FlightsimLogic = FlightsimLogic or {}
FlightsimLogic.Acceleration = Acceleration
return Acceleration
