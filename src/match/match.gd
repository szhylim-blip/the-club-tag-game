class_name Match
extends Node3D
## A rules-driven round. Four modes share one arena, cast, HUD and result flow:
##   tag        pass IT by touch, most tags/time wins
##   hush       1 seeker blind for 14 s, hiders found on touch; all found = seeker
##   infection  infected convert survivors on touch; all turned = infected
##   potato     fuse passes on touch, holder is eliminated when it blows
## Everything is offset by `origin` so the admin can run any mode where they stand.

signal round_over(rows: Array, result: String)
signal hud_event(kind: String, payload: Dictionary)

# downloaded Kenney Particle Pack sprites (CC0), see ASSETS.md
const VFX_SPARK: Texture2D = preload("res://assets/vfx/pack/spark_01.png")
const VFX_DUST: Texture2D = preload("res://assets/vfx/pack/smoke_04.png")
const VFX_STREAK: Texture2D = preload("res://assets/vfx/pack/slash_02.png")

const MODES := {
	"tag": {"title": "THE FLOOR", "time": 105.0},
	"hush": {"title": "THE HUSH", "time": 95.0},
	"infection": {"title": "INFECTION", "time": 100.0},
	"potato": {"title": "HOT POTATO", "time": 90.0},
}
const HUSH_SEEK_DELAY := 14.0
const POTATO_FUSE := 9.0
const POTATO_IMMUNITY := 0.8

var mode_id := "tag"
var mode_title := "THE FLOOR"
var last_result := ""

var arena
var player: ClubPlayer
var bots: Array[ClubBot] = []
var actors: Array[Node3D] = []
var it_actor: Node3D

var time_left := Cfg.ROUND_TIME
var running := false
var tags_total := 0

var _stamp := 0.0
var _immunity: Dictionary = {}
var _runner_time: Dictionary = {}
var _tag_count: Dictionary = {}
var _started := false
var _it_time: Dictionary = {}

var _found: Dictionary = {}
var _out: Dictionary = {}
var _infected: Dictionary = {}
var _potato_holder: Node3D
var _potato_t := 0.0
var _potato_immune := 0.0
var _potato_mesh: MeshInstance3D
var _seek_delay := 0.0
var _seek_released := false
var intro_left := 0.0
var _aura: MeshInstance3D
var _aura_light: OmniLight3D
var _motes: GPUParticles3D

# --- E/F role kit -------------------------------------------------------
var _scan_t := 0.0
var _scan_marks: Array[Node3D] = []
var _traps: Array[Dictionary] = []
var _decoy: Node3D
var _decoy_t := 0.0


func start(origin: Vector3 = Vector3.ZERO, mode: String = "tag", intro := false) -> void:
	mode_id = mode if MODES.has(mode) else "tag"
	mode_title = MODES[mode_id]["title"]
	last_result = ""
	_found.clear()
	_out.clear()
	_infected.clear()
	_potato_holder = null
	_potato_t = 0.0
	_seek_delay = 0.0
	_seek_released = false

	# HUSH is the giant-house map; the rest use the club arena.
	if mode_id == "hush":
		arena = HouseArena.new()
	else:
		arena = Arena.new()
	arena.name = "Arena"
	arena.position = origin
	add_child(arena)
	arena.build()

	player = ClubPlayer.new()
	player.name = "Player"
	player.member_name = "YOU"
	player.is_local = true
	add_child(player)
	player.global_position = arena.spawn_points[0] + origin
	player.look_at(Vector3(origin.x, player.global_position.y, origin.z), Vector3.UP)
	player.cam.current = true
	player.ground_surface = "concrete"
	player.stepped.connect(_on_step)
	player.landed.connect(_on_land)
	player.ability_fired.connect(_on_ability)
	player.role_ability_fired.connect(_on_role_ability)
	Sfx.stop_casino_bed()

	for i in Cfg.BOT_COUNT:
		var b := ClubBot.new()
		b.name = "Bot%d" % (i + 1)
		b.member_name = "MEMBER %d" % (i + 1)
		b.body_color = Cfg.BOT_COLORS[i % Cfg.BOT_COLORS.size()]
		b.shape_id = i % 3
		add_child(b)
		b.global_position = arena.spawn_points[(i + 1) % arena.spawn_points.size()] + origin
		bots.append(b)

	actors.append(player)
	for b in bots:
		actors.append(b)

	for a in actors:
		_runner_time[a] = 0.0
		_tag_count[a] = 0
		_it_time[a] = 0.0

	time_left = float(MODES[mode_id]["time"])
	match mode_id:
		"tag":
			it_actor = bots[0]
		"hush":
			it_actor = bots[0]
			_seek_delay = HUSH_SEEK_DELAY
			bots[0].freeze(true)
		"infection":
			it_actor = bots[0]
			_infected[bots[0]] = true
		"potato":
			it_actor = null
			_give_potato(bots[randi() % bots.size()], true)

	_apply_roles()
	_ensure_aura()
	_motes = Fx.motes(self, arena.position + Vector3(0, 4.0, 0), Vector3(30.0, 5.0, 30.0))
	running = true
	_started = true
	Sfx.play("stinger", -8.0, 1.0)

	if intro:
		intro_left = 3.4
		player.set_physics_process(false)
		player.set_input_enabled(false)
		for b in bots:
			b.set_physics_process(false)


func _process(dt: float) -> void:
	if not running:
		return
	if intro_left > 0.0:
		intro_left -= dt
		_update_aura(dt)
		if intro_left <= 0.0:
			_finish_intro()
		return
	if not _started:
		return
	_stamp += dt
	time_left -= dt
	if time_left <= 0.0:
		time_left = 0.0
		_time_up()
		return

	for k: int in _immunity.keys():
		_immunity[k] = maxf(0.0, float(_immunity[k]) - dt)
		if float(_immunity[k]) <= 0.0:
			_immunity.erase(k)

	for a in actors:
		if a == it_actor:
			_it_time[a] = float(_it_time[a]) + dt
		else:
			_runner_time[a] = float(_runner_time[a]) + dt

	if mode_id == "hush" and _seek_delay > 0.0:
		_seek_delay -= dt
		if _seek_delay <= 0.0:
			_release_seeker()

	if mode_id == "potato":
		_potato_immune = maxf(0.0, _potato_immune - dt)
		_potato_t -= dt
		_tick_potato(dt)
		if _potato_t <= 0.0:
			_potato_blow()

	_update_bots()
	_tick_role_effects(dt)
	if mode_id == "tag":
		_check_tags()
	else:
		_check_contacts()

	_update_aura(dt)

	if player.global_position.y < -12.0:
		player.global_position = arena.spawn_points[randi() % arena.spawn_points.size()] + arena.position + Vector3(0, 1, 0)
		player.velocity = Vector3.ZERO


func _time_up() -> void:
	match mode_id:
		"tag":
			_end_tag_time()
		"hush":
			_end_round("HIDERS WIN — TIME RAN OUT")
		"infection":
			_end_round("SURVIVORS WIN — HELD OUT")
		"potato":
			_end_round("TIME — ROUND OVER")


func _near(a: Node3D, b: Node3D) -> bool:
	var d: float = a.global_position.distance_to(b.global_position)
	var dy: float = absf(a.global_position.y - b.global_position.y)
	return d < Cfg.TAG_DISTANCE + (0.15 if mode_id == "potato" else 0.0) and dy < 1.8


func _check_contacts() -> void:
	match mode_id:
		"hush":
			if it_actor == null or _seek_delay > 0.0:
				return
			for a in actors:
				if a == it_actor or _found.has(a):
					continue
				if a == player and player.is_shielded():
					continue
				if _near(it_actor, a):
					_find_hider(a)
					return
		"infection":
			for inf in actors:
				if not _infected.has(inf):
					continue
				for a in actors:
					if _infected.has(a):
						continue
					if a == player and player.is_shielded():
						continue
					if _near(inf, a):
						_infect(a)
						return
		"potato":
			if _potato_holder == null or _potato_immune > 0.0 or _out.has(_potato_holder):
				return
			for a in actors:
				if a == _potato_holder or _out.has(a):
					continue
				if _near(_potato_holder, a):
					_give_potato(a, false)
					return


func _find_hider(a: Node3D) -> void:
	if _found.has(a):
		return
	_found[a] = true
	hud_event.emit("feed", {"text": "%s FOUND" % _name_of(a), "color": Color("#8fb6ff")})
	if a is ClubBot:
		(a as ClubBot).eliminate()
	elif a is ClubPlayer:
		(a as ClubPlayer).set_frozen(true)
		hud_event.emit("toast", {"text": "FOUND — SPECTATING", "color": Cfg.CORAL})
	var pos: Vector3 = a.global_position + Vector3(0, 1.0, 0)
	_burst(pos, Cfg.CORAL)
	Sfx.play_at("impact_soft", pos, self, -4.0, 1.05)
	_check_hush_end()


func _check_hush_end() -> void:
	var remaining := 0
	for a in actors:
		if a != it_actor and not _found.has(a):
			remaining += 1
	if remaining == 0:
		_end_round("SEEKER WINS — ALL HIDERS FOUND")


func _release_seeker() -> void:
	_seek_released = true
	if it_actor is ClubBot:
		(it_actor as ClubBot).freeze(false)
	Sfx.play("stinger", -9.0, 0.92)
	hud_event.emit("toast", {"text": "THE SEEKER IS LOOSE", "color": Cfg.CORAL})
	hud_event.emit("feed", {"text": "THE SEEKER IS LOOSE", "color": Color("#8fb6ff")})


func _infect(a: Node3D) -> void:
	if _infected.has(a):
		return
	_infected[a] = true
	hud_event.emit("feed", {"text": "%s TURNED" % _name_of(a), "color": Cfg.CORAL})
	if a is ClubPlayer:
		(a as ClubPlayer).set_role(true)
		hud_event.emit("toast", {"text": "INFECTED", "color": Cfg.CORAL})
	var pos: Vector3 = a.global_position + Vector3(0, 1.0, 0)
	_burst(pos, Cfg.CORAL)
	Sfx.play_at("impact_punch", pos, self, -2.0, 0.95)
	_apply_roles()
	var survivors := 0
	for x in actors:
		if not _infected.has(x):
			survivors += 1
	if survivors == 0:
		_end_round("INFECTED WIN — EVERYONE TURNED")


func _give_potato(a: Node3D, initial: bool) -> void:
	if _potato_mesh != null and is_instance_valid(_potato_mesh):
		_potato_mesh.queue_free()
		_potato_mesh = null
	_potato_holder = a
	_potato_t = POTATO_FUSE
	_potato_immune = POTATO_IMMUNITY
	_potato_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.19
	sphere.height = 0.38
	_potato_mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#d9a441")
	mat.emission_enabled = true
	mat.emission = Color("#ffb347")
	mat.emission_energy_multiplier = 3.0
	_potato_mesh.material_override = mat
	a.add_child(_potato_mesh)
	_potato_mesh.position = Vector3(0, 1.55, 0)
	if not initial:
		Sfx.play("chip_stack", -10.0, 1.1)
		if a is ClubPlayer:
			hud_event.emit("toast", {"text": "POTATO — PASS IT", "color": Cfg.GOLD})
	_apply_roles()


func _tick_potato(dt: float) -> void:
	if _potato_mesh == null or not is_instance_valid(_potato_mesh):
		return
	_potato_mesh.position.y = 1.55 + sin(_stamp * 6.0) * 0.07
	_potato_mesh.rotation.y += dt * 3.0


func _potato_blow() -> void:
	var holder := _potato_holder
	if holder == null:
		return
	var pos: Vector3 = holder.global_position + Vector3(0, 1.0, 0)
	_burst(pos, Cfg.CORAL)
	_burst(pos, Cfg.GOLD)
	Fx.shock(holder.global_position + Vector3(0, 0.08, 0), Cfg.GOLD, 3.2)
	_hitstop(0.5, 0.08)
	hud_event.emit("feed", {"text": "%s BLEW UP" % _name_of(holder), "color": Cfg.GOLD})
	Sfx.play_at("impact_punch", pos, self, 1.0, 0.9)
	_out[holder] = true
	if holder is ClubBot:
		(holder as ClubBot).eliminate()
	elif holder is ClubPlayer:
		(holder as ClubPlayer).set_frozen(true)
		hud_event.emit("toast", {"text": "THE POTATO GOT YOU", "color": Cfg.CORAL})
	if _potato_mesh != null and is_instance_valid(_potato_mesh):
		_potato_mesh.queue_free()
	_potato_mesh = null
	_potato_holder = null

	var alive: Array[Node3D] = []
	for a in actors:
		if not _out.has(a):
			alive.append(a)
	if alive.size() <= 1:
		var winner_name := "NOBODY"
		if alive.size() == 1:
			winner_name = _actor_name(alive[0])
		_end_round("LAST ONE STANDING — %s" % winner_name)
		return
	_give_potato(alive[randi() % alive.size()], false)


func _actor_name(a: Node3D) -> String:
	if a is ClubPlayer:
		return "YOU"
	if a is ClubBot:
		return (a as ClubBot).member_name
	return "MEMBER"


func _update_bots() -> void:
	match mode_id:
		"tag":
			for b in bots:
				if b == it_actor:
					b.target = _decoy if _decoy_live() else _nearest_runner(b.global_position)
					b.flee_from = null
				else:
					b.target = null
					b.flee_from = it_actor
		"hush":
			for b in bots:
				if _found.has(b):
					continue
				if b == it_actor:
					b.flee_from = null
					b.target = null if _seek_delay > 0.0 else (_decoy if _decoy_live() else _nearest_hider(b))
				else:
					b.target = null
					b.flee_from = it_actor if _seek_delay <= 0.0 else null
		"infection":
			var hunter := _nearest_infected()
			for b in bots:
				if _infected.has(b):
					b.flee_from = null
					b.target = _decoy if _decoy_live() else _nearest_survivor(b)
				else:
					b.target = null
					b.flee_from = hunter
		"potato":
			for b in bots:
				if _out.has(b):
					continue
				if b == _potato_holder:
					b.target = null
					b.flee_from = _nearest_other(b)
				else:
					b.target = _potato_holder
					b.flee_from = null


func _nearest_runner(from: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := 1e9
	for a in actors:
		if a == it_actor:
			continue
		var d := from.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _nearest_hider(from: Node3D) -> Node3D:
	var best: Node3D = null
	var best_d := 1e9
	for a in actors:
		if a == it_actor or _found.has(a):
			continue
		var d := from.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _nearest_infected() -> Node3D:
	var best: Node3D = null
	var best_d := 1e9
	for a in actors:
		if not _infected.has(a):
			continue
		var d := player.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _nearest_survivor(from: Node3D) -> Node3D:
	var best: Node3D = null
	var best_d := 1e9
	for a in actors:
		if _infected.has(a):
			continue
		var d := from.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _nearest_other(from: Node3D) -> Node3D:
	var best: Node3D = null
	var best_d := 1e9
	for a in actors:
		if a == from or _out.has(a):
			continue
		var d := from.global_position.distance_to(a.global_position)
		if d < best_d:
			best_d = d
			best = a
	return best


func _check_tags() -> void:
	if it_actor == null:
		return
	for a in actors:
		if a == it_actor:
			continue
		if a == player and player.is_shielded():
			continue
		if _immunity.has(a.get_instance_id()):
			continue
		if _near(it_actor, a):
			_pass_it(a)
			return


func _pass_it(new_it: Node3D) -> void:
	var old := it_actor
	var old_id := old.get_instance_id()
	var new_id := new_it.get_instance_id()

	_tag_count[old] = int(_tag_count.get(old, 0)) + 1
	tags_total += 1
	_immunity[old_id] = Cfg.TAG_IMMUNITY
	_immunity[new_id] = 0.0
	it_actor = new_it
	_apply_roles()

	var pos: Vector3 = new_it.global_position + Vector3(0, 1.0, 0)
	_burst(pos, Cfg.CORAL)
	Fx.shock(new_it.global_position + Vector3(0, 0.08, 0), Cfg.CORAL, 1.9)
	Sfx.play_at("impact_punch", pos, self, 1.5, randf_range(0.94, 1.04))
	hud_event.emit("feed", {"text": "%s TAGGED %s" % [_name_of(old), _name_of(new_it)], "color": Cfg.CORAL})
	Sfx.play("stinger", -7.0, randf_range(0.97, 1.04))

	if new_it == player or old == player:
		_hitstop(0.55, 0.07)
	if new_it == player:
		player.add_shake(0.20)
		hud_event.emit("became_it", {})
	elif old == player:
		player.add_shake(0.08)
		hud_event.emit("tagged_someone", {})


func _finish_intro() -> void:
	intro_left = 0.0
	if player != null:
		player.set_physics_process(true)
		player.set_input_enabled(true)
		player.velocity = Vector3.ZERO
	for b in bots:
		if is_instance_valid(b):
			b.set_physics_process(true)


func _name_of(a: Node3D) -> String:
	if a == null:
		return "NOBODY"
	if a == player:
		return "YOU"
	if a is ClubBot:
		return (a as ClubBot).member_name
	return "MEMBER"


## The one-sentence objective shown under the clock. Rules, not flavour text.
func mode_objective() -> String:
	match mode_id:
		"tag":
			return "PASS IT BY TOUCH  ·  DON'T BE IT WHEN THE CLOCK ENDS"
		"hush":
			return "ONE SEEKER  ·  HIDE OR BE FOUND  ·  SURVIVE THE HOUSE"
		"infection":
			return "ONE TOUCH TURNS A RUNNER  ·  LAST SURVIVOR WINS"
		"potato":
			return "PASS THE FUSE  ·  WHEN IT BLOWS, THE HOLDER IS OUT"
	return ""


func _ensure_aura() -> void:
	if _aura != null:
		return
	var ring := TorusMesh.new()
	ring.inner_radius = 0.42
	ring.outer_radius = 0.56
	ring.rings = 40
	ring.ring_segments = 10
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = _aura_color()
	mat.emission_enabled = true
	mat.emission = _aura_color()
	mat.emission_energy_multiplier = 4.0
	_aura = MeshInstance3D.new()
	_aura.mesh = ring
	_aura.material_override = mat
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_aura)

	_aura_light = OmniLight3D.new()
	_aura_light.light_color = _aura_color()
	_aura_light.light_energy = 1.5
	_aura_light.omni_range = 3.4
	add_child(_aura_light)


func _aura_color() -> Color:
	if mode_id == "hush":
		return Color("#8fb6ff")
	if mode_id == "infection":
		return Color("#ff5d5d")
	return Cfg.CORAL


func _update_aura(dt: float) -> void:
	if _aura == null:
		return
	var active := it_actor != null and is_instance_valid(it_actor)
	_aura.visible = active
	if _aura_light != null:
		_aura_light.visible = active
	if not active:
		return
	_aura.global_position = it_actor.global_position + Vector3(0, 0.055, 0)
	_aura.rotation.y += dt * 1.35
	var pulse := 1.0 + sin(_stamp * 4.2) * 0.06
	_aura.scale = Vector3(pulse, 1.0, pulse)
	if _aura_light != null:
		_aura_light.global_position = it_actor.global_position + Vector3(0, 0.75, 0)
		_aura_light.light_energy = 1.4 + sin(_stamp * 3.4) * 0.35


func _hitstop(scale: float, secs: float) -> void:
	if not running:
		return
	Engine.time_scale = scale
	await get_tree().create_timer(secs, true, false, true).timeout
	Engine.time_scale = 1.0


func _apply_roles() -> void:
	for a in actors:
		var is_role := false
		match mode_id:
			"tag", "hush":
				is_role = a == it_actor
			"infection":
				is_role = _infected.has(a)
			"potato":
				is_role = a == _potato_holder
		if a is ClubPlayer:
			(a as ClubPlayer).set_role(is_role)
		elif a is ClubBot:
			(a as ClubBot).set_role(is_role)


func _on_step(pos: Vector3, _surface: String) -> void:
	if randf() < 0.25:
		_dust(pos)


func _on_role_ability(kind: String) -> void:
	hud_event.emit("ability", {"kind": kind})
	match kind:
		"scan":
			_scan()
			Sfx.play("ability_blink", -10.0, 1.3)
		"trap":
			_place_trap()
			Sfx.play("chip_stack", -8.0, 0.9)
		"decoy":
			_place_decoy()
			Sfx.play("ability_power", -12.0, 1.25)
		"stamina":
			hud_event.emit("feed", {"text": "STAMINA — 4s", "color": Cfg.MINT})
			Sfx.play("ability_power", -10.0, 1.35)


## SCAN reveals every runner for four seconds through geometry. The marker is a
## world child of the runner, so it tracks movement instead of lying on the floor.
func _scan() -> void:
	_clear_scan()
	_scan_t = 4.0
	for a in actors:
		if a == it_actor or _out.has(a) or _found.has(a):
			continue
		var mark := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.24
		tor.outer_radius = 0.33
		tor.rings = 28
		tor.ring_segments = 8
		mark.mesh = tor
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.no_depth_test = true
		mat.albedo_color = Color("#8fb6ff")
		mat.emission_enabled = true
		mat.emission = Color("#8fb6ff")
		mat.emission_energy_multiplier = 4.0
		mark.material_override = mat
		mark.position = Vector3(0, 2.05, 0)
		a.add_child(mark)
		_scan_marks.append(mark)
	hud_event.emit("feed", {"text": "SCAN — %d SIGNALS" % _scan_marks.size(), "color": Color("#8fb6ff")})


func _clear_scan() -> void:
	for mark in _scan_marks:
		if is_instance_valid(mark):
			mark.queue_free()
	_scan_marks.clear()
	_scan_t = 0.0


## TRAP is a real slow field. It keeps ticking while a runner stands in it, so
## crossing it has a cost and the chaser can steer a route instead of only chase.
func _place_trap() -> void:
	var trap := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = Cfg.TRAP_RADIUS - 0.12
	tor.outer_radius = Cfg.TRAP_RADIUS
	tor.rings = 48
	tor.ring_segments = 8
	trap.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color("#ff9d5c")
	mat.emission_enabled = true
	mat.emission = Color("#ff9d5c")
	mat.emission_energy_multiplier = 3.0
	trap.material_override = mat
	add_child(trap)
	trap.global_position = player.global_position + Vector3(0, 0.07, 0)
	_traps.append({"pos": trap.global_position, "t": 8.0, "mesh": trap})
	hud_event.emit("feed", {"text": "TRAP SET — 8s", "color": Color("#ff9d5c")})


func _tick_role_effects(dt: float) -> void:
	if _scan_t > 0.0:
		_scan_t -= dt
		if _scan_t <= 0.0:
			_clear_scan()
	if _decoy_t > 0.0:
		_decoy_t -= dt
		if _decoy_t <= 0.0 or not is_instance_valid(_decoy):
			if is_instance_valid(_decoy):
				_decoy.queue_free()
			_decoy = null
			_decoy_t = 0.0
	for i in range(_traps.size() - 1, -1, -1):
		var trap: Dictionary = _traps[i]
		trap["t"] = float(trap["t"]) - dt
		if float(trap["t"]) <= 0.0:
			var dead: Node3D = trap["mesh"]
			if is_instance_valid(dead):
				dead.queue_free()
			_traps.remove_at(i)
			continue
		var center: Vector3 = trap["pos"]
		for a in actors:
			if a == it_actor or _out.has(a) or _found.has(a):
				continue
			if a.global_position.distance_to(center) <= Cfg.TRAP_RADIUS:
				if a is ClubBot:
					(a as ClubBot).apply_slow(0.35)
				elif a is ClubPlayer:
					(a as ClubPlayer).apply_slow(0.35)


func _decoy_live() -> bool:
	return _decoy != null and is_instance_valid(_decoy) and _decoy_t > 0.0


## DECOY is a visible hologram with its own life. Chasers acquire it for four
## seconds; the runner gets a real juke window, not a cosmetic puff.
func _place_decoy() -> void:
	if is_instance_valid(_decoy):
		_decoy.queue_free()
	_decoy = Node3D.new()
	_decoy.name = "Decoy"
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = Cfg.RADIUS
	capsule.height = Cfg.STAND_H
	mesh.mesh = capsule
	mesh.position.y = Cfg.STAND_H * 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.45, 0.9, 1.0, 0.34)
	mat.emission_enabled = true
	mat.emission = Color("#7de3ff")
	mat.emission_energy_multiplier = 2.2
	mesh.material_override = mat
	_decoy.add_child(mesh)
	add_child(_decoy)
	_decoy.global_position = player.global_position + -player.transform.basis.z * 1.8
	_decoy_t = 4.0
	hud_event.emit("feed", {"text": "DECOY — 4s", "color": Color("#7de3ff")})


## TAG timeout is a win/lose, not a shrug. Lowest total time spent as IT wins; a
## clean runner wins outright over everyone who carried IT.
func _end_tag_time() -> void:
	var winner: Node3D = actors[0]
	var best := INF
	for a in actors:
		var carried := float(_it_time.get(a, 0.0))
		if carried < best - 0.001:
			best = carried
			winner = a
		elif absf(carried - best) <= 0.001 and a == player:
			winner = player
	var result := "TIME — %s WINS" % _actor_name(winner)
	if winner == player:
		result = "TIME — YOU WIN"
	_end_round(result)


func _on_ability(kind: String) -> void:
	hud_event.emit("ability", {"kind": kind})
	match kind:
		"dash":
			_dash_trail()
			Fx.trail(player, Cfg.GOLD)
			Sfx.play("whoosh", -12.0, 0.85)
		"lunge":
			_dash_trail()
			Sfx.play("ability_power", -13.0, 1.0)
		"blink":
			_burst(player.global_position + Vector3(0, 1, 0), Color("#8fb6ff"))
			Fx.shock(player.global_position + Vector3(0, 0.2, 0), Color("#8fb6ff"), 2.2)
			_dash_trail()
		"shock":
			_shock()
		"shield":
			hud_event.emit("toast", {"text": "SHIELDED", "color": Color("#8fb6ff")})


## Screenshot harness: fire the real effects, not stand-ins.
func debug_vfx() -> void:
	if player == null:
		return
	# Exercise the real tag path so the aura, ring, feed and burst all show.
	if mode_id == "tag" and it_actor != player:
		_pass_it(player)
	_dash_trail()
	var pos := player.global_position + -player.transform.basis.z * 2.0
	_burst(pos + Vector3(0, 1.0, 0), Cfg.GOLD)
	_dust(player.global_position)


## Test/admin hook: collapse the clock so the end state can be observed.
func debug_expire(seconds: float = 0.2) -> void:
	time_left = seconds


## Admin hook: drive THIS mode's own win condition through its real rule calls,
## not the clock. Hush marks every hider, infection converts every survivor,
## potato blows holders until one is left.
func debug_force_win() -> void:
	if not running:
		return
	match mode_id:
		"hush":
			for a in actors.duplicate():
				if a != it_actor and not _found.has(a):
					_find_hider(a)
		"infection":
			for a in actors.duplicate():
				if not _infected.has(a):
					_infect(a)
		"potato":
			var guard := 0
			while running and guard < actors.size() + 4:
				_potato_blow()
				guard += 1
	print("FORCED_WIN mode=%s result=%s" % [mode_id, last_result])


## SHOCK: stun every bot in a 6 m ring for 1.5 s and shove them out.
func _shock() -> void:
	var pos := player.global_position + Vector3(0, 1.0, 0)
	Fx.shock(player.global_position + Vector3(0, 0.2, 0), Color("#7de3ff"), 6.0)
	for b in bots:
		if b.eliminated or b.global_position.distance_to(pos) > 6.0:
			continue
		b.freeze(true)
		b.velocity += (b.global_position - pos).normalized() * 4.0
		get_tree().create_timer(1.5).timeout.connect(func():
			if is_instance_valid(b) and not b.eliminated:
				b.freeze(false))
	_burst(pos, Color("#7de3ff"))
	Sfx.play("ability_zap", -6.0, 1.0)


func _on_land(pos: Vector3, strength: float) -> void:
	_dust(pos)
	if strength > 0.09:
		Sfx.play_at("impact_soft", pos, self, -8.0, randf_range(0.9, 1.05))


## Real streak texture dragged behind a dash: 0.45 s, attached to the runner.
func _dash_trail() -> void:
	if player == null:
		return
	var p := GPUParticles3D.new()
	p.amount = 34
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.85
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 24.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.35
	pm.scale_max = 0.8
	pm.color = Color(0.78, 0.92, 1.0, 0.55)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.24)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = VFX_STREAK
	mat.vertex_color_use_as_albedo = true
	q.material = mat
	p.draw_pass_1 = q
	add_child(p)
	p.global_position = player.global_position + Vector3(0, 0.9, 0)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _dust(pos: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 6
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 60.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, -1.2, 0)
	pm.scale_min = 0.25
	pm.scale_max = 0.6
	pm.color = Color(0.7, 0.64, 0.58, 0.5)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = VFX_DUST
	mat.vertex_color_use_as_albedo = true
	q.material = mat
	p.draw_pass_1 = q
	add_child(p)
	p.global_position = pos + Vector3(0, 0.06, 0)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)


func _burst(pos: Vector3, color: Color) -> void:
	var p := GPUParticles3D.new()
	p.amount = 44
	p.lifetime = 1.0
	p.one_shot = true
	p.explosiveness = 0.95
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 2.5
	pm.initial_velocity_max = 7.5
	pm.gravity = Vector3(0, -9.0, 0)
	pm.scale_min = 0.25
	pm.scale_max = 0.75
	pm.color = color
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = VFX_SPARK
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.5
	q.material = mat
	p.draw_pass_1 = q
	add_child(p)
	p.global_position = pos
	p.emitting = true

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 5.0
	light.omni_range = 6.0
	add_child(light)
	light.global_position = pos
	var tw := create_tween()
	tw.tween_property(light, "light_energy", 0.0, 0.32)
	tw.tween_callback(light.queue_free)

	get_tree().create_timer(1.4).timeout.connect(p.queue_free)


func _end_round(result: String = "TIME — ROUND OVER") -> void:
	if not running:
		return
	running = false
	Engine.time_scale = 1.0
	last_result = result
	if player != null:
		player.set_input_enabled(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var rows: Array = []
	for a in actors:
		var nm := "MEMBER"
		var col := Cfg.MINT
		if a is ClubPlayer:
			nm = "YOU"
			col = Cfg.GOLD
		elif a is ClubBot:
			nm = (a as ClubBot).member_name
			col = (a as ClubBot).body_color
		var score: float = float(_runner_time.get(a, 0.0)) + float(_tag_count.get(a, 0)) * 3.0
		var status := ""
		if _found.has(a):
			status = "FOUND"
		elif _out.has(a):
			status = "OUT"
		elif _infected.has(a):
			status = "INFECTED"
		rows.append({
			"name": nm,
			"score": int(score),
			"tags": int(_tag_count.get(a, 0)),
			"it_time": float(_it_time.get(a, 0.0)),
			"color": col,
			"is_player": a is ClubPlayer,
			"status": status,
			"out": _found.has(a) or _out.has(a),
		})
	rows.sort_custom(func(x, y):
		if bool(x.get("out", false)) != bool(y.get("out", false)):
			return not bool(x.get("out", false))
		return x["score"] > y["score"])
	Sfx.play("win", -10.0, 1.0)
	round_over.emit(rows, result)


func player_is_it() -> bool:
	if player == null:
		return false
	match mode_id:
		"tag", "hush":
			return it_actor == player
		"infection":
			return _infected.has(player)
		"potato":
			return _potato_holder == player
	return false


func player_role_text() -> String:
	match mode_id:
		"tag":
			return "YOU ARE IT" if player_is_it() else "RUN"
		"hush":
			if _found.has(player):
				return "FOUND — SPECTATING"
			if player_is_it():
				return "SEEKER"
			return "STAY HIDDEN"
		"infection":
			return "INFECTED" if _infected.has(player) else "SURVIVOR"
		"potato":
			if _out.has(player):
				return "ELIMINATED"
			return "YOU HAVE THE POTATO" if _potato_holder == player else "DON'T GET IT"
	return "RUN"


func player_role_color() -> Color:
	if mode_id == "potato" and _potato_holder == player:
		return Cfg.GOLD
	if player_role_text().begins_with("FOUND") or player_role_text() == "ELIMINATED":
		return Cfg.MUTED
	return Cfg.CORAL if player_is_it() else Cfg.MINT


func mode_status() -> String:
	match mode_id:
		"tag":
			return "TAGS %d" % tags_total
		"hush":
			var hiders := 0
			var remaining := 0
			for a in actors:
				if a == it_actor:
					continue
				hiders += 1
				if not _found.has(a):
					remaining += 1
			if _seek_delay > 0.0:
				return "SEEKER IN %ds   ·   HIDERS %d" % [int(ceil(_seek_delay)), remaining]
			return "HIDERS %d / %d" % [remaining, hiders]
		"infection":
			var n := 0
			for a in actors:
				if _infected.has(a):
					n += 1
			return "INFECTED %d / %d" % [n, actors.size()]
		"potato":
			var alive := 0
			for a in actors:
				if not _out.has(a):
					alive += 1
			if _potato_holder == player:
				return "FUSE %.1fs   ·   PASS IT" % maxf(0.0, _potato_t)
			return "FUSE %.1fs   ·   ALIVE %d" % [maxf(0.0, _potato_t), alive]
	return ""


func mode_hint() -> String:
	var q := player.primary_ability_name() if player != null else "DASH"
	var e := player.role_ability_name(1) if player != null else "ROLE"
	var f := player.role_ability_name(2) if player != null else "ROLE"
	match mode_id:
		"hush":
			return "TOUCH A HIDER  ·  SHIFT SPRINT  ·  Q %s  ·  E %s  ·  F %s" % [q, e, f]
		"infection":
			return "DON'T GET TOUCHED  ·  Q %s  ·  E %s  ·  F %s" % [q, e, f]
		"potato":
			return "TOUCH SOMEONE TO PASS  ·  Q %s  ·  E %s  ·  F %s" % [q, e, f]
	return "SHIFT SPRINT  ·  CTRL SLIDE  ·  SPACE JUMP  ·  Q %s  ·  E %s  ·  F %s" % [q, e, f]


func get_player_score() -> float:
	if player == null:
		return 0.0
	return float(_runner_time.get(player, 0.0)) + float(_tag_count.get(player, 0)) * 3.0


func get_tag_distance() -> float:
	if player == null:
		return 99.0
	var best := 99.0
	if mode_id == "hush":
		if it_actor != null:
			best = it_actor.global_position.distance_to(player.global_position)
	elif mode_id == "infection":
		for a in actors:
			if _infected.has(a) and a != player:
				best = minf(best, a.global_position.distance_to(player.global_position))
	elif mode_id == "tag":
		if it_actor != null:
			best = it_actor.global_position.distance_to(player.global_position)
	return best


func get_speed() -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()
