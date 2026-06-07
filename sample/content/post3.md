+++
title = "Second post"
description = "This post uses TOML for frontmatter, instead of YAML or Lua."
date = 2025-04-22
+++

This is the third post. It comes after [the second one](post2.md).

## TOML frontmatter format

Text fields must have quotation marks around strings. Numeric fields, including Boolean and date/time values, do not need quotation marks. Arrays list multiple values, enclosed by brackets, with their elements separated by commas. Use an array for a post that contains more than one `keyword`.

This post's TOML frontmatter, with additional examples:

```toml
title = "Second post"
description = "This post uses TOML for frontmatter, instead of YAML or Lua."
date = 2025-04-22
draft = false
keywords = ["lua", "toml"]
```