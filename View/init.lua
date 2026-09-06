-- Flightsim View Layer
-- UI Frames and Rendering
-- Consumes ActionResults from Bridge/Executor

---@class FlightsimView
---@field MainFrame table Main HUD frame
---@field Components table UI components
FlightsimView = FlightsimView or {}
FlightsimView.Components = FlightsimView.Components or {}

-- Reference to Bridge for execution
local Bridge = FlightsimBridge
local Executor = Bridge.Executor
local Events = Bridge.Events

-- FenCore references
local FenCore = _G.FenCore
local ActionResult = FenCore.ActionResult

-- Logic layer references
local Logic = FlightsimLogic
local Color = Logic.Color

local ABILITY_LAYOUT = {
	["Surge Forward"] = { frameKey = "surgeForwardFrame", visibilityKey = "showSurgeForward" },
	["Second Wind"] = { frameKey = "secondWindFrame", visibilityKey = "showSecondWind" },
	["Whirling Surge"] = { frameKey = "whirlingSurgeBar", visibilityKey = "showWhirlingSurge" },
}

local normalizedAbilityOrder = {}

-- Internal state
local isInitialized = false
local tickerFrame = nil
local lastUpdateTime = 0

-- Performance tracking
FlightsimView.perf = {
	executor = 0,
	visibility = 0,
	speed = 0,
	accel = 0,
	surge = 0,
	wind = 0,
	whirling = 0,
}

local PERF_KEYS = { "executor", "visibility", "speed", "accel", "surge", "wind", "whirling" }
local perfAccumulator = {
	executor = 0,
	visibility = 0,
	speed = 0,
	accel = 0,
	surge = 0,
	wind = 0,
	whirling = 0,
}
local perfWindowElapsed = 0
local wasProfiling = false

local function ResetPerformance(target)
	for _, key in ipairs(PERF_KEYS) do
		target[key] = 0
	end
end

local function RecordPerformance(key, startTime)
	perfAccumulator[key] = perfAccumulator[key] + (debugprofilestop() - startTime)
end

local function PublishPerformance()
	if perfWindowElapsed < 1 then
		return
	end

	for _, key in ipairs(PERF_KEYS) do
		FlightsimView.perf[key] = perfAccumulator[key] / perfWindowElapsed
	end
	ResetPerformance(perfAccumulator)
	perfWindowElapsed = 0
end

-- Throttling
local UPDATE_INTERVAL_ACTIVE = 0.05 -- 20Hz when visible
local UPDATE_INTERVAL_IDLE = 0.5 -- 2Hz when hidden

--- Create a circle indicator using a FontString bullet character.
--- Guaranteed to work in any WoW version, scales and colors perfectly.
---@param parent Frame Parent frame
---@param size number Font size (controls circle diameter)
---@param r number Red (0-1)
---@param g number Green (0-1)
---@param b number Blue (0-1)
---@param a number Alpha (0-1)
---@return Frame frame Container with :SetIndicatorColor(r,g,b,a) and :SetIndicatorSize(size) methods
local function CreateCircleIndicator(parent, size, r, g, b, a)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(size, size)
	frame:SetFrameLevel(parent:GetFrameLevel() + 15)

	local text = frame:CreateFontString(nil, "OVERLAY")
	text:SetFont("Fonts\\ARIALN.TTF", size, "")
	text:SetText("\226\151\143") -- UTF-8 for ● (U+25CF BLACK CIRCLE)
	text:SetTextColor(r, g, b, a)
	text:SetPoint("CENTER", frame, "CENTER", 0, 0)
	frame._text = text

	function frame:SetIndicatorColor(nr, ng, nb, na)
		self._text:SetTextColor(nr, ng, nb, na or 1)
	end

	function frame:SetIndicatorSize(newSize)
		self:SetSize(newSize, newSize)
		self._text:SetFont("Fonts\\ARIALN.TTF", newSize, "")
	end

	return frame
end

--- Initialize the View layer.
--- Called after all modules are loaded.
---@param db table SavedVariables database
function FlightsimView:Init(db)
	if isInitialized then
		return
	end

	self.db = db

	-- Initialize Bridge events
	Events.Init()

	-- Register for mount events to reset state
	Events.OnMount("view", function()
		Executor.ResetState()
		self:ApplyVisibility()
	end)

	-- Create main frame structure
	self:CreateFrames()

	-- Start update loop
	self:StartUpdating()

	isInitialized = true
	Bridge:Log("View layer initialized")
end

--- Create all UI frames.
function FlightsimView:CreateFrames()
	local db = self.db
	local ui = db.profile.ui or {}
	local width = ui.width or 150

	-- Container frame (background behind all bars)
	local container = CreateFrame("Frame", "FlightsimContainer", UIParent)
	container:SetSize(width, 100)
	container:SetPoint("CENTER", UIParent, "CENTER", db.profile.x or 0, db.profile.y or 0)
	container:SetScale(db.profile.scale or 1)
	self.container = container

	-- Container background
	local containerBg = container:CreateTexture(nil, "BACKGROUND", nil, -8)
	containerBg:SetAllPoints(container)
	local bgColor = db.profile.colors and db.profile.colors.frame and db.profile.colors.frame.background
		or { r = 0, g = 0, b = 0, a = 0.3 }
	containerBg:SetColorTexture(bgColor.r, bgColor.g, bgColor.b, bgColor.a)
	self.containerBg = containerBg

	-- Border textures (positioned OUTSIDE the container)
	self.borders = {}
	local borderColor = db.profile.colors and db.profile.colors.frame and db.profile.colors.frame.border
		or { r = 0, g = 0, b = 0, a = 0 }
	local borderWidth = db.profile.colors and db.profile.colors.frame and db.profile.colors.frame.borderWidth or 0

	-- Top border: sits above container, extends to cover corners
	local topBorder = container:CreateTexture(nil, "OVERLAY")
	topBorder:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
	topBorder:SetPoint("BOTTOMLEFT", container, "TOPLEFT", -borderWidth, 0)
	topBorder:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", borderWidth, 0)
	topBorder:SetHeight(borderWidth)
	self.borders.top = topBorder

	-- Bottom border: sits below container, extends to cover corners
	local bottomBorder = container:CreateTexture(nil, "OVERLAY")
	bottomBorder:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
	bottomBorder:SetPoint("TOPLEFT", container, "BOTTOMLEFT", -borderWidth, 0)
	bottomBorder:SetPoint("TOPRIGHT", container, "BOTTOMRIGHT", borderWidth, 0)
	bottomBorder:SetHeight(borderWidth)
	self.borders.bottom = bottomBorder

	-- Left border: sits to the left of container
	local leftBorder = container:CreateTexture(nil, "OVERLAY")
	leftBorder:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
	leftBorder:SetPoint("TOPRIGHT", container, "TOPLEFT", 0, 0)
	leftBorder:SetPoint("BOTTOMRIGHT", container, "BOTTOMLEFT", 0, 0)
	leftBorder:SetWidth(borderWidth)
	self.borders.left = leftBorder

	-- Right border: sits to the right of container
	local rightBorder = container:CreateTexture(nil, "OVERLAY")
	rightBorder:SetColorTexture(borderColor.r, borderColor.g, borderColor.b, borderColor.a)
	rightBorder:SetPoint("TOPLEFT", container, "TOPRIGHT", 0, 0)
	rightBorder:SetPoint("BOTTOMLEFT", container, "BOTTOMRIGHT", 0, 0)
	rightBorder:SetWidth(borderWidth)
	self.borders.right = rightBorder

	-- Make container draggable when unlocked
	-- IMPORTANT: Use View (self) reference, not local db, so profile changes work correctly
	local View = self
	container:SetMovable(true)
	container:EnableMouse(true)
	container:RegisterForDrag("LeftButton")

	-- Apply initial click-through state based on lock setting
	if View.db and View.db.profile.locked then
		container:EnableMouse(false)
	end

	container:SetScript("OnDragStart", function(f)
		if View.db and not View.db.profile.locked and not View.isSwitchingProfile then
			f:StartMoving()
		end
	end)
	container:SetScript("OnDragStop", function(f)
		f:StopMovingOrSizing()
		-- Don't save position during profile switch
		if View.db and not View.isSwitchingProfile then
			local scale = f:GetScale() or 1

			-- Get center positions
			local frameX, frameY = f:GetCenter()
			local uiCenterX, uiCenterY = UIParent:GetCenter()

			-- For scaled frames, SetPoint offsets are relative to a coordinate system
			-- where the origin (UIParent center) is scaled. To compensate:
			-- offset = framePos - (uiCenter / scale)
			local x = frameX - uiCenterX / scale
			local y = frameY - uiCenterY / scale

			-- Re-anchor to our standard anchor point
			f:ClearAllPoints()
			f:SetPoint("CENTER", UIParent, "CENTER", x, y)

			local profileName = View.db:GetCurrentProfile()

			-- Write directly to raw SavedVariables table to ensure persistence
			if FlightsimDB and FlightsimDB.profiles then
				FlightsimDB.profiles[profileName] = FlightsimDB.profiles[profileName] or {}
				FlightsimDB.profiles[profileName].x = x
				FlightsimDB.profiles[profileName].y = y
			end
			-- Also update AceDB's view for immediate effect
			View.db.profile.x = x
			View.db.profile.y = y
		end
	end)

	-- Main HUD frame (speed bar) - parented to container
	local frame = CreateFrame("StatusBar", "FlightsimHUD", container)
	frame:SetSize(width, ui.speedBarHeight or 20)
	frame:SetPoint("TOP", container, "TOP", 0, 0)
	frame:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
	frame:SetMinMaxValues(0, 1)
	frame:SetValue(0)
	self.frame = frame

	-- Speed bar background (transparent - container provides bg)
	local speedBarBg = frame:CreateTexture(nil, "BACKGROUND")
	speedBarBg:SetAllPoints(frame)
	speedBarBg:SetColorTexture(0, 0, 0, 0)
	self.speedBarBg = speedBarBg

	-- Overlay frame for text and marker (above StatusBar fill)
	local overlay = CreateFrame("Frame", nil, frame)
	overlay:SetAllPoints(frame)
	overlay:SetFrameLevel(frame:GetFrameLevel() + 10)
	self.speedBarOverlay = overlay

	-- Sustainable speed marker
	local markerWidth = ui.sustainableSpeedMarkerWidth or 1
	local markerAlpha = ui.sustainableSpeedMarkerAlpha or 0.2
	local sustainableMarker = overlay:CreateTexture(nil, "OVERLAY")
	sustainableMarker:SetColorTexture(1, 1, 1, markerAlpha)
	sustainableMarker:SetWidth(markerWidth)
	sustainableMarker:SetPoint("TOP", overlay, "TOP", 0, 0)
	sustainableMarker:SetPoint("BOTTOM", overlay, "BOTTOM", 0, 0)
	sustainableMarker:Hide() -- Hide until first valid position update
	self.sustainableMarker = sustainableMarker

	-- Speed text
	local p = db.profile.speedBar or {}
	local fontFamily = p.fontFamily or "Fonts\\ARIALN.TTF"
	local fontSize = p.fontSize or 10
	local fontOutline = p.fontOutline or "OUTLINE"
	local speedText = overlay:CreateFontString(nil, "OVERLAY")
	speedText:SetFont(fontFamily, fontSize, fontOutline)
	speedText:SetPoint("LEFT", overlay, "LEFT", 6, 0)
	speedText:SetJustifyH("LEFT")
	speedText:SetText("0%")
	self.speedText = speedText

	-- Acceleration bar (below speed bar)
	local accelBarHeight = ui.accelBarHeight or 2
	local accelGap = ui.accelBarGap or 2

	local accelFrame = CreateFrame("Frame", nil, container)
	accelFrame:SetSize(width, accelBarHeight)
	accelFrame:SetPoint("TOP", frame, "BOTTOM", 0, -accelGap)
	self.accelFrame = accelFrame

	local accelBg = accelFrame:CreateTexture(nil, "BACKGROUND")
	accelBg:SetAllPoints(accelFrame)
	accelBg:SetColorTexture(0, 0, 0, 0)
	self.accelBarBg = accelBg

	local accelBar = accelFrame:CreateTexture(nil, "ARTWORK")
	accelBar:SetColorTexture(1, 1, 1, 0.9)
	accelBar:SetHeight(accelBarHeight)
	self.accelBar = accelBar

	-- Pitch bar (below accel bar, default OFF)
	local pitchBarHeight = ui.pitchBarHeight or 2
	local pitchGap = ui.pitchBarGap or 1

	local pitchFrame = CreateFrame("Frame", nil, container)
	pitchFrame:SetSize(width, pitchBarHeight)
	pitchFrame:SetPoint("TOP", accelFrame, "BOTTOM", 0, -pitchGap)
	self.pitchFrame = pitchFrame

	local pitchBg = pitchFrame:CreateTexture(nil, "BACKGROUND")
	pitchBg:SetAllPoints(pitchFrame)
	pitchBg:SetColorTexture(0, 0, 0, 0)
	self.pitchBarBg = pitchBg

	local pitchBar = pitchFrame:CreateTexture(nil, "ARTWORK")
	pitchBar:SetColorTexture(0.3, 0.6, 1.0, 0.9)
	pitchBar:SetHeight(pitchBarHeight)
	self.pitchBar = pitchBar

	-- Hide pitch frame (feature shelved - estimation needs refinement)
	-- local pitchEnabled = db.profile.pitchBar and db.profile.pitchBar.enabled
	local pitchEnabled = false
	if not pitchEnabled then
		pitchFrame:Hide()
	end

	-- Ability bars configuration
	local abilityBarHeight = ui.abilityBarHeight or 10
	local barGap = ui.barGap or 2
	local chargeGap = 2

	-- Get ability color settings
	local abilityColors = db.profile.colors and db.profile.colors.abilities or {}

	-- Surge Forward (6 charges, blue #74AFFF)
	local surgeForwardFrame = CreateFrame("Frame", nil, container)
	surgeForwardFrame:SetSize(width, abilityBarHeight)
	surgeForwardFrame:SetPoint("TOP", accelFrame, "BOTTOM", 0, -barGap)
	self.surgeForwardFrame = surgeForwardFrame

	-- Surge Forward frame background (behind all charge bars)
	local sfFrameBg = surgeForwardFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
	sfFrameBg:SetAllPoints(surgeForwardFrame)
	local sfFrameBgColor = abilityColors.surgeForwardFrameBg or { r = 0, g = 0, b = 0, a = 0 }
	sfFrameBg:SetColorTexture(sfFrameBgColor.r, sfFrameBgColor.g, sfFrameBgColor.b, sfFrameBgColor.a)
	self.surgeForwardFrameBg = sfFrameBg

	self.surgeForwardBars = {}
	self.surgeForwardBarBgs = {}
	local sfTotalGaps = chargeGap * 5
	local sfChargeWidth = (width - sfTotalGaps) / 6
	local sfBarBgColor = abilityColors.surgeForwardBarBg or { r = 0.1, g = 0.15, b = 0.25, a = 0.5 }

	for i = 1, 6 do
		local chargeBar = CreateFrame("StatusBar", nil, surgeForwardFrame)
		chargeBar:SetSize(sfChargeWidth, abilityBarHeight)
		chargeBar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
		chargeBar:SetMinMaxValues(0, 1)
		chargeBar:SetValue(1)

		local chargeBg = chargeBar:CreateTexture(nil, "BACKGROUND")
		chargeBg:SetAllPoints(chargeBar)
		chargeBg:SetColorTexture(sfBarBgColor.r, sfBarBgColor.g, sfBarBgColor.b, sfBarBgColor.a)
		self.surgeForwardBarBgs[i] = chargeBg

		if i == 1 then
			chargeBar:SetPoint("LEFT", surgeForwardFrame, "LEFT", 0, 0)
		else
			chargeBar:SetPoint("LEFT", self.surgeForwardBars[i - 1], "RIGHT", chargeGap, 0)
		end

		self.surgeForwardBars[i] = chargeBar
	end

	-- Second Wind (3 charges, purple #D379EF)
	local secondWindFrame = CreateFrame("Frame", nil, container)
	secondWindFrame:SetSize(width, abilityBarHeight)
	secondWindFrame:SetPoint("TOP", surgeForwardFrame, "BOTTOM", 0, -barGap)
	self.secondWindFrame = secondWindFrame

	-- Second Wind frame background (behind all charge bars)
	local swFrameBg = secondWindFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
	swFrameBg:SetAllPoints(secondWindFrame)
	local swFrameBgColor = abilityColors.secondWindFrameBg or { r = 0, g = 0, b = 0, a = 0 }
	swFrameBg:SetColorTexture(swFrameBgColor.r, swFrameBgColor.g, swFrameBgColor.b, swFrameBgColor.a)
	self.secondWindFrameBg = swFrameBg

	self.secondWindBars = {}
	self.secondWindBarBgs = {}
	local swTotalGaps = chargeGap * 2
	local swChargeWidth = (width - swTotalGaps) / 3
	local swBarBgColor = abilityColors.secondWindBarBg or { r = 0.2, g = 0.1, b = 0.25, a = 0.5 }

	for i = 1, 3 do
		local chargeBar = CreateFrame("StatusBar", nil, secondWindFrame)
		chargeBar:SetSize(swChargeWidth, abilityBarHeight)
		chargeBar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
		chargeBar:SetMinMaxValues(0, 1)
		chargeBar:SetValue(1)

		local chargeBg = chargeBar:CreateTexture(nil, "BACKGROUND")
		chargeBg:SetAllPoints(chargeBar)
		chargeBg:SetColorTexture(swBarBgColor.r, swBarBgColor.g, swBarBgColor.b, swBarBgColor.a)
		self.secondWindBarBgs[i] = chargeBg

		if i == 1 then
			chargeBar:SetPoint("LEFT", secondWindFrame, "LEFT", 0, 0)
		else
			chargeBar:SetPoint("LEFT", self.secondWindBars[i - 1], "RIGHT", chargeGap, 0)
		end

		self.secondWindBars[i] = chargeBar
	end

	-- Whirling Surge (cooldown bar, cyan #4AC7D4)
	local whirlingSurgeBar = CreateFrame("StatusBar", nil, container)
	whirlingSurgeBar:SetSize(width, abilityBarHeight)
	whirlingSurgeBar:SetPoint("TOP", secondWindFrame, "BOTTOM", 0, -barGap)
	whirlingSurgeBar:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
	whirlingSurgeBar:SetMinMaxValues(0, 1)
	whirlingSurgeBar:SetValue(1)
	self.whirlingSurgeBar = whirlingSurgeBar

	local whirlingSurgeBg = whirlingSurgeBar:CreateTexture(nil, "BACKGROUND")
	whirlingSurgeBg:SetAllPoints(whirlingSurgeBar)
	local wsBarBgColor = abilityColors.whirlingSurgeBarBg or { r = 0.1, g = 0.2, b = 0.22, a = 0.5 }
	whirlingSurgeBg:SetColorTexture(wsBarBgColor.r, wsBarBgColor.g, wsBarBgColor.b, wsBarBgColor.a)
	self.whirlingSurgeBg = whirlingSurgeBg

	-- Buff recovery indicators (arrows flanking speed bar)
	self:CreateBuffIndicators()

	-- Update container size based on visible bars
	self:UpdateContainerSize()
end

--- Update container size to fit all visible bars.
function FlightsimView:UpdateContainerSize()
	if not self.container or not self.db then
		return
	end

	-- Use cached visibility if available, otherwise use settings
	local visibility = self.currentVisibility
	if not visibility then
		local abilityBars = self.db.profile.abilityBars or {}
		visibility = {
			showSurgeForward = abilityBars.showSurgeForward ~= false,
			showSecondWind = abilityBars.showSecondWind ~= false,
			showWhirlingSurge = abilityBars.showWhirlingSurge ~= false,
		}
	end

	self:UpdateContainerSizeForVisibility(visibility)
end

--- Start the update loop.
function FlightsimView:StartUpdating()
	if tickerFrame then
		return
	end

	tickerFrame = CreateFrame("Frame")
	tickerFrame:SetScript("OnUpdate", function(_, elapsed)
		self:OnUpdate(elapsed)
	end)
end

--- Main update loop.
---@param elapsed number Time since last frame
function FlightsimView:OnUpdate(elapsed)
	local isProfiling = Flightsim.debugMode or _G.Mechanic ~= nil
	if isProfiling then
		if not wasProfiling then
			ResetPerformance(perfAccumulator)
			perfWindowElapsed = 0
		end
		perfWindowElapsed = perfWindowElapsed + (elapsed or 0)
	elseif wasProfiling then
		ResetPerformance(self.perf)
		ResetPerformance(perfAccumulator)
		perfWindowElapsed = 0
	end
	wasProfiling = isProfiling

	local now = GetTime()
	local isHUDVisible = self.container and self.container:IsShown()
	local interval = isHUDVisible and UPDATE_INTERVAL_ACTIVE or UPDATE_INTERVAL_IDLE

	if (now - lastUpdateTime) < interval then
		return
	end
	lastUpdateTime = now

	self.layoutDimensions = self.layoutDimensions or {}
	self.layoutDimensions.accelBarWidth = self.accelFrame and self.accelFrame:GetWidth() or 200
	self.layoutDimensions.accelBarHeight = self.accelFrame and self.accelFrame:GetHeight() or 4
	self.layoutDimensions.pitchBarWidth = self.pitchFrame and self.pitchFrame:GetWidth() or 200
	self.layoutDimensions.pitchBarHeight = self.pitchFrame and self.pitchFrame:GetHeight() or 2
	if not isProfiling then
		-- Fast path (no profiling)
		local result = Executor.FullUpdate(self.db, self.layoutDimensions)
		if not result.success then
			return
		end
		local data = ActionResult.unwrap(result)
		if data.visibility then
			self:ApplyVisibilityState(data.visibility)
		end
		if data.shouldUpdate then
			self:UpdateSpeed(data.speed)
			self:UpdateAcceleration(data.acceleration)
			if data.pitch then
				self:UpdatePitch(data.pitch)
			end
			if data.surgeForward then
				self:UpdateChargeBar("surgeForward", data.surgeForward)
			end
			if data.secondWind then
				self:UpdateChargeBar("secondWind", data.secondWind)
			end
			if data.whirlingSurge then
				self:UpdateCooldownBar(data.whirlingSurge)
			end
			self:UpdateBuffIndicators(data.buffs)
		end
		return
	end

	-- Execute full update through Bridge (with timing)
	local execStart = debugprofilestop()
	local result = Executor.FullUpdate(self.db, self.layoutDimensions)
	RecordPerformance("executor", execStart)

	if not result.success then
		PublishPerformance()
		return
	end

	local data = result.data

	-- Apply visibility (with timing)
	if data.visibility then
		local visStart = debugprofilestop()
		self:ApplyVisibilityState(data.visibility)
		RecordPerformance("visibility", visStart)
	end

	-- Update components if visible (with timing)
	if data.shouldUpdate then
		local speedStart = debugprofilestop()
		self:UpdateSpeed(data.speed)
		RecordPerformance("speed", speedStart)

		local accelStart = debugprofilestop()
		self:UpdateAcceleration(data.acceleration)
		RecordPerformance("accel", accelStart)

		if data.pitch then
			self:UpdatePitch(data.pitch)
		end

		if data.surgeForward then
			local surgeStart = debugprofilestop()
			self:UpdateChargeBar("surgeForward", data.surgeForward)
			RecordPerformance("surge", surgeStart)
		end
		if data.secondWind then
			local windStart = debugprofilestop()
			self:UpdateChargeBar("secondWind", data.secondWind)
			RecordPerformance("wind", windStart)
		end
		if data.whirlingSurge then
			local whirlStart = debugprofilestop()
			self:UpdateCooldownBar(data.whirlingSurge)
			RecordPerformance("whirling", whirlStart)
		end

		self:UpdateBuffIndicators(data.buffs)
	end

	PublishPerformance()
end

--- Apply visibility state to frames and reposition bars to collapse gaps.
---@param visibility table Visibility state from Executor
function FlightsimView:ApplyVisibilityState(visibility)
	if not self.lastVisibility then
		self.lastVisibility = {}
	end

	local lv = self.lastVisibility
	if
		lv.showHUD == visibility.showHUD
		and lv.showSpeedBar == visibility.showSpeedBar
		and lv.showPitchBar == visibility.showPitchBar
		and lv.showSurgeForward == visibility.showSurgeForward
		and lv.showSecondWind == visibility.showSecondWind
		and lv.showWhirlingSurge == visibility.showWhirlingSurge
		and lv.showAbilities == visibility.showAbilities
	then
		return -- Layout hasn't changed; skip expensive UI frame redraws
	end

	-- Update cache
	lv.showHUD = visibility.showHUD
	lv.showSpeedBar = visibility.showSpeedBar
	lv.showPitchBar = visibility.showPitchBar
	lv.showSurgeForward = visibility.showSurgeForward
	lv.showSecondWind = visibility.showSecondWind
	lv.showWhirlingSurge = visibility.showWhirlingSurge
	lv.showAbilities = visibility.showAbilities

	-- Container controls overall visibility
	if self.container then
		if visibility.showHUD then
			self.container:Show()
		else
			self.container:Hide()
		end
	end

	-- Cache visibility state for layout calculations
	self.currentVisibility = visibility

	-- Pitch bar visibility (shelved - hardcoded off)
	if self.pitchFrame then
		-- local pitchEnabled = self.db and self.db.profile.pitchBar and self.db.profile.pitchBar.enabled
		local pitchEnabled = false
		if pitchEnabled then
			self.pitchFrame:Show()
		else
			self.pitchFrame:Hide()
		end
	end

	-- Individual ability visibility
	if self.surgeForwardFrame then
		if visibility.showSurgeForward then
			self.surgeForwardFrame:Show()
		else
			self.surgeForwardFrame:Hide()
		end
	end

	if self.secondWindFrame then
		if visibility.showSecondWind then
			self.secondWindFrame:Show()
		else
			self.secondWindFrame:Hide()
		end
	end

	if self.whirlingSurgeBar then
		if visibility.showWhirlingSurge then
			self.whirlingSurgeBar:Show()
		else
			self.whirlingSurgeBar:Hide()
		end
	end

	-- Reposition frames to collapse gaps for hidden bars
	self:RepositionAbilityBars(visibility)
end

--- Reposition ability bars to collapse gaps when some are hidden.
---@param visibility table Visibility state
function FlightsimView:RepositionAbilityBars(visibility)
	if not self.db then
		return
	end

	local ui = self.db.profile.ui or {}
	local barGap = ui.barGap or 2
	-- Pitch frame is the anchor when pitch is enabled, otherwise accel frame
	-- local pitchEnabled = self.db.profile.pitchBar and self.db.profile.pitchBar.enabled
	local pitchEnabled = false
	local lastFrame = (pitchEnabled and self.pitchFrame) or self.accelFrame

	local abilities = self.db.profile.abilities or {}
	local order = Logic.Visibility.GetAbilityOrder(abilities.order, normalizedAbilityOrder)
	for _, token in ipairs(order) do
		local layout = ABILITY_LAYOUT[token]
		local frame = self[layout.frameKey]
		if frame then
			frame:ClearAllPoints()
			if visibility[layout.visibilityKey] then
				frame:SetPoint("TOP", lastFrame, "BOTTOM", 0, -barGap)
				lastFrame = frame
			end
		end
	end

	-- Update container size to fit visible bars only
	self:UpdateContainerSizeForVisibility(visibility)
end

--- Update container size based on which bars are visible.
---@param visibility table Visibility state
function FlightsimView:UpdateContainerSizeForVisibility(visibility)
	if not self.container or not self.db then
		return
	end

	local ui = self.db.profile.ui or {}
	local width = ui.width or 150
	local speedBarHeight = ui.speedBarHeight or 20
	local accelBarHeight = ui.accelBarHeight or 2
	local accelGap = ui.accelBarGap or 2
	local abilityBarHeight = ui.abilityBarHeight or 10
	local barGap = ui.barGap or 2

	local pitchBarHeight = ui.pitchBarHeight or 2
	local pitchGap = ui.pitchBarGap or 1

	-- Base height: speed bar + gap + accel bar
	local totalHeight = speedBarHeight + accelGap + accelBarHeight

	-- Add pitch bar if enabled
	-- local pitchEnabled = self.db and self.db.profile.pitchBar and self.db.profile.pitchBar.enabled
	local pitchEnabled = false
	if pitchEnabled then
		totalHeight = totalHeight + pitchGap + pitchBarHeight
	end

	-- Add height for each visible ability bar
	if visibility.showSurgeForward then
		totalHeight = totalHeight + barGap + abilityBarHeight
	end
	if visibility.showSecondWind then
		totalHeight = totalHeight + barGap + abilityBarHeight
	end
	if visibility.showWhirlingSurge then
		totalHeight = totalHeight + barGap + abilityBarHeight
	end

	self.container:SetSize(width, totalHeight)
end

--- Update speed bar display.
---@param data table Speed data from Executor
function FlightsimView:UpdateSpeed(data)
	if not data or not self.frame then
		return
	end

	if data.isSecret then
		self.speedText:SetText("???")
		self.frame:SetStatusBarColor(0.5, 0.5, 0.5, 1)
		self.sustainableMarker:Hide()
	else
		self.speedText:SetText(data.displayText or "0%")
		self.frame:SetValue(data.fillPct or 0)

		local c = data.barColor or { 0.5, 0.5, 0.5 }
		self.frame:SetStatusBarColor(c[1], c[2], c[3], 1)

		if data.showMarker and data.markerPct then
			local barWidth = self.frame:GetWidth()
			-- Only show marker if frame has valid width (layout complete)
			if barWidth and barWidth > 0 then
				self.sustainableMarker:ClearAllPoints()
				local offset = data.markerPct * barWidth
				self.sustainableMarker:SetPoint("TOP", self.frame, "TOPLEFT", offset, 0)
				self.sustainableMarker:SetPoint("BOTTOM", self.frame, "BOTTOMLEFT", offset, 0)
				self.sustainableMarker:Show()
			else
				self.sustainableMarker:Hide()
			end
		else
			self.sustainableMarker:Hide()
		end
	end
end

--- Update acceleration bar display.
---@param data table Acceleration data from Executor
function FlightsimView:UpdateAcceleration(data)
	if not data or not self.accelBar then
		return
	end

	if data.shouldHide then
		self.accelBar:Hide()
		return
	end

	self.accelBar:Show()
	self.accelBar:ClearAllPoints()
	self.accelBar:SetWidth(data.width or 4)

	-- Apply color based on dynamic color setting and direction
	-- Logic layer returns: "accelerating", "decelerating", or "stable"
	local colors = self.db.profile.colors and self.db.profile.colors.accelBar
	if colors and colors.useDynamic and data.direction then
		local c
		if data.direction == "accelerating" then
			c = colors.accel or { r = 0, g = 1, b = 0, a = 0.9 }
		elseif data.direction == "decelerating" then
			c = colors.decel or { r = 1, g = 0, b = 0, a = 0.9 }
		else
			c = { r = 1, g = 1, b = 1, a = 0.9 }
		end
		self.accelBar:SetColorTexture(c.r, c.g, c.b, c.a or 0.9)
	else
		self.accelBar:SetColorTexture(1, 1, 1, 0.9)
	end

	if data.anchorSide == "CENTER" then
		self.accelBar:SetPoint("CENTER", self.accelFrame, "CENTER", 0, 0)
	elseif data.anchorSide == "LEFT" then
		self.accelBar:SetPoint("LEFT", self.accelFrame, "LEFT", data.offsetX or 0, 0)
	else
		self.accelBar:SetPoint("RIGHT", self.accelFrame, "LEFT", data.offsetX or 0, 0)
	end
end

--- Update pitch bar display.
---@param data table Pitch data from Executor
function FlightsimView:UpdatePitch(data)
	if not data or not self.pitchBar then
		return
	end

	if data.shouldHide then
		self.pitchBar:Hide()
		return
	end

	self.pitchBar:Show()
	self.pitchBar:ClearAllPoints()
	self.pitchBar:SetWidth(data.width or 4)

	-- Apply color based on dynamic color setting and direction
	local colors = self.db.profile.colors and self.db.profile.colors.pitchBar
	if colors and colors.useDynamic and data.direction then
		local c
		if data.direction == "diving" then
			c = colors.diving or { r = 0.3, g = 0.6, b = 1.0, a = 0.9 }
		elseif data.direction == "climbing" then
			c = colors.climbing or { r = 1.0, g = 0.5, b = 0.2, a = 0.9 }
		else
			c = { r = 1, g = 1, b = 1, a = 0.9 }
		end
		self.pitchBar:SetColorTexture(c.r, c.g, c.b, c.a or 0.9)
	else
		self.pitchBar:SetColorTexture(1, 1, 1, 0.9)
	end

	if data.anchorSide == "CENTER" then
		self.pitchBar:SetPoint("CENTER", self.pitchFrame, "CENTER", 0, 0)
	elseif data.anchorSide == "LEFT" then
		self.pitchBar:SetPoint("LEFT", self.pitchFrame, "LEFT", data.offsetX or 0, 0)
	else
		self.pitchBar:SetPoint("RIGHT", self.pitchFrame, "LEFT", data.offsetX or 0, 0)
	end
end

--- Update charge bar display (Surge Forward or Second Wind).
---@param abilityKey string "surgeForward" or "secondWind"
---@param data table Charge data from Executor
function FlightsimView:UpdateChargeBar(abilityKey, data)
	if not data then
		return
	end

	local bars = abilityKey == "surgeForward" and self.surgeForwardBars or self.secondWindBars
	if not bars then
		return
	end

	-- Get custom color if configured
	local abilities = self.db.profile.colors and self.db.profile.colors.abilities
	local customColor = abilities and abilities[abilityKey]

	-- Default color function for gradient
	local colorFunc = abilityKey == "surgeForward" and Color.ForSurgeForward or Color.ForSecondWind

	local numStates = data.numStates or #(data.states or {})
	local states = data.states or {}

	for i = 1, numStates do
		local state = states[i]
		local bar = bars[i]
		if state and bar then
			bar:SetValue(state.displayPct or 0)
			local r, g, b
			if customColor then
				-- Use custom color, but dim based on charge level
				local pct = state.displayPct or 0
				-- Lerp from dim (30% brightness) to full brightness
				local brightness = 0.3 + (0.7 * pct)
				r = customColor.r * brightness
				g = customColor.g * brightness
				b = customColor.b * brightness
			else
				r, g, b = colorFunc(state.displayPct or 0)
			end
			bar:SetStatusBarColor(r, g, b, 1)
		end
	end
end

--- Update cooldown bar display (Whirling Surge).
---@param data table Cooldown data from Executor
function FlightsimView:UpdateCooldownBar(data)
	if not data or not self.whirlingSurgeBar then
		return
	end

	self.whirlingSurgeBar:SetValue(data.displayValue or 0)

	-- Get custom color if configured
	local abilities = self.db.profile.colors and self.db.profile.colors.abilities
	local customColor = abilities and abilities.whirlingSurge

	local r, g, b
	if customColor then
		-- Use custom color, but dim based on cooldown progress
		local pct = data.displayValue or 0
		-- Lerp from dim (30% brightness) to full brightness
		local brightness = 0.3 + (0.7 * pct)
		r = customColor.r * brightness
		g = customColor.g * brightness
		b = customColor.b * brightness
	else
		local c = data.barColor or { 0.3, 0.8, 0.8 }
		r, g, b = c[1], c[2], c[3]
	end
	self.whirlingSurgeBar:SetStatusBarColor(r, g, b, 1)
end

--- Update buff recovery indicators (Thrill of the Skies, Ground Skimming).
--- Shows/hides arrow indicators flanking the speed bar based on active buffs.
---@param data table|nil Buff data from Executor {thrillOfTheSkies, groundSkimming}
function FlightsimView:UpdateBuffIndicators(data)
	if not data then
		if self.thrillArrow then
			self.thrillArrow:Hide()
		end
		if self.skimArrow then
			self.skimArrow:Hide()
		end
		return
	end

	local indicators = self.db and self.db.profile.buffIndicators or {}

	if self.thrillArrow then
		if indicators.showThrillOfTheSkies ~= false and data.thrillOfTheSkies then
			self.thrillArrow:Show()
		else
			self.thrillArrow:Hide()
		end
	end

	if self.skimArrow then
		if indicators.showGroundSkimming ~= false and data.groundSkimming then
			self.skimArrow:Show()
		else
			self.skimArrow:Hide()
		end
	end
end

--- Update buff indicator colors from settings.
function FlightsimView:UpdateBuffIndicatorColors()
	if not self.db then
		return
	end

	local colors = self.db.profile.colors and self.db.profile.colors.buffIndicators or {}

	if self.thrillArrow then
		local c = colors.thrillOfTheSkies or { r = 1.0, g = 0.82, b = 0.0, a = 0.9 }
		self.thrillArrow:SetIndicatorColor(c.r, c.g, c.b, c.a)
	end

	if self.skimArrow then
		local c = colors.groundSkimming or { r = 0.3, g = 0.9, b = 0.3, a = 0.9 }
		self.skimArrow:SetIndicatorColor(c.r, c.g, c.b, c.a)
	end
end

--- Create or recreate buff indicator circles.
--- Called from CreateFrames and when indicator size settings change.
function FlightsimView:CreateBuffIndicators()
	if not self.db or not self.container or not self.frame then
		return
	end

	-- Destroy existing indicators
	if self.thrillArrow then
		self.thrillArrow:Hide()
		self.thrillArrow:SetParent(nil)
		self.thrillArrow = nil
	end
	if self.skimArrow then
		self.skimArrow:Hide()
		self.skimArrow:SetParent(nil)
		self.skimArrow = nil
	end

	local indicators = self.db.profile.buffIndicators or {}
	local size = indicators.indicatorSize or 8

	local buffColors = self.db.profile.colors and self.db.profile.colors.buffIndicators or {}

	local thrillColor = buffColors.thrillOfTheSkies or { r = 1.0, g = 0.82, b = 0.0, a = 0.9 }
	local thrillCircle =
		CreateCircleIndicator(self.speedBarOverlay, size, thrillColor.r, thrillColor.g, thrillColor.b, thrillColor.a)
	thrillCircle:SetPoint("RIGHT", self.speedBarOverlay, "RIGHT", -(size + 5), 0)
	thrillCircle:Hide()
	self.thrillArrow = thrillCircle

	local skimColor = buffColors.groundSkimming or { r = 0.3, g = 0.9, b = 0.3, a = 0.9 }
	local skimCircle =
		CreateCircleIndicator(self.speedBarOverlay, size, skimColor.r, skimColor.g, skimColor.b, skimColor.a)
	skimCircle:SetPoint("RIGHT", self.speedBarOverlay, "RIGHT", -4, 0)
	skimCircle:Hide()
	self.skimArrow = skimCircle
end

--- Apply visibility (legacy method for compatibility).
function FlightsimView:ApplyVisibility()
	-- Trigger a visibility recalculation on next update
	lastUpdateTime = 0
end

-- ============================================================================
-- Settings Integration Methods
-- Called from Settings.lua when preferences change
-- ============================================================================

--- Set scale for all frames.
---@param scale number Scale factor (0.5-2.0)
function FlightsimView:SetScale(scale)
	scale = scale or 1
	if scale < 0.5 then
		scale = 0.5
	end
	if scale > 2.0 then
		scale = 2.0
	end

	-- Only set scale on container - all child frames inherit it
	if self.container then
		self.container:SetScale(scale)
	end
end

--- Set position for container from profile.
--- Called when profile changes to reposition frame based on saved x/y.
function FlightsimView:SetPosition()
	if not self.container or not self.db then
		return
	end

	local x = self.db.profile.x or 0
	local y = self.db.profile.y or 0

	self.container:ClearAllPoints()
	self.container:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

--- Set click-through state based on lock setting.
---@param locked boolean Whether the frame should be click-through
function FlightsimView:SetClickThrough(locked)
	if self.container then
		self.container:EnableMouse(not locked)
	end
end

--- Rebuild all frames with current settings.
--- Called when dimensions or layout settings change.
function FlightsimView:RebuildLayout()
	if not self.db then
		return
	end

	local db = self.db
	local ui = db.profile.ui or {}
	local width = ui.width or 150

	-- Update main frame
	if self.frame then
		self.frame:SetSize(width, ui.speedBarHeight or 20)
	end

	-- Update accel frame and bar
	if self.accelFrame then
		local accelBarHeight = ui.accelBarHeight or 2
		self.accelFrame:SetSize(width, accelBarHeight)
		if self.accelBar then
			self.accelBar:SetHeight(accelBarHeight)
		end
	end

	-- Update ability bar heights and widths
	local abilityBarHeight = ui.abilityBarHeight or 10
	local chargeGap = 2

	-- Surge Forward (6 charges)
	if self.surgeForwardFrame then
		self.surgeForwardFrame:SetSize(width, abilityBarHeight)
		local sfTotalGaps = chargeGap * 5
		local sfChargeWidth = (width - sfTotalGaps) / 6
		for _, bar in ipairs(self.surgeForwardBars or {}) do
			bar:SetSize(sfChargeWidth, abilityBarHeight)
		end
	end

	-- Second Wind (3 charges)
	if self.secondWindFrame then
		self.secondWindFrame:SetSize(width, abilityBarHeight)
		local swTotalGaps = chargeGap * 2
		local swChargeWidth = (width - swTotalGaps) / 3
		for _, bar in ipairs(self.secondWindBars or {}) do
			bar:SetSize(swChargeWidth, abilityBarHeight)
		end
	end

	-- Whirling Surge
	if self.whirlingSurgeBar then
		self.whirlingSurgeBar:SetSize(width, abilityBarHeight)
	end

	-- Update sustain marker
	if self.sustainableMarker then
		local markerWidth = ui.sustainableSpeedMarkerWidth or 1
		local markerAlpha = ui.sustainableSpeedMarkerAlpha or 0.2
		self.sustainableMarker:SetWidth(markerWidth)
		self.sustainableMarker:SetColorTexture(1, 1, 1, markerAlpha)
	end

	-- Reposition frames with new gaps (respecting visibility)
	if self.accelFrame and self.frame then
		self.accelFrame:ClearAllPoints()
		self.accelFrame:SetPoint("TOP", self.frame, "BOTTOM", 0, -(ui.accelBarGap or 2))
	end

	-- Get visibility state for proper positioning
	local visibility = self.currentVisibility
	if not visibility then
		local abilityBars = db.profile.abilityBars or {}
		visibility = {
			showSurgeForward = abilityBars.showSurgeForward ~= false,
			showSecondWind = abilityBars.showSecondWind ~= false,
			showWhirlingSurge = abilityBars.showWhirlingSurge ~= false,
		}
	end

	-- Reposition ability bars with gap collapsing
	self:RepositionAbilityBars(visibility)
end

--- Update font settings on speed text.
function FlightsimView:UpdateFont()
	if not self.db or not self.speedText then
		return
	end

	local p = self.db.profile.speedBar or {}
	local fontFamily = p.fontFamily or "Fonts\\ARIALN.TTF"
	local fontSize = p.fontSize or 10
	local fontOutline = p.fontOutline or "OUTLINE"

	self.speedText:SetFont(fontFamily, fontSize, fontOutline)
end

--- Update frame background and border colors.
function FlightsimView:UpdateFrameColors()
	if not self.db then
		return
	end

	local colors = self.db.profile.colors or {}
	local frame = colors.frame or {}
	local bg = frame.background or { r = 0, g = 0, b = 0, a = 0.3 }
	local border = frame.border or { r = 0, g = 0, b = 0, a = 0 }
	local borderWidth = frame.borderWidth or 0

	-- Update container background
	if self.containerBg then
		self.containerBg:SetColorTexture(bg.r, bg.g, bg.b, bg.a)
	end

	-- Update border textures (repositioned outside frame)
	if self.borders and self.container then
		if self.borders.top then
			self.borders.top:SetColorTexture(border.r, border.g, border.b, border.a)
			self.borders.top:SetHeight(borderWidth)
			self.borders.top:ClearAllPoints()
			self.borders.top:SetPoint("BOTTOMLEFT", self.container, "TOPLEFT", -borderWidth, 0)
			self.borders.top:SetPoint("BOTTOMRIGHT", self.container, "TOPRIGHT", borderWidth, 0)
		end
		if self.borders.bottom then
			self.borders.bottom:SetColorTexture(border.r, border.g, border.b, border.a)
			self.borders.bottom:SetHeight(borderWidth)
			self.borders.bottom:ClearAllPoints()
			self.borders.bottom:SetPoint("TOPLEFT", self.container, "BOTTOMLEFT", -borderWidth, 0)
			self.borders.bottom:SetPoint("TOPRIGHT", self.container, "BOTTOMRIGHT", borderWidth, 0)
		end
		if self.borders.left then
			self.borders.left:SetColorTexture(border.r, border.g, border.b, border.a)
			self.borders.left:SetWidth(borderWidth)
		end
		if self.borders.right then
			self.borders.right:SetColorTexture(border.r, border.g, border.b, border.a)
			self.borders.right:SetWidth(borderWidth)
		end
	end
end

--- Invalidate color cache (triggers recalculation on next frame).
--- Colors are handled in Logic layer, so just force an update.
function FlightsimView:InvalidateColorCache()
	lastUpdateTime = 0
end

--- Update ability background colors.
function FlightsimView:UpdateAbilityColors()
	if not self.db then
		return
	end

	local colors = self.db.profile.colors or {}
	local abilities = colors.abilities or {}

	-- Surge Forward frame background
	if self.surgeForwardFrameBg then
		local c = abilities.surgeForwardFrameBg or { r = 0, g = 0, b = 0, a = 0 }
		self.surgeForwardFrameBg:SetColorTexture(c.r, c.g, c.b, c.a)
	end

	-- Surge Forward individual bar backgrounds
	local sfBarBg = abilities.surgeForwardBarBg or { r = 0.1, g = 0.15, b = 0.25, a = 0.5 }
	for _, bg in ipairs(self.surgeForwardBarBgs or {}) do
		bg:SetColorTexture(sfBarBg.r, sfBarBg.g, sfBarBg.b, sfBarBg.a)
	end

	-- Second Wind frame background
	if self.secondWindFrameBg then
		local c = abilities.secondWindFrameBg or { r = 0, g = 0, b = 0, a = 0 }
		self.secondWindFrameBg:SetColorTexture(c.r, c.g, c.b, c.a)
	end

	-- Second Wind individual bar backgrounds
	local swBarBg = abilities.secondWindBarBg or { r = 0.2, g = 0.1, b = 0.25, a = 0.5 }
	for _, bg in ipairs(self.secondWindBarBgs or {}) do
		bg:SetColorTexture(swBarBg.r, swBarBg.g, swBarBg.b, swBarBg.a)
	end

	-- Whirling Surge bar background
	if self.whirlingSurgeBg then
		local c = abilities.whirlingSurgeBarBg or { r = 0.1, g = 0.2, b = 0.22, a = 0.5 }
		self.whirlingSurgeBg:SetColorTexture(c.r, c.g, c.b, c.a)
	end
end

--- Set width for all bars.
---@param width number Bar width in pixels
function FlightsimView:SetWidth(width)
	if not self.db then
		return
	end
	width = tonumber(width)
	if not width then
		return
	end
	if width < 50 then
		width = 50
	end
	if width > 800 then
		width = 800
	end

	self.db.profile.ui.width = width
	self:RebuildLayout()
end

-- ============================================================================
-- MechanicLib Integration (Performance & Debug)
-- ============================================================================

--- Debug buffer for MechanicLib pull model
FlightsimView.debugBuffer = {}

--- Get performance sub-metrics for MechanicLib
---@return table[] Array of performance metrics
function FlightsimView:GetPerformanceSubMetrics()
	local p = self.perf
	return {
		{ name = "Executor", msPerSec = p.executor, description = "Bridge logic and API calls" },
		{ name = "Speed Bar", msPerSec = p.speed, description = "Speed percent calculation and HUD bar" },
		{ name = "Accel Bar", msPerSec = p.accel, description = "Acceleration delta calculation and UI" },
		{ name = "Visibility", msPerSec = p.visibility, description = "Frame visibility updates" },
		{ name = "Surge Forward", msPerSec = p.surge, description = "Surge Forward charges and animations" },
		{ name = "Whirling Surge", msPerSec = p.whirling, description = "Whirling Surge cooldown bar" },
		{ name = "Second Wind", msPerSec = p.wind, description = "Second Wind charges and animations" },
	}
end

--- Test definitions for MechanicLib
FlightsimView.tests = {
	{
		id = "view_init",
		name = "View Layer Init",
		category = "UI Compliance",
		type = "auto",
		description = "Verifies View layer initialized correctly.",
	},
}

--- Get all tests for MechanicLib
---@return table[] Array of test definitions
function FlightsimView:GetTests()
	return self.tests
end

--- Run a specific test
---@param id string Test ID
---@return table Test result
function FlightsimView:RunTest(id)
	local startTime = debugprofilestop()
	local result = self:GetTestResult(id)
	if type(result) == "table" then
		result.duration = (debugprofilestop() - startTime) / 1000
		result.id = id
	end
	return result
end

--- Get test result
---@param id string Test ID
---@return table Test result
function FlightsimView:GetTestResult(id)
	if id == "view_init" then
		local details = {}

		-- Check container exists
		local hasContainer = self.container ~= nil
		table.insert(details, {
			label = "Container Frame",
			value = hasContainer and "OK" or "Missing",
			status = hasContainer and "pass" or "fail",
		})

		-- Check speed bar exists
		local hasSpeedBar = self.frame ~= nil
		table.insert(details, {
			label = "Speed Bar",
			value = hasSpeedBar and "OK" or "Missing",
			status = hasSpeedBar and "pass" or "fail",
		})

		-- Check accel bar exists
		local hasAccelBar = self.accelBar ~= nil
		table.insert(details, {
			label = "Accel Bar",
			value = hasAccelBar and "OK" or "Missing",
			status = hasAccelBar and "pass" or "fail",
		})

		local allPassed = hasContainer and hasSpeedBar and hasAccelBar
		return {
			passed = allPassed,
			status = allPassed and "pass" or "fail",
			summary = allPassed and "View layer initialized" or "View layer incomplete",
			details = details,
		}
	end

	return {
		passed = false,
		status = "fail",
		summary = "Unknown test: " .. tostring(id),
		details = {},
	}
end

return FlightsimView
