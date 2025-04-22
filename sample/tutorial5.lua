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
