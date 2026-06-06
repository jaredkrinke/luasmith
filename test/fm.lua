return {
	readFromSource(args[3]),
	processMarkdown(),
	applyTemplates({ { "%.html$",
[[
<%= title %>
<%= date %>
<% for _, keyword in ipairs(keywords) do -%>
* <%= keyword %>
<% end -%>
<% if draft then -%>
yep
<% else -%>
nope
<% end -%>
]]
	} }),
	writeToDestination(args[4]),
}

