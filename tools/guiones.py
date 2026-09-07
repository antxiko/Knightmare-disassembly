#!/usr/bin/env python3
"""Lee los guiones de texto del cartucho y los pasa a letras.

El armazon pinta los rotulos con 0x43F9: un guion es una palabra con la
direccion de VRAM y detras los codigos de casilla, con 0xFE para saltar a otra
direccion y 0xFF para terminar. Los codigos NO son ASCII: son numeros de
casilla de la fuente.

El alfabeto no se supone, se LEE: los 280 bytes de 0x45C9 se descomprimen
y se dibujan glifo a glifo -las 35 casillas que el propio codigo declara con su `ld bc,00118h` de
relleno de color- y cada glifo se identifica dibujandolo. Sale un orden que
delata como se construyo la fuente: primero las cifras, el simbolo de copyright
y las doce letras mas usadas en orden alfabetico (A C E G H I M O R S T V),
detras las ocho que faltaban (F K L N P U W Y) tambien en orden, y al final los
cuatro anadidos sueltos (punto, D, cierre de exclamacion, B).

Uso: guiones.py <rom> <direccion> [<direccion> ...]
"""
import sys

ORG = 0x4000
ALFABETO = {0x00: " ", 0x1A: "(c)", 0x2F: ".", 0x31: "!"}
for i, c in enumerate("0123456789"):
    ALFABETO[0x10 + i] = c
for i, c in enumerate("ACEGHIMORSTV"):
    ALFABETO[0x1B + i] = c
for i, c in enumerate("FKLNPUWY"):
    ALFABETO[0x27 + i] = c
ALFABETO[0x30] = "D"
ALFABETO[0x32] = "B"


def fila_columna(vram):
    """La casilla de la tabla de nombres, que empieza en 0x3800."""
    n = vram - 0x3800
    return n // 32, n % 32


def guion(rom, a):
    out = []
    while True:
        vram = rom[a - ORG] | (rom[a + 1 - ORG] << 8)
        a += 2
        texto = ""
        while True:
            b = rom[a - ORG]
            a += 1
            if b == 0xFF:
                f, c = fila_columna(vram)
                out.append((vram, f, c, texto))
                return out, a
            if b == 0xFE:
                break
            texto += ALFABETO.get(b, "{%02X}" % b)
        f, c = fila_columna(vram)
        out.append((vram, f, c, texto))


def main():
    rom = open(sys.argv[1], "rb").read()
    for x in sys.argv[2:]:
        a = int(x, 0)
        lineas, fin = guion(rom, a)
        print("0x%04X..0x%04X" % (a, fin))
        for vram, f, c, t in lineas:
            print("   VRAM 0x%04X  fila %2d col %2d   |%s|" % (vram, f, c, t))


if __name__ == "__main__":
    main()
