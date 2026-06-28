local source = args[3] or "."

return {
	readFromSource(source),
	checkLinks(),
	createProcessingNode(function (changes)
		print("\nLink checking completed. See warnings above for any broken links.\n")
	end)
}

