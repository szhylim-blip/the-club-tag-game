class_name VictoryScreen
extends Control
## No one has to press continue. The round closes itself, on a timer, with
## awards and a payout — the player can skip their own wait or leave early.

signal continue_pressed

var _panel: PanelContainer
var _bar: ColorRect
var _bar_bg: ColorRect
var _auto := 12.0
var _left := 12.0
var _done := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	theme = Style.theme
	mouse_filter = Control.MOUSE_FILTER_STOP

	var vs := get_viewport_rect().size
	size = vs

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.06, 0.74)
	dim.position = Vector2.ZERO
	dim.size = vs
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.position = Vector2(vs.x * 0.5 - 330.0, vs.y * 0.5 - 286.0)
	_panel.size = Vector2(660, 572)
	_panel.custom_minimum_size = Vector2(660, 0)
	_panel.add_theme_stylebox_override("panel", Style.box(Color(0.086, 0.071, 0.114, 0.98), 20, 1, Color(1, 1, 1, 0.09)))
	add_child(_panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	_panel.add_child(v)

	v.add_child(Style.label("ROUND OVER", 12, Cfg.GOLD))
	var title := Style.label("THE FLOOR", 46, Cfg.CREAM, Style.display)
	title.name = "Title"
	v.add_child(title)
	var result := Style.label("", 17, Cfg.MINT)
	result.name = "Result"
	v.add_child(result)
	v.add_child(Style.hairline())

	var list := VBoxContainer.new()
	list.name = "List"
	list.add_theme_constant_override("separation", 8)
	v.add_child(list)

	v.add_child(Style.hairline())

	var awards := Style.label("", 14, Cfg.MUTED)
	awards.name = "Awards"
	awards.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	awards.custom_minimum_size = Vector2(600, 0)
	v.add_child(awards)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	v.add_child(gap)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)

	var cont := ClubButton.new()
	cont.label_text = "CONTINUE"
	cont.big = true
	cont.custom_minimum_size = Vector2(220, 54)
	cont.pressed.connect(_finish)
	row.add_child(cont)

	var note := Style.label("auto-continues in 12s", 13, Cfg.MUTED)
	note.name = "Note"
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(note)

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(1, 1, 1, 0.1)
	_bar_bg.custom_minimum_size = Vector2(600, 2)
	v.add_child(_bar_bg)

	_bar = ColorRect.new()
	_bar.color = Cfg.GOLD
	_bar.size = Vector2(0, 2)
	_bar.position = Vector2.ZERO
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bg.add_child(_bar)


func setup(rows: Array, result_text: String = "", mode_title: String = "THE FLOOR") -> void:
	var title := _panel.find_child("Title", true, false) as Label
	if title != null:
		title.text = mode_title
	var result := _panel.find_child("Result", true, false) as Label
	if result != null:
		result.text = result_text
	var list := _panel.find_child("List", true, false) as VBoxContainer
	if list == null:
		return
	for i in mini(rows.size(), 8):
		var r: Dictionary = rows[i]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)

		var rank := Style.label("%02d" % (i + 1), 14, Cfg.MUTED)
		rank.add_theme_font_override("font", Style.mono)
		rank.custom_minimum_size = Vector2(34, 0)
		h.add_child(rank)

		var is_me: bool = r.get("is_player", false)
		var nm := Style.label(str(r.get("name", "")), 20 if is_me else 17,
			Cfg.GOLD if is_me else r.get("color", Cfg.CREAM), Style.display if is_me else Style.body)
		nm.custom_minimum_size = Vector2(300, 0)
		h.add_child(nm)

		var status := str(r.get("status", ""))
		var tags := Style.label(status if status != "" else "%d TAGS" % int(r.get("tags", 0)), 13, Cfg.MUTED)
		tags.add_theme_font_override("font", Style.mono)
		tags.custom_minimum_size = Vector2(90, 0)
		h.add_child(tags)

		var sc := Style.label(str(int(r.get("score", 0))), 20, Cfg.CREAM)
		sc.add_theme_font_override("font", Style.mono)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(sc)

		list.add_child(h)
		if i == 0:
			var rule := Style.hairline(0, Color(0.91, 0.69, 0.29, 0.25))
			rule.custom_minimum_size = Vector2(0, 1)
			list.add_child(rule)

	# awards: derive from the table so they're never generic
	var awards := _panel.find_child("Awards", true, false) as Label
	if awards != null and rows.size() > 0:
		var top: Dictionary = rows[0]
		var most_tags := 0
		var tagger := "NOBODY"
		for r: Dictionary in rows:
			if int(r.get("tags", 0)) > most_tags:
				most_tags = int(r.get("tags", 0))
				tagger = str(r.get("name", ""))
		awards.text = "MOST TAGS  %s (%d)     ·     TOP SCORE  %s (%d)     ·     SNAIL OF THE MATCH  %s" % [
			tagger, most_tags, str(top.get("name", "")), int(top.get("score", 0)),
			"YOU" if _player_last(rows) else "MEMBER 3",
		]


func _player_last(rows: Array) -> bool:
	for r: Dictionary in rows:
		if r.get("is_player", false):
			return int(r.get("tags", 0)) == 0
	return false


func _process(dt: float) -> void:
	if _done:
		return
	_left -= dt
	var t := clampf(1.0 - _left / _auto, 0.0, 1.0)
	_bar.size = Vector2(_bar_bg.size.x * t, 2)
	var note := _panel.find_child("Note", true, false) as Label
	if note != null:
		note.text = "auto-continues in %ds" % maxi(0, int(ceil(_left)))
	if _left <= 0.0:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	Sfx.play("click", -8.0, 1.0)
	continue_pressed.emit()
