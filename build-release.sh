#!/bin/sh

make clean
make CC="zig cc --target=x86_64-windows-gnu"
strip luasmith
tar czf luasmith-$1-windows-x86_64.tar.gz --transform "s,^,luasmith-$1/," luasmith themes

