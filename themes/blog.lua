-- Helpers
local months = { "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" }
function formatDate(date)
	local year, month, day = string.match(date, "^(%d%d%d%d)-(%d%d)-(%d%d)")
	if year and month and day then
		return months[string.ToNumber(month)] .. " " .. string.ToNumber(day) .. ", " .. year
	else
		error("Failed to parse date: " .. date)
	end
end

local htmlDateTemplate = etlua.compile([[<time datetime="<%= short %>"><%= long %></time>]])
function htmlifyDate(date)
	return htmlDateTemplate({ short = date, long = formatDate(date) })
end

-- Build pipeline
build({
	readFromSource("content"),
	injectFiles({
		["style.css"] = fs.readThemeFile("css/blog.css"),
	}),
	processMarkdown(),
	aggregate("index.html", "%.html$"),
	applyTemplates({
		{ "%.html$", fs.readThemeFile("templates/post.etlua") },
		{ "^index.html$", fs.readThemeFile("templates/blog.etlua") },
	}),
	applyTemplates({ { "%.html$", fs.readThemeFile("templates/outer.etlua") } }),
	writeToDestination("out", "^[^_]"),
})

