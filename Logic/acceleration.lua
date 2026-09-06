-- Flightsim Acceleration Logic
-- Uses FenCore for math utilities

local FenCore = _G.FenCore
local Result = FenCore.ActionResult
local Math = FenCore.Math

local _staticAccelResult = { success = true, data = nil }

---@class FlightsimAcceleration
local Acceleration = {}

-- Constants
Acceleration.REFERENCE_INTERVAL = 0.05 -- Preserve the original response at 20Hz.
Acceleration.MAX_SAMPLE_GAP = 1 -- Treat long pauses as a new sample stream.
Acceleration.MAX_DELTA = 30 -- Speed change per reference interval for full extension.
Acceleration.SMOOTH_OLD_WEIGHT = 0.7
Acceleration.SMOOTH_NEW_WEIGHT = 0.3
Acceleration.STABLE_THRESHOLD = 0.05

--- Calculate raw delta between speed values.
---@param currentSpeed number Current speed (percentage)
---@param lastSpeed number Previous speed (percentage)
---@return number delta
function Acceleration.CalculateDelta(currentSpeed, lastSpeed)
	if currentSpeed == nil then
		return 0
	end
	lastSpeed = lastSpeed or currentSpeed
	return currentSpeed - lastSpeed
end

--- Smooth a delta value to reduce jitter.
---@param previousSmooth number Previous smoothed value
---@param newDelta number New raw delta
---@param oldWeight? number Weight for old value (default 0.7)
---@param deltaTime? number Elapsed seconds (defaults to the reference interval)
---@return number smoothDelta
function Acceleration.SmoothDelta(previousSmooth, newDelta, oldWeight, deltaTime)
	previousSmooth = previousSmooth or 0
	newDelta = newDelta or 0
	oldWeight = oldWeight or Acceleration.SMOOTH_OLD_WEIGHT
	if deltaTime then
		oldWeight = oldWeight ^ (deltaTime / Acceleration.REFERENCE_INTERVAL)
	end
	return Math.SmoothDelta(previousSmooth, newDelta, oldWeight)
end

--- Normalize delta and apply curve.
---@param smoothDelta number Smoothed delta value
---@param maxDelta? number Maximum expected delta (default 30)
---@return number normalized, number curved, string direction
function Acceleration.NormalizeAndCurve(smoothDelta, maxDelta)
	smoothDelta = smoothDelta or 0
	maxDelta = maxDelta or Acceleration.MAX_DELTA

	local normalized = Math.NormalizeDelta(smoothDelta, maxDelta)
	local curved = Math.ApplyCurve(normalized)

	local direction
	if math.abs(curved) < Acceleration.STABLE_THRESHOLD then
		direction = "stable"
	elseif curved > 0 then
		direction = "accelerating"
	else
		direction = "decelerating"
	end

	return normalized, curved, direction
end

--- Calculate bar extent for rendering.
---@param curved number Curved acceleration value (-1 to 1)
---@param barWidth number Total bar width in pixels
---@param barHeight number Bar height in pixels
---@return number width, string anchorSide, number offsetX, boolean isStable
function Acceleration.CalculateBarExtent(curved, barWidth, barHeight)
	if barWidth == nil or barHeight == nil then
		return 2, "CENTER", 0, true
	end

	curved = curved or 0
	local centerX = barWidth / 2
	local minSize = math.max(barHeight, 2)

	if math.abs(curved) < Acceleration.STABLE_THRESHOLD then
		return minSize, "CENTER", 0, true
	elseif curved >= 0 then
		local extentWidth = curved * centerX
		if extentWidth < minSize then
			extentWidth = minSize
		end
		return extentWidth, "LEFT", centerX, false
	else
		local extentWidth = -curved * centerX
		if extentWidth < minSize then
			extentWidth = minSize
		end
		return extentWidth, "RIGHT", centerX, false
	end
end

--- Full acceleration calculation.
---@param context table {currentSpeed, lastSpeed, previousSmooth, barWidth, barHeight, deltaTime?}
---@return ActionResult<AccelBarState>
function Acceleration.Calculate(context, outData)
	if not context then
		return Result.error("INVALID_INPUT", "context is required")
	end

	local currentSpeed = context.currentSpeed or 0
	local lastSpeed = context.lastSpeed
	local previousSmooth = context.previousSmooth or 0
	local barWidth = context.barWidth or 200
	local barHeight = context.barHeight or 4

	local delta = Acceleration.CalculateDelta(currentSpeed, lastSpeed)
	local deltaTime = context.deltaTime
	if deltaTime == nil then
		deltaTime = Acceleration.REFERENCE_INTERVAL
	end
	local smoothDelta
	if deltaTime ~= deltaTime or deltaTime > Acceleration.MAX_SAMPLE_GAP or lastSpeed == nil then
		-- Never infer acceleration across a pause, a mount transition, or a missing sample.
		delta = 0
		smoothDelta = 0
	elseif deltaTime <= 0 then
		delta = 0
		smoothDelta = previousSmooth
	else
		-- Keep the historic units while making the signal proportional to speed/second.
		local referenceDelta = delta * Acceleration.REFERENCE_INTERVAL / deltaTime
		smoothDelta = Acceleration.SmoothDelta(previousSmooth, referenceDelta, nil, deltaTime)
	end
	local normalized, curved, direction = Acceleration.NormalizeAndCurve(smoothDelta)
	local extentWidth, anchorSide, offsetX, isStable = Acceleration.CalculateBarExtent(curved, barWidth, barHeight)

	local resultData = outData or {}
	resultData.delta = delta
	resultData.smoothDelta = smoothDelta
	resultData.normalized = normalized
	resultData.curved = curved
	resultData.direction = direction
	resultData.barWidth = extentWidth
	resultData.anchorSide = anchorSide
	resultData.offsetX = offsetX
	resultData.isStable = isStable

	_staticAccelResult.data = resultData
	return _staticAccelResult
end

FlightsimLogic = FlightsimLogic or {}
FlightsimLogic.Acceleration = Acceleration
return Acceleration
