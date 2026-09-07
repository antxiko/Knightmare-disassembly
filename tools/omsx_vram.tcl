# Vuelca la VRAM de Knightmare en los instantes que importan.
#
# No hace falta jugar. El cartucho encadena solo presentacion -> titulo ->
# DEMOSTRACION, y la demostracion es una partida GRABADA: la tira de 118
# pulsaciones de 0x5A95, que 0x5A73 va soltando una cada ocho cuadros por la
# misma puerta por la que entra el mando. Dos arranques dan lo mismo.
#
# LAS OCHO FASES EN UN SOLO ARRANQUE. `monta_la_fase` (0x53D3) lee la fase de
# (0xE062) y de ahi saca TODO: el mapa de la tabla de 0x99CD, las casillas y el
# color de la de 0x563C y los enemigos de la de 0x6A98. Un punto de
# interrupcion en 0x53D3 -antes de que la lea- escribe ahi la que toque, y el
# cartucho monta ESA fase con su propio codigo. No se falsea nada: se cambia un
# byte de partida, como haria un jugador llegando a esa fase.
#
# De cada instante salen dos ficheros: vram_NN.bin con los 16 KB tal cual e
# info_NN.txt con el estado del juego, para poder decir CONTRA QUE se compara.
#
# Trampas de Tcl ya pagadas en esta serie y respetadas aqui: nada de corchetes
# dentro de un `format`, el binario con -translation binary, y `debug
# read_block` en vez de `debug save_to_file`, que no existe.

set renderer none
set throttle off

set carpeta "work/omsx"
set fase 0

proc vuelca {nombre} {
    global carpeta
    set d [debug read_block VRAM 0 16384]
    set f [open [file join $carpeta "vram_$nombre.bin"] w]
    fconfigure $f -translation binary
    puts -nonewline $f $d
    close $f

    set f [open [file join $carpeta "info_$nombre.txt"] w]
    puts $f "tiempo [machine_info time]"
    puts $f "escena [debug read memory 0xE000]"
    puts $f "subescena [debug read memory 0xE001]"
    puts $f "fase_interna [debug read memory 0xE062]"
    puts $f "fase_bcd [debug read memory 0xE061]"
    puts $f "tramo [debug read memory 0xE092]"
    puts $f "filas_subidas [debug read memory 0xE091]"
    puts $f "vidas [debug read memory 0xE060]"
    puts $f "jefe [debug read memory 0xE3B0]"
    close $f
}

# La pantalla del titulo: la escena 1. Va antes que nada y no depende de la
# fase, asi que se vuelca por tiempo.
after time 13 {vuelca "titulo"}

# Y cada fase, imponiendo (0xE062) justo antes de que `monta_la_fase` la lea.
# El volcado va MEDIO segundo despues: ya estan subidos los patrones, el color
# y la tabla de nombres -0x55EA remata en `vuelca_la_pantalla`- y el decorado
# todavia no ha subido ninguna fila, que es lo que hace comparable el mapa.
debug set_bp 0x53D3 {} {
    global fase
    if {$fase < 8} {
        debug write memory 0xE062 $fase
        after time 0.5 "vuelca fase$fase"
        incr fase
    } else {
        after time 1 exit
    }
}
