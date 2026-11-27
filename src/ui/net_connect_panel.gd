class_name NetConnectPanel
extends Control
## The online entry card, drawn over the 3D Club. It is only a connection form:
## name, host IP, HOST / JOIN / BACK. Once the transport is up it disappears and
## NetLobbyPanel takes over, still in the same Club — there is only one lobby.

signal back_pressed

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status: Label
var _host_btn: ClubButton
var _join_btn: ClubButton


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Style.theme

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 26
	panel.offset_top = -330
	panel.offset_right = 486
	panel.offset_bottom = -26
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel",
		Style.box(Color(0.05, 0.045, 0.075, 0.94), 16, 1, Color(1, 1, 1, 0.10)))
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var kicker := Style.label("ONLINE · DIRECT IP", 11, Cfg.GOLD)
	kicker.add_theme_font_override("font", Style.mono)
	v.add_child(kicker)
	v.add_child(Style.label("PLAY ONLINE", 30, Cfg.CREAM, Style.display))
	_status = Style.label("Host on this machine or join a host by IP.", 12, Cfg.MUTED)
	_status.add_theme_font_override("font", Style.mono)
	v.add_child(_status)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	v.add_child(name_row)
	name_row.add_child(Style.label("NAME", 10, Cfg.MUTED))
	_name_edit = LineEdit.new()
	_name_edit.text = _default_name()
	_name_edit.max_length = 14
	_name_edit.custom_minimum_size = Vector2(220, 38)
	name_row.add_child(_name_edit)

	var ip_row := HBoxContainer.new()
	ip_row.add_theme_constant_override("separation", 8)
	v.add_child(ip_row)
	ip_row.add_child(Style.label("HOST IP", 10, Cfg.MUTED))
	_ip_edit = LineEdit.new()
	_ip_edit.text = "127.0.0.1"
	_ip_edit.custom_minimum_size = Vector2(220, 38)
	_ip_edit.text_submitted.connect(func(_t: String): _join())
	ip_row.add_child(_ip_edit)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	v.add_child(actions)
	_host_btn = _button("HOST GAME", 160, 44)
	_host_btn.big = true
	_host_btn.pressed.connect(_host)
	actions.add_child(_host_btn)
	_join_btn = _button("JOIN GAME", 130, 44)
	_join_btn.pressed.connect(_join)
	actions.add_child(_join_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(spacer)
	var back := _button("BACK", 80, 40)
	back.pressed.connect(func(): back_pressed.emit())
	actions.add_child(back)

	var hint := Style.label("You are standing in the Club. Hosting keeps you here.", 11,
		Color(1, 1, 1, 0.32))
	hint.add_theme_font_override("font", Style.mono)
	v.add_child(hint)

	Net.status.connect(func(t: String): _status.text = t)
	Net.connection_failed.connect(func(t: String): _status.text = t; _busy(false))
	Net.roster_changed.connect(_on_roster)


func _default_name() -> String:
	var env := OS.get_environment("USERNAME")
	if env.strip_edges() != "":
		return env.strip_edges().substr(0, 14)
	return "MEMBER"


func _button(text: String, w: float, h: float) -> ClubButton:
	var b := ClubButton.new()
	b.label_text = text
	b.custom_minimum_size = Vector2(w, h)
	b.add_theme_font_size_override("font_size", 14)
	return b


func _busy(v: bool) -> void:
	_host_btn.disabled = v
	_join_btn.disabled = v


func _host() -> void:
	_busy(true)
	Net.auto_ready = false
	Net.host_game(_name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "HOST")
	_status.text = "HOSTING · UDP %d" % Net.PORT


func _join() -> void:
	_busy(true)
	Net.auto_ready = false
	var ip := _ip_edit.text.strip_edges()
	if ip == "":
		ip = "127.0.0.1"
	Net.join_game(ip, _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "MEMBER")
	_status.text = "CONNECTING TO %s:%d" % [ip, Net.PORT]


func _on_roster() -> void:
	if Net.connected:
		_status.text = "CONNECTED · ENTERING THE CLUB"
