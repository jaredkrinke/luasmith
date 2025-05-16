shared = fs.loadThemeFile("../shared.lua")()

-- Helpers
local htmlDateTemplate = etlua.compile([[<time datetime="<%= short %>"><%= long %></time>]])
function htmlifyDate(date)
	return htmlDateTemplate({ short = date, long = shared.formatDate(date) })
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

-- Build pipeline
return {
	readFromSource("content"),
	injectFiles({ ["style.css"] = fs.readThemeFile("style.css"), }),
	processMarkdown(),
	aggregate("feed.xml", "%.html$"),
	aggregate("index.html", "%.html$"),
	injectMetadata({ site = site }),
	applyTemplates({
		{ "%.html$", fs.readThemeFile("post.etlua") },
		{ "^feed.xml$", fs.readThemeFile("../shared/feed.etlua") },
		{ "^index.html$", fs.readThemeFile("blog.etlua") },
	}),
	applyTemplates({ { "%.html$", fs.readThemeFile("outer.etlua") } }),
	writeToDestination("out"),
}

