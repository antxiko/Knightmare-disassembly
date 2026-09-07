# The game

*Knightmare* — in Japan *Majou Densetsu*, "legend of the demon castle" — is a
vertical shooter in armour. Popolon climbs through eight stages killing
monsters to rescue Aphrodite, and the cartridge pulls it off with a scenery
engine built in bands and three sprite slots it keeps reloading.

![The title](imagenes/titulo.png)

*The title screen, assembled by running the steps of `monta_el_titulo`
(0x47BA). The big logo is 33 tiles — eleven by three — written in a row by a
loop starting at tile 0x60.*

## The eight stages, in full

Each stage is a vertical strip of **61 bands of four rows**, that is 244 rows
of tiles. It is not stored as a map: it is assembled block by block.

![Stage 1](imagenes/fase_1.png)

*Stage 1 in full. It comes out of the block codes at `0x9E51` and the 4x4 tile
blocks at `0x9A6D`.*

The builder is `0x6502` and it works like this:

- The stage is split into **ten sections**, and each section into **seven
  bands** of four rows.
- Each band is **eight groups of four columns**. Every group yields a block
  code: the low seven bits index the table at `0x99ED` — 64 pointers to 4x4
  tile blocks — and **bit 7 says the block goes mirrored**.
- After each group, an `rl` pulls one bit out of a bitmap: with the bit set the
  pointer moves on to the next block, with it clear **the previous block is
  repeated**. That is where the scenery compression lives.

And the blocks **overlap each other**: `0x9C21` and `0x9C3E` fall halfway into
another block, so one stretch of bytes serves as two different blocks.

## Three sceneries out of one colour script

![Stage 4](imagenes/fase_4.png)

*Stage 4 uses the SAME tiles as stage 1. What changes is the palette.*

Stages 0, 3 and 7 share the pattern script **and** the colour one. What tells
them apart is `(0xE661)`: the block reader (`0x443B`) translates five colour
codes — 0xE1, 0xEC, 0xE8, 0xE6 and 0xE5 — by subtracting 0x50, and another 0x50
when the bank is 2. One 640-byte block gives all three sceneries.

Stages 5 and 6 go further: they share tiles and colour, and **differ only in
the map**.

## Popolon is three sprites

![The player's frames](imagenes/jugador.png)

*The twelve frames. The last four are the explosion.*

The figure is drawn with **three overlaid 16x16 sprites**: `0x5E2D` writes them
with patterns 0, 1 and 2. The first two are uploaded by the frame — each takes
**exactly 64 bytes**, that is two patterns — and the third is the first of the
stage's fixed bank. Each one's `y` and colour come from a six-byte block: three
`[y offset][colour]` pairs.

There are seven animations in the table at `0xA5B4`, and one of them — number 2
— alternates its colours with those at `0xA5EF` to make the invulnerability
blink.

## The bestiary does not fit at once

![The enemy bank](imagenes/banco_de_enemigos.png)

*The 45 patterns of the sixteen blocks at `0xA993`.*

The MSX sprite sheet is 64 16x16 patterns and that is not enough, so the
cartridge keeps **three slots** — VRAM `0x1D00`, `0x1E00` and `0x1F00` — that
it reloads in turn: `0x78F9` decompresses four patterns into whichever is next
and also takes away the base pattern number, later added to each of the
creature's sprites.

Every enemy is drawn with **two sprites**, and the pair comes from the table at
`0x7772`: 38 eight-byte blocks with two `[dy][dx][pattern][colour]` entries.

![The weapons and items](imagenes/sprites_fase.png)

*The 37 fixed patterns `0x54BE` uploads at the start of every stage: the
weapons, the shots and the items. The same in all eight.*

## The scoreboard and the boss clock

![The first screen of stage 1](imagenes/pantalla_fase1.png)

*Exactly as it comes out of the emulator: the byte-for-byte check gives zero
differences.*

SCORE, HISCORE, REST and STAGE sit at the bottom, on row 22, and their digits
on row 23. The score is three BCD bytes from `0xE056` and the high score three
more from `0xE053`; when the high byte passes the threshold in `(0xE063)`,
`0x4305` hands over an extra life and raises the threshold by 0x10 — ten
thousand points — for the next one.

On the boss screen the lap counter is replaced by a **BCD clock** counting down
second by second: at four minutes the music changes, and at zero it is over.
