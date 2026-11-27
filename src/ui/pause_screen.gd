class_name PauseScreen
extends Control
## Pausing should not throw the round away. Esc opens this; every option is
## explicit, and the round is frozen underneath.

signal resume_pressed
signal restart_pressed
signal loadout_pressed
signal leave_pressed
signal menu_pressed

var _title: Label
var _sub: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Style.theme
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.025, 0.02, 0.04, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel",
		Style.box(Color(0.065, 0.052, 0.09, 0.98), 18, 1, Color(1, 1, 1, 0.10)))
	cc.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var kicker := Style.label("MATCH PAUSED", 11, Cfg.GOLD)
	kicker.add_theme_font_override("font", Style.mono)
	v.add_child(kicker)
	_title = Style.label("HOLD", 48, Cfg.CREAM, Style.display)
	v.add_child(_title)
	_sub = Style.label("", 12, Cfg.MUTED)
	_sub.add_theme_font_override("font", Style.mono)
	v.add_child(_sub)
	v.add_child(Style.hairline())

	var resume := ClubButton.new()
	resume.label_text = "RESUME"
	resume.primary = true
	resume.big = true
	resume.custom_minimum_size = Vector2(0, 56)
	resume.pressed.connect(func(): resume_pressed.emit())
	v.add_child(resume)

	var restart := ClubButton.new()
	restart.label_text = "RESTART ROUND"
	restart.custom_minimum_size = Vector2(0, 46)
	restart.pressed.connect(func(): restart_pressed.emit())
	v.add_child(restart)

	var loadout := ClubButton.new()
	loadout.label_text = "CUSTOMISE"
	loadout.custom_minimum_size = Vector2(0, 46)
	loadout.pressed.connect(func(): loadout_pressed.emit())
	v.add_child(loadout)

	var leave := ClubButton.new()
	leave.label_text = "LEAVE TO CLUB"
	leave.custom_minimum_size = Vector2(0, 46)
	leave.pressed.connect(func(): leave_pressed.emit())
	v.add_child(leave)

	var menu := ClubButton.new()
	menu.label_text = "MAIN MENU"
	menu.custom_minimum_size = Vector2(0, 46)
	menu.pressed.connect(func(): menu_pressed.emit())
	v.add_child(menu)

	var hint := Style.label("ESC RESUME  ·  THE ROUND IS FROZEN", 10, Color(1, 1, 1, 0.30))
	hint.add_theme_font_override("font", Style.mono)
	v.add_child(hint)


func setup(mode_title: String, time_left: float) -> void:
	_title.text = mode_title
	_sub.text = "%d:%02d REMAINING  ·  THE ROUND IS FROZEN" % [
		int(time_left) / 60, int(time_left) % 60]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		if key == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			resume_pressed.emit()
		elif key == KEY_C:
			get_viewport().set_input_as_handled()
			loadout_pressed.emit()
