# Hallazgos

Lo que aparecio al desmontarlo. Cada uno con la medida al lado.

## Konami dejo dos erratas en sus tablas de coseno

El cartucho lleva dos cuadrantes de coseno —uno escalado a 255 en `0x844E` y
otro a 128 en `0x848F`, 65 entradas cada uno— y con ellos `0x83E1` saca el seno
y el coseno de un angulo de 0 a 255, leyendo hacia delante para el coseno y
entrando por `0x40 - k` para el seno.

Un cuadrante de coseno **solo puede bajar**. Estos dos suben una vez cada uno:

| tabla | entrada | vale | le tocaba | la de al lado |
|---|---|---|---|---|
| `0x844E` | 58 | `0x2F` | `0x25` (37,4) | la 57 vale `0x2B`, **menor** |
| `0x848F` | 12 | `0x74` | `0x7A` (122,5) | la 13 vale `0x79`, **mayor** |

Y el valor que sube es justo el unico que se aparta de la funcion: quitando
esas dos entradas, las otras 64 de cada tabla se ajustan al coseno con una
desviacion **media de 0,48 y 1,73** y **maxima de 4,03 y 3,78**.

Son dos erratas de los datos, no del desensamblado: los bytes son los que son.
Lo que hacen es un tiron en el recorrido de lo que apunte justo a esos dos
angulos. Un test las vigila.

### Y Twin Bee arreglo una de ellas

La tabla de 255 de `0x844E` es **la misma tabla** que Twin Bee (RC-740) lleva
en `0xB950`, un numero de catalogo mas adelante. De los 65 bytes solo se
diferencian **tres**, y esos tres son justo los que aqui estaban mal:

| k | Knightmare | Twin Bee | 255·cos(k·90/64) |
|---|---|---|---|
| 56 | 46 | 48 | 50 |
| 58 | 47 | 37 | 37 |
| 64 | 1 | 0 | 0 |

Twin Bee pone 37 en k=58 -que es lo que pide la funcion, y lo que evita que la
tabla suba- y devuelve cos(90) a cero. Lo que **no** arregla es la entrada 46,
que vale 105 donde tocaria 109 en los dos cartuchos: esa no rompe la
monotonia, y por eso, se supone, nadie la vio.

La tabla de 128 de `0x848F` no esta en Twin Bee.

## Un truco que pide izquierda y derecha a la vez

`0x6F44` se llama **una sola vez**, desde `0x4182`, justo despues de poner la
partida a cero. Lo primero que pide es que `(0xE009)` valga `0x2C` en sus seis
bits bajos: los bits 2, 3 y 5, o sea **izquierda y derecha a la vez** mas el
segundo boton. Un joystick no puede hacer eso; un teclado si.

Con eso puesto, mira tres filas del teclado. Con la matriz estandar del MSX
—fila 3 = C D E F G H I J, fila 4 = K L M N O P Q R, fila 5 = S T U V W X Y Z—
los bits que comprueba son la **I**, la **N** y la **Y**:

    'I'  ->  (0xE069) = 1        el arma
    'N'  ->  (0xE060) = 0x26     VEINTISEIS VIDAS
    'Y'  ->  (0xE069) = 0x10     otra arma

Falta grabarlo en el emulador: esto es lectura del codigo.

## La cabecera del Game Master declara una rutina del propio cartucho

La segunda cabecera de `0x4010` —`"CD" 07 39`— la lee el Konami Game Master
desde la otra ranura. Su reparto no se ha adivinado: se ha **ejecutado a mano**
el lector del propio Game Master, que esta desensamblado. Y cuadra byte a byte:
los veintiun bytes acaban en `0x4024`, justo antes de donde vuelve a haber
codigo.

Declara la variable de escena, las vidas, el record, la puntuacion, que **no
hay marcador de segundo jugador**, **ocho fases**, y una direccion mas:
`0x56C8`. Esa direccion es una rutina de **este** cartucho a la que no llama
nadie de dentro, y son diez bytes:

    ld hl,0E061h / ld a,(hl) / sub 1 / daa / inc hl / ld (hl),a / ret

O sea: coger la fase que el Game Master acaba de escribir en `(0xE061)` y
pasarla al indice interno de `(0xE062)`.

Esos diez bytes estaban ademas escondidos: el detector de tablas de reparto
daba diez entradas a la tabla de `0x56B8` y son **ocho**. Las dos que sobraban
eran los bytes `21 61 E0 7E` de ese `ld hl,0E061h`, leidos como si fueran
punteros.

## Los tramos de cada fase se solapan una banda exacta

El mapa de bits que dice cuando avanza el puntero de bloques esta en
`(0xE095) - 6*tramo`, o sea que va **seis bytes** por tramo. Pero se leen
**siete**, uno por banda. La ultima banda de un tramo y la primera del
siguiente salen del mismo byte.

Y no solo del mismo byte: el decorado que dan es **identico**. Comprobado en
los nueve empalmes de cada una de las ocho fases —72 comprobaciones— y todos
encajan.

## Tres paletas de un solo guion de color

Las fases 0, 3 y 7 comparten guion de patrones **y** guion de color. Lo que las
distingue es `(0xE661)`: el lector de bloques (`0x443B`) traduce cinco codigos
de color —`0xE1`, `0xEC`, `0xE8`, `0xE6` y `0xE5`— restandoles `0x50`, y otros
`0x50` mas si el banco es el 2. `0x5514` pone el banco a 1 en la fase 3 y a 2
en la 7.

Un bloque de 640 bytes, tres decorados. Y las fases 5 y 6 comparten casillas
**y** color: solo se diferencian en el mapa.

## La demostracion es una partida grabada

`0x5A73` lleva la cuenta en `(0xE00C)`: cada **ocho cuadros** sube `(0xE00B)` y
con el indexa `0x5A95`. El byte que sale no es un dato de dibujo; se lo pasa a
`guarda_lo_recien_pulsado`, que es la misma puerta por la que entra el mando.

Son **118 pulsaciones**, unos diecinueve segundos a 50 Hz. El `cp 0xFF` de
`0x5A87` la cerraria, pero dentro del bloque **no hay ni un 0xFF**: la
demostracion se corta por `(0xE064)`.

## Los bloques del decorado se solapan entre si

La tabla de `0x99ED` son 64 punteros a bloques de 4x4 casillas, dieciseis bytes
cada uno. Pero los bloques no van en fila: `0x9C21` y `0x9C3E` caen **a medio
bloque** de otro, asi que un mismo tramo de bytes hace de dos bloques distintos
segun por donde se entre.

## Las oleadas cuadran solas

`0x7043` dice cuantas entradas tiene el guion de oleadas de cada fase —34, 41,
41, 38, 36, 33, 30 y 35— y la distancia entre dos punteros consecutivos de
`0x704B` es **exactamente el doble**. Las ocho, sin sobrar ni faltar un byte.

## La maquina no cambia nada

El cartucho lee de todo lo que hay por debajo de `0x4000` **una sola
direccion**: `0x0007`, el puerto de datos del VDP. Nunca toca `0x002B`,
`0x002C` ni `0x002D`, que son los bytes de la BIOS que dicen el juego de
caracteres y si la maquina va a 50 o a 60 Hz. Volcada la VRAM del titulo en una
maquina internacional y en una japonesa: **0 bytes distintos de 16.384**.
