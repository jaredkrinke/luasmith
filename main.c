#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <md4c-html.h>

/* Compile in Lua scripts */
#include "main.lua.h"
#include "etlua.lua.h"

typedef struct {
	lua_State* L;
	int count;
} md4c_data_t;

void append_internal(const MD_CHAR* str, MD_SIZE size, void* o) {
	/* TODO: Reuse a single buffer instead of allocating each time */
	md4c_data_t* data = (md4c_data_t*)o;
	char* s = strndup(str, size); /* Ensure null-terminated */

	lua_pushstring(data->L, s);
	free(s);
	data->count++;
}

int l_markdown_to_html(lua_State* L) {
	const char *input = lua_tostring(L, 1);
	md4c_data_t data;
	int result = -1;

	data.L = L;
	data.count = 0;

	result = md_html(
		input, strlen(input),
		&append_internal,
		&data,
		MD_FLAG_TABLES | MD_FLAG_STRIKETHROUGH | MD_FLAG_PERMISSIVEATXHEADERS,
		0);

	if (result == 0) {
		lua_concat(L, data.count);
		return 1;
	}
	else {
		lua_pop(L, data.count);
		luaL_error(L, "Markdown parsing failed!");
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

