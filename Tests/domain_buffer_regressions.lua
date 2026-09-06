-- Offline shared-domain API, storage ownership, and allocation regressions.
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks = checks + 1
end
_G.SlashCmdList = {}
_G.C_Timer = { After = function() end }
_G.issecretvalue = function()
	return false
end
-- Also verifies the local library source before a future dependency sync.
local libraryRoot = os.getenv("FENCORE_ROOT") or "Libs/FenCore"
for _, path in ipairs({
	"Core/FenCore.lua",
	"Core/ActionResult.lua",
	"Core/Catalog.lua",
	"Domains/Math.lua",
	"Domains/Secrets.lua",
	"Domains/Charges.lua",
	"Domains/Cooldowns.lua",
}) do
	dofile(libraryRoot .. "/" .. path)
end
local Charges, Cooldowns = FenCore.Charges, FenCore.Cooldowns
local context = { currentCharges = 1, maxCharges = 3, chargeStart = 100, chargeDuration = 30, now = 115 }
local output = {}
local data = Charges.CalculateAllInto(context, output)
check(data == output and #data.charges == 3, "all charges writes caller storage")
check(data.charges[1].fill == 1 and data.charges[2].fill == 0.5 and data.charges[3].fill == 0, "charge fills")
check(data.anyRecharging and not data.allFull, "charge summary")
local first, second = data.charges[1], data.charges[2]
local snapshot = Charges.CalculateAll(context)
check(
	snapshot.success and snapshot.data ~= output and snapshot.data.charges[2] ~= second,
	"old API owns independent data"
)
context.currentCharges = 3
Charges.CalculateAllInto(context, output)
check(output.charges[1] == first and output.charges[2] == second, "nested buffers reused")
check(
	output.allFull and not output.anyRecharging and not second.isRecharging and second.fill == 1,
	"stale recharge cleared"
)
check(snapshot.data.charges[2].fill == 0.5 and not snapshot.data.allFull, "owned snapshot survives later calls")
context.maxCharges = 1
Charges.CalculateAllInto(context, output)
check(#output.charges == 1 and output.charges[2] == nil and output.charges[3] == nil, "shrink removes stale tail")
context.maxCharges = 4
Charges.CalculateAllInto(context, output)
check(#output.charges == 4 and output.charges[1] == first, "growth retains existing entries")
context.maxCharges = 0
Charges.CalculateAllInto(context, output)
check(#output.charges == 0 and not output.anyRecharging, "zero charges removes all entries")
local fill = {}
check(Charges.CalculateChargeFillInto(2, 1, 100, 30, 115, fill) == fill and fill.fill == 0.5, "single charge buffer")
Charges.CalculateChargeFillInto(2, 1, 0, 30, 115, fill)
check(fill.fill == 0 and not fill.isRecharging, "single charge clears previous recharge")
check(not Charges.CalculateChargeFill(nil, 1, 100, 30, 115).success, "old single validation preserved")
check(not Charges.CalculateAll(nil).success, "old all validation preserved")
local negative = Charges.CalculateChargeFill(2, 1, -10, 30, 0)
check(negative.success and negative.data.fill == 1 / 3, "old numeric semantics preserved")
local cooldown = {}
local coolContext = { startTime = 100, duration = 30, now = 115, enabled = false }
check(Cooldowns.CalculateInto(coolContext, cooldown) == cooldown, "full cooldown reuses buffer")
check(
	cooldown.progress == 0.5 and cooldown.remaining == 15 and cooldown.isOnCooldown and not cooldown.isEnabled,
	"cooldown active values"
)
local savedCooldown = Cooldowns.Calculate(coolContext)
Cooldowns.CalculateProgressInto(0, 0, 130, cooldown)
check(
	cooldown.progress == 1 and cooldown.remaining == 0 and not cooldown.isOnCooldown,
	"cooldown ready clears stale fields"
)
check(cooldown.isEnabled == nil, "progress clears full-state optional field")
check(
	savedCooldown.success and savedCooldown.data.remaining == 15 and not savedCooldown.data.isEnabled,
	"owned cooldown result retained"
)
Cooldowns.CalculateProgressInto(100, 30, 130, cooldown)
check(cooldown.progress == 1 and not cooldown.isOnCooldown, "elapsed cooldown ready")
Cooldowns.CalculateProgressInto(100, 30, 90, cooldown)
check(cooldown.progress == 0 and cooldown.remaining == 40 and cooldown.isOnCooldown, "future start clamps progress")
coolContext.enabled = nil
Cooldowns.CalculateInto(coolContext, cooldown)
check(cooldown.isEnabled, "missing enabled clears disabled state")
local secret = {}
_G.issecretvalue = function(value)
	return value == secret
end
coolContext.enabled = secret
Cooldowns.CalculateInto(coolContext, cooldown)
check(cooldown.isEnabled, "secret enabled assumed enabled")
check(
	not Cooldowns.CalculateProgress(nil, 30, 0).success and not Cooldowns.Calculate(nil).success,
	"old cooldown validation preserved"
)

-- Warm each independent caller buffer, stop GC, and measure growth. New tables in
-- these repeated normal calculations would accumulate rather than be collected.
context.maxCharges = 6
local surge, wind = {}, {}
local windContext = { currentCharges = 1, maxCharges = 3, chargeStart = 100, chargeDuration = 30, now = 115 }
Charges.CalculateAllInto(context, surge)
Charges.CalculateAllInto(windContext, wind)
Cooldowns.CalculateInto(coolContext, cooldown)
collectgarbage("collect")
collectgarbage("stop")
local before = collectgarbage("count")
for i = 1, 10000 do
	context.now = 115 + i % 10
	Charges.CalculateAllInto(context, surge)
	Charges.CalculateAllInto(windContext, wind)
	Cooldowns.CalculateInto(coolContext, cooldown)
end
local growth = collectgarbage("count") - before
collectgarbage("restart")
check(growth < 1, "warmed domain path allocated " .. tostring(growth) .. " KiB")
check(
	#surge.charges == 6 and #wind.charges == 3 and surge.charges[2] ~= wind.charges[2],
	"separate buffers preserve ability ownership"
)
-- Exercise both actual ability paths together: separate per-ability scratch storage
-- prevents six/three-charge alternation from reallocating a pruned shared array.
dofile("Logic/init.lua")
dofile("Logic/color.lua")
dofile("Bridge/init.lua")
dofile("Bridge/Executor.lua")
local Executor = FlightsimBridge.Executor
local ctx = {
	now = 115,
	deltaTime = 0.05,
	abilities = {
		surgeForward = { charges = { currentCharges = 1, chargeStart = 100, chargeDuration = 30 } },
		secondWind = { charges = { currentCharges = 0, chargeStart = 100, chargeDuration = 30 } },
		whirlingSurge = { cooldown = { startTime = 100, duration = 30 } },
	},
}
local surgeView = Executor.Charges(ctx, "surgeForward", 6)
local windView = Executor.Charges(ctx, "secondWind", 3)
Executor.Cooldown(ctx)
check(
	surgeView.states ~= windView.states and surgeView.states[1].targetPct == 1 and windView.states[1].targetPct == 0.5,
	"rendered states retain independent surge and wind values"
)
collectgarbage("collect")
collectgarbage("stop")
before = collectgarbage("count")
for _ = 1, 10000 do
	Executor.Charges(ctx, "surgeForward", 6)
	Executor.Charges(ctx, "secondWind", 3)
	Executor.Cooldown(ctx)
end
growth = collectgarbage("count") - before
collectgarbage("restart")
check(growth < 1, "warmed Executor ability path allocated " .. tostring(growth) .. " KiB")
check(surgeView == Executor.Charges(ctx, "surgeForward", 6), "Executor render output is borrowed storage")
ctx.abilities.surgeForward.charges.isSecret = true
ctx.abilities.surgeForward.isUsable = false
Executor.Charges(ctx, "surgeForward", 6)
check(
	surgeView.isSecret and surgeView.states[2].targetPct == 0 and surgeView.rechargingIndex == nil,
	"secret transition clears recharge values"
)
ctx.abilities.surgeForward.charges.isSecret = false
Executor.Charges(ctx, "surgeForward", 6)
check(
	not surgeView.isSecret and surgeView.states[2].displayPct == 0.5,
	"secret exit restores ordinary state without completion animation"
)
print("DOMAIN_BUFFER_REGRESSIONS:" .. checks)
