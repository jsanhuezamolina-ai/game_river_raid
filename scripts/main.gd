extends Node2D
## Partida: río, avión, puntaje, vidas, HUD, pausa y fin del juego.
## Argumentos de prueba (después de "--"): --autoplay  --autoplay-seconds=N  --mode=A|B  --seed=N
##   --screenshot=ruta.png (guarda una captura a los 6 s; requiere ventana, no --headless)

const PLAYER_SCENE := preload("res://scenes/Player.tscn")
const GENERATOR := preload("res://scripts/river_generator.gd")

var generator: Node2D
var player: CharacterBody2D
var score := 0
var lives := 3
var game_over := false
var view_size := Vector2(540, 960)

var _hud: CanvasLayer
var _score_label: Label
var _high_label: Label
var _lives_label: Label
var _info_label: Label
var _fuel_bar: ProgressBar
var _fuel_fill: StyleBoxFlat
var _message: Label
var _pause_layer: CanvasLayer

# Prueba automática
var _autoplay := false
var _seek_fuel := false # Prueba: no dispara y vuela hacia los tanques
var _refuels := 0
var _autoplay_seconds := 40.0
var _screenshot_path := ""
var _elapsed := 0.0
var _log_t := 0.0
var _stats := {"deaths": 0, "kills": 0, "fuel_shot": 0, "bridges": 0, "max_fuel_gain": 0.0}
var _last_fuel := 100.0


func _ready() -> void:
	_parse_args()
	view_size = get_viewport_rect().size
	lives = GameState.start_lives
	var params := GameState.mode_params()

	generator = GENERATOR.new()
	add_child(generator)
	generator.scored.connect(_on_scored)
	generator.bridge_destroyed.connect(_on_bridge)

	player = PLAYER_SCENE.instantiate()
	player.position = Vector2(270, view_size.y - 190.0)
	player.setup(GameState.ship_color_value(), GameState.ship_model, float(params["fuel_rate"]),
		(GameState.auto_fire or _autoplay) and not _seek_fuel, self)
	add_child(player)
	player.hit.connect(_on_player_hit)
	player.fuel_changed.connect(_on_fuel_changed)

	generator.start_river(GameState.seed_value, params, view_size.y, self)
	_build_hud()
	_update_hud()
	_flash("TRAMO 1", 1.4)


func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			_autoplay = true
		elif a.begins_with("--autoplay-seconds="):
			_autoplay_seconds = float(a.get_slice("=", 1))
		elif a == "--seek-fuel":
			_seek_fuel = true
		elif a.begins_with("--mode="):
			GameState.mode = a.get_slice("=", 1)
		elif a.begins_with("--seed="):
			GameState.seed_value = int(a.get_slice("=", 1))
		elif a.begins_with("--screenshot="):
			_screenshot_path = a.get_slice("=", 1)


func _physics_process(delta: float) -> void:
	if game_over:
		return
	var speed: float = player.current_scroll_speed if player.alive else 0.0
	generator.update_river(speed, delta)
	if _autoplay:
		_autoplay_step(delta)
	_update_hud()


# ---------------------------------------------------------------- Juego

func _on_scored(points: int, pos: Vector2, kind: int) -> void:
	score += points
	_explode(pos, kind == 2)
	if _autoplay:
		if kind == -1:
			_stats["fuel_shot"] += 1
		elif kind == 2:
			_stats["bridges"] += 1
		else:
			_stats["kills"] += 1


func _on_bridge() -> void:
	_flash("TRAMO %d" % generator.section, 1.2)


func _on_fuel_changed(fuel: float, max_fuel: float) -> void:
	_fuel_bar.max_value = max_fuel
	_fuel_bar.value = fuel
	var ratio := fuel / max_fuel
	_fuel_fill.bg_color = Color(0.9, 0.2, 0.2) if ratio < 0.25 else (Color(1.0, 0.75, 0.2) if ratio < 0.5 else Color(0.35, 0.9, 0.4))
	if _autoplay:
		_stats["max_fuel_gain"] = maxf(float(_stats["max_fuel_gain"]), fuel - _last_fuel)
		_last_fuel = fuel


func _on_player_hit(reason: String) -> void:
	_explode(player.global_position, true)
	lives -= 1
	_stats["deaths"] += 1
	if _autoplay:
		print("[autoplay] t=%.1f muerte: %s | vidas=%d puntaje=%d" % [_elapsed, reason, lives, score])
	_update_hud()
	if lives <= 0:
		await get_tree().create_timer(1.3, false).timeout
		_game_over(reason)
		return
	_flash(reason.to_upper(), 1.2)
	await get_tree().create_timer(1.3, false).timeout
	if game_over or not is_inside_tree():
		return
	generator.clear_threats(player.position.y)
	player.respawn(generator.safe_x(player.position.y))


func _explode(pos: Vector2, big: bool) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = 40 if big else 22
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 260.0 if big else 180.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0 if big else 5.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.5))
	grad.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	p.color_ramp = grad
	add_child(p)
	get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)


func _game_over(reason: String) -> void:
	game_over = true
	var is_record := GameState.submit_score(score)
	GameState.save_data()
	if _autoplay:
		_print_summary("fin del juego (%s)" % reason)
		get_tree().quit()
		return
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.make_theme()
	layer.add_child(root)
	var box := UI.overlay(root)
	box.add_child(UI.label("FIN DEL JUEGO", 38, UI.ACCENT))
	box.add_child(UI.label(reason.capitalize(), 20))
	box.add_child(UI.label("Puntaje: %d" % score, 30))
	if is_record:
		box.add_child(UI.label("¡NUEVO RÉCORD!", 26, Color(0.4, 1.0, 0.5)))
	else:
		box.add_child(UI.label("Récord modo %s: %d" % [GameState.mode, GameState.high_score()], 20))
	box.add_child(UI.label("Tramo alcanzado: %d" % generator.section, 20))
	box.add_child(UI.label("Semilla %d — compártela para jugar el mismo río" % GameState.seed_value, 17))
	box.add_child(UI.button("Reintentar (misma semilla)", func() -> void: get_tree().reload_current_scene()))
	box.add_child(UI.button("Río nuevo", func() -> void:
		GameState.new_seed()
		GameState.save_data()
		get_tree().reload_current_scene()))
	box.add_child(UI.button("Menú", func() -> void: get_tree().change_scene_to_file("res://scenes/Menu.tscn")))


# ---------------------------------------------------------------- HUD y pausa

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme()
	_hud.add_child(root)

	var top := ColorRect.new()
	top.color = Color(0, 0, 0, 0.45)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, 66)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)

	_score_label = _hud_label(Vector2(14, 6), 26, UI.ACCENT)
	_high_label = _hud_label(Vector2(14, 38), 15, UI.TEXT)
	_lives_label = _hud_label(Vector2(190, 6), 22, UI.TEXT)
	_info_label = _hud_label(Vector2(190, 38), 15, UI.TEXT)
	for l in [_score_label, _high_label, _lives_label, _info_label]:
		root.add_child(l)

	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.custom_minimum_size = Vector2(52, 50)
	pause_btn.anchor_left = 1.0
	pause_btn.anchor_right = 1.0
	pause_btn.offset_left = -64.0
	pause_btn.offset_right = -10.0
	pause_btn.offset_top = 8.0
	pause_btn.offset_bottom = 58.0
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.pressed.connect(_pause)
	root.add_child(pause_btn)

	# Barra de combustible abajo, estilo tablero "E ... F".
	var fuel_box := HBoxContainer.new()
	fuel_box.position = Vector2(20, view_size.y - 56)
	fuel_box.size = Vector2(view_size.x - 40, 36)
	fuel_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fuel_box.add_theme_constant_override("separation", 10)
	root.add_child(fuel_box)
	fuel_box.add_child(UI.label("E", 22, Color(1, 0.4, 0.4)))
	_fuel_bar = ProgressBar.new()
	_fuel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fuel_bar.custom_minimum_size = Vector2(0, 26)
	_fuel_bar.show_percentage = false
	_fuel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	bg.set_corner_radius_all(6)
	bg.border_color = Color(1, 1, 1, 0.5)
	bg.set_border_width_all(2)
	_fuel_fill = StyleBoxFlat.new()
	_fuel_fill.bg_color = Color(0.35, 0.9, 0.4)
	_fuel_fill.set_corner_radius_all(6)
	_fuel_bar.add_theme_stylebox_override("background", bg)
	_fuel_bar.add_theme_stylebox_override("fill", _fuel_fill)
	fuel_box.add_child(_fuel_bar)
	fuel_box.add_child(UI.label("F", 22, Color(0.5, 1, 0.5)))

	_message = UI.label("", 34, UI.ACCENT)
	_message.anchor_left = 0.0
	_message.anchor_right = 1.0
	_message.anchor_top = 0.36
	_message.anchor_bottom = 0.36
	_message.offset_left = 20.0
	_message.offset_right = -20.0
	_message.offset_bottom = 100.0
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 8)
	root.add_child(_message)


func _hud_label(pos: Vector2, size: int, color: Color) -> Label:
	var l := UI.label("", size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _update_hud() -> void:
	_score_label.text = "%06d" % score
	_high_label.text = "RÉCORD %06d" % maxi(GameState.high_score(), score)
	_lives_label.text = "VIDAS " + "▲ ".repeat(maxi(lives, 0))
	_info_label.text = "MODO %s · TRAMO %d · SEMILLA %d" % [GameState.mode, generator.section, GameState.seed_value]


func _flash(text: String, seconds: float) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(_message, "modulate:a", 0.0, 0.4)


func _pause() -> void:
	if game_over or get_tree().paused:
		return
	get_tree().paused = true
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 10
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.make_theme()
	_pause_layer.add_child(root)
	var box := UI.overlay(root)
	box.add_child(UI.label("PAUSA", 38, UI.ACCENT))
	box.add_child(UI.button("Continuar", _resume))
	box.add_child(UI.button("Menú", func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")))


func _resume() -> void:
	if _pause_layer:
		_pause_layer.queue_free()
		_pause_layer = null
	get_tree().paused = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if get_tree().paused:
			_resume()
		else:
			_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if not _autoplay:
			_pause()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_pause()


# ---------------------------------------------------------------- Prueba automática

func _autoplay_step(delta: float) -> void:
	_elapsed += delta
	if player.alive:
		var look_y: float = player.position.y - 90.0
		var target: float = generator.safe_x(look_y)
		if _seek_fuel:
			for f in get_tree().get_nodes_in_group("fuel"):
				var fy: float = (f as Node2D).global_position.y
				if fy < player.position.y + 10.0 and fy > player.position.y - 260.0:
					target = (f as Node2D).global_position.x
					break
		if player.refuel_count > 0:
			_refuels += 1
		player.position.x = move_toward(player.position.x, target, 260.0 * delta)
	_log_t -= delta
	if _log_t <= 0.0:
		_log_t = 5.0
		print("[autoplay] t=%.0fs puntaje=%d vidas=%d combustible=%.0f tramo=%d velocidad=%.0f filas=%d" % [
			_elapsed, score, lives, player.fuel, generator.section, player.current_scroll_speed, generator.rows_spawned])
	if _screenshot_path != "" and _elapsed >= 6.0:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_screenshot_path)
		print("[autoplay] captura guardada en ", _screenshot_path)
		_screenshot_path = ""
	if _elapsed >= _autoplay_seconds:
		_print_summary("tiempo cumplido")
		get_tree().quit()


func _print_summary(why: String) -> void:
	print("[autoplay] RESUMEN (%s): modo=%s semilla=%d puntaje=%d vidas=%d muertes=%d derribos=%d tanques_destruidos=%d puentes=%d recarga_max_por_frame=%.2f frames_recargando=%d tramo=%d récord=%d" % [
		why, GameState.mode, GameState.seed_value, score, lives, _stats["deaths"], _stats["kills"],
		_stats["fuel_shot"], _stats["bridges"], _stats["max_fuel_gain"], _refuels, generator.section, GameState.high_score()])
