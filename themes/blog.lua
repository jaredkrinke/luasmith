-- Helpers
local htmlDateTemplate = etlua.compile([[<time datetime="<%= short %>"><%= long %></time>]])
function htmlifyDate(date)
	return htmlDateTemplate({ short = date, long = formatDate(date) })
end

-- Build pipeline
build({
	readFromSource("content"),
	injectFiles({
		["style.css"] = readThemeFile("css/blog.css"),
	}),
	processMarkdown(),
	aggregate("index.html", "%.html$"),
	applyTemplates({
		{ "%.html$", readThemeFile("templates/post.etlua") },
		{ "^index.html$", readThemeFile("templates/blog.etlua") },
	}),
	applyTemplates({ { "%.html$", readThemeFile("templates/outer.etlua") } }),
	writeToDestination("out", "^[^_]"),
})

