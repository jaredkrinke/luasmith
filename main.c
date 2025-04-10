#include <stdio.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "main.h"

int main() {
	lua_State* L = luaL_newstate();
	luaL_openlibs(L);
	if (luaL_dostring(L, STRINGIFIED_SCRIPT) != LUA_OK) {
		printf("PANIC: %s\n", lua_tostring(L, 1));
	}
	lua_close(L);

	return 0;
}

