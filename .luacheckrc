-- Flightsim Luacheck configuration.
-- Keep this file self-contained so linting works from a standalone checkout.

std = "lua51"
max_line_length = false
codes = true
quiet = 1

-- Third-party libraries and offline specs have their own contracts.
exclude_files = {
	"Libs/",
	"Tests/",
	".luacheckrc",
}

-- Globals owned and written by the addon.
globals = {
	"Flightsim",
	"FlightsimDB",
	"FlightsimLogic",
	"FlightsimBridge",
	"FlightsimView",
	"FlightsimConfig",
	"SlashCmdList",
	"SLASH_FLIGHTSIM1",
}

-- WoW APIs read by the addon. Keep the list explicit so a misspelled API is
-- still reported as a lint error.
read_globals = {
	"C_AddOns",
	"C_Map",
	"C_PlayerInfo",
	"C_Spell",
	"C_Timer",
	"C_UnitAuras",
	"CreateFrame",
	"GetLocale",
	"GetTime",
	"GetUnitSpeed",
	"UnitSpeed",
	"GetZoneText",
	"GetShapeshiftForm",
	"InCombatLockdown",
	"IsFlying",
	"IsMounted",
	"LibStub",
	"UIParent",
	"UnitClass",
	"UnitPosition",
	"debugprofilestop",
	"format",
	"issecretvalue",
	"print",
	"strtrim",
	"wipe",
}

-- StyLua handles long lines and the addon uses a few intentional callback
-- signatures where an argument is required by WoW but unused locally.
ignore = {
	"212/_.*",
	"212/self",
	"631",
}

