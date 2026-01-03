-- Charges.lua
-- Charge-based ability calculations

local FenCore = _G.FenCore
local Result = FenCore.ActionResult
local Math = FenCore.Math
local Secrets = FenCore.Secrets
local Catalog = FenCore.Catalog

local Charges = {}

--- Calculate fill for a single charge.
---@param chargeIndex number Which charge (1-based)
---@param currentCharges number Current charge count
---@param chargeStart number When recharge started (GetTime)
---@param chargeDuration number Recharge duration in seconds
---@param now number Current time (GetTime)
---@return ActionResult<{fill: number, isRecharging: boolean}>
function Charges.CalculateChargeFill(chargeIndex, currentCharges, chargeStart, chargeDuration, now)
    if chargeIndex == nil or currentCharges == nil then
        return Result.error("INVALID_INPUT", "chargeIndex and currentCharges are required")
    end

    now = now or 0
    chargeDuration = chargeDuration or 0

    -- Charge is full
    if chargeIndex <= currentCharges then
        return Result.success({
            fill = 1,
            isRecharging = false,
        })
    end

    -- Charge is empty (beyond next one recharging)
    if chargeIndex > currentCharges + 1 then
        return Result.success({
            fill = 0,
            isRecharging = false,
        })
    end

    -- This is the currently recharging charge
    if chargeDuration <= 0 or chargeStart == 0 then
        return Result.success({
            fill = 0,
            isRecharging = false,
        })
    end

    local elapsed = now - chargeStart
    local fill = Math.Clamp(elapsed / chargeDuration, 0, 1)

    return Result.success({
        fill = fill,
        isRecharging = true,
    })
end

--- Calculate all charges for an ability.
---@param context table {currentCharges, maxCharges, chargeStart, chargeDuration, now}
---@return ActionResult<{charges: table[], allFull: boolean, anyRecharging: boolean}>
function Charges.CalculateAll(context)
    if context == nil then
        return Result.error("INVALID_INPUT", "context is required")
    end

    local currentCharges = context.currentCharges or 0
    local maxCharges = context.maxCharges or 1
    local chargeStart = context.chargeStart or 0
    local chargeDuration = context.chargeDuration or 0
    local now = context.now or 0

    local charges = {}
    local anyRecharging = false

    for i = 1, maxCharges do
        local result = Charges.CalculateChargeFill(i, currentCharges, chargeStart, chargeDuration, now)
        if result.success then
            table.insert(charges, result.data)
            if result.data.isRecharging then
                anyRecharging = true
            end
        else
            table.insert(charges, { fill = 0, isRecharging = false })
        end
    end

    local allFull = currentCharges >= maxCharges

    return Result.success({
        charges = charges,
        allFull = allFull,
        anyRecharging = anyRecharging,
    })
end

--- Advance animation value smoothly toward target.
---@param currentValue number Current animated value
---@param targetValue number Target value
---@param deltaTime number Frame delta time
---@param animSpeed? number Animation speed multiplier (default 8)
---@return number newValue
function Charges.AdvanceAnimation(currentValue, targetValue, deltaTime, animSpeed)
    animSpeed = animSpeed or 8
    local diff = targetValue - currentValue
    local step = diff * Math.Clamp(deltaTime * animSpeed, 0, 1)
    return currentValue + step
end

--- Handle secret value fallback for charges.
---@param isUsable any Potentially secret usability
---@param maxCharges number Max charges for the ability
---@return ActionResult<{currentCharges: number, isSecret: boolean}>
function Charges.HandleSecretFallback(isUsable, maxCharges)
    maxCharges = maxCharges or 1

    if Secrets.IsSecret(isUsable) then
        return Result.success({
            currentCharges = maxCharges,
            isSecret = true,
        }, "Using max charges as fallback for secret usability")
    end

    local charges = isUsable and maxCharges or 0
    return Result.success({
        currentCharges = charges,
        isSecret = false,
    })
end

-- Register with catalog
Catalog:RegisterDomain("Charges", {
    CalculateChargeFill = {
        handler = Charges.CalculateChargeFill,
        description = "Calculate fill for a single charge",
        params = {
            { name = "chargeIndex", type = "number", required = true, description = "1-based" },
            { name = "currentCharges", type = "number", required = true },
            { name = "chargeStart", type = "number", required = true },
            { name = "chargeDuration", type = "number", required = true },
            { name = "now", type = "number", required = true },
        },
        returns = { type = "ActionResult<{fill, isRecharging}>" },
        example = "Charges.CalculateChargeFill(2, 1, 100, 30, 115) → {fill: 0.5, isRecharging: true}",
    },
    CalculateAll = {
        handler = Charges.CalculateAll,
        description = "Calculate all charges for an ability",
        params = {
            { name = "context", type = "table", required = true, description = "{currentCharges, maxCharges, chargeStart, chargeDuration, now}" },
        },
        returns = { type = "ActionResult<{charges, allFull, anyRecharging}>" },
    },
    AdvanceAnimation = {
        handler = Charges.AdvanceAnimation,
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
        handler = Charges.HandleSecretFallback,
        description = "Handle secret value fallback for charges",
        params = {
            { name = "isUsable", type = "any", required = true },
            { name = "maxCharges", type = "number", required = true },
        },
        returns = { type = "ActionResult<{currentCharges, isSecret}>" },
    },
})

FenCore.Charges = Charges
return Charges
