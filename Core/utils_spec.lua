-- Simple tests for Flightsim Core utilities
-- Uses sandbox test framework (no Busted required)

describe("Core.Utils.Clamp", function()
	it("returns value when within range", function()
		assert.equals(50, FlightsimCore.Utils.Clamp(50, 0, 100))
	end)

	it("returns min when value is below range", function()
		assert.equals(0, FlightsimCore.Utils.Clamp(-10, 0, 100))
	end)

	it("returns max when value is above range", function()
		assert.equals(100, FlightsimCore.Utils.Clamp(150, 0, 100))
	end)

	it("handles edge case at min", function()
		assert.equals(0, FlightsimCore.Utils.Clamp(0, 0, 100))
	end)

	it("handles edge case at max", function()
		assert.equals(100, FlightsimCore.Utils.Clamp(100, 0, 100))
	end)
end)

describe("Core.Utils.ColorForPct", function()
	it("returns red at 0%", function()
		local r, g, b = FlightsimCore.Utils.ColorForPct(0)
		assert.is_near(0.769, r, 0.01)
	end)

	it("returns yellow at 50%", function()
		local r, g, b = FlightsimCore.Utils.ColorForPct(0.5)
		assert.is_near(0.769, r, 0.01)
		assert.is_near(0.651, g, 0.01)
	end)

	it("returns green at 100%", function()
		local r, g, b = FlightsimCore.Utils.ColorForPct(1)
		assert.is_near(0.169, r, 0.01)
	end)

	it("clamps values below 0", function()
		local r1 = FlightsimCore.Utils.ColorForPct(-0.5)
		local r2 = FlightsimCore.Utils.ColorForPct(0)
		assert.equals(r1, r2)
	end)

	it("clamps values above 1", function()
		local r1 = FlightsimCore.Utils.ColorForPct(1.5)
		local r2 = FlightsimCore.Utils.ColorForPct(1)
		assert.equals(r1, r2)
	end)
end)

describe("Core.Utils.ColorForPctBlue", function()
	it("returns dimmed color at 0%", function()
		local r = FlightsimCore.Utils.ColorForPctBlue(0)
		assert.is_near(0.12, r, 0.01)
	end)

	it("returns full color at 100%", function()
		local r = FlightsimCore.Utils.ColorForPctBlue(1)
		assert.is_near(0.290, r, 0.01)
	end)
end)

-- Run all tests and output results
local results = _TestRunner.run()
print("SANDBOX_TESTS:" .. results.passed .. ":" .. results.failed .. ":" .. results.total)
for _, r in ipairs(results.results) do
	if r.passed then
		print("PASS: " .. r.name)
	else
		print("FAIL: " .. r.name .. " | " .. (r.error or ""))
	end
end
