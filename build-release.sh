#!/bin/sh

# Statically-linked Linux build, using zig cc
make clean
make CC="zig cc --target=x86_64-linux-musl"
strip luasmith
tar czf luasmith-$1-linux-x86_64.tar.gz luasmith

# Multi-platform build, using cosmocc
make clean
make CC=cosmocc MYCFLAGS="-Os -s"
cp luasmith luasmith.com
zip luasmith-$1-universal.zip luasmith.com

