CC=cc
OBJS=main.o md4c/src/entity.o md4c/src/md4c.o md4c/src/md4c-html.o
CFLAGS=-I lua -I md4c/src

all: lssg

lua/liblua.a: lua
	make -C lua posix

main.lua.h: main.lua
	echo '#define STRINGIFIED_MAIN \\' > $@
	cat $< |sed -f stringify.sed >> $@

etlua.lua.h: etlua/etlua.lua
	echo '#define STRINGIFIED_ETLUA \\' > $@
	cat $< |sed -f stringify.sed >> $@

main.o: main.c main.lua.h etlua.lua.h
	$(CC) $(CFLAGS) -c main.c

lssg: $(OBJS) lua/liblua.a
	$(CC) -o lssg $^ -lm

