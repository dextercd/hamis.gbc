.PHONY: all clean

all: hamis.gbc
clean:
	rm -f *.gbc *.2bpp *.tilemap *.o sin.inc *.sym

gb: hamis.gbc hamis.sym
	gearboy $< $<.sym

hamis.gbc hamis.sym: hamis.o
	rgblink --sym hamis.sym.tmp -o hamis.gbc.tmp $^
	rgbfix \
	    --validate \
	    --pad-value 0xff \
	    --game-id HAMS \
	    --title "Hämis Boot" \
	    --color-only \
	    hamis.gbc.tmp
	mv hamis.gbc.tmp hamis.gbc && mv hamis.sym.tmp hamis.sym

sin.inc: sin.py
	python $< >$@

hamis.o: hardware.inc sin.inc hamis.2bpp hamis.tilemap

%.2bpp %.tilemap: %.flags %.png
	rgbgfx --output $*.2bpp --tilemap $*.tilemap @$*.flags -- $*.png

%.o: %.asm
	rgbasm -L -o $@ $<
