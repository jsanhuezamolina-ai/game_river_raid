extends Node2D
## Río procedural infinito a partir de una semilla. La misma semilla produce siempre el mismo río.
## Cada fila es un Node2D con orillas (StaticBody2D, capa ParedesRio) y, a veces, un objeto.

signal scored(points: int, pos: Vector2, kind: int)
signal bridge_destroyed

const ENEMY_SCENE := preload("res://scenes/Enemy.tscn")
const FUEL_SCENE := preload("res://scenes/FuelDepot.tscn")
const ROWS_PER_SECTION := 90
const MIN_CHANNEL := 64.0 # Ancho mínimo navegable de cada canal junto a una isla

const LAND := Color(0.18, 0.55, 0.22)
const LAND_DARK := Color(0.13, 0.42, 0.17)
const ROAD := Color(0.35, 0.35, 0.38)

var row_height := 32.0
var screen_width := 540.0
var view_height := 960.0
var bank_overhang := 400.0 # Las orillas se extienden fuera de pantalla (pantallas anchas)

var rng := RandomNumberGenerator.new()
var current_seed := 0
var params: Dictionary = {}
var entity_parent: Node # Donde van los disparos enemigos (no se desplazan con el río)

var river_center := 270.0
var river_half_width := 200.0
var island_half := 0.0
var island_target := 0.0
var island_rows_left := 0
var rows_spawned := 0
var section := 1
var rows: Array[Node2D] = []


func start_river(custom_seed: int, mode_params: Dictionary, p_view_height: float, p_entity_parent: Node) -> void:
	current_seed = custom_seed
	rng.seed = custom_seed
	params = mode_params
	view_height = p_view_height
	entity_parent = p_entity_parent
	river_center = screen_width / 2.0
	river_half_width = float(params["max_half"])
	island_half = 0.0
	island_target = 0.0
	rows_spawned = 0
	section = 1
	for r in rows:
		r.queue_free()
	rows.clear()
	# Llenar la pantalla. Las primeras filas no tienen enemigos (salida segura).
	var y := view_height + row_height
	while y > -row_height * 3.0:
		_spawn_row(y, true)
		y -= row_height


func update_river(scroll_speed: float, delta: float) -> void:
	var dy := scroll_speed * delta
	for r in rows:
		r.position.y += dy
	while rows.size() > 0 and rows[0].position.y > view_height + row_height * 2.0:
		var old: Node2D = rows.pop_front()
		old.queue_free()
	while rows.back().position.y > -row_height * 3.0:
		_spawn_row(rows.back().position.y - row_height, false)


func _effective_max_half() -> float:
	# El río se estrecha un poco en cada tramo.
	var min_h := float(params["min_half"])
	return maxf(min_h + 25.0, float(params["max_half"]) - (section - 1) * 8.0)


func _spawn_row(y_pos: float, safe: bool) -> void:
	rows_spawned += 1
	var in_section := rows_spawned % ROWS_PER_SECTION
	var is_bridge := in_section == 0 and not safe
	var near_bridge := in_section > ROWS_PER_SECTION - 10 or in_section < 6
	var min_h := float(params["min_half"])
	var max_h := _effective_max_half()

	if near_bridge or safe:
		# Antes y después del puente el río se vuelve recto y centrado.
		river_center = move_toward(river_center, screen_width / 2.0, 12.0)
		river_half_width = move_toward(river_half_width, clampf(130.0, min_h, max_h), 10.0)
		island_target = 0.0
	else:
		river_center += rng.randf_range(-22.0, 22.0)
		river_half_width += rng.randf_range(-14.0, 14.0)
		_update_island(max_h)
	river_half_width = clampf(river_half_width, min_h, max_h)
	river_center = clampf(river_center, river_half_width + 24.0, screen_width - river_half_width - 24.0)
	island_half = move_toward(island_half, island_target, 7.0)
	island_half = minf(island_half, maxf(0.0, river_half_width - MIN_CHANNEL))

	var row := Node2D.new()
	row.position = Vector2(0, y_pos)
	row.set_meta("center", river_center)
	row.set_meta("half", river_half_width)
	row.set_meta("island", island_half)
	add_child(row)
	rows.append(row)

	var left_edge := river_center - river_half_width
	var right_edge := river_center + river_half_width
	var bank_color := ROAD if is_bridge else LAND
	_create_bank(row, -bank_overhang, left_edge + bank_overhang, bank_color)
	_create_bank(row, right_edge, screen_width + bank_overhang - right_edge, bank_color)
	if island_half > 2.0:
		_create_bank(row, river_center - island_half, island_half * 2.0, LAND_DARK)

	if is_bridge:
		_spawn_bridge(row, left_edge, right_edge)
	elif not safe and not near_bridge and rows_spawned % int(params["spawn_every"]) == 0:
		_spawn_entity(row)


func _update_island(max_h: float) -> void:
	if island_rows_left > 0:
		island_rows_left -= 1
		if island_rows_left == 0:
			island_target = 0.0
	elif island_half < 1.0 and river_half_width > 150.0 and rng.randf() < 0.025:
		island_target = rng.randf_range(30.0, maxf(31.0, max_h - MIN_CHANNEL - 10.0))
		island_rows_left = rng.randi_range(14, 30)
		river_half_width = maxf(river_half_width, island_target + MIN_CHANNEL + 10.0)


func _create_bank(parent: Node2D, x_start: float, width: float, color: Color) -> void:
	if width <= 0.0:
		return
	var bank := StaticBody2D.new()
	bank.collision_layer = 2 # ParedesRio
	bank.collision_mask = 0
	var visual := ColorRect.new()
	visual.size = Vector2(width, row_height + 1.0)
	visual.position = Vector2(x_start, 0)
	visual.color = color
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bank.add_child(visual)
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, row_height)
	col.shape = shape
	col.position = Vector2(x_start + width / 2.0, row_height / 2.0)
	bank.add_child(col)
	parent.add_child(bank)


## Devuelve los canales navegables [[min_x, max_x], ...] de una fila.
func _channels(row: Node2D) -> Array:
	var c: float = row.get_meta("center")
	var h: float = row.get_meta("half")
	var isl: float = row.get_meta("island")
	if isl > 2.0:
		return [[c - h, c - isl], [c + isl, c + h]]
	return [[c - h, c + h]]


func _spawn_entity(row: Node2D) -> void:
	var chans := _channels(row)
	var ch: Array = chans[rng.randi() % chans.size()]
	var lo: float = ch[0] + 28.0
	var hi: float = ch[1] - 28.0
	if hi <= lo:
		return
	var x := rng.randf_range(lo, hi)
	if rng.randf() < float(params["fuel_chance"]):
		var fuel: Node2D = FUEL_SCENE.instantiate()
		fuel.position = Vector2(x, row_height / 2.0)
		fuel.destroyed.connect(_on_destroyed)
		row.add_child(fuel)
	else:
		var enemy: Node2D = ENEMY_SCENE.instantiate()
		var kind: int = 0 if rng.randf() < 0.55 else 1 # Barco o helicóptero
		enemy.setup(kind, ch[0] + 4.0, ch[1] - 4.0, float(params["enemy_speed"]) * (1.0 + (section - 1) * 0.08),
			bool(params["enemy_shoots"]) and rng.randf() < 0.5, rng, entity_parent)
		enemy.position = Vector2(x, row_height / 2.0)
		enemy.destroyed.connect(_on_destroyed)
		row.add_child(enemy)


func _spawn_bridge(row: Node2D, left_edge: float, right_edge: float) -> void:
	var bridge: Node2D = ENEMY_SCENE.instantiate()
	bridge.setup(2, left_edge, right_edge, 0.0, false, rng, entity_parent)
	bridge.position = Vector2(0, row_height / 2.0)
	bridge.destroyed.connect(_on_destroyed)
	row.add_child(bridge)


func _on_destroyed(points: int, pos: Vector2, kind: int) -> void:
	scored.emit(points, pos, kind)
	if kind == 2:
		section += 1
		bridge_destroyed.emit()


func _row_at(y: float) -> Node2D:
	for r in rows:
		if y >= r.position.y and y < r.position.y + row_height:
			return r
	return null


## Centro del canal más ancho a la altura y (para reaparecer o para el piloto automático).
func safe_x(y: float) -> float:
	var row := _row_at(y)
	if row == null:
		return screen_width / 2.0
	var best: Array = []
	for ch in _channels(row):
		if best.is_empty() or (ch[1] - ch[0]) > (best[1] - best[0]):
			best = ch
	return (best[0] + best[1]) / 2.0


## Quita enemigos cerca del avión para que reaparecer sea justo.
func clear_threats(player_y: float) -> void:
	for r in rows:
		if r.position.y > player_y - 420.0 and r.position.y < player_y + 80.0:
			for c in r.get_children():
				if c.is_in_group("bridges"):
					# Si chocó con un puente, se le da por superado (sin puntos) para no quedar atascado.
					c.queue_free()
					section += 1
				elif c.is_in_group("enemies"):
					c.queue_free()
