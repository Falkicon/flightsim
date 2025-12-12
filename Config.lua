FlightsimConfig = FlightsimConfig or {}

SLASH_FLIGHTSIM1 = "/flightsim"
SLASH_FLIGHTSIM2 = "/fs"
SlashCmdList["FLIGHTSIM"] = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")

	if not FlightsimDB or not FlightsimDB.profile then
		print("Flightsim: not initialized yet.")
		return
	end

	if msg == "lock" then
		FlightsimDB.profile.locked = true
		print("Flightsim: locked")
		return
	elseif msg == "unlock" then
		FlightsimDB.profile.locked = false
		print("Flightsim: unlocked (drag frame to move)")
		return
	elseif msg:match("^scale%s+") then
		local val = tonumber(msg:match("^scale%s+([%d%.]+)$"))
		if not val then
			print("Flightsim: usage: /flightsim scale 1.0")
			return
		end
		if FlightsimUI and FlightsimUI.SetScale then
			FlightsimUI:SetScale(val)
		end
		print("Flightsim: scale set")
		return
	elseif msg:match("^width%s+") then
		local val = tonumber(msg:match("^width%s+([%d%.]+)$"))
		if not val then
			print("Flightsim: usage: /flightsim width 320")
			return
		end
		if FlightsimUI and FlightsimUI.SetWidth then
			FlightsimUI:SetWidth(val)
		end
		print("Flightsim: width set")
		return
	elseif msg:match("^barmax%s+") then
		local val = tonumber(msg:match("^barmax%s+([%d%.]+)$"))
		if not val then
			print("Flightsim: usage: /flightsim barmax 930")
			return
		end
		if FlightsimUI and FlightsimUI.SetSpeedBarMax then
			FlightsimUI:SetSpeedBarMax(val)
		end
		print("Flightsim: speed bar max set")
		return
	elseif msg:match("^sustainable%s+") or msg:match("^optimal%s+") then
		local val = tonumber(msg:match("^sustainable%s+([%d%.]+)$") or msg:match("^optimal%s+([%d%.]+)$"))
		if val == nil then
			print("Flightsim: usage: /flightsim sustainable 0   (0 hides marker)")
			return
		end
		if FlightsimUI and FlightsimUI.SetSustainableSpeed then
			FlightsimUI:SetSustainableSpeed(val)
		end
		print("Flightsim: sustainable speed marker set")
		return
	elseif msg == "hidenot" then
		FlightsimDB.profile.visibility.hideWhenNotSkyriding = true
		FlightsimDB.profile.visibility.hideWhileSkyriding = false
		print("Flightsim: will hide when NOT skyriding")
		return
	elseif msg == "hidesky" then
		FlightsimDB.profile.visibility.hideWhileSkyriding = true
		FlightsimDB.profile.visibility.hideWhenNotSkyriding = false
		print("Flightsim: will hide while skyriding")
		return
	elseif msg == "showalways" then
		FlightsimDB.profile.visibility.hideWhileSkyriding = false
		FlightsimDB.profile.visibility.hideWhenNotSkyriding = false
		print("Flightsim: will always show")
		return
	elseif msg:match("^toggle%s+") then
		local query = msg:match("^toggle%s+(.+)$")
		local found
		for _, token in ipairs(FlightsimDB.profile.abilities.order or {}) do
			if token:lower():find(query, 1, true) then
				local enabled = FlightsimDB.profile.abilities.enabled[token] ~= false
				FlightsimDB.profile.abilities.enabled[token] = not enabled
				print(string.format("Flightsim: %s %s", token, (not enabled) and "enabled" or "disabled"))
				found = true
				break
			end
		end
		if not found then
			print("Flightsim: ability not found. Try /flightsim list")
		else
			if FlightsimUI and FlightsimUI.RebuildAbilityRows then
				FlightsimUI:RebuildAbilityRows()
			end
		end
		return
	elseif msg == "list" then
		print("Flightsim abilities:")
		for i, token in ipairs(FlightsimDB.profile.abilities.order or {}) do
			local enabled = FlightsimDB.profile.abilities.enabled[token] ~= false
			print(string.format("  %d. %s [%s]", i, token, enabled and "ON" or "OFF"))
		end
		return
	elseif msg:match("^move%s+") then
		local a, b = msg:match("^move%s+(.+)%s+(%d+)$")
		local newIndex = tonumber(b)
		if not (a and newIndex) then
			print("Flightsim: usage: /flightsim move <ability> <index>")
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
			print("Flightsim: ability not found. Try /flightsim list")
			return
		end
		newIndex = math.max(1, math.min(#order, newIndex))
		local item = table.remove(order, fromIndex)
		table.insert(order, newIndex, item)
		FlightsimDB.profile.abilities.order = order
		if FlightsimUI and FlightsimUI.RebuildAbilityRows then
			FlightsimUI:RebuildAbilityRows()
		end
		print("Flightsim: ability order updated")
		return
	elseif msg == "debug" then
		if FlightsimUI and FlightsimUI.DebugDump then
			FlightsimUI:DebugDump()
		else
			print("Flightsim: debug not available (UI not initialized yet)")
		end
		return
	elseif msg == "status" then
		if FlightsimUI and FlightsimUI.Status then
			FlightsimUI:Status()
		else
			print("Flightsim: status not available (UI not initialized yet)")
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
		print("Flightsim: position/scale reset")
		return
	end

	print("Flightsim commands:")
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
