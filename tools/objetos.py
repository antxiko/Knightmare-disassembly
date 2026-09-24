#!/usr/bin/env python3
"""Los OBJETOS que cada fase siembra sobre el mapa, dibujados encima de el.

No estan en el mapa de bloques: son una LISTA por fase de registros de tres
bytes -tipo, y, x- en 0x6AF8 (356 en total), que 0x6A1E va montando en ocho
ranuras de 0xE4F0 a medida que el decorado baja. Lo que hace cada bit del tipo
lo dice el propio codigo:

  bit 4     baja con el decorado (0x648E); lo llevan todos
  bit 5     VISIBLE desde que nace: (ix+1) arranca en 1 y 0x6883 pinta el
            interrogante de 0x6F40 en cuanto (ix+1) no es cero. Sin el bit,
            el bloque esta ESCONDIDO hasta el primer disparo
  bits 0-3  cuantos disparos aguanta, por la tabla de 0x6A7F
  bits 0-2  lo que deja al romperse, por la tabla de reparto de 0x6909:
              0 una vida (el pergamino amarillo de 0x6F24, una_vida_mas)
              1 500 puntos (el cian de 0x6F28)
              2 mata a todos (el azul de 0x6F2C)
              3 congela a todos (el rojo de 0x6F30)
              4 deja el bloque gris de 0x6F34 y se queda ahi
              5 el cartel EXIT de 0x6F38: tocarlo salta de fase, tantas como
                diga la pareja de 0x6A8C que case con su y, y una mas al
                cerrar la fase. Solo nace si (0xE006) -la fase mas alta ya
                cerrada desde el encendido, 0x4232- llega a la fase actual
              6 pinta el puente de 0x9A9C, cuatro por cuatro, a su alrededor
              7 no es un bloque: es un PASADIZO lateral (0x69D5). Los tipos
                0x17 en adelante nacen ya en ese estado (0x6A32). Van en
                parejas a la misma altura, uno en x=1 y otro en x=248: una
                franja de ocho pixeles de ancho en cada borde, tan alta como
                diga el nibble alto de 0x6A7F por dos (32, 64 o 96), y el bit
                0 dice si hay que empujar hacia la izquierda o la derecha;
                el muneco sale por el otro lado de la pantalla (0x69FA)

DONDE CAE CADA UNO. El registro nace cuando (0xE091) -la fila que lleva
bajada la fase- iguala su y, y nace en la fila 0 de la pantalla. Medido en
openMSX en once siembras de seis fases (work/siembra.txt): la fila del mapa
que hay arriba de la pantalla es siempre 220 - (0xE091), asi que el objeto
cae en la fila 220 - y del mapa de tools/mapas.py, y en la columna x/8, que
es lo que hace de_pixeles_a_direccion (0x4372).

Uso: objetos.py <rom> <org> <directorio de salida> [<fase>]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mapas as M                                   # noqa: E402

POR_FASE = 0x6A98             # ocho entradas de doce bytes; la palabra es la base
FIN_REGISTROS = 0x6F24        # donde acaban los de la fase 8
AGUANTE = 0x6A7F              # quince valores, por el nibble bajo del tipo
SALTOS = 0x6A8C               # seis parejas [y][fases de mas] del EXIT
DIBUJOS = {0: 0x6F24, 1: 0x6F28, 2: 0x6F2C, 3: 0x6F30, 4: 0x6F34, 5: 0x6F38}
INTERROGANTE = 0x6F40
PUENTE = 0x9A9C
FILA_DE_ARRIBA = 220          # 220 - (0xE091): medido, work/siembra.txt
NOMBRES = {0: "una vida", 1: "500 puntos", 2: "bomba", 3: "congelar",
           4: "bloque gris", 5: "EXIT", 6: "puente", 7: "pasadizo"}

BLANCO = (255, 255, 255)
MAGENTA = (255, 0, 255)
CIAN = (0, 255, 255)


def registros(rom, fase):
    """Los registros [tipo, y, x] de una fase, en el orden en que nacen."""
    base = rom.w(POR_FASE + 12 * fase)
    fin = rom.w(POR_FASE + 12 * (fase + 1)) if fase < 7 else FIN_REGISTROS
    return [(rom.b(a), rom.b(a + 1), rom.b(a + 2)) for a in range(base, fin, 3)]


def clasifica(rom, fase, t, y, x):
    """Que es un registro: clase, visible, disparos, fila, columna y extra."""
    n = t & 7
    fila, col = FILA_DE_ARRIBA - y, x // 8
    aguante = rom.b(AGUANTE + (t & 0x0F))
    if (t & 0x1F) >= 0x17:                          # el `cp 017h` de 0x6A32
        alto = (aguante & 0xF0) * 2                 # B de la caja: el alto
        return dict(clase=7, visible=False, disparos=0, fila=fila, col=col,
                    alto=alto, derecha=bool(aguante & 1))
    visible = bool(t & 0x20)
    extra = {}
    if n == 5:
        for i in range(6):
            if rom.b(SALTOS + 2 * i) == y:
                extra["destino"] = fase + 1 + rom.b(SALTOS + 2 * i + 1) + 1
    return dict(clase=n, visible=visible, disparos=aguante + (1 if visible else 0),
                fila=fila, col=col, **extra)


def marco(px, w, h, x0, y0, ancho, alto, color, punteado=False):
    """Un rectangulo de un pixel alrededor de un dibujo."""
    for k in range(ancho):
        for yy in (y0 - 1, y0 + alto):
            if 0 <= yy < h and 0 <= x0 + k < w and (not punteado or k % 4 < 2):
                o = (yy * w + x0 + k) * 3
                px[o:o + 3] = bytes(color)
    for k in range(alto):
        for xx in (x0 - 1, x0 + ancho):
            if 0 <= xx < w and 0 <= y0 + k < h and (not punteado or k % 4 < 2):
                o = ((y0 + k) * w + xx) * 3
                px[o:o + 3] = bytes(color)


def dibujo(px, w, x0, y0, pat, col, direccion, filas, cols):
    """Un bloque de casillas de la ROM, como pinta_un_bloque_de_casillas."""
    for f in range(filas):
        for c in range(cols):
            M.dibuja_casilla(px, w, x0 + c * 8, y0 + f * 8, pat, col,
                             direccion[f * cols + c])


def hueco_libre(ocupadas, fila, col, filas, cols, ancho_mapa=32):
    """El primer sitio libre pegado al bloque: derecha, izquierda, abajo,
    arriba. Devuelve (fila, col) o None."""
    for f, c in ((fila, col + 2), (fila, col - cols), (fila + 2, col),
                 (fila - filas, col)):
        celdas = {(f + i, c + j) for i in range(filas) for j in range(cols)}
        if c < 0 or c + cols > ancho_mapa or f < 0:
            continue
        if not (celdas & ocupadas):
            ocupadas |= celdas
            return f, c
    return None


def monta_los_objetos(rom, fase, px, w, h, pat, col):
    """Pinta encima del mapa los objetos de la fase. Devuelve la lista.

    Cada bloque va con su interrogante -el dibujo de 0x6F40 que el juego
    pinta en cuanto lo tocas- en el sitio en que nace, con marco blanco si
    es visible y magenta punteado si esta escondido; y PEGADO a el, lo que
    suelta al romperse. El puente se pinta donde lo pinta 0x69C9: alrededor.
    """
    lista = []
    for t, y, x in registros(rom, fase):
        o = clasifica(rom, fase, t, y, x)
        o["tipo"] = t
        lista.append(o)
    ocupadas = set()
    for o in lista:
        if o["clase"] == 7:
            continue
        if o["clase"] == 6:
            ocupadas |= {(o["fila"] - 2 + i, o["col"] - 1 + j)
                         for i in range(4) for j in range(4)}
        else:
            ocupadas |= {(o["fila"] + i, o["col"] + j)
                         for i in range(2) for j in range(2)}
    interrogante = [rom.b(INTERROGANTE + i) for i in range(4)]
    for o in lista:
        X, Y = o["col"] * 8, o["fila"] * 8
        if o["clase"] == 7:
            # el pasadizo: una franja vertical de ocho de ancho en el borde,
            # tan alta como su caja, con una flecha hacia el lado por el que
            # se empuja
            marco(px, w, h, X, Y, 8, o["alto"], CIAN)
            ym = Y + o["alto"] // 2
            for k in range(4):
                xx = X + 4 + k if o["derecha"] else X + 3 - k
                for yy in range(ym - (3 - k), ym + (3 - k) + 1):
                    if 0 <= xx < w and 0 <= yy < h:
                        px[(yy * w + xx) * 3:(yy * w + xx) * 3 + 3] = bytes(CIAN)
            continue
        color, punteado = (BLANCO, False) if o["visible"] else (MAGENTA, True)
        if o["clase"] == 6:
            # el puente: cuatro por cuatro, dos filas arriba y una columna a
            # la izquierda, que es el (-16, -8) que suma 0x69C9; y el bloque
            # que lo suelta, encima
            bloque = [rom.b(PUENTE + i) for i in range(16)]
            dibujo(px, w, X - 8, Y - 16, pat, col, bloque, 4, 4)
            dibujo(px, w, X, Y, pat, col, interrogante, 2, 2)
            marco(px, w, h, X, Y, 16, 16, color, punteado)
            continue
        # el bloque, con su interrogante
        dibujo(px, w, X, Y, pat, col, interrogante, 2, 2)
        marco(px, w, h, X, Y, 16, 16, color, punteado)
        # y lo que suelta, pegado a el
        cols = 3 if o["clase"] == 5 else 2
        sitio = hueco_libre(ocupadas, o["fila"], o["col"], 2, cols)
        if sitio is None:
            o["sin_sitio"] = True
            continue
        f, c = sitio
        cuatro = [rom.b(DIBUJOS[o["clase"]] + i) for i in range(4)]
        dibujo(px, w, c * 8, f * 8, pat, col, cuatro, 2, 2)
        if o["clase"] == 5 and "destino" in o:
            # la fase de destino, con la cifra de la fuente, a su derecha
            M.dibuja_casilla(px, w, c * 8 + 16, f * 8 + 4, pat, col,
                             0x10 + o["destino"])
    return lista


def resumen(lista):
    """Cuantos de cada clase, y cuantos escondidos."""
    out = {}
    for o in lista:
        k = NOMBRES[o["clase"]]
        v, e = out.get(k, (0, 0))
        out[k] = (v + 1, e + (0 if o["visible"] or o["clase"] == 7 else 1))
    return out


def main():
    rom = M.Rom(sys.argv[1], int(sys.argv[2], 0))
    salida = sys.argv[3]
    fases = [int(sys.argv[4])] if len(sys.argv) > 4 else range(8)
    os.makedirs(salida, exist_ok=True)
    heredada = None
    for fase in range(8):
        pat, col = M.casillas_de_la_fase(rom, fase, heredada)
        heredada = M.vram_de_la_fase(rom, fase, heredada)
        if fase not in fases:
            continue
        filas = M.monta_la_fase(rom, fase)
        w, h = 32 * 8, len(filas) * 8
        px = bytearray(w * h * 3)
        for y, fila in enumerate(filas):
            for x, n in enumerate(fila):
                M.dibuja_casilla(px, w, x * 8, y * 8, pat, col, n)
        lista = monta_los_objetos(rom, fase, px, w, h, pat, col)
        fn = os.path.join(salida, "fase_%d_objetos.png" % (fase + 1))
        M.png(w, h, px, fn)
        r = resumen(lista)
        print("  %s  %d objetos: %s" % (fn, len(lista), ", ".join(
            "%s %d%s" % (k, v, " (%d escondidos)" % e if e else "")
            for k, (v, e) in sorted(r.items()))))
        for o in lista:
            if o["clase"] == 5:
                print("     EXIT en la fila %d, columna %d -> fase %s" % (
                    o["fila"], o["col"], o.get("destino", "?")))


if __name__ == "__main__":
    main()
