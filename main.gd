extends Node2D
# =====================================================
#  CAFETERIA TYCOON
#  Empiezas con 1 caja. Vende cafe, junta dinero y
#  compra mas cajas, mesas y amplia el local.
# =====================================================

# ---------- CONFIGURACION (puedes cambiar estos numeros) ----------
const DINERO_INICIAL := 20
const PRECIO_CAFE := 5          # lo que paga cada cliente en la caja
const PROPINA_SENTADO := 3      # extra que deja el cliente que se sienta
const TIEMPO_COBRO := 1.5       # segundos que tarda una caja en cobrar
const VELOCIDAD_CLIENTE := 150.0
const MAX_COLA := 5             # si todas las colas estan llenas, el cliente se va
const MAX_CAJAS := 6
const MESAS_POR_NIVEL := 2      # mesas que entran por cada nivel del local
const MAX_NIVEL_LOCAL := 6      # 6 niveles x 2 = 12 mesas como maximo

# ---------- POSICIONES DEL MAPA ----------
const PUERTA := Vector2(300, 690)   # por aqui entran y salen los clientes


# ---------- CLASE CLIENTE ----------
class Cliente:
	var pos: Vector2
	var estado := "cola"   # cola -> a_mesa -> sentado -> saliendo
	var caja := 0
	var mesa := -1
	var silla := -1
	var timer := 0.0
	var color: Color


# ---------- ESTADO DEL JUEGO ----------
var dinero := DINERO_INICIAL
var clientes_atendidos := 0
var clientes_perdidos := 0
var nivel_local := 1
var cajas: Array = []      # cada caja: { "cola": [], "timer": 0.0 }
var mesas: Array = []      # cada mesa: { "sillas": [false, false] }
var clientes: Array = []
var textos: Array = []     # textos flotantes "+$5"
var tiempo_spawn := 1.0

# ---------- INTERFAZ ----------
var label_dinero: Label
var btn_caja: Button
var btn_mesa: Button
var btn_local: Button


func _ready() -> void:
	position = Vector2.ZERO   # el dibujo siempre empieza en la esquina
	randomize()
	agregar_caja()
	crear_interfaz()


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
	actualizar_interfaz()
	queue_redraw()


func intervalo_spawn() -> float:
	# Mas cajas y mas mesas = llegan clientes mas seguido
	var atraccion := 1.0 + 0.3 * (cajas.size() - 1) + 0.15 * mesas.size()
	return max(0.4, 2.5 / atraccion)


# =====================================================
#  CLIENTES
# =====================================================
func crear_cliente() -> void:
	# Elegir la caja con la cola mas corta
	var mejor := 0
	for i in cajas.size():
		if cajas[i]["cola"].size() < cajas[mejor]["cola"].size():
			mejor = i

	if cajas[mejor]["cola"].size() >= MAX_COLA:
		clientes_perdidos += 1
		agregar_texto(PUERTA + Vector2(-40, -60), "Cliente perdido!", Color.RED)
		return

	var c := Cliente.new()
	c.pos = PUERTA
	c.caja = mejor
	c.color = Color.from_hsv(randf(), 0.6, 0.9)
	cajas[mejor]["cola"].append(c)
	clientes.append(c)


func actualizar_clientes(delta: float) -> void:
	for c in clientes.duplicate():
		var objetivo: Vector2 = c.pos

		match c.estado:
			"cola":
				var lugar: int = cajas[c.caja]["cola"].find(c)
				objetivo = posicion_cola(c.caja, lugar)
			"a_mesa", "sentado":
				objetivo = posicion_silla(c.mesa, c.silla)
			"saliendo":
				objetivo = PUERTA

		c.pos = c.pos.move_toward(objetivo, VELOCIDAD_CLIENTE * delta)
		var llego: bool = c.pos.distance_to(objetivo) < 2.0

		if c.estado == "a_mesa" and llego:
			c.estado = "sentado"
			c.timer = randf_range(5.0, 9.0)
		elif c.estado == "sentado":
			c.timer -= delta
			if c.timer <= 0.0:
				ganar_dinero(PROPINA_SENTADO, c.pos)
				mesas[c.mesa]["sillas"][c.silla] = false
				c.estado = "saliendo"
		elif c.estado == "saliendo" and llego:
			clientes.erase(c)


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
		if primero.pos.distance_to(posicion_cola(i, 0)) > 3.0:
			continue  # todavia no llego a la caja

		caja["timer"] += delta
		if caja["timer"] >= TIEMPO_COBRO:
			caja["timer"] = 0.0
			caja["cola"].pop_front()
			clientes_atendidos += 1
			ganar_dinero(PRECIO_CAFE, primero.pos)
			# Si hay silla libre se sienta, si no se lleva el cafe
			if buscar_silla_libre(primero):
				primero.estado = "a_mesa"
			else:
				primero.estado = "saliendo"


func ganar_dinero(cantidad: int, donde: Vector2) -> void:
	dinero += cantidad
	agregar_texto(donde + Vector2(-10, -20), "+$%d" % cantidad, Color(0.1, 0.6, 0.1))


# =====================================================
#  COMPRAS
# =====================================================
func costo_caja() -> int:
	return 50 * int(pow(2, cajas.size() - 1))   # 50, 100, 200, 400...

func costo_mesa() -> int:
	return 25 + 15 * mesas.size()

func costo_local() -> int:
	return 150 * nivel_local

func max_mesas() -> int:
	return nivel_local * MESAS_POR_NIVEL


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


func ampliar_local() -> void:
	if nivel_local < MAX_NIVEL_LOCAL and dinero >= costo_local():
		dinero -= costo_local()
		nivel_local += 1


# =====================================================
#  POSICIONES
# =====================================================
func posicion_caja(i: int) -> Vector2:
	return Vector2(80 + i * 85, 110)

func posicion_cola(caja: int, lugar: int) -> Vector2:
	return posicion_caja(caja) + Vector2(0, 60 + lugar * 38)

func posicion_mesa(i: int) -> Vector2:
	var col := i % 3
	var fila := i / 3
	return Vector2(710 + col * 165, 140 + fila * 130)

func posicion_silla(mesa: int, silla: int) -> Vector2:
	var lado := -45 if silla == 0 else 45
	return posicion_mesa(mesa) + Vector2(lado, 0)


# =====================================================
#  TEXTOS FLOTANTES
# =====================================================
func agregar_texto(pos: Vector2, texto: String, color: Color) -> void:
	textos.append({"pos": pos, "texto": texto, "color": color, "vida": 1.0})

func actualizar_textos(delta: float) -> void:
	for t in textos.duplicate():
		t["vida"] -= delta
		t["pos"] += Vector2(0, -30 * delta)
		if t["vida"] <= 0.0:
			textos.erase(t)


# =====================================================
#  DIBUJO
# =====================================================
func _draw() -> void:
	var fuente := ThemeDB.fallback_font

	# Piso
	draw_rect(Rect2(0, 0, 1152, 648), Color("#e8d5b7"))
	# Zona de cajas
	draw_rect(Rect2(20, 70, 570, 570), Color("#d9c09a"))
	# Zona de mesas
	draw_rect(Rect2(610, 70, 530, 570), Color("#cfe0c3"))
	draw_string(fuente, Vector2(620, 92), "ZONA DE MESAS (nivel %d)" % nivel_local,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.2, 0.3, 0.2))

	# Mostrador
	draw_rect(Rect2(40, 85, 530, 50), Color("#7a4b2a"))

	# Cajas
	for i in cajas.size():
		var p := posicion_caja(i)
		draw_rect(Rect2(p - Vector2(25, 20), Vector2(50, 40)), Color("#555555"))
		draw_rect(Rect2(p - Vector2(15, 12), Vector2(30, 14)), Color("#88e088"))
		draw_string(fuente, p + Vector2(-20, 34), "Caja %d" % (i + 1),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
		# Barra de progreso del cobro
		var progreso: float = cajas[i]["timer"] / TIEMPO_COBRO
		if progreso > 0.0:
			draw_rect(Rect2(p + Vector2(-25, -32), Vector2(50, 6)), Color.BLACK)
			draw_rect(Rect2(p + Vector2(-25, -32), Vector2(50 * progreso, 6)), Color.YELLOW)

	# Espacios de mesas
	for i in MAX_NIVEL_LOCAL * MESAS_POR_NIVEL:
		var p := posicion_mesa(i)
		var area := Rect2(p - Vector2(75, 55), Vector2(150, 110))
		if i < mesas.size():
			# Mesa comprada
			draw_circle(p, 28, Color("#a0522d"))
			for s in 2:
				var color_silla := Color("#5c3317")
				if mesas[i]["sillas"][s]:
					color_silla = Color("#3a2010")
				draw_circle(posicion_silla(i, s), 14, color_silla)
		elif i < max_mesas():
			# Espacio libre para comprar mesa
			draw_rect(area, Color(0.3, 0.5, 0.3), false, 2.0)
			draw_string(fuente, p + Vector2(-35, 5), "Libre", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.3, 0.5, 0.3))
		else:
			# Espacio bloqueado (hay que ampliar el local)
			draw_rect(area, Color(0, 0, 0, 0.25))
			draw_string(fuente, p + Vector2(-45, 5), "Bloqueado", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.2, 0.2, 0.2))

	# Puerta
	draw_rect(Rect2(260, 632, 80, 16), Color("#4a2c17"))

	# Clientes
	for c in clientes:
		draw_circle(c.pos, 12, c.color)
		draw_arc(c.pos, 12, 0, TAU, 20, Color.BLACK, 1.5)

	# Textos flotantes
	for t in textos:
		var col: Color = t["color"]
		col.a = clamp(t["vida"], 0.0, 1.0)
		draw_string(fuente, t["pos"], t["texto"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, col)


# =====================================================
#  INTERFAZ (botones y dinero)
# =====================================================
func crear_interfaz() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)

	var barra := HBoxContainer.new()
	barra.position = Vector2(10, 12)
	barra.add_theme_constant_override("separation", 12)
	capa.add_child(barra)

	label_dinero = Label.new()
	label_dinero.custom_minimum_size = Vector2(330, 0)
	label_dinero.add_theme_font_size_override("font_size", 20)
	barra.add_child(label_dinero)

	btn_caja = Button.new()
	btn_caja.pressed.connect(comprar_caja)
	barra.add_child(btn_caja)

	btn_mesa = Button.new()
	btn_mesa.pressed.connect(comprar_mesa)
	barra.add_child(btn_mesa)

	btn_local = Button.new()
	btn_local.pressed.connect(ampliar_local)
	barra.add_child(btn_local)


func actualizar_interfaz() -> void:
	label_dinero.text = "$%d   Atendidos: %d   Perdidos: %d" % [dinero, clientes_atendidos, clientes_perdidos]

	if cajas.size() >= MAX_CAJAS:
		btn_caja.text = "Cajas al maximo"
		btn_caja.disabled = true
	else:
		btn_caja.text = "Comprar caja ($%d)" % costo_caja()
		btn_caja.disabled = dinero < costo_caja()

	if mesas.size() >= max_mesas():
		btn_mesa.text = "Sin espacio (amplia el local)"
		btn_mesa.disabled = true
	else:
		btn_mesa.text = "Comprar mesa ($%d)" % costo_mesa()
		btn_mesa.disabled = dinero < costo_mesa()

	if nivel_local >= MAX_NIVEL_LOCAL:
		btn_local.text = "Local al maximo"
		btn_local.disabled = true
	else:
		btn_local.text = "Ampliar local ($%d)" % costo_local()
		btn_local.disabled = dinero < costo_local()
