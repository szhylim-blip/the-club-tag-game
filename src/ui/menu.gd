class_name MenuScreen
extends Control
## Front door: a real game-select screen. Quick Play starts TAG immediately;
## each card starts its own mode; the Club and online entry are separate actions.

signal join_pressed
signal exit_pressed
signal customise_pressed
signal online_pressed
signal mode_pressed(mode: String)

const MODES := [
	{"id": "tag", "title": "TAG", "sub": "Pass IT. Own the floor.", "meta": "THE FLOOR  ·  105 SEC", "col": Cfg.GOLD},
	{"id": "hush", "title": "HUSH", "sub": "One seeker. One house. Hide.", "meta": "THE HOUSE  ·  95 SEC", "col": Color("#8fb6ff")},
	{"id": "infection", "title": "INFECTION", "sub": "Every touch turns a runner.", "meta": "THE FLOOR  ·  100 SEC", "col": Cfg.CORAL},
	{"id": "potato", "title": "HOT POTATO", "sub": "Nine seconds. Pass it on.", "meta": "THE FLOOR  ·  90 SEC", "col": Color("#ff9d5c")},
]

var _bg: ColorRect
var _left: VBoxContainer
var _right: VBoxContainer
var _title: Label
var _time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.theme
	mouse_filter = Control.MOUSE_FILTER_STOP

	_bg = ColorRect.new()
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/shaders/menu_bg.gdshader")
	_bg.material = mat
	add_child(_bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_top", 46)
	margin.add_theme_constant_override("margin_bottom", 42)
	add_child(margin)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 58)
	margin.add_child(cols)

	# --- left: identity + primary actions ---------------------------------
	_left = VBoxContainer.new()
	_left.alignment = BoxContainer.ALIGNMENT_CENTER
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.size_flags_stretch_ratio = 0.88
	_left.add_theme_constant_override("separation", 0)
	cols.add_child(_left)

	var kicker := Style.label("SEASON 01  ·  MEMBERS ONLY  ·  04 MODES", 12, Cfg.GOLD)
	kicker.add_theme_font_override("font", Style.mono)
	_left.add_child(kicker)

	var pad_top := Control.new()
	pad_top.custom_minimum_size = Vector2(0, 10)
	_left.add_child(pad_top)

	_title = Style.label("THE CLUB", 84, Cfg.CREAM, Style.display)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.add_child(_title)

	var rule := Style.hairline(0, Color(0.91, 0.69, 0.29, 0.55))
	rule.custom_minimum_size = Vector2(220, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_left.add_child(rule)

	var tag := Style.label("A 3D party game for people who cannot be trusted.", 16, Cfg.MUTED)
	tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag.custom_minimum_size = Vector2(0, 46)
	_left.add_child(tag)

	var pad_a := Control.new()
	pad_a.custom_minimum_size = Vector2(0, 24)
	_left.add_child(pad_a)

	var quick := ClubButton.new()
	quick.label_text = "QUICK PLAY  ·  TAG"
	quick.big = true
	quick.primary = true
	quick.custom_minimum_size = Vector2(340, 62)
	quick.add_theme_font_size_override("font_size", 21)
	quick.pressed.connect(func(): mode_pressed.emit("tag"))
	_left.add_child(quick)

	var pad_b := Control.new()
	pad_b.custom_minimum_size = Vector2(0, 10)
	_left.add_child(pad_b)

	var club := ClubButton.new()
	club.label_text = "ENTER THE CLUB"
	club.custom_minimum_size = Vector2(340, 50)
	club.pressed.connect(func(): join_pressed.emit())
	_left.add_child(club)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	_left.add_child(gap)

	var online := ClubButton.new()
	online.label_text = "PLAY ONLINE  ·  DIRECT IP"
	online.custom_minimum_size = Vector2(340, 50)
	online.pressed.connect(func(): online_pressed.emit())
	_left.add_child(online)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 18)
	_left.add_child(gap2)

	var small := HBoxContainer.new()
	small.add_theme_constant_override("separation", 10)
	_left.add_child(small)
	var custom := ClubButton.new()
	custom.label_text = "CUSTOMISE"
	custom.custom_minimum_size = Vector2(164, 40)
	custom.add_theme_font_size_override("font_size", 13)
	custom.pressed.connect(func(): customise_pressed.emit())
	small.add_child(custom)
	var quit := ClubButton.new()
	quit.label_text = "EXIT"
	quit.custom_minimum_size = Vector2(120, 40)
	quit.add_theme_font_size_override("font_size", 13)
	quit.pressed.connect(func(): exit_pressed.emit())
	small.add_child(quit)

	# --- right: game select ------------------------------------------------
	_right = VBoxContainer.new()
	_right.alignment = BoxContainer.ALIGNMENT_CENTER
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right.size_flags_stretch_ratio = 1.12
	_right.add_theme_constant_override("separation", 12)
	cols.add_child(_right)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	_right.add_child(head)
	var sel := Style.label("SELECT A GAME", 13, Cfg.MUTED)
	sel.add_theme_font_override("font", Style.mono)
	head.add_child(sel)
	var line := Style.hairline()
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(line)
	var count := Style.label("04", 13, Cfg.GOLD)
	count.add_theme_font_override("font", Style.mono)
	head.add_child(count)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_right.add_child(grid)
	for i in MODES.size():
		var m: Dictionary = MODES[i]
		var card := MenuModeCard.new()
		card.title_text = str(m["title"])
		card.subtitle_text = str(m["sub"])
		card.meta_text = str(m["meta"])
		card.accent = m["col"]
		card.index_text = "%02d" % (i + 1)
		card.pressed.connect(_emit_mode.bind(str(m["id"])))
		grid.add_child(card)

	var how := PanelContainer.new()
	how.add_theme_stylebox_override("panel",
		Style.box(Color(0.045, 0.038, 0.068, 0.76), 10, 1, Color(1, 1, 1, 0.06)))
	_right.add_child(how)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 18)
	how.add_child(hh)
	for pair in [["01", "PICK A GAME"], ["02", "DEPLOY INTO THE CLUB"], ["03", "DON'T GET TAGGED"]]:
		var step := VBoxContainer.new()
		step.add_theme_constant_override("separation", 0)
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hh.add_child(step)
		var num := Style.label(pair[0], 11, Cfg.GOLD)
		num.add_theme_font_override("font", Style.mono)
		step.add_child(num)
		var txt := Style.label(pair[1], 12, Cfg.CREAM)
		txt.add_theme_font_override("font", Style.mono)
		step.add_child(txt)

	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel",
		Style.box(Color(0.06, 0.05, 0.085, 0.86), 10, 1, Color(1, 1, 1, 0.07)))
	_right.add_child(strip)
	var striph := HBoxContainer.new()
	striph.add_theme_constant_override("separation", 14)
	strip.add_child(striph)
	var live := Style.label("BOTS READY", 11, Cfg.MINT)
	live.add_theme_font_override("font", Style.mono)
	striph.add_child(live)
	var dot := Style.label("·", 11, Cfg.MUTED)
	dot.add_theme_font_override("font", Style.mono)
	striph.add_child(dot)
	var info := Style.label("4 MODES  ·  2 MAPS  ·  ONLINE VIA DIRECT IP", 11, Cfg.MUTED)
	info.add_theme_font_override("font", Style.mono)
	striph.add_child(info)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	striph.add_child(fill)
	var controls := Style.label("WASD  ·  SHIFT  ·  CTRL  ·  SPACE  ·  Q", 10,
		Color(1, 1, 1, 0.30))
	controls.add_theme_font_override("font", Style.mono)
	striph.add_child(controls)

	var foot := Style.label("THE FLOOR  ·  THE HOUSE  ·  THE CLUB  ·  F11 FULLSCREEN", 10,
		Color(1, 1, 1, 0.28))
	foot.add_theme_font_override("font", Style.mono)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_right.add_child(foot)

	_intro()


func _emit_mode(mode: String) -> void:
	mode_pressed.emit(mode)


func _intro() -> void:
	_left.modulate.a = 0.0
	_right.modulate.a = 0.0
	_left.position.y += 12.0
	_right.position.y += 12.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_left, "modulate:a", 1.0, 0.45)
	tw.tween_property(_right, "modulate:a", 1.0, 0.55).set_delay(0.06)
	tw.tween_property(_left, "position:y", _left.position.y - 12.0, 0.6)
	tw.tween_property(_right, "position:y", _right.position.y - 12.0, 0.6).set_delay(0.06)


func _process(dt: float) -> void:
	_time += dt
	if _title:
		_title.modulate = Color(1, 1, 1, 0.94 + sin(_time * 1.2) * 0.04)
