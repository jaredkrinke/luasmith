-- Helpers
local months = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }

function parseYamlDate(str)
	local year, month, day = string.match(str, "^(%d%d%d%d)-(%d%d)-(%d%d)")
	local hour, minute = string.match(string.sub(str, 11), "%d%d:%d%d")
	if year and month and day then
		return year, month, day, hour, minute
	else
		error("Failed to parse date: " .. str)
	end
end

function formatDate(str)
	local year, month, day = parseYamlDate(str)
	return months[string.toNumber(month)] .. " " .. string.toNumber(day) .. ", " .. year
end

function yamlDateToIso(str)
	local year, month, day, hour, minute = parseYamlDate(str)
	return year .. "-" .. month .. "-" .. day .. "T" .. (hour or "00") .. ":" .. (minute or "00") .. ":00.000Z"
end

function escapeQuotes(str)
	return string.gsub(str, "\"", [[\"]])
end

local htmlDateTemplate = etlua.compile([[<p><time datetime="<%= short %>"><%= long %></time></p>]])
function htmlifyDate(date)
	return htmlDateTemplate({ short = string.sub(date, 1, 10), long = formatDate(date) })
end

-- Derive keywords from explicit keywords as well as directory
local function deriveTags(item)
	local category = string.match(item.path, "^posts/(.-)/.+%.html$")
	local tags = { category }
	if item.keywords then
		for _, keyword in ipairs(item.keywords) do
			if keyword ~= category then
				tags[#tags + 1] = keyword
			end
		end
	end
	return tags
end

-- Site metadata
local site = {
	title = "Untitled",
	subtitle = "You should set title, subtitle, and url in site.lua",
	url = "https://example.com/",
}

local siteOverrides = fs.tryLoadFile("content/site.lua")
if siteOverrides then
	table.merge(siteOverrides(), site)
end

-- Partials
headerStart = etlua.compile(
[[<header>
<h1><a href="<%= pathToRoot %>index.html"><%= site.title %></a></h1>
<p><%= site.subtitle %></p>
]])

headerEnd = "</header>"

-- TODO: For testing purposes only!
local normalize = createTransformNode(function (item)
	if item.content then
		item.content = string.gsub(item.content, "&#039;", "&#39;")
		item.content = string.gsub(item.content, "'", "&#39;")
	end
end, "%.html$")

-- Build pipeline
return {
	readFromSource("content"),
	-- TODO: Allow shorthand for directly inserting unmodified theme files?
	injectFiles({
		["css/style.css"] = fs.readThemeFile("style.css"),
	}),
	processMarkdown(),
	omitWhen(function (item) return item.draft end),
	deriveMetadata({ tags = deriveTags }, "^posts/.+%.html$"),
	-- TODO: Cache index?
	aggregate("feed.xml", "^posts/.+%.html$"),
	aggregate("index.html", "^posts/.+%.html$"), -- TODO: allow optional metadata
	injectMetadata({ description = site.subtitle }, "^index.html$"),
	aggregate("posts/index.html", "^posts/.+%.html$"), -- TODO: allow optional metadata
	injectMetadata({ description = "All posts since the beginning of time" }, "^posts/index.html$"),
	createIndexes(function (tag) return "posts/" .. tag .. "/index.html" end, "tags", "^posts/.+%.html$"),
	deriveMetadata({ title = function (item) return site.title .. ": Posts tagged with: " .. item.key end }, "^posts/.-/index.html$"),
	injectMetadata({ site = site }),
	applyTemplates({
		{ "%.html$", fs.readThemeFile("post.etlua") },
		{ "^posts/.-/index.html$", fs.readThemeFile("index.etlua") },
		{ "^posts/index.html$", fs.readThemeFile("archive.etlua") },
		{ "^feed.xml$", fs.readThemeFile("feed.etlua") },
		{ "^index.html$", fs.readThemeFile("root.etlua") },
	}),
	applyTemplates({ { "%.html$", fs.readThemeFile("outer.etlua") } }),
	normalize, -- TODO: Remove!
	writeToDestination("out"),
}

