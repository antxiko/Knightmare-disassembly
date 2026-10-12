# La música

Todo lo que suena aquí sale de ejecutar el motor de sonido del cartucho (`suena_el_cuadro`, 0x49C0, y `pide_pieza`, 0x490C, que le reparte las voces; lo llama la interrupción) en un Z80 emulado, cuadro a cuadro y a 60 por segundo, igual que lo llama el juego. Lo que el motor escribe en el PSG pasa a sonido con un AY-3-8910 (`tools/musica.py`). Cada MP3 es la pieza entera hasta donde vuelve a empezar, más 8 segundos de la vuelta apagándose; las que no se repiten acaban donde acaba el motor.

## Cotejado con openMSX

Las escrituras al PSG se han comparado cuadro a cuadro con las de openMSX (C-BIOS MSX1 japonés). En todos los cuadros el PSG queda igual:

- la pieza 0xB7, 219 y 181 cuadros en dos tramos y, de otra petición, 377 de 378;
- los rótulos del final (0xB4), igual: 219, 181 y 751 de 752.

El timbre no está cotejado: es el de un AY-3-8910 de manual, no una grabación del emulador. Las sondas están en `tools/omsx_psg.tcl` y `tools/coteja_psg.py`.

## Cómo se pide una pieza

`pide_pieza` recibe el número en A. Los números bajos son efectos y del 0x9D en adelante hay música. Cada voz ocupa catorce bytes desde 0xE010 y 0xE03A guarda la copia del mezclador del PSG, que el arranque deja en 0xB8. En el último cuadro de cada tramo largo el cotejo difiere porque el juego vuelve a pedir la pieza. Las pistas «de la tabla» están en la tabla de pistas pero ninguna rutina las pide con un `ld a`; se omiten otras, de minutos de duración.

## Las músicas

**La pieza del 0x4193** (0xB7)

Lo pide `L_4193` y `L_5DED`; dura 6,3 s.

<audio controls preload="none" src="../audio/musica_B7.mp3?v=0b2c7342"></audio>

**Los rótulos del final** (0xB4)

Lo pide `escena_final_rotulos`; dura 12,5 s.

<audio controls preload="none" src="../audio/musica_B4.mp3?v=bab918c2"></audio>

**La pieza del 0x41FF** (0xBA)

Lo pide `L_41FF`; dura 5,0 s.

<audio controls preload="none" src="../audio/musica_BA.mp3?v=66993290"></audio>

**La pieza del 0x69A4** (0xB1)

Lo pide `L_69A4`; dura 1,7 s.

<audio controls preload="none" src="../audio/musica_B1.mp3?v=dda729b1"></audio>

**La pieza del 0x67ED** (0xA5)

Lo pide `L_67ED`; dura 1,7 s.

<audio controls preload="none" src="../audio/musica_A5.mp3?v=575a5dec"></audio>

**La muerte del muñeco** (0xAE)

Lo pide `mata_al_muneco`; dura 1,1 s.

<audio controls preload="none" src="../audio/musica_AE.mp3?v=99e94623"></audio>

**La pausa** (0xA8)

Lo pide `mira_la_pausa` y `L_5730`; dura 0,5 s.

<audio controls preload="none" src="../audio/musica_A8.mp3?v=34851524"></audio>

**Pista 0x9D de la tabla** (0x9D)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 6,4 s y vuelve a empezar en el segundo 0,0.

<audio controls preload="none" src="../audio/musica_9D.mp3?v=d57c3915"></audio>

**Pista 0x9E de la tabla** (0x9E)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 44,8 s y vuelve a empezar en el segundo 0,0.

<audio controls preload="none" src="../audio/musica_9E.mp3?v=59aaf3f1"></audio>

**Pista 0x9F de la tabla** (0x9F)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 8,9 s y vuelve a empezar en el segundo 8,4.

<audio controls preload="none" src="../audio/musica_9F.mp3?v=290c2a20"></audio>

**Pista 0xA0 de la tabla** (0xA0)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 34,4 s y vuelve a empezar en el segundo 0,8.

<audio controls preload="none" src="../audio/musica_A0.mp3?v=db352989"></audio>

**Pista 0xA3 de la tabla** (0xA3)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 14,2 s y vuelve a empezar en el segundo 0,2.

<audio controls preload="none" src="../audio/musica_A3.mp3?v=ba37655c"></audio>

**Pista 0xA4 de la tabla** (0xA4)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 2,7 s y vuelve a empezar en el segundo 1,7.

<audio controls preload="none" src="../audio/musica_A4.mp3?v=d6b8fdb5"></audio>

**Pista 0xB2 de la tabla** (0xB2)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 12,5 s.

<audio controls preload="none" src="../audio/musica_B2.mp3?v=d502056c"></audio>

**Pista 0xB3 de la tabla** (0xB3)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 12,5 s.

<audio controls preload="none" src="../audio/musica_B3.mp3?v=fff36640"></audio>

**Pista 0xB5 de la tabla** (0xB5)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 12,5 s.

<audio controls preload="none" src="../audio/musica_B5.mp3?v=06251d42"></audio>

**Pista 0xB6 de la tabla** (0xB6)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 12,5 s.

<audio controls preload="none" src="../audio/musica_B6.mp3?v=dbfb1d59"></audio>

**Pista 0xB8 de la tabla** (0xB8)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 6,3 s.

<audio controls preload="none" src="../audio/musica_B8.mp3?v=2c63983c"></audio>

**Pista 0xB9 de la tabla** (0xB9)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 6,3 s.

<audio controls preload="none" src="../audio/musica_B9.mp3?v=294924d0"></audio>

**Pista 0xBB de la tabla** (0xBB)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 5,0 s.

<audio controls preload="none" src="../audio/musica_BB.mp3?v=42c77a2e"></audio>

**Pista 0xBC de la tabla** (0xBC)

Lo pide ninguna llamada directa: está en la tabla de pistas; dura 5,0 s.

<audio controls preload="none" src="../audio/musica_BC.mp3?v=2821a510"></audio>
