# Preguntas abiertas

Lo que no se sabe, dicho como lo que es. El listado esta al 100 % explicado
—cada byte tiene su nombre y su razon— pero eso no quiere decir que todo este
entendido.

## El truco del arranque, sin grabar

`0x6F44` pide izquierda y derecha a la vez mas el segundo boton y una tecla, y
una de las tres da veintiseis vidas. **Esto es lectura del codigo**: falta
sentarse en el emulador y grabarlo. Con la matriz estandar del MSX las teclas
salen I, N e Y, pero eso depende del teclado de la maquina y no se ha
comprobado.

## Que dice la cabecera del Game Master, exactamente

El reparto de los veintiun bytes de `0x4010` esta cerrado: se saca ejecutando el
lector del propio Game Master y cuadra byte a byte. Lo que **no** esta cerrado
es si el Game Master de 1985 (RC-735) sabe leer una cabecera `"CD"` de un
cartucho de 1986 y que hace con ella. Este cartucho es posterior a el, asi que
lo mas probable es que la cabecera se escribiera para el Game Master 2
(RC-755), que no esta desensamblado.

Tampoco se ha probado con los dos cartuchos puestos.

## El decimo indice de los enemigos

La tabla de `0x6A98` da, por fase, una palabra con la base de los registros de
enemigo y **diez indices**, uno por tramo. Los nueve primeros no bajan nunca y
el decimo es cero en seis fases —sin enemigos en el ultimo tramo— pero en la 5
y la 6 sigue la cuenta (48 → 50 y 44 → 45). No esta claro si eso es
intencionado o si esos dos tramos tienen algo distinto.

## Los bloques que se solapan, aposta o no

`0x9C21` y `0x9C3E` caen a medio bloque de otro. Que un mismo tramo de bytes
sirva de dos bloques distintos ahorra sitio, pero no se sabe si sale de una
herramienta que buscaba solapes o de que alguien lo coloco a mano.

## Las dos erratas de coseno

Estan medidas y no hay duda de que son erratas: rompen la monotonia de una
tabla que solo puede bajar, y son los dos unicos valores que se apartan de la
funcion. Lo que no se sabe es **si se notan**. Habria que soltar un bicho
apuntando justo a esos dos angulos y mirar si da un tiron.

## La marca oculta, y de donde sale

Los ultimos trece bytes son マジョウデンセツ del reves, su longitud, el numero
de catalogo y un `0xAA`. Que Konami metia esa marca en sus cartuchos lo
descubrio **Manuel Pazos**, y aqui se lee con `tools/marca_konami.py`. Por que
esta escrita del reves, no lo sabemos.
