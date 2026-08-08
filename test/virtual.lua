local readMarkdown = false
local readCount = 0
local originalReadFile = fs.readFile

-- Hook fs.readFile() to count reads and check for read of test.md
function fs.readFile(path)
	readCount = readCount + 1
	if path == "virtual/test.md" then
		readMarkdown = true
	end
	return originalReadFile(path)
end

return {
	readFromSource(args[3]),
	processMarkdown(),
	writeToDestination(args[4]),
	function (items)
		local skippedText = (readCount == 1)
		if not readMarkdown then
			error("item.md should have been read!")
		end
		if not skippedText then
			error("item.txt should not have been read (read count: " .. readCount .. ")!")
		end
	end,
}
