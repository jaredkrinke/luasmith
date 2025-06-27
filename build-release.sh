#!/bin/sh

# Statically-linked Linux build, using zig cc
make clean
make CC="zig cc --target=x86_64-linux-musl"
strip luasmith
tar czf luasmith-$1-linux-x86_64.tar.gz luasmith

# Windows build, cross-compiled using zig cc
make clean
make CC="zig cc --target=x86_64-windows-gnu" LUA_CFLAGS=""
mv luasmith luasmith.exe
zip luasmith-$1-windows-x86_64.zip luasmith.exe

# Multi-platform build, using cosmocc
make clean
make CC=cosmocc MYCFLAGS="-Os -s"
cp luasmith luasmith.com
zip luasmith-$1-universal.zip luasmith.com

