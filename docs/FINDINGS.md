# Findings

What turned up when we took it apart. Each one with its measurement.

## Konami left two typos in its cosine tables

The cartridge carries two cosine quadrants — one scaled to 255 at `0x844E` and
one to 128 at `0x848F`, 65 entries each — and with them `0x83E1` gets the sine
and cosine of an angle from 0 to 255, reading forwards for the cosine and
entering at `0x40 - k` for the sine.

A cosine quadrant **can only go down**. These two go up once each:

| table | entry | value | should be | the one next to it |
|---|---|---|---|---|
| `0x844E` | 58 | `0x2F` | `0x25` (37.4) | entry 57 is `0x2B`, **smaller** |
| `0x848F` | 12 | `0x74` | `0x7A` (122.5) | entry 13 is `0x79`, **larger** |

And the value that goes up is precisely the only one that departs from the
function: leaving those two out, the other 64 entries of each table fit the
cosine with a **mean deviation of 0.48 and 1.73** and a **maximum of 4.03 and
3.78**.

They are two data typos, not disassembly slips: the bytes are what they are.
What they do is a tug on the path of anything aiming at exactly those two
angles. A test watches them.

## A cheat that asks for left and right at once

`0x6F44` is called **exactly once**, from `0x4182`, right after the game is
reset. The first thing it wants is `(0xE009)` to read `0x2C` in its low six
bits: bits 2, 3 and 5, that is **left and right at the same time** plus the
second button. A joystick cannot do that; a keyboard can.

With that held, it looks at three keyboard rows. With the standard MSX matrix
— row 3 = C D E F G H I J, row 4 = K L M N O P Q R, row 5 = S T U V W X Y Z —
the bits it checks are **I**, **N** and **Y**:

    'I'  ->  (0xE069) = 1        the weapon
    'N'  ->  (0xE060) = 0x26     TWENTY-SIX LIVES
    'Y'  ->  (0xE069) = 0x10     another weapon

Still to be recorded on the emulator: this is code reading.

## The Game Master header declares a routine of this very cartridge

The second header at `0x4010` — `"CD" 07 39` — is read by the Konami Game
Master from the other slot. Its layout was not guessed: the Game Master's own
reader, which is disassembled, was **run by hand**. And it works out byte for
byte: the twenty-one bytes end at `0x4024`, exactly where code starts again.

It declares the scene variable, the lives, the high score, the score, that
there is **no second player score**, **eight stages**, and one more address:
`0x56C8`. That address is a routine of **this** cartridge that nothing inside
calls, and it is ten bytes:

    ld hl,0E061h / ld a,(hl) / sub 1 / daa / inc hl / ld (hl),a / ret

That is: take the stage the Game Master has just written into `(0xE061)` and
turn it into the internal index at `(0xE062)`.

Those ten bytes were hidden, too: the dispatch-table detector gave ten entries
for the table at `0x56B8` and there are **eight**. The two spare ones were the
bytes `21 61 E0 7E` of that `ld hl,0E061h`, read as if they were pointers.

## Each stage's sections overlap by exactly one band

The bitmap that says when the block pointer moves on sits at
`(0xE095) - 6*section`, so it advances **six bytes** per section. But **seven**
are read, one per band. The last band of one section and the first of the next
come out of the same byte.

And not only the same byte: the scenery they give is **identical**. Checked on
the nine joins of each of the eight stages — 72 checks — and they all fit.

## Three palettes out of one colour script

Stages 0, 3 and 7 share the pattern script **and** the colour script. What
tells them apart is `(0xE661)`: the block reader (`0x443B`) translates five
colour codes — `0xE1`, `0xEC`, `0xE8`, `0xE6` and `0xE5` — by subtracting
`0x50`, and another `0x50` when the bank is 2. `0x5514` sets the bank to 1 on
stage 3 and to 2 on stage 7.

One 640-byte block, three sceneries. And stages 5 and 6 share tiles **and**
colour: they differ only in the map.

## The demo is a recorded game

`0x5A73` keeps the count in `(0xE00C)`: every **eight frames** it bumps
`(0xE00B)` and indexes `0x5A95` with it. The byte that comes out is not drawing
data; it is handed to `guarda_lo_recien_pulsado`, the very door the joystick
comes in through.

That is **118 keypresses**, some nineteen seconds at 50 Hz. The `cp 0xFF` at
`0x5A87` would end it, but there is **not a single 0xFF** inside the block: the
demo is cut short by `(0xE064)`.

## The scenery blocks overlap each other

The table at `0x99ED` is 64 pointers to 4x4 tile blocks, sixteen bytes each.
But the blocks do not sit in a row: `0x9C21` and `0x9C3E` fall **halfway into**
another block, so one stretch of bytes acts as two different blocks depending
on where you come in.

## The waves work out on their own

`0x7043` says how many entries each stage's wave script has — 34, 41, 41, 38,
36, 33, 30 and 35 — and the distance between two consecutive pointers at
`0x704B` is **exactly twice that**. All eight, without a byte to spare or
missing.

## The machine changes nothing

Of everything below `0x4000` the cartridge reads **one single address**:
`0x0007`, the VDP data port. It never touches `0x002B`, `0x002C` or `0x002D`,
the BIOS bytes that say the character set and whether the machine runs at 50 or
60 Hz. The title screen's VRAM dumped on an international machine and on a
Japanese one: **0 bytes different out of 16,384**.
