-- Flightsim pure-logic regression tests.
--
-- This file is intentionally Busted-compatible so Mechanic's sandbox.test can
-- load it, but it has no WoW UI dependency. Run it through Tests/run.lua for
-- an offline check without LuaRocks/Busted.

local FenCore = dofile("Tests/bootstrap.lua")
local Logic = _G.FlightsimLogic

local function assert_near(expected, actual, tolerance)
	assert.is_true(math.abs(expected - actual) <= (tolerance or 0.0001))
end

describe("FenCore foundation", function()
	it("loads the required domains and catalog", function()
		assert.is_not_nil(FenCore.ActionResult)
		assert.is_not_nil(FenCore.Catalog)
		assert.is_not_nil(FenCore.Math)
		assert.is_not_nil(FenCore.Charges)
		assert.is_not_nil(FenCore.Cooldowns)
		assert.is_not_nil(FenCore.Color)
		assert.is_not_nil(FenCore.Secrets)
		assert.is_not_nil(FenCore.Progress)
		assert.is_not_nil(FenCore.Text)
		assert.is_not_nil(FenCore.Time)
		assert.is_not_nil(FenCore.Catalog:GetInfo("Math", "Clamp"))
	end)

	it("supports success, error, unwrap, and map results", function()
		local Result = FenCore.ActionResult
		local success = Result.success({ value = 2 })
		assert.is_true(Result.isSuccess(success))
		assert.same({ value = 2 }, Result.unwrap(success))
		assert.same(
			{ value = 4 },
			Result.unwrap(Result.map(success, function(data)
				return { value = data.value * 2 }
			end))
		)

		local failure = Result.error("BAD_INPUT", "invalid")
		assert.is_true(Result.isError(failure))
		assert.equals("BAD_INPUT", Result.getErrorCode(failure))
		assert.is_nil(Result.unwrap(failure))
	end)
end)

describe("FenCore domains", function()
	it("clamps, fractions, and curves values", function()
		assert.equals(0, FenCore.Math.Clamp(-1, 0, 10))
		assert.equals(10, FenCore.Math.Clamp(11, 0, 10))
		assert.equals(0.75, FenCore.Math.ToFraction(75, 100))
		assert.equals(0, FenCore.Math.ToFraction(-1, 100))
		assert_near(0.5, FenCore.Math.ApplyCurve(0.25))
		assert_near(-0.5, FenCore.Math.ApplyCurve(-0.25))
	end)

	it("calculates a partially recharging charge set", function()
		local result = FenCore.Charges.CalculateAll({
			currentCharges = 2,
			maxCharges = 3,
			chargeStart = 100,
			chargeDuration = 20,
			now = 110,
		})
		assert.is_true(result.success)
		assert.is_false(result.data.allFull)
		assert.is_true(result.data.anyRecharging)
		assert.equals(1, result.data.charges[1].fill)
		assert.equals(1, result.data.charges[2].fill)
		assert_near(0.5, result.data.charges[3].fill)
		assert.is_true(result.data.charges[3].isRecharging)
	end)

	it("calculates cooldown progress and readiness", function()
		local result = FenCore.Cooldowns.CalculateProgress(100, 30, 115)
		assert.is_true(result.success)
		assert_near(0.5, result.data.progress)
		assert.equals(15, result.data.remaining)
		assert.is_true(result.data.isOnCooldown)
		assert.is_false(FenCore.Cooldowns.IsReady(100, 30, 115))
		assert.is_true(FenCore.Cooldowns.IsReady(100, 30, 130))
		assert.equals(0, FenCore.Cooldowns.GetRemaining(100, 30, 140))
	end)

	it("converts and interpolates colors", function()
		local red = FenCore.Color.HexToRGB("#FF0000")
		assert.same({ r = 1, g = 0, b = 0, a = 1 }, red)
		assert.equals("FF0000", FenCore.Color.RGBToHex(red))
		local middle = FenCore.Color.Lerp(red, { r = 0, g = 0, b = 1 }, 0.5)
		assert_near(0.5, middle.r)
		assert_near(0.5, middle.b)
	end)

	it("formats common text and durations", function()
		assert.equals("1,234,567", FenCore.Text.FormatNumber(1234567))
		assert.equals("1.2M", FenCore.Text.FormatCompact(1234567))
		assert.equals("2 items", FenCore.Text.Pluralize(2, "item"))
		assert.equals("1 hour 1 min 1 sec", FenCore.Time.FormatDuration(3661))
		local seconds = FenCore.Time.ParseDuration("1h 30m")
		assert.equals(5400, seconds)
		assert.equals("1:30", FenCore.Time.FormatCooldown(90))
	end)
end)

describe("Flightsim logic", function()
	it("calculates zone-aware speed state", function()
		local Speed = Logic.Speed
		assert.is_true(Speed.IsDragonIslesMap(1978))
		assert.is_false(Speed.IsDragonIslesMap(9999))
		assert.equals(1, Speed.GetZoneModifier(1978))
		assert.equals(Speed.OLD_WORLD_MODIFIER, Speed.GetZoneModifier(nil))
		assert.equals(200, Speed.CalculatePercentage(14, 7))

		local output = {}
		local result = Speed.Calculate({
			rawSpeed = 14,
			zoneModifier = 1,
			configuredMax = 1500,
		}, output)
		assert.is_true(result.success)
		assert.equals(output, result.data)
		assert.equals(14, result.data.rawSpeed)
		assert.equals(1500, result.data.effectiveMax)
		assert.is_true(result.data.showMarker)
	end)

	it("classifies acceleration and bar direction", function()
		local Acceleration = Logic.Acceleration
		assert.equals(5, Acceleration.CalculateDelta(10, 5))
		local normalized, curved, direction = Acceleration.NormalizeAndCurve(30)
		assert.equals(1, normalized)
		assert.equals(1, curved)
		assert.equals("accelerating", direction)

		local width, anchor, offset, stable = Acceleration.CalculateBarExtent(-1, 200, 4)
		assert.equals(100, width)
		assert.equals("RIGHT", anchor)
		assert.equals(100, offset)
		assert.is_false(stable)
	end)

	it("applies speed and ability color palettes", function()
		local Color = Logic.Color
		local r, g, b = Color.ForSpeed(0.5)
		assert_near(Color.Colors.YELLOW[1], r)
		assert_near(Color.Colors.YELLOW[2], g)
		assert_near(Color.Colors.YELLOW[3], b)
		local er, eg, eb = Color.ForSurgeForward(0)
		assert.equals(Color.Colors.SURGE_FORWARD_EMPTY[1], er)
		assert.equals(Color.Colors.SURGE_FORWARD_EMPTY[2], eg)
		assert.equals(Color.Colors.SURGE_FORWARD_EMPTY[3], eb)
	end)

	it("calculates visibility and transitions", function()
		local Visibility = Logic.Visibility
		local hidden = Visibility.Calculate({
			visibility = { hideWhenNotSkyriding = true },
			abilityBars = { showSurgeForward = true },
			playerState = { isSkyriding = false, isFlying = false },
		})
		assert.is_false(hidden.data.showHUD)
		assert.is_false(hidden.data.showSurgeForward)

		local visible = Visibility.Calculate({
			visibility = { hideWhenNotSkyriding = true },
			abilityBars = {
				showSurgeForward = true,
				showSecondWind = true,
				showWhirlingSurge = false,
			},
			playerState = { isSkyriding = true, isFlying = true },
		})
		assert.is_true(visible.data.showHUD)
		assert.is_true(visible.data.showSurgeForward)
		assert.is_true(visible.data.showSecondWind)
		assert.is_false(visible.data.showWhirlingSurge)
		assert.equals("show", Visibility.GetTransition(false, true))
		assert.equals("hide", Visibility.GetTransition(true, false))
		assert.equals("none", Visibility.GetTransition(true, true))
	end)

	it("estimates pitch direction from speed trend", function()
		local result = Logic.Pitch.Calculate({
			totalSpeed = 100,
			horizontalSpeed = 80,
			previousSmooth = 0,
			previousTrend = 0,
			speedTrend = 1,
			barWidth = 200,
		})
		assert.is_true(result.success)
		assert.is_false(result.data.shouldHide)
		assert.equals("diving", result.data.direction)
		assert.is_true(result.data.width > 0)
	end)
end)
