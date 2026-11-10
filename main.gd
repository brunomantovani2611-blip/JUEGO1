extends Node2D
# =====================================================
#  CAFETERIA TYCOON  (para celular, pantalla vertical)
#  Empiezas con un local chico y 1 dispensadora de cafe.
#  Todo se compra desde la COMPU (arriba a la derecha).
#  Las dispensadoras se rompen: tocalas para arreglarlas.
#  La partida se guarda sola.
# =====================================================

# ---------- CONFIGURACION (puedes cambiar estos numeros) ----------
const DINERO_INICIAL := 30
const PROPINA_SENTADO := 3      # extra que deja cada cliente que se sienta
const VELOCIDAD_CLIENTE := 230.0
const MAX_COLA := 5             # si todas las filas estan llenas, el cliente se va
const PACIENCIA := 15.0         # segundos que un cliente aguanta en la fila
const REPUTACION_INICIAL := 3.0 # de 1 a 5 estrellas

# Dispensadoras de cafe
#   precio: lo que cuesta          falla: chance de romperse cada vez que sirve (0.08 = 8%)
#   arreglo: lo que cuesta arreglarla       tiempo: segundos que tarda en servir
const DISPENSADORAS := [
	{"id": "basica",   "nombre": "Básica",   "precio": 60,  "falla": 0.08, "arreglo": 20,  "tiempo": 1.6},
	{"id": "estandar", "nombre": "Estándar", "precio": 220, "falla": 0.03, "arreglo": 60,  "tiempo": 1.2},
	{"id": "premium",  "nombre": "Premium",  "precio": 550, "falla": 0.01, "arreglo": 150, "tiempo": 0.9},
]
const LUGARES_DISPENSADORA := 4       # lugares en el mostrador (se habilitan agrandando)
const TIEMPO_ARREGLO := 2.5           # segundos que tarda en arreglarse
const DEVOLUCION_AL_REEMPLAZAR := 0.5 # al reemplazar una maquina te devuelven el 50%

# Mesas: precio segun la cantidad de asientos
const PRECIO_MESA := {1: 20, 2: 45, 3: 75, 4: 110}

# Tamano del local
const MAX_NIVEL_LOCAL := 3              # nivel maximo del local
const COSTOS_AGRANDAR := [150, 400]     # precio de pasar a nivel 2 y a nivel 3
const MESAS_POR_FILA := 4               # cada ampliacion agrega una fila de mesas
const COLUMNAS_PATIO := 3
const FILAS_PATIO := 3

# Mejoras que se desbloquean
const COSTO_PATIO := 800
const COSTO_CARTEL := 1200
const COSTO_TECNICO := 300

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

# Guardado
const ARCHIVO_PARTIDA := "user://partida.json"
const CADA_CUANTO_GUARDAR := 10.0
const MAX_HORAS_AUSENTE := 1.0  # ganancias offline como maximo de 1 hora
const RENDIMIENTO_OFFLINE := 0.1   # fuera del juego se gana el 10% de lo normal

# Sonido: volumen de cada efecto en decibeles (0 = normal, -10 = mas bajo)
const VOLUMEN_MUSICA := -12.0
const SONIDOS := {
	"cobro": -8.0, "propina": -12.0, "enojado": -8.0, "compra": -6.0,
	"campanita": -16.0, "obra": -4.0, "logro": -4.0, "click": -10.0,
	"rotura": -4.0, "arreglo": -6.0, "compu": -10.0,
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


# ---------- CLASE CLIENTE ----------
class Cliente:
	var pos: Vector2
	var estado := "cola"   # cola -> a_mesa -> sentado -> saliendo
	var camino: Array = [] # puntos por los que pasa antes de su destino
	var salida: Vector2    # por donde se va de la pantalla
	var disp := 0          # en la fila de que dispensadora esta
	var mesa := -1
	var silla := -1
	var timer := 0.0
	var sprite := 0
	var producto := 0      # indice en PRODUCTOS
	var paciencia := PACIENCIA
	var enojado := false


# ---------- ESTADO DEL JUEGO ----------
var dinero := DINERO_INICIAL
var clientes_atendidos := 0
var clientes_perdidos := 0
var reputacion := REPUTACION_INICIAL
var nivel_local := 1
var tiene_patio := false
var tiene_cartel := false
var tiene_tecnico := false
var nivel_receta := {"cafe": 1, "medialuna": 0, "jugo": 0, "torta": 0}   # 0 = no esta en el menu
var dispensadoras: Array = []  # un lugar por posicion del mostrador: null o { modelo, cola, timer, rota, arreglando }
var mesas: Array = []          # cada mesa: { "lugar": int, "asientos": int, "sillas": [bool...] }
var clientes: Array = []
var textos: Array = []         # textos flotantes "+$5"
var particulas: Array = []     # polvo de las obras y humo de maquinas rotas
var tiempo_spawn := 1.0
var tiempo_guardado := CADA_CUANTO_GUARDAR
var no_guardar := false
var reloj := 0.0               # para animaciones que titilan
var colocando := {}            # lo que se esta por colocar: { "tipo": "dispensadora"/"mesa", "valor": int }
var tienda_abierta_alguna_vez := false

# ---------- ANIMACIONES ----------
var borde_local := borde_para_nivel(1)   # pared de abajo del local (se anima al agrandar)
var alto_patio := 0.0       # el patio aparece de arriba hacia abajo
var en_obras := false       # true mientras dura una animacion
var origen := Vector2.ZERO  # para centrar el local en pantallas mas altas

# ---------- DIBUJOS Y SONIDOS ----------
var tex := {}
var tex_clientes: Array = []
var reproductores := {}    # nombre -> AudioStreamPlayer
var musica: AudioStreamPlayer
var musica_on := true
var sonido_on := true

# ---------- INTERFAZ ----------
var capa_ui: CanvasLayer
var label_dinero: Label
var label_stats: Label
var label_pista: Label
var dibujo_estrellas: Control
var btn_compu: Button
var btn_cancelar: Button
var panel_tienda: PanelContainer
var label_tienda_dinero: Label
var filas_disp: Array = []
var filas_mesa: Array = []
var filas_menu: Array = []
var fila_agrandar: Dictionary
var fila_tecnico: Dictionary
var fila_patio: Dictionary
var fila_cartel: Dictionary
var btn_musica: Button
var btn_sonido: Button


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art nitido
	randomize()
	configurar_pantalla()
	cargar_sprites()
	crear_audio()
	crear_interfaz()
	for i in LUGARES_DISPENSADORA:
		dispensadoras.append(null)
	if not cargar_partida():
		dispensadoras[0] = nueva_dispensadora(0)   # empiezas con una basica
	if musica_on and musica != null:
		musica.play()


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


# =====================================================
#  BUCLE PRINCIPAL
# =====================================================
func _process(delta: float) -> void:
	reloj += delta
	tiempo_spawn -= delta
	if tiempo_spawn <= 0.0:
		tiempo_spawn = intervalo_spawn()
		crear_cliente()

	actualizar_dispensadoras(delta)
	actualizar_clientes(delta)
	actualizar_textos(delta)
	actualizar_obras(delta)
	actualizar_interfaz()

	tiempo_guardado -= delta
	if tiempo_guardado <= 0.0:
		tiempo_guardado = CADA_CUANTO_GUARDAR
		guardar_partida()

	queue_redraw()


func _notification(what: int) -> void:
	# En el celular el juego se guarda al salir o al mandarlo al fondo
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		guardar_partida()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Boton "atras" de Android: cierra la tienda o cancela lo que estabas colocando
		if not colocando.is_empty():
			cancelar_colocacion()
		elif panel_tienda != null and panel_tienda.visible:
			cerrar_tienda()


func intervalo_spawn() -> float:
	# Mas maquinas, mas asientos y mejor reputacion = llegan clientes mas seguido
	var atraccion := 1.0 + 0.3 * (cantidad_dispensadoras() - 1) + 0.06 * asientos_totales()
	if tiene_cartel:
		atraccion *= 1.5
	atraccion *= reputacion / 3.0
	return max(0.35, 2.5 / atraccion)


# =====================================================
#  TOQUES EN LA PANTALLA
# =====================================================
func _unhandled_input(event: InputEvent) -> void:
	# En el celular cada toque llega como un clic del mouse
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tocar(get_local_mouse_position())


func tocar(p: Vector2) -> void:
	# Tocar una dispensadora o un lugar del mostrador
	for i in LUGARES_DISPENSADORA:
		if rect_dispensadora(i).has_point(p):
			if colocando.get("tipo") == "dispensadora":
				colocar_dispensadora(i)
			elif dispensadoras[i] != null and dispensadoras[i]["rota"]:
				arreglar(i)
			return
	# Tocar un lugar de mesa
	if colocando.get("tipo") == "mesa":
		for lugar in total_lugares_mesa():
			if lugar_mesa_habilitado(lugar) and rect_lugar_mesa(lugar).has_point(p):
				colocar_mesa(lugar)
				return


# =====================================================
#  SONIDO Y MUSICA (archivos en la carpeta res://sonidos)
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
	if ResourceLoader.exists("res://sonidos/musica.ogg"):
		musica = AudioStreamPlayer.new()
		musica.stream = load("res://sonidos/musica.ogg")
		musica.stream.loop = true
		musica.volume_db = VOLUMEN_MUSICA
		add_child(musica)


func sonar(nombre: String, variacion := 0.0) -> void:
	# variacion: cambia un poco el tono para que no suene siempre igual
	if not sonido_on or not reproductores.has(nombre):
		return
	var r: AudioStreamPlayer = reproductores[nombre]
	r.pitch_scale = 1.0 + randf_range(-variacion, variacion)
	r.play()


func cambiar_musica() -> void:
	musica_on = not musica_on
	if musica != null:
		if musica_on:
			musica.play()
		else:
			musica.stop()


func cambiar_sonido() -> void:
	sonido_on = not sonido_on


# =====================================================
#  REPUTACION
# =====================================================
func cambiar_reputacion(cuanto: float) -> void:
	reputacion = clamp(reputacion + cuanto, 1.0, 5.0)


# =====================================================
#  PRODUCTOS
# =====================================================
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
	return total / lista.size()


func desbloquear_o_mejorar(i: int) -> void:
	var p: Dictionary = PRODUCTOS[i]
	var nivel: int = nivel_receta[p["id"]]
	if nivel == 0:
		if nivel_local >= p["nivel_local"] and dinero >= p["desbloqueo"]:
			dinero -= p["desbloqueo"]
			nivel_receta[p["id"]] = 1
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
	# Un punto fuera de la pantalla, a la izquierda o a la derecha
	return Vector2(-30 if randf() < 0.5 else ANCHO_PANTALLA + 30, CALLE_Y)

func puerta_adentro() -> Vector2:
	return Vector2(CAMINO_X, borde_local - 25)

func puerta_afuera() -> Vector2:
	return Vector2(CAMINO_X, borde_local + 30)


func crear_cliente() -> void:
	# Elegir la dispensadora con la fila mas corta (las rotas se evitan)
	var mejor := -1
	for i in LUGARES_DISPENSADORA:
		if dispensadoras[i] != null and (mejor == -1 or puntaje_fila(i) < puntaje_fila(mejor)):
			mejor = i
	if mejor == -1:
		return

	if dispensadoras[mejor]["cola"].size() >= MAX_COLA:
		clientes_perdidos += 1
		cambiar_reputacion(-0.05)
		sonar("enojado", 0.1)
		agregar_texto(Vector2(CAMINO_X - 40, CALLE_ARRIBA - 20), "Cliente perdido!", Color.RED)
		return

	var c := Cliente.new()
	c.pos = Vector2(-30, CALLE_Y)   # llegan caminando por la vereda desde la izquierda
	c.camino = [Vector2(CAMINO_X, CALLE_Y), puerta_afuera(), puerta_adentro()]
	c.disp = mejor
	c.sprite = randi() % max(1, tex_clientes.size())
	c.producto = productos_disponibles().pick_random()
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
			# Adentro del local esperando: se le acaba la paciencia
			# (salvo cuando una maquina que anda ya lo esta atendiendo)
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
				ganar_dinero(PROPINA_SENTADO, c.pos)
				sonar("propina", 0.1)
				mesas[c.mesa]["sillas"][c.silla] = false
				irse(c)
		elif c.estado == "saliendo" and llego_al_final:
			clientes.erase(c)


func enojarse(c: Cliente) -> void:
	dispensadoras[c.disp]["cola"].erase(c)
	c.enojado = true
	clientes_perdidos += 1
	cambiar_reputacion(-0.15)
	sonar("enojado", 0.1)
	agregar_texto(c.pos + Vector2(-30, -50), "Me voy!", Color(1, 0.3, 0.3))
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
		for s in mesas[m]["sillas"].size():
			if not mesas[m]["sillas"][s]:
				mesas[m]["sillas"][s] = true
				c.mesa = m
				c.silla = s
				return true
	return false


func atender(c: Cliente) -> void:
	clientes_atendidos += 1
	ganar_dinero(precio_producto(c.producto), c.pos)
	sonar("cobro", 0.06)
	# Si lo atendieron rapido queda contento
	if c.paciencia > PACIENCIA * 0.5:
		cambiar_reputacion(0.03)
	else:
		cambiar_reputacion(0.01)
	# Si hay silla libre se sienta, si no se lleva el pedido (y le gusta menos)
	if buscar_silla_libre(c):
		c.estado = "a_mesa"
		cambiar_reputacion(0.01)
		if mesa_en_patio(c.mesa):
			# Sale por la puerta, baja por el caminito y entra al patio por el porton
			c.camino = [puerta_adentro(), puerta_afuera(), Vector2(CAMINO_X, PORTON_Y), Vector2(PATIO_X + 32, PORTON_Y)]
	else:
		cambiar_reputacion(-0.02)
		irse(c)


func ganar_dinero(cantidad: int, donde: Vector2) -> void:
	dinero += cantidad
	agregar_texto(donde + Vector2(-10, -40), "+$%d" % cantidad, Color(0.4, 1.0, 0.4))


# =====================================================
#  DISPENSADORAS (se rompen y se arreglan)
# =====================================================
func nueva_dispensadora(modelo: int) -> Dictionary:
	return {"modelo": modelo, "cola": [], "timer": 0.0, "rota": false, "arreglando": 0.0}

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

func tiempo_atencion(i: int, c: Cliente) -> float:
	return DISPENSADORAS[dispensadoras[i]["modelo"]]["tiempo"] * PRODUCTOS[c.producto]["tiempo"]


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
				sonar("compra")
				agregar_texto(posicion_dispensadora(i) + Vector2(-45, 100), "Arreglada!", Color(0.5, 0.9, 1.0))
			continue

		# Esta rota: sale humo y no atiende
		if d["rota"]:
			if randf() < delta * 5:
				agregar_particula(posicion_dispensadora(i) + Vector2(randf_range(-12, 12), -20), Color(0.35, 0.35, 0.35))
			if tiene_tecnico and dinero >= costo_arreglo(i):
				arreglar(i)
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
			# Cada vez que sirve puede romperse (las baratas mas seguido)
			if randf() < DISPENSADORAS[d["modelo"]]["falla"]:
				romper(i)


func romper(i: int) -> void:
	dispensadoras[i]["rota"] = true
	sonar("rotura")
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
	sonar("arreglo")


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
	var precio: int = DISPENSADORAS[modelo]["precio"]
	if not puede_colocar_dispensadora(i, modelo) or dinero < precio:
		return
	dinero -= precio
	var vieja = dispensadoras[i]
	if vieja == null:
		dispensadoras[i] = nueva_dispensadora(modelo)
	else:
		# Reemplazo: te devuelven parte de lo que costo la vieja y la fila se queda
		var devolucion := int(DISPENSADORAS[vieja["modelo"]]["precio"] * DEVOLUCION_AL_REEMPLAZAR)
		dinero += devolucion
		agregar_texto(posicion_dispensadora(i) + Vector2(-40, -60), "+$%d" % devolucion, Color(0.4, 1.0, 0.4))
		vieja["modelo"] = modelo
		vieja["rota"] = false
		vieja["arreglando"] = 0.0
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

func colocar_mesa(lugar: int) -> void:
	var asientos: int = colocando["valor"]
	var precio: int = PRECIO_MESA[asientos]
	if not puede_colocar_mesa(lugar, asientos) or dinero < precio:
		return
	dinero -= precio
	var sillas := []
	for s in asientos:
		sillas.append(false)
	var m := mesa_en_lugar(lugar)
	if m == -1:
		mesas.append({"lugar": lugar, "asientos": asientos, "sillas": sillas})
	else:
		var devolucion := int(PRECIO_MESA[mesas[m]["asientos"]] * DEVOLUCION_AL_REEMPLAZAR)
		dinero += devolucion
		mesas[m]["asientos"] = asientos
		mesas[m]["sillas"] = sillas
	sonar("compra", 0.05)
	for k in 15:
		agregar_particula(posicion_lugar_mesa(lugar), Color(1, 0.9, 0.5))
	colocando = {}


# ---- Local y mejoras ----
func agrandar_local() -> void:
	if en_obras or nivel_local >= MAX_NIVEL_LOCAL or dinero < costo_local():
		return
	dinero -= costo_local()
	nivel_local += 1
	cerrar_tienda()
	sonar("obra")
	# Animacion: la pared de abajo se corre hasta el nuevo tamano
	empezar_obras()
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
	# Animacion: el patio aparece de arriba hacia abajo
	empezar_obras()
	var tw := create_tween()
	tw.tween_property(self, "alto_patio", PATIO_ALTO, 1.6) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(terminar_obras.bind("Patio de mesas abierto!"))


func contratar_tecnico() -> void:
	if not tiene_tecnico and nivel_local >= 2 and dinero >= COSTO_TECNICO:
		dinero -= COSTO_TECNICO
		tiene_tecnico = true
		sonar("logro")


func comprar_cartel() -> void:
	if not tiene_cartel and tiene_patio and dinero >= COSTO_CARTEL:
		dinero -= COSTO_CARTEL
		tiene_cartel = true
		sonar("logro")


# =====================================================
#  GUARDAR Y CARGAR PARTIDA
# =====================================================
func guardar_partida() -> void:
	if no_guardar:
		return
	var lista_disp := []
	for d in dispensadoras:
		lista_disp.append(null if d == null else {"modelo": d["modelo"], "rota": d["rota"]})
	var lista_mesas := []
	for m in mesas:
		lista_mesas.append({"lugar": m["lugar"], "asientos": m["asientos"]})
	var datos := {
		"version": 2,
		"dinero": dinero,
		"atendidos": clientes_atendidos,
		"perdidos": clientes_perdidos,
		"reputacion": reputacion,
		"nivel_local": nivel_local,
		"patio": tiene_patio,
		"cartel": tiene_cartel,
		"tecnico": tiene_tecnico,
		"dispensadoras": lista_disp,
		"mesas": lista_mesas,
		"recetas": nivel_receta,
		"musica": musica_on,
		"sonido": sonido_on,
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

	dinero = int(datos.get("dinero", DINERO_INICIAL))
	clientes_atendidos = int(datos.get("atendidos", 0))
	clientes_perdidos = int(datos.get("perdidos", 0))
	reputacion = float(datos.get("reputacion", REPUTACION_INICIAL))
	nivel_local = int(datos.get("nivel_local", 1))
	tiene_patio = bool(datos.get("patio", false))
	tiene_cartel = bool(datos.get("cartel", false))
	tiene_tecnico = bool(datos.get("tecnico", false))
	musica_on = bool(datos.get("musica", true))
	sonido_on = bool(datos.get("sonido", true))
	tienda_abierta_alguna_vez = bool(datos.get("tienda_vista", false))
	var recetas: Dictionary = datos.get("recetas", {})
	for id in recetas:
		if nivel_receta.has(id):
			nivel_receta[id] = int(recetas[id])

	if datos.has("dispensadoras"):
		var lista: Array = datos["dispensadoras"]
		for i in min(lista.size(), LUGARES_DISPENSADORA):
			if lista[i] != null:
				dispensadoras[i] = nueva_dispensadora(int(lista[i]["modelo"]))
				dispensadoras[i]["rota"] = bool(lista[i]["rota"])
		for m in datos.get("mesas", []):
			agregar_mesa_cargada(int(m["lugar"]), int(m["asientos"]))
	else:
		# Partida de la version anterior (con cajas): se pasa a dispensadoras basicas
		for i in clamp(int(datos.get("cajas", 1)), 1, lugares_dispensadora_habilitados()):
			dispensadoras[i] = nueva_dispensadora(0)
		for i in int(datos.get("mesas", 0)):
			agregar_mesa_cargada(i, 2)
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
			sonar("logro")
			mostrar_mensaje("Bienvenido de vuelta!",
				"Mientras no estabas (%d minutos)\ntu cafetería ganó $%d" % [int(segundos / 60), ganado])
	return true


func agregar_mesa_cargada(lugar: int, asientos: int) -> void:
	if lugar < total_lugares_mesa() and mesa_en_lugar(lugar) == -1:
		var sillas := []
		for s in clamp(asientos, 1, 4):
			sillas.append(false)
		mesas.append({"lugar": lugar, "asientos": sillas.size(), "sillas": sillas})


func ingreso_por_segundo() -> float:
	# Cuantos clientes por segundo se pueden atender, por lo que paga cada uno
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
func empezar_obras() -> void:
	en_obras = true

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

func actualizar_obras(delta: float) -> void:
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
func agregar_texto(pos: Vector2, s: String, color: Color, vida := 1.0) -> void:
	textos.append({"pos": pos, "texto": s, "color": color, "vida": vida})

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
	for nombre in ["mesa", "silla", "piso", "piso_mesas", "mostrador", "puerta",
			"pasto", "vereda", "piso_patio", "sombrilla", "compu"]:
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

func dibujar_zona(area: Rect2, nombre: String, color: Color) -> void:
	if tex[nombre] != null:
		draw_texture_rect(tex[nombre], area, true)   # true = repetir como baldosas
	else:
		draw_rect(area, color)

func texto(pos: Vector2, s: String, tam: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, tam, color)

func texto_centrado(centro: Vector2, s: String, tam: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, centro + Vector2(-100, tam * 0.35), s, HORIZONTAL_ALIGNMENT_CENTER, 200, tam, color)


# =====================================================
#  DIBUJO DEL LOCAL
# =====================================================
func _draw() -> void:
	var pared := Color("#4a2e1f")
	var titila := 0.5 + 0.5 * sin(reloj * 6.0)

	# ---- Exterior: pasto, vereda y caminito a la puerta ----
	dibujar_zona(Rect2(-20, -800, ANCHO_PANTALLA + 40, 2900), "pasto", Color("#6fa85a"))
	dibujar_zona(Rect2(-20, CALLE_ARRIBA, ANCHO_PANTALLA + 40, 800), "vereda", Color("#b8b8b0"))
	dibujar_zona(Rect2(CAMINO_X - 35, borde_local, 70, CALLE_ARRIBA - borde_local), "vereda", Color("#b8b8b0"))

	# ---- Patio ----
	if tiene_patio:
		var patio := Rect2(PATIO_X, PATIO_Y, PATIO_ANCHO, alto_patio)
		dibujar_zona(patio, "piso_patio", Color("#d9a07a"))
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
	dibujar_zona(Rect2(IZQUIERDA, ARRIBA, DERECHA - IZQUIERDA, y_mesas - ARRIBA), "piso", Color("#d9c09a"))
	dibujar_zona(Rect2(IZQUIERDA, y_mesas, DERECHA - IZQUIERDA, borde_local - y_mesas), "piso_mesas", Color("#cfe0c3"))
	# Paredes
	draw_rect(Rect2(IZQUIERDA - 8, ARRIBA - 8, DERECHA - IZQUIERDA + 16, 8), pared)                # arriba
	draw_rect(Rect2(IZQUIERDA - 8, ARRIBA, 8, borde_local - ARRIBA + 8), pared)                     # izquierda
	draw_rect(Rect2(DERECHA, ARRIBA, 8, borde_local - ARRIBA + 8), pared)                           # derecha
	draw_rect(Rect2(IZQUIERDA, borde_local, CAMINO_X - 40 - IZQUIERDA, 8), pared)                   # abajo (izq. de la puerta)
	draw_rect(Rect2(CAMINO_X + 40, borde_local, DERECHA - CAMINO_X - 40, 8), pared)                 # abajo (der. de la puerta)
	if tex["puerta"] != null:
		draw_texture(tex["puerta"], Vector2(CAMINO_X - 40, borde_local - 4))
	texto(Vector2(IZQUIERDA + 8, y_mesas + 20), "Nivel %d" % nivel_local, 16, Color(0.2, 0.3, 0.25))

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

	# ---- Clientes (los de mas abajo se dibujan encima) ----
	var ordenados := clientes.duplicate()
	ordenados.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for c in ordenados:
		var tinte := Color(1, 0.55, 0.55) if c.enojado else Color.WHITE
		if tex_clientes.size() > 0:
			var t: Texture2D = tex_clientes[c.sprite]
			draw_texture(t, c.pos - Vector2(t.get_width() / 2.0, t.get_height() - 12), tinte)
		else:
			draw_circle(c.pos, 12, Color.CORNFLOWER_BLUE * tinte)
	for c in ordenados:
		dibujar_globo(c)

	# ---- Avisos de maquinas rotas (encima de los clientes) ----
	for i in LUGARES_DISPENSADORA:
		dibujar_aviso_rota(i, titila)

	# ---- Sombrillas del patio (encima de todo) ----
	if tex["sombrilla"] != null:
		for m in mesas.size():
			if mesa_en_patio(m) and lugar_visible(mesas[m]["lugar"]):
				dibujar_centrado(tex["sombrilla"], posicion_lugar_mesa(mesas[m]["lugar"]) + Vector2(0, -8))

	# ---- Particulas ----
	for p in particulas:
		var col: Color = p["color"]
		col.a = clamp(p["vida"], 0.0, 1.0)
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
		# Lugar bloqueado: hay que agrandar el local
		draw_rect(rect.grow(-14), Color(0, 0, 0, 0.35))
		texto_centrado(p, "Nivel %d" % i, 16, Color(0.9, 0.9, 0.9))
	elif d == null:
		# Lugar libre
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
		texto_centrado(p + Vector2(0, 40), modelo["nombre"], 14, Color.WHITE)

		if not d["rota"] and not d["cola"].is_empty():
			var progreso: float = d["timer"] / tiempo_atencion(i, d["cola"][0])
			if progreso > 0.0:
				draw_rect(Rect2(p + Vector2(-30, -40), Vector2(60, 8)), Color.BLACK)
				draw_rect(Rect2(p + Vector2(-30, -40), Vector2(60 * progreso, 8)), Color.YELLOW)

	# Lugar donde se puede poner la maquina que estas colocando
	if colocando.get("tipo") == "dispensadora" and puede_colocar_dispensadora(i, colocando["valor"]):
		draw_rect(rect, Color(1, 0.85, 0.2, 0.2 + 0.3 * titila))
		draw_rect(rect, Color(1, 0.85, 0.2), false, 4.0)


func dibujar_aviso_rota(i: int, titila: float) -> void:
	var d = dispensadoras[i]
	if d == null or not d["rota"]:
		return
	var p := posicion_dispensadora(i)
	if d["arreglando"] > 0.0:
		# Barra de arreglo
		var avance: float = 1.0 - d["arreglando"] / TIEMPO_ARREGLO
		var barra := Rect2(p + Vector2(-50, 24), Vector2(100, 26))
		draw_rect(barra, Color(0.05, 0.1, 0.2, 0.95))
		draw_rect(Rect2(barra.position, Vector2(barra.size.x * avance, barra.size.y)), Color(0.2, 0.55, 0.9))
		texto_centrado(barra.get_center(), "Arreglando...", 14, Color.WHITE)
	else:
		# Cartel rojo de "toca para arreglar"
		var escala := 1.0 + 0.1 * titila
		draw_circle(p + Vector2(32, -26), 13 * escala, Color(0.85, 0.15, 0.1))
		texto_centrado(p + Vector2(32, -26), "!", 22, Color.WHITE)
		var cartel := Rect2(p + Vector2(-56, 24), Vector2(112, 28))
		draw_rect(cartel, Color(0.8, 0.1, 0.1, 0.95))
		draw_rect(cartel, Color(1, 0.85, 0.2, titila), false, 2.0)
		texto_centrado(cartel.get_center(), "Arreglar $%d" % costo_arreglo(i), 15, Color.WHITE)


func dibujar_globo(c: Cliente) -> void:
	# Globito con lo que pidio + barra de paciencia (solo mientras espera)
	if c.estado != "cola":
		return
	var base := c.pos + Vector2(14, -58)
	draw_rect(Rect2(base, Vector2(34, 32)), Color.WHITE)
	draw_rect(Rect2(base, Vector2(34, 32)), Color(0.2, 0.2, 0.2), false, 2.0)
	draw_colored_polygon(PackedVector2Array([base + Vector2(4, 32), base + Vector2(12, 32), base + Vector2(2, 40)]), Color.WHITE)
	var icono: Texture2D = tex["icono_" + PRODUCTOS[c.producto]["id"]]
	if icono != null:
		draw_texture(icono, base + Vector2(3, 2))
	else:
		texto(base + Vector2(10, 23), PRODUCTOS[c.producto]["nombre"].left(1), 18, Color.BLACK)
	if c.camino.is_empty():
		var resto: float = clamp(c.paciencia / PACIENCIA, 0.0, 1.0)
		var color := Color.GREEN.lerp(Color.RED, 1.0 - resto)
		draw_rect(Rect2(c.pos + Vector2(-16, -44), Vector2(32, 5)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(c.pos + Vector2(-16, -44), Vector2(32 * resto, 5)), color)


func lugar_visible(lugar: int) -> bool:
	# Solo se ve si la animacion ya "construyo" esa parte
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


# =====================================================
#  INTERFAZ: barra de arriba y boton de la compu
# =====================================================
func crear_interfaz() -> void:
	capa_ui = CanvasLayer.new()
	add_child(capa_ui)

	# Tema: letras grandes para el celular
	var tema := Theme.new()
	tema.default_font_size = 22
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
	dibujo_estrellas.size = Vector2(200, 30)
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


func dibujar_estrellas() -> void:
	for i in 5:
		var centro := Vector2(14 + i * 34, 15)
		var lleno: float = clamp(reputacion - i, 0.0, 1.0)
		estrella(dibujo_estrellas, centro, 15, Color(0.35, 0.35, 0.35))
		if lleno >= 0.75:
			estrella(dibujo_estrellas, centro, 15, Color("#ffcc33"))
		elif lleno >= 0.25:
			estrella(dibujo_estrellas, centro, 9, Color("#ffcc33"))   # media estrella (mas chica)


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

	# Encabezado
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

	var pestanas := TabContainer.new()
	pestanas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pestanas.add_theme_font_size_override("font_size", 21)
	columna.add_child(pestanas)

	# --- Maquinas ---
	var lista := nueva_pestana(pestanas, "Máquinas")
	agregar_ayuda(lista, "Las baratas se rompen más seguido. Tocá una máquina rota en el local para arreglarla.")
	for i in DISPENSADORAS.size():
		filas_disp.append(crear_fila(lista, tex["disp_" + DISPENSADORAS[i]["id"]],
			empezar_colocacion.bind("dispensadora", i)))

	# --- Mesas ---
	lista = nueva_pestana(pestanas, "Mesas")
	agregar_ayuda(lista, "Más asientos = más clientes sentados dejando propina.")
	for asientos in [1, 2, 3, 4]:
		filas_mesa.append(crear_fila(lista, tex["mesa"], empezar_colocacion.bind("mesa", asientos)))

	# --- Local ---
	lista = nueva_pestana(pestanas, "Local")
	fila_agrandar = crear_fila(lista, null, agrandar_local)
	fila_tecnico = crear_fila(lista, null, contratar_tecnico)
	fila_patio = crear_fila(lista, tex["sombrilla"], comprar_patio)
	fila_cartel = crear_fila(lista, null, comprar_cartel)

	# --- Menu ---
	lista = nueva_pestana(pestanas, "Menú")
	agregar_ayuda(lista, "Agregá productos al menú y mejorá sus recetas para cobrar más.")
	for i in PRODUCTOS.size():
		filas_menu.append(crear_fila(lista, tex["icono_" + PRODUCTOS[i]["id"]], desbloquear_o_mejorar.bind(i)))

	# --- Ajustes ---
	lista = nueva_pestana(pestanas, "Ajustes")
	btn_musica = crear_boton(lista, cambiar_musica)
	btn_musica.custom_minimum_size = Vector2(0, 70)
	btn_sonido = crear_boton(lista, cambiar_sonido)
	btn_sonido.custom_minimum_size = Vector2(0, 70)
	lista.add_child(HSeparator.new())
	var borrar := crear_boton(lista, confirmar_borrar)
	borrar.text = "Borrar partida"
	borrar.custom_minimum_size = Vector2(0, 70)


func nueva_pestana(pestanas: TabContainer, titulo: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pestanas.add_child(scroll)
	pestanas.set_tab_title(pestanas.get_tab_count() - 1, titulo)
	var lista := VBoxContainer.new()
	lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lista.add_theme_constant_override("separation", 14)
	scroll.add_child(lista)
	return lista


func agregar_ayuda(lista: VBoxContainer, s: String) -> void:
	var l := Label.new()
	l.text = s
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color("#bfe0ff"))
	lista.add_child(l)


func crear_fila(lista: VBoxContainer, icono: Texture2D, accion: Callable) -> Dictionary:
	# Una fila de la tienda: [dibujo] [descripcion] [boton]
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	lista.add_child(fila)
	var dibujo := TextureRect.new()
	dibujo.texture = icono
	dibujo.custom_minimum_size = Vector2(64, 64)
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
	b.custom_minimum_size = Vector2(190, 76)
	b.add_theme_font_size_override("font_size", 19)
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

func cerrar_tienda() -> void:
	panel_tienda.visible = false


func confirmar_borrar() -> void:
	var dialogo := ConfirmationDialog.new()
	dialogo.title = "Borrar partida"
	dialogo.dialog_text = "¿Seguro? Se pierde todo el progreso."
	dialogo.ok_button_text = "Sí, borrar"
	dialogo.cancel_button_text = "No"
	dialogo.confirmed.connect(borrar_partida)
	capa_ui.add_child(dialogo)
	dialogo.popup_centered()


func mostrar_mensaje(titulo: String, s: String) -> void:
	var dialogo := AcceptDialog.new()
	dialogo.title = titulo
	dialogo.dialog_text = s
	dialogo.ok_button_text = "Genial!"
	capa_ui.add_child(dialogo)
	dialogo.popup_centered.call_deferred()


func configurar_boton(b: Button, s: String, se_puede: bool) -> void:
	b.text = s
	b.disabled = not se_puede or en_obras


# =====================================================
#  ACTUALIZAR TEXTOS DE LA INTERFAZ (cada cuadro)
# =====================================================
func actualizar_interfaz() -> void:
	label_dinero.text = "$%d" % dinero
	label_stats.text = "%.1f    Atendidos %d  ·  Perdidos %d" % [reputacion, clientes_atendidos, clientes_perdidos]
	dibujo_estrellas.queue_redraw()
	btn_cancelar.visible = not colocando.is_empty()

	# La compu salta hasta que la abras por primera vez
	if not tienda_abierta_alguna_vez:
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
	if not tienda_abierta_alguna_vez:
		return "Tocá la TIENDA (arriba a la derecha) para comprar máquinas y mesas."
	if reputacion < 2.0:
		return "Tu reputación está baja: más máquinas y mesas para que nadie espere."
	if mesas.is_empty():
		return "Comprá mesas en la tienda: los que se sientan dejan propina."
	if nivel_local < 2:
		return "Agrandá el local para habilitar otra máquina y contratar un técnico."
	if nivel_local < MAX_NIVEL_LOCAL:
		return "Agrandá 1 vez más para desbloquear el Patio de mesas."
	if not tiene_patio:
		return "Comprá el patio para desbloquear el Cartel luminoso."
	return ""


func actualizar_tienda() -> void:
	label_tienda_dinero.text = "$%d" % dinero

	# Maquinas
	for i in DISPENSADORAS.size():
		var d: Dictionary = DISPENSADORAS[i]
		var fila: Dictionary = filas_disp[i]
		fila["label"].text = "Máquina %s\nFalla: %d%% por café\nArreglo: $%d  ·  Sirve en %.1f s" % [
			d["nombre"], int(d["falla"] * 100), d["arreglo"], d["tiempo"]]
		if not hay_lugar_para_dispensadora(i):
			configurar_boton(fila["boton"], "Sin lugar", false)
		else:
			configurar_boton(fila["boton"], "Comprar\n$%d" % d["precio"], dinero >= d["precio"])

	# Mesas
	for k in filas_mesa.size():
		var asientos: int = k + 1
		var fila: Dictionary = filas_mesa[k]
		fila["label"].text = "Mesa de %d asiento%s" % [asientos, "" if asientos == 1 else "s"]
		if not hay_lugar_para_mesa(asientos):
			configurar_boton(fila["boton"], "Sin lugar", false)
		else:
			configurar_boton(fila["boton"], "Comprar\n$%d" % PRECIO_MESA[asientos], dinero >= PRECIO_MESA[asientos])

	# Local
	if nivel_local < MAX_NIVEL_LOCAL:
		fila_agrandar["label"].text = "Agrandar cafetería (nivel %d a %d)\nUna fila más de mesas y un lugar más para máquinas." % [nivel_local, nivel_local + 1]
		configurar_boton(fila_agrandar["boton"], "Agrandar\n$%d" % costo_local(), dinero >= costo_local())
	else:
		fila_agrandar["label"].text = "Cafetería al tamaño máximo."
		configurar_boton(fila_agrandar["boton"], "Listo", false)

	fila_tecnico["label"].text = "Contratar técnico\nArregla solo las máquinas rotas (el arreglo se paga igual)."
	if tiene_tecnico:
		configurar_boton(fila_tecnico["boton"], "Contratado", false)
	elif nivel_local < 2:
		configurar_boton(fila_tecnico["boton"], "Requiere\nnivel 2", false)
	else:
		configurar_boton(fila_tecnico["boton"], "Contratar\n$%d" % COSTO_TECNICO, dinero >= COSTO_TECNICO)

	fila_patio["label"].text = "Patio de mesas\n%d lugares más para mesas al aire libre." % (COLUMNAS_PATIO * FILAS_PATIO)
	if tiene_patio:
		configurar_boton(fila_patio["boton"], "Comprado", false)
	elif nivel_local < MAX_NIVEL_LOCAL:
		configurar_boton(fila_patio["boton"], "Requiere\nnivel %d" % MAX_NIVEL_LOCAL, false)
	else:
		configurar_boton(fila_patio["boton"], "Comprar\n$%d" % COSTO_PATIO, dinero >= COSTO_PATIO)

	fila_cartel["label"].text = "Cartel luminoso\nLlegan 50% más clientes."
	if tiene_cartel:
		configurar_boton(fila_cartel["boton"], "Comprado", false)
	elif not tiene_patio:
		configurar_boton(fila_cartel["boton"], "Requiere\nel patio", false)
	else:
		configurar_boton(fila_cartel["boton"], "Comprar\n$%d" % COSTO_CARTEL, dinero >= COSTO_CARTEL)

	# Menu
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

	# Ajustes
	btn_musica.text = "Música: SÍ" if musica_on else "Música: NO"
	btn_sonido.text = "Sonidos: SÍ" if sonido_on else "Sonidos: NO"
