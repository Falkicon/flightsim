FlightsimConfig = FlightsimConfig or {}

function FlightsimConfig:CreateCompliancePanel(container)
	local title = container:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -10)
	title:SetText("Midnight UI Compliance Lab")

	local function CreateTestBar(y, label, color)
		local b = CreateFrame("StatusBar", nil, container)
		b:SetHeight(24)
		b:SetPoint("TOPLEFT", container, "TOPLEFT", 20, y)
		b:SetPoint("TOPRIGHT", container, "TOPRIGHT", -20, y)
		b:SetStatusBarTexture("Interface/Buttons/WHITE8X8")
		b:SetStatusBarColor(unpack(color))

		local bg = b:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		bg:SetColorTexture(0.1, 0.1, 0.1, 1)

		local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		t:SetPoint("CENTER", 0, 0)
		t:SetText(label)

		return b
	end

	-- 1. Standard SetValue(1)
	pcall(function()
		local b1 = CreateTestBar(-50, "1. SetValue(1) [Control]", { 0, 1, 0 })
		b1:SetMinMaxValues(0, 1)
		b1:SetValue(1)
	end)

	-- 2. Secret Passthrough (Speed)
	pcall(function()
		local b2 = CreateTestBar(-80, "2. SetValue(secret) [Speed]", { 0, 0.5, 1 })
		b2:SetMinMaxValues(0, 1000)
		local speed = GetUnitSpeed("player")
		if type(speed) == "number" then
			b2:SetValue(speed)
		else
			b2:SetValue(0)
		end
	end)

	-- 3. Boolean Proxy (IsSpellUsable)
	pcall(function()
		local b3 = CreateTestBar(-110, "3. SetValue(Proxy) [Surge Usable]", { 1, 0.5, 0 })
		local usable = C_Spell.IsSpellUsable(372608)
		b3:SetMinMaxValues(0, 1)
		b3:SetValue(usable and 1 or 0)
	end)

	-- 4. Color Texture Fallback
	pcall(function()
		local b4 = CreateTestBar(-140, "4. ColorTexture (ArtLayer)", { 1, 0, 1 })
		b4:SetStatusBarTexture(nil)
		local tex = b4:CreateTexture(nil, "ARTWORK")
		tex:SetAllPoints()
		tex:SetColorTexture(1, 0, 1, 1)
	end)

	-- 5. SetFillAmount (The 12.0 'New Way'?)
	pcall(function()
		local b5 = CreateTestBar(-170, "5. SetFillAmount(0.75)", { 1, 1, 0 })
		if type(b5.SetFillAmount) == "function" then
			b5:SetFillAmount(0.75)
		else
			b5:SetAlpha(0.3)
			local t = b5:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
			t:SetPoint("CENTER")
			t:SetText("SetFillAmount Unsupported")
		end
	end)

	-- 6. Taint/Security Test (Whitelisted API)
	pcall(function()
		local b6 = CreateTestBar(-200, "6. UnitPower('player', 25) [Vigor]", { 0.5, 0, 0.5 })
		local vigor = (UnitPower("player", 25))
		local vigorMax = (UnitPowerMax("player", 25))
		
		-- Protection against secret comparison crashes
		local safeVigorMax = 6
		if type(vigorMax) == "number" then
			-- In 12.0, secrets are 'number' type but crash on comparison
			local ok, isGreater = pcall(function() return vigorMax > 0 end)
			if ok and isGreater then
				safeVigorMax = vigorMax
			end
		end

		b6:SetMinMaxValues(0, safeVigorMax)
		
		if type(vigor) == "number" then
			b6:SetValue(vigor)
		else
			b6:SetValue(0)
		end
	end)

	-- 7. Audit Results (Visualizing what Audit found)
	pcall(function()
		local b7 = CreateTestBar(-230, "7. Surge Charge Table Count", { 1, 1, 1 })
		local charges = C_Spell.GetSpellCharges(372608)
		local count = 0
		if type(charges) == "table" then
			for _ in pairs(charges) do
				count = count + 1
			end
		end
		b7:SetMinMaxValues(0, 6)
		b7:SetValue(count)
	end)

	-- 8. Visibility Audit
	pcall(function()
		local b8 = CreateTestBar(-260, "8. Alpha/Shown Check", { 1, 0, 0 })
		b8:SetMinMaxValues(0, 1)
		b8:SetValue(1)
	end)

	local footer = container:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	footer:SetPoint("BOTTOM", 0, 10)
	footer:SetText("These bars test different rendering and API techniques for Midnight.")
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
