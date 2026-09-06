-- Run from the repository root: lua Tests/acceleration_timing_regressions.lua
dofile("Tests/bootstrap.lua")
local Acceleration = FlightsimLogic.Acceleration
local checks = 0
local function near(actual, expected, label)
	assert(math.abs(actual - expected) < 1e-8, label .. ": " .. actual .. " vs " .. expected)
	checks = checks + 1
end

local function runTrace(intervals, slope, smooth)
	local time, speed = 0, 100
	local input, output = {}, {}
	for _, elapsed in ipairs(intervals) do
		input.lastSpeed = speed
		time = time + elapsed
		speed = 100 + slope * time
		input.currentSpeed = speed
		input.previousSmooth = smooth or 0
		input.deltaTime = elapsed
		local result = Acceleration.Calculate(input, output)
		assert(result.success and result.data == output)
		smooth = output.smoothDelta
	end
	return smooth
end

local rates = {}
for _, hz in ipairs({ 10, 20, 60 }) do
	local intervals = {}
	for _ = 1, hz do
		intervals[#intervals + 1] = 1 / hz
	end
	rates[hz] = intervals
end
for _, slope in ipairs({ 100, -100, 0 }) do
	local reference = runTrace(rates[20], slope, 2)
	near(runTrace(rates[10], slope, 2), reference, "10Hz trace matches 20Hz")
	near(runTrace(rates[60], slope, 2), reference, "60Hz trace matches 20Hz")
	near(runTrace({ 0.1, 0.05, 0.2, 0.025, 0.125, 0.25, 0.25 }, slope, 2), reference, "irregular frame trace")
end

local original = 0
for _ = 1, 20 do
	original = original * 0.7 + 5 * 0.3
end
near(runTrace(rates[20], 100, 0), original, "original 20Hz response preserved")
local input = { currentSpeed = 900, lastSpeed = 100, previousSmooth = 2, deltaTime = 0 }
near(Acceleration.Calculate(input).data.smoothDelta, 2, "zero time holds previous value")
input.deltaTime = 2
near(Acceleration.Calculate(input).data.smoothDelta, 0, "long pause resets the signal")
input.deltaTime = 0.05
input.lastSpeed = nil
near(Acceleration.Calculate(input).data.smoothDelta, 0, "first sample resets the signal")
input.lastSpeed = 895
input.deltaTime = nil
near(Acceleration.Calculate(input).data.smoothDelta, 2 * 0.7 + 5 * 0.3, "legacy callers retain 20Hz units")
print("Acceleration timing regressions: " .. checks .. " checks passed")
