shared = require("themes.shared")

local source = args[3] or "."
local destination = args[4] or "html"

-- Compute path to root from HTML output destination
if string.sub(destination, -1) == "/" then
	destination = string.sub(destination, #destination - 1)
end

local destinationAsPrefix = destination .. "/"
local outputPrefix = fs.reverseDirectory(destinationAsPrefix)

-- Included in each HTML file
stylesheet = fs.readFile("themes/generic/style.css")

-- Only output converted Markdown files
local filesToInclude = {}
local function isFromMarkdownSource(item)
	return filesToInclude[item.path]
end

return {
	readFromSource(source),
	createTransformNode(function (item) filesToInclude[string.gsub(item.path, "%.md$", ".html")] = true end, "%.md$"),
	processMarkdown(),
	highlightSyntax({ highlightSpan = shared.highlightSpanWithoutClass }),
	deriveMetadata({ title = function (item) return string.match(item.content, "<h1.->(.-)</h1>") end }, "%.html$"),
	applyTemplates({ { "%.html$", fs.readThemeFile("html.etlua") } }),
	createTransformNode(function (item)
		-- Repath 
		item.content = lib.item.repathRelativeLinksCustom(item, function (destination, pathFromRoot)
			if string.sub(destination, 1, 1) == "#" then
				return destination
			else
				destination = string.gsub(destination, "#.*$", "")
			end

			local destinationPathFromRoot = fs.resolveRelative(item.path, destination)
			if isFromMarkdownSource({ path = destinationPathFromRoot }) then
				return destination
			else
				return outputPrefix .. destination
			end
		end)
	end, isFromMarkdownSource),
	writeToDestination(destination, isFromMarkdownSource),

	-- Check links separately (not ideal, performance-wise)
	readFromSource(source),
	checkLinks(nil, function (item)
		return #item.path >= #destinationAsPrefix
			and string.sub(item.path, 1, #destinationAsPrefix) == destinationAsPrefix
			and filesToInclude[string.sub(item.path, #destinationAsPrefix + 1)]
	end),
}

