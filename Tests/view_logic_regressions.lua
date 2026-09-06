-- Run from the repository root: lua Tests/view_logic_regressions.lua
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks = checks + 1
end

_G.FenCore = {
	ActionResult = {
		error = function(code, message)
			return { success = false, error = { code = code, message = message } }
		end,
		unwrap = function(result)
			return result.data
		end,
	},
	Math = {
		Clamp = function(value, minimum, maximum)
			return math.max(minimum, math.min(maximum, value))
		end,
	},
}

dofile("Logic/init.lua")
local Speed = dofile("Logic/speed.lua")
local Pitch = dofile("Logic/pitch.lua")
local Visibility = dofile("Logic/visibility.lua")

local speedResult = Speed.Calculate({
	rawSpeed = Speed.BASE_SUSTAINABLE * Speed.BASE_SPEED_FOR_PCT / 100,
	zoneModifier = 1,
	configuredMax = 2000,
	sessionMax = 2500,
})
check(
	math.abs(speedResult.data.fillPct - speedResult.data.markerPct) < 0.000001,
	"sustainable marker uses the same configured/session scale as the speed fill"
)
check(
	Speed.Calculate({ zoneModifier = 1 }).data.sustainableSpeed == Speed.BASE_SUSTAINABLE,
	"nil sustainable speed keeps the zone-aware default"
)
local hiddenMarker = Speed.Calculate({ zoneModifier = 1, sustainableSpeed = 0 }).data
check(not hiddenMarker.showMarker and hiddenMarker.markerPct == 0, "zero sustainable speed hides the marker")
local customMarker = Speed.Calculate({ zoneModifier = 1, configuredMax = 2000, sustainableSpeed = 800 }).data
check(
	customMarker.sustainableSpeed == 800 and math.abs(customMarker.markerPct - 0.4) < 0.000001,
	"custom sustainable speed controls the marker position"
)

local invalidPitch = Pitch.Calculate(nil)
check(not invalidPitch.success and invalidPitch.error.code == "INVALID_INPUT", "nil pitch input returns an error")

local pitchOutput = { stale = true }
local pitchResult = Pitch.Calculate({ totalSpeed = 0, previousSmooth = 0.5, previousTrend = -0.5 }, pitchOutput)
check(pitchResult.data == pitchOutput, "pitch calculation reuses the caller's output buffer")
check(pitchOutput.shouldHide and pitchOutput.smoothRatio == 0.475, "low-speed pitch state decays smoothly")

local configuredOrder = { "Whirling Surge", "Unknown", "Whirling Surge", "Surge Forward" }
local normalized = Visibility.GetAbilityOrder(configuredOrder)
check(
	table.concat(normalized, ",") == "Whirling Surge,Surge Forward,Second Wind",
	"ability order filters invalid entries and appends missing abilities"
)
check(#configuredOrder == 4, "ability order normalization does not mutate SavedVariables")
local reusedOrder = { "stale", "values", "remain" }
check(
	Visibility.GetAbilityOrder(nil, reusedOrder) == reusedOrder
		and table.concat(reusedOrder, ",") == "Surge Forward,Second Wind,Whirling Surge",
	"ability order can safely reuse an output buffer"
)
check(
	table.concat(Visibility.GetAbilityOrder("corrupt"), ",") == "Surge Forward,Second Wind,Whirling Surge",
	"ability order recovers from malformed SavedVariables"
)

local profilerTime = 0
local wallTime = 0
local fullUpdateCalls = 0
_G.debugprofilestop = function()
	return profilerTime
end
_G.GetTime = function()
	return wallTime
end
_G.Flightsim = { debugMode = true }
_G.FlightsimLogic = {
	Color = {},
	Visibility = Visibility,
}
_G.FlightsimBridge = {
	Events = {},
	Executor = {
		FullUpdate = function()
			fullUpdateCalls = fullUpdateCalls + 1
			profilerTime = profilerTime + 2
			return { success = true, data = { shouldUpdate = false } }
		end,
	},
}

local View = dofile("View/init.lua")
local function makeFrame()
	local frame = {}
	function frame:ClearAllPoints()
		self.relativeTo = nil
	end
	function frame:SetPoint(_, relativeTo)
		self.relativeTo = relativeTo
	end
	function frame:GetWidth()
		return 150
	end
	function frame:GetHeight()
		return 2
	end
	function frame:IsShown()
		return true
	end
	return frame
end

View.db = {
	profile = {
		abilities = { order = { "Whirling Surge", "Surge Forward", "Second Wind" } },
		ui = {},
	},
}
View.accelFrame = makeFrame()
View.pitchFrame = makeFrame()
View.surgeForwardFrame = makeFrame()
View.secondWindFrame = makeFrame()
View.whirlingSurgeBar = makeFrame()
View.container = makeFrame()
function View.container:SetSize(width, height)
	self.width, self.height = width, height
end

View:RepositionAbilityBars({
	showSurgeForward = true,
	showSecondWind = true,
	showWhirlingSurge = true,
})
check(View.whirlingSurgeBar.relativeTo == View.accelFrame, "first configured ability anchors below acceleration")
check(View.surgeForwardFrame.relativeTo == View.whirlingSurgeBar, "second configured ability follows the first")
check(View.secondWindFrame.relativeTo == View.surgeForwardFrame, "third configured ability follows the second")

for _ = 1, 12 do
	wallTime = wallTime + 0.1
	View:OnUpdate(0.1)
end
local executorRate = View:GetPerformanceSubMetrics()[1].msPerSec
check(executorRate >= 15 and executorRate <= 25, "performance metric reports accumulated milliseconds per second")

function View.container:IsShown()
	return false
end
local idleStartCalls = fullUpdateCalls
for _ = 1, 10 do
	wallTime = wallTime + 0.1
	View:OnUpdate(0.1)
end
check(
	fullUpdateCalls - idleStartCalls <= 3,
	"a hidden container uses idle throttling even when its speed child is locally shown"
)

print("View/logic regressions: " .. checks .. " checks passed")
