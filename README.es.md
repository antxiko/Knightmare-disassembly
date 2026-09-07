# Knightmare (Konami, MSX1) — desensamblado comentado

*(Also [in English](README.md).)* ·
**[Leerlo en la web](https://antxiko.github.io/Knightmare-disassembly/es/)**

Desensamblado completo y comentado de **Knightmare** —en Japon *Majou
Densetsu*—, de Konami para MSX (RC-739, 32 KB, 1986). Los 32.768 bytes estan
explicados, y el listado vuelve a dar la ROM **byte a byte**.

    explicado          32.768 de 32.768   100 %
    densidad           1.681 de 7.509     22,4 %
    bloques bajo 10 %        0 de 985
    tests                   23, en verde
    reensamblado       el mismo sha256 que el cartucho

## Que hay aqui

    src/knightmare.asm       el listado comentado, generado
    src/knightmare.notes     los comentarios y los bloques de datos, con su medida
    src/knightmare.entries   los puntos de entrada que no se deducen solos
    tools/                   las herramientas: trazado, listado, dibujos, cotejo
    tests/                   23 comprobaciones que no necesitan el cartucho
    docs/                    la web bilingue

## El cartucho no esta aqui

`knightmare.rom` no se distribuye. Pon tu copia en la raiz; son exactamente
32.768 bytes y

    sha256  6e7a8a2d2fadc078ec9043deee804cfa5efcf2eb64f2fb6291a5161776220cf6

## Como reproducirlo

    make comprueba     # comprueba que tu ROM es la misma
    make               # listado, reensamblado, comprobaciones y tests
    make imagenes      # dibuja las fases, los sprites y las pantallas
    make vram          # coteja esos dibujos contra la VRAM de openMSX

## Ni una captura de pantalla

Todas las imagenes de este repositorio estan **dibujadas desde los bytes de la
ROM**, ejecutando en Python los mismos descompresores, espejos y montadores de
bandas que corre el Z80. Y estan cotejadas byte a byte contra la VRAM del
emulador: **las ocho fases, cero diferencias** en color (6.144 bytes), patrones
(6.144) y las 704 casillas del mapa.

## Lo que aparecio

- **Konami dejo dos erratas en sus tablas de coseno.** Un cuadrante de coseno
  solo puede bajar; estos dos suben una vez cada uno, y el valor que sube es
  justo el unico que se aparta de la funcion.
- **Un truco que pide izquierda y derecha a la vez** —imposible en un
  joystick— mas una tecla, y regala veintiseis vidas.
- **La cabecera del Game Master declara ocho fases** y una direccion mas: una
  rutina de diez bytes de este mismo cartucho a la que nadie de dentro llama.
- **Los tramos de cada fase se solapan una banda exacta**, y no solo en el
  mapa de bits: el decorado que dan es identico, en los nueve empalmes de las
  ocho fases.
- **Tres paletas de un solo guion de color**: las fases 0, 3 y 7 comparten
  casillas y color, y las distingue una traduccion de cinco codigos.
- **La demostracion es una partida grabada**: 118 pulsaciones, una cada ocho
  cuadros.

Todo, con sus medidas, en
[Hallazgos](https://antxiko.github.io/Knightmare-disassembly/es/HALLAZGOS.html),
y lo que *no* se sabe en
[Preguntas abiertas](https://antxiko.github.io/Knightmare-disassembly/es/PREGUNTAS-ABIERTAS.html).

## Licencia y creditos

Las herramientas, los comentarios, el analisis y la documentacion son MIT —ver
`LICENSE`—. El juego no es nuestro: lee [AVISO-LEGAL.md](AVISO-LEGAL.md).

La marca oculta de Konami la descubrio **Manuel Pazos**.
