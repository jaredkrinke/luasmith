shared = require("themes.shared")

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
<% for i, item in ipairs(table.sortBy(items, "date", true)) do
   local year = string.match(item.date, "^(%d%d%d%d)")
   if lastYear ~= year then
     if lastYear ~= nil then -%>
</ul>
<% end -%>
<h2><%= year %></h2>
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
function postList(self)
	return postListTemplate({ pathToRoot = self.pathToRoot, items = self.items })
end

-- Site metadata
local site = {
	title = "Untitled",
	url = "https://example.com/",
}

local siteOverrides = fs.tryLoadFile("site.lua")
if siteOverrides then
	table.merge(siteOverrides(), site)
end

local source = args[3] or "content"
local destination = args[4] or "out"

-- Build pipeline
return {
	readFromSource(source),
	injectFiles({ ["style.css"] = fs.readThemeFile("style.css"), }),

	-- Markdown, drafts, syntax highlighting
	processMarkdown(),
	omitWhen(function (item) return item.draft or item.path == "site.lua" end),
	highlightSyntax(),

	-- RSS and root page
	aggregate("feed.xml", "%.html$"),
	aggregate("index.html", "%.html$"),

	-- Keyword indexes
	createIndexes(function (keyword) return "topics/" .. keyword .. ".html" end, "keywords", "%.html$"),
	deriveMetadata({ title = function (item) return item.key end }, "^topics/.-%.html$"),

	-- Global metadata and templates
	injectMetadata({ site = site }),
	applyTemplates({
		{ "%.html$", fs.readThemeFile("post.etlua") },
		{ "^topics/.-%.html$", fs.readThemeFile("index.etlua") },
		{ "^feed.xml$", fs.readThemeFile("../shared/feed.etlua") },
		{ "^index.html$", fs.readThemeFile("blog.etlua") },
	}),
	applyTemplates({ { "%.html$", fs.readThemeFile("outer.etlua") } }),

	checkLinks(),
	writeToDestination(destination),
}

