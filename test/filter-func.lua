return {
	readFromSource(args[3], function (item) return item.path == "included.txt" end),
	injectMetadata({ content = "replaced\n" }, function (item) return item.path == "included.txt" end),
	writeToDestination(args[4], function (item) return item.path == "included.txt" end),
}
