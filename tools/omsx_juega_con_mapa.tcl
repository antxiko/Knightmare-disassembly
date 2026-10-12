# Jugar a Knightmare con el mapa de objetos al lado.
#
# Un letrero arriba dice la fase y QUE FILA del mapa de tools/objetos.py hay en
# el borde de arriba de la pantalla (220 - (0xE091), medido con
# omsx_siembra.tcl), para cazar los bloques escondidos con la lamina delante.
# Y (0xE006) -la fase mas alta cerrada desde el encendido- se mantiene en 4, que
# es lo que pide 0x6A22 para que nazcan los seis carteles EXIT: sin esto solo
# salen en la segunda partida.
#
#   openmsx -machine Philips_VG_8020 -cart knightmare.rom -script tools/omsx_juega_con_mapa.tcl
set renderer SDLGL-PP
set throttle on
set scale_factor 3

osd create rectangle hud -x 4 -y 4 -w 236 -h 18 -rgba 0x000000a0
osd create text hud.t -x 4 -y 2 -size 11 -rgba 0xffffffff -text ""

proc tick {} {
    set fase [debug read memory 0xE061]
    set fila [debug read memory 0xE091]
    set arriba [expr {220 - $fila}]
    osd configure hud.t -text "STAGE [format %02X $fase]   fila del mapa arriba: $arriba"
    debug write memory 0xE006 4
    after time 0.2 tick
}
tick
