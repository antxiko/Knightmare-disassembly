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

# LA HOJA DE CASILLAS NO ES SOLO LA DE LA FASE. Antes de montarla, 0x41C2 y
# 0x5A46 llaman a `monta_el_marcador` (0x565C), que sube OTRO bloque de 41
# casillas -de la 0x27 a la 0x4F- y su copia espejada en la 0x87. Ese bloque no
# es solo el rotulo de arriba: ahi estan tambien los RIOS y los PUENTES, que
# son iguales en las ocho fases. Y detras, tres casillas de marco en la 0xA0.
#
# El orden importa, y es el de la maquina: primero el marcador, y encima las
# casillas de la fase, que pisan de la 0x87 a la 0x9F la copia espejada de
# aquel. Al reves saldrian rotas.
MARCADOR_PAT = 0xB17B         # descomprime a 0x2138 -> casilla 0x27
MARCADOR_COL = 0xB285         # y a 0x0138; la copia va a 0x2438 / 0x0438
MARCO_PAT = 0xB2FB            # a 0x2500 -> casilla 0xA0, tres casillas
MARCO_COL = 0xB314            # a 0x0500
EXTRA7_PAT = 0xBE41           # solo la fase 7: a 0x2470 -> casilla 0x8E
EXTRA7_COL = 0xBEB7           # y a 0x0470
FUENTE = 0x45C9               # 0x45B5 la sube a 0x2080 -> casilla 0x10

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


def en_los_tres_bancos(v, destino, datos, espejo=False):
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

    Esta es LA hoja de casillas, y no hay otra: de aqui salen tanto las
    imagenes como el cotejo contra el emulador (tools/coteja_vram.py la
    importa). La geometria va al reves de lo normal -R3 = 0x7F y R4 = 0x07 en
    los ocho bytes de 0x44C5-: el color en 0x0000, los patrones en 0x2000.

    Los cinco volcados, en el orden en que los hace el cartucho:

      * 0x4595 las dieciseis primeras casillas: patron a cero y un color cada
        una, o sea dieciseis casillas macizas de un color;
      * 0x45B5 la fuente en 0x2080 -la casilla 0x10-, blanca sobre transparente;
      * 0x565C el marcador y el marco. NO es solo el rotulo de abajo: en esas
        41 casillas de la 0x27 a la 0x4F estan los RIOS y los PUENTES del
        decorado, iguales en las ocho fases. Se cargan tambien espejadas en la
        0x87, y encima van tres casillas de marco en la 0xA0;
      * 0x54F8 las casillas de la fase en la 0x50 y su copia espejada en la
        0xB0 -que pisa de la 0x87 a la 0x9F lo que dejo el marcador-; el color
        se descomprime dos veces SIN espejar, que dar la vuelta a una fila de
        ocho pixeles no cambia sus colores;
      * 0x553E las nueve casillas de mas de la fase 7, y solo de ella.

    Se le puede pasar la VRAM que habia antes, y hay que hacerlo: el cartucho
    NO borra los patrones ni el color al cambiar de fase, solo la tabla de
    nombres. Las fases 1, 2 y 4 traen menos casillas que la 0 -61, 59 y 79
    contra 80-, asi que lo que sobra se queda de la anterior.
    """
    v = bytearray(0x3800) if v is None else bytearray(v)

    en_los_tres_bancos(v, 0x2000, bytes(0x80))
    for n in range(16):
        en_los_tres_bancos(v, 0x0000 + n * 8, bytes([n]) * 8)

    en_los_tres_bancos(v, 0x2080, descomprime(rom, FUENTE))
    en_los_tres_bancos(v, 0x0080, bytes([0xF0]) * 0x118)

    en_los_tres_bancos(v, 0x2138, descomprime(rom, MARCADOR_PAT))
    en_los_tres_bancos(v, 0x2438, descomprime(rom, MARCADOR_PAT), espejo=True)
    en_los_tres_bancos(v, 0x0138, descomprime(rom, MARCADOR_COL))
    en_los_tres_bancos(v, 0x0438, descomprime(rom, MARCADOR_COL))
    en_los_tres_bancos(v, 0x2500, descomprime(rom, MARCO_PAT))
    en_los_tres_bancos(v, 0x0500, descomprime(rom, MARCO_COL))

    a = TABLA_GRAFICOS + 4 * fase
    pat = descomprime(rom, rom.w(a))
    bank = 1 if fase == 3 else 2 if fase == 7 else 0
    col = descomprime(rom, rom.w(a + 2), bank)
    en_los_tres_bancos(v, 0x2280, pat)
    en_los_tres_bancos(v, 0x2580, pat, espejo=True)
    en_los_tres_bancos(v, 0x0280, col)
    en_los_tres_bancos(v, 0x0580, col)

    if fase == 7:
        en_los_tres_bancos(v, 0x2470, descomprime(rom, EXTRA7_PAT))
        en_los_tres_bancos(v, 0x2770, descomprime(rom, EXTRA7_PAT), espejo=True)
        en_los_tres_bancos(v, 0x0470, descomprime(rom, EXTRA7_COL))
        en_los_tres_bancos(v, 0x0770, descomprime(rom, EXTRA7_COL))
    return v


def casillas_de_la_fase(rom, fase, heredada=None):
    """Las 256 casillas de un banco, sacadas de la VRAM que monta la fase.

    Las tres bandas del SCREEN 2 llevan la misma hoja -todos los volcados van
    `en_los_tres_bancos`-, asi que con el primer tercio basta.
    """
    v = vram_de_la_fase(rom, fase, heredada)
    return v[0x2000:0x2800], v[0x0000:0x0800]


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
    # la hoja se hereda de una fase a la siguiente, como en la partida: el
    # cartucho no borra los patrones al cambiar de fase, y las fases 2, 3 y 5
    # traen menos casillas que la 1
    heredada = None
    for fase in range(8):
        pat, col = casillas_de_la_fase(rom, fase, heredada)
        heredada = vram_de_la_fase(rom, fase, heredada)
        if fase not in fases:
            continue
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
