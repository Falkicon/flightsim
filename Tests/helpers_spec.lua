-- Mock FlightsimUI structure
_G.FlightsimUI = { Utils = {} }

-- Helper to load the functions into the mock
local function loadUtils()
	-- Clamp
	_G.FlightsimUI.Utils.Clamp = function(n, minV, maxV)
		if n < minV then return minV end
		if n > maxV then return maxV end
		return n
	end

	-- Colors (extracted from UI.lua logic)
	local COLOR_GREEN = { 0.169, 0.651, 0.016 }
	local COLOR_YELLOW = { 0.769, 0.651, 0.016 }
	local COLOR_RED = { 0.769, 0.169, 0.016 }
	local COLOR_SURGE_FORWARD = { 0.455, 0.686, 1.0 }
	local COLOR_SURGE_FORWARD_EMPTY = { 0.18, 0.27, 0.4 }

	_G.FlightsimUI.Utils.ColorForPct = function(pct)
		local Clamp = _G.FlightsimUI.Utils.Clamp
		pct = Clamp(pct or 0, 0, 1)
		local r, g, b
		if pct < 0.5 then
			local t = pct * 2
			r = COLOR_RED[1] + (COLOR_YELLOW[1] - COLOR_RED[1]) * t
			g = COLOR_RED[2] + (COLOR_YELLOW[2] - COLOR_RED[2]) * t
			b = COLOR_RED[3] + (COLOR_YELLOW[3] - COLOR_RED[3]) * t
		else
			local t = (pct - 0.5) * 2
			r = COLOR_YELLOW[1] + (COLOR_GREEN[1] - COLOR_YELLOW[1]) * t
			g = COLOR_YELLOW[2] + (COLOR_GREEN[2] - COLOR_YELLOW[2]) * t
			b = COLOR_YELLOW[3] + (COLOR_GREEN[3] - COLOR_YELLOW[3]) * t
		end
		return r, g, b
	end

	_G.FlightsimUI.Utils.ColorForPctSurgeForward = function(pct)
		local Clamp = _G.FlightsimUI.Utils.Clamp
		pct = Clamp(pct or 0, 0, 1)
		local r = COLOR_SURGE_FORWARD_EMPTY[1] + (COLOR_SURGE_FORWARD[1] - COLOR_SURGE_FORWARD_EMPTY[1]) * pct
		local g = COLOR_SURGE_FORWARD_EMPTY[2] + (COLOR_SURGE_FORWARD[2] - COLOR_SURGE_FORWARD_EMPTY[2]) * pct
		local b = COLOR_SURGE_FORWARD_EMPTY[3] + (COLOR_SURGE_FORWARD[3] - COLOR_SURGE_FORWARD_EMPTY[3]) * pct
		return r, g, b
	end

	_G.FlightsimUI.Utils.CopyDefaults = function(dst, src)
		for k, v in pairs(src) do
			if type(v) == "table" then
				dst[k] = dst[k] or {}
				_G.FlightsimUI.Utils.CopyDefaults(dst[k], v)
			elseif dst[k] == nil then
				dst[k] = v
			end
		end
	end
end

loadUtils()

describe("Flightsim Helpers", function()
	local Utils = _G.FlightsimUI.Utils

	describe("Clamp", function()
		it("should return the value if within range", function()
			assert.equals(5, Utils.Clamp(5, 0, 10))
		end)

		it("should return the min value if below range", function()
			assert.equals(0, Utils.Clamp(-1, 0, 10))
		end)

		it("should return the max value if above range", function()
			assert.equals(10, Utils.Clamp(11, 0, 10))
		end)
	end)

	describe("ColorForPct", function()
		local function assert_near(expected, actual)
			assert.is_true(math.abs(expected - actual) < 0.001)
		end

		it("should return red for 0%", function()
			local r, g, b = Utils.ColorForPct(0)
			assert_near(0.769, r)
			assert_near(0.169, g)
			assert_near(0.016, b)
		end)

		it("should return yellow for 50%", function()
			local r, g, b = Utils.ColorForPct(0.5)
			assert_near(0.769, r)
			assert_near(0.651, g)
			assert_near(0.016, b)
		end)

		it("should return green for 100%", function()
			local r, g, b = Utils.ColorForPct(1)
			assert_near(0.169, r)
			assert_near(0.651, g)
			assert_near(0.016, b)
		end)
	end)

	describe("ColorForPctSurgeForward", function()
		local function assert_near(expected, actual)
			assert.is_true(math.abs(expected - actual) < 0.001)
		end

		it("should return dimmed blue for 0%", function()
			local r, g, b = Utils.ColorForPctSurgeForward(0)
			assert_near(0.18, r)
			assert_near(0.27, g)
			assert_near(0.4, b)
		end)

		it("should return bright blue for 100%", function()
			local r, g, b = Utils.ColorForPctSurgeForward(1)
			assert_near(0.455, r)
			assert_near(0.686, g)
			assert_near(1.0, b)
		end)
	end)

	describe("CopyDefaults", function()
		it("should copy missing keys", function()
			local dst = { a = 1 }
			local src = { a = 2, b = 2 }
			Utils.CopyDefaults(dst, src)
			assert.equals(1, dst.a)
			assert.equals(2, dst.b)
		end)

		it("should recursively copy tables", function()
			local dst = { sub = { a = 1 } }
			local src = { sub = { a = 2, b = 2 }, c = 3 }
			Utils.CopyDefaults(dst, src)
			assert.equals(1, dst.sub.a)
			assert.equals(2, dst.sub.b)
			assert.equals(3, dst.c)
		end)
	end)
end)

