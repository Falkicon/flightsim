-- ActionResult.lua
-- AFD-style structured results for all FenCore operations

local FenCore = _G.FenCore

---@class ActionError
---@field code string Machine-readable error code
---@field message string Human-readable message
---@field suggestion? string What to do about it

---@class ActionResult<T>
---@field success boolean Whether the action succeeded
---@field data? T The result data (if success)
---@field error? ActionError Error details (if failure)
---@field reasoning? string Why this result

local ActionResult = {}

--- Create a successful ActionResult.
---@generic T
---@param data T The result data
---@param reasoning? string Optional explanation
---@return ActionResult<T>
function ActionResult.success(data, reasoning)
    return {
        success = true,
        data = data,
        reasoning = reasoning,
    }
end

--- Create a failed ActionResult.
---@param code string Error code (e.g., "INVALID_INPUT")
---@param message string Human-readable message
---@param suggestion? string What to do about it
---@return ActionResult
function ActionResult.error(code, message, suggestion)
    return {
        success = false,
        error = {
            code = code,
            message = message,
            suggestion = suggestion,
        },
    }
end

--- Check if a result is successful.
---@param result ActionResult
---@return boolean
function ActionResult.isSuccess(result)
    return result and result.success == true
end

--- Check if a result is an error.
---@param result ActionResult
---@return boolean
function ActionResult.isError(result)
    return result and result.success == false
end

--- Unwrap a result, returning data or nil.
---@generic T
---@param result ActionResult<T>
---@return T|nil
function ActionResult.unwrap(result)
    if result and result.success then
        return result.data
    end
    return nil
end

--- Unwrap a result, throwing error if failed.
---@generic T
---@param result ActionResult<T>
---@return T
function ActionResult.unwrapOrThrow(result)
    if result and result.success then
        return result.data
    end
    local errMsg = result and result.error and result.error.message or "Unknown error"
    error(errMsg, 2)
end

--- Get error code from a failed result.
---@param result ActionResult
---@return string|nil
function ActionResult.getErrorCode(result)
    if result and result.error then
        return result.error.code
    end
    return nil
end

--- Map a successful result to a new value.
---@generic T, U
---@param result ActionResult<T>
---@param fn fun(data: T): U Mapping function
---@return ActionResult<U>
function ActionResult.map(result, fn)
    if result and result.success then
        return ActionResult.success(fn(result.data), result.reasoning)
    end
    return result
end

FenCore.ActionResult = ActionResult
return ActionResult
