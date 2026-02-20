-- Flightsim Pitch Logic
-- Estimates vertical flight angle via Pythagorean triangulation:
--   totalSpeed (from API) vs horizontalSpeed (from UnitPosition XY deltas)
--   verticalSpeed = sqrt(total² - horizontal²)
-- Direction inferred from speed trend (gaining = diving, losing = climbing)
-- Uses FenCore for ActionResult pattern

local FenCore = _G.FenCore
local Math = FenCore.Math

local _staticPitchResult = { success = true, data = nil }

---@class FlightsimPitch
local Pitch = {}

-- Smoothing weight for pitch ratio (higher = more inertia)
Pitch.SMOOTH_WEIGHT = 0.75

-- Smoothing weight for speed trend (direction stability)
Pitch.TREND_SMOOTH_WEIGHT = 0.80

-- Below this ratio, flight is considered level (0-1 range)
-- 0.02 = need ~1° pitch before the bar moves
Pitch.STABLE_THRESHOLD = 0.02

-- Pitch ratio that maps to "full bar" (100%).
-- sin(50°) ≈ 0.77 — very steep dive. Gives room for 45° to be ~70% bar.
Pitch.MAX_PITCH_RATIO = 0.77

-- Below this total speed (yards/sec), pitch is indeterminate
Pitch.MIN_SPEED = 5

-- Minimum bar width in pixels
Pitch.MIN_BAR_WIDTH = 2

--- Calculate pitch indicator state via triangulation.
--- Returns bar geometry for a bidirectional pitch indicator.
---@param input table {totalSpeed, horizontalSpeed, previousSmooth, previousTrend, speedTrend, barWidth}
---@return ActionResult<PitchBarData>
function Pitch.Calculate(input)
	if not input then
		return Result.error("INVALID_INPUT", "input is required")
	end

	local totalSpeed = input.totalSpeed or 0
	local horizontalSpeed = input.horizontalSpeed or 0
	local previousSmooth = input.previousSmooth or 0
	local previousTrend = input.previousTrend or 0
	local speedTrend = input.speedTrend or 0
	local barWidth = input.barWidth or 200

	-- Too slow to estimate pitch (on ground, hovering, mounting up)
	if totalSpeed < Pitch.MIN_SPEED then
		local resultData = outData or {}
		resultData.shouldHide = true
		resultData.smoothRatio = previousSmooth * 0.95 -- gentle decay toward zero
		resultData.smoothTrend = previousTrend * 0.95
		
		_staticPitchResult.data = resultData
		return _staticPitchResult
	end

	-- Clamp horizontal to total (floating-point overshoot / timing jitter safety)
	-- Use min of raw horiz and total, but also don't let stale horiz exceed current total
	horizontalSpeed = math.min(horizontalSpeed, totalSpeed * 1.0)

	-- Vertical speed via Pythagorean triangulation
	local verticalSpeed = math.sqrt(math.max(0, totalSpeed * totalSpeed - horizontalSpeed * horizontalSpeed))

	-- Pitch ratio: 0 = perfectly level, 1 = straight up/down
	local pitchRatio = verticalSpeed / totalSpeed

	-- Smooth the ratio for visual stability
	local smoothRatio = (Pitch.SMOOTH_WEIGHT * previousSmooth) + ((1 - Pitch.SMOOTH_WEIGHT) * pitchRatio)

	-- Smooth the speed trend for direction stability
	local smoothTrend = (Pitch.TREND_SMOOTH_WEIGHT * previousTrend) + ((1 - Pitch.TREND_SMOOTH_WEIGHT) * speedTrend)

	-- Level flight check
	local isStable = smoothRatio < Pitch.STABLE_THRESHOLD

	-- Direction from smoothed speed trend (physics: diving gains speed, climbing loses it)
	-- Require a minimum trend magnitude to avoid flipping on noise
	local TREND_DEAD_ZONE = 0.05
	local direction
	if isStable then
		direction = "level"
	elseif math.abs(smoothTrend) < TREND_DEAD_ZONE then
		-- Trend too weak to determine direction; show level
		direction = "level"
	elseif smoothTrend > 0 then
		direction = "diving"
	else
		direction = "climbing"
	end

	-- Bar geometry (bidirectional from center)
	local width, anchorSide, offsetX = Pitch.CalculateBarExtent(smoothRatio, direction, barWidth)

	local resultData = outData or {}
	resultData.shouldHide = false
	resultData.smoothRatio = smoothRatio
	resultData.smoothTrend = smoothTrend
	resultData.isStable = isStable
	resultData.direction = direction
	resultData.width = width
	resultData.anchorSide = anchorSide
	resultData.offsetX = offsetX

	_staticPitchResult.data = resultData
	return _staticPitchResult
end

--- Calculate the bar rendering geometry for a bidirectional pitch bar.
---@param smoothRatio number Smoothed pitch ratio (0-1)
---@param direction string "diving", "climbing", or "level"
---@param barWidth number Total bar width in pixels
---@return table {width: number, anchorSide: string, offsetX: number}
function Pitch.CalculateBarExtent(smoothRatio, direction, barWidth)
	local halfWidth = barWidth / 2

	-- Subtract dead zone and normalize to 0-1 within usable range
	local range = Pitch.MAX_PITCH_RATIO - Pitch.STABLE_THRESHOLD
	local effective = Math.Clamp(smoothRatio - Pitch.STABLE_THRESHOLD, 0, range)
	local normalized = effective / range

	-- Gentle curve: sqrt for visible response at moderate angles
	local curved = math.sqrt(normalized)
	local barW = math.max(Pitch.MIN_BAR_WIDTH, math.floor(curved * halfWidth))

	local centerX = halfWidth
	if direction == "diving" then
		-- Bar extends RIGHT from center
		return barW, "LEFT", centerX
	elseif direction == "climbing" then
		-- Bar extends LEFT from center
		return barW, "RIGHT", centerX
	else
		-- Level: small centered bar
		return Pitch.MIN_BAR_WIDTH, "CENTER", 0
	end
end

FlightsimLogic = FlightsimLogic or {}
FlightsimLogic.Pitch = Pitch
return Pitch
