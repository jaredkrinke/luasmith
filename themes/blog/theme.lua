shared = require("themes.shared")

-- Site metadata
local site = {
	title = "Untitled",
	subtitle = nil,
	url = "https://example.com/",
	footer = nil,
	keywordDirectoryPattern = "^posts/(.-)/.+%.html$",
	syntaxAliases = nil,
}

-- Helpers
local htmlDateTemplate = etlua.compile([[<time datetime="<%= short %>"><%= long %></time>]])
local months = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
function htmlifyDateShort(date)
	local year, month, day = string.match(date, "^(%d%d%d%d)-(%d%d)-(%d%d)")
	return htmlDateTemplate({ short = date, long = months[string.toNumber(month)] .. " " .. day })
end

function htmlifyDate(date)
	return htmlDateTemplate({ short = date, long = shared.formatDate(date) })
end

local keywordListTemplate = etlua.compile([[<%
for i, k in ipairs(keywords) do -%><% if i > 1 then %> | <% end %><a href="<%= pathToRoot %>topics/<%= k %>.html">#<%= k %></a>
<% end -%>]])
function keywordList(pathToRoot, keywords)
	return keywordListTemplate({ pathToRoot = pathToRoot, keywords = keywords })
end

local postListTemplate = etlua.compile([[<% local lastYear = nil -%>
<% local level = level or 2
   for i, item in ipairs(table.sortBy(items, "date", true)) do
   if limit and i > limit then break end
   local year = string.match(item.date, "^(%d%d%d%d)")
   if lastYear ~= year then
     if lastYear ~= nil then -%>
</ul>
<% end -%>
<h<%= level%>><%= year %></h<%= level%>>
<ul class="posts">
<%
	 lastYear = year
   end
-%>
<li><%- htmlifyDateShort(item.date) %> <a href="<%= pathToRoot %><%= item.path %>"><%= item.title %></a></li>
<% end -%>
<% if #items > 0 then -%>
</ul>
<% end -%>
]])
function postList(self, level, limit)
	return postListTemplate({
		pathToRoot = self.pathToRoot,
		items = table.include(self.items, shared.hasDate),
		level = level,
		limit = limit,
	})
end

-- Hard-code syntax highlighting as normal HTML markup to support non-CSS browsers (e.g. terminal browsers)
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

local function highlightSpan(verbatim, tag)
	local element = tagToElement[tag] or "span"
	return "<" .. element .. " class=\"hl-" .. tag .. "\">" .. verbatim .. "</" .. element .. ">"
end

local function deriveKeywords(item)
	local category = string.match(item.path, site.keywordDirectoryPattern)
	local keywords = item.keywords or {}
	if category then
		return table.concatenate({ category }, keywords)
	end
	return keywords
end

-- Load site metadata
local siteOverrides = fs.tryLoadFile("site.lua")
if siteOverrides then
	table.merge(siteOverrides(), site)
end

local source = args[3] or "content"
local destination = args[4] or "out"

-- Build pipeline
return {
	readFromSource(source),
	injectFiles({
		["style.css"] = fs.readThemeFile("style.css"),
		["404.html"] = "",
	}),
	injectMetadata({ title = "Not found", pathToRoot = site.url or "/" }, "^404%.html$"),

	-- Markdown, drafts, syntax highlighting
	processMarkdown(),
	omitWhen(function (item) return item.draft or item.path == "site.lua" end),
	highlightSyntax({
		aliases = site.syntaxAliases,
		highlightSpan = highlightSpan,
	}),
	deriveMetadata({ keywords = deriveKeywords }, site.keywordDirectoryPattern),

	-- RSS and root page
	aggregate("feed.xml", "%.html$"),
	aggregate("index.html", "%.html$"),
	aggregate("topics/index.html", "%.html$"),

	-- Ugly hack to remove any duplicate index.html, e.g. if index.md was present in the input
	omitWhen(function (item) return item.path == "index.html" and not item.items end),

	-- Keyword indexes
	createIndexes(function (keyword) return "topics/" .. keyword .. ".html" end, "keywords", "%.html$"),
	deriveMetadata({ title = function (item) return item.key and ("#" .. item.key) or "All articles" end }, "^topics/.-%.html$"),

	-- Global metadata and templates
	injectMetadata({ site = site }),
	applyTemplates({ { "^feed.xml$", fs.readThemeFile("../shared/feed.etlua") } }),
	applyTemplates({
		{ "%.html$", fs.readThemeFile("post.etlua") },
		{ "^topics/.-%.html$", fs.readThemeFile("index.etlua") },
		{ "^topics/index%.html$", fs.readThemeFile("archive.etlua") },
		{ "^index.html$", fs.readThemeFile("blog.etlua") },
		{ "^404.html$", fs.readThemeFile("404.etlua") },
	}),
	applyTemplates({ { "%.html$", fs.readThemeFile("outer.etlua") } }),

	checkLinks(),
	writeToDestination(destination),
}

