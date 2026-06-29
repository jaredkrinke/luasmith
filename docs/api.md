# API
This documentation is split into a few sections:

* [Lua standard library information](#lua)
* [General helper functions](#lua-helpers)
* [Item schema for representing items in luasmith](#item-schema)
* [Built-in processing nodes for constructing pipelines](#processing-nodes)
* Infrastructure for creating new processing nodes (TODO)

## Lua
luasmith exposes Lua 5.2's standard library. See the [Lua 5.2 manual](https://www.lua.org/manual/5.2/manual.html#6) for information about basic Lua functions such as `pairs`, `string.find`, etc.

In particular, note that luasmith builds on top of [Lua's string matching patterns](https://www.lua.org/manual/5.2/manual.html#6.4.1) (which are similar to Regular Expressions).

## Site Schema
The built-in themes each support site-level metadata, as returned by a script in the input directory named `site.lua`.

### `blog` Theme
An optional `index.md` file in the root of the input directory will have its rendered contents added to the top of (only) the site's landing page. This is useful for adding an introduction, contact info, links to other sites, etc.

Required/recommended:

* `title`: Title for the site
* `url`: Root URL for the site (e.g. `https://example.com/`) -- this is used to provide absolute links in the Atom feed

Optional:

* `subtitle`: Subtitle for the site (default: `nil`/none)
* `footer`: Footer (raw HTML) to append to the end of every page (default: `nil`/none)
* `keywordDirectoryPattern`: Lua pattern for deriving keywords from the first capture group of item paths (default: `"^posts/(.-)/.+%.html$"`, meaning the (first) subdirectory of `posts/` is the name of a keyword)
* `syntaxAliases`: Aliases for syntax highlighting, e.g. to have a code block tagged as `sh` use the Scintillua highlighter ("lexer") for Bash, you could set `syntaxAliases = { sh = "bash" }`

### `md2blog` Theme
* `title`: Title for the site
* `subtitle`: Subtitle for the site
* `url`: Root URL for the site (e.g. `https://example.com/`) -- this is used to provide absolute links in the Atom feed
* `links`: List of links to include at the top of each page, example: `links = { { "About", "about.html" }, { "Contact", "mailto:contact@example.com" } }`

## Item Schema
### Frontmatter
Both `blog` and `md2blog` items make use of the following frontmatter properties:

* `title`: Name of the article
* `date`: Creation date of the article, in the form `YYYY-MM-DD` or `YYYY-MM-DD HH:mm`
* `description`: Description or summary of the article (optional in the `blog` theme)
* `keywords`: Optional array of keywords, e.g. `keywords: [foo,bar]`

Optional:

* `draft`: Optionally set to `true` to exclude an item

Additional properties can be added, for use in custom templates.

### Templates
Items in luasmith are represented as Lua tables, with a few known keys that can be used in templates (in addition to any frontmatter properties):

* `path` the path (relative to the input/output root) of the item
* `pathToRoot` the path *from* the item *to* the root (useful for relative references)
* `content` the content of the item/file, represented as a Lua string (note that Lua strings can contain binary data)

Additional properties can be added by simply setting additional key-value pairs on the item's table.

## Processing Nodes
There are a few different kinds of processing nodes in luasmith (number of inputs and outputs shown in parentheses):

* Source nodes: find and produce new items (0:M)
* Sink nodes: process items, but don't produce anything (N:0)
* Transform nodes: process items in isolation (1:M)
* Aggregate nodes: process items as a group (N:M)

### Source Nodes
* `readFromSource(dir)` reads files from a directory
* `injectFiles(files)` inserts new files; the table format is `{ [path] = content, ... }`

### Sink Nodes
* `writeToDestination(dir)` writes items into files in `dir`
* `omitWhen(test, pattern)` calls function `test` on each item matching path `pattern` and removes items that return non-false

### Transform Nodes
* `processMarkdown()` converts `*.md` files from Markdown to HTML (`.html`), extracting either Lua, (limited) YAML, or (limited) TOML frontmatter metadata in the process
* `highlightSyntax(options?)` adds HTML spans with `.hl-*` CSS classes to fenced code blocks (see notes [below](#syntax-highlighting) for more detail)
* `processEtlua(pattern?)` evaluates any [etlua](https://github.com/leafo/etlua) blocks in item content, similar to Hugo shortcodes, but using Lua (note: due to Markdown processing escaping angle brackets, be sure to use this node *prior* to `processMarkdown()`); `pattern` defaults to `%.md$` ("*.md")
* `injectMetadata(properties, pattern)` merges `properties` into items that match path `pattern`
* `deriveMetadata(derivations, pattern)` similar to `injectMetadata` but instead of adding fixed metadata, it runs functions on the item; the format of `derivations` is `{ [property] = f, ... }` where `f` takes in the item and returns the new value
* `applyTemplates(templates)` applies a single template to each matched item; note that `templates` is an array of the format `{ [pattern] = template }` and the last match wins (e.g. so you can match "all HTML files" but then override that logic for specific items using more specific patterns)

#### Syntax highlighting
Syntax highlighting uses [Scintillua](https://github.com/orbitalquark/scintillua) internally. `highlightSyntax()` accepts an optional table, with the following keys:

* `aliases`: Table of syntax aliases, where keys are code block tags and values are the corresponding  highlighters ("lexers"), for example `highlightSyntax({ sh = "bash" })` would highlight code blocks tagged `sh` with the embedded Bash lexer (`bash.lua`)

luasmith's embedded copy of Scintillua may be slightly out of date, but, for reference, [here is a list of Scintillua lexers](https://github.com/orbitalquark/scintillua/tree/default/lexers).

Note: if you need to tweak or add a lexer, you can simply add a lexer on Lua's search path (usually the current working directory) and it will take precedence over any embedded lexer.

### Aggregate Nodes
* `aggregate(path, pattern)` creates a new item at `path` with empty `content`, but with an `items` property that is an array of all items matched by `pattern`
* `createIndexes(createPath, property, pattern)` creates multiple new "index" items, one for each unique value of the property `property` on items matching `pattern`, at the path computed by `createPath(value)`; the "index" item format includes `{ key = <the unique value>, items = <array of items with that value>, groups = <map of unique values to items for ALL unique values> }`
* `checkLinks()` verifies that relative link targets in HTML files exist, including hash/fragments/anchors (i.e. "checks for broken links")

Note: `aggregate()` can be easily used to create a blog index/home page with a list of posts. `createIndexes()` can be used to create e.g. "keyword index" pages.

There is also an "escape hatch" for arbitrarily modifying the entire site at once, for example if you want to add previous/next links between posts:

* `processItems(process)`: Calls `process` (a function) with a representation of all items, in the form of a key-value table with paths as keys and items as values; you can add and remove entries to/from the map (luasmith will internally added `path` and `pathToRoot` properties to new items)

Here's an example for adding `previousItem`/`nextItem` links to all items that have a `date` property:

```lua
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
```

## Theme helpers
The built-in themes rely on some shared and reusable (though not necessarily guaranteed to be stable across release!) functionality.

### Atom feeds
To add an Atom feed to a from-scratch theme, you'll need to

1. Load the shared helpers: `shared = require("themes.shared")`
2. Define site metadata: `local site = { title = ..., url = ... }`
3. Aggregate articles into a new item named e.g. `feed.xml`, in the build pipeline: `aggregate("feed.xml", "%.html$"),`
4. Inject site metadata into items, as part of the build pipeline: `injectMetadata({ site = site }),`
5. Ensure that `applyTemplates()` to generate the feed using the built-in feed template is run, *in a separate step*, *before* generic/outer HTML templates (to avoid having those included in the generated feed): `applyTemplates({ { "^feed.xml$", fs.readFile("themes/shared/feed.etlua") } })`

Note: the last bit of code uses `readFile` instead of the usual `readThemeFile` because it's using the built-in `feed.etlua` file instead of a file from this particular theme's directory.

## Lua Helpers
For convenience, luasmith exposes some generic Lua helper functions, as documented here. See [main.lua](../main.lua) for the source code.

### `log` Helpers
* `log.warn(message)` logs a warning
* `log.info(message)` logs a message

### `table` Helpers
* `table.merge(source, dest)` copies (shallowly) keys and values from table `source` to `dest`
* `table.copy(table)` creates a shallow copy of `table`
* `table.map(table, func)` creates a new (array) table that is the result of applying `func` to each value in `table`
* `table.sortBy(table, prop, desc)` creates a new (array) table with items ordered by the value of key `prop`, optionally in descending order (if `desc` is not false)
* `table.sorted(table, compare)` creates a new (array) table with items ordered by the result of calling `compare(a, b)` on two elements
* `table.groupBy(table, key)` groups items in array `table` under keys in a new table -- this is used for creating e.g. index pages based on keywords
* `table.concatenate(table1, table2)` creates a new array table that contains values from `table1` followed by items from `table2`
* `table.include(table, incl)` creates a new array table that contains values from array table `table` for which the function `incl` returns a truthy value
* `table.values(table)` creates a new array table that contains the values from `table` (in unspecified order); think of this as converting a map to an array (discarding the keys in the process)

### `iterator` Helpers
* `iterator.count(iterator)` counts the number of items in a Lua iterator
* `iterator.collect(iterator)` collects items from a Lua iterator into an array table

### `string` Helpers
* `string.toNumber(str)` converts a decimal integer string into a number
* `string.charAt(str, index)` returns a single-byte string that represents the byte at position `index` in `str`
* `string.split(str, separator)` returns a Lua iterator that returns substrings of `str` that are separated by the single character string `separator`
* `string.lines(str)` returns a Lua iterator that returns lines ("\n"-separated) of `str`
* `string.trim(str)` returns `str`, with spaces from the beginning and end removed

### `fs` Helpers
* `fs.join(part1, part2)` joins `part1` and `part2` with a `/` (note: if one value is an empty string, this just returns the other value)
* `fs.dir(path)` returns the directory part of `path` (without any trailing slash)
* `fs.normalize(path)` normalizes `path` by converting `\` to `/` and resolving `..` and `.`
* `fs.resolveRelative(base, relative)` resolves path `relative`, relative to `base`
* `fs.createDirectory(dir)` creates directory at path `dir`, including any necessary parent directories
* `fs.enumerateFiles(dir)` returns a list of files under `dir`
* `fs.tryReadFile(path)` tries to read the file at `path` and return its contents as a string, returning `nil` if the file doesn't exist or can't be opened
* `fs.tryLoadFile(path)` tries to load a Lua script at `path`, returning `nil` on error
* `fs.readFile(path)` reads the file at `path` and returns its contents as a string
* `fs.readThemeFile(path)` reads the file at `path`, relative to the current `theme.lua` file
* `fs.loadThemeFile(path)` loads the Lua script at `path` (relative to the current `theme.lua` file) into a Lua chunk (but *does not* execute it), returning a function to execute the code
* `fs.doThemeFile(path)` loads and executes the Lua script at `path` (relative to the current `theme.lua` file), returning any value that is returned from the script (this is useful for splitting theme code into multiple files and loading them relative to the main script)
* `fs.writeFile(path, content)` writes file with `content` to `path` (relative to the working directory, i.e. where `luasmith` was invoked)

### `url` Helpers
* `url.isRelative(url)` returns true if `url` is a relative URL (instead of absolute)

### Item/HTML helpers
* `lib.item.repathRelativeLinks(item, prefix)` rewrites relative HTML links so that they start with the given prefix (this can be used to rewrite relative links as absolute links, e.g. as used when built-in themes produce Atom feeds)
* `lib.item.createTableOfContents(item)` generates a table of contents for the given HTML item (see example below)

#### Inserting a table of contents
Example of inserting a table of contents into an etlua template (note the call to `lib.item.createTableOfContents`:

```etlua
<header>
<h1><%= title %></h1>
<details><summary>Table of contents</summary>
<%- lib.item.createTableOfContents(self) %>
</details>
</header>
```

