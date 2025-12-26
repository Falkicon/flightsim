FlightsimUI = FlightsimUI or {}
FlightsimUI.Utils = FlightsimUI.Utils or {}
FlightsimUI.debugBuffer = {}

-- Performance Tracking
FlightsimUI.perf = {
	blocks = {
		state = 0,
		speed = 0,
		accel = 0,
		prep = 0,
		surge = 0,
		whirling = 0,
		wind = 0,
	},
	lastUpdate = 0,
}

-- Testing Definitions
FlightsimUI.tests = {
	{ id = "api_diag", name = "API Diagnostic", category = "API Diagnostic", type = "auto", description = "Checks core skyriding APIs for secret values." },
	{ id = "ui_compliance", name = "UI Compliance", category = "UI Compliance", type = "auto", description = "Verifies StatusBar compliance with secret passthrough." },
}

local function IsSecret(val)
	if val == nil then return false end
	if issecretvalue then
		return issecretvalue(val) == true
	end
	-- Robust fallback for secret-like objects that crash comparisons
	local ok = pcall(function() local _ = (val > -1e12) end)
	return not ok
end

local function SafeToString(val)
	if val == nil then
		return "nil"
	end
	if IsSecret(val) then
		return "???"
	end
	return tostring(val)
end

local function SafeCompare(a, b, op)
	if a == nil or b == nil then
		return nil
	end
	if IsSecret(a) or IsSecret(b) then
		return nil
	end
	if op == ">" then
		return a > b
	elseif op == "<" then
		return a < b
	elseif op == ">=" then
		return a >= b
	elseif op == "<=" then
		return a <= b
	elseif op == "==" then
		return a == b
	elseif op == "~=" then
		return a ~= b
	end
	return nil
end

local function DebugLog(...)
	if not Flightsim or not Flightsim.debugMode then
		return
	end

	local msg = ""
	local n = select("#", ...)
	for i = 1, n do
		local v = select(i, ...)
		msg = msg .. (i > 1 and " " or "") .. SafeToString(v)
	end

	-- Log to internal buffer for Mechanic's pull model
	table.insert(FlightsimUI.debugBuffer, {
		msg = msg,
		time = GetTime(),
	})
	if #FlightsimUI.debugBuffer > 500 then
		table.remove(FlightsimUI.debugBuffer, 1)
	end

	-- Log to Mechanic's live console if available
	local MechanicLib = LibStub("MechanicLib-1.0", true)
	if MechanicLib then
		local category = MechanicLib.Categories.CORE
		-- Quick category heuristic
		if msg:find("secret") or msg:find("???") then
			category = MechanicLib.Categories.SECRET
		elseif msg:find("API") or msg:find("charges") or msg:find("GetSpell") then
			category = MechanicLib.Categories.API
		elseif msg:find("Block") then
			category = MechanicLib.Categories.PERF
		end
		MechanicLib:Log("Flightsim", msg, category)
	end

	if Flightsim.debugMode then
		print("|cff74AFFF[Flightsim]|r", msg)
	end
end

local function Clamp(n, minV, maxV)
	if n < minV then
		return minV
	end
	if n > maxV then
		return maxV
	end
	return n
end
FlightsimUI.Utils.Clamp = Clamp

-- Blizzard-matching color palette (based on #2BA604 green)
local COLOR_GREEN = { 0.169, 0.651, 0.016 } -- #2BA604
local COLOR_YELLOW = { 0.769, 0.651, 0.016 } -- #C4A604 (gold)
local COLOR_RED = { 0.769, 0.169, 0.016 } -- #C42B04

-- Surge Forward color: #74AFFF (light blue)
local COLOR_SURGE_FORWARD = { 0.455, 0.686, 1.0 } -- #74AFFF
local COLOR_SURGE_FORWARD_EMPTY = { 0.18, 0.27, 0.4 } -- Dimmed version

-- Second Wind color: #D379EF (purple/magenta)
local COLOR_SECOND_WIND = { 0.827, 0.475, 0.937 } -- #D379EF
local COLOR_SECOND_WIND_EMPTY = { 0.33, 0.19, 0.37 } -- Dimmed version

-- Whirling Surge color: #4AC7D4 (cyan/teal)
local COLOR_WHIRLING_SURGE = { 0.290, 0.780, 0.831 } -- #4AC7D4
local COLOR_WHIRLING_SURGE_EMPTY = { 0.12, 0.31, 0.33 } -- Dimmed version

local function ColorForPct(pct)
	-- Ramp: red (0%) -> yellow (50%) -> green (100%)
	pct = Clamp(pct or 0, 0, 1)
	local r, g, b
	if pct < 0.5 then
		-- red -> yellow (0% to 50%)
		local t = pct * 2 -- 0 -> 1 as pct goes 0 -> 0.5
		r = COLOR_RED[1] + (COLOR_YELLOW[1] - COLOR_RED[1]) * t
		g = COLOR_RED[2] + (COLOR_YELLOW[2] - COLOR_RED[2]) * t
		b = COLOR_RED[3] + (COLOR_YELLOW[3] - COLOR_RED[3]) * t
	else
		-- yellow -> green (50% to 100%)
		local t = (pct - 0.5) * 2 -- 0 -> 1 as pct goes 0.5 -> 1
		r = COLOR_YELLOW[1] + (COLOR_GREEN[1] - COLOR_YELLOW[1]) * t
		g = COLOR_YELLOW[2] + (COLOR_GREEN[2] - COLOR_YELLOW[2]) * t
		b = COLOR_YELLOW[3] + (COLOR_GREEN[3] - COLOR_YELLOW[3]) * t
	end
	return r, g, b
end
FlightsimUI.Utils.ColorForPct = ColorForPct

local function ColorForPctBlue(pct)
	-- Simple lerp: empty -> full for Whirling Surge (#4AC7D4)
	pct = Clamp(pct or 0, 0, 1)
	local r = COLOR_WHIRLING_SURGE_EMPTY[1] + (COLOR_WHIRLING_SURGE[1] - COLOR_WHIRLING_SURGE_EMPTY[1]) * pct
	local g = COLOR_WHIRLING_SURGE_EMPTY[2] + (COLOR_WHIRLING_SURGE[2] - COLOR_WHIRLING_SURGE_EMPTY[2]) * pct
	local b = COLOR_WHIRLING_SURGE_EMPTY[3] + (COLOR_WHIRLING_SURGE[3] - COLOR_WHIRLING_SURGE_EMPTY[3]) * pct
	return r, g, b
end
FlightsimUI.Utils.ColorForPctBlue = ColorForPctBlue

local function ColorForPctPurple(pct)
	-- Simple lerp: empty -> full for Second Wind (#D379EF)
	pct = Clamp(pct or 0, 0, 1)
	local r = COLOR_SECOND_WIND_EMPTY[1] + (COLOR_SECOND_WIND[1] - COLOR_SECOND_WIND_EMPTY[1]) * pct
	local g = COLOR_SECOND_WIND_EMPTY[2] + (COLOR_SECOND_WIND[2] - COLOR_SECOND_WIND_EMPTY[2]) * pct
	local b = COLOR_SECOND_WIND_EMPTY[3] + (COLOR_SECOND_WIND[3] - COLOR_SECOND_WIND_EMPTY[3]) * pct
	return r, g, b
end
FlightsimUI.Utils.ColorForPctPurple = ColorForPctPurple

local function ColorForPctSurgeForward(pct)
	-- Simple lerp: empty -> full for Surge Forward (#74AFFF)
	pct = Clamp(pct or 0, 0, 1)
	local r = COLOR_SURGE_FORWARD_EMPTY[1] + (COLOR_SURGE_FORWARD[1] - COLOR_SURGE_FORWARD_EMPTY[1]) * pct
	local g = COLOR_SURGE_FORWARD_EMPTY[2] + (COLOR_SURGE_FORWARD[2] - COLOR_SURGE_FORWARD_EMPTY[2]) * pct
	local b = COLOR_SURGE_FORWARD_EMPTY[3] + (COLOR_SURGE_FORWARD[3] - COLOR_SURGE_FORWARD_EMPTY[3]) * pct
	return r, g, b
end
FlightsimUI.Utils.ColorForPctSurgeForward = ColorForPctSurgeForward

-- WeakAura-inspired skyriding constants (Retail 11.x):
-- These are used only where they map cleanly to addon-safe APIs.
local SLOW_SKYRIDING_RATIO = 705 / 830
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

-- Spell IDs for ability tracking
local WHIRLING_SURGE_SPELL_ID = 361584
local SECOND_WIND_SPELL_ID = 425782 -- Second Wind (restores Surge Forward charges)
local SURGE_FORWARD_SPELL_ID = 372608 -- Surge Forward (6 charges)

local function GetUnitSpeedSafe(unit)
	local fn = GetUnitSpeed or UnitSpeed
	if type(fn) == "function" then
		local ok, result = pcall(fn, unit)
		if ok and result then
			-- In Midnight combat, result may be a secret value (not a number).
			-- We return it anyway so it can be passed to StatusBars.
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

function FlightsimUI:_UpdateSkyridingState(now)
	-- Zone normalization (WA behavior): treat some zones as "slow" and scale up.
	self._isSlowSkyriding = IsSlowSkyridingZone()
end

function FlightsimUI:_GetSkyridingSpeed(now)
	-- Returns: speed, isGliding
	if C_PlayerInfo and type(C_PlayerInfo.GetGlidingInfo) == "function" then
		local ok, isGliding, _, forwardSpeed = pcall(C_PlayerInfo.GetGlidingInfo)
		if ok and isGliding then
			-- In Midnight combat, forwardSpeed may be a secret value.
			-- isGliding will be true if secret or boolean true.
			local adjusted = forwardSpeed
			if not (issecretvalue and issecretvalue(adjusted)) then
			if self._isSlowSkyriding then
				adjusted = adjusted / SLOW_SKYRIDING_RATIO
				end
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
				local cur = a.currentCharges
				if cur == nil then
					cur = a.charges
				end
				local max = a.maxCharges
				if max == nil then
					max = a.max
				end
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
	local hasStartTime = false
	if IsSecret(_cooldownResult.startTime) then
		hasStartTime = true
	elseif _cooldownResult.startTime ~= nil then
		hasStartTime = true
	end

	if not hasStartTime and type(GetSpellCooldown) == "function" then
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
	if not token then
		return nil, nil
	end

	if C_Spell and C_Spell.GetSpellInfo then
		local ok, info = pcall(C_Spell.GetSpellInfo, token)
		if ok and info and info.spellID then
			return info.spellID, info.iconID
		end
	end

	-- Fallback for older clients or transition periods
	if type(GetSpellInfo) == "function" then
		local ok, _, _, icon, _, _, _, spellID = pcall(GetSpellInfo, token)
		if ok then
			return spellID or (type(token) == "number" and token), icon
		end
	end

	return (type(token) == "number" and token) or nil, nil
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

	-- 1. Primary: GetGlidingInfo (The most accurate when it works)
	if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
		local ok, isGliding, canGlide = pcall(C_PlayerInfo.GetGlidingInfo)
		if ok and (isGliding or canGlide) then
				result = true
		end
	end

	-- 2. Definitive Fallback: Check for Surge Forward charges (372608)
	-- If the player has this spell with charges, they are in Skyriding mode.
	if not result and (isMounted or isDruidFlying) then
		local surgeCharges = GetSpellCooldownSafe(372608, true)
		if surgeCharges and surgeCharges.maxCharges then
			local maxRaw = surgeCharges.maxCharges
			local isMaxSecret = issecretvalue and issecretvalue(maxRaw)
			if not isMaxSecret and type(maxRaw) == "number" and maxRaw > 0 then
				result = true
			elseif isMaxSecret then
				result = true
			end
		end
	end

	-- 3. Legacy Fallbacks: check older API names
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

	-- Cache the result
	self._skyridingCacheTime = now
	self._skyridingCacheResult = result
	return result
end

local function IsSecret(val)
	if val == nil then return false end
	if issecretvalue then
		return issecretvalue(val) == true
	end
	-- Robust fallback for secret-like objects that crash comparisons
	local ok = pcall(function() local _ = (val > -1e12) end)
	return not ok
end

local function SafeCompare(a, b, op)
	if a == nil or b == nil then
		return nil
	end
	if IsSecret(a) or IsSecret(b) then
		return nil
	end
	if op == ">" then
		return a > b
	elseif op == "<" then
		return a < b
	elseif op == ">=" then
		return a >= b
	elseif op == "<=" then
		return a <= b
	elseif op == "==" then
		return a == b
	elseif op == "~=" then
		return a ~= b
	end
	return nil
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

	-- Event hooks for skyriding state (zone changes).
	local events = CreateFrame("Frame")
	self._eventFrame = events
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	events:SetScript("OnEvent", function(_, event, ...)
		-- Zone-related state refresh
		self._isSlowSkyriding = IsSlowSkyridingZone()
	end)

	local barBg = frame:CreateTexture(nil, "BACKGROUND")
	barBg:SetAllPoints(frame)
	-- Flat dark background.
	barBg:SetColorTexture(0.08, 0.12, 0.18, 0.85)
	self.speedBarBg = barBg

	-- Create an overlay frame on top of the StatusBar for text and marker
	-- This ensures they render above the StatusBar fill texture
	local overlay = CreateFrame("Frame", nil, frame)
	overlay:SetAllPoints(frame)
	overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
	self.speedBarOverlay = overlay

	-- Sustainable speed marker - parented to overlay frame
	local sustainableMarkerWidth = (db.profile.ui and db.profile.ui.sustainableSpeedMarkerWidth)
		or (db.profile.ui and db.profile.ui.optimalMarkerWidth)
		or 1
	local sustainableMarkerAlpha = (db.profile.ui and db.profile.ui.sustainableSpeedMarkerAlpha) or 0.2
	local optimal = overlay:CreateTexture(nil, "OVERLAY")
	optimal:SetColorTexture(1, 1, 1, sustainableMarkerAlpha)
	optimal:SetWidth(sustainableMarkerWidth)
	optimal:SetPoint("TOP", overlay, "TOP", 0, 0)
	optimal:SetPoint("BOTTOM", overlay, "BOTTOM", 0, 0)
	self.sustainableMarker = optimal

	-- Speed text - parented to overlay frame
	local speedText = overlay:CreateFontString(nil, "OVERLAY")
	-- Sans-serif look like WA.
	local fontSize = (db.profile.speedBar and db.profile.speedBar.fontSize) or 12
	speedText:SetFont("Fonts\\ARIALN.TTF", fontSize, "OUTLINE")
	speedText:SetPoint("LEFT", overlay, "LEFT", 6, 0)
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
	accelBar:SetColorTexture(1, 1, 1, 0.9) -- White
	accelBar:SetHeight(accelBarHeight)
	self.accelBar = accelBar

	-- Ability bars (below the acceleration bar)
	-- Order: Surge Forward -> Second Wind -> Whirling Surge
	local abilityBarHeight = (db.profile.ui and db.profile.ui.abilityBarHeight) or 10
	local barGap = (db.profile.ui and db.profile.ui.barGap) or 2
	local chargeGap = 2 -- Gap between charge bars within a multi-charge ability

	-- Surge Forward charge bars (6 charges, light blue #74AFFF)
	local surgeForwardFrame = CreateFrame("Frame", nil, UIParent)
	surgeForwardFrame:SetSize(db.profile.ui.width or 150, abilityBarHeight)
	surgeForwardFrame:SetPoint("TOP", accelFrame, "BOTTOM", 0, -barGap)
	self.surgeForwardFrame = surgeForwardFrame

	self.surgeForwardBars = {}
	self.surgeForwardBarBgs = {}
	local sfTotalGaps = chargeGap * 5 -- 5 gaps between 6 bars
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
			chargeBar:SetPoint("LEFT", self.surgeForwardBars[i - 1], "RIGHT", chargeGap, 0)
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
	local swTotalGaps = chargeGap * 2 -- 2 gaps between 3 bars
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
			chargeBar:SetPoint("LEFT", self.secondWindBars[i - 1], "RIGHT", chargeGap, 0)
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
	if not (self.frame and self.db and self.db.profile) then
		return
	end

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
	if self.accelFrame then
		self.accelFrame:SetScale(scale)
	end
	if self.surgeForwardFrame then
		self.surgeForwardFrame:SetScale(scale)
	end
	if self.secondWindFrame then
		self.secondWindFrame:SetScale(scale)
	end
	if self.whirlingSurgeBar then
		self.whirlingSurgeBar:SetScale(scale)
	end

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
						chargeBar:SetPoint("LEFT", self.surgeForwardBars[i - 1], "RIGHT", chargeGap, 0)
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
						chargeBar:SetPoint("LEFT", self.secondWindBars[i - 1], "RIGHT", chargeGap, 0)
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
	if not (self.frame and self.db and self.db.profile and self.db.profile.visibility) then
		return
	end

	-- Wrap visibility logic in pcall to handle API instability during flight mode transitions
	local ok, err = pcall(function()
		local v = self.db.profile.visibility
		local ab = self.db.profile.abilityBars or {}
		local skyriding = self:IsSkyridingActive()

		local shouldShow = true
		if v.hideWhenNotSkyriding and not skyriding then
			shouldShow = false
		end

		if shouldShow then
			if not self.frame:IsShown() then
				self.frame:Show()
			end
			self.frame:SetAlpha(1)
			
			if self.accelFrame and not self.accelFrame:IsShown() then
				self.accelFrame:Show()
			end
			if self.accelFrame then self.accelFrame:SetAlpha(1) end

			-- Respect individual ability bar settings
			if self.surgeForwardFrame and ab.showSurgeForward ~= false then
				if not self.surgeForwardFrame:IsShown() then
					self.surgeForwardFrame:Show()
				end
				self.surgeForwardFrame:SetAlpha(1)
			end
			if self.secondWindFrame and ab.showSecondWind ~= false then
				if not self.secondWindFrame:IsShown() then
					self.secondWindFrame:Show()
				end
				self.secondWindFrame:SetAlpha(1)
			end
			if self.whirlingSurgeBar and ab.showWhirlingSurge ~= false then
				if not self.whirlingSurgeBar:IsShown() then
					self.whirlingSurgeBar:Show()
				end
				self.whirlingSurgeBar:SetAlpha(1)
			end
		else
			if self.frame:IsShown() then
				self.frame:Hide()
			end
			if self.accelFrame and self.accelFrame:IsShown() then
				self.accelFrame:Hide()
			end
			if self.surgeForwardFrame and self.surgeForwardFrame:IsShown() then
				self.surgeForwardFrame:Hide()
			end
			if self.secondWindFrame and self.secondWindFrame:IsShown() then
				self.secondWindFrame:Hide()
			end
			if self.whirlingSurgeBar and self.whirlingSurgeBar:IsShown() then
				self.whirlingSurgeBar:Hide()
			end
		end
	end)

	if not ok and self.db.profile.debug then
		-- Only log if debug is enabled to avoid spamming the user
		local L = Flightsim.L
		print(L["VISIBILITY_ERROR"] .. tostring(err))
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
	if not self.frame then
		return
	end

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
		self.tickerFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS") -- For druid flight form
		self.tickerFrame:SetScript("OnEvent", function(_, event, unit)
			if event == "UNIT_AURA" and unit ~= "player" then
				return
			end
			-- Force visibility check on mount change and invalidate cache
			self._forceVisibilityCheck = true
			self._skyridingCacheTime = nil -- Invalidate cache immediately
		end)
	end

	self.tickerFrame:SetScript("OnUpdate", function(_, elapsed) -- luacheck: ignore
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
		if
			not mounted
			and not druidFlying
			and self.db
			and self.db.profile
			and self.db.profile.visibility
			and self.db.profile.visibility.hideWhenNotSkyriding
		then
			-- Force hide when not mounted and not in druid flight form (faster than full visibility check)
			if self.frame:IsShown() then
				self.frame:Hide()
				if self.accelFrame then
					self.accelFrame:Hide()
				end
				if self.surgeForwardFrame then
					self.surgeForwardFrame:Hide()
				end
				if self.secondWindFrame then
					self.secondWindFrame:Hide()
				end
				if self.whirlingSurgeBar then
					self.whirlingSurgeBar:Hide()
				end
			end
			return
		end

		self:ApplyVisibility()
		if not self.frame:IsShown() then
			return
		end

		local now = (GetTimePreciseSec and GetTimePreciseSec()) or GetTime()
		local block_start

		-- 1. Skyriding State & Speed (Primary detection)
		block_start = debugprofilestop()
		local speed, isGliding
		local ok_state, err_state = pcall(function()
			self:_UpdateSkyridingState(now)
			speed, isGliding = self:_GetSkyridingSpeed(now)
			if not isGliding then
				speed = GetUnitSpeedSafe("player")
				if SafeCompare(speed, 0, "<=") then
					speed = self:_GetFallbackSpeedFromPosition(elapsed)
				end
			end
		end)
		self.perf.blocks.state = debugprofilestop() - block_start
		if not ok_state then
			DebugLog("State/Speed update error:", err_state)
			speed = 0
			isGliding = false
		end

		-- 2. Speed Bar Update
		block_start = debugprofilestop()
		pcall(function()
			-- Check for secret values (Midnight combat)
			local isSpeedSecret = IsSecret(speed)

			if isSpeedSecret then
				DebugLog("Speed is secret value")
				-- DEGRADED MODE (Combat)
				-- Cannot perform arithmetic or string formatting on secret values.
				self.speedText:SetText("???")

				-- StatusBar passthrough works - pass the secret speed directly.
				-- We must also pass a secret or static max to SetMinMaxValues.
				-- Since we can't calculate percentage, we scale the bar to a fixed 1000 range
				-- and hope the secret value maps relatively well, or just show full.
				self.speedBar:SetMinMaxValues(0, 1000) -- Arbitrary high max for secret passthrough
				self.speedBar:SetValue(speed)
				self.speedBar:SetStatusBarColor(0.5, 0.5, 0.5, 1) -- Grey for "restricted"
				self.sustainableMarker:Hide()
			else
				-- NORMAL MODE
				local baseMax = 950
				if self.db.profile.speedBar and self.db.profile.speedBar.maxSpeed then
					baseMax = self.db.profile.speedBar.maxSpeed
				end
				if baseMax <= 0 then
					baseMax = 950
				end

				-- Convert raw speed (yards/sec) to percentage (WA-style: ~790% at stable, ~950% max)
				local speedVal = 0
				if type(speed) == "number" and not IsSecret(speed) then
					speedVal = speed
				end
				local speedPct = (speedVal / BASE_SPEED_FOR_PCT) * 100

				-- Display as percentage or raw speed
				local showPercent = true
				if self.db.profile.speedBar and self.db.profile.speedBar.showPercent == false then
					showPercent = false
				end

				if showPercent then
					self.speedText:SetText(string.format("%.0f%%", speedPct))
				else
					self.speedText:SetText(string.format("%.1f", speedVal))
				end

				-- Normalize bar fill against maxSpeed (as percentage)
				local skyriding = self:IsSkyridingActive()
				if skyriding then
					local smax = self._sessionMaxSpeed
					if smax == nil then
						smax = 0
					end
					self._sessionMaxSpeed = math.max(smax, speedPct)
				else
					self._sessionMaxSpeed = nil
				end

				local effectiveMax = baseMax
				if skyriding and self._sessionMaxSpeed and self._sessionMaxSpeed > effectiveMax then
					effectiveMax = self._sessionMaxSpeed
				end
				if effectiveMax <= 0 then
					effectiveMax = 1
				end

				local pct = Clamp(speedPct / effectiveMax, 0, 1)
				self.speedBar:SetMinMaxValues(0, 1)
				self.speedBar:SetValue(pct)
				local r, g, b = ColorForPct(pct)
				self.speedBar:SetStatusBarColor(r, g, b, 1)

				local sustainableSpeed = 0
				if self.db.profile.speedBar then
					sustainableSpeed = self.db.profile.speedBar.sustainableSpeed or self.db.profile.speedBar.optimalSpeed or 0
				end

				if sustainableSpeed and sustainableSpeed > 0 then
					local op = Clamp(sustainableSpeed / effectiveMax, 0, 1)
					self.sustainableMarker:Show()
					self.sustainableMarker:ClearAllPoints()
					self.sustainableMarker:SetPoint("TOP", self.speedBar, "TOPLEFT", op * self.speedBar:GetWidth(), 0)
					self.sustainableMarker:SetPoint("BOTTOM", self.speedBar, "BOTTOMLEFT", op * self.speedBar:GetWidth(), 0)
				else
					self.sustainableMarker:Hide()
				end

				self._lastSpeedPct_Internal = speedPct -- Used for accel bar
			end
		end)
		self.perf.blocks.speed = debugprofilestop() - block_start

		-- 3. Acceleration Bar Update
		block_start = debugprofilestop()
		pcall(function()
			local isSpeedSecret = IsSecret(speed)
			if isSpeedSecret then
				if self.accelBar then
					self.accelBar:Hide()
				end
				return
			end

			local speedPct = self._lastSpeedPct_Internal
			if speedPct then
				-- Calculate delta from last frame
				local lastSpeedPct = self._lastSpeedPct
				if lastSpeedPct == nil then
					lastSpeedPct = speedPct
				end
				local deltaSpeed = speedPct - lastSpeedPct
				self._lastSpeedPct = speedPct

				-- Smooth the delta a bit to avoid jitter
				local sDelta = self._smoothDelta
				if sDelta == nil then
					sDelta = 0
				end
				self._smoothDelta = sDelta * 0.7 + deltaSpeed * 0.3

				-- Update acceleration bar
				if self.accelBar and self.accelFrame then
					self.accelBar:Show()
					local barWidth = self.accelFrame:GetWidth()
					local barHeight = self.accelFrame:GetHeight()
					local centerX = barWidth / 2

					-- Scale: clamp raw delta to ±1 range
					local maxDelta = 30 -- Max delta per update to show full bar extension
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
						if extentWidth < minSize then
							extentWidth = minSize
						end
						self.accelBar:SetWidth(extentWidth)
						self.accelBar:SetPoint("LEFT", self.accelFrame, "LEFT", centerX, 0)
					else
						-- Decelerating: bar extends left from center
						local extentWidth = -curved * centerX
						if extentWidth < minSize then
							extentWidth = minSize
						end
						self.accelBar:SetWidth(extentWidth)
						self.accelBar:SetPoint("RIGHT", self.accelFrame, "LEFT", centerX, 0)
					end
				end
			end
		end)
		self.perf.blocks.accel = debugprofilestop() - block_start

		-- 4. Shared Ability State (Prep for charges/cooldowns)
		block_start = debugprofilestop()
		local surgeInfo, dt, surgeAtMax
		local ok_prep, err_prep = pcall(function()
			DebugLog("--- Ability Update Start ---")
			local now_val = GetTime()
			dt = now_val - (self._lastAbilityUpdate or now_val)
			self._lastAbilityUpdate = now_val

			DebugLog("Calling GetSpellCooldownSafe...")
			surgeInfo = GetSpellCooldownSafe(SURGE_FORWARD_SPELL_ID, true)
			DebugLog("surgeInfo obtained")

			local surgeChargesRaw = surgeInfo.currentCharges
			local surgeMaxRaw = surgeInfo.maxCharges
			DebugLog("Raw charges:", SafeToString(surgeChargesRaw), "/", SafeToString(surgeMaxRaw))

			local isSurgeSecret = IsSecret(surgeChargesRaw) or IsSecret(surgeMaxRaw)
			DebugLog("isSurgeSecret:", isSurgeSecret)

			if isSurgeSecret then
				DebugLog("Surge is secret, using IsSpellUsable")
				surgeAtMax = C_Spell.IsSpellUsable(SURGE_FORWARD_SPELL_ID) or false
			else
				local m = surgeMaxRaw or 6
				DebugLog("Comparing charges...")
				surgeAtMax = ((surgeChargesRaw or 0) >= m)
			end
			DebugLog("surgeAtMax:", surgeAtMax)

			-- Show/Hide ability frames based on profile
			if self.surgeForwardFrame then
				if self.db.profile.abilityBars and self.db.profile.abilityBars.showSurgeForward ~= false then
					self.surgeForwardFrame:Show()
				else
					self.surgeForwardFrame:Hide()
				end
			end
			if self.secondWindFrame then
				if self.db.profile.abilityBars and self.db.profile.abilityBars.showSecondWind then
					self.secondWindFrame:Show()
				else
					self.secondWindFrame:Hide()
				end
			end
			if self.whirlingSurgeBar then
				if self.db.profile.abilityBars and self.db.profile.abilityBars.showWhirlingSurge then
					self.whirlingSurgeBar:Show()
				else
					self.whirlingSurgeBar:Hide()
				end
			end
		end)
		self.perf.blocks.prep = debugprofilestop() - block_start
		if not ok_prep then
			DebugLog("Block 4 (Prep) error:", err_prep)
		end

		-- 5. Surge Forward Update
		block_start = debugprofilestop()
		local ok_sf, err_sf = pcall(function()
			DebugLog("Entering Block 5 (Surge)...")
			local surgeCondition = self.surgeForwardFrame
				and self.surgeForwardBars
				and self.db.profile.abilityBars
				and self.db.profile.abilityBars.showSurgeForward ~= false

			DebugLog("Surge condition:", surgeCondition, "Has surgeInfo:", surgeInfo ~= nil)

			if surgeCondition and surgeInfo then
				local ANIM_SPEED = 3.0
				local now_val = GetTime()
				local surgeChargesRaw = surgeInfo.currentCharges
				local surgeMaxRaw = surgeInfo.maxCharges
				local isSurgeSecret = IsSecret(surgeChargesRaw) or IsSecret(surgeMaxRaw)
				local surgeChargesCount = isSurgeSecret and 0 or (surgeChargesRaw or 0)

				local cStart = surgeInfo.chargeStart
				local cDur = surgeInfo.chargeDuration
				local isAnimSecret = IsSecret(cStart) or IsSecret(cDur)

				if isSurgeSecret then
					local usable = C_Spell.IsSpellUsable(SURGE_FORWARD_SPELL_ID) or false
					DebugLog("Surge is secret, usable proxy:", usable)

					-- TEST COLOR: RED if secret to distinguish from non-secret
					local r, g, b = 1, 0, 0
					if not self.db.profile.debugMode then
						r, g, b = COLOR_SURGE_FORWARD[1], COLOR_SURGE_FORWARD[2], COLOR_SURGE_FORWARD[3]
					end

					for i = 1, 6 do
						local bar = self.surgeForwardBars[i]
						if bar then
							-- Midnight Safety: Re-assert bar configuration
							bar:SetMinMaxValues(0, 1)
							bar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")

							-- DIRECT HUD TEST: If debug is on, make the first bar BRIGHT GREEN and ALWAYS FULL
							if i == 1 and self.db.profile.debugMode then
								bar:SetValue(1)
								bar:SetStatusBarColor(0, 1, 0, 1) -- Bright Green
							else
								bar:SetValue(usable and 1 or 0)
								bar:SetStatusBarColor(r, g, b, 1)
							end
							bar:SetAlpha(1)
						end
					end
				else
					local chargeStart = (cStart ~= nil and not IsSecret(cStart)) and cStart or 0
					local chargeDuration = (cDur ~= nil and not IsSecret(cDur)) and cDur or 0
					local barAlpha = 1
					local bgAlpha = 0.85

					for i = 1, 6 do
						local bar = self.surgeForwardBars[i]
						local bg = self.surgeForwardBarBgs and self.surgeForwardBarBgs[i]
						if bar then
							if bg then
								bg:SetColorTexture(0.08, 0.12, 0.18, bgAlpha)
							end

							local targetPct = 0
							if SafeCompare(i, surgeChargesCount, "<=") then
								targetPct = 1
							elseif SafeCompare(i, surgeChargesCount + 1, "==") and chargeDuration > 0 and not isAnimSecret then
								local cdElapsed = now_val - chargeStart
								targetPct = Clamp(cdElapsed / chargeDuration, 0, 1)
							else
								targetPct = 0
							end

							local lastTarget = (self._surgeForwardLastTarget and self._surgeForwardLastTarget[i]) or 0
							self._surgeForwardLastTarget = self._surgeForwardLastTarget or {}
							self._surgeForwardLastTarget[i] = targetPct

							if SafeCompare(targetPct, 1, ">=") and SafeCompare(lastTarget, 1, "<") then
								self._surgeForwardAnimating[i] = true
							end

							if self._surgeForwardAnimating[i] then
								local val = (self._surgeForwardAnimValue[i] or 0) + dt * ANIM_SPEED
								if val >= 1 then
									val = 1
									self._surgeForwardAnimating[i] = false
								end
								self._surgeForwardAnimValue[i] = val

								-- Midnight Safety: Re-assert configuration every frame
								bar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
								bar:SetMinMaxValues(0, 1)
								bar:SetValue(val)
								local r_val, g_val, b_val = ColorForPctSurgeForward(val)
								bar:SetStatusBarColor(r_val, g_val, b_val, barAlpha)
								bar:SetAlpha(1)
							else
								self._surgeForwardAnimValue[i] = targetPct

								-- Midnight Safety: Re-assert configuration every frame
								bar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
								bar:SetMinMaxValues(0, 1)
								bar:SetValue(targetPct)
								local r_val, g_val, b_val = ColorForPctSurgeForward(targetPct)
								bar:SetStatusBarColor(r_val, g_val, b_val, barAlpha)
								bar:SetAlpha(1)
							end
						end
					end
				end
			end
		end)
		self.perf.blocks.surge = debugprofilestop() - block_start
		if not ok_sf then
			DebugLog("Block 5 (Surge) error:", err_sf)
		end

		-- 6. Whirling Surge Update
		block_start = debugprofilestop()
		local ok_ws, err_ws = pcall(function()
			DebugLog("Entering Block 6 (Whirling)...")
			if self.whirlingSurgeBar and self.db.profile.abilityBars and self.db.profile.abilityBars.showWhirlingSurge then
				local info_ws = GetSpellCooldownSafe(WHIRLING_SURGE_SPELL_ID)
				local ws_dur = info_ws.duration
				local ws_start = info_ws.startTime
				local isWSSecret = IsSecret(ws_dur) or IsSecret(ws_start)

				if isWSSecret then
					local usable = C_Spell.IsSpellUsable(WHIRLING_SURGE_SPELL_ID)
					DebugLog("Whirling is secret, usable proxy:", usable)
					-- Midnight Safety: Re-assert bar configuration
					self.whirlingSurgeBar:SetMinMaxValues(0, 1)
					self.whirlingSurgeBar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
					self.whirlingSurgeBar:SetValue(usable and 1 or 0)
					self.whirlingSurgeBar:SetStatusBarColor(COLOR_WHIRLING_SURGE[1], COLOR_WHIRLING_SURGE[2], COLOR_WHIRLING_SURGE[3], 1)
					self.whirlingSurgeBar:SetAlpha(1)
				else
					local onCooldown = ws_dur and ws_dur > 1.5
					local now_val = GetTime()
					local ANIM_SPEED = 3.0

					if onCooldown then
						local cdElapsed = now_val - (ws_start or now_val)
						local pct_ws = Clamp(cdElapsed / ws_dur, 0, 1)
						if self._whirlingSurgeWasReady then
							self._whirlingSurgeAnimating = false
							self._whirlingSurgeAnimValue = 0
						end
						self._whirlingSurgeWasReady = false
						self.whirlingSurgeBar:SetValue(pct_ws)
						local r_ws, g_ws, b_ws = ColorForPctBlue(pct_ws)
						self.whirlingSurgeBar:SetStatusBarColor(r_ws, g_ws, b_ws, 1)
					else
						if not self._whirlingSurgeWasReady and (self._whirlingSurgeAnimValue or 0) < 1 then
							self._whirlingSurgeAnimating = true
						end
						self._whirlingSurgeWasReady = true
						if self._whirlingSurgeAnimating then
							local val = (self._whirlingSurgeAnimValue or 0) + dt * ANIM_SPEED
							if val >= 1 then
								val = 1
								self._whirlingSurgeAnimating = false
							end
							self._whirlingSurgeAnimValue = val
							-- Midnight Safety
							self.whirlingSurgeBar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
							self.whirlingSurgeBar:SetMinMaxValues(0, 1)
							self.whirlingSurgeBar:SetValue(val)
							local r_ws, g_ws, b_ws = ColorForPctBlue(val)
							self.whirlingSurgeBar:SetStatusBarColor(r_ws, g_ws, b_ws, 1)
							self.whirlingSurgeBar:SetAlpha(1)
						else
							-- Midnight Safety
							self.whirlingSurgeBar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
							self.whirlingSurgeBar:SetMinMaxValues(0, 1)
							self.whirlingSurgeBar:SetValue(1)
							local r_ws, g_ws, b_ws = ColorForPctBlue(1)
							self.whirlingSurgeBar:SetStatusBarColor(r_ws, g_ws, b_ws, 1)
							self.whirlingSurgeBar:SetAlpha(1)
						end
					end
				end
			end
		end)
		self.perf.blocks.whirling = debugprofilestop() - block_start
		if not ok_ws then
			DebugLog("Block 6 (Whirling) error:", err_ws)
		end

		-- 7. Second Wind Update
		block_start = debugprofilestop()
		local ok_wind, err_wind = pcall(function()
			DebugLog("Entering Block 7 (Wind)...")
			if self.secondWindFrame and self.secondWindBars and self.db.profile.abilityBars and self.db.profile.abilityBars.showSecondWind then
				local info_sw = GetSpellCooldownSafe(SECOND_WIND_SPELL_ID, true)
				local swChargesRaw = info_sw.currentCharges
				local swStart = info_sw.chargeStart
				local swDur = info_sw.chargeDuration
				local isSWSecret = IsSecret(swChargesRaw) or IsSecret(swStart) or IsSecret(swDur)

				if isSWSecret then
					local usable = C_Spell.IsSpellUsable(SECOND_WIND_SPELL_ID)
					DebugLog("Wind is secret, usable proxy:", usable)
					local barAlpha = surgeAtMax and 0.2 or 1
					for i = 1, 3 do
						local bar = self.secondWindBars[i]
						if bar then
							-- Midnight Safety: Re-assert bar configuration
							bar:SetMinMaxValues(0, 1)
							bar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
							bar:SetValue(usable and 1 or 0)
							bar:SetStatusBarColor(COLOR_SECOND_WIND[1], COLOR_SECOND_WIND[2], COLOR_SECOND_WIND[3], barAlpha)
							bar:SetAlpha(1)
						end
					end
				else
					local currentCharges = swChargesRaw or 0
					local chargeStart = swStart or 0
					local chargeDuration = swDur or 0
					local barAlpha = surgeAtMax and 0.2 or 1
					local bgAlpha = surgeAtMax and 0.17 or 0.85
					local now_val = GetTime()
					local ANIM_SPEED = 3.0

					for i = 1, 3 do
						local bar = self.secondWindBars[i]
						local bg = self.secondWindBarBgs and self.secondWindBarBgs[i]
						if bar then
							if bg then
								bg:SetColorTexture(0.08, 0.12, 0.18, bgAlpha)
							end

							local targetPct = 0
							if SafeCompare(i, currentCharges, "<=") then
								targetPct = 1
							elseif SafeCompare(i, currentCharges + 1, "==") and chargeDuration > 0 then
								local cdElapsed = now_val - chargeStart
								targetPct = Clamp(cdElapsed / chargeDuration, 0, 1)
							else
								targetPct = 0
							end

							local lastTarget = (self._secondWindLastTarget and self._secondWindLastTarget[i]) or 0
							self._secondWindLastTarget = self._secondWindLastTarget or {}
							self._secondWindLastTarget[i] = targetPct

							if SafeCompare(targetPct, 1, ">=") and SafeCompare(lastTarget, 1, "<") then
								self._secondWindAnimating[i] = true
							end

							if self._secondWindAnimating[i] then
								local val = (self._secondWindAnimValue[i] or 0) + dt * ANIM_SPEED
								if val >= 1 then
									val = 1
									self._secondWindAnimating[i] = false
								end
								self._secondWindAnimValue[i] = val
								-- Midnight Safety
								bar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
								bar:SetMinMaxValues(0, 1)
								bar:SetValue(val)
								local r_sw, g_sw, b_sw = ColorForPctPurple(val)
								bar:SetStatusBarColor(r_sw, g_sw, b_sw, barAlpha)
								bar:SetAlpha(1)
							else
								self._secondWindAnimValue[i] = targetPct
								-- Midnight Safety
								bar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
								bar:SetMinMaxValues(0, 1)
								bar:SetValue(targetPct)
								local r_sw, g_sw, b_sw = ColorForPctPurple(targetPct)
								bar:SetStatusBarColor(r_sw, g_sw, b_sw, barAlpha)
								bar:SetAlpha(1)
							end
						end
					end
				end
			end
		end)
		self.perf.blocks.wind = debugprofilestop() - block_start
		if not ok_wind then
			DebugLog("Block 7 (Wind) error:", err_wind)
		end
	end)
end

function FlightsimUI:SetScale(scale)
	scale = Clamp(scale or 1, 0.5, 2.0)
	self.db.profile.scale = scale
	-- Apply scale to all frames
	if self.frame then
		self.frame:SetScale(scale)
	end
	if self.accelFrame then
		self.accelFrame:SetScale(scale)
	end
	if self.surgeForwardFrame then
		self.surgeForwardFrame:SetScale(scale)
	end
	if self.secondWindFrame then
		self.secondWindFrame:SetScale(scale)
	end
	if self.whirlingSurgeBar then
		self.whirlingSurgeBar:SetScale(scale)
	end
end

function FlightsimUI:SetWidth(width)
	width = tonumber(width)
	if not width then
		return
	end
	width = Clamp(width, 50, 800)
	self.db.profile.ui.width = width
	self:RebuildLayout()
end

function FlightsimUI:SetBarHeight(height)
	height = tonumber(height)
	if not height then
		return
	end
	height = Clamp(height, 10, 100)
	self.db.profile.ui.speedBarHeight = height
	self:RebuildLayout()
end

function FlightsimUI:SetSpeedBarMax(maxSpeed)
	maxSpeed = tonumber(maxSpeed)
	if not maxSpeed then
		return
	end
	maxSpeed = Clamp(maxSpeed, 100, 1500)
	self.db.profile.speedBar.maxSpeed = maxSpeed
end

function FlightsimUI:SetFontSize(fontSize)
	fontSize = tonumber(fontSize)
	if not fontSize then
		return
	end
	fontSize = Clamp(fontSize, 8, 48)
	self.db.profile.speedBar.fontSize = fontSize
	if self.speedText then
		self.speedText:SetFont("Fonts\\ARIALN.TTF", fontSize, "OUTLINE")
	end
end

function FlightsimUI:SetSustainableSpeed(sustainableSpeed)
	sustainableSpeed = tonumber(sustainableSpeed)
	if not sustainableSpeed then
		return
	end
	local maxSpeed = (self.db.profile.speedBar and self.db.profile.speedBar.maxSpeed) or 1100
	sustainableSpeed = Clamp(sustainableSpeed, 0, maxSpeed)
	self.db.profile.speedBar.sustainableSpeed = sustainableSpeed
end

function FlightsimUI:DebugDump()
	local L = Flightsim.L
	local function PrintKV(k, v)
		print(string.format(L["DEBUG_KV"], tostring(k), tostring(v)))
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

	print(L["DEBUG_HEADER"])
	-- Use C_AddOns.GetAddOnMetadata (modern) or fall back to GetAddOnMetadata (legacy)
	local version = "?"
	if C_AddOns and C_AddOns.GetAddOnMetadata then
		version = C_AddOns.GetAddOnMetadata("Flightsim", "Version") or "?"
	elseif GetAddOnMetadata then
		version = GetAddOnMetadata("Flightsim", "Version") or "?"
	end
	PrintKV("Version", version)
	-- BugGrabber folder is named "!BugGrabber" (with ! prefix for load order)
	PrintKV("BugGrabber loaded", (IsAddonLoaded("!BugGrabber") or IsAddonLoaded("BugGrabber")) and "yes" or "no")
	PrintKV("BugSack loaded", IsAddonLoaded("BugSack") and "yes" or "no")
	PrintKV("Has GetSpellCharges", type(GetSpellCharges) == "function" and "yes" or "no")
	PrintKV("Has C_Spell.GetSpellCharges", (C_Spell and type(C_Spell.GetSpellCharges) == "function") and "yes" or "no")
	PrintKV(
		"Has C_PlayerInfo.IsPlayerInSkyriding",
		(C_PlayerInfo and type(C_PlayerInfo.IsPlayerInSkyriding) == "function") and "yes" or "no"
	)
	PrintKV(
		"Has C_PlayerInfo.IsPlayerInDragonriding",
		(C_PlayerInfo and type(C_PlayerInfo.IsPlayerInDragonriding) == "function") and "yes" or "no"
	)

	if not (self.db and self.db.profile) then
		print(L["DEBUG_DB_NOT_INIT"])
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

	print(L["DEBUG_ABILITIES_HEADER"])
	for i, token in ipairs((p.abilities and p.abilities.order) or {}) do
		local enabled = (p.abilities.enabled == nil) or (p.abilities.enabled[token] ~= false)
		local spellID, iconID = ResolveSpellInfo(token)
		local cur, max = nil, nil
		if spellID then
			cur, max = GetSpellChargesSafe(spellID)
		end
		print(
			string.format(
				L["DEBUG_ABILITY_FORMAT"],
				i,
				tostring(token),
				enabled and "yes" or "no",
				tostring(spellID),
				tostring(iconID),
				tostring(cur),
				tostring(max)
			)
		)
	end

	print(L["DEBUG_FOOTER"])
end

function FlightsimUI:Status()
	local L = Flightsim.L
	if not (self.db and self.db.profile) then
		print(L["STATUS_NOT_INIT"])
		return
	end

	local skyriding = self:IsSkyridingActive()
	local speed = GetUnitSpeedSafe("player")
	local maxSpeed = (self.db.profile.speedBar and self.db.profile.speedBar.maxSpeed) or 20
	local optimalSpeed = (self.db.profile.speedBar and self.db.profile.speedBar.optimalSpeed) or 0

	local showState = (self.frame and self.frame:IsShown()) and L["SHOWN"] or L["HIDDEN"]
	local ridingState = skyriding and L["SKYRIDING"] or L["NOT_SKYRIDING"]

	local chargeState = L["CHARGES_DISABLED"]

	local optimalStr = (optimalSpeed and optimalSpeed > 0) and string.format(L["OPTIMAL_FORMAT"], optimalSpeed)
		or L["OPTIMAL_OFF"]

	print(
		string.format(
			L["STATUS_FORMAT"],
			ridingState,
			showState,
			speed,
			maxSpeed,
			optimalStr,
			chargeState
		)
	)
end

-- ============================================================
-- Mechanic Integration Helpers
-- ============================================================

function FlightsimUI:GetPerformanceSubMetrics()
	local p = self.perf.blocks
	return {
		{ name = "State & Speed", msPerSec = p.state, description = "Skyriding detection and raw speed APIs" },
		{ name = "Speed Bar", msPerSec = p.speed, description = "Speed percent calculation and HUD bar" },
		{ name = "Accel Bar", msPerSec = p.accel, description = "Acceleration delta calculation and UI" },
		{ name = "Ability Prep", msPerSec = p.prep, description = "Spell cooldown and charge polling" },
		{ name = "Surge Forward", msPerSec = p.surge, description = "Surge Forward charges and animations" },
		{ name = "Whirling Surge", msPerSec = p.whirling, description = "Whirling Surge cooldown bar" },
		{ name = "Second Wind", msPerSec = p.wind, description = "Second Wind charges and animations" },
	}
end

function FlightsimUI:GetTests()
	return self.tests
end

function FlightsimUI:RunTest(id)
	-- No-op for auto tests, they just return results
	return true
end

function FlightsimUI:GetTestResult(id)
	if id == "api_diag" then
		local details = {}

		-- 1. GetUnitSpeed
		local speed = GetUnitSpeedSafe("player")
		local speedSecret = IsSecret(speed)
		table.insert(details, {
			label = "GetUnitSpeed(\"player\")",
			value = SafeToString(speed) .. (speedSecret and " (SECRET)" or ""),
			status = speedSecret and "warn" or "pass",
		})

		-- 2. C_PlayerInfo.GetGlidingInfo
		if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
			local ok, gliding, canGlide, fwd = pcall(C_PlayerInfo.GetGlidingInfo)
			local fwdSecret = IsSecret(fwd)
			table.insert(details, {
				label = "C_PlayerInfo.GetGlidingInfo",
				value = string.format("gliding=%s, fwd=%s", tostring(gliding), SafeToString(fwd)),
				status = fwdSecret and "warn" or "pass",
			})
		end

		-- 3. Surge Forward Charges
		local info = GetSpellCooldownSafe(372608, true)
		local chargesSecret = IsSecret(info.currentCharges)
		table.insert(details, {
			label = "Surge Forward Charges",
			value = string.format("%s/%s", SafeToString(info.currentCharges), SafeToString(info.maxCharges)),
			status = chargesSecret and "warn" or "pass",
		})

		return {
			passed = true,
			message = chargesSecret and "Running in Degraded (Combat) Mode" or "Running in Normal Mode",
			details = details,
		}
	elseif id == "ui_compliance" then
		local details = {}

		-- 1. Speed Bar
		table.insert(details, {
			label = "Speed Bar (StatusBar)",
			value = self.speedBar and "Initialized" or "Missing",
			status = self.speedBar and "pass" or "fail",
		})

		-- 2. Passthrough Test
		local speed = GetUnitSpeedSafe("player")
		local ok = pcall(function()
			self.speedBar:SetValue(speed)
		end)
		table.insert(details, {
			label = "Secret Passthrough",
			value = ok and "Safe" or "CRASH",
			status = ok and "pass" or "fail",
		})

		return {
			passed = ok,
			message = ok and "UI elements are Midnight compliant" or "UI elements may crash in combat",
			details = details,
		}
	end

	return { passed = false, message = "Unknown test ID" }
end
