class_name Hud
extends Control
## In-round HUD. Laid out in absolute pixels against the live viewport rect —
## deterministic at any window size, no anchor surprises.

var match: Match

var _post: ColorRect
var _lines: ColorRect
var _role: Label
var _timer: Label
var _score: Label
var _mode_lbl: Label
var _objective: Label
var _feed: VBoxContainer
var _intro_panel: PanelContainer
var _intro_kicker: Label
var _intro_big: Label
var _intro_small: Label
var _toast: Label
var _chip: AbilityChip
var _ability_lbl: Label
var _role1_lbl: Label
var _role2_lbl: Label
var _hint: Label
var _chaser: Label
var _cross: Crosshair
var _toast_tween: Tween
var _hurt := 0.0
var _heart := 0.0
var _elapsed := 0.0
var _dash_t := 0.0


class Crosshair extends Control:
	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 1.9, Color(0.98, 0.96, 0.92, 0.92))
		for i in 4:
			var dir := Vector2.RIGHT.rotated(TAU * 0.25 * i)
			draw_line(c + dir * 7.0, c + dir * 11.0, Color(1, 1, 1, 0.32), 1.0)


class AbilityChip extends Control:
	var ratio := 0.0
	var is_it := false

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, 24.0, Color(0, 0, 0, 0.42))
		draw_arc(c, 24.0, 0.0, TAU, 48, Color(1, 1, 1, 0.16), 2.0, true)
		var ready := 1.0 - ratio
		if ready > 0.001:
			draw_arc(c, 24.0, -PI * 0.5, -PI * 0.5 + TAU * ready, 48,
				Cfg.CORAL if is_it else Cfg.GOLD, 3.0, true)
		var font := ThemeDB.fallback_font
		draw_string(font, c + Vector2(-5, 6), "Q", HORIZONTAL_ALIGNMENT_LEFT, -1, 15,
			Cfg.CREAM if ready > 0.99 else Color(1, 1, 1, 0.5))


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_post = ColorRect.new()
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://src/shaders/post.gdshader")
	_post.material = pm
	add_child(_post)

	_lines = ColorRect.new()
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lm := ShaderMaterial.new()
	lm.shader = load("res://src/shaders/speedlines.gdshader")
	_lines.material = lm
	add_child(_lines)

	_score = Style.label("SCORE 0", 15, Cfg.CREAM)
	_score.add_theme_font_override("font", Style.mono)
	_score.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_score)

	_mode_lbl = Style.label("", 12, Cfg.MUTED)
	_mode_lbl.add_theme_font_override("font", Style.mono)
	_mode_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_mode_lbl)

	_objective = Style.label("", 11, Color(1, 1, 1, 0.42))
	_objective.add_theme_font_override("font", Style.mono)
	_objective.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_objective)

	_timer = Style.label("2:00", 34, Cfg.CREAM, Style.mono)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_timer)

	_role = Style.label("RUN", 14, Cfg.MINT)
	_role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_role)

	_chaser = Style.label("", 13, Cfg.CORAL)
	_chaser.add_theme_font_override("font", Style.mono)
	_chaser.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_chaser.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_chaser)

	_cross = Crosshair.new()
	_cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cross)

	_chip = AbilityChip.new()
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_chip)

	_ability_lbl = Style.label("Q DASH", 11, Cfg.MUTED)
	_ability_lbl.add_theme_font_override("font", Style.mono)
	add_child(_ability_lbl)

	_role1_lbl = Style.label("E SCAN", 11, Cfg.MUTED)
	_role1_lbl.add_theme_font_override("font", Style.mono)
	add_child(_role1_lbl)

	_role2_lbl = Style.label("F TRAP", 11, Cfg.MUTED)
	_role2_lbl.add_theme_font_override("font", Style.mono)
	add_child(_role2_lbl)

	_hint = Style.label("SHIFT SPRINT  ·  CTRL SLIDE  ·  SPACE JUMP  ·  Q DASH", 11, Cfg.MUTED)
	_hint.add_theme_font_override("font", Style.mono)
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_hint)

	_feed = VBoxContainer.new()
	_feed.add_theme_constant_override("separation", 6)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)

	_toast = Style.label("", 32, Cfg.GOLD, Style.display)
	_toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	_toast.add_theme_constant_override("shadow_offset_x", 2)
	_toast.add_theme_constant_override("shadow_offset_y", 2)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	add_child(_toast)

	_intro_panel = PanelContainer.new()
	_intro_panel.add_theme_stylebox_override("panel",
		Style.box(Color(0.035, 0.028, 0.058, 0.97), 18, 1, Color(0.91, 0.69, 0.29, 0.35)))
	_intro_panel.visible = false
	add_child(_intro_panel)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 0)
	_intro_panel.add_child(iv)
	_intro_kicker = Style.label("ROUND START", 11, Cfg.GOLD)
	_intro_kicker.add_theme_font_override("font", Style.mono)
	_intro_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	iv.add_child(_intro_kicker)
	_intro_big = Style.label("", 104, Cfg.CREAM, Style.display)
	_intro_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_big.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_big.custom_minimum_size = Vector2(0, 118)
	iv.add_child(_intro_big)
	_intro_small = Style.label("", 13, Cfg.GOLD)
	_intro_small.add_theme_font_override("font", Style.mono)
	_intro_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_small.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	iv.add_child(_intro_small)

	_relayout()
	get_viewport().size_changed.connect(_relayout)


func _relayout() -> void:
	var vs := get_viewport_rect().size
	size = vs
	_post.position = Vector2.ZERO
	_post.size = vs
	_lines.position = Vector2.ZERO
	_lines.size = vs

	_score.position = Vector2(34, 20)
	_score.size = Vector2(320, 26)
	_mode_lbl.position = Vector2(34, 48)
	_mode_lbl.size = Vector2(520, 20)
	_objective.position = Vector2(34, 70)
	_objective.size = Vector2(560, 20)

	_feed.position = Vector2(vs.x - 376.0, 88.0)
	_feed.size = Vector2(336, 260)

	_timer.position = Vector2(vs.x * 0.5 - 130.0, 12.0)
	_timer.size = Vector2(260, 44)

	_role.position = Vector2(vs.x * 0.5 - 130.0, 58.0)
	_role.size = Vector2(260, 22)

	_chaser.position = Vector2(vs.x - 334.0, vs.y - 50.0)
	_chaser.size = Vector2(300, 24)

	_cross.position = Vector2(vs.x * 0.5 - 20.0, vs.y * 0.5 - 20.0)
	_cross.size = Vector2(40, 40)

	_chip.position = Vector2(38, vs.y - 92.0)
	_chip.size = Vector2(48, 48)
	_ability_lbl.position = Vector2(92, vs.y - 78.0)
	_ability_lbl.size = Vector2(110, 20)
	_role1_lbl.position = Vector2(202, vs.y - 78.0)
	_role1_lbl.size = Vector2(110, 20)
	_role2_lbl.position = Vector2(312, vs.y - 78.0)
	_role2_lbl.size = Vector2(130, 20)

	_hint.position = Vector2(38, vs.y - 34.0)
	_hint.size = Vector2(760, 20)

	_toast.position = Vector2(vs.x * 0.5 - 300.0, 88.0)
	_toast.size = Vector2(600, 44)

	_intro_panel.position = Vector2(vs.x * 0.5 - 350.0, vs.y * 0.31)
	_intro_panel.size = Vector2(700, 242)
	_intro_panel.custom_minimum_size = Vector2(700, 0)


func _process(dt: float) -> void:
	_elapsed += dt
	if match == null or not is_instance_valid(match):
		return

	var is_it := match.player_is_it()
	_timer.text = "%d:%02d" % [int(match.time_left) / 60, int(match.time_left) % 60]
	_timer.add_theme_color_override("font_color", Cfg.CORAL if match.time_left < 20.0 else Cfg.CREAM)

	_role.text = match.player_role_text()
	_role.add_theme_color_override("font_color", match.player_role_color())

	_mode_lbl.text = "%s   ·   %s" % [match.mode_title, match.mode_status()]
	_objective.text = match.mode_objective()
	_score.text = ("SCORE %d" % int(match.get_player_score())) if match.mode_id == "tag" else ""

	var intro := float(match.get("intro_left"))
	var intro_on := intro > 0.0
	_intro_panel.visible = intro_on
	if intro_on:
		var n := clampi(ceili(intro), 1, 3)
		_intro_big.text = "GO" if n <= 1 else str(n)
		_intro_big.modulate.a = 0.70 + 0.30 * absf(sin(intro * 3.2))
		_intro_kicker.text = "ROUND START  ·  %s" % match.mode_title
		_intro_small.text = match.mode_objective()

	_chip.ratio = match.player.get_cooldown_ratio() if match.player else 0.0
	_chip.is_it = is_it
	_chip.queue_redraw()
	if match.player != null:
		var p: ClubPlayer = match.player
		_ability_lbl.text = "Q " + p.primary_ability_name()
		var e_cd := p.role_cooldown_remaining(1)
		var f_cd := p.role_cooldown_remaining(2)
		_role1_lbl.text = "E " + p.role_ability_name(1)
		_role2_lbl.text = "F " + p.role_ability_name(2)
		if e_cd > 0.05:
			_role1_lbl.text += " %.1f" % e_cd
		if f_cd > 0.05:
			_role2_lbl.text += " %.1f" % f_cd

	var dist := match.get_tag_distance()
	if not is_it and dist < 14.0 and match.mode_id != "potato":
		var threat := "CHASER"
		if match.mode_id == "hush":
			threat = "SEEKER"
		elif match.mode_id == "infection":
			threat = "INFECTED"
		_chaser.text = "%s %dm" % [threat, int(dist)]
		_chaser.add_theme_color_override("font_color", Cfg.CORAL)
		_heart -= dt
		if _heart <= 0.0 and dist < 11.0:
			_heart = clampf(dist / 11.0, 0.28, 1.0) * 0.85
			Sfx.play("heart", -20.0 + (1.0 - dist / 11.0) * 6.0, 1.0)
	else:
		_chaser.text = ""

	_hurt = maxf(0.0, _hurt - dt * 1.6)
	var pulse := (0.32 + 0.22 * sin(_elapsed * 3.4)) if is_it else 0.0
	var pm := _post.material as ShaderMaterial
	pm.set_shader_parameter("hurt", _hurt)
	pm.set_shader_parameter("pulse", pulse)
	pm.set_shader_parameter("aberration", 0.20 + _hurt * 1.2 + pulse * 0.4)
	pm.set_shader_parameter("vignette", 0.30 + (0.18 if is_it else 0.0))
	_dash_t = maxf(0.0, _dash_t - dt)
	var dash_amt := clampf(_dash_t / 0.30, 0.0, 1.0)
	pm.set_shader_parameter("dash", dash_amt)

	var speed := match.get_speed()
	var lm := _lines.material as ShaderMaterial
	lm.set_shader_parameter("intensity", clampf((speed - 4.8) / 3.2, 0.0, 1.0))


func toast(text: String, color: Color) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	_toast.modulate.a = 0.0
	if _toast_tween != null and _toast_tween.is_running():
		_toast_tween.kill()
	_toast.scale = Vector2(0.94, 0.94)
	_toast.pivot_offset = _toast.size * 0.5
	_toast_tween = create_tween().set_parallel(true)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.12)
	_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.18)
	_toast_tween.chain().tween_interval(0.7)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, 0.35)


func flash(amount: float = 0.8) -> void:
	_hurt = maxf(_hurt, amount)


## Camera treatment for the dash: radial smear + streak tint for 300 ms.
func dash() -> void:
	_dash_t = 0.30
	_hurt = maxf(_hurt, 0.05)


func set_hint(text: String) -> void:
	_hint.text = text


## A short right-side event card for tags, conversions and objective changes.
func feed(text: String, color: Color = Cfg.CREAM) -> void:
	if _feed == null:
		return
	while _feed.get_child_count() >= 5:
		var old := _feed.get_child(0)
		_feed.remove_child(old)
		old.queue_free()

	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_stylebox_override("panel",
		Style.box(Color(0.055, 0.045, 0.08, 0.92), 8, 1, Color(color.r, color.g, color.b, 0.28)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	row.add_child(h)
	var bar := ColorRect.new()
	bar.color = color
	bar.custom_minimum_size = Vector2(3, 0)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(bar)
	var l := Style.label(text, 13, Cfg.CREAM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)

	_feed.add_child(row)
	row.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(row, "modulate:a", 1.0, 0.12)
	tw.tween_interval(3.8)
	tw.tween_property(row, "modulate:a", 0.0, 0.45)
	tw.tween_callback(row.queue_free)
