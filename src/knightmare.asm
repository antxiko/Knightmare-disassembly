; ==========================================================================
; KNIGHTMARE: MAJYO DENSETSU - Konami - MSX1 - cartucho RC-739 de 32 KB en las paginas 1 y 2
; ==========================================================================
; Generado por tools/mkasm.py a partir del trazado de flujo real.
; Los comentarios provienen de tools/../src/*.notes y estan anclados a
; direccion, de modo que sobreviven a un retrazado.
; ==========================================================================

	org 0x04000


; ----------------------------------------------------------------------
; DATOS cabecera_del_cartucho: "AB" y la direccion de INIT (0x407E);
;   STATEMENT, DEVICE y TEXT a cero, y los seis bytes reservados tambien
;   0x4000..0x4010  (16 bytes)
DATA_cabecera_del_cartucho:
	defw 04241h,0407eh,00000h,00000h,00000h,00000h,00000h,00000h	; 4000

; ----------------------------------------------------------------------
; DATOS cabecera_del_game_master: "CD" 07 39: el 0x07 de los RC-7xx y el 0x39
;   de RC-739. El "CD" es el marcador de los cartuchos de 1986-87, frente al
;   "AB" de los de 1985
;   0x4010..0x4014  (4 bytes)
DATA_cabecera_del_game_master:
	defb 043h,044h,007h,039h	; 4010

; ----------------------------------------------------------------------
; DATOS banderas_del_game_master: 0x20: los ocho campos vienen todos menos el
;   del bit 5, que es el puntero al marcador del segundo jugador -este juego
;   no tiene-
;   0x4014..0x4015  (1 bytes)
DATA_banderas_del_game_master:
	defb 020h	; 4014

; ----------------------------------------------------------------------
; DATOS punteros_del_game_master: Los siete campos que declara el cartucho, en
;   el orden en que los lee 0x5E92 del Game Master: 0xE000 y 0x04 (la variable
;   de escena y la escena en la que hay que aplicar los trucos), 0xE061 y 0x08
;   (la variable de fase y CUANTAS fases hay: ocho), 0xE060 (las vidas),
;   0xE053 (el record), 0xE056 (la puntuacion), 0xE002 (los bits de modo) y
;   0x56C8, que es una RUTINA de este cartucho que el Game Master llama entre
;   ranuras: convierte la fase escrita en (0xE061) al indice interno de
;   (0xE062)
;   0x4015..0x4025  (16 bytes)
DATA_punteros_del_game_master:
	defw 0e000h,06104h	; 4015
	defb 0e0h	; 4019
	defw 06008h,053e0h	; 401a
	defb 0e0h	; 401e
	defw 0e056h,0e002h,056c8h	; 401f  -> 0xe056 0xe002 fase_pedida_a_indice

; ======================================================================
; CODIGO 0x4025..0x40ea  (197 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL ARRANQUE DEL TITULO, con un escribe-en-la-ROM que no hace nada
; ----------------------------------------------------------------------
prepara_el_titulo:
	ld hl,0c9e1h		;4025   ; 0xC9E1 son, puestos en memoria, los bytes E1 C9: `pop hl / ret`
	ld (04112h),hl		;4028   ; pero 0x4112 es la ROM del propio cartucho, asi que este escribe SE PIERDE. Si tuviera efecto, convertiria el `djnz` de 0x4112 en un `pop hl / ret`
	jp monta_el_cartel		;402b   ; y sigue montando la pantalla del titulo

; ----------------------------------------------------------------------
; EL GANCHO DE LA INTERRUPCION: aqui cuelga el cuadro entero
; ----------------------------------------------------------------------
cada_cuadro:		; El gancho de H.KEYI: el juego ENTERO cuelga de aqui
	call 0013eh		;402e   ; BIOS RDVDP - Reads VDP status register | RDVDP borra la peticion de interrupcion del VDP; si no se lee, el VDP la mantiene
	di			;4031
	call suena_el_cuadro		;4032   ; el sonido va PRIMERO, antes que nada, para que no se le note el retraso si el cuadro se alarga
	ld hl,0e005h		;4035   ; el cerrojo de reentrada: si el cuadro anterior todavia no ha acabado
	bit 0,(hl)		;4038
	jr nz,L_4048		;403a   ; se salta el trabajo entero y se va a limpiar y salir
	inc (hl)			;403c
	ei			;403d
	call lee_los_mandos		;403e   ; los mandos
	call haz_el_cuadro		;4041   ; y el cuadro
	xor a			;4044
	ld (0e005h),a		;4045
L_4048:
	call 0013eh		;4048   ; BIOS RDVDP - Reads VDP status register | segunda lectura del VDP, ya de salida
	or a			;404b
	di			;404c
	call m,suena_el_cuadro		;404d   ; y si el bit 7 dice que hubo colision o quinto sprite, otra pasada de sonido
	ei			;4050
	ret			;4051

; ----------------------------------------------------------------------
; PONER UN REGISTRO DEL VDP, con otro escribe-en-la-ROM
; ----------------------------------------------------------------------
pon_registro_del_vdp:
	ld hl,00000h		;4052   ; otra vez lo mismo: 0x411E cae dentro del `jp L_4187` de 0x411D, y es ROM
	ld (0411eh),hl		;4055   ; asi que el escribe se pierde. De tener efecto, dejaria ahi un `jp 00000h`, o sea un reinicio
	jp 00047h		;4058   ; BIOS WRTVDP - Writes data in the VDP-register | lo que si hace es escribir el registro: b el valor, c el numero

; ----------------------------------------------------------------------
; LAS DOS SUMAS DE 16 BITS QUE USA TODO EL CARTUCHO
; ----------------------------------------------------------------------
suma_a_a_hl:		; HL += A, con el acarreo al alto
	add a,l			;405b   ; hl += a, sin signo
	ld l,a			;405c
	ret nc			;405d   ; el `ret nc` se ahorra el incremento cuando no hay acarreo
	inc h			;405e
	ret			;405f
suma_a_a_de:		; DE += A, igual
	add a,e			;4060   ; de += a, la misma receta
	ld e,a			;4061
	ret nc			;4062
	inc d			;4063
	ret			;4064

; ----------------------------------------------------------------------
; EL REPARTIDOR. Tres puertas al mismo `jp (hl)`: con la tabla en la direccion de retorno, con la tabla ya en HL, y con el indice sacado de (ix+0)
; ----------------------------------------------------------------------
reparte_por_ix:		; El indice sale de (ix+0) menos uno, y la tabla ya viene en HL
	ld a,(ix+000h)		;4065   ; el indice menos uno: la entrada 0 de estas tablas no existe
	dec a			;4068
	ret m			;4069   ; y con (ix+0) a cero, no hay a donde ir
	jr reparte_por_tabla_en_hl		;406a
reparte_por_tabla:		; El `pop hl` recoge la tabla: es la direccion de retorno
	pop hl			;406c   ; el `pop hl` recoge la direccion de retorno, que es la tabla: por eso las tablas van DETRAS del `call`
reparte_por_tabla_en_hl:		; Con la tabla ya en HL, sin sacarla de la pila
	call palabra_de_tabla_en_hl		;406d
	jp (hl)			;4070   ; aqui esta el unico salto indirecto del cartucho
palabra_de_tabla_doble:		; A se duplica antes de indexar: entradas de dos bytes
	add a,a			;4071   ; dos bytes por entrada
palabra_de_tabla:		; Devuelve en DE la palabra numero A de la tabla HL
	call suma_a_a_hl		;4072
	ld e,(hl)			;4075   ; y la palabra que sale es la direccion
	inc hl			;4076
	ld d,(hl)			;4077
	ret			;4078
palabra_de_tabla_en_hl:		; Lo mismo, pero devolviendola en HL
	call palabra_de_tabla_doble		;4079   ; y la devuelve en HL
	ex de,hl			;407c
	ret			;407d

; ----------------------------------------------------------------------
; INIT: lo que ejecuta la BIOS al encontrar la "AB" de 0x4000
; ----------------------------------------------------------------------
INIT:		; Lo que ejecuta la BIOS al encontrar la "AB" de 0x4000
	di			;407e   ; interrupciones fuera y modo 1
	im 1		;407f
	ld sp,0e800h		;4081   ; la pila, arriba del todo de la RAM del juego
	call 00138h		;4084   ; BIOS RSLREG - Reads the primary slot register | RSLREG da el registro de ranuras primarias
	rrca			;4087   ; los dos bits de la pagina 1, que es donde esta este cartucho
	rrca			;4088
	and 003h		;4089
	ld c,a			;408b
	ld b,000h		;408c
	ld hl,0fcc1h		;408e   ; 0xFCC1 es SLTTBL, la tabla de ranuras expandidas
	add hl,bc			;4091
	or (hl)			;4092   ; si la ranura es expandida, se le pega el bit 7
	ld c,a			;4093
	inc hl			;4094   ; cuatro adelante esta el byte de la subranura
	inc hl			;4095
	inc hl			;4096
	inc hl			;4097
	ld a,(hl)			;4098
	and 00ch		;4099   ; y de el solo interesan los dos bits de la pagina 1
	or c			;409b
	ld h,080h		;409c   ; h = 0x80: la pagina 2, que es donde hay que meter la segunda mitad del cartucho
	call 00024h		;409e   ; BIOS ENASLT - Switches to specified slot and page definitively | ENASLT deja el cartucho entero visible, 0x4000..0xBFFF
	ld a,0c3h		;40a1   ; 0xC3 es el opcode de `jp`
	ld (0fd9ah),a		;40a3   ; H.KEYI, el gancho de la interrupcion del teclado, que salta antes que el reloj
	ld hl,cada_cuadro		;40a6   ; y ahi va la direccion del cuadro
	ld (0fd9bh),hl		;40a9   ; y ahi va la direccion del cuadro
	ld hl,0e000h		;40ac   ; borra las variables: 0xE000..0xE7FF
	ld de,0e001h		;40af
	ld bc,007ffh		;40b2
	ld (hl),000h		;40b5   ; a cero
	ldir		;40b7   ; de un golpe
	ld a,001h		;40b9   ; el cerrojo de reentrada, echado a mano
	ld (0e005h),a		;40bb   ; el cerrojo, echado
	call arranca_la_pantalla		;40be   ; monta el VDP y la pantalla de arranque
	xor a			;40c1
	ld (0e005h),a		;40c2   ; y lo suelta
	call 0013eh		;40c5   ; BIOS RDVDP - Reads VDP status register | y se lee el VDP antes de abrir
	ei			;40c8   ; a partir de aqui manda la interrupcion
el_bucle_vacio:		; INIT acaba aqui: a partir de este `jr $` todo pasa en la interrupcion
	jr el_bucle_vacio		;40c9   ; y este bucle vacio es todo el programa principal: el juego entero ocurre dentro del gancho

; ----------------------------------------------------------------------
; PEDIR UNA PIEZA CON EL VDP A OSCURAS
; ----------------------------------------------------------------------
suena_con_pantalla_apagada:
	ld hl,044c6h		;40cb   ; 0x44C6 es el byte de R1 dentro de la tabla de registros del VDP
	res 6,(hl)		;40ce   ; le quita el bit 6, que es el que enciende la pantalla, pero SOLO en la copia de la ROM... que es ROM: no cambia nada
	jp pide_pieza		;40d0   ; y pide la pieza

; ----------------------------------------------------------------------
; EL CUADRO: cuenta, mira la escena y reparte
; ----------------------------------------------------------------------
haz_el_cuadro:		; Cuenta el cuadro y reparte la escena que toque
	ld hl,0e003h		;40d3   ; el contador de cuadros, que muchas animaciones usan de reloj
	inc (hl)			;40d6
	ld a,(0e000h)		;40d7   ; en las escenas 0, 1 y 2 -presentacion, titulo y demostracion-
	cp 003h		;40da
	jr nc,L_40E2		;40dc
	ld hl,04262h		;40de   ; se empuja 0x4262 a mano, para que la escena remate por ahi al volver: es el que mira si se ha pulsado algo
	push hl			;40e1
L_40E2:
	ld bc,(0e000h)		;40e2   ; c = (0xE000) la escena, b = (0xE001) la subescena
	ld a,c			;40e6
	call reparte_por_tabla		;40e7   ; y a la tabla de diez

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_40EA: 10 entradas; tras el `call 406Ch` de 0x40E7;
;   sigue en 0x40FE
;   0x40ea..0x40fe  (20 bytes)
DATA_tabla_de_reparto_40EA:
	defw 040feh,0412eh,04135h,0416ah,0419ch,041e1h,041f4h,0420bh	; 40ea
	defw 0422bh,0425fh	; 40fa  -> escena_fase_siguiente escena_final

; ======================================================================
; CODIGO 0x40fe..0x42a9  (427 bytes)
; ======================================================================


escena_presentacion:		; Baja el cartel de KONAMI un paso por cuadro
	djnz L_4112		;40fe
	ld a,(0e003h)		;4100   ; el contador de cuadros
	rra			;4103   ; uno de cada dos
	ret nc			;4104
	call baja_un_paso		;4105   ; baja el cartel un paso
	ret nz			;4108
	ld de,04518h		;4109   ; y al acabar, el fondo de la presentacion
	call descomprime_desde_la_palabra		;410c
	xor a			;410f
	jr L_4162		;4110
L_4112:
	djnz L_4120		;4112
	ld hl,0e004h		;4114   ; el reloj del titulo
	dec (hl)			;4117
	ret nz			;4118
	call monta_el_titulo		;4119   ; monta la pantalla
	xor a			;411c
	jp L_4187		;411d
L_4120:
	call pon_los_registros_del_vdp		;4120
	call limpia_sprites_y_nombres		;4123   ; monta la pantalla
	call limpia_la_fuente		;4126   ; la fuente
	call arranca_la_presentacion		;4129   ; y el cartel de KONAMI
	jr L_4165		;412c
escena_espera:
	ld hl,0e004h		;412e   ; el reloj
	dec (hl)			;4131
	ret nz			;4132
	jr L_4185		;4133
escena_titulo:		; El titulo, la demostracion y el menu
	djnz L_4155		;4135
	call L_5A73		;4137   ; la demostracion
	call mira_la_pausa		;413a   ; y la pausa
	ld a,(0e064h)		;413d   ; con demostracion en marcha no se sale
	or a			;4140
	ret nz			;4141
	ld hl,0e062h		;4142   ; la fase siguiente de la demostracion, de 0 a 7
	ld a,(hl)			;4145
	inc a			;4146
	and 007h		;4147
	ld (hl),a			;4149
L_414A:
	xor a			;414a
L_414B:
	ld (0e000h),a		;414b
	ld a,020h		;414e
	ld (0e004h),a		;4150
	jr L_418E		;4153
L_4155:
	ld b,0e0h		;4155   ; borde negro
	call pon_registro_7		;4157
	call limpia_sprites_y_nombres		;415a
	call arranca_la_demostracion		;415d   ; arranca la demostracion
	ld a,020h		;4160   ; y 0x20 cuadros de espera
L_4162:
	ld (0e004h),a		;4162
L_4165:
	ld hl,0e001h		;4165   ; (0xE001) es la subescena
	inc (hl)			;4168
	ret			;4169
escena_cuenta_atras:		; Parpadea el rotulo y arranca la partida
	djnz L_417D		;416a
	ld hl,0e004h		;416c   ; el reloj del parpadeo
	dec (hl)			;416f
	jr z,L_4165		;4170
	bit 2,(hl)		;4172   ; el bit 2 hace el parpadeo
	ld de,04556h		;4174   ; el mismo rotulo se pinta...
	jp z,pinta_texto		;4177
	jp pinta_texto_en_negro		;417a
L_417D:
	djnz L_4193		;417d
	call partida_nueva		;417f   ; partida nueva
	call el_truco_del_arranque		;4182   ; y el truco del arranque
L_4185:
	ld a,020h		;4185   ; 0x20 cuadros
L_4187:
	ld (0e004h),a		;4187
L_418A:
	ld hl,0e000h		;418a   ; a la escena siguiente
	inc (hl)			;418d
L_418E:
	xor a			;418e
	ld (0e001h),a		;418f
	ret			;4192
L_4193:
	ld a,0b7h		;4193   ; el borde en 0xB7
	call pide_pieza		;4195
	ld a,040h		;4198
L_419A:
	jr L_4162		;419a
escena_juego:		; La escena 4: la que el Game Master vigila
	djnz escena_se_pierde_una_vida		;419c
	ld a,(0e073h)		;419e   ; con (0xE073) puesto la fase ya estaba montada
	or a			;41a1
	jr nz,L_41AB		;41a2
	ld a,(0e02eh)		;41a4   ; y se espera a que se calle el sonido
	or a			;41a7
	ret nz			;41a8
	jr L_41B0		;41a9
L_41AB:
	ld hl,0e004h		;41ab
	dec (hl)			;41ae
	ret nz			;41af
L_41B0:
	call monta_la_fase		;41b0   ; monta la fase
	ld a,001h		;41b3
	ld (0e064h),a		;41b5   ; y (0xE064) dice que hay partida
	jr L_418A		;41b8
escena_se_pierde_una_vida:
	ld b,0e0h		;41ba   ; borde negro
	call pon_registro_7		;41bc
	call limpia_sprites_y_nombres		;41bf
	call monta_el_marcador		;41c2
	ld hl,0e060h		;41c5   ; una vida menos
	ld a,(hl)			;41c8
	sub 001h		;41c9   ; una vida menos, en BCD
	daa			;41cb
	ld (hl),a			;41cc
	call pinta_el_marcador		;41cd   ; se repinta el marcador
	ld de,04582h		;41d0   ; y el rotulo de STAGE con su numero
	ld hl,0392ch		;41d3
	call byte_del_guion		;41d6
	inc l			;41d9
	call pinta_un_byte_bcd		;41da
	ld a,078h		;41dd
	jr L_419A		;41df
escena_fase_pasada:
	call mira_la_pausa		;41e1
	ld a,(0e00dh)		;41e4   ; con (0xE00D) puesto se ha acabado el tramo
	and a			;41e7
	ld a,008h		;41e8
	jp nz,L_414B		;41ea
	ld a,(0e064h)		;41ed   ; y con (0xE064), la demostracion
	or a			;41f0
	ret nz			;41f1
L_41F2:
	jr L_4185		;41f2
escena_se_acabo_una_vida:		; Si no quedan vidas, el GAME OVER
	ld a,(0e060h)		;41f4   ; sin vidas
	or a			;41f7
	jr z,L_41FF		;41f8
L_41FA:
	ld a,004h		;41fa
	jp L_414B		;41fc
L_41FF:
	ld a,0bah		;41ff   ; borde 0xBA
	call pide_pieza		;4201
	ld b,0e0h		;4204   ; y otra vez negro
	call pon_registro_7		;4206
	jr L_41F2		;4209
escena_game_over:
	djnz L_421C		;420b
	ld a,(0e012h)		;420d   ; hasta que no se acabe el sonido del GAME OVER
	or a			;4210
	ret nz			;4211
	ld hl,0e002h		;4212   ; se apaga el bit 6 de (0xE002): se acabo el sonido
	ld a,(hl)			;4215
	and 0bfh		;4216
	ld (hl),a			;4218
	jp L_414A		;4219   ; a la escena 0
L_421C:
	call limpia_sprites_y_nombres		;421c   ; limpia
	ld de,04588h		;421f   ; y pinta el GAME OVER
	call pinta_texto		;4222
	call pinta_el_marcador		;4225
	jp L_4165		;4228
escena_fase_siguiente:		; Sube la fase, el marcador de fase y el record de fase
	xor a			;422b
	ld (0e00dh),a		;422c   ; se apagan los avisos de fin de tramo
	ld (0e073h),a		;422f
	ld hl,0e006h		;4232   ; y se guarda la fase mas alta a la que se ha llegado
	ld a,(hl)			;4235
	cp 004h		;4236
	jr nc,sube_de_fase		;4238
	ld a,(0e061h)		;423a
	cp (hl)			;423d
	jr c,sube_de_fase		;423e
	ld (hl),a			;4240
sube_de_fase:
	ld hl,0e060h		;4241   ; una vida mas
	ld a,(hl)			;4244
	add a,001h		;4245
	daa			;4247
	ld (hl),a			;4248
	inc hl			;4249   ; y una fase mas, las dos en BCD
	ld a,(hl)			;424a
	add a,001h		;424b
	daa			;424d
	ld (hl),a			;424e
	inc hl			;424f   ; la fase interna, de 0 a 7
	inc (hl)			;4250
	ld a,(hl)			;4251
	and 007h		;4252
	ld (hl),a			;4254
	jp nz,L_41FA		;4255   ; y al dar la vuelta, (0xE068) enciende el modo dificil
	ld a,001h		;4258
	ld (0e068h),a		;425a
	jr L_41F2		;425d
escena_final:
	jp escena_final_espera		;425f
mira_si_se_ha_pulsado_algo:
	call lee_mando_y_teclado		;4262   ; lo que hay pulsado
	ld hl,0e052h		;4265   ; lo que hay pulsado, a 0xE052
	call guarda_lo_recien_pulsado_en_hl		;4268   ; y lo que ACABA de pulsarse
	or a			;426b
	ret z			;426c   ; sin nada nuevo, no se hace nada
	ld hl,0e004h		;426d   ; fuera la espera
	ld (hl),000h		;4270
	ld hl,0e000h		;4272
	ld b,(hl)			;4275
	djnz L_4286		;4276   ; con la escena 1 -el titulo- se sigue por aqui
	and 030h		;4278   ; y solo con los botones de disparo
	ret z			;427a
	ld a,040h		;427b   ; (0xE002) enciende el sonido
	ld (0e002h),a		;427d
	ld (hl),003h		;4280   ; escena 3, subescena 0: a jugar
	inc hl			;4282
	ld (hl),000h		;4283
	ret			;4285
L_4286:
	ld (hl),001h		;4286   ; y desde cualquier otra escena, se vuelve al titulo
	ld a,03dh		;4288   ; con el silencio
	call pide_pieza		;428a
	jp monta_el_titulo		;428d
partida_nueva:		; Borra de 0xE056 a 0xE750 y pone las cuatro variables de 0x42A9
	ld hl,0e056h		;4290   ; desde el marcador
	ld bc,006fah		;4293   ; borra 0x6FA bytes, hasta 0xE750
	ld d,h			;4296
	ld e,l			;4297
	inc e			;4298
	ld (hl),000h		;4299
	ldir		;429b
	ld hl,042a9h		;429d   ; y pone las cuatro variables de arranque
	ld de,0e060h		;42a0
	ld bc,00004h		;42a3
	ldir		;42a6
	ret			;42a8

; ----------------------------------------------------------------------
; DATOS partida_recien_puesta: Los cuatro bytes que 0x42A9 copia a 0xE060:
;   tres vidas, fase 1, fase interna 0 y el umbral de la vida extra en 0x10
;   (10.000 puntos en BCD)
;   0x42a9..0x42ad  (4 bytes)
DATA_partida_recien_puesta:
	defb 003h,001h,000h,010h	; 42a9

; ======================================================================
; CODIGO 0x42ad..0x44c5  (536 bytes)
; ======================================================================


suma_puntos_bc:		; Con el byte alto a cero
	ld c,000h		;42ad
suma_puntos:		; DE:C se suma en BCD a la puntuacion de 0xE056; topa en 999999 y, si se pasa el umbral de (0xE063), regala una vida
	ld a,(0e002h)		;42af   ; el bit 6 de (0xE002) es el que deja sumar
	add a,a			;42b2   ; subido al 7 para poder mirarlo con `ret p`
	ret p			;42b3
	ld hl,0e056h		;42b4   ; el marcador, tres bytes en BCD
	ld a,(hl)			;42b7
	add a,e			;42b8   ; el byte bajo
	daa			;42b9   ; y `daa` arregla el resultado a decimal
	ld (hl),a			;42ba
	inc hl			;42bb
	ld a,(hl)			;42bc   ; el de en medio, con acarreo
	adc a,d			;42bd
	daa			;42be
	ld (hl),a			;42bf
	inc hl			;42c0
	ld a,(hl)			;42c1   ; y el alto
	adc a,c			;42c2
	daa			;42c3
	ld (hl),a			;42c4
	jr nc,L_42D4		;42c5   ; si se pasa de 999999
	ld bc,09999h		;42c7   ; se clava en 999999
	ld (0e053h),bc		;42ca   ; y tambien el record
	ld (0e054h),bc		;42ce
	jr pinta_puntuacion_y_record		;42d2
L_42D4:
	ex de,hl			;42d4
	ld hl,0e063h		;42d5   ; el umbral de la vida extra
	cp (hl)			;42d8
	jr c,L_42EA		;42d9
	ld a,(hl)			;42db
	ld b,010h		;42dc   ; se sube 0x10 -diez mil puntos- para la siguiente
	add a,b			;42de
	daa			;42df
	jr nc,L_42E4		;42e0
	ld a,0ffh		;42e2
L_42E4:
	ld (hl),a			;42e4
	push de			;42e5
	call una_vida_mas		;42e6
	pop de			;42e9
L_42EA:
	ld b,003h		;42ea
	ld hl,0e055h		;42ec
	ex de,hl			;42ef
L_42F0:
	ld a,(de)			;42f0   ; el marcador contra el record, byte a byte
	sub (hl)			;42f1
	jr c,L_42FA		;42f2
	jr nz,pinta_puntuacion_y_record		;42f4   ; si es mayor, no hay record nuevo
	dec l			;42f6
	dec e			;42f7
	djnz L_42F0		;42f8
L_42FA:
	ld bc,00003h		;42fa
	ld e,055h		;42fd
	ld l,058h		;42ff
	lddr		;4301
	jr pinta_puntuacion_y_record		;4303
una_vida_mas:
	ld hl,0e060h		;4305
	ld a,(hl)			;4308
	cp 099h		;4309   ; con 99 vidas ya no se suman mas
	ret z			;430b
	add a,001h		;430c   ; una mas, en BCD
	daa			;430e
	ld (hl),a			;430f
	ld a,015h		;4310   ; y su sonido
	call pide_pieza_si_la_escena_lo_permite		;4312
pinta_las_vidas:
	ld hl,03af5h		;4315   ; las vidas, en 0x3AF5
	ld de,0e060h		;4318
	ld b,001h		;431b
	jr escribe_en_bcd		;431d
pinta_el_marcador:		; Los cuatro rotulos, las vidas, la fase, la puntuacion y el record
	ld de,04567h		;431f   ; los cuatro rotulos
	call pinta_texto		;4322
	call pinta_las_vidas		;4325   ; las vidas
	call pinta_la_fase		;4328   ; y la fase
pinta_puntuacion_y_record:
	ld hl,03aebh		;432b   ; la puntuacion, en 0x3AEB
	ld de,0e055h		;432e
	call L_433A		;4331
	ld hl,03ae2h		;4334   ; y el record, en 0x3AE2
	ld de,0e058h		;4337
L_433A:
	ld b,003h		;433a
	jr escribe_en_bcd		;433c
pinta_la_fase:
	ld hl,03afch		;433e   ; la fase, en 0x3AFC
pinta_un_byte_bcd:
	ld de,0e061h		;4341
	ld b,001h		;4344
escribe_en_bcd:		; Nibble alto y bajo por separado, +0x10 para caer en las cifras de la fuente; el `ld c,0xFF` come los ceros a la izquierda
	ld c,000h		;4346   ; sin ceros a la izquierda de momento
L_4348:
	ld a,(de)			;4348   ; el nibble alto
	rra			;4349
	rra			;434a
	rra			;434b
	rra			;434c
	and 00fh		;434d   ; en cifras de 0 a 9
	jr z,L_4353		;434f
	ld c,0ffh		;4351
L_4353:
	dec b			;4353   ; el ultimo byte los pinta siempre
	jr nz,L_4358		;4354
	ld c,0ffh		;4356
L_4358:
	inc b			;4358
	add a,010h		;4359   ; +0x10 para caer en las cifras de la fuente
	and c			;435b
	call 0004dh		;435c   ; BIOS WRTVRM - Writes data in VRAM | WRTVRM de una en una
	inc hl			;435f
	ld a,(de)			;4360
	and 00fh		;4361
	jr z,L_4367		;4363
	ld c,0ffh		;4365
L_4367:
	add a,010h		;4367
	and c			;4369
	call 0004dh		;436a   ; BIOS WRTVRM - Writes data in VRAM
	dec de			;436d
	inc hl			;436e
	djnz L_4348		;436f
	ret			;4371

; ----------------------------------------------------------------------
; DE PIXELES A CASILLA. Con (x,y) en HL devuelve en HL la direccion de la
; tabla de nombres: y/8 por 32 mas x/8, y el 0x38 de arriba, que es la
; tabla de nombres de 0x3800.
; ----------------------------------------------------------------------
de_pixeles_a_direccion:		; De (x,y) en HL a la direccion de la tabla de nombres
	ld a,l			;4372   ; la x
	rra			;4373   ; partida por ocho, arrastrando los bits de la y
	rra			;4374
	rra			;4375
	rra			;4376
	rr h		;4377
	rra			;4379
	rr h		;437a
	rra			;437c
	rr h		;437d
	ld l,h			;437f
	and 003h		;4380   ; la y ya cabe en dos bits...
	add a,038h		;4382   ; ...y con 0x38 delante sale la direccion de 0x3800
	ld h,a			;4384
	ret			;4385
limpia_sprites_y_nombres:		; Aparca los 32 sprites en 0x3B00 -y su sombra de 0xE320- y borra la tabla de nombres
	ld hl,03b00h		;4386   ; el primer atributo, aparcado en 0xD0
	ld a,0d0h		;4389
	call 0004dh		;438b   ; BIOS WRTVRM - Writes data in VRAM
	ld hl,03b01h		;438e   ; y los demas con 0xC3
	ld bc,0007fh		;4391
	ld a,0c3h		;4394
	call 00056h		;4396   ; BIOS FILVRM - Fills VRAM with value
	ld hl,0e320h		;4399   ; lo mismo en la sombra de la RAM
	ld de,0e321h		;439c
	ld bc,0005fh		;439f
	ld (hl),0c3h		;43a2
	ldir		;43a4
	ld hl,03800h		;43a6   ; la tabla de nombres
	ld bc,00300h		;43a9
	xor a			;43ac
	jp 00056h		;43ad   ; BIOS FILVRM - Fills VRAM with value | a cero de un golpe
abre_para_escribir:		; SETWRT y deja en C' el puerto de datos del VDP
	ex af,af'			;43b0   ; guarda a, que el que llama lo esta usando
	call 00053h		;43b1   ; BIOS SETWRT - Enables VDP to write
	exx			;43b4
	ld a,(00007h)		;43b5   ; 0x0007 de la ROM del BIOS trae el puerto de datos del VDP
	ld c,a			;43b8
	exx			;43b9
	ex af,af'			;43ba
	ret			;43bb
vuelca_a_vram:
	ex de,hl			;43bc   ; LDIRVM con los registros al reves
	jp 0005ch		;43bd   ; BIOS LDIRVM - Block transfers to VRAM from memory
rellena_los_tres_bancos:
	ld d,003h		;43c0   ; los tres bancos
L_43C2:
	push bc			;43c2
	push de			;43c3
	call 00056h		;43c4   ; BIOS FILVRM - Fills VRAM with value | uno cada vuelta
	ld de,00800h		;43c7
	add hl,de			;43ca
	pop de			;43cb
	pop bc			;43cc
	dec d			;43cd
	jr nz,L_43C2		;43ce
	ret			;43d0
descomprime_en_los_tres_bancos:
	ld b,003h		;43d1
L_43D3:
	push bc			;43d3
	push de			;43d4
	call descomprime		;43d5   ; la misma tanda en cada banco
	ld de,00800h		;43d8   ; 0x800 mas alla
	add hl,de			;43db
	pop de			;43dc
	pop bc			;43dd
	djnz L_43D3		;43de
	ret			;43e0
vuelca_el_guion_en_los_tres_tercios:
	ld b,003h		;43e1
L_43E3:
	push bc			;43e3
	push de			;43e4
	call descomprime_espejado		;43e5   ; y aqui espejada
	ld de,00800h		;43e8
	add hl,de			;43eb
	pop de			;43ec
	pop bc			;43ed
	djnz L_43E3		;43ee
	ret			;43f0
pinta_texto:		; Guion de rotulos: palabra con la direccion de VRAM, codigos de casilla, 0xFE para cambiar de sitio y 0xFF para acabar
	ld c,0ffh		;43f1
pinta_texto_desde_la_palabra:
	ex de,hl			;43f3
	ld e,(hl)			;43f4   ; los dos primeros bytes son la direccion de VRAM
	inc hl			;43f5
	ld d,(hl)			;43f6
	ex de,hl			;43f7
	inc de			;43f8   ; y el guion sigue detras
byte_del_guion:
	ld a,(de)			;43f9
	inc de			;43fa   ; el byte siguiente del guion
	ld b,a			;43fb
	inc b			;43fc   ; 0xFF: se acabo
	ret z			;43fd
	inc b			;43fe   ; 0xFE: cambia de sitio y sigue
	jr z,pinta_texto_desde_la_palabra		;43ff
	and c			;4401   ; aqui es donde la mascara decide
	call 0004dh		;4402   ; BIOS WRTVRM - Writes data in VRAM
	inc hl			;4405
	jr byte_del_guion		;4406
pinta_texto_en_negro:		; Lo mismo con la mascara a cero: borra el rotulo
	ld c,000h		;4408   ; c = 0: el mismo guion, pero escribiendo ceros
	jr pinta_texto_desde_la_palabra		;440a
descomprime_desde_la_palabra:
	ex de,hl			;440c
	ld e,(hl)			;440d   ; la direccion de VRAM, dentro del guion
	inc hl			;440e
	ld d,(hl)			;440f
	ex de,hl			;4410
	inc de			;4411
descomprime:
	ld c,000h		;4412   ; sin espejar
descomprime_en_hl:
	call abre_para_escribir		;4414   ; con el destino ya puesto
byte_del_bloque_comprimido:		; El formato: n con el bit 7 puesto = n bytes tal cual; n sin el bit 7 = el byte siguiente repetido n veces; 0x80 = cambio de direccion; 0x00 = fin
	ld a,(de)			;4417   ; el byte de cuenta
	and a			;4418
	ret z			;4419   ; el 0x00 cierra el bloque
	inc de			;441a
	ld b,a			;441b
	and 07fh		;441c   ; sin el bit 7: la cuenta
	cp b			;441e   ; si eran iguales, es una repeticion
	jr z,L_4430		;441f
	and a			;4421
	jr z,descomprime_desde_la_palabra		;4422
	ld b,a			;4424
L_4425:
	call lee_y_traduce		;4425   ; b bytes tal cual
	exx			;4428
	out (c),a		;4429   ; por el puerto del VDP
	exx			;442b
	djnz L_4425		;442c
	jr byte_del_bloque_comprimido		;442e
L_4430:
	call lee_y_traduce		;4430
L_4433:
	exx			;4433
	out (c),a		;4434
	exx			;4436
	djnz L_4433		;4437
	jr byte_del_bloque_comprimido		;4439
lee_y_traduce:		; El byte que sale, pasado por el banco de casillas de (0xE661): cinco codigos -0xE1, 0xEC, 0xE8, 0xE6 y 0xE5- bajan 0x50, y otros 0x50 mas si esta el bit 1
	ld a,(0e661h)		;443b   ; el banco de casillas de esta fase
	or a			;443e
	ld a,(de)			;443f   ; el byte que sale del guion
	inc de			;4440
	jr z,espeja_si_toca		;4441   ; sin banco, no se traduce
	cp 0e1h		;4443   ; los cinco codigos que se traducen
	jr z,L_4456		;4445
	cp 0ech		;4447
	jr z,L_4456		;4449
	cp 0e8h		;444b
	jr z,L_4456		;444d
	cp 0e6h		;444f
	jr z,L_4456		;4451
	cp 0e5h		;4453
	ret nz			;4455
L_4456:
	sub 050h		;4456   ; los cinco codigos bajan 0x50
	ex af,af'			;4458
	ld a,(0e661h)		;4459
	push bc			;445c
	ld b,a			;445d
	ex af,af'			;445e
	bit 1,b		;445f   ; y con el bit 1 del banco, otros 0x50
	pop bc			;4461
	ret z			;4462
	sub 050h		;4463
	ret			;4465
espeja_si_toca:
	bit 0,c		;4466   ; y con c a uno, el byte sale del reves
	ret z			;4468
vuelve_los_bits:		; Da la vuelta a los ocho bits de A
	push bc			;4469   ; los ocho bits, al reves
	ld c,a			;446a
	ld b,008h		;446b
L_446D:
	rr c		;446d
	rla			;446f
	djnz L_446D		;4470
	pop bc			;4472
	ret			;4473
descomprime_espejado:
	ld c,001h		;4474   ; espejado
	jr descomprime_en_hl		;4476
espeja_sprites:
	call espeja_un_sprite		;4478   ; uno
	ld a,020h		;447b   ; y el siguiente, 32 bytes mas alla
	call suma_a_a_de		;447d
	dec c			;4480
	jr nz,espeja_sprites		;4481
	ret			;4483
espeja_un_sprite:
	push de			;4484   ; dieciseis filas de golpe
L_4485:
	ld b,010h		;4485
L_4487:
	call 0004ah		;4487   ; BIOS RDVRM - Reads the content of VRAM | lee de la VRAM
	call vuelve_los_bits		;448a   ; le da la vuelta a los ocho bits
	ex de,hl			;448d
	call 0004dh		;448e   ; BIOS WRTVRM - Writes data in VRAM | y la escribe en el destino
	ex de,hl			;4491
	inc e			;4492
	inc hl			;4493
	djnz L_4487		;4494
	ld a,e			;4496
	sub 020h		;4497
	ld e,a			;4499
	bit 4,e		;449a   ; el bit 4 dice cuando se han hecho las dos mitades
	jr z,L_4485		;449c
	pop de			;449e
	ret			;449f
arranca_la_pantalla:
	ld a,0b8h		;44a0   ; borde 0xB8
	call escribe_el_mezclador		;44a2
	ld a,03dh		;44a5   ; y la primera pieza
	call suena_con_pantalla_apagada		;44a7
	ld hl,00000h		;44aa   ; borra los 16 KB de VRAM enteros
	ld bc,04000h		;44ad
	xor a			;44b0
	call 00056h		;44b1   ; BIOS FILVRM - Fills VRAM with value
pon_los_registros_del_vdp:
	ld hl,044c5h		;44b4   ; la tabla de ocho registros
	ld d,008h		;44b7
	ld c,000h		;44b9
L_44BB:
	ld b,(hl)			;44bb
	call 00047h		;44bc   ; BIOS WRTVDP - Writes data in the VDP-register
	inc hl			;44bf
	inc c			;44c0
	dec d			;44c1
	jr nz,L_44BB		;44c2
	ret			;44c4

; ----------------------------------------------------------------------
; DATOS registros_del_vdp: Los ocho valores de R0 a R7. R3=0x7F y R4=0x07
;   ponen los COLORES en 0x0000 y los PATRONES en 0x2000, o sea al reves de lo
;   corriente; los nombres en 0x3800, los sprites en 0x1800 y sus atributos en
;   0x3B00
;   0x44c5..0x44cd  (8 bytes)
DATA_registros_del_vdp:
	defb 002h,0e2h,00eh,07fh,007h,076h,003h,0e4h	; 44c5  .....v..

; ======================================================================
; CODIGO 0x44cd..0x4518  (75 bytes)
; ======================================================================


pon_registro_7:
	ld c,007h		;44cd   ; el registro 7 lleva el borde en el nibble bajo
	jp pon_registro_del_vdp		;44cf
lee_los_mandos:
	call lee_mando_y_teclado		;44d2   ; lo que hay pulsado
guarda_lo_recien_pulsado:
	ld hl,0e009h		;44d5   ; aqui se entra tambien DESDE LA DEMOSTRACION
guarda_lo_recien_pulsado_en_hl:		; (hl) queda con lo que hay pulsado y (hl-1) con lo que ACABA de pulsarse
	ld c,(hl)			;44d8   ; lo de antes
	ld (hl),a			;44d9
	xor c			;44da   ; lo que ha cambiado
	and (hl)			;44db   ; y de eso, lo que se acaba de PULSAR
	dec hl			;44dc
	ld (hl),a			;44dd
	ret			;44de
lee_mando_y_teclado:		; Junta el mando del PSG con las filas 7 y 8 del teclado en un solo byte
	ld e,08fh		;44df   ; 0x8F selecciona el puerto A del PSG como entrada
	ld a,00fh		;44e1
	call 00093h		;44e3   ; BIOS WRTPSG - Writes data to PSG-register
	ld a,00eh		;44e6   ; y el registro 14 trae el mando
	di			;44e8
	call 00096h		;44e9   ; BIOS RDPSG - Reads value from PSG-register
	ei			;44ec
	cpl			;44ed   ; el mando da los bits al reves
	and 03fh		;44ee
	push af			;44f0
	ld a,007h		;44f1   ; fila 7 del teclado
	call 00141h		;44f3   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix
	cpl			;44f6
	rrca			;44f7
	and 020h		;44f8
	ld e,a			;44fa
	ld a,008h		;44fb   ; fila 8
	call 00141h		;44fd   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix
	cpl			;4500
	rrca			;4501
	rrca			;4502
	ld b,a			;4503
	and 004h		;4504   ; el bit 2: izquierda
	or e			;4506
	ld c,a			;4507
	ld a,b			;4508
	rrca			;4509
	rrca			;450a
	ld b,a			;450b
	and 018h		;450c   ; los bits 3 y 4: derecha y disparo
	or c			;450e
	ld c,a			;450f
	ld a,b			;4510
	rrca			;4511
	and 003h		;4512   ; y los dos ultimos
	or c			;4514
	pop bc			;4515
	or b			;4516   ; y las dos cosas se juntan en el mismo byte
	ret			;4517

; ----------------------------------------------------------------------
; DATOS fondo_de_la_presentacion: Bloque comprimido para la tabla de nombres
;   desde 0x394A: el cartel de KONAMI que baja
;   0x4518..0x4529  (17 bytes)
DATA_fondo_de_la_presentacion:
	defb 04ah,039h,00ch,05ah,080h,06ch,039h,088h,024h,022h,027h,025h,02dh,01bh,023h,01dh	; 4518  J9.Z.l9.$"'%-.#.
	defb 000h	; 4528

; ----------------------------------------------------------------------
; DATOS rotulos_del_titulo: KNIGHTMARE en la fila 4, (c)KONAMI 1986 en la 12 y
;   PUSH SPACE KEY en la 16; los codigos son casillas de la fuente, no ASCII
;   (tools/guiones.py)
;   0x4529..0x4556  (45 bytes)
DATA_rotulos_del_titulo:
	defb 08bh,038h,028h,02ah,020h,01eh,01fh,025h,021h,01bh,023h,01dh,0feh,08ah,039h,01ah	; 4529  .8(* ..%!.#...9.
	defb 028h,022h,02ah,01bh,021h,020h,000h,011h,019h,018h,016h,0feh,009h,03ah,02bh,02ch	; 4539  ("*.! .......:+,
	defb 024h,01fh,000h,024h,02bh,01bh,01ch,01dh,000h,028h,01dh,02eh,0ffh	; 4549  $..$+....(...

; ----------------------------------------------------------------------
; DATOS rotulo_play_start: PLAY START, encima de donde estaba el PUSH SPACE
;   KEY
;   0x4556..0x4567  (17 bytes)
DATA_rotulo_play_start:
	defb 009h,03ah,000h,000h,02bh,029h,01bh,02eh,000h,024h,025h,01bh,023h,025h,000h,000h	; 4556  .:..+)...$%.#%..
	defb 0ffh	; 4566

; ----------------------------------------------------------------------
; DATOS rotulos_del_marcador: SCORE, HISCORE, REST y STAGE, los cuatro de la
;   fila 22
;   0x4567..0x4588  (33 bytes)
DATA_rotulos_del_marcador:
	defb 0cah,03ah,01fh,020h,024h,01ch,022h,023h,01dh,0feh,0c3h,03ah,024h,01ch,022h,023h	; 4567  .:. $."#...:$."#
	defb 01dh,0feh,0d3h,03ah,023h,01dh,024h,025h,0feh,0d9h,03ah,024h,025h,01bh,01eh,01dh	; 4577  ...:#.$%..:$%...
	defb 0ffh	; 4587

; ----------------------------------------------------------------------
; DATOS rotulo_game_over: GAME OVER en la fila 9
;   0x4588..0x4595  (13 bytes)
DATA_rotulo_game_over:
	defb 02bh,039h,01eh,01bh,021h,01dh,000h,000h,022h,026h,01dh,023h,0ffh	; 4588  +9..!..."&.#.

; ======================================================================
; CODIGO 0x4595..0x45c9  (52 bytes)
; ======================================================================


limpia_la_fuente:		; Casillas 0x00 a 0x0F: patron a cero y color 0..15, o sea dieciseis cuadros macizos
	ld hl,02000h		;4595   ; las dieciseis primeras casillas
	ld bc,00080h		;4598
	xor a			;459b
	call rellena_los_tres_bancos		;459c   ; a cero
	ld hl,00000h		;459f   ; y su color, uno distinto cada una
	ld de,00008h		;45a2
	ld b,010h		;45a5
L_45A7:
	push bc			;45a7
	ld bc,00008h		;45a8   ; ocho bytes por casilla
	push hl			;45ab
	call rellena_los_tres_bancos		;45ac
	pop hl			;45af
	add hl,de			;45b0   ; y a la casilla siguiente
	inc a			;45b1
	pop bc			;45b2
	djnz L_45A7		;45b3
monta_la_fuente:		; Las 35 casillas de la fuente en los tres bancos, en blanco sobre transparente
	ld de,045c9h		;45b5   ; la fuente
	ld hl,02080h		;45b8   ; a la casilla 0x10
	call descomprime_en_los_tres_bancos		;45bb
	ld a,0f0h		;45be   ; blanco sobre transparente
	ld hl,00080h		;45c0
	ld bc,00118h		;45c3   ; las 35 casillas de la fuente
	jp rellena_los_tres_bancos		;45c6

; ----------------------------------------------------------------------
; DATOS fuente: Comprimida; 280 bytes = 35 casillas, que es justo el 0x118 del
;   relleno de color de 0x45C3. En orden: las diez cifras, el simbolo de
;   copyright, las doce letras mas usadas en orden alfabetico (A C E G H I M O
;   R S T V), las ocho que faltaban (F K L N P U W Y) tambien en orden, y al
;   final punto, D, cierre de exclamacion y B
;   0x45c9..0x46cf  (262 bytes)
DATA_fuente:
	defb 083h,000h,01ch,022h,003h,063h,085h,022h,01ch,000h,018h,038h,004h,018h,0aeh,07eh	; 45c9  ...".c."...8...~
	defb 000h,03eh,063h,003h,00eh,03ch,070h,07fh,000h,03eh,063h,003h,00eh,003h,063h,03eh	; 45d9  .>c..<p..>c...c>
	defb 000h,00eh,01eh,036h,066h,066h,07fh,006h,000h,07fh,060h,07eh,063h,003h,063h,03eh	; 45e9  ...6ff....`~c.c>
	defb 000h,03eh,063h,060h,07eh,063h,063h,03eh,000h,07fh,063h,006h,00ch,003h,018h,0a3h	; 45f9  .>c`~cc>..c.....
	defb 000h,03eh,063h,063h,03eh,063h,063h,03eh,000h,03eh,063h,063h,03fh,003h,063h,03eh	; 4609  .>cc>cc>.>cc?.c>
	defb 03ch,042h,099h,0a1h,0a1h,099h,042h,03ch,000h,01ch,036h,063h,063h,07fh,063h,063h	; 4619  <B....B<..6cc.cc
	defb 000h,03eh,063h,003h,060h,093h,063h,03eh,000h,07fh,060h,060h,07eh,060h,060h,07fh	; 4629  .>c.`.c>..``~``.
	defb 000h,03eh,063h,060h,067h,063h,063h,03fh,000h,003h,063h,081h,07fh,003h,063h,082h	; 4639  .>c`gcc?..c...c.
	defb 000h,03ch,005h,018h,08bh,03ch,000h,063h,077h,07fh,07fh,06bh,063h,063h,000h,03eh	; 4649  .<...<.cw..kcc.>
	defb 005h,063h,093h,03eh,000h,07eh,063h,063h,062h,07ch,066h,063h,000h,03eh,063h,060h	; 4659  .c.>.~ccb|fc.>c`
	defb 03eh,003h,063h,03eh,000h,07eh,006h,018h,081h,000h,004h,063h,088h,036h,01ch,008h	; 4669  >.c>.~.....c.6..
	defb 000h,07fh,060h,060h,07eh,003h,060h,089h,000h,063h,066h,06ch,078h,07ch,06eh,067h	; 4679  ..``~.`..cflx|ng
	defb 000h,006h,060h,08bh,07fh,000h,063h,073h,07bh,07fh,06fh,067h,063h,000h,07eh,003h	; 4689  ..`...cs{.ogc.~.
	defb 063h,084h,07eh,060h,060h,000h,006h,063h,08eh,03eh,000h,063h,063h,06bh,06bh,07fh	; 4699  c.~``..c.>.cckk.
	defb 077h,022h,000h,066h,066h,07eh,03ch,003h,018h,006h,000h,002h,018h,083h,000h,07ch	; 46a9  w".ff~<........|
	defb 066h,003h,063h,083h,066h,07ch,000h,004h,018h,08bh,000h,018h,018h,000h,07eh,063h	; 46b9  f.c.f|........~c
	defb 063h,07eh,063h,063h,07eh,000h	; 46c9

; ======================================================================
; CODIGO 0x46cf..0x4723  (84 bytes)
; ======================================================================


arranca_la_presentacion:		; Catorce pasos y el cartel arrancando en 0x3AAA
	ld a,00eh		;46cf   ; catorce pasos
	ld (0e00ah),a		;46d1
	ld hl,03aaah		;46d4   ; empezando por la ultima fila
	ld (0e00eh),hl		;46d7
	jp prepara_el_titulo		;46da
monta_el_cartel:
	ld de,04723h		;46dd
	ld hl,06200h		;46e0   ; en los tres bancos desde 0x6200, que es 0x2200 con el bit 14 puesto
	call descomprime_en_los_tres_bancos		;46e3
	ld hl,00200h		;46e6   ; y su color
	ld bc,000d8h		;46e9
	ld a,0f0h		;46ec   ; blanco sobre negro
	jp rellena_los_tres_bancos		;46ee
baja_un_paso:
	ld hl,(0e00eh)		;46f1   ; por donde va el cartel
	ld de,0ffe0h		;46f4   ; una fila menos: 0x20 casillas hacia atras
	add hl,de			;46f7
	ld (0e00eh),hl		;46f8
	ld a,040h		;46fb   ; la casilla 0x40, tres seguidas
	ld b,003h		;46fd
	call escribe_seguidas_subiendo		;46ff
	ld bc,00b0ch		;4702   ; luego once desde la 0x0C
	call escribe_seguidas_subiendo		;4705
	ld b,c			;4708
	call escribe_seguidas_subiendo		;4709
	xor a			;470c   ; y lo que queda de fila, a cero
	call 00056h		;470d   ; BIOS FILVRM - Fills VRAM with value
	ld hl,0e00ah		;4710   ; un paso menos
	dec (hl)			;4713
	ret			;4714
escribe_seguidas_subiendo:
	push hl			;4715
L_4716:
	call 0004dh		;4716   ; BIOS WRTVRM - Writes data in VRAM | casilla
	inc hl			;4719
	inc a			;471a   ; y la siguiente, una mas
	djnz L_4716		;471b
	pop de			;471d
	ld hl,00020h		;471e   ; al acabar, se baja una fila
	add hl,de			;4721
	ret			;4722

; ----------------------------------------------------------------------
; DATOS cartel_de_konami: Comprimido; los patrones del logotipo de KONAMI y el
;   simbolo de copyright, a 0x2200 en los tres bancos
;   0x4723..0x47ba  (151 bytes)
DATA_cartel_de_konami:
	defb 00fh,000h,001h,001h,006h,000h,082h,0ffh,0feh,008h,00fh,084h,0c3h,0c7h,0cfh,0dfh	; 4723  ................
	defb 003h,0ffh,089h,0feh,0fch,0f8h,0f0h,0e0h,0c0h,080h,007h,007h,005h,000h,083h,003h	; 4733  ................
	defb 0cfh,0dfh,005h,000h,083h,0e1h,0f9h,07dh,005h,000h,083h,0efh,0ffh,0f7h,005h,000h	; 4743  .......}........
	defb 083h,007h,08fh,09eh,005h,000h,083h,0f0h,0f8h,078h,005h,000h,083h,0f7h,0ffh,0fbh	; 4753  .........x......
	defb 005h,000h,08bh,08fh,0dfh,0f7h,00ch,01eh,01eh,00ch,000h,01eh,09eh,09eh,008h,00fh	; 4763  ................
	defb 090h,0ffh,0ffh,0dfh,0cfh,0c7h,0c3h,0c1h,0c0h,007h,087h,0c7h,0efh,0ffh,0ffh,0ffh	; 4773  ................
	defb 0fch,004h,0deh,084h,09eh,09fh,00fh,003h,005h,03dh,083h,07dh,0f9h,0e1h,008h,0e3h	; 4783  .........=.}....
	defb 090h,0dch,0c0h,0c7h,0deh,0dch,0deh,0cfh,0c3h,03ch,07ch,0fch,03ch,03ch,07ch,0fch	; 4793  .........<|.<<|.
	defb 0deh,008h,0f1h,008h,0e3h,008h,0deh,088h,038h,044h,0bah,0aah,0b2h,0aah,044h,038h	; 47a3  ........8D....D8
	defb 003h,000h,001h,0ffh,004h,000h,000h	; 47b3

; ======================================================================
; CODIGO 0x47ba..0x47f6  (60 bytes)
; ======================================================================


monta_el_titulo:
	ld b,0e0h		;47ba
	call pon_registro_7		;47bc   ; borde negro
	call limpia_sprites_y_nombres		;47bf   ; borra las 768 casillas
	call monta_la_fuente		;47c2
	ld hl,02300h		;47c5   ; los patrones del rotulo, en los tres bancos desde 0x2300
	ld de,047f6h		;47c8
	call descomprime_en_los_tres_bancos		;47cb
	ld hl,00300h		;47ce   ; y su color, desde 0x0300
	ld de,048fah		;47d1
	call descomprime_en_los_tres_bancos		;47d4
	ld hl,038cbh		;47d7   ; la tabla de nombres, en 0x38CB
	ld de,00020h		;47da
	ld a,060h		;47dd   ; desde la casilla 0x60
	ld c,003h		;47df   ; tres filas
L_47E1:
	ld b,00bh		;47e1   ; de once casillas
	push hl			;47e3
L_47E4:
	call 0004dh		;47e4   ; BIOS WRTVRM - Writes data in VRAM
	inc hl			;47e7
	inc a			;47e8
	djnz L_47E4		;47e9
	pop hl			;47eb
	add hl,de			;47ec
	dec c			;47ed
	jr nz,L_47E1		;47ee
	ld de,04529h		;47f0   ; y el rotulo del titulo
	jp pinta_texto		;47f3

; ----------------------------------------------------------------------
; DATOS rotulo_knightmare: Comprimido; los patrones del rotulo del titulo, a
;   0x2300 en los tres bancos
;   0x47f6..0x48fa  (260 bytes)
DATA_rotulo_knightmare:
	defb 002h,000h,096h,006h,00fh,01fh,01fh,01eh,00eh,01ch,01eh,00fh,0ffh,0ffh,030h,0fbh	; 47f6  ..............0.
	defb 0f1h,000h,000h,038h,0fch,0fch,060h,0fch,0fch,005h,000h,083h,070h,078h,039h,003h	; 4806  ...8..`.....px9.
	defb 000h,085h,018h,03ch,01ch,01dh,0bfh,005h,000h,08bh,0e0h,070h,0b1h,000h,000h,020h	; 4816  ...<.......p... 
	defb 030h,070h,071h,0e3h,0e7h,005h,000h,08bh,080h,0feh,0ffh,000h,006h,00eh,00fh,007h	; 4826  0pq.............
	defb 003h,006h,0bfh,003h,000h,08fh,00ch,09eh,01eh,00fh,0c7h,000h,070h,078h,07ch,0fch	; 4836  ............px|.
	defb 0fch,0f8h,0e0h,00fh,00fh,003h,00eh,002h,01eh,0d1h,03eh,0f9h,0b6h,00fh,07fh,0e6h	; 4846  ..........>.....
	defb 0dfh,0ceh,0ffh,078h,07ch,0ech,0f1h,039h,0bch,07ch,078h,031h,03bh,0fbh,0f9h,0f1h	; 4856  ...x|..9.|x1;...
	defb 0b1h,031h,03dh,0ffh,0dfh,08eh,0eeh,0feh,0ffh,0f7h,0b7h,0c7h,0cfh,00fh,00fh,0efh	; 4866  .1=.............
	defb 0edh,0d9h,083h,0c7h,0c3h,0c0h,0cfh,0dfh,0cfh,0e3h,0efh,0ffh,080h,067h,0ffh,0ffh	; 4876  .............g..
	defb 09bh,080h,00ch,09fh,000h,09fh,0cfh,0c0h,09fh,007h,019h,09fh,01fh,018h,09ch,039h	; 4886  ...............9
	defb 0bfh,01eh,00ch,0f8h,07ch,038h,038h,0bch,0fch,0f9h,0c2h,003h,07ch,0d0h,07bh,077h	; 4896  ....|88.....|.{w
	defb 077h,027h,000h,0f9h,075h,076h,0eeh,0eeh,09fh,01fh,003h,0f0h,0b8h,0e1h,0ddh,03ch	; 48a6  w'..uv.........<
	defb 0feh,0ffh,0c6h,0fbh,0f3h,0e7h,0e7h,0ceh,01eh,03ch,000h,0b7h,0b7h,0efh,0edh,0d9h	; 48b6  .........<......
	defb 0d0h,000h,000h,083h,0c3h,0f7h,0f7h,0fbh,0fbh,07bh,038h,0ceh,0deh,0dfh,09fh,09fh	; 48c6  .........{8.....
	defb 08fh,000h,000h,006h,007h,0ffh,0ffh,0f3h,003h,001h,000h,01fh,09fh,0cch,0ddh,0dfh	; 48d6  ................
	defb 0dfh,08ch,000h,08dh,0cbh,0dbh,0dbh,0bbh,077h,073h,000h,084h,08ch,09eh,003h,0feh	; 48e6  ........ws......
	defb 082h,0fch,038h,000h	; 48f6

; ----------------------------------------------------------------------
; DATOS color_del_rotulo: Comprimido; 0x7F + 0x7F + 0x0A = 264 bytes de 0x81,
;   que son las 33 casillas del rotulo (11 x 3) en rojo sobre negro
;   0x48fa..0x4901  (7 bytes)
DATA_color_del_rotulo:
	defb 07fh,081h,07fh,081h,00ah,081h,000h	; 48fa

; ======================================================================
; CODIGO 0x4901..0x4b2c  (555 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; PEDIR UNA PIEZA
; ----------------------------------------------------------------------
pide_pieza_si_la_escena_lo_permite:
	di			;4901   ; aqui solo suena si la escena lo permite
	push hl			;4902
	ld hl,0e002h		;4903
	bit 6,(hl)		;4906   ; el bit 6 de (0xE002) es el que deja sonar: sin el, no se pide nada
	jr z,L_4976		;4908
	jr L_490E		;490a
pide_pieza:
	di			;490c   ; esta es la puerta de al lado, la que suena pase lo que pase
	push hl			;490d
L_490E:
	push de			;490e
	push bc			;490f
	push af			;4910
	ld c,a			;4911   ; el numero de pieza
	ld d,03fh		;4912   ; el numero de pieza cabe en seis bits
	and d			;4914
	ld b,002h		;4915   ; dos voces por defecto
	ld hl,0e02eh		;4917   ; y la tercera voz, 0xE02C, como primera
	cp 01dh		;491a   ; los efectos por debajo de 0x1D van a la tercera voz
	jr c,L_492B		;491c
	cp 025h		;491e
	ld hl,0e012h		;4920   ; y de 0x1D a 0x24, a la segunda
	jr c,L_4946		;4923
	ld hl,0e012h		;4925
	inc b			;4928   ; de 0x25 arriba son piezas de tres voces
	jr L_4946		;4929
L_492B:
	dec b			;492b
	cp 018h		;492c   ; los efectos de 0x18 y 0x19 van a la segunda voz
	jr c,L_493A		;492e
	ld hl,0e012h		;4930
	cp 01ah		;4933
	jr c,L_493A		;4935
	ld hl,0e020h		;4937
L_493A:
	ld a,c			;493a
	or a			;493b
	jp m,L_494E		;493c
	ld a,(0e600h)		;493f   ; con (0xE600) a 2 no se interrumpe lo que suena
	cp 002h		;4942
	jr z,L_4973		;4944
L_4946:
	ld a,(hl)			;4946   ; y si no, solo entra la pieza si pesa mas que la que hay: el numero de pieza hace de prioridad
	and d			;4947
	ld e,a			;4948
	ld a,c			;4949
	and d			;494a
	cp e			;494b
	jr c,L_4973		;494c
L_494E:
	and d			;494e
	add a,a			;494f
	ld de,04b36h		;4950   ; 0x4B36 es la tabla de punteros de voz MENOS DOS: la pieza 1 es la primera entrada, no hay pieza 0
	call suma_a_a_de		;4953
	dec hl			;4956
	dec hl			;4957
arranca_una_voz:
	ld (hl),001h		;4958   ; el contador a uno: la voz suena en el cuadro siguiente
	inc hl			;495a
	inc hl			;495b
	ld (hl),c			;495c   ; el numero de pieza, que es tambien su peso
	inc hl			;495d
	ld a,(de)			;495e   ; el puntero al guion
	ld (hl),a			;495f
	inc hl			;4960
	inc de			;4961
	ld a,(de)			;4962
	ld (hl),a			;4963
	ld a,005h		;4964   ; cinco bytes mas alla
	call suma_a_a_hl		;4966
	xor a			;4969
	ld (hl),a			;496a   ; las vueltas del repetidor, a cero
	ld a,005h		;496b
	call suma_a_a_hl		;496d
	inc de			;4970   ; las voces de una pieza van seguidas en la tabla
	djnz arranca_una_voz		;4971   ; dos o tres
L_4973:
	pop af			;4973   ; y si no, se sale sin tocar nada
	pop bc			;4974
	pop de			;4975
L_4976:
	pop hl			;4976
	ei			;4977
	ret			;4978

; ----------------------------------------------------------------------
; EL 0xFE DEL GUION: repetir un trozo
; ----------------------------------------------------------------------
repite_un_trozo:
	inc hl			;4979
	ld a,(ix+009h)		;497a   ; cuantas vueltas lleva
	inc a			;497d
	cp (hl)			;497e   ; contra las que pide el guion
	jr z,L_4994		;497f   ; si ya estan hechas, se sigue de largo
	jp m,L_4985		;4981   ; el 0x00 quiere decir para siempre
	dec a			;4984
L_4985:
	ld (ix+009h),a		;4985
	inc hl			;4988   ; y si no, se vuelve a la direccion que trae el guion
	ld a,(hl)			;4989
	ld (ix+003h),a		;498a
	inc hl			;498d
	ld a,(hl)			;498e
	ld (ix+004h),a		;498f
	jr L_499D		;4992
L_4994:
	inc hl			;4994   ; dos bytes de la orden
	inc hl			;4995
	xor a			;4996
	ld (ix+009h),a		;4997   ; la cuenta se reinicia
	call avanza_el_guion		;499a
L_499D:
	inc (ix+000h)		;499d
	jr sigue_el_guion		;49a0

; ----------------------------------------------------------------------
; EL MEZCLADOR. OJO: los bits que toca son el 3, el 4 y el 5, o sea los
; del RUIDO, no los del tono. La copia del registro 7 (0xE03A) arranca a
; cero con el borrado de 0x40AC, y este es el UNICO sitio del cartucho
; que escribe el registro 7, asi que el tono de las tres voces queda
; abierto de principio a fin: para callar una voz se le baja el volumen,
; no se cierra aqui.
; Y el sentido de D es el contrario del que parece: el `dec d` manda al
; `or e` con D=1, y el registro 7 del PSG va al reves, asi que con D=1
; el bit se PONE y el ruido se APAGA.
; ----------------------------------------------------------------------
enciende_o_apaga_el_ruido:
	ld a,(0e03ah)		;49a2   ; la copia del registro 7
	ld e,a			;49a5
	ld a,c			;49a6   ; c es 1, 3 o 5: la voz
	cp 001h		;49a7
	jr z,L_49AC		;49a9
	dec a			;49ab
L_49AC:
	rlca			;49ac   ; tres rotaciones dejan 0x08, 0x10 o 0x20, los bits de RUIDO
	rlca			;49ad
	rlca			;49ae
	dec d			;49af   ; con D a uno...
	jr z,L_49B6		;49b0
	cpl			;49b2   ; el bit se quita y el ruido suena
	and e			;49b3
	jr escribe_el_mezclador		;49b4
L_49B6:
	or e			;49b6   ; ...el bit se pone y el ruido calla
escribe_el_mezclador:
	ld (0e03ah),a		;49b7
	ld e,a			;49ba
	ld a,007h		;49bb   ; el registro 7 del PSG es el mezclador
	jp 00093h		;49bd   ; BIOS WRTPSG - Writes data to PSG-register

; ----------------------------------------------------------------------
; EL SONIDO DE CADA CUADRO
; ----------------------------------------------------------------------
suena_el_cuadro:
	ld a,(0e03ah)		;49c0   ; primero el mezclador, tal como quedo
	call escribe_el_mezclador		;49c3
	ld c,001h		;49c6   ; la voz A, que en el PSG es el registro 1
	ld ix,0e010h		;49c8   ; y su bloque de catorce bytes
	exx			;49cc
	ld b,003h		;49cd   ; tres voces
	ld de,0000eh		;49cf   ; catorce bytes de una a otra
L_49D2:
	exx			;49d2
	ld a,(ix+002h)		;49d3   ; si la voz esta callada
	or a			;49d6
	jr nz,L_49DE		;49d7
	call apaga_la_voz_y_dejala_libre		;49d9   ; se apaga
	jr L_49E1		;49dc
L_49DE:
	call calla_la_voz_si_lo_pide_la_orden		;49de   ; y si no, suena
L_49E1:
	inc c			;49e1   ; c va 1, 3, 5: son los registros de periodo de las tres voces
	inc c			;49e2
	exx			;49e3
	add ix,de		;49e4   ; y ix salta al siguiente bloque
	djnz L_49D2		;49e6
	ret			;49e8
calla_la_voz_si_lo_pide_la_orden:
	bit 6,a		;49e9
	ld d,001h		;49eb
	call z,enciende_o_apaga_el_ruido		;49ed
sigue_el_guion:
	ld a,(ix+002h)		;49f0   ; el estado de la voz
	or a			;49f3
	jp m,envolvente		;49f4   ; con el bit 7 puesto, la envolvente
	dec (ix+000h)		;49f7   ; la nota sigue sonando: solo baja el contador
	ret nz			;49fa
paso_del_guion:
	ld l,(ix+003h)		;49fb   ; y cuando llega a cero, el guion da el siguiente paso
	ld h,(ix+004h)		;49fe
	ld a,(hl)			;4a01
	cp 0feh		;4a02   ; 0xFE: repetir un trozo
	jp z,repite_un_trozo		;4a04
	jp nc,apaga_la_voz_y_dejala_libre		;4a07   ; 0xFF: se acabo la voz
	bit 7,(ix+002h)		;4a0a   ; con el bit 7 puesto, lo que viene es una orden larga
	jp nz,orden_larga		;4a0e
	and 0f0h		;4a11   ; el nibble alto de la orden
	cp 020h		;4a13   ; 0x2n fija la duracion de las notas que siguen
	jr nz,L_4A1E		;4a15
	ld a,(hl)			;4a17   ; 0x2n: la duracion de las notas
	and 00fh		;4a18
	ld (ix+001h),a		;4a1a
	inc hl			;4a1d
L_4A1E:
	ld a,(hl)			;4a1e
	and 0f0h		;4a1f
	cp 010h		;4a21   ; 0x1n fija el ruido: el registro 6 del PSG y el ruido abierto en el mezclador
	jr nz,L_4A35		;4a23
	ld a,(hl)			;4a25   ; 0x1n: el ruido
	and 00fh		;4a26
	add a,a			;4a28
	ld e,a			;4a29
	ld a,006h		;4a2a
	call 00093h		;4a2c   ; BIOS WRTPSG - Writes data to PSG-register | el registro 6 del PSG es el periodo del ruido
	ld d,000h		;4a2f
	call enciende_o_apaga_el_ruido		;4a31   ; y con D=0 se abre el ruido de esa voz en el mezclador
	inc hl			;4a34
L_4A35:
	ld a,(hl)			;4a35

; ----------------------------------------------------------------------
; LA NOTA
; ----------------------------------------------------------------------
toca_la_nota:
	and 0f0h		;4a36   ; el nibble alto es el semitono
	ld b,a			;4a38
	xor (hl)			;4a39   ; lo que queda es el semitono
	ld d,a			;4a3a
	inc hl			;4a3b
	ld e,(hl)			;4a3c   ; y detras va el segundo byte de la nota
	call avanza_el_guion		;4a3d   ; y el byte siguiente
	ex de,hl			;4a40
	call pon_el_periodo		;4a41   ; se escribe el periodo en el PSG
	ld a,b			;4a44
	rrca			;4a45   ; el nibble bajo, bajado
	rrca			;4a46
	rrca			;4a47
	rrca			;4a48
L_4A49:
	ld h,a			;4a49
	ld e,(ix+001h)		;4a4a   ; la duracion que fijo el 0x2n
	ld (ix+000h),e		;4a4d
	ld a,(ix+00ch)		;4a50   ; mas el ataque
	add a,e			;4a53
	ld (ix+008h),a		;4a54   ; en el contador de la envolvente
	jr escribe_el_volumen		;4a57

; ----------------------------------------------------------------------
; CALLAR LA VOZ Y DEJARLA LIBRE
; ----------------------------------------------------------------------
apaga_la_voz_y_dejala_libre:
	ld d,001h		;4a59
	call enciende_o_apaga_el_ruido		;4a5b   ; con D=1: se cierra el ruido de esa voz
	xor a			;4a5e
	ld (ix+002h),a		;4a5f   ; y la voz queda libre
	ld (ix+00bh),a		;4a62
	ld h,a			;4a65
	jr escribe_el_volumen		;4a66

; ----------------------------------------------------------------------
; LA ENVOLVENTE
; ----------------------------------------------------------------------
envolvente:
	dec (ix+000h)		;4a68   ; la nota se acaba
	jp z,paso_del_guion		;4a6b   ; al llegar a cero, el guion sigue
	dec (ix+008h)		;4a6e   ; el volumen baja
	ld a,(ix+008h)		;4a71
	cp (ix+000h)		;4a74   ; hasta el sostenido
	jr nz,L_4A82		;4a77
	ld e,a			;4a79
	ld a,(ix+00dh)		;4a7a   ; y de ahi, la caida
	cp e			;4a7d
	ld a,e			;4a7e
	jr nc,L_4A85		;4a7f
	ret			;4a81
L_4A82:
	dec (ix+008h)		;4a82
L_4A85:
	ld a,(ix+007h)		;4a85   ; el volumen de ahora
	dec a			;4a88   ; uno menos cada vez
	ret m			;4a89   ; y por debajo de cero, nada
	ld (ix+007h),a		;4a8a
	ld h,a			;4a8d
escribe_el_volumen:
	ld a,c			;4a8e   ; c es 1, 3 o 5
	rrca			;4a8f   ; una rotacion y sumar 0x88 los convierte en los registros 8, 9 y 10, que son los tres volumenes: un truco para no llevar tabla
	add a,088h		;4a90
	ld e,h			;4a92
	jp 00093h		;4a93   ; BIOS WRTPSG - Writes data to PSG-register | el registro de volumen de esa voz

; ----------------------------------------------------------------------
; LAS ORDENES LARGAS
; ----------------------------------------------------------------------
orden_larga:
	ld a,(hl)			;4a96
	and 0f0h		;4a97   ; 0xDn fija el paso del volumen
	cp 0d0h		;4a99
	ld a,(hl)			;4a9b
	jr nz,L_4AA5		;4a9c
	and 00fh		;4a9e
	ld (ix+00ah),a		;4aa0   ; el paso, en el nibble bajo
	inc hl			;4aa3
	ld a,(hl)			;4aa4
L_4AA5:
	cp 0f0h		;4aa5   ; 0xFn, el ataque y el sostenido
	jr c,L_4AC1		;4aa7
	and 00fh		;4aa9
	ld (ix+006h),a		;4aab
	inc hl			;4aae
	ld a,(hl)			;4aaf
	and 00fh		;4ab0   ; el sostenido, en el nibble bajo
	ld (ix+00dh),a		;4ab2
	xor (hl)			;4ab5   ; y el ataque en el alto
	rrca			;4ab6
	rrca			;4ab7
	rrca			;4ab8
	rrca			;4ab9
	and 00fh		;4aba
	ld (ix+00ch),a		;4abc
	inc hl			;4abf
	ld a,(hl)			;4ac0
L_4AC1:
	cp 0e0h		;4ac1   ; 0xEn
	jr c,L_4AD6		;4ac3
	and 00fh		;4ac5
	bit 3,a		;4ac7   ; con el bit 3 puesto es el desafine
	jr z,L_4AD1		;4ac9
	ld (ix+00bh),a		;4acb   ; con el bit 3, el desafine
	inc hl			;4ace
	jr orden_larga		;4acf
L_4AD1:
	ld (ix+005h),a		;4ad1   ; y sin el, la octava
	inc hl			;4ad4
	ld a,(hl)			;4ad5
L_4AD6:
	and 00fh		;4ad6   ; y lo que queda es cuantas veces se suma el paso del volumen
	ld b,a			;4ad8
	ld a,(ix+00ah)		;4ad9
	jr z,L_4AE3		;4adc
L_4ADE:
	add a,(ix+00ah)		;4ade   ; de ahi sale el volumen de arranque
	djnz L_4ADE		;4ae1
L_4AE3:
	ld (ix+001h),a		;4ae3
	ld a,(hl)			;4ae6   ; y detras, ya, la nota
	call avanza_el_guion		;4ae7   ; y el guion avanza
	and 0f0h		;4aea
	rrca			;4aec
	rrca			;4aed
	rrca			;4aee
	rrca			;4aef
	ld b,a			;4af0
	sub 00ch		;4af1   ; el semitono 0x0C deja el volumen a cero: es el silencio
	jr z,L_4AF8		;4af3
	ld a,(ix+006h)		;4af5
L_4AF8:
	ld (ix+007h),a		;4af8
	call L_4A49		;4afb   ; el volumen, escrito
	ld hl,04b2ch		;4afe
	ld a,b			;4b01
	call suma_a_a_hl		;4b02   ; el periodo de esa nota, en la octava mas alta
	ld l,(hl)			;4b05
	ld h,000h		;4b06
	ld a,(ix+005h)		;4b08   ; y la octava
	or a			;4b0b
	jr z,pon_el_periodo		;4b0c
	ld b,a			;4b0e
L_4B0F:
	add hl,hl			;4b0f   ; doblar el periodo es bajar una octava exacta
	djnz L_4B0F		;4b10
pon_el_periodo:
	ld a,(ix+00bh)		;4b12   ; con esto se le suma uno, para desafinar a proposito
	or a			;4b15
	jr z,escribe_las_dos_mitades_del_tono		;4b16
	inc hl			;4b18
escribe_las_dos_mitades_del_tono:
	ld a,c			;4b19   ; c es el registro alto del periodo
	ld e,h			;4b1a
	call 00093h		;4b1b   ; BIOS WRTPSG - Writes data to PSG-register
	ld a,c			;4b1e
	dec a			;4b1f   ; y c-1 el bajo
	ld e,l			;4b20
	jp 00093h		;4b21   ; BIOS WRTPSG - Writes data to PSG-register
avanza_el_guion:
	inc hl			;4b24   ; el guion avanza un byte
	ld (ix+003h),l		;4b25
	ld (ix+004h),h		;4b28   ; y queda apuntado
	ret			;4b2b

; ----------------------------------------------------------------------
; DATOS periodos_de_los_doce_semitonos: Doce bytes, de 0x6B a 0x39: la octava
;   mas alta. Las razones entre uno y el siguiente dan 1,059, que es la raiz
;   doceava de dos; y bajar de octava es doblar el periodo, que es lo que
;   hacen los `add hl,hl` de 0x4B0F
;   0x4b2c..0x4b38  (12 bytes)
DATA_periodos_de_los_doce_semitonos:
	defb 06bh,065h,05fh,05ah,055h,050h,04ch,047h,043h,040h,03ch,039h	; 4b2c  ke_ZUPLGC@<9

; ----------------------------------------------------------------------
; DATOS punteros_de_voz: 63 punteros, uno por VOZ: cada pieza gasta una, dos o
;   tres seguidos. La cuenta de 0x4950 es 0x4B36 + n*2, o sea que la pieza 1
;   es la primera entrada -no hay pieza 0-, y el `and 0x3F` de 0x4914 topa el
;   numero en 63, que es justo el ultimo. Los 63 caen dentro del bloque de
;   guiones, y 55 son distintos: 0x53D2, la voz vacia, se repite en las piezas
;   que gastan menos voces
;   0x4b38..0x4bb6  (126 bytes)
DATA_punteros_de_voz:
	defw 04c11h,04c2fh,04e6eh,04db2h,04e80h,04e94h,04bc4h,04d72h	; 4b38
	defw 04f61h,04bdfh,04dd9h,04dcdh,04c64h,04f73h,04f3fh,04f1dh	; 4b48
	defw 04f37h,04f03h,04c0ah,053d2h,04f49h,04fach,04d48h,04d8fh	; 4b58
	defw 04d9dh,04e1eh,04e08h,053d2h,0518eh,05231h,05073h,050dbh	; 4b68
	defw 04fdbh,053d2h,0500fh,05021h,04ebah,04ed8h,04ef6h,053d2h	; 4b78
	defw 04bb6h,04bb7h,04c88h,04d09h,04ccbh,0515ch,053d2h,05175h	; 4b88
	defw 053d2h,04f7fh,04f80h,0532ch,0535fh,05397h,052c1h,052e7h	; 4b98
	defw 05304h,0526dh,05286h,0529ah,053d2h,053d2h,053d2h	; 4ba8

; ----------------------------------------------------------------------
; DATOS guiones_de_musica: Los guiones que 0x49F0 va leyendo, uno por voz. Los
;   apuntan los 63 punteros de 0x4B38 y no hay ni un byte suelto entre el
;   primero -0x4BB6, el minimo- y el ultimo
;   0x4bb6..0x53d3  (2077 bytes)
DATA_guiones_de_musica:
	defb 0e8h,0d1h,0fbh,088h,0e1h,004h,074h,044h,074h,0fbh,023h,0e0h,009h,0ffh,022h,01eh	; 4bb6  ......tDt.#...".
	defb 0f0h,040h,0d0h,060h,0e0h,060h,022h,016h,0f0h,020h,0e0h,040h,0d0h,020h,0c0h,040h	; 4bc6  .@.`.`".. .@. .@
	defb 0b0h,020h,0a0h,040h,090h,020h,080h,040h,0ffh,021h,0e0h,078h,0d0h,078h,0c0h,078h	; 4bd6  . .@. .@.!.x.x.x
	defb 0b0h,078h,0b0h,079h,0a0h,078h,0d0h,079h,0c0h,079h,0c0h,078h,0b0h,078h,0a0h,078h	; 4be6  .x.y.x.y.y.x.x.x
	defb 090h,078h,023h,0b0h,078h,090h,079h,0a0h,078h,080h,079h,090h,078h,070h,079h,080h	; 4bf6  .x#.x.y.x.y.xpy.
	defb 078h,060h,079h,0ffh,025h,0b0h,040h,02ah,0b0h,080h,0ffh,021h,012h,0a0h,000h,0c0h	; 4c06  x`y.%.@*...!....
	defb 000h,090h,000h,0b0h,000h,016h,090h,000h,0b0h,000h,080h,000h,0a0h,000h,070h,000h	; 4c16  ..............p.
	defb 080h,000h,060h,000h,0feh,00ah,011h,04ch,0ffh,022h,0b0h,01ch,021h,0b0h,019h,0a0h	; 4c26  ..`....L."..!...
	defb 01ch,0a0h,01dh,090h,01dh,090h,01dh,070h,01dh,023h,0a0h,01dh,021h,0a0h,01eh,0a0h	; 4c36  .......p.#..!...
	defb 01eh,000h,000h,0b0h,01ch,0b0h,01ch,0b0h,019h,0a0h,01ch,0a0h,01dh,090h,01dh,090h	; 4c46  ................
	defb 01dh,070h,01dh,023h,0a0h,01dh,022h,0a0h,01eh,0feh,002h,02fh,04ch,0ffh,022h,01fh	; 4c56  .p.#.."..../L.".
	defb 0a3h,059h,01eh,0b2h,002h,01dh,0c1h,0f0h,01eh,0e1h,070h,01fh,0d1h,0d9h,0d2h,002h	; 4c66  .Y........p.....
	defb 0e1h,090h,0f2h,040h,0c1h,0a0h,0b2h,010h,0a2h,03ah,028h,091h,0c0h,082h,04ah,073h	; 4c76  ...@.....:(...Js
	defb 03ah,0ffh,022h,01fh,0b3h,000h,0b1h,050h,0b1h,080h,0b3h,030h,0b1h,040h,0b3h,070h	; 4c86  :."....P...0.@.p
	defb 0a1h,022h,0a3h,010h,091h,080h,0b3h,020h,0b1h,0a0h,0c3h,070h,0c1h,010h,0d3h,000h	; 4c96  ."..... ...p....
	defb 0d1h,000h,0c3h,020h,0c1h,040h,0b3h,030h,0b1h,045h,0b3h,067h,0a1h,020h,0c3h,027h	; 4ca6  ... .@.0.E.g. .'
	defb 0a1h,029h,093h,010h,081h,080h,083h,032h,071h,020h,073h,000h,061h,080h,063h,032h	; 4cb6  .).....2q s.a.c2
	defb 051h,020h,053h,000h,0ffh,022h,01fh,0a2h,0f0h,0a1h,060h,0a3h,010h,0a1h,020h,0a3h	; 4cc6  Q S.."....`... .
	defb 050h,0a1h,002h,0b2h,0f0h,0c1h,060h,0c3h,000h,0c1h,080h,0d3h,050h,0d1h,000h,0e2h	; 4cd6  P.....`.....P...
	defb 0e0h,0e1h,030h,0d3h,000h,0d1h,020h,0c3h,010h,0c1h,032h,0c3h,020h,0b1h,010h,0b3h	; 4ce6  ..0... ...2. ...
	defb 057h,0b1h,021h,0a2h,0f0h,091h,060h,083h,012h,081h,010h,072h,0d0h,073h,012h,061h	; 4cf6  W.!...`....r.s.a
	defb 010h,062h,0d0h,022h,01dh,091h,0f0h,090h,060h,092h,010h,0a1h,020h,0b2h,050h,0c1h	; 4d06  .b."....`... .P.
	defb 002h,091h,0f0h,0a1h,060h,0a2h,000h,0a1h,080h,0b2h,050h,0b1h,000h,0c1h,0e0h,0c1h	; 4d16  ....`.....P.....
	defb 030h,0b2h,000h,0b1h,020h,0a2h,010h,0a1h,032h,0a2h,020h,091h,010h,092h,057h,091h	; 4d26  0... ...2. ...W.
	defb 021h,081h,0f0h,071h,060h,062h,012h,061h,010h,051h,0d0h,052h,012h,051h,010h,051h	; 4d36  !..q`b.a.Q.R.Q.Q
	defb 0d0h,0ffh,023h,0f0h,0d0h,0f0h,050h,000h,000h,0e0h,0d0h,0e0h,050h,000h,000h,0d0h	; 4d46  ..#...P.....P...
	defb 0d0h,0d0h,050h,000h,000h,0c0h,0d0h,0c0h,050h,000h,000h,0b0h,0d0h,0b0h,050h,000h	; 4d56  ..P.....P.....P.
	defb 000h,0a0h,0d0h,0a0h,050h,000h,000h,090h,0d0h,090h,050h,0ffh,026h,0b0h,0c4h,0b0h	; 4d66  ....P.....P.&...
	defb 0c2h,0a0h,0c4h,090h,0c2h,080h,0c4h,070h,0c2h,060h,0c2h,024h,0b0h,0aah,0a0h,0ach	; 4d76  .......p.`.$....
	defb 090h,0aah,080h,0abh,070h,0a9h,060h,0a9h,0ffh,021h,0d0h,070h,0b0h,070h,02fh,000h	; 4d86  ....p.`..!.p.p/.
	defb 000h,000h,000h,0feh,0ffh,08fh,04dh,02ah,000h,000h,000h,000h,021h,000h,000h,0d0h	; 4d96  ......M*....!...
	defb 070h,0b0h,070h,02ah,000h,000h,000h,000h,0feh,0ffh,0a2h,04dh,021h,018h,090h,000h	; 4da6  p.p*.......M!...
	defb 0a0h,021h,0b0h,025h,0c0h,021h,0d0h,025h,0c0h,021h,0b0h,025h,0a0h,021h,090h,021h	; 4db6  .!.%.!.%.!.%.!.!
	defb 080h,021h,070h,021h,060h,021h,0ffh,022h,0c0h,02ch,0a0h,02ch,080h,02bh,000h,000h	; 4dc6  .!p!`!.".,.,.+..
	defb 080h,02bh,0ffh,021h,0f0h,080h,0f1h,000h,0f2h,000h,0d1h,080h,0b1h,040h,091h,020h	; 4dd6  .+.!.........@. 
	defb 024h,0f2h,000h,0e1h,000h,0d4h,000h,0c1h,000h,0b2h,000h,0a1h,000h,094h,000h,081h	; 4de6  $...............
	defb 000h,082h,000h,081h,000h,0a1h,000h,094h,000h,081h,000h,082h,000h,081h,000h,084h	; 4df6  ................
	defb 000h,0ffh,021h,073h,030h,053h,060h,093h,060h,0c2h,020h,0c3h,060h,0c2h,0d0h,093h	; 4e06  ..!s0S`.`. .`...
	defb 0c0h,0a2h,060h,093h,060h,072h,0d0h,0ffh,022h,01eh,0e2h,040h,0e2h,000h,0c2h,060h	; 4e16  ..`.`r.."..@...`
	defb 0e1h,020h,01ch,0e2h,070h,0d1h,000h,01eh,0d2h,0d0h,0b1h,000h,0e2h,070h,0d1h,010h	; 4e26  . ..p........p..
	defb 01ch,0c1h,070h,021h,01ch,0e2h,040h,0c1h,0d0h,0b2h,000h,0e1h,0b0h,0d2h,070h,0d2h	; 4e36  ..p!..@.......p.
	defb 000h,01bh,0c2h,0c0h,0a1h,000h,0d2h,000h,0c1h,0a0h,01eh,0b1h,020h,021h,01ch,0d2h	; 4e46  ............ !..
	defb 020h,0b1h,0a0h,0a2h,000h,0d1h,010h,01eh,0c2h,070h,0c1h,010h,01ch,0b2h,0f0h,091h	; 4e56   ........p......
	defb 000h,0c2h,000h,0c1h,0a0h,0c2h,0e0h,0ffh,021h,0d1h,0a0h,0d1h,0a0h,0c0h,0a0h,0b0h	; 4e66  ........!.......
	defb 0b0h,0a0h,0c0h,090h,0d0h,080h,0e0h,070h,0f0h,0ffh,021h,061h,020h,0a1h,0d0h,0c1h	; 4e76  .......p..!a ...
	defb 030h,0b1h,080h,082h,000h,061h,0b0h,000h,000h,0feh,00ch,080h,04eh,0ffh,021h,0e0h	; 4e86  0....a......N.!.
	defb 080h,0e1h,000h,0d1h,080h,0d2h,000h,0c2h,080h,0c3h,000h,0b3h,000h,0b4h,000h,0a4h	; 4e96  ................
	defb 080h,0a5h,000h,098h,000h,098h,080h,0a9h,000h,0a9h,080h,09ah,000h,09ah,080h,08bh	; 4ea6  ................
	defb 000h,08bh,080h,0ffh,0d2h,0fch,044h,0e1h,000h,0c0h,020h,0c0h,040h,0c0h,060h,0c0h	; 4eb6  ......D... .@.`.
	defb 080h,0c0h,0a0h,0c0h,0e0h,000h,0c0h,020h,0c0h,0d7h,0fch,022h,0e1h,000h,0c0h,000h	; 4ec6  ....... ..."....
	defb 026h,0ffh,0d2h,0fch,044h,0e3h,000h,0c0h,020h,0c0h,040h,0c0h,060h,0c0h,080h,0c0h	; 4ed6  &...D... .@.`...
	defb 0a0h,0c0h,0e2h,000h,0c0h,020h,0c0h,0d7h,0fbh,022h,000h,0c0h,000h,0e3h,0b6h,0ffh	; 4ee6  ..... ..."......
	defb 0d2h,0fch,044h,0e1h,0cfh,0d7h,0fch,022h,070h,0c0h,070h,076h,0ffh,023h,0d0h,09fh	; 4ef6  ..D...."p.pv.#..
	defb 0d0h,058h,0c0h,09fh,0c0h,058h,0b0h,09fh,0b0h,058h,0a0h,09fh,0a0h,058h,090h,09fh	; 4f06  .X...X...X...X..
	defb 090h,058h,080h,09fh,080h,058h,0ffh,021h,0f0h,0a0h,0b0h,0a0h,000h,000h,0e0h,070h	; 4f16  .X...X.!.......p
	defb 0a0h,070h,023h,000h,000h,021h,0d0h,052h,0a0h,052h,000h,000h,0b0h,052h,090h,052h	; 4f26  .p#..!.R.R...R.R
	defb 0ffh,022h,0e0h,040h,000h,000h,0a0h,041h,0ffh,022h,0d0h,080h,0c0h,070h,0b0h,040h	; 4f36  .".@...A."...p.@
	defb 0a0h,070h,0ffh,022h,0d0h,090h,0e0h,092h,0d0h,090h,0b0h,092h,0c0h,090h,0a0h,092h	; 4f46  .p."............
	defb 0c0h,060h,0a0h,062h,0b0h,060h,090h,062h,080h,060h,0ffh,024h,0d0h,0a0h,0c0h,09fh	; 4f56  .`.b.`.b.`.$....
	defb 0b0h,09ch,0a0h,097h,090h,090h,080h,087h,070h,080h,070h,077h,0ffh,021h,0d0h,040h	; 4f66  ........p.pw.!.@
	defb 0b0h,050h,0c0h,050h,0a0h,050h,080h,050h,0ffh,0e8h,0d4h,0fdh,031h,0e2h,090h,0e1h	; 4f76  .P.P.P.P....1...
	defb 030h,070h,090h,0e0h,030h,070h,0e2h,0a0h,0e1h,050h,090h,0a0h,0e0h,050h,090h,0d3h	; 4f86  0p..0p...P...P..
	defb 0e1h,000h,070h,0b0h,0e0h,000h,070h,0b0h,0c1h,0d4h,0fah,011h,0b0h,0c1h,0f7h,011h	; 4f96  ..p...p.........
	defb 0b0h,0c1h,0f4h,011h,0b0h,0ffh,022h,010h,0f0h,030h,0e0h,02eh,0d0h,02ch,0c0h,02ah	; 4fa6  ......"..0...,.*
	defb 0feh,002h,0ach,04fh,0e0h,030h,0d0h,02eh,0c0h,02ch,0b0h,02ah,0feh,002h,0bah,04fh	; 4fb6  ...O.0...,.*...O
	defb 0c0h,030h,0b0h,02eh,0a0h,02ch,090h,02ah,0feh,002h,0c6h,04fh,0b0h,030h,0a0h,02eh	; 4fc6  .0...,.*...O.0..
	defb 090h,02ch,080h,02ah,0ffh,0d8h,0fch,021h,0c1h,0e3h,070h,040h,010h,0e4h,0a0h,0feh	; 4fd6  .,.*...!..p@....
	defb 004h,0dfh,04fh,060h,030h,000h,0e4h,090h,0feh,004h,0e9h,04fh,0e4h,0a0h,0e3h,010h	; 4fe6  ..O`0......O....
	defb 040h,070h,040h,070h,0a0h,070h,030h,060h,090h,0e2h,000h,0e3h,090h,0e2h,000h,030h	; 4ff6  @p@p.p0`.......0
	defb 000h,0feh,002h,0f2h,04fh,0feh,0ffh,0dfh,04fh,0dah,0fdh,011h,0e3h,0c0h,00bh,01bh	; 5006  ....O...O.......
	defb 03bh,0e4h,0bbh,0e3h,01bh,04bh,01bh,0feh,0ffh,014h,050h,0d2h,0fah,011h,0e2h,0c4h	; 5016  ;....K....P.....
	defb 070h,0c0h,070h,0c0h,070h,0c0h,070h,0c0h,070h,0c0h,0e1h,000h,0c0h,000h,0c0h,000h	; 5026  p.p.p.p.p.......
	defb 0c0h,000h,0c0h,000h,0c0h,0e2h,0b0h,0c0h,0b0h,0c0h,0b0h,0c0h,0b0h,0c0h,0b0h,0c0h	; 5036  ................
	defb 0feh,00ah,026h,050h,0e2h,070h,0c0h,070h,0c0h,070h,0c0h,070h,0c0h,070h,0c0h,0e1h	; 5046  ..&P.p.p.p.p.p..
	defb 010h,0c0h,010h,0c0h,010h,0c0h,010h,0c0h,010h,0c0h,0e2h,0a0h,0c0h,0a0h,0c0h,0a0h	; 5056  ................
	defb 0c0h,0a0h,0c0h,0a0h,0c0h,0feh,004h,04ah,050h,0feh,0ffh,026h,050h,0d7h,0fbh,023h	; 5066  .......JP..&P..#
	defb 0e1h,000h,020h,030h,070h,0e0h,001h,0e1h,071h,063h,0c1h,061h,053h,0c1h,031h,003h	; 5076  .. 0p...qc.aS.1.
	defb 0c0h,0e2h,0b0h,0a0h,0b0h,0e1h,000h,020h,030h,070h,0e0h,001h,0e1h,071h,063h,0c1h	; 5086  ....... 0p...qc.
	defb 061h,053h,070h,050h,030h,010h,005h,0c1h,030h,070h,0feh,004h,09eh,050h,060h,090h	; 5096  aSpP0...0p...P`.
	defb 0feh,004h,0a4h,050h,050h,080h,0feh,003h,0aah,050h,0e0h,010h,050h,031h,000h,0e1h	; 50a6  ...PP....P..P1..
	defb 072h,0c1h,030h,070h,0feh,004h,0b8h,050h,060h,090h,0feh,004h,0beh,050h,050h,080h	; 50b6  r.0p...P`....PP.
	defb 0feh,003h,0c4h,050h,0e0h,010h,050h,030h,000h,0e1h,0b0h,080h,070h,050h,030h,020h	; 50c6  ...P..P0....pP0 
	defb 0feh,0ffh,073h,050h,0ffh,0d7h,0fbh,023h,0e2h,000h,030h,0e3h,070h,0e2h,030h,0feh	; 50d6  ..sP...#..0.p.0.
	defb 002h,0dfh,050h,020h,060h,0e3h,090h,0e2h,060h,0feh,002h,0e9h,050h,010h,050h,0e3h	; 50e6  ..P `...`...P.P.
	defb 080h,0e2h,050h,0feh,002h,0f3h,050h,000h,030h,0e3h,070h,0e2h,030h,000h,0e3h,0b0h	; 50f6  ..P...P.0.p.0...
	defb 0a0h,0b0h,0e2h,000h,030h,0e3h,070h,0e2h,030h,0feh,002h,008h,051h,0e2h,020h,060h	; 5106  ....0.p.0...Q. `
	defb 0e3h,090h,0e2h,060h,0feh,002h,013h,051h,0e2h,020h,050h,0e3h,080h,0e2h,050h,0feh	; 5116  ...`...Q. P...P.
	defb 002h,01eh,051h,000h,030h,0e3h,070h,0e2h,030h,0feh,003h,029h,051h,000h,0e3h,0b0h	; 5126  ..Q.0.p.0..)Q...
	defb 0e2h,000h,010h,020h,060h,0e3h,090h,0e2h,060h,0feh,002h,039h,051h,010h,050h,0e3h	; 5136  ... `...`..9Q.P.
	defb 080h,0e2h,050h,0feh,002h,043h,051h,000h,0e1h,000h,0e2h,0b0h,080h,070h,050h,030h	; 5146  ..P..CQ......pP0
	defb 020h,0feh,0ffh,0dbh,050h,0ffh,0d3h,0fbh,021h,0e2h,071h,0b1h,051h,091h,041h,071h	; 5156   ...P...!.q.Q.Aq
	defb 021h,001h,0fah,011h,0e3h,070h,0f9h,011h,050h,0f8h,011h,040h,020h,001h,0ffh,0d3h	; 5166  !....p..P..@ ...
	defb 0fbh,021h,0e3h,071h,0b1h,051h,091h,041h,071h,021h,001h,0fah,011h,0e2h,070h,0f9h	; 5176  .!.q.Q.Aq!....p.
	defb 011h,050h,0f8h,011h,040h,020h,000h,0ffh,0d6h,0fbh,033h,0e1h,031h,000h,0c0h,0e4h	; 5186  .P..@ ....3.1...
	defb 000h,000h,000h,000h,0e3h,031h,030h,030h,0e2h,050h,070h,080h,0a0h,0e1h,001h,0e2h	; 5196  .....100.Pp.....
	defb 080h,0e1h,000h,0e2h,020h,030h,050h,030h,021h,0e3h,0a0h,0e2h,020h,050h,020h,0a0h	; 51a6  .... 0P0!... P .
	defb 050h,0e1h,004h,0c0h,020h,030h,021h,002h,0c0h,0e2h,070h,0a0h,0e1h,002h,020h,030h	; 51b6  P... 0!...p... 0
	defb 050h,070h,050h,030h,020h,003h,0e2h,070h,0a0h,0feh,002h,08eh,051h,0f5h,000h,0e1h	; 51c6  PpP0 ..p....Q...
	defb 000h,0f6h,000h,000h,0f7h,000h,000h,0f8h,000h,000h,0f9h,000h,000h,0fah,000h,000h	; 51d6  ................
	defb 0fbh,000h,000h,0fch,010h,000h,0c1h,0f9h,010h,000h,0c1h,0f7h,010h,000h,0c1h,0fch	; 51e6  ................
	defb 010h,030h,000h,0c0h,0f9h,020h,030h,000h,0f8h,020h,030h,000h,0c0h,0feh,002h,0f5h	; 51f6  .0... 0.. 0.....
	defb 051h,0fch,012h,070h,050h,030h,0c0h,0fah,022h,070h,050h,030h,020h,0fch,012h,080h	; 5206  Q..pP0.."pP0 ...
	defb 070h,050h,0c0h,0fah,022h,080h,070h,050h,0a0h,0d1h,0fah,000h,0c1h,080h,090h,0a0h	; 5216  pP..".pP........
	defb 0b0h,0d9h,0fch,033h,0e0h,009h,0feh,0ffh,08eh,051h,0ffh,0d6h,0fdh,034h,0e3h,001h	; 5226  ...3.....Q...4..
	defb 000h,000h,001h,000h,000h,001h,000h,000h,001h,000h,000h,0e4h,081h,080h,080h,081h	; 5236  ................
	defb 080h,080h,0a1h,0a0h,0a0h,0a1h,0a0h,0a0h,0e3h,001h,000h,000h,001h,000h,000h,001h	; 5246  ................
	defb 000h,000h,001h,000h,000h,031h,030h,030h,031h,030h,030h,0e4h,0a1h,0a0h,0a0h,0a1h	; 5256  .....100100.....
	defb 0a0h,0a0h,0feh,0ffh,031h,052h,0ffh,0d9h,0fch,032h,0e1h,043h,000h,040h,073h,050h	; 5266  ....1R...2.C.@sP
	defb 040h,052h,0fah,021h,002h,002h,0dah,0fch,023h,0e2h,0a0h,050h,020h,0e2h,047h,0ffh	; 5276  @R.!....#..P .G.
	defb 0d9h,0fbh,024h,0e2h,073h,070h,070h,0a3h,0a0h,0a0h,092h,052h,032h,0dah,050h,020h	; 5286  ..$.spp....R2.P 
	defb 0c0h,0e3h,007h,0ffh,0d9h,0fdh,032h,0e3h,000h,000h,000h,0fbh,024h,0e2h,002h,0fdh	; 5296  ......2.....$...
	defb 032h,0e4h,0a0h,0a0h,0a0h,0fbh,024h,0e3h,0a2h,0fdh,032h,0e4h,090h,090h,090h,0fbh	; 52a6  2.....$...2.....
	defb 023h,0e3h,092h,082h,0dah,0a2h,0fbh,034h,0e3h,077h,0ffh,0d4h,0fbh,023h,0e1h,041h	; 52b6  #......4.w...#.A
	defb 0c1h,0e2h,091h,0e1h,049h,011h,011h,0e2h,0b1h,091h,0e1h,041h,041h,0e2h,091h,0e1h	; 52c6  ....I......AA...
	defb 045h,0e2h,093h,0b3h,0e1h,013h,041h,0c1h,041h,095h,075h,021h,021h,021h,04fh,0ffh	; 52d6  E.....A.A.u!!!O.
	defb 0ffh,0d4h,0fbh,023h,0e2h,091h,0c1h,041h,099h,041h,045h,091h,091h,041h,095h,013h	; 52e6  ...#...A.AE..A..
	defb 043h,093h,091h,0c1h,091h,0e1h,045h,005h,0e2h,091h,091h,091h,08fh,0ffh,0d4h,0fch	; 52f6  C.....E.........
	defb 023h,0e4h,093h,0e3h,041h,091h,041h,091h,0feh,002h,007h,053h,0e4h,073h,0e3h,041h	; 5306  #...A.A....S.s.A
	defb 091h,041h,091h,0feh,002h,012h,053h,0e4h,053h,0e3h,001h,051h,001h,051h,0feh,002h	; 5316  .A....S.S..Q.Q..
	defb 01dh,053h,0e4h,04fh,0c5h,0ffh,0dah,0fch,033h,0e1h,0c3h,012h,0e2h,095h,090h,0e1h	; 5326  .S.O....3.......
	defb 020h,010h,012h,0e2h,093h,050h,070h,090h,0b0h,0e1h,020h,042h,0e2h,070h,0e1h,000h	; 5336   ....Pp... B.p..
	defb 040h,022h,0e2h,072h,0e1h,042h,070h,050h,040h,022h,072h,090h,090h,090h,090h,050h	; 5346  @".r.BpP@"r....P
	defb 090h,0b0h,0b0h,0b0h,070h,090h,0b0h,09ah,0ffh,0e8h,0dah,0fch,033h,0e1h,0c3h,012h	; 5356  ....p.......3...
	defb 0e2h,092h,055h,092h,042h,022h,090h,0b0h,0e1h,020h,042h,0e2h,070h,0e1h,000h,040h	; 5366  ..U.B"... B.p..@
	defb 022h,0e2h,072h,002h,040h,020h,000h,0e3h,0b2h,0e2h,022h,050h,000h,050h,050h,000h	; 5376  ".r.@ ...."P.PP.
	defb 050h,070h,020h,070h,0f9h,003h,0e2h,070h,090h,0b0h,0e1h,010h,0e2h,090h,020h,017h	; 5386  Pp p...p...... .
	defb 0ffh,0dah,0fch,015h,0e4h,0c3h,092h,090h,0e3h,040h,090h,0e4h,092h,090h,090h,090h	; 5396  .........@......
	defb 092h,090h,0e3h,040h,090h,050h,020h,040h,050h,070h,0b0h,002h,000h,000h,000h,0e4h	; 53a6  ...@.P @Pp......
	defb 072h,070h,0e3h,020h,070h,002h,002h,0e4h,072h,072h,050h,050h,0e3h,000h,052h,0e4h	; 53b6  rp. p...rrPP..R.
	defb 070h,070h,0e3h,020h,072h,0e4h,090h,090h,0e3h,040h,097h,0ffh,0ffh	; 53c6  pp. r....@...

; ======================================================================
; CODIGO 0x53d3..0x5615  (578 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; ====================================================================
; MONTAR LA FASE. Se llama al empezar cada fase y cada vez que se pierde
; una vida: borra las variables del juego, coge de la tabla de 0x99CD el
; mapa que toca, siembra los enemigos y sube todos los graficos.
; ====================================================================
; ----------------------------------------------------------------------
monta_la_fase:
	ld a,(0e092h)		;53d3   ; el tramo dentro de la fase
	cp 009h		;53d6   ; el noveno es el del jefe, y ese conserva su marca
	jr z,L_53DE		;53d8
	xor a			;53da
	ld (0e3b0h),a		;53db   ; en los demas se limpia (0xE3B0)
L_53DE:
	ld a,(0e3b0h)		;53de   ; con la marca puesta, la pantalla del jefe
	or a			;53e1
	jr z,L_53E9		;53e2
	call pon_la_musica_del_jefe		;53e4   ; la pantalla del jefe
	jr L_53EC		;53e7
L_53E9:
	call pon_la_musica_de_la_fase		;53e9   ; y sin ella, la corriente
L_53EC:
	ld hl,0e609h		;53ec   ; los siete bytes de cabecera del tramo, a 0xE080
	ld de,0e080h		;53ef
	ld bc,00007h		;53f2
	ldir		;53f5   ; los siete bytes de cabecera del tramo
	ld hl,0e600h		;53f7   ; borra de 0xE600 a 0xE750: el jugador, los disparos y todo lo de la fase
	ld de,0e601h		;53fa
	ld bc,0014fh		;53fd
	ld (hl),000h		;5400
	ldir		;5402   ; de un golpe
	ld hl,0e600h		;5404   ; y con esos ceros deja limpios los 0x80 bytes de 0xE4F0
	ld de,0e4f0h		;5407
	ld bc,00080h		;540a
	ldir		;540d   ; y con esos ceros, los 0x80 de 0xE4F0
	ld a,(0e062h)		;540f   ; la fase 5 arranca con (0xE3F0) a 0x80
	cp 005h		;5412
	jr nz,L_541B		;5414
	ld a,080h		;5416
	ld (0e3f0h),a		;5418
L_541B:
	ld a,(0e062h)		;541b   ; y la 6 con (0xE3D0) a cero
	sub 006h		;541e
	jr nz,L_5425		;5420
	ld (0e3d0h),a		;5422
L_5425:
	xor a			;5425   ; tres marcas mas, a cero
	ld (0e590h),a		;5426
	ld (0e5b0h),a		;5429
	ld (0e5d0h),a		;542c
	ld hl,0e073h		;542f   ; (0xE073) dice si la fase ya estaba montada: si lo estaba, solo se
	ld a,(hl)			;5432
	or a			;5433
	jr nz,L_5464		;5434
	ld (0e092h),a		;5436   ; tramo 0, y el guion de oleadas al principio
	ld (0e09fh),a		;5439
	inc (hl)			;543c   ; queda marcada como montada
	ld hl,099cdh		;543d   ; la tabla de las ocho fases, de cuatro bytes por fase
	ld a,(0e062h)		;5440
	add a,a			;5443   ; cuatro bytes por fase
	call palabra_de_tabla_doble		;5444
	ld (0e093h),de		;5447   ; (0xE093) la lista de tramos
	inc hl			;544b   ; la segunda palabra
	ld e,(hl)			;544c
	inc hl			;544d
	ld d,(hl)			;544e
	ld (0e095h),de		;544f   ; y (0xE095) el final del mapa de bits de repeticion
	ld a,(0e062h)		;5453
	ld (0e065h),a		;5456   ; la fase, tambien en (0xE065)
	ld hl,0e080h		;5459   ; y la cabecera del tramo se guarda de vuelta
	ld de,0e609h		;545c
	ld bc,00007h		;545f
	ldir		;5462   ; y de vuelta a su sitio
L_5464:
	ld ix,0e600h		;5464   ; la posicion de salida del muneco: x 0x87, y 0x78
	ld (ix+002h),087h		;5468   ; la columna de salida
	ld (ix+004h),078h		;546c   ; y la fila
	ld hl,0e620h		;5470   ; las cuatro ranuras de 0xE620, marcadas con 0x80 y su numero
	ld bc,00400h		;5473
L_5476:
	ld a,080h		;5476   ; marcadas con 0x80 y su numero
	or c			;5478
	ld (hl),a			;5479
	ld de,00010h		;547a
	add hl,de			;547d
	inc c			;547e
	djnz L_5476		;547f
	ld hl,0e0a0h		;5481   ; borra de 0xE0A0 a 0xE2C0: los generadores y los enemigos
	ld de,0e0a1h		;5484
	ld bc,00220h		;5487
	xor a			;548a
	ld (hl),a			;548b   ; a cero
	ldir		;548c
	ld (0e09eh),a		;548e
	ld a,(0e062h)		;5491
	ld hl,0704bh		;5494   ; el guion de oleadas de esta fase
	call palabra_de_tabla_doble		;5497   ; el guion de la fase
	ld hl,0e09fh		;549a
	dec (hl)			;549d   ; y se rebobina
L_549E:
	dec (hl)			;549e   ; rebobina el guion hasta la ultima entrada cuyo nibble bajo no sea cero
	ld a,(hl)			;549f
	cp 0feh		;54a0   ; por debajo de 0xFE se ha pasado del principio: se deja en cero
	jr c,L_54A8		;54a2
	xor a			;54a4
	ld (hl),a			;54a5
	jr L_54B5		;54a6
L_54A8:
	add a,a			;54a8
	push de			;54a9   ; la entrada por dos
	call suma_a_a_de		;54aa
	inc de			;54ad
	ld a,(de)			;54ae
	pop de			;54af
	and 00fh		;54b0   ; su nibble bajo dice si vale
	jr nz,L_549E		;54b2
	inc (hl)			;54b4
L_54B5:
	call L_7613		;54b5   ; aparca los siete enemigos
	call borra_el_objeto		;54b8   ; y monta el marcador
	ld de,0a71eh		;54bb   ; los 37 patrones de sprite de la fase: armas, disparos y objetos
	call descomprime_desde_la_palabra		;54be
	ld ix,0ee20h		;54c1   ; y los dos bloques de 32 bytes que van a la RAM, en 0xEE20 y 0xEE40
	ld hl,05615h		;54c5
	ld b,002h		;54c8
L_54CA:
	push bc			;54ca
	ld e,(hl)			;54cb   ; el puntero del bloque
	inc hl			;54cc
	ld d,(hl)			;54cd
	inc hl			;54ce
	push hl			;54cf
	push ix		;54d0
	pop hl			;54d2
	push hl			;54d3
	ld bc,00010h		;54d4   ; se descomprime en la segunda mitad...
	add hl,bc			;54d7
	call descomprime_espejado_en_ram		;54d8   ; se descomprime
	pop de			;54db
	ld hl,00020h		;54dc
	add hl,de			;54df
	ld bc,00010h		;54e0   ; ...y luego se copia la mitad de arriba sobre la de abajo, que es como
	ldir		;54e3
	pop hl			;54e5
	ld de,00020h		;54e6
	add ix,de		;54e9
	pop bc			;54eb
	djnz L_54CA		;54ec   ; y el siguiente
	ld a,(0e3b0h)		;54ee   ; con la marca del jefe puesta, un retoque mas
	or a			;54f1
	jr z,L_54F8		;54f2
	call reparte_por_la_fase		;54f4   ; un retoque para el jefe
	dec (hl)			;54f7
L_54F8:
	ld a,(0e062h)		;54f8   ; la tabla de graficos de la fase, cuatro bytes por fase
	add a,a			;54fb
	ld hl,0563ch		;54fc
	call palabra_de_tabla_doble		;54ff   ; cuatro bytes por fase
	inc hl			;5502
	push hl			;5503
	ld hl,02280h		;5504   ; los patrones de las casillas, a 0x2280 en los tres bancos
	call descomprime_en_los_tres_bancos		;5507   ; los patrones, a 0x2280
	ld hl,02580h		;550a   ; y la copia ESPEJADA, a 0x2580: la casilla 0x50 y la 0xB0 son la misma
	call vuelca_el_guion_en_los_tres_tercios		;550d
	pop hl			;5510
	ld e,(hl)			;5511   ; el guion de color, que va detras del de patrones en la tabla
	inc hl			;5512
	ld d,(hl)			;5513
	ld a,(0e062h)		;5514   ; las fases 3 y 7 usan el color de la 0 pasado por el traductor...
	ld h,001h		;5517
	cp 003h		;5519   ; ...la 3 con (0xE661) a uno...
	jr z,L_5523		;551b
	ld h,002h		;551d
	cp 007h		;551f   ; ...y la 7 con dos, que baja los cinco codigos 0x50 mas
	jr nz,L_5527		;5521
L_5523:
	ld a,h			;5523
	ld (0e661h),a		;5524
L_5527:
	ld hl,00280h		;5527   ; el color, en 0x0280
	call descomprime_en_los_tres_bancos		;552a
	ld hl,00580h		;552d   ; y otra vez en 0x0580, para las casillas espejadas: dar la vuelta a
	call descomprime_en_los_tres_bancos		;5530
	xor a			;5533   ; y el traductor, apagado otra vez
	ld (0e661h),a		;5534
	ld a,(0e062h)		;5537
	cp 007h		;553a   ; solo la fase 7 carga las casillas de mas
	jr nz,monta_el_tramo		;553c
	ld de,0be41h		;553e
	ld hl,02470h		;5541   ; los patrones de mas de la fase 7
	call descomprime_en_los_tres_bancos		;5544
	ld hl,02770h		;5547
	call vuelca_el_guion_en_los_tres_tercios		;554a
	ld de,0beb7h		;554d
	ld hl,00470h		;5550   ; y su color
	call descomprime_en_los_tres_bancos		;5553
	ld hl,00770h		;5556
	call descomprime_en_los_tres_bancos		;5559
monta_el_tramo:
	xor a			;555c   ; a montar el tramo que toque
	ld (0e090h),a		;555d   ; el reloj del tramo, a cero
	ld (0e09ah),a		;5560
	ld a,(0e092h)		;5563   ; (0xE091) = 24 veces el numero de tramo: las filas de casilla que hay
	add a,a			;5566   ; por veinticuatro
	ld e,a			;5567
	add a,a			;5568
	ld d,a			;5569
	add a,a			;556a
	ld b,a			;556b
	add a,a			;556c
	add a,b			;556d
	ld (0e091h),a		;556e
	ld a,d			;5571   ; y por seis
	add a,e			;5572
	ld e,a			;5573
	ld d,000h		;5574
	ld hl,(0e095h)		;5576   ; y el mapa de bits del tramo, seis bytes mas atras por cada tramo
	or a			;5579
	sbc hl,de		;557a   ; restado del final del mapa de bits
	ld (0e088h),hl		;557c
	ld a,(0e092h)		;557f
	ld hl,(0e093h)		;5582   ; los codigos de bloque, de la lista de tramos de la fase
	call palabra_de_tabla_en_hl		;5585   ; la lista de tramos, indexada
	ld (0e097h),hl		;5588
	ld (0e09ch),hl		;558b   ; y queda por duplicado, que 0x6502 gasta una copia
	xor a			;558e   ; siete bandas de cuatro filas
L_558F:
	push af			;558f
	call monta_una_banda		;5590   ; cada una monta ocho grupos de cuatro columnas
	pop af			;5593
	inc a			;5594   ; siete bandas
	cp 007h		;5595
	jr c,L_558F		;5597
	ld a,(0e3b0h)		;5599
	or a			;559c
	call nz,monta_el_decorado_del_jefe		;559d   ; si es la pantalla del jefe, encima va lo suyo
	call retrocede_un_byte_del_mapa		;55a0   ; y el mapa de bits retrocede un byte
	ld hl,06a98h		;55a3   ; la tabla de enemigos de la fase, doce bytes por fase
	ld a,(0e062h)		;55a6
	add a,a			;55a9
	add a,a			;55aa
	ld b,a			;55ab
	add a,a			;55ac
	add a,b			;55ad
	call palabra_de_tabla		;55ae   ; doce bytes por fase
	inc hl			;55b1   ; y detras van los diez indices
	push hl			;55b2
	ld a,(0e092h)		;55b3
	call enemigo_numero		;55b6   ; donde empieza la lista de enemigos de este tramo
	ld (0e570h),hl		;55b9   ; donde acaba la lista de este tramo
	pop hl			;55bc
	ld a,(0e092h)		;55bd   ; el tramo 0 y el 8 no siembran enemigos
	dec a			;55c0   ; el tramo 0 no siembra
	jp m,L_55EA		;55c1
	cp 008h		;55c4
	jr z,L_55EA		;55c6   ; ni el 8
	call enemigo_numero		;55c8   ; los del tramo siguiente
	push hl			;55cb
	pop iy		;55cc
	sub c			;55ce   ; cuantos hay: los que van de un tramo al siguiente
	ld b,a			;55cf
	ld ix,0e4f0h		;55d0   ; y se van montando de 0x10 en 0x10 desde 0xE4F0
L_55D4:
	call monta_un_bicho		;55d4
	ld a,(0e091h)		;55d7   ; la y, contada desde el techo del tramo y multiplicada por ocho
	sub (iy-002h)		;55da
	add a,a			;55dd   ; por ocho: la fila en pixeles
	add a,a			;55de
	add a,a			;55df
	ld (ix+002h),a		;55e0
	ld de,00010h		;55e3   ; y el enemigo siguiente
	add ix,de		;55e6
	djnz L_55D4		;55e8
L_55EA:
	jp vuelca_la_pantalla		;55ea   ; a pintar la pantalla

; ----------------------------------------------------------------------
; RETROCEDER UN BYTE DEL MAPA DE BITS. Cada bit puesto quiere decir que
; ese grupo gastaba un codigo de bloque, asi que retroceder el byte es
; retroceder tantos codigos como bits tenga.
; ----------------------------------------------------------------------
retrocede_un_byte_del_mapa:
	ld hl,(0e088h)		;55ed
	dec hl			;55f0   ; un byte atras
	ld a,(hl)			;55f1   ; el byte de bits
	ld (0e088h),hl		;55f2
	ld b,008h		;55f5   ; sus ocho bits
	ld hl,(0e097h)		;55f7
L_55FA:
	rla			;55fa   ; y por cada uno puesto, un codigo de bloque menos
	jr nc,L_55FE		;55fb
	dec hl			;55fd
L_55FE:
	djnz L_55FA		;55fe
	ld (0e097h),hl		;5600   ; y el puntero, retrocedido
	ld (0e09ch),hl		;5603
	ret			;5606

; ----------------------------------------------------------------------
; LA DIRECCION DE UN ENEMIGO DENTRO DE SU FASE. El byte numero A de la
; lista dice cuantos enemigos van por delante, y cada uno ocupa tres
; bytes: por eso el `add hl,hl / add hl,bc` multiplica por tres.
; ----------------------------------------------------------------------
enemigo_numero:
	call suma_a_a_hl		;5607
	ld a,(hl)			;560a   ; y de paso queda en A' el indice, que 0x55CE necesita para restar
	ex af,af'			;560b
	ld l,(hl)			;560c
	ld h,000h		;560d
	ld b,h			;560f   ; y de paso queda en A' el indice
	ld c,l			;5610
	add hl,hl			;5611   ; por tres
	add hl,bc			;5612
	add hl,de			;5613   ; y sobre la base de la fase
	ret			;5614

; ----------------------------------------------------------------------
; DATOS punteros_de_los_dos_bloques_de_ram: 0xA640 y 0xA65D, y un 0x000E;
;   0x54C5 los recorre para montar 0xEE20 y 0xEE40
;   0x5615..0x561b  (6 bytes)
DATA_punteros_de_los_dos_bloques_de_ram:
	defw 0a640h,0a65dh	; 5615
	defb 00eh,000h	; 5619

; ======================================================================
; CODIGO 0x561b..0x563c  (33 bytes)
; ======================================================================


L_561B:
	ld a,(de)			;561b   ; el byte de cuenta
	inc de			;561c
	and a			;561d
	ret z			;561e   ; el 0x00 cierra
	ld b,a			;561f
	and 07fh		;5620
	cp b			;5622
	ld b,a			;5623
	jr z,L_562F		;5624
L_5626:
	call lee_y_traduce		;5626
	ld (hl),a			;5629
	inc hl			;562a
	djnz L_5626		;562b
	jr L_561B		;562d
L_562F:
	call lee_y_traduce		;562f
L_5632:
	ld (hl),a			;5632
	inc hl			;5633
	djnz L_5632		;5634
	jr L_561B		;5636
descomprime_espejado_en_ram:
	ld c,001h		;5638   ; c a uno: los bytes salen con los bits dados la vuelta
	jr L_561B		;563a

; ----------------------------------------------------------------------
; DATOS graficos_por_fase: Ocho entradas de cuatro bytes -0x54FC indexa con
;   (0xE062)*4-: el guion de patrones y el de color de las casillas de esa
;   fase. Las fases 0, 3 y 7 apuntan al MISMO par, y la 5 y la 6 tambien
;   0x563c..0x565c  (32 bytes)
DATA_graficos_por_fase:
	defw 0b317h,0b4d0h,0b570h,0b647h,0b6aeh,0b7feh,0b317h,0b4d0h	; 563c
	defw 0b871h,0ba5bh,0bafbh,0bd5dh,0bafbh,0bd5dh,0b317h,0b4d0h	; 564c

; ======================================================================
; CODIGO 0x565c..0x56a2  (70 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL MARCADOR DE ARRIBA. Sus casillas y su color, en los tres bancos.
; ----------------------------------------------------------------------
monta_el_marcador:
	ld de,0b17bh		;565c
	ld hl,02138h		;565f
	call descomprime_en_los_tres_bancos		;5662
	ld hl,02438h		;5665   ; y la copia espejada del rotulo
	call vuelca_el_guion_en_los_tres_tercios		;5668
	ld de,0b285h		;566b
	ld hl,00138h		;566e
	call descomprime_en_los_tres_bancos		;5671
	ld hl,00438h		;5674
	call descomprime_en_los_tres_bancos		;5677
	ld de,0b2fbh		;567a   ; el marco, aparte
	ld hl,02500h		;567d
	call descomprime_en_los_tres_bancos		;5680
	ld de,0b314h		;5683
	ld hl,00500h		;5686
	jp descomprime_en_los_tres_bancos		;5689

; ----------------------------------------------------------------------
; LA MUSICA DE LA FASE. Cada fase tiene la suya; la tabla de 0x56A2 es la
; corriente y la de 0x56AA la del jefe.
; ----------------------------------------------------------------------
pon_la_musica_de_la_fase:
	xor a			;568c
	ld (0e667h),a		;568d
pon_la_musica_de_la_tabla:
	ld hl,056a2h		;5690
L_5693:
	ld a,(0e062h)		;5693   ; indexada por la fase
	call suma_a_a_hl		;5696
	ld a,(hl)			;5699
	jp pide_pieza_si_la_escena_lo_permite		;569a   ; y a pedir la pieza
pon_la_musica_del_jefe:
	ld hl,056aah		;569d
	jr L_5693		;56a0

; ----------------------------------------------------------------------
; DATOS dieciseis_codigos_de_casilla: 0x5690 y 0x569D los leen
;   0x56a2..0x56b2  (16 bytes)
DATA_dieciseis_codigos_de_casilla:
	defb 09dh,09fh,09dh,09dh,09fh,09dh,09dh,09fh,0a3h,0a1h,0a3h,0a3h,0a3h,0a1h,0a3h,0a3h	; 56a2  ................

; ======================================================================
; CODIGO 0x56b2..0x56b8  (6 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; REPARTIR POR LA FASE. Ocho entradas, una por fase: cada una monta lo
; suyo en la pantalla del jefe. Las fases 0, 4 y 5 comparten la primera.
; ----------------------------------------------------------------------
reparte_por_la_fase:
	ld a,(0e065h)		;56b2
	call reparte_por_tabla		;56b5

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_56B8: 8 entradas; tras el `call 406Ch` de 0x56B5;
;   OCHO, no diez: ver abajo
;   0x56b8..0x56c8  (16 bytes)
DATA_tabla_de_reparto_56B8:
	defw 08ae6h,08e57h,090bfh,09224h,08ae6h,08ae6h,09435h,09645h	; 56b8

; ======================================================================
; CODIGO 0x56c8..0x5982  (698 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; PASAR LA FASE PEDIDA AL INDICE INTERNO. No la llama nadie de este
; cartucho: la llama el Konami Game Master desde la otra ranura, y su
; direccion esta declarada en 0x4023, dentro de la cabecera de 0x4010.
; ----------------------------------------------------------------------
fase_pedida_a_indice:
	ld hl,0e061h		;56c8   ; la fase que el Game Master acaba de escribir, en BCD
	ld a,(hl)			;56cb
	sub 001h		;56cc   ; menos uno
	daa			;56ce
	inc hl			;56cf   ; y a (0xE062), que es el indice con el que trabaja el juego
	ld (hl),a			;56d0
	ret			;56d1

; ----------------------------------------------------------------------
; LA PAUSA. La tecla STOP -fila 6, bit 4- congela el juego: se guarda la
; zona de sprites 0x1D00 en la RAM, se aparcan todos y se pinta el
; rotulo; al volver a pulsar, se devuelve todo.
; ----------------------------------------------------------------------
mira_la_pausa:
	ld a,(0e002h)		;56d2
	bit 6,a		;56d5   ; con el sonido apagado no hay pausa
	jp z,haz_el_cuadro_del_juego		;56d7
	ld a,(0e3b0h)		;56da
	or a			;56dd   ; ni en la pantalla del jefe
	jp nz,haz_el_cuadro_del_juego		;56de
	ld a,(0e600h)		;56e1
	or a			;56e4   ; ni si el muneco esta muriendose
	jp nz,haz_el_cuadro_del_juego		;56e5
	ld a,006h		;56e8
	call 00141h		;56ea   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix | fila 6 del teclado: la tecla STOP
	ld hl,0e06bh		;56ed
	cpl			;56f0
	ld c,(hl)			;56f1   ; lo que ACABA de pulsarse
	ld (hl),a			;56f2
	xor c			;56f3
	and (hl)			;56f4
	ld c,a			;56f5
	dec hl			;56f6
	ld a,(hl)			;56f7
	or a			;56f8
	jr z,L_5730		;56f9   ; si ya estaba en pausa
	bit 5,c		;56fb   ; y se vuelve a pulsar, se sale
	jp z,L_5908		;56fd
	ld (hl),000h		;5700
	ld a,(0e618h)		;5702   ; se devuelve el escudo que habia
	ld (0e60ch),a		;5705
	ld a,03ch		;5708
	ld (0e06ch),a		;570a   ; 0x3C cuadros de gracia
	ld hl,01d00h		;570d   ; y los patrones guardados vuelven a la VRAM
	ld de,0ee60h		;5710
	ld bc,00100h		;5713
	call vuelca_a_vram		;5716
	ld hl,03b00h		;5719   ; los sprites, aparcados
	ld bc,00080h		;571c
	ld a,0c3h		;571f
	call 00056h		;5721   ; BIOS FILVRM - Fills VRAM with value
	ld a,0a8h		;5724
	call pide_pieza_si_la_escena_lo_permite		;5726   ; y el sonido de salir
	ld ix,0e600h		;5729
	jp pinta_al_muneco		;572d
L_5730:
	bit 5,c		;5730   ; y si no estaba en pausa, se entra
	jr z,haz_el_cuadro_del_juego		;5732
	ld a,001h		;5734
	ld (hl),a			;5736
	ld (0e667h),a		;5737   ; quedan marcados el escudo y la musica
	ld a,(0e60ch)		;573a
	ld (0e618h),a		;573d
	ld hl,00258h		;5740   ; 0x258 cuadros de pausa como mucho
	ld (0e06ch),hl		;5743
	ld a,058h		;5746
	ld (0e003h),a		;5748
	ld hl,03b24h		;574b   ; se aparcan los sprites del muneco
	ld a,0c3h		;574e
	call 0004dh		;5750   ; BIOS WRTVRM - Writes data in VRAM
	ld hl,03b28h		;5753
	ld a,0d0h		;5756
	call 0004dh		;5758   ; BIOS WRTVRM - Writes data in VRAM
	ld hl,01d00h		;575b   ; y se guardan los patrones de 0x1D00 en la RAM
	ld de,0ee60h		;575e
	ld bc,00100h		;5761
	call 00059h		;5764   ; BIOS LDIRMV - Block transfers to memory from VRAM
	ld de,059edh		;5767   ; para poner encima el rotulo de la pausa
	call descomprime_desde_la_palabra		;576a
	ld hl,01d00h		;576d   ; con su copia espejada
	ld de,01d90h		;5770
	ld c,004h		;5773
	call espeja_sprites		;5775
	ld a,0a8h		;5778   ; y el sonido de entrar
	call pide_pieza_si_la_escena_lo_permite		;577a
	jp L_5908		;577d

; ----------------------------------------------------------------------
; EL CUADRO DE JUEGO. Lo llama la escena 4 en cada interrupcion.
; ----------------------------------------------------------------------
haz_el_cuadro_del_juego:
	ld hl,03b20h		;5780   ; los sprites del giro empiezan en el 8
	call abre_para_escribir		;5783
	exx			;5786
	ld hl,0e300h		;5787   ; el paso del giro, de 11 a 0 y vuelta a empezar
	dec (hl)			;578a
	jp p,L_5790		;578b
	ld (hl),00bh		;578e
L_5790:
	ld a,(hl)			;5790   ; doce pasos de seis bytes: por doce
	add a,a			;5791
	ld b,a			;5792
	add a,a			;5793
	add a,b			;5794
	ld de,059a5h		;5795
	add a,e			;5798
	ld e,a			;5799
	jr nc,L_579D		;579a
	inc d			;579c
L_579D:
	ld b,00ch		;579d   ; los doce sprites del giro
L_579F:
	push bc			;579f
	ld a,b			;57a0
	rra			;57a1   ; en los pares el nibble bajo, en los impares el alto: cada byte lleva
	ld a,(de)			;57a2
	jr nc,L_57AA		;57a3
	inc de			;57a5
	rra			;57a6
	rra			;57a7
	rra			;57a8
	rra			;57a9
L_57AA:
	and 00fh		;57aa   ; por ocho: la sombra de atributos va de cuatro en cuatro, y cada
	add a,a			;57ac
	add a,a			;57ad
	add a,a			;57ae
	ld hl,0e320h		;57af
	add a,l			;57b2
	ld l,a			;57b3
	jr nc,L_57B7		;57b4
	inc h			;57b6
L_57B7:
	ld b,008h		;57b7
L_57B9:
	outi		;57b9   ; ocho bytes de un tiron por el puerto del VDP
	jp nz,L_57B9		;57bb
	pop bc			;57be
	djnz L_579F		;57bf
	ld hl,0e06ch		;57c1   ; mientras (0xE06C) no llegue a cero, el juego esta parado
	ld a,(hl)			;57c4
	or a			;57c5
	jr z,L_57CA		;57c6
	dec (hl)			;57c8
	ret			;57c9
L_57CA:
	ld a,(0e600h)		;57ca   ; con (0xE600) en 2 o mas el muneco esta muriendose
	cp 002h		;57cd
	jr nc,L_5801		;57cf
	ld hl,0e668h		;57d1   ; el aviso de que se ha cogido algo
	ld a,(hl)			;57d4
	or a			;57d5
	jr z,L_57DF		;57d6
	ld (hl),000h		;57d8
	ld a,018h		;57da
	call pide_pieza_si_la_escena_lo_permite		;57dc
L_57DF:
	dec hl			;57df   ; y el de que hay que cambiar de musica
	ld a,(hl)			;57e0
	or a			;57e1
	jr z,L_5801		;57e2
	ld a,(0e012h)		;57e4
	or a			;57e7
	jr nz,L_5801		;57e8
	ld (hl),000h		;57ea
	ld a,(0e663h)		;57ec   ; (0xE663) dice si suena la del jefe
	or a			;57ef
	jr z,L_57FE		;57f0
	cp 001h		;57f2
	ld a,018h		;57f4
	jr z,L_57F9		;57f6
	inc a			;57f8
L_57F9:
	call pide_pieza_si_la_escena_lo_permite		;57f9
	jr L_5801		;57fc
L_57FE:
	call pon_la_musica_de_la_fase		;57fe   ; y si no, la corriente de la fase
L_5801:
	ld hl,0e090h		;5801   ; el reloj del cuadro
	inc (hl)			;5804
	ld a,(0e663h)		;5805
	or a			;5808
	jr nz,cuenta_atras_del_jefe		;5809
	ld a,(hl)			;580b
	and 03fh		;580c   ; cada 64 cuadros, una vuelta al generador
	call z,sube_un_paso		;580e
	ld hl,0e091h		;5811
	ld a,(hl)			;5814   ; mientras no se llegue al techo de la fase
	cp 0d8h		;5815
	jr nc,L_5822		;5817
	dec hl			;5819
	ld a,(hl)			;581a
	sub 0f2h		;581b   ; y en la franja de trece filas de arriba, otra cosa
	cp 00dh		;581d
	call c,monta_una_banda_si_toca		;581f
L_5822:
	call haz_al_jefe		;5822   ; los choques
	call haz_el_muneco		;5825   ; el muneco
	call mira_si_se_acaba_el_tramo		;5828   ; y los disparos
	ld a,(0e600h)		;582b
	cp 003h		;582e   ; con (0xE600) en 3 o mas ya no se mueve nada
	ret nc			;5830
	ld a,(0e090h)		;5831
	rra			;5834   ; un cuadro si y otro no
	jr nc,L_5840		;5835
	call haz_los_enemigos		;5837
	call haz_los_disparos_del_enemigo		;583a
	jp el_objeto		;583d
L_5840:
	ld a,(0e091h)		;5840
	cp 0d8h		;5843   ; cerca del techo del tramo ya no se mueven los enemigos
	jr nc,L_5859		;5845
	ld ix,0e4f0h		;5847   ; los ocho de la lista de 0xE4F0
	ld b,008h		;584b
L_584D:
	push bc			;584d
	call haz_un_bicho		;584e   ; a cada uno, su vuelta
	ld de,00010h		;5851
	add ix,de		;5854
	pop bc			;5856
	djnz L_584D		;5857
L_5859:
	call mueve_los_disparos		;5859   ; y los generadores
	ld a,(0e090h)		;585c
	and 03fh		;585f   ; cada 64 cuadros
	ret z			;5861
	ld a,(0e3b0h)		;5862   ; en la pantalla del jefe no se recarga nada
	or a			;5865
	ret nz			;5866
	jp recarga_los_patrones_de_los_generadores		;5867   ; y si no, a por los patrones del enemigo que toque

; ----------------------------------------------------------------------
; EL RELOJ DEL JEFE. Mientras (0xE663) no sea cero hay jefe, y en vez de
; la vuelta corriente se descuenta un reloj en BCD que se pinta arriba.
; Al llegar a cuatro cambia la musica; al llegar a cero, se acabo.
; ----------------------------------------------------------------------
cuenta_atras_del_jefe:
	ld a,(0e664h)		;586a   ; por dieciseis: la ranura del reloj
	add a,a			;586d
	add a,a			;586e
	add a,a			;586f
	add a,a			;5870
	ld hl,0e4f5h		;5871
	call suma_a_a_hl		;5874
	push hl			;5877
	call pinta_el_reloj		;5878   ; pintarlo
	pop hl			;587b
	ld a,(hl)			;587c
	sub 001h		;587d   ; un segundo menos, en BCD
	daa			;587f
	ld (hl),a			;5880
	jr nc,L_5822		;5881
	ld (hl),059h		;5883   ; al pasar de 00 a 59 se baja un minuto
	inc hl			;5885
	ld a,(hl)			;5886
	sub 001h		;5887
	daa			;5889
	ld (hl),a			;588a
	jr c,L_589D		;588b
	cp 004h		;588d   ; a los cuatro minutos, la musica de la prisa
	jr nz,L_58BB		;588f
	ld a,002h		;5891
	ld (0e663h),a		;5893
	ld a,019h		;5896
	call pide_pieza_si_la_escena_lo_permite		;5898
	jr L_58BB		;589b
L_589D:
	push hl			;589d   ; se acabo el tiempo: reloj a cero
	xor a			;589e
	ld (hl),a			;589f
	dec hl			;58a0
	ld (hl),a			;58a1
	call pinta_el_reloj		;58a2
	pop hl			;58a5
	inc hl			;58a6
	ld a,(hl)			;58a7
	ld (0e090h),a		;58a8   ; y el contador de cuadros se pone a lo que diga el reloj
	dec hl			;58ab
	dec hl			;58ac
	dec hl			;58ad
	xor a			;58ae
	ld (hl),a			;58af
	ld (0e663h),a		;58b0   ; fuera la marca de jefe
	ld a,(0e600h)		;58b3
	cp 002h		;58b6
	call c,pon_la_musica_de_la_tabla		;58b8   ; y vuelve la musica de la fase
L_58BB:
	jp L_5822		;58bb
pinta_el_reloj:
	ex de,hl			;58be
	ld hl,03838h		;58bf   ; en la fila 1, columna 24
	inc de			;58c2
	ld b,001h		;58c3
	call escribe_en_bcd		;58c5
	ld a,0a2h		;58c8   ; el 0xA2 de en medio son los dos puntos
	call 0004dh		;58ca   ; BIOS WRTVRM - Writes data in VRAM
	inc hl			;58cd
	ld b,001h		;58ce
	jp escribe_en_bcd		;58d0
mira_si_se_acaba_el_tramo:
	ld a,(0e600h)		;58d3
	cp 002h		;58d6   ; muriendose, no
	ret nc			;58d8
	ld a,(0e660h)		;58d9   ; con (0xE660) puesto, el muneco ha tocado algo mortal
	or a			;58dc
	jr z,L_58E8		;58dd
	ld a,003h		;58df
	ld (0e600h),a		;58e1
	xor a			;58e4
	ld (0e60bh),a		;58e5
L_58E8:
	ld de,0e091h		;58e8
	ld a,(de)			;58eb
	cp 0cfh		;58ec   ; en la fila 0xCF del tramo se enciende la marca del jefe
	ret nz			;58ee
	ld hl,0e3b0h		;58ef
	ld a,(hl)			;58f2
	or a			;58f3
	jr nz,L_58F8		;58f4
	ld (hl),001h		;58f6
L_58F8:
	dec de			;58f8
	ld a,(de)			;58f9
	sub 0c0h		;58fa   ; y entre 0xC0 y 0xC1 se cambia de musica
	cp 002h		;58fc
	ret nc			;58fe
	or a			;58ff
	ld a,03dh		;5900
	jp z,pide_pieza_si_la_escena_lo_permite		;5902
	jp pon_la_musica_del_jefe		;5905
L_5908:
	ld ix,0e600h		;5908
	ld hl,03b00h		;590c
	ld de,05982h		;590f
	call 00053h		;5912   ; BIOS SETWRT - Enables VDP to write
	ld a,(00007h)		;5915
	ld c,a			;5918
	ld b,009h		;5919
pinta_los_sprites_del_remate:
	ld a,(de)			;591b   ; la fila del sprite mas la del muneco
	add a,(ix+002h)		;591c
	out (c),a		;591f
	inc de			;5921
	ld a,(de)			;5922   ; y la columna
	push de			;5923
	ld d,a			;5924
	ld a,(ix+004h)		;5925
	cp 008h		;5928
	jr nc,L_592E		;592a
	ld a,008h		;592c
L_592E:
	add a,d			;592e
	pop de			;592f
	out (c),a		;5930
	inc de			;5932
	ld a,009h		;5933   ; el patron, 0x9C mas cuatro por sprite
	sub b			;5935
	add a,a			;5936
	add a,a			;5937
	add a,09ch		;5938
	out (c),a		;593a
	push bc			;593c
	pop bc			;593d
	ld a,(de)			;593e   ; y su color
	out (c),a		;593f
	inc de			;5941
	djnz pinta_los_sprites_del_remate		;5942
	ld hl,(0e06ch)		;5944   ; mientras quede pausa
	ld a,l			;5947
	or h			;5948
	jr nz,L_597D		;5949
	ld hl,03b24h		;594b   ; el sprite del rotulo, en 0x3B24
	call 00053h		;594e   ; BIOS SETWRT - Enables VDP to write
	ld a,0eeh		;5951   ; con la fila del muneco
	add a,(ix+002h)		;5953
	out (c),a		;5956
	ld a,(ix+004h)		;5958
	cp 008h		;595b   ; topado en 8
	jr nc,L_5961		;595d
	ld a,008h		;595f
L_5961:
	out (c),a		;5961
	ld a,(0e003h)		;5963   ; el color, de la tira de 0x599D
	rra			;5966
	rra			;5967
	rra			;5968
	rra			;5969
	and 007h		;596a   ; uno de cada dieciseis cuadros
	ld de,0599dh		;596c
	call suma_a_a_de		;596f
	ld a,(de)			;5972
	out (c),a		;5973
	or a			;5975
	jr z,L_597A		;5976
	ld a,00fh		;5978
L_597A:
	out (c),a		;597a
	ret			;597c
L_597D:
	dec hl			;597d
	ld (0e06ch),hl		;597e
	ret			;5981

; ----------------------------------------------------------------------
; DATOS sprites_del_remate: Nueve tercias [dy][dx][patron] que 0x590F suelta
;   en 0x3B00, sumandoles la posicion de (ix+2) y (ix+4)
;   0x5982..0x599d  (27 bytes)
DATA_sprites_del_remate:
	defb 0f6h,000h,007h	; 5982
	defb 006h,0f8h,006h	; 5985
	defb 016h,0f8h,006h	; 5988
	defb 0ffh,0f8h,00fh	; 598b
	defb 00fh,0f8h,00fh	; 598e
	defb 006h,008h,006h	; 5991
	defb 016h,008h,006h	; 5994
	defb 0ffh,008h,00fh	; 5997
	defb 00fh,008h,00fh	; 599a

; ----------------------------------------------------------------------
; DATOS colores_que_giran: Ocho colores; 0x596C indexa con los bits 4 a 6 del
;   contador de cuadros, asi que el sprite cambia de color solo
;   0x599d..0x59a5  (8 bytes)
DATA_colores_que_giran:
	defb 000h,000h,05ch,098h,084h,084h,098h,05ch	; 599d  ..\....\

; ----------------------------------------------------------------------
; DATOS pasos_del_giro: Doce pasos de seis bytes; 0x5795 los indexa con
;   (0xE300), que va de 11 a 0 y vuelve a empezar
;   0x59a5..0x59ed  (72 bytes)
DATA_pasos_del_giro:
	defb 001h,023h,045h,067h,089h,0abh	; 59a5
	defb 0bah,098h,076h,054h,032h,010h	; 59ab
	defb 012h,034h,050h,078h,09ah,0b6h	; 59b1
	defb 06bh,0a9h,087h,005h,043h,021h	; 59b7
	defb 023h,045h,001h,089h,0abh,067h	; 59bd
	defb 076h,0bah,098h,010h,054h,032h	; 59c3
	defb 034h,050h,012h,09ah,0b6h,078h	; 59c9
	defb 087h,06bh,0a9h,021h,005h,043h	; 59cf
	defb 045h,001h,023h,0abh,067h,089h	; 59d5
	defb 098h,076h,0bah,032h,010h,054h	; 59db
	defb 050h,012h,034h,0b6h,078h,09ah	; 59e1
	defb 0a9h,087h,06bh,043h,021h,005h	; 59e7

; ----------------------------------------------------------------------
; DATOS patrones_del_remate: Comprimido con palabra; 160 bytes = 5 patrones a
;   0x1D00, y 0x576D deja la copia espejada en 0x1D90
;   0x59ed..0x5a46  (89 bytes)
DATA_patrones_del_remate:
	defb 0e0h,01ch,00ah,000h,083h,007h,00fh,01bh,003h,017h,00ah,000h,082h,0e0h,0f0h,004h	; 59ed  ................
	defb 0f8h,085h,000h,001h,007h,004h,00ch,00bh,008h,090h,03fh,0e0h,000h,000h,00fh,07fh	; 59fd  ..........?.....
	defb 0fbh,0f5h,0fbh,0dfh,0afh,0dfh,0fbh,0f5h,0fbh,0dfh,003h,008h,084h,00ch,004h,007h	; 5a0d  ................
	defb 001h,009h,000h,083h,0afh,0dfh,07fh,003h,000h,081h,0ffh,009h,000h,082h,001h,003h	; 5a1d  ................
	defb 003h,006h,00bh,007h,087h,0bfh,05fh,0dfh,0dfh,0ffh,07fh,09fh,009h,0ffh,00ah,007h	; 5a2d  ......_.........
	defb 002h,003h,004h,000h,00dh,0ffh,003h,000h,000h	; 5a3d  .........

; ======================================================================
; CODIGO 0x5a46..0x5a95  (79 bytes)
; ======================================================================


arranca_la_demostracion:
	call monta_el_marcador		;5a46
	ld hl,0e070h		;5a49   ; borra de 0xE070 a 0xE750
	ld de,0e071h		;5a4c
	ld bc,006e0h		;5a4f
	ld (hl),000h		;5a52
	ldir		;5a54
	xor a			;5a56
	ld (0e061h),a		;5a57
	call pinta_el_marcador		;5a5a
	call monta_la_fase		;5a5d
	ld a,(0e062h)		;5a60
	inc a			;5a63
	ld (0e061h),a		;5a64   ; la fase que toque
	ld hl,00800h		;5a67   ; y el indice de la grabacion a cero, con ocho cuadros de espera
	ld (0e00bh),hl		;5a6a
	ld a,001h		;5a6d
	ld (0e064h),a		;5a6f   ; (0xE064) dice que hay demostracion en marcha
	ret			;5a72
L_5A73:
	ld hl,0e00ch		;5a73
	dec (hl)			;5a76   ; el reloj de la grabacion
	jr nz,L_5A7E		;5a77
	ld (hl),008h		;5a79   ; ocho cuadros por paso
	dec hl			;5a7b
	inc (hl)			;5a7c
	inc hl			;5a7d
L_5A7E:
	dec hl			;5a7e
	ld a,(hl)			;5a7f   ; por donde va la grabacion
	ld hl,05a95h		;5a80
	call suma_a_a_hl		;5a83   ; el byte que le toca
	ld a,(hl)			;5a86
	cp 0ffh		;5a87   ; el 0xFF la cerraria
	jp nz,guarda_lo_recien_pulsado		;5a89   ; y si no, se cuela como si fuera el mando
	xor a			;5a8c
	ld (0e064h),a		;5a8d
	ld a,03dh		;5a90
	jp pide_pieza		;5a92

; ----------------------------------------------------------------------
; DATOS partida_grabada: 118 pulsaciones, una cada ocho cuadros: unos
;   diecinueve segundos a 50 Hz. El `cp 0xFF` de 0x5A87 la cerraria, pero
;   dentro del bloque NO hay ni un 0xFF: la demostracion se corta por
;   (0xE064), que 0x5A6F pone a uno
;   0x5a95..0x5b0b  (118 bytes)
DATA_partida_grabada:
	defb 001h,001h,009h,018h,018h,002h,005h,005h,004h,014h,004h,006h,002h,00ah,008h,011h	; 5a95  ................
	defb 001h,001h,001h,001h,001h,008h,008h,008h,005h,014h,00ah,00ah,01ah,008h,019h,011h	; 5aa5  ................
	defb 014h,012h,01ah,008h,011h,004h,004h,006h,006h,014h,014h,004h,006h,014h,005h,004h	; 5ab5  ................
	defb 006h,016h,005h,004h,014h,014h,011h,011h,009h,009h,008h,018h,018h,00ah,01ah,01ah	; 5ac5  ................
	defb 01ah,010h,010h,010h,010h,010h,010h,012h,016h,004h,004h,004h,004h,015h,019h,008h	; 5ad5  ................
	defb 018h,018h,008h,00ah,018h,018h,009h,019h,008h,008h,019h,009h,012h,012h,002h,004h	; 5ae5  ................
	defb 014h,012h,002h,019h,014h,01ah,008h,008h,00ah,011h,011h,008h,008h,008h,019h,018h	; 5af5  ................
	defb 004h,004h,006h,006h,008h,008h	; 5b05

; ======================================================================
; CODIGO 0x5b0b..0x5c74  (361 bytes)
; ======================================================================


escena_final_espera:
	djnz L_5B35		;5b0b
	ld hl,0e004h		;5b0d
	dec (hl)			;5b10
	ret nz			;5b11
	ld hl,0e602h		;5b12   ; el muneco vuelve a la columna 0x97, fila 0x78
	ld (hl),097h		;5b15
	inc hl			;5b17
	inc hl			;5b18
	ld (hl),078h		;5b19
	ld hl,0e682h		;5b1b
	ld (hl),000h		;5b1e
	inc hl			;5b20
	inc hl			;5b21
	ld (hl),078h		;5b22
	ld hl,00070h		;5b24   ; y sube despacio
	ld (0e676h),hl		;5b27
	call aparca_los_sprites_del_muneco		;5b2a
	call pinta_el_marcador		;5b2d
	call vuelca_la_pantalla		;5b30
	jr L_5B95		;5b33
L_5B35:
	djnz L_5B81		;5b35
	ld ix,0e600h		;5b37
	call pinta_al_muneco_en_0x3B20		;5b3b   ; el muneco, en los sprites de 0x3B20
	ld ix,0e680h		;5b3e
	call arrastra_al_muneco		;5b42   ; y lo que sube con el
	ld hl,03b30h		;5b45
	ld de,05c74h		;5b48
	call 00053h		;5b4b   ; BIOS SETWRT - Enables VDP to write
	ld a,(00007h)		;5b4e
	ld c,a			;5b51
	ld b,004h		;5b52
pinta_los_cuatro_sprites_del_final:
	ld a,(de)			;5b54
	add a,(ix+002h)		;5b55   ; la fila del muneco mas el desplazamiento
	out (c),a		;5b58
	inc de			;5b5a
	ld a,(de)			;5b5b
	add a,(ix+004h)		;5b5c   ; y la columna
	out (c),a		;5b5f
	inc de			;5b61
	ld a,004h		;5b62
	sub b			;5b64
	add a,a			;5b65
	add a,a			;5b66
	add a,00ch		;5b67   ; el patron, 0x0C mas cuatro por sprite
	out (c),a		;5b69
	push bc			;5b6b
	pop bc			;5b6c
	ld a,(de)			;5b6d   ; y el color
	out (c),a		;5b6e
	inc de			;5b70
	djnz pinta_los_cuatro_sprites_del_final		;5b71
	ld a,(ix+002h)		;5b73
	cp 048h		;5b76   ; pasada la columna 0x48 se le empuja a la izquierda
	ret c			;5b78
	ld hl,0ff60h		;5b79
	ld (0e676h),hl		;5b7c
	jr L_5B95		;5b7f
L_5B81:
	djnz L_5B98		;5b81
	ld ix,0e600h		;5b83
	call arrastra_y_pinta_al_muneco		;5b87
	ld a,(ix+002h)		;5b8a   ; hasta la columna 0x5B
	cp 05bh		;5b8d
	ret nc			;5b8f
	ld a,078h		;5b90
	ld (0e690h),a		;5b92
L_5B95:
	jp L_4165		;5b95
L_5B98:
	djnz L_5BAC		;5b98
	ld hl,0e690h		;5b9a   ; el reloj del rotulo
	dec (hl)			;5b9d
	ret nz			;5b9e
	ld hl,05c80h		;5b9f   ; los cinco bytes de arranque, a 0xE6A0
	ld de,0e6a0h		;5ba2
	ld bc,00005h		;5ba5
	ldir		;5ba8
	jr L_5B95		;5baa
L_5BAC:
	djnz L_5BBF		;5bac
	ld a,(0e003h)		;5bae   ; uno de cada dos cuadros
	rra			;5bb1
	ret c			;5bb2
	call el_rotulo_del_final_se_escribe_solo		;5bb3   ; escribe una letra
	ret p			;5bb6
	ld de,05ca4h		;5bb7
	call pinta_texto		;5bba
	jr L_5B95		;5bbd
L_5BBF:
	djnz escena_final_rotulos		;5bbf
	ld hl,0e690h		;5bc1   ; el reloj de la espera
	dec (hl)			;5bc4
	ret nz			;5bc5
	ld hl,0e080h		;5bc6
	ld de,0e609h		;5bc9
	ld bc,00007h		;5bcc
	ldir		;5bcf
	jp L_41FA		;5bd1
escena_final_rotulos:
	ld a,(0e012h)		;5bd4   ; hasta que no se acabe lo que suena
	or a			;5bd7
	ret nz			;5bd8
	call limpia_sprites_y_nombres		;5bd9
	ld a,0b4h		;5bdc   ; con la musica del final
	call pide_pieza		;5bde
	ld hl,0e609h		;5be1
	ld de,0e080h		;5be4
	ld bc,00007h		;5be7
	ldir		;5bea
	xor a			;5bec
	ld (0e60ch),a		;5bed
	call monta_la_fuente		;5bf0
	ld de,05cb9h		;5bf3   ; los patrones del rotulo
	call descomprime_desde_la_palabra		;5bf6   ; y el texto
	ld de,05c85h		;5bf9
	call pinta_texto		;5bfc
	ld a,0b4h		;5bff
	ld (0e004h),a		;5c01
	jr L_5B95		;5c04
el_rotulo_del_final_se_escribe_solo:
	ld hl,0e6a4h		;5c06
	dec (hl)			;5c09   ; su reloj
	ret m			;5c0a
	ld hl,(0e6a0h)		;5c0b   ; por donde va
	ld bc,(0e6a2h)		;5c0e
	ld a,c			;5c12
	cp b			;5c13   ; hasta que se acaba la linea
	jr c,L_5C36		;5c14
	push af			;5c16
	push bc			;5c17
	call L_5C67		;5c18
	pop bc			;5c1b
	ld a,c			;5c1c
	dec a			;5c1d
	call suma_a_a_hl		;5c1e
	call L_5C67		;5c21
	ld hl,(0e6a0h)		;5c24
	inc hl			;5c27
	ld (0e6a0h),hl		;5c28
	ld a,(0e6a2h)		;5c2b
	dec a			;5c2e
	dec a			;5c2f
	ld (0e6a2h),a		;5c30
	pop af			;5c33
	jr nz,L_5C65		;5c34
L_5C36:
	ld bc,(0e6a2h)		;5c36   ; y entonces se borra lo que sobra
	xor a			;5c3a
	ld b,a			;5c3b
	inc bc			;5c3c
	push bc			;5c3d
	push hl			;5c3e
	call 00056h		;5c3f   ; BIOS FILVRM - Fills VRAM with value
	ld hl,(0e6a3h)		;5c42   ; y se pasa a la linea siguiente
	dec l			;5c45
	xor a			;5c46
	ld h,a			;5c47
	add hl,hl			;5c48
	add hl,hl			;5c49
	add hl,hl			;5c4a
	add hl,hl			;5c4b
	add hl,hl			;5c4c
	pop de			;5c4d
	add hl,de			;5c4e
	pop bc			;5c4f
	call 00056h		;5c50   ; BIOS FILVRM - Fills VRAM with value
	ld hl,(0e6a0h)		;5c53   ; 0x20 casillas mas abajo
	ld de,00020h		;5c56
	add hl,de			;5c59
	ld (0e6a0h),hl		;5c5a
	ld a,(0e6a3h)		;5c5d
	dec a			;5c60
	dec a			;5c61
	ld (0e6a3h),a		;5c62
L_5C65:
	xor a			;5c65
	ret			;5c66
L_5C67:
	push hl			;5c67
	xor a			;5c68
	ld de,00020h		;5c69
L_5C6C:
	call 0004dh		;5c6c   ; BIOS WRTVRM - Writes data in VRAM
	add hl,de			;5c6f
	djnz L_5C6C		;5c70
	pop hl			;5c72
	ret			;5c73

; ----------------------------------------------------------------------
; DATOS sprites_del_final: Cuatro tercias [dy][dx][patron] a 0x3B30 (0x5B48)
;   0x5c74..0x5c80  (12 bytes)
DATA_5C74:
	defb 0fbh,003h,00bh	; 5c74
	defb 0f8h,000h,006h	; 5c77
	defb 006h,001h,00fh	; 5c7a
	defb 009h,004h,007h	; 5c7d

; ----------------------------------------------------------------------
; DATOS cinco_bytes_a_0xE6A0: Los copia 0x5B9F
;   0x5c80..0x5c85  (5 bytes)
DATA_cinco_bytes_a_0xE6A0:
	defb 000h,038h,020h,016h,00dh	; 5c80

; ----------------------------------------------------------------------
; DATOS rotulo_you_have_beaten_all_demons: YOU HAVE BEATEN ALL DEMONS ! en la
;   fila 13, columna 2 (tools/guiones.py)
;   0x5c85..0x5ca4  (31 bytes)
DATA_rotulo_you_have_beaten_all_demons:
	defb 0a2h,039h,02eh,022h,02ch,000h,01fh,01bh,026h,01dh,000h,032h,01dh,01bh,025h,01dh	; 5c85  .9.",...&..2..%.
	defb 02ah,000h,01bh,029h,029h,000h,030h,01dh,021h,022h,02ah,024h,000h,031h,0ffh	; 5c95  *..)).0.!"*$.1.

; ----------------------------------------------------------------------
; DATOS rotulo_love_is_forever: LOVE IS FOREVER... en la fila 15, columna 7.
;   Es lo ultimo que dice el cartucho
;   0x5ca4..0x5cb9  (21 bytes)
DATA_rotulo_love_is_forever:
	defb 0e7h,039h,029h,022h,026h,01dh,000h,020h,024h,000h,027h,022h,023h,01dh,026h,01dh	; 5ca4  .9)"&.. $.'"#.&.
	defb 023h,02fh,02fh,02fh,0ffh	; 5cb4

; ----------------------------------------------------------------------
; DATOS patrones_del_final: Comprimido con palabra; 128 bytes = 4 patrones
;   (0x5BF3)
;   0x5cb9..0x5d02  (73 bytes)
DATA_patrones_del_final:
	defb 060h,018h,08ch,088h,049h,07fh,055h,03eh,000h,010h,03eh,06bh,07fh,036h,01ch,004h	; 5cb9  `...I.U>..>k.6..
	defb 000h,081h,080h,016h,000h,089h,008h,01fh,03dh,038h,032h,070h,0f9h,0e0h,040h,007h	; 5cc9  ........=82p..@.
	defb 000h,092h,020h,0f0h,0f8h,038h,098h,01ch,03eh,00eh,004h,038h,07fh,03fh,007h,030h	; 5cd9  .. ..8..>..8.?.0
	defb 07dh,07fh,0ffh,03fh,007h,000h,089h,0e0h,0f0h,0e0h,000h,060h,0f0h,0f0h,0f8h,0e0h	; 5ce9  }..?.......`....
	defb 007h,000h,083h,0c6h,07ch,010h,01dh,000h,000h	; 5cf9  ....|....

; ======================================================================
; CODIGO 0x5d02..0x5d0c  (10 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; ====================================================================
; EL MUNECO. (0xE600) es su estado y reparte por la tabla de 0x5D0C:
; 0 = jugando, 1 = recogiendo, 2 = muriendose, 3 = se acabo.
; ====================================================================
; ----------------------------------------------------------------------
haz_el_muneco:
	ld ix,0e600h		;5d02
	ld a,(ix+000h)		;5d06   ; su estado
	call reparte_por_tabla		;5d09

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_5D0C: 4 entradas; tras el `call 406Ch` de 0x5D09;
;   sigue en 0x5D14
;   0x5d0c..0x5d14  (8 bytes)
DATA_tabla_de_reparto_5D0C:
	defw 05d14h,05d30h,05d47h,05d95h	; 5d0c  -> muneco_jugando muneco_recogiendo muneco_muriendose muneco_acabado

; ======================================================================
; CODIGO 0x5d14..0x60bd  (937 bytes)
; ======================================================================


muneco_jugando:
	call mueve_al_muneco_con_el_mando		;5d14   ; mirar el mando y moverse
	ld a,(ix+00ch)		;5d17
	cp 003h		;5d1a   ; con la animacion 3 no se recoge nada
	jr z,L_5D2D		;5d1c
	ld a,(0e008h)		;5d1e
	bit 4,a		;5d21   ; el bit 4 de (0xE008) es lo que se acaba de pulsar
	jr z,L_5D2D		;5d23
	ld (ix+000h),001h		;5d25   ; al estado 1
	ld (ix+00bh),000h		;5d29
L_5D2D:
	jp pinta_al_muneco		;5d2d
muneco_recogiendo:
	call mueve_al_muneco_con_el_mando		;5d30
	inc (ix+00bh)		;5d33   ; seis cuadros de recogida
	ld a,(ix+00bh)		;5d36
	cp 004h		;5d39
	call z,suelta_un_disparo		;5d3b   ; al cuarto se aplica lo recogido
	cp 006h		;5d3e
	jr c,L_5D2D		;5d40
	ld (ix+000h),000h		;5d42   ; y vuelta a jugar
	ret			;5d46
muneco_muriendose:
	dec (ix+00bh)		;5d47   ; la cuenta atras de la muerte
	ld a,(ix+00bh)		;5d4a
	jr z,L_5D85		;5d4d   ; al llegar a cero, se acabo la vida
	cp 051h		;5d4f   ; los primeros 0x50 cuadros solo parpadea
	jr c,L_5D61		;5d51
	bit 2,a		;5d53   ; el bit 2 alterna entre cian y blanco
	ld a,007h		;5d55
	jr z,L_5D5B		;5d57
	ld a,00fh		;5d59
L_5D5B:
	ld hl,03b07h		;5d5b   ; el color del segundo sprite del muneco
	jp 0004dh		;5d5e   ; BIOS WRTVRM - Writes data in VRAM
L_5D61:
	ld b,000h		;5d61   ; y de 0x50 abajo va cambiando de fotograma cada ocho cuadros
	cp 049h		;5d63
	jr nc,L_5D89		;5d65
	inc b			;5d67
	cp 041h		;5d68
	jr nc,L_5D89		;5d6a
	inc b			;5d6c
	cp 039h		;5d6d
	jr nc,L_5D89		;5d6f
	inc b			;5d71
	cp 031h		;5d72
	jr nc,L_5D89		;5d74
	ld hl,03b00h		;5d76   ; y aparcando sus sprites de dos en dos
	cp 029h		;5d79
	jr nc,L_5D80		;5d7b
	ld hl,03b04h		;5d7d
L_5D80:
	ld a,0c3h		;5d80
	jp 0004dh		;5d82   ; BIOS WRTVRM - Writes data in VRAM
L_5D85:
	ld (0e064h),a		;5d85   ; (0xE064) a cero: la escena se entera de que se acabo
	ret			;5d88
L_5D89:
	ld (ix+006h),b		;5d89   ; el fotograma de la explosion
	ld de,0a60bh		;5d8c   ; y sus atributos, los de 0xA60B
	ld (ix+00ch),004h		;5d8f
	jr pinta_al_muneco_muriendose		;5d93
muneco_acabado:
	ld b,(ix+00bh)		;5d95
	djnz L_5DBD		;5d98
	call arrastra_y_pinta_al_muneco		;5d9a   ; mira si hay que soltarlo por donde entro
	cp 020h		;5d9d   ; por debajo de la fila 0x20
	jr c,L_5DAD		;5d9f
	ld a,(0e675h)		;5da1   ; y con la columna cuadrada
	and 07fh		;5da4
	ret nz			;5da6
	ld a,(ix+004h)		;5da7
	cp 078h		;5daa
	ret nz			;5dac
L_5DAD:
	inc (ix+00bh)		;5dad   ; y a la fase siguiente
	ld hl,00000h		;5db0
	ld (0e678h),hl		;5db3
	ld hl,0ff50h		;5db6
	ld (0e676h),hl		;5db9
	ret			;5dbc
L_5DBD:
	djnz L_5DCB		;5dbd   ; la segunda vuelta del remate
	call arrastra_y_pinta_al_muneco		;5dbf   ; si esta abajo del todo
	cp 005h		;5dc2
	ret nc			;5dc4
	ld a,001h		;5dc5
	ld (0e00dh),a		;5dc7   ; (0xE00D) avisa a la escena de que se ha acabado el tramo
	ret			;5dca
L_5DCB:
	inc (ix+00bh)		;5dcb   ; y si no, sale por arriba
	call aparca_los_sprites_del_muneco		;5dce
	call angulo_hasta_el_muneco		;5dd1
	ld (0e675h),a		;5dd4   ; (0xE675) es su posicion dentro de la pantalla siguiente
	call seno_y_coseno		;5dd7
	ld a,(0e675h)		;5dda
	and 07fh		;5ddd
	cp 005h		;5ddf   ; fuera del margen 0x05..0x7B se recoloca en el borde
	jr c,L_5DE7		;5de1
	cp 07bh		;5de3
	jr c,L_5DED		;5de5
L_5DE7:
	xor a			;5de7
	ld (0e675h),a		;5de8
	ld b,a			;5deb
	ld c,a			;5dec
L_5DED:
	ld (0e676h),bc		;5ded
	ld (0e678h),de		;5df1
	ld a,0b7h		;5df5   ; y suena el paso de tramo
	jp pide_pieza		;5df7
pinta_al_muneco_muriendose:
	ld hl,03b00h		;5dfa
	jr L_5E24		;5dfd
pinta_al_muneco:
	ld hl,03b00h		;5dff
L_5E02:
	ld de,0a5c2h		;5e02   ; los atributos corrientes
	ld a,(ix+00ch)		;5e05
	cp 002h		;5e08   ; con la animacion 2 se alterna con los de 0xA5EF
	jr nz,L_5E24		;5e0a
	ld de,0a5efh		;5e0c
	ld a,(ix+00eh)		;5e0f
	cp 012h		;5e12   ; y solo por debajo de 0x12
	jr nc,L_5E24		;5e14
	ld a,(0e003h)		;5e16
	bit 3,a		;5e19
	jr z,L_5E24		;5e1b
	ld de,0a5c2h		;5e1d
	ld (ix+00ch),080h		;5e20
L_5E24:
	call 00053h		;5e24   ; BIOS SETWRT - Enables VDP to write
	ld a,(00007h)		;5e27
	ld c,a			;5e2a
	ld b,003h		;5e2b
pinta_los_tres_sprites_del_muneco:
	push bc			;5e2d
	call L_5ED5		;5e2e
	ld a,003h		;5e31   ; el patron: 0, 4 y 8
	sub b			;5e33
	add a,a			;5e34
	add a,a			;5e35
	out (c),a		;5e36
	ld a,(ix+00ch)		;5e38   ; con la animacion 3 y el color 7...
	cp 003h		;5e3b
	ld a,(de)			;5e3d
	jr nz,pinta_el_resto_del_muneco		;5e3e
	cp 007h		;5e40
	jr nz,pinta_el_resto_del_muneco		;5e42
	ld a,(ix+00eh)		;5e44   ; ...y por debajo de 0x12, parpadea
	cp 012h		;5e47
	jr nc,L_5E53		;5e49
	ld a,(0e003h)		;5e4b
	bit 2,a		;5e4e
	ld a,(de)			;5e50
	jr nz,pinta_el_resto_del_muneco		;5e51
L_5E53:
	ld a,006h		;5e53
pinta_el_resto_del_muneco:
	out (c),a		;5e55
	inc de			;5e57
	pop bc			;5e58
	djnz pinta_los_tres_sprites_del_muneco		;5e59
	ld a,(ix+00ch)		;5e5b
	dec a			;5e5e   ; la animacion 1 lleva un sprite mas
	jr nz,L_5E7E		;5e5f
	ld de,0a5dah		;5e61
	call L_5ED5		;5e64
	ld a,(de)			;5e67
	out (c),a		;5e68
	ld b,007h		;5e6a
	ld a,(ix+00fh)		;5e6c   ; y su color cambia con lo que quede de escudo
	cp 00ah		;5e6f
	jr nc,L_5E7A		;5e71
	ld b,00ah		;5e73
	cp 005h		;5e75
	jr nc,L_5E7A		;5e77
	dec b			;5e79
L_5E7A:
	out (c),b		;5e7a
	jr L_5E82		;5e7c
L_5E7E:
	ld a,0c3h		;5e7e
	out (c),a		;5e80
L_5E82:
	ld hl,0a5b4h		;5e82
	ld a,(ix+00ch)		;5e85   ; la animacion, en los cuatro bits bajos
	and 00fh		;5e88
	call palabra_de_tabla_en_hl		;5e8a
	ld a,(ix+006h)		;5e8d   ; y el fotograma dentro de ella
	call palabra_de_tabla_doble		;5e90
	bit 7,(ix+00ch)		;5e93
	jr z,L_5E9D		;5e97
	ld (ix+00ch),002h		;5e99
L_5E9D:
	ld hl,01800h		;5e9d
	call 00053h		;5ea0   ; BIOS SETWRT - Enables VDP to write
	ex de,hl			;5ea3
L_5EA4:
	ld a,(hl)			;5ea4   ; el byte de cuenta del guion
	and a			;5ea5
	ret z			;5ea6   ; el 0x00 lo cierra
	inc hl			;5ea7
	ld e,(hl)			;5ea8   ; y detras, el puntero a los datos
	inc hl			;5ea9
	ld d,(hl)			;5eaa
	inc hl			;5eab
	inc a			;5eac
	jr nz,L_5ECB		;5ead
L_5EAF:
	ld a,(de)			;5eaf
	and a			;5eb0   ; el 0x00 cierra el tramo
	jr z,L_5EA4		;5eb1
	inc de			;5eb3
	ld b,a			;5eb4
	and 07fh		;5eb5   ; sin el bit 7: la cuenta
	cp b			;5eb7
	ld b,a			;5eb8
	jr z,L_5EC3		;5eb9
L_5EBB:
	ld a,(de)			;5ebb
	inc de			;5ebc
	out (c),a		;5ebd
	djnz L_5EBB		;5ebf
	jr L_5EAF		;5ec1
L_5EC3:
	ld a,(de)			;5ec3
	inc de			;5ec4
L_5EC5:
	out (c),a		;5ec5
	djnz L_5EC5		;5ec7
	jr L_5EAF		;5ec9
L_5ECB:
	ld b,020h		;5ecb
L_5ECD:
	ld a,(de)			;5ecd
	inc de			;5ece
	out (c),a		;5ecf
	djnz L_5ECD		;5ed1
	jr L_5EA4		;5ed3
L_5ED5:
	ld a,(ix+008h)		;5ed5   ; con el fotograma 0x0B o 0x0C
	and 00ch		;5ed8
	cp 00bh		;5eda
	jr z,L_5EE3		;5edc
	cp 00ch		;5ede
	ld a,(de)			;5ee0   ; la fila del sprite
	jr nz,L_5EE5		;5ee1
L_5EE3:
	ld a,(de)			;5ee3
	dec a			;5ee4
L_5EE5:
	add a,(ix+002h)		;5ee5   ; la fila del sprite, mas la del muneco
	out (c),a		;5ee8
	inc de			;5eea
	ld a,(ix+004h)		;5eeb   ; y la columna
	out (c),a		;5eee
	ret			;5ef0

; ----------------------------------------------------------------------
; EL MANDO. Lee lo que hay pulsado en (0xE009) y mueve al muneco: los
; dos bits bajos son arriba y abajo, los dos siguientes izquierda y
; derecha, y cada eje se mueve por separado con su tope.
; ----------------------------------------------------------------------
mueve_al_muneco_con_el_mando:
	ld a,(0e008h)		;5ef1   ; lo que se acaba de pulsar
	bit 5,a		;5ef4   ; el bit 5 es el segundo boton: cambia de arma
	jr z,L_5F11		;5ef6
	ld hl,0e069h		;5ef8   ; solo si hay armas cogidas
	ld a,(hl)			;5efb
	and 01fh		;5efc
	jr z,L_5F11		;5efe
	bit 4,a		;5f00   ; con el bit 4 puesto no rota
	jr nz,L_5F0C		;5f02
	inc (hl)			;5f04   ; y si no, la siguiente de las cuatro
	ld a,(hl)			;5f05
	cp 004h		;5f06
	jr c,L_5F0C		;5f08
	ld (hl),000h		;5f0a
L_5F0C:
	ld hl,0e60ch		;5f0c
	ld (hl),002h		;5f0f   ; medio segundo de espera para que no se pase de largo
L_5F11:
	ld hl,062e2h		;5f11   ; la pareja de velocidades que toca, de la tabla de 0x62E2
	ld a,(ix+00ch)		;5f14
	cp 003h		;5f17   ; con la animacion 3 vale la quinta pareja
	ld a,(ix+00ah)		;5f19
	jr nz,L_5F20		;5f1c
	ld a,004h		;5f1e
L_5F20:
	add a,a			;5f20
	call suma_a_a_hl		;5f21
	ld b,(hl)			;5f24
	inc hl			;5f25
	ld c,(hl)			;5f26
	ld a,(0e009h)		;5f27   ; sin nada pulsado, a parar
	and 00fh		;5f2a
	call z,para_al_muneco		;5f2c
	and 003h		;5f2f   ; los dos bits bajos: arriba y abajo
	jr z,L_5F5B		;5f31
	ld e,(ix+001h)		;5f33   ; se guarda donde estaba, por si hay que devolverlo
	ld d,(ix+002h)		;5f36
	ld (0e074h),de		;5f39
	ld l,b			;5f3d
	call suma_el_paso		;5f3e   ; y se mueve
	ld (ix+001h),l		;5f41
	ld a,020h		;5f44   ; topado por arriba en 0x20...
	cp h			;5f46
	jr c,L_5F4A		;5f47
	ld h,a			;5f49
L_5F4A:
	ld a,09fh		;5f4a   ; ...y por abajo en 0x9F
	cp h			;5f4c
	jr nc,L_5F50		;5f4d
	ld h,a			;5f4f
L_5F50:
	ld (ix+002h),h		;5f50
	ld a,(0e009h)		;5f53
	and 00ch		;5f56
	call z,suma_al_recorrido		;5f58
L_5F5B:
	ld a,(0e009h)		;5f5b
	and 00ch		;5f5e   ; los dos siguientes: izquierda y derecha
	jr z,L_5F8C		;5f60
	ld e,(ix+003h)		;5f62
	ld d,(ix+004h)		;5f65
	ld (0e076h),de		;5f68
	ld l,c			;5f6c
	rra			;5f6d   ; los bits, bajados a su sitio
	rra			;5f6e
	call suma_el_paso		;5f6f
	ld (ix+003h),l		;5f72
	ld a,003h		;5f75   ; topado a la izquierda en 3...
	cp h			;5f77
	jr c,L_5F7B		;5f78
	ld h,a			;5f7a
L_5F7B:
	ld a,0efh		;5f7b   ; ...y a la derecha en 0xEF
	cp h			;5f7d
	jr nc,L_5F81		;5f7e
	ld h,a			;5f80
L_5F81:
	ld (ix+004h),h		;5f81
	ld a,(0e009h)		;5f84
	and 00ch		;5f87
	call nz,suma_al_recorrido		;5f89
L_5F8C:
	call elige_el_fotograma		;5f8c   ; el fotograma que toca
	call choca_con_el_decorado		;5f8f   ; y el arma
	ld a,(0e3b0h)		;5f92   ; en la pantalla del jefe
	or a			;5f95
	jr z,L_5FB0		;5f96
	ld a,(0e3c0h)		;5f98
	or a			;5f9b
	jr nz,L_5FB0		;5f9c
	ld a,(0e062h)		;5f9e
	cp 006h		;5fa1   ; la fase 6 tiene lo suyo
	jr nz,L_5FAB		;5fa3
	ld a,(0e3d0h)		;5fa5
	or a			;5fa8
	jr z,L_5FB0		;5fa9
L_5FAB:
	call toca_el_decorado_al_muneco		;5fab   ; mira si choca con el decorado
	jr nc,L_5FBB		;5fae
L_5FB0:
	ld a,(ix+002h)		;5fb0
	cp 0a0h		;5fb3   ; y si se pasa de 0xA0, se le clava en 0x9F
	jr c,L_5FBF		;5fb5
	ld (ix+002h),09fh		;5fb7
L_5FBB:
	pop hl			;5fbb
	jp mata_al_muneco		;5fbc
L_5FBF:
	ld a,(ix+00ch)		;5fbf   ; con la animacion 0 o 1 no hay nada mas que hacer
	cp 002h		;5fc2
	ret c			;5fc4
	call pinta_la_municion		;5fc5   ; pinta la municion que queda
	dec (ix+00dh)		;5fc8   ; y cada 0x14 cuadros se gasta una
	ret nz			;5fcb
	ld (ix+00dh),014h		;5fcc
	ld a,(ix+00eh)		;5fd0
	or a			;5fd3
	jr z,L_5FDD		;5fd4
	cp 012h		;5fd6   ; por debajo de 0x12 avisa de que se acaba
	ld a,013h		;5fd8
	call c,pide_pieza_si_la_escena_lo_permite		;5fda
L_5FDD:
	ld a,(ix+00eh)		;5fdd
	sub 001h		;5fe0   ; una menos, en BCD
	daa			;5fe2
	ld (ix+00eh),a		;5fe3
	ret nz			;5fe6
	ld a,(ix+00fh)		;5fe7   ; al llegar a cero se vuelve al arma corriente
	or a			;5fea
	ld c,000h		;5feb
	jr z,L_5FF0		;5fed
	inc c			;5fef
L_5FF0:
	ld (ix+00ch),c		;5ff0
	ld a,014h		;5ff3
	call pide_pieza_si_la_escena_lo_permite		;5ff5
pinta_la_municion:
	ld hl,03824h		;5ff8   ; en la fila 1, columna 4
	ld de,0e60eh		;5ffb
	ld b,001h		;5ffe
	jp escribe_en_bcd		;6000

; ----------------------------------------------------------------------
; UN PASO CON SIGNO. HL trae la velocidad en dieciseisavos; el primer bit
; de A dice si se resta y el segundo si se suma, o sea que con los dos
; puestos -las dos direcciones a la vez- el muneco se queda quieto.
; ----------------------------------------------------------------------
suma_el_paso:
	ld h,000h		;6003
	add hl,hl			;6005   ; por dieciseis: la parte entera del paso
	add hl,hl			;6006
	add hl,hl			;6007
	add hl,hl			;6008
	ex de,hl			;6009
	rra			;600a   ; el primer bit: hacia atras
	jr nc,L_6010		;600b
	or a			;600d
	sbc hl,de		;600e
L_6010:
	rra			;6010   ; y el segundo: hacia delante
	ret nc			;6011
	add hl,de			;6012
	ret			;6013
elige_el_fotograma:
	ld a,(ix+008h)		;6014   ; el contador de animacion
L_6017:
	rra			;6017   ; su bit 3 alterna los dos fotogramas
	rra			;6018
	rra			;6019
	and 001h		;601a
	ld b,(ix+006h)		;601c   ; y el de antes se guarda, que el pintor lo compara
	ld (ix+005h),b		;601f
	ld (ix+006h),a		;6022
	ret			;6025

; ----------------------------------------------------------------------
; SOLTAR UN DISPARO. Busca una ranura libre de las cuatro de 0xE620 y la
; llena con el arma que lleva el muneco.
; ----------------------------------------------------------------------
suelta_un_disparo:
	ld a,(ix+009h)		;6026   ; el arma
	ld c,a			;6029
	ld hl,060bdh		;602a   ; su pareja [cuantos][ajuste de y] de la tabla de 0x60BD
	add a,a			;602d
	call suma_a_a_hl		;602e
	ld b,(hl)			;6031
	inc hl			;6032
	ld d,(hl)			;6033
	ld hl,0e620h		;6034   ; las cuatro ranuras
L_6037:
	bit 7,(hl)		;6037   ; con el bit 7 puesto la ranura esta ocupada
	jr z,L_604E		;6039
	ld a,c			;603b
	srl a		;603c   ; el arma 4 -la de tres disparos- necesita ademas las dos de al lado
	cp 004h		;603e
	jr nz,L_6056		;6040
	push hl			;6042
	pop iy		;6043
	ld a,(iy+010h)		;6045
	or (iy+020h)		;6048
	rla			;604b
	jr c,L_6056		;604c
L_604E:
	ld a,010h		;604e   ; a la siguiente, 0x10 mas alla
	call suma_a_a_hl		;6050
	djnz L_6037		;6053
	ret			;6055
L_6056:
	res 7,(hl)		;6056   ; ranura tomada
	res 4,(hl)		;6058
	inc hl			;605a
	inc hl			;605b
	ld a,(ix+002h)		;605c   ; la x del muneco, ocho a la izquierda
	sub 008h		;605f
	ld (hl),a			;6061
	inc hl			;6062
	inc hl			;6063
	ld a,(ix+004h)		;6064   ; y la y con el ajuste del arma
	add a,d			;6067
	ld (hl),a			;6068
	inc hl			;6069
	ld (hl),c			;606a   ; el arma, en su sitio
	inc hl			;606b
	xor a			;606c
	ld (hl),a			;606d
	inc hl			;606e
	ld (hl),a			;606f
	inc hl			;6070
	ld de,06442h		;6071   ; y el recorrido, que es siempre 0x6442
	ld (hl),e			;6074
	inc hl			;6075
	ld (hl),d			;6076
	ld a,c			;6077
	srl a		;6078
	ld c,a			;607a
	ld hl,060d5h		;607b   ; el sonido del arma
	call suma_a_a_hl		;607e
	ld a,(hl)			;6081
	call pide_pieza_si_la_escena_lo_permite		;6082
	ld a,c			;6085
	cp 004h		;6086   ; el arma 4 se copia a las dos ranuras de al lado
	ret nz			;6088
	ld hl,0e621h		;6089
	ld de,0e631h		;608c
	ld bc,0000fh		;608f
	ldir		;6092
	res 7,(hl)		;6094
	inc hl			;6096
	inc de			;6097
	ld c,00fh		;6098
	ldir		;609a
	res 7,(hl)		;609c
	ld a,(ix+009h)		;609e
	cp 009h		;60a1
	ret nz			;60a3
	ld a,(iy+002h)		;60a4
	add a,010h		;60a7
	ld (iy+012h),a		;60a9
	ld (iy+022h),a		;60ac
	ld a,(iy+004h)		;60af
	sub 010h		;60b2
	ld (iy+014h),a		;60b4
	add a,020h		;60b7
	ld (iy+024h),a		;60b9
	ret			;60bc

; ----------------------------------------------------------------------
; DATOS treinta_bytes_de_0x602A: 0x602A y 0x607B los indexan
;   0x60bd..0x60db  (30 bytes)
DATA_treinta_bytes_de_0x602A:
	defb 002h,006h,002h,006h,002h,002h,003h,002h,003h,005h,003h,002h,002h,003h,003h	; 60bd  ...............
	defb 003h,001h,006h,001h,006h,002h,004h,003h,004h,003h,003h,044h,005h,006h,006h	; 60cc  ...........D...

; ======================================================================
; CODIGO 0x60db..0x6216  (315 bytes)
; ======================================================================


arrastra_y_pinta_al_muneco:
	call arrastra_al_muneco		;60db
	call L_6017		;60de   ; y el fotograma
pinta_al_muneco_en_0x3B20:
	ld hl,03b20h		;60e1
	call L_5E02		;60e4
	ld a,(ix+002h)		;60e7
	ret			;60ea
arrastra_al_muneco:
	ld l,(ix+003h)		;60eb   ; su posicion vertical
	ld h,(ix+004h)		;60ee
	ld de,(0e678h)		;60f1   ; mas el arrastre del tramo, que es lo que hace el scroll
	add hl,de			;60f5
	ld (ix+003h),l		;60f6
	ld (ix+004h),h		;60f9
	ld l,(ix+001h)		;60fc   ; y lo mismo con la horizontal
	ld h,(ix+002h)		;60ff
	ld de,(0e676h)		;6102
	add hl,de			;6106
	ld (ix+001h),l		;6107
	ld (ix+002h),h		;610a
	ld a,(0e003h)		;610d   ; devuelve en el acarreo el bit 0 del contador de cuadros
	rra			;6110
	ret			;6111
aparca_los_sprites_del_muneco:
	ld hl,03b00h		;6112
	ld bc,00020h		;6115   ; los ocho primeros atributos, a cero
	xor a			;6118
	call 00056h		;6119   ; BIOS FILVRM - Fills VRAM with value
	ld hl,03b00h		;611c
	ld b,008h		;611f   ; y aparcados: los cuatro primeros en la fila 5 y los otros abajo del todo
L_6121:
	ld a,b			;6121
	cp 005h		;6122
	ld a,005h		;6124
	jr c,L_612A		;6126
	ld a,0fch		;6128
L_612A:
	call 0004dh		;612a   ; BIOS WRTVRM - Writes data in VRAM
	inc hl			;612d
	inc hl			;612e
	inc hl			;612f
	inc hl			;6130
	djnz L_6121		;6131
	ld hl,0e330h		;6133   ; y la sombra de 0xE330 en adelante, con 0xC3
	ld de,0e331h		;6136
	ld bc,0004fh		;6139
	ld (hl),0c3h		;613c
	ldir		;613e
	ret			;6140
para_al_muneco:
	push af			;6141
	xor a			;6142
	ld (ix+001h),a		;6143   ; las dos fracciones de posicion, a cero
	ld (ix+003h),a		;6146
	ld l,b			;6149   ; y el paso por ocho
	ld h,000h		;614a
	add hl,hl			;614c
	add hl,hl			;614d
	add hl,hl			;614e
	ex de,hl			;614f
	call suma_al_recorrido		;6150
	pop af			;6153
	ret			;6154
suma_al_recorrido:
	ld l,(ix+007h)		;6155   ; el recorrido
	ld h,(ix+008h)		;6158
	add hl,de			;615b   ; mas el paso
	ld (ix+007h),l		;615c
	ld (ix+008h),h		;615f
	ret			;6162

; ----------------------------------------------------------------------
; CHOCAR CON EL DECORADO. Lee de la VRAM las OCHO casillas que rodean al
; muneco -los desplazamientos estan en 0x6216-, las guarda en 0xE610 y
; para cada direccion pulsada mira si las dos de ese lado dejan pasar. Si
; no, se devuelve la posicion que se habia guardado antes de moverse.
; ----------------------------------------------------------------------
choca_con_el_decorado:
	ld hl,06216h		;6163   ; los ocho desplazamientos
	ld iy,0e610h		;6166   ; y donde se guardan las ocho casillas
	ld b,008h		;616a
L_616C:
	ld a,(ix+002h)		;616c
	add a,(hl)			;616f   ; la x del muneco mas el desplazamiento
	inc hl			;6170
	ld e,a			;6171
	ld a,(ix+004h)		;6172   ; y la y
	add a,(hl)			;6175
	inc hl			;6176
	ld d,a			;6177
	ex de,hl			;6178
	call de_pixeles_a_direccion		;6179   ; de pixeles a casilla
	call 0004ah		;617c   ; BIOS RDVRM - Reads the content of VRAM | leida de la VRAM
	ld (iy+000h),a		;617f
	ex de,hl			;6182
	inc iy		;6183
	djnz L_616C		;6185
	ld iy,0e610h		;6187
	ld hl,(0e074h)		;618b   ; la posicion vertical de antes de moverse
	ld a,(0e009h)		;618e
	rra			;6191   ; el primer bit: arriba
	push af			;6192
	jr nc,L_61AB		;6193
	ld a,(iy+000h)		;6195   ; las dos casillas de arriba
	call se_puede_pisar		;6198
	jr nc,L_61AB		;619b
	ld a,(iy+001h)		;619d
	call se_puede_pisar		;61a0
	jr nc,L_61AB		;61a3
	ld (ix+001h),l		;61a5   ; alguna estorba: se devuelve la y
	ld (ix+002h),h		;61a8
L_61AB:
	pop af			;61ab
	rra			;61ac   ; el segundo: abajo
	push af			;61ad
	jr nc,L_61C6		;61ae
	ld a,(iy+004h)		;61b0   ; las dos casillas de abajo
	call se_puede_pisar		;61b3
	jr nc,L_61C6		;61b6   ; alguna estorba: se devuelve la y
	ld a,(iy+005h)		;61b8
	call se_puede_pisar		;61bb
	jr nc,L_61C6		;61be
	ld (ix+001h),l		;61c0
	ld (ix+002h),h		;61c3
L_61C6:
	pop af			;61c6
	ld hl,(0e076h)		;61c7   ; y aqui la horizontal
	rra			;61ca   ; el tercero: izquierda
	push af			;61cb
	jr nc,L_61EC		;61cc
	ld a,(iy+002h)		;61ce
	call se_puede_pisar		;61d1
	jr c,L_61E6		;61d4
	ld a,(iy+000h)		;61d6
	call se_puede_pisar		;61d9
	jr nc,L_61EC		;61dc
	ld a,(iy+004h)		;61de
	call se_puede_pisar		;61e1
	jr nc,L_61EC		;61e4
L_61E6:
	ld (ix+003h),l		;61e6
	ld (ix+004h),h		;61e9
L_61EC:
	pop af			;61ec
	rra			;61ed   ; y el cuarto: derecha
	ret nc			;61ee
	ld a,(iy+003h)		;61ef   ; las dos de la derecha
	call se_puede_pisar		;61f2
	jr c,L_6205		;61f5
	ld a,(iy+001h)		;61f7   ; y si esa no, las de las esquinas
	call se_puede_pisar		;61fa
	ret nc			;61fd
	ld a,(iy+005h)		;61fe
	call se_puede_pisar		;6201
	ret nc			;6204
L_6205:
	ld (ix+003h),l		;6205
	ld (ix+004h),h		;6208
	ret			;620b

; ----------------------------------------------------------------------
; DEJA PASAR ESTA CASILLA? Las casillas de 0x43 a 0x7F y las de 0xA3 a
; 0xDF son suelo; el resto, pared. Devuelve el acarreo puesto si se pasa.
; ----------------------------------------------------------------------
se_puede_pisar:
	sub 043h		;620c   ; de 0x43 arriba...
	cp 03dh		;620e   ; ...y menos de 0x3D mas alla: 0x43..0x7F
	ret c			;6210
	sub 060h		;6211   ; y lo mismo 0x60 mas alla, que es el banco espejado
	cp 03dh		;6213
	ret			;6215

; ----------------------------------------------------------------------
; DATOS pares_de_0x6163: Dieciseis bytes, en parejas
;   0x6216..0x6226  (16 bytes)
DATA_pares_de_0x6163:
	defb 001h,004h	; 6216
	defb 001h,00bh	; 6218
	defb 008h,002h	; 621a
	defb 008h,00dh	; 621c
	defb 00eh,004h	; 621e
	defb 00eh,00bh	; 6220
	defb 0f9h,004h	; 6222
	defb 0f9h,00bh	; 6224

; ======================================================================
; CODIGO 0x6226..0x6262  (60 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL ANGULO AL MUNECO. Da el angulo, de 0 a 63, en el que queda el
; muneco visto desde (ix+2),(ix+4). Divide el cateto vertical entre el
; horizontal con 0x8569 y busca el resultado en la tabla de tangentes de
; 0x6262: la primera entrada que se le queda por debajo da el angulo.
; ----------------------------------------------------------------------
angulo_hasta_el_muneco:
	ld a,(ix+002h)		;6226   ; el cateto horizontal, contado desde 0x20
	sub 020h		;6229
	ld l,000h		;622b
	jr z,L_6230		;622d
	ld l,a			;622f
L_6230:
	ld a,078h		;6230   ; y el vertical, desde 0x78
	sub (ix+004h)		;6232
	ld d,000h		;6235
	ld b,d			;6237
	jr z,L_6240		;6238
	jr nc,L_623F		;623a
	inc d			;623c   ; con D a uno se ha cruzado el eje: el angulo va del otro lado
	neg		;623d
L_623F:
	ld b,a			;623f
L_6240:
	push de			;6240
	ld h,000h		;6241
	call divide_con_fraccion		;6243   ; la division, que devuelve la tangente en DE con ocho bits de fraccion
	ld hl,06262h		;6246
	ld b,040h		;6249   ; las 64 entradas de la tabla
L_624B:
	ld a,(hl)			;624b   ; la palabra siguiente
	inc hl			;624c
	push hl			;624d
	ld h,(hl)			;624e
	ld l,a			;624f
	and a			;6250
	sbc hl,de		;6251   ; hasta que una se queda por debajo
	pop hl			;6253
	jr c,L_625A		;6254
	inc hl			;6256   ; y una entrada mas contada
	dec b			;6257
	jr nz,L_624B		;6258
L_625A:
	pop de			;625a
	dec d			;625b
	ld a,b			;625c   ; y el numero de entradas que quedaban es el angulo
	ret nz			;625d
	ld a,080h		;625e   ; o su complemento, si se cruzo el eje
	sub b			;6260
	ret			;6261

; ----------------------------------------------------------------------
; DATOS tabla_de_tangentes: 64 palabras que BAJAN de 0x28B5 a 0x0000: la
;   tangente, con ocho bits de fraccion, de los angulos 90 - (k+1)*90/64.
;   Comprobado entrada a entrada: 0x28B5/256 = 40,707 y tan(88,59) = 40,735;
;   la 31 da 0,996 y tan(45) = 1; la 62 da 0,023 y tan(1,41) = 0,025. 0x6226
;   la recorre con `ld b,040h` y el numero de entradas que quedan es el angulo
;   0x6262..0x62e2  (128 bytes)
DATA_tabla_de_tangentes:
	defw 028b5h,01459h,00d8dh,00a26h,0081bh,006bdh,005c3h,00506h	; 6262
	defw 00473h,003fdh,0039dh,0034bh,00306h,002cbh,00297h,0026ah	; 6272
	defw 00241h,0021dh,001fch,001deh,001c3h,001abh,00194h,0017fh	; 6282
	defw 0016bh,00159h,00148h,00137h,00128h,0011ah,0010ch,000ffh	; 6292
	defw 000f3h,000e8h,000dch,000d2h,000c7h,000bdh,000b4h,000abh	; 62a2
	defw 000a2h,00099h,00091h,00088h,00080h,00079h,00071h,0006ah	; 62b2
	defw 00062h,0005bh,00054h,0004dh,00046h,00040h,00039h,00032h	; 62c2
	defw 0002ch,00025h,0001fh,00019h,00012h,0000ch,00006h,00000h	; 62d2

; ----------------------------------------------------------------------
; DATOS cinco_parejas_de_0x5F11: 0x5F11 indexa con (ix+0x0A), o con un 4 fijo
;   si (ix+0x0C) vale 3
;   0x62e2..0x62ec  (10 bytes)
DATA_cinco_parejas_de_0x5F11:
	defb 00eh,010h	; 62e2
	defb 013h,015h	; 62e4
	defb 017h,01ah	; 62e6
	defb 01ch,01eh	; 62e8
	defb 020h,024h	; 62ea

; ======================================================================
; CODIGO 0x62ec..0x63fb  (271 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; ====================================================================
; LOS DISPAROS. Tres ranuras de 0x10 bytes desde 0xE620. El bit 7 de
; (ix+0) dice que la ranura esta libre; los cuatro bits bajos, cual es y
; (ix+5) que arma la lanzo.
; ====================================================================
; ----------------------------------------------------------------------
mueve_los_disparos:
	ld ix,0e620h		;62ec
	ld b,003h		;62f0
L_62F2:
	push bc			;62f2
	bit 7,(ix+000h)		;62f3   ; con el bit 7 puesto no hay disparo en esta ranura
	jr nz,L_6341		;62f7
	ld a,(ix+005h)		;62f9   ; el arma 8 tiene recorrido propio
	cp 008h		;62fc
	jr z,L_6305		;62fe
L_6300:
	call mueve_un_disparo_corriente		;6300   ; y las demas, el corriente
	jr L_6341		;6303
L_6305:
	ld a,(ix+000h)		;6305
	and 00fh		;6308   ; el numero de disparo dentro del arma
	jr z,L_6300		;630a
	dec a			;630c
	ld de,0fd00h		;630d   ; el primero sube -0x300 y el segundo baja +0x300
	jr z,L_6315		;6310
	ld de,00300h		;6312
L_6315:
	ld l,(ix+003h)		;6315   ; la posicion vertical
	ld h,(ix+004h)		;6318
	add hl,de			;631b
	ld (ix+003h),l		;631c
	ld (ix+004h),h		;631f
	ld a,h			;6322
	add a,009h		;6323   ; y fuera de pantalla se apaga
	cp 009h		;6325
	jr nc,L_632D		;6327
	set 7,(ix+000h)		;6329
L_632D:
	ld de,0f8a7h		;632d   ; 0xF8A7 es el paso horizontal: casi ocho a la izquierda
	call suma_el_paso_horizontal		;6330
	ld a,h			;6333
	sub 0e5h		;6334   ; fuera del margen 0xE5..0xEE, apagado
	cp 00ah		;6336
	jr nc,L_633E		;6338
	set 7,(ix+000h)		;633a
L_633E:
	call mira_si_el_disparo_toca_al_objeto		;633e   ; mira si le da a alguien
L_6341:
	call pinta_un_disparo		;6341   ; y se pinta
	ld de,00010h		;6344   ; la ranura siguiente
	add ix,de		;6347
	pop bc			;6349
	djnz L_62F2		;634a
	ret			;634c
mueve_un_disparo_corriente:
	ld a,(ix+005h)		;634d
	srl a		;6350   ; el arma partida por dos
	cp 003h		;6352
	push af			;6354
	jr z,L_636D		;6355
	ld a,(ix+005h)		;6357   ; y su paso horizontal: la 2 va a -0x0980
	ld de,0f680h		;635a
	cp 002h		;635d
	jr z,L_6383		;635f
	ld de,0f700h		;6361   ; la 4 a -0x0900
	cp 004h		;6364
	jr z,L_6383		;6366
	ld de,0f800h		;6368   ; y las demas a -0x0800
	jr L_6383		;636b
L_636D:
	inc (ix+007h)		;636d   ; las armas 6 y 7 tienen animacion propia
	ld a,(ix+007h)		;6370
	rra			;6373   ; su fotograma, uno de cada cuatro cuadros
	rra			;6374
	and 003h		;6375
	ld (ix+006h),a		;6377
	ld a,(0e604h)		;637a   ; y se pegan a la y del muneco
	ld (ix+004h),a		;637d
	call sigue_el_recorrido		;6380   ; con su recorrido grabado
L_6383:
	call suma_el_paso_horizontal		;6383
	pop af			;6386   ; con el arma 8, otra comprobacion
	jr z,L_6392		;6387
	ld a,h			;6389   ; fuera del margen 0xE5..0xEE se apaga
	sub 0e5h		;638a
	cp 00ah		;638c
	jr c,L_639C		;638e
	jr L_63A0		;6390
L_6392:
	ld a,(0e602h)		;6392   ; y fuera de la banda de diez alrededor del muneco, se apaga
	add a,008h		;6395
	sub h			;6397
	cp 00ah		;6398
	jr nc,L_63A0		;639a
L_639C:
	set 7,(ix+000h)		;639c
L_63A0:
	jp mira_si_el_disparo_toca_al_objeto		;63a0
suma_el_paso_horizontal:
	ld l,(ix+001h)		;63a3   ; la posicion horizontal
	ld h,(ix+002h)		;63a6
	add hl,de			;63a9   ; mas el paso
	ld (ix+001h),l		;63aa
	ld (ix+002h),h		;63ad
	ret			;63b0
pinta_un_disparo:
	ld a,(ix+000h)		;63b1
	and 00fh		;63b4   ; el numero de disparo, por cuatro: su atributo
	add a,a			;63b6
	add a,a			;63b7
	ld hl,03b10h		;63b8   ; los disparos van del sprite 4 en adelante
	call suma_a_a_hl		;63bb
	call 00053h		;63be   ; BIOS SETWRT - Enables VDP to write
	ld a,(00007h)		;63c1
	ld c,a			;63c4
	ld a,(ix+002h)		;63c5
	bit 7,(ix+000h)		;63c8   ; apagado o en la fila 0xD0, se aparca con 0xC3
	jr nz,L_63D2		;63cc
	cp 0d0h		;63ce
	jr nz,L_63D4		;63d0
L_63D2:
	ld a,0c3h		;63d2
L_63D4:
	out (c),a		;63d4
	ld a,(ix+004h)		;63d6
	out (c),a		;63d9
	ld a,(ix+005h)		;63db
	cp 005h		;63de   ; el arma 5 pinta como la 12
	jr nz,L_63E4		;63e0
	ld a,00ch		;63e2
L_63E4:
	and 00eh		;63e4   ; la pareja [patron][color] de la tabla de 0x63FB
	ld l,a			;63e6
	ld h,000h		;63e7
	ld de,063fbh		;63e9
	add hl,de			;63ec
	ld d,(hl)			;63ed
	ld a,(ix+006h)		;63ee   ; mas cuatro por cada fotograma
	add a,a			;63f1
	add a,a			;63f2
	add a,d			;63f3
	out (c),a		;63f4
	inc hl			;63f6
	ld a,(hl)			;63f7
	out (c),a		;63f8
	ret			;63fa

; ----------------------------------------------------------------------
; DATOS siete_parejas_de_0x63E9: Pareja [patron][color] por arma; 0x63E9 la
;   indexa con el arma partida por dos
;   0x63fb..0x6409  (14 bytes)
DATA_siete_parejas_de_0x63E9:
	defb 00ch,001h	; 63fb
	defb 010h,001h	; 63fd
	defb 018h,00fh	; 63ff
	defb 01ch,001h	; 6401
	defb 02ch,00ah	; 6403
	defb 014h,00fh	; 6405
	defb 040h,00fh	; 6407

; ======================================================================
; CODIGO 0x6409..0x6441  (56 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; SEGUIR EL RECORRIDO GRABADO. (ix+8) apunta a una tira de bytes con el
; paso de cada cuadro; el bit 4 de (ix+0) dice si se lee hacia delante o
; hacia atras, y un 0xFF o un 0xFE dan la vuelta.
; ----------------------------------------------------------------------
sigue_el_recorrido:
	ld l,(ix+008h)		;6409
	ld h,(ix+009h)		;640c
	ld a,(hl)			;640f   ; el paso de este cuadro
	bit 4,(ix+000h)		;6410   ; con el bit 4 puesto se va hacia atras
	jr nz,L_6423		;6414
	inc hl			;6416
	cpl			;6417   ; hacia delante: el paso cambiado de signo y con medio bit de fraccion
	ld d,a			;6418
	ld a,0ffh		;6419
	scf			;641b
	rr d		;641c
	rra			;641e
	ld e,a			;641f
	inc de			;6420
	jr L_642A		;6421
L_6423:
	dec hl			;6423   ; hacia atras: tal cual, tambien con medio bit
	ld d,a			;6424
	xor a			;6425
	srl d		;6426
	rra			;6428
	ld e,a			;6429
L_642A:
	ld a,(hl)			;642a
	inc a			;642b   ; un 0xFF da la vuelta
	jr nz,L_643B		;642c
	dec hl			;642e
	dec hl			;642f
	set 4,(ix+000h)		;6430
L_6434:
	ld (ix+008h),l		;6434
	ld (ix+009h),h		;6437
	ret			;643a
L_643B:
	inc a			;643b
	jr nz,L_6434		;643c
	inc hl			;643e
	jr L_6434		;643f

; ----------------------------------------------------------------------
; DATOS rampa_de_0x6071: De 0xFE a 0x08 bajando: veinticuatro bytes
;   0x6441..0x6459  (24 bytes)
DATA_rampa_de_0x6071:
	defb 0feh,00ch,00ch,00bh,00bh,00ah,00ah,009h,009h,009h,009h,008h	; 6441  ............
	defb 008h,008h,007h,007h,006h,006h,005h,004h,003h,002h,001h,0ffh	; 644d  ............

; ======================================================================
; CODIGO 0x6459..0x65e6  (397 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; SUBIR UN PASO. Cada 64 cuadros el tramo avanza una fila de pixeles, y
; cada 24 filas se cambia de tramo. Los 0xD8 son el techo del tramo.
; ----------------------------------------------------------------------
sube_un_paso:
	ld a,(0e600h)		;6459
	cp 002h		;645c   ; muriendose no se avanza
	ret nc			;645e
	ld hl,0e091h		;645f
	ld a,(hl)			;6462
	cp 0d8h		;6463   ; y en el techo, tampoco
	ret nc			;6465
	inc (hl)			;6466   ; una fila mas
	ld hl,0e09ah		;6467   ; (0xE09A) cuenta las filas dentro de la banda
	inc (hl)			;646a
	ld a,(hl)			;646b
	cp 003h		;646c   ; a la tercera fila se enciende (0xE09E)
	jr c,L_6481		;646e
	ex af,af'			;6470
	ld a,001h		;6471
	ld (0e09eh),a		;6473
	ex af,af'			;6476
	cp 018h		;6477   ; y a la 24 se cambia de tramo
	jr c,L_6481		;6479
	ld (hl),000h		;647b
	ld hl,0e092h		;647d
	inc (hl)			;6480
L_6481:
	ld a,(0e090h)		;6481
	or a			;6484
	call z,retrocede_un_byte_del_mapa		;6485   ; con (0xE090) a cero se retrocede un byte del mapa de bits
	ld ix,0e4f0h		;6488
	ld b,008h		;648c
L_648E:
	bit 4,(ix+000h)		;648e   ; los enemigos con el bit 4 puesto bajan con el decorado
	jr z,L_649C		;6492
	ld a,(ix+002h)		;6494
	add a,008h		;6497
	ld (ix+002h),a		;6499
L_649C:
	ld de,00010h		;649c
	add ix,de		;649f
	djnz L_648E		;64a1
vuelca_la_pantalla:
	ld hl,03800h		;64a3   ; la tabla de nombres entera
	call 00053h		;64a6   ; BIOS SETWRT - Enables VDP to write
	ld a,(00007h)		;64a9
	ld c,a			;64ac
	ld a,(0e091h)		;64ad   ; la fila de arranque, en la ventana de cuatro
	and 003h		;64b0
	ld l,a			;64b2
	ld h,000h		;64b3
	add hl,hl			;64b5   ; por 32: el desplazamiento dentro del buffer
	add hl,hl			;64b6
	add hl,hl			;64b7
	add hl,hl			;64b8
	add hl,hl			;64b9
	ld de,0e8a0h		;64ba   ; el buffer de casillas de la RAM, 0xE820 menos lo que se ha subido
	ex de,hl			;64bd
	or a			;64be
	sbc hl,de		;64bf
	ld b,000h		;64c1
	call vuelca_256_casillas		;64c3   ; tres tandas de 256 casillas
	call vuelca_256_casillas		;64c6
	ld b,0c0h		;64c9   ; y la ultima, 0xC0: en total 0x300, las 768 de la pantalla
	call vuelca_256_casillas		;64cb
	ld ix,0e600h		;64ce
	ld a,(ix+010h)		;64d2
	call se_puede_pisar		;64d5   ; mira si el muneco ha quedado dentro de una pared...
	jr nc,L_64E2		;64d8
	ld a,(ix+011h)		;64da
	call se_puede_pisar		;64dd
	jr c,L_64F0		;64e0
L_64E2:
	ld a,(ix+016h)		;64e2
	call se_puede_pisar		;64e5   ; las dos casillas de abajo del muneco
	ret nc			;64e8
	ld a,(ix+017h)		;64e9
	call se_puede_pisar		;64ec
	ret nc			;64ef
L_64F0:
	ld a,(ix+002h)		;64f0   ; ...y si es asi, se le empuja ocho pixeles abajo
	add a,008h		;64f3
	ld (ix+002h),a		;64f5
	ret			;64f8
vuelca_256_casillas:
	outi		;64f9   ; `outi` hasta que B da la vuelta
	jp nz,vuelca_256_casillas		;64fb
	ret			;64fe
monta_una_banda_si_toca:
	srl a		;64ff
	ret c			;6501

; ----------------------------------------------------------------------
; MONTAR UNA BANDA DEL DECORADO. Cuatro filas de 32 casillas, en ocho
; grupos de cuatro columnas. De cada grupo sale un codigo de bloque:
; los siete bits bajos indexan la tabla de 0x99ED y el bit 7 dice que el
; bloque va espejado. Detras de cada grupo, el `rl` de 0x6551 saca un bit
; del mapa: con el puesto el puntero avanza, y con el a cero SE REPITE el
; bloque anterior. Ahi esta la compresion del decorado.
; ----------------------------------------------------------------------
monta_una_banda:
	push af			;6502
	ld hl,(0e088h)		;6503   ; el byte del mapa de bits de esta banda
	call suma_a_a_hl		;6506
	ld a,(hl)			;6509
	ld iy,0e08ah		;650a
	ld (iy+000h),a		;650e   ; guardado, que el `rl` lo va a ir sacando bit a bit
	pop af			;6511
	ld hl,00000h		;6512   ; la banda por 0x80: cuatro filas de 32
	ld de,00080h		;6515
	or a			;6518
	ld b,a			;6519
	jr z,L_651F		;651a
L_651C:
	add hl,de			;651c
	djnz L_651C		;651d
L_651F:
	ld de,0e820h		;651f   ; sobre el buffer de casillas
	add hl,de			;6522
	ld ix,(0e09ch)		;6523   ; y los codigos de bloque, por donde iban
	ld c,008h		;6527   ; ocho grupos de cuatro columnas
L_6529:
	push hl			;6529
	ld a,(ix+000h)		;652a
	and 07fh		;652d   ; los siete bits bajos: el bloque
	ld l,a			;652f
	ld h,000h		;6530
	add hl,hl			;6532   ; dos bytes por entrada
	ld de,099edh		;6533
	add hl,de			;6536
	ld e,(hl)			;6537
	inc hl			;6538
	ld d,(hl)			;6539
	pop hl			;653a
	push hl			;653b
	ld b,004h		;653c   ; cuatro filas
L_653E:
	push bc			;653e
	push hl			;653f
	call L_6561		;6540   ; una fila de cuatro casillas
	pop hl			;6543
	ld bc,00020h		;6544   ; y a la fila siguiente, 0x20 mas alla
	add hl,bc			;6547
	pop bc			;6548
	djnz L_653E		;6549
	pop hl			;654b
	ld a,004h		;654c
	call suma_a_a_hl		;654e
	rl (iy+000h)		;6551
	jr nc,L_6559		;6555
	inc ix		;6557
L_6559:
	dec c			;6559
	jr nz,L_6529		;655a
	ld (0e09ch),ix		;655c
	ret			;6560
L_6561:
	ld b,004h		;6561
	bit 7,(ix+000h)		;6563
	jr z,L_6586		;6567
	ld a,003h		;6569
	call suma_a_a_hl		;656b
L_656E:
	call L_6576		;656e
	ld (hl),a			;6571
	dec hl			;6572
	djnz L_656E		;6573
	ret			;6575
L_6576:
	ld a,(de)			;6576
	and 0f0h		;6577   ; las casillas por debajo de 0x10 pasan tal cual
	ld a,(de)			;6579
	inc de			;657a
	ret z			;657b
	cp 0a0h		;657c   ; de 0xA0 arriba restan 0x60...
	jr nc,L_6583		;657e
	add a,060h		;6580
	ret			;6582
L_6583:
	sub 060h		;6583   ; ...y las demas suman 0x60: es el banco espejado
	ret			;6585
L_6586:
	ld a,(de)			;6586   ; b bytes tal cual
	inc de			;6587
	ld (hl),a			;6588
	inc hl			;6589
	djnz L_6586		;658a
	ret			;658c

; ----------------------------------------------------------------------
; ====================================================================
; EL OBJETO QUE SE PUEDE COGER. Solo hay uno a la vez, en 0xE290: el
; primer byte dice si esta suelto, y por la lista de la fase se sabe en
; que fila aparece. La lista es una tira de bytes con la fila -partida
; por dos- y su bit 7 diciendo cual de los dos objetos sale.
; ====================================================================
; ----------------------------------------------------------------------
el_objeto:
	call pinta_el_objeto		;658d   ; pintarlo, si lo hay
	ld hl,0e290h		;6590
	ld a,(hl)			;6593   ; con el primer byte puesto ya esta en marcha
	or a			;6594
	jp nz,mueve_el_objeto		;6595
	inc l			;6598
	inc l			;6599
	inc l			;659a
	ld (hl),0e0h		;659b   ; aparcado
	ld a,(0e3b0h)		;659d
	or a			;65a0   ; en la pantalla del jefe no salen objetos
	ret nz			;65a1
	ld a,(0e663h)		;65a2
	and a			;65a5
	ret nz			;65a6   ; ni con el jefe sonando
	ld a,(0e062h)		;65a7
	ld hl,065e6h		;65aa   ; la lista de la fase
	call palabra_de_tabla_en_hl		;65ad
	ld a,(0e091h)		;65b0   ; la fila de ahora, partida por dos
	srl a		;65b3
	ld b,a			;65b5
L_65B6:
	ld a,(hl)			;65b6   ; un 0xFF cierra la lista
	inc a			;65b7
	ret z			;65b8
	dec a			;65b9
	and 07fh		;65ba   ; sin su bit 7
	cp b			;65bc   ; hasta dar con la fila
	jr z,L_65C2		;65bd
	inc hl			;65bf
	jr L_65B6		;65c0
L_65C2:
	push hl			;65c2
	call borra_el_objeto		;65c3   ; se borra lo que hubiera
	pop hl			;65c6
	ld a,(hl)			;65c7
	ld hl,0e290h		;65c8
	ld (hl),001h		;65cb   ; objeto suelto
	inc l			;65cd
	rlc a		;65ce   ; y el bit 7 de la entrada dice cual de los dos
	and 001h		;65d0
	ld (hl),a			;65d2
	ld a,(0e604h)		;65d3   ; sale por donde este el muneco, topado entre 0x28 y 0xD0
	ld b,028h		;65d6
	cp b			;65d8
	jr c,L_65E1		;65d9
	ld b,0d0h		;65db
	cp b			;65dd
	jr nc,L_65E1		;65de
	ld b,a			;65e0
L_65E1:
	ld a,b			;65e1
	ld (0e29ah),a		;65e2
	ret			;65e5

; ----------------------------------------------------------------------
; DATOS listas_por_fase: Ocho punteros; 0x65AA indexa con (0xE062)
;   0x65e6..0x65f6  (16 bytes)
DATA_listas_por_fase:
	defw 065f6h,06600h,0660ah,06614h,0661eh,06628h,06636h,06644h	; 65e6

; ----------------------------------------------------------------------
; DATOS listas_de_0x65B6: Los ocho tramos que apunta la tabla de arriba;
;   0x65B6 los recorre hasta un 0xFF
;   0x65f6..0x6652  (92 bytes)
DATA_listas_de_0x65B6:
	defb 08ch,098h,024h,030h,0b6h,03ch,0c8h,0d4h,060h,0ffh	; 65f6  ..$0.<..`.
	defb 08ch,098h,024h,030h,0b6h,03ch,0c8h,0d4h,060h,0ffh	; 6600  ..$0.<..`.
	defb 08ch,098h,024h,030h,0b6h,03ch,0c8h,0d4h,060h,0ffh	; 660a  ..$0.<..`.
	defb 08ch,098h,024h,030h,0b6h,03ch,0c8h,0d4h,060h,0ffh	; 6614  ..$0.<..`.
	defb 08ch,098h,024h,030h,0b6h,03ch,0c8h,0d4h,060h,0ffh	; 661e  ..$0.<..`.
	defb 08ch,092h,018h,0a4h,02ah,0b0h,036h,0c2h,048h,0ceh	; 6628  ....*.6.H.
	defb 054h,0dah,060h,0ffh,08ch,092h,018h,0a4h,02ah,0b0h	; 6632  T.`.....*.
	defb 036h,0c2h,048h,0ceh,054h,0dah,060h,0ffh,08ch,092h	; 663c  6.H.T.`...
	defb 018h,0a4h,02ah,0b0h,036h,0c2h,048h,0ceh,054h,0dah	; 6646  ..*.6.H.T.
	defb 060h,0ffh	; 6650

; ======================================================================
; CODIGO 0x6652..0x66af  (93 bytes)
; ======================================================================


mueve_el_objeto:
	ld a,(0e600h)		;6652
	cp 002h		;6655   ; muriendose no se coge nada
	jr nc,L_665F		;6657
	call toca_el_objeto_al_muneco		;6659   ; mira si el muneco lo toca
	jp nc,coge_el_objeto		;665c
L_665F:
	ld hl,0e290h		;665f
	ld a,(hl)			;6662
	cp 002h		;6663   ; con el 2 esta cogido y se anima
	jr nz,L_6687		;6665
	inc l			;6667
	ld a,(hl)			;6668
	and a			;6669
	ld bc,00803h		;666a   ; el primero da tres fotogramas y el segundo uno
	jr z,L_6672		;666d
	ld bc,00701h		;666f
L_6672:
	ld l,09dh		;6672
	inc (hl)			;6674   ; el fotograma que toca
	ld a,(hl)			;6675
	cp b			;6676
	jr c,L_667B		;6677
	xor a			;6679
	ld (hl),a			;667a
L_667B:
	ld d,a			;667b
	dec l			;667c
	ld a,(hl)			;667d   ; hasta el tope de su fotograma
	cp c			;667e
	jr nc,L_6687		;667f
	ld a,d			;6681
	srl a		;6682
	srl a		;6684
	ld (hl),a			;6686
L_6687:
	ld hl,0e290h		;6687
	ld (hl),001h		;668a
	call mueve_el_objeto_por_su_angulo		;668c   ; su recorrido
	ld hl,(0e292h)		;668f   ; y el paso de este cuadro
	ld bc,(0e296h)		;6692
	add hl,bc			;6696
	ld (0e292h),hl		;6697
	ld a,(0e293h)		;669a
	cp 0a8h		;669d   ; entre la fila 0xA8 y la 0xD8 se queda; fuera de ahi, se borra
	ret c			;669f
	cp 0d8h		;66a0
	ret nc			;66a2
borra_el_objeto:
	ld hl,066afh		;66a3   ; los dieciseis bytes de 0x66AF, que lo dejan aparcado
	ld de,0e290h		;66a6
	ld bc,00010h		;66a9
	ldir		;66ac
	ret			;66ae

; ----------------------------------------------------------------------
; DATOS dieciseis_bytes_de_0x66A3: Los dieciseis bytes con los que 0x66A3 deja
;   el objeto aparcado en la fila 0xE0
;   0x66af..0x66bf  (16 bytes)
DATA_dieciseis_bytes_de_0x66A3:
	defb 000h,000h,000h,0e0h,000h,000h,09fh,000h,000h,000h,000h,040h,000h,000h,000h,001h	; 66af  ...........@....

; ======================================================================
; CODIGO 0x66bf..0x674b  (140 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; PINTAR EL OBJETO. Dos sprites, uno encima del otro, en 0xE378 y 0xE37C.
; ----------------------------------------------------------------------
pinta_el_objeto:
	ld hl,0e290h		;66bf
	ld a,(hl)			;66c2
	and a			;66c3   ; sin objeto, los dos aparcados en la fila 0xE0
	ld de,0e37ch		;66c4
	jr nz,L_66D0		;66c7
	ld a,0e0h		;66c9
	ld (de),a			;66cb
	ld (0e378h),a		;66cc
	ret			;66cf
L_66D0:
	ld hl,0e291h		;66d0
	ld a,(hl)			;66d3
	and a			;66d4
	push af			;66d5
	inc l			;66d6
	inc l			;66d7
	ldi		;66d8   ; la fila y la columna, copiadas del bloque del objeto
	inc l			;66da
	ldi		;66db
	ex de,hl			;66dd
	ld (hl),094h		;66de   ; patron 0x94 y color 1
	inc l			;66e0
	ld (hl),001h		;66e1
	pop af			;66e3
	jr z,L_66F1		;66e4
	ld de,0674fh		;66e6   ; y si es el segundo objeto, el color sale de la tabla de 0x674F
	ld a,(0e29dh)		;66e9
	call suma_a_a_de		;66ec
	ld a,(de)			;66ef
	ld (hl),a			;66f0
L_66F1:
	ld de,0e378h		;66f1
	ld hl,0e291h		;66f4
	ld a,(hl)			;66f7
	inc l			;66f8
	inc l			;66f9
	and a			;66fa
	jr nz,L_672B		;66fb
	ld b,(hl)			;66fd   ; la fila y la columna del objeto
	inc l			;66fe
	inc l			;66ff
	ld c,(hl)			;6700
	ld a,(0e29dh)		;6701
	ld hl,06839h		;6704   ; la tabla de fotogramas de 0x6839
	call suma_a_a_hl		;6707
	ld a,(0e609h)		;670a   ; y (0xE609) alterna entre dos
	and 0feh		;670d
	cp (hl)			;670f
	ld a,(hl)			;6710
	jr nz,L_6714		;6711
	inc a			;6713
L_6714:
	ld hl,06756h		;6714   ; los dos sprites del fotograma, de la tabla de 0x6756
	push de			;6717
	call palabra_de_tabla_en_hl		;6718
	pop de			;671b
	ld a,(hl)			;671c
	add a,b			;671d   ; con el desplazamiento de cada uno
	ld (de),a			;671e
	inc hl			;671f
	inc e			;6720
	ld a,(hl)			;6721
	add a,c			;6722
	ld (de),a			;6723
	inc hl			;6724
	inc e			;6725
	ldi		;6726
	ex de,hl			;6728
	jr L_673B		;6729
L_672B:
	ld a,(hl)			;672b   ; y con el objeto quieto, un ajuste fijo de 3 y 5
	add a,003h		;672c
	ld (de),a			;672e
	inc l			;672f
	inc l			;6730
	inc e			;6731
	ld a,(hl)			;6732
	add a,005h		;6733
	ld (de),a			;6735
	inc e			;6736
	ex de,hl			;6737
	ld (hl),038h		;6738   ; patron 0x38
	inc l			;673a
L_673B:
	ld a,(0e003h)		;673b   ; y el color, que da vueltas cada cuatro cuadros
	rra			;673e
	rra			;673f
	and 003h		;6740
	ld de,0674bh		;6742
	call suma_a_a_de		;6745
	ld a,(de)			;6748
	ld (hl),a			;6749
	ret			;674a

; ----------------------------------------------------------------------
; DATOS tablas_de_0x66E6: Tres tramos, que leen 0x66E6, 0x6714 y 0x6742
;   0x674b..0x6783  (56 bytes)
DATA_tablas_de_0x66E6:
	defb 00fh,001h,00fh,004h,001h,001h,001h,005h	; 674b  ........
	defb 007h,00fh,006h,06eh,067h,06eh,067h,071h	; 6753  ...ngngq
	defb 067h,071h,067h,074h,067h,077h,067h,07ah	; 675b  gqgtgwgz
	defb 067h,07ah,067h,07dh,067h,07dh,067h,080h	; 6763  gzg}g}g.
	defb 067h,080h,067h,000h,000h,094h,001h,002h	; 676b  g.g.....
	defb 010h,000h,005h,018h,001h,001h,040h,003h	; 6773  ......@.
	defb 006h,01ch,000h,000h,034h,001h,004h,014h	; 677b  ....4...

; ======================================================================
; CODIGO 0x6783..0x6839  (182 bytes)
; ======================================================================


toca_el_objeto_al_muneco:
	ld hl,0e293h		;6783
	ld a,(hl)			;6786
	inc l			;6787
	inc l			;6788
	ld h,(hl)			;6789
	ld l,a			;678a
	ld bc,01010h		;678b   ; la caja del objeto, 16 por 16
	ld a,(0e602h)		;678e   ; contra la posicion del muneco
	ld (0e0d0h),a		;6791
	ld a,(0e604h)		;6794
	ld (0e0d1h),a		;6797
	ld de,00e0eh		;679a
	jp se_cruzan_las_cajas		;679d
mira_si_el_disparo_toca_al_objeto:
	ld a,(0e290h)		;67a0
	dec a			;67a3   ; solo si esta suelto
	ret nz			;67a4
	push ix		;67a5
	pop hl			;67a7
	inc l			;67a8
	inc l			;67a9
	call caja_de_lo_apuntado_por_hl		;67aa   ; la caja del disparo
	ld hl,0e293h		;67ad
	ld a,(hl)			;67b0
	inc l			;67b1
	inc l			;67b2
	ld h,(hl)			;67b3
	ld l,a			;67b4
	ld bc,01010h		;67b5
	call se_cruzan_las_cajas		;67b8
	ret c			;67bb
	ld a,00eh		;67bc   ; suena el toque
	call pide_pieza		;67be
	set 7,(ix+000h)		;67c1   ; el disparo se apaga
	ld a,002h		;67c5
	ld (0e290h),a		;67c7   ; y el objeto pasa al estado 2: cogido
	ret			;67ca

; ----------------------------------------------------------------------
; COGER EL OBJETO. Suma los puntos, aplica lo que sea y deja el remate
; en la pila para que al volver se borre.
; ----------------------------------------------------------------------
coge_el_objeto:
	ld hl,066a3h		;67cb   ; se empuja el borrado, que es por donde se sale
	push hl			;67ce
	ld hl,0e291h		;67cf
	ld a,(hl)			;67d2
	and a			;67d3
	ld hl,06839h		;67d4   ; la tabla de valores del primer objeto...
	jr z,L_67DC		;67d7
	ld hl,06841h		;67d9   ; ...o la del segundo
L_67DC:
	ld a,(0e29dh)		;67dc
	call suma_a_a_hl		;67df
	ld a,(hl)			;67e2
	and a			;67e3
	push af			;67e4
	ld de,00200h		;67e5   ; el que no vale nada da 0x0200 puntos y el otro 0x1000
	jr nz,L_67ED		;67e8
	ld de,01000h		;67ea
L_67ED:
	call suma_puntos_bc		;67ed
	pop af			;67f0   ; el premio que ha salido
	ld b,a			;67f1
	jr z,L_6834		;67f2
	ld a,0a5h		;67f4   ; su sonido
	call pide_pieza_si_la_escena_lo_permite		;67f6
	ld a,001h		;67f9
	ld (0e667h),a		;67fb   ; y el aviso de que hay que cambiar de musica
	ld a,(0e291h)		;67fe
	or a			;6801
	jr nz,L_6810		;6802
	ld hl,0e609h		;6804   ; el objeto que no vale nada solo cambia el arma de (0xE609)
	ld a,(hl)			;6807
	and 0feh		;6808
	cp b			;680a
	jr nz,L_680E		;680b
	inc b			;680d
L_680E:
	ld (hl),b			;680e
	ret			;680f
L_6810:
	ld a,b			;6810   ; y los que valen: el 1 sube el nivel de arma
	dec a			;6811
	jr z,L_6829		;6812
	ld (0e60ch),a		;6814   ; el 2 pone (0xE60C)
	dec a			;6817
	jr z,L_6823		;6818
	dec hl			;681a
	ld bc,04514h		;681b   ; y los demas, 0x14 y 0x45 en la municion
	ld (0e60dh),bc		;681e
	ret			;6822
L_6823:
	ld a,01eh		;6823   ; el 3 da 0x1E de otra cosa
	ld (0e60fh),a		;6825
	ret			;6828
L_6829:
	ld hl,0e60ah		;6829   ; el 4 sube (0xE60A), topado en 4
	inc (hl)			;682c
	ld a,(hl)			;682d
	cp 005h		;682e
	ret c			;6830
	ld (hl),004h		;6831
	ret			;6833
L_6834:
	ld a,012h		;6834   ; y suena el toque
	jp pide_pieza		;6836

; ----------------------------------------------------------------------
; DATOS tabla_de_0x6704: La leen 0x6704, 0x67D4 y 0x67D9
;   0x6839..0x6848  (15 bytes)
DATA_tabla_de_0x6704:
	defb 000h,000h,000h,002h,008h,006h,004h,00ah,000h,000h,000h,001h,002h,003h,004h	; 6839  ...............

; ======================================================================
; CODIGO 0x6848..0x6909  (193 bytes)
; ======================================================================


mueve_el_objeto_por_su_angulo:
	ld hl,0e29ch		;6848   ; el angulo del objeto, mas su paso
	ld a,(hl)			;684b
	dec l			;684c
	add a,(hl)			;684d
	ld (hl),a			;684e
	call seno_y_coseno		;684f   ; seno y coseno de ese angulo
	ld h,d			;6852
	ld l,e			;6853
	add hl,hl			;6854   ; por ocho
	add hl,hl			;6855
	add hl,hl			;6856
	add hl,hl			;6857
	add hl,hl			;6858
	ld a,(0e29ah)		;6859   ; mas el centro
	add a,h			;685c
	ld h,a			;685d
	ld (0e294h),hl		;685e   ; y el paso queda en (0xE294)
	ret			;6861

; ----------------------------------------------------------------------
; UN BICHO DE LA LISTA DE 0xE4F0. Ocho ranuras de 0x10 bytes: son los
; que la fase siembra por filas, no los que salen de los generadores. Su
; estado esta en (ix+0): a cero espera a que llegue su fila, y con el
; bit 7 puesto ya lo han matado.
; ----------------------------------------------------------------------
haz_un_bicho:
	ld a,b			;6862   ; el numero de ranura, que hace falta luego
	ld (0e665h),a		;6863
	ld a,(ix+000h)		;6866
	bit 7,a		;6869   ; con el bit 7 puesto esta muriendose
	jr nz,bicho_muriendose		;686b
	or a			;686d   ; a cero, todavia no ha salido
	jr nz,L_6883		;686e
	ld iy,(0e570h)		;6870   ; el siguiente de la lista de la fase
	ld a,(0e091h)		;6874
	cp (iy+001h)		;6877   ; sale cuando el tramo llega a su fila
	ret nz			;687a
	call monta_un_bicho		;687b   ; se monta
	ld (0e570h),iy		;687e   ; y la lista avanza
	ret			;6882
L_6883:
	ld a,(ix+001h)		;6883   ; su recorrido, el de 0x6F40
	or a			;6886
	ld de,06f40h		;6887
	call nz,borra_lo_que_dejo		;688a
	ld a,(ix+002h)		;688d
	cp 0b0h		;6890   ; por debajo de la fila 0xB0 no se le puede dar
	jp nc,apaga_la_ranura		;6892
	ld hl,0e620h		;6895   ; las tres ranuras de disparo
	ld b,003h		;6898
L_689A:
	bit 7,(hl)		;689a   ; saltando las vacias
	jr nz,L_68B5		;689c
	push hl			;689e
	push bc			;689f
	inc l			;68a0
	inc l			;68a1
	call caja_de_lo_apuntado_por_hl		;68a2   ; la caja del disparo
	ld l,(ix+002h)		;68a5
	ld h,(ix+003h)		;68a8
	ld bc,00808h		;68ab   ; contra la del bicho, ocho por ocho
	call se_cruzan_las_cajas		;68ae
	pop bc			;68b1
	pop hl			;68b2
	jr nc,L_68BC		;68b3
L_68B5:
	ld de,00010h		;68b5
	add hl,de			;68b8
	djnz L_689A		;68b9
	ret			;68bb
L_68BC:
	set 7,(hl)		;68bc   ; tocado: el disparo se apaga
	ld a,00fh		;68be   ; y suena
	call pide_pieza		;68c0
	inc (ix+001h)		;68c3   ; un impacto mas
	ld a,(ix+001h)		;68c6
	cp (ix+008h)		;68c9   ; hasta los que aguanta (ix+8)
	ret c			;68cc
	set 7,(ix+000h)		;68cd   ; y entonces se muere
	ld a,010h		;68d1   ; con su sonido
	jp pide_pieza		;68d3
bicho_muriendose:
	ld h,a			;68d6
	and 007h		;68d7   ; los tres bits bajos dicen que premio deja
	cp 004h		;68d9
	jr nc,L_68FD		;68db
	ld de,06f24h		;68dd   ; el recorrido de la muerte, el de 0x6F24
	add a,a			;68e0
	add a,a			;68e1
	call suma_a_a_de		;68e2
	bit 6,h		;68e5
	jr z,L_68EC		;68e7
	ld de,06f3ch		;68e9   ; o el de 0x6F3C si lleva el bit 6
L_68EC:
	call borra_lo_que_dejo		;68ec
	bit 6,(ix+000h)		;68ef   ; con el bit 6 ya se conto
	ret nz			;68f3
	call L_6A67		;68f4   ; mira si toca al muneco
	ret c			;68f7
	ld a,012h		;68f8
	call pide_pieza		;68fa
L_68FD:
	set 6,(ix+000h)		;68fd   ; marcado, para no contarlo dos veces
	ld a,(ix+000h)		;6901
	and 007h		;6904
	call reparte_por_tabla		;6906   ; y se reparte por lo que deje

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_6909: 8 entradas; tras el `call 406Ch` de 0x6906;
;   sigue en 0x4305
;   0x6909..0x6919  (16 bytes)
DATA_tabla_de_reparto_6909:
	defw 04305h,06919h,0691fh,0694eh,06983h,0698ah,069bch,069d5h	; 6909

; ======================================================================
; CODIGO 0x6919..0x6a7f  (358 bytes)
; ======================================================================


deja_500_puntos:
	ld de,00500h		;6919
	jp suma_puntos_bc		;691c
mata_a_todos:
	ld a,056h		;691f   ; suena la bomba
	call pide_pieza_si_la_escena_lo_permite		;6921
L_6924:
	push ix		;6924   ; los siete enemigos de 0xE100
	ld ix,0e100h		;6926
	ld b,007h		;692a
L_692C:
	push bc			;692c
	ld a,(ix+001h)		;692d
	and 00fh		;6930
	ld hl,075aah		;6932   ; el tope de cada uno, de la tabla de 0x75AA
	call suma_a_a_hl		;6935
	ld a,(ix+000h)		;6938
	and a			;693b
	jr z,L_6942		;693c
	cp (hl)			;693e   ; los que estan por debajo del tope, mueren
	call c,mata_a_este_enemigo_del_jefe		;693f
L_6942:
	pop bc			;6942
	ld de,00020h		;6943   ; la ranura siguiente
	add ix,de		;6946
	djnz L_692C		;6948
	pop ix		;694a
	jr L_6974		;694c
congela_a_todos:
	ld a,03dh		;694e   ; su sonido
	call pide_pieza_si_la_escena_lo_permite		;6950
	ld hl,0e665h		;6953
	ld a,008h		;6956   ; el reloj de la congelacion
	sub (hl)			;6958
	dec hl			;6959
	ld (hl),a			;695a
	dec hl			;695b
	ld a,001h		;695c
	ld (0e668h),a		;695e   ; y el aviso de que hay que cambiar de musica
	ld (ix+004h),a		;6961
	ld (hl),a			;6964
	ld hl,01000h		;6965
	ld (ix+005h),l		;6968
	ld (ix+006h),h		;696b
	ld a,(0e090h)		;696e
	ld (ix+007h),a		;6971
L_6974:
	ld hl,0e200h		;6974   ; y borra los ocho enemigos de 0xE200
	ld b,008h		;6977
L_6979:
	ld (hl),000h		;6979
	ld a,010h		;697b
	call suma_a_a_hl		;697d
	djnz L_6979		;6980
	ret			;6982
deja_su_dibujo:
	ld de,06f34h		;6983
	call borra_lo_que_dejo		;6986
	ret			;6989
el_pergamino:
	ld de,06f38h		;698a   ; su dibujo
	call borra_lo_que_dejo		;698d
	call L_6A67		;6990   ; si el muneco lo toca
	ret c			;6993
	ld hl,06a8ch		;6994   ; la tabla de 0x6A8C, seis parejas
	ld b,006h		;6997
L_6999:
	ld a,(ix+009h)		;6999   ; busca el que casa con (ix+9)
	cp (hl)			;699c
	inc hl			;699d
	jr z,L_69A4		;699e
	inc hl			;69a0
	djnz L_6999		;69a1
	ret			;69a3
L_69A4:
	ld b,(hl)			;69a4   ; y salta esas fases: se le suman a (0xE061) en BCD y a (0xE062) tal cual
	ld hl,0e061h		;69a5
	ld a,(hl)			;69a8
	add a,b			;69a9
	daa			;69aa
	ld (hl),a			;69ab
	inc hl			;69ac
	ld a,(hl)			;69ad
	add a,b			;69ae
	ld (hl),a			;69af
	ld a,001h		;69b0
	ld (0e00dh),a		;69b2   ; (0xE00D) avisa a la escena de que hay salto de fase
	ld a,0b1h		;69b5   ; y su sonido
	call pide_pieza_si_la_escena_lo_permite		;69b7
L_69BA:
	jr apaga_la_ranura		;69ba
deja_un_dibujo_de_cuatro_por_cuatro:
	ld l,(ix+002h)		;69bc
	ld a,l			;69bf
	add a,010h		;69c0   ; por debajo de la fila 0xD0 no se pinta
	cp 0d0h		;69c2
	jr nc,L_69BA		;69c4
	ld h,(ix+003h)		;69c6
	ld de,0f7f0h		;69c9
	add hl,de			;69cc
	ld de,09a9ch		;69cd   ; el dibujo de 0x9A9C, de cuatro por cuatro casillas
	ld bc,00404h		;69d0
	jr L_6A12		;69d3
la_puerta:
	ld a,(ix+002h)		;69d5
	cp 0b0h		;69d8   ; por debajo de 0xB0 no se puede tocar
	jr nc,apaga_la_ranura		;69da
	ld a,(ix+008h)		;69dc
	and 0f0h		;69df   ; el nibble alto de (ix+8) por dos: el ancho de la caja
	add a,a			;69e1
	ld b,a			;69e2
	ld c,008h		;69e3
	call L_6A71		;69e5   ; mira si el muneco esta dentro
	ret c			;69e8
	ld a,(0e009h)		;69e9
	bit 0,(ix+008h)		;69ec   ; el bit 0 dice si hace falta izquierda o derecha
	jr z,L_69F7		;69f0
	bit 3,a		;69f2
	ret z			;69f4
	jr L_69FA		;69f5
L_69F7:
	bit 2,a		;69f7
	ret z			;69f9
L_69FA:
	ld hl,0e604h		;69fa   ; y da la vuelta a la columna del tramo: por ahi se sale
	ld a,(hl)			;69fd
	neg		;69fe
	sub 010h		;6a00
	ld (hl),a			;6a02
	ret			;6a03
borra_lo_que_dejo:
	ld l,(ix+002h)		;6a04
	ld h,(ix+003h)		;6a07
	ld bc,00202h		;6a0a   ; dos por dos casillas
	ld a,l			;6a0d
	cp 0b0h		;6a0e   ; por debajo de 0xB0 no se toca la pantalla
	jr nc,L_6A15		;6a10
L_6A12:
	jp pinta_un_bloque_de_casillas		;6a12
L_6A15:
	pop hl			;6a15
apaga_la_ranura:
	xor a			;6a16
	ld (ix+000h),a		;6a17
	ld (ix+001h),a		;6a1a
	ret			;6a1d

; ----------------------------------------------------------------------
; MONTAR UN BICHO DE LA LISTA. Los registros de la fase son de tres
; bytes: tipo, x y y. El tipo trae en los cuatro bits bajos el indice de
; la tabla de 0x6A7F, que da cuantos impactos aguanta.
; ----------------------------------------------------------------------
monta_un_bicho:
	ld a,(iy+000h)		;6a1e
	ld c,a			;6a21
	cp 015h		;6a22   ; el tipo 0x15 solo sale a partir de la fase que diga (0xE006)
	jr nz,L_6A2F		;6a24
	ld a,(0e006h)		;6a26
	ld hl,0e061h		;6a29
	cp (hl)			;6a2c
	jr c,L_6A61		;6a2d
L_6A2F:
	ld a,c			;6a2f
	and 01fh		;6a30
	cp 017h		;6a32   ; de 0x17 arriba se cambia por 0x97
	jr c,L_6A38		;6a34
	ld a,097h		;6a36
L_6A38:
	ld (ix+000h),a		;6a38
	ld (ix+002h),000h		;6a3b
	ld a,(iy+002h)		;6a3f   ; la columna
	ld (ix+003h),a		;6a42
	ld a,c			;6a45
	and 00fh		;6a46
	ld hl,06a7fh		;6a48   ; y los impactos que aguanta, de la tabla de 0x6A7F
	call suma_a_a_hl		;6a4b
	ld a,(hl)			;6a4e
	bit 5,c		;6a4f
	jr z,L_6A58		;6a51
	ld (ix+001h),001h		;6a53
	inc a			;6a57
L_6A58:
	ld (ix+008h),a		;6a58
	ld a,(iy+001h)		;6a5b
	ld (ix+009h),a		;6a5e
L_6A61:
	ld de,00003h		;6a61
	add iy,de		;6a64
	ret			;6a66
L_6A67:
	ld a,(0e600h)		;6a67
	cp 002h		;6a6a
	jr nc,L_6A7D		;6a6c
	ld bc,00808h		;6a6e
L_6A71:
	call caja_del_muneco		;6a71
	ld l,(ix+002h)		;6a74
	ld h,(ix+003h)		;6a77
	jp se_cruzan_las_cajas		;6a7a
L_6A7D:
	scf			;6a7d
	ret			;6a7e

; ----------------------------------------------------------------------
; DATOS tabla_de_tipos_de_enemigo: Quince valores; 0x6A48 la indexa con los
;   cuatro bits bajos del tipo y el resultado va a (ix+8)
;   0x6a7f..0x6a8e  (15 bytes)
DATA_tabla_de_tipos_de_enemigo:
	defb 00fh,005h,00ah,00ah,004h,01eh,005h,010h,011h,020h,021h,030h,031h,050h,000h	; 6a7f  ......... !01P.

; ----------------------------------------------------------------------
; DATOS sin_identificar_6A8E: Diez bytes delante de la tabla de fases
;   0x6a8e..0x6a98  (10 bytes)
DATA_sin_identificar_6A8E:
	defb 088h,001h,070h,000h,0bch,001h,086h,001h,03eh,001h	; 6a8e  ..p.....>.

; ----------------------------------------------------------------------
; DATOS enemigos_por_fase: Ocho entradas de doce bytes -0x55A3 indexa con
;   (0xE062)*12-: una palabra con la base de los registros de enemigo de esa
;   fase y diez bytes, uno por tramo, con el indice del primer enemigo de cada
;   uno
;   0x6a98..0x6af8  (96 bytes)
DATA_enemigos_por_fase:
	defw 06af8h,00300h,01009h,01613h,0211bh,00024h,06b64h,00400h	; 6a98
	defb 00ah,00fh,014h,018h,01ch,023h,02ah,000h,0e2h,06bh	; 6aa8  .....#*..k
	defb 000h,003h,007h,00eh,014h,01bh,022h,027h,02ah,000h	; 6ab2  ......"'*.
	defb 060h,06ch,000h,004h,00ah,010h,016h,01dh,021h,027h	; 6abc  `l......!'
	defb 02eh,000h,0eah,06ch,000h,006h,00ch,012h,01ah,01fh	; 6ac6  ...l......
	defb 025h,02dh,034h,000h,086h,06dh,000h,006h,00ch,012h	; 6ad0  %-4..m....
	defb 01ah,020h,027h,02ch,030h,032h,01ch,06eh,000h,005h	; 6ada  . ',02.n..
	defb 00bh,011h,018h,01ch,022h,026h,02ch,02dh,0a3h,06eh	; 6ae4  ...."&,-.n
	defb 000h,003h,009h,010h,017h,01ch,020h,026h,02bh,000h	; 6aee  ...... &+.

; ----------------------------------------------------------------------
; DATOS registros_de_enemigo: Tres bytes cada uno -tipo, y, x-, agrupados por
;   fase. 0x6A1E los lee: el tipo da (ix+0) y, por la tabla de 0x6A7F, (ix+8)
;   0x6af8..0x6f44  (1100 bytes)
DATA_registros_de_enemigo:
	defb 031h,004h,044h	; 6af8
	defb 031h,00eh,094h	; 6afb
	defb 031h,010h,094h	; 6afe
	defb 012h,018h,0e4h	; 6b01
	defb 032h,020h,074h	; 6b04
	defb 011h,020h,0c4h	; 6b07
	defb 011h,024h,0c4h	; 6b0a
	defb 031h,028h,034h	; 6b0d
	defb 011h,028h,0c4h	; 6b10
	defb 09bh,030h,001h	; 6b13
	defb 09ch,030h,0f8h	; 6b16
	defb 031h,038h,054h	; 6b19
	defb 031h,03ch,054h	; 6b1c
	defb 011h,040h,054h	; 6b1f
	defb 033h,042h,0b4h	; 6b22
	defb 011h,044h,054h	; 6b25
	defb 015h,050h,014h	; 6b28
	defb 031h,056h,0d4h	; 6b2b
	defb 013h,05eh,064h	; 6b2e
	defb 010h,06ch,0e4h	; 6b31
	defb 031h,072h,054h	; 6b34
	defb 031h,072h,0b4h	; 6b37
	defb 031h,086h,034h	; 6b3a
	defb 097h,088h,001h	; 6b3d
	defb 098h,088h,0f8h	; 6b40
	defb 015h,088h,0e4h	; 6b43
	defb 032h,08ah,064h	; 6b46
	defb 097h,090h,001h	; 6b49
	defb 098h,090h,0f8h	; 6b4c
	defb 011h,098h,084h	; 6b4f
	defb 011h,09eh,084h	; 6b52
	defb 013h,09eh,0d4h	; 6b55
	defb 031h,0a4h,084h	; 6b58
	defb 012h,0ach,034h	; 6b5b
	defb 09bh,0bch,001h	; 6b5e
	defb 09ch,0bch,0f8h	; 6b61
	defb 011h,008h,0a4h	; 6b64
	defb 012h,00ah,034h	; 6b67
	defb 011h,00eh,0a4h	; 6b6a
	defb 011h,014h,0a4h	; 6b6d
	defb 034h,020h,074h	; 6b70
	defb 034h,020h,084h	; 6b73
	defb 034h,020h,094h	; 6b76
	defb 034h,020h,0a4h	; 6b79
	defb 097h,028h,001h	; 6b7c
	defb 098h,028h,0f8h	; 6b7f
	defb 031h,038h,0a4h	; 6b82
	defb 011h,03ah,094h	; 6b85
	defb 031h,03ch,084h	; 6b88
	defb 011h,03eh,074h	; 6b8b
	defb 013h,044h,0b4h	; 6b8e
	defb 031h,04eh,054h	; 6b91
	defb 031h,050h,074h	; 6b94
	defb 031h,052h,094h	; 6b97
	defb 031h,054h,0b4h	; 6b9a
	defb 012h,05ah,044h	; 6b9d
	defb 011h,06ah,064h	; 6ba0
	defb 011h,070h,064h	; 6ba3
	defb 015h,070h,0e4h	; 6ba6
	defb 011h,076h,064h	; 6ba9
	defb 014h,07ah,094h	; 6bac
	defb 031h,084h,044h	; 6baf
	defb 033h,088h,0c4h	; 6bb2
	defb 011h,08ch,094h	; 6bb5
	defb 012h,092h,034h	; 6bb8
	defb 097h,094h,001h	; 6bbb
	defb 098h,094h,0f8h	; 6bbe
	defb 011h,09ch,054h	; 6bc1
	defb 031h,09ch,084h	; 6bc4
	defb 011h,09ch,0b4h	; 6bc7
	defb 014h,0a6h,064h	; 6bca
	defb 014h,0a8h,064h	; 6bcd
	defb 031h,0b2h,044h	; 6bd0
	defb 031h,0b2h,0b4h	; 6bd3
	defb 031h,0b6h,074h	; 6bd6
	defb 031h,0b6h,094h	; 6bd9
	defb 015h,0bch,014h	; 6bdc
	defb 014h,0beh,044h	; 6bdf
	defb 031h,006h,034h	; 6be2
	defb 031h,00ah,054h	; 6be5
	defb 031h,00eh,074h	; 6be8
	defb 012h,024h,0b4h	; 6beb
	defb 036h,026h,06ch	; 6bee
	defb 033h,02ah,044h	; 6bf1
	defb 031h,02ah,0d4h	; 6bf4
	defb 09bh,034h,001h	; 6bf7
	defb 09ch,034h,0f8h	; 6bfa
	defb 031h,038h,0a4h	; 6bfd
	defb 031h,03ch,084h	; 6c00
	defb 011h,040h,064h	; 6c03
	defb 010h,042h,0d4h	; 6c06
	defb 031h,044h,044h	; 6c09
	defb 031h,052h,044h	; 6c0c
	defb 031h,052h,0b4h	; 6c0f
	defb 011h,054h,064h	; 6c12
	defb 011h,054h,094h	; 6c15
	defb 014h,05ah,044h	; 6c18
	defb 014h,05ah,0b4h	; 6c1b
	defb 016h,062h,04ch	; 6c1e
	defb 011h,06ah,044h	; 6c21
	defb 011h,06ah,0c4h	; 6c24
	defb 031h,072h,054h	; 6c27
	defb 031h,072h,0a4h	; 6c2a
	defb 031h,074h,074h	; 6c2d
	defb 031h,074h,084h	; 6c30
	defb 099h,080h,001h	; 6c33
	defb 09ah,080h,0f8h	; 6c36
	defb 015h,086h,014h	; 6c39
	defb 011h,088h,0b4h	; 6c3c
	defb 031h,08ah,044h	; 6c3f
	defb 031h,08eh,044h	; 6c42
	defb 013h,08eh,0f4h	; 6c45
	defb 010h,09ch,014h	; 6c48
	defb 012h,09ch,0e4h	; 6c4b
	defb 09bh,0a4h,001h	; 6c4e
	defb 09ch,0a4h,0f8h	; 6c51
	defb 016h,0a6h,0cch	; 6c54
	defb 034h,0aah,054h	; 6c57
	defb 011h,0b6h,044h	; 6c5a
	defb 011h,0b6h,064h	; 6c5d
	defb 031h,006h,054h	; 6c60
	defb 031h,00ah,0d4h	; 6c63
	defb 031h,00ch,084h	; 6c66
	defb 031h,016h,074h	; 6c69
	defb 011h,020h,084h	; 6c6c
	defb 011h,022h,074h	; 6c6f
	defb 011h,024h,084h	; 6c72
	defb 097h,028h,001h	; 6c75
	defb 098h,028h,0f8h	; 6c78
	defb 012h,02eh,0c4h	; 6c7b
	defb 032h,030h,014h	; 6c7e
	defb 031h,036h,044h	; 6c81
	defb 034h,038h,0c4h	; 6c84
	defb 016h,03ah,0ach	; 6c87
	defb 013h,03eh,034h	; 6c8a
	defb 015h,03eh,0e4h	; 6c8d
	defb 014h,054h,044h	; 6c90
	defb 014h,054h,054h	; 6c93
	defb 014h,054h,064h	; 6c96
	defb 014h,054h,094h	; 6c99
	defb 014h,054h,0a4h	; 6c9c
	defb 014h,054h,0b4h	; 6c9f
	defb 011h,06ah,074h	; 6ca2
	defb 011h,06ah,084h	; 6ca5
	defb 011h,06eh,074h	; 6ca8
	defb 011h,06eh,084h	; 6cab
	defb 016h,072h,04ch	; 6cae
	defb 011h,076h,074h	; 6cb1
	defb 011h,076h,084h	; 6cb4
	defb 034h,082h,0c4h	; 6cb7
	defb 010h,084h,014h	; 6cba
	defb 016h,086h,0cch	; 6cbd
	defb 034h,08ah,054h	; 6cc0
	defb 031h,090h,0c4h	; 6cc3
	defb 016h,092h,04ch	; 6cc6
	defb 031h,096h,074h	; 6cc9
	defb 013h,096h,0d4h	; 6ccc
	defb 031h,09eh,044h	; 6ccf
	defb 012h,0a2h,084h	; 6cd2
	defb 099h,0b0h,001h	; 6cd5
	defb 09ah,0b0h,0f8h	; 6cd8
	defb 016h,0b2h,04ch	; 6cdb
	defb 031h,0b6h,024h	; 6cde
	defb 031h,0b6h,0b4h	; 6ce1
	defb 031h,0b8h,0c4h	; 6ce4
	defb 016h,0bah,0cch	; 6ce7
	defb 034h,002h,064h	; 6cea
	defb 031h,00ch,0d4h	; 6ced
	defb 013h,00eh,044h	; 6cf0
	defb 031h,012h,024h	; 6cf3
	defb 031h,012h,094h	; 6cf6
	defb 012h,012h,0e4h	; 6cf9
	defb 031h,018h,0d4h	; 6cfc
	defb 031h,01eh,064h	; 6cff
	defb 031h,022h,064h	; 6d02
	defb 031h,026h,084h	; 6d05
	defb 031h,02ah,084h	; 6d08
	defb 013h,02eh,0b4h	; 6d0b
	defb 031h,03ah,064h	; 6d0e
	defb 011h,03ah,094h	; 6d11
	defb 031h,040h,074h	; 6d14
	defb 011h,040h,084h	; 6d17
	defb 09bh,040h,001h	; 6d1a
	defb 09ch,040h,0f8h	; 6d1d
	defb 012h,048h,074h	; 6d20
	defb 031h,048h,084h	; 6d23
	defb 011h,054h,024h	; 6d26
	defb 011h,056h,0c4h	; 6d29
	defb 011h,058h,024h	; 6d2c
	defb 034h,05ah,074h	; 6d2f
	defb 011h,05ah,0c4h	; 6d32
	defb 034h,05ch,084h	; 6d35
	defb 031h,06ah,084h	; 6d38
	defb 09bh,070h,001h	; 6d3b
	defb 09ch,070h,0f8h	; 6d3e
	defb 011h,072h,0d4h	; 6d41
	defb 011h,076h,024h	; 6d44
	defb 012h,078h,014h	; 6d47
	defb 034h,07eh,054h	; 6d4a
	defb 034h,082h,074h	; 6d4d
	defb 034h,088h,084h	; 6d50
	defb 013h,08ah,0d4h	; 6d53
	defb 010h,08eh,014h	; 6d56
	defb 012h,096h,014h	; 6d59
	defb 099h,098h,001h	; 6d5c
	defb 09ah,098h,0f8h	; 6d5f
	defb 031h,09ch,0a4h	; 6d62
	defb 031h,09eh,0a4h	; 6d65
	defb 031h,0a0h,0a4h	; 6d68
	defb 014h,0a6h,074h	; 6d6b
	defb 014h,0a6h,084h	; 6d6e
	defb 013h,0aeh,0e4h	; 6d71
	defb 012h,0aeh,0f4h	; 6d74
	defb 031h,0b6h,044h	; 6d77
	defb 09bh,0bch,001h	; 6d7a
	defb 09ch,0bch,0f8h	; 6d7d
	defb 034h,0bch,074h	; 6d80
	defb 031h,0beh,084h	; 6d83
	defb 011h,004h,084h	; 6d86
	defb 014h,008h,074h	; 6d89
	defb 016h,00ah,04ch	; 6d8c
	defb 016h,00ah,0ach	; 6d8f
	defb 011h,010h,034h	; 6d92
	defb 011h,012h,0c4h	; 6d95
	defb 097h,018h,001h	; 6d98
	defb 098h,018h,0f8h	; 6d9b
	defb 012h,01ch,0a4h	; 6d9e
	defb 011h,022h,044h	; 6da1
	defb 011h,026h,034h	; 6da4
	defb 011h,028h,034h	; 6da7
	defb 011h,032h,054h	; 6daa
	defb 013h,034h,064h	; 6dad
	defb 011h,036h,074h	; 6db0
	defb 011h,038h,084h	; 6db3
	defb 014h,03ah,094h	; 6db6
	defb 016h,042h,04ch	; 6db9
	defb 012h,048h,0e4h	; 6dbc
	defb 014h,050h,064h	; 6dbf
	defb 014h,050h,074h	; 6dc2
	defb 014h,050h,084h	; 6dc5
	defb 014h,050h,094h	; 6dc8
	defb 013h,054h,024h	; 6dcb
	defb 011h,05ch,074h	; 6dce
	defb 011h,05ch,0d4h	; 6dd1
	defb 016h,062h,0cch	; 6dd4
	defb 011h,068h,034h	; 6dd7
	defb 011h,068h,074h	; 6dda
	defb 012h,06ah,094h	; 6ddd
	defb 016h,06eh,06ch	; 6de0
	defb 010h,072h,0f4h	; 6de3
	defb 011h,07eh,084h	; 6de6
	defb 011h,082h,074h	; 6de9
	defb 011h,084h,0c4h	; 6dec
	defb 011h,086h,084h	; 6def
	defb 011h,088h,0c4h	; 6df2
	defb 012h,08ah,074h	; 6df5
	defb 014h,08eh,084h	; 6df8
	defb 016h,096h,0ach	; 6dfb
	defb 013h,09ah,014h	; 6dfe
	defb 097h,09ch,001h	; 6e01
	defb 098h,09ch,0f8h	; 6e04
	defb 016h,09eh,04ch	; 6e07
	defb 014h,0b0h,024h	; 6e0a
	defb 014h,0b0h,034h	; 6e0d
	defb 016h,0b6h,0cch	; 6e10
	defb 014h,0beh,0c4h	; 6e13
	defb 011h,0c0h,034h	; 6e16
	defb 011h,0c0h,094h	; 6e19
	defb 011h,008h,084h	; 6e1c
	defb 016h,00eh,04ch	; 6e1f
	defb 097h,014h,001h	; 6e22
	defb 098h,014h,0f8h	; 6e25
	defb 016h,016h,08ch	; 6e28
	defb 012h,01ah,024h	; 6e2b
	defb 011h,01ch,034h	; 6e2e
	defb 012h,024h,0e4h	; 6e31
	defb 016h,026h,0ach	; 6e34
	defb 016h,02ah,0ach	; 6e37
	defb 014h,02eh,034h	; 6e3a
	defb 011h,034h,084h	; 6e3d
	defb 013h,036h,024h	; 6e40
	defb 011h,036h,084h	; 6e43
	defb 016h,03eh,0cch	; 6e46
	defb 010h,042h,024h	; 6e49
	defb 016h,046h,02ch	; 6e4c
	defb 011h,050h,094h	; 6e4f
	defb 014h,052h,094h	; 6e52
	defb 09bh,054h,001h	; 6e55
	defb 09ch,054h,0f8h	; 6e58
	defb 016h,056h,0cch	; 6e5b
	defb 016h,05ah,0cch	; 6e5e
	defb 016h,05eh,0cch	; 6e61
	defb 031h,066h,0a4h	; 6e64
	defb 013h,068h,0b4h	; 6e67
	defb 016h,072h,04ch	; 6e6a
	defb 016h,076h,04ch	; 6e6d
	defb 09bh,084h,001h	; 6e70
	defb 09ch,084h,0f8h	; 6e73
	defb 016h,086h,04ch	; 6e76
	defb 016h,086h,0ach	; 6e79
	defb 016h,08eh,06ch	; 6e7c
	defb 016h,08eh,08ch	; 6e7f
	defb 011h,096h,0c4h	; 6e82
	defb 012h,098h,044h	; 6e85
	defb 016h,09eh,08ch	; 6e88
	defb 016h,0a6h,06ch	; 6e8b
	defb 016h,0aah,06ch	; 6e8e
	defb 011h,0b0h,0c4h	; 6e91
	defb 097h,0b0h,001h	; 6e94
	defb 098h,0b0h,0f8h	; 6e97
	defb 016h,0b2h,0ach	; 6e9a
	defb 010h,0b6h,064h	; 6e9d
	defb 031h,0c0h,044h	; 6ea0
	defb 011h,008h,0b4h	; 6ea3
	defb 011h,00eh,044h	; 6ea6
	defb 011h,00eh,094h	; 6ea9
	defb 013h,018h,044h	; 6eac
	defb 012h,018h,0d4h	; 6eaf
	defb 014h,020h,0b4h	; 6eb2
	defb 014h,024h,054h	; 6eb5
	defb 011h,02ch,084h	; 6eb8
	defb 014h,02eh,084h	; 6ebb
	defb 011h,036h,0a4h	; 6ebe
	defb 011h,038h,054h	; 6ec1
	defb 011h,03eh,0a4h	; 6ec4
	defb 012h,03eh,0c4h	; 6ec7
	defb 011h,040h,054h	; 6eca
	defb 011h,042h,0a4h	; 6ecd
	defb 011h,044h,054h	; 6ed0
	defb 012h,050h,0e4h	; 6ed3
	defb 014h,054h,084h	; 6ed6
	defb 011h,05ah,014h	; 6ed9
	defb 013h,05ch,014h	; 6edc
	defb 011h,05ch,054h	; 6edf
	defb 014h,05ch,0a4h	; 6ee2
	defb 011h,05eh,0a4h	; 6ee5
	defb 014h,06eh,044h	; 6ee8
	defb 011h,070h,064h	; 6eeb
	defb 011h,070h,0c4h	; 6eee
	defb 014h,072h,074h	; 6ef1
	defb 012h,074h,074h	; 6ef4
	defb 011h,080h,074h	; 6ef7
	defb 012h,082h,024h	; 6efa
	defb 011h,082h,074h	; 6efd
	defb 013h,086h,0c4h	; 6f00
	defb 012h,090h,014h	; 6f03
	defb 014h,098h,054h	; 6f06
	defb 011h,098h,084h	; 6f09
	defb 014h,09ch,054h	; 6f0c
	defb 011h,0a0h,054h	; 6f0f
	defb 014h,0a4h,0a4h	; 6f12
	defb 014h,0aeh,094h	; 6f15
	defb 014h,0aeh,0a4h	; 6f18
	defb 011h,0b4h,044h	; 6f1b
	defb 011h,0b8h,0a4h	; 6f1e
	defb 014h,0bch,064h	; 6f21
	defb 030h,02eh,031h	; 6f24
	defb 02fh,034h,032h	; 6f27
	defb 035h,033h,038h	; 6f2a
	defb 036h,039h,037h	; 6f2d
	defb 03ch,03ah,03dh	; 6f30
	defb 03bh,04fh,04ch	; 6f33
	defb 04dh,04eh,0a0h	; 6f36
	defb 0a1h,001h,001h	; 6f39
	defb 028h,03eh,029h	; 6f3c
	defb 027h,02dh,02ch	; 6f3f
	defb 02bh,02ah	; 6f42

; ======================================================================
; CODIGO 0x6f44..0x7033  (239 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; ====================================================================
; UN TRUCO ESCONDIDO. Lo llama 0x4182, justo despues de `partida_nueva`,
; o sea UNA VEZ, al arrancar la partida. Pide que (0xE009) valga 0x2C en
; sus seis bits bajos -bits 2, 3 y 5: IZQUIERDA y DERECHA a la vez mas
; el segundo boton, que en un joystick no se puede hacer- y ademas una
; tecla. Con la matriz estandar del MSX -fila 3 = C D E F G H I J,
; fila 4 = K L M N O P Q R, fila 5 = S T U V W X Y Z- los bits que
; comprueba son la 'I', la 'N' y la 'Y'.
; Falta grabarlo en el emulador: esto es lectura del codigo.
; ====================================================================
; ----------------------------------------------------------------------
el_truco_del_arranque:
	ld a,(0e009h)		;6f44   ; lo que hay pulsado
	and 03fh		;6f47
	cp 02ch		;6f49   ; 0x2C = izquierda + derecha + el segundo boton
	ret nz			;6f4b
	ld a,003h		;6f4c
	call 00141h		;6f4e   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix | fila 3 del teclado: C D E F G H I J
	cp 0bfh		;6f51   ; el bit 6 a cero es la 'I'
	ld a,001h		;6f53
	call z,L_6F6B		;6f55
	ld a,004h		;6f58
	call 00141h		;6f5a   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix | fila 4: K L M N O P Q R
	cp 0f7h		;6f5d   ; el bit 3 a cero es la 'N'
	jr z,L_6F6F		;6f5f
	ld a,005h		;6f61
	call 00141h		;6f63   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix | fila 5: S T U V W X Y Z
	cp 0bfh		;6f66   ; y el bit 6, la 'Y'
	ret nz			;6f68
	ld a,010h		;6f69
L_6F6B:
	ld (0e069h),a		;6f6b   ; con la 'I' y con la 'Y' se toca el arma de (0xE069)
	ret			;6f6e
L_6F6F:
	ld a,026h		;6f6f   ; y con la 'N', 26 VIDAS de golpe
	ld (0e060h),a		;6f71
	ret			;6f74

; ----------------------------------------------------------------------
; EL GENERADOR DE OLEADAS. Cada dos cuadros baja el reloj de (0xE1E1);
; cuando llega a cero saca la entrada siguiente del guion de la fase y
; la mete en una de las dos ranuras de 0xE0A0.
; ----------------------------------------------------------------------
el_generador:
	ld a,(0e09eh)		;6f75   ; hasta que (0xE09E) no se enciende no hay oleadas
	and a			;6f78
	jr nz,L_6F7F		;6f79
	ld (0e1e1h),a		;6f7b
	ret			;6f7e
L_6F7F:
	ld a,(0e003h)		;6f7f
	and 01eh		;6f82   ; uno de cada dos cuadros
	ret nz			;6f84
	ld hl,0e1e1h		;6f85
	ld a,(hl)			;6f88
	and 07fh		;6f89   ; el reloj, sin su bit 7
	jr z,L_6F8F		;6f8b
	dec (hl)			;6f8d   ; todavia no toca
	ret			;6f8e
L_6F8F:
	ld a,(hl)			;6f8f
	rla			;6f90   ; con el bit 7 puesto se salta la espera
	jr c,L_6FAC		;6f91
	ld a,(0e0a0h)		;6f93   ; con las dos ranuras ocupadas no se saca nada
	and a			;6f96
	ret nz			;6f97
	ld a,(0e0b0h)		;6f98
	and a			;6f9b
	ret nz			;6f9c
	ld hl,0e100h		;6f9d   ; ni con alguno de los siete enemigos vivo
	ld b,007h		;6fa0
L_6FA2:
	ld a,(hl)			;6fa2   ; con alguno vivo no se saca oleada
	and a			;6fa3
	ret nz			;6fa4
	ld a,020h		;6fa5   ; y el siguiente, 0x20 mas alla
	call suma_a_a_hl		;6fa7
	djnz L_6FA2		;6faa
L_6FAC:
	ld ix,0e0a0h		;6fac   ; la primera ranura
	ld a,(ix+000h)		;6fb0
	and a			;6fb3
	jr z,L_6FBF		;6fb4
	ld ix,0e0b0h		;6fb6   ; y si esta ocupada, la segunda
	ld a,(ix+000h)		;6fba
	and a			;6fbd
	ret nz			;6fbe
L_6FBF:
	push ix		;6fbf
	pop hl			;6fc1
	xor a			;6fc2
	ld b,008h		;6fc3
L_6FC5:
	ld (hl),a			;6fc5   ; se borra entera
	inc hl			;6fc6
	djnz L_6FC5		;6fc7
	ld a,(0e062h)		;6fc9
	ld hl,0704bh		;6fcc   ; el guion de oleadas de la fase
	call palabra_de_tabla_doble		;6fcf
	ld hl,0e09fh		;6fd2
	ld a,(hl)			;6fd5   ; por la entrada que toque, de dos bytes
	add a,a			;6fd6
	call suma_a_a_de		;6fd7
	ld a,(de)			;6fda
	ld c,a			;6fdb
	ld (ix+000h),a		;6fdc   ; el primer byte es el tipo de bicho
	inc de			;6fdf
	ld a,(de)			;6fe0
	rra			;6fe1   ; el nibble alto del segundo, cuantos
	rra			;6fe2
	rra			;6fe3
	rra			;6fe4
	and 00fh		;6fe5
	ld b,a			;6fe7
	ld a,(0e068h)		;6fe8   ; con (0xE068) puesto salen dos mas
	and a			;6feb
	jr z,L_6FF4		;6fec
	ld a,b			;6fee
	dec a			;6fef
	jr z,L_6FF4		;6ff0
	inc b			;6ff2
	inc b			;6ff3
L_6FF4:
	ld (ix+006h),b		;6ff4
	ld a,(de)			;6ff7   ; y el nibble bajo por dos es la espera hasta la oleada siguiente
	and 00fh		;6ff8
	add a,a			;6ffa
	bit 5,c		;6ffb   ; con el bit 5 del tipo, el bit 7: sin espera
	jr z,L_7001		;6ffd
	set 7,a		;6fff
L_7001:
	ld (0e1e1h),a		;7001
	ld a,(ix+000h)		;7004
	and a			;7007
	jr z,L_700E		;7008
	ld (ix+008h),001h		;700a   ; la ranura queda pidiendo patrones
L_700E:
	ld a,(0e062h)		;700e
	ld de,07043h		;7011   ; cuantas entradas tiene el guion de esta fase
	call suma_a_a_de		;7014
	ld a,(de)			;7017
	ld c,a			;7018
	inc (hl)			;7019   ; y a la siguiente, dando la vuelta al llegar al final
	ld a,(hl)			;701a
	cp c			;701b
	jr c,L_7020		;701c
	ld (hl),000h		;701e
L_7020:
	ld a,(ix+000h)		;7020
	bit 6,a		;7023   ; con el bit 6 del tipo, ademas se le pone el (ix+3) de la tabla de 0x7033
	ret z			;7025
	ld hl,07033h		;7026
	and 00fh		;7029
	call suma_a_a_hl		;702b
	ld a,(hl)			;702e
	ld (ix+003h),a		;702f
	ret			;7032

; ----------------------------------------------------------------------
; DATOS tabla_de_los_dieciseis: Dieciseis bytes; 0x7026 la indexa con los
;   cuatro bits bajos de (ix+0) y el resultado va a (ix+3)
;   0x7033..0x7043  (16 bytes)
DATA_tabla_de_los_dieciseis:
	defb 001h,005h,005h,005h,005h,005h,001h,001h,006h,004h,004h,001h,001h,001h,001h,001h	; 7033  ................

; ----------------------------------------------------------------------
; DATOS entradas_por_fase: Ocho cuentas -34, 41, 41, 38, 36, 33, 30 y 35-: las
;   entradas del guion de oleadas de cada fase
;   0x7043..0x704b  (8 bytes)
DATA_entradas_por_fase:
	defb 022h,029h,029h,026h,024h,021h,01eh,023h	; 7043  "))&$!.#

; ----------------------------------------------------------------------
; DATOS guiones_de_oleada: Ocho punteros, uno por fase; 0x5494 los indexa con
;   (0xE062)
;   0x704b..0x705b  (16 bytes)
DATA_guiones_de_oleada:
	defw 0705bh,0709fh,070f1h,07143h,0718fh,071d7h,07219h,07255h	; 704b

; ----------------------------------------------------------------------
; DATOS oleadas: Los ocho guiones, de dos bytes por entrada y seguidos. Cada
;   tramo cuadra con su cuenta de 0x7043: 0x709F-0x705B son 68 = 34*2, y asi
;   las ocho
;   0x705b..0x729b  (576 bytes)
DATA_oleadas:
	defb 00eh,060h	; 705b
	defb 02eh,044h	; 705d
	defb 041h,010h	; 705f
	defb 041h,010h	; 7061
	defb 041h,010h	; 7063
	defb 00eh,040h	; 7065
	defb 002h,040h	; 7067
	defb 002h,040h	; 7069
	defb 02eh,024h	; 706b
	defb 001h,020h	; 706d
	defb 001h,040h	; 706f
	defb 001h,040h	; 7071
	defb 000h,013h	; 7073
	defb 009h,040h	; 7075
	defb 089h,040h	; 7077
	defb 0aeh,064h	; 7079
	defb 081h,060h	; 707b
	defb 041h,010h	; 707d
	defb 0c1h,010h	; 707f
	defb 0c1h,010h	; 7081
	defb 0aeh,023h	; 7083
	defb 0c2h,010h	; 7085
	defb 0c2h,010h	; 7087
	defb 0c2h,010h	; 7089
	defb 08eh,080h	; 708b
	defb 000h,013h	; 708d
	defb 0a9h,042h	; 708f
	defb 081h,040h	; 7091
	defb 081h,040h	; 7093
	defb 0aeh,043h	; 7095
	defb 081h,060h	; 7097
	defb 0a1h,061h	; 7099
	defb 089h,040h	; 709b
	defb 081h,0a0h	; 709d
	defb 02eh,052h	; 709f
	defb 082h,060h	; 70a1
	defb 082h,060h	; 70a3
	defb 004h,040h	; 70a5
	defb 084h,040h	; 70a7
	defb 0e9h,013h	; 70a9
	defb 084h,040h	; 70ab
	defb 0aeh,043h	; 70ad
	defb 0c9h,010h	; 70af
	defb 0c9h,010h	; 70b1
	defb 000h,013h	; 70b3
	defb 00ch,020h	; 70b5
	defb 02ch,043h	; 70b7
	defb 082h,0a0h	; 70b9
	defb 007h,030h	; 70bb
	defb 0aeh,044h	; 70bd
	defb 0c1h,010h	; 70bf
	defb 0c1h,010h	; 70c1
	defb 0c1h,010h	; 70c3
	defb 0a7h,034h	; 70c5
	defb 0c1h,010h	; 70c7
	defb 000h,012h	; 70c9
	defb 00bh,020h	; 70cb
	defb 0e1h,011h	; 70cd
	defb 00bh,020h	; 70cf
	defb 0e1h,013h	; 70d1
	defb 00bh,030h	; 70d3
	defb 0aeh,082h	; 70d5
	defb 00bh,030h	; 70d7
	defb 0a0h,022h	; 70d9
	defb 00bh,030h	; 70db
	defb 0a0h,031h	; 70dd
	defb 00bh,040h	; 70df
	defb 0a0h,041h	; 70e1
	defb 00bh,060h	; 70e3
	defb 0a1h,0a1h	; 70e5
	defb 003h,080h	; 70e7
	defb 0a2h,0a1h	; 70e9
	defb 003h,080h	; 70eb
	defb 0a3h,081h	; 70ed
	defb 00bh,060h	; 70ef
	defb 04ah,010h	; 70f1
	defb 04ah,010h	; 70f3
	defb 04ah,010h	; 70f5
	defb 04ah,010h	; 70f7
	defb 00bh,060h	; 70f9
	defb 0aeh,042h	; 70fb
	defb 003h,060h	; 70fd
	defb 083h,040h	; 70ff
	defb 0e1h,012h	; 7101
	defb 00bh,040h	; 7103
	defb 0e1h,011h	; 7105
	defb 00bh,040h	; 7107
	defb 0e1h,011h	; 7109
	defb 00bh,060h	; 710b
	defb 0e1h,011h	; 710d
	defb 00bh,060h	; 710f
	defb 02ch,044h	; 7111
	defb 084h,040h	; 7113
	defb 0c4h,010h	; 7115
	defb 0c4h,010h	; 7117
	defb 0c4h,010h	; 7119
	defb 0aeh,022h	; 711b
	defb 0a0h,042h	; 711d
	defb 08eh,030h	; 711f
	defb 0a7h,042h	; 7121
	defb 08ah,0a0h	; 7123
	defb 0e4h,012h	; 7125
	defb 0cah,010h	; 7127
	defb 0e4h,012h	; 7129
	defb 00bh,040h	; 712b
	defb 08bh,040h	; 712d
	defb 0aeh,042h	; 712f
	defb 08ah,080h	; 7131
	defb 0a7h,061h	; 7133
	defb 08bh,0a0h	; 7135
	defb 02ch,041h	; 7137
	defb 081h,0a0h	; 7139
	defb 0a2h,0a1h	; 713b
	defb 08ah,0a0h	; 713d
	defb 0abh,0a1h	; 713f
	defb 087h,040h	; 7141
	defb 0aeh,042h	; 7143
	defb 081h,040h	; 7145
	defb 0e1h,011h	; 7147
	defb 084h,040h	; 7149
	defb 0c1h,010h	; 714b
	defb 0e1h,011h	; 714d
	defb 084h,060h	; 714f
	defb 0aeh,083h	; 7151
	defb 080h,060h	; 7153
	defb 02ch,042h	; 7155
	defb 08ah,0a0h	; 7157
	defb 0e2h,011h	; 7159
	defb 0cah,010h	; 715b
	defb 000h,014h	; 715d
	defb 0aeh,042h	; 715f
	defb 00bh,060h	; 7161
	defb 0c1h,010h	; 7163
	defb 0c1h,010h	; 7165
	defb 0e1h,011h	; 7167
	defb 08bh,060h	; 7169
	defb 0a1h,081h	; 716b
	defb 08bh,080h	; 716d
	defb 02ch,052h	; 716f
	defb 080h,080h	; 7171
	defb 0e3h,011h	; 7173
	defb 080h,060h	; 7175
	defb 0e3h,011h	; 7177
	defb 080h,080h	; 7179
	defb 0e4h,011h	; 717b
	defb 081h,060h	; 717d
	defb 0e4h,011h	; 717f
	defb 082h,060h	; 7181
	defb 0a9h,041h	; 7183
	defb 0cah,010h	; 7185
	defb 0eah,011h	; 7187
	defb 0c3h,010h	; 7189
	defb 0eah,011h	; 718b
	defb 0c3h,010h	; 718d
	defb 048h,010h	; 718f
	defb 048h,010h	; 7191
	defb 0aeh,041h	; 7193
	defb 048h,010h	; 7195
	defb 0aeh,062h	; 7197
	defb 089h,040h	; 7199
	defb 089h,041h	; 719b
	defb 088h,0a0h	; 719d
	defb 088h,040h	; 719f
	defb 000h,012h	; 71a1
	defb 0aeh,041h	; 71a3
	defb 025h,060h	; 71a5
	defb 045h,010h	; 71a7
	defb 045h,010h	; 71a9
	defb 02ch,041h	; 71ab
	defb 087h,040h	; 71ad
	defb 02ch,041h	; 71af
	defb 085h,080h	; 71b1
	defb 085h,060h	; 71b3
	defb 02ch,021h	; 71b5
	defb 0c5h,010h	; 71b7
	defb 02ch,021h	; 71b9
	defb 0c5h,010h	; 71bb
	defb 0a7h,041h	; 71bd
	defb 089h,040h	; 71bf
	defb 0c8h,010h	; 71c1
	defb 0c8h,010h	; 71c3
	defb 0e8h,011h	; 71c5
	defb 0c5h,010h	; 71c7
	defb 0a8h,0a1h	; 71c9
	defb 0c5h,010h	; 71cb
	defb 02ch,041h	; 71cd
	defb 085h,060h	; 71cf
	defb 0a5h,041h	; 71d1
	defb 00ch,041h	; 71d3
	defb 088h,080h	; 71d5
	defb 089h,080h	; 71d7
	defb 0a8h,081h	; 71d9
	defb 082h,080h	; 71db
	defb 0c2h,010h	; 71dd
	defb 0c2h,010h	; 71df
	defb 0e2h,011h	; 71e1
	defb 089h,040h	; 71e3
	defb 0a6h,048h	; 71e5
	defb 081h,060h	; 71e7
	defb 0a6h,012h	; 71e9
	defb 0c1h,010h	; 71eb
	defb 0c1h,010h	; 71ed
	defb 0afh,0b2h	; 71ef
	defb 085h,0f0h	; 71f1
	defb 0e5h,011h	; 71f3
	defb 089h,060h	; 71f5
	defb 0afh,062h	; 71f7
	defb 082h,0d0h	; 71f9
	defb 0c5h,010h	; 71fb
	defb 0c5h,010h	; 71fd
	defb 085h,081h	; 71ff
	defb 081h,0a0h	; 7201
	defb 0c1h,010h	; 7203
	defb 0afh,061h	; 7205
	defb 085h,0a0h	; 7207
	defb 0a2h,0a1h	; 7209
	defb 085h,0a0h	; 720b
	defb 0a5h,041h	; 720d
	defb 082h,060h	; 720f
	defb 0a2h,0a1h	; 7211
	defb 085h,0a0h	; 7213
	defb 0a3h,0a1h	; 7215
	defb 085h,0a0h	; 7217
	defb 00dh,080h	; 7219
	defb 0c8h,010h	; 721b
	defb 0c8h,010h	; 721d
	defb 0a0h,081h	; 721f
	defb 08bh,080h	; 7221
	defb 08dh,060h	; 7223
	defb 0e8h,011h	; 7225
	defb 08bh,080h	; 7227
	defb 0c8h,010h	; 7229
	defb 0c8h,010h	; 722b
	defb 02ch,042h	; 722d
	defb 080h,060h	; 722f
	defb 0adh,0a2h	; 7231
	defb 08bh,0c0h	; 7233
	defb 08dh,040h	; 7235
	defb 02ch,041h	; 7237
	defb 088h,040h	; 7239
	defb 088h,060h	; 723b
	defb 0a0h,081h	; 723d
	defb 084h,080h	; 723f
	defb 0a8h,0a1h	; 7241
	defb 08dh,0a0h	; 7243
	defb 0a4h,081h	; 7245
	defb 08dh,0c0h	; 7247
	defb 0a8h,0a1h	; 7249
	defb 08bh,0a1h	; 724b
	defb 08dh,080h	; 724d
	defb 0a0h,0a1h	; 724f
	defb 08bh,0a1h	; 7251
	defb 08dh,080h	; 7253
	defb 0abh,0c3h	; 7255
	defb 081h,080h	; 7257
	defb 0a1h,082h	; 7259
	defb 0a9h,062h	; 725b
	defb 08bh,040h	; 725d
	defb 0a8h,0a2h	; 725f
	defb 08bh,080h	; 7261
	defb 0a5h,042h	; 7263
	defb 081h,040h	; 7265
	defb 0a1h,081h	; 7267
	defb 080h,080h	; 7269
	defb 0a8h,081h	; 726b
	defb 08bh,080h	; 726d
	defb 000h,012h	; 726f
	defb 02ch,041h	; 7271
	defb 0a0h,061h	; 7273
	defb 08bh,060h	; 7275
	defb 0a1h,081h	; 7277
	defb 0a2h,081h	; 7279
	defb 083h,080h	; 727b
	defb 0abh,0a1h	; 727d
	defb 02ch,041h	; 727f
	defb 0adh,062h	; 7281
	defb 081h,040h	; 7283
	defb 0a5h,061h	; 7285
	defb 08ah,060h	; 7287
	defb 0a8h,0a1h	; 7289
	defb 085h,080h	; 728b
	defb 000h,011h	; 728d
	defb 02ch,082h	; 728f
	defb 0a0h,041h	; 7291
	defb 08bh,080h	; 7293
	defb 0abh,081h	; 7295
	defb 0a5h,061h	; 7297
	defb 089h,050h	; 7299

; ======================================================================
; CODIGO 0x729b..0x73ce  (307 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; SOLTAR LOS BICHOS DE LA OLEADA. Las dos ranuras de 0xE0A0 van
; soltando bichos de uno en uno hasta completar la oleada.
; ----------------------------------------------------------------------
suelta_los_bichos:
	ld a,(0e091h)		;729b
	cp 0c8h		;729e   ; cerca del techo del tramo, ya no
	ret nc			;72a0
	ld iy,0e0a0h		;72a1   ; las dos ranuras
	ld b,002h		;72a5
L_72A7:
	push bc			;72a7
	call suelta_de_una_ranura		;72a8   ; cada una suelta lo suyo
	pop bc			;72ab
	ld de,00010h		;72ac   ; y la siguiente, 0x10 mas alla
	add iy,de		;72af
	djnz L_72A7		;72b1
	ret			;72b3
suelta_de_una_ranura:
	ld a,(iy+000h)		;72b4
	and a			;72b7   ; vacia, nada que hacer
	ret z			;72b8
	ld a,(iy+008h)		;72b9   ; con (iy+8) puesto esta esperando sus patrones
	and a			;72bc
	ret nz			;72bd
	ld a,(iy+005h)		;72be   ; (iy+5) es lo que queda de rafaga
	and a			;72c1
	jr nz,L_72CE		;72c2
	ld a,(iy+001h)		;72c4   ; y (iy+1) la espera entre bichos
	and a			;72c7
	jr z,L_72EC		;72c8
	dec (iy+001h)		;72ca
	ret			;72cd
L_72CE:
	ld a,(iy+004h)		;72ce
	and a			;72d1
	jr z,L_72D8		;72d2
	dec (iy+004h)		;72d4
	ret			;72d7
L_72D8:
	ld hl,073ceh		;72d8   ; la espera de esta oleada, de la tabla de 0x73CE
	ld a,(iy+000h)		;72db
	and 00fh		;72de
	call suma_a_a_hl		;72e0
	ld a,(hl)			;72e3
	ld (iy+004h),a		;72e4
	dec (iy+005h)		;72e7   ; un bicho menos de la rafaga
	jr L_72FA		;72ea
L_72EC:
	ld a,(iy+000h)		;72ec
	bit 6,a		;72ef   ; con el bit 6 del tipo la rafaga vuelve a empezar
	jr z,L_72FA		;72f1
	ld a,(iy+003h)		;72f3
	ld (iy+005h),a		;72f6
	ret			;72f9
L_72FA:
	call busca_ranura_de_enemigo		;72fa   ; busca una ranura de enemigo libre
	ret nz			;72fd   ; sin sitio, no sale
	ld (ix+000h),001h		;72fe   ; ranura tomada
	ld (ix+011h),0ffh		;7302
	ld a,(iy+007h)		;7306   ; el patron base de la ranura de sprites en la que esta cargado
	ld (ix+016h),a		;7309
	ld a,(iy+000h)		;730c   ; y el tipo
	ld (ix+001h),a		;730f
	bit 6,a		;7312   ; los del bit 6 van en formacion
	jr z,L_734F		;7314
	ld hl,0e1e2h		;7316   ; y llevan su cuenta en 0xE1E2
	ld a,(hl)			;7319
	push af			;731a
	ld c,a			;731b
	add a,a			;731c
	add a,c			;731d
	inc hl			;731e
	call suma_a_a_hl		;731f
	pop af			;7322
	rla			;7323
	rla			;7324
	rla			;7325
	rla			;7326
	and 0f0h		;7327
	ld c,a			;7329
	ld a,(hl)			;732a
	ld b,a			;732b
	or c			;732c
	ld (ix+011h),a		;732d
	inc (hl)			;7330
	inc hl			;7331
	ld a,(ix+001h)		;7332
	and 00fh		;7335
	ld de,07033h		;7337   ; la tabla de 0x7033 dice si el recorrido es fijo
	call suma_a_a_de		;733a
	ld a,(de)			;733d
	cp 001h		;733e
	jr nz,L_7344		;7340
	ld a,0ffh		;7342
L_7344:
	ld (hl),a			;7344
	ld a,b			;7345
	and a			;7346
	jr nz,L_734F		;7347
	ld a,(0e604h)		;7349   ; la columna de la formacion se guarda
	ld (0e1f2h),a		;734c
L_734F:
	ld a,(iy+000h)		;734f
	and 00fh		;7352
	ld hl,073f5h		;7354   ; la fila de salida, de la tabla de 0x73F5
	call suma_a_a_hl		;7357
	ld a,(hl)			;735a
	ld (ix+003h),a		;735b
	ld hl,07405h		;735e   ; y la columna, de la de 0x7405
	ld a,(iy+002h)		;7361
	ld c,a			;7364
	and 007h		;7365
	call suma_a_a_hl		;7367
	ld a,c			;736a
	and a			;736b
	ld c,(hl)			;736c
	jr nz,L_7384		;736d
	ld a,(ix+001h)		;736f
	bit 6,a		;7372
	ld a,(0e1f2h)		;7374
	jr nz,L_737C		;7377
	ld a,(0e604h)		;7379
L_737C:
	cp 087h		;737c   ; a la derecha del centro sale por 0x50, y a la izquierda por 0xB0
	ld c,050h		;737e
	jr nc,L_7384		;7380
	ld c,0b0h		;7382
L_7384:
	ld (ix+005h),c		;7384
	ld hl,0740dh		;7387   ; la espera hasta el siguiente, de la tabla de 0x740D
	ld a,(ix+001h)		;738a
	and 00fh		;738d
	call suma_a_a_hl		;738f
	ld a,(hl)			;7392
	ld (iy+001h),a		;7393
	ld a,(iy+005h)		;7396   ; solo al acabar la rafaga
	and a			;7399
	ret nz			;739a
	ld a,(iy+000h)		;739b
	bit 6,a		;739e   ; con el bit 6 se pasa a la formacion siguiente, de cuatro
	jr z,L_73B9		;73a0
	ld hl,0e1e2h		;73a2   ; la formacion siguiente, de cuatro
	inc (hl)			;73a5
	ld a,(hl)			;73a6
	and 003h		;73a7
	ld (hl),a			;73a9
	ld hl,0e1e3h		;73aa   ; y sus tres bytes de cuenta, a cero
	ld c,a			;73ad
	add a,a			;73ae
	add a,c			;73af
	call suma_a_a_hl		;73b0
	xor a			;73b3
	ld (hl),a			;73b4
	inc hl			;73b5
	ld (hl),a			;73b6
	inc hl			;73b7
	ld (hl),a			;73b8
L_73B9:
	inc (iy+002h)		;73b9   ; un bicho mas soltado
	ld a,(iy+002h)		;73bc
	cp (iy+006h)		;73bf   ; hasta los que pide (iy+6)
	ret c			;73c2
	xor a			;73c3   ; y la ranura queda libre
	ld (iy+000h),a		;73c4
	ld (iy+001h),a		;73c7
	ld (iy+002h),a		;73ca
	ret			;73cd

; ----------------------------------------------------------------------
; DATOS dieciseis_bytes_de_0x72D8: La espera entre bicho y bicho de cada tipo
;   de oleada; 0x72D8 indexa con los cuatro bits bajos
;   0x73ce..0x73de  (16 bytes)
DATA_dieciseis_bytes_de_0x72D8:
	defb 001h,005h,005h,005h,007h,007h,001h,001h,008h,010h,006h,001h,001h,001h,001h,001h	; 73ce  ................

; ======================================================================
; CODIGO 0x73de..0x73f5  (23 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; BUSCAR UNA RANURA DE ENEMIGO LIBRE. Siete, de 0x20 en 0x20 desde
; 0xE100. Sale con Z puesto y la ranura en IX, o con Z a cero si no hay.
; ----------------------------------------------------------------------
busca_ranura_de_enemigo:
	ld hl,0e100h		;73de
	ld b,007h		;73e1
L_73E3:
	ld a,(hl)			;73e3   ; la ranura, si esta a cero, esta libre
	and a			;73e4
	jr z,L_73F1		;73e5
	ld a,020h		;73e7   ; y si no, 0x20 mas alla
	call suma_a_a_hl		;73e9
	djnz L_73E3		;73ec
	or 001h		;73ee
	ret			;73f0
L_73F1:
	push hl			;73f1
	pop ix		;73f2
	ret			;73f4

; ----------------------------------------------------------------------
; DATOS tres_tramos_de_0x7354: Los leen 0x7354, 0x735E y 0x7387
;   0x73f5..0x741d  (40 bytes)
DATA_tres_tramos_de_0x7354:
	defb 0f0h,0f0h,0f0h,088h,0f0h,0f0h,0f0h,0f0h	; 73f5  ........
	defb 0f0h,0f0h,010h,001h,010h,001h,0f0h,001h	; 73fd  ........
	defb 050h,028h,0b0h,080h,0d8h,07fh,0b0h,028h	; 7405  P(.....(
	defb 028h,010h,010h,010h,010h,010h,070h,050h	; 740d  (.....pP
	defb 010h,018h,020h,010h,030h,028h,040h,030h	; 7415  .. .0(@0

; ======================================================================
; CODIGO 0x741d..0x75aa  (397 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; ====================================================================
; LOS SIETE ENEMIGOS. Ranuras de 0x20 bytes desde 0xE100. Cada cuadro:
; se mueven, se mira si los tocan los disparos y se mira si tocan al
; muneco.
; ====================================================================
; ----------------------------------------------------------------------
haz_los_enemigos:
	ld a,(0e3b0h)		;741d
	and a			;7420   ; en la pantalla del jefe no hay enemigos corrientes
	ret nz			;7421
	ld a,(0e091h)		;7422
	cp 0cah		;7425   ; pasada la fila 0xCA, se los mata a todos
	call nc,L_6924		;7427
	call L_772A		;742a   ; los sprites
	ld a,(0e663h)		;742d
	and a			;7430   ; y sin jefe sonando, tambien las oleadas
	jr nz,L_7439		;7431
	call el_generador		;7433
	call suelta_los_bichos		;7436
L_7439:
	ld ix,0e100h		;7439   ; las siete ranuras
	ld b,007h		;743d
L_743F:
	push bc			;743f
	call mueve_un_enemigo		;7440   ; mover
	call le_dan_los_disparos		;7443   ; recibir disparos
	call toca_al_muneco		;7446   ; y tocar al muneco
	pop bc			;7449
	ld de,00020h		;744a
	add ix,de		;744d
	djnz L_743F		;744f
	ret			;7451
toca_al_muneco:
	call tope_de_este_enemigo		;7452
	ret z			;7455   ; ranura vacia
	cp (hl)			;7456   ; o por encima del tope, no toca
	ret nc			;7457
	ld a,(ix+001h)		;7458
	and 00fh		;745b
	cp 007h		;745d   ; el tipo 7 solo toca a partir del estado 4
	jr nz,L_7467		;745f
	ld a,(ix+000h)		;7461
	cp 004h		;7464
	ret nc			;7466
L_7467:
	ld iy,0e600h		;7467
	call toca_el_bicho_al_muneco		;746b   ; mira si las cajas se cruzan
	ret c			;746e
	ld iy,0e600h		;746f
	ld a,(iy+000h)		;7473
	cp 002h		;7476   ; muriendose ya, no
	ret nc			;7478
	ld a,(iy+00ch)		;7479   ; con la animacion 0 o 1 el muneco muere
	cp 002h		;747c
	jr c,L_7484		;747e
	ret z			;7480
	jp mata_a_este_enemigo		;7481   ; y con la 3 solo empuja
L_7484:
	call mata_al_muneco		;7484
	jp pon_al_enemigo_a_morir		;7487
tope_de_este_enemigo:
	ld a,(ix+001h)		;748a
	and 00fh		;748d
	ld hl,075aah		;748f   ; la tabla de topes de 0x75AA, por tipo
	call suma_a_a_hl		;7492
	ld a,(ix+000h)		;7495
	and a			;7498
	ret			;7499
le_dan_los_disparos:
	call tope_de_este_enemigo		;749a
	ret z			;749d
	cp (hl)			;749e
	ret nc			;749f
	ld a,(ix+001h)		;74a0   ; el tipo decide a partir de que estado se le puede dar
	and 00fh		;74a3
	jr nz,L_74B8		;74a5
	ld a,(0e663h)		;74a7   ; el tipo 0 solo entre el estado 3 y el 4, y sin jefe
	and a			;74aa
	jr nz,L_74E4		;74ab
	ld a,(ix+000h)		;74ad
	cp 003h		;74b0
	ret c			;74b2
	cp 005h		;74b3
	ret nc			;74b5
	jr L_74E4		;74b6
L_74B8:
	cp 00fh		;74b8   ; el 15, del 3 al 4
	jr nz,L_74C8		;74ba
	ld a,(ix+000h)		;74bc
	cp 003h		;74bf
	jr c,L_74C8		;74c1
	cp 005h		;74c3
	ret nz			;74c5
	jr L_74E4		;74c6
L_74C8:
	cp 007h		;74c8   ; el 7, por debajo del 4
	jr nz,L_74D4		;74ca
	ld a,(ix+000h)		;74cc
	cp 004h		;74cf
	ret nc			;74d1
	jr L_74E4		;74d2
L_74D4:
	cp 00ch		;74d4   ; y el 12, por debajo del 3 y sin jefe
	jr nz,L_74E4		;74d6
	ld a,(0e663h)		;74d8
	and a			;74db
	jr nz,L_74E4		;74dc
	ld a,(ix+000h)		;74de
	cp 003h		;74e1
	ret nc			;74e3
L_74E4:
	ld hl,0e620h		;74e4   ; las tres ranuras de disparo, una a una
	ld a,(hl)			;74e7
	rla			;74e8
	jr c,L_74F3		;74e9
	call toca_el_disparo_al_bicho		;74eb
	ld hl,0e625h		;74ee
	jr nc,L_750F		;74f1
L_74F3:
	ld hl,0e630h		;74f3
	ld a,(hl)			;74f6   ; la segunda ranura de disparo
	rla			;74f7
	jr c,L_7502		;74f8
	call toca_el_disparo_al_bicho		;74fa
	ld hl,0e635h		;74fd
	jr nc,L_750F		;7500
L_7502:
	ld hl,0e640h		;7502
	ld a,(hl)			;7505   ; y la tercera
	rla			;7506
	ret c			;7507
	call toca_el_disparo_al_bicho		;7508
	ld hl,0e645h		;750b
	ret c			;750e
L_750F:
	ld a,(hl)			;750f   ; el arma partida por dos
	srl a		;7510
	ld b,a			;7512
	cp 003h		;7513   ; las armas 0, 1 y 2 gastan el disparo
	jr nc,L_751E		;7515
	dec l			;7517
	dec l			;7518
	dec l			;7519
	dec l			;751a
	dec l			;751b
	set 7,(hl)		;751c
L_751E:
	ld a,(ix+001h)		;751e   ; el tipo 15 se queda en el estado 3
	and 00fh		;7521
	cp 00fh		;7523   ; el tipo 15
	jr nz,L_753D		;7525
	ld a,(ix+000h)		;7527
	cp 003h		;752a
	jr nc,L_753D		;752c
	ld a,(0e663h)		;752e   ; y sin jefe sonando
	and a			;7531
	jr nz,L_753D		;7532
	ld (ix+000h),003h		;7534
	ld a,00ah		;7538
	jp pide_pieza		;753a
L_753D:
	cp 007h		;753d   ; el 7 aguanta (ix+0x14) impactos
	jr nz,L_7555		;753f
	dec (ix+014h)		;7541
	jr z,L_7555		;7544
	ld a,(0e663h)		;7546
	and a			;7549
	jr nz,L_7555		;754a
	ld (ix+000h),004h		;754c
	ld a,00ah		;7550
	jp pide_pieza		;7552
L_7555:
	cp 00ch		;7555   ; el tipo 12 se queda en el estado 3
	jr nz,L_7568		;7557
	ld a,(0e663h)		;7559
	and a			;755c
	jr nz,L_7568		;755d
	ld (ix+000h),003h		;755f
	ld a,04dh		;7563
	jp pide_pieza_si_la_escena_lo_permite		;7565
L_7568:
	ld a,b			;7568   ; y las armas 0, 1 y 2 gastan (ix+0x0B) impactos
	cp 003h		;7569
	jr nc,mata_a_este_enemigo		;756b
	dec (ix+00bh)		;756d
	ret nz			;7570
mata_a_este_enemigo:
	ld c,000h		;7571
	ld a,(0e663h)		;7573   ; con jefe sonando valen los puntos de la segunda mitad de la tabla
	and a			;7576
	jr z,L_757B		;7577
mata_a_este_enemigo_del_jefe:
	ld c,010h		;7579
L_757B:
	ld hl,075bah		;757b   ; la tabla de puntos de 0x75BA, por tipo
	ld a,(ix+001h)		;757e
	and 00fh		;7581
	add a,c			;7583
	call suma_a_a_hl		;7584
	ld l,(hl)			;7587
	ld h,000h		;7588
	add hl,hl			;758a   ; por dieciseis: los puntos de verdad
	add hl,hl			;758b
	add hl,hl			;758c
	add hl,hl			;758d
	ex de,hl			;758e
	call suma_puntos_bc		;758f   ; sumados al marcador
pon_al_enemigo_a_morir:
	ld a,(ix+001h)		;7592
	and 00fh		;7595
	ld hl,075aah		;7597   ; el tope de su tipo es tambien su estado de muerte
	call suma_a_a_hl		;759a
	ld a,(hl)			;759d
	ld (ix+000h),a		;759e
	ld (ix+00eh),006h		;75a1   ; seis cuadros de agonia
	ld a,04dh		;75a5   ; y su sonido
	jp pide_pieza_si_la_escena_lo_permite		;75a7

; ----------------------------------------------------------------------
; DATOS cuatro_tramos_de_0x6932: Los leen 0x6932, 0x748F, 0x757B y 0x7597
;   0x75aa..0x75da  (48 bytes)
DATA_cuatro_tramos_de_0x6932:
	defb 006h,003h,003h,004h,004h,007h,003h,008h,004h,004h,005h,003h,005h,004h,003h,006h	; 75aa  ................
	defb 010h,005h,005h,005h,005h,020h,005h,020h,010h,010h,010h,030h,000h,020h,001h,010h	; 75ba  ..... . ...0. ..
	defb 020h,010h,010h,010h,010h,040h,010h,040h,020h,020h,020h,050h,020h,040h,005h,020h	; 75ca   ....@.@   P @. 

; ======================================================================
; CODIGO 0x75da..0x75f3  (25 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; MOVER UN ENEMIGO. El despacho es de DOS niveles: el tipo elige una de
; las dieciseis subtablas de 0x75F3 y el estado, la entrada dentro.
; ----------------------------------------------------------------------
mueve_un_enemigo:
	ld a,(0e663h)		;75da
	and a			;75dd   ; sin jefe, todos se mueven
	jr z,L_75E5		;75de
	call tope_de_este_enemigo		;75e0   ; y con jefe, solo los que ya pasaron su tope
	cp (hl)			;75e3
	ret c			;75e4
L_75E5:
	ld a,(ix+001h)		;75e5
	and 00fh		;75e8   ; el tipo
L_75EA:
	ld hl,075f3h		;75ea   ; su subtabla
	call palabra_de_tabla_en_hl		;75ed
	jp reparte_por_ix		;75f0   ; y el estado, menos uno, elige dentro

; ----------------------------------------------------------------------
; DATOS tabla_de_tablas_del_despacho: Dieciseis punteros a subtablas; 0x75F0
;   la indexa con (ix+1) & 0x0F y deja la subtabla en HL para que 0x4065 la
;   indexe con (ix+0) - 1
;   0x75f3..0x7613  (32 bytes)
DATA_tabla_de_tablas_del_despacho:
	defw 07bb5h,07953h,07a75h,07ac4h,07c25h,07cf5h,07d8dh,07dafh	; 75f3
	defw 07b28h,07eabh,07f1dh,07fd9h,08004h,0809ch,08108h,08127h	; 7603

; ======================================================================
; CODIGO 0x7613..0x76bd  (170 bytes)
; ======================================================================


L_7613:
	ld hl,0e103h		;7613
	ld b,007h		;7616
L_7618:
	ld (hl),0e0h		;7618
	ld a,020h		;761a
	call suma_a_a_hl		;761c
	djnz L_7618		;761f
	ret			;7621
hay_alguna_ranura_de_disparo_libre:
	ld b,004h		;7622
	ld hl,0e620h		;7624
L_7627:
	ld a,(hl)			;7627
	rla			;7628   ; el bit 7 dice que esta libre
	ret nc			;7629
	ld a,010h		;762a
	call suma_a_a_hl		;762c
	djnz L_7627		;762f
	scf			;7631   ; sin ninguna, sale con acarreo
	ret			;7632
dispara_el_enemigo:
	ld a,(ix+003h)		;7633
	cp 0c0h		;7636   ; por debajo de la columna 0xC0 no dispara
	ret nc			;7638
	ld a,(ix+001h)		;7639
	and 00fh		;763c
	ld c,a			;763e
	ld hl,076edh		;763f   ; cuantos disparos suelta, de la tabla de 0x76ED
	call suma_a_a_hl		;7642
	ld b,(hl)			;7645
	ld a,(0e061h)		;7646   ; en las tres primeras fases, uno menos
	dec a			;7649
	and 00fh		;764a
	cp 003h		;764c
	jr nc,L_7651		;764e
	dec b			;7650
L_7651:
	ld a,c			;7651
	ld hl,076cdh		;7652   ; y el reparto de angulos, de la de 0x76CD
	call palabra_de_tabla_en_hl		;7655
	ld a,(0e061h)		;7658
	dec a			;765b
	and 00fh		;765c
	cp 003h		;765e
	ld a,(ix+00fh)		;7660   ; el contador de disparos de este enemigo
	jr nc,L_7668		;7663
	cp 0ffh		;7665
	ret z			;7667
L_7668:
	inc a			;7668
	ld (ix+00fh),a		;7669
L_766C:
	cp (hl)			;766c   ; solo dispara en los cuadros que dice su tira de angulos
	jr z,L_7673		;766d
	inc hl			;766f
	djnz L_766C		;7670
	ret			;7672
L_7673:
	ld a,(0e602h)		;7673   ; y solo si el muneco esta a mas de 0x18 en horizontal...
	add a,008h		;7676
	sub (ix+003h)		;7678
	jr nc,L_767F		;767b
	neg		;767d
L_767F:
	cp 018h		;767f
	ret c			;7681
	ld a,(0e604h)		;7682   ; ...y a mas de 0x18 en vertical: de cerca no dispara
	add a,008h		;7685
	sub (ix+005h)		;7687
	jr nc,L_768E		;768a
	neg		;768c
L_768E:
	cp 018h		;768e
	ret c			;7690
	ld b,(ix+001h)		;7691
	ld a,(0e068h)		;7694   ; con (0xE068) puesto disparan todos
	and a			;7697
	jr nz,L_76AE		;7698
	ld a,(0e062h)		;769a   ; en las cuatro primeras fases, solo los que llevan el bit 7 del tipo
	cp 004h		;769d
	jr nc,L_76AE		;769f
	ld a,b			;76a1
	rla			;76a2
	ret nc			;76a3
	ld a,(ix+011h)		;76a4   ; y de esos, uno de cada dos de la formacion
	cp 0ffh		;76a7
	jr z,L_76AE		;76a9
	and 001h		;76ab
	ret nz			;76ad
L_76AE:
	ld a,b			;76ae
	and 00fh		;76af
	ld hl,076bdh		;76b1   ; cuantos disparos suelta, de la tabla de 0x76BD
	call suma_a_a_hl		;76b4
	ld c,004h		;76b7   ; y el tipo de disparo, el 4
	ld b,(hl)			;76b9
	jp suelta_una_rafaga		;76ba

; ----------------------------------------------------------------------
; DATOS tres_tramos_de_0x76B1: 0x76B1 indexa el primero con cuatro bits; los
;   otros dos los leen 0x7652 y 0x763F
;   0x76bd..0x772a  (109 bytes)
DATA_tres_tramos_de_0x76B1:
	defb 005h,002h,002h,002h,003h,004h,007h,006h,003h,001h,003h,003h,001h,004h,003h,003h	; 76bd  ................
	defb 0fdh,076h,0fdh,076h,000h,077h,003h,077h,006h,077h,009h,077h,00ch,077h,00fh,077h	; 76cd  .v.v.w.w.w.w.w.w
	defb 012h,077h,015h,077h,018h,077h,01bh,077h,0fdh,076h,01eh,077h,021h,077h,026h,077h	; 76dd  .w.w.w.w.v.w!w&w
	defb 003h,003h,003h,003h,003h,003h,003h,003h,003h,003h,003h,003h,003h,003h,005h,004h	; 76ed  ................
	defb 010h,050h,090h,010h,028h,048h,030h,008h,050h,00bh,028h,048h,010h,060h,0b0h,050h	; 76fd  .P..(H0.P.(H.`.P
	defb 0a0h,0f0h,018h,070h,0c0h,010h,038h,090h,018h,060h,0a8h,020h,050h,080h,002h,00ch	; 770d  ...p..8..`. P...
	defb 017h,010h,050h,090h,010h,030h,050h,070h,090h,010h,030h,050h,070h	; 771d  ..P..0Pp..0Pp

; ======================================================================
; CODIGO 0x772a..0x7772  (72 bytes)
; ======================================================================


L_772A:
	ld ix,0e100h		;772a
	ld hl,0e320h		;772e
	ld b,007h		;7731
L_7733:
	push bc			;7733
	ld a,(ix+00ah)		;7734
	ld b,h			;7737   ; se guarda donde va la sombra de atributos
	ld c,l			;7738
	add a,a			;7739
	ld hl,07772h		;773a   ; el bloque de dos sprites de este enemigo
	call suma_a_a_hl		;773d
	ld e,(hl)			;7740
	inc hl			;7741
	ld d,(hl)			;7742
	ld h,b			;7743
	ld l,c			;7744
	ld b,002h		;7745
L_7747:
	ld a,(de)			;7747   ; la fila del enemigo mas el desplazamiento
	add a,(ix+003h)		;7748
	ld (hl),a			;774b
	inc l			;774c
	inc de			;774d
	ld a,(de)			;774e   ; y la columna
	add a,(ix+005h)		;774f
	ld (hl),a			;7752
	inc de			;7753
	inc l			;7754
	ld a,(ix+00ah)		;7755
	cp 005h		;7758
	ld a,(de)			;775a
	jr c,L_7760		;775b
	add a,(ix+016h)		;775d
L_7760:
	ld (hl),a			;7760   ; el patron
	inc de			;7761
	inc l			;7762
	ld a,(de)			;7763   ; y el color
	ld (hl),a			;7764
	inc de			;7765
	inc l			;7766
	djnz L_7747		;7767
	pop bc			;7769
	ld de,00020h		;776a
	add ix,de		;776d
	djnz L_7733		;776f
	ret			;7771

; ----------------------------------------------------------------------
; DATOS tabla_de_sprites_de_enemigo: 38 punteros a bloques de ocho bytes;
;   0x773A indexa con (ix+0x0A). Cierran solos: el mas bajo, 0x77BE, esta a 76
;   bytes del principio
;   0x7772..0x77be  (76 bytes)
DATA_tabla_de_sprites_de_enemigo:
	defw 077d2h,077beh,077c6h,077ceh,077d6h,077deh,077e6h,077eeh	; 7772
	defw 077f6h,077feh,07806h,0780eh,07816h,0781eh,07826h,0782eh	; 7782
	defw 07836h,0783eh,07846h,0784eh,07856h,0785eh,07866h,0786eh	; 7792
	defw 07876h,0787eh,07886h,0788eh,07896h,0789eh,078a6h,078aeh	; 77a2
	defw 078b6h,078beh,078c6h,078ceh,078d6h,078deh	; 77b2

; ----------------------------------------------------------------------
; DATOS sprites_de_los_enemigos: 38 bloques de ocho bytes: dos sprites de
;   [dy][dx][patron][color] que se suman a la posicion del enemigo. A las
;   entradas 0 a 4 el patron les va absoluto; de la 5 en adelante -0x7755 hace
;   `cp 005h` y `jr c`- al patron se le suma ademas (ix+0x16), que es el
;   patron base de la ranura en la que se ha cargado ese enemigo. Cual es el
;   bloque de cada entrada lo dice el TIPO, que manda las dos cosas: 0x7914 lo
;   usa (nibble bajo) para elegir el bloque de 0xA993 y 0x75E5 para elegir la
;   subtabla de 0x75F3 cuyas rutinas escriben (ix+0x0A). Atadas las dos puntas
;   cuadra solo: los patrones que piden las entradas de cada tipo son
;   exactamente los que trae su bloque, ni uno de mas ni uno de menos, en los
;   dieciseis (test propio)
;   0x77be..0x78e6  (296 bytes)
DATA_sprites_de_los_enemigos:
	defb 0fdh,0fch,044h,00ah	; 77be
	defb 0f8h,0f8h,048h,006h	; 77c2
	defb 000h,0fch,04ch,00ah	; 77c6
	defb 0f8h,0fah,050h,006h	; 77ca
	defb 0f8h,0fch,054h,006h	; 77ce
	defb 000h,000h,000h,000h	; 77d2
	defb 000h,000h,000h,000h	; 77d6
	defb 0f8h,0f8h,03ch,00fh	; 77da
	defb 0f8h,0f8h,000h,00ah	; 77de
	defb 00ah,0f8h,004h,001h	; 77e2
	defb 0f8h,0f8h,008h,00fh	; 77e6
	defb 009h,0f8h,00ch,001h	; 77ea
	defb 0f8h,0f8h,000h,001h	; 77ee
	defb 0fbh,0fch,004h,00fh	; 77f2
	defb 0f8h,0f8h,010h,001h	; 77f6
	defb 0fbh,0f4h,014h,00fh	; 77fa
	defb 0f8h,0f8h,000h,001h	; 77fe
	defb 00ch,0f8h,008h,001h	; 7802
	defb 0f8h,0f8h,004h,001h	; 7806
	defb 00ch,0f8h,008h,001h	; 780a
	defb 0f8h,0f8h,000h,007h	; 780e
	defb 00eh,0f8h,008h,001h	; 7812
	defb 0f8h,0f8h,004h,007h	; 7816
	defb 00eh,0f8h,008h,001h	; 781a
	defb 0f8h,0f8h,000h,001h	; 781e
	defb 0fah,0fch,004h,00bh	; 7822
	defb 0f8h,0f8h,010h,001h	; 7826
	defb 0fah,0f4h,014h,00bh	; 782a
	defb 0f8h,0f8h,000h,001h	; 782e
	defb 0feh,0fch,004h,00fh	; 7832
	defb 0f9h,0f8h,010h,001h	; 7836
	defb 0ffh,0f4h,014h,00fh	; 783a
	defb 0f8h,0f8h,000h,00fh	; 783e
	defb 0f8h,0f8h,004h,001h	; 7842
	defb 0f9h,0f8h,010h,00fh	; 7846
	defb 0f9h,0f8h,014h,001h	; 784a
	defb 0f0h,0f0h,008h,00fh	; 784e
	defb 0f0h,000h,00ch,00fh	; 7852
	defb 0f0h,0e8h,008h,00fh	; 7856
	defb 0f0h,008h,00ch,00fh	; 785a
	defb 0f8h,0e0h,008h,00fh	; 785e
	defb 0f8h,010h,00ch,00fh	; 7862
	defb 0f8h,0f8h,000h,00fh	; 7866
	defb 00eh,0f8h,004h,001h	; 786a
	defb 0f8h,0f8h,010h,00fh	; 786e
	defb 00eh,0f8h,014h,001h	; 7872
	defb 0f8h,0f8h,000h,005h	; 7876
	defb 0f8h,0f8h,004h,001h	; 787a
	defb 0f9h,0f8h,010h,005h	; 787e
	defb 0f9h,0f8h,014h,001h	; 7882
	defb 0f8h,0f8h,000h,006h	; 7886
	defb 00ch,0f8h,008h,001h	; 788a
	defb 0f8h,0f8h,004h,006h	; 788e
	defb 00ch,0f8h,008h,001h	; 7892
	defb 0f8h,0f8h,000h,00fh	; 7896
	defb 009h,0f8h,008h,001h	; 789a
	defb 0f8h,0f8h,004h,00fh	; 789e
	defb 009h,0f8h,008h,001h	; 78a2
	defb 0f8h,0f8h,000h,001h	; 78a6
	defb 0fah,0fch,004h,008h	; 78aa
	defb 0f8h,0f8h,010h,001h	; 78ae
	defb 0fah,0f4h,014h,008h	; 78b2
	defb 0f8h,0f8h,000h,001h	; 78b6
	defb 0fch,0fbh,008h,00fh	; 78ba
	defb 0f8h,0f8h,004h,001h	; 78be
	defb 0fbh,0fch,008h,00fh	; 78c2
	defb 0f8h,0f8h,000h,006h	; 78c6
	defb 0f8h,0f8h,004h,001h	; 78ca
	defb 0f9h,0f8h,010h,006h	; 78ce
	defb 0f9h,0f8h,014h,001h	; 78d2
	defb 0f8h,0f8h,008h,006h	; 78d6
	defb 0f8h,0f8h,00ch,001h	; 78da
	defb 0f9h,0f8h,018h,006h	; 78de
	defb 0f9h,0f8h,01ch,001h	; 78e2

; ======================================================================
; CODIGO 0x78e6..0x7944  (94 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; RECARGAR LOS PATRONES DE UN ENEMIGO. La hoja de sprites no tiene sitio
; para todos, asi que hay TRES ranuras de cuatro patrones -0x1D00, 0x1E00
; y 0x1F00- que se van reutilizando por turno. Cada ranura de generador
; que pide patrones se lleva la siguiente, y con ella el patron base que
; luego se le suma a cada sprite.
; ----------------------------------------------------------------------
recarga_los_patrones_de_los_generadores:
	ld iy,0e0a0h		;78e6
	ld b,002h		;78ea
L_78EC:
	push bc			;78ec
	call recarga_los_patrones_de_una_ranura		;78ed   ; cada ranura pide lo suyo
	pop bc			;78f0
	ld de,00010h		;78f1
	add iy,de		;78f4
	djnz L_78EC		;78f6
	ret			;78f8
recarga_los_patrones_de_una_ranura:
	ld a,(iy+008h)		;78f9   ; con (iy+8) a cero no ha pedido nada
	and a			;78fc
	ret z			;78fd
	ld (iy+008h),000h		;78fe   ; pedido atendido
	ld a,(0e1f1h)		;7902   ; la ranura que toca, de 0 a 2
	ld hl,07950h		;7905   ; su patron base: 0xA0, 0xC0 o 0xE0
	call suma_a_a_hl		;7908
	ld a,(hl)			;790b
	ld (iy+007h),a		;790c   ; guardado para el que lo pinte
	ld a,(iy+000h)		;790f
	and 00fh		;7912
	ld hl,0a993h		;7914   ; los cuatro patrones de este tipo de bicho, del banco de 0xA993
	call palabra_de_tabla_doble		;7917
	push de			;791a
	ld hl,07944h		;791b   ; la direccion de VRAM de la ranura
	ld a,(0e1f1h)		;791e
	call palabra_de_tabla_en_hl		;7921
	pop de			;7924
	push hl			;7925
	call descomprime		;7926   ; descomprimidos
	ld hl,0794ah		;7929   ; y la copia espejada, 0x90 mas alla
	ld a,(0e1f1h)		;792c
	call palabra_de_tabla_doble		;792f
	pop hl			;7932
	ld c,004h		;7933
	call espeja_sprites		;7935
	ld hl,0e1f1h		;7938   ; y la ranura siguiente, dando la vuelta a las tres
	ld a,(hl)			;793b
	inc a			;793c
	cp 003h		;793d
	jr c,L_7942		;793f
	xor a			;7941
L_7942:
	ld (hl),a			;7942
	ret			;7943

; ----------------------------------------------------------------------
; DATOS ranuras_de_enemigo: Las tres direcciones de VRAM donde 0x7926
;   descomprime los patrones: 0x1D00, 0x1E00 y 0x1F00. Cada ranura son OCHO
;   patrones: cuatro tal cual y cuatro espejados 0x80 mas alla, que es donde
;   acaba escribiendo `espeja_un_sprite` aunque la tabla de al lado diga
;   0x1D90 -esa rutina arranca en destino+0x10 porque ademas de dar la vuelta
;   a los bits INTERCAMBIA las dos mitades del sprite-
;   0x7944..0x794a  (6 bytes)
DATA_ranuras_de_enemigo:
	defw 01d00h,01e00h,01f00h	; 7944

; ----------------------------------------------------------------------
; DATOS espejos_de_las_ranuras: Y donde 0x7935 deja la copia espejada: 0x90
;   mas alla de cada una
;   0x794a..0x7950  (6 bytes)
DATA_espejos_de_las_ranuras:
	defw 01d90h,01e90h,01f90h	; 794a

; ----------------------------------------------------------------------
; DATOS patrones_base_de_las_ranuras: 0xA0, 0xC0 y 0xE0, que son 0x1D00,
;   0x1E00 y 0x1F00 contados en numero de patron. Es lo que 0x790C guarda en
;   (iy+7) y acaba sumandose en 0x775D
;   0x7950..0x7953  (3 bytes)
DATA_patrones_base_de_las_ranuras:
	defb 0a0h,0c0h,0e0h	; 7950

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_7953: 6 entradas; subtabla  1 de 0x75F3
;   0x7953..0x795f  (12 bytes)
DATA_tabla_de_reparto_7953:
	defw 0795fh,0799dh,07c74h,07c8ah,07ca0h,07cefh	; 7953

; ======================================================================
; CODIGO 0x795f..0x7991  (50 bytes)
; ======================================================================


bicho_01_arranca:
	call limpia_el_bicho		;795f
	ld (ix+006h),030h		;7962   ; su velocidad
	ld (ix+007h),001h		;7966
	ld (ix+00ah),009h		;796a   ; su sprite, el 9
	ld (ix+00dh),080h		;796e
	ld b,006h		;7972
	ld hl,07991h		;7974   ; mira si su columna es una de las seis de 0x7991
	ld a,(ix+005h)		;7977
L_797A:
	cp (hl)			;797a
	jr z,L_7981		;797b
	inc hl			;797d
	djnz L_797A		;797e
	ret			;7980
L_7981:
	ld a,006h		;7981
	sub b			;7983
	ld hl,07997h		;7984   ; y le pone el desvio que le toque, de la tira de 0x7997
	call suma_a_a_hl		;7987
	ld a,(hl)			;798a
	ld (ix+009h),a		;798b
	jp sube_de_estado		;798e

; ----------------------------------------------------------------------
; DATOS dos_tramos_de_0x7974: Los leen 0x7974 y 0x7984
;   0x7991..0x799d  (12 bytes)
DATA_dos_tramos_de_0x7974:
	defb 028h,050h,07fh,080h,0b0h,0d8h	; 7991
	defb 000h,005h,0fah,006h,0fbh,0ffh	; 7997

; ======================================================================
; CODIGO 0x799d..0x7a75  (216 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LOS RECORRIDOS. Cada bicho lleva en (ix+6..9) su velocidad en 8.8 y en
; (ix+3),(ix+5) su posicion; el paso de cada cuadro es sumarle una a la
; otra. Los tirones de 0x7A0C y 0x7A32 lo curvan hacia (ix+0x0C),(ix+0x0D),
; que es a donde va.
; ----------------------------------------------------------------------
bicho_01_persigue:
	ld c,000h		;799d
persigue_en_vertical:
	call tira_hacia_la_fila_c		;799f
mueve_y_suena:
	call suena_el_aleteo		;79a2
mueve_y_dispara:
	call dispara_el_enemigo		;79a5
mueve_al_bicho:
	push ix		;79a8
L_79AA:
	pop hl			;79aa
	inc l			;79ab   ; apunta a la posicion
	inc l			;79ac
	ld d,h			;79ad
	ld e,l			;79ae
	inc e			;79af   ; y cuatro mas alla, a la velocidad
	inc e			;79b0
	inc e			;79b1
	inc e			;79b2
	ld a,(de)			;79b3   ; la fraccion de la vertical
	add a,(hl)			;79b4
	ld (hl),a			;79b5
	inc l			;79b6
	inc e			;79b7
	ld a,(de)			;79b8   ; y la parte entera, con acarreo
	adc a,(hl)			;79b9
	ld (hl),a			;79ba
	cp 0a8h		;79bb   ; entre 0xA8 y 0xE8 esta fuera de pantalla por abajo: se apaga
	jr c,L_79C3		;79bd
	cp 0e8h		;79bf
	jr c,L_79D4		;79c1
L_79C3:
	inc l			;79c3   ; lo mismo con la horizontal
	inc e			;79c4
	ld a,(de)			;79c5
	add a,(hl)			;79c6
	ld (hl),a			;79c7
	inc l			;79c8
	inc e			;79c9
	ld a,(de)			;79ca
	adc a,(hl)			;79cb
	ld (hl),a			;79cc
	sub 008h		;79cd   ; y por los lados, tambien
	cp 0f0h		;79cf
	ret c			;79d1
	dec l			;79d2
	dec l			;79d3
L_79D4:
	ld (hl),0e0h		;79d4   ; fila 0xE0: aparcado
	dec l			;79d6
	dec l			;79d7
	dec l			;79d8
	ld (hl),000h		;79d9   ; y la ranura, libre
	ret			;79db
suena_el_aleteo:
	ld a,(0e02eh)		;79dc   ; solo si no suena ya otra cosa en esa voz
	and a			;79df
	jr nz,L_79F8		;79e0
	ld a,(ix+010h)		;79e2
	bit 0,a		;79e5   ; alterna entre dos sonidos
	ld a,041h		;79e7
	jr z,L_79ED		;79e9
	ld a,002h		;79eb
L_79ED:
	call pide_pieza		;79ed
	ld a,(ix+010h)		;79f0
	xor 001h		;79f3
	ld (ix+010h),a		;79f5
L_79F8:
	ld b,009h		;79f8   ; y entre dos sprites, cada ocho cuadros
L_79FA:
	ld a,(0e003h)		;79fa
	bit 3,a		;79fd
	jr z,L_7A02		;79ff
	inc b			;7a01
L_7A02:
	ld (ix+00ah),b		;7a02
	ret			;7a05
tira_hacia_la_fila:
	ld c,000h		;7a06
	jr tira_hacia_la_fila_c		;7a08
tira_hacia_la_fila_a_la_mitad:
	ld c,001h		;7a0a
tira_hacia_la_fila_c:
	ld a,(ix+005h)		;7a0c   ; lo que le falta para llegar
	sub (ix+00dh)		;7a0f
	ld e,a			;7a12
	ld d,000h		;7a13
	add a,a			;7a15   ; con signo
	jr nc,L_7A19		;7a16
	dec d			;7a18
L_7A19:
	ld a,c			;7a19
	and a			;7a1a
	jr z,L_7A22		;7a1b
L_7A1D:
	sra e		;7a1d   ; partido por dos tantas veces como diga C
	dec a			;7a1f
	jr nz,L_7A1D		;7a20
L_7A22:
	ld l,(ix+008h)		;7a22   ; y se le resta a la velocidad vertical: eso es la curva
	ld h,(ix+009h)		;7a25
	and a			;7a28
	sbc hl,de		;7a29
	ld (ix+008h),l		;7a2b
	ld (ix+009h),h		;7a2e
	ret			;7a31
tira_hacia_la_columna:
	ld c,000h		;7a32
	jr tira_hacia_la_columna_c		;7a34
tira_hacia_la_columna_a_la_mitad:
	ld c,001h		;7a36
tira_hacia_la_columna_c:
	ld a,(ix+003h)		;7a38   ; igual, pero con la columna
	sub (ix+00ch)		;7a3b
	ld e,a			;7a3e
	ld d,000h		;7a3f
	add a,a			;7a41
	jr nc,L_7A45		;7a42
	dec d			;7a44
L_7A45:
	ld a,c			;7a45
	and a			;7a46
	jr z,L_7A4E		;7a47
L_7A49:
	sra e		;7a49
	dec a			;7a4b
	jr nz,L_7A49		;7a4c
L_7A4E:
	ld l,(ix+006h)		;7a4e   ; la velocidad horizontal
	ld h,(ix+007h)		;7a51
	and a			;7a54
	sbc hl,de		;7a55   ; menos el tiron
	ld (ix+006h),l		;7a57
	ld (ix+007h),h		;7a5a
	ret			;7a5d
limpia_el_bicho:
	push ix		;7a5e
	pop hl			;7a60
	ld a,006h		;7a61   ; desde (ix+6)
	call suma_a_a_hl		;7a63
	ld d,h			;7a66
	ld e,l			;7a67
	inc de			;7a68
	ld bc,00009h		;7a69   ; nueve bytes a cero
	ld (hl),000h		;7a6c
	ldir		;7a6e
	ld (ix+00bh),001h		;7a70   ; y al estado 1
	ret			;7a74

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_7A75: 6 entradas; subtabla  2 de 0x75F3
;   0x7a75..0x7a81  (12 bytes)
DATA_tabla_de_reparto_7A75:
	defw 07a81h,07abfh,07c74h,07c8ah,07ca0h,07cefh	; 7a75

; ======================================================================
; CODIGO 0x7a81..0x7ac4  (67 bytes)
; ======================================================================


bicho_02_arranca:
	call limpia_el_bicho		;7a81
	ld (ix+007h),002h		;7a84
	ld (ix+00ah),009h		;7a88
	ld a,(0e604h)		;7a8c   ; la columna del muneco
	ld c,a			;7a8f
	ld a,(ix+011h)		;7a90
	cp 0ffh		;7a93   ; los que no van en formacion, la miran directamente
	jr z,L_7AA0		;7a95
	and 00fh		;7a97
	ld hl,0e1f0h		;7a99   ; y los de formacion se quedan con la del primero, en (0xE1F0)
	jr nz,L_7A9F		;7a9c
	ld (hl),c			;7a9e
L_7A9F:
	ld c,(hl)			;7a9f
L_7AA0:
	ld a,c			;7aa0
	cp 080h		;7aa1   ; a la derecha del centro entra por un lado...
	ld bc,00380h		;7aa3
	ld de,02010h		;7aa6
	jr nc,L_7AB1		;7aa9
	ld bc,0fc80h		;7aab   ; ...y a la izquierda por el otro
	ld de,0e0f0h		;7aae
L_7AB1:
	ld (ix+008h),c		;7ab1   ; con su velocidad y su destino
	ld (ix+009h),b		;7ab4
	ld (ix+00dh),d		;7ab7
	ld (ix+005h),e		;7aba
	jr $+65		;7abd
bicho_02_persigue:
	ld c,001h		;7abf
	jp persigue_en_vertical		;7ac1

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_7AC4: 7 entradas; subtabla  3 de 0x75F3
;   0x7ac4..0x7ad2  (14 bytes)
DATA_tabla_de_reparto_7AC4:
	defw 07ad2h,07b07h,07b20h,07c74h,07c8ah,07ca0h,07cefh	; 7ac4

; ======================================================================
; CODIGO 0x7ad2..0x7b28  (86 bytes)
; ======================================================================


bicho_03_arranca:
	call limpia_el_bicho		;7ad2
	ld (ix+006h),0c0h		;7ad5   ; sube despacio
	ld (ix+007h),0ffh		;7ad9
	ld (ix+00ah),009h		;7add
	ld (ix+00ch),030h		;7ae1   ; y va hacia la fila 0x30, columna 0x80: el centro de arriba
	ld (ix+00dh),080h		;7ae5
	ld a,(ix+005h)		;7ae9
	cp 080h		;7aec   ; segun por que lado entre, se le da un empujon u otro
	ld b,003h		;7aee
	ld c,010h		;7af0
	jr c,L_7AF8		;7af2
	ld b,0fdh		;7af4
	ld c,0f0h		;7af6
L_7AF8:
	ld (ix+009h),b		;7af8
	ld (ix+005h),c		;7afb
sube_de_estado:
	ld a,(ix+000h)		;7afe   ; con el estado a cero no hay bicho
	and a			;7b01
	ret z			;7b02
	inc (ix+000h)		;7b03
	ret			;7b06
bicho_03_vuela:
	call mueve_y_suena		;7b07
	ld a,(ix+005h)		;7b0a   ; cuando llega al centro...
	sub 080h		;7b0d
	jr nc,L_7B13		;7b0f
	neg		;7b11
L_7B13:
	cp 005h		;7b13   ; ...a menos de cinco...
	ret nc			;7b15
	ld (ix+006h),000h		;7b16   ; ...se para en seco y cambia de estado
	ld (ix+007h),000h		;7b1a
	jr sube_de_estado		;7b1e
bicho_03_baja:
	call tira_hacia_la_columna_a_la_mitad		;7b20
	ld c,001h		;7b23
	jp persigue_en_vertical		;7b25

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_7B28: 7 entradas; subtabla  8 de 0x75F3
;   0x7b28..0x7b36  (14 bytes)
DATA_tabla_de_reparto_7B28:
	defw 07b36h,07b65h,07b81h,07c74h,07c8ah,07ca0h,07cefh	; 7b28

; ======================================================================
; CODIGO 0x7b36..0x7bb5  (127 bytes)
; ======================================================================


bicho_09_arranca:
	call limpia_el_bicho		;7b36
	ld (ix+006h),030h		;7b39
	ld (ix+007h),001h		;7b3d
	ld (ix+00ah),016h		;7b41   ; su sprite, el 0x16
	ld a,(ix+005h)		;7b45
	cp 080h		;7b48   ; entra por arriba o por abajo segun de donde venga
	ld b,018h		;7b4a
	ld c,003h		;7b4c
	ld d,006h		;7b4e
	jr c,L_7B58		;7b50
	ld b,0e8h		;7b52
	ld c,002h		;7b54
	ld d,0fah		;7b56
L_7B58:
	ld (ix+00dh),b		;7b58
	ld (ix+005h),b		;7b5b
	ld (ix+000h),c		;7b5e
	ld (ix+009h),d		;7b61
	ret			;7b64
bicho_09_baja:
	call bicho_09_se_mueve		;7b65
	ld a,(ix+005h)		;7b68
	cp 0e9h		;7b6b   ; al pasar de la fila 0xE9 da la vuelta
	ret c			;7b6d
	ld (ix+008h),000h		;7b6e
	ld (ix+009h),006h		;7b72
	ld a,018h		;7b76
	ld (ix+005h),a		;7b78
	ld (ix+00dh),a		;7b7b
	jp sube_de_estado		;7b7e
bicho_09_sube:
	call bicho_09_se_mueve		;7b81
	ld a,(ix+005h)		;7b84
	cp 017h		;7b87   ; y al pasar de la 0x17, tambien
	ret nc			;7b89
	ld (ix+008h),000h		;7b8a
	ld (ix+009h),0fah		;7b8e
	ld a,0e8h		;7b92
	ld (ix+005h),a		;7b94
	ld (ix+00dh),a		;7b97
baja_de_estado:
	ld a,(ix+000h)		;7b9a
	and a			;7b9d
	ret z			;7b9e
	dec (ix+000h)		;7b9f
	ret			;7ba2
bicho_09_se_mueve:
	call tira_hacia_la_fila		;7ba3
	ld a,(ix+009h)		;7ba6   ; el signo de la velocidad elige el sprite
	rla			;7ba9
	ld a,016h		;7baa
	jr nc,L_7BAF		;7bac
	inc a			;7bae
L_7BAF:
	ld (ix+00ah),a		;7baf
	jp mueve_y_dispara		;7bb2

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_7BB5: 9 entradas; subtabla  0 de 0x75F3
;   0x7bb5..0x7bc7  (18 bytes)
DATA_tabla_de_reparto_7BB5:
	defw 07bc7h,07be2h,07bffh,07c0ah,079a8h,07c74h,07c8ah,07ca0h	; 7bb5
	defw 07cefh	; 7bc5  -> acaba_de_morirse

; ======================================================================
; CODIGO 0x7bc7..0x7c25  (94 bytes)
; ======================================================================


bicho_00_arranca:
	call limpia_el_bicho		;7bc7
	ld a,(ix+005h)		;7bca   ; por el lado por el que entre
	cp 080h		;7bcd
	ld c,002h		;7bcf
	jr c,L_7BD5		;7bd1
	ld c,0feh		;7bd3
L_7BD5:
	ld (ix+009h),c		;7bd5
	ld (ix+007h),006h		;7bd8
	ld (ix+00ah),006h		;7bdc   ; su sprite, el 6
	jr L_7BFC		;7be0
bicho_00_baja:
	call mueve_al_bicho		;7be2
	ld a,(ix+003h)		;7be5
	cp 008h		;7be8   ; entre la columna 8 y la 0xC0
	ret c			;7bea
	cp 0c0h		;7beb
	ret nc			;7bed
	ld a,(0e602h)		;7bee   ; y a menos de 0x50 del muneco
	sub (ix+003h)		;7bf1
	cp 050h		;7bf4
	ret nc			;7bf6
	ld a,020h		;7bf7   ; se queda 0x20 cuadros en el sitio
L_7BF9:
	ld (ix+00eh),a		;7bf9
L_7BFC:
	jp sube_de_estado		;7bfc
bicho_00_dispara:
	call cuenta_los_cuadros_del_bicho		;7bff
	ret nz			;7c02
	call L_7673		;7c03   ; suelta lo suyo
	ld a,008h		;7c06   ; y ocho cuadros mas
	jr L_7BF9		;7c08
bicho_00_se_va:
	call cuenta_los_cuadros_del_bicho		;7c0a
	ret nz			;7c0d
	ld (ix+006h),000h		;7c0e   ; sube deprisa
	ld (ix+007h),0fah		;7c12
	ld (ix+00ah),006h		;7c16
	jr L_7BFC		;7c1a
cuenta_los_cuadros_del_bicho:
	ld b,007h		;7c1c
	call L_79FA		;7c1e
	dec (ix+00eh)		;7c21
	ret			;7c24

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_7C25: 7 entradas; subtabla  4 de 0x75F3
;   0x7c25..0x7c33  (14 bytes)
DATA_tabla_de_reparto_7C25:
	defw 07c33h,07c44h,07c6fh,07c74h,07c8ah,07ca0h,07cefh	; 7c25

; ======================================================================
; CODIGO 0x7c33..0x7cf5  (194 bytes)
; ======================================================================


bicho_04_arranca:
	call limpia_el_bicho		;7c33
	ld (ix+006h),050h		;7c36
	ld (ix+007h),002h		;7c3a
	ld (ix+00ah),00bh		;7c3e   ; su sprite, el 0x0B
L_7C42:
	jr $-70		;7c42
bicho_04_persigue:
	call bicho_04_se_mueve		;7c44
	ld a,(ix+003h)		;7c47
	cp 008h		;7c4a   ; entre la columna 8 y la 0xC0
	ret c			;7c4c
	cp 0c0h		;7c4d
	ret nc			;7c4f
	ld a,(0e602h)		;7c50   ; y a menos de 0x50 del muneco
	sub (ix+003h)		;7c53
	cp 050h		;7c56
	ret nc			;7c58
	ld a,(0e604h)		;7c59   ; se lanza hacia el, por arriba o por abajo
	cp (ix+005h)		;7c5c
	ld bc,0027fh		;7c5f
	jr nc,L_7C67		;7c62
	ld bc,0fd81h		;7c64
L_7C67:
	ld (ix+008h),c		;7c67
	ld (ix+009h),b		;7c6a
	jr L_7C42		;7c6d
bicho_04_se_mueve:
	ld b,00bh		;7c6f
	jp anima_y_dispara		;7c71

; ----------------------------------------------------------------------
; LOS TRES ESTADOS DE MORIRSE, iguales para todos los bichos: cambian de
; sprite cada dos cuadros y descuentan (ix+0x0E) hasta el siguiente.
; ----------------------------------------------------------------------
muriendose_1:
	ld a,(0e003h)		;7c74
	bit 1,a		;7c77   ; el bit 1 del contador de cuadros alterna los dos sprites
	ld a,001h		;7c79
	jr z,L_7C7E		;7c7b
	inc a			;7c7d
L_7C7E:
	ld (ix+00ah),a		;7c7e
	dec (ix+00eh)		;7c81   ; y la cuenta de la agonia
	ret nz			;7c84
	ld a,006h		;7c85
	jp L_7BF9		;7c87
muriendose_2:
	ld a,(0e003h)		;7c8a
	bit 1,a		;7c8d
	ld a,002h		;7c8f
	jr z,L_7C94		;7c91
	inc a			;7c93
L_7C94:
	ld (ix+00ah),a		;7c94
	dec (ix+00eh)		;7c97
	ret nz			;7c9a
	ld a,006h		;7c9b
	jp L_7BF9		;7c9d
muriendose_3:
	ld a,(0e003h)		;7ca0
	bit 1,a		;7ca3
	ld a,003h		;7ca5
	jr z,L_7CAA		;7ca7
	xor a			;7ca9
L_7CAA:
	ld (ix+00ah),a		;7caa
	dec (ix+00eh)		;7cad
	ret nz			;7cb0
	ld a,(0e600h)		;7cb1
	cp 002h		;7cb4   ; si el muneco esta muriendose, no hay premio
	jr z,borra_al_bicho		;7cb6
	ld a,(ix+001h)		;7cb8
	bit 6,a		;7cbb   ; los de formacion cuentan aparte
	jr z,borra_al_bicho		;7cbd
	ld a,(ix+011h)		;7cbf   ; cual de las cuatro formaciones
	rra			;7cc2
	rra			;7cc3
	rra			;7cc4
	rra			;7cc5
	and 00fh		;7cc6
	ld hl,0e1e4h		;7cc8
	ld c,a			;7ccb
	add a,a			;7ccc
	add a,c			;7ccd
	call suma_a_a_hl		;7cce
	ld a,(hl)			;7cd1
	inc hl			;7cd2
	inc (hl)			;7cd3   ; uno mas caido de esa formacion
	cp (hl)			;7cd4   ; y al caer todos, 0x1000 puntos
	jr nz,borra_al_bicho		;7cd5
	ld de,01000h		;7cd7
	call suma_puntos_bc		;7cda
	ld a,008h		;7cdd
	ld (ix+00ah),004h		;7cdf
	jp L_7BF9		;7ce3
borra_al_bicho:
	ld (ix+000h),000h		;7ce6
	ld (ix+003h),0e0h		;7cea   ; y lo aparca en la fila 0xE0
	ret			;7cee
acaba_de_morirse:
	dec (ix+00eh)		;7cef
	ret nz			;7cf2
	jr borra_al_bicho		;7cf3

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_7CF5: 10 entradas; subtabla  5 de 0x75F3
;   0x7cf5..0x7d09  (20 bytes)
DATA_tabla_de_reparto_7CF5:
	defw 07d09h,07d24h,07d45h,07d5bh,07d74h,07d85h,07c74h,07c8ah	; 7cf5
	defw 07ca0h,07cefh	; 7d05  -> muriendose_3 acaba_de_morirse

; ======================================================================
; CODIGO 0x7d09..0x7d8d  (132 bytes)
; ======================================================================


bicho_05_arranca:
	call limpia_el_bicho		;7d09
	ld (ix+007h),003h		;7d0c
	ld (ix+00ah),00dh		;7d10   ; su sprite, el 0x0D
	ld a,(ix+005h)		;7d14
	cp 080h		;7d17   ; entra por un lado o por el otro
	ld a,020h		;7d19
	jr c,L_7D1F		;7d1b
	ld a,0e0h		;7d1d
L_7D1F:
	ld (ix+005h),a		;7d1f
	jr L_7D42		;7d22
bicho_05_entra:
	call bicho_05_dispara		;7d24
	ld a,(ix+003h)		;7d27
	cp 0e0h		;7d2a   ; por debajo de la fila 0xE0 todavia no
	ret nc			;7d2c
	cp 050h		;7d2d   ; ni por encima de la 0x50
	ret c			;7d2f
	ld (ix+00ch),050h		;7d30   ; y ahi se le manda a la fila 0x50, columna 0x70 o 0x90
	ld a,(ix+005h)		;7d34
	cp 080h		;7d37
	ld a,090h		;7d39
	jr nc,L_7D3F		;7d3b
	ld a,070h		;7d3d
L_7D3F:
	ld (ix+00dh),a		;7d3f
L_7D42:
	jp L_7BFC		;7d42
bicho_05_va_al_centro:
	call bicho_05_se_mueve		;7d45
	ld a,(ix+003h)		;7d48
	cp 04fh		;7d4b   ; al llegar a la fila 0x4F, al centro
	ret nc			;7d4d
	ld (ix+00dh),080h		;7d4e
L_7D52:
	xor a			;7d52
	ld (ix+008h),a		;7d53
	ld (ix+009h),a		;7d56
	jr L_7D42		;7d59
bicho_05_baja:
	call bicho_05_se_mueve		;7d5b
	ld a,(ix+003h)		;7d5e   ; pasada la fila 0x50
	cp 050h		;7d61
	ret c			;7d63
	ld a,(ix+005h)		;7d64   ; se le manda al lado por el que entro
	cp 080h		;7d67
	ld a,070h		;7d69
	jr nc,L_7D6F		;7d6b
	ld a,090h		;7d6d
L_7D6F:
	ld (ix+00dh),a		;7d6f
	jr L_7D52		;7d72
bicho_05_vuelve:
	call bicho_05_se_mueve		;7d74
	ld a,(ix+003h)		;7d77
	cp 04fh		;7d7a
	ret nc			;7d7c
	jr L_7D52		;7d7d
bicho_05_se_mueve:
	call tira_hacia_la_fila_a_la_mitad		;7d7f
	call tira_hacia_la_columna_a_la_mitad		;7d82
bicho_05_dispara:
	ld b,00dh		;7d85
anima_y_dispara:
	call L_79FA		;7d87
	jp mueve_y_dispara		;7d8a

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_7D8D: 6 entradas; subtabla  6 de 0x75F3
;   0x7d8d..0x7d99  (12 bytes)
DATA_tabla_de_reparto_7D8D:
	defw 07d99h,07dabh,07c74h,07c8ah,07ca0h,07cefh	; 7d8d

; ======================================================================
; CODIGO 0x7d99..0x7daf  (22 bytes)
; ======================================================================


bicho_06_arranca:
	call limpia_el_bicho		;7d99
	ld (ix+006h),0a0h		;7d9c
	ld (ix+00ah),00fh		;7da0   ; su sprite, el 0x0F
	ld (ix+00bh),005h		;7da4
	jp L_7BFC		;7da8
bicho_06_se_mueve:
	ld b,00fh		;7dab
	jr $-38		;7dad

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_7DAF: 11 entradas; subtabla  7 de 0x75F3
;   0x7daf..0x7dc5  (22 bytes)
DATA_tabla_de_reparto_7DAF:
	defw 07dc5h,07debh,07e2bh,07e4ch,07e62h,07e75h,07e8ah,07c74h	; 7daf
	defw 07c8ah,07ca0h,07cefh	; 7dbf  -> muriendose_2 muriendose_3 acaba_de_morirse

; ======================================================================
; CODIGO 0x7dc5..0x7e13  (78 bytes)
; ======================================================================


bicho_07_arranca:
	call limpia_el_bicho		;7dc5
	ld (ix+00ah),011h		;7dc8   ; su sprite, el 0x11
	ld (ix+014h),004h		;7dcc   ; aguanta cuatro impactos
	ld (ix+015h),000h		;7dd0
	ld a,(ix+005h)		;7dd4
	cp 080h		;7dd7   ; entra por un lado o por el otro, y (ix+0x10) se acuerda de cual
	ld a,020h		;7dd9
	ld b,000h		;7ddb
	jr c,L_7DE2		;7ddd
	ld a,0e0h		;7ddf
	inc b			;7de1
L_7DE2:
	ld (ix+005h),a		;7de2
	ld (ix+010h),b		;7de5
	jp L_7BFC		;7de8
bicho_07_elige_velocidad:
	ld a,(ix+010h)		;7deb   ; segun el lado, una tabla u otra
	and a			;7dee
	ld hl,07e13h		;7def
	jr z,L_7DF7		;7df2
	ld hl,07e1bh		;7df4
L_7DF7:
	ld a,(ix+015h)		;7df7   ; y (ix+0x15) dice cuantas vueltas lleva: cada una va mas deprisa
	push af			;7dfa
	call palabra_de_tabla_doble		;7dfb
	ld (ix+008h),e		;7dfe
	ld (ix+009h),d		;7e01
	pop af			;7e04
	ld hl,07e23h		;7e05   ; la velocidad vertical, de la tabla de 0x7E23
	call palabra_de_tabla_doble		;7e08
	ld (ix+006h),e		;7e0b
	ld (ix+007h),d		;7e0e
	jr $+78		;7e11

; ----------------------------------------------------------------------
; DATOS tres_parejas_de_0x7DEF: Las leen 0x7DEF, 0x7DF4 y 0x7E05
;   0x7e13..0x7e2b  (24 bytes)
DATA_tres_parejas_de_0x7DEF:
	defb 080h,001h,000h,002h,080h,002h,000h,003h	; 7e13  ........
	defb 080h,0feh,000h,0feh,080h,0fdh,000h,0fdh	; 7e1b  ........
	defb 060h,000h,090h,000h,0c0h,000h,000h,001h	; 7e23  `.......

; ======================================================================
; CODIGO 0x7e2b..0x7eab  (128 bytes)
; ======================================================================


bicho_07_cruza:
	ld b,011h		;7e2b
	call anima_y_dispara		;7e2d
	ld a,(ix+010h)		;7e30
	and a			;7e33
	ld a,(ix+005h)		;7e34
	jr nz,L_7E3E		;7e37
	cp 0e0h		;7e39   ; al llegar al otro lado
	ret c			;7e3b
	jr L_7E41		;7e3c
L_7E3E:
	cp 021h		;7e3e
	ret nc			;7e40
L_7E41:
	ld a,(ix+010h)		;7e41
	xor 001h		;7e44   ; da la vuelta
	ld (ix+010h),a		;7e46
	jp baja_de_estado		;7e49
bicho_07_tocado:
	ld de,00100h		;7e4c   ; cien puntos por impacto
	call suma_puntos_bc		;7e4f
	ld (ix+00ah),013h		;7e52   ; y se pone a parpadear
	ld (ix+012h),002h		;7e56
	ld a,006h		;7e5a
L_7E5C:
	ld (ix+00eh),a		;7e5c
L_7E5F:
	jp L_7BFC		;7e5f
bicho_07_parpadea:
	dec (ix+00eh)		;7e62
	ret nz			;7e65
	inc (ix+00ah)		;7e66   ; sube de sprite cada seis cuadros
	ld (ix+00eh),006h		;7e69
	dec (ix+012h)		;7e6d
	ret nz			;7e70
	ld a,020h		;7e71
	jr L_7E5C		;7e73
bicho_07_recupera:
	dec (ix+00eh)		;7e75
	ret nz			;7e78
	ld (ix+00ah),015h		;7e79
	ld (ix+012h),002h		;7e7d
	ld a,009h		;7e81
	call pide_pieza		;7e83   ; con su sonido
	ld a,006h		;7e86
	jr L_7E5C		;7e88
bicho_07_vuelve_a_su_sprite:
	dec (ix+00eh)		;7e8a
	ret nz			;7e8d
	dec (ix+00ah)		;7e8e   ; baja de sprite cada seis cuadros
	ld (ix+00eh),006h		;7e91
	dec (ix+012h)		;7e95
	ret nz			;7e98
	ld a,(ix+015h)		;7e99   ; una vuelta mas, topada en cuatro
	inc a			;7e9c
	cp 004h		;7e9d
	jr c,L_7EA3		;7e9f
	ld a,004h		;7ea1
L_7EA3:
	ld (ix+015h),a		;7ea3
	ld (ix+000h),002h		;7ea6   ; y a cruzar otra vez
	ret			;7eaa

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_7EAB: 7 entradas; subtabla  9 de 0x75F3
;   0x7eab..0x7eb9  (14 bytes)
DATA_tabla_de_reparto_7EAB:
	defw 07eb9h,07ecah,07efeh,07c74h,07c8ah,07ca0h,07cefh	; 7eab

; ======================================================================
; CODIGO 0x7eb9..0x7f1d  (100 bytes)
; ======================================================================


bicho_09_arranca_b:
	call limpia_el_bicho		;7eb9
L_7EBC:
	ld (ix+007h),001h		;7ebc
	ld (ix+00ah),018h		;7ec0   ; su sprite, el 0x18
	ld (ix+00bh),003h		;7ec4   ; aguanta tres impactos
	jr L_7EFB		;7ec8
bicho_09_se_acerca:
	call bicho_09_dispara_y_se_mueve		;7eca
	ld a,(ix+003h)		;7ecd
	cp 0c0h		;7ed0   ; por debajo de la columna 0xC0
	ret nc			;7ed2
	ld a,(0e602h)		;7ed3   ; y a menos de 0x40 del muneco
	sub (ix+003h)		;7ed6
	cp 040h		;7ed9
	ret nc			;7edb
	ld a,(ix+005h)		;7edc   ; se lanza de lado y se queda 0x30 cuadros asi
	cp 080h		;7edf
	ld bc,00120h		;7ee1
	jr c,L_7EE9		;7ee4
	ld bc,0fee0h		;7ee6
L_7EE9:
	ld (ix+008h),c		;7ee9
	ld (ix+009h),b		;7eec
	xor a			;7eef   ; y se queda quieto
	ld (ix+006h),a		;7ef0
	ld (ix+007h),a		;7ef3
	ld a,030h		;7ef6   ; 0x30 cuadros asi
	ld (ix+00eh),a		;7ef8
L_7EFB:
	jp sube_de_estado		;7efb
bicho_09_se_lanza:
	call bicho_09_dispara_y_se_mueve		;7efe
	dec (ix+00eh)		;7f01   ; pasados los 0x30 cuadros
	ret nz			;7f04
	xor a			;7f05
	ld (ix+008h),a		;7f06
	ld (ix+009h),a		;7f09
	ld (ix+006h),080h		;7f0c   ; vuelve a bajar
	ld (ix+007h),001h		;7f10
	ret			;7f14
bicho_09_dispara_y_se_mueve:
	call dispara_el_enemigo		;7f15
L_7F18:
	ld b,018h		;7f18
	jp anima_y_mueve		;7f1a

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_7F1D: 8 entradas; subtabla 10 de 0x75F3
;   0x7f1d..0x7f2d  (16 bytes)
DATA_tabla_de_reparto_7F1D:
	defw 07f2dh,07f64h,07f97h,07fd1h,07c74h,07c8ah,07ca0h,07cefh	; 7f1d

; ======================================================================
; CODIGO 0x7f2d..0x7fd9  (172 bytes)
; ======================================================================


bicho_10_arranca:
	call limpia_el_bicho		;7f2d
	ld (ix+006h),000h		;7f30
	ld (ix+007h),002h		;7f34
	ld (ix+00ah),01ah		;7f38   ; su sprite, el 0x1A
	ld (ix+00ch),050h		;7f3c
	ld a,(ix+005h)		;7f40
	cp 080h		;7f43   ; entra por el lado que le toque, con su destino
	ld bc,0fa80h		;7f45
	ld d,0b0h		;7f48
	ld e,0f0h		;7f4a
	jr c,L_7F55		;7f4c
	ld bc,00580h		;7f4e
	ld d,050h		;7f51
	ld e,010h		;7f53
L_7F55:
	ld (ix+005h),e		;7f55
	ld (ix+008h),c		;7f58
	ld (ix+009h),b		;7f5b
	ld (ix+00dh),d		;7f5e
L_7F61:
	jp L_7EFB		;7f61
bicho_10_baja:
	call tira_hacia_la_fila		;7f64
	ld b,01ah		;7f67
	call anima_y_dispara		;7f69
	ld a,(ix+003h)		;7f6c
	cp 038h		;7f6f   ; al llegar a la fila 0x38
	ret c			;7f71
	ld (ix+00ch),068h		;7f72   ; se le manda al centro
	ld (ix+00dh),080h		;7f76
	ld a,(ix+005h)		;7f7a
	cp 080h		;7f7d
	ld bc,00480h		;7f7f
	jr nc,L_7F87		;7f82
	ld bc,0fb80h		;7f84
L_7F87:
	ld (ix+006h),000h		;7f87
	ld (ix+007h),001h		;7f8b
	ld (ix+008h),c		;7f8f
	ld (ix+009h),b		;7f92
	jr L_7F61		;7f95
bicho_10_va_al_centro:
	call tira_hacia_la_fila		;7f97
	call tira_hacia_la_columna		;7f9a
	ld b,01ah		;7f9d
	call anima_y_dispara		;7f9f
	ld a,(ix+003h)		;7fa2
	cp 038h		;7fa5   ; por encima de la fila 0x38
	ret nc			;7fa7
	ld a,(ix+005h)		;7fa8   ; se le manda al lado contrario
	cp 080h		;7fab
	ld a,050h		;7fad
	ld bc,0fb20h		;7faf
	jr nc,L_7FB9		;7fb2
	ld a,0b0h		;7fb4
	ld bc,004e0h		;7fb6
L_7FB9:
	ld (ix+00dh),a		;7fb9   ; su destino
	ld (ix+00ch),050h		;7fbc
	ld (ix+006h),000h		;7fc0   ; y sube despacio
	ld (ix+007h),0feh		;7fc4
	ld (ix+008h),c		;7fc8
	ld (ix+009h),b		;7fcb
	jp L_7EFB		;7fce
bicho_10_se_va:
	call tira_hacia_la_fila		;7fd1
	ld b,01ah		;7fd4
	jp anima_y_dispara		;7fd6

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_7FD9: 6 entradas; subtabla 11 de 0x75F3
;   0x7fd9..0x7fe5  (12 bytes)
DATA_tabla_de_reparto_7FD9:
	defw 07fe5h,079a5h,07c74h,07c8ah,07ca0h,07cefh	; 7fd9

; ======================================================================
; CODIGO 0x7fe5..0x8000  (27 bytes)
; ======================================================================


bicho_11_arranca:
	call limpia_el_bicho		;7fe5
	ld (ix+00ah),005h		;7fe8   ; su sprite, el 5
	ld a,(0e003h)		;7fec   ; una de las cuatro columnas de 0x8000, por el contador de cuadros
	rra			;7fef
	rra			;7ff0
	and 003h		;7ff1
	ld hl,08000h		;7ff3
	call suma_a_a_hl		;7ff6
	ld l,(hl)			;7ff9
	call angulo_a_la_columna_l		;7ffa   ; el angulo hasta ahi
	jp pon_la_velocidad_del_angulo		;7ffd

; ----------------------------------------------------------------------
; DATOS tabla_de_0x7FF3 (tramo): Las cuatro columnas por las que puede salir
;   el bicho 11; 0x7FF3 indexa con el contador de cuadros
;   0x8000..0x8004  (4 bytes)  de 0x8000..0x8014 (20 bytes)
DATA_tabla_de_0x7FF3:
	defb 0b0h,090h,070h,050h	; 8000

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_8004: 8 entradas; subtabla 12 de 0x75F3
;   0x8004..0x8014  (16 bytes)
DATA_tabla_de_reparto_8004:
	defw 08014h,08044h,08076h,08094h,07c74h,07c8ah,07ca0h,07cefh	; 8004

; ======================================================================
; CODIGO 0x8014..0x809c  (136 bytes)
; ======================================================================


bicho_12_arranca:
	call limpia_el_bicho		;8014
	ld (ix+006h),080h		;8017
	ld (ix+00ah),01ch		;801b   ; su sprite, el 0x1C
	ld (ix+00ch),010h		;801f
	ld (ix+012h),000h		;8023
	ld a,(ix+005h)		;8027   ; entra por un lado o por el otro
	cp 080h		;802a
	ld a,010h		;802c
	ld bc,00100h		;802e
	jr c,L_8038		;8031
	ld a,0f0h		;8033
	ld bc,0ff00h		;8035
L_8038:
	ld (ix+005h),a		;8038
	ld (ix+008h),c		;803b
	ld (ix+009h),b		;803e
L_8041:
	jp L_7EFB		;8041
bicho_12_serpentea:
	call tira_hacia_la_columna		;8044
	call bicho_12_se_mueve		;8047
	ld a,(ix+012h)		;804a   ; el destino vertical sube 0x20 dieciseisavos por cuadro
	add a,020h		;804d
	ld (ix+012h),a		;804f
	jr nc,L_8057		;8052
	inc (ix+00ch)		;8054
L_8057:
	ld a,(ix+003h)		;8057
	cp 060h		;805a   ; pasada la fila 0x60
	ret nc			;805c
	ld a,(ix+005h)		;805d
	cp 018h		;8060   ; y cerca de un borde, se le da la vuelta
	jr nc,L_8069		;8062
	ld bc,00100h		;8064
	jr L_806F		;8067
L_8069:
	cp 0e8h		;8069
	ret c			;806b
	ld bc,0ff00h		;806c
L_806F:
	ld (ix+008h),c		;806f
	ld (ix+009h),b		;8072
	ret			;8075
bicho_12_apunta_al_muneco:
	call angulo_al_muneco		;8076
pon_la_velocidad_del_angulo:
	call seno_y_coseno		;8079   ; seno y coseno del angulo
	ld h,b			;807c
	ld l,c			;807d
	add hl,hl			;807e   ; el coseno por ocho: la velocidad horizontal
	add hl,hl			;807f
	add hl,hl			;8080
	ld (ix+006h),l		;8081
	ld (ix+007h),h		;8084
	ld h,d			;8087
	ld l,e			;8088
	add hl,hl			;8089   ; y el seno por cinco: la vertical
	add hl,hl			;808a
	add hl,de			;808b
	ld (ix+008h),l		;808c
	ld (ix+009h),h		;808f
	jr L_8041		;8092
bicho_12_se_mueve:
	ld b,01ch		;8094
anima_y_mueve:
	call L_79FA		;8096
	jp mueve_al_bicho		;8099

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_809C: 7 entradas; subtabla 13 de 0x75F3
;   0x809c..0x80aa  (14 bytes)
DATA_tabla_de_reparto_809C:
	defw 080aah,080b8h,080e3h,07c74h,07c8ah,07ca0h,07cefh	; 809c

; ======================================================================
; CODIGO 0x80aa..0x8108  (94 bytes)
; ======================================================================


bicho_13_arranca:
	call limpia_el_bicho		;80aa
	ld (ix+00ah),01eh		;80ad   ; su sprite, el 0x1E
	ld (ix+010h),001h		;80b1
	jp apunta_al_muneco_y_arranca		;80b5
bicho_13_espera:
	call bicho_13_se_mueve		;80b8
	ld a,(ix+010h)		;80bb
	rra			;80be   ; con el bit 0 a cero se hace invisible
	jr c,L_80C5		;80bf
	ld (ix+00ah),000h		;80c1
L_80C5:
	call hay_alguna_ranura_de_disparo_libre		;80c5   ; y sale cuando hay ranura de disparo libre
	ld b,000h		;80c8
	jr nc,L_80CD		;80ca
	inc b			;80cc
L_80CD:
	ld a,(ix+010h)		;80cd
	and 001h		;80d0   ; hasta que cambia si hay hueco
	xor b			;80d2
	ret z			;80d3
	ld a,(ix+010h)		;80d4
	xor 001h		;80d7
	ld (ix+010h),a		;80d9
	ld (ix+00eh),008h		;80dc
	jp L_7EFB		;80e0
bicho_13_sale:
	call bicho_13_se_mueve		;80e3
	ld a,(ix+00eh)		;80e6
	bit 0,a		;80e9   ; y parpadea mientras sale
	jr z,L_80F1		;80eb
	ld (ix+00ah),000h		;80ed
L_80F1:
	dec (ix+00eh)		;80f1
	ret nz			;80f4
	jp baja_de_estado		;80f5
bicho_13_se_mueve:
	ld b,01eh		;80f8
	call anima_y_dispara		;80fa
	ld a,(0e003h)		;80fd
	and 03eh		;8100   ; y suena cada 64 cuadros
	ret nz			;8102
	ld a,008h		;8103
	jp pide_pieza		;8105

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_8108: 6 entradas; subtabla 14 de 0x75F3
;   0x8108..0x8114  (12 bytes)
DATA_tabla_de_reparto_8108:
	defw 08114h,08122h,07c74h,07c8ah,07ca0h,07cefh	; 8108

; ======================================================================
; CODIGO 0x8114..0x8127  (19 bytes)
; ======================================================================


bicho_14_arranca:
	call limpia_el_bicho		;8114
	ld (ix+006h),080h		;8117
	ld (ix+00ah),020h		;811b   ; su sprite, el 0x20
	jp L_7EFB		;811f
bicho_14_se_mueve:
	ld b,020h		;8122
	jp anima_y_dispara		;8124

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_8127: 9 entradas; subtabla 15 de 0x75F3
;   0x8127..0x8139  (18 bytes)
DATA_tabla_de_reparto_8127:
	defw 08139h,08155h,0815ah,08181h,081b5h,07c74h,07c8ah,07ca0h	; 8127
	defw 07cefh	; 8137  -> acaba_de_morirse

; ======================================================================
; CODIGO 0x8139..0x8250  (279 bytes)
; ======================================================================


bicho_15_arranca:
	call limpia_el_bicho		;8139
	ld (ix+00ah),022h		;813c   ; su sprite, el 0x22
apunta_al_muneco_y_arranca:
	call angulo_al_muneco		;8140   ; el angulo hasta el muneco
	call seno_y_coseno		;8143   ; su seno y su coseno
	ld (ix+006h),c		;8146
	ld (ix+007h),b		;8149
	ld (ix+008h),e		;814c
	ld (ix+009h),d		;814f
L_8152:
	jp L_7EFB		;8152
bicho_15_se_mueve:
	ld b,022h		;8155
	jp anima_y_dispara		;8157
bicho_15_se_parte_en_dos:
	call limpia_el_bicho		;815a
	ld (ix+009h),0f9h		;815d   ; uno sube
	ld (ix+00eh),004h		;8161
	call L_8152		;8165   ; y se busca ranura para el otro
	push ix		;8168
	push ix		;816a
	call busca_ranura_de_enemigo		;816c
	pop hl			;816f
	jr nz,L_817E		;8170
	push ix		;8172
	pop de			;8174
	ld bc,00020h		;8175   ; que es una copia de los 0x20 bytes de este
	ldir		;8178
	ld (ix+009h),007h		;817a   ; pero bajando
L_817E:
	pop ix		;817e
	ret			;8180
bicho_15_rebota:
	call bicho_15_se_mueve_b		;8181
	ld a,(ix+005h)		;8184
	ld b,a			;8187
	cp 018h		;8188   ; topado por arriba en 0x18...
	jr nc,L_818E		;818a
	ld b,018h		;818c
L_818E:
	cp 0e8h		;818e   ; ...y por abajo en 0xE7
	jr c,L_8194		;8190
	ld b,0e7h		;8192
L_8194:
	ld (ix+005h),b		;8194
	dec (ix+00eh)		;8197   ; y al acabar la cuenta, apunta al muneco al doble de velocidad
	ret nz			;819a
	call angulo_al_muneco		;819b   ; el angulo hasta el muneco
	call seno_y_coseno		;819e
	ld h,b			;81a1
	ld l,c			;81a2
	add hl,hl			;81a3   ; al doble
	ld (ix+006h),l		;81a4
	ld (ix+007h),h		;81a7
	ld h,d			;81aa
	ld l,e			;81ab
	add hl,hl			;81ac
	ld (ix+008h),l		;81ad
	ld (ix+009h),h		;81b0
	jr L_8152		;81b3
bicho_15_se_mueve_b:
	ld b,024h		;81b5
	jp anima_y_dispara		;81b7

; ----------------------------------------------------------------------
; ====================================================================
; LOS DISPAROS DEL ENEMIGO. Ocho ranuras de 0x10 bytes desde 0xE200, y
; sus sprites en 0xE358. (iy+0) es el estado: 1 volando, 2 saliendo y
; 3 el especial.
; ====================================================================
; ----------------------------------------------------------------------
haz_los_disparos_del_enemigo:
	ld a,(0e3b0h)		;81ba
	or a			;81bd   ; en la pantalla del jefe...
	jr z,L_81C9		;81be
	ld a,(0e065h)		;81c0   ; ...solo las fases 1 y 3 los tienen
	cp 001h		;81c3
	ret z			;81c5
	cp 003h		;81c6
	ret z			;81c8
L_81C9:
	xor a			;81c9
	ld (0e0c1h),a		;81ca
	ld iy,0e200h		;81cd   ; las ocho ranuras
L_81D1:
	ld hl,disparo_del_enemigo_siguiente		;81d1   ; se empuja el remate, que pasa a la ranura siguiente
	push hl			;81d4
	ld a,(iy+000h)		;81d5
	dec a			;81d8
	jp z,disparo_del_enemigo_volando		;81d9
	dec a			;81dc
	jp z,mueve_un_disparo_del_enemigo		;81dd
	dec a			;81e0
	jp z,disparo_del_enemigo_saliendo		;81e1
	jp aparca_este_disparo		;81e4
disparo_del_enemigo_siguiente:
	ld de,00010h		;81e7
	add iy,de		;81ea
	ld hl,0e0c1h		;81ec
	inc (hl)			;81ef
	ld a,(hl)			;81f0
	cp 008h		;81f1   ; hasta las ocho
	ret nc			;81f3
	jr L_81D1		;81f4
aparca_este_disparo:
	ld (iy+002h),0e0h		;81f6
	ld a,(0e0c1h)		;81fa   ; su sprite, tambien aparcado
	add a,a			;81fd
	add a,a			;81fe
	ld hl,0e358h		;81ff
	add a,l			;8202
	ld l,a			;8203
	ld (hl),0e0h		;8204
	ret			;8206
disparo_del_enemigo_volando:
	call pinta_un_disparo_del_enemigo		;8207
	call mueve_un_disparo_del_enemigo		;820a
	push iy		;820d
	jp L_79AA		;820f
disparo_del_enemigo_saliendo:
	dec (iy+00dh)		;8212   ; la cuenta de la salida
	jp m,apaga_este_disparo		;8215
	ld b,(iy+00dh)		;8218
	ld a,(0e0c1h)		;821b
	add a,a			;821e
	add a,a			;821f
	ld hl,0e358h		;8220   ; su sprite
	add a,l			;8223
	ld l,a			;8224
	ld a,(iy+003h)		;8225
	ld (hl),a			;8228
	inc l			;8229
	ld a,(iy+005h)		;822a
	ld (hl),a			;822d
	inc l			;822e
	ld a,b			;822f
	add a,a			;8230
	ld de,08250h		;8231   ; y la pareja [patron][color] de la tabla de 0x8250
	add a,e			;8234
	ld e,a			;8235
	jr nc,L_8239		;8236
	inc d			;8238
L_8239:
	ex de,hl			;8239
	ldi		;823a   ; la pareja [patron][color]
	ldi		;823c
	dec e			;823e
	dec e			;823f
	ld a,(de)			;8240   ; el patron 0x44 va cinco pixeles mas abajo
	dec e			;8241
	dec e			;8242
	cp 044h		;8243   ; el patron 0x44 se pinta cinco pixeles mas abajo
	ret nz			;8245
	ld a,(de)			;8246
	add a,005h		;8247
	ld (de),a			;8249
	ret			;824a
apaga_este_disparo:
	ld (iy+000h),000h		;824b
	ret			;824f

; ----------------------------------------------------------------------
; DATOS tabla_de_0x8231: Pareja [patron][color] por fotograma del disparo que
;   sale; 0x8231 la indexa con la cuenta de salida
;   0x8250..0x825e  (14 bytes)
DATA_tabla_de_0x8231:
	defb 054h,008h	; 8250
	defb 054h,000h	; 8252
	defb 054h,008h	; 8254
	defb 050h,008h	; 8256
	defb 044h,00ah	; 8258
	defb 050h,008h	; 825a
	defb 044h,00ah	; 825c

; ======================================================================
; CODIGO 0x825e..0x82c0  (98 bytes)
; ======================================================================


cuantos_disparos_del_enemigo_caben:
	ld a,(0e0c3h)		;825e   ; el tope, de (0xE0C3)
	ld d,a			;8261
	ld hl,0e200h		;8262
	ld bc,00800h		;8265   ; las ocho ranuras
L_8268:
	ld a,(hl)			;8268
	or a			;8269
	jr nz,L_8271		;826a
	inc c			;826c   ; se cuentan las vacias
	ld a,c			;826d
	cp d			;826e
	ccf			;826f
	ret c			;8270
L_8271:
	ld a,010h		;8271
	add a,l			;8273
	ld l,a			;8274
	djnz L_8268		;8275
	ret			;8277
pinta_un_disparo_del_enemigo:
	ld a,(0e0c1h)		;8278   ; su sprite, cuatro bytes por ranura
	add a,a			;827b
	add a,a			;827c
	ld de,0e358h		;827d
	add a,e			;8280
	ld e,a			;8281
	push iy		;8282
	pop hl			;8284
	inc l			;8285   ; la fila y la columna
	inc l			;8286
	inc l			;8287
	ldi		;8288
	inc hl			;828a
	ldi		;828b
	ld a,(iy+00ah)		;828d   ; el patron
	ld (de),a			;8290
	inc de			;8291
	ld a,00fh		;8292   ; y el color, blanco
	ld (de),a			;8294
	ld a,(iy+001h)		;8295   ; los tipos 6 y 12 tienen animacion
	cp 006h		;8298
	jr z,L_829F		;829a
	cp 00ch		;829c
	ret nz			;829e
L_829F:
	and 002h		;829f   ; el tipo 12 alterna cuatro dibujos y el 6, ocho
	add a,a			;82a1
	ld b,a			;82a2
	inc (iy+00dh)		;82a3   ; su contador de animacion
	ld a,(iy+001h)		;82a6
	cp 006h		;82a9
	ld a,(iy+00dh)		;82ab
	jr z,L_82B1		;82ae
	rra			;82b0
L_82B1:
	and 003h		;82b1
	add a,b			;82b3
	ld hl,082c0h		;82b4   ; su patron sale de la tabla de 0x82C0
	add a,l			;82b7
	ld l,a			;82b8
	jr nc,L_82BC		;82b9
	inc h			;82bb
L_82BC:
	dec de			;82bc
	ldi		;82bd
	ret			;82bf

; ----------------------------------------------------------------------
; DATOS ocho_bytes_de_0x82B4: Los ocho patrones con los que se animan los
;   disparos de los tipos 6 y 12; 0x82B4 los indexa
;   0x82c0..0x82c8  (8 bytes)
DATA_ocho_bytes_de_0x82B4:
	defb 0a8h,0b4h,0b0h,0ach,064h,068h,06ch,070h	; 82c0  ....dhlp

; ======================================================================
; CODIGO 0x82c8..0x8301  (57 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; SOLTAR UN DISPARO DE ENEMIGO. Se llena la ranura con la posicion del
; bicho que lo tira y el patron que le toca a su tipo.
; ----------------------------------------------------------------------
suelta_un_disparo_del_enemigo:
	inc (iy+000h)		;82c8
	push iy		;82cb
	pop hl			;82cd
	inc l			;82ce
	ld a,(0e0c6h)		;82cf   ; el tipo, de (0xE0C6)
	ld (hl),a			;82d2
	inc l			;82d3
	inc l			;82d4
	ld e,(ix+003h)		;82d5   ; la fila del bicho
	ld (hl),e			;82d8
	inc l			;82d9
	inc l			;82da
	ld d,(ix+005h)		;82db   ; y la columna
	ld (hl),d			;82de
	push iy		;82df
	pop de			;82e1
	ld a,00ah		;82e2
	add a,e			;82e4
	ld e,a			;82e5
	ld a,(iy+001h)		;82e6
	dec a			;82e9
	ld hl,08301h		;82ea   ; el patron de su tipo, de la tabla de 0x8301
	add a,l			;82ed
	ld l,a			;82ee
	jr nc,L_82F2		;82ef
	inc h			;82f1
L_82F2:
	ldi		;82f2
	ld a,00fh		;82f4   ; en blanco
	ld (de),a			;82f6
	ld a,(iy+001h)		;82f7   ; salvo el tipo 11, que va en rojo
	cp 00bh		;82fa
	ret nz			;82fc
	ld a,008h		;82fd
	ld (de),a			;82ff
	ret			;8300

; ----------------------------------------------------------------------
; DATOS tabla_de_0x82EA: El patron de cada tipo de disparo de enemigo; 0x82EA
;   indexa con (iy+1) menos uno
;   0x8301..0x830f  (14 bytes)
DATA_tabla_de_0x82EA:
	defb 074h,058h,058h,060h,060h,064h,058h	; 8301
	defb 060h,000h,084h,084h,090h,098h,098h	; 8308

; ======================================================================
; CODIGO 0x830f..0x844e  (319 bytes)
; ======================================================================


mueve_un_disparo_del_enemigo:
	ld a,(0e600h)		;830f
	cp 002h		;8312   ; con el muneco muriendose, nada
	ret nc			;8314
	push iy		;8315
	pop ix		;8317
L_8319:
	ld a,(0e60ch)		;8319   ; (0xE60C) es el escudo: 1 lo para, 2 lo devuelve
	and a			;831c
	jr z,L_8325		;831d
	dec a			;831f
	jr z,el_escudo_lo_para		;8320
	dec a			;8322
	jr z,mira_si_el_disparo_choca_con_otro		;8323
L_8325:
	call toca_el_disparo_del_enemigo_al_muneco		;8325   ; mira si le da al muneco
	jr c,mira_si_el_disparo_choca_con_otro		;8328
	ld (iy+000h),000h		;832a   ; y se apaga
	ld (iy+003h),0e0h		;832e
	ld a,(0e60ch)		;8332
	cp 003h		;8335
	ret z			;8337
mata_al_muneco:
	ld hl,0e600h		;8338
	ld a,002h		;833b   ; ya estaba muriendose
	cp (hl)			;833d
	ret z			;833e
	ld (hl),a			;833f
	ld a,090h		;8340   ; 0x90 cuadros de agonia
	ld (0e60bh),a		;8342
	ld a,0aeh		;8345   ; y su sonido
	jp pide_pieza		;8347
el_escudo_lo_para:
	call caja_del_disparo_del_muneco		;834a
	ld a,(0e602h)		;834d   ; la caja del escudo, alrededor del muneco
	sub 009h		;8350
	ld (0e0d0h),a		;8352
	ld a,(0e604h)		;8355
	ld (0e0d1h),a		;8358
	ld de,00810h		;835b
	call se_cruzan_las_cajas		;835e   ; si lo toca
	jr c,L_8325		;8361
	ld a,011h		;8363   ; suena el rebote
	call pide_pieza		;8365
	xor a			;8368   ; y el disparo se apaga
	ld (ix+000h),a		;8369
	ld (ix+003h),0e0h		;836c
	ld a,(iy+001h)		;8370
	cp 007h		;8373
	ld hl,0e60fh		;8375
	ld a,(hl)			;8378
	ld b,001h		;8379   ; el escudo se gasta: uno de los tipos rapidos gasta cuatro
	jr c,L_837F		;837b
	ld b,004h		;837d
L_837F:
	sub b			;837f
	ld (hl),a			;8380
	ret p			;8381
	xor a			;8382
	ld (hl),a			;8383
	ld (0e60ch),a		;8384   ; y al agotarse, fuera
	ret			;8387
mira_si_el_disparo_choca_con_otro:
	ld a,(0e3b0h)		;8388
	cp 004h		;838b   ; en la pantalla del jefe pasada la fase 4, no
	ret nc			;838d
	ld a,(iy+001h)		;838e
	cp 006h		;8391   ; solo el tipo 6 se puede tumbar
	ret nz			;8393
	ld hl,0e620h		;8394   ; las tres ranuras de disparo del muneco
	ld a,(hl)			;8397
	rla			;8398
	jr c,L_83A3		;8399
	call toca_el_disparo_al_disparo_del_enemigo		;839b
	ld hl,0e625h		;839e
	jr nc,L_83C1		;83a1
L_83A3:
	ld hl,0e630h		;83a3
	ld a,(hl)			;83a6   ; la segunda ranura
	rla			;83a7
	jr c,L_83B2		;83a8
	call toca_el_disparo_al_disparo_del_enemigo		;83aa
	ld hl,0e635h		;83ad
	jr nc,L_83C1		;83b0
L_83B2:
	ld hl,0e640h		;83b2
	ld a,(hl)			;83b5   ; y la tercera
	rla			;83b6
	jr c,L_83DC		;83b7
	call toca_el_disparo_al_disparo_del_enemigo		;83b9
	ld hl,0e645h		;83bc
	jr c,L_83DC		;83bf
L_83C1:
	ld a,(hl)			;83c1   ; el arma partida por dos
	srl a		;83c2
	cp 003h		;83c4
	jr nc,L_83CF		;83c6
	dec l			;83c8
	dec l			;83c9
	dec l			;83ca
	dec l			;83cb
	dec l			;83cc
	set 7,(hl)		;83cd
L_83CF:
	ld a,04dh		;83cf   ; suena el rebote
	call pide_pieza_si_la_escena_lo_permite		;83d1
	ld (ix+000h),003h		;83d4   ; y el disparo se pone a morirse
	ld (ix+00dh),007h		;83d8
L_83DC:
	push ix		;83dc
	pop iy		;83de
	ret			;83e0

; ----------------------------------------------------------------------
; SENO Y COSENO DE UN ANGULO. El angulo va de 0 a 255 y se parte en
; cuatro cuadrantes; dentro de cada uno, las tablas de 0x844E y 0x848F
; -una vuelta de coseno escalada a 255 y otra a 128- se leen hacia
; delante para el coseno y hacia atras, entrando por 0x40 - k, para el
; seno. Devuelve BC y DE, y ademas los deja en (0xE0CF).
; ----------------------------------------------------------------------
seno_y_coseno:
	ld b,a			;83e1
	ld c,000h		;83e2
	cp 041h		;83e4   ; primer cuadrante
	jr c,L_83FE		;83e6
	inc c			;83e8
	cp 080h		;83e9   ; segundo: el angulo se refleja
	jr nc,L_83F2		;83eb
	ld a,080h		;83ed
	sub b			;83ef
	jr L_83FE		;83f0
L_83F2:
	inc c			;83f2
	cp 0c0h		;83f3   ; tercero
	jr nc,L_83FB		;83f5
	sub 080h		;83f7
	jr L_83FE		;83f9
L_83FB:
	inc c			;83fb   ; y cuarto
	neg		;83fc
L_83FE:
	ld b,a			;83fe
	ex af,af'			;83ff
	ld a,b			;8400
	ex af,af'			;8401
	ld hl,0844eh		;8402   ; el coseno, con la tabla de 255
	add a,l			;8405
	ld l,a			;8406
	jr nc,L_840A		;8407
	inc h			;8409
L_840A:
	ld d,000h		;840a
	ld e,(hl)			;840c
	ld a,c			;840d
	sub 001h		;840e   ; en los cuadrantes 1 y 2 cambia de signo
	cp 002h		;8410
	ld a,e			;8412
	jr nc,L_8418		;8413
	dec d			;8415
	neg		;8416
L_8418:
	ld e,a			;8418
	ld hl,0844eh		;8419   ; y el seno, entrando por 0x40 - k
	ld a,040h		;841c
	sub b			;841e
	add a,l			;841f
	ld l,a			;8420
	jr nc,L_8424		;8421
	inc h			;8423
L_8424:
	ld b,000h		;8424   ; el signo
	ld a,c			;8426
	cp 002h		;8427   ; los cuadrantes 0 y 1 lo llevan cambiado
	ld a,(hl)			;8429
	jr nc,L_842F		;842a
	dec b			;842c
	neg		;842d
L_842F:
	ld c,a			;842f
	exx			;8430
	ex af,af'			;8431
	ld b,a			;8432
	ld hl,0848fh		;8433   ; lo mismo con la tabla de 128
	add a,l			;8436
	ld l,a			;8437
	jr nc,L_843B		;8438
	inc h			;843a
L_843B:
	ld d,(hl)			;843b
	ld hl,0848fh		;843c   ; y el seno, entrando por 0x40 - k
	ld a,040h		;843f
	sub b			;8441
	add a,l			;8442
	ld l,a			;8443
	jr nc,L_8447		;8444
	inc h			;8446
L_8447:
	ld e,(hl)			;8447
	ld (0e0cfh),de		;8448   ; y las dos parejas quedan en (0xE0CF)
	exx			;844c
	ret			;844d

; ----------------------------------------------------------------------
; DATOS tabla_de_coseno_de_255: 65 entradas: 255 * cos(k * 90/64), o sea un
;   cuadrante. 0x83E1 la indexa con el angulo doblado por 0x8402 y 0x8419 -una
;   para el coseno y otra, entrando por 0x40 - k, para el seno-. El ajuste es
;   exacto: la desviacion media contra la funcion es de 0,48 y la maxima de
;   4,03... salvo UNA. Ver abajo
;   0x844e..0x848f  (65 bytes)
DATA_tabla_de_coseno_de_255:
	defb 0ffh,0ffh,0ffh,0ffh,0feh,0feh,0fdh,0fch,0fbh,0f9h,0f8h,0f6h,0f4h,0f3h,0f1h,0eeh	; 844e  ................
	defb 0ech,0eah,0e7h,0e4h,0e1h,0deh,0dch,0d9h,0d4h,0d1h,0cdh,0c9h,0c5h,0c1h,0bdh,0b9h	; 845e  ................
	defb 0b5h,0b0h,0abh,0a7h,0a2h,09dh,098h,093h,08eh,088h,083h,07eh,078h,073h,069h,067h	; 846e  ...........~xsig
	defb 061h,05ch,056h,050h,04ah,044h,03eh,038h,02eh,02bh,02fh,01fh,019h,012h,00ch,006h	; 847e  a\VPJD>8.+/.....
	defb 001h	; 848e

; ----------------------------------------------------------------------
; DATOS tabla_de_coseno_de_128: Otras 65: 128 * cos(k * 90/64). La misma
;   receta en 0x8433 y 0x843C. Desviacion media 1,73 y maxima 3,78, salvo una
;   0x848f..0x84d0  (65 bytes)
DATA_tabla_de_coseno_de_128:
	defb 080h,07fh,07fh,07fh,07fh,07fh,07eh,07eh,07dh,07ch,07ch,07bh,074h,079h,078h,077h	; 848f  ......~~}||{tyxw
	defb 075h,074h,073h,071h,070h,06eh,06dh,06bh,069h,067h,066h,064h,062h,05fh,05dh,05bh	; 849f  utsqpnmkigfdb_][
	defb 059h,057h,054h,052h,04fh,04dh,04ah,048h,045h,042h,040h,03dh,03ah,037h,034h,031h	; 84af  YWTROMJHEB@=:741
	defb 02eh,02bh,028h,025h,022h,01fh,01ch,019h,016h,013h,00fh,00ch,009h,006h,003h,001h	; 84bf  .+(%"...........
	defb 000h	; 84cf

; ----------------------------------------------------------------------
; DATOS tabla_de_tangentes_de_ocho: Ocho palabras que 0x8526 recorre con `ld
;   b,040h` bajando de ocho en ocho: es la tabla de tangentes gruesa, la que
;   usa 0x84E6 para sacar el angulo entre dos puntos
;   0x84d0..0x84e0  (16 bytes)
DATA_tabla_de_tangentes_de_ocho:
	defw 004f6h,00266h,0017dh,000ffh,000aah,00069h,00032h,00000h	; 84d0

; ======================================================================
; CODIGO 0x84e0..0x85dc  (252 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL ANGULO DE 0 A 255 ENTRE EL MUNECO Y UN BICHO. Los dos catetos en
; valor absoluto, el cociente por 0x8569 y la busqueda en la tabla de
; ----------------------------------------------------------------------
angulo_al_muneco:
	ld a,(0e602h)		;84e0
	add a,008h		;84e3
	ld l,a			;84e5
angulo_a_la_columna_l:
	ld a,(0e604h)		;84e6   ; la fila del muneco
	add a,008h		;84e9
	ld h,a			;84eb
	ld d,001h		;84ec   ; el signo, de momento positivo
	ld a,l			;84ee   ; el cateto horizontal, con su signo en D
	add a,008h		;84ef
	sub (ix+003h)		;84f1
	ld b,000h		;84f4
	jr z,L_84FF		;84f6
	ld b,a			;84f8
	jr nc,L_84FF		;84f9
	dec d			;84fb
	neg		;84fc
	ld b,a			;84fe
L_84FF:
	ld a,h			;84ff   ; y el vertical, con el suyo en E
	add a,008h		;8500   ; el cateto vertical
	sub (ix+005h)		;8502
	ld e,000h		;8505
	ld c,000h		;8507
	jr z,L_8512		;8509
	ld c,a			;850b   ; con su signo en E
	jr nc,L_8512		;850c
	inc e			;850e
	neg		;850f
	ld c,a			;8511
L_8512:
	ld a,d			;8512   ; los dos signos dan el cuadrante
	add a,e			;8513
	cp 001h		;8514
	jr nz,L_851D		;8516
	dec d			;8518
	jr nz,L_851D		;8519
	ld a,003h		;851b
L_851D:
	ld d,a			;851d
	ld l,b			;851e
	ld h,000h		;851f
	ld b,c			;8521
	push de			;8522
	call divide_con_fraccion		;8523   ; el cociente
	ld hl,084d0h		;8526   ; y se busca en la tabla, bajando de ocho en ocho
	ld b,040h		;8529
L_852B:
	ld a,(hl)			;852b   ; la entrada siguiente de la tabla
	inc hl			;852c
	push hl			;852d
	ld h,(hl)			;852e
	ld l,a			;852f
	and a			;8530
	sbc hl,de		;8531   ; hasta que se queda por debajo
	pop hl			;8533
	jr c,L_853D		;8534
	inc hl			;8536
	ld a,b			;8537
	sub 008h		;8538
	ld b,a			;853a
	jr nz,L_852B		;853b
L_853D:
	pop de			;853d
	dec d			;853e   ; el cuadrante decide como se cuenta el angulo
	jr nz,L_8547		;853f
	ld a,040h		;8541
	sub b			;8543
	add a,040h		;8544
	ret			;8546
L_8547:
	dec d			;8547
	jr nz,L_854E		;8548
	ld a,080h		;854a
	add a,b			;854c
	ret			;854d
L_854E:
	ld a,b			;854e
	dec d			;854f
	ret nz			;8550
	neg		;8551
	ret			;8553

; ----------------------------------------------------------------------
; LA DIVISION. HL entre B, ocho vueltas de restar y desplazar: el
; cociente sale en L y el resto en H.
; ----------------------------------------------------------------------
divide_hl_entre_b:
	ld c,008h		;8554
	xor a			;8556
L_8557:
	adc hl,hl		;8557   ; se dobla el dividendo
	ld a,h			;8559
	jr c,L_855F		;855a
	cp b			;855c   ; y si cabe, se resta
	jr c,L_8562		;855d
L_855F:
	sub b			;855f
	ld h,a			;8560
	xor a			;8561
L_8562:
	ccf			;8562
	dec c			;8563
	jr nz,L_8557		;8564
	rl l		;8566   ; el ultimo bit del cociente
	ret			;8568

; ----------------------------------------------------------------------
; DIVIDIR CON OCHO BITS DE FRACCION. Devuelve en DE el cociente de L
; entre B con la parte entera en D y la fraccion en E; con B a cero,
; devuelve 0xFFFF, que es el infinito de esta aritmetica.
; ----------------------------------------------------------------------
divide_con_fraccion:
	ld a,b			;8569
	or a			;856a
	jr z,L_857B		;856b   ; con divisor cero, infinito
	ld de,00000h		;856d
	call divide_hl_entre_b		;8570   ; la parte entera
	ld d,l			;8573
	ld l,000h		;8574
	call divide_hl_entre_b		;8576   ; y con el resto, otra vuelta: la fraccion
	ld e,l			;8579
	ret			;857a
L_857B:
	dec a			;857b   ; 0xFFFF: lo mas grande que hay
	ld d,a			;857c
	ld e,a			;857d
	ret			;857e

; ----------------------------------------------------------------------
; SOLTAR UNA RAFAGA DE DISPAROS DE ENEMIGO. B trae el tipo de rafaga, de
; 1 a 14; cuantos disparos salen lo dice la tabla de 0x8747 y como se
; reparten los angulos, el reparto de 0x85DC.
; ----------------------------------------------------------------------
suelta_una_rafaga:
	ld hl,0865ch		;857f
	ld (0e0c7h),hl		;8582   ; la lista de parejas de 0x865C, para el tipo que la use
	ld a,b			;8585
	ld (0e0c6h),a		;8586   ; el tipo de rafaga
	ld hl,08747h		;8589   ; cuantos disparos suelta, de la tabla de 0x8747
	dec a			;858c
	add a,l			;858d
	ld l,a			;858e
	jr nc,L_8592		;858f
	inc h			;8591
L_8592:
	ld a,(hl)			;8592
	ld (0e0c3h),a		;8593
	call angulo_al_muneco		;8596   ; el angulo hasta el muneco
	ld hl,0e0c2h		;8599
	ld (hl),a			;859c
	inc l			;859d
	ld b,(hl)			;859e
	inc l			;859f
	xor a			;85a0
	ld (hl),a			;85a1
	call cuantos_disparos_del_enemigo_caben		;85a2   ; y solo si caben todos
	ret nc			;85a5
	ld a,(0e0c6h)		;85a6
	cp 005h		;85a9   ; los tipos 5 y 10 abren el abanico hacia atras
	jr z,L_85B1		;85ab
	cp 00ah		;85ad
	jr nz,L_85C0		;85af
L_85B1:
	ld hl,0e0c2h		;85b1   ; el angulo y el numero de disparo
	ld b,(hl)			;85b4
	inc l			;85b5
	ld a,(hl)			;85b6
	add a,a			;85b7   ; por seis: el abanico se abre hacia atras
	ld c,a			;85b8
	add a,a			;85b9
	add a,c			;85ba
	sub b			;85bb
	neg		;85bc
	dec l			;85be
	ld (hl),a			;85bf
L_85C0:
	xor a			;85c0
	ld (0e0c1h),a		;85c1
	ld iy,0e200h		;85c4   ; las ocho ranuras
L_85C8:
	ld a,(iy+000h)		;85c8
	or a			;85cb
	jr nz,$+52		;85cc
	ld hl,085f8h		;85ce   ; se empuja el remate
	push hl			;85d1
	call suelta_un_disparo_del_enemigo		;85d2   ; se llena la ranura
	ld a,(0e0c6h)		;85d5
	dec a			;85d8
	call reparte_por_tabla		;85d9   ; y el tipo decide el angulo de ESTE disparo

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_85DC: 14 entradas; tras el `call 406Ch` de 0x85D9;
;   sigue en 0x860F
;   0x85dc..0x85f8  (28 bytes)
DATA_tabla_de_reparto_85DC:
	defw 0860fh,08646h,08646h,08646h,0863fh,08646h,0864ch,08646h	; 85dc
	defw 08646h,08636h,08646h,08674h,08646h,08646h	; 85ec

; ======================================================================
; CODIGO 0x85f8..0x8626  (46 bytes)
; ======================================================================


disparo_de_la_rafaga_siguiente:
	ld hl,0e0c4h		;85f8
	inc (hl)			;85fb   ; uno mas soltado
	ld a,(hl)			;85fc
	dec l			;85fd
	cp (hl)			;85fe   ; hasta los que pedia la rafaga
	ret z			;85ff
salta_a_la_ranura_siguiente:
	ld de,00010h		;8600   ; la ranura siguiente
	add iy,de		;8603
	ld hl,0e0c1h		;8605
	inc (hl)			;8608
	ld a,(hl)			;8609   ; hasta las ocho
	cp 008h		;860a
	ret z			;860c
	jr $-69		;860d
rafaga_01_por_octantes:
	ld a,(0e0c2h)		;860f   ; el nibble alto del angulo: uno de dieciseis
	rra			;8612
	rra			;8613
	rra			;8614
	rra			;8615
	and 00fh		;8616
	ld de,08626h		;8618   ; y su velocidad, de la tabla de 0x8626
	add a,e			;861b
	ld e,a			;861c
	jr nc,L_8620		;861d
	inc d			;861f
L_8620:
	ld a,(de)			;8620
	ld (iy+00ah),a		;8621
	jr $+34		;8624

; ----------------------------------------------------------------------
; DATOS dieciseis_bytes_de_0x8618: La velocidad de cada uno de los dieciseis
;   octantes; 0x8618 indexa con el nibble alto del angulo
;   0x8626..0x8636  (16 bytes)
DATA_dieciseis_bytes_de_0x8618:
	defb 08ch,088h,088h,00ch,00ch,080h,080h,07ch,07ch,078h,078h,074h,074h,090h,090h,08ch	; 8626  .......||xxtt...

; ======================================================================
; CODIGO 0x8636..0x865c  (38 bytes)
; ======================================================================


rafaga_10_abre_diez_grados:
	ld hl,0e0c2h		;8636
	ld a,(hl)			;8639
	add a,00ah		;863a
	ld (hl),a			;863c
	jr rafaga_por_el_angulo		;863d
rafaga_05_abre_dieciseis:
	ld hl,0e0c2h		;863f
	ld a,(hl)			;8642
	add a,010h		;8643
	ld (hl),a			;8645
rafaga_por_el_angulo:
	call pon_la_velocidad_de_la_rafaga		;8646
L_8649:
	jp guarda_la_velocidad_del_disparo		;8649
rafaga_07_por_la_lista:
	ld hl,(0e0c7h)		;864c   ; la pareja siguiente de 0x865C
	ld c,(hl)			;864f   ; la velocidad horizontal
	inc hl			;8650
	ld b,(hl)			;8651
	inc hl			;8652
	ld e,(hl)			;8653   ; y la vertical
	inc hl			;8654
	ld d,(hl)			;8655
	inc hl			;8656
	ld (0e0c7h),hl		;8657
	jr L_8649		;865a

; ----------------------------------------------------------------------
; DATOS doce_parejas_de_0x857F: Doce parejas [velocidad horizontal][vertical]
;   que 0x864C va sacando una por disparo
;   0x865c..0x8674  (24 bytes)
DATA_doce_parejas_de_0x857F:
	defb 000h,0fdh	; 865c
	defb 000h,000h	; 865e
	defb 080h,0feh	; 8660
	defb 040h,0feh	; 8662
	defb 080h,001h	; 8664
	defb 040h,0feh	; 8666
	defb 000h,003h	; 8668
	defb 000h,000h	; 866a
	defb 080h,001h	; 866c
	defb 0c0h,001h	; 866e
	defb 080h,0feh	; 8670
	defb 0c0h,001h	; 8672

; ======================================================================
; CODIGO 0x8674..0x868c  (24 bytes)
; ======================================================================


rafaga_12_en_abanico:
	ld a,(0e0c4h)		;8674
	ld hl,0868ch		;8677   ; el desvio de este disparo, de la tabla de 0x868C
	call suma_a_a_hl		;867a
	ld a,(hl)			;867d
	add a,(iy+005h)		;867e
	ld (iy+005h),a		;8681
	ld bc,00300h		;8684   ; y todos con la misma velocidad
	ld de,00000h		;8687
	jr $-65		;868a

; ----------------------------------------------------------------------
; DATOS tabla_de_0x8677: El desvio de cada disparo del abanico; 0x8677 indexa
;   con los que lleva sueltos
;   0x868c..0x86b5  (41 bytes)
DATA_tabla_de_0x8677:
	defb 0ebh,015h,03ah,0c2h,0e0h,047h,03eh,020h	; 868c  ..:..G> 
	defb 090h,0edh,044h,047h,0ddh,07eh,001h,0e6h	; 8694  ..DG.~..
	defb 0f0h,0feh,010h,028h,00dh,03ah,003h,0e0h	; 869c  ...(.:..
	defb 01fh,04fh,03ah,005h,0e1h,081h,0e6h,03fh	; 86a4  .O:....?
	defb 080h,047h,078h,032h,0c2h,0e0h,0cdh,0e1h	; 86ac  .Gx2....
	defb 083h	; 86b4

; ======================================================================
; CODIGO 0x86b5..0x872b  (118 bytes)
; ======================================================================


pon_la_velocidad_de_la_rafaga:
	ld a,(0e0c2h)		;86b5
	call seno_y_coseno		;86b8   ; seno y coseno del angulo
	ld a,(iy+001h)		;86bb
	dec a			;86be
	add a,a			;86bf
	ld hl,0872bh		;86c0   ; la velocidad de su tipo, de la tabla de 0x872B
	add a,l			;86c3
	ld l,a			;86c4
	jr nc,L_86C8		;86c5
	inc h			;86c7
L_86C8:
	ld a,(0e068h)		;86c8   ; con (0xE068) puesto, o de la fase 4 arriba, van mas deprisa
	and a			;86cb
	jr nz,L_86D5		;86cc
	ld a,(0e062h)		;86ce
	cp 004h		;86d1
	jr c,L_86D6		;86d3
L_86D5:
	inc hl			;86d5
L_86D6:
	ld a,(hl)			;86d6
	and 00fh		;86d7
	dec a			;86d9   ; la velocidad 2 es la de 0x86FE, la 3 la de 0x86F1
	dec a			;86da
	jr z,L_86FE		;86db
	dec a			;86dd
	jr z,L_86F1		;86de
	sla c		;86e0   ; y las demas, por cuatro
	rl b		;86e2
	sla c		;86e4
	rl b		;86e6
	sla e		;86e8
	rl d		;86ea
	sla e		;86ec
	rl d		;86ee
	ret			;86f0
L_86F1:
	ld h,b			;86f1   ; la 3: por tres
	ld l,c			;86f2
	add hl,hl			;86f3
	add hl,bc			;86f4   ; mas uno: por tres
	ld b,h			;86f5
	ld c,l			;86f6
	ld h,d			;86f7
	ld l,e			;86f8
	add hl,hl			;86f9
	add hl,de			;86fa
	ld d,h			;86fb
	ld e,l			;86fc
	ret			;86fd
L_86FE:
	ld a,(hl)			;86fe   ; la 2: por dos, y con el bit 7 se le suma el resto de (0xE0CE)
	ld h,b			;86ff   ; por dos: el paso horizontal
	ld l,c			;8700
	add hl,hl			;8701
	ld b,h			;8702
	ld c,l			;8703
	ld h,d			;8704
	ld l,e			;8705
	add hl,hl			;8706   ; y el vertical
	ld d,h			;8707
	ld e,l			;8708
	rla			;8709   ; con el bit 7 puesto, ademas se le suma el resto
	ret nc			;870a
	ld a,(0e0ceh)		;870b
	ld l,a			;870e
	ld h,000h		;870f
	add hl,bc			;8711
	ld b,h			;8712
	ld c,l			;8713
	ld a,(0e0cfh)		;8714
	ld l,a			;8717
	ld h,000h		;8718
	add hl,de			;871a
	ld d,h			;871b
	ld e,l			;871c
	ret			;871d
guarda_la_velocidad_del_disparo:
	ld (iy+006h),c		;871e
	ld (iy+007h),b		;8721
	ld (iy+008h),e		;8724
	ld (iy+009h),d		;8727
	ret			;872a

; ----------------------------------------------------------------------
; DATOS dos_tramos_de_0x8589: Los leen 0x8589 y 0x86C0
;   0x872b..0x8755  (42 bytes)
DATA_dos_tramos_de_0x8589:
	defb 003h,004h,082h,003h,002h,082h,003h,004h,003h,004h,002h,082h,003h,004h	; 872b  ..............
	defb 004h,004h,000h,000h,004h,004h,003h,003h,004h,004h,004h,004h,004h,004h	; 8739  ..............
	defb 001h,001h,001h,001h,004h,001h,006h,001h,001h,007h,001h,002h,001h,001h	; 8747  ..............

; ======================================================================
; CODIGO 0x8755..0x87c4  (111 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LAS CAJAS. Cada choque compara dos rectangulos: uno lo monta la rutina
; que corresponda -la del bicho, la del muneco, la del disparo- y el
; otro, la de enfrente; 0x88D3 decide si se cruzan.
; ----------------------------------------------------------------------
toca_el_bicho_al_muneco:
	call caja_del_bicho		;8755
	call caja_del_muneco		;8758
	jp se_cruzan_las_cajas		;875b
toca_el_decorado_al_muneco:
	call caja_del_decorado_de_la_fase		;875e
L_8761:
	call caja_del_muneco		;8761
	jp se_cruzan_las_cajas		;8764
toca_el_disparo_al_bicho:
	ld a,(ix+003h)		;8767
	cp 0d0h		;876a   ; entre la fila 0xD0 y la 0xFA no se puede tocar
	jr c,L_8772		;876c
	cp 0fah		;876e
	jr c,L_877D		;8770
L_8772:
	inc l			;8772
	inc l			;8773
	call caja_de_lo_apuntado_por_hl		;8774
	call caja_del_bicho		;8777
	jp se_cruzan_las_cajas		;877a
L_877D:
	scf			;877d
	ret			;877e
toca_el_disparo_del_enemigo_al_muneco:
	call caja_del_muneco		;877f
	call caja_del_disparo_del_muneco		;8782
	jp se_cruzan_las_cajas		;8785
toca_el_disparo_al_disparo_del_enemigo:
	ld a,(hl)			;8788   ; con el bit 7 puesto la ranura esta vacia
	rla			;8789
	jr c,L_877D		;878a
	inc l			;878c
	inc l			;878d
	call caja_de_lo_apuntado_por_hl		;878e
	call caja_del_disparo_del_muneco		;8791
	jp se_cruzan_las_cajas		;8794
toca_el_disparo_a_la_puerta:
	inc l			;8797
	inc l			;8798
	call caja_de_lo_apuntado_por_hl		;8799
	call caja_del_disparo_del_enemigo		;879c
	jp se_cruzan_las_cajas		;879f
caja_del_bicho:
	push de			;87a2
	ld a,(ix+001h)		;87a3
	and 00fh		;87a6   ; su tipo, por cuatro
	add a,a			;87a8
	add a,a			;87a9
	ld hl,087c4h		;87aa   ; la tabla de 0x87C4: [ajuste y][ajuste x][alto][ancho]
	add a,l			;87ad
	ld l,a			;87ae
	jr nc,L_87B2		;87af
	inc h			;87b1
L_87B2:
	ld a,(ix+003h)		;87b2
	add a,(hl)			;87b5   ; la fila del bicho mas el ajuste
	ld e,a			;87b6
	inc hl			;87b7
	ld a,(ix+005h)		;87b8   ; la columna
	add a,(hl)			;87bb
	ld d,a			;87bc
	inc hl			;87bd
	ld b,(hl)			;87be   ; y el alto y el ancho
	inc hl			;87bf
	ld c,(hl)			;87c0
	ex de,hl			;87c1
	pop de			;87c2
	ret			;87c3

; ----------------------------------------------------------------------
; DATOS dieciseis_por_cuatro: 0x87AA indexa con cuatro bits y multiplica por
;   cuatro: dieciseis entradas de cuatro bytes, sesenta y cuatro justos
;   0x87c4..0x8804  (64 bytes)
DATA_dieciseis_por_cuatro:
	defb 0fah,0fah,00ch,00ch	; 87c4
	defb 0fch,0fbh,008h,00ah	; 87c8
	defb 0fch,0fbh,008h,00ah	; 87cc
	defb 0fch,0fbh,008h,00ah	; 87d0
	defb 0fah,0fah,00ch,00ch	; 87d4
	defb 0fbh,0fah,00ah,00ah	; 87d8
	defb 0fah,0fah,00ch,00ch	; 87dc
	defb 0fah,0fch,00ah,008h	; 87e0
	defb 0feh,0fch,008h,008h	; 87e4
	defb 0fah,0fah,00ch,00ch	; 87e8
	defb 0fch,0fch,008h,008h	; 87ec
	defb 0fbh,0fbh,00ah,00ah	; 87f0
	defb 0fah,0fah,00ch,00ch	; 87f4
	defb 0fbh,0fah,00ah,00ah	; 87f8
	defb 0fbh,0fbh,00ah,00ah	; 87fc
	defb 0fbh,0fbh,00ah,00ah	; 8800

; ======================================================================
; CODIGO 0x8804..0x8838  (52 bytes)
; ======================================================================


caja_del_disparo_del_enemigo:
	ld a,(ix+006h)		;8804
	add a,004h		;8807   ; cuatro a la derecha
	ld l,a			;8809
	ld a,(ix+007h)		;880a
	add a,001h		;880d   ; y uno abajo
	ld h,a			;880f
	ld bc,0080eh		;8810
	ret			;8813
caja_del_decorado_de_la_fase:
	ld iy,0e3d0h		;8814
	ld a,(0e065h)		;8818   ; la fase decide la caja, de la tabla de 0x8838
	and 00fh		;881b
	ld hl,08838h		;881d
	add a,a			;8820
	add a,a			;8821
	add a,l			;8822
	ld l,a			;8823
	jr nc,L_8827		;8824
	inc h			;8826
L_8827:
	ld c,(hl)			;8827   ; el alto y el ancho de la caja
	inc hl			;8828
	ld b,(hl)			;8829
	inc hl			;882a
	ld a,(iy+003h)		;882b   ; mas la posicion del jefe
	add a,(hl)			;882e
	ld e,a			;882f
	inc hl			;8830
	ld a,(iy+005h)		;8831
	add a,(hl)			;8834
	ld h,a			;8835
	ld l,e			;8836
	ret			;8837

; ----------------------------------------------------------------------
; DATOS tabla_de_0x881D: Cuatro bytes por fase -alto, ancho y los dos
;   desplazamientos- con la caja del decorado; 0x881D indexa con (0xE065)
;   0x8838..0x8858  (32 bytes)
DATA_tabla_de_0x881D:
	defb 024h,024h,002h,002h,01ah,020h,0fch,0fbh	; 8838  $$... ..
	defb 008h,008h,010h,010h,01ah,020h,003h,0f7h	; 8840  ..... ..
	defb 024h,020h,00dh,002h,024h,025h,008h,002h	; 8848  $ ..$%..
	defb 00ch,00ch,0fah,0fah,020h,020h,008h,008h	; 8850  ....  ..

; ======================================================================
; CODIGO 0x8858..0x8871  (25 bytes)
; ======================================================================


caja_del_disparo_del_muneco:
	ld a,(ix+001h)		;8858
	dec a			;885b
	and 00fh		;885c
	ld hl,08871h		;885e   ; la tabla de 0x8871, doce parejas [alto][ancho]
	add a,a			;8861
	add a,l			;8862
	ld l,a			;8863
	jr nc,L_8867		;8864
	inc h			;8866
L_8867:
	ld c,(hl)			;8867   ; el alto y el ancho
	inc hl			;8868
	ld b,(hl)			;8869
	ld l,(ix+003h)		;886a   ; y la posicion del disparo
	ld h,(ix+005h)		;886d
	ret			;8870

; ----------------------------------------------------------------------
; DATOS tabla_de_0x885E: Pareja [alto][ancho] por arma, la caja del disparo
;   del muneco; 0x885E indexa con (ix+1) menos uno
;   0x8871..0x888f  (30 bytes)
DATA_tabla_de_0x885E:
	defb 008h,008h,002h,003h,004h,004h,008h,008h,008h,008h	; 8871  ..........
	defb 00ah,00ah,004h,004h,008h,008h,00eh,00eh,008h,008h	; 887b  ..........
	defb 008h,008h,00ch,00ch,008h,008h,008h,008h,00ch,010h	; 8885  ..........

; ======================================================================
; CODIGO 0x888f..0x88bb  (44 bytes)
; ======================================================================


caja_del_muneco:
	ld de,0e602h		;888f
	ld a,(de)			;8892
	add a,003h		;8893   ; tres pixeles dentro por cada lado
	ld (0e0d0h),a		;8895
	inc e			;8898
	inc e			;8899
	ld a,(de)			;889a
	add a,003h		;889b
	ld (0e0d1h),a		;889d
	ld de,00a0ah		;88a0   ; diez por diez
	ret			;88a3
caja_de_lo_apuntado_por_hl:
	ld e,(hl)			;88a4   ; la fila y la columna
	inc l			;88a5
	inc l			;88a6
	ld d,(hl)			;88a7
	ld (0e0d0h),de		;88a8
	inc l			;88ac
	ld a,(hl)			;88ad   ; y el tipo, que indexa las doce cajas de 0x88BB
	ld hl,088bbh		;88ae
	add a,a			;88b1
	add a,l			;88b2
	ld l,a			;88b3
	jr nc,L_88B7		;88b4
	inc h			;88b6
L_88B7:
	ld e,(hl)			;88b7
	inc hl			;88b8
	ld d,(hl)			;88b9
	ret			;88ba

; ----------------------------------------------------------------------
; DATOS doce_cajas: Doce parejas [alto][ancho] que 0x88AE indexa; son las
;   cajas con las que se miden los choques
;   0x88bb..0x88d3  (24 bytes)
DATA_doce_cajas:
	defb 004h,008h	; 88bb
	defb 004h,008h	; 88bd
	defb 00dh,008h	; 88bf
	defb 00dh,008h	; 88c1
	defb 004h,008h	; 88c3
	defb 00dh,008h	; 88c5
	defb 00ah,008h	; 88c7
	defb 00ah,008h	; 88c9
	defb 005h,005h	; 88cb
	defb 005h,005h	; 88cd
	defb 005h,008h	; 88cf
	defb 005h,008h	; 88d1

; ======================================================================
; CODIGO 0x88d3..0x88f2  (31 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; SE CRUZAN LAS DOS CAJAS? Una viene en (0xE0D0) con su tamano en DE y la
; otra en HL con el suyo en BC. Sale con acarreo si NO se tocan.
; ----------------------------------------------------------------------
se_cruzan_las_cajas:
	ld a,(0e0d0h)		;88d3
	add a,d			;88d6   ; la distancia en vertical
	sub l			;88d7
	ld l,a			;88d8
	ld a,b			;88d9   ; contra la suma de los dos altos
	add a,d			;88da
	cp l			;88db
	ret c			;88dc
	ld a,(0e0d1h)		;88dd   ; y lo mismo en horizontal
	add a,e			;88e0
	sub h			;88e1
	ld h,a			;88e2
	ld a,c			;88e3
	add a,e			;88e4
	cp h			;88e5
	ret			;88e6

; ----------------------------------------------------------------------
; LA PANTALLA DEL JEFE. Cada fase tiene la suya; (0xE3B0) lleva su
; estado y (0xE065) la fase. Las fases 0, 4 y 5 comparten la primera.
; ----------------------------------------------------------------------
haz_al_jefe:
	ld a,(0e3b0h)		;88e7
	and a			;88ea   ; sin marca de jefe, nada
	ret z			;88eb
	ld a,(0e065h)		;88ec
	call reparte_por_tabla		;88ef

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_88F2: 8 entradas; tras el `call 406Ch` de 0x88EF;
;   sigue en 0x8A95
;   0x88f2..0x8902  (16 bytes)
DATA_tabla_de_reparto_88F2:
	defw 08a95h,08e34h,09090h,09201h,08a95h,08a95h,0941dh,095e4h	; 88f2

; ======================================================================
; CODIGO 0x8902..0x8999  (151 bytes)
; ======================================================================


arranca_al_jefe:
	ld a,005h		;8902
L_8904:
	ld (0e3b0h),a		;8904   ; estado 5
	ld (0e3c0h),a		;8907
	ld b,00ah		;890a   ; aparca los diez trozos del jefe
	ld hl,0e200h		;890c
	ld de,0000dh		;890f
L_8912:
	ld (hl),000h		;8912
	inc hl			;8914
	inc hl			;8915
	inc hl			;8916
	ld (hl),0e0h		;8917
	add hl,de			;8919
	djnz L_8912		;891a
	call monta_los_sprites_de_los_trozos		;891c   ; y sus sprites
	ld a,040h		;891f
	ld (0e3b1h),a		;8921   ; 0x40 cuadros de entrada
	ld a,017h		;8924   ; con su musica
	jp pide_pieza_si_la_escena_lo_permite		;8926
espera_al_jefe:
	call le_dan_los_disparos_al_jefe		;8929
	ld a,(0e3bfh)		;892c
	and a			;892f
	ret			;8930
monta_diez_trozos_de_la_cabeza:
	ld bc,0440ah		;8931   ; patron 0x44, color 0x0A
	ld de,00405h		;8934
	exx			;8937
	ld bc,04806h		;8938   ; y el de detras, patron 0x48
	ld de,00000h		;893b
	exx			;893e
L_893F:
	ld a,00ah		;893f   ; diez trozos
	ld (0e3bah),a		;8941
	ld hl,0e320h		;8944
	exx			;8947
	ld hl,0e320h		;8948
	exx			;894b
	ld ix,08999h		;894c   ; los desplazamientos de la tabla de 0x8999
L_8950:
	ld a,(0e3d3h)		;8950   ; la fila del jefe mas el desplazamiento
	add a,(ix+000h)		;8953
	add a,e			;8956
	ld (hl),a			;8957
	inc hl			;8958
	ld a,(0e3d5h)		;8959   ; y la columna
	add a,(ix+001h)		;895c
	add a,d			;895f
	ld (hl),a			;8960
	inc hl			;8961
	ld (hl),b			;8962   ; con su patron y su color
	inc hl			;8963
	ld (hl),c			;8964
	inc hl			;8965
	exx			;8966
	inc hl			;8967
	inc hl			;8968
	inc hl			;8969
	inc hl			;896a
	inc ix		;896b
	inc ix		;896d
	ld a,(0e3bah)		;896f
	dec a			;8972
	ld (0e3bah),a		;8973
	jr nz,L_8950		;8976
	ret			;8978
monta_diez_trozos_del_cuerpo:
	ld bc,04c0ah		;8979   ; patron 0x4C, color 0x0A
	ld de,00208h		;897c
	exx			;897f
	ld bc,05006h		;8980   ; y el de detras, patron 0x50
	ld de,00000h		;8983
	exx			;8986
	jr L_893F		;8987
monta_diez_trozos_de_la_cola:
	ld bc,05406h		;8989   ; patron 0x54
	ld de,00000h		;898c
	exx			;898f
	ld bc,0ff00h		;8990   ; y el segundo, apagado
	ld de,00000h		;8993
	exx			;8996
	jr L_893F		;8997

; ----------------------------------------------------------------------
; DATOS tabla_de_0x894C: La carga con `ld ix`
;   0x8999..0x89ad  (20 bytes)
DATA_tabla_de_0x894C:
	defb 000h,000h,000h,000h	; 8999
	defb 008h,0f0h,008h,0f0h	; 899d
	defb 012h,010h,012h,010h	; 89a1
	defb 01ah,014h,01ah,014h	; 89a5
	defb 01fh,0fah,01fh,0fah	; 89a9

; ======================================================================
; CODIGO 0x89ad..0x8aa6  (249 bytes)
; ======================================================================


monta_los_sprites_del_jefe:
	ld ix,0e3d0h		;89ad
	ld de,0e320h		;89b1
L_89B4:
	ld a,(ix+003h)		;89b4   ; la fila del jefe mas el desplazamiento
	add a,(hl)			;89b7
	ld (de),a			;89b8
	inc hl			;89b9
	inc de			;89ba
	ld a,(ix+005h)		;89bb   ; la columna
	add a,(hl)			;89be
	ld (de),a			;89bf
	inc hl			;89c0
	inc de			;89c1
	ld a,(hl)			;89c2   ; el patron
	ld (de),a			;89c3
	inc hl			;89c4
	inc de			;89c5
	ld a,(hl)			;89c6   ; y el color
	ld (de),a			;89c7
	inc hl			;89c8
	inc de			;89c9
	djnz L_89B4		;89ca
	ret			;89cc

; ----------------------------------------------------------------------
; MOVER AL JEFE. La posicion va en 8.8 y el paso se saca multiplicando
; la distancia que le falta por su velocidad: por eso se acerca
; frenando.
; ----------------------------------------------------------------------
mueve_al_jefe:
	ld hl,(0e3b7h)		;89cd
	ld a,(0e3d3h)		;89d0   ; lo que le falta en horizontal
	sub l			;89d3
	neg		;89d4
	ld (0e3b6h),a		;89d6
	ld h,a			;89d9
	ld a,(0e3b3h)		;89da   ; por su velocidad
	ld e,a			;89dd
	call multiplica_con_signo		;89de
	ld de,(0e3d6h)		;89e1   ; sumado al paso...
	add hl,de			;89e5
	ld (0e3d6h),hl		;89e6
	ld de,(0e3d2h)		;89e9   ; ...y el paso a la posicion
	add hl,de			;89ed
	ld (0e3d2h),hl		;89ee
	ld hl,(0e3b7h)		;89f1
	ld a,(0e3d5h)		;89f4   ; y lo mismo en vertical
	sub h			;89f7
	neg		;89f8
	ld (0e3b5h),a		;89fa
	ld h,a			;89fd
	ld a,(0e3b4h)		;89fe
	ld e,a			;8a01
	call multiplica_con_signo		;8a02
	ld de,(0e3d8h)		;8a05
	add hl,de			;8a09
	ld (0e3d8h),hl		;8a0a
	ld de,(0e3d4h)		;8a0d
	add hl,de			;8a11
	ld (0e3d4h),hl		;8a12
	ret			;8a15
multiplica_con_signo:
	bit 7,h		;8a16   ; con el multiplicando negativo
	jp z,multiplica_h_por_e		;8a18
	ld a,h			;8a1b
	neg		;8a1c   ; se hace positivo, se multiplica y se niega el resultado
	ld h,a			;8a1e
	call multiplica_h_por_e		;8a1f
	ld a,l			;8a22
	cpl			;8a23
	ld l,a			;8a24
	ld a,h			;8a25
	cpl			;8a26
	ld h,a			;8a27
	inc hl			;8a28
	ret			;8a29
monta_los_sprites_de_los_trozos:
	ld de,0e358h		;8a2a
	ld hl,0e200h		;8a2d
	exx			;8a30
	ld b,00ah		;8a31   ; los diez trozos
L_8A33:
	exx			;8a33
	ld a,(hl)			;8a34   ; el estado del trozo
	and a			;8a35   ; el trozo apagado se aparca en la fila 0xE0
	jr nz,L_8A43		;8a36
	ld a,0e0h		;8a38
	ld (de),a			;8a3a
	inc e			;8a3b   ; saltando su patron y su color
	inc e			;8a3c
	inc e			;8a3d
	inc e			;8a3e
	ld a,010h		;8a3f
	jr L_8A55		;8a41
L_8A43:
	inc l			;8a43
	inc l			;8a44
	inc l			;8a45
	ldi		;8a46   ; y el vivo copia su fila, su columna, su patron y su color
	inc l			;8a48
	ldi		;8a49   ; el patron
	inc l			;8a4b
	inc l			;8a4c
	inc l			;8a4d
	inc l			;8a4e
	ldi		;8a4f
	ldi		;8a51
	ld a,004h		;8a53
L_8A55:
	call suma_a_a_hl		;8a55
	exx			;8a58
	djnz L_8A33		;8a59
	ret			;8a5b
mueve_los_trozos:
	ld ix,0e200h		;8a5c
	ld b,00ah		;8a60
L_8A62:
	push bc			;8a62
	ld a,(ix+000h)		;8a63   ; solo los del estado 1
	dec a			;8a66
	call z,mueve_al_bicho		;8a67
	pop bc			;8a6a
	ld de,00010h		;8a6b   ; y al siguiente, 0x10 mas alla
	add ix,de		;8a6e
	djnz L_8A62		;8a70
	ret			;8a72
multiplica_h_por_e:
	ld l,000h		;8a73
	ld d,l			;8a75
	ld b,008h		;8a76   ; ocho vueltas de doblar y sumar
L_8A78:
	add hl,hl			;8a78
	jr nc,L_8A7C		;8a79
	add hl,de			;8a7b
L_8A7C:
	djnz L_8A78		;8a7c
	sra h		;8a7e   ; y el resultado, partido por ocho
	rr l		;8a80
	sra h		;8a82
	rr l		;8a84
	sra h		;8a86
	rr l		;8a88
	ret			;8a8a
baja_el_reloj_del_jefe:
	ld hl,(0e3b1h)		;8a8b
	dec hl			;8a8e   ; un cuadro menos de jefe
	ld (0e3b1h),hl		;8a8f
	ld a,l			;8a92
	or h			;8a93
	ret			;8a94

; ----------------------------------------------------------------------
; EL JEFE DE LAS FASES 0, 4 y 5. Siete estados en la tabla de 0x8AA6.
; ----------------------------------------------------------------------
jefe_de_las_fases_0_4_y_5:
	ld a,(0e3b0h)		;8a95
	dec a			;8a98
	ret m			;8a99   ; estado 0: no hay jefe
	cp 002h		;8a9a   ; en el estado 2 ademas se pinta la barra de vida
	jr nz,L_8AA3		;8a9c
	push af			;8a9e
	call pinta_el_cuadro_del_jefe		;8a9f
	pop af			;8aa2
L_8AA3:
	call reparte_por_tabla		;8aa3

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_8AA6: 7 entradas; tras el `call 406Ch` de 0x8AA3;
;   sigue en 0x8AB4
;   0x8aa6..0x8ab4  (14 bytes)
DATA_tabla_de_reparto_8AA6:
	defw 08ab4h,08afah,08b1bh,08bb0h,092ach,092c3h,092d2h	; 8aa6

; ======================================================================
; CODIGO 0x8ab4..0x8c14  (352 bytes)
; ======================================================================


jefe_1_monta:
	ld hl,0e3d0h		;8ab4   ; borra sus 0x40 bytes de variables
	ld de,0e3d1h		;8ab7
	ld bc,0003fh		;8aba
	ld (hl),000h		;8abd
	ldir		;8abf
	ld a,0d8h		;8ac1   ; y lo pone en la fila 0xD8, columna 0x70
	ld (0e3d3h),a		;8ac3
	ld a,070h		;8ac6
	ld (0e3d5h),a		;8ac8
	ld a,(0e065h)		;8acb
	ld hl,08c14h		;8ace   ; su variante, de la tabla de 0x8C14
	call suma_a_a_hl		;8ad1
	ld a,(hl)			;8ad4
	ld (0e3e0h),a		;8ad5
	ld hl,08c1ch		;8ad8   ; y su reloj, de la de 0x8C1C
	call palabra_de_tabla_en_hl		;8adb
	ld (0e3b1h),hl		;8ade
	ld a,080h		;8ae1
	ld (0e3f0h),a		;8ae3
jefe_1_sube_sus_patrones:
	ld de,0af73h		;8ae6   ; ocho patrones a 0x1CC0
	ld hl,01cc0h		;8ae9
	call descomprime		;8aec
	ld de,0ad17h		;8aef   ; y tres mas a 0x1E00
	ld hl,01e00h		;8af2
	call descomprime		;8af5
	jr L_8B13		;8af8
jefe_1_entra:
	ld a,(0e090h)		;8afa
	and 03fh		;8afd   ; uno de cada 64 cuadros
	cp 001h		;8aff
	ret nz			;8b01
	ld hl,0e3d3h		;8b02   ; sube ocho pixeles
	ld a,(hl)			;8b05
	add a,008h		;8b06
	ld (hl),a			;8b08
	ret m			;8b09
	cp 020h		;8b0a   ; hasta la fila 0x20
	ret c			;8b0c
	call monta_el_decorado_del_jefe		;8b0d
	call jefe_1_elige_a_donde_va		;8b10
L_8B13:
	jp sube_de_estado_al_jefe		;8b13
jefe_1_a_morirse:
	ld a,004h		;8b16
	jp L_8904		;8b18
jefe_1_pelea:
	call baja_el_reloj_del_jefe		;8b1b   ; mientras le quede reloj
	jr z,jefe_1_a_morirse		;8b1e
	ld a,(0e090h)		;8b20
	bit 4,a		;8b23   ; el bit 4 del reloj alterna sus dos dibujos
	ld a,000h		;8b25
	jr z,L_8B2A		;8b27
	inc a			;8b29
L_8B2A:
	ld (0e3e1h),a		;8b2a
	call la_lengua_de_la_fase_5		;8b2d
	call el_rayo_de_la_fase_4		;8b30
	call los_tres_satelites		;8b33
	call espera_al_jefe		;8b36   ; y cuando le dan bastante, se muere
	jr nz,jefe_1_a_morirse		;8b39
	ld a,(0e3d3h)		;8b3b   ; su posicion, para la rafaga
	add a,00ch		;8b3e
	ld (0e583h),a		;8b40
	ld a,(0e3d5h)		;8b43
	add a,00ah		;8b46
	ld (0e585h),a		;8b48
	ld a,(0e003h)		;8b4b
	and 01fh		;8b4e   ; cada 32 cuadros suelta una
	jr nz,L_8B63		;8b50
	ld a,(0e3e0h)		;8b52
	ld hl,08c22h		;8b55   ; del tipo que diga la tabla de 0x8C22
	call suma_a_a_hl		;8b58
	ld b,(hl)			;8b5b
	ld ix,0e580h		;8b5c
	call suelta_una_rafaga		;8b60
L_8B63:
	ld hl,0e3dbh		;8b63
	ld a,(hl)			;8b66   ; con reloj de espera puesto, esperando
	or a			;8b67
	jr nz,jefe_1_espera		;8b68
	ld hl,(0e3d4h)		;8b6a   ; el paso horizontal
	ld a,h			;8b6d   ; redondeado a cuatro
	and 0fch		;8b6e
	add a,00ch		;8b70
	ld c,a			;8b72
	ld a,(0e3dah)		;8b73
	cp c			;8b76   ; al llegar a su sitio
	jr z,L_8BA6		;8b77
	ld de,(0e3d8h)		;8b79
	add hl,de			;8b7d
	ld (0e3d4h),hl		;8b7e
	ld a,h			;8b81
	cp 020h		;8b82   ; topado entre la columna 0x20 y la 0xBF
	ld h,020h		;8b84
	ld e,050h		;8b86
	jr c,L_8B91		;8b88
	cp 0bfh		;8b8a
	ld h,0bfh		;8b8c
	ld e,088h		;8b8e
	ret c			;8b90
L_8B91:
	ld (0e3d4h),hl		;8b91
	ld a,(0e065h)		;8b94   ; la fase 0 se queda quieta al llegar
	cp 000h		;8b97
	jr z,L_8BA6		;8b99
	ld a,d			;8b9b   ; y las demas rebotan
	neg		;8b9c
	ld (0e3d9h),a		;8b9e
	ld a,e			;8ba1
	ld (0e3dah),a		;8ba2
	ret			;8ba5
L_8BA6:
	ld a,050h		;8ba6   ; y al llegar al sitio, 0x50 cuadros parado
	ld (0e3dbh),a		;8ba8
	ret			;8bab
jefe_1_espera:
	dec (hl)			;8bac
	ret nz			;8bad
	jr jefe_1_elige_a_donde_va		;8bae
jefe_1_muriendose:
	ld a,(0e065h)		;8bb0
	cp 005h		;8bb3   ; la fase 5 tiene lo suyo
	jr nz,L_8BBF		;8bb5
	ld hl,0e3f0h		;8bb7
	bit 7,(hl)		;8bba
	call z,la_lengua_crece		;8bbc
L_8BBF:
	call parpadea_el_borde		;8bbf
	ld hl,0e3b1h		;8bc2
	dec (hl)			;8bc5
	ret nz			;8bc6
	ld (hl),030h		;8bc7   ; 0x30 cuadros de agonia
	call vuelca_la_banda_de_arriba		;8bc9
	ld a,(0e3d5h)		;8bcc
	add a,012h		;8bcf   ; y se hunde 0x12 pixeles
	ld (0e3d5h),a		;8bd1
	jp apaga_el_borde_y_suena_el_remate		;8bd4
jefe_1_elige_a_donde_va:
	ld a,(0e604h)		;8bd7   ; la columna del muneco, redondeada a cuatro
	and 0fch		;8bda
	ld b,a			;8bdc
	ld a,(0e3d5h)		;8bdd
	and 0fch		;8be0
	add a,00ch		;8be2
	cp b			;8be4   ; y se le persigue por arriba o por abajo
	ld hl,00000h		;8be5
	jr z,L_8BF0		;8be8
	ld h,001h		;8bea
	jr c,L_8BF0		;8bec
	ld h,0ffh		;8bee
L_8BF0:
	ld a,(0e065h)		;8bf0
	cp 000h		;8bf3   ; la fase 0 puede quedarse quieta
	jr z,L_8BFD		;8bf5
	ld a,h			;8bf7   ; las demas, no
	or a			;8bf8
	jr nz,L_8BFD		;8bf9
	ld h,001h		;8bfb
L_8BFD:
	ld (0e3d8h),hl		;8bfd
	inc h			;8c00   ; el signo, subido a 1 o 2
	ld a,(0e3e0h)		;8c01   ; y la variante del jefe, por tres
	ld c,a			;8c04
	add a,a			;8c05
	add a,c			;8c06
	add a,h			;8c07
	ld hl,08c25h		;8c08   ; el destino sale de la tabla de 0x8C25, tres por variante
	call suma_a_a_hl		;8c0b
	ld a,(hl)			;8c0e
	add a,b			;8c0f
	ld (0e3dah),a		;8c10
	ret			;8c13

; ----------------------------------------------------------------------
; DATOS tabla_de_0x8ACE: La leen 0x8ACE, 0x8AD8, 0x8B55 y 0x8C08
;   0x8c14..0x8c2e  (26 bytes)
DATA_tabla_de_0x8ACE:
	defb 000h,000h,000h,000h,001h,002h,000h,000h,010h,00eh,020h,01ch,020h	; 8c14  .......... . 
	defb 01ch,008h,00ch,00dh,000h,000h,000h,0e0h,010h,020h,0d0h,010h,030h	; 8c21  ......... ..0

; ======================================================================
; CODIGO 0x8c2e..0x8cbf  (145 bytes)
; ======================================================================


los_tres_satelites:
	ld a,(0e065h)		;8c2e
	cp 000h		;8c31   ; solo el jefe de la fase 0 los tiene
	ret nz			;8c33
L_8C34:
	ld a,(0e090h)		;8c34
	rra			;8c37   ; uno de cada dos cuadros
	ret c			;8c38
	ld ix,0e590h		;8c39   ; tres, de 0x20 en 0x20 desde 0xE590
	ld b,003h		;8c3d
L_8C3F:
	ld hl,08cbfh		;8c3f   ; su reloj, con la mascara de 0x8CBF: 0x55, 0xAA y 0xFF
	ld a,b			;8c42
	call suma_a_a_hl		;8c43
	ld c,(hl)			;8c46
	inc (ix+018h)		;8c47
	ld a,(ix+018h)		;8c4a
	cp c			;8c4d
	jr nz,L_8C6E		;8c4e
	ld a,(ix+000h)		;8c50
	or a			;8c53
	jr nz,L_8C6E		;8c54
	ld (ix+000h),001h		;8c56   ; y sale como bicho del tipo 0x0C
	ld (ix+001h),00ch		;8c5a
	ld (ix+003h),010h		;8c5e
	ld hl,0e666h		;8c62
	inc (hl)			;8c65
	ld a,(hl)			;8c66
	and 001h		;8c67
	add a,07fh		;8c69   ; y entra por el lado que toque
	ld (ix+005h),a		;8c6b
L_8C6E:
	push bc			;8c6e
	ld a,(ix+001h)		;8c6f
	call L_75EA		;8c72   ; se mueve como un bicho cualquiera
	call le_dan_los_disparos		;8c75
	call toca_al_muneco		;8c78
	pop bc			;8c7b
	ld a,b			;8c7c
	exx			;8c7d
	add a,a			;8c7e
	add a,a			;8c7f
	add a,a			;8c80
	ld de,0e338h		;8c81
	call suma_a_a_de		;8c84
	ld a,(ix+00ah)		;8c87
	cp 01ch		;8c8a   ; el sprite 0x1C tiene su pareja en 0x7896 y los demas en 0x789E
	ld hl,07896h		;8c8c
	jr z,L_8C94		;8c8f
	ld hl,0789eh		;8c91
L_8C94:
	ld b,002h		;8c94
L_8C96:
	ld a,(ix+000h)		;8c96
	or a			;8c99
	ld a,(ix+003h)		;8c9a
	jr nz,L_8CA1		;8c9d
	ld a,0cah		;8c9f   ; apagado, se aparca en la fila 0xCA
L_8CA1:
	add a,(hl)			;8ca1   ; la fila del satelite
	ld (de),a			;8ca2
	inc hl			;8ca3
	inc de			;8ca4
	ld a,(ix+005h)		;8ca5   ; y su columna
	add a,(hl)			;8ca8
	ld (de),a			;8ca9
	inc hl			;8caa
	inc de			;8cab
	ld a,(hl)			;8cac
	add a,0c0h		;8cad   ; y el patron va 0xC0 mas alla
	ld (de),a			;8caf
	inc hl			;8cb0
	inc de			;8cb1
	ldi		;8cb2
	djnz L_8C96		;8cb4
	exx			;8cb6
	ld de,00020h		;8cb7
	add ix,de		;8cba
	djnz L_8C3F		;8cbc
	ret			;8cbe

; ----------------------------------------------------------------------
; DATOS tres_mascaras: 0x55, 0xAA y 0xFF; las lee 0x8C3F
;   0x8cbf..0x8cc2  (3 bytes)
DATA_tres_mascaras:
	defb 055h,0aah,0ffh	; 8cbf

; ======================================================================
; CODIGO 0x8cc2..0x8daf  (237 bytes)
; ======================================================================


el_rayo_de_la_fase_4:
	ld a,(0e065h)		;8cc2
	cp 004h		;8cc5   ; solo la fase 4
	ret nz			;8cc7
	ld hl,0e3e2h		;8cc8
	ld a,(0e090h)		;8ccb
	and 07fh		;8cce   ; cada 128 cuadros cambia
	jr nz,L_8CD3		;8cd0
	inc (hl)			;8cd2
L_8CD3:
	bit 0,(hl)		;8cd3
	ret z			;8cd5
	or a			;8cd6
	jr nz,L_8CDE		;8cd7
	ld a,047h		;8cd9   ; con su sonido
	call pide_pieza_si_la_escena_lo_permite		;8cdb
L_8CDE:
	ld de,0bf4ah		;8cde   ; y pinta el cuadro de tres por tres de 0xBF4A encima del jefe
	ld bc,00303h		;8ce1
	ld a,(0e3d3h)		;8ce4
	add a,008h		;8ce7
	ld l,a			;8ce9
	ld a,(0e3d5h)		;8cea
	add a,008h		;8ced
	ld h,a			;8cef
	jp pinta_un_bloque_de_casillas		;8cf0
la_lengua_de_la_fase_5:
	ld a,(0e065h)		;8cf3
	cp 005h		;8cf6   ; solo la fase 5
	ret nz			;8cf8
	ld hl,0e3f0h		;8cf9
	bit 7,(hl)		;8cfc
	jr nz,la_lengua_pega		;8cfe
la_lengua_crece:
	inc hl			;8d00
	inc (hl)			;8d01   ; el largo de la lengua
	ld a,(hl)			;8d02
	inc hl			;8d03
	and 003h		;8d04
	jr nz,L_8D09		;8d06
	inc (hl)			;8d08
L_8D09:
	ld a,(hl)			;8d09
	inc hl			;8d0a
	ld de,08e14h		;8d0b   ; las casillas de la tabla de 0x8E14
	ld b,a			;8d0e
	cp 011h		;8d0f
	jr nc,L_8D4C		;8d11
	sub 010h		;8d13
	neg		;8d15
	add a,a			;8d17
	call suma_a_a_de		;8d18
	ld c,002h		;8d1b
	ld h,(hl)			;8d1d
	ld l,050h		;8d1e   ; se pintan en la columna 0x50
	call pinta_un_bloque_de_casillas		;8d20
	jr mira_si_el_muneco_toca_la_lengua		;8d23
la_lengua_pega:
	ld a,(0e604h)		;8d25
	ld b,a			;8d28
	ld a,(0e3d5h)		;8d29
	add a,01ah		;8d2c   ; si el muneco esta debajo
	sub b			;8d2e
	cp 005h		;8d2f
	jr c,L_8D39		;8d31
	ld a,(0e003h)		;8d33
	and 07fh		;8d36
	ret nz			;8d38
L_8D39:
	xor a			;8d39
	ld (hl),a			;8d3a
	inc a			;8d3b
	ld (0e3f2h),a		;8d3c   ; se le engancha
	ld a,(0e3d5h)		;8d3f
	add a,018h		;8d42
	ld (0e3f3h),a		;8d44
	ld a,05ah		;8d47   ; con su sonido
	jp pide_pieza_si_la_escena_lo_permite		;8d49
L_8D4C:
	cp 015h		;8d4c   ; pasado el 0x15, la lengua se ha estirado del todo
	jr c,mira_si_el_muneco_toca_la_lengua		;8d4e
	ld hl,0e3f0h		;8d50   ; y queda marcada
	set 7,(hl)		;8d53
	ld hl,03940h		;8d55   ; se borra la fila 0x3940
	call abre_para_escribir		;8d58
	exx			;8d5b
	ld hl,0e9e0h		;8d5c
	ld b,000h		;8d5f
	call L_8DC3		;8d61
	ld b,080h		;8d64
	jr $+93		;8d66
mira_si_el_muneco_toca_la_lengua:
	ld a,(0e600h)		;8d68
	cp 002h		;8d6b
	ret nc			;8d6d
	ld hl,0e610h		;8d6e   ; las seis casillas de alrededor del muneco
	ld b,006h		;8d71
L_8D73:
	ld a,(hl)			;8d73
	sub 06bh		;8d74   ; las de 0x6B a 0x74 -y las mismas 0x60 mas alla- son la lengua
	cp 00ah		;8d76
	jr c,L_8D84		;8d78
	sub 060h		;8d7a
	cp 00ah		;8d7c
	jr c,L_8D84		;8d7e
	inc hl			;8d80
	djnz L_8D73		;8d81
	ret			;8d83
L_8D84:
	jp mata_al_muneco		;8d84
monta_el_decorado_del_jefe:
	ld a,(0e065h)		;8d87
	ld hl,08dafh		;8d8a   ; el bloque de esta fase, de la tabla de 0x8DAF
	call suma_a_a_hl		;8d8d
	ld a,(hl)			;8d90
	inc a			;8d91   ; un 0xFF quiere decir que esta fase no lo tiene
	ret z			;8d92
	push hl			;8d93
	pop ix		;8d94
	ld iy,0e08ah		;8d96
	ld (iy+000h),000h		;8d9a
	ld hl,0e92ch		;8d9e   ; dos bandas de dos filas, arriba y 0x78 mas abajo
	ld c,002h		;8da1
	call L_6529		;8da3
	ld de,00078h		;8da6
	add hl,de			;8da9
	ld c,002h		;8daa
	jp L_6529		;8dac

; ----------------------------------------------------------------------
; DATOS ocho_bytes_de_0x8D8A: El bloque de decorado del jefe de cada fase, o
;   0xFF si esa fase no lo tiene; 0x8D8A indexa con (0xE065)
;   0x8daf..0x8db7  (8 bytes)
DATA_ocho_bytes_de_0x8D8A:
	defb 000h,0ffh,0ffh,0ffh,01ah,000h,0ffh,010h	; 8daf  ........

; ======================================================================
; CODIGO 0x8db7..0x8e14  (93 bytes)
; ======================================================================


vuelca_la_banda_de_arriba:
	ld hl,03880h		;8db7
	call abre_para_escribir		;8dba
	exx			;8dbd
	ld hl,0e920h		;8dbe
	ld b,0c0h		;8dc1
L_8DC3:
	jp vuelca_256_casillas		;8dc3
pinta_el_cuadro_del_jefe:
	call vuelca_la_banda_de_arriba		;8dc6
	ld a,(0e3d3h)		;8dc9   ; su fila y su columna
	ld l,a			;8dcc
	ld a,(0e3d5h)		;8dcd
	ld h,a			;8dd0
pinta_el_cuadro:
	push hl			;8dd1
	ld a,(0e3e0h)		;8dd2
	ld hl,0becch		;8dd5   ; el cuadro que toca, de la tabla de 0xBECC
	call palabra_de_tabla_en_hl		;8dd8
	ld a,(0e3e1h)		;8ddb
	call palabra_de_tabla_doble		;8dde
	pop hl			;8de1
	ld bc,00605h		;8de2   ; seis filas de cinco casillas
	ld a,(0e065h)		;8de5
	cp 007h		;8de8   ; la fase 7 pinta una columna mas
	jr nz,L_8DED		;8dea
	inc c			;8dec
L_8DED:
	or a			;8ded
	jr nz,pinta_un_bloque_de_casillas		;8dee
	dec b			;8df0
pinta_un_bloque_de_casillas:
	call de_pixeles_a_direccion		;8df1   ; de pixeles a direccion de VRAM
L_8DF4:
	push bc			;8df4
	ld b,c			;8df5
	call 00053h		;8df6   ; BIOS SETWRT - Enables VDP to write | una fila por vuelta
	ld a,(00007h)		;8df9
	ld c,a			;8dfc
	ex de,hl			;8dfd
	call L_8DC3		;8dfe
	ex de,hl			;8e01
	ld a,020h		;8e02   ; y a la fila siguiente
	call suma_a_a_hl		;8e04
	push hl			;8e07
	ld bc,03ac0h		;8e08   ; sin pasarse de 0x3AC0, que es donde acaba la pantalla
	or a			;8e0b
	sbc hl,bc		;8e0c
	pop hl			;8e0e
	pop bc			;8e0f
	ret nc			;8e10
	djnz L_8DF4		;8e11
	ret			;8e13

; ----------------------------------------------------------------------
; DATOS tabla_de_0x8D0B: Las parejas de casillas con las que crece la lengua
;   de la fase 5; 0x8D0B las indexa con lo estirada que este
;   0x8e14..0x8e34  (32 bytes)
DATA_tabla_de_0x8D0B:
	defb 06ch,0cbh	; 8e14
	defb 06bh,0cch	; 8e16
	defb 073h,0cbh	; 8e18
	defb 06bh,0d3h	; 8e1a
	defb 074h,0cbh	; 8e1c
	defb 06ch,0cch	; 8e1e
	defb 06ch,0cbh	; 8e20
	defb 06bh,0cch	; 8e22
	defb 073h,0cbh	; 8e24
	defb 06bh,0d3h	; 8e26
	defb 074h,0cbh	; 8e28
	defb 06ch,0cch	; 8e2a
	defb 075h,0d5h	; 8e2c
	defb 091h,0f1h	; 8e2e
	defb 092h,0f2h	; 8e30
	defb 093h,094h	; 8e32

; ======================================================================
; CODIGO 0x8e34..0x8e44  (16 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL JEFE DE LA FASE 1. Ocho estados en la tabla de 0x8E44.
; ----------------------------------------------------------------------
jefe_de_la_fase_1:
	ld a,(0e3b0h)		;8e34
	dec a			;8e37
	ret m			;8e38
	cp 004h		;8e39
	jr nc,L_8E41		;8e3b
	ld hl,0900ch		;8e3d   ; con los estados 1, 2 y 3 se empuja el remate de 0x900C
	push hl			;8e40
L_8E41:
	call reparte_por_tabla		;8e41

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_8E44: 8 entradas; tras el `call 406Ch` de 0x8E41;
;   sigue en 0x8E54
;   0x8e44..0x8e54  (16 bytes)
DATA_tabla_de_reparto_8E44:
	defw 08e54h,09238h,08e69h,08e75h,0928fh,092ach,092c3h,092d2h	; 8e44

; ======================================================================
; CODIGO 0x8e54..0x902d  (473 bytes)
; ======================================================================


jefe_2_monta:
	call monta_el_jefe_en_la_puerta		;8e54
jefe_2_sube_sus_patrones:
	ld de,0ad69h		;8e57   ; once patrones
	call descomprime_desde_la_palabra		;8e5a
	ld hl,01f80h		;8e5d
	ld de,0abdch		;8e60   ; y tres mas a 0x1F80
	call descomprime		;8e63
	jp sube_de_estado_al_jefe		;8e66
jefe_2_entra:
	ld hl,00140h		;8e69
	ld de,00180h		;8e6c
	ld bc,00e10h		;8e6f
	jp pon_los_datos_del_jefe		;8e72
jefe_2_pelea:
	call baja_el_reloj_del_jefe		;8e75
	jr z,jefe_2_se_muere		;8e78   ; al acabarse el reloj, se muere
	call mueve_al_jefe		;8e7a
	call haz_los_trozos_del_jefe_2		;8e7d
	call espera_al_jefe		;8e80
	jr nz,jefe_2_se_muere		;8e83
	call mueve_lo_que_solto_el_jefe		;8e85
	ld a,(0e003h)		;8e88   ; cada dieciseis cuadros suelta uno
	and 00fh		;8e8b
	ret nz			;8e8d
	ld b,a			;8e8e
	ld ix,0e3d0h		;8e8f
	jp suelta_algo_el_jefe_2		;8e93
jefe_2_se_muere:
	call arranca_al_jefe		;8e96
	ld hl,0e3d3h		;8e99
	ld a,(hl)			;8e9c
	sub 010h		;8e9d   ; y sube 0x10
	ld (hl),a			;8e9f
	pop hl			;8ea0
	ret			;8ea1
mueve_lo_que_solto_el_jefe:
	ld a,(0e600h)		;8ea2
	cp 002h		;8ea5   ; con el muneco muriendose, nada
	ret z			;8ea7
	ld ix,0e200h		;8ea8   ; las ocho ranuras de disparo del enemigo
	exx			;8eac
	ld b,008h		;8ead
L_8EAF:
	exx			;8eaf
	ld a,(ix+000h)		;8eb0   ; solo los del estado 1
	dec a			;8eb3
	jr nz,L_8EBC		;8eb4
	call L_8319		;8eb6   ; se mueven
	call le_dan_a_lo_que_solto		;8eb9
L_8EBC:
	exx			;8ebc
	ld de,00010h		;8ebd
	add ix,de		;8ec0
	djnz L_8EAF		;8ec2
	ret			;8ec4
le_dan_a_lo_que_solto:
	ld hl,0e620h		;8ec5   ; las tres ranuras de disparo del muneco
	ld b,003h		;8ec8
L_8ECA:
	push bc			;8eca
	ld a,(hl)			;8ecb   ; con el bit 7 puesto la ranura esta vacia
	rla			;8ecc
	jr c,L_8ED6		;8ecd
	push hl			;8ecf
	call toca_el_disparo_al_disparo_del_enemigo		;8ed0   ; y si toca
	pop hl			;8ed3
	jr nc,L_8EDE		;8ed4
L_8ED6:
	pop bc			;8ed6
	ld de,00010h		;8ed7
	add hl,de			;8eda
	djnz L_8ECA		;8edb
	ret			;8edd
L_8EDE:
	pop bc			;8ede
	pop bc			;8edf
	set 7,(hl)		;8ee0   ; tocado: el disparo se apaga
	ld (ix+000h),000h		;8ee2   ; y lo suyo tambien
	ld (ix+003h),0e0h		;8ee6
	ret			;8eea
suelta_algo_el_jefe_2:
	ld hl,0e200h		;8eeb   ; busca ranura libre entre las cinco primeras
	ld de,00010h		;8eee
	ld b,005h		;8ef1
L_8EF3:
	ld a,(hl)			;8ef3   ; busca ranura libre entre las cinco primeras
	and a			;8ef4
	jr z,L_8EFB		;8ef5
	add hl,de			;8ef7
	djnz L_8EF3		;8ef8
	ret			;8efa
L_8EFB:
	ld (hl),001h		;8efb   ; tipo 6
	inc hl			;8efd
	ld (hl),006h		;8efe
	inc hl			;8f00
	inc hl			;8f01
	ld a,(0e3d3h)		;8f02   ; sale 0x10 debajo del jefe
	add a,010h		;8f05
	ld (hl),a			;8f07
	inc hl			;8f08
	inc hl			;8f09
	ld a,(0e3d5h)		;8f0a
	add a,004h		;8f0d
	ld (hl),a			;8f0f
	push af			;8f10
	inc hl			;8f11
	ld (hl),000h		;8f12
	inc hl			;8f14
	ld (hl),000h		;8f15
	inc hl			;8f17
	ld de,00180h		;8f18
	pop af			;8f1b
	ld c,a			;8f1c
	ld a,(0e3cfh)		;8f1d   ; y con el bit 1 de (0xE3CF) apunta al muneco
	and 002h		;8f20
	call z,niega_de		;8f22
	ld (hl),e			;8f25
	inc hl			;8f26
	ld (hl),d			;8f27
	inc hl			;8f28
	ld (hl),07ch		;8f29
	inc hl			;8f2b
	ld (hl),00fh		;8f2c   ; color 0x0F, patron 0x64
	inc hl			;8f2e
	ld (hl),064h		;8f2f
	inc hl			;8f31
	ld (hl),c			;8f32
	inc hl			;8f33
	ld (hl),000h		;8f34
	ld hl,0e3cfh		;8f36   ; y la cuenta que decide si apunta o no
	inc (hl)			;8f39
	ret			;8f3a
niega_de:
	ld a,e			;8f3b   ; se niega DE: el paso, al reves
	cpl			;8f3c
	ld e,a			;8f3d
	ld a,d			;8f3e
	cpl			;8f3f
	ld d,a			;8f40
	inc de			;8f41
	ret			;8f42
haz_los_trozos_del_jefe_2:
	call mueve_lo_que_solto_el_jefe_2		;8f43
	call mueve_los_trozos		;8f46
	call mira_si_lo_que_solto_vuelve_al_jefe		;8f49
	jp monta_los_sprites_de_los_trozos		;8f4c
mueve_lo_que_solto_el_jefe_2:
	ld ix,0e200h		;8f4f
	ld b,008h		;8f53   ; las ocho ranuras
L_8F55:
	ld a,(ix+000h)		;8f55
	and a			;8f58
	jr z,L_8FBD		;8f59
	ld a,(ix+00ch)		;8f5b   ; cuando llega a su columna...
	sub (ix+003h)		;8f5e
	or a			;8f61
	jr nz,L_8F67		;8f62
	inc (ix+00eh)		;8f64   ; ...sube de fase
L_8F67:
	ld e,(ix+006h)		;8f67
	ld d,(ix+007h)		;8f6a
	call frena_el_paso		;8f6d   ; el paso horizontal, frenando
	ld (ix+006h),l		;8f70
	ld (ix+007h),h		;8f73
	xor a			;8f76
	bit 7,(ix+00eh)		;8f77
	jr nz,L_8F94		;8f7b
	ld a,(ix+00dh)		;8f7d   ; y el vertical, hasta engancharse
	sub (ix+005h)		;8f80
	ld c,a			;8f83
	or a			;8f84
	jr nz,L_8F94		;8f85
	ld a,(ix+00eh)		;8f87
	cp 002h		;8f8a
	ld a,c			;8f8c
	jr c,L_8F94		;8f8d
	set 7,(ix+00eh)		;8f8f
	xor a			;8f93
L_8F94:
	ld e,(ix+008h)		;8f94
	ld d,(ix+009h)		;8f97
	call frena_el_paso		;8f9a
	ld (ix+008h),l		;8f9d
	ld (ix+009h),h		;8fa0
	ld hl,0e020h		;8fa3   ; su sonido, si la voz esta libre
	ld a,01bh		;8fa6
	cp (hl)			;8fa8
	call nz,pide_pieza_si_la_escena_lo_permite		;8fa9
	ld a,(ix+000h)		;8fac
	cp 002h		;8faf
	jr z,L_8FBD		;8fb1
	ld a,(0e003h)		;8fb3   ; y su fotograma, uno de cada cuatro cuadros
	and 00ch		;8fb6
	add a,07ch		;8fb8
	ld (ix+00ah),a		;8fba
L_8FBD:
	ld de,00010h		;8fbd
	add ix,de		;8fc0
	djnz L_8F55		;8fc2
	ret			;8fc4
frena_el_paso:
	sra a		;8fc5   ; la distancia partida por cuatro, con signo
	sra a		;8fc7
	ld l,a			;8fc9
	ld h,000h		;8fca
	add a,a			;8fcc
	jr nc,L_8FD0		;8fcd
	dec h			;8fcf
L_8FD0:
	add hl,de			;8fd0
	ret			;8fd1
mira_si_lo_que_solto_vuelve_al_jefe:
	ld ix,0e200h		;8fd2
	ld b,008h		;8fd6
L_8FD8:
	ld a,(ix+000h)		;8fd8
	and a			;8fdb
	jr z,L_9004		;8fdc
	bit 7,(ix+007h)		;8fde   ; solo los que ya se engancharon
	jr z,L_9004		;8fe2
	ld a,(0e3d3h)		;8fe4   ; dentro de una caja de 0x38 por 0x50 alrededor del jefe
	sub (ix+003h)		;8fe7
	add a,018h		;8fea
	cp 038h		;8fec
	jr nc,L_9004		;8fee
	ld a,(0e3d5h)		;8ff0
	sub (ix+005h)		;8ff3
	add a,030h		;8ff6
	cp 050h		;8ff8
	jr nc,L_9004		;8ffa
	ld (ix+000h),000h		;8ffc   ; vuelve a entrar, y la ranura queda libre
	ld (ix+003h),0e0h		;9000
L_9004:
	ld de,00010h		;9004
	add ix,de		;9007
	djnz L_8FD8		;9009
	ret			;900b
pinta_al_jefe_2:
	ld hl,0902dh		;900c   ; sus siete sprites, de la tabla de 0x902D
	ld b,007h		;900f
	call monta_los_sprites_del_jefe		;9011
	call pon_las_tres_bolas		;9014   ; y las tres bolas
	ld a,(0e3d1h)		;9017   ; el color cambia con lo que le queda de vida: blanco, amarillo, cian
	ld c,00fh		;901a
	cp 00ah		;901c
	jr c,L_9028		;901e
	ld c,00ah		;9020
	cp 014h		;9022
	jr c,L_9028		;9024
	ld c,007h		;9026
L_9028:
	ld a,c			;9028
	ld (0e323h),a		;9029
	ret			;902c

; ----------------------------------------------------------------------
; DATOS tabla_de_0x900C: Siete sprites [dy][dx][patron][color]: el jefe de la
;   fase 1
;   0x902d..0x9049  (28 bytes)
DATA_tabla_de_0x900C:
	defb 000h,000h,060h,00fh	; 902d
	defb 0f0h,000h,064h,004h	; 9031
	defb 000h,0f5h,068h,004h	; 9035
	defb 000h,00ch,06ch,004h	; 9039
	defb 010h,0f5h,070h,004h	; 903d
	defb 010h,005h,074h,004h	; 9041
	defb 010h,015h,078h,004h	; 9045

; ======================================================================
; CODIGO 0x9049..0x90ac  (99 bytes)
; ======================================================================


pon_las_tres_bolas:
	ld hl,0e344h		;9049
	ld a,(0e3d3h)		;904c   ; la fila del jefe
	ld c,a			;904f
	ld a,(0e3d5h)		;9050
	sub 006h		;9053
	ld d,a			;9055
	ld b,000h		;9056
L_9058:
	ld a,c			;9058
	add a,028h		;9059   ; y 0x28 a su derecha
	ld e,a			;905b
	ld a,(0e065h)		;905c
	cp 003h		;905f   ; la fase 3 las pone 0x10 mas alla
	jr nz,L_9067		;9061
	ld a,e			;9063
	add a,010h		;9064
	ld e,a			;9066
L_9067:
	ld (hl),e			;9067
	ld a,(0e3b0h)		;9068   ; y a partir del estado 4 se clavan en la columna 0x48
	cp 004h		;906b
	jr c,L_907A		;906d
	ld (hl),048h		;906f
	ld a,(0e065h)		;9071
	cp 003h		;9074
	jr nz,L_907A		;9076
	ld (hl),058h		;9078
L_907A:
	inc l			;907a
	ld a,b			;907b   ; seis pixeles entre bola y bola
	add a,a			;907c
	ld e,a			;907d
	add a,a			;907e
	add a,e			;907f
	add a,d			;9080
	ld (hl),a			;9081
	inc l			;9082
	ld (hl),0f8h		;9083   ; patron 0xF8, color 1
	inc l			;9085
	ld (hl),001h		;9086
	inc l			;9088
	inc b			;9089
	ld a,b			;908a
	cp 003h		;908b
	jr c,L_9058		;908d
	ret			;908f

; ----------------------------------------------------------------------
; EL JEFE DE LA FASE 2. Otros ocho estados, en la tabla de 0x90AC.
; ----------------------------------------------------------------------
jefe_de_la_fase_2:
	ld a,(0e3c0h)		;9090
	or a			;9093   ; mientras no se le haya matado, tocarlo mata
	jr nz,L_909C		;9094
	call toca_el_jefe_3_al_muneco		;9096
	jp nc,mata_al_muneco		;9099
L_909C:
	ld a,(0e3b0h)		;909c
	dec a			;909f   ; estado 0: no hay jefe
	ret m			;90a0
	cp 004h		;90a1   ; con los estados 1, 2 y 3 se empuja el remate
	jr nc,L_90A9		;90a3
	ld hl,09156h		;90a5
	push hl			;90a8
L_90A9:
	call reparte_por_tabla		;90a9

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_90AC: 8 entradas; tras el `call 406Ch` de 0x90A9;
;   sigue en 0x90BC
;   0x90ac..0x90bc  (16 bytes)
DATA_tabla_de_reparto_90AC:
	defw 090bch,09238h,0924ch,090e5h,0928fh,092ach,092c3h,092d2h	; 90ac

; ======================================================================
; CODIGO 0x90bc..0x911c  (96 bytes)
; ======================================================================


jefe_3_monta:
	call monta_el_jefe_en_la_puerta		;90bc
jefe_3_sube_sus_patrones:
	ld hl,01c20h		;90bf   ; ocho patrones a 0x1C20
	ld de,0af73h		;90c2
	call descomprime		;90c5
	ld de,0b060h		;90c8   ; y ocho mas encima
	call descomprime_desde_la_palabra		;90cb
	ld hl,01ca0h		;90ce   ; seis, espejados, a 0x1D50
	ld de,01d50h		;90d1
	ld c,006h		;90d4
	call espeja_sprites		;90d6
	ld hl,01e00h		;90d9   ; y tres a 0x1E00
	ld de,0abdch		;90dc
	call descomprime		;90df
	jp sube_de_estado_al_jefe		;90e2
jefe_3_pelea:
	call baja_el_reloj_del_jefe		;90e5
	jp z,arranca_al_jefe		;90e8   ; al acabarse el reloj, se muere
	call mueve_al_jefe		;90eb
	call jefe_3_mira_si_le_han_dado		;90ee
	jp nz,arranca_al_jefe		;90f1
	ld a,(0e3e1h)		;90f4
	or a			;90f7
	ret nz			;90f8
	ld a,(0e003h)		;90f9   ; cada 32 cuadros suelta una rafaga del tipo 10
	and 01fh		;90fc
	ret nz			;90fe
	ld b,00ah		;90ff
	ld ix,0e3d0h		;9101
	jp suelta_una_rafaga		;9105
jefe_3_mira_si_le_han_dado:
	ld a,(0e3e1h)		;9108
	or a			;910b
	jr nz,L_9111		;910c
	jp espera_al_jefe		;910e
L_9111:
	ld hl,0911ch		;9111
	call le_dan_con_esta_caja		;9114
	ld a,(0e3bfh)		;9117
	or a			;911a
	ret			;911b

; ----------------------------------------------------------------------
; DATOS cuatro_bytes_de_0x9111: Los cuatro bytes de la caja del jefe de la
;   fase 2 con la boca cerrada
;   0x911c..0x9120  (4 bytes)
DATA_cuatro_bytes_de_0x9111:
	defb 003h,013h,0feh,01ah	; 911c

; ======================================================================
; CODIGO 0x9120..0x91b9  (153 bytes)
; ======================================================================


toca_el_jefe_3_al_muneco:
	ld a,(0e3d3h)		;9120
	add a,002h		;9123   ; su caja, dos pixeles dentro
	ld l,a			;9125
	ld a,(0e3d5h)		;9126
	sub 003h		;9129
	ld h,a			;912b
	ld a,(0e3e1h)		;912c   ; con la boca abierta es una caja de 0x18 por 0x16
	or a			;912f
	jr z,L_9138		;9130
	ld bc,01816h		;9132
	jp L_8761		;9135
L_9138:
	dec l			;9138   ; y cerrada, dos: la cabeza...
	ld a,h			;9139
	sub 009h		;913a
	ld h,a			;913c
	ld bc,00e28h		;913d
	call L_8761		;9140
	ret nc			;9143
	ld a,(0e3d3h)		;9144   ; ...y el cuerpo
	add a,00eh		;9147
	ld l,a			;9149
	ld a,(0e3d5h)		;914a
	sub 004h		;914d
	ld h,a			;914f
	ld bc,0100fh		;9150
	jp L_8761		;9153
pinta_al_jefe_3:
	ld a,(0e3b0h)		;9156
	cp 004h		;9159   ; a partir del estado 4 vale el juego de sprites de 0x91E9
	ld de,091e9h		;915b
	jr c,L_9180		;915e
	ld hl,0e3e0h		;9160
	inc (hl)			;9163   ; y si no, alterna cada 64 cuadros
	ld a,(hl)			;9164
	and 03fh		;9165
	jr nz,L_9170		;9167
	ld (hl),a			;9169
	inc hl			;916a
	ld a,001h		;916b
	xor (hl)			;916d
	ld (hl),a			;916e
	dec hl			;916f
L_9170:
	inc hl			;9170
	ld a,(hl)			;9171
	and a			;9172
	jr nz,L_9180		;9173
	dec hl			;9175
	bit 2,(hl)		;9176   ; entre el de 0x91B9 y el de 0x91D1
	ld de,091b9h		;9178
	jr z,L_9180		;917b
	ld de,091d1h		;917d
L_9180:
	ex de,hl			;9180
	ld b,006h		;9181   ; seis sprites
	call monta_los_sprites_del_jefe		;9183
	ld hl,0e338h		;9186   ; y la cola, 0x34 a la derecha
	ld a,(0e3d3h)		;9189
	add a,034h		;918c
	ld (hl),a			;918e
	ld a,(0e3b0h)		;918f
	cp 004h		;9192   ; clavada en 0x54 a partir del estado 4
	jr c,L_9198		;9194
	ld (hl),054h		;9196
L_9198:
	inc hl			;9198
	ld a,(0e3d5h)		;9199   ; la fila del jefe
	ld (hl),a			;919c
	inc hl			;919d
	ld (hl),0c8h		;919e   ; patron 0xC8, color 1
	inc hl			;91a0
	ld (hl),001h		;91a1
	ld a,(0e3d1h)		;91a3   ; su color cambia con la vida que le queda
	ld c,00fh		;91a6
	cp 00ah		;91a8
	jr c,L_91B4		;91aa
	ld c,00ah		;91ac
	cp 014h		;91ae
	jr c,L_91B4		;91b0
	ld c,005h		;91b2
L_91B4:
	ld a,c			;91b4
	ld (0e333h),a		;91b5
	ret			;91b8

; ----------------------------------------------------------------------
; DATOS tres_tramos_de_0x915B: Los leen 0x915B (0x91E9), 0x9178 y 0x917D
;   0x91b9..0x9201  (72 bytes)
DATA_tres_tramos_de_0x915B:
	defb 000h,000h,090h,001h	; 91b9
	defb 000h,0f3h,094h,001h	; 91bd
	defb 000h,00dh,0a8h,001h	; 91c1
	defb 010h,0f8h,098h,001h	; 91c5
	defb 009h,001h,08ch,00fh	; 91c9
	defb 010h,008h,0ach,001h	; 91cd
	defb 000h,000h,090h,001h	; 91d1
	defb 000h,0f3h,09ch,001h	; 91d5
	defb 000h,00dh,0b0h,001h	; 91d9
	defb 010h,0f8h,098h,001h	; 91dd
	defb 009h,001h,08ch,00fh	; 91e1
	defb 010h,008h,0ach,001h	; 91e5
	defb 003h,0f8h,0a0h,001h	; 91e9
	defb 003h,008h,0b4h,001h	; 91ed
	defb 013h,0f8h,0a4h,001h	; 91f1
	defb 013h,008h,0b8h,001h	; 91f5
	defb 009h,004h,088h,00fh	; 91f9
	defb 013h,008h,0b8h,001h	; 91fd

; ======================================================================
; CODIGO 0x9201..0x9211  (16 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL JEFE DE LA FASE 3. Los mismos ocho estados, en 0x9211.
; ----------------------------------------------------------------------
jefe_de_la_fase_3:
	ld a,(0e3b0h)		;9201
	dec a			;9204   ; estado 0: no hay jefe
	ret m			;9205
	cp 004h		;9206   ; y con los tres primeros, el remate de 0x9317
	jr nc,L_920E		;9208
	ld hl,09317h		;920a
	push hl			;920d
L_920E:
	call reparte_por_tabla		;920e

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_9211: 8 entradas; tras el `call 406Ch` de 0x920E;
;   sigue en 0x9221
;   0x9211..0x9221  (16 bytes)
DATA_tabla_de_reparto_9211:
	defw 09221h,09238h,0924ch,0926eh,0928fh,092ach,092c3h,092d2h	; 9211

; ======================================================================
; CODIGO 0x9221..0x9338  (279 bytes)
; ======================================================================


jefe_4_monta:
	call monta_el_jefe_en_la_puerta		;9221
jefe_4_sube_sus_patrones:
	ld de,0aea6h		;9224   ; diecisiete patrones
	call descomprime_desde_la_palabra		;9227
	ld hl,01f80h		;922a   ; y tres a 0x1F80
	ld de,0abdch		;922d
	call descomprime		;9230
sube_de_estado_al_jefe:
	ld hl,0e3b0h		;9233
	inc (hl)			;9236
	ret			;9237
jefe_entra_desde_abajo:
	ld a,(0e090h)		;9238
	and 03fh		;923b   ; uno de cada 64 cuadros
	dec a			;923d
	ret nz			;923e
	ld hl,0e3d3h		;923f
	ld a,(hl)			;9242
	add a,008h		;9243   ; sube ocho pixeles
	ld (hl),a			;9245
	ret m			;9246
	cp 020h		;9247   ; hasta la fila 0x20
	ret c			;9249
	jr sube_de_estado_al_jefe		;924a
jefe_arranca_con_estos_datos:
	ld hl,00208h		;924c
	ld de,00280h		;924f
	ld bc,01c20h		;9252
pon_los_datos_del_jefe:
	ld (0e3b3h),hl		;9255   ; la velocidad, el paso y el reloj
	ld (0e3d8h),de		;9258
	ld (0e3b1h),bc		;925c
	ld hl,00100h		;9260   ; y la posicion de partida
	ld (0e3d6h),hl		;9263
	ld hl,07820h		;9266
	ld (0e3b7h),hl		;9269
	jr sube_de_estado_al_jefe		;926c
jefe_4_pelea:
	call baja_el_reloj_del_jefe		;926e
	jp z,arranca_al_jefe		;9271   ; al acabarse el reloj, se muere
	call mueve_al_jefe		;9274   ; se mueve
	call haz_los_trozos_del_jefe_4		;9277   ; y sus trozos
	call espera_al_jefe		;927a
	jp nz,arranca_al_jefe		;927d
	ld a,(0e003h)		;9280   ; cada 32 cuadros, una rafaga del tipo 11
	and 01fh		;9283
	ret nz			;9285
	ld b,00bh		;9286
	ld ix,0e3d0h		;9288
	jp suelta_una_rafaga		;928c
jefe_muriendose_1:
	call parpadea_el_borde		;928f
	ld hl,0e3b1h		;9292   ; 0x30 cuadros
	dec (hl)			;9295
	ret nz			;9296
	ld (hl),030h		;9297
apaga_el_borde_y_suena_el_remate:
	ld b,0e0h		;9299   ; borde a cero
	call pon_registro_7		;929b
	ld a,06bh		;929e   ; y el sonido de que se ha acabado
	call pide_pieza_si_la_escena_lo_permite		;92a0
	ld bc,0005fh		;92a3   ; y se aparcan todos los sprites
	call aparca_sprites_bc		;92a6
	jp sube_de_estado_al_jefe		;92a9
jefe_muriendose_2:
	ld a,(0e003h)		;92ac   ; alternando cabeza y cuerpo cada ocho cuadros
	and 008h		;92af
	push af			;92b1
	call z,monta_diez_trozos_de_la_cabeza		;92b2
	pop af			;92b5
	call nz,monta_diez_trozos_del_cuerpo		;92b6
baja_el_reloj_y_sube_de_estado:
	ld hl,0e3b1h		;92b9
	dec (hl)			;92bc
	ret nz			;92bd
	ld (hl),030h		;92be
	jp sube_de_estado_al_jefe		;92c0
jefe_muriendose_3:
	ld a,(0e003h)		;92c3
	and 008h		;92c6   ; alternando cuerpo y cola cada ocho cuadros
	push af			;92c8
	call nz,monta_diez_trozos_del_cuerpo		;92c9
	pop af			;92cc
	call z,monta_diez_trozos_de_la_cola		;92cd
	jr baja_el_reloj_y_sube_de_estado		;92d0
jefe_muriendose_4:
	ld a,(0e003h)		;92d2
	and 008h		;92d5
	push af			;92d7
	call z,monta_diez_trozos_de_la_cola		;92d8
	pop af			;92db
	call nz,aparca_los_diez_sprites		;92dc
	ld hl,0e3b1h		;92df
	dec (hl)			;92e2
	ret nz			;92e3
	ld hl,0e3b0h		;92e4   ; y al acabar, se borran sus 0x40 bytes
	ld de,0e3b1h		;92e7
	ld bc,0003fh		;92ea
	ld (hl),000h		;92ed
	ldir		;92ef
	ld hl,0e660h		;92f1   ; y (0xE660) mata al muneco... o abre la puerta
	ld (hl),001h		;92f4
aparca_los_diez_sprites:
	ld bc,00027h		;92f6
aparca_sprites_bc:
	ld hl,0e320h		;92f9
	ld de,0e321h		;92fc
	ld (hl),0e0h		;92ff
	ldir		;9301
	ret			;9303
haz_los_trozos_del_jefe_4:
	ld a,(0e003h)		;9304   ; uno de cada dos cuadros
	rra			;9307
	call c,mueve_los_trozos		;9308
	call decide_cuando_sale_cada_trozo		;930b   ; se decide quien sale
	call apaga_los_trozos_gastados		;930e
	call mueve_los_trozos_del_jefe_4		;9311
	jp monta_los_sprites_de_los_trozos		;9314
pinta_al_jefe_4:
	ld hl,09338h		;9317   ; sus nueve sprites, de la tabla de 0x9338
	ld b,009h		;931a
	call monta_los_sprites_del_jefe		;931c
	call pon_las_tres_bolas		;931f
	ld a,(0e3d1h)		;9322   ; y el color, por la vida que le queda
	ld c,006h		;9325
	cp 00fh		;9327
	jr c,L_9333		;9329
	ld c,005h		;932b
	cp 01eh		;932d
	jr c,L_9333		;932f
	ld c,00eh		;9331
L_9333:
	ld a,c			;9333
	ld (0e323h),a		;9334
	ret			;9337

; ----------------------------------------------------------------------
; DATOS tabla_de_0x9317: Nueve sprites [dy][dx][patron][color]: el jefe de la
;   fase 3
;   0x9338..0x935c  (36 bytes)
DATA_tabla_de_0x9317:
	defb 0fch,000h,060h,008h	; 9338
	defb 0fch,0f6h,064h,00fh	; 933c
	defb 0fch,006h,068h,00fh	; 9340
	defb 00ch,0efh,06ch,00fh	; 9344
	defb 00ch,0ffh,070h,00fh	; 9348
	defb 00ch,00fh,074h,00fh	; 934c
	defb 01ch,0f1h,078h,00fh	; 9350
	defb 01ch,001h,07ch,00fh	; 9354
	defb 01ch,011h,080h,00fh	; 9358

; ======================================================================
; CODIGO 0x935c..0x9424  (200 bytes)
; ======================================================================


apaga_los_trozos_gastados:
	ld ix,0e200h		;935c
	ld de,00010h		;9360
	ld b,00bh		;9363
L_9365:
	ld a,(ix+000h)		;9365
	cp 002h		;9368   ; solo los del estado 2
	jr nz,L_9386		;936a
	bit 2,(ix+00ch)		;936c   ; su fotograma alterna con el bit 2 de la cuenta
	ld c,088h		;9370
	jr z,L_9376		;9372
	ld c,08ch		;9374
L_9376:
	ld (ix+00ah),c		;9376
	dec (ix+00ch)		;9379   ; y al acabarse, fuera
	jr nz,L_9386		;937c
	ld (ix+000h),000h		;937e
	ld (ix+003h),0e0h		;9382
L_9386:
	add ix,de		;9386
	djnz L_9365		;9388
	ret			;938a
decide_cuando_sale_cada_trozo:
	ld a,(0e602h)		;938b   ; la posicion del muneco
	ld l,a			;938e
	ld a,(0e604h)		;938f
	ld h,a			;9392
	ld ix,0e200h		;9393
	ld b,00ah		;9397
L_9399:
	ld a,(ix+000h)		;9399
	dec a			;939c
	jr nz,L_93C3		;939d
	ld a,(ix+00ch)		;939f
	and a			;93a2
	jr nz,al_trozo_le_toca_salir		;93a3
	ld a,(ix+003h)		;93a5   ; los que estan a mas de 0x28 por delante no salen
	sub l			;93a8
	add a,028h		;93a9
	jp m,L_93C3		;93ab
	ld a,r		;93ae   ; el registro R como numero al azar
	and 00fh		;93b0
	add a,008h		;93b2
	ld c,a			;93b4
	ld a,(ix+005h)		;93b5   ; mas la distancia vertical partida por dos: cuanto tarda en salir
	sub h			;93b8
	jr nc,L_93BD		;93b9
	neg		;93bb
L_93BD:
	sra a		;93bd
	add a,c			;93bf
	ld (ix+00ch),a		;93c0
L_93C3:
	ld de,00010h		;93c3
	add ix,de		;93c6
	djnz L_9399		;93c8
	ret			;93ca
al_trozo_le_toca_salir:
	dec (ix+00ch)		;93cb
	jr nz,L_93C3		;93ce
	ld (ix+000h),002h		;93d0   ; estado 2, tipo 0x0F, y 0x18 cuadros
	ld (ix+001h),00fh		;93d4
	ld (ix+00ch),018h		;93d8
	jr L_93C3		;93dc
mueve_los_trozos_del_jefe_4:
	ld a,(0e600h)		;93de
	cp 002h		;93e1
	ret z			;93e3
	ld ix,0e200h		;93e4
	ld b,008h		;93e8
L_93EA:
	exx			;93ea
	ld a,(ix+000h)		;93eb   ; solo los estados 1 y 2
	and a			;93ee
	jr z,L_93F8		;93ef
	cp 003h		;93f1
	jr nc,L_93F8		;93f3
	call L_8319		;93f5
L_93F8:
	exx			;93f8
	ld de,00010h		;93f9
	add ix,de		;93fc
	djnz L_93EA		;93fe
	ret			;9400
parpadea_el_borde:
	ld a,(0e003h)		;9401   ; entre negro y 0xEE cada dos cuadros
	ld b,0e0h		;9404
	and 002h		;9406
	jr z,L_940C		;9408
	ld b,0eeh		;940a
L_940C:
	jp pon_registro_7		;940c
monta_el_jefe_en_la_puerta:
	call borra_las_variables_del_jefe		;940f
	ld a,0d8h		;9412   ; fila 0xD8, columna 0x78
	ld (0e3d3h),a		;9414
	ld a,078h		;9417
	ld (0e3d5h),a		;9419
	ret			;941c

; ----------------------------------------------------------------------
; EL JEFE DE LAS FASES 6 y 7. Siete estados, en 0x9424.
; ----------------------------------------------------------------------
jefe_de_las_fases_6_y_7:
	ld a,(0e3b0h)		;941d
	dec a			;9420
	call reparte_por_tabla		;9421

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_9424: 7 entradas; tras el `call 406Ch` de 0x9421;
;   sigue en 0x9432
;   0x9424..0x9432  (14 bytes)
DATA_tabla_de_reparto_9424:
	defw 09432h,0944bh,09454h,0928fh,092ach,092c3h,092d2h	; 9424

; ======================================================================
; CODIGO 0x9432..0x94eb  (185 bytes)
; ======================================================================


jefe_5_monta:
	call borra_las_variables_del_jefe		;9432
jefe_5_sube_sus_patrones:
	ld de,0ab9dh		;9435   ; dos patrones a 0x1E00
	ld hl,01e00h		;9438
	call descomprime		;943b
	ld hl,01e00h		;943e   ; y su copia espejada
	ld de,01e90h		;9441
	ld c,004h		;9444
	call espeja_sprites		;9446
	jr L_9451		;9449
jefe_5_espera_al_techo:
	ld a,(0e091h)		;944b
	cp 0d8h		;944e   ; hasta la fila 0xD8 del tramo
	ret nz			;9450
L_9451:
	jp sube_de_estado_al_jefe		;9451
jefe_5_pelea:
	ld a,(0e090h)		;9454
	rra			;9457   ; uno de cada dos cuadros
	jr c,L_94B4		;9458
	call L_772A		;945a   ; sus sprites
	ld ix,0e3d0h		;945d
	ld a,(0e090h)		;9461
	cp 00eh		;9464   ; al cuadro 0x0E suelta el primero
	jr nz,L_946F		;9466
	ld a,(0e3d0h)		;9468
	or a			;946b
	call z,pon_un_bicho_del_jefe_5		;946c
L_946F:
	call mueve_al_jefe_5		;946f
	ld de,0e348h		;9472   ; su dibujo
	call pinta_un_bicho_del_jefe_5		;9475
	ld ix,0e100h		;9478   ; y los cinco bichos que lleva
	ld b,005h		;947c
L_947E:
	ld hl,094ebh		;947e   ; su reloj, de la rampa de 0x94EB: 0, 0x33, 0x66, 0x99, 0xCC y 0xFF
	ld a,b			;9481
	call suma_a_a_hl		;9482
	ld c,(hl)			;9485
	inc (ix+018h)		;9486
	ld a,(ix+018h)		;9489
	cp c			;948c
	jr nz,L_94A0		;948d
	ld a,(ix+000h)		;948f
	or a			;9492
	jr nz,L_94A0		;9493
	call pon_un_bicho_del_jefe_5		;9495
	ld (ix+001h),009h		;9498   ; salen como bichos del tipo 9, con la ranura de patrones 0xC0
	ld (ix+016h),0c0h		;949c
L_94A0:
	push bc			;94a0
	call mueve_un_bicho_del_jefe_5		;94a1   ; se mueven
	pop bc			;94a4
	push bc			;94a5
	call le_dan_los_disparos		;94a6   ; y se les puede dar
	call toca_al_muneco		;94a9
	ld bc,00020h		;94ac
	add ix,bc		;94af
	pop bc			;94b1
	djnz L_947E		;94b2
L_94B4:
	call espera_al_jefe		;94b4
	jr nz,jefe_5_se_muere		;94b7
	ld a,(0e090h)		;94b9
	and 01fh		;94bc   ; cada 32 cuadros, una rafaga del tipo 1
	ret nz			;94be
	ld b,001h		;94bf
	ld ix,0e3d0h		;94c1
	jp suelta_una_rafaga		;94c5
jefe_5_se_muere:
	ld a,004h		;94c8
	call L_8904		;94ca
	ld a,(0e3d3h)		;94cd   ; y se aparta 0x10 por cada lado
	sub 010h		;94d0
	ld (0e3d3h),a		;94d2
	ld a,(0e3d5h)		;94d5
	sub 010h		;94d8
	ld (0e3d5h),a		;94da
	ret			;94dd
pon_un_bicho_del_jefe_5:
	ld (ix+000h),001h		;94de
	ld (ix+003h),020h		;94e2   ; fila 0x20, columna 0x7E
	ld (ix+005h),07eh		;94e6
	ret			;94ea

; ----------------------------------------------------------------------
; DATOS rampa_de_0x947E: 0x00, 0x33, 0x66, 0x99, 0xCC y 0xFF: seis pasos
;   iguales
;   0x94eb..0x94f1  (6 bytes)
DATA_rampa_de_0x947E:
	defb 000h,033h,066h,099h,0cch,0ffh	; 94eb

; ======================================================================
; CODIGO 0x94f1..0x9549  (88 bytes)
; ======================================================================


pinta_un_bicho_del_jefe_5:
	ld a,(ix+00ah)		;94f1
	cp 018h		;94f4   ; el sprite 0x18 tiene su pareja en 0x7876 y los demas en 0x787E
	ld hl,07876h		;94f6
	jr z,L_94FE		;94f9
	ld hl,0787eh		;94fb
L_94FE:
	ld b,002h		;94fe
L_9500:
	ld a,(ix+000h)		;9500
	or a			;9503
	ld a,(ix+003h)		;9504
	jr nz,L_950B		;9507
	ld a,0cah		;9509   ; apagado, a la fila 0xCA
L_950B:
	add a,(hl)			;950b   ; la fila del jefe mas el desplazamiento
	ld (de),a			;950c
	inc hl			;950d
	inc de			;950e
	ld a,(ix+005h)		;950f   ; y la columna
	add a,(hl)			;9512
	ld (de),a			;9513
	inc hl			;9514
	inc de			;9515
	ld a,(hl)			;9516
	add a,0c0h		;9517   ; el patron va 0xC0 mas alla
	ld (de),a			;9519
	inc hl			;951a
	inc de			;951b
	ld c,(hl)			;951c   ; el color de la tabla
	ld a,c			;951d
	cp 005h		;951e   ; el color 5 parpadea segun lo que le quede de vida
	jr nz,L_953A		;9520
	ld c,00fh		;9522   ; blanco...
	ld a,(0e003h)		;9524
	bit 2,a		;9527
	jr nz,L_953A		;9529
	ld a,(ix+001h)		;952b
	cp 014h		;952e
	jr c,L_953A		;9530
	ld c,004h		;9532   ; ...azul...
	cp 028h		;9534
	jr c,L_953A		;9536
	ld c,006h		;9538   ; ...o rojo
L_953A:
	ld a,c			;953a   ; el color, ya elegido
	ld (de),a			;953b
	inc hl			;953c
	inc de			;953d
	djnz L_9500		;953e
	ret			;9540
mueve_un_bicho_del_jefe_5:
	ld a,(ix+000h)		;9541
	dec a			;9544
	ret m			;9545
	call reparte_por_tabla		;9546

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_9549: 7 entradas; tras el `call 406Ch` de 0x9546
;   0x9549..0x9557  (14 bytes)
DATA_tabla_de_reparto_9549:
	defw 07eb9h,09557h,07f15h,07c74h,07c8ah,07ca0h,07cefh	; 9549

; ======================================================================
; CODIGO 0x9557..0x9582  (43 bytes)
; ======================================================================


bicho_del_jefe_apunta:
	call bicho_09_dispara_y_se_mueve		;9557
	ld a,(ix+003h)		;955a
	cp 038h		;955d   ; pasada la fila 0x38
	ret c			;955f
	call angulo_al_muneco		;9560   ; se lanza al muneco al doble de velocidad
	call seno_y_coseno		;9563
	ld h,b			;9566
	ld l,c			;9567
	add hl,hl			;9568
	ld (ix+006h),l		;9569
	ld (ix+007h),h		;956c
	ld h,d			;956f
	ld l,e			;9570
	add hl,hl			;9571
	ld (ix+008h),l		;9572
	ld (ix+009h),h		;9575
	jr $+28		;9578
mueve_al_jefe_5:
	ld a,(ix+000h)		;957a
	dec a			;957d
	ret m			;957e
	call reparte_por_tabla		;957f

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_9582: 3 entradas; tras el `call 406Ch` de 0x957F
;   0x9582..0x9588  (6 bytes)
DATA_tabla_de_reparto_9582:
	defw 07ebch,09588h,09598h	; 9582  -> L_7EBC jefe_5_entra jefe_5_carga

; ======================================================================
; CODIGO 0x9588..0x95f7  (111 bytes)
; ======================================================================


jefe_5_entra:
	call L_7F18		;9588
	ld a,(0e3d3h)		;958b
	cp 038h		;958e   ; hasta la fila 0x38
	ret c			;9590
	call jefe_5_apunta_al_muneco		;9591
L_9594:
	inc (ix+000h)		;9594
	ret			;9597
jefe_5_carga:
	call L_7F18		;9598
	dec (ix+00eh)		;959b
	ret nz			;959e
jefe_5_apunta_al_muneco:
	call angulo_al_muneco		;959f
	call seno_y_coseno		;95a2   ; su seno y su coseno
	ld a,(0e3d1h)		;95a5   ; y va mas deprisa cuanta menos vida le queda
	cp 014h		;95a8
	jr c,L_95D7		;95aa
	cp 028h		;95ac
	jr c,L_95BA		;95ae
	ld h,b			;95b0   ; con poca vida, al doble
	ld l,c			;95b1
	add hl,hl			;95b2
	ld b,h			;95b3
	ld c,l			;95b4
	ex de,hl			;95b5
	add hl,hl			;95b6
	ex de,hl			;95b7
	jr L_95D7		;95b8
L_95BA:
	ld h,b			;95ba   ; y con la mitad, a la mitad
	ld l,c			;95bb
	srl b		;95bc
	rr c		;95be
	bit 6,b		;95c0   ; con signo: si el bit 6 estaba puesto, se estira el 7
	jr z,L_95C6		;95c2
	set 7,b		;95c4
L_95C6:
	add hl,bc			;95c6   ; la mitad, sumada: por tres cuartos
	ld b,h			;95c7
	ld c,l			;95c8
	ld h,d			;95c9
	ld l,e			;95ca
	srl d		;95cb   ; y lo mismo con la otra componente
	rr e		;95cd
	bit 6,d		;95cf
	jr z,L_95D5		;95d1
	set 7,d		;95d3
L_95D5:
	add hl,de			;95d5
	ex de,hl			;95d6
L_95D7:
	ld (0e3d6h),bc		;95d7   ; la velocidad, y 0x30 cuadros de carga
	ld (0e3d8h),de		;95db
	ld (ix+00eh),030h		;95df
	ret			;95e3

; ----------------------------------------------------------------------
; EL JEFE DE LA FASE 5, el de las seis puertas. Nueve estados en 0x95F7.
; ----------------------------------------------------------------------
jefe_de_la_fase_5:
	call pinta_el_decorado_del_jefe_6		;95e4   ; su decorado
	ld a,(0e3b0h)		;95e7
	dec a			;95ea
	ret m			;95eb
	cp 005h		;95ec
	jr nc,L_95F4		;95ee
	ld hl,096cch		;95f0
	push hl			;95f3
L_95F4:
	call reparte_por_tabla		;95f4

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_95F7: 9 entradas; tras el `call 406Ch` de 0x95F4;
;   nueve, no una: ver abajo
;   0x95f7..0x9609  (18 bytes)
DATA_tabla_de_reparto_95F7:
	defw 09609h,09238h,09662h,09687h,096c1h,0928fh,092ach,092c3h	; 95f7
	defw 092d2h	; 9607  -> jefe_muriendose_4

; ======================================================================
; CODIGO 0x9609..0x965c  (83 bytes)
; ======================================================================


jefe_6_monta:
	call borra_las_variables_del_jefe		;9609
	ld a,0d8h		;960c   ; fila 0xD8, columna 0x68
	ld (0e3d3h),a		;960e
	ld a,068h		;9611
	ld (0e3d5h),a		;9613
	ld a,003h		;9616
	ld (0e3e0h),a		;9618
	ld ix,0e400h		;961b   ; las SEIS puertas, de 0x10 en 0x10 desde 0xE400
	ld hl,0965ch		;961f   ; sus columnas, de la tira de 0x965C
	ld de,00010h		;9622
	ld b,006h		;9625
L_9627:
	ld (ix+000h),001h		;9627
	ld a,(hl)			;962b
	inc hl			;962c
	ld (ix+004h),a		;962d
	ld (ix+003h),00fh		;9630   ; con 0x0F de fotograma y 0x14 de aguante
	ld (ix+008h),014h		;9634
	add ix,de		;9638
	djnz L_9627		;963a
	xor a			;963c
	ld (0e400h),a		;963d   ; la primera, apagada
	ld a,040h		;9640
	ld (0e408h),a		;9642
jefe_6_sube_sus_patrones:
	ld de,0b124h		;9645   ; cinco patrones
	call descomprime_desde_la_palabra		;9648
	jp jefe_1_sube_sus_patrones		;964b
borra_las_variables_del_jefe:
	ld hl,0e3d0h		;964e   ; los 0xE0 bytes de 0xE3D0
	ld de,0e3d1h		;9651
	ld bc,000dfh		;9654
	ld (hl),000h		;9657
	ldir		;9659
	ret			;965b

; ----------------------------------------------------------------------
; DATOS seis_bytes_de_0x961F: Las columnas de las seis puertas del jefe de la
;   fase 5
;   0x965c..0x9662  (6 bytes)
DATA_seis_bytes_de_0x961F:
	defb 080h,030h,070h,0a0h,080h,0e0h	; 965c

; ======================================================================
; CODIGO 0x9662..0x96f0  (142 bytes)
; ======================================================================


jefe_6_entra:
	call monta_el_decorado_del_jefe		;9662   ; su decorado
	ld hl,0e604h		;9665   ; y persigue la columna del muneco, redondeada a ocho
	ld a,(hl)			;9668
	and 0f8h		;9669
	ld (0e3dah),a		;966b
	ld b,a			;966e
	ld a,(0e3d5h)		;966f
	and 0f8h		;9672
	add a,010h		;9674
	cp b			;9676
	ld hl,00000h		;9677
	jr z,L_9681		;967a
	inc h			;967c
	jr c,L_9681		;967d
	ld h,0ffh		;967f
L_9681:
	ld (0e3d8h),hl		;9681
L_9684:
	jp sube_de_estado_al_jefe		;9684
jefe_6_se_mueve:
	ld a,(0e003h)		;9687   ; alterna sus dos dibujos cada cuatro cuadros
	bit 2,a		;968a
	ld a,001h		;968c
	jr z,L_9691		;968e
	dec a			;9690
L_9691:
	ld (0e3e1h),a		;9691
	ld hl,(0e3d4h)		;9694
	ld a,h			;9697
	and 0f8h		;9698
	add a,010h		;969a
	ld c,a			;969c
	ld a,(0e3dah)		;969d   ; hasta llegar a la columna que buscaba
	cp c			;96a0
	jr z,L_96BA		;96a1
	ld de,(0e3d8h)		;96a3
	add hl,de			;96a7
	ld (0e3d4h),hl		;96a8
	ld a,h			;96ab
	cp 020h		;96ac   ; topado entre 0x20 y 0xB0
	ld h,020h		;96ae
	jr c,L_96B7		;96b0
	cp 0b0h		;96b2
	ld h,0b0h		;96b4
	ret c			;96b6
L_96B7:
	ld (0e3d4h),hl		;96b7
L_96BA:
	ld a,050h		;96ba   ; y 0x50 cuadros parado
	ld (0e3dbh),a		;96bc
	jr L_9684		;96bf
jefe_6_espera:
	ld hl,0e3dbh		;96c1
	dec (hl)			;96c4   ; el reloj de la espera
	ret nz			;96c5
	ld a,003h		;96c6   ; y a abrir las puertas
	ld (0e3b0h),a		;96c8
	ret			;96cb
haz_las_seis_puertas:
	ld a,(0e3b0h)		;96cc
	cp 003h		;96cf   ; hasta el estado 3 no se abren
	jr c,L_96E5		;96d1
	ld ix,0e400h		;96d3
	ld b,006h		;96d7
	ld de,00010h		;96d9
L_96DC:
	exx			;96dc
	call haz_una_puerta		;96dd
	exx			;96e0
	add ix,de		;96e1
	djnz L_96DC		;96e3
L_96E5:
	jp pinta_las_seis_puertas		;96e5
haz_una_puerta:
	ld a,(ix+000h)		;96e8
	dec a			;96eb
	ret m			;96ec
	call reparte_por_tabla		;96ed

; ----------------------------------------------------------------------
; DATOS tabla_de_reparto_96F0: 4 entradas; tras el `call 406Ch` de 0x96ED;
;   sigue en 0x96F8
;   0x96f0..0x96f8  (8 bytes)
DATA_tabla_de_reparto_96F0:
	defw 096f8h,097abh,097d6h,097f0h	; 96f0  -> puerta_cerrada puerta_abierta puerta_abriendose puerta_cerrandose

; ======================================================================
; CODIGO 0x96f8..0x97a5  (173 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; UNA PUERTA CERRADA. Los disparos la van rompiendo: cada uno le suma lo
; que diga su arma en la tabla de 0x97A5, y al llegar a (ix+8) se abre.
; ----------------------------------------------------------------------
puerta_cerrada:
	ld a,(ix+002h)		;96f8
	and 0fbh		;96fb
	cp 002h		;96fd   ; solo el estado 2 se puede romper
	jr nz,L_9742		;96ff
	ld iy,0e620h		;9701   ; las tres ranuras de disparo
	ld b,003h		;9705
L_9707:
	push bc			;9707
	ld a,(iy+000h)		;9708
	rla			;970b
	jr c,L_973A		;970c
	push iy		;970e
	pop hl			;9710
	call toca_el_disparo_a_la_puerta		;9711   ; si toca
	jr c,L_973A		;9714
	ld a,00bh		;9716   ; suena el golpe
	call pide_pieza_si_la_escena_lo_permite		;9718
	set 7,(iy+000h)		;971b   ; el disparo se gasta
	ld a,(iy+005h)		;971f
	srl a		;9722
	ld hl,097a5h		;9724   ; y el arma dice cuanto suma, de la tabla de 0x97A5
	call suma_a_a_hl		;9727
	ld a,(ix+001h)		;972a
	add a,(hl)			;972d
	ld (ix+001h),a		;972e
	cp (ix+008h)		;9731   ; al llegar al aguante, la puerta se abre
	jr c,L_973A		;9734
	pop bc			;9736
	jp sube_de_estado_la_puerta		;9737
L_973A:
	pop bc			;973a
	ld de,00010h		;973b
	add iy,de		;973e
	djnz L_9707		;9740
L_9742:
	call dispara_la_puerta		;9742
	ld a,(ix+001h)		;9745   ; lo roto que este
	ld b,00fh		;9748   ; el fotograma va con lo roto que este: 0x0F, 7, 0x0A, 9 y 8
	cp 006h		;974a
	jr c,L_9760		;974c
	ld b,007h		;974e
	cp 00bh		;9750
	jr c,L_9760		;9752
	ld b,00ah		;9754
	cp 010h		;9756
	jr c,L_9760		;9758
	dec b			;975a
	cp 015h		;975b
	jr c,L_9760		;975d
	dec b			;975f
L_9760:
	ld (ix+003h),b		;9760
	ld a,(ix+004h)		;9763   ; su reloj
	sub 008h		;9766
	ld c,a			;9768
	ld a,(ix+005h)		;9769
	and a			;976c
	jr z,la_puerta_arranca		;976d   ; con el reloj a cero se arranca
	cp c			;976f   ; y al llegar a la mitad se da la vuelta
	jr nz,L_9784		;9770
	ld a,(ix+002h)		;9772
	and 002h		;9775
	xor 002h		;9777
	ld (ix+002h),a		;9779
	bit 1,a		;977c
	jr nz,L_9784		;977e
	ld (ix+005h),020h		;9780
L_9784:
	dec (ix+005h)		;9784   ; cada dieciseis pasos, cambio de dibujo
	ld a,(ix+005h)		;9787
	and 00fh		;978a
	ret nz			;978c
	ld a,(ix+002h)		;978d
	xor 004h		;9790
	ld (ix+002h),a		;9792
	ret			;9795
la_puerta_arranca:
	ld a,(ix+004h)		;9796
	ld (ix+005h),a		;9799   ; el reloj entero
	ld a,(ix+002h)		;979c
	xor 001h		;979f
	ld (ix+002h),a		;97a1
	ret			;97a4

; ----------------------------------------------------------------------
; DATOS seis_bytes_de_0x9724: Lo que suma cada arma al romper una puerta: uno
;   las tres primeras y dos las otras tres
;   0x97a5..0x97ab  (6 bytes)
DATA_seis_bytes_de_0x9724:
	defb 001h,001h,001h,002h,002h,002h	; 97a5

; ======================================================================
; CODIGO 0x97ab..0x98c3  (280 bytes)
; ======================================================================


puerta_abierta:
	ld hl,0e3f0h		;97ab
	inc (hl)			;97ae   ; una puerta abierta mas
	ld a,(hl)			;97af
	cp 006h		;97b0   ; y con las SEIS, el jefe se muere
	jr nz,L_97C9		;97b2
	exx			;97b4
	push bc			;97b5
	push de			;97b6
	push hl			;97b7
	ld hl,0e3d5h		;97b8
	ld a,(hl)			;97bb
	add a,018h		;97bc   ; y se hunde 0x18
	ld (hl),a			;97be
	ld a,006h		;97bf
	call L_8904		;97c1
	pop hl			;97c4
	pop de			;97c5
	pop bc			;97c6
	exx			;97c7
	ret			;97c8
L_97C9:
	ld a,04dh		;97c9   ; con su sonido
	call pide_pieza_si_la_escena_lo_permite		;97cb
	ld (ix+003h),009h		;97ce
	ld a,020h		;97d2
	jr pon_el_reloj_de_la_puerta		;97d4
puerta_abriendose:
	ld a,(ix+005h)		;97d6
	bit 1,a		;97d9   ; alterna sus dos dibujos
	ld a,008h		;97db
	jr z,L_97E0		;97dd
	inc a			;97df
L_97E0:
	ld (ix+002h),a		;97e0
	dec (ix+005h)		;97e3
	ret nz			;97e6
	ld a,020h		;97e7
pon_el_reloj_de_la_puerta:
	ld (ix+005h),a		;97e9
sube_de_estado_la_puerta:
	inc (ix+000h)		;97ec
	ret			;97ef
puerta_cerrandose:
	bit 1,(ix+005h)		;97f0
	ld a,009h		;97f4
	jr z,L_97F9		;97f6
	inc a			;97f8
L_97F9:
	ld (ix+002h),a		;97f9
	dec (ix+005h)		;97fc
	ret nz			;97ff
	ld (ix+002h),00bh		;9800   ; y vuelve a estar cerrada
	ld (ix+003h),006h		;9804
	ld (ix+000h),000h		;9808
	ld a,(0e3f0h)		;980c   ; con cinco abiertas, la sexta tambien se abre
	sub 005h		;980f
	ret nz			;9811
	inc a			;9812
	ld (0e400h),a		;9813
	ret			;9816
dispara_la_puerta:
	ld a,(ix+002h)		;9817
	and 0fbh		;981a   ; solo las cerradas
	cp 002h		;981c
	ret nz			;981e
	ld a,(0e3f0h)		;981f   ; cuantas mas puertas abiertas, mas a menudo dispara
	ld c,03fh		;9822
	cp 002h		;9824
	jr c,L_9830		;9826
	ld c,01fh		;9828
	cp 004h		;982a
	jr c,L_9830		;982c
	ld c,00fh		;982e
L_9830:
	ld a,(ix+005h)		;9830
	and c			;9833   ; solo cada tantos cuadros
	ret nz			;9834
	ld hl,0e463h		;9835   ; desde su posicion
	ld a,(ix+006h)		;9838   ; nueve a la derecha
	add a,009h		;983b
	ld (hl),a			;983d
	inc hl			;983e
	inc hl			;983f
	ld a,(ix+007h)		;9840   ; y seis abajo
	add a,006h		;9843
	ld (hl),a			;9845
	push ix		;9846   ; se guarda todo, que la rafaga usa IX y los registros alternos
	exx			;9848
	push bc			;9849
	push de			;984a
	push hl			;984b
	ld ix,0e460h		;984c
	ld b,00eh		;9850   ; una rafaga del tipo 14
	call suelta_una_rafaga		;9852
	pop hl			;9855
	pop de			;9856
	pop bc			;9857
	exx			;9858
	pop ix		;9859
	ret			;985b
pinta_el_decorado_del_jefe_6:
	ld a,(0e3b0h)		;985c
	cp 003h		;985f   ; hasta el estado 3, nada
	ret c			;9861
	ld a,(0e3b0h)		;9862
	cp 006h		;9865
	push af			;9867
	call nz,vuelca_la_banda_de_arriba		;9868   ; la banda de arriba
	pop af			;986b
	ret nc			;986c
	ld de,0e3d3h		;986d
	ld a,(de)			;9870
	ld l,a			;9871
	inc de			;9872
	inc de			;9873
	ld a,(de)			;9874
	and 0f8h		;9875
	ld h,a			;9877
	call pinta_el_cuadro		;9878   ; y su cuadro
	jp L_8C34		;987b
pinta_las_seis_puertas:
	ld a,(0e3b0h)		;987e
	cp 006h		;9881
	ret nc			;9883
	ld de,0e320h		;9884   ; los seis sprites, desde 0xE320
	ld hl,098c3h		;9887
	ld ix,0e400h		;988a
	ld b,006h		;988e
L_9890:
	ld a,(0e3d3h)		;9890   ; la fila del jefe mas el desplazamiento de 0x98C3
	add a,(hl)			;9893
	ld (de),a			;9894
	ld (ix+006h),a		;9895
	inc de			;9898
	inc hl			;9899
	ld a,(0e3d5h)		;989a   ; y la columna, redondeada a ocho
	and 0f8h		;989d
	add a,(hl)			;989f
	ld (de),a			;98a0
	ld (ix+007h),a		;98a1
	inc de			;98a4
	inc hl			;98a5
	push hl			;98a6
	ld hl,098cfh		;98a7   ; el patron, de la tira de 0x98CF
	ld a,(ix+002h)		;98aa
	call suma_a_a_hl		;98ad
	ld a,(hl)			;98b0
	ld (de),a			;98b1
	inc de			;98b2
	ld a,(ix+003h)		;98b3
	ld (de),a			;98b6
	ex de,hl			;98b7
	ld de,00010h		;98b8
	add ix,de		;98bb
	ex de,hl			;98bd
	pop hl			;98be
	inc de			;98bf
	djnz L_9890		;98c0
	ret			;98c2

; ----------------------------------------------------------------------
; DATOS tabla_de_0x9887: La leen 0x9887 y 0x98A7
;   0x98c3..0x98db  (24 bytes)
DATA_tabla_de_0x9887:
	defb 0fch,010h,002h,003h	; 98c3
	defb 002h,01dh,00ch,010h	; 98c7
	defb 012h,003h,012h,01dh	; 98cb
	defb 090h,08ch,084h,08ch	; 98cf
	defb 090h,08ch,088h,08ch	; 98d3
	defb 048h,050h,054h,094h	; 98d7

; ======================================================================
; CODIGO 0x98db..0x9992  (183 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LE DAN LOS DISPAROS AL JEFE. Cada fase trae en la tabla de 0x9999 los
; cuatro bytes de su caja -alto, ancho y los dos desplazamientos- y en
; la de 0x9992, cuantos impactos aguanta.
; ----------------------------------------------------------------------
le_dan_los_disparos_al_jefe:
	ld a,(0e065h)		;98db   ; su fase, por cuatro
	add a,a			;98de
	add a,a			;98df
	ld hl,09999h		;98e0
	call suma_a_a_hl		;98e3
le_dan_con_esta_caja:
	ld de,0e3bbh		;98e6   ; los cuatro bytes de la caja, a 0xE3BB
	ld bc,00004h		;98e9
	ldir		;98ec
	ld ix,0e620h		;98ee   ; las tres ranuras de disparo
	ld b,003h		;98f2
L_98F4:
	bit 7,(ix+000h)		;98f4   ; saltando las vacias
	jr nz,L_992F		;98f8
	ld a,(ix+005h)		;98fa
	ld hl,099b5h		;98fd   ; el arma decide su caja, de la tabla de 0x99B5
	add a,a			;9900
	call suma_a_a_hl		;9901
	ld a,(0e3bbh)		;9904
	add a,(hl)			;9907
	ld e,a			;9908
	ld a,(0e3bch)		;9909
	add a,e			;990c
	ld d,a			;990d
	ld a,(0e3d5h)		;990e   ; la distancia vertical...
	sub (ix+004h)		;9911
	neg		;9914
	add a,e			;9916
	cp d			;9917
	jr nc,L_992F		;9918
	ld a,(0e3bdh)		;991a
	ld e,a			;991d
	ld a,(0e3beh)		;991e
	ld d,a			;9921
	ld a,(0e3d3h)		;9922   ; ...y la horizontal, contra la caja
	sub (ix+002h)		;9925
	neg		;9928
	add a,e			;992a
	cp d			;992b
	call c,dale_al_jefe		;992c
L_992F:
	ld de,00010h		;992f
	add ix,de		;9932
	djnz L_98F4		;9934
	ret			;9936
dale_al_jefe:
	ld (ix+002h),0e0h		;9937   ; el disparo se apaga
	set 7,(ix+000h)		;993b
	ld a,(0e3bfh)		;993f   ; y si ya estaba muerto, no cuenta
	and a			;9942
	ret nz			;9943
	call la_fase_2_tiene_la_boca_abierta		;9944   ; la fase 2 solo se deja dar con la boca abierta...
	ld a,00ch		;9947
	jp z,pide_pieza_si_la_escena_lo_permite		;9949
	call la_fase_4_tiene_el_rayo_apagado		;994c   ; ...y la fase 4, con el rayo apagado
	ld a,00ch		;994f
	jp z,pide_pieza_si_la_escena_lo_permite		;9951
	ld a,00bh		;9954   ; su sonido
	call pide_pieza_si_la_escena_lo_permite		;9956
	inc hl			;9959
	ld e,(hl)			;995a
	ld a,(0e065h)		;995b
	ld hl,09992h		;995e   ; cuanto aguanta esta fase, de la tabla de 0x9992
	call suma_a_a_hl		;9961
	ld c,(hl)			;9964
	ld hl,0e3d1h		;9965
	ld a,(hl)			;9968
	add a,e			;9969   ; un impacto mas
	ld (hl),a			;996a
	cp c			;996b
	ret c			;996c
	ld a,001h		;996d
	ld (0e3bfh),a		;996f   ; y al llegar, se muere
	pop bc			;9972
	ld de,00000h		;9973   ; con un punto, que es lo que dispara el marcador
	ld c,001h		;9976
	jp suma_puntos		;9978
la_fase_2_tiene_la_boca_abierta:
	ld a,(0e065h)		;997b   ; la fase 2
	cp 002h		;997e
	ret nz			;9980
	ld a,(0e3e1h)		;9981   ; con (0xE3E1) a uno tiene la boca abierta
	dec a			;9984
	ret			;9985
la_fase_4_tiene_el_rayo_apagado:
	ld a,(0e065h)		;9986   ; la fase 4
	cp 004h		;9989
	ret nz			;998b
	ld a,(0e3e2h)		;998c   ; con el bit 0 de (0xE3E2) el rayo esta encendido
	bit 0,a		;998f
	ret			;9991

; ----------------------------------------------------------------------
; DATOS tabla_de_0x995E: 0x995E la indexa con (0xE065), que es la fase; 0x98E0
;   y 0x98FD entran en 0x9999 y 0x99B5
;   0x9992..0x99cd  (59 bytes)
DATA_tabla_de_0x995E:
	defb 014h,01eh,01eh,02dh,02dh,02dh,03ch,0f2h	; 9992  ...---<.
	defb 01ah,0f8h,010h,000h,010h,000h,010h,0feh	; 999a  ........
	defb 00eh,0fbh,011h,001h,00bh,0f9h,005h,0f4h	; 99a2  ........
	defb 01ch,0f2h,00ch,0f5h,01dh,0f8h,012h,006h	; 99aa  ........
	defb 006h,006h,00ch,004h,001h,004h,001h,00dh	; 99b2  ........
	defb 001h,00dh,001h,005h,001h,00dh,001h,00ah	; 99ba  ........
	defb 002h,00ah,002h,005h,002h,005h,002h,005h	; 99c2  ........
	defb 002h,005h,002h	; 99ca

; ----------------------------------------------------------------------
; DATOS tabla_de_las_ocho_fases: Ocho entradas de cuatro bytes -0x543D indexa
;   con (0xE062)*4-: la lista de tramos y el final del mapa de bits. Los ocho
;   pares van seguidos y sin hueco de 0x9E3D a 0xA5B4
;   0x99cd..0x99ed  (32 bytes)
DATA_tabla_de_las_ocho_fases:
	defw 09e3dh,09f25h,09f2dh,0a057h,0a05eh,0a135h,0a13ch,0a1ffh	; 99cd
	defw 0a206h,0a2e2h,0a2e9h,0a3cch,0a3d3h,0a4c3h,0a4cah,0a5adh	; 99dd

; ----------------------------------------------------------------------
; DATOS tabla_de_bloques: 64 punteros a los bloques de 4x4 casillas; 0x6533
;   indexa con el codigo de bloque sin el bit 7
;   0x99ed..0x9a6d  (128 bytes)
DATA_tabla_de_bloques:
	defw 09a7ch,09a8ch,09a9ch,09aach,09a6dh,09abch,09acch,09adch	; 99ed
	defw 09aech,09afch,09b0ch,09b1ch,09b2ch,09b3ch,09b4ch,09b6ah	; 99fd
	defw 09b7ah,09b8ah,09b9ah,09baah,09bbah,09bcah,09bdah,09beah	; 9a0d
	defw 09bfah,09c0ah,09c21h,09c3eh,09c4eh,09c5eh,09c2eh,09b5ah	; 9a1d
	defw 09c6eh,09c8ch,09c9ch,09cach,09cbch,09ccch,09c7ch,09cdch	; 9a2d
	defw 09cf4h,09cf8h,09cech,09d08h,09d18h,09d30h,09d20h,09d40h	; 9a3d
	defw 09d50h,09d60h,09d70h,09d80h,09d90h,09da0h,09db0h,09dc0h	; 9a4d
	defw 09c1ah,09dddh,09dedh,09dfdh,09e0dh,09e1dh,09e2dh,09dcdh	; 9a5d

; ----------------------------------------------------------------------
; DATOS bloques_de_4x4: Los bloques que apunta la tabla de 0x99ED: dieciseis
;   casillas cada uno, cuatro filas de cuatro. Algunos SE SOLAPAN -0x9C21 y
;   0x9C3E caen a medio bloque de otro-, que es otra vuelta de tuerca de la
;   compresion del decorado
;   0x9a6d..0x9e3d  (976 bytes)
DATA_bloques_de_4x4:
	defb 085h,09dh,080h,080h	; 9a6d
	defb 096h,088h,080h,080h	; 9a71
	defb 08bh,09ah,0e9h,080h	; 9a75
	defb 08fh,094h,091h,080h	; 9a79
	defb 080h,081h,080h,082h	; 9a7d
	defb 080h,083h,080h,083h	; 9a81
	defb 081h,080h,080h,080h	; 9a85
	defb 083h,080h,081h,050h	; 9a89
	defb 051h,050h,051h,043h	; 9a8d
	defb 044h,043h,044h,04bh	; 9a91
	defb 04bh,04bh,04bh,084h	; 9a95
	defb 085h,084h,085h,03fh	; 9a99
	defb 040h,041h,042h,03fh	; 9a9d
	defb 040h,041h,042h,03fh	; 9aa1
	defb 040h,041h,042h,03fh	; 9aa5
	defb 040h,041h,042h,07fh	; 9aa9
	defb 054h,055h,076h,05ch	; 9aad
	defb 05dh,05eh,077h,07fh	; 9ab1
	defb 05bh,05fh,074h,07fh	; 9ab5
	defb 057h,07fh,078h,067h	; 9ab9
	defb 068h,067h,068h,043h	; 9abd
	defb 044h,043h,044h,04bh	; 9ac1
	defb 04bh,04bh,04bh,08eh	; 9ac5
	defb 08fh,08eh,08fh,07fh	; 9ac9
	defb 07fh,058h,079h,07fh	; 9acd
	defb 057h,07fh,076h,063h	; 9ad1
	defb 066h,067h,07dh,07fh	; 9ad5
	defb 058h,068h,07eh,086h	; 9ad9
	defb 080h,086h,080h,052h	; 9add
	defb 053h,059h,086h,07fh	; 9ae1
	defb 07fh,07fh,07ch,07fh	; 9ae5
	defb 07fh,058h,07ah,060h	; 9ae9
	defb 062h,062h,076h,061h	; 9aed
	defb 061h,05ah,075h,087h	; 9af1
	defb 088h,089h,080h,080h	; 9af5
	defb 086h,080h,086h,045h	; 9af9
	defb 045h,045h,045h,046h	; 9afd
	defb 046h,046h,046h,071h	; 9b01
	defb 047h,047h,047h,080h	; 9b05
	defb 072h,048h,048h,045h	; 9b09
	defb 045h,045h,045h,046h	; 9b0d
	defb 046h,046h,046h,047h	; 9b11
	defb 047h,047h,047h,048h	; 9b15
	defb 048h,048h,048h,086h	; 9b19
	defb 08eh,08fh,090h,088h	; 9b1d
	defb 09bh,091h,092h,087h	; 9b21
	defb 09ch,093h,094h,089h	; 9b25
	defb 09bh,091h,092h,060h	; 9b29
	defb 080h,080h,080h,05ch	; 9b2d
	defb 055h,059h,056h,05ch	; 9b31
	defb 05fh,05ah,051h,05ch	; 9b35
	defb 06dh,05eh,051h,05ch	; 9b39
	defb 052h,053h,051h,05ch	; 9b3d
	defb 001h,054h,051h,05ch	; 9b41
	defb 05dh,050h,051h,05ch	; 9b45
	defb 06dh,05eh,051h,05ch	; 9b49
	defb 052h,053h,051h,061h	; 9b4d
	defb 066h,054h,051h,066h	; 9b51
	defb 066h,05bh,058h,084h	; 9b55
	defb 085h,080h,080h,081h	; 9b59
	defb 080h,082h,080h,078h	; 9b5d
	defb 079h,083h,081h,07ch	; 9b61
	defb 07dh,080h,083h,077h	; 9b65
	defb 07fh,062h,064h,055h	; 9b69
	defb 056h,063h,065h,05eh	; 9b6d
	defb 051h,080h,052h,053h	; 9b71
	defb 051h,080h,066h,057h	; 9b75
	defb 058h,086h,087h,086h	; 9b79
	defb 087h,088h,089h,088h	; 9b7d
	defb 089h,087h,086h,087h	; 9b81
	defb 086h,089h,088h,089h	; 9b85
	defb 088h,0f0h,0efh,0eeh	; 9b89
	defb 087h,0f2h,0f1h,0fbh	; 9b8d
	defb 089h,0f4h,0f3h,0fch	; 9b91
	defb 086h,0f2h,0f1h,0fbh	; 9b95
	defb 088h,086h,09dh,095h	; 9b99
	defb 098h,088h,09eh,096h	; 9b9d
	defb 099h,087h,086h,087h	; 9ba1
	defb 086h,089h,088h,089h	; 9ba5
	defb 088h,0f8h,0fah,0fdh	; 9ba9
	defb 087h,0f9h,0f7h,0feh	; 9bad
	defb 089h,087h,086h,087h	; 9bb1
	defb 086h,089h,088h,089h	; 9bb5
	defb 088h,045h,045h,045h	; 9bb9
	defb 045h,046h,046h,046h	; 9bbd
	defb 046h,069h,047h,047h	; 9bc1
	defb 047h,06dh,06ah,048h	; 9bc5
	defb 048h,045h,045h,045h	; 9bc9
	defb 045h,046h,046h,046h	; 9bcd
	defb 046h,047h,049h,06ch	; 9bd1
	defb 06ch,048h,04ah,06dh	; 9bd5
	defb 06dh,05ch,052h,053h	; 9bd9
	defb 051h,061h,066h,054h	; 9bdd
	defb 051h,066h,066h,05bh	; 9be1
	defb 058h,08ch,08dh,0e8h	; 9be5
	defb 088h,0b1h,0b3h,0b2h	; 9be9
	defb 0bch,0b1h,0b4h,0c6h	; 9bed
	defb 0c1h,0b8h,0bbh,0c6h	; 9bf1
	defb 0c6h,089h,088h,0ebh	; 9bf5
	defb 0eah,060h,087h,086h	; 9bf9
	defb 087h,05ch,055h,059h	; 9bfd
	defb 056h,05ch,05fh,05ah	; 9c01
	defb 051h,05ch,06dh,05eh	; 9c05
	defb 051h,086h,087h,086h	; 9c09
	defb 0c0h,0b6h,0b9h,0b5h	; 9c0d
	defb 0bch,0b1h,0bah,0bfh	; 9c11
	defb 0bch,0b1h,0beh,06dh	; 9c15
	defb 0bch,09ch,095h,08ah	; 9c19
	defb 080h,001h,099h,0ech	; 9c1d
	defb 080h,080h,080h,080h	; 9c21
	defb 080h,080h,080h,080h	; 9c25
	defb 080h,080h,080h,080h	; 9c29
	defb 080h,080h,080h,080h	; 9c2d
	defb 06ah,080h,080h,06bh	; 9c31
	defb 0b4h,080h,06ch,0b9h	; 9c35
	defb 0b8h,06dh,0beh,0bdh	; 9c39
	defb 0bch,060h,080h,080h	; 9c3d
	defb 080h,054h,061h,080h	; 9c41
	defb 080h,058h,059h,062h	; 9c45
	defb 080h,05ch,05dh,05eh	; 9c49
	defb 063h,050h,051h,052h	; 9c4d
	defb 053h,054h,055h,056h	; 9c51
	defb 057h,058h,059h,05ah	; 9c55
	defb 05bh,05ch,05dh,05eh	; 9c59
	defb 05fh,064h,051h,052h	; 9c5d
	defb 053h,065h,067h,056h	; 9c61
	defb 057h,066h,068h,069h	; 9c65
	defb 05bh,081h,082h,083h	; 9c69
	defb 084h,045h,045h,045h	; 9c6d
	defb 045h,046h,046h,046h	; 9c71
	defb 046h,047h,049h,070h	; 9c75
	defb 070h,048h,04ah,080h	; 9c79
	defb 080h,098h,099h,082h	; 9c7d
	defb 080h,09dh,09ch,083h	; 9c81
	defb 081h,080h,080h,080h	; 9c85
	defb 083h,080h,081h,09fh	; 9c89
	defb 080h,081h,080h,07ah	; 9c8d
	defb 07bh,076h,080h,06eh	; 9c91
	defb 0ddh,07eh,080h,095h	; 9c95
	defb 096h,097h,081h,064h	; 9c99
	defb 080h,081h,080h,05ah	; 9c9d
	defb 065h,088h,080h,05eh	; 9ca1
	defb 05fh,066h,088h,061h	; 9ca5
	defb 062h,063h,067h,056h	; 9ca9
	defb 057h,058h,059h,05ah	; 9cad
	defb 05bh,05ch,05dh,05eh	; 9cb1
	defb 05fh,060h,054h,061h	; 9cb5
	defb 062h,063h,067h,050h	; 9cb9
	defb 057h,058h,059h,051h	; 9cbd
	defb 052h,053h,05dh,001h	; 9cc1
	defb 001h,084h,085h,001h	; 9cc5
	defb 086h,087h,080h,068h	; 9cc9
	defb 069h,068h,069h,043h	; 9ccd
	defb 044h,043h,044h,04bh	; 9cd1
	defb 04bh,04bh,04bh,08ah	; 9cd5
	defb 089h,08ah,089h,09ah	; 9cd9
	defb 0f9h,0f8h,080h,001h	; 9cdd
	defb 09bh,09eh,080h,083h	; 9ce1
	defb 081h,080h,080h,080h	; 9ce5
	defb 083h,080h,081h,068h	; 9ce9
	defb 069h,068h,069h,043h	; 9ced
	defb 044h,043h,044h,04bh	; 9cf1
	defb 04bh,04bh,04bh,04bh	; 9cf5
	defb 04bh,04bh,04bh,04bh	; 9cf9
	defb 04bh,04bh,04bh,04bh	; 9cfd
	defb 04bh,04bh,04bh,08fh	; 9d01
	defb 090h,08fh,090h,068h	; 9d05
	defb 069h,068h,069h,043h	; 9d09
	defb 044h,043h,044h,04bh	; 9d0d
	defb 04bh,04bh,04bh,08fh	; 9d11
	defb 090h,08fh,090h,06fh	; 9d15
	defb 06dh,06fh,06dh,043h	; 9d19
	defb 044h,043h,044h,04bh	; 9d1d
	defb 04bh,04bh,04bh,04bh	; 9d21
	defb 04bh,04bh,04bh,04bh	; 9d25
	defb 04bh,04bh,04bh,08ah	; 9d29
	defb 089h,08ah,089h,06fh	; 9d2d
	defb 06dh,06fh,06dh,043h	; 9d31
	defb 044h,043h,044h,04bh	; 9d35
	defb 04bh,04bh,04bh,08fh	; 9d39
	defb 090h,08fh,090h,06fh	; 9d3d
	defb 06dh,06fh,06dh,043h	; 9d41
	defb 044h,043h,044h,04bh	; 9d45
	defb 04bh,04bh,04bh,08ah	; 9d49
	defb 089h,08ah,089h,08bh	; 9d4d
	defb 08bh,08bh,08bh,08ch	; 9d51
	defb 08ch,08ch,08ch,08dh	; 9d55
	defb 08dh,08dh,08dh,08eh	; 9d59
	defb 08eh,08eh,08eh,084h	; 9d5d
	defb 080h,081h,080h,001h	; 9d61
	defb 085h,083h,080h,001h	; 9d65
	defb 086h,080h,080h,001h	; 9d69
	defb 087h,080h,081h,088h	; 9d6d
	defb 080h,081h,080h,001h	; 9d71
	defb 085h,083h,080h,001h	; 9d75
	defb 086h,080h,080h,001h	; 9d79
	defb 087h,080h,081h,050h	; 9d7d
	defb 051h,052h,053h,051h	; 9d81
	defb 050h,051h,054h,050h	; 9d85
	defb 051h,050h,055h,051h	; 9d89
	defb 050h,051h,056h,080h	; 9d8d
	defb 080h,081h,080h,082h	; 9d91
	defb 080h,083h,080h,05ah	; 9d95
	defb 05bh,080h,080h,051h	; 9d99
	defb 050h,05bh,08ch,050h	; 9d9d
	defb 051h,057h,059h,058h	; 9da1
	defb 058h,059h,059h,001h	; 9da5
	defb 001h,08ah,089h,08bh	; 9da9
	defb 08bh,080h,081h,084h	; 9dad
	defb 080h,081h,080h,087h	; 9db1
	defb 080h,083h,080h,083h	; 9db5
	defb 081h,080h,080h,080h	; 9db9
	defb 083h,080h,081h,080h	; 9dbd
	defb 080h,092h,0f5h,080h	; 9dc1
	defb 080h,08ch,098h,080h	; 9dc5
	defb 080h,080h,080h,080h	; 9dc9
	defb 080h,080h,080h,0fdh	; 9dcd
	defb 080h,080h,080h,0e8h	; 9dd1
	defb 080h,080h,089h,0fah	; 9dd5
	defb 080h,080h,08dh,0f4h	; 9dd9
	defb 06fh,06dh,06dh,0cfh	; 9ddd
	defb 043h,044h,043h,044h	; 9de1
	defb 04bh,04bh,04bh,04bh	; 9de5
	defb 08fh,090h,08fh,090h	; 9de9
	defb 06fh,06dh,06dh,0cfh	; 9ded
	defb 043h,044h,043h,044h	; 9df1
	defb 04bh,04bh,04bh,04bh	; 9df5
	defb 08ah,089h,08ah,089h	; 9df9
	defb 080h,080h,06bh,073h	; 9dfd
	defb 082h,080h,093h,097h	; 9e01
	defb 083h,081h,098h,099h	; 9e05
	defb 080h,083h,095h,09bh	; 9e09
	defb 090h,091h,092h,080h	; 9e0d
	defb 06fh,0f7h,094h,080h	; 9e11
	defb 09ah,0f9h,0f8h,080h	; 9e15
	defb 09ch,0fbh,096h,081h	; 9e19
	defb 080h,080h,09fh,09dh	; 9e1d
	defb 082h,080h,083h,080h	; 9e21
	defb 083h,081h,080h,080h	; 9e25
	defb 080h,083h,080h,081h	; 9e29
	defb 09eh,0fdh,0ffh,080h	; 9e2d
	defb 082h,080h,083h,080h	; 9e31
	defb 083h,081h,080h,080h	; 9e35
	defb 080h,083h,080h,081h	; 9e39

; ----------------------------------------------------------------------
; DATOS mapas_de_las_ocho_fases: Los ocho mapas, seguidos y sin un byte suelto
;   entre ellos. Cada uno empieza por la lista de punteros a sus tramos -la
;   que carga (0xE093)- y acaba con el mapa de bits de repeticion, que 0x55ED
;   lee HACIA ATRAS desde (0xE095)
;   0x9e3d..0xa5b4  (1911 bytes)
DATA_mapas_de_las_ocho_fases:
	defb 0e1h,09eh,0d1h,09eh,0c5h,09eh,0b5h,09eh,0a3h,09eh,094h,09eh,089h,09eh,079h,09eh	; 9e3d  ..............y.
	defb 06ch,09eh,051h,09eh,000h,00dh,009h,00ah,020h,0a0h,00ah,089h,08dh,00dh,000h,03bh	; 9e4d  l.Q..... ......;
	defb 03ch,000h,08dh,00dh,000h,03dh,03eh,000h,08dh,00dh,000h,08dh,00dh,000h,08dh,00dh	; 9e5d  <....=>.........
	defb 000h,08dh,00eh,000h,08eh,000h,005h,002h,085h,000h,00fh,000h,000h,005h,002h,085h	; 9e6d  ................
	defb 002h,085h,000h,00fh,000h,08fh,00fh,000h,08fh,00fh,000h,08fh,00fh,000h,08fh,000h	; 9e7d  ................
	defb 000h,08fh,000h,005h,002h,085h,000h,00ch,000h,08fh,00dh,000h,08fh,00dh,000h,00dh	; 9e8d  ................
	defb 000h,00dh,000h,00dh,000h,08ch,00dh,000h,08dh,00dh,000h,08dh,00dh,000h,08dh,00eh	; 9e9d  ................
	defb 000h,08eh,005h,002h,005h,002h,085h,000h,00fh,000h,00fh,000h,08ch,00fh,000h,08dh	; 9ead  ................
	defb 000h,08dh,00fh,000h,08dh,00fh,000h,08eh,00fh,000h,000h,005h,002h,085h,000h,00ch	; 9ebd  ................
	defb 000h,00dh,000h,08fh,00dh,000h,08fh,00dh,000h,00dh,000h,00dh,000h,08ch,00dh,000h	; 9ecd  ................
	defb 08dh,00dh,000h,08dh,00dh,000h,08dh,00dh,000h,08dh,00eh,000h,08eh,000h,000h,000h	; 9edd  ................
	defb 000h,000h,001h,0ffh,0bbh,0bbh,083h,083h,083h,083h,001h,061h,001h,081h,001h,03dh	; 9eed  ...........a...=
	defb 001h,083h,083h,083h,083h,001h,003h,001h,019h,001h,083h,083h,081h,081h,081h,083h	; 9efd  ................
	defb 083h,083h,083h,083h,079h,001h,081h,083h,083h,003h,083h,083h,081h,001h,029h,001h	; 9f0d  ....y.........).
	defb 081h,083h,083h,081h,081h,083h,083h,083h,083h,083h,083h,001h,001h,001h,001h,001h	; 9f1d  ................
	defb 00ah,0a0h,0f3h,09fh,0e1h,09fh,0c8h,09fh,0b5h,09fh,09eh,09fh,08bh,09fh,072h,09fh	; 9f2d  ..............r.
	defb 05eh,09fh,041h,09fh,000h,034h,009h,00ah,020h,0a0h,00ah,089h,0b4h,033h,032h,000h	; 9f3d  ^.A..4.. ....32.
	defb 0b2h,0b3h,033h,031h,000h,0b1h,0b3h,033h,031h,000h,0b1h,0b3h,033h,031h,000h,0b1h	; 9f4d  ..31...31...31..
	defb 0b3h,035h,036h,000h,0b1h,0b3h,000h,0b6h,0b5h,000h,034h,000h,033h,032h,000h,0b4h	; 9f5d  .56.......4.32..
	defb 033h,031h,000h,0b2h,0b3h,033h,031h,000h,0b1h,0b3h,035h,036h,000h,0b1h,0b3h,000h	; 9f6d  31...31...56....
	defb 0b1h,0b3h,034h,000h,0b1h,0b3h,033h,032h,000h,0b6h,0b5h,035h,036h,000h,000h,000h	; 9f7d  ..4...32...56...
	defb 0b4h,034h,000h,0b2h,0b3h,033h,032h,000h,0b6h,0b5h,033h,031h,000h,033h,031h,000h	; 9f8d  .4...32...31.31.
	defb 0b4h,033h,031h,000h,0b2h,0b3h,033h,031h,000h,0b6h,0b5h,033h,031h,000h,033h,031h	; 9f9d  .31...31...31.31
	defb 000h,035h,036h,000h,0b4h,000h,0b2h,0b3h,000h,0b1h,0b3h,000h,0b1h,0b3h,000h,0b1h	; 9fad  .56.............
	defb 0b3h,000h,0b1h,0b3h,000h,0b1h,0b3h,034h,000h,0b1h,0b3h,033h,032h,000h,0b6h,0b5h	; 9fbd  .......4...32...
	defb 033h,031h,000h,033h,031h,000h,033h,031h,000h,0b4h,033h,031h,000h,0b2h,0b3h,033h	; 9fcd  31.31.31..31...3
	defb 031h,000h,0b1h,0b3h,033h,031h,000h,0b6h,0b5h,033h,031h,000h,035h,036h,000h,000h	; 9fdd  1...31...31.56..
	defb 000h,0b4h,034h,000h,0b2h,0b3h,033h,032h,000h,0b1h,0b3h,035h,036h,000h,0b1h,0b3h	; 9fed  ..4...32...56...
	defb 000h,0b1h,0b3h,000h,0b1h,0b3h,000h,0b1h,0b3h,034h,000h,0b1h,0b3h,033h,032h,000h	; 9ffd  .........4...32.
	defb 0b1h,0b3h,033h,031h,000h,0b1h,0b3h,033h,031h,000h,0b6h,0b5h,033h,031h,000h,035h	; a00d  ..31...31...31.5
	defb 036h,000h,000h,000h,001h,0ffh,0c7h,0c7h,0c7h,0c7h,0c7h,007h,001h,081h,0c3h,0c7h	; a01d  6...............
	defb 0c7h,0c7h,007h,087h,0c7h,0c1h,001h,003h,087h,0c7h,0c1h,0c3h,0c7h,0c7h,0c1h,0c1h	; a02d  ................
	defb 0c3h,007h,007h,007h,007h,007h,007h,087h,0c7h,0c1h,0c1h,0c3h,0c7h,0c7h,0c7h,0c1h	; a03d  ................
	defb 0c1h,001h,003h,087h,0c7h,0c7h,007h,007h,007h,087h,0c7h,0c7h,0c7h,0c1h,0c1h,001h	; a04d  ................
	defb 001h,0f1h,0a0h,0e2h,0a0h,0d8h,0a0h,0c9h,0a0h,0bbh,0a0h,0ach,0a0h,0a1h,0a0h,097h	; a05d  ................
	defb 0a0h,087h,0a0h,072h,0a0h,000h,003h,009h,00ah,020h,0a0h,00ah,089h,086h,003h,000h	; a06d  ...r..... ......
	defb 083h,006h,000h,083h,003h,000h,086h,006h,000h,086h,006h,000h,083h,003h,000h,088h	; a07d  ................
	defb 006h,000h,003h,000h,087h,008h,000h,083h,000h,088h,000h,001h,081h,000h,001h,002h	; a08d  ................
	defb 081h,000h,007h,000h,006h,000h,003h,000h,008h,000h,000h,001h,002h,081h,000h,000h	; a09d  ................
	defb 007h,000h,087h,003h,000h,086h,006h,000h,083h,008h,000h,083h,000h,088h,001h,081h	; a0ad  ................
	defb 000h,000h,087h,007h,000h,083h,003h,000h,086h,006h,000h,086h,006h,000h,083h,003h	; a0bd  ................
	defb 000h,086h,006h,000h,088h,003h,000h,003h,000h,008h,000h,000h,000h,000h,001h,081h	; a0cd  ................
	defb 002h,081h,000h,000h,087h,000h,086h,000h,088h,001h,002h,081h,000h,087h,007h,000h	; a0dd  ................
	defb 086h,006h,000h,086h,003h,000h,083h,006h,000h,088h,006h,000h,003h,000h,008h,000h	; a0ed  ................
	defb 000h,000h,001h,0ffh,083h,083h,083h,083h,083h,083h,081h,083h,083h,003h,001h,011h	; a0fd  ................
	defb 001h,019h,001h,081h,081h,081h,081h,001h,031h,001h,001h,083h,083h,083h,083h,003h	; a10d  ........1.......
	defb 011h,001h,003h,083h,083h,083h,083h,083h,083h,081h,081h,081h,001h,001h,001h,017h	; a11d  ................
	defb 001h,003h,003h,003h,019h,003h,083h,083h,083h,083h,081h,081h,081h,001h,001h,0bdh	; a12d  ................
	defb 0a1h,0b0h,0a1h,0a5h,0a1h,09ah,0a1h,091h,0a1h,088h,0a1h,07eh,0a1h,070h,0a1h,065h	; a13d  ...........~.p.e
	defb 0a1h,050h,0a1h,000h,00fh,009h,00ah,020h,0a0h,00ah,089h,08fh,00fh,000h,08fh,00fh	; a14d  .P..... ........
	defb 000h,08fh,00fh,000h,08fh,00fh,000h,08fh,00fh,000h,08fh,000h,005h,085h,000h,005h	; a15d  ................
	defb 002h,085h,000h,000h,00fh,000h,08fh,00fh,000h,08fh,00fh,000h,08fh,00fh,000h,08fh	; a16d  ................
	defb 000h,005h,085h,000h,000h,005h,085h,000h,00fh,000h,08fh,000h,08fh,000h,005h,085h	; a17d  ................
	defb 000h,00fh,000h,000h,000h,000h,08fh,000h,000h,00fh,000h,00fh,000h,00fh,000h,000h	; a18d  ................
	defb 000h,08fh,00fh,000h,005h,002h,085h,000h,000h,000h,00fh,000h,08fh,000h,000h,08fh	; a19d  ................
	defb 00fh,000h,08fh,00fh,000h,08fh,000h,005h,002h,085h,000h,00fh,000h,08fh,00fh,000h	; a1ad  ................
	defb 00fh,000h,08fh,000h,08fh,000h,00fh,000h,000h,08fh,000h,000h,001h,0ffh,083h,083h	; a1bd  ................
	defb 083h,083h,083h,001h,011h,001h,019h,001h,001h,083h,083h,083h,083h,001h,011h,001h	; a1cd  ................
	defb 001h,011h,001h,083h,003h,001h,011h,001h,081h,001h,001h,003h,001h,001h,081h,081h	; a1dd  ................
	defb 081h,001h,003h,081h,031h,001h,001h,001h,083h,001h,003h,083h,083h,001h,031h,001h	; a1ed  ....1.........1.
	defb 083h,081h,083h,003h,001h,081h,003h,001h,001h,09bh,0a2h,08dh,0a2h,081h,0a2h,075h	; a1fd  ...............u
	defb 0a2h,063h,0a2h,059h,0a2h,04bh,0a2h,040h,0a2h,035h,0a2h,01ah,0a2h,01ah,01ch,009h	; a20d  .c.Y.K.@.5......
	defb 00ah,020h,0a0h,00ah,089h,09ch,01ch,01ah,03fh,004h,01ah,09ch,01ch,01ah,037h,038h	; a21d  . ......?.....78
	defb 01ah,09ch,01ch,01ah,09ch,01ch,01ah,09ch,01ch,01ah,09ch,01dh,01ah,09dh,01ah,01ah	; a22d  ................
	defb 01ah,01bh,01ah,01ch,01ah,01ch,01ah,01ch,01ah,01ch,01ah,01dh,01ah,01ah,01ah,01ah	; a23d  ................
	defb 01eh,01ah,09ch,01bh,01ah,09ch,01ch,01ah,09ch,01ch,01ah,09ch,01dh,01ah,09ch,01ah	; a24d  ................
	defb 09ch,01ah,09dh,01ah,01ah,01ah,01bh,01ah,01eh,01ch,01ah,09ch,01ch,01ah,09ch,01ch	; a25d  ................
	defb 01ah,09ch,01ch,01ah,09ch,01ch,01ah,09ch,01ch,01ah,09ch,01ch,01ah,09ch,01dh,01ah	; a26d  ................
	defb 09dh,01ah,01ah,01ah,01ah,01eh,01ah,09ch,01ah,09ch,01ah,09ch,01ah,09dh,01bh,01ah	; a27d  ................
	defb 01ch,01ah,01ch,01ah,01ch,01ah,01ch,01ah,01ch,01ah,01eh,01ch,01ah,09ch,01ch,01ah	; a28d  ................
	defb 09ch,01ch,01ah,09ch,01dh,01ah,09ch,01ah,09ch,01ah,09ch,01ah,09ch,01ah,09ch,001h	; a29d  ................
	defb 0ffh,0bbh,0bbh,083h,083h,083h,083h,001h,001h,001h,081h,081h,081h,081h,081h,081h	; a2ad  ................
	defb 001h,001h,003h,003h,083h,083h,083h,083h,003h,003h,001h,001h,001h,083h,083h,083h	; a2bd  ................
	defb 083h,083h,083h,083h,083h,083h,001h,001h,001h,003h,003h,003h,003h,003h,081h,081h	; a2cd  ................
	defb 081h,081h,081h,083h,083h,083h,083h,083h,003h,003h,003h,003h,086h,0a3h,078h,0a3h	; a2dd  ..............x.
	defb 068h,0a3h,05ch,0a3h,04ch,0a3h,03fh,0a3h,033h,0a3h,025h,0a3h,018h,0a3h,0fdh,0a2h	; a2ed  h.\.L.?.3.%.....
	defb 000h,023h,009h,00ah,020h,0a0h,00ah,089h,0a2h,023h,000h,01fh,021h,000h,0a3h,023h	; a2fd  .#.. ....#..!..#
	defb 000h,026h,027h,000h,0a3h,023h,000h,0a3h,023h,000h,0a3h,023h,000h,0a3h,024h,000h	; a30d  .&'..#..#..#..$.
	defb 0a3h,000h,0a4h,025h,0a5h,000h,022h,000h,023h,000h,023h,000h,0a2h,024h,000h,0a4h	; a31d  ...%..".#.#..$..
	defb 025h,0a5h,000h,025h,002h,0a5h,000h,022h,000h,024h,000h,000h,0a2h,000h,0a3h,022h	; a32d  %..%...".$....."
	defb 000h,0a3h,023h,000h,0a4h,023h,000h,024h,000h,025h,0a5h,022h,000h,024h,000h,025h	; a33d  ..#..#.$.%.".$.%
	defb 002h,0a5h,000h,0a2h,022h,000h,0a3h,023h,000h,0a3h,024h,000h,0a3h,000h,0a3h,000h	; a34d  ...."..#..$.....
	defb 0a4h,000h,025h,0a5h,000h,0a2h,000h,0a3h,022h,000h,0a3h,023h,000h,0a3h,023h,000h	; a35d  ..%....."..#..#.
	defb 0a4h,024h,000h,025h,002h,0a5h,000h,0a2h,022h,000h,0a4h,024h,000h,000h,022h,000h	; a36d  .$.%...."..$..".
	defb 0a2h,024h,000h,0a4h,025h,002h,0a5h,022h,000h,023h,000h,023h,000h,0a2h,023h,000h	; a37d  .$..%..".#.#..#.
	defb 0a3h,023h,000h,0a4h,023h,000h,024h,000h,000h,001h,0ffh,0bbh,0bbh,083h,083h,083h	; a38d  .#..#.$.........
	defb 083h,003h,011h,001h,081h,081h,083h,083h,011h,001h,029h,001h,081h,081h,003h,003h	; a39d  ..........).....
	defb 083h,083h,081h,081h,011h,081h,081h,0c1h,003h,083h,083h,083h,003h,003h,001h,011h	; a3ad  ................
	defb 003h,003h,083h,083h,083h,081h,00dh,003h,083h,081h,001h,083h,083h,031h,081h,081h	; a3bd  .............1..
	defb 083h,083h,083h,081h,081h,001h,07eh,0a4h,076h,0a4h,068h,0a4h,05ah,0a4h,048h,0a4h	; a3cd  ......~.v.h.Z.H.
	defb 035h,0a4h,029h,0a4h,011h,0a4h,0fch,0a3h,0e7h,0a3h,000h,022h,009h,00ah,020h,0a0h	; a3dd  5.)........".. .
	defb 00ah,089h,0a3h,023h,000h,0a3h,023h,000h,0a3h,023h,000h,0a3h,023h,000h,0a3h,024h	; a3ed  ...#..#..#..#..$
	defb 000h,0a3h,000h,0a4h,02ah,002h,0aah,002h,0aah,028h,002h,0a8h,002h,0a8h,029h,039h	; a3fd  ....*....(....)9
	defb 0a9h,039h,0a9h,030h,02ch,002h,02ch,0ach,002h,0ach,028h,039h,029h,039h,028h,028h	; a40d  .9.0,.,...(9)9((
	defb 030h,028h,028h,02dh,0adh,028h,028h,030h,028h,028h,030h,028h,028h,030h,028h,029h	; a41d  0((-.((0((0((0()
	defb 02dh,0adh,029h,030h,02dh,0adh,030h,030h,030h,02ch,002h,0ach,002h,0ach,02eh,03ah	; a42d  -.)0-.000,.....:
	defb 02eh,03ah,02eh,022h,000h,023h,000h,0a2h,024h,000h,0a4h,000h,02ah,002h,02ah,02bh	; a43d  .:.".#..$...*.*+
	defb 0aah,028h,002h,028h,002h,028h,029h,039h,029h,002h,029h,030h,030h,030h,02ch,02dh	; a44d  .(.(.()9).)000,-
	defb 0adh,0ach,028h,030h,028h,029h,02dh,0adh,029h,030h,030h,030h,030h,02ch,002h,02ch	; a45d  ..(0()-.)0000,.,
	defb 002h,0ach,029h,039h,029h,039h,029h,030h,030h,030h,02dh,0adh,030h,02dh,0adh,030h	; a46d  ..)9)9)000-.0-.0
	defb 030h,030h,030h,02fh,002h,0afh,000h,0a2h,022h,000h,0a3h,023h,000h,0a4h,023h,000h	; a47d  000/...."..#..#.
	defb 001h,0ffh,083h,083h,083h,083h,083h,003h,03dh,03dh,03dh,001h,0d7h,0c7h,083h,093h	; a48d  ........===.....
	defb 083h,083h,083h,093h,001h,011h,001h,001h,001h,01fh,01fh,081h,083h,083h,001h,079h	; a49d  ...............y
	defb 079h,079h,001h,001h,001h,093h,083h,093h,001h,001h,001h,001h,0f1h,0f1h,001h,001h	; a4ad  yy..............
	defb 001h,011h,001h,011h,001h,001h,001h,001h,029h,003h,083h,083h,081h,06eh,0a5h,05eh	; a4bd  ........)....n.^
	defb 0a5h,04fh,0a5h,03dh,0a5h,035h,0a5h,025h,0a5h,015h,0a5h,008h,0a5h,0f9h,0a4h,0deh	; a4cd  .O.=.5.%........
	defb 0a4h,010h,00dh,014h,00ah,015h,095h,00ah,094h,08dh,00dh,010h,00bh,011h,010h,08dh	; a4dd  ................
	defb 00dh,010h,012h,013h,010h,08dh,00dh,010h,08dh,00dh,010h,08dh,00dh,010h,08dh,00dh	; a4ed  ................
	defb 010h,017h,00dh,010h,00dh,010h,00dh,010h,00dh,010h,019h,00dh,010h,08dh,016h,010h	; a4fd  ................
	defb 08dh,010h,017h,010h,010h,018h,010h,019h,016h,010h,08dh,010h,08dh,010h,08dh,018h	; a50d  ................
	defb 010h,08dh,00dh,010h,08dh,00dh,010h,08dh,00dh,010h,08dh,00dh,010h,08dh,00dh,010h	; a51d  ................
	defb 08dh,016h,010h,08dh,010h,08dh,010h,08dh,010h,08dh,010h,017h,010h,010h,010h,010h	; a52d  ................
	defb 018h,010h,019h,00dh,010h,08dh,00dh,010h,08dh,00dh,010h,08dh,00dh,010h,08dh,00dh	; a53d  ................
	defb 010h,08dh,00dh,010h,08dh,00dh,010h,017h,00dh,010h,00dh,010h,00dh,010h,016h,010h	; a54d  ................
	defb 019h,010h,08dh,010h,08dh,018h,010h,08dh,00dh,010h,08dh,00dh,010h,08dh,00dh,010h	; a55d  ................
	defb 017h,00dh,010h,016h,010h,010h,010h,010h,010h,010h,001h,0ffh,0bbh,0bbh,083h,083h	; a56d  ................
	defb 083h,083h,081h,081h,081h,083h,083h,083h,003h,001h,001h,083h,083h,003h,003h,083h	; a57d  ................
	defb 083h,083h,083h,083h,083h,083h,003h,003h,003h,003h,001h,001h,001h,001h,083h,083h	; a58d  ................
	defb 083h,083h,083h,083h,083h,083h,081h,081h,081h,083h,003h,003h,083h,083h,083h,083h	; a59d  ................
	defb 081h,081h,001h,001h,001h,001h,001h	; a5ad

; ----------------------------------------------------------------------
; DATOS animaciones_del_jugador: Siete punteros; 0x5E82 indexa con (ix+0x0C) &
;   0x0F y saca la tabla de fotogramas de esa animacion
;   0xa5b4..0xa5c2  (14 bytes)
DATA_animaciones_del_jugador:
	defw 0a5beh,0a5d6h,0a5ebh,0a5beh,0a603h,0a5c8h,0a5cfh	; a5b4

; ----------------------------------------------------------------------
; DATOS atributos_del_jugador: Tres parejas [ajuste de y][color] para los tres
;   sprites del muneco: -10 en blanco, 0 en cian y +7 en negro. 0x5E02 lo usa
;   por defecto
;   0xa5c2..0xa5c8  (6 bytes)
DATA_atributos_del_jugador:
	defb 0f6h,00fh	; a5c2
	defb 000h,007h	; a5c4
	defb 007h,001h	; a5c6

; ----------------------------------------------------------------------
; DATOS fotogramas_de_andar: Los dos guiones de la animacion 0, y su tabla de
;   dos punteros en 0xA5BE
;   0xa5c8..0xa5d6  (14 bytes)
DATA_fotogramas_de_andar:
	defb 0ffh,02dh,0a6h,0ffh,040h,0a6h,000h,0ffh,02dh,0a6h,0feh,020h,0eeh,000h	; a5c8  .-..@...-.. ..

; ----------------------------------------------------------------------
; DATOS fotogramas_de_la_animacion_1: Dos punteros, los dos fotogramas de la
;   animacion 1
;   0xa5d6..0xa5da  (4 bytes)
DATA_fotogramas_de_la_animacion_1:
	defw 0a5ddh,0a5e4h	; a5d6

; ----------------------------------------------------------------------
; DATOS atributos_y_guiones_de_la_animacion_1: Los tres sprites de la
;   animacion 1 y los guiones de sus dos fotogramas
;   0xa5da..0xa5eb  (17 bytes)
DATA_atributos_y_guiones_de_la_animacion_1:
	defb 0eeh,030h,007h,0ffh,07bh,0a6h,0ffh,040h,0a6h,000h,0ffh,07bh,0a6h,0feh,020h,0eeh	; a5da  .0..{..@...{.. .
	defb 000h	; a5ea

; ----------------------------------------------------------------------
; DATOS fotogramas_de_la_animacion_2: Dos punteros, los dos fotogramas de la
;   animacion 2
;   0xa5eb..0xa5ef  (4 bytes)
DATA_fotogramas_de_la_animacion_2:
	defw 0a5f5h,0a5fch	; a5eb

; ----------------------------------------------------------------------
; DATOS atributos_del_parpadeo: Los tres sprites con el segundo en negro:
;   0x5E0C alterna este bloque con el de 0xA5C2 y eso es el parpadeo de
;   invulnerable
;   0xa5ef..0xa603  (20 bytes)
DATA_atributos_del_parpadeo:
	defb 0f6h,00fh,000h,001h,007h,000h,0ffh,02dh,0a6h,0ffh,05dh,0a6h,000h,0ffh,02dh,0a6h	; a5ef  .......-..]...-.
	defb 0feh,040h,0eeh,000h	; a5ff

; ----------------------------------------------------------------------
; DATOS fotogramas_de_la_explosion: Cuatro punteros: la animacion 4, la de
;   morirse
;   0xa603..0xa60b  (8 bytes)
DATA_fotogramas_de_la_explosion:
	defw 0a611h,0a618h,0a61fh,0a626h	; a603

; ----------------------------------------------------------------------
; DATOS atributos_de_la_explosion_y_guiones: Los tres sprites de la explosion
;   y los guiones de sus cuatro fotogramas
;   0xa60b..0xa62d  (34 bytes)
DATA_atributos_de_la_explosion_y_guiones:
	defb 000h,00fh,000h,001h,010h,000h,0ffh,09dh,0a6h,0ffh,00bh,0a7h,000h,0ffh,0beh,0a6h	; a60b  ................
	defb 0ffh,00bh,0a7h,000h,0ffh,0e0h,0a6h,0ffh,00bh,0a7h,000h,0ffh,0fbh,0a6h,0ffh,00bh	; a61b  ................
	defb 0a7h,000h	; a62b

; ----------------------------------------------------------------------
; DATOS patrones_del_jugador: Los bloques comprimidos que arman los diez
;   fotogramas. Cada fotograma son 64 bytes justos, o sea DOS patrones de
;   16x16; el tercer sprite del muneco sale del banco de la fase
;   0xa62d..0xa71e  (241 bytes)
DATA_patrones_del_jugador:
	defb 00ah,000h,086h,040h,0c0h,0c4h,0e8h,068h,008h,00ah,000h,086h,002h,003h,003h,007h	; a62d  ...@...h........
	defb 006h,000h,000h,082h,007h,00fh,005h,01fh,08bh,02fh,070h,077h,02fh,000h,00fh,00fh	; a63d  ........./pw/...
	defb 009h,006h,0e0h,0f0h,005h,0f8h,086h,0f4h,00eh,0eeh,0f6h,006h,0f0h,003h,000h,000h	; a64d  ................
	defb 082h,007h,008h,005h,010h,08bh,030h,04fh,048h,030h,00fh,010h,030h,036h,009h,0e0h	; a65d  ......0OH0..06..
	defb 010h,005h,008h,089h,00ch,0f2h,012h,00ah,0f6h,008h,0fch,0fch,0f0h,000h,0a0h,000h	; a66d  ................
	defb 00fh,03fh,070h,040h,001h,001h,000h,000h,000h,040h,0c0h,0c4h,0e8h,068h,008h,000h	; a67d  .?p@.....@...h..
	defb 0f0h,0fch,00eh,002h,080h,080h,000h,000h,000h,002h,003h,003h,007h,006h,000h,000h	; a68d  ................
	defb 09dh,044h,08bh,056h,08dh,06ah,015h,00ah,025h,050h,025h,00ah,000h,005h,00ah,001h	; a69d  .D.V.j..%P%.....
	defb 004h,0a2h,051h,0aah,055h,0aah,050h,0a8h,054h,00ah,054h,0a2h,004h,050h,003h,000h	; a6ad  ..Q.U.P.T.T..P..
	defb 000h,0a0h,000h,002h,000h,008h,000h,002h,000h,00ah,005h,011h,00ah,00eh,005h,01ah	; a6bd  ................
	defb 007h,000h,000h,000h,020h,080h,000h,0a0h,050h,080h,028h,040h,090h,044h,070h,0f0h	; a6cd  .... ...P.(@.Dp.
	defb 0e0h,000h,000h,004h,000h,08bh,001h,000h,000h,000h,002h,001h,00ah,005h,00ah,00fh	; a6dd  ................
	defb 007h,008h,000h,089h,080h,000h,000h,0c0h,040h,0f0h,0f0h,0e0h,000h,000h,00bh,000h	; a6ed  ........@.......
	defb 083h,003h,007h,003h,00ch,000h,086h,080h,0c0h,0e0h,0c0h,000h,000h,000h,00ah,000h	; a6fd  ................
	defb 086h,007h,01fh,03fh,03fh,01fh,007h,00ah,000h,086h,0e0h,0f8h,0fch,0fch,0f8h,0e0h	; a70d  ...??...........
	defb 000h	; a71d

; ----------------------------------------------------------------------
; DATOS sprites_de_la_fase: Comprimido; 1184 bytes = 37 patrones a 0x1840. Las
;   armas, los disparos y los objetos, iguales en las ocho fases
;   0xa71e..0xa993  (629 bytes)
DATA_sprites_de_la_fase:
	defb 040h,018h,089h,010h,00fh,008h,010h,00fh,01fh,03fh,03fh,00fh,007h,000h,089h,008h	; a71e  @........??.....
	defb 0f0h,010h,008h,0f0h,0f8h,0fch,0fch,0f0h,007h,000h,002h,020h,081h,070h,004h,020h	; a72e  ........... .p. 
	defb 086h,070h,0a8h,070h,0a8h,050h,088h,013h,000h,002h,020h,081h,070h,004h,020h,086h	; a73e  .p.p.P.... .p. .
	defb 070h,0a9h,070h,0a9h,050h,089h,003h,000h,002h,040h,081h,0e0h,004h,040h,086h,0e0h	; a74e  p.p.P....@...@..
	defb 050h,0e0h,050h,0a0h,010h,003h,000h,08eh,010h,038h,03ah,078h,034h,054h,010h,091h	; a75e  P.P......8:x4T..
	defb 038h,054h,038h,054h,028h,044h,012h,000h,002h,010h,008h,030h,082h,0fch,010h,003h	; a76e  8T8T(D.....0....
	defb 030h,081h,020h,010h,000h,08ah,040h,060h,030h,018h,038h,038h,070h,060h,0c0h,080h	; a77e  0. ...@`0.88p`..
	defb 016h,000h,084h,01ch,03eh,06fh,0c3h,00fh,000h,082h,080h,0c0h,00bh,000h,08ah,008h	; a78e  ....>o..........
	defb 018h,030h,070h,0e0h,0e0h,0c0h,060h,030h,010h,016h,000h,085h,0c0h,070h,03dh,01fh	; a79e  .0p...`0.....p=.
	defb 00eh,00ch,000h,082h,0c0h,080h,00dh,000h,081h,060h,003h,0f0h,086h,0a0h,050h,080h	; a7ae  .........`....P.
	defb 020h,000h,040h,021h,000h,004h,07fh,081h,01fh,00bh,000h,004h,0feh,08fh,0f8h,000h	; a7be   .@!............
	defb 000h,001h,003h,033h,07bh,07ah,079h,052h,028h,040h,011h,000h,020h,004h,000h,090h	; a7ce  ...3{zyR(@.. ...
	defb 080h,0c0h,0cch,0deh,09eh,05eh,014h,08ah,010h,004h,000h,008h,000h,000h,0fch,0feh	; a7de  .....^..........
	defb 003h,0c6h,082h,0feh,0fch,003h,0c0h,016h,000h,082h,04eh,0cah,004h,04ah,081h,0eeh	; a7ee  ..........N..J..
	defb 009h,000h,081h,0eeh,005h,0aah,081h,0eeh,009h,000h,002h,010h,008h,030h,082h,0fdh	; a7fe  .............0..
	defb 010h,003h,030h,003h,020h,008h,060h,082h,0f8h,020h,003h,060h,08bh,040h,010h,010h	; a80e  ..0. .`.. .`.@..
	defb 024h,050h,054h,0fah,0feh,0feh,07ch,038h,016h,000h,089h,002h,000h,001h,007h,016h	; a81e  $PT...|8........
	defb 00dh,01fh,01fh,03fh,003h,07fh,002h,03fh,08bh,01fh,007h,040h,080h,090h,050h,0c0h	; a82e  ...?...?...@..P.
	defb 040h,0d0h,0e8h,0f8h,004h,0fch,086h,0f8h,0f0h,0c0h,040h,060h,060h,003h,0f0h,081h	; a83e  @.........@``...
	defb 060h,019h,000h,08ah,004h,012h,008h,012h,05ah,048h,024h,05ch,05eh,07eh,004h,0ffh	; a84e  `.......ZH$\^~..
	defb 082h,07eh,03ch,006h,000h,002h,080h,008h,000h,08bh,020h,000h,008h,020h,000h,090h	; a85e  .~<....... .. ..
	defb 020h,010h,038h,078h,030h,015h,000h,084h,060h,0f0h,0f0h,060h,027h,000h,085h,010h	; a86e   .8x0...`..`'...
	defb 038h,038h,030h,010h,010h,000h,089h,010h,020h,039h,00fh,02dh,04ch,0b5h,007h,005h	; a87e  880..... 9.-L...
	defb 00ah,000h,082h,040h,080h,004h,000h,081h,080h,008h,000h,083h,003h,007h,003h,006h	; a88e  ...@............
	defb 001h,083h,003h,007h,003h,004h,000h,083h,040h,0e0h,0c0h,006h,080h,083h,0c0h,0e0h	; a89e  ........@.......
	defb 040h,009h,000h,086h,001h,003h,01fh,01eh,006h,006h,005h,000h,002h,030h,085h,03ch	; a8ae  @............0.<
	defb 07ch,0e0h,0c0h,080h,00ch,000h,086h,010h,038h,03fh,01fh,038h,010h,00ah,000h,086h	; a8be  |.......8?.8....
	defb 008h,01ch,0fch,0f8h,01ch,008h,007h,000h,002h,00ch,085h,03ch,03eh,007h,003h,001h	; a8ce  ...........<>...
	defb 00eh,000h,086h,080h,0c0h,0f8h,078h,060h,060h,003h,000h,086h,088h,050h,0a8h,070h	; a8de  ......x``....P.p
	defb 0a8h,070h,004h,020h,083h,070h,020h,020h,015h,000h,089h,002h,003h,00bh,00ch,00eh	; a8ee  .p. .p  ........
	defb 010h,060h,060h,080h,005h,000h,002h,080h,083h,0e0h,000h,080h,00ch,000h,083h,021h	; a8fe  .``............!
	defb 0ffh,021h,00ch,000h,085h,0a8h,050h,0e0h,050h,0a8h,00bh,000h,089h,080h,060h,060h	; a90e  .!....P.P.....``
	defb 010h,00eh,00ch,00bh,003h,002h,00dh,000h,085h,080h,000h,0e0h,080h,080h,00bh,000h	; a91e  ................
	defb 08ah,038h,07ch,0deh,0beh,0beh,0feh,07ch,078h,030h,010h,013h,000h,088h,001h,00eh	; a92e  .8|....|x0......
	defb 006h,03ah,018h,0e8h,020h,020h,005h,000h,083h,020h,0c0h,0c0h,00dh,000h,085h,0a8h	; a93e  .:..  ... ......
	defb 054h,03fh,054h,0a8h,00ch,000h,083h,020h,0f8h,020h,00ch,000h,002h,020h,086h,0e8h	; a94e  T?T.... . ... ..
	defb 018h,03ah,006h,00eh,001h,010h,000h,002h,0c0h,081h,020h,005h,000h,085h,007h,01fh	; a95e  .:........ .....
	defb 03fh,07fh,07fh,006h,0ffh,002h,07fh,088h,03fh,01fh,007h,0e0h,0f8h,0fch,0feh,0feh	; a96e  ?.......?.......
	defb 006h,0ffh,002h,0feh,083h,0fch,0f8h,0e0h,009h,000h,087h,038h,05ch,05ch,07ch,078h	; a97e  ...........8\\|x
	defb 030h,010h,010h,000h,000h	; a98e

; ----------------------------------------------------------------------
; DATOS banco_de_enemigos: Dieciseis punteros; 0x7914 indexa con (iy+0) &
;   0x0F. Las entradas 1, 2 y 3 apuntan al mismo bloque, y la 5 y la 13
;   tambien
;   0xa993..0xa9b3  (32 bytes)
DATA_banco_de_enemigos:
	defw 0a9b3h,0aa0ah,0aa0ah,0aa0ah,0aa50h,0aaa3h,0aac9h,0aaefh	; a993
	defw 0ab6ah,0ab9dh,0abdch,0ac2ch,0ad17h,0aaa3h,0ac5fh,0ac9fh	; a9a3

; ----------------------------------------------------------------------
; DATOS patrones_de_los_enemigos: Los bloques que apunta 0xA993: dos, tres o
;   cuatro patrones cada uno, y los dieciseis dan 45 patrones en total. Los
;   enemigos se pintan con DOS sprites -0x772A monta las dos parejas
;   [dy][dx][patron][color]-, asi que muchos bloques traen la silueta y su
;   relleno macizo
;   0xa9b3..0xad17  (868 bytes)
DATA_patrones_de_los_enemigos:
	defb 0a0h,000h,07bh,05fh,08bh,03dh,077h,0fbh,0fbh,0ddh,08eh,0dfh,0feh,03bh,07fh,07fh	; a9b3  ..{_.=w......;..
	defb 01fh,000h,0dch,0fah,0d5h,0beh,0eeh,0dfh,0dfh,0bbh,077h,0fah,07ch,0dch,0feh,0feh	; a9c3  ..........w.|...
	defb 0f8h,008h,0ffh,019h,000h,091h,00ch,03eh,03fh,078h,077h,037h,037h,01bh,067h,07fh	; a9d3  .......>?xw77.g.
	defb 07fh,07dh,03bh,001h,000h,000h,070h,003h,0f8h,091h,0fch,0f6h,0fah,0fah,0f4h,0ech	; a9e3  .};...p.........
	defb 0fch,0f0h,0f0h,0e0h,000h,007h,01fh,03fh,03fh,01fh,007h,00ah,000h,086h,0e0h,0f8h	; a9f3  .......??.......
	defb 0fch,0fch,0f8h,0e0h,00ah,000h,000h,08ah,060h,0b8h,03ch,03eh,07ch,0bah,01bh,01dh	; aa03  ........`.<>|...
	defb 013h,001h,006h,000h,08ah,006h,01dh,03ch,07ch,03eh,05dh,0d8h,0b8h,0c8h,080h,00bh	; aa13  .......<|>].....
	defb 000h,08bh,002h,013h,01dh,03bh,03dh,078h,074h,060h,050h,020h,010h,005h,000h,091h	; aa23  .....;=xt`P ....
	defb 040h,0c8h,0b8h,0dch,0bch,01eh,02eh,006h,00ah,004h,008h,007h,01fh,03fh,03fh,01fh	; aa33  @............??.
	defb 007h,00ah,000h,086h,0e0h,0f8h,0fch,0fch,0f8h,0e0h,00ah,000h,000h,0c6h,088h,0e5h	; aa43  ................
	defb 0f7h,06fh,04bh,029h,06fh,0f5h,0dah,08dh,0ceh,017h,01bh,01ch,00ch,038h,011h,0a7h	; aa53  .oK)o........8..
	defb 0efh,0f6h,0d2h,094h,0f6h,0afh,05bh,0b1h,073h,0e8h,0d8h,038h,030h,01ch,000h,008h	; aa63  ......[.s..80...
	defb 005h,007h,00fh,02bh,029h,06fh,075h,06ah,0cdh,016h,01bh,00ch,002h,00eh,000h,010h	; aa73  ...+)ouj........
	defb 0a0h,0e0h,0f0h,0d4h,094h,0f6h,0aeh,056h,0b3h,068h,0d8h,030h,040h,070h,007h,01fh	; aa83  .......V.h.0@p..
	defb 03fh,03fh,01fh,007h,00ah,000h,086h,0e0h,0f8h,0fch,0fch,0f8h,0e0h,00ah,000h,000h	; aa93  ??..............
	defb 0a0h,003h,007h,00eh,01ch,018h,014h,012h,030h,07ah,079h,0fch,0feh,07fh,03fh,01fh	; aaa3  ........0zy...?.
	defb 007h,0c0h,0e0h,070h,038h,018h,028h,048h,008h,05ch,09eh,03eh,07eh,0fch,0fch,0f8h	; aab3  ...p8.(H.\.>~...
	defb 0e0h,00ah,0ffh,016h,000h,000h,0a0h,001h,003h,087h,0cfh,0efh,0ffh,0fbh,0fdh,07fh	; aac3  ................
	defb 07fh,03fh,03fh,07fh,07fh,03fh,00fh,080h,0c0h,0e4h,0f6h,0f7h,0ffh,0dfh,0bfh,0feh	; aad3  .??..?..........
	defb 0feh,0fch,0fch,0feh,0feh,0cch,090h,00ah,0ffh,016h,000h,000h,0a6h,006h,00dh,01fh	; aae3  ................
	defb 01fh,01bh,019h,05eh,0efh,0c3h,090h,01bh,00dh,000h,00eh,006h,01ch,0e0h,070h,078h	; aaf3  ...^..........px
	defb 0f8h,0d8h,098h,0f8h,0f6h,0c7h,04bh,0d9h,0b3h,008h,030h,000h,000h,009h,012h,020h	; ab03  ......K...0.... 
	defb 020h,024h,066h,004h,0ffh,08dh,0a4h,032h,07fh,071h,039h,003h,010h,088h,084h,004h	; ab13   $f....2.q9.....
	defb 024h,064h,006h,006h,0ffh,083h,0ceh,0fch,0f0h,003h,000h,08dh,001h,019h,03eh,069h	; ab23  $d............>i
	defb 0cdh,0c7h,089h,04dh,007h,01dh,0d8h,070h,030h,003h,000h,099h,080h,098h,07ch,096h	; ab33  ...M...p0.....|.
	defb 0b3h,0e3h,091h,0b2h,0e0h,0b8h,01bh,00eh,00ch,006h,00dh,01fh,01fh,01dh,018h,01dh	; ab43  ................
	defb 00eh,003h,003h,002h,001h,004h,000h,08ch,0e0h,070h,078h,0f8h,0b8h,018h,0b8h,0f0h	; ab53  .........px.....
	defb 0c0h,0c0h,040h,080h,004h,000h,000h,0a6h,000h,001h,023h,00fh,004h,01dh,00dh,0bch	; ab63  ..@.......#.....
	defb 07fh,0bfh,06eh,06fh,036h,079h,03fh,006h,0e0h,0f0h,0f8h,0fch,072h,00ah,0d8h,0d8h	; ab73  ..no6y?.....r...
	defb 004h,0fbh,07fh,0bah,078h,0f0h,0c0h,000h,007h,01fh,03fh,03fh,01fh,007h,00ah,000h	; ab83  ....x.....??....
	defb 086h,0e0h,0f8h,0fch,0fch,0f8h,0e0h,00ah,000h,000h,084h,000h,007h,008h,007h,003h	; ab93  ................
	defb 00dh,086h,037h,078h,077h,04fh,000h,00fh,004h,000h,083h,0e0h,010h,0e0h,003h,050h	; aba3  ..7xwO.........P
	defb 091h,0ech,01ch,0ech,0f0h,000h,0f0h,0f0h,060h,000h,047h,0c8h,0f7h,0f8h,072h,012h	; abb3  ........`.G...r.
	defb 032h,048h,004h,0ffh,08bh,030h,07fh,07fh,03fh,0e2h,013h,0efh,01fh,0aeh,0a8h,0ach	; abc3  2H...0..?.......
	defb 004h,0feh,085h,0fch,00ch,00eh,09eh,0fch,000h,08eh,000h,004h,009h,04fh,067h,03fh	; abd3  .............Og?
	defb 03fh,01fh,05fh,06fh,03fh,01fh,003h,00eh,003h,000h,08eh,0ebh,0c0h,0f8h,0fch,0feh	; abe3  ?._o?...........
	defb 0fah,0fdh,0fdh,0feh,0feh,0f2h,0f4h,020h,0c0h,003h,000h,08ah,004h,009h,02fh,027h	; abf3  ....... ....../'
	defb 037h,01bh,01fh,027h,01fh,00eh,006h,000h,08bh,0e0h,090h,0c0h,0f8h,0fch,0f4h,0f0h	; ac03  7..'............
	defb 0d4h,0d0h,060h,0c0h,003h,000h,086h,007h,01fh,03fh,03fh,01fh,007h,00ah,000h,086h	; ac13  ..`......??.....
	defb 0e0h,0f8h,0fch,0fch,0f8h,0e0h,00ah,000h,000h,08eh,000h,002h,001h,009h,007h,002h	; ac23  ................
	defb 02fh,01fh,007h,00bh,015h,002h,004h,008h,003h,000h,095h,020h,004h,0d8h,030h,0d8h	; ac33  /.......... ..0.
	defb 0eeh,0f8h,0d8h,0b8h,0f4h,066h,0a0h,010h,000h,000h,007h,01fh,03fh,03fh,01fh,007h	; ac43  .....f......??..
	defb 00ah,000h,086h,0e0h,0f8h,0fch,0fch,0f8h,0e0h,00ah,000h,000h,002h,000h,084h,007h	; ac53  ................
	defb 01fh,039h,03fh,003h,06fh,084h,037h,03fh,01fh,007h,005h,000h,084h,0e0h,0f8h,0fch	; ac63  .9?.o.7?........
	defb 0fch,003h,0feh,002h,0fch,082h,0f8h,0e0h,004h,000h,085h,001h,007h,00dh,00fh,01bh	; ac73  ................
	defb 003h,017h,002h,01fh,002h,00fh,088h,007h,001h,000h,000h,0c0h,0f0h,0f8h,0f8h,006h	; ac83  ................
	defb 0fch,002h,0f8h,083h,0f0h,0c0h,000h,008h,0ffh,018h,000h,000h,08dh,000h,007h,00fh	; ac93  ................
	defb 00bh,02ch,06fh,073h,07ah,06bh,06ch,067h,070h,036h,004h,000h,094h,0e0h,0d0h,0d0h	; aca3  .,oszklgp6......
	defb 0b4h,0f6h,036h,0d6h,0eah,012h,0e6h,014h,070h,060h,070h,01ch,007h,008h,010h,034h	; acb3  ..6.....p`p....4
	defb 053h,007h,0ffh,089h,049h,07fh,03fh,00fh,0e0h,010h,028h,02ch,04ah,006h,0ffh,085h	; acc3  S...I.?...(,J...
	defb 0eah,08eh,09eh,08ch,0e0h,003h,000h,08dh,003h,002h,006h,017h,01bh,03dh,02dh,026h	; acd3  .............=-&
	defb 037h,013h,006h,003h,00eh,003h,000h,08ch,0f0h,0e8h,0e8h,058h,0f4h,0dah,0dah,072h	; ace3  7..........X...r
	defb 086h,0f4h,020h,018h,003h,000h,086h,003h,004h,005h,019h,028h,024h,004h,0ffh,08ch	; acf3  .. ........($...
	defb 02ch,039h,03ch,011h,000h,000h,0f0h,008h,014h,014h,0a4h,00ah,004h,0ffh,084h,00ah	; ad03  ,9<.............
	defb 0dch,0e4h,0f8h,000h	; ad13

; ----------------------------------------------------------------------
; DATOS sprites_del_jefe: Comprimido; 96 bytes = 3 patrones a 0x1E00 (0x8AF5).
;   Es tambien la entrada 12 del banco de enemigos
;   0xad17..0xad69  (82 bytes)
DATA_sprites_del_jefe:
	defb 002h,000h,08ch,003h,007h,00fh,00fh,037h,03fh,077h,06fh,06fh,037h,018h,003h,004h	; ad17  .......7?woo7...
	defb 000h,0a0h,0b0h,0c0h,0d0h,018h,0dch,0ech,0ech,0d8h,0f0h,0e8h,0f8h,0f0h,0c0h,000h	; ad27  ................
	defb 000h,00ch,03eh,03fh,078h,077h,037h,037h,01bh,067h,07fh,07fh,07dh,03bh,001h,000h	; ad37  ..>?xw77.g..};..
	defb 000h,070h,003h,0f8h,091h,0fch,0f6h,0fah,0fah,0f4h,0ech,0fch,0f0h,0f0h,0e0h,000h	; ad47  .p..............
	defb 007h,01fh,03fh,03fh,01fh,007h,00ah,000h,086h,0e0h,0f8h,0fch,0fch,0f8h,0e0h,00ah	; ad57  ..??............
	defb 000h,000h	; ad67

; ----------------------------------------------------------------------
; DATOS dibujo_del_remate: Comprimido y con la palabra de destino dentro; 352
;   bytes = 11 patrones (0x8E5A)
;   0xad69..0xaea6  (317 bytes)
DATA_dibujo_del_remate:
	defb 000h,01bh,0a0h,003h,007h,00fh,01fh,031h,021h,063h,0ffh,0fdh,07fh,01fh,00fh,00dh	; ad69  .......1!c......
	defb 002h,007h,003h,0c0h,0e0h,0f0h,0f8h,08ch,084h,0c6h,0ffh,07fh,0feh,0f8h,0f0h,050h	; ad79  ...............P
	defb 0a0h,0e0h,0c0h,006h,000h,08ah,001h,003h,007h,00fh,01fh,03eh,07eh,07eh,0fch,0f8h	; ad89  ...........>~~..
	defb 006h,000h,08ah,040h,060h,070h,078h,07ch,0feh,0ffh,0ffh,07fh,01fh,004h,000h,092h	; ad99  ...@`px|........
	defb 002h,006h,007h,00fh,00fh,01fh,03fh,07fh,0ffh,0f7h,0efh,05fh,03eh,03ch,038h,030h	; ada9  ......?...._><80
	defb 030h,060h,003h,040h,08eh,020h,080h,0c0h,0e0h,0f0h,0e0h,09eh,0f8h,078h,03ah,01bh	; adb9  0`.@. .......x:.
	defb 01dh,00dh,005h,003h,007h,086h,00fh,01fh,01fh,03fh,03fh,00fh,004h,000h,082h,080h	; adc9  .........??.....
	defb 0c0h,003h,0e0h,09bh,0f0h,0f8h,0fch,0bch,0beh,0deh,0deh,03fh,07eh,0f9h,0ffh,0ffh	; add9  ...........?~...
	defb 07fh,03fh,03fh,01fh,00fh,005h,008h,000h,000h,001h,000h,07fh,0feh,0fdh,0fbh,003h	; ade9  .??.............
	defb 0f7h,002h,0efh,004h,0ffh,086h,0bfh,033h,067h,001h,0cdh,0eeh,004h,0efh,006h,0cfh	; adf9  .......3g.......
	defb 002h,087h,093h,003h,0e7h,0fbh,0ffh,07fh,07fh,0bfh,0bfh,0dfh,0ffh,0ffh,0fch,0feh	; ae09  ................
	defb 0fah,0f1h,030h,098h,0d8h,0e0h,003h,0f0h,083h,0e0h,0c0h,0c0h,003h,080h,081h,040h	; ae19  ..0............@
	defb 014h,000h,08eh,003h,001h,000h,001h,007h,00fh,01fh,03eh,039h,076h,068h,050h,020h	; ae29  ..........>9vhP 
	defb 020h,004h,000h,086h,030h,0f0h,0f8h,0f8h,0c0h,018h,003h,060h,002h,030h,083h,038h	; ae39   ...0......`.0.8
	defb 000h,018h,003h,000h,08ch,006h,03eh,03eh,01eh,05fh,0dfh,00fh,017h,017h,090h,006h	; ae49  ......>>._......
	defb 001h,005h,000h,09bh,003h,01fh,0fch,060h,000h,000h,080h,0c0h,0f0h,000h,0f0h,000h	; ae59  .......`........
	defb 020h,070h,038h,018h,01ch,00eh,006h,000h,003h,01fh,01fh,02fh,016h,009h,006h,004h	; ae69   p8......../....
	defb 000h,002h,004h,08ah,00ch,03ch,0fch,0f8h,0f4h,0e8h,090h,060h,070h,030h,003h,000h	; ae79  .....<.....`p0..
	defb 084h,00fh,003h,00dh,002h,003h,000h,084h,003h,01fh,0fch,0e0h,006h,000h,086h,0c0h	; ae89  ................
	defb 0e0h,0e0h,0f3h,0f7h,07ah,003h,078h,084h,060h,018h,060h,000h,000h	; ae99  ....z.x.`.`..

; ----------------------------------------------------------------------
; DATOS sprites_grandes: Comprimido con palabra; 544 bytes = 17 patrones
;   (0x9227). Los ocho ultimos patrones se comparten: 0xAF73 entra a media
;   tira y acaba en el mismo sitio
;   0xaea6..0xaf73  (205 bytes)
DATA_sprites_grandes:
	defb 000h,01bh,00ch,000h,084h,03eh,063h,0e3h,03eh,00eh,000h,081h,080h,004h,000h,0adh	; aea6  .....>c.>.......
	defb 001h,003h,003h,015h,00bh,003h,017h,00bh,007h,00eh,02fh,06bh,0c3h,002h,012h,067h	; aeb6  ........../k...g
	defb 0b7h,0f7h,0fah,0fdh,0ffh,0ffh,0f0h,0efh,0d0h,0e0h,001h,080h,0c0h,000h,080h,070h	; aec6  ...............p
	defb 03ch,07eh,0fah,0fbh,0fdh,0feh,07fh,0bdh,05eh,03ah,007h,00fh,01fh,00ah,000h,0a8h	; aed6  <~......^:......
	defb 040h,080h,000h,040h,070h,0b0h,003h,002h,007h,007h,00fh,00fh,01fh,03bh,07bh,0f7h	; aee6  @..@p........;{.
	defb 0f7h,0e7h,04fh,02fh,01fh,03fh,04fh,0efh,0efh,0f7h,0ebh,0cfh,0cfh,087h,096h,0bah	; aef6  ..O/.?O.........
	defb 09dh,09eh,0dfh,0dbh,0cbh,0edh,060h,0d5h,007h,0ffh,08ah,06fh,02fh,037h,095h,0a5h	; af06  ......`....o/7..
	defb 0cbh,0f2h,0dfh,07dh,0fdh,003h,0feh,09ah,0fah,0f9h,0dbh,0d7h,0b7h,0afh,0afh,05fh	; af16  ...}..........._
	defb 07fh,0ffh,070h,070h,078h,078h,0fch,0feh,0ffh,0f7h,0f7h,0fbh,0fbh,0f9h,0edh,0ech	; af26  ..ppxx..........
	defb 0eeh,0f7h,008h,000h,006h,080h,002h,000h,003h,0ffh,085h,07fh,03fh,03fh,00fh,003h	; af36  ............??..
	defb 008h,000h,08ah,0b7h,0dbh,0dch,0dfh,0efh,0f3h,0fch,0ffh,00fh,003h,006h,000h,085h	; af46  ................
	defb 0e7h,0ffh,0ffh,03eh,0c1h,005h,0ffh,081h,07eh,005h,000h,007h,0ffh,083h,0feh,0e0h	; af56  ...>....~.......
	defb 080h,006h,000h,002h,0dch,085h,0ech,0e8h,0e0h,0e0h,080h,019h,000h	; af66  .............

; ----------------------------------------------------------------------
; DATOS sprites_grandes_cola: 256 bytes = 8 patrones, la cola del bloque de
;   arriba. 0x8AEC los lleva a 0x1CC0 y 0x90C5 a 0x1C20
;   0xaf73..0xb060  (237 bytes)
DATA_sprites_grandes_cola:
	defb 089h,049h,03eh,03fh,07fh,0bfh,07fh,03eh,04dh,010h,009h,000h,085h,080h,000h,080h	; af73  .I>?...>M.......
	defb 000h,080h,009h,000h,0c0h,001h,002h,008h,00ch,004h,021h,00ch,009h,031h,08ch,0d8h	; af83  ..........!..1..
	defb 0fdh,07dh,07fh,03fh,00fh,000h,010h,0a0h,020h,034h,090h,0c0h,09ch,044h,056h,0dbh	; af93  .}.?.... 4...DV.
	defb 0ffh,0eeh,0feh,0fch,0f0h,000h,000h,004h,000h,000h,009h,003h,019h,012h,02ah,05bh	; afa3  ..............*[
	defb 07fh,077h,07fh,03fh,00fh,080h,000h,020h,040h,040h,004h,020h,000h,080h,030h,01ah	; afb3  .w.?... @@. ..0.
	defb 0beh,0beh,0feh,0fch,0f0h,005h,000h,08eh,002h,000h,001h,001h,000h,008h,031h,025h	; afc3  ..............1%
	defb 012h,01bh,007h,000h,000h,080h,003h,000h,098h,040h,000h,040h,050h,090h,08ch,0d4h	; afd3  .........@.@P...
	defb 0e8h,068h,0e0h,000h,000h,001h,019h,01dh,00bh,007h,03fh,03fh,03eh,03dh,01bh,00ah	; afe3  .h........??>=..
	defb 002h,004h,000h,08ch,0e0h,0f0h,0f8h,0e0h,0dch,0b0h,040h,0e0h,070h,038h,014h,00ch	; aff3  ..........@.p8..
	defb 003h,000h,082h,007h,01fh,003h,03fh,086h,007h,039h,006h,00eh,015h,018h,005h,000h	; b003  ......?..9......
	defb 086h,008h,01ch,0b8h,0b0h,0c0h,0f0h,003h,0fch,084h,07ah,074h,008h,070h,003h,000h	; b013  ..........zt.p..
	defb 086h,010h,038h,01dh,00dh,003h,00fh,003h,03fh,084h,05eh,02eh,010h,00eh,003h,000h	; b023  ..8.....?.^.....
	defb 082h,0e0h,0f8h,003h,0fch,086h,0e0h,09ch,060h,070h,0a8h,018h,006h,000h,08ch,007h	; b033  ........`p......
	defb 00fh,01fh,007h,03bh,00dh,002h,007h,00eh,01ch,028h,030h,004h,000h,08eh,080h,098h	; b043  ...;.....(0.....
	defb 0b8h,0d0h,0e0h,0fch,0fch,07ch,0bch,0d8h,050h,040h,000h,000h,000h	; b053  .....|..P@...

; ----------------------------------------------------------------------
; DATOS mas_sprites_grandes: Comprimido con palabra; 256 bytes = 8 patrones
;   (0x90CB)
;   0xb060..0xb124  (196 bytes)
DATA_mas_sprites_grandes:
	defb 040h,01ch,083h,081h,042h,024h,01dh,000h,08bh,090h,088h,084h,040h,030h,010h,008h	; b060  @...B$......@0..
	defb 00ch,00fh,007h,003h,005h,000h,08ah,024h,044h,084h,008h,030h,020h,040h,0c0h,0c0h	; b070  .......$D..0 @..
	defb 080h,009h,000h,08dh,018h,02ch,00dh,00fh,01fh,03fh,037h,03bh,03dh,01fh,007h,017h	; b080  .....,...?7;=...
	defb 01bh,003h,000h,09fh,018h,034h,0b0h,0f0h,0f8h,0fch,0ech,0dch,0bch,0f8h,0e0h,0e8h	; b090  .....4..........
	defb 0d8h,000h,000h,003h,00fh,01fh,03fh,03fh,07fh,07fh,0ffh,0f6h,0e2h,0c0h,080h,082h	; b0a0  ......??........
	defb 003h,00fh,07eh,003h,0fch,088h,0feh,0ffh,0feh,0f0h,024h,01ch,03ch,07eh,003h,0ffh	; b0b0  ..~.......$.<~..
	defb 08ah,03eh,03ch,03ch,01ch,01bh,01eh,00eh,00ch,00ch,006h,006h,000h,090h,0f9h,0f8h	; b0c0  .><<............
	defb 07ch,03eh,07fh,0ffh,0ffh,0fch,0f8h,078h,03ch,01ch,00eh,01eh,030h,020h,007h,000h	; b0d0  |>.....x<...0 ..
	defb 089h,001h,007h,00fh,01fh,01fh,03ch,030h,062h,083h,006h,000h,087h,03fh,0fch,0f8h	; b0e0  ......<0b....?..
	defb 0e4h,0dch,03ch,07eh,003h,0ffh,006h,000h,084h,003h,007h,00fh,00fh,005h,01fh,08ah	; b0f0  ..<~............
	defb 00fh,018h,02ch,00dh,00fh,01fh,03fh,0b7h,0fbh,0fdh,007h,0ffh,003h,00fh,002h,007h	; b100  ..,...?.........
	defb 002h,003h,081h,001h,008h,000h,004h,0ffh,082h,0feh,0fch,003h,0f8h,083h,07ch,01ch	; b110  ..............|.
	defb 006h,004h,000h,000h	; b120

; ----------------------------------------------------------------------
; DATOS sprites_del_final: Comprimido con palabra; 160 bytes = 5 patrones
;   (0x9648)
;   0xb124..0xb17b  (87 bytes)
DATA_B124:
	defb 020h,01ch,007h,000h,088h,007h,01fh,038h,070h,070h,034h,018h,007h,008h,000h,088h	; b124   ......8pp4.....
	defb 0e0h,0f8h,07ch,03eh,03eh,03ch,078h,0e0h,008h,000h,088h,007h,01fh,03eh,07ch,07ch	; b134  ..|>><x......>||
	defb 03ch,01eh,007h,008h,000h,088h,0e0h,0f8h,01ch,00eh,00eh,02ch,018h,0e0h,00ch,000h	; b144  <..........,....
	defb 084h,010h,034h,018h,007h,00ch,000h,084h,030h,03ch,078h,0e0h,027h,000h,08ah,007h	; b154  ..4.....0<x.'...
	defb 01fh,03dh,076h,078h,074h,078h,035h,01eh,007h,006h,000h,08ah,0e0h,0f8h,0bch,05eh	; b164  .=vxtx5........^
	defb 03eh,00eh,05eh,02ch,0f8h,0e0h,000h	; b174

; ----------------------------------------------------------------------
; DATOS patrones_del_cartel: Comprimido; 328 bytes a 0x2138 en los tres bancos
;   (0x5662)
;   0xb17b..0xb285  (266 bytes)
DATA_patrones_del_cartel:
	defb 007h,003h,082h,001h,07fh,00dh,03fh,002h,000h,090h,007h,03fh,03fh,0ffh,03fh,0ffh	; b17b  ......?....??.?.
	defb 000h,000h,03fh,03eh,03eh,03fh,03eh,03fh,000h,000h,003h,0ffh,082h,007h,003h,003h	; b18b  ..?>>?>?........
	defb 0e3h,085h,07fh,03fh,03fh,038h,030h,003h,031h,002h,0ffh,083h,003h,083h,0d3h,003h	; b19b  ...??80.1.......
	defb 0abh,08dh,053h,0d3h,023h,0f3h,013h,003h,003h,001h,07fh,03fh,0c0h,0c1h,0cah,003h	; b1ab  ..S.#......?....
	defb 0d5h,086h,0cah,0c8h,0c7h,0c8h,0cfh,0c0h,004h,0ffh,09ch,003h,093h,0f3h,023h,0f3h	; b1bb  ..............#.
	defb 013h,023h,0f3h,00bh,0f3h,00bh,003h,003h,001h,07fh,03fh,0c0h,0c9h,0c8h,0c7h,0c8h	; b1cb  .#........?.....
	defb 0cfh,0c4h,0c4h,0cfh,0d0h,0cfh,0c0h,004h,0ffh,083h,003h,0c3h,023h,003h,013h,002h	; b1db  ............#...
	defb 023h,094h,013h,0e3h,013h,003h,003h,001h,07fh,03fh,0c0h,0c6h,0c8h,0c4h,0c8h,0d1h	; b1eb  #........?......
	defb 0d6h,0cch,0c7h,0c8h,0cfh,0c0h,004h,0ffh,09ch,003h,09bh,08bh,003h,09bh,0abh,04bh	; b1fb  ...............K
	defb 0f3h,00bh,0f3h,00bh,003h,003h,001h,07fh,03fh,0c0h,0d0h,0d9h,0c0h,0d9h,0d5h,0d2h	; b20b  ........?.......
	defb 0d0h,0cfh,0d0h,0dfh,0c0h,004h,0ffh,006h,003h,0b1h,080h,0c5h,000h,000h,0f1h,0c0h	; b21b  ................
	defb 0ffh,07fh,000h,080h,000h,000h,0d8h,000h,0ffh,0ffh,000h,001h,000h,000h,00eh,000h	; b22b  ................
	defb 0ffh,0ffh,007h,06fh,003h,003h,05fh,007h,0ffh,0feh,048h,0a2h,000h,020h,001h,000h	; b23b  ...o.._...H.. ..
	defb 000h,080h,010h,044h,001h,008h,000h,000h,008h,000h,0ffh,004h,010h,081h,0ffh,004h	; b24b  ...D............
	defb 001h,081h,0ffh,004h,010h,017h,0ffh,002h,0e0h,087h,01fh,0ffh,00fh,00fh,0ffh,007h	; b25b  ................
	defb 007h,00bh,0ffh,08eh,003h,0ffh,0ffh,003h,0ffh,003h,03fh,000h,03fh,000h,000h,03fh	; b26b  ..........?.?..?
	defb 000h,000h,007h,003h,082h,001h,07fh,007h,03fh,000h	; b27b  ........?.

; ----------------------------------------------------------------------
; DATOS color_del_cartel: Los mismos 328 bytes de color, a 0x0138 y 0x0438
;   (0x5671 y 0x5677)
;   0xb285..0xb2fb  (118 bytes)
DATA_color_del_cartel:
	defb 006h,0feh,004h,0f1h,01eh,0e1h,002h,0ffh,006h,0e1h,002h,0f1h,006h,0e1h,00eh,0fah	; b285  ................
	defb 004h,0f1h,00eh,01ah,00eh,0f7h,004h,0f1h,00eh,017h,00eh,0f5h,004h,0f1h,00eh,015h	; b295  ................
	defb 00eh,0f6h,004h,0f1h,00eh,016h,008h,0feh,007h,01ah,081h,014h,017h,01ah,081h,014h	; b2a5  ................
	defb 010h,054h,004h,016h,081h,018h,004h,016h,081h,018h,004h,016h,002h,018h,0a0h,088h	; b2b5  .T..............
	defb 011h,088h,066h,066h,011h,088h,066h,066h,011h,088h,066h,011h,088h,066h,011h,088h	; b2c5  ..ff..ff..f..f..
	defb 011h,088h,066h,066h,011h,081h,061h,016h,016h,018h,016h,016h,018h,016h,016h,008h	; b2d5  ..ff..a.........
	defb 044h,008h,0feh,008h,0e1h,086h,0feh,0f1h,0feh,0f1h,0f1h,0feh,004h,0f1h,086h,0e1h	; b2e5  D...............
	defb 0f1h,0f1h,0e1h,0f1h,0e1h,000h	; b2f5

; ----------------------------------------------------------------------
; DATOS patrones_del_marco: 24 bytes a 0x2500 (0x5680)
;   0xb2fb..0xb314  (25 bytes)
DATA_patrones_del_marco:
	defb 08eh,000h,068h,045h,062h,045h,068h,000h,000h,000h,0aeh,024h,024h,024h,0a4h,004h	; b2fb  ..hEbEh....$$$..
	defb 000h,086h,018h,000h,000h,018h,000h,000h,000h	; b30b  .........

; ----------------------------------------------------------------------
; DATOS color_del_marco: 24 bytes a 0x0500 (0x5689); tres bytes comprimidos,
;   que es una repeticion y el cero de cierre
;   0xb314..0xb317  (3 bytes)
DATA_color_del_marco:
	defb 018h,0f1h,000h	; b314

; ----------------------------------------------------------------------
; DATOS casillas_de_las_fases_0_3_y_7: Comprimido; 640 bytes = 80 casillas a
;   0x2280, y la copia espejada a 0x2580
;   0xb317..0xb4d0  (441 bytes)
DATA_casillas_de_las_fases_0_3_y_7:
	defb 002h,07fh,005h,0ffh,081h,07fh,008h,0dah,099h,0ffh,07fh,01fh,007h,009h,006h,001h	; b317  ................
	defb 000h,0fah,0fah,0f6h,0f6h,0cdh,039h,0f3h,003h,007h,007h,00fh,00fh,01fh,01fh,03fh	; b327  ......9........?
	defb 03fh,000h,006h,0ffh,083h,07fh,000h,0d8h,006h,0dah,002h,007h,002h,00fh,081h,01fh	; b337  ?...............
	defb 003h,000h,005h,0dah,081h,01ah,003h,000h,00eh,0ffh,003h,07fh,003h,0ffh,003h,000h	; b347  ................
	defb 008h,0aeh,08dh,080h,0c0h,0e0h,0f0h,0f9h,0fdh,0feh,0ffh,0bfh,0c7h,0ebh,0f5h,0f4h	; b357  ................
	defb 003h,0fah,08ah,0bfh,0dfh,0efh,0f7h,0fbh,0fdh,0feh,0ffh,000h,0ach,008h,0aeh,088h	; b367  ................
	defb 00eh,0f2h,0fch,0ffh,000h,000h,01fh,07fh,00bh,0ffh,08ah,07fh,03fh,007h,080h,0dfh	; b377  ............?...
	defb 0efh,0e7h,0ebh,0f5h,0f6h,003h,0f7h,002h,0efh,082h,0dfh,03fh,00ah,0ffh,0a8h,044h	; b387  ...........?...D
	defb 033h,0fdh,06eh,080h,048h,066h,0bfh,0a4h,092h,0fdh,06eh,0c4h,062h,03bh,0efh,0ffh	; b397  3.n.Hf....n.b;..
	defb 0ffh,0c0h,0c0h,0f0h,0f0h,0fch,0fch,0ffh,0ffh,0c0h,0c0h,0e0h,0f8h,0f8h,0fch,040h	; b3a7  ...............@
	defb 031h,03bh,01bh,033h,031h,03ch,013h,010h,0ffh,090h,0e7h,0c3h,000h,081h,0c3h,0e7h	; b3b7  1;.31<..........
	defb 066h,000h,0e7h,0c3h,000h,081h,0c3h,0e7h,066h,000h,00ah,0ffh,002h,03fh,002h,00fh	; b3c7  f.......f....?..
	defb 002h,003h,002h,0ffh,002h,03fh,08ch,01fh,007h,007h,003h,074h,0f8h,071h,03eh,07fh	; b3d7  .....?.....t.q>.
	defb 0efh,0dfh,0dfh,060h,000h,09dh,005h,020h,010h,082h,000h,020h,004h,000h,001h,080h	; b3e7  ...`... ... ....
	defb 014h,02ah,018h,01eh,040h,012h,082h,010h,025h,02ah,01eh,080h,010h,041h,050h,006h	; b3f7  .*..@...%*...AP.
	defb 006h,040h,009h,003h,060h,005h,000h,08bh,020h,004h,000h,01fh,01fh,03fh,03fh,0ffh	; b407  .@..`... ....??.
	defb 020h,004h,000h,008h,0feh,082h,07fh,03fh,006h,07fh,006h,0feh,082h,0fch,000h,007h	; b417   ......?........
	defb 07fh,005h,000h,002h,07fh,086h,03fh,000h,01fh,01fh,03fh,03fh,003h,0ffh,005h,000h	; b427  ......?...??....
	defb 003h,07fh,088h,000h,01eh,01eh,03eh,03eh,0feh,0feh,0fch,005h,000h,084h,010h,082h	; b437  ......>>........
	defb 008h,0e7h,003h,000h,088h,010h,041h,004h,038h,0ffh,000h,0efh,0f7h,005h,0ffh,0d4h	; b447  ......A.8.......
	defb 000h,087h,0eeh,0fch,0fbh,0f7h,0f9h,0fbh,0e0h,0f0h,0e8h,000h,000h,080h,084h,0b8h	; b457  ................
	defb 007h,046h,036h,036h,09dh,0e3h,0e7h,03eh,038h,060h,0b2h,0d7h,0e7h,072h,0beh,01ch	; b467  .F66...>8`...r..
	defb 0efh,076h,035h,033h,01bh,03bh,031h,040h,0dch,0beh,072h,0e7h,0d7h,0b2h,068h,070h	; b477  .v53.;1@..r...hp
	defb 0ffh,0dfh,0efh,0e4h,0f4h,0f4h,0fch,0fch,0cfh,02bh,0c3h,003h,040h,0a0h,0f8h,0fch	; b487  .........+..@...
	defb 0cch,086h,006h,007h,00fh,01fh,03fh,01fh,0a1h,091h,066h,03ch,0bdh,0dbh,0c3h,0e7h	; b497  ......?...f<....
	defb 0f4h,0f3h,0cch,083h,003h,000h,0a1h,098h,042h,024h,0ffh,000h,0ffh,009h,032h,0c4h	; b4a7  ........B$....2.
	defb 090h,04ch,0a3h,018h,027h,0c4h,0f8h,0ffh,008h,030h,0c0h,000h,0c3h,03ch,000h,081h	; b4b7  .L..'....0...<..
	defb 003h,007h,003h,007h,00fh,00fh,007h,001h,000h	; b4c7  .........

; ----------------------------------------------------------------------
; DATOS color_de_las_fases_0_3_y_7: Los 640 de color, a 0x0280 y 0x0580. Las
;   fases 3 y 7 usan ESTE MISMO guion pasado por el traductor de 0x443B con
;   (0xE661) a 1 y a 2, que baja 0x50 o 0xA0 a cinco codigos: de ahi salen
;   tres paletas de un solo bloque
;   0xb4d0..0xb570  (160 bytes)
DATA_color_de_las_fases_0_3_y_7:
	defb 07fh,0e1h,011h,0e1h,010h,0ech,010h,0e1h,008h,010h,084h,09ch,08ch,086h,086h,003h	; b4d0  ................
	defb 016h,099h,014h,09ch,08ch,08ch,086h,018h,016h,016h,014h,088h,011h,0e8h,0e6h,0e6h	; b4e0  ................
	defb 0e1h,0e8h,0e6h,066h,011h,0e8h,0e6h,0e1h,0e8h,0e6h,0e1h,008h,01ch,086h,088h,011h	; b4f0  ...f............
	defb 088h,066h,066h,011h,00ah,0e1h,002h,01bh,006h,0fbh,008h,01bh,097h,088h,011h,088h	; b500  .ff.............
	defb 066h,066h,011h,0cch,0cch,088h,011h,08ch,06ch,06ch,01ch,08ch,06ch,066h,011h,08ch	; b510  ff......ll..lf..
	defb 06ch,01ch,08ch,06ch,009h,01ch,060h,000h,00bh,0ach,083h,03ch,02ch,01ch,005h,0ach	; b520  l..l..`....<,...
	defb 082h,03ch,01ch,004h,0ach,087h,0ech,01ch,0ach,0ach,0ech,0ech,01ch,004h,0e1h,004h	; b530  .<..............
	defb 0ach,005h,0c1h,003h,0ach,081h,051h,007h,0e1h,081h,051h,007h,0e5h,008h,0e1h,007h	; b540  ......Q...Q.....
	defb 0e5h,015h,0e1h,003h,0e5h,009h,0e1h,007h,054h,081h,0c4h,006h,054h,002h,0c4h,038h	; b550  ........T...T..8
	defb 01ch,012h,01bh,005h,06bh,081h,061h,008h,06bh,020h,016h,003h,06ch,005h,01ch,000h	; b560  ....k.a.k ..l...

; ----------------------------------------------------------------------
; DATOS casillas_de_la_fase_1: 488 bytes = 61 casillas
;   0xb570..0xb647  (215 bytes)
DATA_casillas_de_la_fase_1:
	defb 098h,008h,007h,012h,04ch,030h,048h,009h,080h,002h,004h,010h,042h,009h,090h,080h	; b570  ....L0H.....B...
	defb 065h,000h,005h,021h,002h,010h,041h,006h,001h,003h,0ffh,0a9h,0dfh,09fh,0bfh,07fh	; b580  e..!..A.........
	defb 07fh,09fh,03fh,067h,013h,08fh,00fh,031h,043h,02fh,01fh,007h,053h,08bh,00eh,029h	; b590  ..?g...1C/..S..)
	defb 017h,04bh,031h,00fh,01fh,033h,047h,03fh,09fh,020h,086h,041h,004h,016h,02fh,063h	; b5a0  .K1..3G?. .A../c
	defb 0ffh,006h,049h,0cfh,0bfh,00ch,0ffh,090h,04ah,024h,000h,000h,030h,048h,009h,080h	; b5b0  ..I.....J$..0H..
	defb 06fh,095h,043h,009h,001h,048h,002h,010h,07fh,000h,021h,000h,00ah,0ffh,002h,03fh	; b5c0  o.C..H....!....?
	defb 002h,00fh,002h,003h,002h,0ffh,002h,03fh,084h,01fh,007h,007h,003h,069h,000h,092h	; b5d0  .......?.....i..
	defb 030h,032h,032h,040h,040h,004h,004h,030h,078h,078h,038h,002h,002h,020h,020h,000h	; b5e0  022@@..0xx8..  .
	defb 040h,040h,003h,00eh,002h,0c0h,003h,00eh,002h,020h,002h,081h,0b1h,000h,0ffh,0fah	; b5f0  @@....... ......
	defb 0feh,0fdh,0efh,0feh,0f9h,0feh,060h,0c0h,098h,0ech,070h,0f0h,0eeh,0bch,0f0h,0e0h	; b600  ......`...p.....
	defb 0f8h,0ach,070h,0f0h,0d6h,0ech,0bch,0eeh,0f0h,0f0h,0ech,0b8h,0c0h,060h,000h,060h	; b610  ..p..........`.`
	defb 0dah,0edh,0fbh,0eeh,0ffh,0feh,0ffh,0f6h,0fbh,0ach,070h,0f0h,0d6h,0ech,003h,0ffh	; b620  ..........p.....
	defb 095h,0fbh,0ffh,0bdh,0edh,09ah,0f9h,0b6h,032h,032h,040h,040h,004h,004h,030h,078h	; b630  ........22@@..0x
	defb 078h,038h,002h,06ch,0d9h,066h,000h	; b640

; ----------------------------------------------------------------------
; DATOS color_de_la_fase_1: Los 488 bytes de color, a 0x0280 y 0x0580
;   0xb647..0xb6ae  (103 bytes)
DATA_color_de_la_fase_1:
	defb 084h,0ach,03ch,01ch,03ch,003h,01ch,086h,0ach,01ch,0ach,0ach,01ch,03ch,007h,01ch	; b647  ..<.<........<..
	defb 081h,0ach,03bh,01ch,004h,08ch,004h,01ch,004h,08ch,004h,01ch,07fh,000h,021h,000h	; b657  ..;...........!.
	defb 086h,088h,011h,088h,066h,066h,011h,003h,088h,08fh,011h,088h,068h,068h,018h,088h	; b667  ....ff......hh..
	defb 068h,066h,011h,088h,068h,018h,088h,068h,018h,068h,000h,003h,098h,085h,018h,098h	; b677  hf..h..h.h......
	defb 018h,098h,018h,003h,0c8h,093h,018h,098h,018h,098h,018h,098h,098h,018h,098h,098h	; b687  ................
	defb 018h,098h,018h,0e8h,0e8h,018h,098h,018h,098h,03ch,018h,086h,098h,018h,098h,018h	; b697  .........<......
	defb 098h,018h,003h,0c8h,005h,018h,000h	; b6a7

; ----------------------------------------------------------------------
; DATOS casillas_de_la_fase_2: 472 bytes = 59 casillas
;   0xb6ae..0xb7fe  (336 bytes)
DATA_casillas_de_la_fase_2:
	defb 092h,008h,044h,033h,001h,010h,048h,066h,040h,070h,012h,001h,0e7h,080h,062h,03bh	; b6ae  ..D3..Hf@p....b;
	defb 010h,0feh,003h,007h,000h,082h,0fch,007h,007h,000h,086h,002h,000h,002h,004h,00fh	; b6be  ................
	defb 0ffh,003h,000h,085h,008h,000h,008h,010h,0e0h,00ah,004h,081h,000h,003h,004h,085h	; b6ce  ................
	defb 009h,001h,008h,008h,000h,003h,008h,002h,002h,002h,000h,086h,080h,070h,00ch,002h	; b6de  .............p..
	defb 002h,001h,005h,0ffh,085h,0fch,0fdh,0f0h,0ffh,060h,006h,000h,088h,0ffh,0f8h,0c0h	; b6ee  .........`......
	defb 000h,000h,00dh,0e0h,0f8h,003h,0ffh,002h,0fdh,087h,0fbh,0d9h,001h,003h,0ffh,0ffh	; b6fe  ................
	defb 01ch,004h,000h,088h,03fh,00fh,080h,0e0h,0f8h,0feh,0ffh,0ffh,003h,001h,084h,002h	; b70e  ....?...........
	defb 007h,01fh,0f0h,00bh,000h,089h,004h,000h,004h,0f8h,0ffh,00fh,01fh,0e3h,0fch,015h	; b71e  ................
	defb 0ffh,088h,007h,01fh,07bh,012h,0c0h,0f0h,0fch,0feh,003h,07fh,088h,00eh,0f1h,0ffh	; b72e  ....{...........
	defb 07fh,03fh,01eh,0c0h,0f8h,045h,0ffh,002h,000h,002h,0c0h,002h,0f0h,002h,0fch,002h	; b73e  .?...E..........
	defb 000h,002h,0c0h,084h,0e0h,0f8h,0f8h,0fch,008h,000h,0b8h,0e0h,0e2h,0d0h,080h,0a4h	; b74e  ................
	defb 080h,090h,040h,0e8h,0e2h,0d0h,0a0h,084h,060h,061h,088h,030h,018h,01ah,01ch,018h	; b75e  ..@.....`a.0....
	defb 014h,01ah,034h,030h,010h,019h,0d0h,0f8h,0f0h,0e4h,0e0h,021h,028h,020h,034h,010h	; b76e  ..40.......!( 4.
	defb 010h,018h,01ah,0a0h,042h,028h,010h,01ah,018h,034h,039h,018h,01ch,01ch,01ah,01ch	; b77e  ....B(...49.....
	defb 019h,014h,039h,008h,000h,098h,088h,0a0h,0d0h,064h,030h,014h,018h,039h,030h,038h	; b78e  ..9......d0..908
	defb 070h,074h,0e0h,0f2h,0e0h,0c8h,008h,021h,090h,040h,024h,010h,010h,019h,008h,0ffh	; b79e  pt.....!.@$.....
	defb 0a0h,000h,004h,020h,012h,0e0h,004h,010h,082h,000h,041h,013h,00eh,040h,001h,008h	; b7ae  ... ......A..@..
	defb 070h,000h,020h,008h,008h,030h,001h,000h,040h,020h,002h,008h,040h,00ah,028h,001h	; b7be  p. ..0..@ ..@.(.
	defb 084h,004h,000h,084h,010h,082h,008h,0e7h,003h,000h,08dh,010h,041h,004h,038h,0ffh	; b7ce  ............A.8.
	defb 004h,086h,020h,030h,000h,040h,000h,002h,003h,0ffh,092h,0f1h,04ah,020h,000h,011h	; b7de  .. 0.@......J ..
	defb 0ffh,0feh,0e4h,010h,042h,000h,088h,000h,000h,004h,040h,000h,020h,00bh,000h,000h	; b7ee  ....B.....@. ...

; ----------------------------------------------------------------------
; DATOS color_de_la_fase_2: Los 472 bytes de color, a 0x0280 y 0x0580
;   0xb7fe..0xb871  (115 bytes)
DATA_color_de_la_fase_2:
	defb 083h,098h,068h,068h,004h,016h,082h,041h,098h,003h,068h,003h,016h,081h,041h,010h	; b7fe  ..hh...A..h...A.
	defb 069h,030h,089h,008h,069h,008h,019h,005h,086h,084h,061h,091h,091h,088h,007h,061h	; b80e  i0..i.....a....a
	defb 081h,098h,007h,086h,002h,061h,006h,091h,006h,089h,00ah,086h,007h,089h,083h,086h	; b81e  .....a..........
	defb 061h,061h,016h,091h,084h,098h,086h,061h,061h,007h,091h,082h,098h,068h,004h,061h	; b82e  aa.....aa....h.a
	defb 03fh,091h,098h,088h,011h,088h,066h,066h,011h,099h,099h,088h,011h,098h,096h,096h	; b83e  ?.....ff........
	defb 091h,098h,098h,066h,011h,098h,096h,091h,098h,096h,091h,060h,069h,008h,099h,00eh	; b84e  ...f.......`i...
	defb 089h,002h,069h,010h,089h,007h,054h,081h,094h,006h,054h,082h,094h,099h,008h,089h	; b85e  ..i...T...T.....
	defb 020h,069h,000h	; b86e

; ----------------------------------------------------------------------
; DATOS casillas_de_la_fase_4: 632 bytes = 79 casillas
;   0xb871..0xba5b  (490 bytes)
DATA_casillas_de_la_fase_4:
	defb 081h,00ch,003h,008h,085h,098h,0f8h,038h,018h,030h,005h,010h,002h,018h,082h,066h	; b871  .......8.0.....f
	defb 046h,004h,042h,08bh,043h,063h,06dh,025h,025h,027h,035h,02dh,025h,0e5h,018h,004h	; b881  F.B.Ccm%%'5-%...
	defb 008h,002h,00ch,084h,00eh,01ch,01fh,019h,005h,010h,085h,07ah,0ceh,0c6h,0c2h,042h	; b891  ...........z...B
	defb 003h,043h,0b4h,077h,03dh,02dh,027h,025h,035h,03dh,0efh,00fh,00dh,008h,008h,088h	; b8a1  .C.w=-'%5=......
	defb 0c8h,078h,038h,030h,0f0h,070h,030h,018h,018h,01ch,01eh,042h,062h,066h,07eh,066h	; b8b1  .x80.p0....Bbf~f
	defb 042h,043h,043h,065h,025h,027h,035h,02dh,025h,027h,0a5h,018h,018h,008h,008h,00ch	; b8c1  BCCe%'5-%'......
	defb 00ch,00eh,00fh,013h,010h,018h,018h,003h,010h,083h,0f8h,0c3h,0c2h,003h,042h,09ch	; b8d1  ..............B.
	defb 062h,066h,07fh,0e5h,037h,02dh,02dh,025h,027h,025h,0b5h,0ffh,041h,021h,011h,09fh	; b8e1  bf..7--%'%..A!..
	defb 0f0h,03eh,019h,0ffh,041h,021h,011h,01fh,010h,01eh,011h,0ffh,003h,041h,08dh,07fh	; b8f1  .>..A!.......A..
	defb 064h,042h,043h,0ffh,041h,021h,021h,03fh,024h,026h,0b5h,00ch,004h,008h,0bch,088h	; b901  dBC.A!!?$&......
	defb 068h,038h,018h,0fch,004h,003h,000h,000h,080h,0ffh,000h,080h,070h,0ffh,003h,000h	; b911  h8..........p...
	defb 000h,0ffh,01ch,01fh,019h,010h,090h,050h,070h,0f8h,004h,002h,001h,0ffh,000h,080h	; b921  .......Pp.......
	defb 060h,0ffh,042h,062h,0e6h,0feh,072h,012h,01bh,0ffh,0ffh,002h,004h,008h,0f9h,00fh	; b931  `.Bb..r.........
	defb 07ch,098h,0ffh,002h,004h,008h,0f8h,018h,078h,088h,0ffh,003h,002h,08ch,0feh,026h	; b941  |.......x......&
	defb 042h,0c2h,0ffh,002h,004h,004h,0fch,024h,064h,0adh,010h,000h,006h,0ffh,002h,010h	; b951  B......$d.......
	defb 002h,000h,002h,0c0h,002h,0f0h,002h,0fch,002h,000h,002h,0c0h,003h,0f8h,081h,0fch	; b961  ................
	defb 068h,000h,081h,0ffh,003h,001h,081h,0ffh,003h,010h,0a1h,00ch,002h,0ffh,00ch,003h	; b971  h...............
	defb 0ffh,044h,0ffh,003h,001h,0ffh,00ch,003h,0ffh,044h,0ffh,001h,080h,0ffh,008h,006h	; b981  .D.......D......
	defb 0ffh,044h,0ffh,025h,0f7h,0edh,03dh,01dh,0ffh,045h,0ffh,0ffh,003h,001h,091h,0ffh	; b991  .D.%..=..E......
	defb 010h,018h,018h,0e0h,0e3h,0f7h,0e5h,0edh,06dh,02dh,00fh,0ffh,0c1h,081h,001h,0ffh	; b9a1  ........m-......
	defb 003h,010h,08dh,0c7h,0e7h,0efh,0f7h,0f7h,0f6h,0f4h,000h,0ffh,007h,01fh,03fh,03fh	; b9b1  ..............??
	defb 003h,07fh,089h,0ffh,03ch,038h,078h,0f8h,0b8h,070h,0ffh,0ffh,006h,05ah,083h,0dbh	; b9c1  ....<8x..p...Z..
	defb 0ffh,07fh,004h,0ffh,083h,07fh,01fh,07fh,004h,03fh,083h,01fh,00fh,00fh,008h,000h	; b9d1  .........?......
	defb 087h,07eh,081h,0ffh,0fdh,0feh,0feh,0ffh,009h,000h,002h,0feh,08bh,07fh,0ffh,0ffh	; b9e1  .~..............
	defb 07fh,07eh,07eh,0ffh,003h,001h,0ffh,0ffh,003h,010h,098h,000h,081h,0ffh,0fdh,0feh	; b9f1  .~~.............
	defb 0feh,0ffh,000h,07ch,0fch,0f8h,0f4h,0e8h,0d4h,02eh,0deh,03eh,0deh,0e0h,0e6h,0eeh	; ba01  ...|.......>....
	defb 00eh,0c2h,03ch,004h,0e7h,099h,0ffh,0c3h,03ch,0c3h,014h,01bh,0c8h,0e8h,0e0h,0e0h	; ba11  ..<.....<.......
	defb 0e8h,0dch,07fh,03eh,001h,03eh,001h,03eh,03ch,000h,0feh,07ch,080h,07ch,03ch,003h	; ba21  ...>.>.><..|.|<.
	defb 000h,099h,0f0h,0b0h,0b3h,0b7h,0b7h,0e7h,0d7h,0bbh,07eh,081h,07eh,000h,0c3h,066h	; ba31  ..........~.~..f
	defb 000h,000h,0ffh,000h,0bdh,0bdh,03ch,0bdh,018h,03ch,0ffh,003h,080h,086h,004h,006h	; ba41  ......<..<......
	defb 007h,007h,0ffh,0dbh,004h,05ah,082h,07eh,0ffh,000h	; ba51  .....Z.~..

; ----------------------------------------------------------------------
; DATOS color_de_la_fase_4: Los 632 bytes de color, a 0x0280 y 0x0580
;   0xba5b..0xbafb  (160 bytes)
DATA_color_de_la_fase_4:
	defb 07fh,014h,071h,014h,010h,000h,098h,088h,011h,088h,066h,066h,011h,014h,015h,088h	; ba5b  ..q.......ff....
	defb 011h,048h,056h,016h,041h,048h,056h,066h,011h,048h,056h,011h,048h,046h,051h,068h	; ba6b  .HV.AHVf.HV.HFQh
	defb 000h,003h,014h,081h,015h,003h,014h,081h,015h,023h,014h,087h,015h,014h,014h,094h	; ba7b  .........#......
	defb 095h,061h,064h,006h,061h,003h,014h,081h,015h,003h,014h,083h,015h,061h,064h,006h	; ba8b  .ad.a........ad.
	defb 061h,085h,011h,094h,064h,065h,061h,003h,064h,088h,011h,064h,014h,065h,061h,064h	; ba9b  a...dea.d..d.ead
	defb 064h,055h,008h,061h,007h,014h,089h,015h,061h,014h,094h,065h,061h,064h,014h,015h	; baab  dU.a....a..ead..
	defb 008h,000h,002h,061h,005h,069h,081h,061h,008h,000h,088h,061h,014h,091h,061h,061h	; babb  ...a.i.a...a..aa
	defb 064h,014h,015h,003h,014h,081h,055h,003h,014h,083h,015h,061h,061h,005h,069h,011h	; bacb  d.....U....aa.i.
	defb 061h,002h,069h,003h,068h,083h,061h,091h,096h,018h,061h,081h,091h,00bh,061h,004h	; badb  a.i.h.a...a...a.
	defb 0f1h,007h,061h,081h,015h,003h,014h,085h,015h,061h,064h,064h,065h,008h,061h,000h	; baeb  ..a......adde.a.

; ----------------------------------------------------------------------
; DATOS casillas_de_las_fases_5_y_6: 640 bytes = 80 casillas; las dos fases
;   comparten casillas Y color, y solo se diferencian en el mapa
;   0xbafb..0xbd5d  (610 bytes)
DATA_casillas_de_las_fases_5_y_6:
	defb 0b4h,080h,060h,030h,008h,000h,001h,081h,040h,009h,006h,000h,061h,018h,004h,000h	; bafb  ..`0....@...a...
	defb 000h,020h,010h,004h,084h,063h,001h,010h,00eh,0ceh,0e7h,073h,079h,01ch,08fh,047h	; bb0b  . ...c.....sy..G
	defb 023h,0ech,070h,001h,003h,00eh,0e4h,0e1h,0f4h,0f9h,0fch,0feh,0feh,0cfh,0f7h,0fbh	; bb1b  #.p.............
	defb 0f9h,0c0h,0f0h,0fch,0feh,004h,0ffh,0c2h,0feh,0ffh,0ffh,0fbh,03dh,08eh,0c7h,0c0h	; bb2b  ............=...
	defb 0e7h,0f9h,0fch,0fch,0fdh,07bh,03bh,051h,0fdh,0fch,0feh,07eh,0bfh,0dfh,0efh,0ffh	; bb3b  .....{;Q...~....
	defb 07fh,09fh,0e7h,0f1h,0f8h,0feh,0ffh,0ffh,0e3h,0f8h,0fch,0feh,0feh,07eh,00ch,0c1h	; bb4b  .............~..
	defb 0ceh,0e7h,073h,079h,01ch,0cfh,0f7h,0fbh,07dh,07ch,0beh,0deh,0ceh,017h,037h,09bh	; bb5b  ..sy....}|....7.
	defb 0ffh,0ffh,03fh,0cfh,031h,0cch,0f0h,0fch,0e0h,0fch,004h,0ffh,0a7h,03fh,0dfh,0f8h	; bb6b  ..?.1........?..
	defb 0fch,07eh,0beh,08fh,0b7h,0cbh,0f3h,03eh,00fh,007h,001h,00ch,00eh,007h,001h,024h	; bb7b  .~.....>.......$
	defb 019h,0c1h,0f8h,0fch,07eh,087h,0f9h,0f9h,0feh,0ffh,0ffh,07fh,03fh,09fh,0dfh,03bh	; bb8b  ....~.......?..;
	defb 00eh,003h,003h,001h,003h,000h,0a8h,03fh,007h,003h,001h,001h,07eh,00ch,0c1h,007h	; bb9b  .......?....~...
	defb 003h,001h,07fh,08fh,0b7h,0cbh,0f3h,006h,063h,001h,001h,0cfh,0f7h,0fbh,0f9h,008h	; bbab  ........c.......
	defb 044h,033h,001h,010h,048h,066h,040h,070h,012h,001h,0e7h,080h,062h,03bh,010h,008h	; bbbb  D3..Hf@p....b;..
	defb 000h,002h,0c8h,090h,088h,090h,010h,010h,090h,090h,0a0h,0c0h,0c0h,0e0h,0e0h,0f0h	; bbcb  ................
	defb 0e8h,0c8h,0ffh,0ffh,006h,000h,087h,07eh,03ch,099h,0c3h,03ch,042h,018h,003h,0ffh	; bbdb  .......~<..<B...
	defb 002h,0f8h,002h,07ch,002h,03eh,00ah,0ffh,002h,03fh,002h,00fh,002h,003h,002h,0ffh	; bbeb  ...|.>...?......
	defb 002h,03fh,085h,01fh,007h,007h,003h,0c8h,003h,0a8h,087h,0c8h,0d0h,0e0h,0f0h,0a0h	; bbfb  .?..............
	defb 0c0h,0c0h,003h,0a0h,08ah,020h,0a0h,0c8h,0e0h,0f0h,0e8h,0e8h,0c8h,0c8h,0e0h,004h	; bc0b  ..... ..........
	defb 000h,088h,0c0h,0f0h,0f8h,0fch,07eh,07ah,07eh,03ch,003h,000h,095h,001h,00fh,03fh	; bc1b  ......~z~<.....?
	defb 07fh,07fh,0feh,0ffh,0ffh,083h,000h,0c3h,0c7h,0efh,0efh,06fh,05dh,05bh,0c3h,0e7h	; bc2b  ...........o][..
	defb 0fdh,0ffh,003h,0feh,099h,0ffh,000h,0c0h,0e0h,0f1h,0f3h,0f3h,0bbh,0dbh,001h,000h	; bc3b  ................
	defb 000h,001h,001h,083h,03ch,07eh,0d8h,0dch,0efh,0eeh,0ceh,0c7h,087h,001h,003h,0feh	; bc4b  ....<~..........
	defb 002h,0ffh,08ch,07fh,03fh,01fh,0fch,0fbh,0dfh,0dfh,06fh,033h,08fh,081h,07bh,003h	; bc5b  ....?.....o3..{.
	defb 0cfh,002h,0fch,002h,0bfh,09ah,0b7h,0fch,0fch,08fh,087h,0c7h,0fdh,05fh,0c3h,081h	; bc6b  ............._..
	defb 0c3h,0c3h,0feh,037h,037h,0ech,0fbh,0bch,0f7h,07fh,0e5h,0c0h,0c1h,0e1h,018h,004h	; bc7b  ...77...........
	defb 006h,000h,088h,0ech,070h,001h,003h,006h,01bh,03eh,077h,003h,000h,08eh,001h,007h	; bc8b  ....p....>w.....
	defb 00dh,03fh,0f7h,001h,007h,01dh,0f7h,0feh,037h,037h,0ech,0deh,003h,0f3h,002h,0ffh	; bc9b  .?......77......
	defb 082h,07fh,03fh,004h,000h,084h,010h,082h,008h,0e7h,003h,000h,092h,010h,041h,004h	; bcab  ..?...........A.
	defb 038h,0ffh,003h,070h,0f4h,0f4h,0fch,0bch,0fch,0b4h,0b4h,0f4h,0fch,0f4h,0f4h,007h	; bcbb  8..p............
	defb 0fch,003h,0f4h,0a3h,0bch,0fch,0fch,0b4h,0bch,0f4h,0b4h,030h,000h,080h,000h,000h	; bccb  ...........0....
	defb 001h,020h,000h,0a2h,048h,000h,008h,000h,000h,008h,001h,044h,010h,0f0h,0fch,0fah	; bcdb  . ..H......D....
	defb 0f2h,0e2h,0f8h,0fch,0fch,0e2h,0dah,003h,0fch,087h,0f8h,0f6h,0feh,0fdh,0fdh,0fbh	; bceb  ................
	defb 0ffh,004h,0feh,002h,03fh,002h,05fh,081h,0efh,003h,0ffh,083h,05eh,018h,0ffh,004h	; bcfb  ....?._.....^...
	defb 0bdh,084h,0ffh,03eh,0ddh,01ch,003h,03eh,085h,01ch,080h,07fh,00fh,003h,003h,0feh	; bd0b  ...>...>........
	defb 086h,0f8h,080h,003h,003h,007h,007h,004h,00fh,08bh,0c0h,0e0h,0f8h,0c0h,0f0h,0fch	; bd1b  ................
	defb 0fch,0f8h,0ffh,0c3h,0c3h,004h,0ffh,084h,000h,00fh,01fh,01fh,003h,03fh,087h,007h	; bd2b  .............?..
	defb 000h,0f0h,0c8h,038h,0e0h,080h,003h,000h,098h,007h,003h,000h,007h,00fh,000h,000h	; bd3b  ...8............
	defb 0e0h,0e0h,0c0h,000h,000h,0c0h,0f0h,0f0h,007h,0ffh,0bfh,0cfh,0e3h,0c3h,087h,083h	; bd4b  ................
	defb 0c3h,000h	; bd5b

; ----------------------------------------------------------------------
; DATOS color_de_las_fases_5_y_6: Los 640 bytes de color, a 0x0280 y 0x0580
;   0xbd5d..0xbe41  (228 bytes)
DATA_color_de_las_fases_5_y_6:
	defb 022h,0e1h,003h,091h,007h,0e9h,074h,0e1h,00dh,09eh,003h,0e1h,003h,09eh,005h,0e1h	; bd5d  ".....t.........
	defb 004h,09eh,004h,0e1h,083h,098h,068h,068h,004h,016h,082h,041h,098h,003h,068h,003h	; bd6d  ......hh...A..h.
	defb 016h,081h,041h,008h,000h,010h,091h,008h,061h,005h,0b1h,083h,0f1h,0bdh,0bdh,008h	; bd7d  ..A.....a.......
	defb 061h,098h,088h,011h,088h,066h,066h,011h,099h,099h,088h,011h,089h,069h,069h,019h	; bd8d  a....ff......ii.
	defb 089h,069h,066h,011h,089h,069h,019h,089h,069h,019h,018h,091h,00fh,0b9h,081h,069h	; bd9d  .if..i..i......i
	defb 004h,0b9h,088h,0b1h,0b9h,0b9h,0b6h,0b9h,0b9h,0b6h,0b6h,006h,0b1h,006h,0bfh,003h	; bdad  ................
	defb 0b9h,003h,0b6h,002h,0b1h,081h,016h,004h,0b6h,083h,096h,0b9h,0b9h,005h,0b1h,003h	; bdbd  ................
	defb 0b6h,005h,0b9h,003h,0b1h,008h,061h,090h,096h,09eh,09eh,091h,09eh,091h,09fh,091h	; bdcd  ......a.........
	defb 096h,09fh,091h,09eh,09eh,091h,096h,096h,003h,09eh,084h,091h,096h,09fh,091h,003h	; bddd  ................
	defb 096h,002h,098h,002h,092h,082h,09ch,091h,00ah,0e1h,013h,091h,087h,09fh,091h,096h	; bded  ................
	defb 096h,09eh,09eh,091h,004h,09eh,00eh,054h,002h,094h,081h,041h,01fh,0a1h,010h,054h	; bdfd  .......T...A...T
	defb 020h,091h,002h,0b1h,002h,06fh,082h,061h,06fh,004h,061h,005h,0b6h,084h,061h,0b1h	; be0d   ....o.ao.a...a.
	defb 0b6h,0b6h,007h,069h,003h,0b9h,003h,0b1h,003h,061h,003h,0b6h,002h,0b1h,084h,011h	; be1d  ...i.....a......
	defb 01fh,01eh,011h,004h,061h,083h,0b1h,061h,061h,014h,0b1h,083h,091h,0b1h,061h,005h	; be2d  ....a..aa.....a.
	defb 0b1h,009h,091h,000h	; be3d

; ----------------------------------------------------------------------
; DATOS casillas_de_mas_de_la_fase_7: 136 bytes a 0x2470, y la copia espejada
;   a 0x2770; solo la fase 7 los carga (0x5544)
;   0xbe41..0xbeb7  (118 bytes)
DATA_casillas_de_mas_de_la_fase_7:
	defb 004h,000h,003h,001h,083h,00fh,01fh,07fh,006h,0ffh,08ah,0e0h,0fch,0ffh,0f8h,0e0h	; be41  ................
	defb 0c0h,080h,080h,0ffh,003h,006h,000h,002h,080h,083h,0c0h,060h,038h,003h,03fh,002h	; be51  ...........`8.?.
	defb 000h,081h,003h,005h,0ffh,0a1h,07fh,0ffh,0ffh,0f8h,0e0h,0c0h,080h,080h,000h,000h	; be61  ................
	defb 003h,0ffh,06bh,005h,030h,07ch,07ch,03eh,01fh,03fh,056h,0ach,0a8h,000h,07ch,018h	; be71  ..k.0||>.?V...|.
	defb 078h,0d0h,0b0h,0a0h,020h,000h,07fh,005h,0ffh,084h,06fh,015h,0c0h,010h,008h,000h	; be81  x... .....o.....
	defb 08ah,003h,0ffh,06bh,005h,0d0h,0fch,03fh,07fh,0fch,0f8h,004h,0f0h,085h,0f8h,0fch	; be91  ...k...?........
	defb 0ffh,07fh,03fh,003h,01fh,08ah,0f8h,07ch,02fh,015h,07fh,03fh,01fh,003h,01fh,07fh	; bea1  ..?....|/..?....
	defb 004h,0ffh,082h,07fh,01fh,000h	; beb1

; ----------------------------------------------------------------------
; DATOS color_de_las_casillas_de_mas: Los mismos 136 de color, a 0x0470 y
;   0x0770
;   0xbeb7..0xbecc  (21 bytes)
DATA_color_de_las_casillas_de_mas:
	defb 013h,064h,02bh,061h,012h,091h,016h,061h,002h,091h,002h,064h,009h,061h,005h,064h	; beb7  .d+a...a...d.a.d
	defb 004h,061h,00ch,014h,000h	; bec7

; ----------------------------------------------------------------------
; DATOS cuadros_del_remate: Cuatro punteros; 0x8DD5 indexa con (0xE3E0) y saca
;   una tabla de dos, que 0x8DDE indexa con (0xE3E1)
;   0xbecc..0xbed4  (8 bytes)
DATA_cuadros_del_remate:
	defw 0bed4h,0bf0ah,0bf53h,0bf93h	; becc  -> DATA_pareja_de_cuadros_0 DATA_pareja_de_cuadros_1 DATA_pareja_de_cuadros_2 DATA_pareja_de_cuadros_3

; ----------------------------------------------------------------------
; DATOS pareja_de_cuadros_0: Los dos cuadros de la variante 0; 0x8DDE elige
;   con (0xE3E1)
;   0xbed4..0xbed8  (4 bytes)
DATA_pareja_de_cuadros_0:
	defw 0bed8h,0bef1h	; bed4  -> DATA_cuadros_0 0xbef1

; ----------------------------------------------------------------------
; DATOS cuadros_0: Dos bloques de 25 casillas
;   0xbed8..0xbf0a  (50 bytes)
DATA_cuadros_0:
	defb 06bh,073h,090h,091h,092h,093h,097h,06eh,0f7h,094h,098h,099h,09ah,0f9h,0f8h,095h,09bh,09ch,0fbh,096h,09fh,09dh,09eh,0fdh,0ffh	; bed8  ks.....n.................
	defb 0f2h,0f1h,090h,0d3h,0cbh,0f4h,097h,06fh,0f7h,0f3h,098h,099h,09ah,0f9h,0f8h,0f6h,09bh,09ch,0fbh,0f5h,09fh,09dh,09eh,0fdh,0ffh	; bef1  .......o.................

; ----------------------------------------------------------------------
; DATOS pareja_de_cuadros_1: Los dos cuadros de la variante 1
;   0xbf0a..0xbf0e  (4 bytes)
DATA_pareja_de_cuadros_1:
	defw 0bf0eh,0bf2ch	; bf0a  -> DATA_cuadros_1 0xbf2c

; ----------------------------------------------------------------------
; DATOS cuadros_1: Dos bloques de 30 casillas
;   0xbf0e..0xbf4a  (60 bytes)
DATA_cuadros_1:
	defb 080h,0fdh,085h,09dh,080h,080h,0e8h,096h,088h,080h,089h,0fah,08bh,09ah,0e9h,08dh,0f4h,08fh,094h,091h,092h,0f5h,09ch,095h,08ah,08ch,098h,001h,099h,0ech	; bf0e  ..............................
	defb 080h,0fdh,085h,09dh,080h,080h,0e8h,096h,088h,080h,089h,0fah,08bh,09ah,0e9h,0f1h,0f4h,08fh,094h,0edh,0eah,0f5h,09ch,095h,087h,08ch,0f9h,001h,0f8h,0ech	; bf2c  ..............................

; ----------------------------------------------------------------------
; DATOS cuadro_de_tres_por_tres: Las nueve casillas que 0x8CDE pinta con su
;   `ld bc,00303h`
;   0xbf4a..0xbf53  (9 bytes)
DATA_cuadro_de_tres_por_tres:
	defb 086h,09eh,0e6h	; bf4a
	defb 097h,09bh,0f7h	; bf4d
	defb 0f4h,093h,094h	; bf50

; ----------------------------------------------------------------------
; DATOS pareja_de_cuadros_2: Los dos cuadros de la variante 2
;   0xbf53..0xbf57  (4 bytes)
DATA_pareja_de_cuadros_2:
	defw 0bf57h,0bf75h	; bf53  -> DATA_cuadros_2 0xbf75

; ----------------------------------------------------------------------
; DATOS cuadros_2: Dos bloques de 30 casillas
;   0xbf57..0xbf93  (60 bytes)
DATA_cuadros_2:
	defb 080h,081h,09fh,080h,081h,078h,079h,07ah,07bh,076h,07ch,07dh,06eh,0ddh,07eh,077h,07fh,095h,096h,097h,098h,099h,09ah,0f9h,0f8h,09dh,09ch,001h,09bh,09eh	; bf57  .....xyz{v|}n.~w..............
	defb 080h,081h,0ffh,080h,081h,0d6h,0dbh,07ah,0d9h,0d8h,0deh,07dh,06eh,0ddh,0dch,0f7h,0f6h,095h,0dfh,0d7h,098h,099h,09ah,0f9h,0f8h,0feh,0fbh,001h,0fch,0fdh	; bf75  .......z...}n.................

; ----------------------------------------------------------------------
; DATOS pareja_de_cuadros_3: Los dos cuadros de la variante 3
;   0xbf93..0xbf97  (4 bytes)
DATA_pareja_de_cuadros_3:
	defw 0bf97h,0bfbbh	; bf93  -> DATA_cuadros_3 0xbfbb

; ----------------------------------------------------------------------
; DATOS cuadros_3: Dos bloques de 36 casillas
;   0xbf97..0xbfdf  (72 bytes)
DATA_cuadros_3:
	defb 08eh,08fh,090h,0f0h,0efh,0eeh,09bh,091h,092h,0f2h,0f1h,0fbh,09ch,093h,094h,0f4h,0f3h,0fch,09bh,091h,092h,0f2h,0f1h,0fbh,09dh,095h,098h,0f8h,0fah,0fdh,09eh,096h,099h,0f9h,0f7h,0feh	; bf97  ....................................
	defb 08eh,08fh,090h,0f0h,0efh,0eeh,09bh,091h,092h,0f2h,0f1h,0fbh,09ch,093h,094h,0f4h,0f3h,0fch,09bh,091h,092h,0f2h,0f1h,0fbh,09dh,09ah,098h,0f8h,0f5h,0fdh,09eh,097h,099h,0f9h,0f6h,0feh	; bfbb  ....................................

; ----------------------------------------------------------------------
; DATOS relleno_del_final: Veinte bytes 0xFF hasta donde empieza la marca
;   0xbfdf..0xbff3  (20 bytes)
DATA_relleno_del_final:
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bfdf  ....................

; ----------------------------------------------------------------------
; DATOS marca_oculta_de_konami: マジョウデンセツ -Majou Densetsu- del reves, su
;   longitud (0x0A), el 0x39 de RC-739 y el 0xAA que cierra. La descubrio
;   Manuel Pazos; tools/marca_konami.py la lee
;   0xbff3..0xc000  (13 bytes)
DATA_marca_oculta_de_konami:
	defb 091h,08dh,0ach,0b7h,092h,082h,0b3h,0b7h,08bh,09eh,00ah,039h,0aah	; bff3  ...........9.
