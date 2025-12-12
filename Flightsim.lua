local ADDON_NAME = ...

Flightsim = Flightsim or {}

local function CopyDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = dst[k] or {}
			CopyDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local DEFAULTS = {
	profile = {
		locked = false,
		x = 0,
		y = 0,
		scale = 1,
		ui = {
			width = 150,
			speedBarHeight = 20,
			rowHeight = 22,
			padding = 10,
			gap = 6,
			sustainableSpeedMarkerWidth = 1,
			sustainableSpeedMarkerAlpha = 0.2,
			accelBarHeight = 1,
			accelBarGap = 0,
			abilityBarHeight = 5,
			barGap = 2,
		},
		speedBar = {
			maxSpeed = 950,
			sustainableSpeed = 790,
			fontSize = 10,
			showPercent = true,
		},
		visibility = {
			hideWhenNotSkyriding = true,
		},
		abilityBars = {
			showWhirlingSurge = true,
			showSecondWind = true,
			showSurgeForward = true,
		},
		abilities = {
			-- Stored as stable tokens (English names for now); resolved to spellIDs at runtime.
			order = {
				"Surge Forward",
				"Whirling Surge",
				"Skyward Ascent",
				"Aerial Halt",
				"Second Wind",
			},
			enabled = {
				["Surge Forward"] = true,
				["Whirling Surge"] = true,
				["Skyward Ascent"] = true,
				["Aerial Halt"] = true,
				["Second Wind"] = true,
			},
		},
	},
}

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == ADDON_NAME then
		FlightsimDB = FlightsimDB or {}
		CopyDefaults(FlightsimDB, DEFAULTS)

		-- Migration: remove deprecated hideWhileSkyriding setting
		if FlightsimDB.profile and FlightsimDB.profile.visibility then
			FlightsimDB.profile.visibility.hideWhileSkyriding = nil
		end

		if FlightsimUI and FlightsimUI.Init then
			FlightsimUI:Init(FlightsimDB)
		end
	end
end)
