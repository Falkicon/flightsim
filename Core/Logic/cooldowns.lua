-- Flightsim Core Cooldown Logic
-- Pure Lua 5.1 - No WoW dependencies
-- Cooldown progress calculations for abilities like Whirling Surge

local Core = FlightsimCore
local Actions = Core.Actions
local Math = Core.Utils.Math

---@class CooldownsLogic
local Cooldowns = {}

-- Constants
Cooldowns.ANIM_SPEED = 3.0 -- Animation speed multiplier
Cooldowns.MIN_CD_THRESHOLD = 1.5 -- Minimum duration to consider "on cooldown"

---@class CooldownState
---@field progress number Cooldown progress (0-1), 1 = ready
---@field onCooldown boolean Whether ability is on cooldown
---@field remaining number Remaining cooldown time
---@field isReady boolean Whether ability is ready to use

--- Calculate cooldown progress.
---@param startTime number When the cooldown started
---@param duration number Total cooldown duration
---@param now number Current time (GetTime())
---@return ActionResult<CooldownState>
function Cooldowns.CalculateProgress(startTime, duration, now)
	startTime = startTime or 0
	duration = duration or 0
	now = now or 0

	-- Check if actually on cooldown
	local onCooldown = duration > Cooldowns.MIN_CD_THRESHOLD
	local progress = 1
	local remaining = 0
	local isReady = true

	if onCooldown then
		local elapsed = now - startTime
		progress = Math.Clamp(elapsed / duration, 0, 1)
		remaining = math.max(0, duration - elapsed)
		isReady = progress >= 1
	end

	return Actions.success({
		progress = progress,
		onCooldown = onCooldown,
		remaining = remaining,
		isReady = isReady,
	})
end

--- Check if ready animation should trigger.
--- Triggers when cooldown ends (was on CD, now ready).
---@param wasReady boolean Previous ready state
---@param isReady boolean Current ready state
---@param currentAnimValue number Current animation value (0-1)
---@return boolean shouldAnimate
function Cooldowns.ShouldAnimateReady(wasReady, isReady, currentAnimValue)
	wasReady = wasReady or false
	isReady = isReady or false
	currentAnimValue = currentAnimValue or 0

	-- Trigger when transitioning to ready and animation not complete
	return isReady and not wasReady and currentAnimValue < 1
end

--- Advance animation value.
---@param currentValue number Current animation value (0-1)
---@param deltaTime number Time since last frame
---@param animSpeed? number Animation speed (default 3.0)
---@return ActionResult<{value: number, isComplete: boolean}>
function Cooldowns.AdvanceAnimation(currentValue, deltaTime, animSpeed)
	currentValue = currentValue or 0
	deltaTime = deltaTime or 0
	animSpeed = animSpeed or Cooldowns.ANIM_SPEED

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

--- Full cooldown bar calculation.
---@param context table {startTime, duration, now, wasReady, animating, animValue, deltaTime}
---@return ActionResult<CooldownBarState>
function Cooldowns.Calculate(context)
	if not context then
		return Actions.error("INVALID_INPUT", "context is required")
	end

	local startTime = context.startTime or 0
	local duration = context.duration or 0
	local now = context.now or 0
	local wasReady = context.wasReady or false
	local animating = context.animating or false
	local animValue = context.animValue or 0
	local deltaTime = context.deltaTime or 0

	-- Calculate progress
	local progressResult = Cooldowns.CalculateProgress(startTime, duration, now)
	local state = Actions.unwrap(progressResult)

	-- Determine if animation should start
	local shouldAnimate = Cooldowns.ShouldAnimateReady(wasReady, state.isReady, animValue)
	if shouldAnimate then
		animating = true
		animValue = 0
	end

	-- Reset animation when going on cooldown
	if state.onCooldown and wasReady then
		animating = false
		animValue = 0
	end

	-- Advance animation if active
	local displayValue = state.progress
	if animating then
		local animResult = Cooldowns.AdvanceAnimation(animValue, deltaTime)
		local animData = Actions.unwrap(animResult)
		animValue = animData.value
		displayValue = animValue
		if animData.isComplete then
			animating = false
		end
	elseif state.isReady then
		displayValue = 1
	end

	return Actions.success({
		progress = state.progress,
		onCooldown = state.onCooldown,
		remaining = state.remaining,
		isReady = state.isReady,
		displayValue = displayValue,
		animating = animating,
		animValue = animValue,
	})
end

--- Handle secret value fallback (Midnight combat mode).
---@param isUsable boolean Whether the spell is currently usable
---@return ActionResult<{displayValue: number, isSecret: boolean}>
function Cooldowns.HandleSecretFallback(isUsable)
	return Actions.success({
		displayValue = isUsable and 1 or 0,
		isSecret = true,
		isReady = isUsable,
	})
end

Core.Logic.Cooldowns = Cooldowns
return Cooldowns
