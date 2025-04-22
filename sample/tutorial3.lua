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
