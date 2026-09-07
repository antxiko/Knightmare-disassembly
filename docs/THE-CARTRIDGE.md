# The cartridge

**Knightmare**, Konami RC-739, 1986. 32,768 bytes seen in **pages 1 and 2** of
the MSX, that is from `0x4000` to `0xBFFF`.

    sha256  6e7a8a2d2fadc078ec9043deee804cfa5efcf2eb64f2fb6291a5161776220cf6

## The two headers

At `0x4000` sits the usual one: `"AB"`, the INIT address (`0x407E`), and
STATEMENT, DEVICE and TEXT at zero.

And at `0x4010` sits **a second one**, which this cartridge never reads: the
**Konami Game Master**, the house's cheat cartridge, reads it from the other
slot. It is `"CD" 07 39`, that is the `0x07` of the RC-7xx family and the
`0x39` of RC-739. The `"CD"` marks the 1986-87 cartridges; the 1985 ones carry
`"AB"`.

Behind it come twenty-one bytes laid out by a flags byte — each bit clear means
the field is present — and the layout **works out byte for byte**: it ends at
`0x4024`, exactly where code starts again. With flags `0x20` this comes out:

| field | value | what it is |
|---|---|---|
| scene | `0xE000` | the scene variable |
| when | `4` | the scene where cheats are applied |
| stage | `0xE061` | the stage, in BCD |
| how many | `8` | **eight stages** |
| lives | `0xE060` | |
| data | `0xE053` | the high score |
| score | `0xE056` | |
| — | — | *no second player score* |
| mode | `0xE002` | the mode bits |
| routine | `0x56C8` | **a routine of this cartridge** |

That last one is the interesting bit: `0x56C8` is ten bytes **nothing inside
calls**. What they do is take the stage the Game Master writes into
`(0xE061)` and turn it into the internal index at `(0xE062)`, subtracting one
in BCD.

## The VDP, the other way round

The register table sits at `0x44C5`, eight bytes from R0 to R7:

    02 E2 0E 7F 07 76 03 E4

R3 and R4 **are not addresses, they are base and mask**, and here they flip the
usual geometry:

| table | where | size |
|---|---|---|
| colour | `0x0000` | three banks of `0x800` |
| sprite patterns | `0x1800` | 64 of 32 bytes |
| patterns | `0x2000` | three banks of `0x800` |
| names | `0x3800` | 768 tiles |
| sprite attributes | `0x3B00` | 32 of four bytes |

So colour sits where one expects patterns and the other way round. An `ld
hl,00008h` in this cartridge **does not point at patterns**.

Register 7 in the table says `0xE4` — dark blue background — but that only
holds until the game starts: the cartridge changes it to `0xE0` with
`pon_registro_7`, and the low nibble becomes 0, which is **black**.

## The memory map

    0xE000  scene           0xE001  subscene        0xE002  mode bits
    0xE003  frame counter                           0xE004  wait
    0xE009  what is pressed
    0xE010  0xE01E  0xE02C  the three PSG voices, fourteen bytes each
    0xE053  high score (3 BCD)                      0xE056  score (3)
    0xE060  lives           0xE061  stage in BCD    0xE062  internal stage (0-7)
    0xE063  extra life threshold
    0xE088  the section's bitmap                    0xE091  rows scrolled
    0xE092  section (0-9)   0xE093  section list    0xE095  end of the bitmap
    0xE0A0  the two wave spawners, 0x10 each
    0xE100  the seven enemies, 0x20 each
    0xE200  the eight enemy shots, 0x10 each
    0xE320  the shadow of the sprite attribute table
    0xE3D0  the boss
    0xE4F0  the eight creatures seeded by the stage, 0x10 each
    0xE600  the player      0xE620  the four shot slots
    0xE820  the tile buffer: 28 rows of 32

## The machine changes nothing

Of everything below `0x4000` the cartridge reads **one single address:
`0x0007`**, the VDP data port, and it calls seventeen BIOS routines: VDP, PSG,
keyboard and slots. **It never touches `0x002B`, `0x002C` or `0x002D`**, the
bytes that say the character set, the date format and whether the machine runs
at 50 or 60 Hz.

Checked by dumping, too: the title screen's VRAM on an international machine
and on a Japanese one gives **0 bytes different out of 16,384**. The kanji logo
is the same on both.

## The hidden mark

The last thirteen bytes of the cartridge, `0xBFF3` to `0xBFFF`, are the house's
mark: マジョウデンセツ — *Majou Densetsu* — written backwards in katakana, its
length (`0x0A`), the `0x39` of RC-739 and an `0xAA` closing it. It was
uncovered by **Manuel Pazos**.
