# Open questions

What is not known, said as what it is. The listing is 100 % explained — every
byte has its name and its reason — but that does not mean everything is
understood.

## The startup cheat, unrecorded

`0x6F44` wants left and right at once plus the second button and a key, and one
of the three gives twenty-six lives. **This is code reading**: sitting down at
the emulator and recording it is still to be done. With the standard MSX matrix
the keys come out as I, N and Y, but that depends on the machine's keyboard and
has not been checked.

## What the Game Master header says, exactly

The layout of the twenty-one bytes at `0x4010` is settled: it comes out of
running the Game Master's own reader and it works out byte for byte. What is
**not** settled is whether the 1985 Game Master (RC-735) can read a `"CD"`
header from a 1986 cartridge and what it does with it. This cartridge is later
than that one, so the header was most likely written for the Game Master 2
(RC-755), which is not disassembled.

Nor has it been tried with both cartridges plugged in.

## The tenth enemy index

The table at `0x6A98` gives, per stage, a word with the base of the enemy
records and **ten indices**, one per section. The first nine never go down and
the tenth is zero in six stages — no enemies in the last section — but on
stages 5 and 6 it carries on counting (48 → 50 and 44 → 45). Whether that is
deliberate or whether those two sections have something different is not clear.

## The overlapping blocks, on purpose or not

`0x9C21` and `0x9C3E` fall halfway into another block. One stretch of bytes
serving as two different blocks saves room, but whether it comes out of a tool
that looked for overlaps or whether someone placed it by hand is unknown.

## The two cosine typos

They are measured and there is no doubt they are typos: they break the
monotonicity of a table that can only go down, and they are the only two values
that depart from the function. What is not known is **whether they show**. One
would have to send a creature aiming at exactly those two angles and watch for
a tug.

## The hidden mark, and where it comes from

The last thirteen bytes are マジョウデンセツ backwards, its length, the
catalogue number and an `0xAA`. That Konami put that mark in its cartridges was
uncovered by **Manuel Pazos**, and here it is read with
`tools/marca_konami.py`. Why it is written backwards, we do not know.
