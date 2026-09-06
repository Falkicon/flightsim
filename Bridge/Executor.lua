-- Flightsim Bridge: Executor
-- Orchestrates FenCore + FlightsimLogic execution with WoW context
-- AFD pattern: Bridge:Execute(action, context) -> ActionResult

local Bridge = FlightsimBridge
local Context = Bridge.Context
local FenCore = _G.FenCore
local Logic = FlightsimLogic
local Result = FenCore.ActionResult

---@class ExecutorModule
local Executor = {}

-- Reusable buffers to eliminate GC churn in the hot path
local _speedInput = {}
local _speedOutput = {}
local _accelInput = {}
local _accelOutput = {}
local _visInput = {
	visibility = {},
	abilityBars = {},
	playerState = {},
}
local _visOutput = {}
local _pitchInput = {}
local _pitchOutput = {}
-- Borrowed FenCore scratch data is copied into each rendered ability below.
local _chargeInput = {}
local _surgeChargeOutput = { charges = { {}, {}, {}, {}, {}, {} } }
local _windChargeOutput = { charges = { {}, {}, {} } }
local _cooldownOutput = {}
local _surgeStates = { {}, {}, {}, {}, {}, {}, {}, {} }
local _windStates = { {}, {}, {}, {}, {}, {}, {}, {} }
local _fullUpdateData = {
	visibility = {},
	speed = {},
	acceleration = {},
	pitch = {},
	surgeForward = { states = _surgeStates },
	secondWind = { states = _windStates },
	whirlingSurge = {},
	buffs = {},
}
local _fullUpdateResult = { success = true, data = _fullUpdateData }

-- Frame state cache (persists between updates)
local frameState = {
	lastFrameTime = nil,
	lastSpeedPct = nil,
	smoothDelta = 0,
	sessionMaxSpeed = nil,

	-- Pitch state: continuous position tracking
	pitchLastX = nil, -- last UnitPosition X where position actually changed
	pitchLastY = nil,
	pitchLastTime = nil,
	pitchHorizSpeed = 0, -- exponentially smoothed horizontal speed
	pitchSmoothRatio = 0,
	pitchSmoothTrend = 0,
	pitchPrevSpeed = nil,

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
	frameState.lastFrameTime = nil
	frameState.lastSpeedPct = nil
	frameState.smoothDelta = 0
	frameState.sessionMaxSpeed = nil
	frameState.pitchLastX = nil
	frameState.pitchLastY = nil
	frameState.pitchLastTime = nil
	frameState.pitchHorizSpeed = 0
	frameState.pitchSmoothRatio = 0
	frameState.pitchSmoothTrend = 0
	frameState.pitchPrevSpeed = nil
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
	local out = _fullUpdateData.speed

	if ctx.player.isSpeedSecret then
		out.isSecret = true
		out.displayText = "???"
		out.barColor = out.barColor or {}
		out.barColor[1], out.barColor[2], out.barColor[3] = 0.5, 0.5, 0.5
		out.speedPct = 0
		out.fillPct = 0
		out.showMarker = false
		return out
	end

	local db = ctx.db or {}
	local profile = db.profile or {}
	local speedBar = profile.speedBar or {}

	-- Calculate speed
	_speedInput.rawSpeed = ctx.player.speed or 0
	_speedInput.zoneModifier = ctx.zone.zoneModifier
	_speedInput.configuredMax = speedBar.maxSpeed or 950
	_speedInput.sustainableSpeed = speedBar.useCustomSustainableSpeed and speedBar.sustainableSpeed or nil
	_speedInput.sessionMax = frameState.sessionMaxSpeed

	local speedResult = Logic.Speed.Calculate(_speedInput, _speedOutput)

	if not speedResult.success then
		return speedResult
	end

	local data = speedResult.data

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
		if pct < 0 then
			pct = 0
		end
		if pct > 1 then
			pct = 1
		end

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

	-- Format display text (only reformat when value changes to avoid string allocation)
	local showPercent = speedBar.showPercent ~= false
	local displayText
	if showPercent then
		local intSpeed = math.floor(data.speedPct + 0.5)
		if intSpeed ~= frameState.lastDisplayInt then
			frameState.lastDisplayInt = intSpeed
			frameState.lastDisplayText = intSpeed .. "%"
		end
		displayText = frameState.lastDisplayText or "0%"
	else
		-- Raw speed changes less frequently, cache similarly
		local intRaw = math.floor(data.rawSpeed * 10 + 0.5)
		if intRaw ~= frameState.lastRawInt then
			frameState.lastRawInt = intRaw
			frameState.lastRawText = string.format("%.1f", data.rawSpeed)
		end
		displayText = frameState.lastRawText or "0.0"
	end

	-- Check if sustain marker should be shown (setting + has valid marker data)
	local ui = profile.ui or {}
	local showSustainMarker = ui.showSustainMarker ~= false
	local shouldShowMarker = showSustainMarker and data.showMarker

	-- out already declared at top of function
	out.isSecret = false
	out.speedPct = data.speedPct
	out.fillPct = data.fillPct
	out.displayText = displayText
	out.barColor = out.barColor or {}
	out.barColor[1], out.barColor[2], out.barColor[3] = r, g, b
	out.markerPct = data.markerPct
	out.showMarker = shouldShowMarker

	return out
end

--- Execute acceleration bar calculation.
---@param ctx FlightsimContext Current context
---@param barWidth number Bar width in pixels
---@param barHeight number Bar height in pixels
---@return ActionResult<AccelBarData>
function Executor.Acceleration(ctx, barWidth, barHeight, speedPct)
	local out = _fullUpdateData.acceleration

	if ctx.player.isSpeedSecret then
		out.isSecret = true
		out.shouldHide = true
		frameState.lastSpeedPct = nil
		frameState.smoothDelta = 0
		return out
	end

	speedPct = speedPct or 0

	-- Calculate acceleration
	_accelInput.currentSpeed = speedPct
	_accelInput.lastSpeed = frameState.lastSpeedPct
	_accelInput.previousSmooth = frameState.smoothDelta
	_accelInput.deltaTime = ctx.deltaTime
	_accelInput.barWidth = barWidth or 200
	_accelInput.barHeight = barHeight or 4

	local accelResult = Logic.Acceleration.Calculate(_accelInput, _accelOutput)

	if not accelResult.success then
		out.shouldHide = true
		return out
	end

	local data = accelResult.data

	-- Update state
	frameState.lastSpeedPct = speedPct
	frameState.smoothDelta = data.smoothDelta

	out.isSecret = false
	out.shouldHide = false
	out.width = data.barWidth
	out.anchorSide = data.anchorSide
	out.offsetX = data.offsetX
	out.isStable = data.isStable
	out.direction = data.direction

	return out
end

--- Execute pitch bar calculation via position-based triangulation.
--- Detects each UnitPosition server tick and computes instant horizontal speed,
--- then applies exponential smoothing for a continuous, jitter-free signal.
---@param ctx FlightsimContext Current context
---@param barWidth number Bar width in pixels
---@param barHeight number Bar height in pixels
---@return ActionResult<PitchBarData>
function Executor.Pitch(ctx, barWidth, barHeight)
	local out = _fullUpdateData.pitch

	if ctx.player.isSpeedSecret then
		out.shouldHide = true
		out.smoothRatio = 0
		out.smoothTrend = 0
		return out
	end

	local totalSpeed = ctx.player.speed or 0
	local posX = ctx.player.posX
	local posY = ctx.player.posY
	local now = ctx.now

	-- Horizontal speed: use raw instant speed from each UnitPosition server tick.
	-- Between ticks, hold the last computed value.
	-- Ratio smoothing in Logic handles frame-to-frame stability.

	if posX and posY then
		if frameState.pitchLastX and frameState.pitchLastTime then
			-- Check if position actually changed (new server tick)
			local dx = posX - frameState.pitchLastX
			local dy = posY - frameState.pitchLastY
			local moved = (dx ~= 0 or dy ~= 0)
			if moved then
				local dt = now - frameState.pitchLastTime
				if dt > 0.001 then
					frameState.pitchHorizSpeed = math.sqrt(dx * dx + dy * dy) / dt
				end
				frameState.pitchLastX = posX
				frameState.pitchLastY = posY
				frameState.pitchLastTime = now
			end
		else
			-- First frame with position: seed it
			frameState.pitchLastX = posX
			frameState.pitchLastY = posY
			frameState.pitchLastTime = now
		end
	end

	local horizontalSpeed = frameState.pitchHorizSpeed

	-- Speed trend for direction inference
	local speedTrend = 0
	if frameState.pitchPrevSpeed then
		speedTrend = totalSpeed - frameState.pitchPrevSpeed
	end
	frameState.pitchPrevSpeed = totalSpeed

	-- Call triangulation logic
	_pitchInput.totalSpeed = totalSpeed
	_pitchInput.horizontalSpeed = horizontalSpeed
	_pitchInput.previousSmooth = frameState.pitchSmoothRatio
	_pitchInput.previousTrend = frameState.pitchSmoothTrend
	_pitchInput.speedTrend = speedTrend
	_pitchInput.barWidth = barWidth or 200
	_pitchInput.barHeight = barHeight or 2

	local pitchResult = Logic.Pitch.Calculate(_pitchInput, _pitchOutput)

	if not pitchResult.success then
		out.shouldHide = true
		out.smoothRatio = 0
		out.smoothTrend = 0
		return out
	end

	local data = Result.unwrap(pitchResult)
	frameState.pitchSmoothRatio = data.smoothRatio or 0
	frameState.pitchSmoothTrend = data.smoothTrend or 0

	out.shouldHide = data.shouldHide or false
	out.width = data.width
	out.anchorSide = data.anchorSide
	out.offsetX = data.offsetX
	out.isStable = data.isStable
	out.direction = data.direction

	return out
end

--- Execute charge bar calculation (Surge Forward or Second Wind).
---@param ctx FlightsimContext Current context
---@param abilityKey string "surgeForward" or "secondWind"
---@param maxCharges number Maximum charges
---@return ActionResult<ChargeBarData>
function Executor.Charges(ctx, abilityKey, maxCharges)
	maxCharges = maxCharges or 1
	local abilityData = ctx.abilities[abilityKey]
	if not abilityData then
		return Result.error("INVALID_ABILITY", "Unknown ability: " .. tostring(abilityKey))
	end

	local charges = abilityData.charges
	local isUsable = abilityData.isUsable

	local out, listOut, targets, animating, animValues
	if abilityKey == "surgeForward" then
		targets = frameState.surgeTargets
		animating = frameState.surgeAnimating
		animValues = frameState.surgeAnimValues
		out = _fullUpdateData.surgeForward
		listOut = _surgeStates
	else
		targets = frameState.windTargets
		animating = frameState.windAnimating
		animValues = frameState.windAnimValues
		out = _fullUpdateData.secondWind
		listOut = _windStates
	end

	-- Handle secret values
	if charges.isSecret then
		local fill = isUsable and 1 or 0
		for i = 1, maxCharges do
			targets[i] = nil
			animating[i] = nil
			animValues[i] = nil
			local stateOut = listOut[i] or {}
			listOut[i] = stateOut
			stateOut.index = i
			stateOut.displayPct = fill
			stateOut.targetPct = fill
			stateOut.isRecharging = false
			stateOut.isFull = fill == 1
		end
		out.isSecret = true
		out.states = listOut
		out.numStates = maxCharges
		out.allFull = fill == 1
		out.rechargingIndex = nil
		return out
	end

	-- Resolve ordinary adapter values through the shared allocation-free API.
	_chargeInput.currentCharges = charges.currentCharges or 0
	_chargeInput.maxCharges = maxCharges
	_chargeInput.chargeStart = math.max(0, charges.chargeStart or 0)
	_chargeInput.chargeDuration = charges.chargeDuration or 0
	_chargeInput.now = ctx.now or 0
	local domainOutput = abilityKey == "surgeForward" and _surgeChargeOutput or _windChargeOutput
	local chargeState = FenCore.Charges.CalculateAllInto(_chargeInput, domainOutput)

	local ANIM_SPEED = 3.0
	local rechargingIndex = nil
	local allFull = chargeState.allFull

	-- Update animation state and calculate display values
	for i = 1, maxCharges do
		local charge = chargeState.charges[i]
		local targetPct = charge.fill
		local isRecharging = charge.isRecharging
		local displayPct = targetPct
		local prevTarget = targets[i]
		local isFirstFrame = prevTarget == nil

		-- Track recharging index
		if isRecharging then
			rechargingIndex = i
		end

		-- Check if animation should trigger (charge just became full)
		-- Skip animation on first frame (after mount) - start at current state
		local shouldAnimate = not isFirstFrame and targetPct >= 1 and (prevTarget or 0) < 1
		-- Spending a charge must cancel a completion animation immediately.
		if targetPct < 1 then
			animating[i] = false
		end
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

		-- Mutate pre-allocated state table
		local stateOut = listOut[i] or {}
		listOut[i] = stateOut
		stateOut.index = i
		stateOut.displayPct = displayPct
		stateOut.targetPct = targetPct
		stateOut.isRecharging = isRecharging
		stateOut.isFull = targetPct >= 1
	end

	out.isSecret = false
	out.states = listOut
	out.numStates = maxCharges
	out.allFull = allFull
	out.rechargingIndex = rechargingIndex

	return out
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
	-- Handle secret values
	if cooldown.isSecret then
		frameState.whirlFirstFrame = true
		frameState.whirlAnimating = false
		-- Return full bar when secret
		local r, g, b = Logic.Color.ForWhirlingSurge(1)
		local out = _fullUpdateData.whirlingSurge
		out.isSecret = true
		out.displayValue = 1
		out.isReady = true
		out.onCooldown = false
		out.remaining = 0
		out.barColor = out.barColor or {}
		out.barColor[1], out.barColor[2], out.barColor[3] = r, g, b
		return out
	end

	local cooldownState = FenCore.Cooldowns.CalculateProgressInto(
		math.max(0, cooldown.startTime or 0),
		cooldown.duration or 0,
		ctx.now or 0,
		_cooldownOutput
	)
	local targetValue = cooldownState.progress
	local remaining = cooldownState.remaining
	local isOnCooldown = cooldownState.isOnCooldown

	local isReady = not isOnCooldown
	local ANIM_SPEED = 8.0
	if isOnCooldown then
		frameState.whirlAnimating = false
	end

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
		local newValue =
			FenCore.Cooldowns.AdvanceAnimation(frameState.whirlAnimValue or 0, 1, ctx.deltaTime, ANIM_SPEED)
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
	frameState.whirlAnimValue = displayValue

	-- Get color
	local r, g, b = Logic.Color.ForWhirlingSurge(displayValue)

	local out = _fullUpdateData.whirlingSurge
	out.isSecret = false
	out.displayValue = displayValue
	out.isReady = isReady
	out.onCooldown = isOnCooldown
	out.remaining = remaining
	out.barColor = out.barColor or {}
	out.barColor[1], out.barColor[2], out.barColor[3] = r, g, b

	return out
end

--- Execute visibility calculation.
---@param ctx FlightsimContext Current context
---@return ActionResult<VisibilityData>
function Executor.Visibility(ctx)
	local db = ctx.db or {}
	local profile = db.profile or {}

	_visInput.visibility = profile.visibility or {}
	_visInput.abilityBars = profile.abilityBars or {}
	_visInput.playerState.isSkyriding = ctx.player.isSkyriding
	_visInput.playerState.isMounted = ctx.player.isMounted
	_visInput.playerState.isDruidFlying = ctx.player.isDruidFlying
	_visInput.playerState.isFlying = ctx.player.isFlying

	-- Calculate visibility
	local visResult = Logic.Visibility.Calculate(_visInput, _visOutput)
	return visResult
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
	local visibility = visResult.data

	-- If HUD is hidden, return early
	local visOut = _fullUpdateData.visibility
	if not visibility.showHUD then
		frameState.lastSpeedPct = nil
		frameState.smoothDelta = 0
		visOut.showHUD = false
		visOut.reason = visibility.reason
		_fullUpdateData.shouldUpdate = false
		return _fullUpdateResult
	end

	visOut.showHUD = true
	visOut.showSpeedBar = visibility.showSpeedBar
	visOut.showPitchBar = visibility.showPitchBar
	visOut.showSurgeForward = visibility.showSurgeForward
	visOut.showSecondWind = visibility.showSecondWind
	visOut.showWhirlingSurge = visibility.showWhirlingSurge
	visOut.showAbilities = visibility.showAbilities

	-- Calculate all components (safely bypass if nil returned)
	local speedData = Executor.Speed(ctx)
	local speedPct = speedData and speedData.speedPct or 0

	Executor.Acceleration(ctx, barDimensions.accelBarWidth or 200, barDimensions.accelBarHeight or 4, speedPct)

	-- Pitch bar shelved: skip computation until estimation is refined
	local pitchEnabled = false
	if pitchEnabled then
		Executor.Pitch(ctx, barDimensions.pitchBarWidth or 200, barDimensions.pitchBarHeight or 2)
	else
		_fullUpdateData.pitch = nil
	end

	if visibility.showSurgeForward then
		Executor.Charges(ctx, "surgeForward", 6)
	end

	if visibility.showSecondWind then
		Executor.Charges(ctx, "secondWind", 3)
	end

	if visibility.showWhirlingSurge then
		Executor.Cooldown(ctx)
	end

	_fullUpdateData.shouldUpdate = true
	_fullUpdateData.buffs = ctx.buffs

	return _fullUpdateResult
end

Bridge.Executor = Executor
return Executor
