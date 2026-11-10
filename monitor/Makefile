# MAX-80 boot disk monitor. Needs sjasmplus and Python 3. The boot
# sector, console, keys and disk tool are the diag's.
SJASM ?= sjasmplus
SRC = $(wildcard src/*.asm src/*.inc) ../diag/src/boot.asm ../diag/src/cons.asm \
      ../diag/src/keys.asm ../diag/src/setup.asm ../diag/src/vars.inc \
      ../xcpmz80/src/hw.inc ../xcpmz80/src/font.bin
MKDISK = ../diag/tools/mkdisk.py

all: build/monitor.imd build/monitor_525.imd

# The build shown at boot: the commit, then the date. Written only when
# it changes, so an unchanged tree is not rebuilt.
BUILD := $(shell git log -1 --format=%h 2>/dev/null || echo unknown)
DATE := $(shell LC_ALL=C date +%d-%b-%Y)

build/version.inc: FORCE
	@mkdir -p build
	@printf 'BUILD\tmacro\n\tdb\t"%s %s"\n\tendm\n' '$(BUILD)' '$(DATE)' > $@.new
	@cmp -s $@.new $@ && rm $@.new || mv $@.new $@

build/monitor.sys: $(SRC) build/version.inc
	@mkdir -p build
	cd src && $(SJASM) --nologo --msg=war --lst=../build/monitor.lst --raw=../build/monitor.sys mon.asm

build/monitor.imd: build/monitor.sys $(MKDISK)
	python3 $(MKDISK) build/monitor.sys $@

build/monitor_525.imd: build/monitor.sys $(MKDISK)
	python3 $(MKDISK) build/monitor.sys $@ --525

clean:
	rm -rf build

.PHONY: all test clean FORCE
FORCE:
