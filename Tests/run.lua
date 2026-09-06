-- Self-contained offline test entry point.
-- Run from the Flightsim repository root:
--   lua Tests/run.lua

local suites = {}
local currentSuite

local function describe(name, fn)
	local parent = currentSuite
	local suite = {
		name = parent and (parent.name .. " > " .. name) or name,
		tests = {},
	}
	table.insert(suites, suite)
	currentSuite = suite
	fn()
	currentSuite = parent
end

local function it(name, fn)
	if not currentSuite then
		error("it() must be called inside describe()", 2)
	end
	table.insert(currentSuite.tests, { name = name, fn = fn })
end

local function deep_equal(expected, actual, path)
	path = path or "value"
	if type(expected) ~= type(actual) then
		return false, path .. " has different types"
	end
	if type(expected) ~= "table" then
		if expected ~= actual then
			return false, string.format("%s expected %s but got %s", path, tostring(expected), tostring(actual))
		end
		return true
	end
	for key, value in pairs(expected) do
		local equal, message = deep_equal(value, actual[key], path .. "." .. tostring(key))
		if not equal then
			return false, message
		end
	end
	for key in pairs(actual) do
		if expected[key] == nil then
			return false, path .. " has unexpected key " .. tostring(key)
		end
	end
	return true
end

local assertions = {}
function assertions.equals(expected, actual, message)
	if expected ~= actual then
		error(message or string.format("Expected %s but got %s", tostring(expected), tostring(actual)), 2)
	end
end

function assertions.same(expected, actual, message)
	local equal, detail = deep_equal(expected, actual)
	if not equal then
		error(message or detail, 2)
	end
end

function assertions.is_true(value, message)
	if value ~= true then
		error(message or "Expected true", 2)
	end
end

function assertions.is_false(value, message)
	if value ~= false then
		error(message or "Expected false", 2)
	end
end

function assertions.is_nil(value, message)
	if value ~= nil then
		error(message or "Expected nil", 2)
	end
end

function assertions.is_not_nil(value, message)
	if value == nil then
		error(message or "Expected a value", 2)
	end
end

_G.describe = describe
_G.it = it
_G.assert = assertions

dofile("Tests/helpers_spec.lua")

local passed, failed = 0, 0
for _, suite in ipairs(suites) do
	for _, test in ipairs(suite.tests) do
		local ok, err = pcall(test.fn)
		local name = suite.name .. " > " .. test.name
		if ok then
			passed = passed + 1
			print("PASS: " .. name)
		else
			failed = failed + 1
			print("FAIL: " .. name .. " | " .. tostring(err))
		end
	end
end

print("OFFLINE_TESTS:" .. passed .. ":" .. failed .. ":" .. (passed + failed))

-- The adapter/view/config checks intentionally install different WoW mocks.
-- Run each in a child Lua process so one suite cannot leak globals into the
-- next. Set MECHANIC_LUA when using a different Lua 5.1 executable.
local interpreterIndex = -1
while arg and arg[interpreterIndex - 1] do
	interpreterIndex = interpreterIndex - 1
end
local lua = os.getenv("MECHANIC_LUA") or (arg and arg[interpreterIndex]) or "lua"
local isWindows = package.config:sub(1, 1) == "\\"
local function quotePath(path)
	if isWindows then
		return '"' .. path .. '"'
	end
	return "'" .. path:gsub("'", "'\\''") .. "'"
end
local scripts = {
	"Tests/bridge_regressions.lua",
	"Tests/config_regressions.lua",
	"Tests/view_logic_regressions.lua",
	"Tests/acceleration_timing_regressions.lua",
	"Tests/domain_buffer_regressions.lua",
	"Tests/event_diagnostics_regressions.lua",
	"Tests/lifecycle_regressions.lua",
	"Tests/locale_regressions.lua",
}

local childFailures = 0
for _, script in ipairs(scripts) do
	local command = quotePath(lua) .. " " .. quotePath(script)
	if isWindows then
		command = 'cmd /d /c "' .. command .. '"'
	end
	local status = os.execute(command)
	local exitCode = type(status) == "number" and status or (status and 0 or 1)
	if exitCode == 0 then
		print("PASS: " .. script)
	else
		childFailures = childFailures + 1
		print("FAIL: " .. script .. " | exit code " .. tostring(exitCode))
	end
end

os.exit(failed == 0 and childFailures == 0 and 0 or 1)
