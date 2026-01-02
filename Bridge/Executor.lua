-- Flightsim Bridge: Executor
-- Orchestrates Core logic execution with WoW context
-- AFD pattern: Bridge:Execute(action, context) -> ActionResult

local Bridge = FlightsimBridge
local Context = Bridge.Context
local Secrets = Bridge.Secrets
local Core = FlightsimCore
local Actions = Core.Actions

---@class ExecutorModule
local Executor = {}

-- Frame state cache (persists between updates)
local frameState = {
	lastFrameTime = nil,
	lastSpeedPct = nil,
	smoothDelta = 0,
	sessionMaxSpeed = nil,

	-- Surge Forward animation state
	surgeTargets = {},
	surgeAnimating = {},
	surgeAnimValues = {},

	-- Second Wind animation state
	windTargets = {},
	windAnimating = {},
	windAnimValues = {},

	-- Whirling Surge animation state
	whirlWasReady = false,
	whirlAnimating = false,
	whirlAnimValue = 0,
}

--- Reset frame state (on mount/dismount).
function Executor.ResetState()
	frameState.lastSpeedPct = nil
	frameState.smoothDelta = 0
	frameState.sessionMaxSpeed = nil
	frameState.surgeTargets = {}
	frameState.surgeAnimating = {}
	frameState.surgeAnimValues = {}
	frameState.windTargets = {}
	frameState.windAnimating = {}
	frameState.windAnimValues = {}
	frameState.whirlWasReady = false
	frameState.whirlAnimating = false
	frameState.whirlAnimValue = 0
end

--- Execute speed bar calculation.
---@param ctx FlightsimContext Current context
---@return ActionResult<SpeedBarData>
function Executor.Speed(ctx)
	if ctx.player.isSpeedSecret then
		return Actions.success({
			isSecret = true,
			displayText = "???",
			barColor = { 0.5, 0.5, 0.5 },
		})
	end

	local db = ctx.db or {}
	local profile = db.profile or {}
	local speedBar = profile.speedBar or {}

	-- Calculate speed
	local speedResult = Core.Logic.Speed.Calculate({
		rawSpeed = ctx.player.speed or 0,
		isSlowZone = ctx.zone.isSlowSkyriding,
		configuredMax = speedBar.maxSpeed or 950,
		sessionMax = frameState.sessionMaxSpeed,
		sustainableSpeed = speedBar.sustainableSpeed or speedBar.optimalSpeed or 0,
	})

	if not speedResult.success then
		return speedResult
	end

	local data = Actions.unwrap(speedResult)

	-- Update session max if skyriding
	if ctx.player.isSkyriding then
		local currentMax = frameState.sessionMaxSpeed or 0
		if data.speedPct > currentMax then
			frameState.sessionMaxSpeed = data.speedPct
		end
	else
		frameState.sessionMaxSpeed = nil
	end

	-- Get color
	local r, g, b = Core.Utils.Color.ForSpeed(data.fillPct)

	-- Format display text
	local showPercent = speedBar.showPercent ~= false
	local displayText
	if showPercent then
		displayText = string.format("%.0f%%", data.speedPct)
	else
		displayText = string.format("%.1f", data.rawSpeed)
	end

	return Actions.success({
		isSecret = false,
		speedPct = data.speedPct,
		fillPct = data.fillPct,
		displayText = displayText,
		barColor = { r, g, b },
		markerPct = data.markerPct,
		showMarker = data.showMarker,
	})
end

--- Execute acceleration bar calculation.
---@param ctx FlightsimContext Current context
---@param barWidth number Bar width in pixels
---@param barHeight number Bar height in pixels
---@return ActionResult<AccelBarData>
function Executor.Acceleration(ctx, barWidth, barHeight)
	if ctx.player.isSpeedSecret then
		return Actions.success({
			isSecret = true,
			shouldHide = true,
		})
	end

	-- Get current speed percentage
	local speedResult = Executor.Speed(ctx)
	if not speedResult.success then
		return Actions.success({ shouldHide = true })
	end

	local speedPct = Actions.unwrap(speedResult).speedPct or 0

	-- Calculate acceleration
	local accelResult = Core.Logic.Acceleration.Calculate({
		currentSpeed = speedPct,
		lastSpeed = frameState.lastSpeedPct,
		previousSmooth = frameState.smoothDelta,
		barWidth = barWidth or 200,
		barHeight = barHeight or 4,
	})

	if not accelResult.success then
		return Actions.success({ shouldHide = true })
	end

	local data = Actions.unwrap(accelResult)

	-- Update state
	frameState.lastSpeedPct = speedPct
	frameState.smoothDelta = data.smoothDelta

	return Actions.success({
		isSecret = false,
		shouldHide = false,
		width = data.barWidth,
		anchorSide = data.anchorSide,
		offsetX = data.offsetX,
		isStable = data.isStable,
		direction = data.direction,
	})
end

--- Execute charge bar calculation (Surge Forward or Second Wind).
---@param ctx FlightsimContext Current context
---@param abilityKey string "surgeForward" or "secondWind"
---@param maxCharges number Maximum charges
---@return ActionResult<ChargeBarData>
function Executor.Charges(ctx, abilityKey, maxCharges)
	local abilityData = ctx.abilities[abilityKey]
	if not abilityData then
		return Actions.error("INVALID_ABILITY", "Unknown ability: " .. tostring(abilityKey))
	end

	local charges = abilityData.charges
	local isUsable = abilityData.isUsable

	-- Handle secret values
	if charges.isSecret then
		local secretResult = Core.Logic.Charges.HandleSecretFallback(isUsable, maxCharges)
		return secretResult
	end

	-- Get animation state tables for this ability
	local targets, animating, animValues
	if abilityKey == "surgeForward" then
		targets = frameState.surgeTargets
		animating = frameState.surgeAnimating
		animValues = frameState.surgeAnimValues
	else
		targets = frameState.windTargets
		animating = frameState.windAnimating
		animValues = frameState.windAnimValues
	end

	-- Calculate charge states
	local chargeResult = Core.Logic.Charges.CalculateAllCharges({
		currentCharges = charges.currentCharges,
		maxCharges = maxCharges,
		chargeStart = charges.chargeStart,
		chargeDuration = charges.chargeDuration,
		now = ctx.now,
		previousTargets = targets,
	})

	if not chargeResult.success then
		return chargeResult
	end

	local data = Actions.unwrap(chargeResult)

	-- Update animation state and calculate display values
	local displayStates = {}
	for i, state in ipairs(data.states) do
		local displayPct = state.targetPct

		-- Check if animation should trigger
		if state.shouldAnimate and not animating[i] then
			animating[i] = true
			animValues[i] = 0
		end

		-- Advance animation
		if animating[i] then
			local animResult = Core.Logic.Charges.AdvanceAnimation(animValues[i] or 0, ctx.deltaTime)
			local animData = Actions.unwrap(animResult)
			animValues[i] = animData.value
			displayPct = animData.value
			if animData.isComplete then
				animating[i] = false
			end
		end

		-- Update targets for next frame
		targets[i] = state.targetPct

		displayStates[i] = {
			index = i,
			displayPct = displayPct,
			targetPct = state.targetPct,
			isRecharging = state.isRecharging,
			isFull = state.isFull,
		}
	end

	return Actions.success({
		isSecret = false,
		states = displayStates,
		allFull = data.allFull,
		rechargingIndex = data.rechargingIndex,
	})
end

--- Execute cooldown bar calculation (Whirling Surge).
---@param ctx FlightsimContext Current context
---@return ActionResult<CooldownBarData>
function Executor.Cooldown(ctx)
	local abilityData = ctx.abilities.whirlingSurge
	if not abilityData then
		return Actions.error("INVALID_ABILITY", "Whirling Surge data not found")
	end

	local cooldown = abilityData.cooldown
	local isUsable = abilityData.isUsable

	-- Handle secret values
	if cooldown.isSecret then
		local secretResult = Core.Logic.Cooldowns.HandleSecretFallback(isUsable)
		return secretResult
	end

	-- Calculate cooldown state
	local cdResult = Core.Logic.Cooldowns.Calculate({
		startTime = cooldown.startTime,
		duration = cooldown.duration,
		now = ctx.now,
		wasReady = frameState.whirlWasReady,
		animating = frameState.whirlAnimating,
		animValue = frameState.whirlAnimValue,
		deltaTime = ctx.deltaTime,
	})

	if not cdResult.success then
		return cdResult
	end

	local data = Actions.unwrap(cdResult)

	-- Update state
	frameState.whirlWasReady = data.isReady
	frameState.whirlAnimating = data.animating
	frameState.whirlAnimValue = data.animValue

	-- Get color
	local r, g, b = Core.Utils.Color.ForWhirlingSurge(data.displayValue)

	return Actions.success({
		isSecret = false,
		displayValue = data.displayValue,
		isReady = data.isReady,
		onCooldown = data.onCooldown,
		remaining = data.remaining,
		barColor = { r, g, b },
	})
end

--- Execute visibility calculation.
---@param ctx FlightsimContext Current context
---@return ActionResult<VisibilityData>
function Executor.Visibility(ctx)
	local db = ctx.db or {}
	local profile = db.profile or {}

	return Core.Logic.Visibility.Calculate({
		visibility = profile.visibility or {},
		abilityBars = profile.abilityBars or {},
		playerState = {
			isSkyriding = ctx.player.isSkyriding,
			isMounted = ctx.player.isMounted,
			isDruidFlying = ctx.player.isDruidFlying,
		},
	})
end

--- Execute full frame update.
--- Returns all calculated state for rendering.
---@param db table SavedVariables database
---@param barDimensions table {speedBarWidth, accelBarWidth, accelBarHeight}
---@return ActionResult<FrameUpdateData>
function Executor.FullUpdate(db, barDimensions)
	barDimensions = barDimensions or {}

	-- Build context
	local ctx = Context.Build(db, frameState.lastFrameTime)
	frameState.lastFrameTime = ctx.now

	-- Calculate visibility first
	local visResult = Executor.Visibility(ctx)
	if not visResult.success then
		return visResult
	end
	local visibility = Actions.unwrap(visResult)

	-- If HUD is hidden, return early
	if not visibility.showHUD then
		return Actions.success({
			visibility = visibility,
			shouldUpdate = false,
		})
	end

	-- Calculate all components
	local speedData = Actions.unwrap(Executor.Speed(ctx))
	local accelData = Actions.unwrap(
		Executor.Acceleration(ctx, barDimensions.accelBarWidth or 200, barDimensions.accelBarHeight or 4)
	)

	local surgeData = visibility.showSurgeForward and Actions.unwrap(Executor.Charges(ctx, "surgeForward", 6)) or nil

	local windData = visibility.showSecondWind and Actions.unwrap(Executor.Charges(ctx, "secondWind", 3)) or nil

	local whirlData = visibility.showWhirlingSurge and Actions.unwrap(Executor.Cooldown(ctx)) or nil

	return Actions.success({
		visibility = visibility,
		shouldUpdate = true,
		speed = speedData,
		acceleration = accelData,
		surgeForward = surgeData,
		secondWind = windData,
		whirlingSurge = whirlData,
		context = ctx,
	})
end

Bridge.Executor = Executor
return Executor
