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
    que cambia de fase, asi que tienen que salir a CERO diferencias. Aqui se
    rehacen los cinco volcados que hace el cartucho -la fuente, las casillas de
    la fase con su copia espejada, el marcador, el marco y, solo en la fase 7,
    las casillas de mas- con el mismo orden y las mismas direcciones.

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
from mapas import Rom, descomprime, vuelve_los_bits            # noqa: E402

TABLA_FASES = 0x99CD
TABLA_BLOQUES = 0x99ED
TABLA_GRAFICOS = 0x563C
FUENTE = 0x45C9
BANDAS = 7


def banco(v, destino, datos, espejo=False):
    """`descomprime_en_los_tres_bancos` (0x43D1): el mismo guion en los tres
    tercios, 0x800 mas alla cada vez. Con espejo, `vuelca_el_guion_en_los_tres_tercios`
    (0x43E1), que ademas da la vuelta a los ocho bits de cada byte."""
    if espejo:
        datos = bytes(vuelve_los_bits(x) for x in datos)
    for k in range(3):
        i = destino + k * 0x800
        v[i:i + len(datos)] = datos


def vram_de_la_fase(rom, fase, v=None):
    """Los 0x3800 primeros bytes de la VRAM tal como los deja `monta_la_fase`.

    Se le puede pasar la VRAM que habia antes, y hay que hacerlo: el cartucho
    NO borra los patrones ni el color al cambiar de fase, solo la tabla de
    nombres. Las fases 1, 2 y 4 traen menos casillas que la 0 -61, 59 y 79
    contra 80-, asi que lo que sobra se queda de la anterior. Montar una fase
    suelta deja cientos de bytes de diferencia que no son un error de lectura
    sino herencia que falta.
    """
    v = bytearray(0x3800) if v is None else bytearray(v)

    # 0x4595: las dieciseis primeras casillas, patron a cero y un color cada
    # una, en los tres bancos
    banco(v, 0x2000, bytes(0x80))
    for n in range(16):
        banco(v, 0x0000 + n * 8, bytes([n]) * 8)

    # 0x45B5: la fuente, y su color en blanco sobre transparente
    banco(v, 0x2080, descomprime(rom, FUENTE))
    banco(v, 0x0080, bytes([0xF0]) * 0x118)

    # 0x565C: el marcador de arriba y el marco
    banco(v, 0x2138, descomprime(rom, 0xB17B))
    banco(v, 0x2438, descomprime(rom, 0xB17B), espejo=True)
    banco(v, 0x0138, descomprime(rom, 0xB285))
    banco(v, 0x0438, descomprime(rom, 0xB285))
    banco(v, 0x2500, descomprime(rom, 0xB2FB))
    banco(v, 0x0500, descomprime(rom, 0xB314))

    # 0x54F8: las casillas de la fase y su copia espejada; el color se
    # descomprime dos veces sin espejar, que dar la vuelta a una fila de ocho
    # pixeles no cambia sus colores
    a = TABLA_GRAFICOS + 4 * fase
    pat = descomprime(rom, rom.w(a))
    bank = 1 if fase == 3 else 2 if fase == 7 else 0
    col = descomprime(rom, rom.w(a + 2), bank)
    banco(v, 0x2280, pat)
    banco(v, 0x2580, pat, espejo=True)
    banco(v, 0x0280, col)
    banco(v, 0x0580, col)

    # 0x553E: y solo la fase 7 carga las casillas de mas
    if fase == 7:
        banco(v, 0x2470, descomprime(rom, 0xBE41))
        banco(v, 0x2770, descomprime(rom, 0xBE41), espejo=True)
        banco(v, 0x0470, descomprime(rom, 0xBEB7))
        banco(v, 0x0770, descomprime(rom, 0xBEB7))
    return v


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
