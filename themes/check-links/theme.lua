local source = nil
local includeMarkdown = false
for i, arg in ipairs(args) do
	if i >= 3 then
		if arg == "--help" then
			print("USAGE: luasmith check-links [--markdown] [<source directory>]")
			os.exit(-1)
		elseif arg == "--markdown" then
			includeMarkdown = true
		else
			if not source then
				source = arg
			end
		end
	end
end

local noop = function () end
local htmlCount = 0
local mdCount = 0
return {
	readFromSource(source or "."),
	createTransformNode(function () if includeMarkdown then mdCount = mdCount + 1 end end, "%.md$"),
	createTransformNode(function () htmlCount = htmlCount + 1 end, "%.html$"),
	(includeMarkdown and processMarkdown()) or noop,
	checkLinks(),
	processItems(function (items)
		print("\nLink checking completed (" .. mdCount .. " Markdown, " .. htmlCount .. " HTML files checked). See warnings above for any broken links.\n")
	end)
}

