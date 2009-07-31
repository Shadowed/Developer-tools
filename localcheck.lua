local function output(msg)
	io.stdout:write(msg)
	io.stdout:write("\n")
	io.stdout:flush()
end

local file = io.open("localization.enUS.lua")
local contents = file:read("*line")
file:close()

local LOCAL_VAR = string.match(contents, "^(.+) = {")
if( not LOCAL_VAR ) then
	output("Failed to find localization variable in localization.enUS.lua")
	return
else
	output("Localization key " .. LOCAL_VAR)
end

function string.trim(text)
	return string.gsub(text, "^%s*(.-)%s*$", "%1")
end

local foundLocals = {}
local totalFound = 0
local function scanFile(path)
	output("Scanning " .. path)
	
	local contents = io.open(path):read("*all")
	for line in string.gmatch(contents, "L%[\"(.-)\"%]") do
		foundLocals[string.trim(line)] = true
		totalFound = totalFound + 1
	end

	for line in string.gmatch(contents, LOCAL_VAR .. "%[\"(.-)\"%]") do
		foundLocals[string.trim(line)] = true
		totalFound = totalFound + 1
	end
end

local function scanFolder(path)
	for file in io.popen(string.format("dir /B \"%s\"", (path or ""))):lines() do
		local extension = string.match(file, "%.([%a%d]+)$")
		if( file ~= "" and not extension and file ~= "libs" ) then
			if( path ) then
				scanFolder(path .. "/" .. file)
			else
				scanFolder(file)
			end
		elseif( extension == "lua" and file ~= "localcheck.lua" and file ~= "globalcheck.lua" and not string.match(file, "^localization") ) then
			if( path ) then
				scanFile(path .. "/" .. file)
			else
				scanFile(file)
			end
		end
	end
end

scanFolder()

output("Total keys found " .. totalFound)

-- Sort everything
local keyOrder = {}
for key in pairs(foundLocals) do
	table.insert(keyOrder, key)
end

table.sort(keyOrder, function(a, b) return a < b end)

-- Load the current localization to get the tables out
dofile("localization.enUS.lua")

local file = io.open("localization.enUS.lua", "w")
file:write(LOCAL_VAR .. " = {")

-- Write all used keys
for _, key in pairs(keyOrder) do
	file:write(string.format("\n	[\"%s\"] = \"%s\",", key, key))
end

-- Format the string so it can be written
local function parse(text)
	text = string.gsub(text, "\n", "\\n")
	text = string.gsub(text, "\"", "\\\"")
	text = string.trim(text)
	
	return text
end

-- Tables inside localization are assumed to always be there
local _G = getfenv(0)
local keyOrder = {}
for key, data in pairs(_G[LOCAL_VAR]) do
	if( type(data) == "table" ) then
		table.insert(keyOrder, key)
	end
end

table.sort(keyOrder, function(a, b) return a < b end)

file:write("\n")

local hadTables
local subKeyOrder = {}
for _, key in pairs(keyOrder) do
	file:write(string.format("\n	[\"%s\"] = {\n", key))
	
	for i=#(subKeyOrder), 1, -1 do table.remove(subKeyOrder, i) end

	local data = _G[LOCAL_VAR][key]
	for subKey in pairs(data) do
		table.insert(subKeyOrder, subKey)
	end
	
	table.sort(subKeyOrder, function(a, b) return a < b end)
	for _, subKey in pairs(subKeyOrder) do
		file:write(string.format("		[\"%s\"] = \"%s\",\n", parse(subKey), parse(data[subKey])))
	end
	
	hadTables = true
	file:write("	},")
end

if( hadTables ) then
	file:write("\n")
end

file:write("}")
file:flush()
file:close()


output("Done")



