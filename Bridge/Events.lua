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

local CALLBACK_ERROR_THROTTLE = 10

local function registerCallback(category, id, callback)
	callbacks[category][id] = {
		callback = callback,
		lastErrorAt = nil,
	}
end

--- Register a callback for mount-related events.
---@param id string Unique callback ID
---@param callback function Callback function
function Events.OnMount(id, callback)
	registerCallback("onMount", id, callback)
end

--- Register a callback for zone change events.
---@param id string Unique callback ID
---@param callback function Callback function
function Events.OnZoneChange(id, callback)
	registerCallback("onZoneChange", id, callback)
end

--- Register a callback for aura change events.
---@param id string Unique callback ID
---@param callback function Callback function
function Events.OnAura(id, callback)
	registerCallback("onAura", id, callback)
end

local function getErrorTime()
	if type(GetTime) ~= "function" then
		return nil
	end
	local ok, now = pcall(GetTime)
	if ok and type(now) == "number" then
		return now
	end
	return nil
end

local function reportCallbackError(category, id, event, callbackEntry, callbackError)
	local now = getErrorTime()
	local lastErrorAt = callbackEntry.lastErrorAt
	if lastErrorAt == false then
		return
	end
	if
		type(lastErrorAt) == "number"
		and now
		and now >= lastErrorAt
		and (now - lastErrorAt) < CALLBACK_ERROR_THROTTLE
	then
		return
	end
	callbackEntry.lastErrorAt = now or false

	local getErrorHandler = rawget(_G, "geterrorhandler")
	if type(getErrorHandler) ~= "function" then
		return
	end
	local handlerOK, errorHandler = pcall(getErrorHandler)
	if not handlerOK or type(errorHandler) ~= "function" then
		return
	end

	local errorOK, errorText = pcall(tostring, callbackError)
	if not errorOK then
		errorText = "<unprintable error>"
	end
	local message = string.format(
		"Flightsim callback failed (event=%s, category=%s, id=%s): %s",
		tostring(event),
		tostring(category),
		tostring(id),
		errorText
	)
	pcall(errorHandler, message)
end

--- Fire all callbacks for a category.
---@param category string Callback category
---@param ... any Arguments to pass to callbacks
local function fireCallbacks(category, event, ...)
	for id, callbackEntry in pairs(callbacks[category] or {}) do
		local ok, callbackError = pcall(callbackEntry.callback, event, ...)
		if not ok then
			reportCallbackError(category, id, event, callbackEntry, callbackError)
		end
	end
end

--- Handle WoW events.
---@param event string Event name
---@param ... any Event arguments
local function onEvent(_, event, ...)
	if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
		Context.InvalidateSpellCache()
		Context.InvalidateSkyridingCache()
		Context.UpdateZoneState() -- Refresh zone on mount to ensure correct speed calculations
		fireCallbacks("onMount", event)
	elseif event == "UNIT_AURA" then
		local unit = ...
		if unit == "player" then
			Context.InvalidateSkyridingCache()
			Context.UpdateBuffs()
			fireCallbacks("onAura", event, unit)
		end
	elseif event == "UPDATE_SHAPESHIFT_FORMS" or event == "UPDATE_SHAPESHIFT_FORM" then
		Context.InvalidateSpellCache()
		Context.InvalidateSkyridingCache()
		fireCallbacks("onMount", event)
	elseif event == "PLAYER_ENTERING_WORLD" then
		Context.InvalidateSpellCache()
		Context.InvalidateSkyridingCache()
		Context.UpdateZoneState()
		Context.UpdateBuffs()
		fireCallbacks("onZoneChange", event)
		fireCallbacks("onMount", event)
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		Context.InvalidateSpellCache()
		Context.InvalidateSkyridingCache()
		Context.UpdateZoneState()
		fireCallbacks("onZoneChange", event)
	elseif
		event == "SPELL_UPDATE_COOLDOWN"
		or event == "SPELL_UPDATE_CHARGES"
		or event == "SPELLS_CHANGED"
		or event == "PLAYER_REGEN_DISABLED"
		or event == "PLAYER_REGEN_ENABLED"
	then
		Context.InvalidateSpellCache()
		Context.InvalidateSkyridingCache()
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
	eventFrame:RegisterUnitEvent("UNIT_AURA", "player")
	eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
	eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")

	-- Zone events
	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

	-- Spell cooldown events (for charge/cooldown cache invalidation)
	eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	eventFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
	eventFrame:RegisterEvent("SPELLS_CHANGED")
	eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

	Context.InvalidateSpellCache()
	Context.InvalidateSkyridingCache()
	Context.UpdateBuffs()

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
