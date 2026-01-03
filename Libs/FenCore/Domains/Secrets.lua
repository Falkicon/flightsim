-- Secrets.lua
-- Midnight (12.0+) secret value handling

local FenCore = _G.FenCore
local Catalog = FenCore.Catalog

local Secrets = {}

--- Check if a value is a WoW secret value.
---@param val any Value to check
---@return boolean isSecret
function Secrets.IsSecret(val)
    if val == nil then return false end

    -- Use WoW's built-in check if available (Midnight+)
    if issecretvalue then
        return issecretvalue(val) == true
    end

    -- Fallback: secret values crash on comparison
    local ok = pcall(function()
        local _ = (val > -1e12)
    end)
    return not ok
end

--- Safely convert a value to string.
---@param val any Value to convert
---@return string
function Secrets.SafeToString(val)
    if val == nil then return "nil" end
    if Secrets.IsSecret(val) then return "???" end
    return tostring(val)
end

--- Safely compare two values.
---@param a any First value
---@param b any Second value
---@param op string Operator: ">", "<", ">=", "<=", "==", "~="
---@return boolean|nil Result or nil if comparison not possible
function Secrets.SafeCompare(a, b, op)
    if a == nil or b == nil then return nil end
    if Secrets.IsSecret(a) or Secrets.IsSecret(b) then return nil end

    if op == ">" then return a > b
    elseif op == "<" then return a < b
    elseif op == ">=" then return a >= b
    elseif op == "<=" then return a <= b
    elseif op == "==" then return a == b
    elseif op == "~=" then return a ~= b
    end
    return nil
end

--- Safely perform arithmetic on a value.
---@param val number|secret Value to use
---@param operation function Operation to perform
---@param fallback any Fallback value if secret
---@return any Result or fallback
function Secrets.SafeArithmetic(val, operation, fallback)
    if val == nil or Secrets.IsSecret(val) then
        return fallback
    end

    local ok, result = pcall(operation, val)
    if not ok then return fallback end
    return result
end

--- Extract a clean number from a potentially secret value.
---@param val any Raw value
---@return number|nil value, boolean isSecret
function Secrets.CleanNumber(val)
    if val == nil then return nil, false end
    if Secrets.IsSecret(val) then return nil, true end
    if type(val) == "number" then return val, false end
    return nil, false
end

-- Register with catalog
Catalog:RegisterDomain("Secrets", {
    IsSecret = {
        handler = Secrets.IsSecret,
        description = "Check if a value is a WoW secret value (Midnight+)",
        params = {
            { name = "val", type = "any", required = true },
        },
        returns = { type = "boolean" },
        example = "Secrets.IsSecret(someValue) → true/false",
    },
    SafeToString = {
        handler = Secrets.SafeToString,
        description = "Safely convert value to string (returns '???' for secrets)",
        params = {
            { name = "val", type = "any", required = true },
        },
        returns = { type = "string" },
        example = 'Secrets.SafeToString(secretVal) → "???"',
    },
    SafeCompare = {
        handler = Secrets.SafeCompare,
        description = "Safely compare two values (returns nil if either is secret)",
        params = {
            { name = "a", type = "any", required = true },
            { name = "b", type = "any", required = true },
            { name = "op", type = "string", required = true, description = '">", "<", ">=", "<=", "==", "~="' },
        },
        returns = { type = "boolean|nil" },
        example = 'Secrets.SafeCompare(a, b, ">") → true/false/nil',
    },
    SafeArithmetic = {
        handler = Secrets.SafeArithmetic,
        description = "Safely perform arithmetic on potentially secret value",
        params = {
            { name = "val", type = "any", required = true },
            { name = "operation", type = "function", required = true },
            { name = "fallback", type = "any", required = true },
        },
        returns = { type = "any" },
        example = "Secrets.SafeArithmetic(val, function(v) return v * 2 end, 0)",
    },
    CleanNumber = {
        handler = Secrets.CleanNumber,
        description = "Extract clean number from potentially secret value",
        params = {
            { name = "val", type = "any", required = true },
        },
        returns = { type = "number|nil, boolean" },
        example = "local num, isSecret = Secrets.CleanNumber(val)",
    },
})

FenCore.Secrets = Secrets
return Secrets
