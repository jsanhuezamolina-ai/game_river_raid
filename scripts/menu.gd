extends Control
## Menú inicial: modo A/B, nave (modelo y color), vidas, disparo, semilla y récords.

var _mode_desc: Label
var _mode_buttons: Dictionary = {}
var _model_label: Label
var _lives_label: Label
var _fire_button: Button
var _seed_edit: LineEdit
var _records: Label
var _preview: ShipPreview
var _color_buttons: Array[Button] = []


func _ready() -> void:
	theme = UI.make_theme()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--autoplay"):
			# Las pruebas automáticas saltan el menú.
			get_tree().change_scene_to_file.call_deferred("res://scenes/Main.tscn")
			return
	_build()
	_refresh()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--menu-shot="):
			# Prueba: guarda una captura del menú y cierra.
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png(a.get_slice("=", 1))
			get_tree().quit()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.08, 0.18)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	for side in [0.0, 1.0]:
		var bank := ColorRect.new()
		bank.color = Color(0.18, 0.55, 0.22)
		bank.anchor_left = side
		bank.anchor_right = side
		bank.anchor_bottom = 1.0
		bank.offset_left = -40.0 if side == 1.0 else 0.0
		bank.offset_right = 0.0 if side == 1.0 else 40.0
		add_child(bank)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 56
	scroll.offset_right = -56
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)

	box.add_child(_spacer(18))
	box.add_child(UI.label("RIVER RAID", 52, UI.ACCENT))
	box.add_child(UI.label("MODERNO", 22))
	_records = UI.label("", 18)
	box.add_child(_records)

	box.add_child(_section("Modo"))
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 10)
	for m in ["A", "B"]:
		var b := UI.button("Modo %s" % m, func() -> void:
			GameState.mode = m
			_refresh())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		_mode_buttons[m] = b
		modes.add_child(b)
	box.add_child(modes)
	_mode_desc = UI.label("", 16)
	box.add_child(_mode_desc)

	box.add_child(_section("Nave"))
	_preview = ShipPreview.new()
	_preview.custom_minimum_size = Vector2(0, 80)
	box.add_child(_preview)
	var models := HBoxContainer.new()
	models.add_theme_constant_override("separation", 10)
	models.add_child(UI.button("<", func() -> void: _change_model(-1)))
	_model_label = UI.label("", 22)
	_model_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	models.add_child(_model_label)
	models.add_child(UI.button(">", func() -> void: _change_model(1)))
	box.add_child(models)
	var colors := HBoxContainer.new()
	colors.alignment = BoxContainer.ALIGNMENT_CENTER
	colors.add_theme_constant_override("separation", 8)
	for i in GameState.SHIP_COLORS.size():
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(52, 52)
		cb.focus_mode = Control.FOCUS_NONE
		var sb := StyleBoxFlat.new()
		sb.bg_color = GameState.SHIP_COLORS[i]
		sb.set_corner_radius_all(26)
		for st in ["normal", "hover", "pressed"]:
			cb.add_theme_stylebox_override(st, sb)
		cb.pressed.connect(func() -> void:
			Sfx.play("click", -6.0)
			GameState.ship_color = i
			_refresh())
		_color_buttons.append(cb)
		colors.add_child(cb)
	box.add_child(colors)

	box.add_child(_section("Vidas iniciales"))
	var lives := HBoxContainer.new()
	lives.add_child(UI.button("−", func() -> void: _change_lives(-1)))
	_lives_label = UI.label("", 26)
	_lives_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lives.add_child(_lives_label)
	lives.add_child(UI.button("+", func() -> void: _change_lives(1)))
	box.add_child(lives)

	box.add_child(_section("Disparo"))
	_fire_button = UI.button("", func() -> void:
		GameState.auto_fire = not GameState.auto_fire
		_refresh())
	box.add_child(_fire_button)

	box.add_child(_section("Semilla del río"))
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 10)
	_seed_edit = LineEdit.new()
	_seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_seed_edit.max_length = 9
	_seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_edit.add_theme_font_size_override("font_size", 24)
	_seed_edit.text_changed.connect(_on_seed_changed)
	seed_row.add_child(_seed_edit)
	seed_row.add_child(UI.button("Aleatoria", func() -> void:
		GameState.new_seed()
		_refresh()))
	box.add_child(seed_row)
	box.add_child(UI.label("La misma semilla genera el mismo río: compártela para competir.", 15))

	box.add_child(_spacer(6))
	var play := UI.button("JUGAR", _play, 32)
	play.custom_minimum_size = Vector2(0, 72)
	box.add_child(play)
	box.add_child(UI.label("Desliza el dedo para moverte. Arriba acelera, abajo frena.\nPasa sobre FUEL para recargar.", 15))
	box.add_child(_spacer(24))


func _section(text: String) -> Label:
	var l := UI.label(text.to_upper(), 16, UI.ACCENT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l


func _spacer(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _change_model(step: int) -> void:
	GameState.ship_model = posmod(GameState.ship_model + step, GameState.SHIP_MODELS.size())
	_refresh()


func _change_lives(step: int) -> void:
	GameState.start_lives = clampi(GameState.start_lives + step, 1, 5)
	_refresh()


func _on_seed_changed(text: String) -> void:
	var digits := ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits != text:
		_seed_edit.text = digits
		_seed_edit.caret_column = digits.length()
	if digits != "":
		GameState.seed_value = maxi(1, int(digits))


func _refresh() -> void:
	_records.text = "Récord A: %d   ·   Récord B: %d" % [int(GameState.high_scores["A"]), int(GameState.high_scores["B"])]
	for m in _mode_buttons:
		(_mode_buttons[m] as Button).button_pressed = (m == GameState.mode)
	_mode_desc.text = ("Veterano: más consumo, río estrecho, enemigos rápidos que disparan."
		if GameState.mode == "B" else "Clásico: consumo moderado, río ancho, enemigos lentos.")
	_model_label.text = GameState.SHIP_MODELS[GameState.ship_model]
	_lives_label.text = str(GameState.start_lives)
	_fire_button.text = "Automático" if GameState.auto_fire else "Manual (toca para disparar)"
	if _seed_edit.text != str(GameState.seed_value):
		_seed_edit.text = str(GameState.seed_value)
	for i in _color_buttons.size():
		_color_buttons[i].modulate = Color.WHITE if i == GameState.ship_color else Color(1, 1, 1, 0.45)
	_preview.queue_redraw()


func _play() -> void:
	if _seed_edit.text.strip_edges() == "":
		GameState.new_seed()
	GameState.save_data()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


## Vista previa de la nave elegida.
class ShipPreview extends Control:
	func _draw() -> void:
		var pts := GameState.ship_polygon(GameState.ship_model)
		var t := Transform2D(0.0, Vector2(1.7, 1.7), 0.0, size / 2.0)
		draw_colored_polygon(t * pts, GameState.ship_color_value())
