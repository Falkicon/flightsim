local _, ns = ...

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
			name = L["SETTINGS_GENERAL"],
			type = "group",
			order = 1,
			args = {
				locked = {
					name = L["LOCK_FRAME"],
					desc = L["LOCK_FRAME_DESC"],
					type = "toggle",
					order = 1,
					get = function()
						return Flightsim.db.profile.locked
					end,
					set = function(_, v)
						Flightsim.db.profile.locked = v
						if FlightsimView and FlightsimView.SetClickThrough then
							FlightsimView:SetClickThrough(v)
						end
					end,
				},
				appearanceHeader = {
					name = L["SETTINGS_APPEARANCE"],
					type = "header",
					order = 5,
				},
				scale = {
					name = L["SCALE"],
					desc = L["SCALE_DESC"],
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
					name = L["BAR_WIDTH"],
					desc = L["BAR_WIDTH_DESC"],
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
					name = L["SETTINGS_BACKGROUND"],
					desc = L["SETTINGS_BACKGROUND_DESC"],
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
					name = L["SETTINGS_VISIBILITY"],
					type = "header",
					order = 10,
				},
				hideWhenNotSkyriding = {
					name = L["ONLY_SKYRIDING"],
					desc = L["ONLY_SKYRIDING_DESC"],
					type = "toggle",
					width = 1.2,
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
				showWhenGroundMounted = {
					name = L["SHOW_GROUND_MOUNTED"],
					desc = L["SHOW_GROUND_MOUNTED_DESC"],
					type = "toggle",
					width = 1.2,
					order = 12,
					disabled = function()
						return not Flightsim.db.profile.visibility.hideWhenNotSkyriding
					end,
					get = function()
						return Flightsim.db.profile.visibility.showWhenGroundMounted
					end,
					set = function(_, v)
						Flightsim.db.profile.visibility.showWhenGroundMounted = v
						if FlightsimView and FlightsimView.ApplyVisibility then
							FlightsimView:ApplyVisibility()
						end
					end,
				},
				-- Border section
				borderHeader = {
					name = L["SETTINGS_BORDER"],
					type = "header",
					order = 15,
				},
				frameBorder = {
					name = L["SETTINGS_BORDER_COLOR"],
					desc = L["SETTINGS_BORDER_COLOR_DESC"],
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
					name = L["SETTINGS_BORDER_WIDTH"],
					desc = L["SETTINGS_BORDER_WIDTH_DESC"],
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
			name = L["SETTINGS_SPEED_BAR"],
			type = "group",
			order = 2,
			args = {
				height = {
					name = L["HEIGHT"],
					desc = L["SPEED_BAR_HEIGHT_DESC"],
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
					name = L["SETTINGS_TEXT_DISPLAY"],
					type = "header",
					order = 5,
				},
				fontFamily = {
					name = L["SETTINGS_FONT"],
					desc = L["SETTINGS_FONT_DESC"],
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
					name = L["FONT_SIZE"],
					desc = L["FONT_SIZE_DESC"],
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
					name = L["SETTINGS_OUTLINE"],
					desc = L["SETTINGS_OUTLINE_DESC"],
					type = "select",
					order = 8,
					values = {
						[""] = L["SETTINGS_NONE"],
						["OUTLINE"] = L["SETTINGS_OUTLINE"],
						["OUTLINE, THICKOUTLINE"] = L["SETTINGS_THICK_OUTLINE"],
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
					name = L["SHOW_PERCENT"],
					desc = L["SHOW_PERCENT_DESC"],
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
					name = L["SETTINGS_SUSTAIN_MARKER"],
					type = "header",
					order = 10,
				},
				showSustainMarker = {
					name = L["SETTINGS_SHOW_SUSTAIN_MARKER"],
					desc = L["SETTINGS_SUSTAIN_MARKER_DESC"],
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
					name = L["SUSTAIN_MARKER_WIDTH"],
					desc = L["SUSTAIN_MARKER_WIDTH_DESC"],
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
					name = L["SUSTAIN_MARKER_ALPHA"],
					desc = L["SUSTAIN_MARKER_ALPHA_DESC"],
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
					name = L["SETTINGS_COLORS"],
					type = "header",
					order = 20,
				},
				useCustomSpeedColors = {
					name = L["SETTINGS_USE_CUSTOM_COLORS"],
					desc = L["SETTINGS_CUSTOM_COLORS_DESC"],
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
					name = L["SETTINGS_LOW_SPEED_COLOR"],
					desc = L["SETTINGS_LOW_SPEED_COLOR_DESC"],
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
					name = L["SETTINGS_MID_SPEED_COLOR"],
					desc = L["SETTINGS_MID_SPEED_COLOR_DESC"],
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
					name = L["SETTINGS_HIGH_SPEED_COLOR"],
					desc = L["SETTINGS_HIGH_SPEED_COLOR_DESC"],
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
					name = L["SETTINGS_SOLID_COLOR_TIP"],
					type = "description",
					order = 25,
					hidden = function()
						return not Flightsim.db.profile.colors.speedBar.useCustom
					end,
				},
			},
		},
		accelBar = {
			name = L["SETTINGS_ACCELERATION_BAR"],
			type = "group",
			order = 3,
			args = {
				description = {
					name = L["SETTINGS_ACCELERATION_DESCRIPTION"],
					type = "description",
					order = 0,
					fontSize = "medium",
				},
				height = {
					name = L["HEIGHT"],
					desc = L["ACCEL_BAR_HEIGHT_DESC"],
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
					name = L["SETTINGS_COLORS"],
					type = "header",
					order = 10,
				},
				useDynamicAccelColors = {
					name = L["SETTINGS_DYNAMIC_COLORS"],
					desc = L["SETTINGS_DYNAMIC_COLORS_DESC"],
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
					name = L["SETTINGS_DECELERATION"],
					desc = L["SETTINGS_DECELERATION_COLOR_DESC"],
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
					name = L["SETTINGS_ACCELERATION"],
					desc = L["SETTINGS_ACCELERATION_COLOR_DESC"],
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
			name = L["SETTINGS_ABILITY_BARS"],
			type = "group",
			order = 4,
			args = {
				height = {
					name = L["HEIGHT"],
					desc = L["ABILITY_BAR_HEIGHT_DESC"],
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
					name = L["BAR_GAP"],
					desc = L["BAR_GAP_DESC"],
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
					name = L["SETTINGS_VISIBILITY"],
					type = "header",
					order = 10,
				},
				showSurgeForward = {
					name = L["SHOW_SURGE_FORWARD"],
					desc = L["SHOW_SURGE_FORWARD_DESC"],
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
					name = L["SHOW_SECOND_WIND"],
					desc = L["SHOW_SECOND_WIND_DESC"],
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
					name = L["SHOW_WHIRLING_SURGE"],
					desc = L["SHOW_WHIRLING_SURGE_DESC"],
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
					name = L["SETTINGS_COLORS"],
					type = "header",
					order = 20,
				},
				surgeForwardColor = {
					name = L["SETTINGS_SURGE_FORWARD"],
					desc = L["SETTINGS_SURGE_COLOR_DESC"],
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
					name = L["SETTINGS_SECOND_WIND"],
					desc = L["SETTINGS_WIND_COLOR_DESC"],
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
					name = L["SETTINGS_WHIRLING_SURGE"],
					desc = L["SETTINGS_WHIRL_COLOR_DESC"],
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
					name = L["SETTINGS_BACKGROUND_COLORS"],
					type = "header",
					order = 30,
				},
				surgeForwardFrameBg = {
					name = L["SETTINGS_SURGE_ROW_BG"],
					desc = L["SETTINGS_SURGE_ROW_BG_DESC"],
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
					name = L["SETTINGS_SURGE_BAR_BG"],
					desc = L["SETTINGS_SURGE_BAR_BG_DESC"],
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
					name = L["SETTINGS_WIND_ROW_BG"],
					desc = L["SETTINGS_WIND_ROW_BG_DESC"],
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
					name = L["SETTINGS_WIND_BAR_BG"],
					desc = L["SETTINGS_WIND_BAR_BG_DESC"],
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
					name = L["SETTINGS_WHIRL_BAR_BG"],
					desc = L["SETTINGS_WHIRL_BAR_BG_DESC"],
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
		buffIndicators = {
			name = L["SETTINGS_BUFF_INDICATORS"],
			type = "group",
			order = 5,
			args = {
				description = {
					name = L["SETTINGS_BUFF_DESCRIPTION"],
					type = "description",
					order = 0,
					fontSize = "medium",
				},
				visibilityHeader = {
					name = L["SETTINGS_VISIBILITY"],
					type = "header",
					order = 1,
				},
				showThrillOfTheSkies = {
					name = L["SHOW_THRILL_OF_THE_SKIES"],
					desc = L["SHOW_THRILL_OF_THE_SKIES_DESC"],
					type = "toggle",
					order = 2,
					get = function()
						return Flightsim.db.profile.buffIndicators.showThrillOfTheSkies
					end,
					set = function(_, v)
						Flightsim.db.profile.buffIndicators.showThrillOfTheSkies = v
					end,
				},
				showGroundSkimming = {
					name = L["SHOW_GROUND_SKIMMING"],
					desc = L["SHOW_GROUND_SKIMMING_DESC"],
					type = "toggle",
					order = 3,
					get = function()
						return Flightsim.db.profile.buffIndicators.showGroundSkimming
					end,
					set = function(_, v)
						Flightsim.db.profile.buffIndicators.showGroundSkimming = v
					end,
				},
				sizeHeader = {
					name = L["SETTINGS_SIZE"],
					type = "header",
					order = 5,
				},
				indicatorSize = {
					name = L["SETTINGS_INDICATOR_SIZE"],
					desc = L["SETTINGS_INDICATOR_SIZE_DESC"],
					type = "range",
					order = 6,
					min = 4,
					max = 24,
					step = 1,
					get = function()
						return Flightsim.db.profile.buffIndicators.indicatorSize or 8
					end,
					set = function(_, v)
						Flightsim.db.profile.buffIndicators.indicatorSize = v
						if FlightsimView and FlightsimView.CreateBuffIndicators then
							FlightsimView:CreateBuffIndicators()
						end
					end,
				},
				colorsHeader = {
					name = L["SETTINGS_COLORS"],
					type = "header",
					order = 10,
				},
				thrillColor = {
					name = L["SHOW_THRILL_OF_THE_SKIES"],
					desc = L["SETTINGS_THRILL_COLOR_DESC"],
					type = "color",
					hasAlpha = true,
					order = 11,
					get = function()
						local c = Flightsim.db.profile.colors.buffIndicators.thrillOfTheSkies
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.buffIndicators.thrillOfTheSkies
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.UpdateBuffIndicatorColors then
							FlightsimView:UpdateBuffIndicatorColors()
						end
					end,
				},
				skimColor = {
					name = L["SHOW_GROUND_SKIMMING"],
					desc = L["SETTINGS_SKIM_COLOR_DESC"],
					type = "color",
					hasAlpha = true,
					order = 12,
					get = function()
						local c = Flightsim.db.profile.colors.buffIndicators.groundSkimming
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.buffIndicators.groundSkimming
						c.r, c.g, c.b, c.a = r, g, b, a
						if FlightsimView and FlightsimView.UpdateBuffIndicatorColors then
							FlightsimView:UpdateBuffIndicatorColors()
						end
					end,
				},
			},
		},
		pitchBar = {
			name = L["PITCH_BAR"],
			type = "group",
			order = 6,
			hidden = true, -- Hidden until pitch estimation is refined
			args = {
				description = {
					name = L["SETTINGS_PITCH_DESCRIPTION"],
					type = "description",
					order = 0,
					fontSize = "medium",
				},
				enabled = {
					name = L["PITCH_BAR_ENABLED"],
					desc = L["PITCH_BAR_ENABLED_DESC"],
					type = "toggle",
					order = 1,
					width = "full",
					get = function()
						return Flightsim.db.profile.pitchBar.enabled
					end,
					set = function(_, v)
						Flightsim.db.profile.pitchBar.enabled = v
						if FlightsimView and FlightsimView.UpdateContainerSize then
							FlightsimView:UpdateContainerSize()
						end
					end,
				},
				sizeHeader = {
					name = L["SETTINGS_SIZE"],
					type = "header",
					order = 5,
				},
				height = {
					name = L["PITCH_BAR_HEIGHT"],
					desc = L["SETTINGS_PITCH_HEIGHT_DESC"],
					type = "range",
					order = 6,
					min = 1,
					max = 8,
					step = 1,
					get = function()
						return Flightsim.db.profile.ui.pitchBarHeight or 2
					end,
					set = function(_, v)
						Flightsim.db.profile.ui.pitchBarHeight = v
						if FlightsimView and FlightsimView.pitchFrame then
							FlightsimView.pitchFrame:SetHeight(v)
							if FlightsimView.pitchBar then
								FlightsimView.pitchBar:SetHeight(v)
							end
							FlightsimView:UpdateContainerSize()
						end
					end,
				},
				colorsHeader = {
					name = L["SETTINGS_COLORS"],
					type = "header",
					order = 10,
				},
				useDynamic = {
					name = L["PITCH_DYNAMIC_COLOR"],
					desc = L["SETTINGS_PITCH_DYNAMIC_DESC"],
					type = "toggle",
					order = 11,
					get = function()
						return Flightsim.db.profile.colors.pitchBar.useDynamic
					end,
					set = function(_, v)
						Flightsim.db.profile.colors.pitchBar.useDynamic = v
					end,
				},
				divingColor = {
					name = L["PITCH_COLOR_DIVING"],
					desc = L["SETTINGS_DIVING_COLOR_DESC"],
					type = "color",
					hasAlpha = true,
					order = 12,
					get = function()
						local c = Flightsim.db.profile.colors.pitchBar.diving
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.pitchBar.diving
						c.r, c.g, c.b, c.a = r, g, b, a
					end,
				},
				climbingColor = {
					name = L["PITCH_COLOR_CLIMBING"],
					desc = L["SETTINGS_CLIMBING_COLOR_DESC"],
					type = "color",
					hasAlpha = true,
					order = 13,
					get = function()
						local c = Flightsim.db.profile.colors.pitchBar.climbing
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = Flightsim.db.profile.colors.pitchBar.climbing
						c.r, c.g, c.b, c.a = r, g, b, a
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
	local blizPanel = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Flightsim", "Flightsim")

	-- Hook OnShow to force refresh (fixes controls not showing values initially)
	if blizPanel then
		blizPanel:HookScript("OnShow", function()
			C_Timer.After(0, function()
				LibStub("AceConfigRegistry-3.0"):NotifyChange("Flightsim")
			end)
		end)
	end

	-- Add profiles tab
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(Flightsim.db)

	-- Helper to open dialog and force refresh (fixes controls not showing values initially)
	local function OpenSettings()
		LibStub("AceConfigDialog-3.0"):Open("Flightsim")
		-- Force refresh on next frame to ensure controls display their values
		C_Timer.After(0, function()
			LibStub("AceConfigRegistry-3.0"):NotifyChange("Flightsim")
		end)
	end

	-- Register both aliases once, routing subcommands through Config.lua.
	local function HandleCommand(msg)
		if not msg or msg:match("^%s*$") then
			OpenSettings()
		elseif Flightsim.HandleSlashCommand then
			Flightsim.HandleSlashCommand(msg)
		end
	end
	LibStub("AceConsole-3.0"):RegisterChatCommand("flightsim", HandleCommand)
	LibStub("AceConsole-3.0"):RegisterChatCommand("fs", HandleCommand)
end

ns.options = options
