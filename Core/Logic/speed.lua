-- Flightsim Core Speed Logic
-- Pure Lua 5.1 - No WoW dependencies
-- All speed calculations and state management

local Core = FlightsimCore
local Actions = Core.Actions
local Math = Core.Utils.Math

---@class SpeedLogic
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

--- Calculate speed percentage from raw yards/sec.
--- WA-style: ~790% at stable skyriding, ~950% at max.
---@param rawSpeed number Raw speed in yards/second
---@param baseSpeed? number Base speed for 100% (default 8.24)
---@return ActionResult<{percentage: number, rawSpeed: number}>
function Speed.CalculatePercentage(rawSpeed, baseSpeed)
	if rawSpeed == nil then
		return Actions.error("INVALID_INPUT", "rawSpeed is required")
	end

	baseSpeed = baseSpeed or Speed.BASE_SPEED_FOR_PCT
	if baseSpeed <= 0 then
		baseSpeed = Speed.BASE_SPEED_FOR_PCT
	end

	local pct = (rawSpeed / baseSpeed) * 100

	return Actions.success({
		percentage = pct,
		rawSpeed = rawSpeed,
	}, string.format("%.1f y/s = %.0f%%", rawSpeed, pct))
end

--- Adjust speed for slow skyriding zones (Dragon Isles).
---@param rawSpeed number Raw speed in yards/second
---@param isSlowZone boolean Whether current zone has slow skyriding
---@return ActionResult<{adjustedSpeed: number, wasAdjusted: boolean}>
function Speed.AdjustForZone(rawSpeed, isSlowZone)
	if rawSpeed == nil then
		return Actions.error("INVALID_INPUT", "rawSpeed is required")
	end

	if isSlowZone then
		local adjusted = rawSpeed / Speed.SLOW_SKYRIDING_RATIO
		return Actions.success({
			adjustedSpeed = adjusted,
			wasAdjusted = true,
		})
	end

	return Actions.success({
		adjustedSpeed = rawSpeed,
		wasAdjusted = false,
	})
end

--- Get effective max speed for bar scaling.
--- Uses session max if higher than configured max.
---@param configuredMax number User-configured max speed (percentage)
---@param sessionMax? number Session observed max (percentage)
---@return ActionResult<{effectiveMax: number, usedSession: boolean}>
function Speed.GetEffectiveMax(configuredMax, sessionMax)
	if configuredMax == nil or configuredMax <= 0 then
		configuredMax = 950 -- Default max
	end

	local effectiveMax = configuredMax
	local usedSession = false

	if sessionMax and sessionMax > configuredMax then
		effectiveMax = sessionMax
		usedSession = true
	end

	if effectiveMax <= 0 then
		effectiveMax = 1
	end

	return Actions.success({
		effectiveMax = effectiveMax,
		usedSession = usedSession,
	})
end

--- Calculate bar fill percentage for display.
---@param speedPct number Current speed percentage
---@param effectiveMax number Maximum speed for scaling
---@return ActionResult<{fillPct: number, isAtMax: boolean}>
function Speed.CalculateBarFill(speedPct, effectiveMax)
	if speedPct == nil then
		return Actions.error("INVALID_INPUT", "speedPct is required")
	end
	if effectiveMax == nil or effectiveMax <= 0 then
		effectiveMax = 950
	end

	local fillPct = Math.Clamp(speedPct / effectiveMax, 0, 1)
	local isAtMax = fillPct >= 0.99

	return Actions.success({
		fillPct = fillPct,
		isAtMax = isAtMax,
	})
end

--- Calculate sustainable marker position.
---@param sustainableSpeed number Sustainable speed percentage
---@param effectiveMax number Maximum speed for scaling
---@return ActionResult<{markerPct: number, shouldShow: boolean}>
function Speed.CalculateSustainableMarker(sustainableSpeed, effectiveMax)
	if sustainableSpeed == nil or sustainableSpeed <= 0 then
		return Actions.success({
			markerPct = 0,
			shouldShow = false,
		})
	end

	if effectiveMax == nil or effectiveMax <= 0 then
		effectiveMax = 950
	end

	local markerPct = Math.Clamp(sustainableSpeed / effectiveMax, 0, 1)

	return Actions.success({
		markerPct = markerPct,
		shouldShow = true,
	})
end

--- Check if a zone is a slow skyriding zone.
---@param zoneID number Instance/zone ID
---@return boolean
function Speed.IsSlowSkyridingZone(zoneID)
	return Speed.FAST_FLYING_ZONES[zoneID] == true
end

--- Full speed bar calculation (combines all above).
---@param context table {rawSpeed, isSlowZone, configuredMax, sessionMax, sustainableSpeed}
---@return ActionResult<SpeedBarState>
function Speed.Calculate(context)
	if not context then
		return Actions.error("INVALID_INPUT", "context is required")
	end

	local rawSpeed = context.rawSpeed or 0
	local isSlowZone = context.isSlowZone or false
	local configuredMax = context.configuredMax or 950
	local sessionMax = context.sessionMax
	local sustainableSpeed = context.sustainableSpeed or 0

	-- Adjust for zone
	local zoneResult = Speed.AdjustForZone(rawSpeed, isSlowZone)
	local adjustedSpeed = Actions.unwrap(zoneResult).adjustedSpeed

	-- Calculate percentage
	local pctResult = Speed.CalculatePercentage(adjustedSpeed)
	local speedPct = Actions.unwrap(pctResult).percentage

	-- Get effective max
	local maxResult = Speed.GetEffectiveMax(configuredMax, sessionMax)
	local effectiveMax = Actions.unwrap(maxResult).effectiveMax

	-- Calculate bar fill
	local fillResult = Speed.CalculateBarFill(speedPct, effectiveMax)
	local fillPct = Actions.unwrap(fillResult).fillPct

	-- Calculate sustainable marker
	local markerResult = Speed.CalculateSustainableMarker(sustainableSpeed, effectiveMax)
	local markerData = Actions.unwrap(markerResult)

	return Actions.success({
		rawSpeed = rawSpeed,
		adjustedSpeed = adjustedSpeed,
		speedPct = speedPct,
		effectiveMax = effectiveMax,
		fillPct = fillPct,
		markerPct = markerData.markerPct,
		showMarker = markerData.shouldShow,
		isSlowZone = isSlowZone,
	})
end

Core.Logic = Core.Logic or {}
Core.Logic.Speed = Speed
return Speed
