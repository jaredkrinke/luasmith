#!/bin/sh

make clean
make CC="zig cc --target=x86_64-linux-musl"
strip luasmith
tar czf luasmith-linux-x86_64-$1.tar.gz --transform "s,^,luasmith-$1/," luasmith themes

