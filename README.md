# Knightmare (Konami, MSX1) — a commented disassembly

*(También [en castellano](README.es.md).)* ·
**[Read it on the web](https://antxiko.github.io/Knightmare-disassembly/)**

A complete, commented disassembly of Konami's **Knightmare** — in Japan
*Majou Densetsu* — for the MSX (RC-739, 32 KB, 1986). Every one of the 32,768
bytes is accounted for, and the listing reassembles into the ROM **byte for
byte**.

    explained          32,768 of 32,768   100 %
    comment density    1,681 of 7,509     22.4 %
    blocks below 10 %        0 of 985
    tests                   23, green
    reassembly         same sha256 as the cartridge

## What is here

    src/knightmare.asm       the commented listing, generated
    src/knightmare.notes     the comments and the data blocks, with their measure
    src/knightmare.entries   the entry points that cannot be deduced statically
    tools/                   the tools: trace, listing, pictures, VRAM check
    tests/                   23 checks that do not need the cartridge
    docs/                    the bilingual website

## The cartridge is not here

`knightmare.rom` is not distributed. Put your own copy in the root; it is
exactly 32,768 bytes and

    sha256  6e7a8a2d2fadc078ec9043deee804cfa5efcf2eb64f2fb6291a5161776220cf6

## Reproducing it

    make comprueba     # checks your ROM is the same one
    make               # listing, reassembly, sanity checks and tests
    make imagenes      # draws the stages, the sprites and the screens
    make vram          # checks those pictures against openMSX's VRAM

## Not one screen capture

Every picture in this repository is **drawn from the bytes of the ROM**, by
running in Python the same decompressors, mirrors and band builders the Z80
runs. And they are checked byte for byte against the emulator's VRAM: **the
eight stages, zero differences** in colour (6,144 bytes), patterns (6,144) and
the 704 tiles of the map.

## What turned up

- **Konami left two typos in its cosine tables.** A cosine quadrant can only
  go down; these two go up once each, and the value that goes up is precisely
  the only one that departs from the function.
- **A cheat that asks for left and right at once** — impossible on a joystick
  — plus a key, and hands over twenty-six lives.
- **The Game Master header declares eight stages** and one address more: a
  ten-byte routine of this very cartridge that nothing inside it ever calls.
- **Each stage's sections overlap by exactly one band**, and not just in the
  bitmap: the scenery they give is identical, on all nine joins of all eight
  stages.
- **Three palettes out of one colour script**: stages 0, 3 and 7 share tiles
  and colour, and a five-code translation tells them apart.
- **The demo is a recorded game**: 118 keypresses, one every eight frames.

The lot, with its measurements, in
[Findings](https://antxiko.github.io/Knightmare-disassembly/FINDINGS.html),
and what is *not* known in
[Open questions](https://antxiko.github.io/Knightmare-disassembly/OPEN-QUESTIONS.html).

## Licence and credit

The tools, comments, analysis and documentation are MIT — see `LICENSE`. The
game is not ours: read [LEGAL-NOTICE.md](LEGAL-NOTICE.md).

Konami's hidden mark was uncovered by **Manuel Pazos**.
