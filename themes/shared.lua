-- Helpers
local function escapeQuotes(str)
	return string.gsub(str, "\"", [[\"]])
end

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

local function hasDate(item)
	return item.date
end

-- Atom feed helpers
function atomifyItemContent(item, siteUrl)
	return lib.item.repathRelativeLinks(item, siteUrl)
end

-- Syntax highlighting for legacy browsers
local tagToElement = {}
for e, list in pairs({
	i = {"comment", "preprocessor", "bold", "italic", "number", "underline", "string"},
	b = {"tag", "function", "heading", "label", "annotation", "class", "type", "keyword"},
	u = {"link", "list", "error", "regex"},
}) do
	for _, t in ipairs(list) do
		tagToElement[t] = e
	end
end

local function highlightSpanWithLegacyTag(verbatim, tag)
	local element = tagToElement[tag] or "span"
	return "<" .. element .. " class=\"hl-" .. tag .. "\">" .. verbatim .. "</" .. element .. ">"
end

local function highlightSpanWithoutClass(verbatim, tag)
	local element = tagToElement[tag]
	if element then
		return "<" .. element .. ">" .. verbatim .. "</" .. element .. ">"
	else
		return verbatim
	end
end

return {
	atomifyItemContent = atomifyItemContent,
	escapeQuotes = escapeQuotes,
	formatDate = formatDate,
	hasDate = hasDate,
	highlightSpanWithLegacyTag = highlightSpanWithLegacyTag,
	highlightSpanWithoutClass = highlightSpanWithoutClass,
	yamlDateToIso = yamlDateToIso,
}

