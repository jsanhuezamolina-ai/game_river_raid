extends Area2D
## Barcos, helicópteros y puentes. Patrullan dentro de su tramo de río.

signal destroyed(points: int, pos: Vector2, kind: int)

enum Kind { BOAT, HELI, BRIDGE }

const POINTS := {Kind.BOAT: 30, Kind.HELI: 60, Kind.BRIDGE: 500}

var kind: int = Kind.BOAT
var min_x := 0.0
var max_x := 540.0
var speed := 0.0
var dir := 1.0
var shoots := false
var bullet_parent: Node

var _active := false
var _fire_t := 1.5
var _rotor: Polygon2D
var _half_w := 20.0
var _dead := false


func setup(p_kind: int, p_min_x: float, p_max_x: float, speed_mult: float, p_shoots: bool,
		rng: RandomNumberGenerator, parent_for_bullets: Node) -> void:
	kind = p_kind
	min_x = p_min_x
	max_x = p_max_x
	shoots = p_shoots and kind != Kind.BRIDGE
	bullet_parent = parent_for_bullets
	dir = -1.0 if rng.randf() < 0.5 else 1.0
	match kind:
		Kind.BOAT:
			speed = rng.randf_range(40.0, 80.0) * speed_mult
		Kind.HELI:
			speed = rng.randf_range(80.0, 140.0) * speed_mult
		_:
			speed = 0.0
	_fire_t = rng.randf_range(0.8, 2.2)


func _ready() -> void:
	add_to_group("enemies")
	if kind == Kind.BRIDGE:
		add_to_group("bridges")
	collision_layer = 4 # Enemigos
	collision_mask = 0
	_build()


func _build() -> void:
	var size := Vector2.ZERO
	match kind:
		Kind.BOAT:
			size = Vector2(56, 18)
			_add_poly([Vector2(-28, -6), Vector2(28, -6), Vector2(20, 9), Vector2(-20, 9)], Color(0.2, 0.2, 0.25))
			_add_poly([Vector2(-14, -14), Vector2(10, -14), Vector2(10, -6), Vector2(-14, -6)], Color(0.85, 0.85, 0.9))
			_add_poly([Vector2(-4, -20), Vector2(2, -20), Vector2(2, -14), Vector2(-4, -14)], Color(0.9, 0.3, 0.2))
		Kind.HELI:
			size = Vector2(40, 22)
			_add_poly([Vector2(-14, -8), Vector2(10, -8), Vector2(16, 0), Vector2(10, 8), Vector2(-14, 8)], Color(0.15, 0.55, 0.35))
			_add_poly([Vector2(-14, -2), Vector2(-30, -3), Vector2(-30, 3), Vector2(-14, 2)], Color(0.15, 0.55, 0.35))
			_add_poly([Vector2(4, -5), Vector2(12, -2), Vector2(4, 0)], Color(0.6, 0.85, 1.0))
			_rotor = _add_poly([Vector2(-24, -12), Vector2(24, -12), Vector2(24, -10), Vector2(-24, -10)], Color(0.1, 0.1, 0.1))
		Kind.BRIDGE:
			var w := max_x - min_x
			size = Vector2(w, 30)
			position.x = (min_x + max_x) / 2.0
			_add_poly([Vector2(-w / 2, -15), Vector2(w / 2, -15), Vector2(w / 2, 15), Vector2(-w / 2, 15)], Color(0.55, 0.35, 0.2))
			_add_poly([Vector2(-w / 2, -3), Vector2(w / 2, -3), Vector2(w / 2, 3), Vector2(-w / 2, 3)], Color(0.95, 0.85, 0.2))
			var x := -w / 2 + 6
			while x < w / 2 - 6:
				_add_poly([Vector2(x, -15), Vector2(x + 4, -15), Vector2(x + 4, 15), Vector2(x, 15)], Color(0.4, 0.25, 0.15))
				x += 28
	_half_w = size.x / 2.0
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	col.shape = rect
	add_child(col)


func _add_poly(points: Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = PackedVector2Array(points)
	p.color = color
	add_child(p)
	return p


func _physics_process(delta: float) -> void:
	if kind == Kind.BRIDGE:
		return
	if _rotor:
		_rotor.scale.x = 0.3 + absf(sin(Time.get_ticks_msec() / 40.0))
	# Empiezan a moverse al entrar en pantalla, como en el original.
	if not _active:
		_active = global_position.y > -20.0
		return
	position.x += dir * speed * delta
	if position.x - _half_w < min_x:
		position.x = min_x + _half_w
		dir = 1.0
	elif position.x + _half_w > max_x:
		position.x = max_x - _half_w
		dir = -1.0
	for p in get_children():
		if p is Polygon2D:
			(p as Polygon2D).scale.x = -1.0 if dir < 0 else 1.0
	if shoots:
		_fire_t -= delta
		if _fire_t <= 0.0 and global_position.y > 40.0 and global_position.y < 620.0:
			_fire_t = 1.6
			_fire()


func _fire() -> void:
	if bullet_parent == null:
		return
	var b := EnemyBullet.new()
	b.global_position = global_position + Vector2(0, 14)
	bullet_parent.add_child(b)
	Sfx.play("enemy_shot", -6.0)


func take_hit() -> void:
	if _dead:
		return
	_dead = true
	destroyed.emit(int(POINTS[kind]), global_position, kind)
	Sfx.play("bridge" if kind == Kind.BRIDGE else "explosion")
	queue_free()


## Disparo enemigo (modo B): baja en línea recta.
class EnemyBullet extends Area2D:
	var speed := 520.0

	func _ready() -> void:
		add_to_group("enemy_bullets")
		collision_layer = 4
		collision_mask = 0
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([Vector2(-4, -4), Vector2(4, -4), Vector2(4, 4), Vector2(-4, 4)])
		poly.color = Color(1.0, 0.3, 0.3)
		add_child(poly)
		var col := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = 4.0
		col.shape = c
		add_child(col)

	func take_hit() -> void:
		queue_free()

	func _physics_process(delta: float) -> void:
		position.y += speed * delta
		if global_position.y > 2200.0:
			queue_free()
