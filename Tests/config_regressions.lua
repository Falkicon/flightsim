-- Run from the repository root: lua Tests/config_regressions.lua
local output = {}
local originalPrint = print
print = function(message)
	output[#output + 1] = message
end

FlightsimLogic = {}
dofile("Logic/visibility.lua")
Flightsim = { L = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
}) }
dofile("Locales/enUS.lua")
local profile = {
	scale = 1,
	ui = { width = 150 },
	speedBar = { maxSpeed = 950, sustainableSpeed = 790 },
	visibility = {},
	abilityBars = { showSurgeForward = true, showSecondWind = true, showWhirlingSurge = true },
	abilities = {
		order = { "Surge Forward", "Second Wind", "Whirling Surge" },
		enabled = { ["Surge Forward"] = true },
	},
}
Flightsim.db = { profile = profile }
local visibleScale, visibleWidth, visibilityUpdates, layoutUpdates = nil, nil, 0, 0
FlightsimView = {
	SetScale = function(_, value)
		visibleScale = value
	end,
	SetWidth = function(_, value)
		visibleWidth = value
	end,
	ApplyVisibility = function()
		visibilityUpdates = visibilityUpdates + 1
	end,
	RebuildLayout = function()
		layoutUpdates = layoutUpdates + 1
	end,
}
SlashCmdList = {}
dofile("Config.lua")
assert(next(SlashCmdList) == nil and SLASH_FLIGHTSIM1 == nil, "Config must not duplicate AceConsole aliases")
local command = Flightsim.HandleSlashCommand
command("scale 99")
assert(profile.scale == 2 and visibleScale == 2, "saved scale must match rendered scale")
command("scale 0")
assert(profile.scale == 0.5 and visibleScale == 0.5)
command("scale " .. string.rep("9", 400))
assert(profile.scale == 0.5, "overflowing numeric input must be rejected")
command("width 999")
assert(profile.ui.width == 800 and visibleWidth == 800)
command("barmax 0")
assert(profile.speedBar.maxSpeed == 950, "zero bar maximum must be rejected")
command("barmax 1000")
assert(profile.speedBar.maxSpeed == 1000)
command("sustainable 0")
assert(profile.speedBar.sustainableSpeed == 0, "zero remains a supported marker-disable value")
assert(profile.speedBar.useCustomSustainableSpeed == true, "sustainable command must enable its explicit override")
command("sustainable auto")
assert(profile.speedBar.useCustomSustainableSpeed == false, "auto must restore the zone-aware marker")
command("toggle surge forward")
assert(profile.abilityBars.showSurgeForward == false and visibilityUpdates == 1)
command("list")
assert(output[#output - 2] == "  1. Surge Forward [OFF]", "list must report the settings used by the renderer")
command("move whirling 1")
assert(profile.abilities.order[1] == "Whirling Surge" and layoutUpdates == 1)
command("list")
assert(output[#output - 2] == "  1. Whirling Surge [ON]", "list must reflect custom row order")

-- Exercise the actual settings registration and both aliases.
local commands, opened, refreshed = {}, 0, 0
local libraries = {
	["AceConfig-3.0"] = { RegisterOptionsTable = function() end },
	["AceConfigDialog-3.0"] = {
		AddToBlizOptions = function() end,
		Open = function()
			opened = opened + 1
		end,
	},
	["AceConfigRegistry-3.0"] = {
		NotifyChange = function()
			refreshed = refreshed + 1
		end,
	},
	["AceDBOptions-3.0"] = {
		GetOptionsTable = function()
			return {}
		end,
	},
	["AceConsole-3.0"] = {
		RegisterChatCommand = function(_, alias, handler)
			assert(commands[alias] == nil, "each alias must be registered exactly once")
			commands[alias] = handler
		end,
	},
}
LibStub = function(name)
	return assert(libraries[name], name)
end
C_Timer = {
	After = function(_, callback)
		callback()
	end,
}
local namespace = {}
assert(loadfile("Settings.lua"))("Flightsim", namespace)
namespace:InitializeSettings()
commands.fs("  ")
commands.flightsim("")
assert(opened == 2 and refreshed == 2, "empty aliases must open settings")
commands.fs("scale 1.5")
assert(profile.scale == 1.5 and visibleScale == 1.5, "aliases must route subcommands")
print = originalPrint
print("Config regressions passed")
