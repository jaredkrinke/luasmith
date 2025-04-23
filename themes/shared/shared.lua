-- Helpers
local months = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }

local function parseYamlDate(str)
	local year, month, day = string.match(str, "^(%d%d%d%d)-(%d%d)-(%d%d)")
	local hour, minute = string.match(string.sub(str, 11), "%d%d:%d%d")
	if year and month and day then
		return year, month, day, hour, minute
	else
		error("Failed to parse date: " .. str)
	end
end

local function formatDate(str)
	local year, month, day = parseYamlDate(str)
	return months[string.toNumber(month)] .. " " .. string.toNumber(day) .. ", " .. year
end

local function yamlDateToIso(str)
	local year, month, day, hour, minute = parseYamlDate(str)
	return year .. "-" .. month .. "-" .. day .. "T" .. (hour or "00") .. ":" .. (minute or "00") .. ":00.000Z"
end

return {
	yamlDateToIso = yamlDateToIso,
	formatDate = formatDate,
}

