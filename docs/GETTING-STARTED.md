# Getting started

This repository does not carry the cartridge. It carries what you need to
regenerate everything from your own copy and check that what it says is true.

## What you need

- **Python 3** for the tools.
- **pasmo** for the reassembly (`make verify`).
- **openMSX** only if you want to check the pictures against the VRAM.
- Your copy of `knightmare.rom`, in the root. Exactly 32,768 bytes, and

      sha256  6e7a8a2d2fadc078ec9043deee804cfa5efcf2eb64f2fb6291a5161776220cf6

  `make comprueba` tells you whether it is the same one.

## The four steps

    make comprueba     # is your ROM this one
    make               # listing, reassembly, sanity checks and tests
    make imagenes      # draws the stages, the sprites and the screens
    make vram          # checks those pictures against openMSX's VRAM

`make` is the one that matters. It chains four things:

1. **`listado`** traces the flow from the entry points declared in
   `src/knightmare.entries` and generates `src/knightmare.asm` with the
   comments from `src/knightmare.notes`.
2. **`verify`** reassembles that listing with pasmo and compares the sha256
   with your ROM's. If they differ, the disassembly is worthless and it stops
   there.
3. **`sanity`** checks what the reassembly canNOT catch: that no area declared
   as data comes out as code, that no entry point falls inside a data block,
   and that **not one byte is left unassigned**.
4. **`test`** runs the 23 checks in `tests/`.

## How the listing is organised

The listing is generated; it is not hand-edited. What is edited is
`src/knightmare.notes`, and out of it come the labels, the line comments, the
block headers and the data ranges with their name and description. Every
comment is anchored to its address, so it survives a re-trace.

`src/knightmare.entries` holds the entry points the trace cannot deduce on its
own — the interrupt hook, the addresses pushed onto the stack so they run on
return, the tables that sit behind a `call` — each with the reason it is
declared. If we cannot say WHY it is code, it is not declared.

## The numbers, measured

    make sanity        # the bytes of code and data, which add up to 32,768
    make densidad      # the routines and the share of commented lines

Not one number on this site is written by eye: they all come out of those two
commands, and there are tests watching them.
