# Configuration
CC=cc
MYCFLAGS=-Os -Wall

LUA_OBJS=lua/lapi.o lua/lcode.o lua/lctype.o lua/ldebug.o lua/ldo.o lua/ldump.o lua/lfunc.o lua/lgc.o lua/llex.o lua/lmem.o lua/lobject.o lua/lopcodes.o lua/lparser.o lua/lstate.o lua/lstring.o lua/ltable.o lua/ltm.o lua/lundump.o lua/lvm.o lua/lzio.o lua/lauxlib.o lua/lbaselib.o lua/lbitlib.o lua/lcorolib.o lua/ldblib.o lua/liolib.o lua/lmathlib.o lua/loslib.o lua/lstrlib.o lua/ltablib.o lua/loadlib.o lua/linit.o
MD4C_OBJS=md4c/src/entity.o md4c/src/md4c.o md4c/src/md4c-html.o
OBJS=main.o $(MD4C_OBJS) $(LUA_OBJS) chtml/chtml.o

LUA_CFLAGS=-DLUA_COMPAT_ALL -DLUA_USE_POSIX
CFLAGS=$(MYCFLAGS) -I lua -I md4c/src -I chtml $(LUA_CFLAGS)

all: luasmith

clean:
	rm -f lua/*.o
	rm -f md4c/src/*.o
	rm -f *.o
	rm -f *.lua.h
	rm -f luasmith

main.lua.h: main.lua
	echo "#define STRINGIFIED_MAIN \\" > $@
	cat main.lua |sed -f stringify.sed >> $@

etlua.lua.h: etlua/etlua.lua
	echo "#define STRINGIFIED_ETLUA \\" > $@
	cat etlua/etlua.lua |sed -f stringify.sed >> $@

main.o: main.c main.lua.h etlua.lua.h
	$(CC) $(CFLAGS) -c main.c

luasmith: $(OBJS)
	$(CC) -o luasmith $(OBJS) -lm

