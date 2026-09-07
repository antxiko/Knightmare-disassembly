#!/usr/bin/env python3
"""Dibuja las OCHO fases enteras, de arriba abajo, ejecutando lo que hace el
cartucho.

No hay ni una captura de pantalla aqui. La tira de cada fase se monta
repitiendo paso a paso lo que hace 0x6502, que es el montador del decorado:

  - (0xE062) es la fase, 0 a 7. La tabla de 0x99CD le da dos punteros: la lista
    de los diez tramos y el FINAL del mapa de bits de repeticion.
  - (0xE092) es el tramo, 0 a 9. Su mapa de bits empieza en
    (0xE095) - 6*tramo, y sus codigos de bloque, en la entrada numero `tramo`
    de la lista.
  - cada tramo son siete bandas de cuatro filas. Cada banda gasta un byte del
    mapa de bits y ocho grupos de cuatro columnas.
  - de cada grupo sale un codigo de bloque: los siete bits bajos indexan la
    tabla de 0x99ED y el bit 7 dice que el bloque va ESPEJADO. Detras de cada
    grupo, `rl` saca un bit del byte del mapa: con el bit puesto el puntero
    avanza, y con el a cero SE REPITE el bloque anterior.
  - un bloque son cuatro filas de cuatro casillas, dieciseis bytes.
  - al espejar, las casillas se traducen como en 0x6576: las de 0xA0 arriba
    restan 0x60 y las demas suman 0x60, que es justo la distancia entre los
    patrones normales de 0x2280 y su copia espejada de 0x2580.

Las casillas se sacan de la tabla de 0x563C, cuatro bytes por fase: el guion de
patrones y el de color, los dos comprimidos. Y las fases 3 y 7 usan EL MISMO
guion de color que la 0, pasado por el traductor de 0x443B con (0xE661) a 1 y a
2: cinco codigos de color bajan 0x50, y otros 0x50 mas en la fase 7.

Uso: mapas.py <rom> <org> <directorio de salida> [<fase>]
"""
import os
import sys

import struct
import zlib


def png(w, h, px, fn):
    """El mismo PNG de tools/dibuja.py, copiado porque aquel modulo ejecuta su
    main() al importarlo."""
    nul = bytes([0])
    raw = b"".join(nul + bytes(px[y * w * 3:(y + 1) * w * 3]) for y in range(h))

    def chunk(t, d):
        return (struct.pack(">I", len(d)) + t + d
                + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF))
    firma = bytes([137, 80, 78, 71, 13, 10, 26, 10])
    open(fn, "wb").write(firma
                         + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                         + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))


def escala(lienzo, esc):
    """El lienzo -una lista de filas de (r,g,b)- a los bytes crudos que espera
    png(), repitiendo cada pixel esc veces en las dos direcciones."""
    px = bytearray()
    for fila in lienzo:
        tira = bytearray()
        for r, g, b in fila:
            tira += bytes((r, g, b)) * esc
        px += tira * esc
    return px


TABLA_FASES = 0x99CD          # ocho entradas de cuatro bytes
TABLA_BLOQUES = 0x99ED        # 64 punteros a bloques de 4x4
TABLA_GRAFICOS = 0x563C       # ocho entradas de cuatro bytes
TRAMOS = 10
BANDAS = 7

# La paleta del TMS9918, en el orden de los codigos del VDP.
PALETA = [(0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120),
          (84, 85, 237), (125, 118, 252), (212, 82, 77), (66, 235, 245),
          (252, 85, 84), (255, 121, 120), (212, 193, 84), (230, 206, 128),
          (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255)]

# Los cinco codigos que 0x443B traduce cuando (0xE661) no es cero.
TRADUCE = (0xE1, 0xEC, 0xE8, 0xE6, 0xE5)


class Rom:
    def __init__(self, path, org):
        self.d = open(path, "rb").read()
        self.org = org

    def b(self, a):
        return self.d[a - self.org]

    def w(self, a):
        return self.b(a) | (self.b(a + 1) << 8)


def descomprime(rom, p, banco=0, con_palabra=False):
    """El formato de 0x4417, con el traductor de 0x443B si banco no es cero.

    Ojo con la palabra de destino: la lleva delante el bloque solo cuando se
    entra por 0x440C. Los guiones del decorado se descomprimen por 0x4412, con
    el destino ya en HL, y NO la llevan.
    """
    out = bytearray()
    if con_palabra:
        p += 2
    while True:
        a = rom.b(p)
        if a == 0:
            break
        p += 1
        n, lit = a & 0x7F, a & 0x80
        if not lit:                          # repetir el byte que viene
            out += bytes([traduce(rom.b(p), banco)]) * n
            p += 1
        elif n == 0:                         # 0x80: cambio de destino
            p += 2
        else:
            for _ in range(n):
                out.append(traduce(rom.b(p), banco))
                p += 1
    return bytes(out)


def traduce(v, banco):
    if banco and v in TRADUCE:
        v = (v - 0x50) & 0xFF
        if banco & 2:
            v = (v - 0x50) & 0xFF
    return v


def vuelve_los_bits(b):
    """El `vuelve_los_bits` de 0x4469: los ocho bits al reves."""
    r = 0
    for k in range(8):
        r = (r << 1) | ((b >> k) & 1)
    return r


def casillas_de_la_fase(rom, fase):
    """La hoja de 256 casillas tal como queda en la VRAM.

    0x5504 descomprime los patrones en 0x2280 -o sea la casilla 0x50- y 0x550A
    vuelve a soltar el MISMO guion, espejado, en 0x2580, que es la casilla
    0xB0. El color se descomprime dos veces sin espejar, en 0x0280 y 0x0580:
    dar la vuelta a una fila de ocho pixeles no cambia sus colores.
    """
    a = TABLA_GRAFICOS + 4 * fase
    pat = descomprime(rom, rom.w(a))
    banco = 1 if fase == 3 else 2 if fase == 7 else 0
    col = descomprime(rom, rom.w(a + 2), banco)
    hoja_p, hoja_c = bytearray(256 * 8), bytearray(256 * 8)
    for i, v in enumerate(pat):
        hoja_p[0x50 * 8 + i] = v
        hoja_p[0xB0 * 8 + i] = vuelve_los_bits(v)
    for i, v in enumerate(col):
        hoja_c[0x50 * 8 + i] = v
        hoja_c[0xB0 * 8 + i] = v
    return hoja_p, hoja_c


def dibuja_casilla(px, ancho, x0, y0, pat, col, n):
    """Una casilla de 8x8 en su sitio. Las tres bandas del SCREEN 2 llevan aqui
    la misma hoja: el decorado se descomprime con `descomprime_en_los_tres_bancos`,
    o sea el mismo guion en los tres tercios, asi que la casilla n se dibuja
    igual caiga en el tercio que caiga."""
    i = n * 8
    for f in range(8):
        b, c = pat[i + f], col[i + f]
        tinta, fondo = PALETA[c >> 4], PALETA[c & 15]
        for k in range(8):
            r, g, bl = tinta if b & (0x80 >> k) else fondo
            o = ((y0 + f) * ancho + x0 + k) * 3
            px[o], px[o + 1], px[o + 2] = r, g, bl


def monta_la_fase(rom, fase):
    """Las 244 filas de casillas de la fase, de arriba abajo.

    Los tramos SE SOLAPAN una banda: el byte del mapa de bits del tramo t esta
    en (0xE095) - 6*t y se leen SIETE, asi que la banda 6 de un tramo y la
    banda 0 del siguiente salen del mismo byte. Y no solo del mismo byte: el
    decorado que sale es identico, comprobado en los 9 empalmes de cada una de
    las ocho fases. Por eso aqui la banda repetida se pinta una sola vez, y la
    fase entera son 7 + 9*6 = 61 bandas de cuatro filas.
    """
    base = TABLA_FASES + 4 * fase
    lista, fin = rom.w(base), rom.w(base + 2)
    filas = []
    for tramo in range(TRAMOS - 1, -1, -1):        # el tramo 0 es el de ABAJO
        ix = rom.w(lista + 2 * tramo)
        bits_base = fin - 6 * tramo
        banda_filas = [[0] * 32 for _ in range(BANDAS * 4)]
        for banda in range(BANDAS):
            bits = rom.b(bits_base + banda)
            for grupo in range(8):
                cod = rom.b(ix)
                bloque = rom.w(TABLA_BLOQUES + (cod & 0x7F) * 2)
                espejo = cod & 0x80
                for f in range(4):
                    for c in range(4):
                        v = rom.b(bloque + f * 4 + c)
                        if espejo:
                            cc = 3 - c
                            if v & 0xF0:               # 0x6576
                                v = v - 0x60 if v >= 0xA0 else v + 0x60
                        else:
                            cc = c
                        banda_filas[banda * 4 + f][grupo * 4 + cc] = v
                # `rl (iy+0)` de 0x6551: el bit que sale es el 7, y con el
                # puesto el puntero avanza al bloque siguiente
                avanza = bits & 0x80
                bits = (bits << 1) & 0xFF
                if avanza:
                    ix += 1
        # el tramo de mas arriba entra entero; a los demas se les quita la
        # banda 0, que ya se pinto como banda 6 del tramo de encima
        filas += banda_filas if tramo == TRAMOS - 1 else banda_filas[4:]
    return filas


def main():
    rom = Rom(sys.argv[1], int(sys.argv[2], 0))
    salida = sys.argv[3]
    fases = [int(sys.argv[4])] if len(sys.argv) > 4 else range(8)
    os.makedirs(salida, exist_ok=True)
    for fase in fases:
        pat, col = casillas_de_la_fase(rom, fase)
        filas = monta_la_fase(rom, fase)
        w, h = 32 * 8, len(filas) * 8
        px = bytearray(w * h * 3)
        for y, fila in enumerate(filas):
            for x, n in enumerate(fila):
                dibuja_casilla(px, w, x * 8, y * 8, pat, col, n)
        fn = os.path.join(salida, "fase_%d.png" % (fase + 1))
        png(w, h, px, fn)
        print("  %s  %d x %d" % (fn, w, h))


if __name__ == "__main__":
    main()
