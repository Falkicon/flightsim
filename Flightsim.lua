local ADDON_NAME = ...

Flightsim = Flightsim or {}
Flightsim.debugMode = false

-- Initialize MechanicLib if available
local MechanicLib = LibStub("MechanicLib-1.0", true)

local L = setmetatable({}, {
	__index = function(t, k)
		return k
	end,
})
Flightsim.L = L

FlightsimUI = FlightsimUI or {}
FlightsimUI.Utils = FlightsimUI.Utils or {}

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
FlightsimUI.Utils.CopyDefaults = CopyDefaults

local DEFAULTS = {
	profile = {
		locked = false,
		debugMode = false,
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
				"Second Wind",
			},
			enabled = {
				["Surge Forward"] = true,
				["Whirling Surge"] = true,
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

		if FlightsimUI and FlightsimUI.Init then
			FlightsimUI:Init(FlightsimDB)
		end

		-- Sync debug mode from settings
		if FlightsimDB.profile then
			Flightsim.debugMode = FlightsimDB.profile.debugMode
		end

		-- Register with Mechanic if available
		if MechanicLib then
			MechanicLib:Register("Flightsim", {
				version = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"),
				getDebugBuffer = function()
					return FlightsimUI and FlightsimUI.debugBuffer or {}
				end,
				clearDebugBuffer = function()
					if FlightsimUI and FlightsimUI.debugBuffer then
						wipe(FlightsimUI.debugBuffer)
					end
				end,

				-- Testing Integration (Phase 5 Rich Details)
				tests = {
					getAll = function()
						return FlightsimUI:GetTests()
					end,
					getCategories = function()
						return { "API Diagnostic", "UI Compliance" }
					end,
					run = function(id)
						return FlightsimUI:RunTest(id)
					end,
					getResult = function(id)
						return FlightsimUI:GetTestResult(id)
					end,
				},

				-- Performance Integration (Phase 6 Sub-metrics)
				performance = {
					getSubMetrics = function()
						return FlightsimUI:GetPerformanceSubMetrics()
					end,
				},

				-- Tools Integration (Phase 6 Custom Panel)
				tools = {
					createPanel = function(container)
						if FlightsimConfig and FlightsimConfig.CreateCompliancePanel then
							FlightsimConfig:CreateCompliancePanel(container)
						end
					end,
				},

				-- Inspect Integration (Phase 8)
				inspect = {
					getWatchFrames = function()
						local UI = FlightsimUI
						local frames = {
							{ label = "Main HUD", frame = UI.frame, property = "Visibility" },
							{ label = "Speed Bar", frame = UI.speedBar, property = "Value" },
							{ label = "Accel Bar", frame = UI.accelBar, property = "Width" },
						}
						-- Add first charge of each ability for quick monitoring
						if UI.surgeForwardBars and UI.surgeForwardBars[1] then
							table.insert(frames, { label = "Surge 1", frame = UI.surgeForwardBars[1], property = "Value" })
						end
						if UI.secondWindBars and UI.secondWindBars[1] then
							table.insert(frames, { label = "Wind 1", frame = UI.secondWindBars[1], property = "Value" })
						end
						if UI.whirlingSurgeBar then
							table.insert(frames, { label = "Whirling", frame = UI.whirlingSurgeBar, property = "Value" })
						end
						return frames
					end,
				},

				settings = {
					debugMode = {
						type = "toggle",
						name = "Debug Mode",
						get = function()
							return FlightsimDB.profile.debugMode
						end,
						set = function(v)
							FlightsimDB.profile.debugMode = v
							Flightsim.debugMode = v
						end,
					},
				},
			})
		end
	end
end)
