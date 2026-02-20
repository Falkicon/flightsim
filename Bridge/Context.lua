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

-- Buff aura names for charge recovery indicators
-- (Using names instead of spell IDs since IDs were recycled/changed in 12.0)
local THRILL_OF_THE_SKIES_NAME = "Thrill of the Skies"
local GROUND_SKIMMING_NAME = "Ground Skimming"

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
--- Note: Always calculates fresh to avoid stale cache issues on login/reload.
---@return number modifier (1.0 or 0.85)
function Context.GetCachedZoneModifier()
	if _zoneModifier == nil then
		_zoneModifier = Context.GetZoneModifier()
	end
	return _zoneModifier
end

local _, playerClass = UnitClass("player")

--- Check if player is in Druid flight form.
---@param isFlying boolean
---@param isGliding boolean
---@return boolean isDruidFlying
function Context.IsInDruidFlightForm(isFlying, isGliding)
	if playerClass ~= "DRUID" then
		return false
	end

	local form = GetShapeshiftForm()
	-- Form 3 is Travel Form (includes Flight Form)
	if form == 3 and (isFlying or isGliding) then
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
---@param isMounted? boolean Player mounted state
---@param isDruidFlying? boolean Player druid flight state
---@param canGlide? boolean Player glide state
---@return boolean isActive
function Context.IsSkyridingActive(forceRefresh, isMounted, isDruidFlying, canGlide)
	local now = GetTime()

	-- Use cache if valid (same frame)
	if not forceRefresh and _skyridingCacheTime and (now - _skyridingCacheTime) < 0.05 then
		return _skyridingCacheResult or false
	end

	local result = false

	if isMounted == nil then isMounted = IsMounted() end
	if isDruidFlying == nil then isDruidFlying = Context.IsInDruidFlightForm(IsFlying(), false) end

	-- Check mount or druid form first
	if not isMounted and not isDruidFlying then
		result = false
	else
		if canGlide == nil then
			if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
				local ok, _, _, cg = pcall(C_PlayerInfo.GetGlidingInfo)
				if ok then
					canGlide = cg
				end
			end
		end

		-- Check gliding state
		if canGlide then
			result = true
		else
			-- Fallback: check Surge Forward charges (reliable for skyriding detection)
			if C_Spell and C_Spell.GetSpellCharges then
				-- We must use the cached Context wrapper here to avoid C-API allocation loop
				local chargeInfo = Context.GetSpellCharges(SURGE_FORWARD_SPELL_ID)
				if chargeInfo and chargeInfo.maxCharges then
					local max = chargeInfo.maxCharges
					if not chargeInfo.isSecret and max > 0 then
						result = true
					end
				end
			end
		end
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

-- Cache payload tables for spell charges and cooldowns
local _spellChargesCache = {}
local _spellCooldownCache = {}

--- Event hook to invalidate spell caches when cooldowns update.
function Context.InvalidateSpellCache()
	wipe(_spellChargesCache)
	wipe(_spellCooldownCache)
end

--- Get spell charges safely (cached).
---@param spellID number Spell ID
---@param outData table Pre-allocated data block
---@return table chargeInfo {currentCharges, maxCharges, chargeStart, chargeDuration, isSecret}
function Context.GetSpellCharges(spellID, outData)
	local result = outData or {}
	
	if _spellChargesCache[spellID] then
		local c = _spellChargesCache[spellID]
		result.currentCharges = c.currentCharges
		result.maxCharges = c.maxCharges
		result.chargeStart = c.cooldownStartTime or 0
		result.chargeDuration = c.cooldownDuration or 0
		result.isSecret = c.isSecret
		return result
	end

	result.currentCharges = 0
	result.maxCharges = 0
	result.chargeStart = 0
	result.chargeDuration = 0
	result.isSecret = false

	if C_Spell and C_Spell.GetSpellCharges then
		local ok, info = pcall(C_Spell.GetSpellCharges, spellID)
		if ok and info then
			result.currentCharges = info.currentCharges
			result.maxCharges = info.maxCharges
			result.chargeStart = info.cooldownStartTime or 0
			result.chargeDuration = info.cooldownDuration or 0
			result.isSecret = Secrets.IsSecret(info.currentCharges) or Secrets.IsSecret(info.maxCharges)
			
			-- Cache the raw results
			_spellChargesCache[spellID] = {
				currentCharges = info.currentCharges,
				maxCharges = info.maxCharges,
				cooldownStartTime = info.cooldownStartTime,
				cooldownDuration = info.cooldownDuration,
				isSecret = result.isSecret
			}
		end
	end

	return result
end

--- Get spell cooldown safely (cached).
---@param spellID number Spell ID
---@param outData table Pre-allocated data block
---@return table cooldownInfo {startTime, duration, enabled, isSecret}
function Context.GetSpellCooldown(spellID, outData)
	local result = outData or {}
	
	if _spellCooldownCache[spellID] then
		local c = _spellCooldownCache[spellID]
		result.startTime = c.startTime
		result.duration = c.duration
		result.enabled = c.enabled
		result.isSecret = c.isSecret
		return result
	end

	result.startTime = 0
	result.duration = 0
	result.enabled = true
	result.isSecret = false

	if C_Spell and C_Spell.GetSpellCooldown then
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
			
			-- Cache the raw results
			_spellCooldownCache[spellID] = {
				startTime = result.startTime,
				duration = result.duration,
				enabled = result.enabled,
				isSecret = result.isSecret
			}
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

--- Check if the player has charge recovery buffs active.
--- Uses index-based aura iteration with name matching for reliability.
---@return boolean hasThrillOfTheSkies, boolean hasGroundSkimming
local _hasThrillBuff = false
local _hasSkimBuff = false

--- Update the buff cache, designed to be called only on UNIT_AURA.
function Context.UpdateBuffs()
	_hasThrillBuff = false
	_hasSkimBuff = false
	pcall(function()
		for i = 1, 40 do
			local auraData = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
			if not auraData then break end
			local name = auraData.name
			if name == THRILL_OF_THE_SKIES_NAME then
				_hasThrillBuff = true
			elseif name == GROUND_SKIMMING_NAME then
				_hasSkimBuff = true
			end
			if _hasThrillBuff and _hasSkimBuff then break end
		end
	end)
end

--- Get cached skyriding charge recovery buffs.
---@return boolean hasThrillBuff, boolean hasSkimBuff
function Context.GetChargeRecoveryBuffs()
	return _hasThrillBuff, _hasSkimBuff
end

---@class FlightsimContext
---@field now number Current GetTime()
---@field deltaTime number Time since last frame
---@field player PlayerContext
---@field abilities AbilityContext
---@field zone ZoneContext
---@field db table SavedVariables reference

-- Pre-allocated static buffers to eliminate GC churn on frame updates
local _surgeCharges = {}
local _windCharges = {}
local _whirlCooldown = {}
local _surgeAbility = { charges = _surgeCharges }
local _windAbility = { charges = _windCharges }
local _whirlAbility = { cooldown = _whirlCooldown }
local _flightSimContext = {
	player = {},
	abilities = {
		surgeForward = _surgeAbility,
		secondWind = _windAbility,
		whirlingSurge = _whirlAbility,
	},
	zone = {},
	buffs = {},
}

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
	local isMounted = IsMounted()
	local isFlying = IsFlying()
	local isDruidFlying = Context.IsInDruidFlightForm(isFlying, isGliding)
	local isActuallyFlying = isFlying or isGliding or isDruidFlying
	local isSkyriding = Context.IsSkyridingActive(false, isMounted, isDruidFlying, canGlide)

	-- Abilities (using pre-allocated outData buffers)
	Context.GetSpellCharges(SURGE_FORWARD_SPELL_ID, _surgeCharges)
	Context.GetSpellCharges(SECOND_WIND_SPELL_ID, _windCharges)
	Context.GetSpellCooldown(WHIRLING_SURGE_SPELL_ID, _whirlCooldown)

	-- Usability fallbacks for secret values
	_surgeAbility.isUsable = Context.IsSpellUsable(SURGE_FORWARD_SPELL_ID)
	_windAbility.isUsable = Context.IsSpellUsable(SECOND_WIND_SPELL_ID)
	_whirlAbility.isUsable = Context.IsSpellUsable(WHIRLING_SURGE_SPELL_ID)

	-- Charge recovery buff detection
	local hasThrillBuff, hasSkimBuff = Context.GetChargeRecoveryBuffs()

	-- Player world position (UnitPosition works unprotected while flying in open world)
	local posX, posY
	local posOk, px, py = pcall(UnitPosition, "player")
	if posOk and px then
		posX, posY = px, py
	end

	-- Update static context table
	_flightSimContext.now = now
	_flightSimContext.deltaTime = deltaTime
	_flightSimContext.db = db

	local p = _flightSimContext.player
	p.speed = speed
	p.isSpeedSecret = Secrets.IsSecret(speed)
	p.isGliding = isGliding
	p.canGlide = canGlide
	p.isMounted = isMounted
	p.isSkyriding = isSkyriding
	p.isDruidFlying = isDruidFlying
	p.isFlying = isActuallyFlying
	p.posX = posX
	p.posY = posY

	local z = _flightSimContext.zone
	z.zoneModifier = Context.GetCachedZoneModifier()

	local b = _flightSimContext.buffs
	b.thrillOfTheSkies = hasThrillBuff
	b.groundSkimming = hasSkimBuff

	return _flightSimContext
end

Bridge.Context = Context
return Context
