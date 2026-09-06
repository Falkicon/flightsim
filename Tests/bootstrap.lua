-- Load FenCore and Flightsim's pure logic in WoW TOC order for offline tests.

_G.SlashCmdList = _G.SlashCmdList or {}
_G.C_Timer = _G.C_Timer or { After = function() end }
_G.LibStub = _G.LibStub or function()
	return nil
end

if not _G.FenCore then
	for _, path in ipairs({
		"Libs/FenCore/Core/FenCore.lua",
		"Libs/FenCore/Core/ActionResult.lua",
		"Libs/FenCore/Core/Catalog.lua",
		"Libs/FenCore/Domains/Math.lua",
		"Libs/FenCore/Domains/Secrets.lua",
		"Libs/FenCore/Domains/Progress.lua",
		"Libs/FenCore/Domains/Charges.lua",
		"Libs/FenCore/Domains/Cooldowns.lua",
		"Libs/FenCore/Domains/Color.lua",
		"Libs/FenCore/Domains/Time.lua",
		"Libs/FenCore/Domains/Text.lua",
	}) do
		dofile(path)
	end
end

if not _G.FlightsimLogic then
	for _, path in ipairs({
		"Logic/init.lua",
		"Logic/speed.lua",
		"Logic/acceleration.lua",
		"Logic/pitch.lua",
		"Logic/visibility.lua",
		"Logic/color.lua",
	}) do
		dofile(path)
	end
end

return _G.FenCore
