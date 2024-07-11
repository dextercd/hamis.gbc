INCLUDE "hardware.inc"

DEF FLAGROW EQU 5
DEF FLAGCOL EQU 7
DEF FLAGSTARTX EQU $68
DEF FLAGSTARTY EQU $A0
DEF MOVESTOP EQU $E0

SECTION "Header", ROM0[$100]

    jp EntryPoint

    ds $150 - @, 0 ; Make room for the header

; bc: count
; de: from
; hl: to
Memcpy:
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or a, c
    jr nz, Memcpy
    ret

; Parameters:
; d: value
; bc: count
; hl: to
; Returns:
; hl will point one past the end of the block
Memset8:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or a, c
    jr nz, Memset8
    ret

; Parameters:
; de: value
; bc: count
; hl: to
; Returns:
; hl will point one past the end of the block
Memset16:
    ld a, e
    ld [hli], a
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or a, c
    jr nz, Memset16
    ret

EntryPoint:
    ; Enable audio
    ld hl, rAUDENA
    ld c, $11

    ld a, $80
    ld [hld], a ; rAUDENA
    ld [c], a ; AUD1LEN
    ld a, $f3
    ld [hld], a ; AUDTERM
    inc c
    ld [c], a ; AUD1ENV

    ld a, $77
    ld [hld], a ; AUDVOL

    xor a
    ld [wFrameCounter], a
    ld [wFlagAnim], a

    ld a, FLAGSTARTY
    ld [wFlagPos], a

    ld de, HRAMData
    ld hl, HRAMLocation
    ld bc, HRAMLocationEnd - HRAMLocation
    call Memcpy

    ; Do not turn the LCD off outside of VBlank
WaitVBlank:
    ld a, [rLY]
    cp 144
    jr c, WaitVBlank

    ; Turn the LCD off
    xor a
    ld [rLCDC], a

    ; Copy the tile data
    ld de, BgTiles
    ld hl, $9000
    ld bc, BgTilesEnd - BgTiles
    call Memcpy

    ; Set CGB bg attributes to make the flag pole black
    ld a, 1
    ld [rVBK], a
    ld hl, $9800 + 9 ; X coord
    ld a, 1          ; Palette 1
    ld de, $20       ; Next line increment
    ld b, 7          ; Pole length
FlagPole:
    ld [hl], a
    add hl, de
    dec b
    jr nz, FlagPole

    ; Restore VRAM bank
    xor a
    ld [rVBK], a

    ; Copy the tilemap
    ld de, Tilemap
    ld hl, $9800
    ld bc, TilemapEnd - Tilemap
    call Memcpy

    ; Create flag tiles
    ; Just blocks of palette index 1, 2, 3
    ld de, `11111111
    ld hl, $8000
    ld bc, $8
    call Memset16
    ld de, `22222222
    ld bc, $8
    call Memset16
    ld d, $ff
    ld bc, $10
    call Memset8

    ; Greyscale
    ld a, $bb
    ld [rOBP0], a

    ; Color

    ; Background
    ld a, BCPSF_AUTOINC
    ld [rBCPS], a

    ld de, BgPalettes
    ld hl, rBCPD
    ld bc, BgPalettesEnd - BgPalettes
CopyBgPalette:
    ld a, [de]
    ld [hl], a
    inc de
    dec bc
    ld a, b
    or a, c
    jr nz, CopyBgPalette

    ; Objects

    ld a, OCPSF_AUTOINC
    ld [rOCPS], a

    ld de, ObjPalettes
    ld hl, rOCPD
    ld bc, ObjPalettesEnd - ObjPalettes
CopyObjPalette:
    ld a, [de]
    ld [hl], a
    inc de
    dec bc
    ld a, b
    or a, c
    jr nz, CopyObjPalette

    ; During the first (blank) frame, initialize display registers
    ld a, %00011011
    ld [rBGP], a

    ; Clear Shadow OAM
    xor a
    ld b, 160
    ld hl, ShadowOAM
ClearShadowOAM:
    ld [hli], a
    dec b
    jr nz, ClearShadowOAM

    ; Init flag tiles and palette flag
    ld hl, ShadowOAM
    ld b, 0 ; Row
    ld c, FLAGCOL ; Column
    ld d, 0 ; Palette

InitFlag:
    ld a, b
TileWrap:
    sub a, 3
    jr nc, TileWrap
    add a, 3

    inc hl ; Y
    inc hl ; X
    ld [hli], a ; Tile
    ld a, d
    ld [hli], a ; Flags+GBC Palette

    dec c
    jr nz, InitFlag
    ld c, FLAGCOL
    inc b

    ld a, b
TileWrap2:
    sub a, 3
    jr nc, TileWrap2
    add a, 3

    jr nz, SkipIncrPalette
    inc d
SkipIncrPalette:

    ld a, b
    cp a, FLAGROW
    jr nz, InitFlag

    ; Init OAM
    ld bc, 160
    ld d, 0
    ld hl, _OAMRAM
    call Memset8

    ; Hämis horizontally centered
    ld a, 240
    ld [rSCX], a
    ; But off-screen on the verticle axis
    ld a, $70
    ld [rSCY], a

    ; Turn the LCD on
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ld [rLCDC], a

Main:
    ; Wait until it's *not* VBlank
    ld a, [rLY]
    cp 144
    jr nc, Main
WaitVBlank2:
    ld a, [rLY]
    cp 144
    jr c, WaitVBlank2

    call RunDMA

    ; Only move every n frames
    ld a, [wFrameCounter]
    inc a
    cp 3
    jr nz, SkipFrame

    xor a
    ld [wFrameCounter], a
    ; Do the move
    ld a, [wFlagAnim]
    inc a
    ld [wFlagAnim], a

    ; Flag done moving?
    ld a, [rSCY]

    cp MOVESTOP
    jr z, SkipMove
    inc a
    ld [rSCY], a

    ld e, $83 ; bloop 1
    cp MOVESTOP - 2
    jr z, Bloop1

    cp MOVESTOP
    jr nz, SkipAudio
    ld e, $c1 ; bloop 2

Bloop1:
    ld a, e
    ld [rAUD1LOW], a

    ld a, $87
    ld [rAUD1HIGH], a

SkipAudio:

    ; Set flag objects
    ld a, [wFlagPos]
    dec a
    ld [wFlagPos], a
SkipMove:
    ld a, [wFlagPos]
    ld c, a

    ; Sprite count
    ld b, (FLAGROW - 1) << 4 | FLAGCOL
    ; X pos
    ld d, FLAGSTARTX
    ld hl, ShadowOAM
SetSprite:
    ; Determine the y coord
    ; c is the base but have to add an offset
    ld a, b
    and a, $0f
    push bc
    ld b, a
    ld a, [wFlagAnim]
    add a, b
    and a, $0f
    push hl
    ld hl, SinStart

    ; Add a to hl
    add l
    ld l, a
    adc h
    sub l

    ld a, [hl]
    pop hl
    pop bc
    add a, c

    ld [hli], a ; y
    ld a, d
    ld [hli], a ; x
    xor a
    inc hl ; tile
    inc hl ; flags

    ld a, d
    add a, 8
    ld d, a

    dec b
    jr z, Done ; Final object of final row

    ; Check if done with row
    ld a, b
    and a, $0F
    jr nz, SetSprite; Nope
    ; Next row
    ld a, b
    sub a, $10
    or a, FLAGCOL
    ld b, a

    ; Wrap
    ld a, c
    add a, 8
    ld c, a
    ld d, FLAGSTARTX

    jr SetSprite

    SkipFrame:
    ld [wFrameCounter], a
    Done:
    jp Main


SECTION "Tile data", ROM0

BgTiles:
    HamisTiles: INCBIN "hamis.2bpp"
BgTilesEnd:

SECTION "Tilemap", ROM0

Tilemap: INCBIN "hamis.tilemap"
TilemapEnd:

; I love sin
SinStart: INCLUDE "sin.inc"
SinEnd:

SECTION "Palette", ROM0

BgPalettes:
; Hämis
dw 12 | (3 << 5) | (15 << 10)
dw 16 | (6 << 5) | (20 << 10)
dw 20 | (31 << 5) | (10 << 10)
dw 31 | (31 << 5) | (31 << 10)

; Flag pole
dw $0000
dw $0000
dw $0000
dw $0000
BgPalettesEnd:

ObjPalettes:
dw $ffff
dw 31 | (2 << 5) | (2 << 10)
dw 31 | (28 << 5) | (3 << 10)
dw 13 | (28 << 5) | (9 << 10)

dw $ffff
dw 4 | (13 << 5) | (31 << 10)
dw 28 | (4 << 5) | (31 << 10)
ObjPalettesEnd:

SECTION "HRAMDATA", ROM0
HRAMData:
LOAD "HRAMLOADED", HRAM
HRAMLocation:

; https://gbdev.io/pandocs/OAM_DMA_Transfer.html#best-practices
RunDMA:
    ld a, HIGH(ShadowOAM)
    ldh [rDMA], a  ; start DMA transfer (starts right after instruction)
    ld a, 40        ; delay for a total of 4×40 = 160 M-cycles
.wait
    dec a           ; 1 M-cycle
    jr nz, .wait    ; 3 M-cycles
    ret

HRAMLocationEnd:
ENDL

SECTION "Counter", WRAM0
wFrameCounter: db
wFlagAnim: db

wFlagPos: db

SECTION "ShadowOAM", WRAM0, ALIGN[8]
ShadowOAM: ds 160
db
