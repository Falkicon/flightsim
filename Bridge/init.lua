-- Flightsim Bridge Layer
-- Blizzard API Adapters
-- Connects FenCore + FlightsimLogic to WoW APIs

-- Require FenCore
local FenCore = _G.FenCore
if not FenCore then
	error("Flightsim requires FenCore library")
end

---@class FlightsimBridge
---@field Secrets table Secret value handling (delegates to FenCore.Secrets)
---@field Context table Context building from WoW APIs
---@field Events table Event registration and routing
---@field Executor table Action execution
FlightsimBridge = FlightsimBridge or {}

-- Convenient aliases for FenCore domains
FlightsimBridge.Result = FenCore.ActionResult
FlightsimBridge.Math = FenCore.Math

-- Debug logging helper (uses MechanicLib if available)
-- Logs to Mechanic Console only (no chat spam)
local logThrottle = {}
local LOG_THROTTLE_INTERVAL = 0.1 -- seconds between identical messages

function FlightsimBridge:Log(msg, category)
	if not Flightsim or not Flightsim.debugMode then
		return
	end

	-- Throttle identical messages
	local now = GetTime()
	if logThrottle[msg] and (now - logThrottle[msg]) < LOG_THROTTLE_INTERVAL then
		return
	end
	logThrottle[msg] = now

	local MechanicLib = LibStub and LibStub("MechanicLib-1.0", true)
	if MechanicLib then
		MechanicLib:Log("Flightsim", msg, category or MechanicLib.Categories.CORE)
	end
end

return FlightsimBridge
