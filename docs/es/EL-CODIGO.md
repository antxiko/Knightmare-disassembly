# El codigo

15.233 bytes de codigo y 17.535 de datos. 7.509 instrucciones repartidas en 985
bloques con nombre, y ni uno por debajo del 10 % de comentario.

## Todo cuelga de la interrupcion

INIT (`0x407E`) no hace mas que preparar el terreno: conmuta el cartucho entero
en las paginas 1 y 2 con ENASLT, escribe un `jp cada_cuadro` en el gancho
H.KEYI de `0xFD9A`, borra de `0xE000` a `0xE7FF`, monta la pantalla y se mete
en un `jr $`. **El juego entero pasa dentro de la interrupcion.**

`cada_cuadro` (`0x402E`) hace en este orden: leer el VDP para bajar la peticion
de interrupcion, **el sonido primero** —para que no se le note el retraso si el
cuadro se alarga—, el cerrojo de reentrada, los mandos, el cuadro, y otra
lectura del VDP de salida.

## El repartidor

Casi todo el flujo pasa por `0x406C`:

    pop hl          ; la direccion de retorno ES la tabla
    add a,a
    call suma_a_a_hl
    ld e,(hl) / inc hl / ld d,(hl) / ex de,hl / jp (hl)

O sea que **la tabla va pegada detras del `call`**. Hay quince sitios asi, y
`tools/tablas_despacho.py` deduce el tamano de cada tabla con la regla de la
entrada mas baja. Tres no se dejaron: su primera entrada salta hacia atras a
codigo que nadie mas llama, y la regla se queda sin apoyo. Se cerraron a mano
por la primera entrada que apunta hacia delante, que es siempre el byte
siguiente a la tabla.

Hay una segunda puerta, `0x4065`, que coge el indice de `(ix+0)` y espera la
tabla ya en HL. Un solo sitio la usa, `0x75F0`, y ahi esta el **despacho de dos
niveles**: `0x75F3` es una tabla de dieciseis subtablas indexada por
`(ix+1) & 0x0F` —el tipo de enemigo— y `0x4065` indexa la subtabla con
`(ix+0)`, que es su estado.

## Las escenas

`(0xE000)` es la escena y `(0xE001)` la subescena; la tabla de `0x40EA` tiene
diez entradas:

    0  presentacion (el cartel de KONAMI bajando)
    1  titulo
    2  demostracion
    3  cuenta atras y arranque de la partida
    4  el juego            <- la escena que el Game Master vigila
    5  fase pasada
    6  se acabo una vida
    7  GAME OVER
    8  fase siguiente
    9  el final

En las escenas 0, 1 y 2, `haz_el_cuadro` empuja `0x4262` a la pila antes de
repartir, asi que al volver de la escena se ejecuta eso: mirar si se ha pulsado
algo y, si estamos en el titulo y es un disparo, arrancar la partida.

## Los descompresores

Hay dos formatos, y conviene no mezclarlos.

**El de bloques** (`0x4417`), para patrones, color y casillas:

    n con el bit 7 puesto   n bytes tal cual
    n sin el bit 7          el byte siguiente, repetido n veces
    0x80                    cambio de direccion de VRAM (dos bytes)
    0x00                    fin

Cada byte pasa ademas por `lee_y_traduce` (`0x443B`), que aplica el banco de
color de `(0xE661)`.

**El de rotulos** (`0x43F9`): una palabra con la direccion de VRAM, detras los
codigos de casilla, `0xFE` para saltar a otro sitio y `0xFF` para acabar. Los
codigos no son ASCII: son numeros de casilla de la fuente, y el alfabeto se lee
dibujando los 35 glifos que `0x45C9` descomprime.

## El motor de sonido

Es el mismo de The Goonies (RC-734), y no de oidas: `tools/porta_nombres.py`
localiza aqui sus rutinas por firma de instrucciones normalizadas con tramos de
hasta 150 bytes seguidos.

Tres voces de catorce bytes en `0xE010`, `0xE01E` y `0xE02C`. Una pieza se pide
por numero, y ese numero **es tambien su prioridad**: solo entra si pesa mas que
lo que ya suena. La tabla de `0x4B38` son 63 punteros **de voz**, no de pieza:
cada pieza gasta una, dos o tres seguidos.

Los doce semitonos estan en `0x4B2C`, y bajar de octava es doblar el periodo:
los `add hl,hl` de `0x4B0F`.

## El armazon compartido

`tools/comun_normalizado.py` da **21 tramos y 996 bytes** normalizados en comun
con The Goonies, o sea el 6,8 % de este cartucho. Lo compartido es el armazon
—el repartidor, las sumas de 16 bits, los descompresores, el espejo de sprites,
el lector de mandos— y el motor de sonido. Los otros 13,7 KB de codigo son
suyos.
