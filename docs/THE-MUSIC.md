# The music

Everything you hear here comes from running the cartridge's own sound engine (`suena_el_cuadro`, 0x49C0, and `pide_pieza`, 0x490C, which hands it the voices; the interrupt calls it) on an emulated Z80, frame by frame at 60 per second, just as the game calls it. What the engine writes to the PSG is turned into sound with an AY-3-8910 (`tools/musica.py`). Each MP3 is the whole piece up to where it starts again, plus 8 seconds of the repeat fading out; those that do not repeat end where the engine ends.

## Checked against openMSX

The PSG writes have been compared frame by frame with those of openMSX (C-BIOS MSX1 japonés). In every frame the PSG ends up the same:

- tune 0xB7, 219 and 181 frames in two stretches and, from another request, 377 of 378;
- the closing captions (0xB4), likewise: 219, 181 and 751 of 752.

The timbre is not checked: it is a textbook AY-3-8910, not a recording of the emulator. The probes are `tools/omsx_psg.tcl` and `tools/coteja_psg.py`.

## How a piece is asked for

`pide_pieza` takes the number in A. Low numbers are effects and from 0x9D up there is music. Each voice takes fourteen bytes from 0xE010 and 0xE03A holds the copy of the PSG mixer, which start-up leaves at 0xB8. On the last frame of each long stretch the check differs because the game asks for the piece again. The tracks marked «in the table» are in the track table but no routine asks for them with an `ld a`; others, minutes long, are left out.

## The tunes

**The tune at 0x4193** (0xB7)

Asked for by `L_4193` y `L_5DED`; lasts 6.3 s.

<audio controls preload="none" src="audio/musica_B7.mp3?v=0b2c7342"></audio>

**The closing captions** (0xB4)

Asked for by `escena_final_rotulos`; lasts 12.5 s.

<audio controls preload="none" src="audio/musica_B4.mp3?v=bab918c2"></audio>

**The tune at 0x41FF** (0xBA)

Asked for by `L_41FF`; lasts 5.0 s.

<audio controls preload="none" src="audio/musica_BA.mp3?v=66993290"></audio>

**The tune at 0x69A4** (0xB1)

Asked for by `L_69A4`; lasts 1.7 s.

<audio controls preload="none" src="audio/musica_B1.mp3?v=dda729b1"></audio>

**The tune at 0x67ED** (0xA5)

Asked for by `L_67ED`; lasts 1.7 s.

<audio controls preload="none" src="audio/musica_A5.mp3?v=575a5dec"></audio>

**The doll dies** (0xAE)

Asked for by `mata_al_muneco`; lasts 1.1 s.

<audio controls preload="none" src="audio/musica_AE.mp3?v=99e94623"></audio>

**The pause** (0xA8)

Asked for by `mira_la_pausa` y `L_5730`; lasts 0.5 s.

<audio controls preload="none" src="audio/musica_A8.mp3?v=34851524"></audio>

**Table track 0x9D** (0x9D)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 6.4 s and starts again at second 0.0.

<audio controls preload="none" src="audio/musica_9D.mp3?v=d57c3915"></audio>

**Table track 0x9E** (0x9E)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 44.8 s and starts again at second 0.0.

<audio controls preload="none" src="audio/musica_9E.mp3?v=59aaf3f1"></audio>

**Table track 0x9F** (0x9F)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 8.9 s and starts again at second 8.4.

<audio controls preload="none" src="audio/musica_9F.mp3?v=290c2a20"></audio>

**Table track 0xA0** (0xA0)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 34.4 s and starts again at second 0.8.

<audio controls preload="none" src="audio/musica_A0.mp3?v=db352989"></audio>

**Table track 0xA3** (0xA3)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 14.2 s and starts again at second 0.2.

<audio controls preload="none" src="audio/musica_A3.mp3?v=ba37655c"></audio>

**Table track 0xA4** (0xA4)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 2.7 s and starts again at second 1.7.

<audio controls preload="none" src="audio/musica_A4.mp3?v=d6b8fdb5"></audio>

**Table track 0xB2** (0xB2)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 12.5 s.

<audio controls preload="none" src="audio/musica_B2.mp3?v=d502056c"></audio>

**Table track 0xB3** (0xB3)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 12.5 s.

<audio controls preload="none" src="audio/musica_B3.mp3?v=fff36640"></audio>

**Table track 0xB5** (0xB5)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 12.5 s.

<audio controls preload="none" src="audio/musica_B5.mp3?v=06251d42"></audio>

**Table track 0xB6** (0xB6)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 12.5 s.

<audio controls preload="none" src="audio/musica_B6.mp3?v=dbfb1d59"></audio>

**Table track 0xB8** (0xB8)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 6.3 s.

<audio controls preload="none" src="audio/musica_B8.mp3?v=2c63983c"></audio>

**Table track 0xB9** (0xB9)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 6.3 s.

<audio controls preload="none" src="audio/musica_B9.mp3?v=294924d0"></audio>

**Table track 0xBB** (0xBB)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 5.0 s.

<audio controls preload="none" src="audio/musica_BB.mp3?v=42c77a2e"></audio>

**Table track 0xBC** (0xBC)

Asked for by ninguna llamada directa: está en la tabla de pistas; lasts 5.0 s.

<audio controls preload="none" src="audio/musica_BC.mp3?v=2821a510"></audio>
