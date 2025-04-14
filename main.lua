-- TODO: Ignore non-file/directory

-- TODO: Needed?
function format(v)
	local t = type(v)
	if t == "table" then
		local s = "{"
		for k, v in pairs(v) do
			s = s .. " " .. tostring(k) .. " = " .. format(v) .. ","
		end
		s = s .. " }"
		return s
	elseif t == "string" then
		-- TODO: Escape quotes
		return "\"" .. tostring(v) .. "\""
	else
		return tostring(v)
	end
end

-- Helpers
function table.append(t, i)
	t[#t + 1] = i
end

function table.merge(source, dest)
	for k, v in pairs(source) do
		dest[k] = v
	end
end

function table.copy(t)
	local r = {}
	table.merge(t, r)
	return r
end

function table.map(t, f)
	local r = {}
	for k, v in ipairs(t) do
		r[k] = f(v)
	end
	return r
end

function table.sortBy(t, property, descending)
	local sorted = table.copy(t)
	if descending then
		table.sort(sorted, function (a, b) return a[property] > b[property] end)
	else
		table.sort(sorted, function (a, b) return a[property] < b[property] end)
	end
	return sorted
end

function table.concatenate(a, b)
	local r = {}
	for k, v in ipairs(a) do
		r[k] = v
	end
	for _, v in ipairs(b) do
		table.append(r, v)
	end
	return r
end

iterator = {}

function iterator.count(iterator)
	local count = 0
	for _ in iterator do
		count = count + 1
	end
	return count
end

function iterator.collect(iterator)
	local result = {}
	for item in iterator do
		table.append(result, item)
	end
	return result
end

-- TODO: Needed?
function chainEnvironment(parent)
	local e = {}
	setmetatable(e, {
		__index = function (table, key)
			local r = rawget(table, key)
			if r then
				return r
			end
			return parent[key]
		end,
	})
	return e
end

-- String helpers
function string.ToNumber(str)
	return 0 + str
end

function string.charAt(str, i)
	return string.sub(str, i, i)
end

function string.split(str, separator)
	local i = 0
	return function ()
		if i > #str then
			return nil
		else
			local j = string.find(str, separator, i)
			if j then
				local result = string.sub(str, i, j - 1)
				i = j + 1
				return result
			else
				local result =  string.sub(str, i)
				i = #str + 1
				return result
			end
		end
	end
end

function string.lines(str)
	return string.split(str, "\n")
end

function string.trim(str)
	return string.match(str, "^%s*(.-)%s*$")
end

-- Frontmatter parsing
local function parseLua(lua)
	local o = {}
	load(lua, "frontmatter", "t", o)()
	return o
end

local function unquote(str)
	if string.charAt(str, 1) == "\"" and string.charAt(str, #str) == "\"" then
		return string.gsub(string.sub(str, 2, -2), [[\"]], [["]])
	else
		return str
	end
end

local function parseYamlValue(v)
	local trimmed = string.trim(v)

	-- Check if array
	if string.charAt(trimmed, 1) == "[" and string.charAt(trimmed, #trimmed) == "]" then
		return table.map(iterator.collect(string.split(string.sub(trimmed, 2, -2), ",")), parseYamlValue)
	else
		return unquote(trimmed)
	end
end

local function parseYaml(yaml)
	local o = {}
	for line in string.lines(yaml) do
		local k, v = string.match(line, "^(.-):(.+)")
		if k and v then
			o[k] = parseYamlValue(v)
		end
	end
	return o
end

-- File system helpers
fs = {}

function fs.join(a, b)
	return a .. "/" .. b
end

function fs.directory(path)
	local dir = string.match(path, "(.*)/")
	return dir or ""
end

function fs.createDirectory(dir)
	-- Create parent directories as needed
	local last = #dir
	local i = 1
	while true do
		local slash = string.find(dir, "/", i, true)
		if slash then
			_mkdir(string.sub(dir, 1, slash - 1))
			if slash == last then
				return
			else
				i = slash + 1
			end
		else
			_mkdir(dir)
			break
		end
	end
end

fs.listDirectory = _listDirectory
fs.isDirectory = _isDirectory

local function enumerateFilesRecursive(prefixLength, dir, files)
	for _, name in ipairs(fs.listDirectory(dir)) do
		local path = fs.join(dir, name)
		if fs.isDirectory(path) then
			enumerateFilesRecursive(prefixLength, path, files)
		else
			table.append(files, string.sub(path, prefixLength + 1))
		end
	end
end

function fs.enumerateFiles(dir)
	local prefixLength = #dir + 1
	files = {}
	enumerateFilesRecursive(prefixLength, dir, files)
	return files
end

function fs.readFile(path)
	local f = io.open(path, "rb")
	if f == nil then
		error("Could not open file: " .. path)
	end

	local content = f:read("*a")
	f:close()
	return content
end

local themeDirectory = "."
function fs.readThemeFile(path)
	return fs.readFile(fs.join(themeDirectory, path))
end

function fs.writeFile(path, content)
	local f = io.open(path, "wb")
	f:write(content)
	f:close()
end

local function computePathToRoot(path)
	return string.rep("../", iterator.count(string.gmatch(path, "/")))
end

-- Processing node helpers
function createChange(changeType, item)
	if not item.pathToRoot then
		item.pathToRoot = computePathToRoot(item.path)
	end

	return {
		changeType = changeType,
		item = item,
	}
end

function createProcessingNode(process, pattern)
	local p = process
	if pattern then
		-- Input pattern was supplied; only process selected changes
		p = function (changes)
			local includedChanges = {}
			local excludedChanges = {}
			for _, change in ipairs(changes) do
				if string.match(change.item.path, pattern) then
					table.append(includedChanges, change)
				else
					table.append(excludedChanges, change)
				end
			end
			return table.concatenate(excludedChanges, process(includedChanges) or {})
		end
	end

	return {
		process = p,
	}
end

-- TODO: Consider supporting multiple outputs
function createTransformNode(transform, pattern)
	return createProcessingNode(function (changes)
			local newChanges = {}
			for _, change in ipairs(changes) do
				local changeType = change.changeType
				local newChange = change
				if changeType ~= "delete" then
					local newItem = table.copy(change.item)
					transform(newItem)
					newChange = createChange(changeType, newItem)
				end
				table.append(newChanges, newChange)
			end
			return newChanges
		end,
		pattern)
end

function createAggregateNode(aggregate, pattern)
	-- TODO: Cache inputs from previous runs
	return createProcessingNode(function (changes)
			-- Find items
			local items = {}
			for _, change in ipairs(changes) do
				if change.changeType ~= "delete" then
					table.append(items, change.item)
				end
			end

			-- Run aggregation
			local outputItems = aggregate(items)
			local newChanges = table.map(outputItems, function (item) return createChange("create", item) end)
			return table.concatenate(changes, newChanges)
		end,
		pattern)
end

-- Source/sink nodes
injectFiles = function (files)
	return createProcessingNode(function (changes)
		newChanges = {}
		for path, content in pairs(files) do
			-- TODO: Detect differences, probably via hash
			table.append(newChanges, createChange("create", {
				path = path,
				content = content
			}))
		end
		return table.concatenate(changes, newChanges)
	end)
end

readFromSource = function (dir)
	return createProcessingNode(function (changes)
			-- TODO: Check for differences from last run
			newChanges = table.map(fs.enumerateFiles(dir), function (path)
				return createChange("create", {
					path = path,
					content = fs.readFile(fs.join(dir, path)),
				})
			end)

			return table.concatenate(changes, newChanges)
		end)
end

writeToDestination = function (dir, pattern)
	return createProcessingNode(function (changes)
			local dirsMade = {}
			for _, change in ipairs(changes) do
				-- TODO: Handle deletes
				local ct = change.changeType
				if ct == "create" then
					local item = change.item
					local localPath = fs.join(dir, item.path)
					local localDir = fs.directory(localPath)
					if not dirsMade[localDir] then
						fs.createDirectory(localDir)
						dirsMade[localDir] = true
					end
					fs.writeFile(localPath, item.content)
				end
			end
		end,
		pattern)
end

-- Transform nodes
markdown = {}
markdown.toHtml = _markdownToHtml

processMarkdown = function ()
	return createTransformNode(function (item)
		-- .md -> .html
		item.path = string.gsub(item.path, "%.md$", ".html")

		-- Parse YAML frontmatter
		local i, j, frontmatter = string.find(item.content, "^%-%-%-\n(.-)\n%-%-%-\n")
		if i and j and frontmatter then
			table.merge(parseYaml(frontmatter), item)
			item.content = string.sub(item.content, j + 1)
		else
			-- Parse Lua frontmatter
			i, j, frontmatter = string.find(item.content, "^%[%[\n(.-)\n%]%]\n")
			if i and j and frontmatter then
				table.merge(parseLua(frontmatter), item)
				item.content = string.sub(item.content, j + 1)
			end
		end

		item.content = markdown.toHtml(item.content)
	end,
	"%.md$")
end

-- TODO: Should templates be able to include frontmatter?
applyTemplates = function(templates)
	local compiled = {}
	for _, pair in ipairs(templates) do
		table.append(compiled, { pair[1], etlua.compile(pair[2]) })
	end

	return createTransformNode(function (item)
		local path = item.path
		local matchingTemplate = nil
		for _, pair in ipairs(compiled) do
			-- Note: Last matching template wins
			if string.find(path, pair[1]) then
				matchingTemplate = pair[2]
			end
		end

		if matchingTemplate then
			item.content = matchingTemplate(item)
		end
	end)
end

-- Aggregate nodes
aggregate = function (path, pattern)
	return createAggregateNode(function (items)
			return {
				{
					path = path,
					items = items,
				},
			}
		end,
		pattern)
end

createIndexes = function (createIndexPath, property, pattern)
	return createAggregateNode(function (items)
			-- Create groups
			local groups = {}
			for _, item in ipairs(items) do
				local key = item[property]
				if key then
					-- Support single value or multiple
					local set = key
					if type(key) == "string" then
						set = { key }
					end

					for _, k in ipairs(set) do
						if not groups[k] then
							groups[k] = {}
						end
						table.append(groups[k], item)
					end
				end
			end

			-- Create index items
			local results = {}
			for key, group in pairs(groups) do
				table.append(results, { path = createIndexPath(key), key = key, items = group })
			end
			return results
		end,
		pattern)
end

-- Top-level logic
function build(nodes)
	changes = {}
	for _, node in ipairs(nodes) do
		changes = node.process(changes)
	end
end

-- Entry point
if #args < 2 then
	print("\nUsage: " .. args[1] .. " <THEME_NAME | THEME_PATH>\n")
	print("The theme (which configures the build pipeline) can either be specified as the name of a theme (foo => themes/foo.lua) or the path to a custom theme (Lua script file).")
	print("")
	os.exit(-1)
end

local userScriptFile = args[2]
if not string.find(userScriptFile, "%.lua$") then
	-- Use built-in theme, relative to executable
	userScriptFile = fs.join(fs.join(fs.directory(args[1]), "themes"), userScriptFile .. ".lua")
end

themeDirectory = fs.directory(userScriptFile)
load(fs.readFile(userScriptFile), userScriptFile, "t")()

