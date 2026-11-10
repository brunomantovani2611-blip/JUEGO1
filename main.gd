extends Node2D
# =====================================================
#  CAFETERIA TYCOON
#  Empiezas con un local chico y 1 caja. Vende cafe,
#  junta dinero, agranda la cafeteria y desbloquea
#  mejoras como el patio de mesas.
# =====================================================

# ---------- CONFIGURACION (puedes cambiar estos numeros) ----------
const DINERO_INICIAL := 20
const PRECIO_CAFE := 5          # lo que paga cada cliente en la caja
const PROPINA_SENTADO := 3      # extra que deja el cliente que se sienta
const VELOCIDAD_CLIENTE := 170.0
const MAX_COLA := 5             # si todas las colas estan llenas, el cliente se va
const MAX_CAJAS := 4

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


# ---------- ESTADO DEL JUEGO ----------
var dinero := DINERO_INICIAL
var clientes_atendidos := 0
var clientes_perdidos := 0
var nivel_local := 1
var tiene_patio := false
var tiene_cafetera := false
var tiene_cartel := false
var cajas: Array = []      # cada caja: { "cola": [], "timer": 0.0 }
var mesas: Array = []      # cada mesa: { "sillas": [false, false] }
var clientes: Array = []
var textos: Array = []     # textos flotantes "+$5"
var particulas: Array = [] # polvo de las obras
var tiempo_spawn := 1.0

# ---------- ANIMACIONES ----------
var borde_local := IZQUIERDA + ANCHO_CAJAS + ANCHO_COLUMNA   # pared derecha (se anima)
var alto_patio := 0.0       # el patio aparece de arriba hacia abajo
var en_obras := false       # true mientras dura una animacion
var temblor := 0.0

# ---------- DIBUJOS (carpeta res://sprites) ----------
var tex := {}
var tex_clientes: Array = []

# ---------- INTERFAZ ----------
var label_dinero: Label
var label_pista: Label
var btn_caja: Button
var btn_mesa: Button
var btn_local: Button
var btn_patio: Button
var btn_cafetera: Button
var btn_cartel: Button


func _ready() -> void:
	position = Vector2.ZERO
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # pixel art nitido
	randomize()
	cargar_sprites()
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
	actualizar_obras(delta)
	actualizar_interfaz()
	queue_redraw()


func intervalo_spawn() -> float:
	# Mas cajas y mas mesas = llegan clientes mas seguido
	var atraccion := 1.0 + 0.3 * (cajas.size() - 1) + 0.12 * mesas.size()
	if tiene_cartel:
		atraccion *= 1.5
	return max(0.35, 2.5 / atraccion)


func tiempo_cobro() -> float:
	return TIEMPO_COBRO_ESPRESSO if tiene_cafetera else TIEMPO_COBRO_NORMAL


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
		agregar_texto(PUERTA_AFUERA + Vector2(-60, -40), "Cliente perdido!", Color.RED)
		return

	var c := Cliente.new()
	c.pos = Vector2(-30, CALLE_Y)   # llegan caminando por la vereda desde la izquierda
	c.camino = [PUERTA_AFUERA, PUERTA_ADENTRO]
	c.caja = mejor
	c.sprite = randi() % max(1, tex_clientes.size())
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

		if c.estado == "a_mesa" and llego_al_final:
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
		if caja["timer"] >= tiempo_cobro():
			caja["timer"] = 0.0
			caja["cola"].pop_front()
			clientes_atendidos += 1
			ganar_dinero(PRECIO_CAFE, primero.pos)
			# Si hay silla libre se sienta, si no se lleva el cafe
			if buscar_silla_libre(primero):
				primero.estado = "a_mesa"
				if es_mesa_patio(primero.mesa):
					# Sale por la puerta y entra al patio por afuera
					primero.camino = [PUERTA_ADENTRO, PUERTA_AFUERA, PATIO_AFUERA, PATIO_ADENTRO]
			else:
				irse(primero)


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
	var nuevo_borde := IZQUIERDA + ANCHO_CAJAS + nivel_local * ANCHO_COLUMNA
	empezar_obras()
	var tw := create_tween()
	tw.tween_property(self, "borde_local", nuevo_borde, 1.6) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(terminar_obras.bind("Cafeteria agrandada!"))


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
#  OBRAS (animacion de construccion)
# =====================================================
func empezar_obras() -> void:
	en_obras = true

func terminar_obras(mensaje: String) -> void:
	en_obras = false
	temblor = 0.0
	position = Vector2.ZERO
	agregar_texto(Vector2(380, 330), mensaje, Color.YELLOW, 2.5)
	# Lluvia de polvo final
	for i in 40:
		agregar_polvo(Vector2(randf_range(IZQUIERDA, borde_local), randf_range(ARRIBA, ABAJO)))

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
		var progreso: float = cajas[i]["timer"] / tiempo_cobro()
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
		if tex_clientes.size() > 0:
			var t: Texture2D = tex_clientes[c.sprite]
			draw_texture(t, c.pos - Vector2(t.get_width() / 2.0, t.get_height() - 12))
		else:
			draw_circle(c.pos, 12, Color.CORNFLOWER_BLUE)

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
#  INTERFAZ (botones y dinero)
# =====================================================
func crear_interfaz() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)

	var columna := VBoxContainer.new()
	columna.position = Vector2(10, 6)
	capa.add_child(columna)

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

	btn_caja = crear_boton(botones, comprar_caja)
	btn_mesa = crear_boton(botones, comprar_mesa)
	btn_local = crear_boton(botones, agrandar_local)
	btn_cafetera = crear_boton(botones, comprar_cafetera)
	btn_patio = crear_boton(botones, comprar_patio)
	btn_cartel = crear_boton(botones, comprar_cartel)


func crear_boton(padre: Node, accion: Callable) -> Button:
	var b := Button.new()
	b.pressed.connect(accion)
	padre.add_child(b)
	return b


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
	if nivel_local < 2:
		label_pista.text = "Proximo: agranda la cafeteria para desbloquear la Cafetera espresso"
	elif nivel_local < MAX_NIVEL_LOCAL:
		label_pista.text = "Proximo: agranda %d vez mas para desbloquear el Patio de mesas" % (MAX_NIVEL_LOCAL - nivel_local)
	elif not tiene_patio:
		label_pista.text = "Compra el patio para desbloquear el Cartel luminoso"
	else:
		label_pista.text = ""
