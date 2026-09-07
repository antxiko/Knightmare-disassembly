# The code

15,233 bytes of code and 17,535 of data. 7,509 instructions spread over 985
named blocks, and not one below 10 % commented.

## Everything hangs off the interrupt

INIT (`0x407E`) does no more than set the stage: it switches the whole
cartridge into pages 1 and 2 with ENASLT, writes a `jp cada_cuadro` into the
H.KEYI hook at `0xFD9A`, clears `0xE000` to `0xE7FF`, builds the screen and
drops into a `jr $`. **The whole game happens inside the interrupt.**

`cada_cuadro` (`0x402E`) does, in this order: read the VDP to drop the
interrupt request, **sound first** — so its delay does not show if the frame
runs long — the reentry latch, the controls, the frame, and one more VDP read
on the way out.

## The dispatcher

Almost all the flow goes through `0x406C`:

    pop hl          ; the return address IS the table
    add a,a
    call suma_a_a_hl
    ld e,(hl) / inc hl / ld d,(hl) / ex de,hl / jp (hl)

So **the table sits right behind the `call`**. There are fifteen such places,
and `tools/tablas_despacho.py` works out each table's size with the
lowest-entry rule. Three would not yield: their first entry jumps backwards to
code nothing else calls, and the rule has nothing to stand on. They were closed
by hand on the first entry pointing forwards, which is always the byte right
after the table.

There is a second door, `0x4065`, which takes the index from `(ix+0)` and wants
the table already in HL. Only one place uses it, `0x75F0`, and that is the
**two-level dispatch**: `0x75F3` is a table of sixteen subtables indexed by
`(ix+1) & 0x0F` — the enemy type — and `0x4065` indexes the subtable with
`(ix+0)`, which is its state.

## The scenes

`(0xE000)` is the scene and `(0xE001)` the subscene; the table at `0x40EA` has
ten entries:

    0  intro (the KONAMI banner coming down)
    1  title
    2  demo
    3  countdown and start of the game
    4  the game            <- the scene the Game Master watches
    5  stage cleared
    6  a life lost
    7  GAME OVER
    8  next stage
    9  the ending

In scenes 0, 1 and 2, `haz_el_cuadro` pushes `0x4262` onto the stack before
dispatching, so on return from the scene that runs: look at whether anything
was pressed and, if we are on the title and it is a fire button, start the
game.

## The decompressors

There are two formats, and it pays not to mix them up.

**The block one** (`0x4417`), for patterns, colour and tiles:

    n with bit 7 set   n bytes as they come
    n without bit 7    the next byte, repeated n times
    0x80               change of VRAM address (two bytes)
    0x00               end

Every byte also goes through `lee_y_traduce` (`0x443B`), which applies the
colour bank in `(0xE661)`.

**The label one** (`0x43F9`): a word with the VRAM address, then the tile
codes, `0xFE` to jump somewhere else and `0xFF` to finish. The codes are not
ASCII: they are tile numbers of the font, and the alphabet is read by drawing
the 35 glyphs `0x45C9` decompresses.

## The sound engine

It is The Goonies' (RC-734), and not by hearsay:
`tools/porta_nombres.py` finds its routines here by normalised instruction
signature, with runs of up to 150 bytes in a row.

Three fourteen-byte voices at `0xE010`, `0xE01E` and `0xE02C`. A piece is asked
for by number, and that number **is also its priority**: it only gets in if it
outweighs whatever is already playing. The table at `0x4B38` is 63 **voice**
pointers, not piece pointers: each piece takes one, two or three in a row.

The twelve semitones are at `0x4B2C`, and dropping an octave means doubling the
period: the `add hl,hl` at `0x4B0F`.

## The shared framework

`tools/comun_normalizado.py` gives **21 runs and 996 normalised bytes** in
common with The Goonies, that is 6.8 % of this cartridge. What is shared is the
framework — the dispatcher, the 16-bit adds, the decompressors, the sprite
mirror, the controller reader — and the sound engine. The other 13.7 KB of code
are its own.
