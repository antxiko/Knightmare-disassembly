# El cartucho

**Knightmare**, Konami RC-739, 1986. Son 32.768 bytes que se ven en las
**paginas 1 y 2** del MSX, o sea de `0x4000` a `0xBFFF`.

    sha256  6e7a8a2d2fadc078ec9043deee804cfa5efcf2eb64f2fb6291a5161776220cf6

## Las dos cabeceras

En `0x4000` va la de siempre: `"AB"`, la direccion de INIT (`0x407E`) y
STATEMENT, DEVICE y TEXT a cero.

Y en `0x4010` va **una segunda**, que este cartucho no lee: la lee el **Konami
Game Master**, el cartucho de trucos de la casa, desde la otra ranura. Son
`"CD" 07 39`, o sea el `0x07` de los RC-7xx y el `0x39` de RC-739. El `"CD"` es
el marcador de los cartuchos de 1986-87; los de 1985 llevan `"AB"`.

Detras van veintiun bytes que se reparten con un byte de banderas —cada bit a
cero quiere decir que el campo viene—, y el reparto **cuadra byte a byte**:
acaba en `0x4024`, justo antes de donde vuelve a haber codigo. Con banderas
`0x20` sale esto:

| campo | vale | que es |
|---|---|---|
| escena | `0xE000` | la variable de escena |
| cuando | `4` | la escena en la que se aplican los trucos |
| fase | `0xE061` | la fase, en BCD |
| cuantas | `8` | **ocho fases** |
| vidas | `0xE060` | |
| datos | `0xE053` | el record |
| marcador | `0xE056` | la puntuacion |
| — | — | *no hay marcador de segundo jugador* |
| modo | `0xE002` | los bits de modo |
| rutina | `0x56C8` | **una rutina de este cartucho** |

Esa ultima es lo interesante: `0x56C8` son diez bytes a los que **no llama
nadie de dentro**. Lo que hacen es pasar la fase que el Game Master escribe en
`(0xE061)` al indice interno de `(0xE062)`, restandole uno en BCD.

## El VDP, al reves de lo corriente

La tabla de registros esta en `0x44C5`, ocho bytes de R0 a R7:

    02 E2 0E 7F 07 76 03 E4

R3 y R4 **no son direcciones, son base y mascara**, y aqui dan la vuelta a la
geometria de siempre:

| tabla | donde | tamano |
|---|---|---|
| color | `0x0000` | tres bancos de `0x800` |
| patrones de sprite | `0x1800` | 64 de 32 bytes |
| patrones | `0x2000` | tres bancos de `0x800` |
| nombres | `0x3800` | 768 casillas |
| atributos de sprite | `0x3B00` | 32 de cuatro bytes |

O sea que el color esta donde uno espera los patrones y al reves. Un `ld
hl,00008h` en este cartucho **no apunta a patrones**.

El registro 7 de la tabla dice `0xE4` —fondo azul oscuro—, pero eso solo vale
hasta que empieza el juego: el cartucho lo cambia a `0xE0` con
`pon_registro_7`, y el nibble bajo pasa a 0, que es **negro**.

## El mapa de memoria

    0xE000  escena          0xE001  subescena       0xE002  bits de modo
    0xE003  contador de cuadros                     0xE004  espera
    0xE009  lo que hay pulsado
    0xE010  0xE01E  0xE02C  las tres voces del PSG, catorce bytes cada una
    0xE053  record (3 en BCD)                       0xE056  puntuacion (3)
    0xE060  vidas           0xE061  fase en BCD     0xE062  fase interna (0-7)
    0xE063  umbral de la vida extra
    0xE088  el mapa de bits del tramo               0xE091  filas subidas
    0xE092  tramo (0-9)     0xE093  lista de tramos 0xE095  fin del mapa de bits
    0xE0A0  los dos generadores de oleadas, 0x10 cada uno
    0xE100  los siete enemigos, 0x20 cada uno
    0xE200  los ocho disparos del enemigo, 0x10 cada uno
    0xE320  la sombra de la tabla de atributos de sprite
    0xE3D0  el jefe
    0xE4F0  los ocho bichos sembrados por la fase, 0x10 cada uno
    0xE600  el muneco       0xE620  las cuatro ranuras de disparo
    0xE820  el buffer de casillas: 28 filas de 32

## La maquina no cambia nada

El cartucho lee de todo lo que hay por debajo de `0x4000` **una sola
direccion: `0x0007`**, que es el puerto de datos del VDP, y llama a diecisiete
rutinas de la BIOS: VDP, PSG, teclado y ranuras. **Nunca toca `0x002B`,
`0x002C` ni `0x002D`**, que son los bytes que dicen el juego de caracteres, el
formato de fecha y si la maquina va a 50 o a 60 Hz.

Comprobado ademas volcando: la VRAM del titulo en una maquina internacional y
en una japonesa da **0 bytes distintos de 16.384**. El rotulo en kanji es el
mismo en las dos.

## La marca oculta

Los ultimos trece bytes del cartucho, de `0xBFF3` a `0xBFFF`, son la marca de
la casa: マジョウデンセツ —*Majou Densetsu*— escrito del reves en katakana, su
longitud (`0x0A`), el `0x39` de RC-739 y un `0xAA` que cierra. La descubrio
**Manuel Pazos**.
