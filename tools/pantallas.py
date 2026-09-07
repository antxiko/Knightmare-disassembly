#!/usr/bin/env python3
"""Monta pantallas enteras ejecutando en Python los pasos del cartucho.

No hay ni una captura de pantalla en este repositorio. Cada lamina se construye
igual que la construye el juego -descomprimiendo sus guiones en una VRAM de
mentira y pintando esa VRAM con la paleta del TMS9918-, y que eso este bien
hecho no es una opinion: tools/coteja_vram.py resta esta misma VRAM de la que
el emulador tiene DE VERDAD y sale a cero en las ocho fases.

Lo que sale:

    titulo.png          la pantalla del titulo entera
    rotulo.png          solo el rotulo, para la cabecera de la web
    presentacion.png    el cartel de KONAMI de la presentacion
    fuente.png          las 35 casillas de la fuente, con su codigo
    casillas_faseN.png  las 80 casillas del decorado de cada fase
    pantalla_faseN.png  la primera pantalla de cada fase, marcador incluido

Uso: pantallas.py <rom> <org> <directorio de salida>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mapas import Rom, descomprime, png, escala, PALETA        # noqa: E402
from coteja_vram import buffer_del_tramo                        # noqa: E402
from mapas import (vram_de_la_fase,                            # noqa: E402
                   en_los_tres_bancos as banco)

NOMBRES = 0x3800
FONDO = PALETA[0]                       # R7 = 0xE0: el fondo es el color 0


def casilla(v, n, banda):
    """Los 8x8 pixeles de la casilla n en el tercio que se pida. Los patrones
    estan en 0x2000 y el color en 0x0000, al reves de lo corriente: lo dicen
    R3 = 0x7F y R4 = 0x07 de la tabla de 0x44C5."""
    p = 0x2000 + banda * 0x800 + n * 8
    c = 0x0000 + banda * 0x800 + n * 8
    out = []
    for f in range(8):
        forma, col = v[p + f], v[c + f]
        tinta, papel = PALETA[col >> 4], PALETA[col & 0x0F]
        out.append([tinta if forma & (0x80 >> b) else papel for b in range(8)])
    return out


def pinta(v, nombres):
    """Los 256x192 pixeles de una pantalla: 24 filas de 32 casillas, cada
    tercio con su banco."""
    px = [[FONDO] * 256 for _ in range(192)]
    for f in range(24):
        for c in range(32):
            d = casilla(v, nombres[f * 32 + c], f // 8)
            for y in range(8):
                px[f * 8 + y][c * 8:c * 8 + 8] = d[y]
    return px


def guarda(px, fn, esc=2):
    lienzo = [list(fila) for fila in px]
    png(len(lienzo[0]) * esc, len(lienzo) * esc, escala(lienzo, esc), fn)
    print("  %s  %d x %d" % (fn, len(lienzo[0]) * esc, len(lienzo) * esc))


def guion_crudo(rom, p):
    """Los pares (direccion de VRAM, codigo) que suelta un guion de texto."""
    out = []
    while True:
        vram = rom.b(p) | (rom.b(p + 1) << 8)
        p += 2
        while True:
            c = rom.b(p)
            p += 1
            if c == 0xFF:
                return out
            if c == 0xFE:
                break
            out.append((vram, c))
            vram += 1


def pantalla_del_titulo(rom):
    """`monta_el_titulo` (0x47BA): el rotulo en 0x2300 y su color en 0x0300, el
    dibujo en la tabla de nombres desde 0x38CB con once casillas por fila
    empezando en la 0x60, y encima los tres rotulos de 0x4529."""
    v = bytearray(0x3800)
    banco(v, 0x2000, bytes(0x80))
    for n in range(16):
        banco(v, 0x0000 + n * 8, bytes([n]) * 8)
    banco(v, 0x2080, descomprime(rom, 0x45C9))
    banco(v, 0x0080, bytes([0xF0]) * 0x118)
    banco(v, 0x2300, descomprime(rom, 0x47F6))
    banco(v, 0x0300, descomprime(rom, 0x48FA))
    nombres = [0] * 768
    n = 0x60
    for fila in range(3):
        for c in range(11):
            nombres[(0x38CB - NOMBRES) + fila * 32 + c] = n
            n += 1
    for vram, cod in guion_crudo(rom, 0x4529):
        nombres[vram - NOMBRES] = cod
    return v, nombres


def pantalla_de_la_presentacion(rom):
    """`monta_el_cartel` (0x46DD) y `baja_un_paso` (0x46F1), con el cartel ya
    llegado a su sitio.

    0x46F1 baja (0xE00E) 0x20 casillas -una fila- y vuelve a pintar las TRES
    filas del cartel con `escribe_seguidas_subiendo` (0x4715), que escribe B
    casillas seguidas empezando por A y deja HL una fila mas abajo: tres desde
    la 0x40, once y doce, o sea las 26 casillas seguidas de 0x40 a 0x59. Se
    repite catorce veces -(0xE00A) arranca en 0x0E-, asi que el sitio final es
    0x3AAA menos catorce filas."""
    v = bytearray(0x3800)
    banco(v, 0x2000, bytes(0x80))
    for n in range(16):
        banco(v, 0x0000 + n * 8, bytes([n]) * 8)
    banco(v, 0x2200, descomprime(rom, 0x4723))
    banco(v, 0x0200, bytes([0xF0]) * 0xD8)
    nombres = [0] * 768
    i = 0x3AAA - 0x20 * 14 - NOMBRES
    n = 0x40
    for cuantas in (3, 11, 12):
        for k in range(cuantas):
            nombres[i + k] = n
            n += 1
        i += 32
    return v, nombres


def hoja_de_casillas(v, ini, n, cols=16, esc=3, sep=1):
    """Las casillas ini..ini+n del primer banco, en rejilla."""
    filas = (n + cols - 1) // cols
    w = cols * (8 + sep) + sep
    h = filas * (8 + sep) + sep
    lienzo = [[(0x18, 0x18, 0x20)] * w for _ in range(h)]
    for k in range(n):
        d = casilla(v, ini + k, 0)
        oy = sep + (k // cols) * (8 + sep)
        ox = sep + (k % cols) * (8 + sep)
        for y in range(8):
            lienzo[oy + y][ox:ox + 8] = d[y]
    return w * esc, h * esc, escala(lienzo, esc)


def main():
    rom = Rom(sys.argv[1], int(sys.argv[2], 0))
    salida = sys.argv[3]
    os.makedirs(salida, exist_ok=True)

    v, nombres = pantalla_del_titulo(rom)
    px = pinta(v, nombres)
    guarda(px, os.path.join(salida, "titulo.png"))
    # el rotulo solo: las filas 4 a 10 del titulo, donde caen el KNIGHTMARE
    # escrito con la fuente y las tres filas del rotulo grande
    guarda([fila[64:192] for fila in px[32:88]],
           os.path.join(salida, "rotulo.png"), esc=3)
    w, h, px = hoja_de_casillas(v, 0x10, 35)
    png(w, h, px, os.path.join(salida, "fuente.png"))
    print("  %s  %d x %d  (las 35 casillas de la fuente)"
          % (os.path.join(salida, "fuente.png"), w, h))

    v, nombres = pantalla_de_la_presentacion(rom)
    guarda(pinta(v, nombres), os.path.join(salida, "presentacion.png"))

    # las ocho fases, encadenadas como las encadena el cartucho: no borra los
    # patrones ni el color al cambiar
    heredada = None
    for fase in range(8):
        v = vram_de_la_fase(rom, fase, heredada)
        heredada = v
        filas = buffer_del_tramo(rom, fase, 0)
        nombres = [0] * 768
        for r in range(22):              # las dos ultimas son el marcador
            for c in range(32):
                nombres[r * 32 + c] = filas[4 + r][c]
        for p in (0x4567,):              # SCORE, HISCORE, REST y STAGE
            for vram, cod in guion_crudo(rom, p):
                nombres[vram - NOMBRES] = cod
        guarda(pinta(v, nombres),
               os.path.join(salida, "pantalla_fase%d.png" % (fase + 1)))
        w, h, px = hoja_de_casillas(v, 0x50, 80)
        fn = os.path.join(salida, "casillas_fase%d.png" % (fase + 1))
        png(w, h, px, fn)
        print("  %s  %d x %d  (las 80 casillas del decorado)" % (fn, w, h))


if __name__ == "__main__":
    main()
