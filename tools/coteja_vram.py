#!/usr/bin/env python3
"""Compara la VRAM que se monta en Python con la del emulador, byte a byte.

Mirar el dibujo no basta. Las imagenes de este repositorio se montan ejecutando
en Python los pasos del cartucho, y la unica forma de saber si los formatos
estan bien leidos es coger la VRAM que el VDP tiene DE VERDAD -volcada con
tools/omsx_vram.tcl mientras la demostracion se juega sola- y restarle la de
Python.

La geometria de este cartucho va al reves de lo normal, y por eso las tablas no
estan donde uno espera (lo dicen los ocho bytes de 0x44C5: R3 = 0x7F y
R4 = 0x07):

    color      0x0000..0x17FF   tres bancos de 0x800
    spr patr   0x1800..0x1FFF   los 64 patrones de sprite
    patrones   0x2000..0x37FF   tres bancos de 0x800
    nombres    0x3800..0x3AFF   que casilla va en cada sitio

Lo que se compara, y por que:

  * PATRONES y COLOR. Los monta `monta_la_fase` al entrar y no se tocan hasta
    que cambia de fase, asi que tienen que salir a CERO diferencias. Los cinco
    volcados que hace el cartucho -la fuente, las casillas de la fase con su
    copia espejada, el marcador, el marco y, solo en la fase 7, las casillas de
    mas- los rehace `vram_de_la_fase`, que vive en tools/mapas.py: es LA MISMA
    hoja con la que se dibujan los mapas, y por eso este cotejo tambien los
    respalda a ellos. Antes habia dos, y la de los mapas se dejaba fuera el
    marcador: los rios y los puentes salian negros.

  * LA TABLA DE NOMBRES, que es el mapa. `vuelca_la_pantalla` (0x64A3) copia
    0x300 bytes desde 0xE8A0 menos (0xE091 & 3) * 32, o sea que la pantalla
    empieza CUATRO filas dentro del buffer de 0xE820. Con el volcado hecho a
    filas_subidas = 0, la fila r de la pantalla es la fila 4+r del buffer, y el
    buffer es lo que monta 0x6502. Las dos ULTIMAS filas se saltan: el marcador
    va ABAJO -SCORE, HISCORE, REST y STAGE en la fila 22 y sus cifras en la 23,
    como dice tools/guiones.py- y se pinta encima despues.

Uso: coteja_vram.py <rom> <org> <carpeta de volcados>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mapas import (Rom, vram_de_la_fase,                       # noqa: E402
                   TABLA_FASES, TABLA_BLOQUES)

BANDAS = 7


def buffer_del_tramo(rom, fase, tramo):
    """Las 28 filas de casillas que 0x6502 deja en 0xE820 para ese tramo."""
    lista = rom.w(TABLA_FASES + 4 * fase)
    fin = rom.w(TABLA_FASES + 4 * fase + 2)
    ix = rom.w(lista + 2 * tramo)
    filas = []
    for band in range(BANDAS):
        bits = rom.b(fin - 6 * tramo + band)
        cuatro = [[0] * 32 for _ in range(4)]
        for grupo in range(8):
            cod = rom.b(ix)
            bloque = rom.w(TABLA_BLOQUES + (cod & 0x7F) * 2)
            for f in range(4):
                for c in range(4):
                    x = rom.b(bloque + f * 4 + c)
                    cc = c
                    if cod & 0x80:
                        cc = 3 - c
                        if x & 0xF0:                    # 0x6576
                            x = x - 0x60 if x >= 0xA0 else x + 0x60
                    cuatro[f][grupo * 4 + cc] = x
            if bits & 0x80:
                ix += 1
            bits = (bits << 1) & 0xFF
        filas += cuatro
    return filas


def compara(nombre, a, b, ini, fin):
    d = sum(1 for i in range(ini, fin) if a[i] != b[i])
    print("    %-28s %5d bytes   %d distintos" % (nombre, fin - ini, d))
    return d


def main():
    rom = Rom(sys.argv[1], int(sys.argv[2], 0))
    carpeta = sys.argv[3]
    total, mirados = 0, 0
    heredada = None
    for fase in range(8):
        fn = os.path.join(carpeta, "vram_fase%d.bin" % fase)
        if not os.path.exists(fn):
            print("  falta %s" % fn)
            continue
        real = open(fn, "rb").read()
        info = open(os.path.join(carpeta, "info_fase%d.txt" % fase)).read()
        mia = vram_de_la_fase(rom, fase, heredada)
        heredada = mia
        print("  fase %d  (%s)" % (fase, " ".join(info.split()[2:8])))
        total += compara("color 0x0000..0x17FF", mia, real, 0x0000, 0x1800)
        total += compara("patrones 0x2000..0x37FF", mia, real, 0x2000, 0x3800)

        # la tabla de nombres: la fila r de la pantalla es la 4+r del buffer
        filas = buffer_del_tramo(rom, fase, 0)
        d = 0
        for r in range(0, 22):
            for c in range(32):
                if filas[4 + r][c] != real[0x3800 + r * 32 + c]:
                    d += 1
        print("    %-28s %5d casillas %d distintas"
              % ("nombres, filas 0 a 21", 22 * 32, d))
        total += d
        mirados += 1
    print("  ---- %d pantallas, %d bytes distintos" % (mirados, total))
    return 0 if total == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
