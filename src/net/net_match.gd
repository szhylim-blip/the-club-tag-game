class_name NetMatch
extends Node3D
## Authoritative networked round for all four modes.
##
## Host: owns the timer, role assignment, contacts, fuse and results; takes
## client state into `_states` and broadcasts a snapshot at ~14 Hz.
## Client: owns its own movement, sends state at ~20 Hz, applies host snapshots
## to puppets and roles. No client ever assigns a role or changes a rule.

signal leave_requested

const MODE_TIME := {"tag": 105.0, "hush": 95.0, "infection": 100.0, "potato": 90.0}
const MODE_TITLE := {"tag": "TAG", "hush": "HUSH", "infection": "INFECTION", "potato": "HOT POTATO"}
const SNAPSHOT_HZ := 14.0
const STATE_HZ := 20.0
const TAG_LOCK := 1.1
const HUSH_SEEK_DELAY := 14.0
const POTATO_FUSE := 9.0
const POTATO_IMMUNITY := 0.8

var arena
var player: ClubPlayer
var remotes: Dictionary = {}
var map_id := "floor"
var mode_id := "tag"
var host := false
var local_id := 1
var it_id := 1
var seeker_id := 1
var found: Dictionary = {}
var infected: Dictionary = {}
var out: Dictionary = {}
var potato_id := 0
var fuse := POTATO_FUSE
var seek_delay := 0.0
var time_left := 105.0
var running := true
var test_mode := false

var _states: Dictionary = {}
var _shield_until: Dictionary = {}
var _snap_acc := 0.0
var _state_acc := 0.0
var _hud_acc := 0.0
var _elapsed := 0.0
var _tag_lock := 0.0
var _potato_immunity := 0.0
var _test_stage := 0
var _ability_sent := false
var _test_drop_scheduled := false
var _shot_posed := false
var _log_acc := 0.0
var _role_sig := ""

var _timer_lbl: Label
var _role_lbl: Label
var _sub_lbl: Label
var _ability_lbl: Label
var _cooldown_bar: ColorRect
var _result_panel: PanelContainer


func setup(p_map: String, p_mode: String, p_test: bool) -> void:
	map_id = p_map if p_map in ["floor", "house"] else "floor"
	mode_id = p_mode if MODE_TIME.has(p_mode) else "tag"
	time_left = float(MODE_TIME[mode_id])
	host = Net.is_host
	local_id = Net.local_id
	test_mode = p_test

	if map_id == "house":
		arena = HouseArena.new()
	else:
		arena = Arena.new()
	arena.name = "Arena"
	add_child(arena)
	arena.build()

	var ids := _ids()
	var idx := maxi(ids.find(local_id), 0)
	var spawn: Vector3 = arena.spawn_points[idx % arena.spawn_points.size()]

	player = ClubPlayer.new()
	player.name = "Player"
	player.member_name = str(Net.players.get(local_id, {}).get("name", "YOU"))
	player.is_local = true
	add_child(player)
	player.global_position = spawn
	var look := Vector3(0, spawn.y, 0)
	if player.global_position.distance_to(look) > 0.5:
		player.look_at(look, Vector3.UP)
	player.cam.current = true
	player.camera_override = 1 if Net.camera_mode == "third" else (0 if Net.camera_mode == "first" else -1)
	player.ability_fired.connect(_on_local_ability)

	for id: int in ids:
		if id == local_id:
			continue
		var data: Dictionary = Net.players.get(id, {})
		var r := RemoteMember.new()
		r.name = "Remote%d" % id
		add_child(r)
		r.setup(id, data)
		var ridx := maxi(ids.find(id), 0)
		var rspawn: Vector3 = arena.spawn_points[ridx % arena.spawn_points.size()]
		r.snap_to(rspawn, 0.0)
		remotes[id] = r

	# Host starts in the role that must be visible immediately: TAG / HUSH
	# seeker, INFECTION patient zero, or HOT POTATO carrier.
	it_id = ids[0]
	seeker_id = it_id
	match mode_id:
		"hush":
			seek_delay = 2.0 if test_mode else HUSH_SEEK_DELAY
		"infection":
			infected[it_id] = true
		"potato":
			fuse = POTATO_FUSE
			potato_id = it_id
	_apply_roles()
	_build_hud()

	Net.state_received.connect(_on_state_received)
	Net.snapshot_received.connect(_on_snapshot)
	Net.ability_event.connect(_on_ability_event)
	Net.peer_left.connect(_on_peer_left)
	Net.roster_changed.connect(_on_roster_changed)
	Net.event_received.connect(_on_event)
	Net.log_line("MATCH_START local=%d host=%s map=%s mode=%s players=%d it=%d" % [
		local_id, str(host), map_id, mode_id, ids.size(), it_id])
	_emit_structured_state()
	Sfx.play("stinger", -10.0, 1.0)


func _ids() -> Array:
	var out_ids := []
	for id: int in Net.players:
		out_ids.append(id)
	out_ids.sort()
	if not out_ids.has(local_id):
		out_ids.append(local_id)
		out_ids.sort()
	return out_ids


func _process(dt: float) -> void:
	if not running:
		return
	_elapsed += dt
	_tag_lock = maxf(0.0, _tag_lock - dt)
	_potato_immunity = maxf(0.0, _potato_immunity - dt)
	_hud_acc += dt
	_log_acc += dt

	var spd := Vector2(player.velocity.x, player.velocity.z).length()
	_state_acc += dt
	if host:
		_states[local_id] = {"pos": player.global_position, "yaw": player.rotation.y, "speed": spd}
		_snap_acc += dt
		if _snap_acc >= 1.0 / SNAPSHOT_HZ:
			_snap_acc = 0.0
			_broadcast_snapshot()
	else:
		if _state_acc >= 1.0 / STATE_HZ:
			_state_acc = 0.0
			Net.send_state(player.global_position, player.rotation.y, spd)
		if test_mode:
			_test_drive()

	if host:
		_host_tick(dt)

	if _hud_acc >= 0.1:
		_hud_acc = 0.0
		_update_hud()
	if _log_acc >= 1.0:
		_log_acc = 0.0
		if host:
			Net.log_line("SNAPSHOT mode=%s t=%.1f it=%d found=%d infected=%d potato=%d" % [
				mode_id, time_left, it_id, found.size(), infected.size(), potato_id])
		else:
			_emit_structured_state()


## One line per second of state received from the host, as JSON. The network
## harness parses this instead of trusting prose logs.
func _emit_structured_state() -> void:
	if host:
		return
	Net.log_line("NET_STATE " + JSON.stringify({
		"mode": mode_id,
		"local": local_id,
		"role": _role_text(),
		"it": it_id,
		"seeker": seeker_id,
		"found": found.keys(),
		"infected": infected.keys(),
		"potato": potato_id,
		"out": out.keys(),
		"seek": snappedf(seek_delay, 0.1),
		"fuse": snappedf(fuse, 0.1),
		"t": snappedf(time_left, 0.1),
		"pos": [snappedf(player.global_position.x, 0.01), snappedf(player.global_position.z, 0.01)],
	}))


func _host_tick(dt: float) -> void:
	time_left = maxf(0.0, time_left - dt)
	if time_left <= 0.0:
		_mode_timeout()
		return

	match mode_id:
		"tag":
			_tick_tag(dt)
		"hush":
			_tick_hush(dt)
		"infection":
			_tick_infection(dt)
		"potato":
			_tick_potato(dt)


func _mode_timeout() -> void:
	match mode_id:
		"hush":
			_end_round("HIDERS WIN — TIME RAN OUT")
		"infection":
			_end_round("SURVIVORS WIN — HELD OUT")
		"potato":
			_end_round("TIME — ROUND OVER")
		_:
			_end_round("TIME — ROUND OVER")


# --- TAG ---------------------------------------------------------------

func _tick_tag(_dt: float) -> void:
	if test_mode and _test_stage == 0 and _elapsed > 2.5 and remotes.size() > 0:
		var first: int = remotes.keys()[0]
		var rp := Vector3.INF
		if _states.has(first):
			rp = _states[first]["pos"]
		if rp != Vector3.INF:
			player.global_position = rp + Vector3(0, 0.1, 1.3)
			player.velocity = Vector3.ZERO
			_test_stage = 1
			Net.log_line("TEST_CLOSE_IN on=%d" % first)
			return

	if _tag_lock > 0.0:
		return
	var it_pos: Variant = _pos_of(it_id)
	if it_pos == null:
		return
	for id: int in _states:
		if id == it_id:
			continue
		if float(_shield_until.get(id, 0.0)) > Time.get_ticks_msec() / 1000.0:
			continue
		var p: Vector3 = _states[id]["pos"]
		if it_pos.distance_to(p) < Cfg.TAG_DISTANCE + 0.35 and absf(it_pos.y - p.y) < 1.8:
			var victim := id
			_set_it(victim)
			if test_mode:
				_tag_lock = 99999.0
				_schedule_test_drop(victim)
			return


func _set_it(id: int) -> void:
	var old := it_id
	it_id = id
	_tag_lock = TAG_LOCK
	_apply_roles()
	var pos: Vector3 = _pos_of(id)
	if pos != null:
		Fx.shock(pos + Vector3(0, 0.2, 0), Cfg.CORAL, 2.4)
		Fx.burst(pos + Vector3(0, 1.0, 0), Cfg.CORAL, 1.1)
		Sfx.play_at("impact_punch", pos, self, -2.0, 1.0)
	if host:
		Net.log_line("TAG %d -> %d" % [old, id])


# --- HUSH --------------------------------------------------------------

func _tick_hush(dt: float) -> void:
	if seek_delay > 0.0:
		seek_delay = maxf(0.0, seek_delay - dt)
		if seek_delay <= 0.0:
			Net.log_line("SEEKER_RELEASED")
			_apply_roles()

	if test_mode:
		if _test_stage == 0 and _elapsed > 3.0:
			_test_stage = 1
			var victim := _first_hider()
			if victim != 0:
				_find_hider(victim)
				_schedule_test_drop(victim)
			return
		if _test_stage == 1 and _elapsed > 5.0:
			_test_stage = 2
			var victim2 := _first_hider()
			if victim2 != 0:
				_find_hider(victim2)
			return

	if seek_delay > 0.0:
		return
	var seeker_pos: Variant = _pos_of(seeker_id)
	if seeker_pos == null:
		return
	for id: int in _states:
		if id == seeker_id or found.has(id):
			continue
		if float(_shield_until.get(id, 0.0)) > Time.get_ticks_msec() / 1000.0:
			continue
		var p: Vector3 = _states[id]["pos"]
		if seeker_pos.distance_to(p) < Cfg.TAG_DISTANCE + 0.35 and absf(seeker_pos.y - p.y) < 1.8:
			_find_hider(id)
			return


func _first_hider() -> int:
	for id: int in _states:
		if id != seeker_id and not found.has(id):
			return id
	return 0


func _find_hider(id: int) -> void:
	if found.has(id):
		return
	found[id] = true
	_apply_roles()
	var pos: Vector3 = _pos_of(id)
	if pos == null:
		pos = player.global_position
	Fx.burst(pos + Vector3(0, 1.0, 0), Cfg.CORAL, 1.2)
	Fx.shock(pos + Vector3(0, 0.2, 0), Cfg.CORAL, 2.0)
	Sfx.play_at("impact_soft", pos, self, -4.0, 1.05)
	Net.log_line("FOUND id=%d remaining=%d" % [id, _hush_remaining()])
	_broadcast_snapshot()
	_check_hush_end()


func _hush_remaining() -> int:
	var remaining := 0
	for id: int in _states:
		if id != seeker_id and not found.has(id):
			remaining += 1
	return remaining


func _check_hush_end() -> void:
	if not running:
		return
	if _hush_remaining() == 0:
		_end_round("SEEKER WINS — ALL HIDERS FOUND")


# --- INFECTION ---------------------------------------------------------

func _tick_infection(_dt: float) -> void:
	if test_mode:
		if _test_stage == 0 and _elapsed > 3.0:
			_test_stage = 1
			var victim := _first_survivor()
			if victim != 0:
				_infect(victim)
				_schedule_test_drop(victim)
			return
		if _test_stage == 1 and _elapsed > 5.0:
			_test_stage = 2
			var victim2 := _first_survivor()
			if victim2 != 0:
				_infect(victim2)
			return

	for inf: int in infected.keys():
		var ip: Variant = _pos_of(inf)
		if ip == null:
			continue
		for id: int in _states:
			if infected.has(id):
				continue
			if float(_shield_until.get(id, 0.0)) > Time.get_ticks_msec() / 1000.0:
				continue
			var p: Vector3 = _states[id]["pos"]
			if ip.distance_to(p) < Cfg.TAG_DISTANCE + 0.35 and absf(ip.y - p.y) < 1.8:
				_infect(id)
				return


func _first_survivor() -> int:
	for id: int in _states:
		if not infected.has(id) and not out.has(id):
			return id
	return 0


func _infect(id: int) -> void:
	if infected.has(id) or out.has(id):
		return
	infected[id] = true
	_apply_roles()
	var pos: Vector3 = _pos_of(id)
	if pos != null:
		Fx.burst(pos + Vector3(0, 1.0, 0), Cfg.CORAL, 1.2)
		Fx.shock(pos + Vector3(0, 0.2, 0), Cfg.CORAL, 2.0)
		Sfx.play_at("impact_punch", pos, self, -2.0, 0.95)
	Net.log_line("INFECT id=%d infected=%d/%d" % [id, infected.size(), _states.size()])
	_broadcast_snapshot()
	var survivors := _states.size() - infected.size()
	if survivors <= 0:
		_end_round("INFECTED WIN — EVERYONE TURNED")


# --- HOT POTATO --------------------------------------------------------

func _tick_potato(dt: float) -> void:
	if potato_id == 0:
		return
	fuse = maxf(0.0, fuse - dt)
	if test_mode:
		if _test_stage == 0 and _elapsed > 3.0:
			_test_stage = 1
			var victim := _first_other_alive(potato_id)
			if victim != 0:
				_give_potato(victim)
			return
		if _test_stage == 1 and _elapsed > 4.5:
			_test_stage = 2
			fuse = 0.1
	if fuse <= 0.0:
		_potato_boom()
		return
	if _potato_immunity > 0.0 or out.has(potato_id):
		return
	var holder_pos: Variant = _pos_of(potato_id)
	if holder_pos == null:
		return
	for id: int in _states:
		if id == potato_id or out.has(id):
			continue
		var p: Vector3 = _states[id]["pos"]
		if holder_pos.distance_to(p) < Cfg.TAG_DISTANCE + 0.35 and absf(holder_pos.y - p.y) < 1.8:
			_give_potato(id)
			return


func _first_other_alive(id: int) -> int:
	for other: int in _states:
		if other != id and not out.has(other):
			return other
	return 0


func _give_potato(id: int) -> void:
	if out.has(id):
		return
	var old := potato_id
	potato_id = id
	fuse = POTATO_FUSE
	_potato_immunity = POTATO_IMMUNITY
	_apply_roles()
	var pos: Vector3 = _pos_of(id)
	if pos != null:
		Fx.burst(pos + Vector3(0, 1.2, 0), Cfg.GOLD, 0.9)
		Sfx.play_at("chip_stack", pos, self, -10.0, 1.1)
	if host:
		Net.log_line("POTATO_PASS %d -> %d" % [old, id])
	_broadcast_snapshot()


func _potato_boom() -> void:
	var victim := potato_id
	if victim == 0:
		return
	var pos: Vector3 = _pos_of(victim)
	if pos == null:
		pos = player.global_position
	out[victim] = true
	potato_id = 0
	fuse = 0.0
	_apply_roles()
	Fx.burst(pos + Vector3(0, 1.0, 0), Cfg.CORAL, 1.8)
	Fx.burst(pos + Vector3(0, 1.0, 0), Cfg.GOLD, 1.4)
	Fx.shock(pos + Vector3(0, 0.2, 0), Cfg.GOLD, 4.0)
	Sfx.play_at("impact_punch", pos, self, 1.0, 0.9)
	Net.log_line("POTATO_BOOM holder=%d" % victim)
	_broadcast_snapshot()

	var alive: Array[int] = []
	for id: int in _states:
		if not out.has(id):
			alive.append(id)
	if alive.size() <= 1:
		var winner := "NOBODY"
		if alive.size() == 1:
			winner = str(Net.players.get(alive[0], {}).get("name", "MEMBER %d" % alive[0]))
		_end_round("LAST ONE STANDING — %s" % winner)
	else:
		_give_potato(alive[0])


# --- shared ------------------------------------------------------------

func _pos_of(id: int) -> Variant:
	if id == local_id:
		return player.global_position
	if _states.has(id):
		return _states[id]["pos"]
	return null


## Test-only transport drop so the host's mid-round repair path is exercised by
## a real ENet peer disconnect, not by deleting a dictionary entry.
func _schedule_test_drop(victim: int) -> void:
	if _test_drop_scheduled:
		return
	_test_drop_scheduled = true
	_drop_after(victim)


func _drop_after(victim: int) -> void:
	await get_tree().create_timer(1.2).timeout
	if running and Net.players.has(victim):
		Net.log_line("TEST_DROP id=%d" % victim)
		Net.drop_peer(victim)


func _role_is_hot(id: int) -> bool:
	match mode_id:
		"tag":
			return id == it_id
		"hush":
			return id == seeker_id
		"infection":
			return infected.has(id)
		"potato":
			return id == potato_id
	return false


func _local_frozen() -> bool:
	if out.has(local_id) or found.has(local_id):
		return true
	if mode_id == "hush" and local_id == seeker_id and seek_delay > 0.0:
		return true
	return false


func _apply_roles() -> void:
	var sig := str([mode_id, it_id, seeker_id, potato_id, found.keys(), infected.keys(), out.keys(), seek_delay > 0.0])
	if sig == _role_sig:
		return
	_role_sig = sig
	player.set_role(_role_is_hot(local_id))
	player.set_frozen(_local_frozen())
	for id: int in remotes:
		remotes[id].set_role(_role_is_hot(int(id)))
		remotes[id].set_out(out.has(int(id)) or found.has(int(id)))
	_update_hud()


func _broadcast_snapshot() -> void:
	var pos := {}
	for id: int in _states:
		var st: Dictionary = _states[id]
		pos[id] = [st["pos"], st["yaw"], st["speed"]]
	Net.broadcast_snapshot({
		"t": time_left, "mode": mode_id, "it": it_id, "seeker": seeker_id,
		"found": found.keys(), "infected": infected.keys(), "potato": potato_id,
		"out": out.keys(), "fuse": fuse, "seek": seek_delay, "pos": pos,
	})


func _on_state_received(id: int, p: Vector3, yaw: float, speed: float) -> void:
	if not host:
		return
	_states[id] = {"pos": p, "yaw": yaw, "speed": speed}
	if remotes.has(id) and not _shot_posed:
		remotes[id].apply_state(p, yaw, speed)


func _on_snapshot(snap: Dictionary) -> void:
	if host:
		return
	time_left = float(snap.get("t", time_left))
	mode_id = str(snap.get("mode", mode_id))
	it_id = int(snap.get("it", it_id))
	seeker_id = int(snap.get("seeker", seeker_id))
	potato_id = int(snap.get("potato", 0))
	fuse = float(snap.get("fuse", 0.0))
	seek_delay = float(snap.get("seek", 0.0))
	_fill_set(found, snap.get("found", []))
	_fill_set(infected, snap.get("infected", []))
	_fill_set(out, snap.get("out", []))
	_apply_roles()
	_update_hud()
	var pos: Dictionary = snap.get("pos", {})
	for id: int in pos:
		if id == local_id:
			continue
		if remotes.has(id):
			var arr: Array = pos[id]
			remotes[id].apply_state(arr[0], arr[1], arr[2])


func _fill_set(target: Dictionary, values: Array) -> void:
	target.clear()
	for v in values:
		target[int(v)] = true


func _on_local_ability(kind: String) -> void:
	Net.send_ability(kind)
	_play_local(kind)


func _play_local(kind: String) -> void:
	if kind == "dash" or kind == "lunge":
		Fx.trail(player, Cfg.MINT)
	elif kind == "shock":
		Fx.shock(player.global_position + Vector3(0, 0.2, 0), Color("7de3ff"), 6.0)
		Fx.burst(player.global_position + Vector3(0, 1.0, 0), Color("7de3ff"), 1.0)
	elif kind == "blink":
		Fx.shock(player.global_position + Vector3(0, 0.2, 0), Color("8fb6ff"), 2.0)
	elif kind == "shield":
		Fx.shock(player.global_position + Vector3(0, 0.2, 0), Color("8fb6ff"), 1.5)


func _on_ability_event(id: int, kind: String) -> void:
	if host and kind == "shield":
		_shield_until[id] = Time.get_ticks_msec() / 1000.0 + 2.0
	if id == local_id:
		return
	if remotes.has(id):
		remotes[id].play_ability(kind)


func _on_roster_changed() -> void:
	if host:
		return
	for id: int in remotes.keys():
		if not Net.players.has(id):
			remotes[id].queue_free()
			remotes.erase(id)


func _on_peer_left(id: int) -> void:
	if not host:
		return
	if remotes.has(id):
		remotes[id].queue_free()
		remotes.erase(id)
	_states.erase(id)
	found.erase(id)
	infected.erase(id)
	out.erase(id)
	var remaining := _states.size()
	Net.log_line("MATCH_CONTINUE mode=%s remaining=%d" % [mode_id, remaining])
	if not running:
		return
	match mode_id:
		"tag":
			if it_id == id and not _states.is_empty():
				var next: int = _states.keys()[0]
				_set_it(next)
				Net.log_line("IT_REASSIGNED to=%d" % next)
		"hush":
			if seeker_id == id:
				var next := _first_hider()
				if next != 0:
					seeker_id = next
					it_id = next
					Net.log_line("SEEKER_REASSIGNED to=%d" % next)
				elif not _states.is_empty():
					_end_round("SEEKER WINS — ALL HIDERS FOUND")
			if running:
				_check_hush_end()
		"infection":
			if infected.is_empty() and not _states.is_empty():
				var next: int = _states.keys()[0]
				infected[next] = true
				Net.log_line("PATIENT_ZERO_REASSIGNED to=%d" % next)
			if running and infected.size() >= _states.size():
				_end_round("INFECTED WIN — EVERYONE TURNED")
		"potato":
			if potato_id == id:
				var next := _first_other_alive(0)
				if next != 0:
					_give_potato(next)
					Net.log_line("POTATO_REASSIGNED to=%d" % next)
				elif not _states.is_empty():
					_end_round("POTATO LOST — ROUND OVER")
	_apply_roles()
	_broadcast_snapshot()


func _on_event(kind: String, data: Dictionary) -> void:
	if kind == "over":
		var result := str(data.get("result", "ROUND OVER"))
		running = false
		Net.log_line("NET_OVER result=%s" % result)
		_show_result(result)


func _end_round(result: String) -> void:
	if not running:
		return
	running = false
	Net.log_line("OVER result=%s" % result)
	Net.broadcast_event("over", {"result": result})
	_show_result(result)


func _test_drive() -> void:
	if not player.scripted:
		player.scripted = true
	if _elapsed > 0.35:
		player.in_sprint = true
		player.in_wish = Vector2(sin(_elapsed * 1.7) * 0.35, 1.0)
	if _elapsed > 1.2 and not _ability_sent:
		_ability_sent = true
		player.try_ability()
		Net.log_line("TEST_ABILITY kind=%s" % Loadout.ability)


# --- HUD ---------------------------------------------------------------

## Screenshot harness: put the host and both puppets in one frame.
func debug_pose_for_shot() -> void:
	_shot_posed = true
	player.global_position = Vector3(0, 1.0, 12.0)
	player.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	var i := 0
	for id: int in remotes:
		var r: RemoteMember = remotes[id]
		r.snap_to(Vector3(-3.0 + i * 6.0, 1.0, 4.0), PI)
		i += 1


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var v := Control.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(v)

	_timer_lbl = Style.label("1:45", 44, Cfg.CREAM, Style.display)
	_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_timer_lbl.offset_top = 18
	v.add_child(_timer_lbl)

	_sub_lbl = Style.label("THE FLOOR · NETWORK · TAG", 12, Cfg.MUTED)
	_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_sub_lbl.offset_top = 64
	v.add_child(_sub_lbl)

	_role_lbl = Style.label("YOU ARE IT", 18, Cfg.CORAL)
	_role_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_role_lbl.offset_left = 38
	_role_lbl.offset_top = 30
	v.add_child(_role_lbl)

	_ability_lbl = Style.label(Loadout.ability_name(), 12, Cfg.MUTED)
	_ability_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_ability_lbl.offset_left = 38
	_ability_lbl.offset_top = -52
	v.add_child(_ability_lbl)

	_cooldown_bar = ColorRect.new()
	_cooldown_bar.color = Cfg.GOLD
	_cooldown_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_cooldown_bar.offset_left = 38
	_cooldown_bar.offset_top = -64
	_cooldown_bar.offset_right = 218
	_cooldown_bar.offset_bottom = -60
	v.add_child(_cooldown_bar)
	_update_hud()


func _role_text() -> String:
	match mode_id:
		"tag":
			return "YOU ARE IT" if local_id == it_id else "RUN"
		"hush":
			if found.has(local_id):
				return "FOUND — SPECTATING"
			if local_id == seeker_id:
				return "SEEKER" if seek_delay <= 0.0 else "SEEKER — WAIT"
			return "STAY HIDDEN"
		"infection":
			return "INFECTED" if infected.has(local_id) else "SURVIVOR"
		"potato":
			if out.has(local_id):
				return "ELIMINATED"
			return "YOU HAVE THE POTATO" if local_id == potato_id else "DON'T GET IT"
	return "RUN"


func _update_hud() -> void:
	if _timer_lbl == null:
		return
	var secs := int(ceil(time_left))
	_timer_lbl.text = "%d:%02d" % [int(secs / 60), secs % 60]
	_role_lbl.text = _role_text()
	var role_color := Cfg.MUTED
	if _role_is_hot(local_id):
		role_color = Cfg.GOLD if mode_id == "potato" else Cfg.CORAL
	elif not _local_frozen():
		role_color = Cfg.MINT
	_role_lbl.add_theme_color_override("font_color", role_color)
	_ability_lbl.text = Loadout.ability_name() + "  ·  Q"
	_cooldown_bar.size.x = 180.0 * (1.0 - player.get_cooldown_ratio())

	var where := "THE HOUSE" if map_id == "house" else "THE FLOOR"
	var sub := "%s · NETWORK · %s" % [where, MODE_TITLE.get(mode_id, mode_id.to_upper())]
	if mode_id == "hush" and seek_delay > 0.0:
		sub += "  ·  SEEKER IN %ds" % int(ceil(seek_delay))
	elif mode_id == "hush":
		sub += "  ·  HIDERS %d" % _hush_remaining()
	elif mode_id == "infection":
		sub += "  ·  INFECTED %d / %d" % [infected.size(), _states.size()]
	elif mode_id == "potato":
		sub += "  ·  FUSE %.1fs" % fuse
	_sub_lbl.text = sub


func _show_result(result: String) -> void:
	if _result_panel != null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(cc)
	_result_panel = PanelContainer.new()
	_result_panel.custom_minimum_size = Vector2(520, 0)
	_result_panel.add_theme_stylebox_override("panel",
		Style.box(Color(0.07, 0.06, 0.1, 0.98), 18, 1, Color(1, 1, 1, 0.1)))
	cc.add_child(_result_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	_result_panel.add_child(v)
	v.add_child(Style.label("ROUND OVER", 12, Cfg.GOLD))
	v.add_child(Style.label(result, 30, Cfg.CREAM, Style.display))
	var back := ClubButton.new()
	back.label_text = "LEAVE SESSION"
	back.custom_minimum_size = Vector2(0, 54)
	back.pressed.connect(func(): leave_requested.emit())
	v.add_child(back)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
