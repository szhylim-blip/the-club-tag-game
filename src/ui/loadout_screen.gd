class_name LoadoutScreen
extends Control
## Every round starts here: pick an ability, a blob tint and silhouette, and the
## camera the host wants. Writes straight into the Loadout autoload and deploys.

signal deploy_pressed
signal back_pressed

const COLORS := [
	Color.WHITE, Color("#f5c542"), Color("#ff725e"), Color("#63d7a2"),
	Color("#5ca8ff"), Color("#b68cff"), Color("#ff8fc7"), Color("#2a2a32"),
]

var _panel: PanelContainer
var _ability_buttons: Dictionary = {}
var _swatches: Array[Button] = []
var _view: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Style.theme

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.025, 0.05, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(860, 0)
	_panel.add_theme_stylebox_override("panel",
		Style.box(Color(0.075, 0.063, 0.10, 0.98), 18, 1, Color(1, 1, 1, 0.09)))
	cc.add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_panel.add_child(v)

	var kicker := Style.label("BEFORE YOU ENTER", 12, Cfg.GOLD)
	kicker.add_theme_font_override("font", Style.mono)
	v.add_child(kicker)
	v.add_child(Style.label("LOADOUT", 52, Cfg.CREAM, Style.display))
	v.add_child(Style.label("Ability, colour and camera are yours. The host can switch view for the room.",
		14, Cfg.MUTED))
	v.add_child(Style.hairline())

	# --- abilities --------------------------------------------------------
	v.add_child(Style.label("ABILITY", 12, Cfg.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for id: String in Loadout.ABILITIES:
		var data: Dictionary = Loadout.ABILITIES[id]
		var b := Button.new()
		b.custom_minimum_size = Vector2(198, 92)
		b.text = "%s\n\n%s" % [data["name"], data["desc"]]
		b.add_theme_font_size_override("font_size", 12)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_select_ability.bind(id))
		b.mouse_entered.connect(func(): Sfx.play("hover", -24.0, 1.0))
		row.add_child(b)
		_ability_buttons[id] = b

	v.add_child(Style.hairline())

	# --- colour ----------------------------------------------------------
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(right)
	right.add_child(Style.label("COLOUR", 12, Cfg.MUTED))
	var sw := HBoxContainer.new()
	sw.add_theme_constant_override("separation", 8)
	right.add_child(sw)
	for c: Color in COLORS:
		var b := Button.new()
		b.custom_minimum_size = Vector2(42, 42)
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(21)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.pressed.connect(_select_color.bind(c))
		sw.add_child(b)
		_swatches.append(b)

	v.add_child(Style.hairline())

	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 18)
	v.add_child(foot)
	_view = Button.new()
	_view.custom_minimum_size = Vector2(240, 44)
	_view.pressed.connect(_toggle_view)
	foot.add_child(_view)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)

	var back := ClubButton.new()
	back.label_text = "BACK"
	back.custom_minimum_size = Vector2(140, 50)
	back.pressed.connect(func(): back_pressed.emit())
	foot.add_child(back)

	var go := ClubButton.new()
	go.label_text = "DEPLOY"
	go.big = true
	go.custom_minimum_size = Vector2(230, 54)
	go.pressed.connect(_deploy)
	foot.add_child(go)

	_refresh()


func _select_ability(id: String) -> void:
	Loadout.ability = id
	Loadout.save_to_disk()
	Sfx.play("click", -10.0, 1.0)
	_refresh()


func _select_color(c: Color) -> void:
	Loadout.body_color = c
	Loadout.save_to_disk()
	Sfx.play("click", -12.0, 1.15)
	_refresh()


func _toggle_view() -> void:
	Loadout.third_person = not Loadout.third_person
	Loadout.save_to_disk()
	Sfx.play("click", -10.0, 0.95)
	_refresh()


func _refresh() -> void:
	for id: String in _ability_buttons:
		var b: Button = _ability_buttons[id]
		var on := Loadout.ability == id
		b.add_theme_stylebox_override("normal", Style.box(
			Color(0.16, 0.13, 0.21, 0.98) if on else Color(0.10, 0.085, 0.135, 0.9),
			10, 1, Cfg.GOLD if on else Color(1, 1, 1, 0.06)))
		b.add_theme_color_override("font_color", Cfg.GOLD if on else Color(0.85, 0.83, 0.9))
	for i in _swatches.size():
		_swatches[i].modulate = Color.WHITE if Loadout.body_color == COLORS[i] else Color(0.62, 0.6, 0.68)
	_view.text = "VIEW  ·  THIRD PERSON" if Loadout.third_person else "VIEW  ·  FIRST PERSON"
	_view.add_theme_color_override("font_color", Cfg.GOLD if Loadout.third_person else Cfg.CREAM)


func _deploy() -> void:
	Sfx.play("confirm", -8.0, 1.0)
	deploy_pressed.emit()
