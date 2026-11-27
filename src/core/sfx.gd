extends Node
## Real recorded audio only. Every cue is a downloaded CC0 OGG (Kenney Impact
## Sounds, Interface Sounds, RPG Audio, Digital, Casino, Jingles) documented in
## ASSETS.md. Nothing here is synthesised at runtime: a missing file is silence.
##
## Cues hold a list of variants; play() picks one at random and jitters pitch and
## volume, so repeated footsteps never sound like one looping sample.

var _bank: Dictionary = {}
var _ui_players: Array[AudioStreamPlayer] = []
var _ui_next := 0
var _rng := RandomNumberGenerator.new()

var _bed := false
var _bed_timer := 0.0

const BED_CUES := ["chip_collide", "card_slide", "chip_stack", "coins"]


func _ready() -> void:
	_rng.randomize()
	_load()
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_ui_players.append(p)
	set_process(false)


func _load() -> void:
	_group("step_concrete", "res://assets/audio/step_concrete_%02d.ogg", 5)
	_group("step_wood", "res://assets/audio/step_wood_%02d.ogg", 5)
	_group("step_grass", "res://assets/audio/step_grass_%02d.ogg", 5)
	_group("step_carpet", "res://assets/audio/step_carpet_%02d.ogg", 5)
	_group("impact_soft", "res://assets/audio/impact_soft_%02d.ogg", 5)
	_group("impact_wood", "res://assets/audio/impact_wood_%02d.ogg", 5)
	_group("impact_metal", "res://assets/audio/impact_metal_%02d.ogg", 5)
	_group("impact_punch", "res://assets/audio/impact_punch_%02d.ogg", 5)
	_group("whoosh", "res://assets/audio/whoosh_%02d.ogg", 4)
	_group("thud", "res://assets/audio/thud_%02d.ogg", 4)
	_group("ui_click", "res://assets/audio/ui_click_%02d.ogg", 5)
	_group("ui_hover", "res://assets/audio/ui_hover_%02d.ogg", 5)
	_group("stinger", "res://assets/audio/stinger_%02d.ogg", 8)
	_group("win", "res://assets/audio/win_%02d.ogg", 4)
	_group("ability_power", "res://assets/audio/ability_power_%02d.ogg", 6)
	_group("ability_laser", "res://assets/audio/ability_laser_%02d.ogg", 5)
	_group("ability_blink", "res://assets/audio/ability_blink_%02d.ogg", 4)
	_group("ability_zap", "res://assets/audio/ability_zap_%02d.ogg", 2)
	_group("chip_lay", "res://assets/audio/chip_lay_%02d.ogg", 4)
	_group("chip_stack", "res://assets/audio/chip_stack_%02d.ogg", 4)
	_group("chip_collide", "res://assets/audio/chip_collide_%02d.ogg", 4)
	_group("card_slide", "res://assets/audio/card_slide_%02d.ogg", 4)
	_group("dice", "res://assets/audio/dice_%02d.ogg", 4)

	_single("ui_back", "res://assets/audio/ui_back.ogg")
	_single("ui_confirm", "res://assets/audio/ui_confirm.ogg")
	_single("card_shuffle", "res://assets/audio/card_shuffle.ogg")
	_single("coins", "res://assets/audio/coins_handle.ogg")
	_single("casino_win", "res://assets/audio/casino_win.ogg")
	_single("casino_lose", "res://assets/audio/casino_lose.ogg")
	_single("menu", "res://assets/audio/menu_00.ogg")

	# call-site aliases: existing gameplay code keeps working on real samples
	_alias("step", "step_concrete")
	_alias("step_metal", "impact_metal")
	_alias("click", "ui_click")
	_alias("hover", "ui_hover")
	_alias("back", "ui_back")
	_alias("confirm", "ui_confirm")
	_alias("beep", "ui_click")
	_alias("tick", "ui_click")
	_alias("jump", "whoosh")
	_alias("dash", "whoosh")
	_alias("land", "thud")
	_alias("heart", "impact_wood")
	_alias("tag", "impact_punch")
	_alias("menu_loop", "menu")


func _group(cue: String, path_fmt: String, count: int) -> void:
	var list: Array = []
	for i in count:
		var p := path_fmt % i
		if not ResourceLoader.exists(p):
			continue
		var s := load(p) as AudioStream
		if s != null:
			list.append(s)
	if not list.is_empty():
		_bank[cue] = list


func _single(cue: String, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var s := load(path) as AudioStream
	if s != null:
		_bank[cue] = [s]


func _alias(cue: String, source: String) -> void:
	if _bank.has(source):
		_bank[cue] = _bank[source]


func has_cue(cue: String) -> bool:
	return _bank.has(cue) and not (_bank[cue] as Array).is_empty()


## Footsteps choose the surface bank; metal falls back to a metal impact layer.
func play_step(surface: String, volume_db: float = -19.0, pitch: float = 1.0) -> void:
	var key := "step_" + surface
	if not has_cue(key):
		key = "step_concrete"
	play(key, volume_db, pitch * _rng.randf_range(0.95, 1.05))


func play(name: String, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	var stream := _pick(name)
	if stream == null:
		return
	var p := _ui_players[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_players.size()
	p.stream = stream
	p.volume_db = volume_db + _rng.randf_range(-1.0, 1.0)
	p.pitch_scale = maxf(0.05, pitch * _rng.randf_range(0.97, 1.03))
	p.play()


func play_at(name: String, pos: Vector3, parent: Node, volume_db: float = -2.0, pitch: float = 1.0) -> void:
	var stream := _pick(name)
	if stream == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db + _rng.randf_range(-1.0, 1.0)
	p.pitch_scale = maxf(0.05, pitch * _rng.randf_range(0.96, 1.04))
	p.max_distance = 40.0
	p.unit_size = 6.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


func _pick(name: String) -> AudioStream:
	var list: Array = _bank.get(name, [])
	if list.is_empty():
		return null
	return list[_rng.randi() % list.size()]


## A casino bed built by scheduling real chip, card and coin recordings, since
## no CC0 casino room-tone loop was available. Still 100% recorded audio.
func start_casino_bed() -> void:
	_bed = true
	_bed_timer = 0.4
	set_process(true)


func stop_casino_bed() -> void:
	_bed = false
	set_process(false)


func _process(dt: float) -> void:
	if not _bed:
		return
	_bed_timer -= dt
	if _bed_timer > 0.0:
		return
	_bed_timer = _rng.randf_range(0.65, 2.3)
	var cue: String = BED_CUES[_rng.randi() % BED_CUES.size()]
	play(cue, -26.0, _rng.randf_range(0.88, 1.08))
