-- Run from the repository root: lua Tests/lifecycle_regressions.lua
-- Exercises the real Context, Events, and Executor across a representative flight lifecycle.
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks = checks + 1
end

local now = 100
local secret = {}
local mounted = true
local flying = false
local gliding = false
local canGlide = true
local forwardSpeed = 0
local rawSpeed = 7
local restricted = false
local surgeCharges = 5
local chargeStart = 100
local chargeDuration = 10
local cooldownStart = 99.1
local cooldownDuration = 10
local chargeCalls = 0
local cooldownCalls = 0
local eventFrame

_G.GetTime = function()
	return now
end
_G.issecretvalue = function(value)
	return value == secret
end
_G.wipe = function(tableToWipe)
	for key in pairs(tableToWipe) do
		tableToWipe[key] = nil
	end
	return tableToWipe
end
_G.UnitClass = function()
	return "Mage", "MAGE"
end
_G.IsMounted = function()
	return mounted
end
_G.IsFlying = function()
	return flying
end
_G.GetUnitSpeed = function()
	return restricted and secret or rawSpeed
end
_G.C_PlayerInfo = {
	GetGlidingInfo = function()
		return gliding, canGlide, forwardSpeed
	end,
}
_G.C_Map = {
	GetBestMapForUnit = function()
		return 2022
	end,
	GetMapInfo = function()
		return nil
	end,
}
_G.C_Spell = {
	GetSpellCharges = function(spellID)
		chargeCalls = chargeCalls + 1
		local currentCharges = spellID == 372608 and surgeCharges or 2
		return {
			currentCharges = restricted and secret or currentCharges,
			maxCharges = restricted and secret or (spellID == 372608 and 6 or 3),
			cooldownStartTime = restricted and secret or chargeStart,
			cooldownDuration = restricted and secret or chargeDuration,
		}
	end,
	GetSpellCooldown = function()
		cooldownCalls = cooldownCalls + 1
		return {
			startTime = restricted and secret or cooldownStart,
			duration = restricted and secret or cooldownDuration,
			isEnabled = restricted and secret or true,
		}
	end,
	IsSpellUsable = function()
		return restricted and secret or true
	end,
}
_G.C_UnitAuras = {
	GetAuraDataByIndex = function()
		return nil
	end,
}
_G.CreateFrame = function()
	eventFrame = { events = {} }
	function eventFrame:SetScript(name, callback)
		self[name] = callback
	end
	function eventFrame:RegisterEvent(name)
		self.events[name] = true
	end
	function eventFrame:RegisterUnitEvent(name)
		self.events[name] = true
	end
	function eventFrame:UnregisterAllEvents()
		self.events = {}
	end
	return eventFrame
end

dofile("Tests/bootstrap.lua")
for _, path in ipairs({
	"Bridge/init.lua",
	"Bridge/Context.lua",
	"Bridge/Events.lua",
	"Bridge/Executor.lua",
}) do
	dofile(path)
end

local Context = FlightsimBridge.Context
local Events = FlightsimBridge.Events
local Executor = FlightsimBridge.Executor
local db = {
	profile = {
		visibility = {
			hideWhenNotSkyriding = true,
			showWhenGroundMounted = true,
		},
		abilityBars = {
			showSurgeForward = true,
			showSecondWind = true,
			showWhirlingSurge = true,
		},
		speedBar = { maxSpeed = 950 },
	},
}
local dimensions = { accelBarWidth = 200, accelBarHeight = 4 }

Events.OnMount("executor-reset", Executor.ResetState)
Events.Init()

-- Login while already on a skyriding mount, but still on the ground.
eventFrame:OnEvent("PLAYER_ENTERING_WORLD")
local result = Executor.FullUpdate(db, dimensions)
check(result.success, "mounted login produces a successful update")
check(result.data.visibility.showHUD, "the ground-mounted profile setting is honored on login")
check(result.data.shouldUpdate, "a visible ground-mounted HUD is updated")
local cachedChargeCalls, cachedCooldownCalls = chargeCalls, cooldownCalls
now = 100.01
Executor.FullUpdate(db, dimensions)
check(chargeCalls == cachedChargeCalls, "charge values remain cached between lifecycle events")
check(cooldownCalls == cachedCooldownCalls, "cooldown values remain cached between lifecycle events")

-- Take flight and verify the mount event refreshes caches and resets animation history.
now = 100.1
flying = true
gliding = true
forwardSpeed = 30
eventFrame:OnEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
result = Executor.FullUpdate(db, dimensions)
check(result.data.visibility.showHUD, "the HUD remains visible after takeoff")
check(result.data.speed.isSecret == false, "public flight speed renders normally")
check(result.data.surgeForward.states[6].targetPct > 0, "the recovering charge reflects live progress")
check(chargeCalls == cachedChargeCalls + 2, "takeoff invalidates both charge cache entries")
check(cooldownCalls == cachedCooldownCalls + 1, "takeoff invalidates the cooldown cache")

-- Completing a charge between events starts the fill animation from its prior value.
now = 100.2
surgeCharges = 6
chargeStart = 0
chargeDuration = 0
eventFrame:OnEvent("SPELL_UPDATE_CHARGES")
result = Executor.FullUpdate(db, dimensions)
check(result.data.surgeForward.states[6].targetPct == 1, "charge completion reaches its full target")
check(result.data.surgeForward.states[6].displayPct < 1, "charge completion animates from the prior fill")

-- Combat restrictions invalidate cached public data and select secret-safe outputs.
now = 100.3
restricted = true
eventFrame:OnEvent("PLAYER_REGEN_DISABLED")
result = Executor.FullUpdate(db, dimensions)
check(result.data.visibility.showHUD, "combat restrictions do not lose flight visibility")
check(result.data.speed.isSecret, "restricted speed selects the secret display")
check(result.data.acceleration.shouldHide, "restricted speed clears and hides acceleration")
check(result.data.surgeForward.isSecret, "restricted charges select the binary charge display")
check(result.data.whirlingSurge.isSecret, "restricted cooldown selects the binary cooldown display")

-- Dismounting resets animation state and hides the HUD even while APIs remain restricted.
now = 100.4
mounted = false
flying = false
gliding = false
canGlide = false
forwardSpeed = 0
eventFrame:OnEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
result = Executor.FullUpdate(db, dimensions)
check(not result.data.visibility.showHUD, "dismount hides the HUD")
check(not result.data.shouldUpdate, "hidden lifecycle states skip component updates")

-- Leaving restrictions and remounting must rebuild public caches without stale animation.
now = 100.5
restricted = false
mounted = true
flying = true
gliding = true
canGlide = true
rawSpeed = 12
forwardSpeed = 35
surgeCharges = 6
cooldownStart = 0
cooldownDuration = 0
eventFrame:OnEvent("PLAYER_REGEN_ENABLED")
eventFrame:OnEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
result = Executor.FullUpdate(db, dimensions)
check(result.data.visibility.showHUD, "public recovery restores flight visibility")
check(result.data.speed.isSecret == false, "public recovery restores numeric speed")
check(result.data.surgeForward.isSecret == false, "public recovery restores numeric charges")
check(result.data.surgeForward.states[6].displayPct == 1, "remount reset prevents stale charge animation")
check(result.data.whirlingSurge.isSecret == false, "public recovery restores numeric cooldowns")

-- A profile update is consumed directly by the next real executor pass.
db.profile.abilityBars.showSecondWind = false
now = 100.6
result = Executor.FullUpdate(db, dimensions)
check(not result.data.visibility.showSecondWind, "profile ability visibility applies on the next update")

-- The cache remains usable after all transitions.
cachedChargeCalls, cachedCooldownCalls = chargeCalls, cooldownCalls
now = 100.61
Executor.FullUpdate(db, dimensions)
check(chargeCalls == cachedChargeCalls, "recovered charge cache is stable")
check(cooldownCalls == cachedCooldownCalls, "recovered cooldown cache is stable")

print("Lifecycle regressions: " .. checks .. " checks passed")
