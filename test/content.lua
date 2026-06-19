return {
	readFromSource(args[3]),
	processMarkdown(),
	applyTemplates({ { "%.html$", "<%- content %>" } }),
	writeToDestination(args[4]),
}


