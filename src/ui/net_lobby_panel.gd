class_name NetLobbyPanel
extends Control
## The lobby controls, living inside the 3D Club instead of replacing it.
## Host picks map/mode and starts; members toggle ready. Everything here reads
## and writes the same Net state the old full-screen panel used.

signal leave_pressed

var _roster: VBoxContainer
var _status: Label
var _start: ClubButton
var _ready_btn: ClubButton
var _map_row: HBoxContainer
var _mode_row: HBoxContainer
var _map_lbl: Label
var _mode_lbl: Label
var _mode_buttons: Dictionary = {}
var _cam_row: HBoxContainer
var _cam_lbl: Label
var _cam_buttons: Dictionary = {}
var _auto_wait := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.theme

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 26
	panel.offset_top = -434
	panel.offset_right = 486
	panel.offset_bottom = -26
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel",
		Style.box(Color(0.05, 0.045, 0.075, 0.9), 16, 1, Color(1, 1, 1, 0.10)))
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var kicker := Style.label("ONLINE · IN THE CLUB", 11, Cfg.GOLD)
	kicker.add_theme_font_override("font", Style.mono)
	v.add_child(kicker)
	v.add_child(Style.label("THE LOBBY", 30, Cfg.CREAM, Style.display))
	_status = Style.label("", 11, Cfg.MUTED)
	_status.add_theme_font_override("font", Style.mono)
	v.add_child(_status)

	_roster = VBoxContainer.new()
	_roster.add_theme_constant_override("separation", 2)
	v.add_child(_roster)
	v.add_child(Style.hairline())

	_map_row = HBoxContainer.new()
	_map_row.add_theme_constant_override("separation", 6)
	v.add_child(_map_row)
	_map_row.add_child(_tag("MAP"))
	var map_floor := _button("THE FLOOR", 132, 32)
	map_floor.pressed.connect(func(): Net.request_config("floor", Net.mode_id))
	_map_row.add_child(map_floor)
	var map_house := _button("THE HOUSE", 132, 32)
	map_house.pressed.connect(func(): Net.request_config("house", Net.mode_id))
	_map_row.add_child(map_house)
	_map_lbl = Style.label("", 11, Cfg.MUTED)
	_map_lbl.add_theme_font_override("font", Style.mono)
	_map_row.add_child(_map_lbl)

	_mode_row = HBoxContainer.new()
	_mode_row.add_theme_constant_override("separation", 5)
	v.add_child(_mode_row)
	_mode_row.add_child(_tag("MODE"))
	for pair in [["tag", "TAG"], ["hush", "HUSH"], ["infection", "INFECT"], ["potato", "POTATO"]]:
		var mid: String = pair[0]
		var b := _button(pair[1], 86, 30)
		b.pressed.connect(func(): Net.request_config(Net.map_id, mid))
		_mode_row.add_child(b)
		_mode_buttons[mid] = b
	_mode_lbl = Style.label("", 11, Cfg.MUTED)
	_mode_lbl.add_theme_font_override("font", Style.mono)
	_mode_row.add_child(_mode_lbl)

	_cam_row = HBoxContainer.new()
	_cam_row.add_theme_constant_override("separation", 5)
	v.add_child(_cam_row)
	_cam_row.add_child(_tag("CAM"))
	for pair in [["first", "FIRST"], ["third", "THIRD"], ["player", "PLAYER"]]:
		var cid: String = pair[0]
		var cb := _button(pair[1], 92, 30)
		cb.pressed.connect(func(): Net.request_config(Net.map_id, Net.mode_id, cid))
		_cam_row.add_child(cb)
		_cam_buttons[cid] = cb
	_cam_lbl = Style.label("", 11, Cfg.MUTED)
	_cam_lbl.add_theme_font_override("font", Style.mono)
	_cam_row.add_child(_cam_lbl)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	v.add_child(actions)
	_start = _button("START ROUND", 170, 42)
	_start.big = true
	_start.pressed.connect(func(): Net.start_round())
	actions.add_child(_start)
	_ready_btn = _button("READY", 120, 40)
	_ready_btn.pressed.connect(func(): Net.set_ready(not Net.is_ready(Net.local_id)))
	actions.add_child(_ready_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var leave := _button("LEAVE", 84, 40)
	leave.pressed.connect(func(): leave_pressed.emit())
	actions.add_child(leave)

	var hint := Style.label("WASD walk · TAB cursor · ENTER start · R ready · ESC leave", 11,
		Color(1, 1, 1, 0.32))
	hint.add_theme_font_override("font", Style.mono)
	v.add_child(hint)

	Net.roster_changed.connect(_refresh)
	Net.config_changed.connect(_refresh)
	Net.status.connect(func(t: String): _status.text = t)
	_refresh()


func _tag(text: String) -> Label:
	var l := Style.label(text, 10, Cfg.MUTED)
	l.add_theme_font_override("font", Style.mono)
	l.custom_minimum_size = Vector2(38, 0)
	return l


func _button(text: String, w: float, h: float) -> ClubButton:
	var b := ClubButton.new()
	b.label_text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 14)
	return b


func _process(dt: float) -> void:
	if not Net.is_host or not Net.auto_start:
		return
	if Net.all_ready() and Net.players.size() >= Net.min_auto:
		_auto_wait += dt
		if _auto_wait > 1.0:
			_auto_wait = -999.0
			Net.start_round()
	else:
		_auto_wait = 0.0


func _refresh() -> void:
	if _status == null:
		return
	if Net.is_host:
		_status.text = "HOSTING · UDP %d · %s" % [Net.PORT, _local_ip()]
	else:
		_status.text = "MEMBER · %d IN THE CLUB" % Net.players.size()
	if Net.running:
		_status.text += " · ROUND STARTING"

	for child in _roster.get_children():
		child.queue_free()
	var ids := Net.players.keys()
	ids.sort()
	for id: int in ids:
		var p: Dictionary = Net.players[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var who := Style.label(str(p.get("name", "MEMBER")), 14,
			Cfg.GOLD if int(id) == 1 else Cfg.CREAM)
		who.custom_minimum_size = Vector2(190, 0)
		row.add_child(who)
		var tag := "HOST" if int(id) == 1 else "MEMBER"
		row.add_child(Style.label(tag, 10, Cfg.MUTED))
		var is_ready := bool(p.get("ready", false)) or int(id) == 1
		var st := Style.label("READY" if is_ready else "WAITING", 10,
			Cfg.MINT if is_ready else Cfg.MUTED)
		st.add_theme_font_override("font", Style.mono)
		row.add_child(st)
		_roster.add_child(row)

	_map_row.visible = Net.is_host
	_mode_row.visible = Net.is_host
	_map_lbl.visible = not Net.is_host
	_map_lbl.text = "THE HOUSE" if Net.map_id == "house" else "THE FLOOR"
	_mode_lbl.visible = not Net.is_host
	_mode_lbl.text = Net.mode_id.to_upper()
	for id: String in _mode_buttons:
		var mb: ClubButton = _mode_buttons[id]
		mb.add_theme_color_override("font_color", Cfg.GOLD if Net.mode_id == id else Cfg.CREAM)
	# Clients still see the session camera; they just cannot change it.
	_cam_row.visible = true
	_cam_lbl.visible = not Net.is_host
	_cam_lbl.text = Net.camera_mode.to_upper()
	for id: String in _cam_buttons:
		var cb: ClubButton = _cam_buttons[id]
		cb.visible = Net.is_host
		cb.add_theme_color_override("font_color", Cfg.GOLD if Net.camera_mode == id else Cfg.CREAM)

	_start.visible = Net.is_host
	_start.disabled = not Net.all_ready()
	_start.label_text = "START ROUND" if Net.all_ready() else "WAITING FOR READY"
	_ready_btn.visible = not Net.is_host
	_ready_btn.label_text = "UNREADY" if Net.is_ready(Net.local_id) else "READY"


func _local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			return a
	return "127.0.0.1"
