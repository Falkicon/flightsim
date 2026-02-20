-- Flightsim Visibility Logic
-- Zero-allocation visibility calculation
-- All results use pre-allocated static buffers

---@class FlightsimVisibility
local Visibility = {}

-- Pre-allocated result buffers (reused every frame)
local _hudResult = { success = true, data = { shouldShow = false, reason = "" } }
local _surgeAbilityResult = { success = true, data = { shouldShow = false } }
local _windAbilityResult = { success = true, data = { shouldShow = false } }
local _whirlAbilityResult = { success = true, data = { shouldShow = false } }
local _visResult = { success = true, data = nil }

---@class VisibilitySettings
---@field hideWhenNotSkyriding boolean Hide HUD when not on a skyriding mount
---@field showSurgeForward boolean Show Surge Forward bar
---@field showSecondWind boolean Show Second Wind bar
---@field showWhirlingSurge boolean Show Whirling Surge bar

---@class PlayerState
---@field isSkyriding boolean Currently in skyriding mode
---@field isMounted boolean Currently mounted
---@field isDruidFlying boolean Druid in flight form
---@field isFlying boolean Currently airborne (flying/gliding)

---@class VisibilityResult
---@field showHUD boolean Whether main HUD should be visible
---@field showSpeedBar boolean Whether speed bar should be visible
---@field showAccelBar boolean Whether acceleration bar should be visible
---@field showSurgeForward boolean Whether Surge Forward bar should be visible
---@field showSecondWind boolean Whether Second Wind bar should be visible
---@field showWhirlingSurge boolean Whether Whirling Surge bar should be visible
---@field reason string Why this visibility state

--- Determine if the main HUD should be visible.
---@param settings VisibilitySettings Visibility settings from SavedVariables
---@param playerState PlayerState Current player state
---@return table result Static result with .data.shouldShow and .data.reason
function Visibility.ShouldShowHUD(settings, playerState)
	if not settings or not playerState then
		_hudResult.data.shouldShow = false
		_hudResult.data.reason = "invalid input"
		return _hudResult
	end

	local hideWhenNotSkyriding = settings.hideWhenNotSkyriding
	local showWhenGroundMounted = settings.showWhenGroundMounted or false
	local isSkyriding = playerState.isSkyriding or false
	local isMounted = playerState.isMounted or false
	local isFlying = playerState.isFlying or false

	if hideWhenNotSkyriding then
		if not isSkyriding then
			_hudResult.data.shouldShow = false
			_hudResult.data.reason = "hideWhenNotSkyriding enabled and not skyriding"
			return _hudResult
		end
		if not isFlying then
			if showWhenGroundMounted and isMounted then
				_hudResult.data.shouldShow = true
				_hudResult.data.reason = "skyriding mount on ground, showWhenGroundMounted enabled"
				return _hudResult
			end
			_hudResult.data.shouldShow = false
			_hudResult.data.reason = "hideWhenNotSkyriding enabled and mounted but not flying"
			return _hudResult
		end
	end

	_hudResult.data.shouldShow = true
	_hudResult.data.reason = "visible (skyriding and flying, or visibility not restricted)"
	return _hudResult
end

--- Determine individual ability bar visibility (zero-alloc).
---@param settings table Ability bar settings
---@param abilityName string "surgeForward" | "secondWind" | "whirlingSurge"
---@param hudVisible boolean Whether the main HUD is visible
---@return table result Static result with .data.shouldShow
function Visibility.ShouldShowAbility(settings, abilityName, hudVisible)
	local resultBuf
	if abilityName == "surgeForward" then
		resultBuf = _surgeAbilityResult
	elseif abilityName == "secondWind" then
		resultBuf = _windAbilityResult
	else
		resultBuf = _whirlAbilityResult
	end

	if not hudVisible then
		resultBuf.data.shouldShow = false
		return resultBuf
	end

	settings = settings or {}

	local shouldShow = false
	if abilityName == "surgeForward" then
		shouldShow = settings.showSurgeForward ~= false
	elseif abilityName == "secondWind" then
		shouldShow = settings.showSecondWind == true
	elseif abilityName == "whirlingSurge" then
		shouldShow = settings.showWhirlingSurge == true
	end

	resultBuf.data.shouldShow = shouldShow
	return resultBuf
end

--- Calculate full visibility state for all components.
---@param context table {visibility: VisibilitySettings, abilityBars: table, playerState: PlayerState}
---@param outData table Pre-allocated output buffer
---@return table result Static result with .data containing visibility state
function Visibility.Calculate(context, outData)
	if not context then
		_visResult.success = false
		return _visResult
	end
	_visResult.success = true

	local visibility = context.visibility or {}
	local abilityBars = context.abilityBars or {}
	local playerState = context.playerState or {}

	-- Check main HUD visibility
	local hudResult = Visibility.ShouldShowHUD(visibility, playerState)
	local hudVisible = hudResult.data.shouldShow
	local reason = hudResult.data.reason

	local resultData = outData or {}

	-- If HUD is hidden, everything is hidden
	if not hudVisible then
		resultData.showHUD = false
		resultData.showSpeedBar = false
		resultData.showAccelBar = false
		resultData.showSurgeForward = false
		resultData.showSecondWind = false
		resultData.showWhirlingSurge = false
		resultData.reason = reason
		_visResult.data = resultData
		return _visResult
	end

	-- Calculate individual ability visibility
	local surgeResult = Visibility.ShouldShowAbility(abilityBars, "surgeForward", hudVisible)
	local windResult = Visibility.ShouldShowAbility(abilityBars, "secondWind", hudVisible)
	local whirlResult = Visibility.ShouldShowAbility(abilityBars, "whirlingSurge", hudVisible)

	resultData.showHUD = true
	resultData.showSpeedBar = true
	resultData.showAccelBar = true
	resultData.showSurgeForward = surgeResult.data.shouldShow
	resultData.showSecondWind = windResult.data.shouldShow
	resultData.showWhirlingSurge = whirlResult.data.shouldShow
	resultData.reason = reason

	_visResult.data = resultData
	return _visResult
end

--- Determine visibility transition (for animation purposes).
---@param wasVisible boolean Previous visibility state
---@param isVisible boolean Current visibility state
---@return string action "hide", "show", or "none"
function Visibility.GetTransition(wasVisible, isVisible)
	if wasVisible and not isVisible then
		return "hide"
	elseif not wasVisible and isVisible then
		return "show"
	else
		return "none"
	end
end

FlightsimLogic = FlightsimLogic or {}
FlightsimLogic.Visibility = Visibility
return Visibility
