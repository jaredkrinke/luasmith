# Configuration
CC=cc
MYCFLAGS=-Os -Wall

LUA_OBJS=lua/lapi.o lua/lcode.o lua/lctype.o lua/ldebug.o lua/ldo.o lua/ldump.o lua/lfunc.o lua/lgc.o lua/llex.o lua/lmem.o lua/lobject.o lua/lopcodes.o lua/lparser.o lua/lstate.o lua/lstring.o lua/ltable.o lua/ltm.o lua/lundump.o lua/lvm.o lua/lzio.o lua/lauxlib.o lua/lbaselib.o lua/lbitlib.o lua/lcorolib.o lua/ldblib.o lua/liolib.o lua/lmathlib.o lua/loslib.o lua/lstrlib.o lua/ltablib.o lua/loadlib.o lua/linit.o
LPEG_OBJS=lpeg/lpcap.o lpeg/lpcode.o lpeg/lpcset.o lpeg/lpprint.o lpeg/lptree.o lpeg/lpvm.o
MD4C_OBJS=md4c/src/entity.o md4c/src/md4c.o md4c/src/md4c-html.o
OBJS=main.o $(MD4C_OBJS) $(LUA_OBJS) $(LPEG_OBJS) chtml/chtml.o

LUA_CFLAGS=-DLUA_COMPAT_ALL -DLUA_USE_POSIX
CFLAGS=$(MYCFLAGS) -I lua -I md4c/src -I chtml $(LUA_CFLAGS)

all: luasmith

clean:
	rm -f $(OBJS)
	rm -f *.lua.h
	rm -f luasmith

main.lua.h: main.lua
	echo "#define STRINGIFIED_MAIN \\" > $@
	cat main.lua |sed -f stringify.sed >> $@

main.o: main.c main.lua.h scripts.lua.h
	$(CC) $(CFLAGS) -c main.c

luasmith: $(OBJS)
	$(CC) -o luasmith $(OBJS) -lm

# Embedded Lua scripts (mostly related to syntax highlighting)
VPATH = scintillua/lexers

THEME_FILES = \
	themes/shared.lua \
	themes/shared/feed.etlua \
	themes/md2blog.lua \
	themes/md2blog/404.etlua \
	themes/md2blog/style.css \
	themes/md2blog/archive.etlua \
	themes/md2blog/index.etlua \
	themes/md2blog/outer.etlua \
	themes/md2blog/post.etlua \
	themes/md2blog/root.etlua \
	themes/blog.lua \
	themes/blog/style.css \
	themes/blog/outer.etlua \
	themes/blog/post.etlua \
	themes/blog/blog.etlua \

GRAMMARS = \
	lexer.lua \
	asm.lua \
	asp.lua \
	awk.lua \
	bash.lua \
	batch.lua \
	clojure.lua \
	c.lua \
	cmake.lua \
	coffeescript.lua \
	cpp.lua \
	crystal.lua \
	csharp.lua \
	css.lua \
	cuda.lua \
	dart.lua \
	desktop.lua \
	diff.lua \
	django.lua \
	d.lua \
	dockerfile.lua \
	dot.lua \
	elixir.lua \
	elm.lua \
	erlang.lua \
	etlua.lua \
	factor.lua \
	fennel.lua \
	forth.lua \
	fortran.lua \
	fsharp.lua \
	fstab.lua \
	gleam.lua \
	glsl.lua \
	go.lua \
	hare.lua \
	haskell.lua \
	html.lua \
	idl.lua \
	ini.lua \
	janet.lua \
	java.lua \
	javascript.lua \
	jq.lua \
	json.lua \
	jsp.lua \
	julia.lua \
	latex.lua \
	ledger.lua \
	less.lua \
	lisp.lua \
	lua.lua \
	makefile.lua \
	markdown.lua \
	matlab.lua \
	mediawiki.lua \
	meson.lua \
	moonscript.lua \
	networkd.lua \
	nim.lua \
	nix.lua \
	nsis.lua \
	null.lua \
	objective_c.lua \
	org.lua \
	output.lua \
	pascal.lua \
	perl.lua \
	php.lua \
	pico8.lua \
	pkgbuild.lua \
	pony.lua \
	powershell.lua \
	prolog.lua \
	props.lua \
	protobuf.lua \
	ps.lua \
	pure.lua \
	python.lua \
	rails.lua \
	rc.lua \
	reason.lua \
	rebol.lua \
	rest.lua \
	rexx.lua \
	rhtml.lua \
	r.lua \
	rpmspec.lua \
	ruby.lua \
	rust.lua \
	sass.lua \
	scala.lua \
	scheme.lua \
	smalltalk.lua \
	sml.lua \
	snobol4.lua \
	spin.lua \
	sql.lua \
	strace.lua \
	systemd.lua \
	taskpaper.lua \
	tcl.lua \
	texinfo.lua \
	tex.lua \
	text.lua \
	toml.lua \
	troff.lua \
	typescript.lua \
	vala.lua \
	vb.lua \
	vcard.lua \
	verilog.lua \
	vhdl.lua \
	xml.lua \
	xs.lua \
	yaml.lua \
	zig.lua \

scripts.lua.h: etlua/etlua.lua $(GRAMMARS) $(THEME_FILES)
	echo "char* _embedded_scripts[] = {" > $@
	cat etlua/etlua.lua |sed -f stringify.sed -e '$$a,' -e '1i"_etlua.lua",' >> $@
	for grammar in $(GRAMMARS); do cat "scintillua/lexers/$$grammar" |sed -f stringify.sed -e '$$a,' -e "1i\"$$grammar\","; done >> $@
	for themefile in $(THEME_FILES); do cat "$$themefile" |sed -f stringify.sed -e '$$a,' -e "1i\"$$themefile\","; done >> $@
	echo "NULL };" >> $@

