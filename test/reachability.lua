return {
	readFromSource(args[3]),
	checkLinks({ excludeUnreachable = true, entryPoints = { "index.html" } }),
	writeToDestination(args[4]),
}

