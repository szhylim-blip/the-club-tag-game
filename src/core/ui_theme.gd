extends Node
## Design tokens + the one Theme resource. Godot's Theme is a token system:
## define it once, every Control inherits it, exactly like CSS variables.

var display: SystemFont
var body: SystemFont
var mono: SystemFont
var theme: Theme


func _ready() -> void:
	display = SystemFont.new()
	display.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Times New Roman"])
	display.font_weight = 700
	display.antialiasing = TextServer.FONT_ANTIALIASING_GRAY

	body = SystemFont.new()
	body.font_names = PackedStringArray(["Segoe UI", "Helvetica Neue", "Arial"])
	body.font_weight = 400
	body.antialiasing = TextServer.FONT_ANTIALIASING_GRAY

	mono = SystemFont.new()
	mono.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Courier New"])
	mono.antialiasing = TextServer.FONT_ANTIALIASING_GRAY

	theme = _build()


func box(bg: Color, radius: int = 14, border: int = 0, border_color: Color = Color(1, 1, 1, 0.1)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.border_width_left = border
	sb.border_width_top = border
	sb.border_width_right = border
	sb.border_width_bottom = border
	sb.border_color = border_color
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.anti_aliasing = true
	return sb


func _build() -> Theme:
	var t := Theme.new()
	t.default_font = body
	t.default_font_size = 17

	var normal := box(Color(0, 0, 0, 0), 10, 1, Color(1, 1, 1, 0.14))
	var hover := box(Color(0.91, 0.69, 0.29, 0.10), 10, 1, Color(0.91, 0.69, 0.29, 0.55))
	var pressed := box(Color(0.91, 0.69, 0.29, 0.20), 10, 1, Color(0.91, 0.69, 0.29, 0.85))
	var focus := box(Color(0, 0, 0, 0), 10, 1, Color(0.91, 0.69, 0.29, 0.9))

	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.03), 10))
	t.set_color("font_color", "Button", Cfg.CREAM)
	t.set_color("font_hover_color", "Button", Cfg.GOLD)
	t.set_color("font_pressed_color", "Button", Cfg.GOLD)
	t.set_color("font_focus_color", "Button", Cfg.GOLD)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.25))
	t.set_font_size("font_size", "Button", 18)

	t.set_color("font_color", "Label", Cfg.CREAM)
	t.set_font_size("font_size", "Label", 17)

	t.set_stylebox("panel", "PanelContainer", box(Cfg.PANEL, 18, 1, Color(1, 1, 1, 0.07)))

	t.set_color("font_color", "RichTextLabel", Cfg.CREAM)
	t.set_font_size("normal_font_size", "RichTextLabel", 17)

	t.set_stylebox("normal", "LineEdit", box(Color(0, 0, 0, 0.25), 10, 1, Color(1, 1, 1, 0.12)))
	t.set_color("font_color", "LineEdit", Cfg.CREAM)

	return t


func label(text: String, size: int = 17, color: Color = Cfg.CREAM, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


func caps(text: String, color: Color = Cfg.MUTED) -> Label:
	var l := label(text, 12, color)
	l.add_theme_constant_override("line_spacing", 0)
	# letter-spacing via a wide font size + manual spaces keeps it dependency-free
	l.text = "  ".join(text.to_upper().split(""))
	return l


func hairline(width: float = 0.0, color: Color = Cfg.HAIRLINE) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(width, 1)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
