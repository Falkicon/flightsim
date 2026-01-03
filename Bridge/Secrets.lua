-- Flightsim Bridge: Secret Value Handling
-- Delegates to FenCore.Secrets for Midnight (12.0+) combat secret values

local Bridge = FlightsimBridge
local FenCore = _G.FenCore

-- Delegate to FenCore.Secrets
Bridge.Secrets = FenCore.Secrets

return Bridge.Secrets
