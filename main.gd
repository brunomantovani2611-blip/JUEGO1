extends Node2D
# =====================================================
#  CAFETERIA TYCOON  (para celular, pantalla vertical)
#
#  - Todo se compra desde la COMPU (boton TIENDA).
#  - Las maquinas se gastan y se rompen: tocalas para
#    hacerles mantenimiento o arreglarlas.
#  - Toca las mesas para juntar propinas y limpiarlas.
#  - Meta: convertirte en Cafeteria Legendaria y abrir
#    sucursales nuevas (franquicia) con mejoras de oro.
#  - La partida se guarda sola.
# =====================================================

# ---------- CONFIGURACION (puedes cambiar estos numeros) ----------
const DINERO_INICIAL := 30
const PROPINA_SENTADO := 3      # propina que deja cada cliente que se sienta
const VELOCIDAD_CLIENTE := 230.0
const VELOCIDAD_MOZO := 300.0
const MAX_COLA := 5             # si todas las filas estan llenas, el cliente se va
const PACIENCIA := 15.0         # segundos que un cliente aguanta en la fila
const REPUTACION_INICIAL := 3.0 # de 1 a 5 estrellas
const DURACION_DIA := 180.0     # segundos que dura un dia del juego
const DURACION_HORA_PICO := 30.0
const VIDA_MONEDA := 8.0        # segundos que dura una propina antes de desaparecer
const REPUTACION_LEGENDARIA := 4.5

# Dispensadoras de cafe
#   precio: lo que cuesta     falla: chance base de romperse cada vez que sirve
#   arreglo: lo que cuesta arreglarla     tiempo: segundos que tarda en servir
#   desgaste: cuanto se gasta con cada cafe (1.0 = totalmente gastada)
const DISPENSADORAS := [
	{"id": "basica",   "nombre": "Básica",   "precio": 60,  "falla": 0.06,  "arreglo": 20,  "tiempo": 1.6, "desgaste": 0.06},
	{"id": "estandar", "nombre": "Estándar", "precio": 220, "falla": 0.025, "arreglo": 60,  "tiempo": 1.2, "desgaste": 0.035},
	{"id": "premium",  "nombre": "Premium",  "precio": 550, "falla": 0.008, "arreglo": 150, "tiempo": 0.9, "desgaste": 0.02},
]
const LUGARES_DISPENSADORA := 4       # lugares en el mostrador (se habilitan agrandando)
const TIEMPO_ARREGLO := 2.5           # segundos que tarda en arreglarse
const TIEMPO_MANTENIMIENTO := 1.0
const DEVOLUCION_AL_REEMPLAZAR := 0.5 # al reemplazar una maquina o mesa te devuelven el 50%

# Mesas: precio segun la cantidad de asientos
const PRECIO_MESA := {1: 20, 2: 45, 3: 75, 4: 110}

# Tamano del local
const MAX_NIVEL_LOCAL := 3
const COSTOS_AGRANDAR := [150, 400]     # precio de pasar a nivel 2 y a nivel 3
const MESAS_POR_FILA := 4               # cada ampliacion agrega una fila de mesas
const COLUMNAS_PATIO := 3
const FILAS_PATIO := 3

# Mejoras del local y empleados
const COSTO_PATIO := 800
const COSTO_CARTEL := 1200
const COSTO_TECNICO := 300
const COSTO_MOZO := 250

# Menu: productos que se venden
#   precio: precio base       tiempo: cuanto tarda en prepararse (x tiempo de la maquina)
#   desbloqueo: lo que cuesta agregarlo al menu    nivel_local: tamano de local necesario
const PRODUCTOS := [
	{"id": "cafe",      "nombre": "Café",      "precio": 5,  "tiempo": 1.0, "desbloqueo": 0,   "nivel_local": 1},
	{"id": "medialuna", "nombre": "Medialuna", "precio": 8,  "tiempo": 1.1, "desbloqueo": 120, "nivel_local": 1},
	{"id": "jugo",      "nombre": "Jugo",      "precio": 10, "tiempo": 1.2, "desbloqueo": 300, "nivel_local": 2},
	{"id": "torta",     "nombre": "Torta",     "precio": 15, "tiempo": 1.4, "desbloqueo": 600, "nivel_local": 3},
]
const MAX_NIVEL_RECETA := 5     # cada nivel de receta sube el precio un 25%

# Sucursales (franquicia): cada una cambia algo del juego
#   meta: plata que hay que juntar para ser legendaria   clientes/paciencia/pago/falla: multiplicadores
#   critico/apurado: chance de que llegue ese cliente     horas_pico: cuantas por dia
#   lluvia: si a veces llueve    caros: si los clientes prefieren lo caro
#   pesos: productos que se piden mas    iniciales: productos que ya estan en el menu
const SUCURSALES := [
	{"id": "centro", "nombre": "Centro", "descripcion": "Una cafetería normal en el centro de la ciudad.",
		"meta": 10000, "clientes": 1.0, "paciencia": 1.0, "pago": 1.0, "falla": 1.0,
		"critico": 0.03, "apurado": 0.10, "horas_pico": 1, "lluvia": false, "caros": false,
		"pesos": {}, "iniciales": ["cafe"], "exterior": "pasto", "tinte": Color(1, 1, 1), "musica": "musica"},
	{"id": "playa", "nombre": "Playa", "descripcion": "Se vende mucho jugo. A veces llueve y nadie usa el patio.",
		"meta": 15000, "clientes": 1.1, "paciencia": 1.1, "pago": 1.0, "falla": 1.0,
		"critico": 0.03, "apurado": 0.05, "horas_pico": 1, "lluvia": true, "caros": false,
		"pesos": {"jugo": 4.0}, "iniciales": ["cafe", "jugo"], "exterior": "arena", "tinte": Color(1.0, 0.96, 0.85), "musica": "musica_playa"},
	{"id": "aeropuerto", "nombre": "Aeropuerto", "descripcion": "Clientes muy apurados (poca paciencia) que pagan el doble.",
		"meta": 25000, "clientes": 1.0, "paciencia": 0.65, "pago": 1.0, "falla": 1.0,
		"critico": 0.05, "apurado": 0.45, "horas_pico": 1, "lluvia": false, "caros": false,
		"pesos": {}, "iniciales": ["cafe"], "exterior": "asfalto", "tinte": Color(0.88, 0.94, 1.0), "musica": "musica_aeropuerto"},
	{"id": "universidad", "nombre": "Universidad", "descripcion": "Muchísimos estudiantes que pagan poco. Horas pico entre clases.",
		"meta": 20000, "clientes": 2.0, "paciencia": 1.0, "pago": 0.6, "falla": 1.0,
		"critico": 0.02, "apurado": 0.15, "horas_pico": 3, "lluvia": false, "caros": false,
		"pesos": {"medialuna": 2.0}, "iniciales": ["cafe"], "exterior": "pasto", "tinte": Color(0.93, 1.0, 0.93), "musica": "musica_universidad"},
	{"id": "montana", "nombre": "Montaña", "descripcion": "Pocos clientes que solo piden cosas caras. El frío rompe más las máquinas.",
		"meta": 30000, "clientes": 0.6, "paciencia": 1.2, "pago": 1.5, "falla": 1.6,
		"critico": 0.04, "apurado": 0.03, "horas_pico": 1, "lluvia": false, "caros": true,
		"pesos": {}, "iniciales": ["cafe"], "exterior": "nieve", "tinte": Color(1.0, 0.94, 0.9), "musica": "musica_montana"},
]

# Mejoras permanentes que se compran con granos de oro (duran para siempre)
const MEJORAS_ORO := [
	{"id": "fama",      "nombre": "Fama de la marca",   "texto": "+10% de clientes por nivel",               "max": 5, "costo": 2},
	{"id": "tecnico",   "nombre": "Técnico experto",    "texto": "-15% de roturas y desgaste por nivel",     "max": 4, "costo": 3},
	{"id": "inversion", "nombre": "Inversión inicial",  "texto": "+$150 al abrir cada local",                "max": 5, "costo": 2},
	{"id": "recetas",   "nombre": "Recetas secretas",   "texto": "Los productos arrancan 1 nivel más arriba", "max": 2, "costo": 5},
	{"id": "zen",       "nombre": "Clientes pacientes", "texto": "+15% de paciencia por nivel",              "max": 4, "costo": 3},
]

# Misiones (se hacen en orden, se ven de a 3)
#   tipo: que se cuenta   meta: cuanto hay que llegar   premio: plata
const MISIONES := [
	{"texto": "Atendé 10 clientes",              "tipo": "atendidos",      "meta": 10,  "premio": 30},
	{"texto": "Comprá una mesa",                 "tipo": "asientos",       "meta": 1,   "premio": 20},
	{"texto": "Juntá 5 propinas",                "tipo": "propinas",       "meta": 5,   "premio": 30},
	{"texto": "Hacé 3 mantenimientos",           "tipo": "mantenimientos", "meta": 3,   "premio": 40},
	{"texto": "Tené 6 asientos",                 "tipo": "asientos",       "meta": 6,   "premio": 60},
	{"texto": "Agrandá la cafetería",            "tipo": "nivel",          "meta": 2,   "premio": 100},
	{"texto": "Atendé 100 clientes",             "tipo": "atendidos",      "meta": 100, "premio": 150},
	{"texto": "Tené 3 productos en el menú",     "tipo": "productos",      "meta": 3,   "premio": 150},
	{"texto": "Llegá a 4 estrellas",             "tipo": "reputacion",     "meta": 4,   "premio": 200},
	{"texto": "Arreglá 10 máquinas",             "tipo": "arreglos",       "meta": 10,  "premio": 200},
	{"texto": "Tené 3 máquinas",                 "tipo": "maquinas",       "meta": 3,   "premio": 250},
	{"texto": "Agrandá al nivel 3",              "tipo": "nivel",          "meta": 3,   "premio": 400},
	{"texto": "Abrí el patio",                   "tipo": "patio",          "meta": 1,   "premio": 500},
	{"texto": "Atendé 5 críticos gastronómicos", "tipo": "criticos",       "meta": 5,   "premio": 500},
	{"texto": "Tené una máquina Premium",        "tipo": "premium",        "meta": 1,   "premio": 600},
	{"texto": "Atendé 500 clientes",             "tipo": "atendidos",      "meta": 500, "premio": 800},
]

# Misiones diarias (se eligen 3 al azar cada dia real)
const DIARIAS := [
	{"texto": "Atendé %d clientes",          "tipo": "atendidos",      "metas": [40, 80, 150]},
	{"texto": "Juntá %d propinas",           "tipo": "propinas",       "metas": [10, 20, 40]},
	{"texto": "Limpiá %d mesas",             "tipo": "limpiezas",      "metas": [10, 25, 50]},
	{"texto": "Hacé %d mantenimientos",      "tipo": "mantenimientos", "metas": [3, 6, 10]},
	{"texto": "Arreglá %d máquinas",         "tipo": "arreglos",       "metas": [2, 4, 8]},
	{"texto": "Atendé %d clientes apurados", "tipo": "apurados",       "metas": [3, 6, 10]},
	{"texto": "Ganá $%d",                    "tipo": "ganado",         "metas": [300, 1000, 3000]},
]
const PREMIO_DIARIAS := [100, 250, 600]   # plata por mision diaria (segun dificultad), ademas de 1 grano de oro

# Premio por entrar cada dia (racha de 7 dias)
const PREMIOS_DIARIOS := [
	{"texto": "$50",                 "dinero": 50},
	{"texto": "$100",                "dinero": 100},
	{"texto": "$150",                "dinero": 150},
	{"texto": "$250",                "dinero": 250},
	{"texto": "1 grano de oro",      "granos": 1},
	{"texto": "$400",                "dinero": 400},
	{"texto": "Máquina Premium gratis", "premium": 1},
]

# Cosas que se cuentan (para misiones y resumenes)
const CONTADORES := ["atendidos", "perdidos", "propinas", "limpiezas", "mantenimientos",
	"arreglos", "roturas", "apurados", "criticos", "ganado"]

# Guardado
const ARCHIVO_PARTIDA := "user://partida.json"
const CADA_CUANTO_GUARDAR := 10.0
const MAX_HORAS_AUSENTE := 1.0     # ganancias offline como maximo de 1 hora
const RENDIMIENTO_OFFLINE := 0.1   # fuera del juego se gana el 10% de lo normal

# Sonido: volumen de cada efecto en decibeles (0 = normal, -10 = mas bajo)
const VOLUMEN_MUSICA := -12.0
const SONIDOS := {
	"cobro": -8.0, "propina": -10.0, "enojado": -8.0, "compra": -6.0,
	"campanita": -16.0, "obra": -4.0, "logro": -4.0, "click": -10.0,
	"rotura": -4.0, "arreglo": -6.0, "compu": -10.0, "limpiar": -8.0,
	"campana": -6.0, "festejo": -2.0,
}

# ---------- PANTALLA Y MAPA (pantalla de 720 x 1280) ----------
const ANCHO_PANTALLA := 720
const ALTO_PANTALLA := 1280
const ALTO_HUD := 150.0          # barra de arriba con la plata
const ARRIBA := 165.0            # pared de arriba del local
const IZQUIERDA := 20.0
const DERECHA := 700.0
const Y_FILAS_MESAS := 490.0     # centro de la primera fila de mesas
const ALTO_FILA := 118.0
const ANCHO_CELDA := 170.0
const PATIO_X := 230.0
const PATIO_Y := 830.0
const PATIO_ALTO := 340.0
const PATIO_ANCHO := 470.0
const CALLE_ARRIBA := 1190.0
const CALLE_Y := 1228.0          # por donde camina la gente
const CAMINO_X := 120.0          # caminito de la vereda a la puerta
const PORTON_Y := PATIO_Y + 112.0   # entrada del patio (en la cerca izquierda)
const OFFSET_SILLAS := [Vector2(-45, 0), Vector2(45, 0), Vector2(0, -42), Vector2(0, 42)]

# Tutorial: un texto por paso
const TUTORIAL := [
	"¡Bienvenido a tu cafetería! Los clientes compran en la máquina de café. Tocá la TIENDA para comprar cosas.",
	"Esta es la compu. Comprá una mesa de 1 asiento.",
	"Ahora tocá un lugar marcado para poner la mesa.",
	"Las máquinas se gastan con el uso (mirá la barrita). Si se gastan mucho, se rompen. ¡Tocala para hacerle mantenimiento!",
	"Cuando un cliente sentado se va, deja propina y la mesa sucia. Tocá la mesa para juntar la plata y limpiarla.",
	"¡Muy bien! En la TIENDA tenés Misiones con premios. Tu meta: convertirte en una Cafetería Legendaria.",
]


# ---------- CLASE CLIENTE ----------
class Cliente:
	var pos: Vector2
	var estado := "cola"   # cola -> a_mesa -> sentado -> saliendo
	var tipo := "normal"   # normal, critico o apurado
	var camino: Array = [] # puntos por los que pasa antes de su destino
	var salida: Vector2    # por donde se va de la pantalla
	var disp := 0          # en la fila de que dispensadora esta
	var mesa := -1
	var silla := -1
	var timer := 0.0
	var sprite := 0
	var producto := 0      # indice en PRODUCTOS
	var paciencia := PACIENCIA
	var paciencia_total := PACIENCIA
	var enojado := false


# ---------- ESTADO DE ESTA SUCURSAL ----------
var sucursal := 0
var dinero := DINERO_INICIAL
var reputacion := REPUTACION_INICIAL
var nivel_local := 1
var tiene_patio := false
var tiene_cartel := false
var tiene_tecnico := false
var tiene_mozo := false
var legendaria := false        # esta sucursal ya llego a la meta
var nivel_receta := {}         # id de producto -> nivel (0 = no esta en el menu)
var dispensadoras: Array = []  # un lugar por posicion del mostrador: null o un diccionario
var mesas: Array = []          # cada mesa: { lugar, asientos, sillas: [bool...], sucia }
var contadores := {}           # lo que paso en esta sucursal
var misiones_hechas: Array = []
var dia := 1
var reloj_dia := 0.0
var inicio_dia := {}           # contadores al empezar el dia (para el resumen)
var horas_pico: Array = []     # segundo del dia en que empieza cada hora pico

# ---------- PROGRESO PERMANENTE ----------
var granos := 0
var mejoras_oro := {}
var sucursales_completadas: Array = []
var vida := {}                 # contadores de toda la vida (para misiones diarias)
var diarias: Array = []
var dia_diarias := -1
var ultimo_premio_diario := -1
var racha := 0
var cupones_premium := 0
var tiempo_jugado := 0.0
var tutorial_paso := 0         # -1 = tutorial terminado

# ---------- COSAS DEL MOMENTO ----------
var clientes: Array = []
var monedas: Array = []        # propinas sobre las mesas: { mesa, valor, cantidad, vida }
var mozo := {}
var textos: Array = []         # textos flotantes "+$5"
var particulas: Array = []     # polvo, humo, brillitos y confeti
var tiempo_spawn := 1.0
var tiempo_guardado := CADA_CUANTO_GUARDAR
var no_guardar := false
var pausado := false
var reloj := 0.0
var colocando := {}            # lo que estas por colocar: { tipo, valor }
var tienda_abierta_alguna_vez := false
var lloviendo := false
var timer_clima := 90.0
var tutorial_base := {}

# ---------- ANIMACIONES ----------
var borde_local := borde_para_nivel(1)   # pared de abajo del local (se anima al agrandar)
var alto_patio := 0.0
var en_obras := false
var origen := Vector2.ZERO  # para centrar el local en pantallas mas altas
var luz: CanvasModulate     # color del dia y la noche

# ---------- DIBUJOS Y SONIDOS ----------
var tex := {}
var tex_clientes: Array = []
var reproductores := {}
var musica: AudioStreamPlayer
var musica_on := true
var sonido_on := true
var vibracion_on := true

# ---------- INTERFAZ ----------
var capa_ui: CanvasLayer
var label_dinero: Label
var label_stats: Label
var label_pista: Label
var dibujo_estrellas: Control
var btn_compu: Button
var aviso_compu: Label
var btn_cancelar: Button
var panel_tienda: PanelContainer
var pestanas: TabContainer
var label_tienda_dinero: Label
var filas_disp: Array = []
var filas_mesa: Array = []
var filas_menu: Array = []
var filas_local := {}
var filas_diarias: Array = []
var filas_misiones: Array = []
var label_diarias: Label
var label_misiones: Label
var label_meta: Label
var label_granos: Label
var filas_oro: Array = []
var filas_sucursales: Array = []
var btn_musica: Button
var btn_sonido: Button
var btn_vibracion: Button
# Mensajes
var capa_mensaje: Control
var label_msg_titulo: Label
var label_msg_texto: Label
var caja_botones_msg: HBoxContainer
var cola_mensajes: Array = []
# Tutorial
var panel_tutorial: PanelContainer
var label_tutorial: Label
var btn_tutorial: Button
var dibujo_mano: Control
var objetivo_mano = null       # Vector2 en pantalla o null


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art nitido
	randomize()
	luz = CanvasModulate.new()
	add_child(luz)
	configurar_pantalla()
	cargar_sprites()
	crear_audio()
	crear_interfaz()
	reiniciar_sucursal()
	for c in CONTADORES:
		vida[c] = 0
	if not cargar_partida():
		mejoras_oro = {}
	cambiar_musica_sucursal()
	revisar_diarias()
	revisar_premio_diario()
	if horas_pico.is_empty():
		programar_horas_pico()


# =====================================================
#  PANTALLA DE CELULAR (vertical)
# =====================================================
func configurar_pantalla() -> void:
	var ventana := get_window()
	ventana.content_scale_size = Vector2i(ANCHO_PANTALLA, ALTO_PANTALLA)
	ventana.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	ventana.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_WIDTH
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	ventana.size_changed.connect(acomodar_mundo)
	acomodar_mundo()


func acomodar_mundo() -> void:
	# En celulares mas altos que 720x1280 el local queda centrado
	var alto := get_viewport_rect().size.y
	origen = Vector2(0, max(0.0, (alto - ALTO_PANTALLA) / 2.0))
	position = origen


func a_pantalla(p: Vector2) -> Vector2:
	# Convierte una posicion del local a una posicion en la pantalla
	return p + position


# =====================================================
#  BUCLE PRINCIPAL
# =====================================================
func _process(delta: float) -> void:
	reloj += delta
	if not pausado:
		tiempo_jugado += delta
		actualizar_dia(delta)
		actualizar_clima(delta)
		tiempo_spawn -= delta
		if tiempo_spawn <= 0.0:
			tiempo_spawn = intervalo_spawn()
			crear_cliente()
		actualizar_dispensadoras(delta)
		actualizar_clientes(delta)
		actualizar_mozo(delta)
		actualizar_monedas(delta)
		revisar_meta()

	actualizar_textos(delta)
	actualizar_particulas(delta)
	actualizar_luz()
	actualizar_interfaz()
	actualizar_tutorial()

	tiempo_guardado -= delta
	if tiempo_guardado <= 0.0:
		tiempo_guardado = CADA_CUANTO_GUARDAR
		revisar_diarias()
		guardar_partida()

	queue_redraw()


func _notification(what: int) -> void:
	# En el celular el juego se guarda al salir o al mandarlo al fondo
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		guardar_partida()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Boton "atras" de Android: cierra la tienda o cancela lo que estabas colocando
		if capa_mensaje != null and capa_mensaje.visible:
			return
		if not colocando.is_empty():
			cancelar_colocacion()
		elif panel_tienda != null and panel_tienda.visible:
			cerrar_tienda()


func suc() -> Dictionary:
	return SUCURSALES[sucursal]

func oro(id: String) -> int:
	return mejoras_oro.get(id, 0)


func intervalo_spawn() -> float:
	# Mas maquinas, mas asientos y mejor reputacion = llegan clientes mas seguido
	var atraccion := 1.0 + 0.3 * (cantidad_dispensadoras() - 1) + 0.06 * asientos_totales()
	if tiene_cartel:
		atraccion *= 1.5
	atraccion *= reputacion / 3.0
	atraccion *= suc()["clientes"] * (1.0 + 0.1 * oro("fama"))
	if hora_pico_activa():
		atraccion *= 2.0
	if es_de_noche():
		atraccion *= 0.6
	return max(0.3, 2.5 / atraccion)


func contar(tipo: String, cuanto := 1) -> void:
	contadores[tipo] = contadores.get(tipo, 0) + cuanto
	vida[tipo] = vida.get(tipo, 0) + cuanto


# =====================================================
#  TOQUES EN LA PANTALLA
# =====================================================
func _unhandled_input(event: InputEvent) -> void:
	# En el celular cada toque llega como un clic del mouse
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tocar(get_local_mouse_position())


func tocar(p: Vector2) -> void:
	if pausado:
		return
	# Dispensadoras y lugares del mostrador
	for i in LUGARES_DISPENSADORA:
		if rect_dispensadora(i).has_point(p):
			if colocando.get("tipo") == "dispensadora":
				colocar_dispensadora(i)
			elif dispensadoras[i] != null:
				tocar_dispensadora(i)
			return
	# Mesas y lugares de mesa
	for lugar in total_lugares_mesa():
		if lugar_mesa_habilitado(lugar) and lugar_visible(lugar) and rect_lugar_mesa(lugar).has_point(p):
			if colocando.get("tipo") == "mesa":
				colocar_mesa(lugar)
			else:
				var m := mesa_en_lugar(lugar)
				if m >= 0:
					atender_mesa(m)
			return


# =====================================================
#  SONIDO, MUSICA Y VIBRACION
# =====================================================
func crear_audio() -> void:
	for nombre in SONIDOS:
		var ruta := "res://sonidos/%s.wav" % nombre
		if ResourceLoader.exists(ruta):
			var r := AudioStreamPlayer.new()
			r.stream = load(ruta)
			r.volume_db = SONIDOS[nombre]
			r.max_polyphony = 4      # puede sonar varias veces a la vez
			add_child(r)
			reproductores[nombre] = r
	musica = AudioStreamPlayer.new()
	musica.volume_db = VOLUMEN_MUSICA
	add_child(musica)


func cambiar_musica_sucursal() -> void:
	# Cada sucursal tiene su musica (si falta el archivo, usa la del centro)
	var ruta := "res://sonidos/%s.ogg" % suc()["musica"]
	if not ResourceLoader.exists(ruta):
		ruta = "res://sonidos/musica.ogg"
	if not ResourceLoader.exists(ruta):
		return
	musica.stream = load(ruta)
	musica.stream.loop = true
	if musica_on:
		musica.play()


func sonar(nombre: String, variacion := 0.0) -> void:
	# variacion: cambia un poco el tono para que no suene siempre igual
	if not sonido_on or not reproductores.has(nombre):
		return
	var r: AudioStreamPlayer = reproductores[nombre]
	r.pitch_scale = 1.0 + randf_range(-variacion, variacion)
	r.play()


func vibrar(ms := 250) -> void:
	if vibracion_on:
		Input.vibrate_handheld(ms)


func cambiar_musica() -> void:
	musica_on = not musica_on
	if musica_on:
		musica.play()
	else:
		musica.stop()

func cambiar_sonido() -> void:
	sonido_on = not sonido_on

func cambiar_vibracion() -> void:
	vibracion_on = not vibracion_on
	vibrar(100)


# =====================================================
#  DIA, NOCHE, HORA PICO Y CLIMA
# =====================================================
func fase_dia() -> float:
	return clamp(reloj_dia / DURACION_DIA, 0.0, 1.0)

func es_de_noche() -> bool:
	return fase_dia() > 0.85

func hora_del_dia() -> String:
	# El dia va de las 8:00 a las 22:00
	var minutos := int(8 * 60 + fase_dia() * 14 * 60)
	return "%02d:%02d" % [minutos / 60, minutos % 60]

func hora_pico_activa() -> bool:
	for t in horas_pico:
		if reloj_dia >= t and reloj_dia < t + DURACION_HORA_PICO:
			return true
	return false

func programar_horas_pico() -> void:
	horas_pico = []
	var n: int = suc()["horas_pico"]
	for k in n:
		# repartidas a lo largo del dia
		var desde := 0.12 + 0.6 * k / n
		horas_pico.append(randf_range(desde, desde + 0.6 / n - 0.05) * DURACION_DIA)


func actualizar_dia(delta: float) -> void:
	var antes := reloj_dia
	reloj_dia += delta
	for t in horas_pico:
		if antes < t and reloj_dia >= t:
			sonar("campana")
			agregar_texto(Vector2(200, 640), "¡HORA PICO!", Color(1, 0.6, 0.2), 2.5)
	if reloj_dia >= DURACION_DIA:
		terminar_dia()


func terminar_dia() -> void:
	pausado = true
	reloj_dia = DURACION_DIA
	var hoy := {}
	for c in CONTADORES:
		hoy[c] = contadores.get(c, 0) - inicio_dia.get(c, 0)
	var texto_resumen := "Ganaste: $%d\nClientes atendidos: %d\nClientes perdidos: %d\nPropinas juntadas: %d\nMáquinas rotas: %d\nReputación: %.1f estrellas" % [
		hoy["ganado"], hoy["atendidos"], hoy["perdidos"], hoy["propinas"], hoy["roturas"], reputacion]
	sonar("logro")
	mostrar_mensaje("Fin del día %d" % dia, texto_resumen, [["Siguiente día", empezar_dia_siguiente]])


func empezar_dia_siguiente() -> void:
	dia += 1
	reloj_dia = 0.0
	inicio_dia = contadores.duplicate()
	programar_horas_pico()
	pausado = false
	guardar_partida()


func actualizar_luz() -> void:
	# Color del cielo segun la hora: amanecer, dia, atardecer y noche
	var f := fase_dia()
	var dia_c := Color.WHITE
	var amanecer := Color(0.85, 0.78, 0.92)
	var atardecer := Color(1.0, 0.78, 0.6)
	var noche := Color(0.5, 0.55, 0.85)
	var c: Color
	if f < 0.08:
		c = amanecer.lerp(dia_c, f / 0.08)
	elif f < 0.7:
		c = dia_c
	elif f < 0.85:
		c = dia_c.lerp(atardecer, (f - 0.7) / 0.15)
	else:
		c = atardecer.lerp(noche, (f - 0.85) / 0.15)
	if lloviendo:
		c = c * Color(0.75, 0.8, 0.9)
	luz.color = c


func actualizar_clima(delta: float) -> void:
	if not suc()["lluvia"]:
		lloviendo = false
		return
	timer_clima -= delta
	if timer_clima <= 0.0:
		lloviendo = not lloviendo
		timer_clima = 25.0 if lloviendo else randf_range(60.0, 120.0)
		if lloviendo:
			agregar_texto(Vector2(220, 640), "¡Empezó a llover!", Color(0.6, 0.8, 1.0), 2.0)


# =====================================================
#  REPUTACION
# =====================================================
func cambiar_reputacion(cuanto: float) -> void:
	reputacion = clamp(reputacion + cuanto, 1.0, 5.0)


# =====================================================
#  PRODUCTOS
# =====================================================
func reiniciar_recetas() -> void:
	nivel_receta = {}
	for p in PRODUCTOS:
		nivel_receta[p["id"]] = 0
	for id in suc()["iniciales"]:
		nivel_receta[id] = min(MAX_NIVEL_RECETA, 1 + oro("recetas"))

func precio_producto(i: int) -> int:
	var p: Dictionary = PRODUCTOS[i]
	var nivel: int = max(1, nivel_receta[p["id"]])
	return int(round(p["precio"] * (1.0 + 0.25 * (nivel - 1))))

func costo_mejorar_receta(i: int) -> int:
	var p: Dictionary = PRODUCTOS[i]
	return p["precio"] * 20 * nivel_receta[p["id"]]

func productos_disponibles() -> Array:
	var lista := []
	for i in PRODUCTOS.size():
		if nivel_receta[PRODUCTOS[i]["id"]] > 0:
			lista.append(i)
	return lista

func precio_promedio() -> float:
	var lista := productos_disponibles()
	var total := 0.0
	for i in lista:
		total += precio_producto(i)
	return total / lista.size() * suc()["pago"]

func elegir_producto() -> int:
	# Cada sucursal tiene sus gustos: en la playa piden jugo, en la montana lo caro
	var lista := productos_disponibles()
	var pesos := []
	var total := 0.0
	for i in lista:
		var w: float = suc()["pesos"].get(PRODUCTOS[i]["id"], 1.0)
		if suc()["caros"]:
			w *= PRODUCTOS[i]["precio"] * PRODUCTOS[i]["precio"]
		pesos.append(w)
		total += w
	var r := randf() * total
	for k in lista.size():
		r -= pesos[k]
		if r <= 0.0:
			return lista[k]
	return lista[lista.size() - 1]


func desbloquear_o_mejorar(i: int) -> void:
	var p: Dictionary = PRODUCTOS[i]
	var nivel: int = nivel_receta[p["id"]]
	if nivel == 0:
		if nivel_local >= p["nivel_local"] and dinero >= p["desbloqueo"]:
			dinero -= p["desbloqueo"]
			nivel_receta[p["id"]] = min(MAX_NIVEL_RECETA, 1 + oro("recetas"))
			sonar("logro")
			agregar_texto(Vector2(150, 640), "Nuevo en el menú: %s!" % p["nombre"], Color.YELLOW, 2.5)
	elif nivel < MAX_NIVEL_RECETA and dinero >= costo_mejorar_receta(i):
		dinero -= costo_mejorar_receta(i)
		nivel_receta[p["id"]] = nivel + 1
		sonar("compra")


# =====================================================
#  CLIENTES
# =====================================================
func punto_borde_calle() -> Vector2:
	return Vector2(-30 if randf() < 0.5 else ANCHO_PANTALLA + 30, CALLE_Y)

func puerta_adentro() -> Vector2:
	return Vector2(CAMINO_X, borde_local - 25)

func puerta_afuera() -> Vector2:
	return Vector2(CAMINO_X, borde_local + 30)

func ruta(desde: String, hacia: String) -> Array:
	# Camino entre el local ("adentro") y el patio, pasando por la puerta y el porton
	if desde == hacia:
		return []
	var ida := [puerta_adentro(), puerta_afuera(), Vector2(CAMINO_X, PORTON_Y), Vector2(PATIO_X + 32, PORTON_Y)]
	if desde == "adentro":
		return ida
	ida.reverse()
	return ida


func crear_cliente() -> void:
	# Elegir la dispensadora con la fila mas corta (las rotas se evitan)
	var mejor := -1
	for i in LUGARES_DISPENSADORA:
		if dispensadoras[i] != null and (mejor == -1 or puntaje_fila(i) < puntaje_fila(mejor)):
			mejor = i
	if mejor == -1:
		return

	if dispensadoras[mejor]["cola"].size() >= MAX_COLA:
		contar("perdidos")
		cambiar_reputacion(-0.05)
		sonar("enojado", 0.1)
		agregar_texto(Vector2(CAMINO_X - 40, CALLE_ARRIBA - 20), "Cliente perdido!", Color.RED)
		return

	var c := Cliente.new()
	c.pos = Vector2(-30, CALLE_Y)   # llegan caminando por la vereda desde la izquierda
	c.camino = [Vector2(CAMINO_X, CALLE_Y), puerta_afuera(), puerta_adentro()]
	c.disp = mejor
	c.sprite = randi() % max(1, tex_clientes.size())
	c.producto = elegir_producto()
	var r := randf()
	if r < suc()["critico"]:
		c.tipo = "critico"
	elif r < suc()["critico"] + suc()["apurado"]:
		c.tipo = "apurado"
	c.paciencia_total = PACIENCIA * suc()["paciencia"] * (1.0 + 0.15 * oro("zen"))
	if c.tipo == "apurado":
		c.paciencia_total *= 0.5
	c.paciencia = c.paciencia_total
	dispensadoras[mejor]["cola"].append(c)
	clientes.append(c)


func puntaje_fila(i: int) -> int:
	var d: Dictionary = dispensadoras[i]
	return d["cola"].size() + (100 if d["rota"] else 0)


func destino_final(c: Cliente) -> Vector2:
	match c.estado:
		"cola":
			return posicion_cola(c.disp, dispensadoras[c.disp]["cola"].find(c))
		"a_mesa", "sentado":
			return posicion_silla(c.mesa, c.silla)
	return c.salida


func actualizar_clientes(delta: float) -> void:
	for c in clientes.duplicate():
		var objetivo: Vector2 = c.camino[0] if not c.camino.is_empty() else destino_final(c)
		c.pos = c.pos.move_toward(objetivo, VELOCIDAD_CLIENTE * delta)
		var llego: bool = c.pos.distance_to(objetivo) < 2.0

		if llego and not c.camino.is_empty():
			c.camino.pop_front()
			if c.camino.is_empty() and c.estado == "cola":
				sonar("campanita", 0.05)   # suena la campanita de la puerta al entrar
			continue
		var llego_al_final: bool = llego and c.camino.is_empty()

		if c.estado == "cola" and c.camino.is_empty():
			# Esperando adentro: se le acaba la paciencia (salvo si ya lo estan atendiendo)
			var d: Dictionary = dispensadoras[c.disp]
			var atendiendolo: bool = d["cola"].find(c) == 0 and llego_al_final and not d["rota"]
			if not atendiendolo:
				c.paciencia -= delta
				if c.paciencia <= 0.0:
					enojarse(c)
		elif c.estado == "a_mesa" and llego_al_final:
			c.estado = "sentado"
			c.timer = randf_range(5.0, 9.0)
		elif c.estado == "sentado":
			c.timer -= delta
			if c.timer <= 0.0:
				# Se va: deja la propina y la mesa sucia
				var propina := int(max(1, round(PROPINA_SENTADO * suc()["pago"] * (3 if c.tipo == "critico" else 1))))
				dejar_propina(c.mesa, propina)
				mesas[c.mesa]["sillas"][c.silla] = false
				mesas[c.mesa]["sucia"] = true
				irse(c)
		elif c.estado == "saliendo" and llego_al_final:
			clientes.erase(c)


func enojarse(c: Cliente) -> void:
	dispensadoras[c.disp]["cola"].erase(c)
	c.enojado = true
	contar("perdidos")
	if c.tipo == "critico":
		cambiar_reputacion(-0.5)
		agregar_texto(c.pos + Vector2(-60, -50), "¡Mala crítica!", Color(1, 0.3, 0.3), 2.0)
	else:
		cambiar_reputacion(-0.15)
		agregar_texto(c.pos + Vector2(-30, -50), "Me voy!", Color(1, 0.3, 0.3))
	sonar("enojado", 0.1)
	irse(c)


func irse(c: Cliente) -> void:
	c.estado = "saliendo"
	c.salida = punto_borde_calle()
	if c.mesa >= 0 and mesa_en_patio(c.mesa):
		c.camino = [Vector2(PATIO_X + 32, PORTON_Y), Vector2(CAMINO_X, PORTON_Y), Vector2(CAMINO_X, CALLE_Y)]
	else:
		c.camino = [puerta_adentro(), puerta_afuera(), Vector2(CAMINO_X, CALLE_Y)]


func buscar_silla_libre(c: Cliente) -> bool:
	for m in mesas.size():
		if mesas[m]["sucia"] or (lloviendo and mesa_en_patio(m)):
			continue   # nadie se sienta en una mesa sucia ni en el patio con lluvia
		for s in mesas[m]["sillas"].size():
			if not mesas[m]["sillas"][s]:
				mesas[m]["sillas"][s] = true
				c.mesa = m
				c.silla = s
				return true
	return false


func pago_cliente(c: Cliente) -> int:
	var mult := 1.0
	if c.tipo == "apurado":
		mult = 2.0
	elif c.tipo == "critico":
		mult = 3.0
	return int(max(1, round(precio_producto(c.producto) * suc()["pago"] * mult)))


func atender(c: Cliente) -> void:
	contar("atendidos")
	ganar_dinero(pago_cliente(c), c.pos)
	sonar("cobro", 0.06)
	var rapido := c.paciencia > c.paciencia_total * 0.5
	if c.tipo == "critico":
		contar("criticos")
		if rapido:
			cambiar_reputacion(0.3)
			agregar_texto(c.pos + Vector2(-80, -70), "¡Al crítico le encantó!", Color(1, 0.85, 0.3), 2.0)
	elif c.tipo == "apurado":
		contar("apurados")
	cambiar_reputacion(0.03 if rapido else 0.01)
	# Si hay silla libre se sienta, si no se lleva el pedido (y le gusta menos)
	if buscar_silla_libre(c):
		c.estado = "a_mesa"
		cambiar_reputacion(0.01)
		if mesa_en_patio(c.mesa):
			c.camino = ruta("adentro", "patio")
	else:
		cambiar_reputacion(-0.02)
		irse(c)


func ganar_dinero(cantidad: int, donde: Vector2) -> void:
	dinero += cantidad
	contar("ganado", cantidad)
	agregar_texto(donde + Vector2(-10, -40), "+$%d" % cantidad, Color(0.4, 1.0, 0.4))


# =====================================================
#  PROPINAS Y MESAS SUCIAS
# =====================================================
func dejar_propina(m: int, valor: int) -> void:
	for mo in monedas:
		if mo["mesa"] == m:
			mo["valor"] += valor
			mo["cantidad"] += 1
			mo["vida"] = VIDA_MONEDA
			return
	monedas.append({"mesa": m, "valor": valor, "cantidad": 1, "vida": VIDA_MONEDA})


func actualizar_monedas(delta: float) -> void:
	for mo in monedas.duplicate():
		mo["vida"] -= delta
		if mo["vida"] <= 0.0:
			monedas.erase(mo)   # la propina se perdio


func atender_mesa(m: int) -> void:
	# Tocar una mesa (o que vaya el mozo): junta las propinas y la limpia
	var hizo_algo := false
	for mo in monedas.duplicate():
		if mo["mesa"] == m:
			ganar_dinero(mo["valor"], posicion_lugar_mesa(mesas[m]["lugar"]))
			contar("propinas", mo["cantidad"])
			sonar("propina", 0.1)
			monedas.erase(mo)
			hizo_algo = true
	if mesas[m]["sucia"]:
		mesas[m]["sucia"] = false
		contar("limpiezas")
		sonar("limpiar", 0.1)
		hizo_algo = true
	if hizo_algo:
		for k in 8:
			agregar_particula(posicion_lugar_mesa(mesas[m]["lugar"]), Color(1, 1, 0.7))


# =====================================================
#  MOZO (limpia mesas y junta propinas solo)
# =====================================================
func casa_mozo() -> Vector2:
	return Vector2(DERECHA - 40, ARRIBA + 140)

func punto_mozo(m: int) -> Vector2:
	return posicion_lugar_mesa(mesas[m]["lugar"]) + Vector2(0, 56)

func mesa_para_mozo() -> int:
	var mejor := -1
	var dist := INF
	for m in mesas.size():
		var hay_moneda := false
		for mo in monedas:
			if mo["mesa"] == m:
				hay_moneda = true
		if mesas[m]["sucia"] or hay_moneda:
			var d: float = mozo["pos"].distance_to(punto_mozo(m))
			if d < dist:
				dist = d
				mejor = m
	return mejor

func actualizar_mozo(delta: float) -> void:
	if not tiene_mozo:
		return
	if mozo.is_empty():
		mozo = {"pos": casa_mozo(), "camino": [], "mesa": -1, "timer": 0.0, "zona": "adentro"}

	if mozo["mesa"] == -1 and mozo["camino"].is_empty():
		var m := mesa_para_mozo()
		if m >= 0:
			var zona := "patio" if mesa_en_patio(m) else "adentro"
			mozo["camino"] = ruta(mozo["zona"], zona) + [punto_mozo(m)]
			mozo["zona"] = zona
			mozo["mesa"] = m
		elif mozo["zona"] == "patio":
			mozo["camino"] = ruta("patio", "adentro") + [casa_mozo()]
			mozo["zona"] = "adentro"
		elif mozo["pos"].distance_to(casa_mozo()) > 2.0:
			mozo["camino"] = [casa_mozo()]

	if not mozo["camino"].is_empty():
		var objetivo: Vector2 = mozo["camino"][0]
		mozo["pos"] = mozo["pos"].move_toward(objetivo, VELOCIDAD_MOZO * delta)
		if mozo["pos"].distance_to(objetivo) < 2.0:
			mozo["camino"].pop_front()
		return

	if mozo["mesa"] >= 0:
		mozo["timer"] += delta
		if mozo["timer"] >= 0.6:
			atender_mesa(mozo["mesa"])
			mozo["mesa"] = -1
			mozo["timer"] = 0.0


# =====================================================
#  DISPENSADORAS (se gastan, se rompen y se arreglan)
# =====================================================
func nueva_dispensadora(modelo: int) -> Dictionary:
	return {"modelo": modelo, "cola": [], "timer": 0.0, "rota": false, "arreglando": 0.0,
		"desgaste": 0.0, "limpiando": 0.0}

func lugares_dispensadora_habilitados() -> int:
	return min(LUGARES_DISPENSADORA, nivel_local + 1)   # nivel 1: 2 lugares, nivel 2: 3, nivel 3: 4

func cantidad_dispensadoras() -> int:
	var n := 0
	for d in dispensadoras:
		if d != null:
			n += 1
	return n

func costo_arreglo(i: int) -> int:
	return DISPENSADORAS[dispensadoras[i]["modelo"]]["arreglo"]

func costo_mantenimiento(i: int) -> int:
	return int(ceil(costo_arreglo(i) * 0.25))

func tiempo_atencion(i: int, c: Cliente) -> float:
	return DISPENSADORAS[dispensadoras[i]["modelo"]]["tiempo"] * PRODUCTOS[c.producto]["tiempo"]

func chance_rotura(i: int) -> float:
	# Cuanto mas gastada, mas facil se rompe
	var d: Dictionary = dispensadoras[i]
	var base: float = DISPENSADORAS[d["modelo"]]["falla"] * suc()["falla"] * (1.0 - 0.15 * oro("tecnico"))
	return base * (0.25 + 3.0 * d["desgaste"] * d["desgaste"])


func actualizar_dispensadoras(delta: float) -> void:
	for i in LUGARES_DISPENSADORA:
		var d = dispensadoras[i]
		if d == null:
			continue

		# Se esta arreglando
		if d["arreglando"] > 0.0:
			d["arreglando"] -= delta
			if d["arreglando"] <= 0.0:
				d["arreglando"] = 0.0
				d["rota"] = false
				d["desgaste"] = 0.0
				sonar("compra")
				agregar_texto(posicion_dispensadora(i) + Vector2(-45, 100), "Arreglada!", Color(0.5, 0.9, 1.0))
			continue

		# Se le esta haciendo mantenimiento
		if d["limpiando"] > 0.0:
			d["limpiando"] -= delta
			if d["limpiando"] <= 0.0:
				d["limpiando"] = 0.0
				d["desgaste"] = 0.0
				agregar_texto(posicion_dispensadora(i) + Vector2(-50, 100), "Como nueva!", Color(0.5, 0.9, 1.0))
			continue

		# Esta rota: sale humo y no atiende
		if d["rota"]:
			if randf() < delta * 5:
				agregar_particula(posicion_dispensadora(i) + Vector2(randf_range(-12, 12), -20), Color(0.35, 0.35, 0.35))
			if tiene_tecnico and dinero >= costo_arreglo(i):
				arreglar(i)
			continue

		# El tecnico le hace mantenimiento cuando esta muy gastada
		if tiene_tecnico and d["desgaste"] >= 0.7 and dinero >= costo_mantenimiento(i):
			hacer_mantenimiento(i)
			continue

		if d["cola"].is_empty():
			d["timer"] = 0.0
			continue

		var primero: Cliente = d["cola"][0]
		if not primero.camino.is_empty() or primero.pos.distance_to(posicion_cola(i, 0)) > 3.0:
			continue  # todavia no llego a la maquina

		d["timer"] += delta
		if d["timer"] >= tiempo_atencion(i, primero):
			d["timer"] = 0.0
			d["cola"].pop_front()
			atender(primero)
			# Cada cafe la gasta un poco y puede romperla
			var gasto: float = DISPENSADORAS[d["modelo"]]["desgaste"] * suc()["falla"] * (1.0 - 0.15 * oro("tecnico"))
			d["desgaste"] = min(1.0, d["desgaste"] + gasto)
			if randf() < chance_rotura(i):
				romper(i)


func tocar_dispensadora(i: int) -> void:
	var d: Dictionary = dispensadoras[i]
	if d["rota"]:
		arreglar(i)
	elif d["arreglando"] > 0.0 or d["limpiando"] > 0.0:
		return
	elif d["desgaste"] >= 0.2:
		hacer_mantenimiento(i)
	else:
		agregar_texto(posicion_dispensadora(i) + Vector2(-60, 100), "Está como nueva", Color(0.8, 0.9, 1.0))


func romper(i: int) -> void:
	dispensadoras[i]["rota"] = true
	contar("roturas")
	sonar("rotura")
	vibrar(300)
	agregar_texto(posicion_dispensadora(i) + Vector2(-50, 100), "Se rompió!", Color(1, 0.35, 0.3), 1.5)
	for k in 12:
		agregar_particula(posicion_dispensadora(i), Color(0.3, 0.3, 0.3))


func arreglar(i: int) -> void:
	var d = dispensadoras[i]
	if d == null or not d["rota"] or d["arreglando"] > 0.0:
		return
	if dinero < costo_arreglo(i):
		agregar_texto(posicion_dispensadora(i) + Vector2(-60, 100), "No te alcanza!", Color(1, 0.35, 0.3))
		return
	dinero -= costo_arreglo(i)
	d["arreglando"] = TIEMPO_ARREGLO
	contar("arreglos")
	sonar("arreglo")


func hacer_mantenimiento(i: int) -> void:
	var d: Dictionary = dispensadoras[i]
	if dinero < costo_mantenimiento(i):
		agregar_texto(posicion_dispensadora(i) + Vector2(-60, 100), "No te alcanza!", Color(1, 0.35, 0.3))
		return
	dinero -= costo_mantenimiento(i)
	d["limpiando"] = TIEMPO_MANTENIMIENTO
	contar("mantenimientos")
	sonar("arreglo", 0.15)
	for k in 6:
		agregar_particula(posicion_dispensadora(i), Color(0.7, 0.9, 1.0))


# =====================================================
#  COMPRAS DESDE LA COMPU
# =====================================================
func costo_local() -> int:
	return COSTOS_AGRANDAR[nivel_local - 1]

func asientos_totales() -> int:
	var n := 0
	for m in mesas:
		n += m["asientos"]
	return n


func empezar_colocacion(tipo: String, valor: int) -> void:
	# Cierra la compu y espera que toques un lugar del local
	colocando = {"tipo": tipo, "valor": valor}
	cerrar_tienda()

func cancelar_colocacion() -> void:
	colocando = {}


# ---- Dispensadoras ----
func precio_dispensadora(modelo: int) -> int:
	if modelo == 2 and cupones_premium > 0:
		return 0   # cupon de maquina Premium gratis
	return DISPENSADORAS[modelo]["precio"]

func puede_colocar_dispensadora(i: int, modelo: int) -> bool:
	# Lugar libre, o con una maquina de otro modelo (se reemplaza)
	if i >= lugares_dispensadora_habilitados():
		return false
	return dispensadoras[i] == null or dispensadoras[i]["modelo"] != modelo

func hay_lugar_para_dispensadora(modelo: int) -> bool:
	for i in LUGARES_DISPENSADORA:
		if puede_colocar_dispensadora(i, modelo):
			return true
	return false

func colocar_dispensadora(i: int) -> void:
	var modelo: int = colocando["valor"]
	var precio := precio_dispensadora(modelo)
	if not puede_colocar_dispensadora(i, modelo) or dinero < precio:
		return
	dinero -= precio
	if modelo == 2 and precio == 0:
		cupones_premium -= 1
	var vieja = dispensadoras[i]
	if vieja == null:
		dispensadoras[i] = nueva_dispensadora(modelo)
	else:
		# Reemplazo: te devuelven parte de lo que costo la vieja y la fila se queda
		var devolucion := int(DISPENSADORAS[vieja["modelo"]]["precio"] * DEVOLUCION_AL_REEMPLAZAR)
		dinero += devolucion
		agregar_texto(posicion_dispensadora(i) + Vector2(-40, 100), "+$%d" % devolucion, Color(0.4, 1.0, 0.4))
		vieja["modelo"] = modelo
		vieja["rota"] = false
		vieja["arreglando"] = 0.0
		vieja["limpiando"] = 0.0
		vieja["desgaste"] = 0.0
		vieja["timer"] = 0.0
	sonar("compra")
	for k in 15:
		agregar_particula(posicion_dispensadora(i), Color(1, 0.9, 0.5))
	colocando = {}


# ---- Mesas ----
func total_lugares_mesa() -> int:
	return MAX_NIVEL_LOCAL * MESAS_POR_FILA + COLUMNAS_PATIO * FILAS_PATIO

func es_lugar_patio(lugar: int) -> bool:
	return lugar >= MAX_NIVEL_LOCAL * MESAS_POR_FILA

func mesa_en_patio(m: int) -> bool:
	return es_lugar_patio(mesas[m]["lugar"])

func lugar_mesa_habilitado(lugar: int) -> bool:
	if es_lugar_patio(lugar):
		return tiene_patio
	return lugar < nivel_local * MESAS_POR_FILA

func mesa_en_lugar(lugar: int) -> int:
	for m in mesas.size():
		if mesas[m]["lugar"] == lugar:
			return m
	return -1

func puede_colocar_mesa(lugar: int, asientos: int) -> bool:
	# Lugar libre, o con una mesa vacia de otro tamano (se reemplaza)
	if not lugar_mesa_habilitado(lugar):
		return false
	var m := mesa_en_lugar(lugar)
	if m == -1:
		return true
	return mesas[m]["asientos"] != asientos and not mesas[m]["sillas"].has(true)

func hay_lugar_para_mesa(asientos: int) -> bool:
	for lugar in total_lugares_mesa():
		if puede_colocar_mesa(lugar, asientos):
			return true
	return false

func nueva_mesa(lugar: int, asientos: int) -> Dictionary:
	var sillas := []
	for s in asientos:
		sillas.append(false)
	return {"lugar": lugar, "asientos": asientos, "sillas": sillas, "sucia": false}

func colocar_mesa(lugar: int) -> void:
	var asientos: int = colocando["valor"]
	var precio: int = PRECIO_MESA[asientos]
	if not puede_colocar_mesa(lugar, asientos) or dinero < precio:
		return
	dinero -= precio
	var m := mesa_en_lugar(lugar)
	if m == -1:
		mesas.append(nueva_mesa(lugar, asientos))
	else:
		atender_mesa(m)   # junta las propinas que habia
		var devolucion := int(PRECIO_MESA[mesas[m]["asientos"]] * DEVOLUCION_AL_REEMPLAZAR)
		dinero += devolucion
		mesas[m] = nueva_mesa(lugar, asientos)
	sonar("compra", 0.05)
	for k in 15:
		agregar_particula(posicion_lugar_mesa(lugar), Color(1, 0.9, 0.5))
	colocando = {}


# ---- Local, mejoras y empleados ----
func agrandar_local() -> void:
	if en_obras or nivel_local >= MAX_NIVEL_LOCAL or dinero < costo_local():
		return
	dinero -= costo_local()
	nivel_local += 1
	cerrar_tienda()
	sonar("obra")
	# Animacion: la pared de abajo se corre hasta el nuevo tamano
	en_obras = true
	var tw := create_tween()
	tw.tween_property(self, "borde_local", borde_para_nivel(nivel_local), 1.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(terminar_obras.bind("Cafetería agrandada!"))


func borde_para_nivel(nivel: int) -> float:
	return Y_FILAS_MESAS + (nivel - 1) * ALTO_FILA + 72


func comprar_patio() -> void:
	if en_obras or tiene_patio or nivel_local < MAX_NIVEL_LOCAL or dinero < COSTO_PATIO:
		return
	dinero -= COSTO_PATIO
	tiene_patio = true
	cerrar_tienda()
	sonar("obra")
	en_obras = true
	var tw := create_tween()
	tw.tween_property(self, "alto_patio", PATIO_ALTO, 1.6) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(terminar_obras.bind("Patio de mesas abierto!"))


func contratar_tecnico() -> void:
	if not tiene_tecnico and nivel_local >= 2 and dinero >= COSTO_TECNICO:
		dinero -= COSTO_TECNICO
		tiene_tecnico = true
		sonar("logro")

func contratar_mozo() -> void:
	if not tiene_mozo and nivel_local >= 2 and dinero >= COSTO_MOZO:
		dinero -= COSTO_MOZO
		tiene_mozo = true
		sonar("logro")

func comprar_cartel() -> void:
	if not tiene_cartel and tiene_patio and dinero >= COSTO_CARTEL:
		dinero -= COSTO_CARTEL
		tiene_cartel = true
		sonar("logro")


# =====================================================
#  MISIONES
# =====================================================
func valor_para_mision(tipo: String) -> int:
	match tipo:
		"asientos":
			return asientos_totales()
		"nivel":
			return nivel_local
		"productos":
			return productos_disponibles().size()
		"reputacion":
			return int(reputacion + 0.001)
		"maquinas":
			return cantidad_dispensadoras()
		"patio":
			return 1 if tiene_patio else 0
		"premium":
			var n := 0
			for d in dispensadoras:
				if d != null and d["modelo"] == 2:
					n += 1
			return n
	return contadores.get(tipo, 0)

func misiones_activas() -> Array:
	# Las primeras 3 misiones que todavia no reclamaste
	var lista := []
	for i in MISIONES.size():
		if not misiones_hechas.has(i):
			lista.append(i)
			if lista.size() == 3:
				break
	return lista

func mision_cumplida(i: int) -> bool:
	return valor_para_mision(MISIONES[i]["tipo"]) >= MISIONES[i]["meta"]

func reclamar_mision(fila: int) -> void:
	var activas := misiones_activas()
	if fila >= activas.size():
		return
	var i: int = activas[fila]
	if mision_cumplida(i):
		misiones_hechas.append(i)
		dinero += MISIONES[i]["premio"]
		sonar("logro")
		agregar_texto(Vector2(200, 640), "Misión cumplida: +$%d" % MISIONES[i]["premio"], Color.YELLOW, 2.0)


# ---- Diarias ----
func dia_calendario() -> int:
	# Numero de dia real (cambia a la medianoche de tu celular)
	var sesgo: int = Time.get_time_zone_from_system().get("bias", 0)
	return int(floor((Time.get_unix_time_from_system() + sesgo * 60) / 86400.0))

func segundos_para_manana() -> int:
	var sesgo: int = Time.get_time_zone_from_system().get("bias", 0)
	var ahora := Time.get_unix_time_from_system() + sesgo * 60
	return int((dia_calendario() + 1) * 86400.0 - ahora)

func revisar_diarias() -> void:
	var hoy := dia_calendario()
	if dia_diarias == hoy:
		return
	dia_diarias = hoy
	diarias = []
	var dificultad := clampi(nivel_local - 1 + sucursales_completadas.size(), 0, 2)
	var opciones := range(DIARIAS.size())
	opciones.shuffle()
	for k in 3:
		var plantilla: Dictionary = DIARIAS[opciones[k]]
		var meta: int = plantilla["metas"][dificultad]
		diarias.append({"texto": plantilla["texto"] % meta, "tipo": plantilla["tipo"], "meta": meta,
			"base": vida.get(plantilla["tipo"], 0), "premio": PREMIO_DIARIAS[dificultad], "reclamada": false})

func progreso_diaria(k: int) -> int:
	var d: Dictionary = diarias[k]
	return int(vida.get(d["tipo"], 0) - d["base"])

func reclamar_diaria(k: int) -> void:
	if k >= diarias.size():
		return
	var d: Dictionary = diarias[k]
	if d["reclamada"] or progreso_diaria(k) < d["meta"]:
		return
	d["reclamada"] = true
	dinero += d["premio"]
	granos += 1
	sonar("logro")
	agregar_texto(Vector2(150, 640), "+$%d y 1 grano de oro" % d["premio"], Color.YELLOW, 2.0)


# ---- Premio por entrar cada dia ----
func revisar_premio_diario() -> void:
	var hoy := dia_calendario()
	if ultimo_premio_diario == hoy:
		return
	if ultimo_premio_diario == hoy - 1:
		racha = racha % 7 + 1
	else:
		racha = 1
	ultimo_premio_diario = hoy
	var premio: Dictionary = PREMIOS_DIARIOS[racha - 1]
	dinero += premio.get("dinero", 0)
	granos += premio.get("granos", 0)
	cupones_premium += premio.get("premium", 0)
	var calendario := ""
	for k in PREMIOS_DIARIOS.size():
		var marca := ">> " if k == racha - 1 else ("OK " if k < racha - 1 else "    ")
		calendario += "%sDía %d: %s\n" % [marca, k + 1, PREMIOS_DIARIOS[k]["texto"]]
	var extra := "\nEl cupón está en TIENDA > Comprar." if premio.has("premium") else ""
	mostrar_mensaje("Premio diario: día %d" % racha,
		"¡Gracias por volver! Hoy ganaste: %s%s\n\n%s\nEntrá todos los días para no perder la racha." % [premio["texto"], extra, calendario],
		[["¡Genial!", func(): sonar("logro")]])


func hay_algo_para_reclamar() -> bool:
	for fila in misiones_activas():
		if mision_cumplida(fila):
			return true
	for k in diarias.size():
		if not diarias[k]["reclamada"] and progreso_diaria(k) >= diarias[k]["meta"]:
			return true
	return false


# =====================================================
#  META FINAL Y FRANQUICIA
# =====================================================
func condiciones_meta() -> Array:
	return [
		["Local al tamaño máximo", nivel_local >= MAX_NIVEL_LOCAL],
		["Patio de mesas", tiene_patio],
		["Reputación %.1f (tenés %.1f)" % [REPUTACION_LEGENDARIA, reputacion], reputacion >= REPUTACION_LEGENDARIA],
		["Juntar $%d (tenés $%d)" % [suc()["meta"], dinero], dinero >= suc()["meta"]],
	]

func revisar_meta() -> void:
	if legendaria:
		return
	for c in condiciones_meta():
		if not c[1]:
			return
	legendaria = true
	if not sucursales_completadas.has(suc()["id"]):
		sucursales_completadas.append(suc()["id"])
	festejar()


func todas_completadas() -> bool:
	return sucursales_completadas.size() >= SUCURSALES.size()

func granos_a_ganar() -> int:
	return 5 + int(contadores.get("ganado", 0) / 3000) + (3 if reputacion >= 4.8 else 0)


func festejar() -> void:
	sonar("festejo")
	vibrar(500)
	# Confeti de colores
	for k in 160:
		particulas.append({
			"pos": Vector2(randf_range(0, ANCHO_PANTALLA), randf_range(-200, 0)),
			"vel": Vector2(randf_range(-40, 40), randf_range(150, 350)),
			"vida": randf_range(2.5, 4.0), "tam": randf_range(4, 8), "confeti": true,
			"color": Color.from_hsv(randf(), 0.8, 1.0),
		})
	var titulo := "¡IMPERIO DEL CAFÉ!" if todas_completadas() else "¡CAFETERÍA LEGENDARIA!"
	var minutos := int(tiempo_jugado / 60)
	var texto_festejo := "Tu local de %s es legendario.\n\nClientes atendidos: %d\nPlata ganada: $%d\nMáquinas arregladas: %d\nDías: %d\nTiempo jugado: %d h %d min\n\nAhora podés abrir una sucursal nueva y ganar %d granos de oro para mejoras permanentes." % [
		suc()["nombre"], contadores.get("atendidos", 0), contadores.get("ganado", 0),
		contadores.get("arreglos", 0), dia, minutos / 60, minutos % 60, granos_a_ganar()]
	if todas_completadas():
		texto_festejo = "¡Completaste TODAS las sucursales!\n\n" + texto_festejo
	mostrar_mensaje(titulo, texto_festejo,
		[["Seguir jugando", func(): pass], ["Ver sucursales", abrir_tienda_en.bind(4)]])


func pedir_abrir_sucursal(i: int) -> void:
	if not legendaria:
		return
	mostrar_mensaje("Abrir sucursal en %s" % SUCURSALES[i]["nombre"],
		"%s\n\nVas a empezar de cero en un local chico.\nGanás %d granos de oro.\nTus mejoras de oro se mantienen.\n\n¿Abrimos?" % [
			SUCURSALES[i]["descripcion"], granos_a_ganar()],
		[["No", func(): pass], ["¡Sí, abrir!", abrir_sucursal.bind(i)]])


func abrir_sucursal(i: int) -> void:
	granos += granos_a_ganar()
	sucursal = i
	reiniciar_sucursal()
	cerrar_tienda()
	cambiar_musica_sucursal()
	sonar("festejo")
	agregar_texto(Vector2(120, 640), "¡Bienvenido a %s!" % suc()["nombre"], Color.YELLOW, 3.0)
	guardar_partida()


func reiniciar_sucursal() -> void:
	# Todo lo de la sucursal vuelve a empezar (lo de oro y las sucursales completadas se mantienen)
	dinero = DINERO_INICIAL + 150 * oro("inversion")
	reputacion = REPUTACION_INICIAL
	nivel_local = 1
	tiene_patio = false
	tiene_cartel = false
	tiene_tecnico = false
	tiene_mozo = false
	legendaria = false
	reiniciar_recetas()
	dispensadoras = []
	for k in LUGARES_DISPENSADORA:
		dispensadoras.append(null)
	dispensadoras[0] = nueva_dispensadora(0)   # empiezas con una basica
	mesas = []
	clientes = []
	monedas = []
	mozo = {}
	colocando = {}
	contadores = {}
	for c in CONTADORES:
		contadores[c] = 0
	misiones_hechas = []
	dia = 1
	reloj_dia = 0.0
	inicio_dia = contadores.duplicate()
	lloviendo = false
	timer_clima = 90.0
	borde_local = borde_para_nivel(1)
	alto_patio = 0.0
	programar_horas_pico()


func comprar_mejora_oro(k: int) -> void:
	var m: Dictionary = MEJORAS_ORO[k]
	var nivel := oro(m["id"])
	if nivel >= m["max"] or granos < costo_mejora_oro(k):
		return
	granos -= costo_mejora_oro(k)
	mejoras_oro[m["id"]] = nivel + 1
	sonar("logro")

func costo_mejora_oro(k: int) -> int:
	return MEJORAS_ORO[k]["costo"] * (oro(MEJORAS_ORO[k]["id"]) + 1)


# =====================================================
#  GUARDAR Y CARGAR PARTIDA
# =====================================================
func guardar_partida() -> void:
	if no_guardar:
		return
	var lista_disp := []
	for d in dispensadoras:
		lista_disp.append(null if d == null else {"modelo": d["modelo"], "rota": d["rota"], "desgaste": d["desgaste"]})
	var lista_mesas := []
	for m in mesas:
		lista_mesas.append({"lugar": m["lugar"], "asientos": m["asientos"], "sucia": m["sucia"]})
	var datos := {
		"version": 3,
		"sucursal": sucursal, "dinero": dinero, "reputacion": reputacion, "nivel_local": nivel_local,
		"patio": tiene_patio, "cartel": tiene_cartel, "tecnico": tiene_tecnico, "mozo": tiene_mozo,
		"legendaria": legendaria, "recetas": nivel_receta, "dispensadoras": lista_disp, "mesas": lista_mesas,
		"contadores": contadores, "misiones_hechas": misiones_hechas, "dia": dia, "reloj_dia": reloj_dia,
		"inicio_dia": inicio_dia,
		"granos": granos, "mejoras_oro": mejoras_oro, "completadas": sucursales_completadas, "vida": vida,
		"diarias": diarias, "dia_diarias": dia_diarias, "ultimo_premio": ultimo_premio_diario, "racha": racha,
		"cupones_premium": cupones_premium, "tiempo_jugado": tiempo_jugado, "tutorial": tutorial_paso,
		"musica": musica_on, "sonido": sonido_on, "vibracion": vibracion_on,
		"tienda_vista": tienda_abierta_alguna_vez,
		"hora": Time.get_unix_time_from_system(),
	}
	var archivo := FileAccess.open(ARCHIVO_PARTIDA, FileAccess.WRITE)
	if archivo:
		archivo.store_string(JSON.stringify(datos))


func cargar_partida() -> bool:
	if not FileAccess.file_exists(ARCHIVO_PARTIDA):
		return false
	var datos = JSON.parse_string(FileAccess.get_file_as_string(ARCHIVO_PARTIDA))
	if typeof(datos) != TYPE_DICTIONARY:
		return false

	# Progreso permanente
	sucursal = clampi(int(datos.get("sucursal", 0)), 0, SUCURSALES.size() - 1)
	granos = int(datos.get("granos", 0))
	mejoras_oro = {}
	for id in datos.get("mejoras_oro", {}):
		mejoras_oro[id] = int(datos["mejoras_oro"][id])
	sucursales_completadas = datos.get("completadas", [])
	for c in datos.get("vida", {}):
		vida[c] = int(datos["vida"][c])
	diarias = []
	for d in datos.get("diarias", []):
		diarias.append({"texto": str(d["texto"]), "tipo": str(d["tipo"]), "meta": int(d["meta"]),
			"base": int(d["base"]), "premio": int(d["premio"]), "reclamada": bool(d["reclamada"])})
	dia_diarias = int(datos.get("dia_diarias", -1))
	ultimo_premio_diario = int(datos.get("ultimo_premio", -1))
	racha = int(datos.get("racha", 0))
	cupones_premium = int(datos.get("cupones_premium", 0))
	tiempo_jugado = float(datos.get("tiempo_jugado", 0.0))
	# Si la partida es de una version anterior, el tutorial ya no hace falta
	tutorial_paso = int(datos.get("tutorial", -1))
	musica_on = bool(datos.get("musica", true))
	sonido_on = bool(datos.get("sonido", true))
	vibracion_on = bool(datos.get("vibracion", true))
	tienda_abierta_alguna_vez = bool(datos.get("tienda_vista", false))

	# Esta sucursal
	reiniciar_sucursal()
	dinero = int(datos.get("dinero", DINERO_INICIAL))
	reputacion = float(datos.get("reputacion", REPUTACION_INICIAL))
	nivel_local = clampi(int(datos.get("nivel_local", 1)), 1, MAX_NIVEL_LOCAL)
	tiene_patio = bool(datos.get("patio", false))
	tiene_cartel = bool(datos.get("cartel", false))
	tiene_tecnico = bool(datos.get("tecnico", false))
	tiene_mozo = bool(datos.get("mozo", false))
	legendaria = bool(datos.get("legendaria", false))
	var recetas: Dictionary = datos.get("recetas", {})
	for id in recetas:
		if nivel_receta.has(id):
			nivel_receta[id] = int(recetas[id])
	for c in datos.get("contadores", {}):
		contadores[c] = int(datos["contadores"][c])
	for i in datos.get("misiones_hechas", []):
		misiones_hechas.append(int(i))
	dia = int(datos.get("dia", 1))
	reloj_dia = float(datos.get("reloj_dia", 0.0))
	for c in datos.get("inicio_dia", {}):
		inicio_dia[c] = int(datos["inicio_dia"][c])

	if datos.has("dispensadoras"):
		dispensadoras[0] = null
		var lista: Array = datos["dispensadoras"]
		for i in min(lista.size(), LUGARES_DISPENSADORA):
			if lista[i] != null:
				dispensadoras[i] = nueva_dispensadora(int(lista[i]["modelo"]))
				dispensadoras[i]["rota"] = bool(lista[i]["rota"])
				dispensadoras[i]["desgaste"] = float(lista[i].get("desgaste", 0.0))
		for m in datos.get("mesas", []):
			agregar_mesa_cargada(int(m["lugar"]), int(m["asientos"]), bool(m.get("sucia", false)))
	else:
		# Partida muy vieja (con cajas): se pasa a dispensadoras basicas
		for i in clamp(int(datos.get("cajas", 1)), 1, lugares_dispensadora_habilitados()):
			dispensadoras[i] = nueva_dispensadora(0)
		for i in int(datos.get("mesas", 0)):
			agregar_mesa_cargada(i, 2, false)
	if cantidad_dispensadoras() == 0:
		dispensadoras[0] = nueva_dispensadora(0)

	# El local y el patio aparecen ya construidos (sin animacion)
	borde_local = borde_para_nivel(nivel_local)
	alto_patio = PATIO_ALTO if tiene_patio else 0.0

	# Ganancias mientras no estabas
	var segundos: float = Time.get_unix_time_from_system() - float(datos.get("hora", 0))
	if segundos > 60:
		segundos = min(segundos, MAX_HORAS_AUSENTE * 3600.0)
		var ganado := int(segundos * ingreso_por_segundo() * RENDIMIENTO_OFFLINE)
		if ganado > 0:
			dinero += ganado
			mostrar_mensaje("¡Bienvenido de vuelta!",
				"Mientras no estabas (%d minutos)\ntu cafetería ganó $%d" % [int(segundos / 60), ganado])
	return true


func agregar_mesa_cargada(lugar: int, asientos: int, sucia: bool) -> void:
	if lugar < total_lugares_mesa() and mesa_en_lugar(lugar) == -1:
		var m := nueva_mesa(lugar, clampi(asientos, 1, 4))
		m["sucia"] = sucia
		mesas.append(m)


func ingreso_por_segundo() -> float:
	var llegan := 1.0 / intervalo_spawn()
	var atienden := 0.0
	for d in dispensadoras:
		if d != null and not d["rota"]:
			atienden += 1.0 / DISPENSADORAS[d["modelo"]]["tiempo"]
	return min(llegan, atienden) * precio_promedio()


func borrar_partida() -> void:
	no_guardar = true
	if FileAccess.file_exists(ARCHIVO_PARTIDA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO_PARTIDA))
	get_tree().reload_current_scene()


# =====================================================
#  OBRAS Y PARTICULAS
# =====================================================
func terminar_obras(mensaje: String) -> void:
	en_obras = false
	position = origen
	sonar("logro")
	agregar_texto(Vector2(140, 640), mensaje, Color.YELLOW, 2.5)
	for i in 40:
		agregar_particula(Vector2(randf_range(IZQUIERDA, DERECHA), randf_range(ARRIBA, borde_local)), Color(0.85, 0.8, 0.7))
	guardar_partida()

func agregar_particula(donde: Vector2, color: Color) -> void:
	particulas.append({
		"pos": donde,
		"vel": Vector2(randf_range(-60, 60), randf_range(-90, -20)),
		"vida": randf_range(0.5, 1.0),
		"tam": randf_range(4, 10),
		"color": color,
	})

func actualizar_particulas(delta: float) -> void:
	if en_obras:
		# El piso tiembla y sale polvo de donde se esta construyendo
		position = origen + Vector2(randf_range(-3, 3), randf_range(-3, 3))
		for i in 3:
			if tiene_patio and alto_patio < PATIO_ALTO:
				agregar_particula(Vector2(randf_range(PATIO_X, PATIO_X + PATIO_ANCHO), PATIO_Y + alto_patio), Color(0.85, 0.8, 0.7))
			else:
				agregar_particula(Vector2(randf_range(IZQUIERDA, DERECHA), borde_local), Color(0.85, 0.8, 0.7))
	for p in particulas.duplicate():
		p["vida"] -= delta
		p["pos"] += p["vel"] * delta
		if p.get("confeti", false):
			p["pos"].x += sin(reloj * 5.0 + p["tam"]) * 40.0 * delta
		if p["vida"] <= 0.0:
			particulas.erase(p)


# =====================================================
#  POSICIONES
# =====================================================
func posicion_dispensadora(i: int) -> Vector2:
	return Vector2(150 + i * 140, ARRIBA + 38)

func rect_dispensadora(i: int) -> Rect2:
	return Rect2(posicion_dispensadora(i) - Vector2(60, 38), Vector2(120, 90))

func posicion_cola(i: int, lugar: int) -> Vector2:
	return posicion_dispensadora(i) + Vector2(0, 78 + lugar * 36)

func posicion_lugar_mesa(lugar: int) -> Vector2:
	if es_lugar_patio(lugar):
		lugar -= MAX_NIVEL_LOCAL * MESAS_POR_FILA
		var ancho := PATIO_ANCHO / COLUMNAS_PATIO
		return Vector2(PATIO_X + ancho / 2 + (lugar % COLUMNAS_PATIO) * ancho,
			PATIO_Y + 56 + (lugar / COLUMNAS_PATIO) * 112)
	return Vector2(IZQUIERDA + ANCHO_CELDA / 2 + (lugar % MESAS_POR_FILA) * ANCHO_CELDA,
		Y_FILAS_MESAS + (lugar / MESAS_POR_FILA) * ALTO_FILA)

func rect_lugar_mesa(lugar: int) -> Rect2:
	return Rect2(posicion_lugar_mesa(lugar) - Vector2(70, 52), Vector2(140, 104))

func posicion_silla(m: int, silla: int) -> Vector2:
	return posicion_lugar_mesa(mesas[m]["lugar"]) + OFFSET_SILLAS[silla]


# =====================================================
#  TEXTOS FLOTANTES
# =====================================================
func agregar_texto(pos: Vector2, s: String, color: Color, duracion := 1.0) -> void:
	textos.append({"pos": pos, "texto": s, "color": color, "vida": duracion})

func actualizar_textos(delta: float) -> void:
	for t in textos.duplicate():
		t["vida"] -= delta
		t["pos"] += Vector2(0, -30 * delta)
		if t["vida"] <= 0.0:
			textos.erase(t)


# =====================================================
#  DIBUJOS: se cargan desde la carpeta res://sprites
#  Si falta algun archivo, se dibuja una figura simple.
# =====================================================
func cargar_sprites() -> void:
	for nombre in ["mesa", "silla", "piso", "piso_mesas", "mostrador", "puerta", "pasto", "vereda",
			"piso_patio", "sombrilla", "compu", "mozo", "mano", "arena", "asfalto", "nieve"]:
		tex[nombre] = cargar("res://sprites/%s.png" % nombre)
	for d in DISPENSADORAS:
		tex["disp_" + d["id"]] = cargar("res://sprites/dispensadora_%s.png" % d["id"])
	for p in PRODUCTOS:
		tex["icono_" + p["id"]] = cargar("res://sprites/icono_%s.png" % p["id"])
	for i in range(1, 7):
		var t := cargar("res://sprites/cliente_%d.png" % i)
		if t != null:
			tex_clientes.append(t)

func cargar(ruta: String) -> Texture2D:
	if ResourceLoader.exists(ruta):
		return load(ruta)
	return null

func dibujar_centrado(t: Texture2D, centro: Vector2, tinte := Color.WHITE) -> void:
	draw_texture(t, centro - t.get_size() / 2, tinte)

func dibujar_zona(area: Rect2, nombre: String, color: Color, tinte := Color.WHITE) -> void:
	if tex.get(nombre) != null:
		draw_texture_rect(tex[nombre], area, true, tinte)   # true = repetir como baldosas
	else:
		draw_rect(area, color * tinte)

func texto(pos: Vector2, s: String, tam: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)

func texto_centrado(centro: Vector2, s: String, tam: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, centro + Vector2(-150, tam * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, 300, tam, color)


# =====================================================
#  DIBUJO DEL LOCAL
# =====================================================
func _draw() -> void:
	var pared := Color("#4a2e1f")
	var titila := 0.5 + 0.5 * sin(reloj * 6.0)
	var tinte: Color = suc()["tinte"]

	# ---- Exterior (cambia segun la sucursal), vereda y caminito ----
	dibujar_zona(Rect2(-20, -800, ANCHO_PANTALLA + 40, 2900), suc()["exterior"], Color("#6fa85a"))
	dibujar_zona(Rect2(-20, CALLE_ARRIBA, ANCHO_PANTALLA + 40, 800), "vereda", Color("#b8b8b0"))
	dibujar_zona(Rect2(CAMINO_X - 35, borde_local, 70, CALLE_ARRIBA - borde_local), "vereda", Color("#b8b8b0"))

	# ---- Patio ----
	if tiene_patio:
		var patio := Rect2(PATIO_X, PATIO_Y, PATIO_ANCHO, alto_patio)
		dibujar_zona(patio, "piso_patio", Color("#d9a07a"), tinte)
		draw_rect(patio, Color.WHITE, false, 4.0)
		var x := PATIO_X
		while x < PATIO_X + PATIO_ANCHO:
			draw_rect(Rect2(x, PATIO_Y - 3, 6, 6), Color("#dddddd"))
			x += 30
		if alto_patio >= PATIO_ALTO - 1:
			draw_rect(Rect2(PATIO_X - 4, PORTON_Y - 30, 8, 60), Color("#d9a07a"))   # porton
			draw_rect(Rect2(CAMINO_X + 35, PORTON_Y - 28, PATIO_X - CAMINO_X - 35, 56), Color("#b8b8b0"))
		draw_rect(Rect2(PATIO_X, PATIO_Y - 26, 180, 24), Color(0, 0, 0, 0.5))
		texto(Vector2(PATIO_X + 8, PATIO_Y - 8), "PATIO DE MESAS", 16, Color.WHITE)

	# ---- Local (interior) ----
	var y_mesas := Y_FILAS_MESAS - 80
	dibujar_zona(Rect2(IZQUIERDA, ARRIBA, DERECHA - IZQUIERDA, y_mesas - ARRIBA), "piso", Color("#d9c09a"), tinte)
	dibujar_zona(Rect2(IZQUIERDA, y_mesas, DERECHA - IZQUIERDA, borde_local - y_mesas), "piso_mesas", Color("#cfe0c3"), tinte)
	draw_rect(Rect2(IZQUIERDA - 8, ARRIBA - 8, DERECHA - IZQUIERDA + 16, 8), pared)
	draw_rect(Rect2(IZQUIERDA - 8, ARRIBA, 8, borde_local - ARRIBA + 8), pared)
	draw_rect(Rect2(DERECHA, ARRIBA, 8, borde_local - ARRIBA + 8), pared)
	draw_rect(Rect2(IZQUIERDA, borde_local, CAMINO_X - 40 - IZQUIERDA, 8), pared)
	draw_rect(Rect2(CAMINO_X + 40, borde_local, DERECHA - CAMINO_X - 40, 8), pared)
	if tex["puerta"] != null:
		draw_texture(tex["puerta"], Vector2(CAMINO_X - 40, borde_local - 4))
	texto(Vector2(IZQUIERDA + 8, y_mesas + 20), "%s - Nivel %d" % [suc()["nombre"], nivel_local], 16, Color(0.2, 0.3, 0.25))

	# ---- Mostrador y dispensadoras ----
	dibujar_zona(Rect2(IZQUIERDA + 50, ARRIBA + 12, DERECHA - IZQUIERDA - 100, 52), "mostrador", Color("#7a4b2a"))
	for i in LUGARES_DISPENSADORA:
		dibujar_lugar_dispensadora(i, titila)

	# ---- Lugares de mesas ----
	for lugar in total_lugares_mesa():
		if not lugar_mesa_habilitado(lugar) or not lugar_visible(lugar):
			continue
		var p := posicion_lugar_mesa(lugar)
		var m := mesa_en_lugar(lugar)
		if m >= 0:
			dibujar_mesa(m)
		else:
			draw_rect(rect_lugar_mesa(lugar).grow(-4), Color(0.2, 0.45, 0.3, 0.6), false, 3.0)
			texto_centrado(p, "Libre", 18, Color(0.15, 0.4, 0.25))
		if colocando.get("tipo") == "mesa" and puede_colocar_mesa(lugar, colocando["valor"]):
			draw_rect(rect_lugar_mesa(lugar), Color(1, 0.85, 0.2, 0.25 + 0.35 * titila))
			draw_rect(rect_lugar_mesa(lugar), Color(1, 0.85, 0.2), false, 4.0)

	# ---- Clientes y mozo (los de mas abajo se dibujan encima) ----
	var ordenados := clientes.duplicate()
	ordenados.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for c in ordenados:
		var tinte_c := Color(1, 0.55, 0.55) if c.enojado else Color.WHITE
		if tex_clientes.size() > 0:
			var t: Texture2D = tex_clientes[c.sprite]
			draw_texture(t, c.pos - Vector2(t.get_width() / 2.0, t.get_height() - 12), tinte_c)
		else:
			draw_circle(c.pos, 12, Color.CORNFLOWER_BLUE * tinte_c)
		if c.tipo == "critico":
			# Galera del critico gastronomico
			draw_rect(Rect2(c.pos + Vector2(-13, -38), Vector2(26, 4)), Color.BLACK)
			draw_rect(Rect2(c.pos + Vector2(-9, -54), Vector2(18, 17)), Color.BLACK)
			draw_rect(Rect2(c.pos + Vector2(-9, -42), Vector2(18, 3)), Color(0.75, 0.1, 0.1))
	if tiene_mozo and not mozo.is_empty():
		if tex["mozo"] != null:
			var t: Texture2D = tex["mozo"]
			draw_texture(t, mozo["pos"] - Vector2(t.get_width() / 2.0, t.get_height() - 12))
		else:
			draw_circle(mozo["pos"], 12, Color.WHITE)
	for c in ordenados:
		dibujar_globo(c)

	# ---- Propinas sobre las mesas ----
	for mo in monedas:
		var p := posicion_lugar_mesa(mesas[mo["mesa"]]["lugar"]) + Vector2(0, -6 + 4 * sin(reloj * 5.0))
		var se_ve: bool = mo["vida"] > 2.0 or fmod(reloj, 0.3) < 0.15   # titila antes de desaparecer
		if se_ve:
			draw_circle(p, 14, Color("#b8860b"))
			draw_circle(p, 11, Color("#ffd700"))
			texto_centrado(p, "$", 16, Color("#8a6400"))
			draw_circle(p + Vector2(-4, -5), 3, Color(1, 1, 0.85, titila))

	# ---- Avisos de maquinas (encima de los clientes) ----
	for i in LUGARES_DISPENSADORA:
		dibujar_aviso_maquina(i, titila)

	# ---- Sombrillas del patio ----
	if tex["sombrilla"] != null:
		for m in mesas.size():
			if mesa_en_patio(m) and lugar_visible(mesas[m]["lugar"]):
				dibujar_centrado(tex["sombrilla"], posicion_lugar_mesa(mesas[m]["lugar"]) + Vector2(0, -8))

	# ---- Lluvia ----
	if lloviendo:
		for k in 110:
			var lx := fmod(k * 97.3 + reloj * 60.0, ANCHO_PANTALLA + 40.0) - 20.0
			var ly := fmod(k * 53.7 + reloj * 900.0, ALTO_PANTALLA + 200.0) - 100.0
			draw_line(Vector2(lx, ly), Vector2(lx - 6, ly + 18), Color(0.7, 0.8, 1.0, 0.55), 2.0)

	# ---- Particulas y confeti ----
	for p in particulas:
		var col: Color = p["color"]
		col.a = clamp(p["vida"], 0.0, 1.0)
		if p.get("confeti", false):
			draw_rect(Rect2(p["pos"], Vector2(p["tam"], p["tam"] * 0.6)), col)
		else:
			draw_circle(p["pos"], p["tam"], col)

	# ---- Textos flotantes (con sombra para que se lean) ----
	for t in textos:
		var col: Color = t["color"]
		col.a = clamp(t["vida"], 0.0, 1.0)
		var tam := 26 if t["texto"].length() <= 4 else 32
		texto(t["pos"] + Vector2(2, 2), t["texto"], tam, Color(0, 0, 0, col.a))
		texto(t["pos"], t["texto"], tam, col)


func dibujar_lugar_dispensadora(i: int, titila: float) -> void:
	var p := posicion_dispensadora(i)
	var d = dispensadoras[i]
	var rect := rect_dispensadora(i)

	if i >= lugares_dispensadora_habilitados():
		draw_rect(rect.grow(-14), Color(0, 0, 0, 0.35))
		texto_centrado(p, "Nivel %d" % i, 16, Color(0.9, 0.9, 0.9))
	elif d == null:
		draw_rect(rect.grow(-14), Color(1, 1, 1, 0.5), false, 3.0)
		texto_centrado(p + Vector2(0, -8), "+", 32, Color(1, 1, 1, 0.8))
		texto_centrado(p + Vector2(0, 22), "Libre", 14, Color(1, 1, 1, 0.8))
	else:
		var modelo: Dictionary = DISPENSADORAS[d["modelo"]]
		var t: Texture2D = tex["disp_" + modelo["id"]]
		var tinte := Color(0.5, 0.5, 0.5) if d["rota"] and d["arreglando"] <= 0.0 else Color.WHITE
		if t != null:
			dibujar_centrado(t, p, tinte)
		else:
			draw_rect(Rect2(p - Vector2(24, 28), Vector2(48, 56)), Color("#777777") * tinte)
		# Barrita de desgaste: verde = nueva, roja = muy gastada
		if not d["rota"]:
			var barra := Rect2(p + Vector2(-30, 32), Vector2(60, 7))
			draw_rect(barra, Color(0, 0, 0, 0.7))
			draw_rect(Rect2(barra.position, Vector2(60 * d["desgaste"], 7)), Color.GREEN.lerp(Color.RED, d["desgaste"]))
		if not d["rota"] and not d["cola"].is_empty() and d["limpiando"] <= 0.0:
			var progreso: float = d["timer"] / tiempo_atencion(i, d["cola"][0])
			if progreso > 0.0:
				draw_rect(Rect2(p + Vector2(-30, -40), Vector2(60, 8)), Color.BLACK)
				draw_rect(Rect2(p + Vector2(-30, -40), Vector2(60 * progreso, 8)), Color.YELLOW)

	if colocando.get("tipo") == "dispensadora" and puede_colocar_dispensadora(i, colocando["valor"]):
		draw_rect(rect, Color(1, 0.85, 0.2, 0.2 + 0.3 * titila))
		draw_rect(rect, Color(1, 0.85, 0.2), false, 4.0)


func dibujar_aviso_maquina(i: int, titila: float) -> void:
	var d = dispensadoras[i]
	if d == null:
		return
	var p := posicion_dispensadora(i)
	if d["arreglando"] > 0.0 or d["limpiando"] > 0.0:
		var arreglo: bool = d["arreglando"] > 0.0
		var avance: float = 1.0 - (d["arreglando"] / TIEMPO_ARREGLO if arreglo else d["limpiando"] / TIEMPO_MANTENIMIENTO)
		var barra := Rect2(p + Vector2(-56, 24), Vector2(112, 26))
		draw_rect(barra, Color(0.05, 0.1, 0.2, 0.95))
		draw_rect(Rect2(barra.position, Vector2(barra.size.x * avance, barra.size.y)), Color(0.2, 0.55, 0.9))
		texto_centrado(barra.get_center(), "Arreglando..." if arreglo else "Limpiando...", 14, Color.WHITE)
	elif d["rota"]:
		var escala := 1.0 + 0.1 * titila
		draw_circle(p + Vector2(32, -26), 13 * escala, Color(0.85, 0.15, 0.1))
		texto_centrado(p + Vector2(32, -26), "!", 22, Color.WHITE)
		var cartel := Rect2(p + Vector2(-56, 24), Vector2(112, 28))
		draw_rect(cartel, Color(0.8, 0.1, 0.1, 0.95))
		draw_rect(cartel, Color(1, 0.85, 0.2, titila), false, 2.0)
		texto_centrado(cartel.get_center(), "Arreglar $%d" % costo_arreglo(i), 15, Color.WHITE)
	elif d["desgaste"] >= 0.6:
		# Aviso amarillo: conviene hacerle mantenimiento
		var c := p + Vector2(32, -26)
		var tri := PackedVector2Array([c + Vector2(0, -13), c + Vector2(13, 10), c + Vector2(-13, 10)])
		draw_colored_polygon(tri, Color(1, 0.8, 0.1, 0.6 + 0.4 * titila))
		texto_centrado(c + Vector2(0, 2), "!", 16, Color.BLACK)


func dibujar_globo(c: Cliente) -> void:
	# Globito con lo que pidio + barra de paciencia (solo mientras espera)
	if c.estado != "cola":
		return
	var base := c.pos + Vector2(14, -58)
	var borde := Color(0.85, 0.15, 0.1) if c.tipo == "apurado" else Color(0.2, 0.2, 0.2)
	draw_rect(Rect2(base, Vector2(34, 32)), Color.WHITE)
	draw_rect(Rect2(base, Vector2(34, 32)), borde, false, 2.0)
	draw_colored_polygon(PackedVector2Array([base + Vector2(4, 32), base + Vector2(12, 32), base + Vector2(2, 40)]), Color.WHITE)
	var icono: Texture2D = tex["icono_" + PRODUCTOS[c.producto]["id"]]
	if icono != null:
		draw_texture(icono, base + Vector2(3, 2))
	else:
		texto(base + Vector2(10, 23), PRODUCTOS[c.producto]["nombre"].left(1), 18, Color.BLACK)
	if c.tipo == "apurado":
		# Relojito rojo: tiene poca paciencia pero paga el doble
		var r := base + Vector2(38, 4)
		draw_circle(r, 9, Color(0.85, 0.15, 0.1))
		draw_circle(r, 6, Color.WHITE)
		draw_line(r, r + Vector2(0, -4), Color.BLACK, 1.5)
		draw_line(r, r + Vector2(3, 0), Color.BLACK, 1.5)
	if c.camino.is_empty():
		var resto: float = clamp(c.paciencia / c.paciencia_total, 0.0, 1.0)
		var color := Color.GREEN.lerp(Color.RED, 1.0 - resto)
		draw_rect(Rect2(c.pos + Vector2(-16, -44), Vector2(32, 5)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(c.pos + Vector2(-16, -44), Vector2(32 * resto, 5)), color)


func lugar_visible(lugar: int) -> bool:
	var p := posicion_lugar_mesa(lugar)
	if es_lugar_patio(lugar):
		return p.y + 50 <= PATIO_Y + alto_patio
	return p.y + 50 <= borde_local


func dibujar_mesa(m: int) -> void:
	var p := posicion_lugar_mesa(mesas[m]["lugar"])
	for s in mesas[m]["asientos"]:
		if tex["silla"] != null:
			dibujar_centrado(tex["silla"], posicion_silla(m, s))
		else:
			draw_circle(posicion_silla(m, s), 14, Color("#5c3317"))
	if tex["mesa"] != null:
		dibujar_centrado(tex["mesa"], p)
	else:
		draw_circle(p, 28, Color("#a0522d"))
	if mesas[m]["sucia"]:
		# Manchas y tazas sucias
		draw_circle(p + Vector2(-10, 8), 7, Color(0.4, 0.25, 0.1, 0.7))
		draw_circle(p + Vector2(12, -6), 5, Color(0.4, 0.25, 0.1, 0.6))
		if tex["icono_cafe"] != null:
			draw_texture_rect(tex["icono_cafe"], Rect2(p + Vector2(-22, -20), Vector2(18, 18)), false)
			draw_texture_rect(tex["icono_cafe"], Rect2(p + Vector2(4, 2), Vector2(18, 18)), false)


# =====================================================
#  INTERFAZ: barra de arriba y boton de la compu
# =====================================================
func crear_interfaz() -> void:
	capa_ui = CanvasLayer.new()
	add_child(capa_ui)

	var tema := Theme.new()
	tema.default_font_size = 22   # letras grandes para el celular
	var raiz := Control.new()
	raiz.theme = tema
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_ui.add_child(raiz)

	# Barra de arriba
	var barra := ColorRect.new()
	barra.color = Color(0.1, 0.07, 0.05, 0.92)
	barra.set_anchors_preset(Control.PRESET_TOP_WIDE)
	barra.offset_bottom = ALTO_HUD
	raiz.add_child(barra)

	label_dinero = Label.new()
	label_dinero.position = Vector2(16, 2)
	label_dinero.add_theme_font_size_override("font_size", 44)
	label_dinero.add_theme_color_override("font_color", Color("#9cff8a"))
	barra.add_child(label_dinero)

	dibujo_estrellas = Control.new()
	dibujo_estrellas.position = Vector2(18, 64)
	dibujo_estrellas.size = Vector2(180, 30)
	dibujo_estrellas.draw.connect(dibujar_estrellas)
	barra.add_child(dibujo_estrellas)

	label_stats = Label.new()
	label_stats.position = Vector2(196, 62)
	label_stats.add_theme_font_size_override("font_size", 17)
	barra.add_child(label_stats)

	label_pista = Label.new()
	label_pista.position = Vector2(16, 94)
	label_pista.size = Vector2(540, 54)
	label_pista.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_pista.add_theme_font_size_override("font_size", 17)
	label_pista.add_theme_color_override("font_color", Color("#ffe08a"))
	barra.add_child(label_pista)

	# La compu (abre la tienda)
	btn_compu = Button.new()
	btn_compu.text = "TIENDA"
	btn_compu.icon = tex["compu"]
	btn_compu.expand_icon = true
	btn_compu.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn_compu.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn_compu.add_theme_font_size_override("font_size", 20)
	btn_compu.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_compu.offset_left = -150
	btn_compu.offset_right = -10
	btn_compu.offset_top = 8
	btn_compu.offset_bottom = 142
	btn_compu.pivot_offset = Vector2(70, 67)
	btn_compu.pressed.connect(abrir_tienda)
	raiz.add_child(btn_compu)

	# Globito rojo "!" cuando hay premios para reclamar
	aviso_compu = Label.new()
	aviso_compu.text = "!"
	aviso_compu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso_compu.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aviso_compu.add_theme_font_size_override("font_size", 26)
	var rojo := StyleBoxFlat.new()
	rojo.bg_color = Color(0.85, 0.1, 0.1)
	rojo.set_corner_radius_all(20)
	aviso_compu.add_theme_stylebox_override("normal", rojo)
	aviso_compu.position = Vector2(100, -4)
	aviso_compu.size = Vector2(40, 40)
	aviso_compu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn_compu.add_child(aviso_compu)

	# Boton para cancelar cuando estas colocando algo
	btn_cancelar = Button.new()
	btn_cancelar.text = "Cancelar"
	btn_cancelar.add_theme_font_size_override("font_size", 28)
	btn_cancelar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	btn_cancelar.offset_left = -130
	btn_cancelar.offset_right = 130
	btn_cancelar.offset_top = -110
	btn_cancelar.offset_bottom = -30
	btn_cancelar.pressed.connect(sonar.bind("click"))
	btn_cancelar.pressed.connect(cancelar_colocacion)
	btn_cancelar.visible = false
	raiz.add_child(btn_cancelar)

	crear_tienda(raiz)
	crear_tutorial(tema)
	crear_mensajes(tema)


func dibujar_estrellas() -> void:
	for i in 5:
		var centro := Vector2(14 + i * 34, 15)
		var lleno: float = clamp(reputacion - i, 0.0, 1.0)
		estrella(dibujo_estrellas, centro, 15, Color(0.35, 0.35, 0.35))
		if lleno >= 0.75:
			estrella(dibujo_estrellas, centro, 15, Color("#ffcc33"))
		elif lleno >= 0.25:
			estrella(dibujo_estrellas, centro, 9, Color("#ffcc33"))


func estrella(lienzo: CanvasItem, centro: Vector2, radio: float, color: Color) -> void:
	var puntos := PackedVector2Array()
	for k in 10:
		var r := radio if k % 2 == 0 else radio * 0.45
		var ang := -PI / 2 + k * PI / 5
		puntos.append(centro + Vector2(cos(ang), sin(ang)) * r)
	lienzo.draw_colored_polygon(puntos, color)


# =====================================================
#  LA COMPU: tienda con pestanas
# =====================================================
func crear_tienda(raiz: Control) -> void:
	panel_tienda = PanelContainer.new()
	panel_tienda.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel_tienda.offset_left = 14
	panel_tienda.offset_right = -14
	panel_tienda.offset_top = ALTO_HUD + 10
	panel_tienda.offset_bottom = -20
	panel_tienda.visible = false
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color("#16324f")            # pantalla azul de la compu
	fondo.border_color = Color("#cfcfcf")        # marco del monitor
	fondo.set_border_width_all(10)
	fondo.set_corner_radius_all(16)
	fondo.set_content_margin_all(18)
	panel_tienda.add_theme_stylebox_override("panel", fondo)
	raiz.add_child(panel_tienda)

	var columna := VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	panel_tienda.add_child(columna)

	var encabezado := HBoxContainer.new()
	columna.add_child(encabezado)
	var titulo := Label.new()
	titulo.text = "CAFE-PC  Tienda"
	titulo.add_theme_font_size_override("font_size", 28)
	encabezado.add_child(titulo)
	label_tienda_dinero = Label.new()
	label_tienda_dinero.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label_tienda_dinero.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label_tienda_dinero.add_theme_font_size_override("font_size", 28)
	label_tienda_dinero.add_theme_color_override("font_color", Color("#9cff8a"))
	encabezado.add_child(label_tienda_dinero)
	var cerrar := crear_boton(encabezado, cerrar_tienda)
	cerrar.text = "  X  "
	cerrar.custom_minimum_size = Vector2(70, 60)

	pestanas = TabContainer.new()
	pestanas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pestanas.add_theme_font_size_override("font_size", 19)
	columna.add_child(pestanas)

	# --- 0: Comprar (maquinas y mesas) ---
	var lista := nueva_pestana("Comprar")
	agregar_titulo(lista, "Máquinas de café")
	agregar_ayuda(lista, "Las baratas se gastan y se rompen más. Tocá una máquina en el local para hacerle mantenimiento o arreglarla.")
	for i in DISPENSADORAS.size():
		filas_disp.append(crear_fila(lista, tex["disp_" + DISPENSADORAS[i]["id"]],
			empezar_colocacion.bind("dispensadora", i)))
	agregar_titulo(lista, "Mesas")
	agregar_ayuda(lista, "Más asientos = más clientes sentados dejando propina.")
	for asientos in [1, 2, 3, 4]:
		filas_mesa.append(crear_fila(lista, tex["mesa"], empezar_colocacion.bind("mesa", asientos)))

	# --- 1: Local y empleados ---
	lista = nueva_pestana("Local")
	filas_local["agrandar"] = crear_fila(lista, null, agrandar_local)
	agregar_titulo(lista, "Empleados")
	filas_local["tecnico"] = crear_fila(lista, null, contratar_tecnico)
	filas_local["mozo"] = crear_fila(lista, tex["mozo"], contratar_mozo)
	agregar_titulo(lista, "Mejoras")
	filas_local["patio"] = crear_fila(lista, tex["sombrilla"], comprar_patio)
	filas_local["cartel"] = crear_fila(lista, null, comprar_cartel)

	# --- 2: Menu ---
	lista = nueva_pestana("Menú")
	agregar_ayuda(lista, "Agregá productos al menú y mejorá sus recetas para cobrar más.")
	for i in PRODUCTOS.size():
		filas_menu.append(crear_fila(lista, tex["icono_" + PRODUCTOS[i]["id"]], desbloquear_o_mejorar.bind(i)))

	# --- 3: Misiones ---
	lista = nueva_pestana("Misiones")
	label_diarias = agregar_titulo(lista, "Misiones diarias")
	for k in 3:
		filas_diarias.append(crear_fila(lista, null, reclamar_diaria.bind(k)))
	label_misiones = agregar_titulo(lista, "Misiones")
	for k in 3:
		filas_misiones.append(crear_fila(lista, null, reclamar_mision.bind(k)))

	# --- 4: Franquicia ---
	lista = nueva_pestana("Franquicia")
	agregar_titulo(lista, "Meta: Cafetería Legendaria")
	label_meta = agregar_ayuda(lista, "")
	label_granos = agregar_titulo(lista, "")
	for k in MEJORAS_ORO.size():
		filas_oro.append(crear_fila(lista, null, comprar_mejora_oro.bind(k)))
	agregar_titulo(lista, "Sucursales")
	agregar_ayuda(lista, "Cuando tu local es legendario, podés abrir una sucursal nueva: empezás de cero pero ganás granos de oro.")
	for i in SUCURSALES.size():
		filas_sucursales.append(crear_fila(lista, null, pedir_abrir_sucursal.bind(i)))

	# --- 5: Ajustes ---
	lista = nueva_pestana("Ajustes")
	btn_musica = crear_boton(lista, cambiar_musica)
	btn_sonido = crear_boton(lista, cambiar_sonido)
	btn_vibracion = crear_boton(lista, cambiar_vibracion)
	var tuto := crear_boton(lista, ver_tutorial)
	tuto.text = "Ver el tutorial de nuevo"
	lista.add_child(HSeparator.new())
	var borrar := crear_boton(lista, confirmar_borrar)
	borrar.text = "Borrar partida"
	for b in [btn_musica, btn_sonido, btn_vibracion, tuto, borrar]:
		b.custom_minimum_size = Vector2(0, 70)


func nueva_pestana(titulo: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pestanas.add_child(scroll)
	pestanas.set_tab_title(pestanas.get_tab_count() - 1, titulo)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 12)
	scroll.add_child(lista)
	return lista


func agregar_titulo(lista: VBoxContainer, s: String) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", Color("#ffe08a"))
	lista.add_child(l)
	return l


func agregar_ayuda(lista: VBoxContainer, s: String) -> Label:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", Color("#bfe0ff"))
	lista.add_child(l)
	return l


func crear_fila(lista: VBoxContainer, icono: Texture2D, accion: Callable) -> Dictionary:
	# Una fila de la tienda: [dibujo] [descripcion] [boton]
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	lista.add_child(fila)
	if icono != null:
		var dibujo := TextureRect.new()
		dibujo.texture = icono
		dibujo.custom_minimum_size = Vector2(60, 60)
		dibujo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dibujo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dibujo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fila.add_child(dibujo)
	var l := Label.new()
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 18)
	fila.add_child(l)
	var b := crear_boton(fila, accion)
	b.custom_minimum_size = Vector2(180, 72)
	b.add_theme_font_size_override("font_size", 18)
	lista.add_child(HSeparator.new())
	return {"label": l, "boton": b}


func crear_boton(padre: Node, accion: Callable) -> Button:
	var b := Button.new()
	b.pressed.connect(sonar.bind("click"))
	b.pressed.connect(accion)
	padre.add_child(b)
	return b


func abrir_tienda() -> void:
	if en_obras:
		return
	colocando = {}
	tienda_abierta_alguna_vez = true
	panel_tienda.visible = true
	sonar("compu")

func abrir_tienda_en(pestana: int) -> void:
	abrir_tienda()
	pestanas.current_tab = pestana

func cerrar_tienda() -> void:
	panel_tienda.visible = false


func confirmar_borrar() -> void:
	mostrar_mensaje("Borrar partida", "¿Seguro? Se pierde TODO el progreso, también los granos de oro y las sucursales.",
		[["No", func(): pass], ["Sí, borrar", borrar_partida]])


func configurar_boton(b: Button, s: String, se_puede: bool) -> void:
	b.text = s
	b.disabled = not se_puede or en_obras


# =====================================================
#  MENSAJES (ventanitas con botones, de a una)
# =====================================================
func crear_mensajes(tema: Theme) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 5
	add_child(capa)
	capa_mensaje = ColorRect.new()
	capa_mensaje.color = Color(0, 0, 0, 0.6)
	capa_mensaje.theme = tema
	capa_mensaje.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa_mensaje.visible = false
	capa.add_child(capa_mensaje)

	var centro := CenterContainer.new()
	centro.set_anchors_preset(Control.PRESET_FULL_RECT)
	capa_mensaje.add_child(centro)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color("#3b2a20")
	fondo.border_color = Color("#d9a066")
	fondo.set_border_width_all(4)
	fondo.set_corner_radius_all(14)
	fondo.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", fondo)
	centro.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	panel.add_child(col)
	label_msg_titulo = Label.new()
	label_msg_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_msg_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_msg_titulo.add_theme_font_size_override("font_size", 30)
	label_msg_titulo.add_theme_color_override("font_color", Color("#ffe08a"))
	col.add_child(label_msg_titulo)
	label_msg_texto = Label.new()
	label_msg_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_msg_texto.add_theme_font_size_override("font_size", 21)
	col.add_child(label_msg_texto)
	caja_botones_msg = HBoxContainer.new()
	caja_botones_msg.alignment = BoxContainer.ALIGNMENT_CENTER
	caja_botones_msg.add_theme_constant_override("separation", 16)
	col.add_child(caja_botones_msg)


func mostrar_mensaje(titulo: String, s: String, botones := []) -> void:
	# botones: [["Texto", funcion], ...]  (si no hay, aparece "OK")
	cola_mensajes.append({"titulo": titulo, "texto": s, "botones": botones})
	if not capa_mensaje.visible:
		siguiente_mensaje()


func siguiente_mensaje() -> void:
	if cola_mensajes.is_empty():
		capa_mensaje.visible = false
		return
	var m: Dictionary = cola_mensajes.pop_front()
	label_msg_titulo.text = m["titulo"]
	label_msg_texto.text = m["texto"]
	for hijo in caja_botones_msg.get_children():
		hijo.queue_free()
	var botones: Array = m["botones"]
	if botones.is_empty():
		botones = [["OK", func(): pass]]
	for par in botones:
		var b := Button.new()
		b.text = par[0]
		b.custom_minimum_size = Vector2(200, 76)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(cerrar_mensaje.bind(par[1]))
		caja_botones_msg.add_child(b)
	capa_mensaje.visible = true


func cerrar_mensaje(accion: Callable) -> void:
	sonar("click")
	capa_mensaje.visible = false
	accion.call()
	siguiente_mensaje()


# =====================================================
#  TUTORIAL (solo la primera vez)
# =====================================================
func crear_tutorial(tema: Theme) -> void:
	var capa := CanvasLayer.new()
	capa.layer = 4
	add_child(capa)
	var raiz := Control.new()
	raiz.theme = tema
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.add_child(raiz)

	panel_tutorial = PanelContainer.new()
	panel_tutorial.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel_tutorial.offset_top = -190
	panel_tutorial.offset_left = 14
	panel_tutorial.offset_right = -14
	panel_tutorial.offset_bottom = -14
	panel_tutorial.mouse_filter = Control.MOUSE_FILTER_IGNORE   # deja tocar el local de abajo
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.1, 0.2, 0.35, 0.95)
	fondo.border_color = Color("#ffe08a")
	fondo.set_border_width_all(3)
	fondo.set_corner_radius_all(14)
	fondo.set_content_margin_all(16)
	panel_tutorial.add_theme_stylebox_override("panel", fondo)
	raiz.add_child(panel_tutorial)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_tutorial.add_child(col)
	label_tutorial = Label.new()
	label_tutorial.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_tutorial.add_theme_font_size_override("font_size", 21)
	col.add_child(label_tutorial)
	btn_tutorial = Button.new()
	btn_tutorial.size_flags_horizontal = Control.SIZE_SHRINK_END
	btn_tutorial.custom_minimum_size = Vector2(200, 56)
	btn_tutorial.pressed.connect(sonar.bind("click"))
	btn_tutorial.pressed.connect(terminar_tutorial)
	col.add_child(btn_tutorial)

	# Manito que senala
	dibujo_mano = Control.new()
	dibujo_mano.set_anchors_preset(Control.PRESET_FULL_RECT)
	dibujo_mano.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dibujo_mano.draw.connect(dibujar_mano)
	raiz.add_child(dibujo_mano)


func ver_tutorial() -> void:
	tutorial_paso = 0
	cerrar_tienda()


func terminar_tutorial() -> void:
	tutorial_paso = -1
	guardar_partida()


func ir_a_paso(paso: int) -> void:
	tutorial_paso = paso
	tutorial_base = contadores.duplicate()
	if paso == 3 and dispensadoras[0] != null:
		# Gastamos la primera maquina para que se pueda practicar el mantenimiento
		dispensadoras[0]["desgaste"] = max(dispensadoras[0]["desgaste"], 0.75)
		dinero = max(dinero, costo_mantenimiento(0))


func actualizar_tutorial() -> void:
	objetivo_mano = null
	var activo := tutorial_paso >= 0 and not capa_mensaje.visible
	panel_tutorial.visible = activo
	if activo:
		label_tutorial.text = TUTORIAL[tutorial_paso]
		btn_tutorial.text = "¡A jugar!" if tutorial_paso == TUTORIAL.size() - 1 else "Saltar tutorial"
		match tutorial_paso:
			0:
				objetivo_mano = btn_compu.get_global_rect().get_center() + Vector2(0, 40)
				if panel_tienda.visible:
					ir_a_paso(1)
			1:
				if panel_tienda.visible:
					pestanas.current_tab = 0
					objetivo_mano = filas_mesa[0]["boton"].get_global_rect().get_center()
				elif colocando.get("tipo") == "mesa":
					ir_a_paso(2)
				else:
					ir_a_paso(0)
			2:
				for lugar in total_lugares_mesa():
					if colocando.get("tipo") == "mesa" and puede_colocar_mesa(lugar, colocando["valor"]):
						objetivo_mano = a_pantalla(posicion_lugar_mesa(lugar))
						break
				if not mesas.is_empty():
					ir_a_paso(3)
				elif colocando.is_empty() and not panel_tienda.visible:
					ir_a_paso(0)
			3:
				if dispensadoras[0] != null:
					objetivo_mano = a_pantalla(posicion_dispensadora(0) + Vector2(0, 10))
				if contadores.get("mantenimientos", 0) > tutorial_base.get("mantenimientos", 0) \
						or contadores.get("arreglos", 0) > tutorial_base.get("arreglos", 0):
					ir_a_paso(4)
			4:
				if not monedas.is_empty():
					objetivo_mano = a_pantalla(posicion_lugar_mesa(mesas[monedas[0]["mesa"]]["lugar"]))
				if contadores.get("limpiezas", 0) > tutorial_base.get("limpiezas", 0):
					ir_a_paso(5)
	dibujo_mano.queue_redraw()


func dibujar_mano() -> void:
	if objetivo_mano == null or tex["mano"] == null:
		return
	var t: Texture2D = tex["mano"]
	var rebote := 10.0 * absf(sin(reloj * 5.0))
	# La punta del dedo queda justo en el objetivo
	dibujo_mano.draw_texture(t, objetivo_mano + Vector2(-t.get_width() * 0.42, rebote))


# =====================================================
#  ACTUALIZAR TEXTOS DE LA INTERFAZ (cada cuadro)
# =====================================================
func actualizar_interfaz() -> void:
	label_dinero.text = "$%d" % dinero
	var extra := "  ·  HORA PICO" if hora_pico_activa() else ""
	if todas_completadas():
		extra += "  ·  Imperio"
	label_stats.text = "Día %d  ·  %s  ·  %s%s" % [dia, hora_del_dia(), suc()["nombre"], extra]
	dibujo_estrellas.queue_redraw()
	btn_cancelar.visible = not colocando.is_empty()
	aviso_compu.visible = hay_algo_para_reclamar()

	# La compu salta hasta que la abras por primera vez (o si hay premios)
	if not tienda_abierta_alguna_vez or aviso_compu.visible:
		var s := 1.0 + 0.08 * absf(sin(reloj * 4.0))
		btn_compu.scale = Vector2(s, s)
	else:
		btn_compu.scale = Vector2.ONE
	btn_compu.disabled = en_obras

	label_pista.text = pista()

	if panel_tienda.visible:
		actualizar_tienda()


func pista() -> String:
	if not colocando.is_empty():
		if colocando["tipo"] == "dispensadora":
			return "Tocá un lugar marcado del mostrador para poner la máquina %s." % DISPENSADORAS[colocando["valor"]]["nombre"]
		return "Tocá un lugar marcado para poner la mesa de %d asientos." % colocando["valor"]
	for i in LUGARES_DISPENSADORA:
		var d = dispensadoras[i]
		if d != null and d["rota"] and d["arreglando"] <= 0.0 and not tiene_tecnico:
			return "¡Se rompió una máquina! Tocala para arreglarla ($%d)." % costo_arreglo(i)
	if hora_pico_activa():
		return "¡HORA PICO! Llegan el doble de clientes."
	if lloviendo:
		return "Está lloviendo: nadie se sienta en el patio."
	for i in LUGARES_DISPENSADORA:
		var d = dispensadoras[i]
		if d != null and not d["rota"] and d["desgaste"] >= 0.6 and not tiene_tecnico:
			return "Una máquina está muy gastada: tocala para hacerle mantenimiento ($%d)." % costo_mantenimiento(i)
	if not tiene_mozo:
		for m in mesas:
			if m["sucia"]:
				return "Hay mesas sucias: tocalas para limpiarlas y juntar las propinas."
	if hay_algo_para_reclamar():
		return "¡Tenés premios para reclamar en TIENDA > Misiones!"
	if legendaria:
		return "¡Sos una Cafetería Legendaria! Abrí una sucursal en TIENDA > Franquicia."
	if not tienda_abierta_alguna_vez:
		return "Tocá la TIENDA (arriba a la derecha) para comprar máquinas y mesas."
	if reputacion < 2.0:
		return "Tu reputación está baja: más máquinas y mesas para que nadie espere."
	if es_de_noche():
		return "Se hace de noche: vienen menos clientes. Mañana es otro día."
	return "Meta: Cafetería Legendaria. Mirá cuánto te falta en TIENDA > Franquicia."


func actualizar_tienda() -> void:
	label_tienda_dinero.text = "$%d" % dinero

	# --- Comprar ---
	for i in DISPENSADORAS.size():
		var d: Dictionary = DISPENSADORAS[i]
		var fila: Dictionary = filas_disp[i]
		fila["label"].text = "%s\nFalla: %.0f%% por café (más si está gastada)\nArreglo $%d · Sirve en %.1f s" % [
			d["nombre"], d["falla"] * 100 * suc()["falla"], d["arreglo"], d["tiempo"]]
		if not hay_lugar_para_dispensadora(i):
			configurar_boton(fila["boton"], "Sin lugar", false)
		elif precio_dispensadora(i) == 0:
			configurar_boton(fila["boton"], "GRATIS\n(cupón x%d)" % cupones_premium, true)
		else:
			configurar_boton(fila["boton"], "Comprar\n$%d" % d["precio"], dinero >= d["precio"])
	for k in filas_mesa.size():
		var asientos: int = k + 1
		var fila: Dictionary = filas_mesa[k]
		fila["label"].text = "Mesa de %d asiento%s" % [asientos, "" if asientos == 1 else "s"]
		if not hay_lugar_para_mesa(asientos):
			configurar_boton(fila["boton"], "Sin lugar", false)
		else:
			configurar_boton(fila["boton"], "Comprar\n$%d" % PRECIO_MESA[asientos], dinero >= PRECIO_MESA[asientos])

	# --- Local ---
	var f: Dictionary = filas_local["agrandar"]
	if nivel_local < MAX_NIVEL_LOCAL:
		f["label"].text = "Agrandar cafetería (nivel %d a %d)\nUna fila más de mesas y un lugar más para máquinas." % [nivel_local, nivel_local + 1]
		configurar_boton(f["boton"], "Agrandar\n$%d" % costo_local(), dinero >= costo_local())
	else:
		f["label"].text = "Cafetería al tamaño máximo."
		configurar_boton(f["boton"], "Listo", false)
	actualizar_fila_mejora(filas_local["tecnico"], "Técnico\nArregla las máquinas rotas y les hace mantenimiento solo (se paga igual).",
		tiene_tecnico, nivel_local >= 2, "nivel 2", COSTO_TECNICO, "Contratado")
	actualizar_fila_mejora(filas_local["mozo"], "Mozo\nLimpia las mesas y junta las propinas solo.",
		tiene_mozo, nivel_local >= 2, "nivel 2", COSTO_MOZO, "Contratado")
	actualizar_fila_mejora(filas_local["patio"], "Patio de mesas\n%d lugares más al aire libre." % (COLUMNAS_PATIO * FILAS_PATIO),
		tiene_patio, nivel_local >= MAX_NIVEL_LOCAL, "nivel %d" % MAX_NIVEL_LOCAL, COSTO_PATIO, "Comprado")
	actualizar_fila_mejora(filas_local["cartel"], "Cartel luminoso\nLlegan 50% más clientes.",
		tiene_cartel, tiene_patio, "el patio", COSTO_CARTEL, "Comprado")

	# --- Menu ---
	for i in PRODUCTOS.size():
		var p: Dictionary = PRODUCTOS[i]
		var nivel: int = nivel_receta[p["id"]]
		var fila: Dictionary = filas_menu[i]
		if nivel == 0:
			fila["label"].text = "%s  -  $%d\n(no está en el menú)" % [p["nombre"], p["precio"]]
			if nivel_local < p["nivel_local"]:
				configurar_boton(fila["boton"], "Requiere\nnivel %d" % p["nivel_local"], false)
			else:
				configurar_boton(fila["boton"], "Agregar\n$%d" % p["desbloqueo"], dinero >= p["desbloqueo"])
		else:
			fila["label"].text = "%s  -  $%d\nReceta nivel %d" % [p["nombre"], precio_producto(i), nivel]
			if nivel >= MAX_NIVEL_RECETA:
				configurar_boton(fila["boton"], "Al máximo", false)
			else:
				configurar_boton(fila["boton"], "Mejorar\n$%d" % costo_mejorar_receta(i), dinero >= costo_mejorar_receta(i))

	# --- Misiones ---
	var horas := segundos_para_manana() / 3600
	label_diarias.text = "Misiones diarias (nuevas en %d h)" % horas
	for k in 3:
		var fila: Dictionary = filas_diarias[k]
		if k >= diarias.size():
			fila["label"].text = ""
			configurar_boton(fila["boton"], "-", false)
			continue
		var d: Dictionary = diarias[k]
		var progreso: int = min(progreso_diaria(k), d["meta"])
		fila["label"].text = "%s\n%d / %d  ·  Premio: $%d + 1 grano de oro" % [d["texto"], progreso, d["meta"], d["premio"]]
		if d["reclamada"]:
			configurar_boton(fila["boton"], "Hecha", false)
		elif progreso >= d["meta"]:
			configurar_boton(fila["boton"], "¡Reclamar!", true)
		else:
			configurar_boton(fila["boton"], "En curso", false)
	var activas := misiones_activas()
	label_misiones.text = "Misiones (%d de %d hechas)" % [misiones_hechas.size(), MISIONES.size()]
	for k in 3:
		var fila: Dictionary = filas_misiones[k]
		if k >= activas.size():
			fila["label"].text = "¡Completaste todas!" if k == 0 else ""
			configurar_boton(fila["boton"], "-", false)
			continue
		var mi: Dictionary = MISIONES[activas[k]]
		var valor: int = min(valor_para_mision(mi["tipo"]), mi["meta"])
		fila["label"].text = "%s\n%d / %d  ·  Premio: $%d" % [mi["texto"], valor, mi["meta"], mi["premio"]]
		if mision_cumplida(activas[k]):
			configurar_boton(fila["boton"], "¡Reclamar!", true)
		else:
			configurar_boton(fila["boton"], "En curso", false)

	# --- Franquicia ---
	var lineas := "Sucursal %s:\n" % suc()["nombre"]
	for c in condiciones_meta():
		lineas += ("[OK]  " if c[1] else "[  ]  ") + c[0] + "\n"
	if legendaria:
		lineas += "¡Ya es legendaria! Podés abrir otra sucursal."
	label_meta.text = lineas
	label_granos.text = "Granos de oro: %d" % granos
	for k in MEJORAS_ORO.size():
		var m: Dictionary = MEJORAS_ORO[k]
		var nivel := oro(m["id"])
		var fila: Dictionary = filas_oro[k]
		fila["label"].text = "%s (nivel %d/%d)\n%s" % [m["nombre"], nivel, m["max"], m["texto"]]
		if nivel >= m["max"]:
			configurar_boton(fila["boton"], "Al máximo", false)
		else:
			configurar_boton(fila["boton"], "Mejorar\n%d granos" % costo_mejora_oro(k), granos >= costo_mejora_oro(k))
	for i in SUCURSALES.size():
		var s: Dictionary = SUCURSALES[i]
		var fila: Dictionary = filas_sucursales[i]
		var estado := ""
		if i == sucursal:
			estado = "  (estás acá)"
		elif sucursales_completadas.has(s["id"]):
			estado = "  (completada)"
		fila["label"].text = "%s%s\n%s\nMeta: $%d" % [s["nombre"], estado, s["descripcion"], s["meta"]]
		if not legendaria:
			configurar_boton(fila["boton"], "Primero\nlegendaria", false)
		elif i == sucursal and not todas_completadas():
			configurar_boton(fila["boton"], "Estás acá", false)
		else:
			configurar_boton(fila["boton"], "Abrir\n+%d granos" % granos_a_ganar(), true)

	# --- Ajustes ---
	btn_musica.text = "Música: SÍ" if musica_on else "Música: NO"
	btn_sonido.text = "Sonidos: SÍ" if sonido_on else "Sonidos: NO"
	btn_vibracion.text = "Vibración: SÍ" if vibracion_on else "Vibración: NO"


func actualizar_fila_mejora(fila: Dictionary, s: String, comprado: bool, disponible: bool,
		requisito: String, costo: int, texto_comprado: String) -> void:
	fila["label"].text = s
	if comprado:
		configurar_boton(fila["boton"], texto_comprado, false)
	elif not disponible:
		configurar_boton(fila["boton"], "Requiere\n%s" % requisito, false)
	else:
		configurar_boton(fila["boton"], "Comprar\n$%d" % costo, dinero >= costo)
