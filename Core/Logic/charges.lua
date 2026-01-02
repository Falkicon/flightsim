-- Flightsim Core Charge Logic
-- Pure Lua 5.1 - No WoW dependencies
-- Charge state calculations for abilities like Surge Forward and Second Wind

local Core = FlightsimCore
local Actions = Core.Actions
local Math = Core.Utils.Math

---@class ChargesLogic
local Charges = {}

-- Constants
Charges.ANIM_SPEED = 3.0 -- Animation speed multiplier

---@class ChargeState
---@field index number Charge index (1-based)
---@field targetPct number Target fill percentage (0-1)
---@field isRecharging boolean Whether this charge is currently recharging
---@field isFull boolean Whether this charge is fully charged

--- Calculate the fill percentage for a single charge.
---@param chargeIndex number 1-based charge index
---@param currentCharges number Current number of charges
---@param chargeStart number Start time of current recharge
---@param chargeDuration number Duration of one charge cycle
---@param now number Current time (GetTime())
---@return ActionResult<ChargeState>
function Charges.CalculateChargeFill(chargeIndex, currentCharges, chargeStart, chargeDuration, now)
	if chargeIndex == nil or chargeIndex < 1 then
		return Actions.error("INVALID_INPUT", "chargeIndex must be >= 1")
	end

	currentCharges = currentCharges or 0
	chargeStart = chargeStart or 0
	chargeDuration = chargeDuration or 0
	now = now or 0

	local targetPct = 0
	local isRecharging = false
	local isFull = false

	if chargeIndex <= currentCharges then
		-- This charge is fully available
		targetPct = 1
		isFull = true
	elseif chargeIndex == currentCharges + 1 and chargeDuration > 0 then
		-- This charge is currently recharging
		local elapsed = now - chargeStart
		targetPct = Math.Clamp(elapsed / chargeDuration, 0, 1)
		isRecharging = true
	else
		-- This charge is not yet recharging
		targetPct = 0
	end

	return Actions.success({
		index = chargeIndex,
		targetPct = targetPct,
		isRecharging = isRecharging,
		isFull = isFull,
	})
end

--- Check if animation should trigger (charge just became full).
---@param currentTarget number Current fill target (0-1)
---@param previousTarget number Previous fill target (0-1)
---@return boolean shouldAnimate
function Charges.ShouldAnimateFill(currentTarget, previousTarget)
	currentTarget = currentTarget or 0
	previousTarget = previousTarget or 0

	-- Trigger animation when transitioning from < 1 to >= 1
	return currentTarget >= 1 and previousTarget < 1
end

--- Advance animation value for a charge.
---@param currentValue number Current animation value (0-1)
---@param deltaTime number Time since last frame
---@param animSpeed? number Animation speed (default 3.0)
---@return ActionResult<{value: number, isComplete: boolean}>
function Charges.AdvanceAnimation(currentValue, deltaTime, animSpeed)
	currentValue = currentValue or 0
	deltaTime = deltaTime or 0
	animSpeed = animSpeed or Charges.ANIM_SPEED

	local newValue = currentValue + deltaTime * animSpeed
	local isComplete = false

	if newValue >= 1 then
		newValue = 1
		isComplete = true
	end

	return Actions.success({
		value = newValue,
		isComplete = isComplete,
	})
end

--- Calculate all charge states for a multi-charge ability.
---@param context table {currentCharges, maxCharges, chargeStart, chargeDuration, now, previousTargets}
---@return ActionResult<{states: ChargeState[], allFull: boolean, rechargingIndex: number|nil}>
function Charges.CalculateAllCharges(context)
	if not context then
		return Actions.error("INVALID_INPUT", "context is required")
	end

	local currentCharges = context.currentCharges or 0
	local maxCharges = context.maxCharges or 6
	local chargeStart = context.chargeStart or 0
	local chargeDuration = context.chargeDuration or 0
	local now = context.now or 0
	local previousTargets = context.previousTargets or {}

	local states = {}
	local allFull = true
	local rechargingIndex = nil

	for i = 1, maxCharges do
		local result = Charges.CalculateChargeFill(i, currentCharges, chargeStart, chargeDuration, now)
		local state = Actions.unwrap(result)

		-- Check if should animate
		local prevTarget = previousTargets[i] or 0
		state.shouldAnimate = Charges.ShouldAnimateFill(state.targetPct, prevTarget)

		states[i] = state

		if not state.isFull then
			allFull = false
		end
		if state.isRecharging then
			rechargingIndex = i
		end
	end

	return Actions.success({
		states = states,
		allFull = allFull,
		rechargingIndex = rechargingIndex,
	})
end

--- Handle secret value fallback (Midnight combat mode).
--- When charges are secret, we use spell usability as a binary proxy.
---@param isUsable boolean Whether the spell is currently usable
---@param maxCharges number Maximum charges
---@return ActionResult<{states: ChargeState[], isSecret: boolean}>
function Charges.HandleSecretFallback(isUsable, maxCharges)
	maxCharges = maxCharges or 6
	local fillValue = isUsable and 1 or 0

	local states = {}
	for i = 1, maxCharges do
		states[i] = {
			index = i,
			targetPct = fillValue,
			isRecharging = false,
			isFull = isUsable,
			isSecret = true,
		}
	end

	return Actions.success({
		states = states,
		isSecret = true,
	})
end

Core.Logic.Charges = Charges
return Charges
