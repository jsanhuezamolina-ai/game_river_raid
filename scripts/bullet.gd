extends Area2D
## Misil del jugador. Sube en línea recta y destruye lo que tenga take_hit().

var speed := 900.0


func _ready() -> void:
	add_to_group("bullets")
	collision_layer = 16 # Proyectiles
	collision_mask = 4 # Solo enemigos: los misiles atraviesan los tanques FUEL sin destruirlos
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-2, -9), Vector2(2, -9), Vector2(2, 9), Vector2(-2, 9)])
	poly.color = Color(1.0, 0.95, 0.6)
	add_child(poly)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(6, 18)
	col.shape = rect
	add_child(col)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position.y -= speed * delta
	if global_position.y < -40.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	if is_queued_for_deletion():
		return
	if area.has_method("take_hit"):
		area.take_hit()
		queue_free()
