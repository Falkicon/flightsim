local ADDON_NAME, ns = ...

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

-- AceDB defaults table
local defaults = {
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
			showSustainMarker = true,
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
			fontFamily = "Fonts\\ARIALN.TTF",
			fontOutline = "OUTLINE",
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
		-- Phase 3: Color customization
		colors = {
			speedBar = {
				useCustom = false,
				gradient = {
					start = { r = 0.769, g = 0.169, b = 0.016, a = 1 }, -- Red
					middle = { r = 0.769, g = 0.651, b = 0.016, a = 1 }, -- Yellow
					finish = { r = 0.169, g = 0.651, b = 0.016, a = 1 }, -- Green
				},
			},
			accelBar = {
				useDynamic = false,
				decel = { r = 1, g = 0, b = 0, a = 0.9 },
				accel = { r = 0, g = 1, b = 0, a = 0.9 },
			},
			abilities = {
				surgeForward = { r = 0.455, g = 0.686, b = 1.0, a = 1 }, -- #74AFFF
				secondWind = { r = 0.827, g = 0.475, b = 0.937, a = 1 }, -- #D379EF
				whirlingSurge = { r = 0.290, g = 0.780, b = 0.831, a = 1 }, -- #4AC7D4
			},
			frame = {
				background = { r = 0.08, g = 0.12, b = 0.18, a = 0.85 },
				border = { r = 0, g = 0, b = 0, a = 0 }, -- Invisible by default
			},
		},
	},
}

-- Profile change callback
function Flightsim:OnProfileChanged()
	-- Rebuild UI when profile changes
	if FlightsimUI then
		FlightsimUI.db = self.db
		if FlightsimUI.RebuildLayout then
			FlightsimUI:RebuildLayout()
		end
		if FlightsimUI.ApplyVisibility then
			FlightsimUI:ApplyVisibility()
		end
	end
	-- Sync debug mode
	self.debugMode = self.db.profile.debugMode
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, name)
	if event == "ADDON_LOADED" and name == ADDON_NAME then
		-- Initialize AceDB
		Flightsim.db = LibStub("AceDB-3.0"):New("FlightsimDB", defaults, true)

		-- Register profile change callbacks
		Flightsim.db.RegisterCallback(Flightsim, "OnProfileChanged", "OnProfileChanged")
		Flightsim.db.RegisterCallback(Flightsim, "OnProfileCopied", "OnProfileChanged")
		Flightsim.db.RegisterCallback(Flightsim, "OnProfileReset", "OnProfileChanged")

		-- Initialize UI with db reference
		if FlightsimUI and FlightsimUI.Init then
			FlightsimUI:Init(Flightsim.db)
		end

		-- Initialize settings (AceConfig)
		if ns.InitializeSettings then
			ns:InitializeSettings()
		end

		-- Sync debug mode from settings
		Flightsim.debugMode = Flightsim.db.profile.debugMode

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

				-- Tools Integration
				tools = {
					createPanel = function(container)
						if FlightsimConfig and FlightsimConfig.CreateToolsPanel then
							FlightsimConfig:CreateToolsPanel(container)
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
							table.insert(
								frames,
								{ label = "Surge 1", frame = UI.surgeForwardBars[1], property = "Value" }
							)
						end
						if UI.secondWindBars and UI.secondWindBars[1] then
							table.insert(frames, { label = "Wind 1", frame = UI.secondWindBars[1], property = "Value" })
						end
						if UI.whirlingSurgeBar then
							table.insert(
								frames,
								{ label = "Whirling", frame = UI.whirlingSurgeBar, property = "Value" }
							)
						end
						return frames
					end,
				},

				settings = {
					debugMode = {
						type = "toggle",
						name = "Debug Mode",
						get = function()
							return Flightsim.db.profile.debugMode
						end,
						set = function(v)
							Flightsim.db.profile.debugMode = v
							Flightsim.debugMode = v
						end,
					},
				},
			})
		end
	end
end)
