CC=cc

all: lssg

lua/liblua.a: lua
	make -C lua posix

main.h: main.lua
	cat $< |sed -f stringify.sed > $@

main.o: main.c main.h
	$(CC) -I lua -c main.c

lssg: main.o lua/liblua.a
	$(CC) -o lssg $^ -lm

