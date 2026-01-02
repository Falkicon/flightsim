-- Flightsim Core Layer
-- Pure Lua 5.1 - No WoW dependencies
-- Fully testable in sandbox

---@class FlightsimCore
---@field Actions table Action utilities
---@field Utils table Utility functions
---@field Logic table Business logic modules
FlightsimCore = FlightsimCore or {}
FlightsimCore.Actions = FlightsimCore.Actions or {}
FlightsimCore.Utils = FlightsimCore.Utils or {}
FlightsimCore.Logic = FlightsimCore.Logic or {}

return FlightsimCore
