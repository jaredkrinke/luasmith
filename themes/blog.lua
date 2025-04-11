build({
	readFromSource("content"),
	processMarkdown(),
	applyTemplates({
		{ "%.html$", readThemeFile("templates/post.etlua") },
	}),
	writeToDestination("out", "^[^_]"),
})

