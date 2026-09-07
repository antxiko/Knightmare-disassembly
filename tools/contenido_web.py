#!/usr/bin/env python3
"""El contenido propio de la portada de Knightmare: hallazgos y galeria.

Vive aparte de make_web.py a proposito: asi el generador no lleva dentro ni un
texto del cartucho anterior, que es de donde salen casi todos los restos de
copia y pega de esta serie.

Cada hallazgo dice QUE se ha medido y CON QUE, y cada pie de imagen dice de
donde sale el dibujo. Ninguna cifra esta escrita a ojo.
"""

HALLAZGOS = {
    "es": [
        ("Konami dejo dos erratas en sus tablas de coseno",
         "<p>El cartucho lleva dos cuadrantes de coseno, uno escalado a 255 "
         "(<code>0x844E</code>) y otro a 128 (<code>0x848F</code>), y con ellos "
         "saca el seno y el coseno de un angulo de 0 a 255. Un cuadrante de "
         "coseno <b>solo puede bajar</b>. Estos dos suben una vez cada uno, y "
         "el valor que sube es justo el unico que se aparta de la funcion: la "
         "entrada 58 de la primera vale <code>0x2F</code> donde le tocaba "
         "<code>0x25</code>, y la 12 de la segunda vale <code>0x74</code> "
         "donde le tocaba <code>0x7A</code>. Las otras 64 entradas de cada "
         "tabla se ajustan al coseno con una desviacion media de <b>0,48</b> y "
         "<b>1,73</b>. Son dos erratas de los datos, y estan vigiladas por un "
         "test.</p>"),
        ("Un truco que pide izquierda y derecha a la vez",
         "<p><code>0x6F44</code> se llama <b>una sola vez</b>, justo despues de "
         "poner la partida a cero. Pide que el mando lea <code>0x2C</code> en "
         "sus seis bits bajos -bits 2, 3 y 5: <b>izquierda y derecha a la vez</b> "
         "mas el segundo boton, que en un joystick no se puede hacer- y ademas "
         "una tecla de las filas 3, 4 o 5 del teclado. Una de las tres pone "
         "<b>26 vidas</b> en <code>(0xE060)</code>; las otras dos tocan el arma "
         "de <code>(0xE069)</code>.</p>"),
        ("El Game Master declara ocho fases y una rutina del propio cartucho",
         "<p>En <code>0x4010</code> va la segunda cabecera, la que lee el "
         "<i>Konami Game Master</i> desde la otra ranura: <code>\"CD\" 07 39</code>, "
         "o sea RC-739. Los 21 bytes que siguen se reparten con un byte de "
         "banderas, y el reparto <b>cuadra byte a byte</b>: acaba en "
         "<code>0x4024</code>, justo antes de donde vuelve a haber codigo. "
         "Declara la variable de escena, las vidas, el record, la puntuacion, "
         "<b>ocho fases</b> y una direccion mas: <code>0x56C8</code>, que es "
         "una rutina de este cartucho a la que nadie de dentro llama. Lo que "
         "hace son diez bytes: pasar la fase que el Game Master escribe en "
         "<code>(0xE061)</code> al indice interno de <code>(0xE062)</code>.</p>"),
        ("Los tramos de cada fase se solapan una banda exacta",
         "<p>El decorado se monta por bandas de cuatro filas, y el mapa de bits "
         "que dice cuando avanza el puntero de bloques va <b>seis bytes</b> por "
         "tramo mientras que se leen <b>siete</b>. O sea que la ultima banda de "
         "un tramo y la primera del siguiente salen del mismo byte. Y no solo "
         "del mismo byte: el decorado que dan es <b>identico</b>, comprobado en "
         "los nueve empalmes de cada una de las ocho fases.</p>"),
        ("Tres paletas de un solo guion de color",
         "<p>Las fases 0, 3 y 7 comparten casillas <b>y</b> guion de color. Lo "
         "que las distingue es <code>(0xE661)</code>: el lector de bloques "
         "(<code>0x443B</code>) traduce cinco codigos de color -0xE1, 0xEC, "
         "0xE8, 0xE6 y 0xE5- restandoles 0x50, y otros 0x50 mas si el banco es "
         "el 2. Un solo bloque de 640 bytes da los tres decorados. La 5 y la 6 "
         "van mas lejos: comparten casillas y color, y solo se diferencian en "
         "el mapa.</p>"),
        ("La demostracion es una partida grabada",
         "<p><code>0x5A73</code> saca un byte de <code>0x5A95</code> cada ocho "
         "cuadros y se lo pasa a <code>guarda_lo_recien_pulsado</code>, que es "
         "la misma puerta por la que entra el mando. Son <b>118 pulsaciones</b>, "
         "unos diecinueve segundos a 50 Hz. El <code>cp 0xFF</code> que la "
         "cerraria nunca llega: dentro del bloque no hay ni un 0xFF, y la "
         "demostracion se corta por otro lado.</p>"),
    ],
    "en": [
        ("Konami left two typos in its cosine tables",
         "<p>The cartridge carries two cosine quadrants, one scaled to 255 "
         "(<code>0x844E</code>) and one to 128 (<code>0x848F</code>), and uses "
         "them to get the sine and cosine of an angle from 0 to 255. A cosine "
         "quadrant <b>can only go down</b>. These two go up once each, and the "
         "value that goes up is precisely the only one that departs from the "
         "function: entry 58 of the first is <code>0x2F</code> where it should "
         "be <code>0x25</code>, and entry 12 of the second is <code>0x74</code> "
         "where it should be <code>0x7A</code>. The other 64 entries of each "
         "table fit the cosine with a mean deviation of <b>0.48</b> and "
         "<b>1.73</b>. Two data typos, and a test now watches them.</p>"),
        ("A cheat that asks for left and right at once",
         "<p><code>0x6F44</code> is called <b>exactly once</b>, right after the "
         "game is reset. It wants the controller to read <code>0x2C</code> in "
         "its low six bits -bits 2, 3 and 5: <b>left and right at the same "
         "time</b> plus the second button, which a joystick cannot do- and a "
         "key from keyboard rows 3, 4 or 5 as well. One of the three puts "
         "<b>26 lives</b> into <code>(0xE060)</code>; the other two touch the "
         "weapon in <code>(0xE069)</code>.</p>"),
        ("The Game Master header declares eight stages and a routine of this "
         "very cartridge",
         "<p>At <code>0x4010</code> sits the second header, the one the "
         "<i>Konami Game Master</i> reads from the next slot: "
         "<code>\"CD\" 07 39</code>, that is RC-739. The 21 bytes that follow "
         "are laid out by a flags byte, and the layout <b>works out byte for "
         "byte</b>: it ends at <code>0x4024</code>, exactly where code starts "
         "again. It declares the scene variable, the lives, the high score, the "
         "score, <b>eight stages</b> and one more address: <code>0x56C8</code>, "
         "a routine of this cartridge that nothing inside it ever calls. What "
         "it does takes ten bytes: turn the stage the Game Master writes into "
         "<code>(0xE061)</code> into the internal index at "
         "<code>(0xE062)</code>.</p>"),
        ("Each stage's sections overlap by exactly one band",
         "<p>The scenery is assembled in bands of four rows, and the bitmap "
         "that says when the block pointer moves on advances <b>six bytes</b> "
         "per section while <b>seven</b> are read. So the last band of one "
         "section and the first of the next come from the same byte. And not "
         "only from the same byte: the scenery they give is <b>identical</b>, "
         "checked on all nine joins of each of the eight stages.</p>"),
        ("Three palettes out of a single colour script",
         "<p>Stages 0, 3 and 7 share tiles <b>and</b> colour script. What tells "
         "them apart is <code>(0xE661)</code>: the block reader "
         "(<code>0x443B</code>) translates five colour codes -0xE1, 0xEC, 0xE8, "
         "0xE6 and 0xE5- by subtracting 0x50, and another 0x50 when the bank is "
         "2. One 640-byte block gives all three sceneries. Stages 5 and 6 go "
         "further: they share tiles and colour, and differ only in the map.</p>"),
        ("The demo is a recorded game",
         "<p><code>0x5A73</code> pulls one byte out of <code>0x5A95</code> every "
         "eight frames and hands it to <code>guarda_lo_recien_pulsado</code>, "
         "the very door the joystick comes in through. That is <b>118 "
         "keypresses</b>, some nineteen seconds at 50 Hz. The <code>cp 0xFF"
         "</code> that would end it never arrives: there is not a single 0xFF "
         "inside the block, and the demo is cut short some other way.</p>"),
    ],
}

# (fichero, pie en castellano, pie en ingles)
GALERIA = [
    ("titulo.png",
     "La pantalla del titulo, montada ejecutando los pasos de "
     "<code>monta_el_titulo</code> (0x47BA). El rotulo grande son 33 casillas "
     "-once por tres- escritas por un bucle desde la 0x60.",
     "The title screen, assembled by running the steps of "
     "<code>monta_el_titulo</code> (0x47BA). The big logo is 33 tiles "
     "-eleven by three- written by a loop starting at tile 0x60."),
    ("presentacion.png",
     "El cartel de KONAMI de la presentacion, en el sitio al que llega tras "
     "sus catorce pasos.",
     "The KONAMI banner of the intro, at the place it reaches after its "
     "fourteen steps."),
    ("fase_1.png",
     "La fase 1 entera, en vertical: 61 bandas de cuatro filas, montadas "
     "bloque a bloque desde los codigos de <code>0x9E51</code>.",
     "Stage 1 in full, top to bottom: 61 bands of four rows, assembled block "
     "by block from the codes at <code>0x9E51</code>."),
    ("fase_4.png",
     "La fase 4. Usa las MISMAS casillas que la 1, pasadas por el traductor "
     "de <code>0x443B</code>: por eso los muros son rosa y no gris.",
     "Stage 4. It uses the SAME tiles as stage 1, run through the translator "
     "at <code>0x443B</code>: that is why the walls are pink, not grey."),
    ("jugador.png",
     "Los doce fotogramas de Popolon. Son TRES sprites -dos del fotograma y "
     "uno del banco de la fase- y cada fotograma ocupa 64 bytes justos. Los "
     "cuatro ultimos son la explosion.",
     "Popolon's twelve frames. He is THREE sprites -two from the frame and one "
     "from the stage bank- and each frame takes exactly 64 bytes. The last "
     "four are the explosion."),
    ("banco_de_enemigos.png",
     "Los 45 patrones del bestiario. No caben a la vez: el cartucho los "
     "recarga en TRES ranuras de la hoja de sprites (0x1D00, 0x1E00 y 0x1F00) "
     "segun lo que vaya saliendo.",
     "The 45 patterns of the bestiary. They do not fit at once: the cartridge "
     "reloads them into THREE slots of the sprite sheet (0x1D00, 0x1E00 and "
     "0x1F00) as they are needed."),
    ("sprites_fase.png",
     "Los 37 patrones fijos de cada fase: las armas, los disparos y los "
     "objetos. Iguales en las ocho.",
     "The 37 fixed patterns of every stage: the weapons, the shots and the "
     "items. The same in all eight."),
    ("pantalla_fase1.png",
     "La primera pantalla de la fase 1 con su marcador, tal como sale del "
     "emulador: el cotejo byte a byte da CERO diferencias.",
     "The first screen of stage 1 with its scoreboard, exactly as it comes out "
     "of the emulator: the byte-for-byte check gives ZERO differences."),
]
