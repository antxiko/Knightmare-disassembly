# El juego

*Knightmare* —en Japon *Majou Densetsu*, «la leyenda del castillo demoniaco»—
es un matamarcianos vertical con armadura. Popolon sube por ocho fases
matando bichos para rescatar a Aphrodite, y el cartucho lo resuelve con un
motor de decorado por bandas y tres ranuras de sprites que se van recargando.

![El titulo](../imagenes/titulo.png)

*La pantalla del titulo, montada ejecutando los pasos de `monta_el_titulo`
(0x47BA). El rotulo grande son 33 casillas —once por tres— que un bucle escribe
seguidas desde la 0x60.*

## Las ocho fases, enteras

Cada fase es una tira vertical de **61 bandas de cuatro filas**, o sea 244
filas de casillas. No esta guardada como un mapa: se monta bloque a bloque.

Aqui estan **las ocho**, de arriba abajo y a tamano real: 256 x 1952 pixeles
cada una. Salen de los codigos de bloque de cada fase y de los bloques de 4x4
casillas de `0x9A6D`; ni una es una captura de pantalla.

| | | | |
|:-:|:-:|:-:|:-:|
| ![La fase 1](../imagenes/fase_1.png) | ![La fase 2](../imagenes/fase_2.png) | ![La fase 3](../imagenes/fase_3.png) | ![La fase 4](../imagenes/fase_4.png) |
| **Fase 1** | **Fase 2** | **Fase 3** | **Fase 4** |
| ![La fase 5](../imagenes/fase_5.png) | ![La fase 6](../imagenes/fase_6.png) | ![La fase 7](../imagenes/fase_7.png) | ![La fase 8](../imagenes/fase_8.png) |
| **Fase 5** | **Fase 6** | **Fase 7** | **Fase 8** |

Se leen de abajo arriba, que es como se juegan: Popolon entra por el borde de
abajo y sube. La banda de arriba del todo es la puerta del jefe.

El montador es `0x6502` y trabaja asi:

- La fase se parte en **diez tramos**, y cada tramo en **siete bandas** de
  cuatro filas.
- Cada banda son **ocho grupos de cuatro columnas**. De cada grupo sale un
  codigo de bloque: los siete bits bajos indexan la tabla de `0x99ED` —64
  punteros a bloques de 4x4 casillas— y **el bit 7 dice que el bloque va
  espejado**.
- Detras de cada grupo, un `rl` saca un bit de un mapa de bits: con el bit
  puesto el puntero avanza al bloque siguiente, y con el a cero **se repite el
  bloque anterior**. Ahi esta la compresion del decorado.

Y los bloques **se solapan entre si**: `0x9C21` y `0x9C3E` caen a medio bloque
de otro, asi que un mismo tramo de bytes sirve de dos bloques distintos.

## Los rios y los puentes no son de la fase

La hoja de casillas de una fase **no la carga sola la fase**. Antes de montarla,
`monta_el_marcador` (`0x565C`) sube otro bloque de 41 casillas —de la `0x27` a
la `0x4F`— y su copia espejada en la `0x87`. Ese bloque no es solo el rotulo de
abajo: ahi estan **los rios y los puentes**, que son iguales en las ocho fases,
y por eso el mapa de cualquiera de ellas los usa sin traerlos.

El orden importa: primero el marcador y **encima** las casillas de la fase, que
pisan de la `0x87` a la `0x9F` la copia espejada de aquel. Montar la hoja solo
con las casillas de la fase deja los puentes y los rios en negro.

## Tres decorados de un solo guion de color

La fase 4 usa las MISMAS casillas que la 1. Lo que cambia es la paleta.
Las fases 0, 3 y 7 comparten el guion de patrones **y** el de color. Lo que las
distingue es `(0xE661)`: el lector de bloques (`0x443B`) traduce cinco codigos
de color —0xE1, 0xEC, 0xE8, 0xE6 y 0xE5— restandoles 0x50, y otros 0x50 mas si
el banco es el 2. Un bloque de 640 bytes da los tres decorados.

Las fases 5 y 6 van mas lejos: comparten casillas y color, y **solo se
diferencian en el mapa**.

## Popolon son tres sprites

![Los fotogramas del muneco](../imagenes/jugador.png)

*Los doce fotogramas. Los cuatro ultimos son la explosion.*

El muneco se pinta con **tres sprites de 16x16** superpuestos: `0x5E2D` los
escribe con los patrones 0, 1 y 2. Los dos primeros los sube el fotograma —cada
uno ocupa **64 bytes justos**, o sea dos patrones— y el tercero es el primero
del banco fijo de la fase. La `y` de cada uno y su color salen de un bloque de
seis bytes: tres parejas `[ajuste de y][color]`.

Hay siete animaciones en la tabla de `0xA5B4`, y una de ellas —la 2— alterna
sus colores con los de `0xA5EF` para hacer el parpadeo de invulnerable.

## El bestiario no cabe entero

![El banco de enemigos](../imagenes/banco_de_enemigos.png)

*Los dieciseis tipos de bicho, uno por bloque de `0xA993`, con el color que les
pone la tabla de `0x7772`.*

La hoja de sprites del MSX son 64 patrones de 16x16 y no llegan, asi que el
cartucho tiene **tres ranuras** —VRAM `0x1D00`, `0x1E00` y `0x1F00`— que va
recargando por turno: `0x78F9` descomprime cuatro patrones en la que toque y se
lleva ademas el numero de patron base, que luego se le suma a cada sprite del
bicho.

Cada enemigo se pinta con **dos sprites**, y el par sale de la tabla de
`0x7772`: 38 bloques de ocho bytes con dos entradas `[dy][dx][patron][color]`.
De la entrada 5 en adelante el byte de patron es **relativo** —`0x7755` compara
con 5 y solo entonces le suma `(ix+0x16)`—, asi que un bicho no se puede dibujar
sin saber en que ranura esta cargado.

Y se puede saber, porque el tipo manda las dos cosas: `(iy+0) & 0x0F` es lo que
`0x7914` usa para elegir el bloque de `0xA993`, y es tambien lo que `0x75E5`
usa para elegir la subtabla de `0x75F3` cuyas rutinas escriben `(ix+0x0A)`, que
es la entrada de `0x7772`. Atando esas dos puntas **cuadra solo**: los patrones
que piden las entradas de cada tipo son exactamente los que trae su bloque, ni
uno de mas ni uno de menos, en los dieciseis.

![Los enemigos](../imagenes/enemigos.png)

*Los 42 fotogramas de la tabla de `0x7772`, cada uno con el bloque de su tipo
cargado en la ranura. El fondo es gris a proposito: la mayoria de los bichos
son siluetas de color 1, o sea NEGRAS.*

De los dos sprites de un bicho gana el **primero**: `0x772A` los escribe en
atributos seguidos, y en el TMS9918 el plano de numero mas bajo tapa al otro.
Pintados al reves, el relleno macizo se come la silueta.

![Las armas](../imagenes/armas.png)

*Las siete armas de la tabla de `0x63FB`, pareja `[patron][color]`. Solo las dos
ultimas se animan: `0x636D` les saca cuatro fotogramas con un `and 003h`.*

![Las armas y los objetos](../imagenes/sprites_fase.png)

*Los 37 patrones fijos que `0x54BE` sube al empezar cada fase: las armas, los
disparos y los objetos. Iguales en las ocho fases.*

## El marcador y el reloj del jefe

![La primera pantalla de la fase 1](../imagenes/pantalla_fase1.png)

*Tal como sale del emulador: el cotejo byte a byte da cero diferencias.*

SCORE, HISCORE, REST y STAGE van abajo, en la fila 22, y sus cifras en la 23.
La puntuacion son tres bytes en BCD desde `0xE056` y el record otros tres desde
`0xE053`; cuando el byte alto pasa del umbral de `(0xE063)`, `0x4305` regala
una vida y sube el umbral 0x10 —diez mil puntos— para la siguiente.

En la pantalla del jefe el marcador de vueltas se cambia por un **reloj en
BCD** que baja segundo a segundo: al llegar a cuatro minutos cambia la musica,
y al llegar a cero se acabo.
