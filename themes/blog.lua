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
	applyTemplates({
		{ "%.html$", readThemeFile("templates/post.etlua") },
	}),
	applyTemplates({ { "%.html$", readThemeFile("templates/outer.etlua") } }),
	writeToDestination("out", "^[^_]"),
})

