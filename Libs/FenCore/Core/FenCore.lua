-- FenCore.lua
-- Foundation library for WoW addon development
-- https://github.com/Falkicon/FenCore

---@class FenCore
local MAJOR, MINOR = "FenCore", 1
local FenCore = {}

-- Version info
FenCore.version = "1.0.0"
FenCore.major = MAJOR
FenCore.minor = MINOR

-- Debug mode (set via /fencore debug)
FenCore.debugMode = false

-- Namespace containers (populated by modules)
FenCore.ActionResult = nil  -- Set by ActionResult.lua
FenCore.Catalog = nil       -- Set by Catalog.lua

-- Domain namespaces (populated by domain modules)
FenCore.Math = nil
FenCore.Secrets = nil
FenCore.Progress = nil
FenCore.Charges = nil
FenCore.Cooldowns = nil
FenCore.Color = nil
FenCore.Time = nil
FenCore.Text = nil

-- Debug logging (to Mechanic console if available)
function FenCore:Log(message, category)
    if not self.debugMode then return end

    local MechanicLib = LibStub and LibStub("MechanicLib-1.0", true)
    if MechanicLib then
        MechanicLib:Log("FenCore", message, category or "[Core]")
    else
        print("|cFF88CCFF[FenCore]|r " .. message)
    end
end

-- Slash command
SLASH_FENCORE1 = "/fencore"
SlashCmdList["FENCORE"] = function(msg)
    local cmd = msg:lower():trim()

    if cmd == "debug" then
        FenCore.debugMode = not FenCore.debugMode
        print("|cFF88CCFF[FenCore]|r Debug mode: " .. (FenCore.debugMode and "ON" or "OFF"))
    elseif cmd == "catalog" then
        if FenCore.Catalog then
            local catalog = FenCore:GetCatalog()
            local domainCount = 0
            for _ in pairs(catalog.domains) do domainCount = domainCount + 1 end
            print("|cFF88CCFF[FenCore]|r Catalog: " .. domainCount .. " domains")
            for name, domain in pairs(catalog.domains) do
                local count = 0
                for _ in pairs(domain.functions) do count = count + 1 end
                print("  - " .. name .. ": " .. count .. " functions")
            end
        end
    else
        print("|cFF88CCFF[FenCore]|r v" .. FenCore.version)
        print("  /fencore debug - Toggle debug mode")
        print("  /fencore catalog - Show domain catalog")
    end
end

-- Register with MechanicLib if available
local function RegisterWithMechanic()
    local MechanicLib = LibStub and LibStub("MechanicLib-1.0", true)
    if MechanicLib and FenCore.Catalog then
        MechanicLib:Register("FenCore", {
            version = FenCore.version,
            catalog = function() return FenCore:GetCatalog() end,
        })
    end
end

-- Deferred registration (after all modules load)
C_Timer.After(0, RegisterWithMechanic)

-- Export global
_G.FenCore = FenCore
return FenCore
