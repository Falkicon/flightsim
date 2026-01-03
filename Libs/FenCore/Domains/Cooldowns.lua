-- Cooldowns.lua
-- Cooldown calculation utilities

local FenCore = _G.FenCore
local Result = FenCore.ActionResult
local Math = FenCore.Math
local Secrets = FenCore.Secrets
local Catalog = FenCore.Catalog

local Cooldowns = {}

--- Calculate cooldown progress.
---@param startTime number When cooldown started (GetTime)
---@param duration number Cooldown duration in seconds
---@param now number Current time (GetTime)
---@return ActionResult<{progress: number, remaining: number, isOnCooldown: boolean}>
function Cooldowns.CalculateProgress(startTime, duration, now)
    if startTime == nil or duration == nil then
        return Result.error("INVALID_INPUT", "startTime and duration are required")
    end

    now = now or 0

    -- No cooldown
    if duration <= 0 or startTime == 0 then
        return Result.success({
            progress = 1,
            remaining = 0,
            isOnCooldown = false,
        })
    end

    local elapsed = now - startTime
    local remaining = duration - elapsed

    -- Cooldown finished
    if remaining <= 0 then
        return Result.success({
            progress = 1,
            remaining = 0,
            isOnCooldown = false,
        })
    end

    local progress = Math.Clamp(elapsed / duration, 0, 1)

    return Result.success({
        progress = progress,
        remaining = remaining,
        isOnCooldown = true,
    })
end

--- Calculate full cooldown state from context.
---@param context table {startTime, duration, now, enabled?}
---@return ActionResult<{progress: number, remaining: number, isOnCooldown: boolean, isEnabled: boolean}>
function Cooldowns.Calculate(context)
    if context == nil then
        return Result.error("INVALID_INPUT", "context is required")
    end

    local startTime = context.startTime or 0
    local duration = context.duration or 0
    local now = context.now or 0
    local enabled = context.enabled

    -- Handle potentially secret enabled value
    local isEnabled = true
    if enabled ~= nil then
        if Secrets.IsSecret(enabled) then
            isEnabled = true  -- Assume enabled for secrets
        else
            isEnabled = enabled == true
        end
    end

    local progressResult = Cooldowns.CalculateProgress(startTime, duration, now)
    if not progressResult.success then
        return progressResult
    end

    local data = progressResult.data
    data.isEnabled = isEnabled

    return Result.success(data)
end

--- Advance animation value smoothly toward target.
---@param currentValue number Current animated value
---@param targetValue number Target value
---@param deltaTime number Frame delta time
---@param animSpeed? number Animation speed multiplier (default 8)
---@return number newValue
function Cooldowns.AdvanceAnimation(currentValue, targetValue, deltaTime, animSpeed)
    animSpeed = animSpeed or 8
    local diff = targetValue - currentValue
    local step = diff * Math.Clamp(deltaTime * animSpeed, 0, 1)
    return currentValue + step
end

--- Handle secret value fallback for usability.
---@param isUsable any Potentially secret usability
---@return ActionResult<{usable: boolean, isSecret: boolean}>
function Cooldowns.HandleSecretFallback(isUsable)
    if Secrets.IsSecret(isUsable) then
        return Result.success({
            usable = true,
            isSecret = true,
        }, "Assuming usable for secret value")
    end

    return Result.success({
        usable = isUsable == true,
        isSecret = false,
    })
end

--- Check if cooldown is ready (not on cooldown).
---@param startTime number When cooldown started
---@param duration number Cooldown duration
---@param now number Current time
---@return boolean isReady
function Cooldowns.IsReady(startTime, duration, now)
    if duration <= 0 or startTime == 0 then
        return true
    end
    local elapsed = now - startTime
    return elapsed >= duration
end

--- Get time remaining on cooldown.
---@param startTime number When cooldown started
---@param duration number Cooldown duration
---@param now number Current time
---@return number remaining (0 if ready)
function Cooldowns.GetRemaining(startTime, duration, now)
    if duration <= 0 or startTime == 0 then
        return 0
    end
    local remaining = (startTime + duration) - now
    return math.max(0, remaining)
end

-- Register with catalog
Catalog:RegisterDomain("Cooldowns", {
    CalculateProgress = {
        handler = Cooldowns.CalculateProgress,
        description = "Calculate cooldown progress",
        params = {
            { name = "startTime", type = "number", required = true },
            { name = "duration", type = "number", required = true },
            { name = "now", type = "number", required = true },
        },
        returns = { type = "ActionResult<{progress, remaining, isOnCooldown}>" },
        example = "Cooldowns.CalculateProgress(100, 30, 115) → {progress: 0.5, remaining: 15}",
    },
    Calculate = {
        handler = Cooldowns.Calculate,
        description = "Calculate full cooldown state from context",
        params = {
            { name = "context", type = "table", required = true, description = "{startTime, duration, now, enabled?}" },
        },
        returns = { type = "ActionResult<{progress, remaining, isOnCooldown, isEnabled}>" },
    },
    AdvanceAnimation = {
        handler = Cooldowns.AdvanceAnimation,
        description = "Advance animation value smoothly toward target",
        params = {
            { name = "currentValue", type = "number", required = true },
            { name = "targetValue", type = "number", required = true },
            { name = "deltaTime", type = "number", required = true },
            { name = "animSpeed", type = "number", required = false, default = 8 },
        },
        returns = { type = "number" },
    },
    HandleSecretFallback = {
        handler = Cooldowns.HandleSecretFallback,
        description = "Handle secret value fallback for usability",
        params = {
            { name = "isUsable", type = "any", required = true },
        },
        returns = { type = "ActionResult<{usable, isSecret}>" },
    },
    IsReady = {
        handler = Cooldowns.IsReady,
        description = "Check if cooldown is ready",
        params = {
            { name = "startTime", type = "number", required = true },
            { name = "duration", type = "number", required = true },
            { name = "now", type = "number", required = true },
        },
        returns = { type = "boolean" },
        example = "Cooldowns.IsReady(100, 30, 130) → true",
    },
    GetRemaining = {
        handler = Cooldowns.GetRemaining,
        description = "Get time remaining on cooldown",
        params = {
            { name = "startTime", type = "number", required = true },
            { name = "duration", type = "number", required = true },
            { name = "now", type = "number", required = true },
        },
        returns = { type = "number" },
        example = "Cooldowns.GetRemaining(100, 30, 115) → 15",
    },
})

FenCore.Cooldowns = Cooldowns
return Cooldowns
