-- Charges.lua
-- Charge-based ability calculations

local FenCore = _G.FenCore
local Result = FenCore.ActionResult
local Math = FenCore.Math
local Secrets = FenCore.Secrets
local Catalog = FenCore.Catalog

local Charges = {}

--- Write a single charge into a caller-owned data buffer (no ActionResult).
--- Inputs must be ordinary numeric values; adapters must resolve secrets first.
--- Output is borrowed mutable storage: copy values to retain a snapshot.
--- Use dedicated buffers; all fields in this output schema are overwritten.
---@param output table Reusable {fill, isRecharging} data buffer
---@return table output
function Charges.CalculateChargeFillInto(chargeIndex, currentCharges, chargeStart, chargeDuration, now, output)
	now = now or 0
	chargeDuration = chargeDuration or 0
	output.fill = 0
	output.isRecharging = false
	if chargeIndex <= currentCharges then
		output.fill = 1
	elseif chargeIndex <= currentCharges + 1 and chargeDuration > 0 and chargeStart ~= 0 then
		output.fill = Math.Clamp((now - chargeStart) / chargeDuration, 0, 1)
		output.isRecharging = true
	end
	return output
end

--- Calculate single charge fill with an independently owned ActionResult.
function Charges.CalculateChargeFill(chargeIndex, currentCharges, chargeStart, chargeDuration, now)
	if chargeIndex == nil or currentCharges == nil then
		return Result.error("INVALID_INPUT", "chargeIndex and currentCharges are required")
	end
	return Result.success(
		Charges.CalculateChargeFillInto(chargeIndex, currentCharges, chargeStart, chargeDuration, now, {})
	)
end

--- Write all charges into a caller-owned data buffer (no ActionResult).
--- Allocates only missing storage when capacity grows; clears array tails on shrink.
--- Output and nested charges are borrowed mutable tables: use separate buffers or
--- copy values to retain snapshots. Numeric inputs must be non-secret.
---@param context table {currentCharges, maxCharges, chargeStart, chargeDuration, now}
---@param output table Reusable {charges, allFull, anyRecharging} buffer
---@return table output
function Charges.CalculateAllInto(context, output)
	local currentCharges = context.currentCharges or 0
	local maxCharges = context.maxCharges or 1
	local chargeStart = context.chargeStart or 0
	local chargeDuration = context.chargeDuration or 0
	local now = context.now or 0
	local charges = output.charges or {}
	output.charges = charges
	local anyRecharging = false
	local count = 0
	for i = 1, maxCharges do
		local charge = charges[i] or {}
		charges[i] = charge
		Charges.CalculateChargeFillInto(i, currentCharges, chargeStart, chargeDuration, now, charge)
		if charge.isRecharging then
			anyRecharging = true
		end
		count = i
	end
	for i = #charges, count + 1, -1 do
		charges[i] = nil
	end
	output.allFull = currentCharges >= maxCharges
	output.anyRecharging = anyRecharging
	return output
end

--- Calculate all charges with an independently owned ActionResult.
function Charges.CalculateAll(context)
	if context == nil then
		return Result.error("INVALID_INPUT", "context is required")
	end
	return Result.success(Charges.CalculateAllInto(context, {}))
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
	CalculateChargeFillInto = {
		handler = Charges.CalculateChargeFillInto,
		description = "Write {fill, isRecharging} into caller-owned borrowed storage",
		params = {
			{ name = "chargeIndex", type = "number", required = true },
			{ name = "currentCharges", type = "number", required = true },
			{ name = "chargeStart", type = "number", required = true },
			{ name = "chargeDuration", type = "number", required = true },
			{ name = "now", type = "number", required = true },
			{
				name = "output",
				type = "table",
				required = true,
				description = "Mutable data buffer; copy to retain a snapshot",
			},
		},
		returns = { type = "table" },
	},
	CalculateAllInto = {
		handler = Charges.CalculateAllInto,
		description = "Write {charges, allFull, anyRecharging} into caller-owned borrowed storage",
		params = {
			{ name = "context", type = "table", required = true },
			{
				name = "output",
				type = "table",
				required = true,
				description = "Mutable data buffer; copy to retain a snapshot",
			},
		},
		returns = { type = "table" },
	},
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
			{
				name = "context",
				type = "table",
				required = true,
				description = "{currentCharges, maxCharges, chargeStart, chargeDuration, now}",
			},
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
