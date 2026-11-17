extends Area2D
## Tanque de combustible: recarga al pasar encima. Los misiles lo atraviesan (no se destruye).

signal destroyed(points: int, pos: Vector2, kind: int)

const POINTS := 80

var _player: Node = null
var _dead := false


func _ready() -> void:
	add_to_group("fuel")
	collision_layer = 8 # Combustible
	collision_mask = 1 # Jugador
	_build()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _build() -> void:
	var stripes := [Color(0.85, 0.15, 0.15), Color(0.95, 0.95, 0.95)]
	for i in 4:
		var y := -28.0 + i * 14.0
		var p := Polygon2D.new()
		p.polygon = PackedVector2Array([Vector2(-18, y), Vector2(18, y), Vector2(18, y + 14), Vector2(-18, y + 14)])
		p.color = stripes[i % 2]
		add_child(p)
	var label := Label.new()
	label.text = "FUEL"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	label.position = Vector2(-15, -9)
	add_child(label)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 56)
	col.shape = rect
	add_child(col)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body
		body.refuel_count += 1


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_release()


func _release() -> void:
	if _player != null and is_instance_valid(_player):
		_player.refuel_count = maxi(0, _player.refuel_count - 1)
	_player = null


func take_hit() -> void:
	if _dead:
		return
	_dead = true
	_release()
	destroyed.emit(POINTS, global_position, -1)
	Sfx.play("explosion")
	queue_free()


func _exit_tree() -> void:
	# Si el tramo sale de pantalla con el avión encima, deja de recargar.
	_release()
