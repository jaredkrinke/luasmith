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
