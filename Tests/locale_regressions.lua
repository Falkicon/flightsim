-- Exercise locale guards and settings label resolution using the actual Lua files.
Flightsim = { L = {} }
dofile("Locales/enUS.lua")
local baseline = Flightsim.L
local locales = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks = checks + 1
end

local formatKeys = { "ABILITY_TOGGLED", "DEBUG_KV", "DEBUG_ABILITY_FORMAT", "OPTIMAL_FORMAT", "STATUS_FORMAT" }
local function signature(text)
	local formats = {}
	text = text:gsub("%%%%", "")
	for token in text:gmatch("%%[-+ #0]*%d*%.?%d*([cdiouxXeEfgGqs])") do
		formats[#formats + 1] = token
	end
	return table.concat(formats)
end

for _, locale in ipairs(locales) do
	Flightsim = { L = {} }
	GetLocale = function()
		return "enUS"
	end
	dofile("Locales/" .. locale .. ".lua")
	check(next(Flightsim.L) == nil, locale .. " guard must prevent overwriting other locales")
	GetLocale = function()
		return locale
	end
	dofile("Locales/" .. locale .. ".lua")
	for key in pairs(baseline) do
		check(type(Flightsim.L[key]) == "string" and Flightsim.L[key] ~= "", locale .. " missing " .. key)
	end
	for key in pairs(Flightsim.L) do
		check(baseline[key] ~= nil, locale .. " unknown key " .. key)
	end
	for _, key in ipairs(formatKeys) do
		check(signature(Flightsim.L[key]) == signature(baseline[key]), locale .. " format mismatch " .. key)
	end
end

-- Sentinel translations expose accidental hardcoded UI text without depending on wording.
local labels = {}
for key in pairs(baseline) do
	labels[key] = "localized:" .. key
end
Flightsim = { L = setmetatable(labels, {
	__index = function(_, key)
		error("Unknown locale key: " .. key)
	end,
}) }
local namespace = {}
assert(loadfile("Settings.lua"))("Flightsim", namespace)
local function verifyOptions(options)
	for field, value in pairs(options) do
		if field == "name" or field == "desc" then
			if type(value) == "string" and value ~= "" and value ~= "Flightsim" then
				check(value:sub(1, 10) == "localized:", "unlocalized settings text: " .. value)
			end
		elseif field == "values" and type(value) == "table" then
			for key, label in pairs(value) do
				if type(key) ~= "string" or not key:match("^Fonts\\") then
					check(label:sub(1, 10) == "localized:", "unlocalized setting choice: " .. label)
				end
			end
		elseif type(value) == "table" then
			verifyOptions(value)
		end
	end
end
verifyOptions(namespace.options)
print("Locale regressions: " .. checks .. " checks passed")
