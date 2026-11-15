shared = require("themes.shared")

-- Site metadata
local site = {
	checkLinks = nil,
	syntaxAliases = nil,
}

-- Load site metadata
local siteOverrides = fs.tryLoadFile("site.lua")
if siteOverrides then
	table.merge(siteOverrides(), site)
end

-- Directories
local source = args[3] or "content"
local destination = args[4] or "out"

-- Build pipeline
local stylesheet = fs.readThemeFile("style.css")
return {
	readFromSource(source),
	injectFiles({ ["style.css"] = stylesheet }),

	injectFiles({ ["404.html"] = "<h1>Not found</h1>\n<p>The requested page was not found.</p>", }),
	injectMetadata({ pathToRoot = site.url or "/" }, "^404%.html$"),
	injectMetadata({ stylesheet = stylesheet }, "^404%.html$"),

	-- Markdown, syntax highlighting
	processMarkdown(),
	highlightSyntax({
		aliases = site.syntaxAliases,
		highlightSpan = shared.highlightSpanWithoutClass,
	}),

	-- Extract title from <h1> tag
	deriveMetadata({ title = function (item) return string.match(item.content, "<h1.->(.-)</h1>") end }, "%.html$"),

	-- Global metadata and templates
	injectMetadata({ site = site }),
	applyTemplates({ { "%.html$", fs.readThemeFile("outer.etlua") } }),

	checkLinks(site.checkLinks),
	writeToDestination(destination),
}

