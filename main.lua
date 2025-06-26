-- Support embedded scripts
local embeddedFiles = {}
local builtInThemes = {}
for _, name in ipairs(_embeddedScripts) do
	embeddedFiles[name] = true

	local theme = string.match(name, "themes/(.-)%.lua")
	if theme and theme ~= "shared" then
		table.insert(builtInThemes, theme)
	end
end

-- Need to hook loadfile since lexer.lua uses it directly...
package.path = package.path .. ";__builtin/?.lua"

local originalLoadFile = loadfile
loadfile = function(filename)
	-- Need to hook loadfile since lexer.lua uses it to load scripts instead of using "require"
	local name = string.match(filename, "^%__builtin/(.*%.lua)$")
	if name and embeddedFiles[name] then
		return _loadEmbeddedScript(name)
	end
	return originalLoadFile(filename)
end

-- Add a searcher to support "require" (note: built-ins are lowest priority, so they can be overridden locally)
table.insert(package.searchers, function (name)
	local filename = string.gsub(name, "%.", "/") .. ".lua"
	if embeddedFiles[filename] then
		return _loadEmbeddedScript(filename)
	end
end)

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
log = {}
function log.warn(message)
	print("WARN:\t" .. message)
end

function log.info(message)
	print("INFO:\t" .. message)
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

function table.groupBy(t, key)
	local groups = {}
	for _, item in ipairs(t) do
		local keyValue = item[key]
		if keyValue then
			-- Support single value or multiple
			local set = keyValue
			if type(keyValue) == "string" then
				set = { keyValue }
			end

			for _, k in ipairs(set) do
				if not groups[k] then
					groups[k] = {}
				end
				table.insert(groups[k], item)
			end
		end
	end
	return groups
end

function table.concatenate(a, b)
	local r = {}
	for k, v in ipairs(a) do
		r[k] = v
	end
	for _, v in ipairs(b) do
		table.insert(r, v)
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
		table.insert(result, item)
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
function string.toNumber(str)
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
	if a == "" then
		return b
	elseif b == "" then
		return a
	else
		return a .. "/" .. b
	end
end

function fs.directory(path)
	local dir = string.match(path, "(.*)/")
	return dir or ""
end

-- Normalize path by resolving ".." and "."
function fs.normalize(path)
	local results = {}
	for part in string.split(path, "/") do
		if part == "." then
			-- Drop any "." components
		elseif part == ".." then
			if #results > 0 then
				results[#results] = nil
			else
				-- Can't fully normalize; just return original path
				return path
			end
		else
			table.insert(results, part)
		end
	end
	return table.concat(results, "/")
end

function fs.resolveRelative(base, relative)
	return fs.normalize(fs.join(fs.directory(base), relative))
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
			table.insert(files, string.sub(path, prefixLength + 1))
		end
	end
end

function fs.enumerateFiles(dir)
	local prefixLength = #dir + 1
	files = {}
	enumerateFilesRecursive(prefixLength, dir, files)
	return files
end

function fs.tryReadFile(path)
	local f = io.open(path, "rb")
	if f == nil then
		return nil
	end

	local content = f:read("*a")
	f:close()
	return content
end

function fs.readFile(path)
	local result = fs.tryReadFile(path)
	if result then
		return result
	end

	-- Fallback to built-in file, if available
	local normalized = fs.normalize(path)
	return (embeddedFiles[normalized] and _readEmbeddedFile(normalized))
		or error("Could not open file: " .. path)
end

function fs.tryLoadFile(path)
	local content = fs.tryReadFile(path)
	if content then
		return load(content, path, "t")
	else
		return nil
	end
end

local themeDirectory = "."
function fs.readThemeFile(path)
	return fs.readFile(fs.join(themeDirectory, path))
end

function fs.loadThemeFile(path)
	local p = fs.join(themeDirectory, path)
	return load(fs.readFile(p), p, "t")
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
					table.insert(includedChanges, change)
				else
					table.insert(excludedChanges, change)
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
					newItem.self = newItem
					transform(newItem)
					newChange = createChange(changeType, newItem)
				end
				table.insert(newChanges, newChange)
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
					table.insert(items, change.item)
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
			table.insert(newChanges, createChange("create", {
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

omitWhen = function (test, pattern)
	return createProcessingNode(function (changes)
		local newChanges = {}
		for _, change in ipairs(changes) do
			-- TODO: How does this work for caching?
			if not (change.changeType == "create" and test(change.item)) then
				table.insert(newChanges, change)
			end
		end
		return newChanges
	end,
	pattern)
end

-- Transform nodes
markdown = {}
markdown.toHtml = _markdownToHtml

local function sluggify(slugs, html)
	-- NOTE: Sadly, this hack only supports ASCII

	-- Remove HTML (elements and entities) and disallowed characters, change to
	-- lowercase, and replace spaces with hyphens
	local result = html
	result = string.gsub(result, "<.->", "")
	result = string.gsub(result, "&.-;", "")
	result = string.gsub(result, "[^a-zA-Z0-9 _%-]", "")
	result = string.lower(result)
	result = string.gsub(result, " ", "-")

	-- Check for duplicates and make unique
	local seenBefore = slugs[result]
	if seenBefore then
		slugs[result] = seenBefore + 1
		result = result .. "-" .. seenBefore
	else
		slugs[result] = 1
	end
	return result
end

local function postProcessMarkdown(content)
	local result = ""
	local position = 1
	local slugs = {}
	while true do
		local i, j, inner = string.find(content, "<h[1-6]>(.-)</h[1-6]>", position)
		if i then
			local id = sluggify(slugs, inner)
			result = result .. string.sub(content, position, i + 2) .. " id=\"" .. id .. "\">" .. string.sub(content, i + 4, j)
			position = j + 1
		else
			result = result .. string.sub(content, position)
			return result
		end
	end
	return result
end

local function parseFrontmatter(item)
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
end

extractFrontmatter = function (pattern)
	return createTransformNode(function (item)
		parseFrontmatter(item)
	end, pattern)
end

processMarkdown = function ()
	return createTransformNode(function (item)
		-- .md -> .html
		item.path = string.gsub(item.path, "%.md$", ".html")

		-- Parse frontmatter
		parseFrontmatter(item)

		item.content = markdown.toHtml(item.content)

		-- TODO: This is a quick hack to add ids to headers. Ideally, this
		-- would be integrated into md4c, and written in C.
		item.content = postProcessMarkdown(item.content)
	end,
	"%.md$")
end

local grammars = {}
lexer = require("lexer")

local function tryLoadGrammar(language)
	-- Cache result of trying to load grammar
	local cached = grammars[language]
	if cached == nil then
		local success, grammar = pcall(function ()
			return lexer.load(language)
		end)

		if success then
			grammars[language] = grammar
			return grammar
		else
			log.info("Syntax highlighting not available for: " .. language)
			grammars[language] = false
			return nil
		end
	else
		return cached or nil
	end
end

local function unescapeHtml(html)
	html = string.gsub(html, "&apos;", "'")
	html = string.gsub(html, "&quot;", "\"")
	html = string.gsub(html, "&lt;", "<")
	html = string.gsub(html, "&gt;", ">")
	html = string.gsub(html, "&amp;", "&")
	return html
end

local function escapeHtml(raw)
	raw = string.gsub(raw, "&", "&amp;")
	raw = string.gsub(raw, ">", "&gt;")
	raw = string.gsub(raw, "<", "&lt;")
	raw = string.gsub(raw, "\"", "&quot;")
	raw = string.gsub(raw, "'", "&apos;")
	return raw
end

local function highlightSyntaxInternal(language, escaped)
	local parser = tryLoadGrammar(language)
	if parser then
		local parts = {}
		local code = unescapeHtml(escaped)
		tokens = parser:lex(code)
		local prev = 1
		for i = 1, #tokens, 2 do
			-- Convert e.g. "string.longstring" to just "string"
			local tag = string.gsub(tokens[i], "%..*", "")

			local raw = string.sub(code, prev, tokens[i+1] - 1)
			local verbatim = escapeHtml(raw)

			-- Don't bother tagging whitespace
			if string.find(tag, "whitespace") then
				table.insert(parts, verbatim)
			else
				table.insert(parts, "<span class=\"hl-")
				table.insert(parts, tag)
				table.insert(parts, "\">")
				table.insert(parts, verbatim)
				table.insert(parts, "</span>")
			end

			prev = tokens[i+1]
		end

		return table.concat(parts)
	end

	return escaped
end

highlightSyntax = function ()
	-- TODO: Consider integrating with md4c-html directly, instead of post-procsesing
	return createTransformNode(function (item)
		local inPre = false
		local inCode = false
		local language = nil
		local codeParts = nil
		local htmlParts = {}

		-- State machine using inPre, inCode, and language
		local handleTag = {
			["pre"] = function () inPre = true end,
			["/pre"] = function () inPre = false end,
			["code"] = function (event)
				if not language then
					if event.attribute == "class" then
						language = string.match(event.value, "^language%-(.*)$")
						if language then
							-- Start accumulating code chunks
							codeParts = {}
						end
					end
				end
			end,
			["/code"] = function () inCode = false end,
		}

		_parseHtml(item.content, function (event)
			local html = nil

			if language then
				-- In a code block; accumulate text nodes or output at end
				local kind = event.event
				if kind == "other" then
					-- Accumulate code
					table.insert(codeParts, event.html)
					html = ""
				elseif kind ~= "exit" then
					-- Highlight and output code
					local code = table.concat(codeParts)
					if code ~= "" then
						html = highlightSyntaxInternal(language, code) .. event.html
					end

					-- Reset
					language = nil
					codeParts = nil
				end
			else
				-- State machine transitions
				local handler = handleTag[event.tag]
				if handler then
					handler(event)
				else
					language = nil
				end
			end

			html = html or event.html
			table.insert(htmlParts, html)
		end)

		item.content = table.concat(htmlParts)
	end,
	"%.html$")
end

injectMetadata = function (properties, pattern)
	return createTransformNode(function (item)
			table.merge(properties, item)
		end,
		pattern)
end

deriveMetadata = function (derivations, pattern)
	return createTransformNode(function (item)
			for key, f in pairs(derivations) do
				item[key] = f(item)
			end
		end,
		pattern)
end

-- TODO: Should templates be able to include frontmatter?
-- Note: Needed to rename etlua's module to not collide with any etlua lexer...
etlua = require("_etlua")

applyTemplates = function(templates)
	local compiled = {}
	for _, pair in ipairs(templates) do
		table.insert(compiled, { pair[1], etlua.compile(pair[2]) })
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
			local groups = table.groupBy(items, property)
			local groupList = {}
			for key, group in pairs(groups) do
				table.insert(groupList, {
					key = key,
					count = #group,
				})
			end

			table.sort(groupList, function (a, b) return a.key < b.key end)

			-- Create index items
			local results = {}
			for key, group in pairs(groups) do
				table.insert(results, {
					path = createIndexPath(key),
					key = key,
					items = group,
					groups = groupList,
				})
			end
			return results
		end,
		pattern)
end

checkLinks = function ()
	return createAggregateNode(function (items)
			-- Enumerate anchors and relative links
			local pathToAnchors = {}
			local pathToLinks = {}
			for _, item in ipairs(items) do
				-- Obviously, only parse HTML files
				if string.sub(item.path, -5) == ".html" then
					local anchors = {}
					local links = {}

					_parseHtml(item.content, function (event)
						if event.attribute and event.value then
							if ((event.tag == "a" and event.attribute == "href") -- Check for links
								or (event.tag == "link" and event.attribute == "href")
								or (event.tag == "script" and event.attribute == "src")
								or (event.tag == "img" and event.attribute == "src"))
								and not string.find(event.value, ":") -- Local/relative links only
							then
								local target = event.value
								if string.sub(event.value, 1, 1) ~= "#" then
									target = fs.resolveRelative(item.path, event.value)
								end
								table.insert(links, target)
							elseif event.attribute == "id" or event.attribute == "name" then
								anchors[event.value] = true
							end
						end
					end)

					pathToAnchors[item.path] = anchors
					pathToLinks[item.path] = links
				else
					pathToAnchors[item.path] = true
				end
			end

			-- Check all links (including hash/anchor)
			for source, links in pairs(pathToLinks) do
				for _, target in ipairs(links) do
					-- Check for #fragment
					local destination = target
					local anchor = nil
					local hash = string.find(target, "#", 1, true)
					if hash then
						if hash == 1 then
							destination = source
						else
							destination = string.sub(target, 1, hash - 1)
						end
						anchor = string.sub(target, hash + 1)
					end

					local anchors = pathToAnchors[destination]
					if anchors then
						if anchor and not anchors[anchor] then
							log.warn("Broken link from \"" .. source .. "\" to \"" .. destination .. "\" (no such fragment: \"#" .. anchor .. "\")")
						end
					else
						log.warn("Broken link from \"" .. source .. "\" to \"" .. target .. "\"")
					end
				end
			end

			return {}
		end)
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
	print("The theme (which configures the build pipeline) can either be specified as the name of a built-in theme or the path to a custom theme (Lua script file).")
	print("")
	print("Built-in themes:")
	print("")
	for _, theme in ipairs(builtInThemes) do
		print("", theme)
	end
	print("")
	os.exit(-1)
end

local themeModule = args[2]
if string.find(themeModule, "%.lua$") then
	themeModule = string.sub(themeModule, 1, #themeModule - 4)
	themeDirectory = fs.directory(themeModule)
else
	-- Use built-in theme
	themeDirectory = fs.join("themes", themeModule)
	themeModule = "themes." .. themeModule  .. ".theme"
end

local pipeline = require(themeModule)
build(pipeline)

