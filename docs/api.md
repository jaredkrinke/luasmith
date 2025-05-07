# API
This documentation is split into a few sections

* [Lua standard library information](#lua)
* [General helper functions](#lua-helpers)
* [Item schema for representing items in luasmith](#item-schema)
* [Built-in processing nodes for constructing pipelines](#processing-nodes)
* Infrastructure for creating new processing nodes (TODO)

## Lua
luasmith exposes Lua 5.2's standard library. See the [Lua 5.2 manual](https://www.lua.org/manual/5.2/manual.html#6) for information about basic Lua functions such as `pairs`, `string.find`, etc.

In particular, note that luasmith builds on top of [Lua's string matching patterns](https://www.lua.org/manual/5.2/manual.html#6.4.1) (which are similar to Regular Expressions).

## Lua Helpers
For convenience, luasmith exposes some generic Lua helper functions, as documented here. See [main.lua](../main.lua) for the source code.

### `table` Helpers
* `table.append(table, item)` appends an item to a table that is being used as an array
* `table.merge(source, dest)` copies (shallowly) keys and values from table `source` to `dest`
* `table.copy(table)` creates a shallow copy of `table`
* `table.map(table, func)` creates a new (array) table that is the result of applying `func` to each value in `table`
* `table.sortBy(table, prop, desc)` creates a new (array) table with items ordered by the value of key `prop`, optionally in descending order (if `desc` is not false)
* `table.groupby(table, key)` groups items in array `table` under keys in a new table -- this is used for creating e.g. index pages based on keywords
* `table.concatenate(table1, table2)` creates a new array table that contains values from `table1` followed by items from `table2`

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
* `fs.createDirectory(dir)` creates directory at path `dir`, including any necessary parent directories
* `fs.readFile(path)` reads the file at `path` and returns its contents as a string
* `fs.readThemeFile(path)` reads the file at `path`, relative to the current `theme.lua` file
* `fs.writeFile(path, content)` writes file with `content` to `path`

## Item Schema
Items in luasmith are represented as Lua tables, with a few known keys:

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
* `processMarkdown()` converts `*.md` files from Markdown to HTML (`.html`), extracting either Lua or (limited) YAML frontmatter metadata in the process
* `injectMetadata(properties, pattern)` merges `properties` into items that match path `pattern`
* `deriveMetadata(derivations, pattern)` similar to `injectMetadata` but instead of adding fixed metadata, it runs functions on the item; the format of `derivations` is `{ [property] = f, ... }` where `f` takes in the item and returns the new value
* `applyTemplates(templates)` applies a single template to each matched item; note that `templates` is an array of the format `{ [pattern] = template }` and the last match wins (e.g. so you can match "all HTML files" but then override that logic for specific items using more specific patterns)

### Aggregate Nodes
* `aggregate(path, pattern)` creates a new item at `path` with empty `content`, but with an `items` property that is an array of all items matched by `pattern`
* `createIndexes(createPath, property, pattern)` creates multiple new "index" items, one for each unique value of the property `property` on items matching `pattern`, at the path computed by `createPath(value)`; the "index" item format includes `{ key = <the unique value>, items = <array of items with that value>, groups = <map of unique values to items for ALL unique values> }`

Note: `aggregate()` can be easily used to create a blog index/home page with a list of posts. `createIndexes()` can be used to create e.g. "keyword index" pages.
