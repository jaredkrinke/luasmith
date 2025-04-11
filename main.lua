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
function append(t, i)
	t[#t + 1] = i
end

function merge(source, dest)
	for k, v in pairs(source) do
		dest[k] = v
	end
end

function copy(t)
	local r = {}
	merge(t, r)
	return r
end

function map(t, f)
	local r = {}
	for k, v in pairs(t) do
		r[k] = f(v)
	end
	return r
end

function concatenate(a, b)
	local r = {}
	for k, v in pairs(a) do
		r[k] = v
	end
	for _, v in pairs(b) do
		append(r, v)
	end
	return r
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
function lines(str)
	local i = 0
	return function ()
		if i > #str then
			return nil
		else
			local j = string.find(str, "\n", i)
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

-- Frontmatter parsing
function parseLua(lua)
	local o = {}
	load(lua, "frontmatter", "t", o)()
	return o
end

function parseYaml(yaml)
	local o = {}
	for line in lines(yaml) do
		-- TODO: Trim
		-- TODO: Quotes (and escaped quotes)
		-- TODO: Arrays
		local _, _, k, v = string.find(line, "^(.-): *(.+)")
		if k and v then
			o[k] = v
		end
	end
	return o
end

-- File system helpers
function pathJoin(a, b)
	return a .. "/" .. b
end

function pathDirectory(path)
	local _, _, dir = string.find(path, "(.*)/")
	return dir or ""
end

function isDirectory(f)
	return "directory" == io.popen("stat -c %F " .. f):read()
end

function createDirectory(dir)
	-- TODO: Obviously doesn't handle spaces
	print("Create directory: " .. dir)
	os.execute("mkdir -p " .. dir)
end

function enumerateFilesRecursive(prefixLength, dir, files)
	for name in io.popen("ls " .. dir):lines() do
		local path = pathJoin(dir, name)
		if isDirectory(path) then
			enumerateFilesRecursive(prefixLength, path, files)
		else
			append(files, string.sub(path, prefixLength + 1))
		end
	end
end

function enumerateFiles(dir)
	local prefixLength = #dir + 1
	files = {}
	enumerateFilesRecursive(prefixLength, dir, files)
	return files
end

function readFile(path)
	local f = io.open(path, "rb")
	local content = f:read("*a")
	f:close()
	return content
end

function writeFile(path, content)
	local f = io.open(path, "wb")
	f:write(content)
	f:close()
end

-- Processing node helpers
function createProcessingNode(process, pattern)
	local p = process
	if pattern then
		-- Input pattern was supplied; only process selected changes
		p = function (changes)
			local includedChanges = {}
			local excludedChanges = {}
			for _, change in pairs(changes) do
				if string.match(change.item.path, pattern) then
					append(includedChanges, change)
				else
					append(excludedChanges, change)
				end
			end
			return concatenate(excludedChanges, process(includedChanges) or {})
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
			for _, change in pairs(changes) do
				local changeType = change.changeType
				local newChange = change
				if changeType ~= "delete" then
					local newItem = copy(change.item)
					transform(newItem)
					newChange = {
						changeType = changeType,
						item = newItem,
					}
				end
				append(newChanges, newChange)
			end
			return newChanges
		end,
		pattern)
end

-- TODO: Aggregate nodes

-- Source/sink nodes
readFromSource = function (dir)
	return createProcessingNode(function (changes)
			-- TODO: Check for differences from last run
			newChanges = map(enumerateFiles(dir), function (path)
				return {
					changeType = "create",
					item = {
						path = path,
						content = readFile(pathJoin(dir, path)),
					},
				}
			end)

			return concatenate(changes, newChanges)
		end)
end

writeToDestination = function (dir, pattern)
	return createProcessingNode(function (changes)
			local dirsMade = {}
			for _, change in pairs(changes) do
				-- TODO: Handle deletes
				local ct = change.changeType
				if ct == "create" or ct == "update" then
					local item = change.item
					local localPath = pathJoin(dir, item.path)
					local localDir = pathDirectory(localPath)
					if not dirsMade[localDir] then
						createDirectory(localDir)
						dirsMade[localDir] = true
					end
					writeFile(localPath, item.content)
				end
			end
		end,
		pattern)
end

-- Transform nodes
processMarkdown = function ()
	return createTransformNode(function (item)
		-- .md -> .html
		item.path = string.gsub(item.path, "%.md$", ".html")

		-- Parse YAML frontmatter
		local i, j, frontmatter = string.find(item.content, "^%-%-%-\n(.-)\n%-%-%-\n")
		if i and j and frontmatter then
			merge(parseYaml(frontmatter), item)
			item.content = string.sub(item.content, j + 1)
		else
			-- Parse Lua frontmatter
			i, j, frontmatter = string.find(item.content, "^%[%[\n(.-)\n%]%]\n")
			if i and j and frontmatter then
				merge(parseLua(frontmatter), item)
				item.content = string.sub(item.content, j + 1)
			end
		end

		item.content = markdownToHtml(item.content)
		print(format(item))
	end,
	"%.md$")
end

applyTemplates = function(templates)
	local compiled = {}
	for _, pair in pairs(templates) do
		append(compiled, { pair[1], etlua.compile(pair[2]) })
	end

	return createTransformNode(function (item)
		local path = item.path
		local matchingTemplate = nil
		for _, pair in pairs(compiled) do
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

-- Entry point
function process(nodes)
	changes = {}
	for _, node in pairs(nodes) do
		changes = node.process(changes)
	end
end

-- Run
templateDefault = [[
<html>
<head><title><%= title %></title></head>
<body>
<%- content %>
</body>
</html>
]]

process({
	readFromSource("content"),
	processMarkdown(),
	applyTemplates({
		{ "%.html$", templateDefault },
	}),
	writeToDestination("out", "^[^_]"),
})

