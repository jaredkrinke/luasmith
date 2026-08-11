#!/bin/sh

cd test
rm -rf actual
mkdir actual

# Frontmatter tests
for i in fm-lua fm-yaml fm-toml; do
	echo "Running test $i..."
	../luasmith fm.lua "$i" "actual/$i"
	if ! diff -qr baseline/fm "actual/$i" ; then
		echo "*** TEST FAILED ***"
	fi
done

# Generic input-based tests
for i in footnotes; do
	echo "Running test $i..."
	../luasmith content.lua "$i" "actual/$i"
	if ! diff -qr "baseline/$i" "actual/$i" ; then
		echo "*** TEST FAILED ***"
	fi
done

# Specific input-based tests
for i in filter filter-func lua-eval prev-next syntax-new syntax-override virtual; do
	echo "Running test $i..."
	../luasmith "$i.lua" "$i" "actual/$i"
	if ! diff -qr "baseline/$i" "actual/$i" ; then
		echo "*** TEST FAILED ***"
	fi
done

# Misc. tests
i=stdin
echo "Running test $i..."
echo 'return { injectFiles({ ["out.txt"] = "hello\\n" }), writeToDestination(args[4]) }' | ../luasmith - "$i" "actual/$i"
if ! diff -qr "baseline/$i" "actual/$i" ; then
	echo "*** TEST FAILED ***"
fi

