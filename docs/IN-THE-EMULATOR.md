# In the emulator

There are no screen captures here, but the emulator does get used: to **check**
what Python draws against what the VDP really holds.

## The check

    make vram

It starts openMSX with no window, lets the demo play itself, dumps the 16 KB of
VRAM at nine moments and subtracts them from the ones Python builds.

    stage 0  colour 0x0000..0x17FF   6144 bytes  0 different
             patterns 0x2000..0x37FF 6144 bytes  0 different
             names, rows 0 to 21      704 tiles  0 different
    ...
    ---- 8 screens, 0 bytes different

Coming out at zero is what lets the pictures be published saying they are the
cartridge's.

## How the eight stages are reached without playing

No need to play, and no need to fake anything either. `monta_la_fase`
(`0x53D3`) reads the stage from `(0xE062)` and gets **everything** out of it:
the map from the table at `0x99CD`, the tiles and colour from the one at
`0x563C` and the enemies from the one at `0x6A98`. A breakpoint at `0x53D3` —
before it reads — writes whichever stage is wanted, and the cartridge builds
**that** stage with its own code. One starting byte is changed, exactly as a
player reaching that stage would do.

The dump goes **half a second later**: the patterns, the colour and the name
table are up by then, and the scenery has not scrolled a single row yet, which
is what makes the map comparable.

## Two traps that cost the check

**The cartridge does not clear the patterns or the colour when the stage
changes**, only the name table. Stages 1, 2 and 4 carry fewer tiles than stage
0 — 61, 59 and 79 against 80 — so what is left over stays from the previous
one. Building one stage on its own gave 456 bytes of difference in colour;
chaining them the way the game chains them, zero.

**The scoreboard is at the bottom, not the top.** The screen starts four rows
into the tile buffer — `vuelca_la_pantalla` copies from `0xE8A0` minus
`(0xE091) & 3` rows — and the last two rows of the screen are SCORE, HISCORE,
REST and STAGE, painted over afterwards.

## Watching it play

    openmsx -machine Philips_VG_8020 -cart knightmare.rom

The cartridge chains intro, title and demo on its own, and the demo is a
recorded game, so two boots give the same thing.

## If you want to poke around

openMSX's console (F10) does the usual:

    debug read memory 0xE062     ; the stage, 0 to 7
    debug read memory 0xE060     ; the lives
    debug write memory 0xE062 5  ; and jump to the sixth

And for the three variables that run the frame:

    debug read memory 0xE000     ; the scene
    debug read memory 0xE092     ; the section within the stage, 0 to 9
    debug read memory 0xE091     ; the tile rows scrolled so far
