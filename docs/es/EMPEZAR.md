# Empezar

Este repositorio no trae el cartucho. Trae lo que hace falta para volver a
generarlo todo desde tu propia copia y comprobar que lo que dice es cierto.

## Lo que necesitas

- **Python 3** para las herramientas.
- **pasmo** para el reensamblado (`make verify`).
- **openMSX** solo si quieres cotejar los dibujos contra la VRAM.
- Tu copia de `knightmare.rom`, en la raiz. Son 32.768 bytes exactos y

      sha256  6e7a8a2d2fadc078ec9043deee804cfa5efcf2eb64f2fb6291a5161776220cf6

  `make comprueba` te dice si es la misma.

## Los cuatro pasos

    make comprueba     # que tu ROM sea esta
    make               # listado, reensamblado, comprobaciones y tests
    make imagenes      # dibuja las fases, los sprites y las pantallas
    make vram          # coteja esos dibujos contra la VRAM de openMSX

`make` es el que importa. Encadena cuatro cosas:

1. **`listado`** traza el flujo desde los puntos de entrada declarados en
   `src/knightmare.entries` y genera `src/knightmare.asm` con los comentarios
   de `src/knightmare.notes`.
2. **`verify`** reensambla ese listado con pasmo y compara el sha256 con el de
   tu ROM. Si no dan igual, el desensamblado no vale y ahi se para.
3. **`sanity`** comprueba lo que el reensamblado NO puede cazar: que ninguna
   zona declarada como datos salga como codigo, que ningun punto de entrada
   caiga dentro de un bloque de datos y que **no quede un solo byte sin
   asignar**.
4. **`test`** pasa las 23 comprobaciones de `tests/`.

## Como esta organizado el listado

El listado se genera; no se edita a mano. Lo que se edita es
`src/knightmare.notes`, y de ahi salen las etiquetas, los comentarios de linea,
las cabeceras de bloque y los rangos de datos con su nombre y su descripcion.
Cada comentario esta anclado a su direccion, asi que sobrevive a un retrazado.

`src/knightmare.entries` lleva los puntos de entrada que el trazado no puede
deducir solo —el gancho de interrupcion, las direcciones que se meten en la
pila para ejecutarse al volver, las tablas que van detras de un `call`— y cada
uno con la razon por la que se declara. Si no se puede decir POR QUE es codigo,
no se declara.

## Las cifras, medidas

    make sanity        # los bytes de codigo y de datos, que suman 32.768
    make densidad      # las rutinas y la proporcion de lineas comentadas

Ninguna cifra de esta web esta escrita a ojo: todas salen de esos dos
comandos, y hay tests que lo vigilan.
