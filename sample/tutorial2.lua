return {
	readFromSource("content"),

    -- Convert Markdown files to HTML fragments
    processMarkdown(),
    
	writeToDestination("out"),
}
