-- Mock LibStub
_G.LibStub = function() return { Register = function() end } end

-- Mock C_AddOns
_G.C_AddOns = {
    GetAddOnMetadata = function() return "1.0.0" end
}

-- Load the addon files to test real code
-- Flightsim.lua expects the addon name as the first argument
-- We can simulate this by setting the arg table or just requiring it
-- if the code handles nil ADDON_NAME gracefully.
require("Flightsim")
require("UI")

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

