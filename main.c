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

#define STRCMP_STATIC(stat, dyn) strncmp(stat, (dyn), sizeof(stat))

/* md4c interface */

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

/* File system interface */

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

/* chtml interface */
#define LUA_CHTML_EVENT "chtml_event"
#define LUA_CHTML_EVENT_HANDLER "chtml_event_handler"

typedef struct {
	chtml_event_t event;
	const char* html;
	size_t html_size;
	const chtml_context_t* ctx;
} chtml_info_t;

int l_chtml_info_index(lua_State* L) {
	chtml_info_t* info = *((chtml_info_t**)lua_touserdata(L, 1));
	if (info) {
		const char* field = lua_tostring(L, 2);
		const char* value = NULL;
		size_t value_size = 0;

		if (STRCMP_STATIC("event", field) == 0) {
			switch (info->event) {
			   case CHTML_EVENT_OTHER: lua_pushstring(L, "other"); break;
			   case CHTML_EVENT_TAG_ENTER: lua_pushstring(L, "enter"); break;
			   case CHTML_EVENT_TAG_EXIT: lua_pushstring(L, "exit"); break;
			   case CHTML_EVENT_ATTRIBUTE: lua_pushstring(L, "attribute"); break;
			   default: lua_pushnil(L); break;
			}
		}
		else {
			if (STRCMP_STATIC("html", field) == 0) {
				value = info->html;
				value_size = info->html_size;
			}
			else if (STRCMP_STATIC("tag", field) == 0) {
				value = info->ctx->tag;
				value_size = info->ctx->tag_size;
			}
			else if (STRCMP_STATIC("attribute", field) == 0) {
				value = info->ctx->attribute;
				value_size = info->ctx->attribute_size;
			}
			else if (STRCMP_STATIC("value", field) == 0) {
				value = info->ctx->value;
				value_size = info->ctx->value_size;
			}

			if (value) {
				lua_pushlstring(L, value, value_size);
			}
			else {
				lua_pushnil(L);
			}
		}

		return 1;
	}
	else {
		luaL_error(L, "Attempt to index non-userdata chtml event!");
		return 0;
	}
}

void process_html_event(chtml_event_t event, const char* str, size_t size, const chtml_context_t* ctx) {
	lua_State* L = (lua_State*)ctx->user_data;
	chtml_info_t info = { event, str, size, ctx };

	lua_getfield(L, LUA_REGISTRYINDEX, LUA_CHTML_EVENT_HANDLER);

	/* Set up event object */
	lua_getfield(L, LUA_REGISTRYINDEX, LUA_CHTML_EVENT);
	*((chtml_info_t**)lua_touserdata(L, -1)) = &info;

	/* Call handler */
	lua_call(L, 1, 0);
}

/* parseHtml(html, handler) */
int l_parse_html(lua_State* L) {
	const char* html = lua_tostring(L, 1);
	lua_setfield(L, LUA_REGISTRYINDEX, LUA_CHTML_EVENT_HANDLER);

	if (html) {
		parse_html(html, process_html_event, L);
	}
	else {
		luaL_error(L, "Non-string passed to _parseHtml(html, callback)!");
	}

	/* Clear event object */
	lua_getfield(L, LUA_REGISTRYINDEX, LUA_CHTML_EVENT);
	*((chtml_info_t**)lua_touserdata(L, -1)) = NULL;
	lua_pop(L, 1);

	lua_pushnil(L);
	lua_setfield(L, LUA_REGISTRYINDEX, LUA_CHTML_EVENT_HANDLER);
	lua_pop(L, 1);

	return 0;
}

/* Initialization for chtml (namely, creating metatable for chtml event object) */
void lua_chtml_init(lua_State* L) {
	lua_newuserdata(L, sizeof(chtml_info_t*));
	lua_newtable(L);
	lua_pushcfunction(L, &l_chtml_info_index);
	lua_setfield(L, -2, "__index");
	lua_setmetatable(L, -2);
	lua_setfield(L, LUA_REGISTRYINDEX, LUA_CHTML_EVENT);
}

/* LPeg interface */
extern int luaopen_lpeg(lua_State* L);

/* Lua helpers */

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
	luaopen_lpeg(L);
	lua_setglobal(L, "lpeg");

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

