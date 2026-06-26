#!/bin/sh

cd test
rm -rf actual
mkdir actual

for i in fm-lua fm-yaml fm-toml; do
	echo "Running test $i..."
	../luasmith fm.lua "$i" "actual/$i"
	if ! diff -qr baseline/fm "actual/$i" ; then
		echo "*** TEST FAILED ***"
	fi
done

for i in footnotes; do
	echo "Running test $i..."
	../luasmith content.lua "$i" "actual/$i"
	if ! diff -qr "baseline/$i" "actual/$i" ; then
		echo "*** TEST FAILED ***"
	fi
done

for i in lua-eval; do
	echo "Running test $i..."
	../luasmith "$i.lua" "$i" "actual/$i"
	if ! diff -qr "baseline/$i" "actual/$i" ; then
		echo "*** TEST FAILED ***"
	fi
done

