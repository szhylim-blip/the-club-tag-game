class_name AdminConsole
extends Control
## F1 playtest console. Lets the host start a match from wherever they stand and
## jump straight to any lobby wing, so every mode can be checked without a walk.

signal command(kind: String, value: String)

var _panel: PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_panel = PanelContainer.new()
	_panel.position = Vector2(28, 28)
	_panel.custom_minimum_size = Vector2(304, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.055, 0.045, 0.085, 0.95)
	sb.border_color = Cfg.GOLD
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_panel.add_child(v)

	var title := Label.new()
	title.text = "ADMIN  /  PLAYTEST"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Cfg.GOLD)
	v.add_child(title)
	v.add_child(HSeparator.new())

	v.add_child(_btn("TAG  —  START HERE", "start_mode", "tag"))
	v.add_child(_btn("HIDE & SEEK  —  START HERE", "start_mode", "hush"))
	v.add_child(_btn("INFECTION  —  START HERE", "start_mode", "infection"))
	v.add_child(_btn("HOT POTATO  —  START HERE", "start_mode", "potato"))
	v.add_child(_btn("TAG  —  START AT ORIGIN", "tag", ""))
	v.add_child(HSeparator.new())
	v.add_child(_btn("LOADOUT  —  CUSTOMISE", "customise", ""))
	v.add_child(HSeparator.new())
	v.add_child(_btn("HUB  —  LOUNGE", "travel", "lounge"))
	v.add_child(_btn("HUB  —  THE FLOOR", "travel", "floor"))
	v.add_child(_btn("HUB  —  THE HUSH", "travel", "hush"))
	v.add_child(_btn("HUB  —  THE PARLOUR", "travel", "parlour"))
	v.add_child(_btn("HUB  —  THE BASEMENT", "travel", "basement"))
	v.add_child(HSeparator.new())
	v.add_child(_btn("CLOSE   (F1)", "close", ""))


func _btn(text: String, kind: String, value: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 30)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color(0.88, 0.86, 0.94))
	b.add_theme_color_override("font_hover_color", Cfg.GOLD)
	b.add_theme_stylebox_override("normal", _flat(Color(0.10, 0.085, 0.14, 0.0)))
	b.add_theme_stylebox_override("hover", _flat(Color(0.16, 0.13, 0.21, 0.9)))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.22, 0.17, 0.28, 0.95)))
	b.pressed.connect(func(): command.emit(kind, value))
	b.mouse_entered.connect(func(): Sfx.play("hover", -22.0, 1.0))
	return b


func _flat(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(6)
	s.content_margin_left = 8
	s.content_margin_right = 8
	return s


func toggle() -> void:
	visible = not visible
	if visible:
		Sfx.play("click", -12.0, 1.0)
