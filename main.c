#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <dirent.h>
#include <sys/stat.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <md4c-html.h>
#include <chtml.h>

/* Compile in Lua scripts */
#include "main.lua.h"
#include "etlua.lua.h"

#define TRUE 1
#define FALSE 0

#define LUA_CHTML_EVENT "chtml_event"
#define LUA_CHTML_EVENT_HANDLER "chtml_event_handler"

/* md4c provides substrings and they need to be concatenated into a final
 * result. Note that Lua's string concatenation isn't optimized for repeated
 * concatenation, so rather than concatenating each string together, gather the
 * strings into a list and use table.concat (which is optimized for this case).
 * */
typedef struct {
	lua_State* L;
	int index;
} append_state;

void push_internal(const MD_CHAR* str, MD_SIZE size, void* o) {
	append_state* state = (append_state*)o;
	lua_State* L = state->L;

	/* Append to table, i.e. t[#t + 1] = str */
	lua_pushinteger(L, ++state->index);
	lua_pushlstring(L, str, size);
	lua_settable(L, -3);
}

int l_markdown_to_html(lua_State* L) {
	const char *input = lua_tostring(L, 1);
	int result = -1;
	append_state state = { L, 0 };

	lua_getglobal(L, "table");
	lua_getfield(L, -1, "concat");

	/* Append strings to temporary table */
	lua_newtable(L);

	result = md_html(
		input, strlen(input),
		&push_internal,
		&state,
		(	0
			| MD_FLAG_PERMISSIVEURLAUTOLINKS
			| MD_FLAG_PERMISSIVEEMAILAUTOLINKS
			| MD_FLAG_TABLES
			| MD_FLAG_STRIKETHROUGH
		),
		MD_HTML_FLAG_TRANSLATE_MD_LINKS);

	if (result == 0) {
		/* Call table.concat */
		lua_call(L, 1, 1);
		return 1;
	}
	else {
		lua_pop(L, 2);
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

int l_mkdir(lua_State* L) {
	if (mkdir(lua_tostring(L, 1), 0777) == -1) {
		/* Ignore "already exists" errors */
		if (errno != EEXIST) {
			luaL_error(L, "Failed to create directory!");
		}
	}
	return 0;
}

int l_list_directory(lua_State* L) {
	DIR* d = opendir(lua_tostring(L, 1));
	if (d) {
		struct dirent* e;
		int i;
		lua_createtable(L, 20, 0);

		for (i = 1; (e = readdir(d));) {
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

void lua_push_string_or_nil(lua_State* L, const char* str, size_t size) {
	if (str) {
		lua_pushlstring(L, str, size);
	}
	else {
		lua_pushnil(L);
	}
}

void process_html_event(chtml_event_t event, const char* str, size_t size, const chtml_context_t* ctx) {
	lua_State* L = (lua_State*)ctx->user_data;
	/* TODO: Copying strings for every callback seems inefficient, esp. if the
	 * fields aren't even read. Investigate using a (single) full user data
	 * that is actually a pointer to the struct on the stack (and that is
	 * cleared afterward). */

	 /* Push handler and event table */
	 lua_getfield(L, LUA_REGISTRYINDEX, LUA_CHTML_EVENT_HANDLER);
	 lua_getfield(L, LUA_REGISTRYINDEX, LUA_CHTML_EVENT);

	 /* Set up event table */
	 switch (event) {
		case CHTML_EVENT_OTHER: lua_pushstring(L, "other"); break;
		case CHTML_EVENT_TAG_ENTER: lua_pushstring(L, "enter"); break;
		case CHTML_EVENT_TAG_EXIT: lua_pushstring(L, "exit"); break;
		case CHTML_EVENT_ATTRIBUTE: lua_pushstring(L, "attribute"); break;
		default: lua_pushnil(L); break;
	 }

	 lua_setfield(L, -2, "type");

	 lua_pushlstring(L, str, size);
	 lua_setfield(L, -2, "html");
	 lua_push_string_or_nil(L, ctx->tag, ctx->tag_size);
	 lua_setfield(L, -2, "tag");
	 lua_push_string_or_nil(L, ctx->attribute, ctx->attribute_size);
	 lua_setfield(L, -2, "attribute");
	 lua_push_string_or_nil(L, ctx->value, ctx->value_size);
	 lua_setfield(L, -2, "value");

	 /* Call handler */
	 lua_call(L, 1, 0);
}

/* parseHtml(html, handler) */
int l_parse_html(lua_State* L) {
	const char* html = lua_tostring(L, 1);
	lua_setfield(L, LUA_REGISTRYINDEX, LUA_CHTML_EVENT_HANDLER);

	parse_html(html, process_html_event, L);

	lua_pushnil(L);
	lua_setfield(L, LUA_REGISTRYINDEX, LUA_CHTML_EVENT_HANDLER);
	lua_pop(L, 1);
	return 0;
}

/* Initialization for chtml (namely, creating metatable for chtml event objects) */
void lua_chtml_init(lua_State* L) {
	lua_newtable(L);
	lua_setfield(L, LUA_REGISTRYINDEX, LUA_CHTML_EVENT);
}

int lua_run(lua_State* L, const char* name, const char* script, int message_handler_index) {
	int result;

	luaL_loadbuffer(L, script, strlen(script), name);
	result = lua_pcall(L, 0, LUA_MULTRET, message_handler_index);
	if (result != LUA_OK) {
		printf("*** ERROR ***\n%s\n", lua_tostring(L, -1));
	}

	return result;
}

void lua_load_library(lua_State* L, const char* name, const char* script, int message_handler_index) {
	if (lua_run(L, name, script, message_handler_index) == LUA_OK) {
		lua_setglobal(L, name);
	}
}

int main(int argc, const char** argv) {
	int message_handler_index;
	int i;
	lua_State* L = luaL_newstate();
	luaL_openlibs(L);
	lua_chtml_init(L);

	/* Load debug.traceback for stack tracing */
	lua_getglobal(L, "debug");
	lua_pushstring(L, "traceback");
	lua_gettable(L, 1);
	message_handler_index = lua_gettop(L);

	/* Register helper functions */
	lua_register(L, "_markdownToHtml", &l_markdown_to_html);
	lua_register(L, "_isDirectory", &l_is_directory);
	lua_register(L, "_listDirectory", &l_list_directory);
	lua_register(L, "_mkdir", &l_mkdir);
	lua_register(L, "_parseHtml", &l_parse_html);

	/* Load libraries */
	lua_load_library(L, "etlua", STRINGIFIED_ETLUA, message_handler_index);

	/* Expose command line arguments */
	lua_createtable(L, argc, 0);

	for (i = 0; i < argc; i++) {
		lua_pushinteger(L, i + 1);
		lua_pushstring(L, argv[i]);
		lua_settable(L, -3);
	}

	lua_setglobal(L, "args");

	/* Run main.lua */
	lua_run(L, "main.lua", STRINGIFIED_MAIN, message_handler_index);

	lua_close(L);
	return 0;
}

