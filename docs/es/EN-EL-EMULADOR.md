# En el emulador

Aqui no hay capturas de pantalla, pero el emulador si se usa: para **cotejar**
lo que dibuja Python contra lo que el VDP tiene de verdad.

## El cotejo

    make vram

Arranca openMSX sin ventana, deja que la demostracion se juegue sola, vuelca
los 16 KB de VRAM en nueve instantes y los resta de los que monta Python.

    fase 0  color 0x0000..0x17FF   6144 bytes  0 distintos
            patrones 0x2000..0x37FF 6144 bytes  0 distintos
            nombres, filas 0 a 21   704 casillas 0 distintas
    ...
    ---- 8 pantallas, 0 bytes distintos

Que salga a cero es lo que permite publicar las imagenes diciendo que son las
del cartucho.

## Como se llega a las ocho fases sin jugar

No hace falta jugar, y tampoco hace falta falsear nada. `monta_la_fase`
(`0x53D3`) lee la fase de `(0xE062)` y de ahi saca **todo**: el mapa de la
tabla de `0x99CD`, las casillas y el color de la de `0x563C` y los enemigos de
la de `0x6A98`. Un punto de interrupcion en `0x53D3` —antes de que la lea—
escribe ahi la que toque, y el cartucho monta **esa** fase con su propio
codigo. Se cambia un byte de partida, como haria un jugador llegando a esa
fase.

El volcado va **medio segundo despues**: ya estan subidos los patrones, el
color y la tabla de nombres, y el decorado todavia no ha subido ninguna fila,
que es lo que hace comparable el mapa.

## Dos trampas que costaron el cotejo

**El cartucho no borra los patrones ni el color al cambiar de fase**, solo la
tabla de nombres. Las fases 1, 2 y 4 traen menos casillas que la 0 —61, 59 y 79
contra 80—, asi que lo que sobra se queda de la anterior. Montar una fase
suelta daba 456 bytes de diferencia en el color; encadenarlas como las encadena
el juego, cero.

**El marcador va abajo, no arriba.** La pantalla empieza cuatro filas dentro
del buffer de casillas —`vuelca_la_pantalla` copia desde `0xE8A0` menos
`(0xE091) & 3` filas—, y las dos ultimas filas de la pantalla son SCORE,
HISCORE, REST y STAGE, que se pintan encima despues.

## Verlo jugar

    openmsx -machine Philips_VG_8020 -cart knightmare.rom

El cartucho encadena solo presentacion, titulo y demostracion, y la
demostracion es una partida grabada, asi que dos arranques dan lo mismo.

## Si quieres mirar por dentro

La consola de openMSX (F10) sirve para lo de siempre:

    debug read memory 0xE062     ; la fase, de 0 a 7
    debug read memory 0xE060     ; las vidas
    debug write memory 0xE062 5  ; y saltar a la sexta

Y para las tres variables que mandan en el cuadro:

    debug read memory 0xE000     ; la escena
    debug read memory 0xE092     ; el tramo dentro de la fase, de 0 a 9
    debug read memory 0xE091     ; las filas de casilla que se han subido
