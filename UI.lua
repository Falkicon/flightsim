FlightsimUI = FlightsimUI or {}

-- WeakAura-inspired skyriding constants (Retail 11.x):
-- These are used only where they map cleanly to addon-safe APIs.
local ASCENT_SPELL_ID = 372610
local THRILL_BUFF_ID = 377234
local SLOW_SKYRIDING_RATIO = 705 / 830
local ASCENT_DURATION = 3.5
-- Base speed for percentage calculation. WA uses ~8.24 y/s (approx 100% mounted ground speed)
-- so that max skyriding (~65 y/s) shows as ~790% rather than ~930%.
local BASE_SPEED_FOR_PCT = 8.24
local FAST_FLYING_ZONES = {
	[2444] = true, -- Dragon Isles
	[2454] = true, -- Zaralek Cavern
	[2548] = true, -- Emerald Dream
	[2516] = true, -- Nokhud Offensive
	[2522] = true, -- Vault of the Incarnates
	[2569] = true, -- Aberrus, the Shadowed Crucible
}

local function Clamp(n, minV, maxV)
	if n < minV then return minV end
	if n > maxV then return maxV end
	return n
end

-- Blizzard-matching color palette (based on #2BA604 green)
local COLOR_GREEN = { 0.169, 0.651, 0.016 }  -- #2BA604
local COLOR_YELLOW = { 0.769, 0.651, 0.016 } -- #C4A604 (gold)
local COLOR_RED = { 0.769, 0.169, 0.016 }    -- #C42B04

-- Surge Forward color: #74AFFF (light blue)
local COLOR_SURGE_FORWARD = { 0.455, 0.686, 1.0 }  -- #74AFFF
local COLOR_SURGE_FORWARD_EMPTY = { 0.18, 0.27, 0.4 }  -- Dimmed version

-- Second Wind color: #D379EF (purple/magenta)
local COLOR_SECOND_WIND = { 0.827, 0.475, 0.937 }  -- #D379EF
local COLOR_SECOND_WIND_EMPTY = { 0.33, 0.19, 0.37 }  -- Dimmed version

-- Whirling Surge color: #4AC7D4 (cyan/teal)
local COLOR_WHIRLING_SURGE = { 0.290, 0.780, 0.831 }  -- #4AC7D4
local COLOR_WHIRLING_SURGE_EMPTY = { 0.12, 0.31, 0.33 }  -- Dimmed version

-- Spell IDs for ability tracking
local WHIRLING_SURGE_SPELL_ID = 361584
local SECOND_WIND_SPELL_ID = 425782  -- Second Wind (vigor refresh)
local SURGE_FORWARD_SPELL_ID = 372608  -- Surge Forward (6 charges, restored by Second Wind)

local function ColorForPct(pct)
	-- Ramp: red (0%) -> yellow (50%) -> green (100%)
	pct = Clamp(pct or 0, 0, 1)
	local r, g, b
	if pct < 0.5 then
		-- red -> yellow (0% to 50%)
		local t = pct * 2  -- 0 -> 1 as pct goes 0 -> 0.5
		r = COLOR_RED[1] + (COLOR_YELLOW[1] - COLOR_RED[1]) * t
		g = COLOR_RED[2] + (COLOR_YELLOW[2] - COLOR_RED[2]) * t
		b = COLOR_RED[3] + (COLOR_YELLOW[3] - COLOR_RED[3]) * t
	else
		-- yellow -> green (50% to 100%)
		local t = (pct - 0.5) * 2  -- 0 -> 1 as pct goes 0.5 -> 1
		r = COLOR_YELLOW[1] + (COLOR_GREEN[1] - COLOR_YELLOW[1]) * t
		g = COLOR_YELLOW[2] + (COLOR_GREEN[2] - COLOR_YELLOW[2]) * t
		b = COLOR_YELLOW[3] + (COLOR_GREEN[3] - COLOR_YELLOW[3]) * t
	end
	return r, g, b
end

local function ColorForPctBlue(pct)
	-- Simple lerp: empty -> full for Whirling Surge (#4AC7D4)
	pct = Clamp(pct or 0, 0, 1)
	local r = COLOR_WHIRLING_SURGE_EMPTY[1] + (COLOR_WHIRLING_SURGE[1] - COLOR_WHIRLING_SURGE_EMPTY[1]) * pct
	local g = COLOR_WHIRLING_SURGE_EMPTY[2] + (COLOR_WHIRLING_SURGE[2] - COLOR_WHIRLING_SURGE_EMPTY[2]) * pct
	local b = COLOR_WHIRLING_SURGE_EMPTY[3] + (COLOR_WHIRLING_SURGE[3] - COLOR_WHIRLING_SURGE_EMPTY[3]) * pct
	return r, g, b
end

local function ColorForPctPurple(pct)
	-- Simple lerp: empty -> full for Second Wind (#D379EF)
	pct = Clamp(pct or 0, 0, 1)
	local r = COLOR_SECOND_WIND_EMPTY[1] + (COLOR_SECOND_WIND[1] - COLOR_SECOND_WIND_EMPTY[1]) * pct
	local g = COLOR_SECOND_WIND_EMPTY[2] + (COLOR_SECOND_WIND[2] - COLOR_SECOND_WIND_EMPTY[2]) * pct
	local b = COLOR_SECOND_WIND_EMPTY[3] + (COLOR_SECOND_WIND[3] - COLOR_SECOND_WIND_EMPTY[3]) * pct
	return r, g, b
end

local function ColorForPctSurgeForward(pct)
	-- Simple lerp: empty -> full for Surge Forward (#74AFFF)
	pct = Clamp(pct or 0, 0, 1)
	local r = COLOR_SURGE_FORWARD_EMPTY[1] + (COLOR_SURGE_FORWARD[1] - COLOR_SURGE_FORWARD_EMPTY[1]) * pct
	local g = COLOR_SURGE_FORWARD_EMPTY[2] + (COLOR_SURGE_FORWARD[2] - COLOR_SURGE_FORWARD_EMPTY[2]) * pct
	local b = COLOR_SURGE_FORWARD_EMPTY[3] + (COLOR_SURGE_FORWARD[3] - COLOR_SURGE_FORWARD_EMPTY[3]) * pct
	return r, g, b
end

local function GetUnitSpeedSafe(unit)
	local fn = GetUnitSpeed or UnitSpeed
	if type(fn) == "function" then
		local ok, result = pcall(fn, unit)
		if ok and result then
			return result
		end
	end
	return 0
end

local function IsSlowSkyridingZone()
	if type(GetInstanceInfo) ~= "function" then
		return false
	end
	local instanceID = select(8, GetInstanceInfo())
	if type(instanceID) ~= "number" then
		return false
	end
	return not FAST_FLYING_ZONES[instanceID]
end

local function HasThrillBuff()
	if C_UnitAuras and type(C_UnitAuras.GetPlayerAuraBySpellID) == "function" then
		local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, THRILL_BUFF_ID)
		return ok and aura ~= nil
	end
	return false
end

function FlightsimUI:_UpdateSkyridingState(now)
	-- Zone normalization (WA behavior): treat some zones as "slow" and scale up.
	self._isSlowSkyriding = IsSlowSkyridingZone()

	-- Detect ascent casts for boost window.
	-- (We keep this state even if we don't expose a separate UI element yet.)
	if self._ascentStart and now and (now > self._ascentStart + ASCENT_DURATION) then
		-- Expired
		self._ascentStart = nil
	end

	local thrill = HasThrillBuff()
	self._hasThrill = thrill
	if thrill and self._ascentStart and now then
		self._isBoosting = now < (self._ascentStart + ASCENT_DURATION)
	else
		self._isBoosting = false
	end
end

function FlightsimUI:_GetSkyridingSpeed(now)
	-- Returns: speed, isGliding
	if C_PlayerInfo and type(C_PlayerInfo.GetGlidingInfo) == "function" then
		local ok, isGliding, _, forwardSpeed = pcall(C_PlayerInfo.GetGlidingInfo)
		if ok and isGliding and type(forwardSpeed) == "number" then
			local adjusted = forwardSpeed
			if self._isSlowSkyriding then
				adjusted = adjusted / SLOW_SKYRIDING_RATIO
			end
			return adjusted, true
		end
	end
	return 0, false
end

local function GetSpellChargesSafe(spellID)
	spellID = tonumber(spellID)
	if not spellID then
		return nil, nil
	end

	-- Some client builds prune/rename the global. Prefer the global if present,
	-- otherwise fall back to C_Spell.GetSpellCharges if available.
	if type(GetSpellCharges) == "function" then
		local ok, cur, max = pcall(GetSpellCharges, spellID)
		if ok then
			return cur, max
		end
	end

	if C_Spell and type(C_Spell.GetSpellCharges) == "function" then
		local ok, a, b = pcall(C_Spell.GetSpellCharges, spellID)
		if ok then
			if type(a) == "table" then
				-- FrameXML typically returns a table with currentCharges/maxCharges.
				local cur = a.currentCharges or a.charges
				local max = a.maxCharges or a.max
				return cur, max
			end
			-- Some builds may return (currentCharges, maxCharges, ...)
			return a, b
		end
	end

	return nil, nil
end

-- Reusable table for GetSpellCooldownSafe to avoid per-frame allocations
local _cooldownResult = {
	startTime = nil,
	duration = nil,
	isEnabled = nil,
	currentCharges = nil,
	maxCharges = nil,
	chargeStart = nil,
	chargeDuration = nil,
}

-- Returns a table with cooldown and charge info for a spell
-- { startTime, duration, isEnabled, currentCharges, maxCharges, chargeStart, chargeDuration }
-- NOTE: Returns a reused table - do not store references to the result!
local function GetSpellCooldownSafe(spellID, getCharges)
	spellID = tonumber(spellID)

	-- Reset the reusable table
	_cooldownResult.startTime = nil
	_cooldownResult.duration = nil
	_cooldownResult.isEnabled = nil
	_cooldownResult.currentCharges = nil
	_cooldownResult.maxCharges = nil
	_cooldownResult.chargeStart = nil
	_cooldownResult.chargeDuration = nil

	if not spellID then
		return _cooldownResult
	end

	-- Try C_Spell.GetSpellCooldown first (modern API)
	if C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
		local ok, cdInfo = pcall(C_Spell.GetSpellCooldown, spellID)
		if ok and cdInfo then
			if type(cdInfo) == "table" then
				_cooldownResult.startTime = cdInfo.startTime
				_cooldownResult.duration = cdInfo.duration
				_cooldownResult.isEnabled = cdInfo.isEnabled
			end
		end
	end

	-- Fallback to global GetSpellCooldown
	if not _cooldownResult.startTime and type(GetSpellCooldown) == "function" then
		local ok, s, d, e = pcall(GetSpellCooldown, spellID)
		if ok then
			_cooldownResult.startTime = s
			_cooldownResult.duration = d
			_cooldownResult.isEnabled = e
		end
	end

	-- Get charge info if requested
	if getCharges then
		if C_Spell and type(C_Spell.GetSpellCharges) == "function" then
			local ok, chargeInfo = pcall(C_Spell.GetSpellCharges, spellID)
			if ok and chargeInfo and type(chargeInfo) == "table" then
				_cooldownResult.currentCharges = chargeInfo.currentCharges
				_cooldownResult.maxCharges = chargeInfo.maxCharges
				_cooldownResult.chargeStart = chargeInfo.cooldownStartTime
				_cooldownResult.chargeDuration = chargeInfo.cooldownDuration
			end
		elseif type(GetSpellCharges) == "function" then
			local ok, cur, max, chargeStart, chargeDuration = pcall(GetSpellCharges, spellID)
			if ok and cur then
				_cooldownResult.currentCharges = cur
				_cooldownResult.maxCharges = max
				_cooldownResult.chargeStart = chargeStart
				_cooldownResult.chargeDuration = chargeDuration
			end
		end
	end

	return _cooldownResult
end

local function ResolveSpellInfo(token)
	if type(token) == "number" then
		if C_Spell and C_Spell.GetSpellInfo then
			local info = C_Spell.GetSpellInfo(token)
			if info and info.spellID then
				return info.spellID, info.iconID
			end
		end
		local _, _, icon, _, _, _, spellID = GetSpellInfo(token)
		return spellID or token, icon
	end

	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(token)
		if info and info.spellID then
			return info.spellID, info.iconID
		end
	end

	local _, _, icon, _, _, _, spellID = GetSpellInfo(token)
	return spellID, icon
end

-- Check if player is in druid flight form (Travel Form in flying mode)
local function IsInDruidFlightForm()
	-- GetShapeshiftForm returns 3 for Travel/Aquatic/Flight Form on druids
	-- We also need to verify we're actually flying (not ground travel or swimming)
	if type(GetShapeshiftForm) ~= "function" then
		return false
	end
	local ok, form = pcall(GetShapeshiftForm)
	if ok and form == 3 and IsFlying() then
		return true
	end
	return false
end

function FlightsimUI:IsSkyridingActive()
	-- Cache result for this frame to avoid repeated pcalls
	local now = GetTime()
	if self._skyridingCacheTime == now then
		return self._skyridingCacheResult
	end

	-- Quick exit: if not mounted AND not in druid flight form, we're definitely not skyriding
	-- Druid Flight Form returns false for IsMounted() but can still do dynamic flight
	local isMounted = IsMounted()
	local isDruidFlying = IsInDruidFlightForm()
	if not isMounted and not isDruidFlying then
		self._skyridingCacheTime = now
		self._skyridingCacheResult = false
		return false
	end

	local result = false

	-- Best-effort detection using GetGlidingInfo (added in 10.0.5)
	-- isGliding = currently gliding in the air
	-- canGlide = on a skyriding mount in a valid zone (even on ground)
	-- This works for both regular mounts AND druid flight form
	if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
		local ok, isGliding, canGlide, forwardSpeed = pcall(C_PlayerInfo.GetGlidingInfo)
		if ok then
			if isGliding or canGlide then
				result = true
			end
		end
	end

	-- Fallback: check older API names (only if not already true)
	if not result and C_PlayerInfo and C_PlayerInfo.IsPlayerInSkyriding then
		local ok, val = pcall(C_PlayerInfo.IsPlayerInSkyriding)
		if ok and type(val) == "boolean" then
			result = val
		end
	end

	if not result and C_PlayerInfo and C_PlayerInfo.IsPlayerInDragonriding then
		local ok, val = pcall(C_PlayerInfo.IsPlayerInDragonriding)
		if ok and type(val) == "boolean" then
			result = val
		end
	end

	-- Last resort: if flying (mounted or druid form), check for skyriding abilities
	if not result and IsFlying() and (isMounted or isDruidFlying) then
		if self.db and self.db.profile and self.db.profile.abilities and self.db.profile.abilities.order then
			for _, token in ipairs(self.db.profile.abilities.order) do
				if self.db.profile.abilities.enabled == nil or self.db.profile.abilities.enabled[token] ~= false then
					local spellID = select(1, ResolveSpellInfo(token))
					if spellID then
						local cur, max = GetSpellChargesSafe(spellID)
						if cur ~= nil and max ~= nil and max > 0 then
							result = true
							break
						end
					end
				end
			end
		end
	end

	-- Cache the result
	self._skyridingCacheTime = now
	self._skyridingCacheResult = result
	return result
end

function FlightsimUI:Init(db)
	self.db = db

	-- Minimal UI: the frame *is* the speed bar.
	local frame = CreateFrame("StatusBar", "FlightsimFrame", UIParent)
	self.frame = frame

	frame:SetSize(150, 40)
	frame:SetScale(db.profile.scale or 1)
	frame:SetPoint("CENTER", UIParent, "CENTER", db.profile.x or 0, db.profile.y or 0)

	frame:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
	frame:SetMinMaxValues(0, 1)
	frame:SetValue(0)
	self.speedBar = frame

	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function()
		if not (self.db and self.db.profile and self.db.profile.locked) then
			frame:StartMoving()
		end
	end)
	frame:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local _, _, _, x, y = frame:GetPoint(1)
		self.db.profile.x = x
		self.db.profile.y = y
	end)

	-- Event hooks for skyriding state (ascent cast + zone changes).
	local events = CreateFrame("Frame")
	self._eventFrame = events
	events:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	events:SetScript("OnEvent", function(_, event, ...)
		if event == "UNIT_SPELLCAST_SUCCEEDED" then
			local unit, _, spellID = ...
			if unit == "player" and spellID == ASCENT_SPELL_ID then
				self._ascentStart = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
			end
			return
		end

		-- Zone-related state refresh
		self._isSlowSkyriding = IsSlowSkyridingZone()
	end)

	local barBg = frame:CreateTexture(nil, "BACKGROUND")
	barBg:SetAllPoints(frame)
	-- Flat dark background.
	barBg:SetColorTexture(0.08, 0.12, 0.18, 0.85)
	self.speedBarBg = barBg

	local sustainableMarkerWidth = (db.profile.ui and db.profile.ui.sustainableSpeedMarkerWidth) or (db.profile.ui and db.profile.ui.optimalMarkerWidth) or 1
	local sustainableMarkerAlpha = (db.profile.ui and db.profile.ui.sustainableSpeedMarkerAlpha) or 0.2
	local optimal = frame:CreateTexture(nil, "OVERLAY")
	optimal:SetColorTexture(1, 1, 1, sustainableMarkerAlpha)
	optimal:SetWidth(sustainableMarkerWidth)
	optimal:SetPoint("TOP", frame, "TOP", 0, 0)
	optimal:SetPoint("BOTTOM", frame, "BOTTOM", 0, 0)
	self.sustainableMarker = optimal

	local speedText = frame:CreateFontString(nil, "OVERLAY")
	-- Sans-serif look like WA.
	local fontSize = (db.profile.speedBar and db.profile.speedBar.fontSize) or 12
	speedText:SetFont("Fonts\\ARIALN.TTF", fontSize, "OUTLINE")
	speedText:SetPoint("LEFT", frame, "LEFT", 6, 0)
	speedText:SetJustifyH("LEFT")
	speedText:SetText("0%")
	self.speedText = speedText

	-- Acceleration bar (below the speed bar)
	local accelBarHeight = (db.profile.ui and db.profile.ui.accelBarHeight) or 2
	local accelGap = (db.profile.ui and db.profile.ui.accelBarGap) or 2

	local accelFrame = CreateFrame("Frame", nil, UIParent)
	accelFrame:SetSize(db.profile.ui.width or 150, accelBarHeight)
	accelFrame:SetPoint("TOP", frame, "BOTTOM", 0, -accelGap)
	self.accelFrame = accelFrame

	local accelBg = accelFrame:CreateTexture(nil, "BACKGROUND")
	accelBg:SetAllPoints(accelFrame)
	accelBg:SetColorTexture(0.08, 0.12, 0.18, 0.85)
	self.accelBarBg = accelBg

	-- No center marker - the bar itself indicates state

	-- The actual acceleration indicator bar (starts from center, white)
	local accelBar = accelFrame:CreateTexture(nil, "ARTWORK")
	accelBar:SetColorTexture(1, 1, 1, 0.9)  -- White
	accelBar:SetHeight(accelBarHeight)
	self.accelBar = accelBar

	-- Ability bars (below the acceleration bar)
	-- Order: Surge Forward -> Second Wind -> Whirling Surge
	local abilityBarHeight = (db.profile.ui and db.profile.ui.abilityBarHeight) or 10
	local barGap = (db.profile.ui and db.profile.ui.barGap) or 2
	local chargeGap = 2  -- Gap between charge bars within a multi-charge ability

	-- Surge Forward charge bars (6 charges, light blue #74AFFF)
	local surgeForwardFrame = CreateFrame("Frame", nil, UIParent)
	surgeForwardFrame:SetSize(db.profile.ui.width or 150, abilityBarHeight)
	surgeForwardFrame:SetPoint("TOP", accelFrame, "BOTTOM", 0, -barGap)
	self.surgeForwardFrame = surgeForwardFrame

	self.surgeForwardBars = {}
	self.surgeForwardBarBgs = {}
	local sfTotalGaps = chargeGap * 5  -- 5 gaps between 6 bars
	local sfChargeWidth = ((db.profile.ui.width or 150) - sfTotalGaps) / 6

	for i = 1, 6 do
		local chargeBar = CreateFrame("StatusBar", nil, surgeForwardFrame)
		chargeBar:SetSize(sfChargeWidth, abilityBarHeight)
		chargeBar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
		chargeBar:SetMinMaxValues(0, 1)
		chargeBar:SetValue(1)

		local chargeBg = chargeBar:CreateTexture(nil, "BACKGROUND")
		chargeBg:SetAllPoints(chargeBar)
		chargeBg:SetColorTexture(0.08, 0.12, 0.18, 0.85)
		self.surgeForwardBarBgs[i] = chargeBg

		if i == 1 then
			chargeBar:SetPoint("LEFT", surgeForwardFrame, "LEFT", 0, 0)
		else
			chargeBar:SetPoint("LEFT", self.surgeForwardBars[i-1], "RIGHT", chargeGap, 0)
		end

		self.surgeForwardBars[i] = chargeBar
	end

	-- Second Wind charge bars (3 charges, purple #D379EF)
	local secondWindFrame = CreateFrame("Frame", nil, UIParent)
	secondWindFrame:SetSize(db.profile.ui.width or 150, abilityBarHeight)
	secondWindFrame:SetPoint("TOP", surgeForwardFrame, "BOTTOM", 0, -barGap)
	self.secondWindFrame = secondWindFrame

	self.secondWindBars = {}
	self.secondWindBarBgs = {}
	local swTotalGaps = chargeGap * 2  -- 2 gaps between 3 bars
	local swChargeWidth = ((db.profile.ui.width or 150) - swTotalGaps) / 3

	for i = 1, 3 do
		local chargeBar = CreateFrame("StatusBar", nil, secondWindFrame)
		chargeBar:SetSize(swChargeWidth, abilityBarHeight)
		chargeBar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
		chargeBar:SetMinMaxValues(0, 1)
		chargeBar:SetValue(1)

		local chargeBg = chargeBar:CreateTexture(nil, "BACKGROUND")
		chargeBg:SetAllPoints(chargeBar)
		chargeBg:SetColorTexture(0.08, 0.12, 0.18, 0.85)
		self.secondWindBarBgs[i] = chargeBg

		if i == 1 then
			chargeBar:SetPoint("LEFT", secondWindFrame, "LEFT", 0, 0)
		else
			chargeBar:SetPoint("LEFT", self.secondWindBars[i-1], "RIGHT", chargeGap, 0)
		end

		self.secondWindBars[i] = chargeBar
	end

	-- Whirling Surge cooldown bar (30s cooldown, cyan #4AC7D4)
	local whirlingSurgeFrame = CreateFrame("StatusBar", nil, UIParent)
	whirlingSurgeFrame:SetSize(db.profile.ui.width or 150, abilityBarHeight)
	whirlingSurgeFrame:SetPoint("TOP", secondWindFrame, "BOTTOM", 0, -barGap)
	whirlingSurgeFrame:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
	whirlingSurgeFrame:SetMinMaxValues(0, 1)
	whirlingSurgeFrame:SetValue(1)
	self.whirlingSurgeBar = whirlingSurgeFrame

	local whirlingSurgeBg = whirlingSurgeFrame:CreateTexture(nil, "BACKGROUND")
	whirlingSurgeBg:SetAllPoints(whirlingSurgeFrame)
	whirlingSurgeBg:SetColorTexture(0.08, 0.12, 0.18, 0.85)
	self.whirlingSurgeBg = whirlingSurgeBg

	-- Animation state tracking
	self._surgeForwardAnimating = { false, false, false, false, false, false }
	self._surgeForwardAnimValue = { 1, 1, 1, 1, 1, 1 }
	self._surgeForwardLastTarget = {}

	self._secondWindAnimating = { false, false, false }
	self._secondWindAnimValue = { 1, 1, 1 }
	self._secondWindLastTarget = {}

	self._whirlingSurgeAnimating = false
	self._whirlingSurgeAnimValue = 1

	self:RebuildLayout()
	self:StartUpdating()
end

function FlightsimUI:RebuildLayout()
	if not (self.frame and self.db and self.db.profile) then return end

	local p = self.db.profile
	local ui = p.ui or {}
	local ab = p.abilityBars or {}
	local scale = p.scale or 1
	local width = ui.width or 150
	local barH = ui.speedBarHeight or 20
	local accelH = ui.accelBarHeight or 1
	local accelGap = ui.accelBarGap or 0
	local barGap = ui.barGap or 2
	local sustainableW = ui.sustainableSpeedMarkerWidth or ui.optimalMarkerWidth or 1
	local sustainableAlpha = ui.sustainableSpeedMarkerAlpha or 0.2

	-- Ability bar visibility settings
	local showSurgeForward = ab.showSurgeForward ~= false
	local showSecondWind = ab.showSecondWind ~= false
	local showWhirlingSurge = ab.showWhirlingSurge ~= false

	-- Apply scale to all frames
	self.frame:SetScale(scale)
	if self.accelFrame then self.accelFrame:SetScale(scale) end
	if self.surgeForwardFrame then self.surgeForwardFrame:SetScale(scale) end
	if self.secondWindFrame then self.secondWindFrame:SetScale(scale) end
	if self.whirlingSurgeBar then self.whirlingSurgeBar:SetScale(scale) end

	self.frame:SetSize(width, barH)

	-- Update sustainable speed marker width and alpha
	if self.sustainableMarker then
		self.sustainableMarker:SetWidth(sustainableW)
		self.sustainableMarker:SetColorTexture(1, 1, 1, sustainableAlpha)
	end

	-- Update acceleration bar dimensions
	if self.accelFrame then
		self.accelFrame:SetSize(width, accelH)
		self.accelFrame:ClearAllPoints()
		self.accelFrame:SetPoint("TOP", self.frame, "BOTTOM", 0, -accelGap)
	end
	if self.accelBar then
		self.accelBar:SetHeight(accelH)
	end

	-- Update ability bar dimensions
	-- Order: Surge Forward -> Second Wind -> Whirling Surge
	-- Bars anchor to the previous visible bar
	local abilityH = ui.abilityBarHeight or 10
	local chargeGap = 2
	local lastAnchor = self.accelFrame

	-- Surge Forward (6 charges)
	if self.surgeForwardFrame then
		if showSurgeForward then
			self.surgeForwardFrame:SetSize(width, abilityH)
			self.surgeForwardFrame:ClearAllPoints()
			self.surgeForwardFrame:SetPoint("TOP", lastAnchor, "BOTTOM", 0, -barGap)
			self.surgeForwardFrame:Show()
			lastAnchor = self.surgeForwardFrame

			local sfTotalGaps = chargeGap * 5
			local sfChargeWidth = (width - sfTotalGaps) / 6

			if self.surgeForwardBars then
				for i, chargeBar in ipairs(self.surgeForwardBars) do
					chargeBar:SetSize(sfChargeWidth, abilityH)
					chargeBar:ClearAllPoints()
					if i == 1 then
						chargeBar:SetPoint("LEFT", self.surgeForwardFrame, "LEFT", 0, 0)
					else
						chargeBar:SetPoint("LEFT", self.surgeForwardBars[i-1], "RIGHT", chargeGap, 0)
					end
				end
			end
		else
			self.surgeForwardFrame:Hide()
		end
	end

	-- Second Wind (3 charges)
	if self.secondWindFrame then
		if showSecondWind then
			self.secondWindFrame:SetSize(width, abilityH)
			self.secondWindFrame:ClearAllPoints()
			self.secondWindFrame:SetPoint("TOP", lastAnchor, "BOTTOM", 0, -barGap)
			self.secondWindFrame:Show()
			lastAnchor = self.secondWindFrame

			local swTotalGaps = chargeGap * 2
			local swChargeWidth = (width - swTotalGaps) / 3

			if self.secondWindBars then
				for i, chargeBar in ipairs(self.secondWindBars) do
					chargeBar:SetSize(swChargeWidth, abilityH)
					chargeBar:ClearAllPoints()
					if i == 1 then
						chargeBar:SetPoint("LEFT", self.secondWindFrame, "LEFT", 0, 0)
					else
						chargeBar:SetPoint("LEFT", self.secondWindBars[i-1], "RIGHT", chargeGap, 0)
					end
				end
			end
		else
			self.secondWindFrame:Hide()
		end
	end

	-- Whirling Surge (cooldown bar)
	if self.whirlingSurgeBar then
		if showWhirlingSurge then
			self.whirlingSurgeBar:SetSize(width, abilityH)
			self.whirlingSurgeBar:ClearAllPoints()
			self.whirlingSurgeBar:SetPoint("TOP", lastAnchor, "BOTTOM", 0, -barGap)
			self.whirlingSurgeBar:Show()
		else
			self.whirlingSurgeBar:Hide()
		end
	end

	-- Always re-apply visibility after layout changes
	self:ApplyVisibility()
end

function FlightsimUI:ApplyVisibility()
	if not (self.frame and self.db and self.db.profile and self.db.profile.visibility) then return end
	local v = self.db.profile.visibility
	local ab = self.db.profile.abilityBars or {}
	local skyriding = self:IsSkyridingActive()

	local shouldShow = true
	if v.hideWhenNotSkyriding and not skyriding then
		shouldShow = false
	end

	if shouldShow then
		self.frame:Show()
		if self.accelFrame then self.accelFrame:Show() end
		-- Respect individual ability bar settings
		if self.surgeForwardFrame and ab.showSurgeForward ~= false then self.surgeForwardFrame:Show() end
		if self.secondWindFrame and ab.showSecondWind ~= false then self.secondWindFrame:Show() end
		if self.whirlingSurgeBar and ab.showWhirlingSurge ~= false then self.whirlingSurgeBar:Show() end
	else
		self.frame:Hide()
		if self.accelFrame then self.accelFrame:Hide() end
		if self.surgeForwardFrame then self.surgeForwardFrame:Hide() end
		if self.secondWindFrame then self.secondWindFrame:Hide() end
		if self.whirlingSurgeBar then self.whirlingSurgeBar:Hide() end
	end
end

function FlightsimUI:_GetFallbackSpeedFromPosition(elapsed)
	if type(UnitPosition) ~= "function" then
		return 0
	end
	local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
	local x, y, z, instanceID = UnitPosition("player")
	if not (x and y and z and instanceID) then
		return 0
	end

	local last = self._lastPos
	-- Reuse the table to avoid per-frame allocation
	if not last then
		self._lastPos = { t = now, x = x, y = y, z = z, instanceID = instanceID }
		return 0
	end

	if last.instanceID ~= instanceID then
		last.t, last.x, last.y, last.z, last.instanceID = now, x, y, z, instanceID
		return 0
	end

	local dt = now - (last.t or now)
	if not dt or dt <= 0 then
		last.t, last.x, last.y, last.z = now, x, y, z
		return 0
	end

	local dx = x - (last.x or x)
	local dy = y - (last.y or y)
	local dz = z - (last.z or z)
	local dist = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
	local speed = dist / dt

	-- Update stored position (reuse table)
	last.t, last.x, last.y, last.z = now, x, y, z

	if speed ~= speed or speed == math.huge then
		return 0
	end
	return speed
end

function FlightsimUI:StartUpdating()
	if not self.frame then return end

	-- Create a separate ticker frame that's always shown (never hidden)
	-- This ensures ApplyVisibility keeps running even when main frame is hidden
	if not self.tickerFrame then
		self.tickerFrame = CreateFrame("Frame")
	end

	-- Register for mount events to reduce polling when not skyriding
	if not self._eventsRegistered then
		self._eventsRegistered = true
		self.tickerFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
		self.tickerFrame:RegisterEvent("UNIT_AURA")
		self.tickerFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		self.tickerFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")  -- For druid flight form
		self.tickerFrame:SetScript("OnEvent", function(_, event, unit)
			if event == "UNIT_AURA" and unit ~= "player" then return end
			-- Force visibility check on mount change and invalidate cache
			self._forceVisibilityCheck = true
			self._skyridingCacheTime = nil  -- Invalidate cache immediately
		end)
	end

	self.tickerFrame:SetScript("OnUpdate", function(_, elapsed)
		self._accum = (self._accum or 0) + elapsed

		-- Adaptive throttling:
		-- - When visible/skyriding: 20Hz (0.05s) for smooth updates
		-- - When hidden: 2Hz (0.5s) to save CPU while staying responsive
		local isVisible = self.frame:IsShown()
		local throttle = isVisible and 0.05 or 0.5

		if not self._forceVisibilityCheck and self._accum < throttle then
			return
		end
		self._accum = 0
		self._forceVisibilityCheck = false

		-- Quick exit for unmounted state - no need to call ApplyVisibility
		-- which does expensive IsSkyridingActive() check
		-- Note: Druids in Flight Form have IsMounted()=false (it's a shapeshift, not a mount)
		local mounted = IsMounted()
		local druidFlying = IsInDruidFlightForm()
		if not mounted and not druidFlying and self.db and self.db.profile and self.db.profile.visibility 
		   and self.db.profile.visibility.hideWhenNotSkyriding then
			-- Force hide when not mounted and not in druid flight form (faster than full visibility check)
			if self.frame:IsShown() then
				self.frame:Hide()
				if self.accelFrame then self.accelFrame:Hide() end
				if self.surgeForwardFrame then self.surgeForwardFrame:Hide() end
				if self.secondWindFrame then self.secondWindFrame:Hide() end
				if self.whirlingSurgeBar then self.whirlingSurgeBar:Hide() end
			end
			return
		end

		self:ApplyVisibility()
		if not self.frame:IsShown() then
			return
		end

		local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
		self:_UpdateSkyridingState(now)

		-- Prefer skyriding/gliding API for flight; fall back to ground speed when unavailable.
		local speed, isGliding = self:_GetSkyridingSpeed(now)
		if not isGliding then
			speed = GetUnitSpeedSafe("player")
			if speed <= 0 then
				speed = self:_GetFallbackSpeedFromPosition(elapsed)
			end
		end
		local baseMax = (self.db.profile.speedBar and self.db.profile.speedBar.maxSpeed) or 950
		if baseMax <= 0 then baseMax = 950 end

		-- Convert raw speed (yards/sec) to percentage (WA-style: ~790% at stable, ~950% max)
		local speedPct = (speed / BASE_SPEED_FOR_PCT) * 100

		-- Display as percentage or raw speed
		local showPercent = self.db.profile.speedBar and self.db.profile.speedBar.showPercent
		if showPercent ~= false then
			self.speedText:SetText(string.format("%.0f%%", speedPct))
		else
			self.speedText:SetText(string.format("%.1f", speed))
		end

		-- Normalize bar fill against maxSpeed (as percentage)
		local skyriding = self:IsSkyridingActive()
		if skyriding then
			self._sessionMaxSpeed = math.max(self._sessionMaxSpeed or 0, speedPct)
		else
			self._sessionMaxSpeed = nil
		end

		local effectiveMax = baseMax
		if skyriding and self._sessionMaxSpeed and self._sessionMaxSpeed > effectiveMax then
			effectiveMax = self._sessionMaxSpeed
		end
		if effectiveMax <= 0 then effectiveMax = 1 end

		local pct = Clamp(speedPct / effectiveMax, 0, 1)
		self.speedBar:SetValue(pct)
		local r, g, b = ColorForPct(pct)
		self.speedBar:SetStatusBarColor(r, g, b, 1)

		local sustainableSpeed = (self.db.profile.speedBar and self.db.profile.speedBar.sustainableSpeed) or (self.db.profile.speedBar and self.db.profile.speedBar.optimalSpeed) or 0
		if sustainableSpeed and sustainableSpeed > 0 then
			local op = Clamp(sustainableSpeed / effectiveMax, 0, 1)
			self.sustainableMarker:Show()
			self.sustainableMarker:ClearAllPoints()
			self.sustainableMarker:SetPoint("TOP", self.speedBar, "TOPLEFT", op * self.speedBar:GetWidth(), 0)
			self.sustainableMarker:SetPoint("BOTTOM", self.speedBar, "BOTTOMLEFT", op * self.speedBar:GetWidth(), 0)
		else
			self.sustainableMarker:Hide()
		end

		-- Acceleration bar: shows rate of speed change
		-- Calculate delta from last frame
		local lastSpeedPct = self._lastSpeedPct or speedPct
		local deltaSpeed = speedPct - lastSpeedPct
		self._lastSpeedPct = speedPct

		-- Smooth the delta a bit to avoid jitter
		self._smoothDelta = (self._smoothDelta or 0) * 0.7 + deltaSpeed * 0.3

		-- Update acceleration bar
		if self.accelBar and self.accelFrame then
			local barWidth = self.accelFrame:GetWidth()
			local barHeight = self.accelFrame:GetHeight()
			local centerX = barWidth / 2

			-- Scale: clamp raw delta to ±1 range
			local maxDelta = 30  -- Max delta per update to show full bar extension
			local deltaNorm = Clamp(self._smoothDelta / maxDelta, -1, 1)

			-- Apply square root curve: more sensitive near zero, compressed at extremes
			-- sqrt(|x|) * sign(x) gives us the ramped response
			local sign = deltaNorm >= 0 and 1 or -1
			local curved = sign * math.sqrt(math.abs(deltaNorm))

			-- Minimum size is a small square (barHeight x barHeight)
			local minSize = math.max(barHeight, 2)

			self.accelBar:ClearAllPoints()
			self.accelBar:SetHeight(barHeight)
			-- Bar is always white
			self.accelBar:SetColorTexture(1, 1, 1, 0.9)

			if math.abs(curved) < 0.05 then
				-- Stable: show small centered square
				self.accelBar:SetWidth(minSize)
				self.accelBar:SetPoint("CENTER", self.accelFrame, "CENTER", 0, 0)
			elseif curved >= 0 then
				-- Accelerating: bar extends right from center
				local extentWidth = curved * centerX
				if extentWidth < minSize then extentWidth = minSize end
				self.accelBar:SetWidth(extentWidth)
				self.accelBar:SetPoint("LEFT", self.accelFrame, "LEFT", centerX, 0)
			else
				-- Decelerating: bar extends left from center
				local extentWidth = (-curved) * centerX
				if extentWidth < minSize then extentWidth = minSize end
				self.accelBar:SetWidth(extentWidth)
				self.accelBar:SetPoint("RIGHT", self.accelFrame, "LEFT", centerX, 0)
			end
		end

		-- ============================================================
		-- Ability Bars: Surge Forward, Second Wind charges & Whirling Surge cooldown
		-- ============================================================
		-- In combat or restricted zones (Midnight API restrictions), spell APIs may be
		-- unavailable. We detect this by checking if maxCharges comes back nil/0.
		-- If APIs are restricted, we hide ability bars gracefully.
		local ANIM_SPEED = 3.0  -- Speed for "fill up" animation (units per second)
		local now = GetTime()
		local dt = now - (self._lastAbilityUpdate or now)
		self._lastAbilityUpdate = now

		-- Get Surge Forward info first (used by multiple bars for dimming)
		-- Also use this to detect if spell APIs are available
		local surgeInfo = GetSpellCooldownSafe(SURGE_FORWARD_SPELL_ID, true)
		local apisRestricted = (surgeInfo.maxCharges == nil or surgeInfo.maxCharges == 0)

		-- Hide ability bars if APIs are restricted (combat lockdown in restricted zones)
		if apisRestricted then
			if self.surgeForwardFrame then self.surgeForwardFrame:Hide() end
			if self.secondWindFrame then self.secondWindFrame:Hide() end
			if self.whirlingSurgeBar then self.whirlingSurgeBar:Hide() end
		else
			-- Show ability bars (visibility permitting)
			if self.surgeForwardFrame and self.db.profile.abilityBars and self.db.profile.abilityBars.showSurgeForward ~= false then
				self.surgeForwardFrame:Show()
			end
			if self.secondWindFrame and self.db.profile.abilityBars and self.db.profile.abilityBars.showSecondWind then
				self.secondWindFrame:Show()
			end
			if self.whirlingSurgeBar and self.db.profile.abilityBars and self.db.profile.abilityBars.showWhirlingSurge then
				self.whirlingSurgeBar:Show()
			end
		end

		local surgeCharges = surgeInfo.currentCharges or 0
		local surgeMaxCharges = surgeInfo.maxCharges or 6
		local surgeAtMax = (surgeCharges >= surgeMaxCharges)

		-- Surge Forward (6 charges)
		if self.surgeForwardFrame and self.surgeForwardBars and self.db.profile.abilityBars and self.db.profile.abilityBars.showSurgeForward ~= false then
			local chargeStart = surgeInfo.chargeStart or 0
			local chargeDuration = surgeInfo.chargeDuration or 0

			-- Surge Forward does NOT dim when at max (you can use it!)
			local barAlpha = 1
			local bgAlpha = 0.85

			for i = 1, 6 do
				local bar = self.surgeForwardBars[i]
				local bg = self.surgeForwardBarBgs and self.surgeForwardBarBgs[i]
				if bar then
					-- Update background alpha
					if bg then
						bg:SetColorTexture(0.08, 0.12, 0.18, bgAlpha)
					end

					local targetPct = 0

					if i <= surgeCharges then
						-- This charge is full
						targetPct = 1
					elseif i == surgeCharges + 1 and chargeDuration > 0 then
						-- This charge is recharging
						local cdElapsed = now - chargeStart
						targetPct = Clamp(cdElapsed / chargeDuration, 0, 1)
					else
						-- This charge is empty (waiting for earlier charges)
						targetPct = 0
					end

					-- Track if we need to animate (charge just became full)
					local lastTarget = self._surgeForwardLastTarget and self._surgeForwardLastTarget[i] or 0
					self._surgeForwardLastTarget = self._surgeForwardLastTarget or {}
					self._surgeForwardLastTarget[i] = targetPct

					if targetPct >= 1 and lastTarget < 1 then
						-- Just became full - start animating
						self._surgeForwardAnimating[i] = true
					end

					if self._surgeForwardAnimating[i] then
						-- Animating to full
						self._surgeForwardAnimValue[i] = (self._surgeForwardAnimValue[i] or 0) + dt * ANIM_SPEED
						if self._surgeForwardAnimValue[i] >= 1 then
							self._surgeForwardAnimValue[i] = 1
							self._surgeForwardAnimating[i] = false
						end
						bar:SetValue(self._surgeForwardAnimValue[i])
						local r, g, b = ColorForPctSurgeForward(self._surgeForwardAnimValue[i])
						bar:SetStatusBarColor(r, g, b, barAlpha)
					else
						-- Not animating, use actual value
						self._surgeForwardAnimValue[i] = targetPct
						bar:SetValue(targetPct)
						local r, g, b = ColorForPctSurgeForward(targetPct)
						bar:SetStatusBarColor(r, g, b, barAlpha)
					end
				end
			end
		end

		-- Whirling Surge (30s cooldown)
		if self.whirlingSurgeBar and self.db.profile.abilityBars and self.db.profile.abilityBars.showWhirlingSurge then
			local info = GetSpellCooldownSafe(WHIRLING_SURGE_SPELL_ID)
			local onCooldown = info and info.startTime and info.duration and info.duration > 1.5

			if onCooldown then
				local cdElapsed = now - info.startTime
				local pct = Clamp(cdElapsed / info.duration, 0, 1)

				-- Reset animation state when ability goes on cooldown
				if self._whirlingSurgeWasReady then
					self._whirlingSurgeAnimating = false
					self._whirlingSurgeAnimValue = 0
				end
				self._whirlingSurgeWasReady = false

				-- Still on cooldown, show fill based on elapsed time
				self.whirlingSurgeBar:SetValue(pct)
				local r, g, b = ColorForPctBlue(pct)
				self.whirlingSurgeBar:SetStatusBarColor(r, g, b, 1)
			else
				-- Off cooldown - animate quickly to full if we were on cooldown
				if not self._whirlingSurgeWasReady and self._whirlingSurgeAnimValue and self._whirlingSurgeAnimValue < 1 then
					self._whirlingSurgeAnimating = true
				end
				self._whirlingSurgeWasReady = true

				if self._whirlingSurgeAnimating then
					self._whirlingSurgeAnimValue = (self._whirlingSurgeAnimValue or 0) + dt * ANIM_SPEED
					if self._whirlingSurgeAnimValue >= 1 then
						self._whirlingSurgeAnimValue = 1
						self._whirlingSurgeAnimating = false
					end
					self.whirlingSurgeBar:SetValue(self._whirlingSurgeAnimValue)
					local r, g, b = ColorForPctBlue(self._whirlingSurgeAnimValue)
					self.whirlingSurgeBar:SetStatusBarColor(r, g, b, 1)
				else
					-- Show full
					self.whirlingSurgeBar:SetValue(1)
					local r, g, b = ColorForPctBlue(1)
					self.whirlingSurgeBar:SetStatusBarColor(r, g, b, 1)
				end
			end
		end

		-- Second Wind (3 charges, 3 min recharge each)
		if self.secondWindFrame and self.secondWindBars and self.db.profile.abilityBars and self.db.profile.abilityBars.showSecondWind then
			local info = GetSpellCooldownSafe(SECOND_WIND_SPELL_ID, true)  -- Request charge info
			local currentCharges = info.currentCharges or 0
			local maxCharges = info.maxCharges or 3
			local chargeStart = info.chargeStart or 0
			local chargeDuration = info.chargeDuration or 0

			-- Use surgeAtMax from above for dimming
			local barAlpha = surgeAtMax and 0.2 or 1  -- Dim to 20% when Second Wind is unusable
			local bgAlpha = surgeAtMax and 0.17 or 0.85  -- Dim background proportionally (0.85 * 0.2 ≈ 0.17)

			for i = 1, 3 do
				local bar = self.secondWindBars[i]
				local bg = self.secondWindBarBgs and self.secondWindBarBgs[i]
				if bar then
					-- Update background alpha
					if bg then
						bg:SetColorTexture(0.08, 0.12, 0.18, bgAlpha)
					end

					local targetPct = 0

					if i <= currentCharges then
						-- This charge is full
						targetPct = 1
					elseif i == currentCharges + 1 and chargeDuration > 0 then
						-- This charge is recharging
						local cdElapsed = now - chargeStart
						targetPct = Clamp(cdElapsed / chargeDuration, 0, 1)
					else
						-- This charge is empty (waiting for earlier charges)
						targetPct = 0
					end

					-- Track if we need to animate (charge just became full)
					local lastTarget = self._secondWindLastTarget and self._secondWindLastTarget[i] or 0
					self._secondWindLastTarget = self._secondWindLastTarget or {}
					self._secondWindLastTarget[i] = targetPct

					if targetPct >= 1 and lastTarget < 1 then
						-- Just became full - start animating
						self._secondWindAnimating[i] = true
					end

					if self._secondWindAnimating[i] then
						-- Animating to full
						self._secondWindAnimValue[i] = (self._secondWindAnimValue[i] or 0) + dt * ANIM_SPEED
						if self._secondWindAnimValue[i] >= 1 then
							self._secondWindAnimValue[i] = 1
							self._secondWindAnimating[i] = false
						end
						bar:SetValue(self._secondWindAnimValue[i])
						local r, g, b = ColorForPctPurple(self._secondWindAnimValue[i])
						bar:SetStatusBarColor(r, g, b, barAlpha)
					else
						-- Not animating, use actual value
						self._secondWindAnimValue[i] = targetPct
						bar:SetValue(targetPct)
						local r, g, b = ColorForPctPurple(targetPct)
						bar:SetStatusBarColor(r, g, b, barAlpha)
					end
				end
			end
		end
	end)
end

function FlightsimUI:SetScale(scale)
	scale = Clamp(scale or 1, 0.5, 2.0)
	self.db.profile.scale = scale
	-- Apply scale to all frames
	if self.frame then self.frame:SetScale(scale) end
	if self.accelFrame then self.accelFrame:SetScale(scale) end
	if self.surgeForwardFrame then self.surgeForwardFrame:SetScale(scale) end
	if self.secondWindFrame then self.secondWindFrame:SetScale(scale) end
	if self.whirlingSurgeBar then self.whirlingSurgeBar:SetScale(scale) end
end

function FlightsimUI:SetWidth(width)
	width = tonumber(width)
	if not width then return end
	width = Clamp(width, 50, 800)
	self.db.profile.ui.width = width
	self:RebuildLayout()
end

function FlightsimUI:SetBarHeight(height)
	height = tonumber(height)
	if not height then return end
	height = Clamp(height, 10, 100)
	self.db.profile.ui.speedBarHeight = height
	self:RebuildLayout()
end

function FlightsimUI:SetSpeedBarMax(maxSpeed)
	maxSpeed = tonumber(maxSpeed)
	if not maxSpeed then return end
	maxSpeed = Clamp(maxSpeed, 100, 1500)
	self.db.profile.speedBar.maxSpeed = maxSpeed
end

function FlightsimUI:SetFontSize(fontSize)
	fontSize = tonumber(fontSize)
	if not fontSize then return end
	fontSize = Clamp(fontSize, 8, 48)
	self.db.profile.speedBar.fontSize = fontSize
	if self.speedText then
		self.speedText:SetFont("Fonts\\ARIALN.TTF", fontSize, "OUTLINE")
	end
end

function FlightsimUI:SetSustainableSpeed(sustainableSpeed)
	sustainableSpeed = tonumber(sustainableSpeed)
	if not sustainableSpeed then return end
	local maxSpeed = (self.db.profile.speedBar and self.db.profile.speedBar.maxSpeed) or 1100
	sustainableSpeed = Clamp(sustainableSpeed, 0, maxSpeed)
	self.db.profile.speedBar.sustainableSpeed = sustainableSpeed
end

function FlightsimUI:DebugDump()
	local function PrintKV(k, v)
		print(string.format("Flightsim debug: %s = %s", tostring(k), tostring(v)))
	end

	-- Use C_AddOns.IsAddOnLoaded (modern) or fall back to IsAddOnLoaded (legacy)
	local function IsAddonLoaded(name)
		if C_AddOns and C_AddOns.IsAddOnLoaded then
			return C_AddOns.IsAddOnLoaded(name)
		elseif IsAddOnLoaded then
			return IsAddOnLoaded(name)
		end
		return false
	end

	print("Flightsim debug: ----")
	-- Use C_AddOns.GetAddOnMetadata (modern) or fall back to GetAddOnMetadata (legacy)
	local version = "?"
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		version = C_AddOns.GetAddOnMetadata("Flightsim", "Version") or "?"
	elseif GetAddOnMetadata then
		version = GetAddOnMetadata("Flightsim", "Version") or "?"
	end
	-- @project-version@ is replaced by CurseForge packager; show "dev" for local installs
	if version:find("@") then version = "dev" end
	PrintKV("Version", version)
	-- BugGrabber folder is named "!BugGrabber" (with ! prefix for load order)
	PrintKV("BugGrabber loaded", (IsAddonLoaded("!BugGrabber") or IsAddonLoaded("BugGrabber")) and "yes" or "no")
	PrintKV("BugSack loaded", IsAddonLoaded("BugSack") and "yes" or "no")
	PrintKV("Has GetSpellCharges", type(GetSpellCharges) == "function" and "yes" or "no")
	PrintKV("Has C_Spell.GetSpellCharges", (C_Spell and type(C_Spell.GetSpellCharges) == "function") and "yes" or "no")
	PrintKV("Has C_PlayerInfo.IsPlayerInSkyriding", (C_PlayerInfo and type(C_PlayerInfo.IsPlayerInSkyriding) == "function") and "yes" or "no")
	PrintKV("Has C_PlayerInfo.IsPlayerInDragonriding", (C_PlayerInfo and type(C_PlayerInfo.IsPlayerInDragonriding) == "function") and "yes" or "no")

	if not (self.db and self.db.profile) then
		print("Flightsim debug: DB not initialized")
		return
	end

	local p = self.db.profile
	PrintKV("locked", p.locked)
	PrintKV("x", p.x)
	PrintKV("y", p.y)
	PrintKV("scale", p.scale)
	PrintKV("ui.width", p.ui and p.ui.width)
	PrintKV("speedBar.maxSpeed", p.speedBar and p.speedBar.maxSpeed)
	PrintKV("speedBar.optimalSpeed", p.speedBar and p.speedBar.optimalSpeed)
	PrintKV("hideWhenNotSkyriding", p.visibility and p.visibility.hideWhenNotSkyriding)

	local speed = GetUnitSpeedSafe("player")
	PrintKV("GetUnitSpeed(player)", string.format("%.2f", speed))
	PrintKV("IsMounted", IsMounted() and "yes" or "no")
	PrintKV("IsFlying", IsFlying() and "yes" or "no")
	
	-- Detailed GetGlidingInfo debug
	if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
		local ok, isGliding, canGlide, forwardSpeed = pcall(C_PlayerInfo.GetGlidingInfo)
		PrintKV("GetGlidingInfo.ok", ok and "yes" or "no")
		PrintKV("GetGlidingInfo.isGliding", isGliding and "yes" or "no")
		PrintKV("GetGlidingInfo.canGlide", canGlide and "yes" or "no")
		PrintKV("GetGlidingInfo.forwardSpeed", tostring(forwardSpeed))
	else
		PrintKV("GetGlidingInfo", "API not available")
	end
	
	PrintKV("IsSkyridingActive", self:IsSkyridingActive() and "yes" or "no")
	PrintKV("Frame shown", (self.frame and self.frame:IsShown()) and "yes" or "no")

	print("Flightsim debug: abilities ----")
	for i, token in ipairs((p.abilities and p.abilities.order) or {}) do
		local enabled = (p.abilities.enabled == nil) or (p.abilities.enabled[token] ~= false)
		local spellID, iconID = ResolveSpellInfo(token)
		local cur, max = nil, nil
		if spellID then
			cur, max = GetSpellChargesSafe(spellID)
		end
		print(string.format(
			"Flightsim debug: %d) %s enabled=%s spellID=%s icon=%s charges=%s/%s",
			i,
			tostring(token),
			enabled and "yes" or "no",
			tostring(spellID),
			tostring(iconID),
			tostring(cur),
			tostring(max)
		))
	end

	print("Flightsim debug: ---- end")
end

function FlightsimUI:Status()
	if not (self.db and self.db.profile) then
		print("Flightsim: not initialized")
		return
	end

	local skyriding = self:IsSkyridingActive()
	local speed = GetUnitSpeedSafe("player")
	local maxSpeed = (self.db.profile.speedBar and self.db.profile.speedBar.maxSpeed) or 20
	local optimalSpeed = (self.db.profile.speedBar and self.db.profile.speedBar.optimalSpeed) or 0

	local showState = (self.frame and self.frame:IsShown()) and "shown" or "hidden"
	local ridingState = skyriding and "skyriding" or "not skyriding"

	local chargeState = "charges UI disabled"

	local optimalStr = (optimalSpeed and optimalSpeed > 0) and string.format("optimal %.1f", optimalSpeed) or "optimal off"

	print(string.format(
		"Flightsim: %s, frame %s, speed %.1f (max %.1f, %s), %s",
		ridingState,
		showState,
		speed,
		maxSpeed,
		optimalStr,
		chargeState
	))
end
