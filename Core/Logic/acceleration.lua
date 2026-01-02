-- Flightsim Core Acceleration Logic
-- Pure Lua 5.1 - No WoW dependencies
-- Acceleration delta calculations and bar extent

local Core = FlightsimCore
local Actions = Core.Actions
local Math = Core.Utils.Math

---@class AccelerationLogic
local Acceleration = {}

-- Constants
Acceleration.MAX_DELTA = 30 -- Max delta per update for full bar extension
Acceleration.SMOOTH_OLD_WEIGHT = 0.7 -- Weight for previous value (smoothing)
Acceleration.SMOOTH_NEW_WEIGHT = 0.3 -- Weight for new value (smoothing)
Acceleration.STABLE_THRESHOLD = 0.05 -- Below this, considered "stable"

--- Calculate raw delta between speed values.
---@param currentSpeed number Current speed (percentage)
---@param lastSpeed number Previous speed (percentage)
---@return ActionResult<{delta: number}>
function Acceleration.CalculateDelta(currentSpeed, lastSpeed)
	if currentSpeed == nil then
		return Actions.error("INVALID_INPUT", "currentSpeed is required")
	end

	lastSpeed = lastSpeed or currentSpeed
	local delta = currentSpeed - lastSpeed

	return Actions.success({
		delta = delta,
	})
end

--- Smooth a delta value to reduce jitter.
--- Uses exponential moving average (0.7 old + 0.3 new).
---@param previousSmooth number Previous smoothed value
---@param newDelta number New raw delta
---@param oldWeight? number Weight for old value (default 0.7)
---@return ActionResult<{smoothDelta: number}>
function Acceleration.SmoothDelta(previousSmooth, newDelta, oldWeight)
	previousSmooth = previousSmooth or 0
	newDelta = newDelta or 0
	oldWeight = oldWeight or Acceleration.SMOOTH_OLD_WEIGHT

	local smoothed = Math.SmoothDelta(previousSmooth, newDelta, oldWeight)

	return Actions.success({
		smoothDelta = smoothed,
	})
end

--- Normalize delta to -1 to 1 range and apply curve.
---@param smoothDelta number Smoothed delta value
---@param maxDelta? number Maximum expected delta (default 30)
---@return ActionResult<{normalized: number, curved: number, direction: string}>
function Acceleration.NormalizeAndCurve(smoothDelta, maxDelta)
	smoothDelta = smoothDelta or 0
	maxDelta = maxDelta or Acceleration.MAX_DELTA

	-- Normalize to -1 to 1
	local normalized = Math.NormalizeDelta(smoothDelta, maxDelta)

	-- Apply sqrt curve: more sensitive near zero, compressed at extremes
	local curved = Math.ApplyCurve(normalized)

	-- Determine direction
	local direction = "stable"
	if math.abs(curved) < Acceleration.STABLE_THRESHOLD then
		direction = "stable"
	elseif curved > 0 then
		direction = "accelerating"
	else
		direction = "decelerating"
	end

	return Actions.success({
		normalized = normalized,
		curved = curved,
		direction = direction,
	})
end

--- Calculate bar extent for rendering.
--- Returns width and anchor point based on acceleration.
---@param curved number Curved acceleration value (-1 to 1)
---@param barWidth number Total bar width in pixels
---@param barHeight number Bar height in pixels
---@return ActionResult<{width: number, anchorSide: string, offsetX: number, isStable: boolean}>
function Acceleration.CalculateBarExtent(curved, barWidth, barHeight)
	if barWidth == nil or barHeight == nil then
		return Actions.error("INVALID_INPUT", "barWidth and barHeight are required")
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
		-- Stable: small centered square
		result.isStable = true
		result.width = minSize
		result.anchorSide = "CENTER"
		result.offsetX = 0
	elseif curved >= 0 then
		-- Accelerating: bar extends right from center
		local extentWidth = curved * centerX
		if extentWidth < minSize then
			extentWidth = minSize
		end
		result.width = extentWidth
		result.anchorSide = "LEFT"
		result.offsetX = centerX
	else
		-- Decelerating: bar extends left from center
		local extentWidth = -curved * centerX
		if extentWidth < minSize then
			extentWidth = minSize
		end
		result.width = extentWidth
		result.anchorSide = "RIGHT"
		result.offsetX = centerX
	end

	return Actions.success(result)
end

--- Full acceleration calculation (combines all above).
---@param context table {currentSpeed, lastSpeed, previousSmooth, barWidth, barHeight}
---@return ActionResult<AccelBarState>
function Acceleration.Calculate(context)
	if not context then
		return Actions.error("INVALID_INPUT", "context is required")
	end

	local currentSpeed = context.currentSpeed or 0
	local lastSpeed = context.lastSpeed
	local previousSmooth = context.previousSmooth or 0
	local barWidth = context.barWidth or 200
	local barHeight = context.barHeight or 4

	-- Calculate raw delta
	local deltaResult = Acceleration.CalculateDelta(currentSpeed, lastSpeed)
	local delta = Actions.unwrap(deltaResult).delta

	-- Smooth the delta
	local smoothResult = Acceleration.SmoothDelta(previousSmooth, delta)
	local smoothDelta = Actions.unwrap(smoothResult).smoothDelta

	-- Normalize and curve
	local curveResult = Acceleration.NormalizeAndCurve(smoothDelta)
	local curveData = Actions.unwrap(curveResult)

	-- Calculate bar extent
	local extentResult = Acceleration.CalculateBarExtent(curveData.curved, barWidth, barHeight)
	local extentData = Actions.unwrap(extentResult)

	return Actions.success({
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

Core.Logic.Acceleration = Acceleration
return Acceleration
