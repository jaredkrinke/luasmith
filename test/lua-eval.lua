return {
	readFromSource(args[3]),
	processEtlua(),
	processMarkdown(),
	writeToDestination(args[4]),
}



