-- Run from the repository root: lua Tests/bridge_regressions.lua
-- These mocks exercise adapter and animation behavior, not WoW's secret VM.
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks = checks + 1
end

local now = 100
local secret = {}
_G.SlashCmdList = {}
_G.C_Timer = { After = function() end }
_G.issecretvalue = function(value)
	return value == secret
end
_G.GetTime = function()
	return now
end
_G.UnitClass = function()
	return "Mage", "MAGE"
end
_G.IsMounted = function()
	return true
end
_G.IsFlying = function()
	return true
end
_G.GetUnitSpeed = function()
	return 10
end
_G.wipe = function(t)
	for key in pairs(t) do
		t[key] = nil
	end
	return t
end
local gliding, canGlide, forwardSpeed = false, false, 0
_G.C_PlayerInfo = {
	GetGlidingInfo = function()
		return gliding, canGlide, forwardSpeed
	end,
}
local charges, cooldown, usable
local chargeCalls, cooldownCalls = 0, 0
_G.C_Spell = {
	GetSpellCharges = function()
		chargeCalls = chargeCalls + 1
		return charges
	end,
	GetSpellCooldown = function()
		cooldownCalls = cooldownCalls + 1
		return cooldown
	end,
	IsSpellUsable = function()
		return usable
	end,
}
local auras = {}
_G.C_UnitAuras = {
	GetAuraDataByIndex = function(_, index)
		return auras[index]
	end,
}
local eventFrame
_G.CreateFrame = function()
	eventFrame = { events = {} }
	function eventFrame:SetScript(name, callback)
		self[name] = callback
	end
	function eventFrame:RegisterEvent(name)
		self.events[name] = true
	end
	eventFrame.RegisterUnitEvent = eventFrame.RegisterEvent
	return eventFrame
end

for _, path in ipairs({
	"Libs/FenCore/Core/FenCore.lua",
	"Libs/FenCore/Core/ActionResult.lua",
	"Libs/FenCore/Core/Catalog.lua",
	"Libs/FenCore/Domains/Math.lua",
	"Libs/FenCore/Domains/Secrets.lua",
	"Libs/FenCore/Domains/Charges.lua",
	"Libs/FenCore/Domains/Cooldowns.lua",
	"Logic/init.lua",
	"Logic/speed.lua",
	"Logic/acceleration.lua",
	"Logic/visibility.lua",
	"Logic/color.lua",
	"Bridge/init.lua",
	"Bridge/Context.lua",
	"Bridge/Events.lua",
	"Bridge/Executor.lua",
}) do
	dofile(path)
end
local Context = FlightsimBridge.Context
local Executor = FlightsimBridge.Executor

-- Zero speed is truthy in Lua: reading speed as canGlide falsely shows the HUD.
check(not Context.IsSkyridingActive(true), "steady flight must not treat zero speed as canGlide")
canGlide = true
check(Context.IsSkyridingActive(true), "stationary skyriding reads the second API return")
canGlide = false
charges = { currentCharges = 6, maxCharges = 6, cooldownStartTime = 0, cooldownDuration = 0 }
check(Context.IsSkyridingActive(true), "charge fallback remains available when gliding info is false")

for _, field in ipairs({ "currentCharges", "maxCharges", "cooldownStartTime", "cooldownDuration" }) do
	Context.InvalidateSpellCache()
	charges = { currentCharges = 3, maxCharges = 6, cooldownStartTime = 90, cooldownDuration = 10 }
	charges[field] = secret
	check(Context.GetSpellCharges(372608).isSecret, "secret charge field must be detected: " .. field)
	check(Context.GetSpellCharges(372608).isSecret, "cached charge secrecy must persist: " .. field)
end
usable = secret
check(not Context.IsSpellUsable(372608), "secret usability must not escape as a branch condition")
usable = true
check(Context.IsSpellUsable(372608), "public usability remains available")

charges = { currentCharges = 3, maxCharges = 6, cooldownStartTime = 90, cooldownDuration = 10 }
cooldown = { startTime = 90, duration = 30, isEnabled = true }
auras = { { spellId = 377234, name = "Frisson des cieux" } }
FlightsimBridge.Events.Init()
check(Context.GetChargeRecoveryBuffs(), "buff cache is seeded at initialization")
local events = {
	"SPELL_UPDATE_COOLDOWN",
	"SPELL_UPDATE_CHARGES",
	"SPELLS_CHANGED",
	"PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED",
	"PLAYER_MOUNT_DISPLAY_CHANGED",
	"UPDATE_SHAPESHIFT_FORM",
	"UPDATE_SHAPESHIFT_FORMS",
	"PLAYER_ENTERING_WORLD",
	"ZONE_CHANGED_NEW_AREA",
}
for _, event in ipairs(events) do
	check(eventFrame.events[event], "cache invalidation event must be registered: " .. event)
	Context.GetSpellCharges(372608)
	Context.GetSpellCooldown(361584)
	local oldCharges, oldCooldowns = chargeCalls, cooldownCalls
	Context.GetSpellCharges(372608)
	Context.GetSpellCooldown(361584)
	check(chargeCalls == oldCharges and cooldownCalls == oldCooldowns, "repeated reads use caches")
	eventFrame:OnEvent(event)
	Context.GetSpellCharges(372608)
	Context.GetSpellCooldown(361584)
	check(chargeCalls == oldCharges + 1 and cooldownCalls == oldCooldowns + 1, "event refreshes both caches: " .. event)
end
auras = { { spellId = secret, name = "Thrill of the Skies" }, { spellId = 404184, name = secret } }
eventFrame:OnEvent("PLAYER_ENTERING_WORLD")
local thrill, skim = Context.GetChargeRecoveryBuffs()
check(not thrill and skim, "world entry skips secret IDs and recognizes public IDs with secret names")
auras = { { spellId = 404183, name = "Ground Skimming" }, { spellId = 1, name = "Thrill of the Skies" } }
Context.UpdateBuffs()
thrill, skim = Context.GetChargeRecoveryBuffs()
check(not thrill and not skim, "passive talents and English names cannot impersonate active recovery auras")

local ctx = {
	now = 100,
	deltaTime = 0.01,
	abilities = {
		surgeForward = { charges = { currentCharges = 0, chargeStart = 0, chargeDuration = 0 }, isUsable = true },
		whirlingSurge = { cooldown = { startTime = 99, duration = 10 } },
	},
}
Executor.ResetState()
local charge = ctx.abilities.surgeForward.charges
Executor.Charges(ctx, "surgeForward", 1)
charge.currentCharges = 1
local out = Executor.Charges(ctx, "surgeForward", 1)
check(out.states[1].displayPct < 1, "newly recovered charge animates")
charge.currentCharges = 0
out = Executor.Charges(ctx, "surgeForward", 1)
check(out.states[1].displayPct == 0, "spending a charge cancels its completion animation")
charge.isSecret = true
Executor.Charges(ctx, "surgeForward", 1)
charge.isSecret = false
charge.currentCharges = 1
check(
	Executor.Charges(ctx, "surgeForward", 1).states[1].displayPct == 1,
	"leaving secrets starts at actual charge state"
)

Executor.ResetState()
out = Executor.Cooldown(ctx)
check(math.abs(out.displayValue - 0.1) < 0.0001, "cooldown initially reflects elapsed time")
ctx.abilities.whirlingSurge.cooldown.startTime = 0
out = Executor.Cooldown(ctx)
check(out.displayValue > 0.1, "ready animation starts at the last displayed cooldown value")
ctx.abilities.whirlingSurge.cooldown.startTime = 100
out = Executor.Cooldown(ctx)
check(out.displayValue == 0 and out.onCooldown, "new cooldown cancels old ready animation")

Executor.ResetState()
ctx.player = { isSpeedSecret = false }
Executor.Acceleration(ctx, 200, 4, 100)
ctx.player.isSpeedSecret = true
check(Executor.Acceleration(ctx, 200, 4, 0).shouldHide, "secret speed hides acceleration")
ctx.player.isSpeedSecret = false
check(Executor.Acceleration(ctx, 200, 4, 900).isStable, "public speed restarts acceleration without a stale delta")

-- The shelved pitch bar must not query unused positions in the frame hot path.
local positionCalls = 0
_G.UnitPosition = function()
	positionCalls = positionCalls + 1
	return 10, 20
end
local built = Context.Build({}, nil)
check(
	positionCalls == 0 and built.player.posX == nil and built.player.posY == nil,
	"disabled pitch does not sample position"
)

-- Marker commands must reach the renderer without disabling zone-aware defaults.
local speedSettings = { maxSpeed = 2000, sustainableSpeed = 0, useCustomSustainableSpeed = true }
built.db = { profile = { speedBar = speedSettings } }
check(not Executor.Speed(built).showMarker, "explicit zero marker setting hides the rendered marker")
speedSettings.sustainableSpeed = 500
check(math.abs(Executor.Speed(built).markerPct - 0.25) < 0.0001, "custom marker setting reaches speed output")
speedSettings.useCustomSustainableSpeed = false
check(
	math.abs(Executor.Speed(built).markerPct - (929 * built.zone.zoneModifier / 2000)) < 0.0001,
	"switching away from a custom marker clears the reusable override input"
)
print("Bridge regressions: " .. checks .. " checks passed")
