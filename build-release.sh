#!/bin/sh

make clean
make CC="zig cc --target=x86_64-linux-musl"
strip luasmith
tar czf luasmith-$1-linux-x86_64.tar.gz --transform "s,^,luasmith-$1/," luasmith

