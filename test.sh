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
for i in filter filter-func lua-eval prev-next reachability syntax-new syntax-override virtual; do
	echo "Running test $i..."
	../luasmith "$i.lua" "$i" "actual/$i" >/dev/null
	if ! diff -qr "baseline/$i" "actual/$i" ; then
		echo "*** TEST FAILED ***"
	fi
done

# Link-checking tests
i=valid-link
echo "Running test $i..."
if echo 'return { injectFiles({ ["foo.html"] = [[<h1 id="baz"><a href="foo.html#baz">link</a></h1>]] }), checkLinks() }' | ../luasmith - |grep -qi 'broken' ; then
	echo "*** TEST FAILED ***"
fi

i=broken-link
echo "Running test $i..."
if ! echo 'return { injectFiles({ ["foo.html"] = [[<a href="bar.html">link</a>]] }), checkLinks() }' | ../luasmith - |grep -qi 'broken' ; then
	echo "*** TEST FAILED ***"
fi

i=broken-root-relative-link
echo "Running test $i..."
if ! echo 'return { injectFiles({ ["foo.html"] = [[<a href="/bar.html">link</a>]] }), checkLinks() }' | ../luasmith - |grep -qi 'broken' ; then
	echo "*** TEST FAILED ***"
fi

i=root-relative-link
echo "Running test $i..."
if ! echo 'return { injectFiles({ ["foo.html"] = [[<h1 id="baz"><a href="/foo.html#baz">link</a></h1>]] }), checkLinks() }' | ../luasmith - |grep -qi 'root-relative' ; then
	echo "*** TEST FAILED ***"
fi
if echo 'return { injectFiles({ ["foo.html"] = [[<h1 id="baz"><a href="/foo.html#baz">link</a></h1>]] }), checkLinks() }' | ../luasmith - |grep -qi 'broken' ; then
	echo "*** TEST FAILED (2) ***"
fi

i=unreachable-item
echo "Running test $i..."
if ! echo 'return { injectFiles({ ["site.css"] = ";", ["foo.html"] = [[Hi]] }), checkLinks({ entryPoints = { "foo.html" } }) }' | ../luasmith - |grep -qi 'unreachable' ; then
	echo "*** TEST FAILED ***"
fi

# Misc. tests
i=stdin
echo "Running test $i..."
echo 'return { injectFiles({ ["out.txt"] = "hello\\n" }), writeToDestination(args[4]) }' | ../luasmith - "$i" "actual/$i"
if ! diff -qr "baseline/$i" "actual/$i" ; then
	echo "*** TEST FAILED ***"
fi

