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

function copy(t)
	r = {}
	for k, v in pairs(t) do
		r[k] = v
	end
	return r
end

function map(t, f)
	r = {}
	for k, v in pairs(t) do
		r[k] = f(v)
	end
	return r
end

function concatenate(a, b)
	r = {}
	for k, v in pairs(a) do
		r[k] = v
	end
	for _, v in pairs(b) do
		append(r, v)
	end
	return r
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
			newChanges = {}
			for _, change in pairs(changes) do
				local changeType = change.changeType
				local newChange = change
				if changeType ~= "delete" then
					newItem = copy(change.item)
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
		-- TODO: Front matter
		item.path = string.gsub(item.path, "%.md$", ".html")
		item.content = markdownToHtml(item.content)
	end,
	"%.md$")
end

-- Entry point
function process(nodes)
	changes = {}
	for _, node in pairs(nodes) do
		changes = node.process(changes)
	end
end

-- Run
process({
	readFromSource("content"),
	processMarkdown(),
	writeToDestination("out", "^[^_]"),
})

