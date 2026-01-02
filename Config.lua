FlightsimConfig = FlightsimConfig or {}

--- Create a button helper
local function CreateToolButton(parent, x, y, width, text, onClick)
	local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
	btn:SetSize(width, 24)
	btn:SetText(text)
	btn:SetScript("OnClick", onClick)
	return btn
end

--- Create the Tools panel for Mechanic integration
function FlightsimConfig:CreateToolsPanel(container)
	local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 10, -10)
	title:SetText("Flightsim Tools")

	local desc = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	desc:SetPoint("TOPLEFT", 10, -35)
	desc:SetText("Quick actions for the Flightsim HUD.")

	-- Row 1: Position & Lock
	local row1Label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row1Label:SetPoint("TOPLEFT", 10, -65)
	row1Label:SetText("Position:")

	CreateToolButton(container, 80, -60, 100, "Reset", function()
		if FlightsimDB and FlightsimDB.profile then
			FlightsimDB.profile.x = 0
			FlightsimDB.profile.y = 0
			FlightsimDB.profile.scale = 1
			if FlightsimUI and FlightsimUI.frame then
				FlightsimUI.frame:ClearAllPoints()
				FlightsimUI.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
				FlightsimUI.frame:SetScale(1)
			end
			print("|cff00ff00Flightsim:|r Position reset to center.")
		end
	end)

	CreateToolButton(container, 185, -60, 80, "Lock", function()
		if FlightsimDB and FlightsimDB.profile then
			FlightsimDB.profile.locked = true
			print("|cff00ff00Flightsim:|r HUD locked.")
		end
	end)

	CreateToolButton(container, 270, -60, 80, "Unlock", function()
		if FlightsimDB and FlightsimDB.profile then
			FlightsimDB.profile.locked = false
			print("|cff00ff00Flightsim:|r HUD unlocked. Drag to reposition.")
		end
	end)

	-- Row 2: Visibility
	local row2Label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row2Label:SetPoint("TOPLEFT", 10, -100)
	row2Label:SetText("Visibility:")

	CreateToolButton(container, 80, -95, 100, "Show Always", function()
		if FlightsimDB and FlightsimDB.profile and FlightsimDB.profile.visibility then
			FlightsimDB.profile.visibility.hideWhileSkyriding = false
			FlightsimDB.profile.visibility.hideWhenNotSkyriding = false
			print("|cff00ff00Flightsim:|r Always visible.")
		end
	end)

	CreateToolButton(container, 185, -95, 100, "Sky Only", function()
		if FlightsimDB and FlightsimDB.profile and FlightsimDB.profile.visibility then
			FlightsimDB.profile.visibility.hideWhileSkyriding = false
			FlightsimDB.profile.visibility.hideWhenNotSkyriding = true
			print("|cff00ff00Flightsim:|r Visible only while Skyriding.")
		end
	end)

	CreateToolButton(container, 290, -95, 100, "Ground Only", function()
		if FlightsimDB and FlightsimDB.profile and FlightsimDB.profile.visibility then
			FlightsimDB.profile.visibility.hideWhileSkyriding = true
			FlightsimDB.profile.visibility.hideWhenNotSkyriding = false
			print("|cff00ff00Flightsim:|r Visible only when grounded (test mode).")
		end
	end)

	-- Row 3: Debug
	local row3Label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row3Label:SetPoint("TOPLEFT", 10, -135)
	row3Label:SetText("Debug:")

	CreateToolButton(container, 80, -130, 100, "Toggle Debug", function()
		if FlightsimDB and FlightsimDB.profile then
			FlightsimDB.profile.debugMode = not FlightsimDB.profile.debugMode
			Flightsim.debugMode = FlightsimDB.profile.debugMode
			print("|cff00ff00Flightsim:|r Debug mode " .. (Flightsim.debugMode and "ON" or "OFF"))
		end
	end)

	CreateToolButton(container, 185, -130, 80, "Status", function()
		if FlightsimUI and FlightsimUI.Status then
			FlightsimUI:Status()
		else
			print("|cffff0000Flightsim:|r Status not available.")
		end
	end)

	-- Row 4: Abilities
	local row4Label = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row4Label:SetPoint("TOPLEFT", 10, -170)
	row4Label:SetText("Abilities:")

	CreateToolButton(container, 80, -165, 100, "List All", function()
		if FlightsimDB and FlightsimDB.profile and FlightsimDB.profile.abilities then
			print("|cff00ff00Flightsim:|r Ability bars:")
			for i, token in ipairs(FlightsimDB.profile.abilities.order or {}) do
				local enabled = FlightsimDB.profile.abilities.enabled[token] ~= false
				print(string.format("  %d. %s [%s]", i, token, enabled and "ON" or "OFF"))
			end
		end
	end)

	-- Footer
	local footer = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	footer:SetPoint("BOTTOM", 0, 10)
	footer:SetText("Use /flightsim for more options. API tests moved to Tests tab.")
end

--- Legacy alias for backwards compatibility
function FlightsimConfig:CreateCompliancePanel(container)
	self:CreateToolsPanel(container)
end

SLASH_FLIGHTSIM1 = "/flightsim"
SLASH_FLIGHTSIM2 = "/fs"
SlashCmdList["FLIGHTSIM"] = function(msg)
	local L = Flightsim.L
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

	if not FlightsimDB or not FlightsimDB.profile then
		print(L["NOT_INITIALIZED_YET"])
		return
	end

	if msg == "lock" then
		FlightsimDB.profile.locked = true
		print(L["LOCKED"])
		return
	elseif msg == "unlock" then
		FlightsimDB.profile.locked = false
		print(L["UNLOCKED"])
		return
	elseif msg:match("^scale%s+") then
		local val = tonumber(msg:match("^scale%s+([%d%.]+)$"))
		if not val then
			print(L["USAGE_SCALE"])
			return
		end
		if FlightsimUI and FlightsimUI.SetScale then
			FlightsimUI:SetScale(val)
		end
		print(L["SCALE_SET"])
		return
	elseif msg:match("^width%s+") then
		local val = tonumber(msg:match("^width%s+([%d%.]+)$"))
		if not val then
			print(L["USAGE_WIDTH"])
			return
		end
		if FlightsimUI and FlightsimUI.SetWidth then
			FlightsimUI:SetWidth(val)
		end
		print(L["WIDTH_SET"])
		return
	elseif msg:match("^barmax%s+") then
		local val = tonumber(msg:match("^barmax%s+([%d%.]+)$"))
		if not val then
			print(L["USAGE_BARMAX"])
			return
		end
		if FlightsimUI and FlightsimUI.SetSpeedBarMax then
			FlightsimUI:SetSpeedBarMax(val)
		end
		print(L["BARMAX_SET"])
		return
	elseif msg:match("^sustainable%s+") or msg:match("^optimal%s+") then
		local val = tonumber(msg:match("^sustainable%s+([%d%.]+)$") or msg:match("^optimal%s+([%d%.]+)$"))
		if val == nil then
			print(L["USAGE_SUSTAINABLE"])
			return
		end
		if FlightsimUI and FlightsimUI.SetSustainableSpeed then
			FlightsimUI:SetSustainableSpeed(val)
		end
		print(L["SUSTAINABLE_SET"])
		return
	elseif msg == "hidenot" then
		FlightsimDB.profile.visibility.hideWhenNotSkyriding = true
		FlightsimDB.profile.visibility.hideWhileSkyriding = false
		print(L["HIDE_NOT_SKYRIDING"])
		return
	elseif msg == "hidesky" then
		FlightsimDB.profile.visibility.hideWhileSkyriding = true
		FlightsimDB.profile.visibility.hideWhenNotSkyriding = false
		print(L["HIDE_WHILE_SKYRIDING"])
		return
	elseif msg == "showalways" then
		FlightsimDB.profile.visibility.hideWhileSkyriding = false
		FlightsimDB.profile.visibility.hideWhenNotSkyriding = false
		print(L["SHOW_ALWAYS"])
		return
	elseif msg:match("^toggle%s+") then
		local query = msg:match("^toggle%s+(.+)$")
		local found
		for _, token in ipairs(FlightsimDB.profile.abilities.order or {}) do
			if token:lower():find(query, 1, true) then
				local enabled = FlightsimDB.profile.abilities.enabled[token] ~= false
				FlightsimDB.profile.abilities.enabled[token] = not enabled
				print(string.format(L["ABILITY_TOGGLED"], token, (not enabled) and "enabled" or "disabled"))
				found = true
				break
			end
		end
		if not found then
			print(L["ABILITY_NOT_FOUND"])
		else
			if FlightsimUI and FlightsimUI.RebuildAbilityRows then
				FlightsimUI:RebuildAbilityRows()
			end
		end
		return
	elseif msg == "list" then
		print(L["ABILITIES_LIST"])
		for i, token in ipairs(FlightsimDB.profile.abilities.order or {}) do
			local enabled = FlightsimDB.profile.abilities.enabled[token] ~= false
			print(string.format("  %d. %s [%s]", i, token, enabled and "ON" or "OFF"))
		end
		return
	elseif msg:match("^move%s+") then
		local a, b = msg:match("^move%s+(.+)%s+(%d+)$")
		local newIndex = tonumber(b)
		if not (a and newIndex) then
			print(L["USAGE_MOVE"])
			return
		end
		local order = FlightsimDB.profile.abilities.order or {}
		local fromIndex
		for i, token in ipairs(order) do
			if token:lower():find(a, 1, true) then
				fromIndex = i
				break
			end
		end
		if not fromIndex then
			print(L["ABILITY_NOT_FOUND"])
			return
		end
		newIndex = math.max(1, math.min(#order, newIndex))
		local item = table.remove(order, fromIndex)
		table.insert(order, newIndex, item)
		FlightsimDB.profile.abilities.order = order
		if FlightsimUI and FlightsimUI.RebuildAbilityRows then
			FlightsimUI:RebuildAbilityRows()
		end
		print(L["ORDER_UPDATED"])
		return
	elseif msg == "debug" then
		FlightsimDB.profile.debugMode = not FlightsimDB.profile.debugMode
		Flightsim.debugMode = FlightsimDB.profile.debugMode
		print("Flightsim debug mode:", Flightsim.debugMode and "ON" or "OFF")
		return
	elseif msg == "status" then
		if FlightsimUI and FlightsimUI.Status then
			FlightsimUI:Status()
		else
			print(L["STATUS_NOT_AVAILABLE"])
		end
		return
	elseif msg == "reset" then
		FlightsimDB.profile.x = 0
		FlightsimDB.profile.y = 0
		FlightsimDB.profile.scale = 1
		if FlightsimUI and FlightsimUI.frame then
			FlightsimUI.frame:ClearAllPoints()
			FlightsimUI.frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
			FlightsimUI.frame:SetScale(1)
		end
		print(L["RESET_DONE"])
		return
	end

	print(L["COMMANDS_HELP"])
	print("  /flightsim lock")
	print("  /flightsim unlock")
	print("  /flightsim scale <number>")
	print("  /flightsim width <number>")
	print("  /flightsim barmax <number>")
	print("  /flightsim sustainable <number>  (0 hides marker)")
	print("  /flightsim hidenot | hidesky | showalways")
	print("  /flightsim list")
	print("  /flightsim toggle <ability>")
	print("  /flightsim move <ability> <index>")
	print("  /flightsim status")
	print("  /flightsim debug")
	print("  /flightsim reset")
end
