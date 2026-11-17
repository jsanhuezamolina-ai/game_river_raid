class_name UI
extends RefCounted
## Utilidades de interfaz compartidas por el menú y el HUD (estilo retro, alto contraste).

const BG := Color(0.05, 0.07, 0.14, 0.92)
const ACCENT := Color(1.0, 0.82, 0.25)
const TEXT := Color(0.96, 0.96, 1.0)


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.18, 0.32) if state != "pressed" else Color(0.3, 0.26, 0.1)
		if state == "hover" or state == "focus":
			sb.bg_color = Color(0.2, 0.25, 0.42)
		sb.border_color = ACCENT if state in ["focus", "pressed"] else Color(0.3, 0.36, 0.55)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(10)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.08, 0.1, 0.2)
	le.border_color = Color(0.3, 0.36, 0.55)
	le.set_border_width_all(2)
	le.set_corner_radius_all(8)
	le.content_margin_left = 12
	le.content_margin_right = 12
	le.content_margin_top = 8
	le.content_margin_bottom = 8
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le)
	t.set_color("font_color", "LineEdit", TEXT)
	return t


static func label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, callback: Callable, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 54)
	b.pressed.connect(func() -> void:
		Sfx.play("click", -6.0)
		callback.call())
	return b


## Panel centrado a pantalla completa con un VBoxContainer adentro (lo devuelve).
static func overlay(parent: Node) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = ACCENT
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box
