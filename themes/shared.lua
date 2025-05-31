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

-- Atom feed helpers
local function atomRepathItemContent(item, prefix)
	local parts = {}
	local pathFromRoot = fs.directory(item.path)
	_parseHtml(item.content, function (event)
		local part = event.html

		-- Repath relative links, if needed
		if pathFromRoot ~= "" and event.attribute and event.value
			and((event.tag == "a" and event.attribute == "href") -- Check for links
			or (event.tag == "link" and event.attribute == "href")
			or (event.tag == "script" and event.attribute == "src")
			or (event.tag == "img" and event.attribute == "src"))
			and not string.find(event.value, ":") -- Local/relative links only
		then
			part = event.attribute .. "=\"" .. (prefix or "") .. fs.join(pathFromRoot, event.value) .. "\""
		end

		table.append(parts, part)
	end)
	return table.concat(parts)
end

function atomifyItemContent(item, siteUrl)
	return atomRepathItemContent(item, siteUrl)
end

return {
	atomifyItemContent = atomifyItemContent,
	formatDate = formatDate,
	yamlDateToIso = yamlDateToIso,
}

