#!/usr/bin/env python3
"""Dibuja los patrones de sprite de 16x16, montando la VRAM como el cartucho.

Los patrones de sprite viven en la VRAM a partir de 0x1800 -lo dice R6 = 0x03
en la tabla de 0x44C5- y son 64 de 32 bytes. NO estan todos a la vez: el
cartucho los va soltando por trozos segun lo que haga falta, y por eso aqui se
monta un juego de VRAM por cada situacion, con los bloques que el codigo suelta
en ella.

Cada bloque se localiza leyendo el listado: un `ld hl,<destino>` seguido de un
`ld de,<datos>` y una llamada al descompresor. Los destinos que salen son:

    0x1840  0xA71E  al empezar la fase (0x54BE), 1184 bytes = 37 patrones
    0x1C20  0xAF73  0x90C5, y encima 0xB060 por 0x90CB
    0x1CC0  0xAF73  0x8AEC
    0x1E00  0xAD17  0x8AF5      0x1E00  0xABDC  0x90DF y 0x9230
    0x1E00  0xAB9D  0x943B      0x1F80  0xABDC  0x8E63

Uso: sprites.py <rom> <org> <directorio de salida>
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mapas import (Rom, descomprime, png, escala, PALETA,          # noqa: E402
                   vuelve_los_bits)

PATRONES = 0x1800                       # R6 = 0x03 -> 0x03 * 0x800
FONDO = PALETA[0]                       # R7 = 0xE0: el fondo es el color 0

# (destino de VRAM, datos, con la palabra de destino dentro, quien lo suelta)
BLOQUES = [
    (0x1840, 0xA71E, True,  "0x54BE, al empezar la fase"),
    (0x1C20, 0xAF73, False, "0x90C5"),
    (0x1C20, 0xB060, True,  "0x90CB, encima del anterior"),
    (0x1CC0, 0xAF73, False, "0x8AEC"),
    (0x1E00, 0xAD17, False, "0x8AF5"),
    (0x1E00, 0xABDC, False, "0x90DF y 0x9230"),
    (0x1E00, 0xAB9D, False, "0x943B"),
    (0x1F80, 0xABDC, False, "0x8E63"),
]


def vram_con(rom, cuales):
    """Los 0x800 bytes de patrones de sprite con los bloques que se pidan."""
    v = bytearray(0x800)
    for k in cuales:
        destino, datos, palabra, _ = BLOQUES[k]
        b = descomprime(rom, datos, con_palabra=palabra)
        i = destino - PATRONES
        v[i:i + len(b)] = b[:0x800 - i]
    return v


def patron(v, n, color, fondo=FONDO):
    """Un sprite de 16x16: cuatro cuartos de 8x8 en el orden del VDP -izquierda
    arriba, izquierda abajo, derecha arriba, derecha abajo-."""
    px = [[fondo] * 16 for _ in range(16)]
    b = n * 32
    for mitad in range(2):
        for f in range(16):
            byte = v[b + mitad * 16 + f]
            for k in range(8):
                if byte & (0x80 >> k):
                    px[f][mitad * 8 + k] = PALETA[color & 0x0F]
    return px


def hoja(v, color=15, cols=8, esc=2, sep=1):
    """Los 64 patrones en rejilla, numerados de 0 a 63."""
    filas = (64 + cols - 1) // cols
    w = cols * (16 + sep) + sep
    h = filas * (16 + sep) + sep
    px = bytearray()
    lienzo = [[(0x18, 0x18, 0x20)] * w for _ in range(h)]
    for n in range(64):
        d = patron(v, n, color)
        oy = sep + (n // cols) * (16 + sep)
        ox = sep + (n % cols) * (16 + sep)
        for y in range(16):
            lienzo[oy + y][ox:ox + 16] = d[y]
    for fila in lienzo:
        for r, g, b in fila:
            px += bytes((r, g, b))
    return w * esc, h * esc, escala(lienzo, esc)


# --------------------------------------------------------------------------
# EL JUGADOR
# --------------------------------------------------------------------------
# 0x5E82 saca su fotograma de DOS tablas: la de 0xA5B4, indexada por
# (ix+0x0C) & 0x0F -la animacion-, da una tabla de fotogramas, y (ix+6) elige
# dentro. El fotograma es un guion que 0x5E9D suelta en la VRAM a partir de
# 0x1800: cada entrada es [n][palabra], con n = 0xFF para un bloque comprimido
# y cualquier otro valor para 32 bytes tal cual; el 0x00 lo cierra. Los diez
# fotogramas ocupan 64 bytes cada uno, o sea DOS patrones justos.
#
# Y el muneco son TRES sprites: 0x5E2D los escribe con `ld b,003h` y les pone
# los patrones (3-b)*4, o sea los bloques 0, 1 y 2. Los dos primeros los acaba
# de subir el fotograma; el tercero es el primero del banco de la fase, que
# 0x54BE deja en 0x1840. La y de cada uno y su color salen de un bloque de seis
# bytes -tres parejas [ajuste de y][color]-: 0xA5C2 el corriente, 0xA5EF el que
# alterna con el al parpadear y 0xA60B el de la animacion 4.
ANIMACIONES = 0xA5B4
ATRIBUTOS = {0: 0xA5C2, 1: 0xA5C2, 2: 0xA5EF, 3: 0xA5C2, 4: 0xA60B}


def rle_del_fotograma(rom, p):
    """0x5EAF: n con el bit 7 puesto = n bytes tal cual, n = el siguiente
    repetido n veces, 0x00 = fin. Sin palabra de destino."""
    out = bytearray()
    while True:
        a = rom.b(p)
        if a == 0:
            break
        p += 1
        n = a & 0x7F
        if n == a:
            out += bytes([rom.b(p)]) * n
            p += 1
        else:
            out += bytes(rom.b(p + k) for k in range(n))
            p += n
    return bytes(out)


def fotogramas_del_jugador(rom):
    """[(animacion, fotograma, los 64 bytes de sus dos patrones)]."""
    # los dos bloques que 0x54C1 descomprime en la RAM, en 0xEE20 y 0xEE40
    ram = {}
    for k, base in enumerate((0xEE20, 0xEE40)):
        b = rle_del_fotograma(rom, rom.w(0x5615 + 2 * k))
        ram[base] = (b + bytes(0x20))[:0x20]
    out = []
    for anim in range(5):
        t = rom.w(ANIMACIONES + 2 * anim)
        for f in range(8):
            p = rom.w(t + 2 * f)
            if not (0xA5B4 <= p < 0xA71E):
                break
            datos, q = bytearray(), p
            while True:
                a = rom.b(q)
                if a == 0:
                    break
                q += 1
                d = rom.w(q)
                q += 2
                datos += rle_del_fotograma(rom, d) if a == 0xFF else ram.get(d, bytes(32))
            out.append((anim, f, bytes(datos)))
    return out


def dibuja_al_jugador(rom, v_fase, datos, atributos):
    """Los tres sprites, cada uno con su ajuste de y y su color."""
    v = bytearray(v_fase)
    v[0:len(datos)] = datos                      # los bloques 0 y 1
    ys = [rom.b(atributos + 2 * k) for k in range(3)]
    cs = [rom.b(atributos + 2 * k + 1) for k in range(3)]
    ys = [y - 256 if y > 127 else y for y in ys]
    y0 = min(ys)
    alto = max(y + 16 for y in ys) - y0
    px = [[FONDO] * 16 for _ in range(alto)]
    for k in range(3):
        if cs[k] & 0x0F == 0:                    # color 0: no se ve
            continue
        d = patron(v, k, cs[k])
        for f in range(16):
            for c in range(16):
                if d[f][c] != FONDO:
                    px[ys[k] - y0 + f][c] = d[f][c]
    return px


# --------------------------------------------------------------------------
# LOS ENEMIGOS
# --------------------------------------------------------------------------
# 0x772A monta los sprites de los siete enemigos vivos: recorre la tabla de
# 0xE100 de 0x20 en 0x20, indexa 0x7772 con (ix+0x0A) y de ahi saca un bloque
# de OCHO bytes, o sea DOS sprites de [dy][dx][patron][color] que se suman a la
# posicion del enemigo. Los punteros son 38 y cierran solos: el mas bajo,
# 0x77BE, esta a 76 bytes del principio de la tabla.
ENEMIGOS = 0x7772

# --------------------------------------------------------------------------
# EL BANCO DE ENEMIGOS
# --------------------------------------------------------------------------
# Los enemigos no caben todos en la hoja de 64 patrones, asi que el cartucho
# tiene TRES ranuras que va recargando: 0x78F9 coge (iy+0) & 0x0F, indexa la
# tabla de 0xA993 y descomprime cuatro patrones en la ranura que toque.
#
#   ranura   patrones en   espejo en   el patron base que se suma a (ix+0x16)
#     0        0x1D00        0x1D90                 0xA0
#     1        0x1E00        0x1E90                 0xC0
#     2        0x1F00        0x1F90                 0xE0
#
# Los destinos salen de 0x7944 y 0x794A y los patrones base de 0x7950, las tres
# tablas de tres entradas que 0x78F9 indexa con (0xE1F1).
BANCO_DE_ENEMIGOS = 0xA993
RANURAS = 0x7944


def cuantos_enemigos(rom):
    """Los punteros de 0x7772, hasta el primero de los apuntados."""
    v = [rom.w(ENEMIGOS + 2 * k) for k in range(64)]
    mn = min(x for x in v if ENEMIGOS < x < ENEMIGOS + 0x200)
    return (mn - ENEMIGOS) // 2


def dibuja_un_enemigo(rom, v, p):
    """Los dos sprites de un enemigo, cada uno con su desplazamiento."""
    trozos = []
    for k in range(2):
        dy, dx = rom.b(p + 4 * k), rom.b(p + 4 * k + 1)
        pat, col = rom.b(p + 4 * k + 2), rom.b(p + 4 * k + 3)
        dy = dy - 256 if dy > 127 else dy
        dx = dx - 256 if dx > 127 else dx
        trozos.append((dy, dx, pat >> 2, col))
    y0 = min(t[0] for t in trozos)
    x0 = min(t[1] for t in trozos)
    alto = max(t[0] for t in trozos) - y0 + 16
    ancho = max(t[1] for t in trozos) - x0 + 16
    px = [[FONDO] * ancho for _ in range(alto)]
    for dy, dx, bloque, col in trozos:
        if col & 0x0F == 0:
            continue
        d = patron(v, bloque, col)
        for f in range(16):
            for c in range(16):
                if d[f][c] != FONDO:
                    px[dy - y0 + f][dx - x0 + c] = d[f][c]
    return px


def rejilla(dibujos, cols, esc=3, sep=2):
    alto = max(len(d) for d in dibujos)
    ancho = max(len(d[0]) for d in dibujos)
    filas = (len(dibujos) + cols - 1) // cols
    w = cols * (ancho + sep) + sep
    h = filas * (alto + sep) + sep
    lienzo = [[(0x18, 0x18, 0x20)] * w for _ in range(h)]
    for i, d in enumerate(dibujos):
        oy = sep + (i // cols) * (alto + sep)
        ox = sep + (i % cols) * (ancho + sep)
        for y, fila in enumerate(d):
            lienzo[oy + alto - len(d) + y][ox:ox + len(fila)] = fila
    return w * esc, h * esc, escala(lienzo, esc)


def bloques_de_enemigo(rom):
    """Los dieciseis bloques de la tabla de 0xA993, de cuatro patrones cada uno."""
    out = []
    for k in range(16):
        p = rom.w(BANCO_DE_ENEMIGOS + 2 * k)
        b = descomprime(rom, p)
        out.append((k, p, b))
    return out


def hoja_de_un_bloque(datos, color, esc=3, sep=2):
    """Los cuatro patrones de 16x16 de un bloque, uno al lado del otro."""
    v = bytearray(0x800)
    v[0:len(datos)] = datos[:0x800]
    dibujos = [patron(v, n, color) for n in range(len(datos) // 32)]
    return dibujos


def main():
    rom = Rom(sys.argv[1], int(sys.argv[2], 0))
    salida = sys.argv[3]
    os.makedirs(salida, exist_ok=True)
    juegos = [
        ("sprites_fase", [0], "los 37 patrones que sube 0x54BE al empezar la fase"),
        ("sprites_todos", list(range(len(BLOQUES))),
         "todos los bloques encima, para ver el reparto de la hoja"),
    ] + [("sprites_bloque_%04X_en_%04X" % (BLOQUES[k][1], BLOQUES[k][0]), [k],
          BLOQUES[k][3]) for k in range(1, len(BLOQUES))]
    for nombre, cuales, que in juegos:
        v = vram_con(rom, cuales)
        w, h, px = hoja(v)
        fn = os.path.join(salida, nombre + ".png")
        png(w, h, px, fn)
        print("  %s  %d x %d  (%s)" % (fn, w, h, que))

    # el jugador, fotograma a fotograma
    v_fase = vram_con(rom, [0])
    dibujos = [dibuja_al_jugador(rom, v_fase, datos, ATRIBUTOS[a])
               for a, f, datos in fotogramas_del_jugador(rom)]
    esc, sep = 3, 2
    alto = max(len(d) for d in dibujos)
    ancho = 16
    w = len(dibujos) * (ancho + sep) + sep
    h = alto + 2 * sep
    lienzo = [[(0x18, 0x18, 0x20)] * w for _ in range(h)]
    for i, d in enumerate(dibujos):
        ox = sep + i * (ancho + sep)
        for y, fila in enumerate(d):
            lienzo[sep + alto - len(d) + y][ox:ox + ancho] = fila
    v = vram_con(rom, list(range(len(BLOQUES))))
    n = cuantos_enemigos(rom)
    ene = [dibuja_un_enemigo(rom, v, rom.w(ENEMIGOS + 2 * k)) for k in range(n)]
    w2, h2, px2 = rejilla(ene, 8)
    fn2 = os.path.join(salida, "enemigos.png")
    png(w2, h2, px2, fn2)
    print("  %s  %d x %d  (los %d enemigos de la tabla de 0x7772)"
          % (fn2, w2, h2, n))

    # el banco de enemigos: dieciseis bloques de cuatro patrones
    todos = []
    for k, p, b in bloques_de_enemigo(rom):
        todos += hoja_de_un_bloque(b, 15)
    w3, h3, px3 = rejilla(todos, 8)
    fn3 = os.path.join(salida, "banco_de_enemigos.png")
    png(w3, h3, px3, fn3)
    print("  %s  %d x %d  (%d patrones, los 16 bloques de 0xA993)"
          % (fn3, w3, h3, len(todos)))

    fn = os.path.join(salida, "jugador.png")
    png(w * esc, h * esc, escala(lienzo, esc), fn)
    print("  %s  %d x %d  (los %d fotogramas del jugador)"
          % (fn, w * esc, h * esc, len(dibujos)))


if __name__ == "__main__":
    main()
