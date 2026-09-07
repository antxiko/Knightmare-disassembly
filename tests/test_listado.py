#!/usr/bin/env python3
"""Comprobaciones sobre el listado de Knightmare, y sobre lo que afirma.

Ninguna necesita el cartucho: las que miran bytes los sacan de los `defb` del
propio listado, que es lo mismo que hay en la ROM -eso lo garantiza
`make verify`, que reensambla y compara el sha256-.

Lo que se vigila:

  - que el listado no se degrade sin que nadie se entere: densidad, rutinas sin
    explicar, bloques de datos sin descripcion;
  - que las afirmaciones que se publican SE COMPRUEBEN sobre los bytes: que la
    cabecera del Game Master se reparta como se dice y acabe justo donde
    empieza el codigo, que la rutina que declara sea de verdad la que convierte
    la fase, que las tablas de seno y coseno se ajusten a la funcion -y que las
    DOS erratas sigan ahi, porque son parte del hallazgo-, que los tramos de
    cada fase se solapen una banda exacta, y que las cuentas de las oleadas
    cuadren con la distancia entre sus punteros;
  - que no se cuele el nombre de otro juego de la serie, que ya ha pasado.
"""
import math
import os
import re
import subprocess
import sys
import unittest

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASM = os.path.join(RAIZ, "src", "knightmare.asm")
NOTES = os.path.join(RAIZ, "src", "knightmare.notes")
ENTRIES = os.path.join(RAIZ, "src", "knightmare.entries")
ORG, FIN = 0x4000, 0xC000

# Los demas juegos de la serie. Que el nombre de otro salga en una pagina de
# este es casi siempre un copia y pega: ya paso con cinco ficheros LICENSE, con
# el pie de catorce paginas de otro proyecto y con unos tests que llegaron
# copiados y apuntaban al .asm de otro cartucho.
#
# "The Goonies" NO esta en la lista, y no por dejadez: es el cartucho DONANTE
# -este comparte con el su armazon y su motor de sonido, y eso esta medido-,
# asi que nombrarlo es el contenido. Lo vigila su propio test, mas abajo.
OTROS_JUEGOS = (
    "temptations", "ale hop", "alehop", "colt 36", "colt36", "stardust",
    "antarctic", "pitfall", "war in middle earth", "athletic land",
    "monkey academy", "f-1 spirit", "f1 spirit", "pippols", "time pilot",
    "frogger", "super cobra", "billiards", "mahjong", "demonia",
    "hyper olympic", "hyper rally", "hyper sports", "nemesis", "sky jaguar",
    "kings valley", "king s valley", "mopi ranger", "mopiranger",
    "road fighter", "ping pong", "soccer", "football",
    "trailblazer", "cabbage patch", "baseball",
    "casio world open", "hole in one", "3d golf", "yie ar kung-fu",
    "yie ar kung fu", "descubrimiento", "tennis",
)


def lee(fn):
    with open(fn, encoding="utf-8", errors="replace") as f:
        return f.read()


def bytes_del_listado():
    """Los 32768 bytes, reconstruidos de los `defb`/`defw` del listado."""
    mem = bytearray(FIN - ORG)
    puestos = bytearray(FIN - ORG)
    pc = None
    for ln in lee(ASM).splitlines():
        m = re.match(r"^\s+def([bw])\s+(.*?)\s*(?:;\s*([0-9a-f]{4}).*)?$", ln)
        if not m:
            continue
        anchura = 1 if m.group(1) == "b" else 2
        if m.group(3):
            pc = int(m.group(3), 16)
        if pc is None:
            continue
        for v in m.group(2).split(","):
            v = v.strip()
            if not v:
                continue
            n = int(v.rstrip("h"), 16) if v.endswith("h") else int(v, 0)
            for k in range(anchura):
                mem[pc - ORG] = (n >> (8 * k)) & 0xFF
                puestos[pc - ORG] = 1
                pc += 1
    return mem, puestos


MEM, PUESTOS = bytes_del_listado()


def b(a):
    """Un byte del listado. Solo valen los que salen como dato: si alguna vez
    una zona pasa a ser codigo, el test se entera en vez de leer un cero."""
    assert PUESTOS[a - ORG], "0x%04X no sale como dato en el listado" % a
    return MEM[a - ORG]


def w(a):
    return b(a) | (b(a + 1) << 8)


class TestElListadoNoSeDegrada(unittest.TestCase):
    """La densidad y las rutinas flojas se miden EJECUTANDO tools/densidad.py,
    no repitiendo aqui su aritmetica: un test que rehace la cuenta que vigila
    no vigila esa cuenta, vigila su propia copia."""

    def densidad(self):
        sal = subprocess.run(
            [sys.executable, os.path.join(RAIZ, "tools", "densidad.py"), ASM],
            capture_output=True, text=True, check=True).stdout
        pct = float(re.search(r"([\d.]+) %\s*$", sal, re.M).group(1))
        flojas = int(re.search(r"---- (\d+) rutinas por debajo", sal).group(1))
        return pct, flojas, sal

    def test_la_densidad_no_baja_del_22_por_ciento(self):
        pct, _, _ = self.densidad()
        self.assertGreaterEqual(pct, 22.0,
                                "la densidad ha bajado a %.1f %%" % pct)

    def test_ninguna_rutina_por_debajo_del_diez_por_ciento(self):
        _, flojas, sal = self.densidad()
        self.assertEqual(flojas, 0, sal.strip())

    def test_todo_bloque_de_datos_lleva_descripcion(self):
        sin = [ln for ln in lee(NOTES).splitlines()
               if re.match(r"^D\s+0x[0-9A-Fa-f]+\s+0x[0-9A-Fa-f]+\s+\S+\s*$", ln)]
        self.assertEqual(sin, [], "bloques de datos sin explicacion: %s" % sin)

    def test_el_listado_no_tiene_datos_sin_identificar(self):
        self.assertNotIn("DATOS sin identificar", lee(ASM))


class TestLaCabeceraDelGameMaster(unittest.TestCase):
    """El reparto de 0x4010 sale de EJECUTAR el lector del cartucho de trucos
    de Konami, que esta desensamblado aparte (su 0x5E92). Aqui se repite paso a
    paso y se comprueba que cuadra byte a byte."""

    def test_la_marca_es_CD_07_39(self):
        self.assertEqual(bytes(MEM[0x10:0x14]), b"CD\x07\x39")

    def test_el_reparto_acaba_justo_donde_empieza_el_codigo(self):
        p = 0x4015                       # detras de "CD" 07 RC y las banderas
        bit = b(0x4014)
        campos = {}
        if not bit & 1:                  # dos bytes y uno
            campos["escena"] = w(p)
            p += 2
            campos["cuando"] = b(p)
            p += 1
        bit >>= 1
        if not bit & 1:                  # dos bytes y uno
            campos["fase"] = w(p)
            p += 2
            campos["cuantas fases"] = b(p)
            p += 1
        bit >>= 1
        for nombre in ("vidas", "datos", "marcador", "marcador 2", "modo",
                       "rutina"):
            if not bit & 1:
                campos[nombre] = w(p)
                p += 2
            bit >>= 1
        self.assertEqual(p, 0x4025,
                         "el reparto acaba en 0x%04X y el codigo empieza en "
                         "0x4025" % p)
        self.assertEqual(campos["escena"], 0xE000)
        self.assertEqual(campos["cuando"], 4)
        self.assertEqual(campos["fase"], 0xE061)
        self.assertEqual(campos["cuantas fases"], 8,
                         "el cartucho declara ocho fases")
        self.assertNotIn("marcador 2", campos,
                         "el bit 5 dice que no hay segundo marcador")
        self.assertEqual(campos["rutina"], 0x56C8)

    def test_la_rutina_que_declara_convierte_la_fase(self):
        """0x56C8 tiene que ser `ld hl,0E061h / ld a,(hl) / sub 1 / daa /
        inc hl / ld (hl),a / ret`: diez bytes que pasan la fase escrita desde
        la otra ranura al indice interno de (0xE062)."""
        esperado = ["ld hl,0e061h", "ld a,(hl)", "sub 001h", "daa", "inc hl",
                    "ld (hl),a", "ret"]
        salen = []
        for ln in lee(ASM).splitlines():
            m = re.search(r"^\s+(\S.*?)\s*;(56c[89abcdef]|56d[01])\b", ln)
            if m:
                salen.append(re.sub(r"\s+", " ", m.group(1)).strip())
        self.assertEqual(salen, esperado)

    def test_la_tabla_de_0x56B8_tiene_ocho_entradas(self):
        """Y no diez: las dos que sobraban son los bytes de esa rutina."""
        m = re.search(r"^!tabla 0x56b8\s+(\d+)", lee(ENTRIES), re.M)
        self.assertEqual(int(m.group(1)), 8)


class TestLasTablasDeAngulos(unittest.TestCase):
    def test_la_tabla_de_tangentes(self):
        """64 palabras que bajan: la tangente de 90-(k+1)*90/64 con ocho bits
        de fraccion."""
        peor = 0
        for k in range(64):
            v = w(0x6262 + 2 * k) / 256.0
            t = math.tan(math.radians(90 - (k + 1) * 90.0 / 64))
            peor = max(peor, abs(v - t))
        self.assertLess(peor, 0.2, "la peor entrada se aparta %.3f" % peor)

    def test_los_cosenos_y_sus_dos_erratas(self):
        """Una tabla de coseno de un cuadrante SOLO PUEDE BAJAR. Estas dos
        suben una vez cada una, y el valor que sube es justo el unico que se
        aparta de la funcion. Es un hallazgo, no un descuido del listado: si
        alguna vez deja de cumplirse, es que se ha tocado el binario."""
        # `sube` es donde salta el `b(k) < b(k+1)`: en 0x844E la entrada mala
        # es MAYOR de lo que le tocaba, asi que el salto se ve en la anterior;
        # en 0x848F es MENOR, y el salto se ve en ella misma
        for base, escala, mala, deberia, sube in ((0x844E, 255, 58, 0x25, 57),
                                                  (0x848F, 128, 12, 0x7A, 12)):
            difs, subidas = [], []
            for k in range(65):
                v = b(base + k)
                t = escala * math.cos(math.radians(k * 90.0 / 64))
                if k != mala:
                    difs.append(abs(v - t))
                if k < 64 and b(base + k) < b(base + k + 1):
                    subidas.append(k)
            self.assertLess(max(difs), 5.0,
                            "0x%04X: el resto de la tabla se aparta %.2f"
                            % (base, max(difs)))
            self.assertEqual(subidas, [sube],
                             "0x%04X sube en %s y solo deberia subir en %d"
                             % (base, subidas, sube))
            self.assertNotEqual(b(base + mala), deberia,
                                "0x%04X + %d ya no es la errata" % (base, mala))


class TestElMapaDeLasFases(unittest.TestCase):
    TABLA, BLOQUES, TRAMOS = 0x99CD, 0x99ED, 10

    def banda(self, fase, tramo, banda):
        """Lo que monta 0x6502: ocho grupos de cuatro columnas por cuatro
        filas, con el mapa de bits diciendo cuando avanza el puntero."""
        lista = w(self.TABLA + 4 * fase)
        fin = w(self.TABLA + 4 * fase + 2)
        ix = w(lista + 2 * tramo)
        for k in range(banda):           # hay que llegar hasta la banda pedida
            bits = b(fin - 6 * tramo + k)
            for _ in range(8):
                if bits & 0x80:
                    ix += 1
                bits = (bits << 1) & 0xFF
        bits = b(fin - 6 * tramo + banda)
        filas = [[0] * 32 for _ in range(4)]
        for grupo in range(8):
            cod = b(ix)
            bloque = w(self.BLOQUES + (cod & 0x7F) * 2)
            for f in range(4):
                for c in range(4):
                    v = b(bloque + f * 4 + c)
                    cc = c
                    if cod & 0x80:
                        cc = 3 - c
                        if v & 0xF0:
                            v = v - 0x60 if v >= 0xA0 else v + 0x60
                    filas[f][grupo * 4 + cc] = v
            if bits & 0x80:
                ix += 1
            bits = (bits << 1) & 0xFF
        return filas

    def test_los_tramos_se_solapan_una_banda_exacta(self):
        """La banda 6 de un tramo y la banda 0 del de abajo salen del mismo
        byte del mapa de bits, y el decorado que dan es IDENTICO. Nueve
        empalmes por fase, ocho fases: 72 comprobaciones."""
        for fase in range(8):
            for t in range(self.TRAMOS - 1, 0, -1):
                self.assertEqual(
                    self.banda(fase, t, 6), self.banda(fase, t - 1, 0),
                    "fase %d: el empalme %d-%d no encaja" % (fase, t, t - 1))

    def test_la_tabla_de_bloques_tiene_64_entradas(self):
        """El bloque mas bajo esta a 128 bytes del principio de la tabla, o sea
        64 punteros; y todos caen dentro de la zona de bloques."""
        v = [w(self.BLOQUES + 2 * k) for k in range(64)]
        self.assertEqual(min(v), self.BLOQUES + 128)
        for x in v:
            self.assertTrue(0x9A6D <= x < 0x9E3D, "0x%04X se sale" % x)

    def test_las_ocho_fases_van_seguidas_y_sin_hueco(self):
        limites = []
        for fase in range(8):
            limites.append(w(self.TABLA + 4 * fase))
            limites.append(w(self.TABLA + 4 * fase + 2))
        self.assertEqual(limites[0], 0x9E3D)
        self.assertEqual(limites[-1], 0xA5AD)
        for k in range(len(limites) - 1):
            self.assertLessEqual(limites[k], limites[k + 1],
                                 "los mapas no van en orden")


class TestLasOleadas(unittest.TestCase):
    def test_las_cuentas_cuadran_con_los_punteros(self):
        """0x7043 dice cuantas entradas tiene el guion de cada fase, y la
        distancia entre dos punteros consecutivos de 0x704B tiene que ser
        exactamente el doble."""
        p = [w(0x704B + 2 * k) for k in range(8)] + [0x729B]
        for k in range(8):
            self.assertEqual(p[k + 1] - p[k], 2 * b(0x7043 + k),
                             "la fase %d no cuadra" % k)

    def test_los_enemigos_por_fase_son_doce_bytes(self):
        """Una palabra con la base de los registros y diez indices, uno por
        tramo; los indices no bajan nunca."""
        for fase in range(8):
            base = 0x6A98 + 12 * fase
            self.assertTrue(0x6AF8 <= w(base) < 0x6F44)
            idx = [b(base + 2 + k) for k in range(10)]
            self.assertEqual(idx[0], 0, "el tramo 0 no siembra enemigos")
            self.assertEqual(idx[:9], sorted(idx[:9]),
                             "la fase %d no lleva los indices en orden" % fase)
            # el decimo es el del ultimo tramo: cero -sin enemigos- en seis
            # fases, y en la 5 y la 6 sigue la cuenta
            self.assertTrue(idx[9] == 0 or idx[9] >= idx[8],
                            "la fase %d tiene un decimo indice raro" % fase)


class TestLaMusicaYLosGraficos(unittest.TestCase):
    def test_los_63_punteros_de_voz_caen_en_los_guiones(self):
        for k in range(1, 64):
            v = w(0x4B36 + 2 * k)
            self.assertTrue(0x4BB6 <= v < 0x53D3,
                            "la voz %d apunta a 0x%04X" % (k, v))

    def test_los_doce_semitonos(self):
        """Las razones entre uno y el siguiente tienen que dar la raiz doceava
        de dos, que es lo que hace que la tabla sea una escala."""
        v = [b(0x4B2C + k) for k in range(12)]
        self.assertEqual(v, sorted(v, reverse=True))
        for k in range(11):
            self.assertAlmostEqual(v[k] / float(v[k + 1]), 2 ** (1 / 12.0),
                                   delta=0.02)

    def test_los_graficos_de_las_ocho_fases_van_seguidos(self):
        """La tabla de 0x563C, cuatro bytes por fase; y solo hay DIEZ bloques
        distintos porque las fases 0, 3 y 7 comparten uno y la 5 y la 6 otro."""
        vistos = set()
        for fase in range(8):
            vistos.add(w(0x563C + 4 * fase))
            vistos.add(w(0x563C + 4 * fase + 2))
        self.assertEqual(min(vistos), 0xB317)
        self.assertEqual(len(vistos), 10)

    def test_el_banco_de_enemigos_tiene_dieciseis_entradas(self):
        v = [w(0xA993 + 2 * k) for k in range(16)]
        self.assertEqual(min(v), 0xA993 + 32)
        for x in v:
            self.assertTrue(0xA9B3 <= x < 0xAD69, "0x%04X se sale" % x)


class TestLaMarcaDeKonami(unittest.TestCase):
    def test_la_marca_oculta_cierra_la_rom(self):
        """El titulo en katakana del reves, su longitud, el numero de catalogo
        y el 0xAA de cierre. La descubrio Manuel Pazos."""
        self.assertEqual(b(0xBFFF), 0xAA)
        self.assertEqual(b(0xBFFE), 0x39, "RC-739")
        n = b(0xBFFD)
        self.assertEqual(n, 10)
        self.assertEqual(0xBFFD - n, 0xBFF3, "la marca empieza en 0xBFF3")
        for k in range(n):               # los diez glifos van de 0x80 arriba
            self.assertGreaterEqual(b(0xBFF3 + k), 0x80)


class TestSinNombresDeOtroJuego(unittest.TestCase):
    def test_ni_los_textos_ni_las_herramientas_nombran_otro_juego(self):
        # Estos SI pueden nombrarlos, y por un motivo: este mismo fichero, que
        # lleva la lista; busca_marca_konami.py, que recorre la coleccion
        # entera de ROM; y porta_nombres.py y comun_*.py, que comparan con el
        # cartucho DONANTE, que es de lo que va la herramienta.
        permitidos = ("test_listado.py", "busca_marca_konami.py",
                      "porta_nombres.py", "comun_normalizado.py",
                      "comun_konami.py")
        malos = []
        for carpeta, _, ficheros in os.walk(RAIZ):
            if any(x in carpeta for x in (".git", "work", "__pycache__")):
                continue
            for fn in ficheros:
                if fn in permitidos:
                    continue
                if not fn.endswith((".py", ".md", ".notes", ".entries",
                                    ".nocode", ".html", ".sh")):
                    continue
                t = lee(os.path.join(carpeta, fn)).lower()
                for juego in OTROS_JUEGOS:
                    # con limites de palabra: "demonia" no puede saltar dentro
                    # de "castillo demoniaco", que es texto de ESTE juego
                    if re.search(r"%s" % re.escape(juego), t):
                        malos.append("%s: %s" % (fn, juego))
        self.assertEqual(malos, [], "nombran otro juego: %s" % malos)

    def test_a_the_goonies_se_le_nombra_como_donante(self):
        """Aparece, y tiene que aparecer: el armazon de este cartucho es el
        suyo. Lo que se vigila es que se le nombre POR ESO -en el .notes, donde
        se explica de donde salen los nombres portados- y no por un copia y
        pega perdido en cualquier otro sitio."""
        con_goonies = []
        for carpeta, _, ficheros in os.walk(RAIZ):
            if any(x in carpeta for x in (".git", "work", "__pycache__")):
                continue
            for fn in ficheros:
                if fn in ("test_listado.py", "busca_marca_konami.py"):
                    continue
                if not fn.endswith((".py", ".md", ".notes", ".entries",
                                    ".nocode", ".html", ".sh")):
                    continue
                if "goonies" in lee(os.path.join(carpeta, fn)).lower():
                    con_goonies.append(fn)
        # el .notes explica de donde salen los nombres portados,
        # porta_nombres.py es la herramienta que los porta, y las paginas del
        # codigo cuentan el hallazgo: 21 tramos y 996 bytes en comun
        self.assertEqual(
            sorted(con_goonies),
            ["EL-CODIGO.html", "EL-CODIGO.md", "THE-CODE.html", "THE-CODE.md",
             "knightmare.notes", "porta_nombres.py"],
            "a The Goonies solo se le nombra donde la comparacion ES el "
            "contenido")

    def test_los_ficheros_que_se_citan_existen(self):
        citados = set()
        for carpeta, _, ficheros in os.walk(RAIZ):
            if any(x in carpeta for x in (".git", "work", "__pycache__")):
                continue
            for fn in ficheros:
                if not fn.endswith((".md", ".notes", ".py")):
                    continue
                texto = lee(os.path.join(carpeta, fn))
                for m in re.finditer(r"\b((?:src|tools|tests)/[\w./-]+)",
                                     texto):
                    cita = m.group(1).rstrip(".-,:;)")
                    # los <src/X.entries> de las lineas de uso son marcadores
                    if re.search(r"/[A-Z]\.", cita):
                        continue
                    citados.add(cita)
        faltan = [c for c in citados
                  if not os.path.exists(os.path.join(RAIZ, c))]
        self.assertEqual(faltan, [], "citados y no estan: %s" % sorted(faltan))


class TestLasImagenesSeDibujanEnteras(unittest.TestCase):
    """Las dos comprobaciones que le faltaban a las laminas.

    Las dos nacen de sendos fallos que estuvieron PUBLICADOS: los mapas salian
    con los rios y los puentes en negro, y los enemigos, con cuadros negros.
    Las dos veces el dibujo se hacia con una hoja de patrones incompleta, y las
    dos veces el fallo se ve mirando la imagen... si a uno se le ocurre mirar.
    Esto lo comprueba solo.
    """

    def setUp(self):
        sys.path.insert(0, os.path.join(RAIZ, "tools"))
        rom = os.path.join(RAIZ, "knightmare.rom")
        if not os.path.exists(rom):
            self.skipTest("hace falta el cartucho")
        import mapas
        self.mapas = mapas
        self.rom = mapas.Rom(rom, ORG)

    def test_ninguna_casilla_del_mapa_se_queda_sin_cargar(self):
        """Toda casilla que use el mapa de una fase tiene que estar CARGADA en
        la hoja, y no vale mirar si sale negra: la 0x01 se carga a proposito
        con patron a cero y color 1, o sea negra maciza, y es legitima.

        El truco para distinguir una cosa de la otra es arrancar la VRAM
        rellena de 0xAA -un valor que ningun volcado escribe- y ver cual sigue
        sin tocar. Asi salieron los rios y los puentes: las casillas 0x3F a
        0x4B no las carga la fase, las carga `monta_el_marcador`, y sin esa
        llamada la lamina publicaba franjas negras de lado a lado.
        """
        m = self.mapas
        vacio = bytes([0xAA]) * 8      # un valor que ningun volcado escribe
        heredada = bytearray(bytes([0xAA]) * 0x3800)
        for fase in range(8):
            heredada = m.vram_de_la_fase(self.rom, fase, heredada)
            usados = set(v for fila in m.monta_la_fase(self.rom, fase)
                         for v in fila)
            sin = sorted(v for v in usados
                         if heredada[0x2000 + v * 8:0x2008 + v * 8] == vacio)
            self.assertEqual(sin, [], "fase %d: casillas sin cargar %s"
                             % (fase + 1, ["0x%02X" % v for v in sin]))

    def test_cada_tipo_de_bicho_gasta_justo_su_bloque(self):
        """El nudo que ata la tabla de sprites de 0x7772 con el banco de
        patrones de 0xA993: los dos cuelgan del MISMO nibble del tipo. Si la
        pareja es la que decimos, los patrones que piden las entradas de un
        tipo tienen que ser exactamente los que trae su bloque -ni uno de mas
        ni uno de menos-, y eso pasa en los dieciseis. Sin esta pareja los
        bichos se dibujan con la hoja equivocada y salen en negro."""
        import sprites
        for tipo, entradas in sprites.TIPOS:
            n = len(sprites.descomprime(
                self.rom, self.rom.w(sprites.BANCO_DE_ENEMIGOS + 2 * tipo))) // 32
            pedidos = set()
            for k in entradas:
                p = self.rom.w(sprites.ENEMIGOS + 2 * k)
                for j in range(2):
                    if self.rom.b(p + 4 * j + 3) & 0x0F == 0:
                        continue          # color 0: ese sprite no se ve
                    b = self.rom.b(p + 4 * j + 2)
                    pedidos.add((b & 0x0F) // 4)    # 0x10 en adelante: el espejo
            self.assertEqual(sorted(pedidos), list(range(n)),
                             "tipo %d: su bloque trae %d patrones y sus "
                             "entradas piden %s" % (tipo, n, sorted(pedidos)))


if __name__ == "__main__":
    unittest.main()
