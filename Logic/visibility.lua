-- Flightsim Visibility Logic
-- Uses FenCore for ActionResult pattern
-- Flightsim-specific visibility decisions for HUD and components

local FenCore = _G.FenCore
local Result = FenCore.ActionResult

---@class FlightsimVisibility
local Visibility = {}

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
---@return ActionResult<{shouldShow: boolean, reason: string}>
function Visibility.ShouldShowHUD(settings, playerState)
	if not settings then
		return Result.error("INVALID_INPUT", "settings is required")
	end
	if not playerState then
		return Result.error("INVALID_INPUT", "playerState is required")
	end

	local hideWhenNotSkyriding = settings.hideWhenNotSkyriding
	local isSkyriding = playerState.isSkyriding or false
	local isFlying = playerState.isFlying or false

	if hideWhenNotSkyriding then
		-- Must be both skyriding AND flying (not just mounted on ground)
		if not isSkyriding then
			return Result.success({
				shouldShow = false,
				reason = "hideWhenNotSkyriding enabled and not skyriding",
			})
		end
		if not isFlying then
			return Result.success({
				shouldShow = false,
				reason = "hideWhenNotSkyriding enabled and mounted but not flying",
			})
		end
	end

	return Result.success({
		shouldShow = true,
		reason = "visible (skyriding and flying, or visibility not restricted)",
	})
end

--- Determine individual ability bar visibility.
---@param settings table Ability bar settings
---@param abilityName string "surgeForward" | "secondWind" | "whirlingSurge"
---@param hudVisible boolean Whether the main HUD is visible
---@return ActionResult<{shouldShow: boolean}>
function Visibility.ShouldShowAbility(settings, abilityName, hudVisible)
	if not hudVisible then
		return Result.success({ shouldShow = false })
	end

	settings = settings or {}

	local shouldShow = false
	if abilityName == "surgeForward" then
		-- Defaults to true if not explicitly set to false
		shouldShow = settings.showSurgeForward ~= false
	elseif abilityName == "secondWind" then
		-- Defaults to false unless explicitly enabled
		shouldShow = settings.showSecondWind == true
	elseif abilityName == "whirlingSurge" then
		-- Defaults to false unless explicitly enabled
		shouldShow = settings.showWhirlingSurge == true
	end

	return Result.success({ shouldShow = shouldShow })
end

--- Calculate full visibility state for all components.
---@param context table {visibility: VisibilitySettings, abilityBars: table, playerState: PlayerState}
---@return ActionResult<VisibilityResult>
function Visibility.Calculate(context)
	if not context then
		return Result.error("INVALID_INPUT", "context is required")
	end

	local visibility = context.visibility or {}
	local abilityBars = context.abilityBars or {}
	local playerState = context.playerState or {}

	-- Check main HUD visibility
	local hudResult = Visibility.ShouldShowHUD(visibility, playerState)
	if not hudResult.success then
		return hudResult
	end
	local hudVisible = Result.unwrap(hudResult).shouldShow
	local reason = Result.unwrap(hudResult).reason

	-- If HUD is hidden, everything is hidden
	if not hudVisible then
		return Result.success({
			showHUD = false,
			showSpeedBar = false,
			showAccelBar = false,
			showSurgeForward = false,
			showSecondWind = false,
			showWhirlingSurge = false,
			reason = reason,
		})
	end

	-- Calculate individual ability visibility
	local surgeResult = Visibility.ShouldShowAbility(abilityBars, "surgeForward", hudVisible)
	local windResult = Visibility.ShouldShowAbility(abilityBars, "secondWind", hudVisible)
	local whirlResult = Visibility.ShouldShowAbility(abilityBars, "whirlingSurge", hudVisible)

	return Result.success({
		showHUD = true,
		showSpeedBar = true,
		showAccelBar = true,
		showSurgeForward = Result.unwrap(surgeResult).shouldShow,
		showSecondWind = Result.unwrap(windResult).shouldShow,
		showWhirlingSurge = Result.unwrap(whirlResult).shouldShow,
		reason = reason,
	})
end

--- Determine visibility transition (for animation purposes).
---@param wasVisible boolean Previous visibility state
---@param isVisible boolean Current visibility state
---@return ActionResult<{action: string}>
function Visibility.GetTransition(wasVisible, isVisible)
	if wasVisible and not isVisible then
		return Result.success({ action = "hide" })
	elseif not wasVisible and isVisible then
		return Result.success({ action = "show" })
	else
		return Result.success({ action = "none" })
	end
end

FlightsimLogic = FlightsimLogic or {}
FlightsimLogic.Visibility = Visibility
return Visibility
