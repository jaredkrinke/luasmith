# luasmith
**luasmith** is a small, simple, and flexible [static site generator](https://en.wikipedia.org/wiki/Static_site_generator) that is similar in design to [Metalsmith](https://metalsmith.io/), but much smaller because it's built on top of [Lua](https://www.lua.org/) and C instead of JavaScript and Node.js.

Most of the heavy lifting in luasmith is done by [md4c](https://github.com/mity/md4c) ([patched](https://github.com/jaredkrinke/md4c/commit/fc4cac5277b060450d93b06a67397388defa358d) for relative links), [Lua](https://www.lua.org/), and [etlua](https://github.com/leafo/etlua).

Note that luasmith is more of a proof-of-concept that, while functional, shouldn't be relied upon to take over the world.

To get a feel for luasmith, either [read over the design](#design) or [go through the tutorial](docs/tutorial.md).

## Supported Platforms
Currently, luasmith is only tested on Linux and NetBSD. It should work on generic POSIX platforms. It has not been tested on Windows yet.

## Architecture
luasmith is designed around the concept of a "theme", which is basically a processing pipeline, probably including some templates (and perhaps static assets). You run the tool by providing a either the path to a Lua script or the name of a built-in theme:

```
./luasmith theme.lua
```

or for a built-in theme under you only supply a name, and that is internally expanded to `<path to luasmith>/themes/<name of theme>/theme.lua`:

```
./luasmith devblog
```

### Under the Hood
After pointing it to a theme, it's completely up to the theme what happens next, but all built-in themes do the following:

1. Enumerate files in the input directory (named `content/` by default)
2. Process Markdown (and frontmatter) for `*.md` files
3. Create a root page (and possibly keyword index pages too)
4. Apply templates (using [etlua](https://github.com/leafo/etlua))
5. Write everything to the output directory (named `out/` by default)

Note that the built-in templates assume Markdown files contain metadata in frontmatter that includes `title`, `description`, `date`, and optionally `keywords`. See the `example/content/` directory for examples (using both Lua and a subset of YAML).

### Customization
If you want to customize the site's appearance or functionality, just copy an existing theme directory and start modifying the templates and/or `theme.lua` script.

## Example / Tutorial
See [docs/tutorial.md](docs/tutorial.md) for a tutorial that starts from scratch with a trivial pipeline and builds it up into a simple blog theme.

## API Documentation
See [docs/api.md](docs/api.md) for detailed information on helper functions, processing nodes, etc.

