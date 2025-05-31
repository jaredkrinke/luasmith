# luasmith Tutorial
In this tutorial, we'll start with a trivial pipeline and build it up into a simple blog theme. See [../README.md](../README.md) for an overview of luasmith.

For an example of input content, look at the `sample/content/` directory.

### Trivial/Identity Pipeline
Here's a pipeline that essentially just copies from `content/` to `out/`:

```lua
-- Pipeline that copies from content/ to out/
return {
	readFromSource("content"),
	writeToDestination("out"),
}
```

Note that no Markdown processing is done whatsoever. You can try this trivial example out by compiling luasmith, going into the `sample` directory, and running `../luasmith tutorial1.lua`.

### Process Markdown
To actually convert Markdown to HTML, just add the `processMarkdown()` node (as in `sample/tutorial2.lua`):

```lua
return {
	readFromSource("content"),

	-- Convert Markdown files to HTML fragments
	processMarkdown(),
	
	writeToDestination("out"),
}
```

### Templates
Markdown produces an HTML fragment, so you can apply a template to build the rest of the document:

```lua
-- Put generated HTML fragment into a complete document

-- The template is internally passed to etlua.compile()
-- See etlua docs for an explanation of <%= %>, etc.

-- The item schema is roughly:
-- {
--   path = "relative path of the item",
--   pathToRoot = "path TO the root FROM the item",
--   content = "contents of the item/file",
--   ... -- Any additional properties added by the pipeline
-- }
local template = [[
<!DOCTYPE html>
<html>
<head>
<title><%= title %></title>
</head>
<body>
<%- content %>
</body>
</html>
]]

return {
	readFromSource("content"),
	processMarkdown(),
	applyTemplates({
		-- The first item in each pair is a pattern to match item paths
		-- The second item in each pair is the etlua template string itself
		-- If an item's path matches multiple entries, the last match wins

		-- The Lua pattern below means "ends with '.html'"
		{ "%.html$", template },
	}),
	writeToDestination("out"),
}
```

### Adding CSS
Injecting a CSS file is trivial, but remember to reference it using the correct relative path (see `pathToRoot` in the contained HTML template):

```lua
-- Add and reference CSS
local css = [[
body { max-width: 40em; margin: auto; }
]]

-- Note CSS is referenced using `pathToRoot`
local template = [[
<!DOCTYPE html>
<html>
<head>
<title><%= title %></title>
<link rel="stylesheet" href="<%= pathToRoot %>style.css" />
</head>
<body>
<%- content %>
</body>
</html>
]]

return {
	readFromSource("content"),

	-- Inject arbitrary files: key is the path and value is the content
	injectFiles({ ["style.css"] = css }),

	processMarkdown(),
	applyTemplates({ { "%.html$", template } }),
	writeToDestination("out"),
}
```

### Root/Index Page
Using `aggregate()`, you can create a root/index/home page that displays information about all posts, in reverse chronological order. Note that you can add multiple `applyTemplates()` steps, e.g. to format the content in the first pass and then insert the content into a document in a second pass.

```lua
-- Add a root/index/home page, listing blog posts
local index = [[
<ul>
<% for i, item in ipairs(table.sortBy(items, "date", true)) do -%>
<li><a href="<%= item.path %>"><%= item.title %></a> (<%= item.date %>)</li>
<% end -%>
</ul>
]]

local outer = [[
<!DOCTYPE html>
<html>
<head>
<title><%= title %></title>
<link rel="stylesheet" href="<%= pathToRoot %>style.css" />
</head>
<body>
<%- content %>
</body>
</html>
]]

local css = [[
body { max-width: 40em; margin: auto; }
]]

return {
	readFromSource("content"),
	injectFiles({ ["style.css"] = css }),
	processMarkdown(),

	-- Aggregate into an item of path, including a new property
	-- named `items` of all items matching the pattern
	aggregate("index.html", "%.html$"),

	-- Apply a template to list the blog posts
	applyTemplates({ { "^index%.html$", index } }),

	-- Finally, wrap each HTML fragment in a document
	applyTemplates({ { "%.html$", outer } }),

	writeToDestination("out"),
}
```

There you go! Now you've got a barebones blog.

### Bonus: validate internal links
Just add in the `checkLinks()` node to check that relative links are not broken:

```lua
return {
	...
	checkLinks(), -- Check for broken links
	writeToDestination("out"),
}
```

### Beyond the Tutorial
Poke around the included themes in `themes/` for further inspiration.
