local ADDON_NAME, ns = ...

-- AceConfig options table for Flightsim
-- Replaces SettingsUI.lua with hierarchical settings

local L = Flightsim.L

-- Options table for AceConfig
local options = {
	name = "Flightsim",
	type = "group",
	childGroups = "tab", -- Use left nav tabs like ActionHud
	args = {
		general = {
			name = "General",
			type = "group",
			order = 1,
			args = {
				locked = {
					name = L["LOCK_FRAME"] or "Lock Frame",
					desc = L["LOCK_FRAME_DESC"] or "Prevents dragging the Flightsim frame.",
					type = "toggle",
					order = 1,
					get = function()
						return Flightsim.db.profile.locked
					end,
					set = function(_, v)
						Flightsim.db.profile.locked = v
					end,
				},
				appearanceHeader = {
					name = "Appearance",
					type = "header",
					order = 5,
				},
				scale = {
					name = L["SCALE"] or "Scale",
					desc = L["SCALE_DESC"] or "Overall scale of the Flightsim frame.",
					type = "range",
					order = 6,
					min = 0.5,
					max = 2.0,
					step = 0.05,
					get = function()
						return Flightsim.db.profile.scale
					end,
					set = function(_, v)
						Flightsim.db.profile.scale = v
						if FlightsimView and FlightsimView.SetScale then
							FlightsimView:SetScale(v)
						end
					end,
				},
				width = {
					name = L["BAR_WIDTH"] or "Bar Width",
					desc = L["BAR_WIDTH_DESC"] or "Width of all bars.",
					type = "range",
					order = 7,
					min = 50,
					max = 800,
					step = 10,
					get = function()
						return Flightsim.db.profile.ui.width
					end,
					set = function(_, v)
						Flightsim.db.profile.ui.width = v
						if FlightsimView and FlightsimView.SetWidth then
							FlightsimView:SetWidth(v)
						end
					end,
				},
				appearanceSpacer = {
					name = "",
					type = "description",
					order = 7.5,
					width = 0.3,
				},
				frameBackground = {
					name = "Background",
					desc = "Background color behind ability bars.",
					type = "color",
					hasAlpha = true,
					order = 8,
					get = function()
						local c = Flightsim.db.profile.colors.frame.background
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.frame.background
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.UpdateFrameColors then
							FlightsimView:UpdateFrameColors()
						end
					end,
				},
				visibilityHeader = {
					name = "Visibility",
					type = "header",
					order = 10,
				},
				hideWhenNotSkyriding = {
					name = L["ONLY_SKYRIDING"] or "Only Show When Skyriding",
					desc = L["ONLY_SKYRIDING_DESC"] or "Hides the frame when not actively skyriding (must also be flying).",
					type = "toggle",
					width = "full",
					order = 11,
					get = function()
						return Flightsim.db.profile.visibility.hideWhenNotSkyriding
					end,
					set = function(_, v)
						Flightsim.db.profile.visibility.hideWhenNotSkyriding = v
						if FlightsimView and FlightsimView.ApplyVisibility then
							FlightsimView:ApplyVisibility()
						end
					end,
				},
				-- Border section
				borderHeader = {
					name = "Border",
					type = "header",
					order = 15,
				},
				frameBorder = {
					name = "Border Color",
					desc = "Border color around the HUD frame.",
					type = "color",
					hasAlpha = true,
					order = 16,
					get = function()
						local c = Flightsim.db.profile.colors.frame.border
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.frame.border
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.UpdateFrameColors then
							FlightsimView:UpdateFrameColors()
						end
					end,
				},
				borderWidth = {
					name = "Border Width",
					desc = "Width of the border around the HUD frame (0 = no border).",
					type = "range",
					order = 17,
					min = 0,
					max = 4,
					step = 1,
					get = function()
						return Flightsim.db.profile.colors.frame.borderWidth or 0
					end,
					set = function(_, v)
						Flightsim.db.profile.colors.frame.borderWidth = v
						if FlightsimView and FlightsimView.UpdateFrameColors then
							FlightsimView:UpdateFrameColors()
						end
					end,
				},
			},
		},
		speedBar = {
			name = "Speed Bar",
			type = "group",
			order = 2,
			args = {
				height = {
					name = "Height",
					desc = L["SPEED_BAR_HEIGHT_DESC"] or "Height of the speed bar.",
					type = "range",
					order = 1,
					min = 10,
					max = 100,
					step = 2,
					get = function()
						return Flightsim.db.profile.ui.speedBarHeight
					end,
					set = function(_, v)
						Flightsim.db.profile.ui.speedBarHeight = v
						if FlightsimView and FlightsimView.RebuildLayout then
							FlightsimView:RebuildLayout()
						end
					end,
				},
				textHeader = {
					name = "Text Display",
					type = "header",
					order = 5,
				},
				fontFamily = {
					name = "Font",
					desc = "Font family for speed text.",
					type = "select",
					order = 6,
					values = {
						["Fonts\\ARIALN.TTF"] = "Arial Narrow",
						["Fonts\\FRIZQT__.TTF"] = "Friz Quadrata",
						["Fonts\\MORPHEUS.TTF"] = "Morpheus",
						["Fonts\\skurri.TTF"] = "Skurri",
					},
					get = function()
						return Flightsim.db.profile.speedBar.fontFamily or "Fonts\\ARIALN.TTF"
					end,
					set = function(_, v)
						Flightsim.db.profile.speedBar.fontFamily = v
						if FlightsimView and FlightsimView.UpdateFont then
							FlightsimView:UpdateFont()
						end
					end,
				},
				fontSize = {
					name = L["FONT_SIZE"] or "Font Size",
					desc = L["FONT_SIZE_DESC"] or "Size of the speed text.",
					type = "range",
					order = 7,
					min = 8,
					max = 48,
					step = 1,
					get = function()
						return Flightsim.db.profile.speedBar.fontSize
					end,
					set = function(_, v)
						Flightsim.db.profile.speedBar.fontSize = v
						if FlightsimView and FlightsimView.UpdateFont then
							FlightsimView:UpdateFont()
						end
					end,
				},
				fontOutline = {
					name = "Outline",
					desc = "Text outline style.",
					type = "select",
					order = 8,
					values = {
						[""] = "None",
						["OUTLINE"] = "Outline",
						["OUTLINE, THICKOUTLINE"] = "Thick Outline",
					},
					get = function()
						return Flightsim.db.profile.speedBar.fontOutline or "OUTLINE"
					end,
					set = function(_, v)
						Flightsim.db.profile.speedBar.fontOutline = v
						if FlightsimView and FlightsimView.UpdateFont then
							FlightsimView:UpdateFont()
						end
					end,
				},
				showPercent = {
					name = L["SHOW_PERCENT"] or "Show as Percentage",
					desc = L["SHOW_PERCENT_DESC"] or "Display speed as percentage instead of raw value.",
					type = "toggle",
					order = 9,
					get = function()
						return Flightsim.db.profile.speedBar.showPercent
					end,
					set = function(_, v)
						Flightsim.db.profile.speedBar.showPercent = v
					end,
				},
				sustainHeader = {
					name = "Sustain Marker",
					type = "header",
					order = 10,
				},
				showSustainMarker = {
					name = "Show Sustain Marker",
					desc = "Shows a vertical line at sustainable flight speed.",
					type = "toggle",
					order = 11,
					get = function()
						return Flightsim.db.profile.ui.showSustainMarker ~= false
					end,
					set = function(_, v)
						Flightsim.db.profile.ui.showSustainMarker = v
						if FlightsimView and FlightsimView.RebuildLayout then
							FlightsimView:RebuildLayout()
						end
					end,
				},
				sustainMarkerWidth = {
					name = L["SUSTAIN_MARKER_WIDTH"] or "Marker Width",
					desc = L["SUSTAIN_MARKER_WIDTH_DESC"] or "Width of the sustainable speed marker line.",
					type = "range",
					order = 12,
					min = 1,
					max = 5,
					step = 1,
					hidden = function()
						return Flightsim.db.profile.ui.showSustainMarker == false
					end,
					get = function()
						return Flightsim.db.profile.ui.sustainableSpeedMarkerWidth or 1
					end,
					set = function(_, v)
						Flightsim.db.profile.ui.sustainableSpeedMarkerWidth = v
						if FlightsimView and FlightsimView.RebuildLayout then
							FlightsimView:RebuildLayout()
						end
					end,
				},
				sustainMarkerAlpha = {
					name = L["SUSTAIN_MARKER_ALPHA"] or "Marker Opacity",
					desc = L["SUSTAIN_MARKER_ALPHA_DESC"] or "Opacity of the sustain speed marker (0.1-1.0).",
					type = "range",
					order = 13,
					min = 0.1,
					max = 1.0,
					step = 0.1,
					hidden = function()
						return Flightsim.db.profile.ui.showSustainMarker == false
					end,
					get = function()
						return Flightsim.db.profile.ui.sustainableSpeedMarkerAlpha or 0.2
					end,
					set = function(_, v)
						Flightsim.db.profile.ui.sustainableSpeedMarkerAlpha = v
						if FlightsimView and FlightsimView.RebuildLayout then
							FlightsimView:RebuildLayout()
						end
					end,
				},
				-- Speed bar colors moved here from Colors section
				colorsHeader = {
					name = "Colors",
					type = "header",
					order = 20,
				},
				useCustomSpeedColors = {
					name = "Use Custom Colors",
					desc = "Enable custom speed bar colors instead of default gradient.",
					type = "toggle",
					order = 21,
					get = function()
						return Flightsim.db.profile.colors.speedBar.useCustom
					end,
					set = function(_, v)
						Flightsim.db.profile.colors.speedBar.useCustom = v
						if FlightsimView and FlightsimView.InvalidateColorCache then
							FlightsimView:InvalidateColorCache()
						end
					end,
				},
				speedStartColor = {
					name = "Low Speed (0%)",
					desc = "Color at minimum speed.",
					type = "color",
					hasAlpha = true,
					order = 22,
					hidden = function()
						return not Flightsim.db.profile.colors.speedBar.useCustom
					end,
					get = function()
						local c = Flightsim.db.profile.colors.speedBar.gradient.start
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.speedBar.gradient.start
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.InvalidateColorCache then
							FlightsimView:InvalidateColorCache()
						end
					end,
				},
				speedMiddleColor = {
					name = "Mid Speed (50%)",
					desc = "Color at half speed.",
					type = "color",
					hasAlpha = true,
					order = 23,
					hidden = function()
						return not Flightsim.db.profile.colors.speedBar.useCustom
					end,
					get = function()
						local c = Flightsim.db.profile.colors.speedBar.gradient.middle
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.speedBar.gradient.middle
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.InvalidateColorCache then
							FlightsimView:InvalidateColorCache()
						end
					end,
				},
				speedEndColor = {
					name = "High Speed (100%)",
					desc = "Color at maximum speed.",
					type = "color",
					hasAlpha = true,
					order = 24,
					hidden = function()
						return not Flightsim.db.profile.colors.speedBar.useCustom
					end,
					get = function()
						local c = Flightsim.db.profile.colors.speedBar.gradient.finish
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.speedBar.gradient.finish
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.InvalidateColorCache then
							FlightsimView:InvalidateColorCache()
						end
					end,
				},
				speedColorTip = {
					name = "|cff888888Tip: Set all three colors the same for a solid color bar.|r",
					type = "description",
					order = 25,
					hidden = function()
						return not Flightsim.db.profile.colors.speedBar.useCustom
					end,
				},
			},
		},
		accelBar = {
			name = "Acceleration Bar",
			type = "group",
			order = 3,
			args = {
				description = {
					name = "The acceleration bar shows whether you are speeding up or slowing down. "
						.. "When gaining speed, the bar fills right. When losing speed, it fills left.\n\n"
						.. "It does not show pitch, altitude, or direction - only your rate of speed change.",
					type = "description",
					order = 0,
					fontSize = "medium",
				},
				height = {
					name = "Height",
					desc = L["ACCEL_BAR_HEIGHT_DESC"] or "Height of the acceleration indicator bar.",
					type = "range",
					order = 1,
					min = 1,
					max = 10,
					step = 1,
					get = function()
						return Flightsim.db.profile.ui.accelBarHeight
					end,
					set = function(_, v)
						Flightsim.db.profile.ui.accelBarHeight = v
						if FlightsimView and FlightsimView.RebuildLayout then
							FlightsimView:RebuildLayout()
						end
					end,
				},
				-- Acceleration bar colors moved here from Colors section
				colorsHeader = {
					name = "Colors",
					type = "header",
					order = 10,
				},
				useDynamicAccelColors = {
					name = "Dynamic Colors",
					desc = "Change color based on acceleration direction.",
					type = "toggle",
					order = 11,
					get = function()
						return Flightsim.db.profile.colors.accelBar.useDynamic
					end,
					set = function(_, v)
						Flightsim.db.profile.colors.accelBar.useDynamic = v
					end,
				},
				decelColor = {
					name = "Deceleration",
					desc = "Color when losing speed.",
					type = "color",
					hasAlpha = true,
					order = 12,
					hidden = function()
						return not Flightsim.db.profile.colors.accelBar.useDynamic
					end,
					get = function()
						local c = Flightsim.db.profile.colors.accelBar.decel
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.accelBar.decel
						c.r, c.g, c.b, c.a = r, g, b, a
					end,
				},
				accelColor = {
					name = "Acceleration",
					desc = "Color when gaining speed.",
					type = "color",
					hasAlpha = true,
					order = 13,
					hidden = function()
						return not Flightsim.db.profile.colors.accelBar.useDynamic
					end,
					get = function()
						local c = Flightsim.db.profile.colors.accelBar.accel
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.accelBar.accel
						c.r, c.g, c.b, c.a = r, g, b, a
					end,
				},
			},
		},
		abilityBars = {
			name = "Ability Bars",
			type = "group",
			order = 4,
			args = {
				height = {
					name = "Height",
					desc = L["ABILITY_BAR_HEIGHT_DESC"] or "Height of ability cooldown bars.",
					type = "range",
					order = 1,
					min = 2,
					max = 20,
					step = 1,
					get = function()
						return Flightsim.db.profile.ui.abilityBarHeight
					end,
					set = function(_, v)
						Flightsim.db.profile.ui.abilityBarHeight = v
						if FlightsimView and FlightsimView.RebuildLayout then
							FlightsimView:RebuildLayout()
						end
					end,
				},
				barGap = {
					name = L["BAR_GAP"] or "Bar Gap",
					desc = L["BAR_GAP_DESC"] or "Gap between ability bar sections.",
					type = "range",
					order = 2,
					min = 0,
					max = 10,
					step = 1,
					get = function()
						return Flightsim.db.profile.ui.barGap
					end,
					set = function(_, v)
						Flightsim.db.profile.ui.barGap = v
						if FlightsimView and FlightsimView.RebuildLayout then
							FlightsimView:RebuildLayout()
						end
					end,
				},
				visibilityHeader = {
					name = "Visibility",
					type = "header",
					order = 10,
				},
				showSurgeForward = {
					name = L["SHOW_SURGE_FORWARD"] or "Show Surge Forward",
					desc = L["SHOW_SURGE_FORWARD_DESC"] or "Show Surge Forward charge bar (6 charges).",
					type = "toggle",
					order = 11,
					get = function()
						return Flightsim.db.profile.abilityBars.showSurgeForward
					end,
					set = function(_, v)
						Flightsim.db.profile.abilityBars.showSurgeForward = v
						if FlightsimView and FlightsimView.RebuildLayout then
							FlightsimView:RebuildLayout()
						end
					end,
				},
				showSecondWind = {
					name = L["SHOW_SECOND_WIND"] or "Show Second Wind",
					desc = L["SHOW_SECOND_WIND_DESC"] or "Show Second Wind charge bar (3 charges).",
					type = "toggle",
					order = 12,
					get = function()
						return Flightsim.db.profile.abilityBars.showSecondWind
					end,
					set = function(_, v)
						Flightsim.db.profile.abilityBars.showSecondWind = v
						if FlightsimView and FlightsimView.RebuildLayout then
							FlightsimView:RebuildLayout()
						end
					end,
				},
				showWhirlingSurge = {
					name = L["SHOW_WHIRLING_SURGE"] or "Show Whirling Surge",
					desc = L["SHOW_WHIRLING_SURGE_DESC"] or "Show Whirling Surge cooldown bar.",
					type = "toggle",
					order = 13,
					get = function()
						return Flightsim.db.profile.abilityBars.showWhirlingSurge
					end,
					set = function(_, v)
						Flightsim.db.profile.abilityBars.showWhirlingSurge = v
						if FlightsimView and FlightsimView.RebuildLayout then
							FlightsimView:RebuildLayout()
						end
					end,
				},
				-- Ability bar colors moved here from Colors section
				colorsHeader = {
					name = "Colors",
					type = "header",
					order = 20,
				},
				surgeForwardColor = {
					name = "Surge Forward",
					desc = "Color for Surge Forward charge bar.",
					type = "color",
					hasAlpha = true,
					order = 21,
					get = function()
						local c = Flightsim.db.profile.colors.abilities.surgeForward
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.abilities.surgeForward
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.InvalidateColorCache then
							FlightsimView:InvalidateColorCache()
						end
					end,
				},
				secondWindColor = {
					name = "Second Wind",
					desc = "Color for Second Wind charge bar.",
					type = "color",
					hasAlpha = true,
					order = 22,
					get = function()
						local c = Flightsim.db.profile.colors.abilities.secondWind
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.abilities.secondWind
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.InvalidateColorCache then
							FlightsimView:InvalidateColorCache()
						end
					end,
				},
				whirlingSurgeColor = {
					name = "Whirling Surge",
					desc = "Color for Whirling Surge cooldown bar.",
					type = "color",
					hasAlpha = true,
					order = 23,
					get = function()
						local c = Flightsim.db.profile.colors.abilities.whirlingSurge
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.abilities.whirlingSurge
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.InvalidateColorCache then
							FlightsimView:InvalidateColorCache()
						end
					end,
				},
				-- Background colors header
				bgColorsHeader = {
					name = "Background Colors",
					type = "header",
					order = 30,
				},
				surgeForwardFrameBg = {
					name = "Surge Forward Row Background",
					desc = "Background color for the entire Surge Forward row (behind all charges). Set alpha to 0 for transparent.",
					type = "color",
					hasAlpha = true,
					order = 31,
					get = function()
						local c = Flightsim.db.profile.colors.abilities.surgeForwardFrameBg
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.abilities.surgeForwardFrameBg
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.UpdateAbilityColors then
							FlightsimView:UpdateAbilityColors()
						end
					end,
				},
				surgeForwardBarBg = {
					name = "Surge Forward Bar Background",
					desc = "Background color for individual Surge Forward charge bars (visible when recharging).",
					type = "color",
					hasAlpha = true,
					order = 32,
					get = function()
						local c = Flightsim.db.profile.colors.abilities.surgeForwardBarBg
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.abilities.surgeForwardBarBg
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.UpdateAbilityColors then
							FlightsimView:UpdateAbilityColors()
						end
					end,
				},
				secondWindFrameBg = {
					name = "Second Wind Row Background",
					desc = "Background color for the entire Second Wind row (behind all charges). Set alpha to 0 for transparent.",
					type = "color",
					hasAlpha = true,
					order = 33,
					get = function()
						local c = Flightsim.db.profile.colors.abilities.secondWindFrameBg
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.abilities.secondWindFrameBg
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.UpdateAbilityColors then
							FlightsimView:UpdateAbilityColors()
						end
					end,
				},
				secondWindBarBg = {
					name = "Second Wind Bar Background",
					desc = "Background color for individual Second Wind charge bars (visible when recharging).",
					type = "color",
					hasAlpha = true,
					order = 34,
					get = function()
						local c = Flightsim.db.profile.colors.abilities.secondWindBarBg
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.abilities.secondWindBarBg
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.UpdateAbilityColors then
							FlightsimView:UpdateAbilityColors()
						end
					end,
				},
				whirlingSurgeBarBg = {
					name = "Whirling Surge Bar Background",
					desc = "Background color for Whirling Surge bar (visible when on cooldown).",
					type = "color",
					hasAlpha = true,
					order = 35,
					get = function()
						local c = Flightsim.db.profile.colors.abilities.whirlingSurgeBarBg
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.abilities.whirlingSurgeBarBg
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.UpdateAbilityColors then
							FlightsimView:UpdateAbilityColors()
						end
					end,
				},
			},
		},
		profiles = nil, -- Populated at runtime with AceDBOptions
	},
}

-- Module initialization (called from Flightsim.lua after AceDB is ready)
function ns:InitializeSettings()
	-- Register options with AceConfig
	LibStub("AceConfig-3.0"):RegisterOptionsTable("Flightsim", options)

	-- Add to Blizzard Interface Options
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Flightsim", "Flightsim")

	-- Add profiles tab
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(Flightsim.db)

	-- Register slash commands - only open settings if no args, call Config.lua's handler for commands
	LibStub("AceConsole-3.0"):RegisterChatCommand("flightsim", function(msg)
		if not msg or msg == "" then
			LibStub("AceConfigDialog-3.0"):Open("Flightsim")
		elseif SlashCmdList["FLIGHTSIM"] then
			SlashCmdList["FLIGHTSIM"](msg)
		end
	end)
	LibStub("AceConsole-3.0"):RegisterChatCommand("fs", function(msg)
		if not msg or msg == "" then
			LibStub("AceConfigDialog-3.0"):Open("Flightsim")
		elseif SlashCmdList["FLIGHTSIM"] then
			SlashCmdList["FLIGHTSIM"](msg)
		end
	end)
end

ns.options = options
