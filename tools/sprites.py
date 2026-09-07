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

# El fondo de las laminas de sprites es un gris medio, y no el negro del juego,
# por una razon: la mayoria de los bichos de este cartucho son siluetas de
# color 1, o sea NEGRAS. Sobre negro no se ven, y sobre blanco tampoco se verian
# las de color 15.
PAPEL = (0x74, 0x74, 0x7C)
MARGEN = (0x18, 0x18, 0x20)

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


def patron(v, n, color):
    """Un sprite de 16x16, con None donde el sprite no tapa nada.

    Los pixeles apagados de un sprite son TRANSPARENTES, y los encendidos
    llevan el color de su atributo. Devolver None en vez de un color de fondo
    no es un detalle: el color 1 es NEGRO, y un sprite negro sobre un fondo
    negro se pierde entero si se componen comparando colores en vez de mirar
    los bits. Los bichos de este cartucho son en su mayoria siluetas negras.

    El sprite son dos columnas de 16 bytes: la izquierda y la derecha.
    """
    px = [[None] * 16 for _ in range(16)]
    b = n * 32
    tinta = PALETA[color & 0x0F]
    for mitad in range(2):
        for f in range(16):
            byte = v[b + mitad * 16 + f]
            for k in range(8):
                if byte & (0x80 >> k):
                    px[f][mitad * 8 + k] = tinta
    return px


def hoja(v, color=15, cols=8, esc=2, sep=1):
    """Los 64 patrones en rejilla, numerados de 0 a 63."""
    filas = (64 + cols - 1) // cols
    w = cols * (16 + sep) + sep
    h = filas * (16 + sep) + sep
    px = bytearray()
    lienzo = [[MARGEN] * w for _ in range(h)]
    for n in range(64):
        oy = sep + (n // cols) * (16 + sep)
        ox = sep + (n % cols) * (16 + sep)
        for y in range(16):
            for x in range(16):
                lienzo[oy + y][ox + x] = PAPEL
    for n in range(64):
        d = patron(v, n, color)
        oy = sep + (n // cols) * (16 + sep)
        ox = sep + (n % cols) * (16 + sep)
        for y in range(16):
            for x in range(16):
                if d[y][x] is not None:
                    lienzo[oy + y][ox + x] = d[y][x]
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
    px = [[None] * 16 for _ in range(alto)]
    for k in reversed(range(3)):              # el plano 0 va encima del 1 y del 2
        if cs[k] & 0x0F == 0:                    # color 0: no se ve
            continue
        d = patron(v, k, cs[k])
        for f in range(16):
            for c in range(16):
                if d[f][c] is not None:
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
ARMAS = 0x63FB                  # pareja [patron][color] por arma, que lee 0x63E9
TIROS = 0x8250                  # pareja [patron][color] por fotograma de salida (0x8231)

# LOS DIECISEIS TIPOS DE BICHO, cada uno con SU bloque de patrones.
#
# El sprite de un enemigo NO se puede dibujar con la hoja de patrones fija: de
# la entrada numero 4 en adelante, el byte de patron de la tabla de 0x7772 es
# RELATIVO, y 0x775D le suma (ix+0x16), que es el patron base de la ranura en
# la que se cargo ese bicho. Sin eso salen cuadros negros.
#
# La cadena que ata cada entrada con su bloque, seguida en el listado:
#
#   (iy+0) & 0x0F  ES EL TIPO. 0x7914 lo usa para indexar 0xA993 y descomprimir
#   los cuatro patrones de ese tipo en la ranura, y 0x730F lo copia al bicho
#   vivo en (ix+1). 0x75E5 lo vuelve a leer para elegir una de las dieciseis
#   subtablas de 0x75F3, y son las rutinas de esa subtabla las que escriben
#   (ix+0x0A), que es la entrada de 0x7772.
#
# O sea que el tipo manda las dos cosas, y basta con leer que valor de
# (ix+0x0A) escribe cada subtabla. TIPOS lo recoge, y CUADRA SOLO: los
# patrones que piden las entradas de cada tipo son exactamente los que trae su
# bloque -ni uno de mas ni uno de menos- en los dieciseis.
#
#   ranura 0   patrones en 0x1D00   espejo en 0x1D80   patron base 0xA0
#   ranura 1               0x1E00               0x1E80               0xC0
#   ranura 2               0x1F00               0x1F80               0xE0
#
# El espejo lo hace `espeja_un_sprite` (0x4484), que ademas de darle la vuelta
# a los ocho bits de cada byte INTERCAMBIA las dos mitades del sprite: empieza
# a escribir en destino+0x10 y baja. Por eso las entradas con patron 0x10 o
# mas son el mismo bicho mirando al otro lado.
BANCO_DE_ENEMIGOS = 0xA993
RANURAS = 0x7944
BASE_RANURA_0 = 0xA0            # 0x7950
VRAM_RANURA_0 = 0x1D00
TIPOS = [
    # tipo: entradas de 0x7772 que escriben sus rutinas de 0x75F3
    (0,  [6, 7, 8]),
    (1,  [9, 10]),
    (2,  [9, 10]),
    (3,  [9, 10]),
    (4,  [11, 12]),
    (5,  [13, 14]),
    (6,  [15, 16]),
    (7,  [17, 18, 19, 20, 21]),
    (8,  [22, 23]),
    (9,  [24, 25]),
    (10, [26, 27]),
    (11, [5]),
    (12, [28, 29]),
    (13, [30, 31]),
    (14, [32, 33]),
    (15, [34, 35, 36, 37]),
]


def espeja_un_sprite(datos):
    """0x4484: los ocho bits de cada byte al reves y, ademas, las dos mitades
    del sprite CAMBIADAS, que es lo que hace que el bicho mire al otro lado."""
    b = bytes(vuelve_los_bits(x) for x in datos[:32])
    return b[16:32] + b[0:16]


def vram_del_tipo(rom, tipo, estaticos):
    """La VRAM de sprites con el bloque de ese tipo en la ranura 0 y su copia
    espejada detras, que es como la deja 0x78F9."""
    v = bytearray(estaticos)
    b = descomprime(rom, rom.w(BANCO_DE_ENEMIGOS + 2 * tipo))
    i = VRAM_RANURA_0 - PATRONES
    v[i:i + len(b)] = b
    for k in range(len(b) // 32):
        e = espeja_un_sprite(b[k * 32:k * 32 + 32])
        j = i + 0x80 + k * 32
        v[j:j + 32] = e
    return v


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


def cuantos_enemigos(rom):
    """Los punteros de 0x7772, hasta el primero de los apuntados."""
    v = [rom.w(ENEMIGOS + 2 * k) for k in range(64)]
    mn = min(x for x in v if ENEMIGOS < x < ENEMIGOS + 0x200)
    return (mn - ENEMIGOS) // 2


def dibuja_un_enemigo(rom, v, p, base=0):
    """Los dos sprites de un enemigo, cada uno con su desplazamiento.

    `base` es (ix+0x16), el patron base de la ranura: 0x7755 se lo suma al
    byte de patron de las entradas de la 5 en adelante -`cp 005h` y `jr c`- y
    NO a las cuatro primeras, que llevan patron absoluto.
    """
    trozos = []
    for k in range(2):
        dy, dx = rom.b(p + 4 * k), rom.b(p + 4 * k + 1)
        pat, col = rom.b(p + 4 * k + 2), rom.b(p + 4 * k + 3)
        dy = dy - 256 if dy > 127 else dy
        dx = dx - 256 if dx > 127 else dx
        trozos.append((dy, dx, ((pat + base) & 0xFF) >> 2, col))
    y0 = min(t[0] for t in trozos)
    x0 = min(t[1] for t in trozos)
    alto = max(t[0] for t in trozos) - y0 + 16
    ancho = max(t[1] for t in trozos) - x0 + 16
    px = [[None] * ancho for _ in range(alto)]
    # el PLANO manda: 0x772A escribe los dos sprites en atributos seguidos, y
    # en el TMS9918 gana el de numero mas bajo. O sea que el primero va ENCIMA
    # del segundo, y hay que pintarlos del ultimo al primero. Al reves, el
    # relleno macizo tapa la silueta y el bicho sale como un cuadro de color.
    for dy, dx, bloque, col in reversed(trozos):
        if col & 0x0F == 0:
            continue
        d = patron(v, bloque, col)
        for f in range(16):
            for c in range(16):
                if d[f][c] is not None:
                    px[dy - y0 + f][dx - x0 + c] = d[f][c]
    return px


def monta_sprites(rom, v, tabla, cuantos, base=0):
    """Un monton de sprites [dy][dx][patron][color] montado en una sola figura.

    Es lo mismo que hace `dibuja_un_enemigo` con sus dos, pero con los que
    haga falta: los jefes de la fase 1 y de la 3 se declaran asi, con siete y
    nueve sprites. Se pintan del ultimo al primero por la prioridad de plano.
    """
    trozos = []
    for k in range(cuantos):
        p = tabla + 4 * k
        dy, dx = rom.b(p), rom.b(p + 1)
        trozos.append((dy - 256 if dy > 127 else dy,
                       dx - 256 if dx > 127 else dx,
                       ((rom.b(p + 2) + base) & 0xFF) >> 2, rom.b(p + 3)))
    y0 = min(t[0] for t in trozos)
    x0 = min(t[1] for t in trozos)
    px = [[None] * (max(t[1] for t in trozos) - x0 + 16)
          for _ in range(max(t[0] for t in trozos) - y0 + 16)]
    for dy, dx, bloque, col in reversed(trozos):
        if col & 0x0F == 0:
            continue
        d = patron(v, bloque, col)
        for f in range(16):
            for c in range(16):
                if d[f][c] is not None:
                    px[dy - y0 + f][dx - x0 + c] = d[f][c]
    return px


def rejilla(dibujos, cols, esc=3, sep=2):
    alto = max(len(d) for d in dibujos)
    ancho = max(len(d[0]) for d in dibujos)
    filas = (len(dibujos) + cols - 1) // cols
    w = cols * (ancho + sep) + sep
    h = filas * (alto + sep) + sep
    lienzo = [[MARGEN] * w for _ in range(h)]
    for i, d in enumerate(dibujos):
        oy = sep + (i // cols) * (alto + sep)
        ox = sep + (i % cols) * (ancho + sep)
        for y in range(alto):
            for x in range(ancho):
                lienzo[oy + y][ox + x] = PAPEL
        for y, fila in enumerate(d):
            for x, c in enumerate(fila):
                if c is not None:
                    lienzo[oy + alto - len(d) + y][ox + x] = c
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
    lienzo = [[MARGEN] * w for _ in range(h)]
    for i, d in enumerate(dibujos):
        ox = sep + i * (ancho + sep)
        for y in range(alto):
            for x in range(ancho):
                lienzo[sep + y][ox + x] = PAPEL
        for y, fila in enumerate(d):
            for x, c in enumerate(fila):
                if c is not None:
                    lienzo[sep + alto - len(d) + y][ox + x] = c
    estaticos = vram_con(rom, list(range(len(BLOQUES))))
    n = cuantos_enemigos(rom)

    # las cuatro primeras entradas llevan patron absoluto (0x7755); las demas
    # van con el bloque de SU tipo cargado en la ranura 0
    ene = [dibuja_un_enemigo(rom, estaticos, rom.w(ENEMIGOS + 2 * k))
           for k in range(5)]
    for tipo, entradas in TIPOS:
        v = vram_del_tipo(rom, tipo, estaticos)
        for k in entradas:
            ene.append(dibuja_un_enemigo(rom, v, rom.w(ENEMIGOS + 2 * k),
                                         BASE_RANURA_0))
    w2, h2, px2 = rejilla(ene, 8)
    fn2 = os.path.join(salida, "enemigos.png")
    png(w2, h2, px2, fn2)
    print("  %s  %d x %d  (los %d fotogramas de la tabla de 0x7772: %d de patron"
          " absoluto y los demas, por tipo, con su bloque de 0xA993)"
          % (fn2, w2, h2, len(ene), 5))

    # LAS ARMAS, en color. 0x63E9 saca de la tabla de 0x63FB una pareja
    # [patron][color] por arma y le suma cuatro por fotograma, que es (ix+6).
    # Solo las armas 6 y 7 se animan -0x636D, `and 003h`: cuatro fotogramas-;
    # las otras cinco llevan (ix+6) a cero y salen con uno solo.
    armas = []
    for arma in range(7):
        pat = rom.b(ARMAS + 2 * arma)
        col = rom.b(ARMAS + 2 * arma + 1)
        for f in range(4 if arma >= 5 else 1):
            armas.append(patron(estaticos, (pat + 4 * f) >> 2, col))
    w4, h4, px4 = rejilla(armas, 7)
    fn4 = os.path.join(salida, "armas.png")
    png(w4, h4, px4, fn4)
    print("  %s  %d x %d  (las siete armas de 0x63FB; las dos ultimas, con sus"
          " cuatro fotogramas)" % (fn4, w4, h4))

    # LOS JEFES que el cartucho declara con una tabla entera de sprites:
    # 0x902D son SIETE [dy][dx][patron][color] -el de la fase 1- y 0x9338,
    # NUEVE -el de la fase 3-. El patron les va absoluto, pero NO al banco
    # fijo: antes de pintarse, cada jefe SUBE LOS SUYOS -0x8E57 y 0x9224, con
    # `descomprime_desde_la_palabra`, que lleva el destino dentro del bloque- y
    # los dos van a 0x1B00, que es justo el patron 0x60 con el que empiezan las
    # dos tablas. Sin ese volcado salen las armas del banco fijo, que es lo que
    # hay en 0x1B00 el resto de la partida.
    # SOLO ESTOS DOS. El de la fase 2 (0x9156) tiene TRES juegos de seis
    # sprites y ademas 0x9186 le pega la cola 0x34 a la derecha, aparte de la
    # tabla: montado solo con los seis sale un trozo suelto, y no se publica un
    # dibujo que no se ha entendido. Los de las fases 4 a 8 tampoco se han
    # localizado. Queda pendiente.
    for nombre, tabla, cuantos, guion, que in (
            ("jefe_fase1", 0x902D, 7, 0xAD69,
             "el jefe de la fase 1, siete sprites, con sus once patrones"),
            ("jefe_fase3", 0x9338, 9, 0xAEA6,
             "el jefe de la fase 3, nueve sprites, con sus diecisiete")):
        v = bytearray(estaticos)
        if guion is not None:
            b = descomprime(rom, guion, con_palabra=True)
            i = rom.w(guion) - PATRONES
            v[i:i + len(b)] = b
        d = monta_sprites(rom, v, tabla, cuantos)
        w5, h5, px5 = rejilla([d], 1, esc=3, sep=2)
        fn5 = os.path.join(salida, nombre + ".png")
        png(w5, h5, px5, fn5)
        print("  %s  %d x %d  (%s)" % (fn5, w5, h5, que))

    # LOS DISPAROS DEL MUNECO: pareja [patron][color] por fotograma de salida,
    # de la tabla de 0x8250, que 0x8231 indexa con la cuenta
    tiros = [patron(estaticos, rom.b(TIROS + 2 * k) >> 2, rom.b(TIROS + 2 * k + 1))
             for k in range(7)]
    w6, h6, px6 = rejilla(tiros, 7)
    fn6 = os.path.join(salida, "disparos.png")
    png(w6, h6, px6, fn6)
    print("  %s  %d x %d  (los siete fotogramas de salida del disparo, 0x8250)"
          % (fn6, w6, h6))

    # y los dieciseis tipos de un vistazo: un fotograma de cada uno
    banco = []
    for tipo, entradas in TIPOS:
        v = vram_del_tipo(rom, tipo, estaticos)
        banco.append(dibuja_un_enemigo(rom, v, rom.w(ENEMIGOS + 2 * entradas[0]),
                                       BASE_RANURA_0))
    w3, h3, px3 = rejilla(banco, 8)
    fn3 = os.path.join(salida, "banco_de_enemigos.png")
    png(w3, h3, px3, fn3)
    print("  %s  %d x %d  (los 16 tipos de 0xA993, uno por bloque, con el color"
          " que les pone 0x7772)" % (fn3, w3, h3))

    fn = os.path.join(salida, "jugador.png")
    png(w * esc, h * esc, escala(lienzo, esc), fn)
    print("  %s  %d x %d  (los %d fotogramas del jugador)"
          % (fn, w * esc, h * esc, len(dibujos)))


if __name__ == "__main__":
    main()
