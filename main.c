#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <dirent.h>
#include <sys/stat.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <md4c-html.h>

/* Compile in Lua scripts */
#include "main.lua.h"
#include "etlua.lua.h"

#define TRUE 1
#define FALSE 0

void append_internal(const MD_CHAR* str, MD_SIZE size, void* o) {
	/* TODO: Reuse a single buffer instead of allocating each time */
	lua_State* L = (lua_State*)o;
	char* s = strndup(str, size); /* Ensure null-terminated */

	lua_pushstring(L, s);
	free(s);
	lua_concat(L, 2);
}

int l_markdown_to_html(lua_State* L) {
	const char *input = lua_tostring(L, 1);
	int result = -1;

	lua_pushstring(L, "");

	result = md_html(
		input, strlen(input),
		&append_internal,
		L,
		MD_FLAG_TABLES | MD_FLAG_STRIKETHROUGH | MD_FLAG_PERMISSIVEATXHEADERS,
		0);

	if (result == 0) {
		return 1;
	}
	else {
		lua_pop(L, 1);
		luaL_error(L, "Markdown parsing failed!");
		return 0;
	}
}

int l_is_directory(lua_State* L) {
	struct stat s;
	int  result = lstat(lua_tostring(L, 1), &s);

	if (result == 0) {
		lua_pushboolean(L, (s.st_mode & S_IFMT) == S_IFDIR);
		return 1;
	}

	lua_pushboolean(L, FALSE);
	return 1;
}

int l_list_directory(lua_State* L) {
	DIR* d = opendir(lua_tostring(L, 1));
	if (d) {
		struct dirent* e;
		int i;
		lua_createtable(L, 20, 0);

		for (i = 1; e = readdir(d);) {
			/* Filter out "." and ".." */
			if (e->d_name[0] == '.') {
				char c = e->d_name[1];
				if (c == '\0') {
					continue;
				}
				else if (c == '.') {
					if (e->d_name[2] == '\0') {
						continue;
					}
				}
			}

			lua_pushnumber(L, i++);
			lua_pushstring(L, e->d_name);
			lua_settable(L, -3);
		}

		closedir(d);
		return 1;
	}
	else {
		luaL_error(L, "Failed to enumerate directory!");
		return 0;
	}
}

void l_load_library(lua_State* L, const char* name, const char* script) {
	if (luaL_dostring(L, script) != LUA_OK) {
		printf("PANIC (%s): %s\n", name, lua_tostring(L, 1));
	}

	lua_setglobal(L, name);
}

int main(int argc, const char** argv) {
	int i;
	lua_State* L = luaL_newstate();
	luaL_openlibs(L);

	/* Register helper functions */
	lua_register(L, "markdownToHtml", &l_markdown_to_html);
	lua_register(L, "isDirectory", &l_is_directory);
	lua_register(L, "listDirectory", &l_list_directory);

	/* Load libraries */
	l_load_library(L, "etlua", STRINGIFIED_ETLUA);

	/* Expose command line arguments */
	lua_createtable(L, argc, 0);

	for (i = 0; i < argc; i++) {
		lua_pushinteger(L, i + 1);
		lua_pushstring(L, argv[i]);
		lua_settable(L, -3);
	}

	lua_setglobal(L, "args");

	/* Run main.lua */
	if (luaL_dostring(L, STRINGIFIED_MAIN) != LUA_OK) {
		printf("PANIC: %s\n", lua_tostring(L, 1));
	}

	lua_close(L);
	return 0;
}

