-- Flightsim Core Actions
-- ActionResult pattern for all Core operations
-- Follows AFD (Agent-First Development) conventions

local Core = FlightsimCore

---@class ActionError
---@field code string Machine-readable error code
---@field message string Human-readable message
---@field suggestion? string What to do about it

---@class ActionResult<T>
---@field success boolean Whether the action succeeded
---@field data? T The result data (if success)
---@field error? ActionError Error details (if failure)
---@field reasoning? string Why this result

local Actions = {}

--- Create a successful ActionResult.
---@generic T
---@param data T The result data
---@param reasoning? string Optional explanation
---@return ActionResult<T>
function Actions.success(data, reasoning)
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
function Actions.error(code, message, suggestion)
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
function Actions.isSuccess(result)
	return result and result.success == true
end

--- Unwrap a result, returning data or nil.
---@generic T
---@param result ActionResult<T>
---@return T|nil
function Actions.unwrap(result)
	if result and result.success then
		return result.data
	end
	return nil
end

Core.Actions = Actions
return Actions
