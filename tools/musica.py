#!/usr/bin/env python3
"""La musica del cartucho, ejecutando su motor de sonido (ver motor_musica.py).

Pide el sonido con `pide_pieza` (0x490C, A = numero; `pide_pieza_si_la_escena_
lo_permite`, 0x4901, mira antes la escena) y corre `suena_el_cuadro` (0x49C0),
que la interrupcion llama cada cuadro. Tres voces de 14 bytes desde 0xE010; la
copia del registro 7 del PSG, en 0xE03A. El cartucho es de 32 KB, sin mapper.
Uso:  musica.py registros 0xB7 [cuadros] | mp3 0xB7 f.mp3 | todas docs/audio
      musica.py barrido 0x80 0xFF | emu
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import motor_musica  # noqa: E402
from motor_musica import P  # noqa: E402

TABLA = "ninguna llamada directa: está en la tabla de pistas"

PIEZAS = [
    P(0xB7, "La pieza del 0x4193", "The tune at 0x4193",
      "`L_4193` y `L_5DED`"),
    P(0xB4, "Los rótulos del final", "The closing captions",
      "`escena_final_rotulos`"),
    P(0xBA, "La pieza del 0x41FF", "The tune at 0x41FF", "`L_41FF`"),
    P(0xB1, "La pieza del 0x69A4", "The tune at 0x69A4", "`L_69A4`"),
    P(0xA5, "La pieza del 0x67ED", "The tune at 0x67ED", "`L_67ED`"),
    P(0xAE, "La muerte del muñeco", "The doll dies", "`mata_al_muneco`"),
    P(0xA8, "La pausa", "The pause", "`mira_la_pausa` y `L_5730`"),
] + [P(n, "Pista 0x%02X de la tabla" % n, "Table track 0x%02X" % n, TABLA)
     for n in (0x9D, 0x9E, 0x9F, 0xA0, 0xA3, 0xA4, 0xB2, 0xB3, 0xB5, 0xB6,
               0xB8, 0xB9, 0xBB, 0xBC)]

PAGINA = motor_musica.pagina_basica(
    "`suena_el_cuadro`, 0x49C0, y `pide_pieza`, 0x490C, que le reparte las "
    "voces; lo llama la interrupción",
    "`suena_el_cuadro`, 0x49C0, and `pide_pieza`, 0x490C, which hands it the "
    "voices; the interrupt calls it",
    "C-BIOS MSX1 japonés",
    [("la pieza 0xB7, 219 y 181 cuadros en dos tramos y, de otra petición, "
      "377 de 378",
      "tune 0xB7, 219 and 181 frames in two stretches and, from another "
      "request, 377 of 378"),
     ("los rótulos del final (0xB4), igual: 219, 181 y 751 de 752",
      "the closing captions (0xB4), likewise: 219, 181 and 751 of 752")],
    [("Cómo se pide una pieza",
      "`pide_pieza` recibe el número en A. Los números bajos son efectos y "
      "del 0x9D en adelante hay música. Cada voz ocupa catorce bytes desde "
      "0xE010 y 0xE03A guarda la copia del mezclador del PSG, que el "
      "arranque deja en 0xB8. En el último cuadro de cada tramo largo el "
      "cotejo difiere porque el juego vuelve a pedir la pieza. Las pistas "
      "«de la tabla» están en la tabla de pistas pero ninguna rutina las "
      "pide con un `ld a`; se omiten otras, de minutos de duración.",
      "How a piece is asked for",
      "`pide_pieza` takes the number in A. Low numbers are effects and from "
      "0x9D up there is music. Each voice takes fourteen bytes from 0xE010 "
      "and 0xE03A holds the copy of the PSG mixer, which start-up leaves at "
      "0xB8. On the last frame of each long stretch the check differs "
      "because the game asks for the piece again. The tracks marked «in the "
      "table» are in the track table but no routine asks for them with an "
      "`ld a`; others, minutes long, are left out.")])

CFG = dict(rom="knightmare.rom", org=0x4000, frame=0x49C0, pide=0x490C,
           ram=(0xE010, 0xE03B), ram0=[(0xE03A, 0xB8)],
           excluye=[0xE019, 0xE027, 0xE035], hz=60, psg0={7: 0xB8},
           piezas=PIEZAS, pagina=PAGINA,
           cotejado=[(0xB7, 378, None), (0xB4, 752, None)])

if __name__ == "__main__":
    sys.exit(motor_musica.main(CFG, sys.argv[1:]))
