class_name MenuModeCard
extends Button
## A large selectable game card. The whole surface is the button; the accent
## bar and typography carry the mode instead of a tiny text button.

var title_text := "TAG"
var subtitle_text := ""
var meta_text := ""
var index_text := "01"
var accent: Color = Cfg.GOLD
var _hover := false


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(300, 154)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	mouse_entered.connect(func(): _hover = true; Sfx.play("hover", -24.0, 1.0); queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())
	focus_entered.connect(func(): _hover = true; queue_redraw())
	focus_exited.connect(func(): _hover = false; queue_redraw())
	pressed.connect(func(): Sfx.play("click", -8.0, 1.02))


func _draw() -> void:
	var hovered := _hover and not disabled
	var bg := Color(0.115, 0.094, 0.148, 0.96) if hovered else Color(0.075, 0.062, 0.105, 0.92)
	var border := accent if hovered else Color(1, 1, 1, 0.10)
	draw_rect(Rect2(Vector2.ZERO, size), bg, true)
	draw_rect(Rect2(Vector2.ZERO, size), border, false, 1.0)
	draw_rect(Rect2(Vector2(0, 0), Vector2(4, size.y)), accent, true)
	draw_string(Style.mono, Vector2(24, 27), index_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
		accent if hovered else Cfg.GOLD_DIM)
	draw_string(Style.display, Vector2(24, 64), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 27,
		Cfg.CREAM if hovered else Color(0.94, 0.91, 0.86))
	draw_string(Style.body, Vector2(24, 91), subtitle_text, HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 48, 13, Cfg.MUTED)
	draw_string(Style.mono, Vector2(24, size.y - 17), meta_text, HORIZONTAL_ALIGNMENT_LEFT,
		size.x - 48, 10, accent if hovered else Color(1, 1, 1, 0.32))
