-- Flightsim Speed Logic
-- Uses FenCore for generic progress/math, adds Flightsim-specific constants

local FenCore = _G.FenCore
local Result = FenCore.ActionResult
local Math = FenCore.Math
local Progress = FenCore.Progress

---@class FlightsimSpeed
local Speed = {}

-- Constants
Speed.BASE_SPEED_FOR_PCT = 7.0 -- Walking speed in y/s (100% baseline, matches WoW tooltips)

-- Base speed values (Dragon Isles / uncapped) - using walking speed baseline
Speed.BASE_SUSTAINABLE = 929 -- Cruise speed in Dragon Isles (65 y/s)
Speed.BASE_MAX = 976 -- Max tooltip speed in Dragon Isles (~68.3 y/s)
Speed.BASE_THRILL = 1007 -- Thrill of the Skies threshold in Dragon Isles (~70.5 y/s)

-- Zone modifier for Old World / TWW (85% of Dragon Isles speeds)
Speed.OLD_WORLD_MODIFIER = 0.85

-- Map IDs where speed is uncapped (Dragon Isles ecosystem)
-- Uses Map IDs from C_Map.GetBestMapForUnit("player"), NOT Instance IDs
Speed.DRAGON_ISLES_MAPS = {
	[1978] = true, -- Dragon Isles (Continent)
	[2022] = true, -- The Waking Shores
	[2023] = true, -- Ohn'ahran Plains
	[2024] = true, -- The Azure Span
	[2025] = true, -- Thaldraszus
	[2151] = true, -- The Forbidden Reach
	[2133] = true, -- Zaralek Cavern
	[2200] = true, -- Emerald Dream
}

--- Check if a map ID is in Dragon Isles (uncapped speed).
---@param mapID number Map ID from C_Map.GetBestMapForUnit
---@return boolean
function Speed.IsDragonIslesMap(mapID)
	return Speed.DRAGON_ISLES_MAPS[mapID] == true
end

--- Get zone modifier for speed calculations.
--- Returns 1.0 for Dragon Isles, 0.85 for Old World / TWW.
---@param mapID number|nil Map ID (if nil, assumes Old World)
---@return number modifier (1.0 or 0.85)
function Speed.GetZoneModifier(mapID)
	if mapID and Speed.DRAGON_ISLES_MAPS[mapID] then
		return 1.0
	end
	return Speed.OLD_WORLD_MODIFIER
end

--- Get sustainable (cruise) speed for current zone.
---@param zoneModifier number Zone modifier (1.0 or 0.85)
---@return number sustainableSpeed (789 or 671)
function Speed.GetSustainableSpeed(zoneModifier)
	return Speed.BASE_SUSTAINABLE * (zoneModifier or Speed.OLD_WORLD_MODIFIER)
end

--- Get max speed for current zone.
---@param zoneModifier number Zone modifier (1.0 or 0.85)
---@return number maxSpeed (830 or 705)
function Speed.GetMaxSpeed(zoneModifier)
	return Speed.BASE_MAX * (zoneModifier or Speed.OLD_WORLD_MODIFIER)
end

--- Get Thrill of the Skies threshold for current zone.
---@param zoneModifier number Zone modifier (1.0 or 0.85)
---@return number thrillSpeed (855 or 727)
function Speed.GetThrillThreshold(zoneModifier)
	return Speed.BASE_THRILL * (zoneModifier or Speed.OLD_WORLD_MODIFIER)
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

--- Full speed bar calculation.
---@param context table {rawSpeed, zoneModifier, configuredMax, sessionMax}
---@return ActionResult<SpeedBarState>
function Speed.Calculate(context)
	if not context then
		return Result.error("INVALID_INPUT", "context is required")
	end

	local rawSpeed = context.rawSpeed or 0
	local zoneModifier = context.zoneModifier or Speed.OLD_WORLD_MODIFIER
	local configuredMax = context.configuredMax or 950
	local sessionMax = context.sessionMax

	-- Calculate percentage directly (no adjustment - GetGlidingInfo is accurate)
	local pctResult = Speed.CalculatePercentage(rawSpeed)
	local speedPct = Result.unwrap(pctResult).percentage

	-- Calculate zone-aware sustainable speed for marker
	local sustainableSpeed = Speed.GetSustainableSpeed(zoneModifier)

	-- Use FenCore.Progress for fill calculation with session max
	local fillResult = Progress.CalculateFillWithSessionMax(speedPct, configuredMax, sessionMax)
	local fillData = Result.unwrap(fillResult)

	-- Use FenCore.Progress for marker calculation
	local markerResult = Progress.CalculateMarker(sustainableSpeed, fillData.effectiveMax)
	local markerData = Result.unwrap(markerResult)

	return Result.success({
		rawSpeed = rawSpeed,
		speedPct = speedPct,
		effectiveMax = fillData.effectiveMax,
		fillPct = fillData.fillPct,
		markerPct = markerData.markerPct,
		showMarker = markerData.shouldShow,
		sustainableSpeed = sustainableSpeed,
		zoneModifier = zoneModifier,
	})
end

-- Export to Flightsim namespace
FlightsimLogic = FlightsimLogic or {}
FlightsimLogic.Speed = Speed
return Speed
