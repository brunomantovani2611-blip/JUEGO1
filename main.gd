extends Node2D
# =====================================================
#  CAFETERIA TYCOON
#  Empiezas con un local chico y 1 caja. Vende cafe,
#  junta dinero, agranda la cafeteria, desbloquea
#  productos y mejoras, y cuida tu reputacion.
#  La partida se guarda sola.
# =====================================================

# ---------- CONFIGURACION (puedes cambiar estos numeros) ----------
const DINERO_INICIAL := 20
const PROPINA_SENTADO := 3      # extra que deja el cliente que se sienta
const VELOCIDAD_CLIENTE := 170.0
const MAX_COLA := 5             # si todas las colas estan llenas, el cliente se va
const MAX_CAJAS := 4

# Paciencia y reputacion
const PACIENCIA := 15.0         # segundos que un cliente aguanta en la fila
const REPUTACION_INICIAL := 3.0 # de 1 a 5 estrellas

# Tamano del local
const MAX_NIVEL_LOCAL := 3              # cuantas veces se puede agrandar (+1)
const COSTOS_AGRANDAR := [150, 400]     # precio de pasar a nivel 2 y a nivel 3
const MESAS_POR_COLUMNA := 4            # cada ampliacion agrega una columna de mesas
const MESAS_PATIO := 8

# Mejoras que se desbloquean
const COSTO_PATIO := 800
const COSTO_CAFETERA := 250
const COSTO_CARTEL := 1200
const TIEMPO_COBRO_NORMAL := 1.5
const TIEMPO_COBRO_ESPRESSO := 0.9

# Menu: productos que se venden
#   precio: precio base       tiempo: cuanto tarda en prepararse (x tiempo de cobro)
#   desbloqueo: lo que cuesta agregarlo al menu    nivel_local: tamano de local necesario
const PRODUCTOS := [
	{"id": "cafe",      "nombre": "Cafe",      "precio": 5,  "tiempo": 1.0, "desbloqueo": 0,   "nivel_local": 1},
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

# ---------- MAPA ----------
const ARRIBA := 90.0             # donde empieza el local (debajo de los botones)
const ABAJO := 600.0             # pared de abajo del local
const IZQUIERDA := 20.0
const ANCHO_CAJAS := 300.0       # zona de cajas (siempre igual)
const ANCHO_COLUMNA := 160.0     # cada ampliacion agrega esto de ancho
const PATIO_X := 820.0
const PATIO_ANCHO := 320.0
const CALLE_Y := 625.0           # vereda por donde camina la gente

const PUERTA_X := 170.0
const PUERTA_ADENTRO := Vector2(PUERTA_X, ABAJO - 25)
const PUERTA_AFUERA := Vector2(PUERTA_X, CALLE_Y)
const PATIO_ENTRADA_X := 980.0
const PATIO_ADENTRO := Vector2(PATIO_ENTRADA_X, ABAJO - 25)
const PATIO_AFUERA := Vector2(PATIO_ENTRADA_X, CALLE_Y)


# ---------- CLASE CLIENTE ----------
class Cliente:
	var pos: Vector2
	var estado := "cola"   # cola -> a_mesa -> sentado -> saliendo
	var camino: Array = [] # puntos por los que pasa antes de su destino
	var salida: Vector2    # por donde se va de la pantalla
	var caja := 0
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
var tiene_cafetera := false
var tiene_cartel := false
var nivel_receta := {"cafe": 1, "medialuna": 0, "jugo": 0, "torta": 0}   # 0 = bloqueado
var cajas: Array = []      # cada caja: { "cola": [], "timer": 0.0 }
var mesas: Array = []      # cada mesa: { "sillas": [false, false] }
var clientes: Array = []
var textos: Array = []     # textos flotantes "+$5"
var particulas: Array = [] # polvo de las obras
var tiempo_spawn := 1.0
var tiempo_guardado := CADA_CUANTO_GUARDAR
var no_guardar := false

# ---------- ANIMACIONES ----------
var borde_local := IZQUIERDA + ANCHO_CAJAS + ANCHO_COLUMNA   # pared derecha (se anima)
var alto_patio := 0.0       # el patio aparece de arriba hacia abajo
var en_obras := false       # true mientras dura una animacion

# ---------- DIBUJOS (carpeta res://sprites) ----------
var tex := {}
var tex_clientes: Array = []

# ---------- INTERFAZ ----------
var capa_ui: CanvasLayer
var label_dinero: Label
var label_pista: Label
var btn_caja: Button
var btn_mesa: Button
var btn_local: Button
var btn_patio: Button
var btn_cafetera: Button
var btn_cartel: Button
var panel_menu: PanelContainer
var filas_menu: Array = []   # por cada producto: { "label": Label, "boton": Button }


func _ready() -> void:
	position = Vector2.ZERO
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art nitido
	randomize()
	cargar_sprites()
	crear_interfaz()
	if not cargar_partida():
		agregar_caja()


# =====================================================
#  BUCLE PRINCIPAL
# =====================================================
func _process(delta: float) -> void:
	tiempo_spawn -= delta
	if tiempo_spawn <= 0.0:
		tiempo_spawn = intervalo_spawn()
		crear_cliente()

	actualizar_cajas(delta)
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
	# Guardar al cerrar la ventana del juego
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		guardar_partida()


func intervalo_spawn() -> float:
	# Mas cajas, mas mesas y mejor reputacion = llegan clientes mas seguido
	var atraccion := 1.0 + 0.3 * (cajas.size() - 1) + 0.12 * mesas.size()
	if tiene_cartel:
		atraccion *= 1.5
	atraccion *= reputacion / 3.0
	return max(0.35, 2.5 / atraccion)


func tiempo_cobro() -> float:
	return TIEMPO_COBRO_ESPRESSO if tiene_cafetera else TIEMPO_COBRO_NORMAL


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
			agregar_texto(Vector2(360, 330), "Nuevo en el menu: %s!" % p["nombre"], Color.YELLOW, 2.5)
	elif nivel < MAX_NIVEL_RECETA and dinero >= costo_mejorar_receta(i):
		dinero -= costo_mejorar_receta(i)
		nivel_receta[p["id"]] = nivel + 1


# =====================================================
#  CLIENTES
# =====================================================
func punto_borde_calle() -> Vector2:
	# Un punto fuera de la pantalla, a la izquierda o a la derecha
	return Vector2(-30 if randf() < 0.5 else 1182, CALLE_Y)


func crear_cliente() -> void:
	# Elegir la caja con la cola mas corta
	var mejor := 0
	for i in cajas.size():
		if cajas[i]["cola"].size() < cajas[mejor]["cola"].size():
			mejor = i

	if cajas[mejor]["cola"].size() >= MAX_COLA:
		clientes_perdidos += 1
		cambiar_reputacion(-0.05)
		agregar_texto(PUERTA_AFUERA + Vector2(-60, -40), "Cliente perdido!", Color.RED)
		return

	var c := Cliente.new()
	c.pos = Vector2(-30, CALLE_Y)   # llegan caminando por la vereda desde la izquierda
	c.camino = [PUERTA_AFUERA, PUERTA_ADENTRO]
	c.caja = mejor
	c.sprite = randi() % max(1, tex_clientes.size())
	c.producto = productos_disponibles().pick_random()
	cajas[mejor]["cola"].append(c)
	clientes.append(c)


func destino_final(c: Cliente) -> Vector2:
	match c.estado:
		"cola":
			return posicion_cola(c.caja, cajas[c.caja]["cola"].find(c))
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
			continue
		var llego_al_final: bool = llego and c.camino.is_empty()

		if c.estado == "cola" and c.camino.is_empty():
			# Adentro del local esperando: se le acaba la paciencia
			# (salvo cuando ya lo estan atendiendo en la caja)
			var atendiendolo: bool = cajas[c.caja]["cola"].find(c) == 0 and llego_al_final
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
				mesas[c.mesa]["sillas"][c.silla] = false
				irse(c)
		elif c.estado == "saliendo" and llego_al_final:
			clientes.erase(c)


func enojarse(c: Cliente) -> void:
	cajas[c.caja]["cola"].erase(c)
	c.enojado = true
	clientes_perdidos += 1
	cambiar_reputacion(-0.15)
	agregar_texto(c.pos + Vector2(-30, -50), "Me voy!", Color(1, 0.3, 0.3))
	irse(c)


func irse(c: Cliente) -> void:
	c.estado = "saliendo"
	c.salida = punto_borde_calle()
	if c.mesa >= 0 and es_mesa_patio(c.mesa):
		c.camino = [PATIO_ADENTRO, PATIO_AFUERA]
	else:
		c.camino = [PUERTA_ADENTRO, PUERTA_AFUERA]


func buscar_silla_libre(c: Cliente) -> bool:
	for m in mesas.size():
		for s in 2:
			if not mesas[m]["sillas"][s]:
				mesas[m]["sillas"][s] = true
				c.mesa = m
				c.silla = s
				return true
	return false


# =====================================================
#  CAJAS
# =====================================================
func actualizar_cajas(delta: float) -> void:
	for i in cajas.size():
		var caja: Dictionary = cajas[i]
		if caja["cola"].is_empty():
			caja["timer"] = 0.0
			continue

		var primero: Cliente = caja["cola"][0]
		if not primero.camino.is_empty() or primero.pos.distance_to(posicion_cola(i, 0)) > 3.0:
			continue  # todavia no llego a la caja

		caja["timer"] += delta
		if caja["timer"] >= tiempo_atencion(primero):
			caja["timer"] = 0.0
			caja["cola"].pop_front()
			atender(primero)


func tiempo_atencion(c: Cliente) -> float:
	return tiempo_cobro() * PRODUCTOS[c.producto]["tiempo"]


func atender(c: Cliente) -> void:
	clientes_atendidos += 1
	ganar_dinero(precio_producto(c.producto), c.pos)
	# Si lo atendieron rapido queda contento
	if c.paciencia > PACIENCIA * 0.5:
		cambiar_reputacion(0.03)
	else:
		cambiar_reputacion(0.01)
	# Si hay silla libre se sienta, si no se lleva el pedido (y le gusta menos)
	if buscar_silla_libre(c):
		c.estado = "a_mesa"
		cambiar_reputacion(0.01)
		if es_mesa_patio(c.mesa):
			# Sale por la puerta y entra al patio por afuera
			c.camino = [PUERTA_ADENTRO, PUERTA_AFUERA, PATIO_AFUERA, PATIO_ADENTRO]
	else:
		cambiar_reputacion(-0.02)
		irse(c)


func ganar_dinero(cantidad: int, donde: Vector2) -> void:
	dinero += cantidad
	agregar_texto(donde + Vector2(-10, -40), "+$%d" % cantidad, Color(0.4, 1.0, 0.4))


# =====================================================
#  COMPRAS
# =====================================================
func costo_caja() -> int:
	return 50 * int(pow(2, cajas.size() - 1))   # 50, 100, 200...

func costo_mesa() -> int:
	return 25 + 15 * mesas.size()

func costo_local() -> int:
	return COSTOS_AGRANDAR[nivel_local - 1]

func mesas_interior() -> int:
	return nivel_local * MESAS_POR_COLUMNA

func max_mesas() -> int:
	return mesas_interior() + (MESAS_PATIO if tiene_patio else 0)

func es_mesa_patio(i: int) -> bool:
	return i >= MAX_NIVEL_LOCAL * MESAS_POR_COLUMNA


func agregar_caja() -> void:
	cajas.append({"cola": [], "timer": 0.0})


func comprar_caja() -> void:
	if cajas.size() < MAX_CAJAS and dinero >= costo_caja():
		dinero -= costo_caja()
		agregar_caja()


func comprar_mesa() -> void:
	if mesas.size() < max_mesas() and dinero >= costo_mesa():
		dinero -= costo_mesa()
		mesas.append({"sillas": [false, false]})


func agrandar_local() -> void:
	if en_obras or nivel_local >= MAX_NIVEL_LOCAL or dinero < costo_local():
		return
	dinero -= costo_local()
	nivel_local += 1
	# Animacion: la pared derecha se corre hasta el nuevo tamano
	empezar_obras()
	var tw := create_tween()
	tw.tween_property(self, "borde_local", borde_para_nivel(nivel_local), 1.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(terminar_obras.bind("Cafeteria agrandada!"))


func borde_para_nivel(nivel: int) -> float:
	return IZQUIERDA + ANCHO_CAJAS + nivel * ANCHO_COLUMNA


func comprar_patio() -> void:
	if en_obras or tiene_patio or nivel_local < MAX_NIVEL_LOCAL or dinero < COSTO_PATIO:
		return
	dinero -= COSTO_PATIO
	tiene_patio = true
	# Animacion: el patio aparece de arriba hacia abajo
	empezar_obras()
	var tw := create_tween()
	tw.tween_property(self, "alto_patio", ABAJO - ARRIBA, 1.6) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_callback(terminar_obras.bind("Patio de mesas abierto!"))


func comprar_cafetera() -> void:
	if not tiene_cafetera and nivel_local >= 2 and dinero >= COSTO_CAFETERA:
		dinero -= COSTO_CAFETERA
		tiene_cafetera = true
		agregar_texto(Vector2(60, 200), "Cafetera espresso: cobras mas rapido!", Color.YELLOW, 2.5)


func comprar_cartel() -> void:
	if not tiene_cartel and tiene_patio and dinero >= COSTO_CARTEL:
		dinero -= COSTO_CARTEL
		tiene_cartel = true
		agregar_texto(Vector2(400, 300), "Cartel luminoso: llegan mas clientes!", Color.YELLOW, 2.5)


# =====================================================
#  GUARDAR Y CARGAR PARTIDA
# =====================================================
func guardar_partida() -> void:
	if no_guardar:
		return
	var datos := {
		"dinero": dinero,
		"atendidos": clientes_atendidos,
		"perdidos": clientes_perdidos,
		"reputacion": reputacion,
		"nivel_local": nivel_local,
		"patio": tiene_patio,
		"cafetera": tiene_cafetera,
		"cartel": tiene_cartel,
		"cajas": cajas.size(),
		"mesas": mesas.size(),
		"recetas": nivel_receta,
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
	tiene_cafetera = bool(datos.get("cafetera", false))
	tiene_cartel = bool(datos.get("cartel", false))
	for i in max(1, int(datos.get("cajas", 1))):
		agregar_caja()
	for i in int(datos.get("mesas", 0)):
		mesas.append({"sillas": [false, false]})
	var recetas: Dictionary = datos.get("recetas", {})
	for id in recetas:
		if nivel_receta.has(id):
			nivel_receta[id] = int(recetas[id])

	# El local y el patio aparecen ya construidos (sin animacion)
	borde_local = borde_para_nivel(nivel_local)
	alto_patio = ABAJO - ARRIBA if tiene_patio else 0.0

	# Ganancias mientras no estabas
	var segundos: float = Time.get_unix_time_from_system() - float(datos.get("hora", 0))
	if segundos > 60:
		segundos = min(segundos, MAX_HORAS_AUSENTE * 3600.0)
		var ganado := int(segundos * ingreso_por_segundo() * RENDIMIENTO_OFFLINE)
		if ganado > 0:
			dinero += ganado
			mostrar_mensaje("Bienvenido de vuelta!",
				"Mientras no estabas (%d minutos)\ntu cafeteria gano $%d" % [int(segundos / 60), ganado])
	return true


func ingreso_por_segundo() -> float:
	# Cuantos clientes por segundo se pueden atender, por lo que paga cada uno
	var llegan := 1.0 / intervalo_spawn()
	var atienden := cajas.size() / tiempo_cobro()
	return min(llegan, atienden) * precio_promedio()


func borrar_partida() -> void:
	no_guardar = true
	if FileAccess.file_exists(ARCHIVO_PARTIDA):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARCHIVO_PARTIDA))
	get_tree().reload_current_scene()


# =====================================================
#  OBRAS (animacion de construccion)
# =====================================================
func empezar_obras() -> void:
	en_obras = true

func terminar_obras(mensaje: String) -> void:
	en_obras = false
	position = Vector2.ZERO
	agregar_texto(Vector2(380, 330), mensaje, Color.YELLOW, 2.5)
	# Lluvia de polvo final
	for i in 40:
		agregar_polvo(Vector2(randf_range(IZQUIERDA, borde_local), randf_range(ARRIBA, ABAJO)))
	guardar_partida()

func agregar_polvo(donde: Vector2) -> void:
	particulas.append({
		"pos": donde,
		"vel": Vector2(randf_range(-60, 60), randf_range(-90, -20)),
		"vida": randf_range(0.5, 1.0),
		"tam": randf_range(4, 10),
	})

func actualizar_obras(delta: float) -> void:
	if en_obras:
		# El piso tiembla y sale polvo de donde se esta construyendo
		position = Vector2(randf_range(-3, 3), randf_range(-3, 3))
		for i in 3:
			if tiene_patio and alto_patio < ABAJO - ARRIBA:
				agregar_polvo(Vector2(randf_range(PATIO_X, PATIO_X + PATIO_ANCHO), ARRIBA + alto_patio))
			else:
				agregar_polvo(Vector2(borde_local, randf_range(ARRIBA, ABAJO)))
	for p in particulas.duplicate():
		p["vida"] -= delta
		p["pos"] += p["vel"] * delta
		if p["vida"] <= 0.0:
			particulas.erase(p)


# =====================================================
#  POSICIONES
# =====================================================
func posicion_caja(i: int) -> Vector2:
	return Vector2(IZQUIERDA + 50 + i * 70, ARRIBA + 38)

func posicion_cola(caja: int, lugar: int) -> Vector2:
	return posicion_caja(caja) + Vector2(0, 62 + lugar * 36)

func posicion_mesa(i: int) -> Vector2:
	var x0 := IZQUIERDA + ANCHO_CAJAS
	if es_mesa_patio(i):
		i -= MAX_NIVEL_LOCAL * MESAS_POR_COLUMNA
		x0 = PATIO_X
	var col := i / MESAS_POR_COLUMNA
	var fila := i % MESAS_POR_COLUMNA
	return Vector2(x0 + ANCHO_COLUMNA / 2 + col * ANCHO_COLUMNA, ARRIBA + 70 + fila * 115)

func posicion_silla(mesa: int, silla: int) -> Vector2:
	var lado := -45 if silla == 0 else 45
	return posicion_mesa(mesa) + Vector2(lado, 0)


# =====================================================
#  TEXTOS FLOTANTES
# =====================================================
func agregar_texto(pos: Vector2, texto: String, color: Color, vida := 1.0) -> void:
	textos.append({"pos": pos, "texto": texto, "color": color, "vida": vida})

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
	for nombre in ["caja", "mesa", "silla", "piso", "piso_mesas", "mostrador", "puerta",
			"pasto", "vereda", "piso_patio", "sombrilla"]:
		tex[nombre] = cargar("res://sprites/%s.png" % nombre)
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

func dibujar_centrado(t: Texture2D, centro: Vector2) -> void:
	draw_texture(t, centro - t.get_size() / 2)

func dibujar_zona(area: Rect2, nombre: String, color: Color) -> void:
	if tex[nombre] != null:
		draw_texture_rect(tex[nombre], area, true)   # true = repetir como baldosas
	else:
		draw_rect(area, color)


# =====================================================
#  DIBUJO
# =====================================================
func _draw() -> void:
	var fuente := ThemeDB.fallback_font
	var pared := Color("#4a2e1f")

	# ---- Exterior: pasto y vereda ----
	dibujar_zona(Rect2(-20, -20, 1200, 700), "pasto", Color("#6fa85a"))
	dibujar_zona(Rect2(-20, ABAJO + 8, 1200, 60), "vereda", Color("#b8b8b0"))
	draw_rect(Rect2(-20, -20, 1200, 94), Color(0.1, 0.07, 0.05, 0.75))   # franja oscura detras de los botones
	dibujar_reputacion(Vector2(950, 18))

	# ---- Patio ----
	if tiene_patio:
		var patio := Rect2(PATIO_X, ARRIBA, PATIO_ANCHO, alto_patio)
		dibujar_zona(patio, "piso_patio", Color("#d9a07a"))
		# Cerca blanca
		draw_rect(patio, Color.WHITE, false, 4.0)
		var y := ARRIBA
		while y < ARRIBA + alto_patio:
			draw_rect(Rect2(PATIO_X - 3, y, 6, 6), Color("#dddddd"))
			draw_rect(Rect2(PATIO_X + PATIO_ANCHO - 3, y, 6, 6), Color("#dddddd"))
			y += 30
		if alto_patio >= ABAJO - ARRIBA - 1:
			draw_rect(Rect2(PATIO_ENTRADA_X - 30, ABAJO - 3, 60, 8), Color("#d9a07a"))  # entrada
		draw_rect(Rect2(PATIO_X, ARRIBA - 22, 150, 22), Color(0, 0, 0, 0.5))
		draw_string(fuente, Vector2(PATIO_X + 8, ARRIBA - 6), "PATIO DE MESAS",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)

	# ---- Local (interior) ----
	var x_mesas := IZQUIERDA + ANCHO_CAJAS
	dibujar_zona(Rect2(IZQUIERDA, ARRIBA, ANCHO_CAJAS, ABAJO - ARRIBA), "piso", Color("#d9c09a"))
	dibujar_zona(Rect2(x_mesas, ARRIBA, borde_local - x_mesas, ABAJO - ARRIBA), "piso_mesas", Color("#cfe0c3"))
	# Paredes
	draw_rect(Rect2(IZQUIERDA - 8, ARRIBA - 8, borde_local - IZQUIERDA + 16, 8), pared)      # arriba
	draw_rect(Rect2(IZQUIERDA - 8, ARRIBA, 8, ABAJO - ARRIBA + 8), pared)                     # izquierda
	draw_rect(Rect2(borde_local, ARRIBA, 8, ABAJO - ARRIBA + 8), pared)                       # derecha
	draw_rect(Rect2(IZQUIERDA, ABAJO, PUERTA_X - 40 - IZQUIERDA, 8), pared)                   # abajo (izq. de la puerta)
	draw_rect(Rect2(PUERTA_X + 40, ABAJO, borde_local - PUERTA_X - 40, 8), pared)             # abajo (der. de la puerta)
	if tex["puerta"] != null:
		draw_texture(tex["puerta"], Vector2(PUERTA_X - 40, ABAJO - 4))
	draw_string(fuente, Vector2(x_mesas + 8, ARRIBA + 18), "Nivel %d" % nivel_local,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.2, 0.3, 0.25))

	# Mostrador
	dibujar_zona(Rect2(IZQUIERDA + 15, ARRIBA + 15, ANCHO_CAJAS - 30, 46), "mostrador", Color("#7a4b2a"))

	# Cajas
	for i in cajas.size():
		var p := posicion_caja(i)
		if tex["caja"] != null:
			dibujar_centrado(tex["caja"], p)
		else:
			draw_rect(Rect2(p - Vector2(25, 20), Vector2(50, 40)), Color("#555555"))
		draw_string(fuente, p + Vector2(-20, 36), "Caja %d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		if not cajas[i]["cola"].is_empty():
			var progreso: float = cajas[i]["timer"] / tiempo_atencion(cajas[i]["cola"][0])
			if progreso > 0.0:
				draw_rect(Rect2(p + Vector2(-25, -30), Vector2(50, 6)), Color.BLACK)
				draw_rect(Rect2(p + Vector2(-25, -30), Vector2(50 * progreso, 6)), Color.YELLOW)

	# Lugares de mesas
	for i in max_mesas():
		var p := posicion_mesa(i)
		if not lugar_visible(i, p):
			continue
		if i < mesas.size():
			dibujar_mesa(i, p)
		else:
			var area := Rect2(p - Vector2(70, 50), Vector2(140, 100))
			draw_rect(area, Color(0.2, 0.45, 0.3), false, 3.0)
			draw_string(fuente, p + Vector2(-20, 5), "Libre", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.15, 0.4, 0.25))

	# Clientes (los de mas abajo se dibujan encima)
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

	# Sombrillas del patio (encima de todo)
	if tex["sombrilla"] != null:
		for i in mesas.size():
			if es_mesa_patio(i) and lugar_visible(i, posicion_mesa(i)):
				dibujar_centrado(tex["sombrilla"], posicion_mesa(i) + Vector2(0, -8))

	# Polvo de las obras
	for p in particulas:
		draw_circle(p["pos"], p["tam"], Color(0.85, 0.8, 0.7, clamp(p["vida"], 0.0, 1.0)))

	# Textos flotantes (con sombra para que se lean)
	for t in textos:
		var col: Color = t["color"]
		col.a = clamp(t["vida"], 0.0, 1.0)
		var tam := 22 if t["texto"].length() <= 4 else 28
		draw_string(fuente, t["pos"] + Vector2(2, 2), t["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, tam, Color(0, 0, 0, col.a))
		draw_string(fuente, t["pos"], t["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, tam, col)


func dibujar_globo(c: Cliente) -> void:
	# Globito con lo que pidio + barra de paciencia (solo mientras espera adentro)
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
		draw_string(ThemeDB.fallback_font, base + Vector2(10, 23), PRODUCTOS[c.producto]["nombre"].left(1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.BLACK)
	if c.camino.is_empty():
		var resto: float = clamp(c.paciencia / PACIENCIA, 0.0, 1.0)
		var color := Color.GREEN.lerp(Color.RED, 1.0 - resto)
		draw_rect(Rect2(c.pos + Vector2(-16, -44), Vector2(32, 5)), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(c.pos + Vector2(-16, -44), Vector2(32 * resto, 5)), color)


func dibujar_reputacion(pos: Vector2) -> void:
	for i in 5:
		var centro := pos + Vector2(i * 26, 0)
		var lleno: float = clamp(reputacion - i, 0.0, 1.0)
		dibujar_estrella(centro, 11, Color(0.35, 0.35, 0.35))
		if lleno >= 0.75:
			dibujar_estrella(centro, 11, Color("#ffcc33"))
		elif lleno >= 0.25:
			dibujar_estrella(centro, 7, Color("#ffcc33"))   # media estrella (mas chica)
	draw_string(ThemeDB.fallback_font, pos + Vector2(128, 6), "%.1f" % reputacion,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)


func dibujar_estrella(centro: Vector2, radio: float, color: Color) -> void:
	var puntos := PackedVector2Array()
	for k in 10:
		var r := radio if k % 2 == 0 else radio * 0.45
		var ang := -PI / 2 + k * PI / 5
		puntos.append(centro + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(puntos, color)


func lugar_visible(i: int, p: Vector2) -> bool:
	# Solo se ve si la animacion ya "construyo" esa parte
	if es_mesa_patio(i):
		return p.y + 50 <= ARRIBA + alto_patio
	return p.x + 70 <= borde_local


func dibujar_mesa(i: int, p: Vector2) -> void:
	for s in 2:
		if tex["silla"] != null:
			dibujar_centrado(tex["silla"], posicion_silla(i, s))
		else:
			draw_circle(posicion_silla(i, s), 14, Color("#5c3317"))
	if tex["mesa"] != null:
		dibujar_centrado(tex["mesa"], p)
	else:
		draw_circle(p, 28, Color("#a0522d"))


# =====================================================
#  INTERFAZ (botones, dinero y menu)
# =====================================================
func crear_interfaz() -> void:
	capa_ui = CanvasLayer.new()
	add_child(capa_ui)

	var columna := VBoxContainer.new()
	columna.position = Vector2(10, 6)
	capa_ui.add_child(columna)

	var fila_textos := HBoxContainer.new()
	fila_textos.add_theme_constant_override("separation", 30)
	columna.add_child(fila_textos)

	label_dinero = Label.new()
	label_dinero.add_theme_font_size_override("font_size", 18)
	fila_textos.add_child(label_dinero)

	label_pista = Label.new()
	label_pista.add_theme_font_size_override("font_size", 14)
	label_pista.add_theme_color_override("font_color", Color("#ffe08a"))
	fila_textos.add_child(label_pista)

	var botones := HBoxContainer.new()
	botones.add_theme_constant_override("separation", 8)
	columna.add_child(botones)

	var btn_menu := crear_boton(botones, abrir_cerrar_menu)
	btn_menu.text = "Menu y recetas"
	btn_caja = crear_boton(botones, comprar_caja)
	btn_mesa = crear_boton(botones, comprar_mesa)
	btn_local = crear_boton(botones, agrandar_local)
	btn_cafetera = crear_boton(botones, comprar_cafetera)
	btn_patio = crear_boton(botones, comprar_patio)
	btn_cartel = crear_boton(botones, comprar_cartel)

	crear_panel_menu()


func crear_boton(padre: Node, accion: Callable) -> Button:
	var b := Button.new()
	b.pressed.connect(accion)
	padre.add_child(b)
	return b


func crear_panel_menu() -> void:
	panel_menu = PanelContainer.new()
	panel_menu.position = Vector2(300, 130)
	panel_menu.custom_minimum_size = Vector2(560, 0)
	panel_menu.visible = false
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color("#3b2a20")
	fondo.border_color = Color("#d9a066")
	fondo.set_border_width_all(3)
	fondo.set_corner_radius_all(8)
	panel_menu.add_theme_stylebox_override("panel", fondo)
	capa_ui.add_child(panel_menu)

	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 16)
	panel_menu.add_child(margen)

	var lista := VBoxContainer.new()
	lista.add_theme_constant_override("separation", 10)
	margen.add_child(lista)

	var titulo := Label.new()
	titulo.text = "MENU DE LA CAFETERIA"
	titulo.add_theme_font_size_override("font_size", 22)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lista.add_child(titulo)

	var ayuda := Label.new()
	ayuda.text = "Agrega productos al menu y mejora sus recetas para cobrar mas."
	ayuda.add_theme_font_size_override("font_size", 13)
	lista.add_child(ayuda)

	for i in PRODUCTOS.size():
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 12)
		lista.add_child(fila)

		var icono := TextureRect.new()
		icono.texture = tex["icono_" + PRODUCTOS[i]["id"]]
		icono.custom_minimum_size = Vector2(28, 28)
		icono.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fila.add_child(icono)

		var texto := Label.new()
		texto.custom_minimum_size = Vector2(250, 0)
		fila.add_child(texto)

		var boton := crear_boton(fila, desbloquear_o_mejorar.bind(i))
		boton.custom_minimum_size = Vector2(220, 0)
		filas_menu.append({"label": texto, "boton": boton})

	lista.add_child(HSeparator.new())

	var abajo := HBoxContainer.new()
	abajo.add_theme_constant_override("separation", 12)
	lista.add_child(abajo)
	var btn_borrar := crear_boton(abajo, confirmar_borrar)
	btn_borrar.text = "Borrar partida"
	var espacio := Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	abajo.add_child(espacio)
	var btn_cerrar := crear_boton(abajo, abrir_cerrar_menu)
	btn_cerrar.text = "Cerrar"


func abrir_cerrar_menu() -> void:
	panel_menu.visible = not panel_menu.visible


func confirmar_borrar() -> void:
	var dialogo := ConfirmationDialog.new()
	dialogo.title = "Borrar partida"
	dialogo.dialog_text = "Seguro? Se pierde todo el progreso."
	dialogo.ok_button_text = "Si, borrar"
	dialogo.cancel_button_text = "No"
	dialogo.confirmed.connect(borrar_partida)
	capa_ui.add_child(dialogo)
	dialogo.popup_centered()


func mostrar_mensaje(titulo: String, texto: String) -> void:
	var dialogo := AcceptDialog.new()
	dialogo.title = titulo
	dialogo.dialog_text = texto
	dialogo.ok_button_text = "Genial!"
	capa_ui.add_child(dialogo)
	dialogo.popup_centered.call_deferred()


func configurar_boton(b: Button, visible_: bool, texto: String, se_puede: bool) -> void:
	b.visible = visible_
	b.text = texto
	b.disabled = not se_puede or en_obras


func actualizar_interfaz() -> void:
	label_dinero.text = "$%d    Atendidos: %d    Perdidos: %d" % [dinero, clientes_atendidos, clientes_perdidos]

	# Cajas
	if cajas.size() >= MAX_CAJAS:
		configurar_boton(btn_caja, true, "Cajas al maximo", false)
	else:
		configurar_boton(btn_caja, true, "Comprar caja ($%d)" % costo_caja(), dinero >= costo_caja())

	# Mesas
	if mesas.size() >= max_mesas():
		configurar_boton(btn_mesa, true, "Mesas: sin espacio", false)
	else:
		configurar_boton(btn_mesa, true, "Comprar mesa ($%d)" % costo_mesa(), dinero >= costo_mesa())

	# Agrandar (desaparece cuando llega al maximo)
	if nivel_local < MAX_NIVEL_LOCAL:
		configurar_boton(btn_local, true, "Agrandar cafeteria ($%d)" % costo_local(), dinero >= costo_local())
	else:
		btn_local.visible = false

	# Mejoras que se desbloquean
	configurar_boton(btn_cafetera, nivel_local >= 2 and not tiene_cafetera,
		"Cafetera espresso ($%d)" % COSTO_CAFETERA, dinero >= COSTO_CAFETERA)
	configurar_boton(btn_patio, nivel_local >= MAX_NIVEL_LOCAL and not tiene_patio,
		"Comprar patio de mesas ($%d)" % COSTO_PATIO, dinero >= COSTO_PATIO)
	configurar_boton(btn_cartel, tiene_patio and not tiene_cartel,
		"Cartel luminoso ($%d)" % COSTO_CARTEL, dinero >= COSTO_CARTEL)

	# Pista de lo proximo que se desbloquea
	if reputacion < 2.0:
		label_pista.text = "Tu reputacion esta baja: compra cajas y mesas para que nadie espere!"
	elif nivel_local < 2:
		label_pista.text = "Proximo: agranda la cafeteria para desbloquear la Cafetera espresso"
	elif nivel_local < MAX_NIVEL_LOCAL:
		label_pista.text = "Proximo: agranda %d vez mas para desbloquear el Patio de mesas" % (MAX_NIVEL_LOCAL - nivel_local)
	elif not tiene_patio:
		label_pista.text = "Compra el patio para desbloquear el Cartel luminoso"
	else:
		label_pista.text = ""

	# Panel del menu
	if panel_menu.visible:
		for i in PRODUCTOS.size():
			var p: Dictionary = PRODUCTOS[i]
			var nivel: int = nivel_receta[p["id"]]
			var fila: Dictionary = filas_menu[i]
			if nivel == 0:
				fila["label"].text = "%s  -  $%d  (no esta en el menu)" % [p["nombre"], p["precio"]]
				if nivel_local < p["nivel_local"]:
					configurar_boton(fila["boton"], true, "Requiere local nivel %d" % p["nivel_local"], false)
				else:
					configurar_boton(fila["boton"], true, "Agregar al menu ($%d)" % p["desbloqueo"], dinero >= p["desbloqueo"])
			else:
				fila["label"].text = "%s  -  $%d  (receta nivel %d)" % [p["nombre"], precio_producto(i), nivel]
				if nivel >= MAX_NIVEL_RECETA:
					configurar_boton(fila["boton"], true, "Receta al maximo", false)
				else:
					configurar_boton(fila["boton"], true, "Mejorar receta ($%d)" % costo_mejorar_receta(i), dinero >= costo_mejorar_receta(i))
