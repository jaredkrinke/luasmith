#!/bin/sh

# Source code
make clean
git ls-files --recurse-submodules |xargs tar czf luasmith-$1-src.tar.gz --transform "s,^,luasmith-$1/,"

# Statically-linked Linux build, using zig cc
make clean
make CC="zig cc --target=x86_64-linux-musl" LUA_CFLAGS="-DLUA_USE_POSIX" LDFLAGS=""
strip luasmith
tar czf luasmith-$1-linux-x86_64.tar.gz luasmith

# Dynamic Linux build, with native module support, using zig cc
make clean
make CC="zig cc --target=x86_64-linux-gnu.2.7"
strip luasmith
tar czf luasmith-$1-linux-x86_64-dynamic.tar.gz luasmith

# Windows build, cross-compiled using zig cc
make clean
make CC="zig cc --target=x86_64-windows-gnu" LUA_CFLAGS="" MYRC=luasmith.exe.manifest
mv luasmith luasmith.exe
zip luasmith-$1-windows-x86_64.zip luasmith.exe

# Multi-platform build, using cosmocc
make clean
make CC=cosmocc MYCFLAGS="-Os -s"
cp luasmith luasmith.com
zip luasmith-$1-universal.zip luasmith.com

