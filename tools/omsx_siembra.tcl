# Cada vez que la fase siembra un objeto de la lista (0x687B, justo antes de
# monta_un_objeto), apuntar E091/E092/E09A, el registro (tipo,fila,x) y el
# bufer de casillas de la RAM (0xE820..0xEB20), para casar la fila de pantalla
# con la fila del mapa. De aqui sale el 220 - (0xE091) que usa tools/objetos.py:
# once siembras de seis fases, casadas contra la tira de tools/mapas.py, y la
# formula fue la unica comun a todas. Se corre con la demostracion, que pasa
# por las fases 1 a 6; el resultado va a work/siembra.txt.
#
#   openmsx -machine Philips_VG_8020 -cart knightmare.rom -script tools/omsx_siembra.tcl
set renderer none
set throttle off
set f [open "work/siembra.txt" w]
set n 0
debug set_bp 0x687B {} {
    global f n
    set iy [reg IY]
    set t [debug read memory $iy]
    set y [debug read memory [expr {$iy + 1}]]
    set x [debug read memory [expr {$iy + 2}]]
    set e91 [debug read memory 0xE091]
    set e92 [debug read memory 0xE092]
    set e9a [debug read memory 0xE09A]
    set e62 [debug read memory 0xE062]
    set e06 [debug read memory 0xE006]
    set e61 [debug read memory 0xE061]
    set buf [debug read_block memory 0xE820 0x300]
    binary scan $buf H* hex
    puts $f "t=[machine_info time] fase=$e62 e061=$e61 e006=$e06 tramo=$e92 e091=$e91 e09a=$e9a tipo=[format %02X $t] y=$y x=$x buf=$hex"
    incr n
    if {$n >= 60} { close $f; exit }
}
after time 200 { close $f; exit }
