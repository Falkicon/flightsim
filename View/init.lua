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

-- Throttling
local UPDATE_INTERVAL_ACTIVE = 0.05 -- 20Hz when visible
local UPDATE_INTERVAL_IDLE = 0.5 -- 2Hz when hidden

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
	container:SetMovable(true)
	container:EnableMouse(true)
	container:RegisterForDrag("LeftButton")
	container:SetScript("OnDragStart", function(f)
		if not db.profile.locked then
			f:StartMoving()
		end
	end)
	container:SetScript("OnDragStop", function(f)
		f:StopMovingOrSizing()
		local _, _, _, x, y = f:GetPoint(1)
		db.profile.x = x
		db.profile.y = y
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
	local now = GetTime()
	local interval = self.frame:IsShown() and UPDATE_INTERVAL_ACTIVE or UPDATE_INTERVAL_IDLE

	if (now - lastUpdateTime) < interval then
		return
	end
	lastUpdateTime = now

	-- Execute full update through Bridge (with timing)
	local execStart = debugprofilestop()
	local result = Executor.FullUpdate(self.db, {
		accelBarWidth = self.accelFrame and self.accelFrame:GetWidth() or 200,
		accelBarHeight = self.accelFrame and self.accelFrame:GetHeight() or 4,
	})
	self.perf.executor = debugprofilestop() - execStart

	if not result.success then
		return
	end

	local data = ActionResult.unwrap(result)

	-- Apply visibility (with timing)
	if data.visibility then
		local visStart = debugprofilestop()
		self:ApplyVisibilityState(data.visibility)
		self.perf.visibility = debugprofilestop() - visStart
	end

	-- Update components if visible (with timing)
	if data.shouldUpdate then
		local speedStart = debugprofilestop()
		self:UpdateSpeed(data.speed)
		self.perf.speed = debugprofilestop() - speedStart

		local accelStart = debugprofilestop()
		self:UpdateAcceleration(data.acceleration)
		self.perf.accel = debugprofilestop() - accelStart

		if data.surgeForward then
			local surgeStart = debugprofilestop()
			self:UpdateChargeBar("surgeForward", data.surgeForward)
			self.perf.surge = debugprofilestop() - surgeStart
		end
		if data.secondWind then
			local windStart = debugprofilestop()
			self:UpdateChargeBar("secondWind", data.secondWind)
			self.perf.wind = debugprofilestop() - windStart
		end
		if data.whirlingSurge then
			local whirlStart = debugprofilestop()
			self:UpdateCooldownBar(data.whirlingSurge)
			self.perf.whirling = debugprofilestop() - whirlStart
		end
	end
end

--- Apply visibility state to frames and reposition bars to collapse gaps.
---@param visibility table Visibility state from Executor
function FlightsimView:ApplyVisibilityState(visibility)
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
	local abilityBarHeight = ui.abilityBarHeight or 10

	-- The accel frame is always the anchor point for ability bars
	local lastFrame = self.accelFrame

	-- Surge Forward
	if self.surgeForwardFrame then
		self.surgeForwardFrame:ClearAllPoints()
		if visibility.showSurgeForward then
			self.surgeForwardFrame:SetPoint("TOP", lastFrame, "BOTTOM", 0, -barGap)
			lastFrame = self.surgeForwardFrame
		end
	end

	-- Second Wind
	if self.secondWindFrame then
		self.secondWindFrame:ClearAllPoints()
		if visibility.showSecondWind then
			self.secondWindFrame:SetPoint("TOP", lastFrame, "BOTTOM", 0, -barGap)
			lastFrame = self.secondWindFrame
		end
	end

	-- Whirling Surge
	if self.whirlingSurgeBar then
		self.whirlingSurgeBar:ClearAllPoints()
		if visibility.showWhirlingSurge then
			self.whirlingSurgeBar:SetPoint("TOP", lastFrame, "BOTTOM", 0, -barGap)
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

	-- Base height: speed bar + gap + accel bar
	local totalHeight = speedBarHeight + accelGap + accelBarHeight

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
			self.sustainableMarker:Show()
			self.sustainableMarker:ClearAllPoints()
			local barWidth = self.frame:GetWidth()
			self.sustainableMarker:SetPoint("TOP", self.frame, "TOPLEFT", data.markerPct * barWidth, 0)
			self.sustainableMarker:SetPoint("BOTTOM", self.frame, "BOTTOMLEFT", data.markerPct * barWidth, 0)
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
	local colorFunc = abilityKey == "surgeForward" and Color.ForSurgeForward
		or Color.ForSecondWind

	for i, state in ipairs(data.states or {}) do
		local bar = bars[i]
		if bar then
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
	if scale < 0.5 then scale = 0.5 end
	if scale > 2.0 then scale = 2.0 end

	-- Only set scale on container - all child frames inherit it
	if self.container then
		self.container:SetScale(scale)
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
	local barGap = ui.barGap or 2
	local chargeGap = 2

	-- Surge Forward (6 charges)
	if self.surgeForwardFrame then
		self.surgeForwardFrame:SetSize(width, abilityBarHeight)
		local sfTotalGaps = chargeGap * 5
		local sfChargeWidth = (width - sfTotalGaps) / 6
		for i, bar in ipairs(self.surgeForwardBars or {}) do
			bar:SetSize(sfChargeWidth, abilityBarHeight)
		end
	end

	-- Second Wind (3 charges)
	if self.secondWindFrame then
		self.secondWindFrame:SetSize(width, abilityBarHeight)
		local swTotalGaps = chargeGap * 2
		local swChargeWidth = (width - swTotalGaps) / 3
		for i, bar in ipairs(self.secondWindBars or {}) do
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
	if not width then return end
	if width < 50 then width = 50 end
	if width > 800 then width = 800 end

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

