local ADDON_NAME = ...

-- Blizzard Settings (Retail 10.0+). No external libraries.
-- This file intentionally sticks to simple controls (checkbox/slider/dropdown)
-- and writes through to FlightsimDB.profile.

local function GetProfile()
	FlightsimDB = FlightsimDB or {}
	FlightsimDB.profile = FlightsimDB.profile or {}
	local p = FlightsimDB.profile

	p.ui = p.ui or {}
	p.speedBar = p.speedBar or {}
	p.visibility = p.visibility or {}
	p.abilityBars = p.abilityBars or {}

	-- General
	if p.locked == nil then
		p.locked = false
	end
	if p.scale == nil then
		p.scale = 1
	end

	-- UI dimensions
	if p.ui.width == nil then
		p.ui.width = 150
	end
	if p.ui.speedBarHeight == nil then
		p.ui.speedBarHeight = 20
	end
	if p.ui.sustainableSpeedMarkerWidth == nil then
		p.ui.sustainableSpeedMarkerWidth = p.ui.optimalMarkerWidth or 1
	end
	if p.ui.sustainableSpeedMarkerAlpha == nil then
		p.ui.sustainableSpeedMarkerAlpha = 0.2
	end
	if p.ui.accelBarHeight == nil then
		p.ui.accelBarHeight = 1
	end
	if p.ui.accelBarGap == nil then
		p.ui.accelBarGap = 0
	end
	if p.ui.abilityBarHeight == nil then
		p.ui.abilityBarHeight = 5
	end
	if p.ui.barGap == nil then
		p.ui.barGap = 2
	end

	-- Speed bar
	if p.speedBar.maxSpeed == nil then
		p.speedBar.maxSpeed = 950
	end
	if p.speedBar.sustainableSpeed == nil then
		p.speedBar.sustainableSpeed = p.speedBar.optimalSpeed or 790
	end
	if p.speedBar.fontSize == nil then
		p.speedBar.fontSize = 10
	end
	if p.speedBar.showPercent == nil then
		p.speedBar.showPercent = true
	end

	-- Visibility
	if p.visibility.hideWhenNotSkyriding == nil then
		p.visibility.hideWhenNotSkyriding = true
	end

	-- Ability bars
	if p.abilityBars.showSurgeForward == nil then -- luacheck: ignore
		p.abilityBars.showSurgeForward = true
	end
	if p.abilityBars.showSecondWind == nil then
		p.abilityBars.showSecondWind = true
	end
	if p.abilityBars.showWhirlingSurge == nil then
		p.abilityBars.showWhirlingSurge = true
	end

	return p
end

local function ApplyIfReady(methodName, ...)
	if FlightsimUI and FlightsimUI[methodName] then
		local ok = pcall(FlightsimUI[methodName], FlightsimUI, ...)
		return ok
	end
	return false
end

-- Custom label formatter for sliders showing decimal values
local function FormatDecimal2(value)
	return string.format("%.2f", value)
end

local function RegisterSettings()
	local L = Flightsim.L
	local Clamp = FlightsimUI.Utils.Clamp
	if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory) then
		-- Modern Settings UI not available; silently do nothing.
		return
	end

	local category = Settings.RegisterVerticalLayoutCategory("Flightsim")

	local function OnSettingChanged(_, _)
		-- Placeholder hook for future: could call Settings.NotifyUpdate if needed.
	end

	-- ============================================================
	-- Visibility Settings
	-- ============================================================

	-- Lock frame
	do
		local name = L["LOCK_FRAME"]
		local variable = "Flightsim_Locked"
		local defaultValue = false

		local function GetValue()
			return GetProfile().locked
		end

		local function SetValue(value)
			GetProfile().locked = value and true or false
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)
		Settings.CreateCheckbox(category, setting, L["LOCK_FRAME_DESC"])
	end

	-- Only show when skyriding
	do
		local name = L["ONLY_SKYRIDING"]
		local variable = "Flightsim_HideWhenNotSkyriding"
		local defaultValue = true

		local function GetValue()
			local v = GetProfile().visibility
			if v.hideWhenNotSkyriding == nil then
				return defaultValue
			end
			return v.hideWhenNotSkyriding
		end

		local function SetValue(value)
			GetProfile().visibility.hideWhenNotSkyriding = value and true or false
			ApplyIfReady("ApplyVisibility")
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)
		Settings.CreateCheckbox(category, setting, L["ONLY_SKYRIDING_DESC"])
	end

	-- ============================================================
	-- Appearance Settings
	-- ============================================================

	-- Scale
	do
		local name = L["SCALE"]
		local variable = "Flightsim_Scale"
		local defaultValue = 1
		local minValue, maxValue, step = 0.5, 2.0, 0.05

		local function GetValue()
			return GetProfile().scale or defaultValue
		end

		local function SetValue(value)
			value = Clamp(tonumber(value) or defaultValue, minValue, maxValue)
			GetProfile().scale = value
			ApplyIfReady("SetScale", value)
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)

		local options = Settings.CreateSliderOptions(minValue, maxValue, step)
		if options and options.SetLabelFormatter then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatDecimal2)
		end

		Settings.CreateSlider(category, setting, options, L["SCALE_DESC"])
	end

	-- Bar width
	do
		local name = L["BAR_WIDTH"]
		local variable = "Flightsim_Width"
		local defaultValue = 150
		local minValue, maxValue, step = 50, 800, 10

		local function GetValue()
			return GetProfile().ui.width or defaultValue
		end

		local function SetValue(value)
			value = Clamp(tonumber(value) or defaultValue, minValue, maxValue)
			GetProfile().ui.width = value
			ApplyIfReady("SetWidth", value)
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)

		local options = Settings.CreateSliderOptions(minValue, maxValue, step)
		if
			options
			and options.SetLabelFormatter
			and MinimalSliderWithSteppersMixin
			and MinimalSliderWithSteppersMixin.Label
			and MinimalSliderWithSteppersMixin.Label.Right
		then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end

		Settings.CreateSlider(category, setting, options, L["BAR_WIDTH_DESC"])
	end

	-- Font size
	do
		local name = L["FONT_SIZE"]
		local variable = "Flightsim_FontSize"
		local defaultValue = 10
		local minValue, maxValue, step = 8, 48, 1

		local function GetValue()
			return GetProfile().speedBar.fontSize or defaultValue
		end

		local function SetValue(value)
			value = Clamp(tonumber(value) or defaultValue, minValue, maxValue)
			GetProfile().speedBar.fontSize = value
			ApplyIfReady("SetFontSize", value)
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)

		local options = Settings.CreateSliderOptions(minValue, maxValue, step)
		if
			options
			and options.SetLabelFormatter
			and MinimalSliderWithSteppersMixin
			and MinimalSliderWithSteppersMixin.Label
			and MinimalSliderWithSteppersMixin.Label.Right
		then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end

		Settings.CreateSlider(category, setting, options, L["FONT_SIZE_DESC"])
	end

	-- Show as percentage
	do
		local name = L["SHOW_PERCENT"]
		local variable = "Flightsim_ShowPercent"
		local defaultValue = true

		local function GetValue()
			local v = GetProfile().speedBar.showPercent
			if v == nil then
				return defaultValue
			end
			return v
		end

		local function SetValue(value)
			GetProfile().speedBar.showPercent = value and true or false
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)
		Settings.CreateCheckbox(category, setting, L["SHOW_PERCENT_DESC"])
	end

	-- ============================================================
	-- SECTION: Speed Bar
	-- ============================================================
	-- Speed bar height
	do
		local name = L["HEIGHT"]
		local variable = "Flightsim_BarHeight"
		local defaultValue = 20
		local minValue, maxValue, step = 10, 100, 2

		local function GetValue()
			return GetProfile().ui.speedBarHeight or defaultValue
		end

		local function SetValue(value)
			value = Clamp(tonumber(value) or defaultValue, minValue, maxValue)
			GetProfile().ui.speedBarHeight = value
			ApplyIfReady("SetBarHeight", value)
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)

		local options = Settings.CreateSliderOptions(minValue, maxValue, step)
		if
			options
			and options.SetLabelFormatter
			and MinimalSliderWithSteppersMixin
			and MinimalSliderWithSteppersMixin.Label
			and MinimalSliderWithSteppersMixin.Label.Right
		then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end

		Settings.CreateSlider(category, setting, options, L["SPEED_BAR_HEIGHT_DESC"])
	end

	-- Sustain speed marker width
	do
		local name = L["SUSTAIN_MARKER_WIDTH"]
		local variable = "Flightsim_SustainableMarkerWidth"
		local defaultValue = 1
		local minValue, maxValue, step = 1, 5, 1

		local function GetValue()
			return GetProfile().ui.sustainableSpeedMarkerWidth or GetProfile().ui.optimalMarkerWidth or defaultValue
		end

		local function SetValue(value)
			value = Clamp(tonumber(value) or defaultValue, minValue, maxValue)
			GetProfile().ui.sustainableSpeedMarkerWidth = value
			ApplyIfReady("RebuildLayout")
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)

		local options = Settings.CreateSliderOptions(minValue, maxValue, step)
		if
			options
			and options.SetLabelFormatter
			and MinimalSliderWithSteppersMixin
			and MinimalSliderWithSteppersMixin.Label
			and MinimalSliderWithSteppersMixin.Label.Right
		then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end

		Settings.CreateSlider(category, setting, options, L["SUSTAIN_MARKER_WIDTH_DESC"])
	end

	-- Sustain speed marker alpha
	do
		local name = L["SUSTAIN_MARKER_ALPHA"]
		local variable = "Flightsim_SustainableMarkerAlpha"
		local defaultValue = 0.2
		local minValue, maxValue, step = 0.1, 1.0, 0.1

		local function GetValue()
			return GetProfile().ui.sustainableSpeedMarkerAlpha or defaultValue
		end

		local function SetValue(value)
			value = Clamp(tonumber(value) or defaultValue, minValue, maxValue)
			GetProfile().ui.sustainableSpeedMarkerAlpha = value
			ApplyIfReady("RebuildLayout")
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)

		local options = Settings.CreateSliderOptions(minValue, maxValue, step)
		if options and options.SetLabelFormatter then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, FormatDecimal2)
		end

		Settings.CreateSlider(category, setting, options, L["SUSTAIN_MARKER_ALPHA_DESC"])
	end

	-- ============================================================
	-- SECTION: Acceleration Bar
	-- ============================================================
	-- Acceleration bar height
	do
		local name = L["HEIGHT"]
		local variable = "Flightsim_AccelBarHeight"
		local defaultValue = 1
		local minValue, maxValue, step = 1, 10, 1

		local function GetValue()
			return GetProfile().ui.accelBarHeight or defaultValue
		end

		local function SetValue(value)
			value = Clamp(tonumber(value) or defaultValue, minValue, maxValue)
			GetProfile().ui.accelBarHeight = value
			ApplyIfReady("RebuildLayout")
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)

		local options = Settings.CreateSliderOptions(minValue, maxValue, step)
		if
			options
			and options.SetLabelFormatter
			and MinimalSliderWithSteppersMixin
			and MinimalSliderWithSteppersMixin.Label
			and MinimalSliderWithSteppersMixin.Label.Right
		then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end

		Settings.CreateSlider(category, setting, options, L["ACCEL_BAR_HEIGHT_DESC"])
	end

	-- ============================================================
	-- SECTION: Ability Bars
	-- ============================================================
	-- Ability bar height
	do
		local name = L["HEIGHT"]
		local variable = "Flightsim_AbilityBarHeight"
		local defaultValue = 5
		local minValue, maxValue, step = 2, 20, 1

		local function GetValue()
			return GetProfile().ui.abilityBarHeight or defaultValue
		end

		local function SetValue(value)
			value = Clamp(tonumber(value) or defaultValue, minValue, maxValue)
			GetProfile().ui.abilityBarHeight = value
			ApplyIfReady("RebuildLayout")
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)

		local options = Settings.CreateSliderOptions(minValue, maxValue, step)
		if
			options
			and options.SetLabelFormatter
			and MinimalSliderWithSteppersMixin
			and MinimalSliderWithSteppersMixin.Label
			and MinimalSliderWithSteppersMixin.Label.Right
		then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end

		Settings.CreateSlider(category, setting, options, L["ABILITY_BAR_HEIGHT_DESC"])
	end

	-- Bar gap (between ability bar sections)
	do
		local name = L["BAR_GAP"]
		local variable = "Flightsim_BarGap"
		local defaultValue = 2
		local minValue, maxValue, step = 0, 10, 1

		local function GetValue()
			return GetProfile().ui.barGap or defaultValue
		end

		local function SetValue(value)
			value = Clamp(tonumber(value) or defaultValue, minValue, maxValue)
			GetProfile().ui.barGap = value
			ApplyIfReady("RebuildLayout")
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)

		local options = Settings.CreateSliderOptions(minValue, maxValue, step)
		if
			options
			and options.SetLabelFormatter
			and MinimalSliderWithSteppersMixin
			and MinimalSliderWithSteppersMixin.Label
			and MinimalSliderWithSteppersMixin.Label.Right
		then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end

		Settings.CreateSlider(category, setting, options, L["BAR_GAP_DESC"])
	end

	-- Show Surge Forward
	do
		local name = L["SHOW_SURGE_FORWARD"]
		local variable = "Flightsim_ShowSurgeForward"
		local defaultValue = true

		local function GetValue()
			local v = GetProfile().abilityBars.showSurgeForward
			if v == nil then
				return defaultValue
			end
			return v
		end

		local function SetValue(value)
			GetProfile().abilityBars.showSurgeForward = value and true or false
			ApplyIfReady("RebuildLayout")
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)
		Settings.CreateCheckbox(category, setting, L["SHOW_SURGE_FORWARD_DESC"])
	end

	-- Show Second Wind
	do
		local name = L["SHOW_SECOND_WIND"]
		local variable = "Flightsim_ShowSecondWind"
		local defaultValue = true

		local function GetValue()
			local v = GetProfile().abilityBars.showSecondWind
			if v == nil then
				return defaultValue
			end
			return v
		end

		local function SetValue(value)
			GetProfile().abilityBars.showSecondWind = value and true or false
			ApplyIfReady("RebuildLayout")
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)
		Settings.CreateCheckbox(category, setting, L["SHOW_SECOND_WIND_DESC"])
	end

	-- Show Whirling Surge
	do
		local name = L["SHOW_WHIRLING_SURGE"]
		local variable = "Flightsim_ShowWhirlingSurge"
		local defaultValue = true

		local function GetValue()
			local v = GetProfile().abilityBars.showWhirlingSurge
			if v == nil then
				return defaultValue
			end
			return v
		end

		local function SetValue(value)
			GetProfile().abilityBars.showWhirlingSurge = value and true or false
			ApplyIfReady("RebuildLayout")
		end

		local setting = Settings.RegisterProxySetting(
			category,
			variable,
			type(defaultValue),
			name,
			defaultValue,
			GetValue,
			SetValue
		)
		setting:SetValueChangedCallback(OnSettingChanged)
		Settings.CreateCheckbox(category, setting, L["SHOW_WHIRLING_SURGE_DESC"])
	end

	Settings.RegisterAddOnCategory(category)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == ADDON_NAME then
		RegisterSettings()
	end
end)
