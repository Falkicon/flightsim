-- Run from the repository root: lua Tests/event_diagnostics_regressions.lua
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks = checks + 1
end

local now = 100
local reports = {}
local eventFrame

_G.GetTime = function()
	return now
end
_G.geterrorhandler = function()
	return function(message)
		reports[#reports + 1] = message
	end
end
_G.CreateFrame = function()
	eventFrame = { events = {} }
	function eventFrame:SetScript(name, callback)
		self[name] = callback
	end
	function eventFrame:RegisterEvent(name)
		self.events[name] = true
	end
	function eventFrame:RegisterUnitEvent(name)
		self.events[name] = true
	end
	function eventFrame:UnregisterAllEvents()
		self.events = {}
	end
	return eventFrame
end

dofile("Tests/bootstrap.lua")
dofile("Bridge/init.lua")

FlightsimBridge.Context = {
	InvalidateSpellCache = function() end,
	InvalidateSkyridingCache = function() end,
	UpdateZoneState = function() end,
	UpdateBuffs = function() end,
}
dofile("Bridge/Events.lua")

local Events = FlightsimBridge.Events
local survivorCalls = 0
Events.OnMount("broken-mount", function()
	error("intentional callback failure")
end)
Events.OnMount("survivor", function(event)
	check(event == "PLAYER_MOUNT_DISPLAY_CHANGED", "surviving callback receives the event name")
	survivorCalls = survivorCalls + 1
end)
Events.Init()

eventFrame:OnEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
check(survivorCalls == 1, "a failing callback does not stop later subscribers")
check(#reports == 1, "the first callback failure reaches the normal error handler")
check(reports[1]:find("event=PLAYER_MOUNT_DISPLAY_CHANGED", 1, true), "diagnostic identifies the event")
check(reports[1]:find("id=broken-mount", 1, true), "diagnostic identifies the callback")
check(reports[1]:find("intentional callback failure", 1, true), "diagnostic includes the callback error")

now = 105
eventFrame:OnEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
check(survivorCalls == 2, "throttling diagnostics does not throttle callback dispatch")
check(#reports == 1, "repeated failures are throttled")

now = 111
eventFrame:OnEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
check(survivorCalls == 3, "subscribers continue after the throttle window")
check(#reports == 2, "a persistent failure is reported again after the throttle window")

Events.OnAura("broken-handler", function()
	error("handler path failure")
end)
_G.geterrorhandler = function()
	error("error handler lookup failed")
end
local dispatchOK = pcall(eventFrame.OnEvent, eventFrame, "UNIT_AURA", "player")
check(dispatchOK, "an error-handler lookup failure cannot escape event dispatch")

_G.geterrorhandler = function()
	return function()
		error("error handler failed")
	end
end
Events.OnZoneChange("broken-error-handler", function()
	error("handler invocation failure")
end)
dispatchOK = pcall(eventFrame.OnEvent, eventFrame, "ZONE_CHANGED_NEW_AREA")
check(dispatchOK, "an error-handler invocation failure cannot escape event dispatch")

print("Event diagnostics regressions: " .. checks .. " checks passed")
