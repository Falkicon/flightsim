-- Flightsim Logic Layer
-- Flightsim-specific logic using FenCore foundation
-- Pure Lua 5.1 - testable in sandbox

-- Ensure FenCore is available
local FenCore = _G.FenCore
if not FenCore then
	error("Flightsim requires FenCore library")
end

---@class FlightsimLogic
---@field Speed table Speed calculation logic
---@field Acceleration table Acceleration bar logic
---@field Visibility table Visibility decisions
---@field Color table Flightsim-specific color palettes
FlightsimLogic = FlightsimLogic or {}

return FlightsimLogic
