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

-- Internal state
local isInitialized = false
local tickerFrame = nil
local lastUpdateTime = 0

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
	-- Main HUD frame
	if not self.frame then
		self.frame = CreateFrame("StatusBar", "FlightsimHUD", UIParent)
		self.frame:SetSize(200, 12)
		self.frame:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
		self.frame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
		self.frame:SetMinMaxValues(0, 1)

		-- Make draggable when unlocked
		self.frame:SetMovable(true)
		self.frame:EnableMouse(true)
		self.frame:RegisterForDrag("LeftButton")
		self.frame:SetScript("OnDragStart", function(f)
			if not self.db.profile.ui.locked then
				f:StartMoving()
			end
		end)
		self.frame:SetScript("OnDragStop", function(f)
			f:StopMovingOrSizing()
			local point, _, relPoint, x, y = f:GetPoint()
			if self.db.profile.ui then
				self.db.profile.ui.point = point
				self.db.profile.ui.relPoint = relPoint
				self.db.profile.ui.x = x
				self.db.profile.ui.y = y
			end
		end)
	end

	-- Speed text
	if not self.speedText then
		self.speedText = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		self.speedText:SetPoint("CENTER", self.frame, "CENTER")
	end

	-- Sustainable marker
	if not self.sustainableMarker then
		self.sustainableMarker = self.frame:CreateTexture(nil, "OVERLAY")
		self.sustainableMarker:SetWidth(2)
		self.sustainableMarker:SetColorTexture(1, 1, 1, 0.8)
	end

	-- Initialize components (will be created by component modules)
	-- Components.SpeedBar, Components.AccelBar, etc.
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

--- Stop the update loop.
function FlightsimView:StopUpdating()
	if tickerFrame then
		tickerFrame:SetScript("OnUpdate", nil)
		tickerFrame = nil
	end
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

	-- Execute full update through Bridge
	local result = Executor.FullUpdate(self.db, {
		accelBarWidth = self.accelFrame and self.accelFrame:GetWidth() or 200,
		accelBarHeight = self.accelFrame and self.accelFrame:GetHeight() or 4,
	})

	if not result.success then
		return
	end

	local data = FlightsimCore.Actions.unwrap(result)

	-- Apply visibility
	if data.visibility then
		self:ApplyVisibilityState(data.visibility)
	end

	-- Update components if visible
	if data.shouldUpdate then
		self:UpdateSpeed(data.speed)
		self:UpdateAcceleration(data.acceleration)

		if data.surgeForward then
			self:UpdateChargeBar("surgeForward", data.surgeForward)
		end
		if data.secondWind then
			self:UpdateChargeBar("secondWind", data.secondWind)
		end
		if data.whirlingSurge then
			self:UpdateCooldownBar(data.whirlingSurge)
		end
	end
end

--- Apply visibility state to frames.
---@param visibility table Visibility state from Executor
function FlightsimView:ApplyVisibilityState(visibility)
	if visibility.showHUD then
		if not self.frame:IsShown() then
			self.frame:Show()
		end
	else
		if self.frame:IsShown() then
			self.frame:Hide()
		end
	end

	-- Apply to ability frames (if they exist)
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
	self.accelBar:SetColorTexture(1, 1, 1, 0.9)

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

	local colorFunc = abilityKey == "surgeForward" and FlightsimCore.Utils.Color.ForSurgeForward
		or FlightsimCore.Utils.Color.ForSecondWind

	for i, state in ipairs(data.states or {}) do
		local bar = bars[i]
		if bar then
			bar:SetValue(state.displayPct or 0)
			local r, g, b = colorFunc(state.displayPct or 0)
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

	local c = data.barColor or { 0.3, 0.8, 0.8 }
	self.whirlingSurgeBar:SetStatusBarColor(c[1], c[2], c[3], 1)
end

--- Apply visibility (legacy method for compatibility).
function FlightsimView:ApplyVisibility()
	-- Trigger a visibility recalculation on next update
	lastUpdateTime = 0
end

return FlightsimView
