-- Flightsim Bridge: Executor
-- Orchestrates FenCore + FlightsimLogic execution with WoW context
-- AFD pattern: Bridge:Execute(action, context) -> ActionResult

local Bridge = FlightsimBridge
local Context = Bridge.Context
local FenCore = _G.FenCore
local Secrets = FenCore.Secrets
local Logic = FlightsimLogic
local Result = FenCore.ActionResult

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
	whirlFirstFrame = true,
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
	frameState.whirlFirstFrame = true
end

--- Execute speed bar calculation.
---@param ctx FlightsimContext Current context
---@return ActionResult<SpeedBarData>
function Executor.Speed(ctx)
	if ctx.player.isSpeedSecret then
		return Result.success({
			isSecret = true,
			displayText = "???",
			barColor = { 0.5, 0.5, 0.5 },
		})
	end

	local db = ctx.db or {}
	local profile = db.profile or {}
	local speedBar = profile.speedBar or {}

	-- Calculate speed
	local speedResult = Logic.Speed.Calculate({
		rawSpeed = ctx.player.speed or 0,
		zoneModifier = ctx.zone.zoneModifier,
		configuredMax = speedBar.maxSpeed or 950,
		sessionMax = frameState.sessionMaxSpeed,
	})

	if not speedResult.success then
		return speedResult
	end

	local data = Result.unwrap(speedResult)

	-- Update session max if skyriding
	if ctx.player.isSkyriding then
		local currentMax = frameState.sessionMaxSpeed or 0
		if data.speedPct > currentMax then
			frameState.sessionMaxSpeed = data.speedPct
		end
	else
		frameState.sessionMaxSpeed = nil
	end

	-- Get color (check for custom gradient)
	local r, g, b
	local colors = profile.colors or {}
	local speedBarColors = colors.speedBar or {}

	if speedBarColors.useCustom and speedBarColors.gradient then
		-- Use custom gradient colors
		local grad = speedBarColors.gradient
		local pct = data.fillPct or 0
		if pct < 0 then pct = 0 end
		if pct > 1 then pct = 1 end

		if pct < 0.5 then
			-- start -> middle (0% to 50%)
			local t = pct * 2
			local c1 = grad.start or { r = 0.769, g = 0.169, b = 0.016 }
			local c2 = grad.middle or { r = 0.769, g = 0.651, b = 0.016 }
			r = c1.r + (c2.r - c1.r) * t
			g = c1.g + (c2.g - c1.g) * t
			b = c1.b + (c2.b - c1.b) * t
		else
			-- middle -> finish (50% to 100%)
			local t = (pct - 0.5) * 2
			local c1 = grad.middle or { r = 0.769, g = 0.651, b = 0.016 }
			local c2 = grad.finish or { r = 0.169, g = 0.651, b = 0.016 }
			r = c1.r + (c2.r - c1.r) * t
			g = c1.g + (c2.g - c1.g) * t
			b = c1.b + (c2.b - c1.b) * t
		end
	else
		-- Use default colors
		r, g, b = Logic.Color.ForSpeed(data.fillPct)
	end

	-- Format display text
	local showPercent = speedBar.showPercent ~= false
	local displayText
	if showPercent then
		displayText = string.format("%.0f%%", data.speedPct)
	else
		displayText = string.format("%.1f", data.rawSpeed)
	end

	-- Check if sustain marker should be shown (setting + has valid marker data)
	local ui = profile.ui or {}
	local showSustainMarker = ui.showSustainMarker ~= false
	local shouldShowMarker = showSustainMarker and data.showMarker

	return Result.success({
		isSecret = false,
		speedPct = data.speedPct,
		fillPct = data.fillPct,
		displayText = displayText,
		barColor = { r, g, b },
		markerPct = data.markerPct,
		showMarker = shouldShowMarker,
	})
end

--- Execute acceleration bar calculation.
---@param ctx FlightsimContext Current context
---@param barWidth number Bar width in pixels
---@param barHeight number Bar height in pixels
---@return ActionResult<AccelBarData>
function Executor.Acceleration(ctx, barWidth, barHeight)
	if ctx.player.isSpeedSecret then
		return Result.success({
			isSecret = true,
			shouldHide = true,
		})
	end

	-- Get current speed percentage
	local speedResult = Executor.Speed(ctx)
	if not speedResult.success then
		return Result.success({ shouldHide = true })
	end

	local speedPct = Result.unwrap(speedResult).speedPct or 0

	-- Calculate acceleration
	local accelResult = Logic.Acceleration.Calculate({
		currentSpeed = speedPct,
		lastSpeed = frameState.lastSpeedPct,
		previousSmooth = frameState.smoothDelta,
		barWidth = barWidth or 200,
		barHeight = barHeight or 4,
	})

	if not accelResult.success then
		return Result.success({ shouldHide = true })
	end

	local data = Result.unwrap(accelResult)

	-- Update state
	frameState.lastSpeedPct = speedPct
	frameState.smoothDelta = data.smoothDelta

	return Result.success({
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
		return Result.error("INVALID_ABILITY", "Unknown ability: " .. tostring(abilityKey))
	end

	local charges = abilityData.charges
	local isUsable = abilityData.isUsable

	-- Handle secret values
	if charges.isSecret then
		local secretResult = FenCore.Charges.HandleSecretFallback(isUsable, maxCharges)
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

	-- Calculate charge states using FenCore
	local chargeResult = FenCore.Charges.CalculateAll({
		currentCharges = charges.currentCharges,
		maxCharges = maxCharges,
		chargeStart = charges.chargeStart,
		chargeDuration = charges.chargeDuration,
		now = ctx.now,
	})

	if not chargeResult.success then
		return chargeResult
	end

	local data = Result.unwrap(chargeResult)
	local ANIM_SPEED = 3.0

	-- Update animation state and calculate display values
	local displayStates = {}
	local rechargingIndex = nil
	for i, chargeState in ipairs(data.charges) do
		local targetPct = chargeState.fill
		local displayPct = targetPct
		local prevTarget = targets[i]
		local isFirstFrame = prevTarget == nil

		-- Track recharging index
		if chargeState.isRecharging then
			rechargingIndex = i
		end

		-- Check if animation should trigger (charge just became full)
		-- Skip animation on first frame (after mount) - start at current state
		local shouldAnimate = not isFirstFrame and targetPct >= 1 and (prevTarget or 0) < 1
		if shouldAnimate and not animating[i] then
			animating[i] = true
			animValues[i] = prevTarget or 0
		end

		-- Advance animation using FenCore
		if animating[i] then
			local newValue = FenCore.Charges.AdvanceAnimation(
				animValues[i] or 0,
				1, -- target is always 1 for fill animation
				ctx.deltaTime,
				ANIM_SPEED
			)
			animValues[i] = newValue
			displayPct = newValue
			if newValue >= 0.99 then
				animating[i] = false
				animValues[i] = 1
				displayPct = 1
			end
		end

		-- Update targets for next frame
		targets[i] = targetPct

		displayStates[i] = {
			index = i,
			displayPct = displayPct,
			targetPct = targetPct,
			isRecharging = chargeState.isRecharging,
			isFull = targetPct >= 1,
		}
	end

	return Result.success({
		isSecret = false,
		states = displayStates,
		allFull = data.allFull,
		rechargingIndex = rechargingIndex,
	})
end

--- Execute cooldown bar calculation (Whirling Surge).
---@param ctx FlightsimContext Current context
---@return ActionResult<CooldownBarData>
function Executor.Cooldown(ctx)
	local abilityData = ctx.abilities.whirlingSurge
	if not abilityData then
		return Result.error("INVALID_ABILITY", "Whirling Surge data not found")
	end

	local cooldown = abilityData.cooldown
	local isUsable = abilityData.isUsable

	-- Handle secret values
	if cooldown.isSecret then
		-- Return full bar when secret
		local r, g, b = Logic.Color.ForWhirlingSurge(1)
		return Result.success({
			isSecret = true,
			displayValue = 1,
			isReady = true,
			onCooldown = false,
			remaining = 0,
			barColor = { r, g, b },
		})
	end

	-- Calculate cooldown state using FenCore
	local cdResult = FenCore.Cooldowns.Calculate({
		startTime = cooldown.startTime,
		duration = cooldown.duration,
		now = ctx.now,
		enabled = cooldown.enabled,
	})

	if not cdResult.success then
		return cdResult
	end

	local data = Result.unwrap(cdResult)

	-- Calculate display value and animation
	local targetValue = data.progress
	local isReady = not data.isOnCooldown
	local ANIM_SPEED = 8.0

	-- Check if cooldown just became ready (for fill animation)
	-- Skip animation on first frame (after mount) - start at current state
	local shouldAnimate = not frameState.whirlFirstFrame and isReady and not frameState.whirlWasReady
	if shouldAnimate and not frameState.whirlAnimating then
		frameState.whirlAnimating = true
		frameState.whirlAnimValue = frameState.whirlAnimValue or targetValue
	end
	frameState.whirlFirstFrame = false

	-- Advance animation
	local displayValue = targetValue
	if frameState.whirlAnimating then
		local newValue = FenCore.Cooldowns.AdvanceAnimation(
			frameState.whirlAnimValue or 0,
			1,
			ctx.deltaTime,
			ANIM_SPEED
		)
		frameState.whirlAnimValue = newValue
		displayValue = newValue
		if newValue >= 0.99 then
			frameState.whirlAnimating = false
			frameState.whirlAnimValue = 1
			displayValue = 1
		end
	end

	-- Update state for next frame
	frameState.whirlWasReady = isReady

	-- Get color
	local r, g, b = Logic.Color.ForWhirlingSurge(displayValue)

	return Result.success({
		isSecret = false,
		displayValue = displayValue,
		isReady = isReady,
		onCooldown = data.isOnCooldown,
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

	return Logic.Visibility.Calculate({
		visibility = profile.visibility or {},
		abilityBars = profile.abilityBars or {},
		playerState = {
			isSkyriding = ctx.player.isSkyriding,
			isMounted = ctx.player.isMounted,
			isDruidFlying = ctx.player.isDruidFlying,
			isFlying = ctx.player.isFlying,
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
	local visibility = Result.unwrap(visResult)

	-- If HUD is hidden, return early
	if not visibility.showHUD then
		return Result.success({
			visibility = visibility,
			shouldUpdate = false,
		})
	end

	-- Calculate all components (safely unwrap to avoid crashes on errors)
	local speedResult = Executor.Speed(ctx)
	local speedData = speedResult.success and Result.unwrap(speedResult) or nil

	local accelResult = Executor.Acceleration(ctx, barDimensions.accelBarWidth or 200, barDimensions.accelBarHeight or 4)
	local accelData = accelResult.success and Result.unwrap(accelResult) or nil

	local surgeData = nil
	if visibility.showSurgeForward then
		local surgeResult = Executor.Charges(ctx, "surgeForward", 6)
		surgeData = surgeResult.success and Result.unwrap(surgeResult) or nil
	end

	local windData = nil
	if visibility.showSecondWind then
		local windResult = Executor.Charges(ctx, "secondWind", 3)
		windData = windResult.success and Result.unwrap(windResult) or nil
	end

	local whirlData = nil
	if visibility.showWhirlingSurge then
		local whirlResult = Executor.Cooldown(ctx)
		whirlData = whirlResult.success and Result.unwrap(whirlResult) or nil
	end

	return Result.success({
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
