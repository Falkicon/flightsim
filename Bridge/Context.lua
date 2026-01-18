-- Flightsim Bridge: Context Builder
-- Queries WoW APIs and builds context tables for Logic layer
-- All WoW API calls happen here - Logic receives clean data

local Bridge = FlightsimBridge
local FenCore = _G.FenCore
local Secrets = FenCore.Secrets
local SpeedLogic = FlightsimLogic.Speed

---@class ContextModule
local Context = {}

-- Spell IDs for ability tracking
local SURGE_FORWARD_SPELL_ID = 372608
local SECOND_WIND_SPELL_ID = 425782
local WHIRLING_SURGE_SPELL_ID = 361584 -- Whitelisted for C_Spell in 12.0

-- Caching
local _skyridingCacheTime = nil
local _skyridingCacheResult = nil
local _zoneModifier = nil

--- Get unit speed safely (handles both C_* and legacy APIs).
---@param unit string Unit ID (default "player")
---@return number|secret speed Raw speed value
function Context.GetUnitSpeed(unit)
	unit = unit or "player"
	local speed = 0

	if type(GetUnitSpeed) == "function" then
		speed = GetUnitSpeed(unit)
	elseif type(UnitSpeed) == "function" then
		speed = UnitSpeed(unit)
	end

	return speed or 0
end

--- Get zone modifier for speed calculations.
--- Uses Map IDs with parent traversal for sub-zones/delves.
---@return number modifier (1.0 for Dragon Isles, 0.85 for Old World/TWW)
function Context.GetZoneModifier()
	local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	if not mapID then
		return SpeedLogic.OLD_WORLD_MODIFIER
	end

	-- Check direct match
	if SpeedLogic.IsDragonIslesMap(mapID) then
		return 1.0
	end

	-- Check parent maps (for sub-zones/delves inside Dragon Isles)
	if C_Map and C_Map.GetMapInfo then
		local mapInfo = C_Map.GetMapInfo(mapID)
		while mapInfo and mapInfo.parentMapID do
			if SpeedLogic.IsDragonIslesMap(mapInfo.parentMapID) then
				return 1.0
			end
			mapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
		end
	end

	return SpeedLogic.OLD_WORLD_MODIFIER
end

--- Update zone modifier state (called on zone change).
function Context.UpdateZoneState()
	_zoneModifier = Context.GetZoneModifier()
end

--- Get the cached zone modifier.
---@return number modifier (1.0 or 0.85)
function Context.GetCachedZoneModifier()
	if _zoneModifier == nil then
		Context.UpdateZoneState()
	end
	return _zoneModifier or SpeedLogic.OLD_WORLD_MODIFIER
end

--- Check if player is in Druid flight form.
---@return boolean isDruidFlying
function Context.IsInDruidFlightForm()
	local _, class = UnitClass("player")
	if class ~= "DRUID" then
		return false
	end

	local form = GetShapeshiftForm()
	-- Form 3 is Travel Form (includes Flight Form)
	if
		form == 3 and (IsFlying() or (C_PlayerInfo and C_PlayerInfo.GetGlidingInfo and C_PlayerInfo.GetGlidingInfo()))
	then
		return true
	end

	return false
end

--- Get skyriding speed from GlidingInfo API.
---@return number|secret speed, boolean isGliding, boolean canGlide
function Context.GetSkyridingSpeed()
	if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
		local ok, isGliding, canGlide, speed = pcall(C_PlayerInfo.GetGlidingInfo)
		if ok then
			return speed or 0, isGliding or false, canGlide or false
		end
	end
	return 0, false, false
end

--- Check if skyriding is currently active.
--- Caches result per frame to avoid repeated API calls.
---@param forceRefresh? boolean Force cache refresh
---@return boolean isActive
function Context.IsSkyridingActive(forceRefresh)
	local now = GetTime()

	-- Use cache if valid (same frame)
	if not forceRefresh and _skyridingCacheTime and (now - _skyridingCacheTime) < 0.05 then
		return _skyridingCacheResult or false
	end

	local result = false

	local ok = pcall(function()
		-- Check mount or druid form first
		local isMounted = IsMounted()
		local isDruidFlying = Context.IsInDruidFlightForm()

		if not isMounted and not isDruidFlying then
			result = false
			return
		end

		-- Check gliding state
		if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
			local isGliding, canGlide = C_PlayerInfo.GetGlidingInfo()
			if canGlide then
				result = true
				return
			end
		end

		-- Fallback: check Surge Forward charges (reliable for skyriding detection)
		if C_Spell and C_Spell.GetSpellCharges then
			local chargeInfo = C_Spell.GetSpellCharges(SURGE_FORWARD_SPELL_ID)
			if chargeInfo and chargeInfo.maxCharges then
				local max = chargeInfo.maxCharges
				if not Secrets.IsSecret(max) and max > 0 then
					result = true
					return
				end
			end
		end
	end)

	if not ok then
		result = false
	end

	_skyridingCacheTime = now
	_skyridingCacheResult = result
	return result
end

--- Invalidate skyriding cache (called on mount events).
function Context.InvalidateSkyridingCache()
	_skyridingCacheTime = nil
	_skyridingCacheResult = nil
end

--- Get spell charges safely.
---@param spellID number Spell ID
---@return table chargeInfo {currentCharges, maxCharges, chargeStart, chargeDuration, isSecret}
function Context.GetSpellCharges(spellID)
	local result = {
		currentCharges = 0,
		maxCharges = 0,
		chargeStart = 0,
		chargeDuration = 0,
		isSecret = false,
	}

	local ok, info = pcall(C_Spell.GetSpellCharges, spellID)
	if ok and info then
		result.currentCharges = info.currentCharges
		result.maxCharges = info.maxCharges
		result.chargeStart = info.cooldownStartTime or 0
		result.chargeDuration = info.cooldownDuration or 0
		result.isSecret = Secrets.IsSecret(info.currentCharges) or Secrets.IsSecret(info.maxCharges)
	end

	return result
end

--- Get spell cooldown safely.
---@param spellID number Spell ID
---@return table cooldownInfo {startTime, duration, enabled, isSecret}
function Context.GetSpellCooldown(spellID)
	local result = {
		startTime = 0,
		duration = 0,
		enabled = true,
		isSecret = false,
	}

	local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
	if ok and info then
		result.startTime = info.startTime or 0
		result.duration = info.duration or 0
		-- Handle potentially secret isEnabled value
		if Secrets.IsSecret(info.isEnabled) then
			result.enabled = true -- Assume enabled for secrets
			result.isSecret = true
		else
			result.enabled = info.isEnabled ~= false
			result.isSecret = Secrets.IsSecret(info.startTime) or Secrets.IsSecret(info.duration)
		end
	end

	return result
end

--- Check if a spell is usable (fallback for secret values).
---@param spellID number Spell ID
---@return boolean isUsable
function Context.IsSpellUsable(spellID)
	if C_Spell and C_Spell.IsSpellUsable then
		local ok, usable = pcall(C_Spell.IsSpellUsable, spellID)
		if ok then
			return usable or false
		end
	end
	return false
end

---@class FlightsimContext
---@field now number Current GetTime()
---@field deltaTime number Time since last frame
---@field player PlayerContext
---@field abilities AbilityContext
---@field zone ZoneContext
---@field db table SavedVariables reference

--- Build complete context for a frame update.
---@param db table SavedVariables database
---@param lastFrameTime? number Time of last frame (for deltaTime)
---@return FlightsimContext
function Context.Build(db, lastFrameTime)
	local now = GetTime()
	local deltaTime = lastFrameTime and (now - lastFrameTime) or 0

	-- Get speed
	local rawSpeed = Context.GetUnitSpeed("player")
	local skySpeed, isGliding, canGlide = Context.GetSkyridingSpeed()

	-- Prefer gliding speed if available and higher
	local speed = rawSpeed
	if skySpeed and type(skySpeed) == "number" and skySpeed > (rawSpeed or 0) then
		speed = skySpeed
	end

	-- Player state
	local isSkyriding = Context.IsSkyridingActive()
	local isMounted = IsMounted()
	local isDruidFlying = Context.IsInDruidFlightForm()
	local isFlying = IsFlying() or isGliding or isDruidFlying

	-- Abilities
	local surgeCharges = Context.GetSpellCharges(SURGE_FORWARD_SPELL_ID)
	local secondWindCharges = Context.GetSpellCharges(SECOND_WIND_SPELL_ID)
	local whirlingSurgeCooldown = Context.GetSpellCooldown(WHIRLING_SURGE_SPELL_ID)

	-- Usability fallbacks for secret values
	local surgeUsable = Context.IsSpellUsable(SURGE_FORWARD_SPELL_ID)
	local secondWindUsable = Context.IsSpellUsable(SECOND_WIND_SPELL_ID)
	local whirlingSurgeUsable = Context.IsSpellUsable(WHIRLING_SURGE_SPELL_ID)

	return {
		now = now,
		deltaTime = deltaTime,

		player = {
			speed = speed,
			isSpeedSecret = Secrets.IsSecret(speed),
			isGliding = isGliding,
			canGlide = canGlide,
			isMounted = isMounted,
			isSkyriding = isSkyriding,
			isDruidFlying = isDruidFlying,
			isFlying = isFlying,
		},

		abilities = {
			surgeForward = {
				charges = surgeCharges,
				isUsable = surgeUsable,
			},
			secondWind = {
				charges = secondWindCharges,
				isUsable = secondWindUsable,
			},
			whirlingSurge = {
				cooldown = whirlingSurgeCooldown,
				isUsable = whirlingSurgeUsable,
			},
		},

		zone = {
			zoneModifier = Context.GetCachedZoneModifier(),
		},

		db = db,
	}
end

Bridge.Context = Context
return Context
