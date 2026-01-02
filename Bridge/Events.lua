-- Flightsim Bridge: Event Handling
-- Registers and routes WoW events to appropriate handlers
-- Manages cache invalidation and state updates

local Bridge = FlightsimBridge
local Context = Bridge.Context

---@class EventsModule
local Events = {}

-- Event frame for WoW events
local eventFrame = nil

-- Registered callbacks
local callbacks = {
	onMount = {}, -- Mount/dismount events
	onZoneChange = {}, -- Zone change events
	onAura = {}, -- Aura change events
}

--- Register a callback for mount-related events.
---@param id string Unique callback ID
---@param callback function Callback function
function Events.OnMount(id, callback)
	callbacks.onMount[id] = callback
end

--- Register a callback for zone change events.
---@param id string Unique callback ID
---@param callback function Callback function
function Events.OnZoneChange(id, callback)
	callbacks.onZoneChange[id] = callback
end

--- Register a callback for aura change events.
---@param id string Unique callback ID
---@param callback function Callback function
function Events.OnAura(id, callback)
	callbacks.onAura[id] = callback
end

--- Fire all callbacks for a category.
---@param category string Callback category
---@param ... any Arguments to pass to callbacks
local function fireCallbacks(category, ...)
	for _, callback in pairs(callbacks[category] or {}) do
		pcall(callback, ...)
	end
end

--- Handle WoW events.
---@param event string Event name
---@param ... any Event arguments
local function onEvent(_, event, ...)
	if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
		Context.InvalidateSkyridingCache()
		fireCallbacks("onMount", event)
	elseif event == "UNIT_AURA" then
		local unit = ...
		if unit == "player" then
			Context.InvalidateSkyridingCache()
			fireCallbacks("onAura", event, unit)
		end
	elseif event == "UPDATE_SHAPESHIFT_FORMS" then
		Context.InvalidateSkyridingCache()
		fireCallbacks("onMount", event)
	elseif event == "PLAYER_ENTERING_WORLD" then
		Context.InvalidateSkyridingCache()
		Context.UpdateZoneState()
		fireCallbacks("onZoneChange", event)
		fireCallbacks("onMount", event)
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		Context.UpdateZoneState()
		fireCallbacks("onZoneChange", event)
	end
end

--- Initialize event handling.
--- Call once during addon initialization.
function Events.Init()
	if eventFrame then
		return -- Already initialized
	end

	eventFrame = CreateFrame("Frame")
	eventFrame:SetScript("OnEvent", onEvent)

	-- Mount/form events
	eventFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
	eventFrame:RegisterEvent("UNIT_AURA")
	eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")

	-- Zone events
	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

	Bridge:Log("Events initialized")
end

--- Clean up event handling.
function Events.Shutdown()
	if eventFrame then
		eventFrame:UnregisterAllEvents()
		eventFrame:SetScript("OnEvent", nil)
		eventFrame = nil
	end

	callbacks = {
		onMount = {},
		onZoneChange = {},
		onAura = {},
	}
end

--- Force a visibility check on next update.
--- Called when mount state may have changed.
function Events.ForceVisibilityCheck()
	Context.InvalidateSkyridingCache()
	fireCallbacks("onMount", "FORCE_CHECK")
end

Bridge.Events = Events
return Events
