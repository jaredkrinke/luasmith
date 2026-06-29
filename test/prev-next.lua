return {
	readFromSource(args[3]),
	processMarkdown(),
	processItems(function (items)
		local itemsWithDates = table.include(table.values(items), function (item) return item.date end)
		local sorted = table.sortBy(itemsWithDates, "date")
		local previousItem = nil
		for _, item in ipairs(sorted) do
			if previousItem then
				previousItem.nextItem = item
				item.previousItem = previousItem
			end
			previousItem = item
		end
	end),
	applyTemplates({ { "%.html$", [[
Previous: <% if previousItem then %><%= previousItem.title %><% end %>
Title: <%= title %>
Next: <% if self.nextItem then %><%= self.nextItem.title %><% end %>
]] } }),
	writeToDestination(args[4]),
}

