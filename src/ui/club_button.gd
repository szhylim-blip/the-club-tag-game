class_name ClubButton
extends Button
## A button with a real interaction model: hover lift, gold sweep, press squash,
## focus ring, and sound. Every state is authored — nothing defaults to grey.

var label_text := ""
var big := false
var primary := false
var _sweep: ColorRect
var _tween: Tween


func _ready() -> void:
	flat = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	text = label_text
	if big:
		custom_minimum_size = Vector2(260, 58)
		add_theme_font_size_override("font_size", 22)
	else:
		custom_minimum_size = Vector2(220, 46)
	if primary:
		add_theme_stylebox_override("normal", Style.box(Cfg.GOLD, 10, 1, Cfg.GOLD))
		add_theme_stylebox_override("hover", Style.box(Color("#f3cb78"), 10, 1, Color("#ffe3a3")))
		add_theme_stylebox_override("pressed", Style.box(Color("#d6a044"), 10, 1, Cfg.GOLD))
		add_theme_color_override("font_color", Cfg.INK)
		add_theme_color_override("font_hover_color", Cfg.INK)
		add_theme_color_override("font_pressed_color", Cfg.INK)
	pivot_offset = custom_minimum_size * 0.5
	clip_contents = false

	_sweep = ColorRect.new()
	_sweep.color = Cfg.INK if primary else Cfg.GOLD
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sweep.size = Vector2(0, 2)
	_sweep.position = Vector2(16, 0)
	add_child(_sweep)
	resized.connect(_on_resized)
	_on_resized()

	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_unhover)
	focus_entered.connect(_on_hover)
	focus_exited.connect(_on_unhover)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	pressed.connect(func(): Sfx.play("click", -8.0, randf_range(0.98, 1.03)))


func _on_hover() -> void:
	if disabled:
		return
	Sfx.play("hover", -18.0, randf_range(0.98, 1.05))
	_animate(1.018, Cfg.INK if primary else Cfg.GOLD)
	if _sweep:
		var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sweep, "size:x", maxf(0.0, size.x - 32.0), 0.18)


func _on_unhover() -> void:
	_animate(1.0, Cfg.INK if primary else Cfg.CREAM)
	if _sweep:
		var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_sweep, "size:x", 0.0, 0.14)


func _on_resized() -> void:
	pivot_offset = size * 0.5
	if _sweep:
		_sweep.position = Vector2(16, size.y - 3)


func _on_down() -> void:
	_animate(0.985, Cfg.INK if primary else Cfg.GOLD)


func _on_up() -> void:
	_animate(1.018, Cfg.INK if primary else Cfg.GOLD)


func _animate(scale_to: float, color: Color) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2(scale_to, scale_to), 0.12)
	_tween.tween_property(self, "modulate", Color.WHITE, 0.12)
	add_theme_color_override("font_color", color)
