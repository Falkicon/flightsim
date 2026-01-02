-- Flightsim Bridge: Secret Value Handling
-- Handles Midnight (12.0+) combat secret values
-- MUST stay in Bridge layer - Core never sees raw secrets

local Bridge = FlightsimBridge

---@class SecretsModule
local Secrets = {}

--- Check if a value is a WoW secret value.
--- Secret values crash Lua when used in arithmetic/comparisons.
---@param val any Value to check
---@return boolean isSecret
function Secrets.IsSecret(val)
	if val == nil then
		return false
	end

	-- Use WoW's built-in check if available (Midnight+)
	if issecretvalue then
		return issecretvalue(val) == true
	end

	-- Robust fallback: secret values crash on comparison
	local ok = pcall(function()
		local _ = (val > -1e12)
	end)
	return not ok
end

--- Safely convert a value to string.
--- Returns "???" for secret values.
---@param val any Value to convert
---@return string
function Secrets.SafeToString(val)
	if val == nil then
		return "nil"
	end
	if Secrets.IsSecret(val) then
		return "???"
	end
	return tostring(val)
end

--- Safely compare two values.
--- Returns nil if either value is secret or nil.
---@param a any First value
---@param b any Second value
---@param op string Operator: ">", "<", ">=", "<=", "==", "~="
---@return boolean|nil Result or nil if comparison not possible
function Secrets.SafeCompare(a, b, op)
	if a == nil or b == nil then
		return nil
	end
	if Secrets.IsSecret(a) or Secrets.IsSecret(b) then
		return nil
	end

	if op == ">" then
		return a > b
	elseif op == "<" then
		return a < b
	elseif op == ">=" then
		return a >= b
	elseif op == "<=" then
		return a <= b
	elseif op == "==" then
		return a == b
	elseif op == "~=" then
		return a ~= b
	end

	return nil
end

--- Safely perform arithmetic on a value.
--- Returns nil if value is secret.
---@param val number|secret Value to use
---@param operation function Operation to perform (receives val)
---@param fallback any Fallback value if secret
---@return any Result or fallback
function Secrets.SafeArithmetic(val, operation, fallback)
	if val == nil or Secrets.IsSecret(val) then
		return fallback
	end

	local ok, result = pcall(operation, val)
	if not ok then
		return fallback
	end
	return result
end

--- Extract a clean number from a potentially secret value.
--- Returns nil and isSecret=true for secrets.
---@param val any Raw value
---@return number|nil value, boolean isSecret
function Secrets.CleanNumber(val)
	if val == nil then
		return nil, false
	end
	if Secrets.IsSecret(val) then
		return nil, true
	end
	if type(val) == "number" then
		return val, false
	end
	return nil, false
end

Bridge.Secrets = Secrets
return Secrets
