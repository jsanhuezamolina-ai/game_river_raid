extends CharacterBody2D
## Avión del jugador: control táctil relativo, velocidad dinámica, combustible y disparo.

signal fuel_changed(fuel: float, max_fuel: float)
signal hit(reason: String)

const BULLET_SCENE := preload("res://scenes/Bullet.tscn")
const SHOOT_INTERVAL := 0.22
const KEY_MOVE_SPEED := 170.0

var horizontal_sensitivity := 0.625 # Mitad del valor original (1.25): el avión se desplaza la mitad de lo que se arrastra el dedo
var min_scroll_speed := 160.0
var max_scroll_speed := 560.0
var normal_scroll_speed := 280.0
var current_scroll_speed := 280.0

var max_fuel := 100.0
var fuel := 100.0
var fuel_consumption_rate := 3.4
var refuel_count := 0 # Cantidad de tanques que el avión está tocando
var auto_fire := true

var alive := true
var invulnerable := false
var min_x := 14.0
var max_x := 526.0
var bullet_parent: Node

var _target_speed := 280.0
var _touch_index := -1
var _shoot_cd := 0.0
var _manual_shot_queued := false
var _refuel_sfx_t := 0.0
var _low_fuel_t := 0.0
var _blink_tween: Tween

var _poly: Polygon2D
var _flame: Polygon2D
var _hurtbox: Area2D


func setup(color: Color, model: int, consumption: float, auto: bool, parent_for_bullets: Node) -> void:
	fuel_consumption_rate = consumption
	auto_fire = auto
	bullet_parent = parent_for_bullets
	_build(color, model)


func _build(color: Color, model: int) -> void:
	add_to_group("player")
	collision_layer = 1 # Jugador
	collision_mask = 0
	var shape_points := GameState.ship_polygon(model)

	_flame = Polygon2D.new()
	_flame.polygon = PackedVector2Array([Vector2(-5, 18), Vector2(5, 18), Vector2(0, 30)])
	_flame.color = Color(1.0, 0.5, 0.1)
	add_child(_flame)

	_poly = Polygon2D.new()
	_poly.polygon = shape_points
	_poly.color = color
	add_child(_poly)

	var cockpit := Polygon2D.new()
	cockpit.polygon = PackedVector2Array([Vector2(0, -14), Vector2(3, -6), Vector2(0, -2), Vector2(-3, -6)])
	cockpit.color = Color(0.15, 0.2, 0.35)
	add_child(cockpit)

	# Cuerpo físico: lo usan los tanques de combustible para detectar al avión.
	var body_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 34)
	body_shape.shape = rect
	add_child(body_shape)

	# Zona de daño algo más pequeña que el dibujo, para que los roces sean justos.
	_hurtbox = Area2D.new()
	_hurtbox.collision_layer = 0
	_hurtbox.collision_mask = 2 | 4 # ParedesRio + Enemigos
	var hurt_shape := CollisionPolygon2D.new()
	var scaled := PackedVector2Array()
	for p in shape_points:
		scaled.append(p * 0.72)
	hurt_shape.polygon = scaled
	_hurtbox.add_child(hurt_shape)
	add_child(_hurtbox)
	_hurtbox.body_entered.connect(_on_hurt_body)
	_hurtbox.area_entered.connect(_on_hurt_area)


func _ready() -> void:
	current_scroll_speed = normal_scroll_speed
	_target_speed = normal_scroll_speed


func _input(event: InputEvent) -> void:
	if not alive:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			if _touch_index == -1:
				_touch_index = touch.index
			if not auto_fire:
				_manual_shot_queued = true
		elif touch.index == _touch_index:
			_touch_index = -1
			_target_speed = normal_scroll_speed
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index != _touch_index:
			return
		# Movimiento horizontal en cualquier zona de la pantalla (sin botones que tapen).
		position.x = clampf(position.x + drag.relative.x * horizontal_sensitivity, min_x, max_x)
		# Deslizar hacia arriba acelera, hacia abajo frena.
		if absf(drag.relative.y) > 1.5:
			_target_speed = clampf(_target_speed - drag.relative.y * 3.0, min_scroll_speed, max_scroll_speed)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	# Teclado (pruebas en PC): flechas mueven y cambian velocidad, Espacio dispara en modo manual.
	var axis := Input.get_axis("ui_left", "ui_right")
	if axis != 0.0:
		position.x = clampf(position.x + axis * KEY_MOVE_SPEED * delta, min_x, max_x)
	if _touch_index == -1:
		if Input.is_action_pressed("ui_up"):
			_target_speed = max_scroll_speed
		elif Input.is_action_pressed("ui_down"):
			_target_speed = min_scroll_speed
		else:
			_target_speed = normal_scroll_speed
	if not auto_fire and Input.is_action_just_pressed("ui_accept"):
		_manual_shot_queued = true

	current_scroll_speed = move_toward(current_scroll_speed, _target_speed, 700.0 * delta)
	_flame.scale.y = lerpf(0.6, 1.6, inverse_lerp(min_scroll_speed, max_scroll_speed, current_scroll_speed))

	_update_fuel(delta)
	_update_shooting(delta)


func _update_fuel(delta: float) -> void:
	if refuel_count > 0:
		fuel = minf(max_fuel, fuel + 30.0 * delta)
		_refuel_sfx_t -= delta
		if _refuel_sfx_t <= 0.0 and fuel < max_fuel:
			Sfx.play("refuel", -4.0)
			_refuel_sfx_t = 0.18
	else:
		# A mayor velocidad, mayor consumo.
		var speed_factor := current_scroll_speed / normal_scroll_speed
		fuel -= fuel_consumption_rate * speed_factor * delta
	fuel_changed.emit(fuel, max_fuel)

	if fuel < max_fuel * 0.25 and refuel_count == 0:
		_low_fuel_t -= delta
		if _low_fuel_t <= 0.0:
			Sfx.play("fuel_low", -3.0)
			_low_fuel_t = 0.55
	if fuel <= 0.0:
		fuel = 0.0
		_die("sin combustible")


func _update_shooting(delta: float) -> void:
	_shoot_cd -= delta
	var wants := auto_fire or _manual_shot_queued
	if wants and _shoot_cd <= 0.0:
		_shoot_cd = SHOOT_INTERVAL
		_manual_shot_queued = false
		_fire()


func _fire() -> void:
	if bullet_parent == null:
		return
	var bullet: Node2D = BULLET_SCENE.instantiate()
	bullet.global_position = global_position + Vector2(0, -26)
	bullet_parent.add_child(bullet)
	Sfx.play("shoot", -8.0)


func _on_hurt_body(_body: Node2D) -> void:
	_die("chocaste con la orilla")


func _on_hurt_area(area: Area2D) -> void:
	if area.is_in_group("enemies") or area.is_in_group("enemy_bullets"):
		if area.is_in_group("bridges"):
			_die("chocaste con un puente")
		else:
			_die("te derribaron")


func _die(reason: String) -> void:
	if not alive or invulnerable:
		return
	alive = false
	visible = false
	_touch_index = -1
	_hurtbox.set_deferred("monitoring", false)
	hit.emit(reason)


## Vuelve a aparecer en x con el tanque lleno y 2 s de invulnerabilidad.
func respawn(x: float) -> void:
	position.x = clampf(x, min_x, max_x)
	fuel = max_fuel
	refuel_count = 0
	current_scroll_speed = normal_scroll_speed
	_target_speed = normal_scroll_speed
	alive = true
	visible = true
	invulnerable = true
	if _blink_tween:
		_blink_tween.kill()
	_blink_tween = create_tween().set_loops(10)
	_blink_tween.tween_property(self, "modulate:a", 0.25, 0.1)
	_blink_tween.tween_property(self, "modulate:a", 1.0, 0.1)
	await get_tree().create_timer(2.0, false).timeout
	if not is_inside_tree():
		return
	modulate.a = 1.0
	invulnerable = false
	_hurtbox.monitoring = true
