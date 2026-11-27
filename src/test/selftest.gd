class_name SelfTest
extends Node
## Headless proof for the movement + tag rules. Drives the REAL ClubPlayer and
## the REAL Match; nothing here reimplements gameplay maths.
##
##   godot --headless --path . --quit-after 1200 -- --selftest
##
## Prints PASS/FAIL per assertion and exits with the failure count.

const STEP := 1.0 / 60.0

var passed := 0
var failed := 0


func run() -> int:
	Engine.time_scale = 1.0
	# Headless runs process frames far faster than the 60 Hz physics tick, and
	# `--quit-after` counts process frames. Pin the rate so simulated seconds are
	# real seconds and the test always gets its full window.
	Engine.max_fps = 60
	Engine.physics_ticks_per_second = 60
	print("SELFTEST begin (Godot %s)" % Engine.get_version_info()["string"])
	await _test_crouch()
	await _test_slide()
	await _test_walls()
	await _test_jump_height()
	await _test_hub_doorway()
	await _test_bhop()
	await _test_movement_metrics()
	await _test_role_abilities()
	await _test_tag_win()
	await _test_animations()
	await _test_driven_animation()
	await _test_air_animation()
	await _test_lean()
	await _test_camera_pitch()
	await _test_camera_wall()
	await _test_camera_strafe()
	await _test_camera_swap()
	await _test_seat_height()
	await _test_tag()
	await _test_modes()
	await _test_mode_wins()
	print("SELFTEST end: %d passed, %d failed" % [passed, failed])
	return 0 if failed == 0 else 1


func _assert(name: String, cond: bool, detail: String) -> void:
	if cond:
		passed += 1
		print("PASS  %s  (%s)" % [name, detail])
	else:
		failed += 1
		print("FAIL  %s  (%s)" % [name, detail])


func _wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().physics_frame
		t += STEP


func _real_wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func _world() -> Array:
	var root := Node3D.new()
	root.name = "TestWorld"
	add_child(root)

	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	cs.shape = box
	floor_body.add_child(cs)
	root.add_child(floor_body)

	var p := ClubPlayer.new()
	p.name = "TestPlayer"
	p.set_scripted(true)
	root.add_child(p)
	p.global_position = Vector3(0, 1.0, 0)
	return [root, p]


func _test_crouch() -> void:
	var pair := _world()
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	await _wait(0.4)

	var stand := p.collision_height()
	p.in_crouch = true
	await _wait(0.35)
	var crouched := p.collision_height()
	_assert("crouch lowers collision height", crouched < stand - 0.3,
		"stand=%.2f crouch=%.2f" % [stand, crouched])
	_assert("crouch height matches CROUCH_H", absf(crouched - Cfg.CROUCH_H) < 0.02,
		"%.2f vs %.2f" % [crouched, Cfg.CROUCH_H])

	p.in_crouch = false
	await _wait(0.4)
	_assert("standing restores height", absf(p.collision_height() - stand) < 0.02,
		"%.2f vs %.2f" % [p.collision_height(), stand])

	root.queue_free()
	await _wait(0.1)


func _test_slide() -> void:
	var pair := _world()
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	await _wait(0.3)

	p.in_sprint = true
	p.in_wish = Vector2(0, 1)
	await _wait(1.4)
	var sprint_speed := p.horizontal_speed()

	p.in_crouch = true
	await _wait(0.06)
	var start := p.horizontal_speed()
	var engaged := p.is_sliding()
	await _wait(0.45)
	var after := p.horizontal_speed()

	_assert("sprint reaches sprint speed", sprint_speed > Cfg.WALK + 0.8,
		"sprint=%.2f walk=%.2f" % [sprint_speed, Cfg.WALK])
	_assert("slide engages from sprint", engaged, "sliding=%s" % engaged)
	_assert("slide decelerates over 0.45 s", after < start - 0.3,
		"start=%.2f after=%.2f drop=%.2f" % [start, after, start - after])
	_assert("slide stays above a stall", after > 1.0, "after=%.2f" % after)

	p.in_crouch = false
	p.in_sprint = false
	p.in_wish = Vector2.ZERO
	root.queue_free()
	await _wait(0.1)


## Concrete metres/second proof for the motor, not adjectives. Baseline is a
## held sprint; the chain uses timed hops plus a strafe; the slide is a real
## crouch-slide from sprint; the mistimed case deliberately waits out the hop
## window and is punished by ground friction.
func _test_movement_metrics() -> void:
	var pair := _world()
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	await _wait(0.35)

	p.in_sprint = true
	p.in_wish = Vector2(0, 1)
	await _wait(1.5)
	var baseline := p.horizontal_speed()
	print("MOVEMENT baseline_run=%.2f m/s (walk=%.2f sprint=%.2f)" % [baseline, Cfg.WALK, Cfg.SPRINT])
	_assert("movement baseline reaches sprint", baseline > Cfg.SPRINT * 0.94,
		"baseline=%.2f sprint=%.2f" % [baseline, Cfg.SPRINT])

	# Chained hops with a diagonal air strafe.
	p.in_wish = Vector2(0.35, 1.0)
	var best := baseline
	var hops := 0
	var was_floor := p.is_on_floor()
	var t := 0.0
	while t < 5.0:
		p.in_jump = p.is_on_floor()
		await get_tree().physics_frame
		t += STEP
		best = maxf(best, p.horizontal_speed())
		if p.is_on_floor() and not was_floor:
			hops += 1
		was_floor = p.is_on_floor()
	p.in_jump = false
	print("MOVEMENT chained_bhop=%.2f m/s hops=%d strafe=0.35 gain=%.2f cap=%.2f" % [best, hops, best - baseline, Cfg.SPEED_CAP])
	_assert("movement chained hops gain measurable speed", best > baseline + 1.0,
		"baseline=%.2f chained=%.2f gain=%.2f" % [baseline, best, best - baseline])
	_assert("movement chained hops stay under the cap", best <= Cfg.SPEED_CAP + 0.02,
		"chained=%.2f cap=%.2f" % [best, Cfg.SPEED_CAP])

	# Reset and build a clean sprint, then crouch-slide out of it.
	p.in_jump = false
	p.in_wish = Vector2.ZERO
	p.in_sprint = false
	p.in_crouch = false
	p.global_position = Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _wait(0.4)
	p.in_sprint = true
	p.in_wish = Vector2(0, 1)
	await _wait(1.2)
	var sprint := p.horizontal_speed()
	p.in_crouch = true
	await _wait(0.06)
	var slide_start := p.horizontal_speed()
	var engaged := p.is_sliding()
	await _wait(0.45)
	var slide_after := p.horizontal_speed()
	print("MOVEMENT crouch_slide sprint=%.2f start=%.2f after=%.2f engaged=%s" % [sprint, slide_start, slide_after, engaged])
	_assert("movement slide engages from a sprint", engaged, "sliding=%s" % engaged)
	_assert("movement slide starts with a burst over sprint", slide_start > sprint + 0.4,
		"sprint=%.2f slide=%.2f" % [sprint, slide_start])
	_assert("movement slide preserves speed above sprint for 0.45 s", slide_after > Cfg.SPRINT,
		"after=%.2f sprint=%.2f" % [slide_after, Cfg.SPRINT])

	# Mistime: land, wait out the bhop window, then jump. Friction must bite.
	p.in_crouch = false
	p.in_jump = false
	p.global_position = Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await _wait(0.5)
	p.in_wish = Vector2(0, 1)
	p.in_sprint = true
	await _wait(0.6)
	var chain_peak := 0.0
	t = 0.0
	while t < 3.0:
		p.in_jump = p.is_on_floor()
		await get_tree().physics_frame
		t += STEP
		chain_peak = maxf(chain_peak, p.horizontal_speed())
	p.in_jump = false
	# Keep holding forward/sprint: the failure should be lost momentum, not the
	# player deliberately letting go of every input.
	# wait until landed, then deliberately miss the 0.14 s chain window
	var land_guard := 0
	while not p.is_on_floor() and land_guard < 240:
		await get_tree().physics_frame
		land_guard += 1
	var landed := p.horizontal_speed()
	print("MOVEMENT mistime_land_guard=%d on_floor=%s pos=%s vel=%s" % [land_guard, p.is_on_floor(), str(p.global_position), str(p.velocity)])
	await _wait(0.42)
	var mistimed_before := p.horizontal_speed()
	p.in_jump = true
	await _wait(0.08)
	p.in_jump = false
	var mistimed_after := p.horizontal_speed()
	print("MOVEMENT mistimed_hop peak=%.2f landed=%.2f after_wait=%.2f after_jump=%.2f" % [chain_peak, landed, mistimed_before, mistimed_after])
	_assert("movement mistimed hop loses speed", mistimed_after < chain_peak - 0.5,
		"peak=%.2f mistimed=%.2f" % [chain_peak, mistimed_after])

	p.in_jump = false
	p.in_sprint = false
	p.in_wish = Vector2.ZERO
	root.queue_free()
	await _wait(0.15)


## Per-ability contract: every chaser and runner tool fires once, applies a real
## effect to the live round, and is blocked by its own cooldown.
func _test_role_abilities() -> void:
	Loadout.ability = "dash"
	var m := Match.new()
	m.name = "AbilityMatch"
	add_child(m)
	m.start(Vector3.ZERO, "tag")
	await _wait(0.25)
	for b in m.bots:
		b.set_physics_process(false)
		b.velocity = Vector3.ZERO
	var p: ClubPlayer = m.player
	p.set_scripted(true)

	# --- chaser kit -----------------------------------------------------
	m.it_actor = p
	m._apply_roles()
	p.debug_reset_ability_cooldowns()
	p.velocity = Vector3.ZERO
	var lunge_ok := p.try_ability()
	await _wait(0.05)
	var lunge_speed := p.horizontal_speed()
	var lunge_blocked := not p.try_ability()
	print("ABILITY chaser_lunge fired=%s speed=%.2f cd_block=%s" % [lunge_ok, lunge_speed, lunge_blocked])
	_assert("chaser lunge fires and moves", lunge_ok and lunge_speed > 5.0,
		"fired=%s speed=%.2f" % [lunge_ok, lunge_speed])
	_assert("chaser lunge respects cooldown", lunge_blocked and p.get_cooldown_ratio() > 0.0,
		"blocked=%s cd=%.2f" % [lunge_blocked, p.get_cooldown_ratio()])

	p.debug_reset_ability_cooldowns()
	var scan_ok := p.try_role_ability(1)
	await _wait(0.08)
	var scan_marks := m._scan_marks.size()
	var scan_blocked := not p.try_role_ability(1)
	print("ABILITY chaser_scan fired=%s marks=%d cd_block=%s" % [scan_ok, scan_marks, scan_blocked])
	_assert("chaser scan reveals runners", scan_ok and scan_marks > 0,
		"fired=%s marks=%d" % [scan_ok, scan_marks])
	_assert("chaser scan respects cooldown", scan_blocked and p.role_cooldown_remaining(1) > 0.0,
		"blocked=%s cd=%.1f" % [scan_blocked, p.role_cooldown_remaining(1)])

	p.debug_reset_ability_cooldowns()
	var trap_ok := p.try_role_ability(2)
	await _wait(0.06)
	var traps := m._traps.size()
	var victim: ClubBot = m.bots[1]
	if traps > 0:
		victim.global_position = m._traps[0]["pos"]
	m._tick_role_effects(0.1)
	var slowed := victim.slow_t > 0.0
	var trap_blocked := not p.try_role_ability(2)
	print("ABILITY chaser_trap fired=%s zones=%d runner_slowed=%s cd_block=%s" % [trap_ok, traps, slowed, trap_blocked])
	_assert("chaser trap slows a runner", trap_ok and traps > 0 and slowed,
		"fired=%s zones=%d slow=%.2f" % [trap_ok, traps, victim.slow_t])
	_assert("chaser trap respects cooldown", trap_blocked and p.role_cooldown_remaining(2) > 0.0,
		"blocked=%s cd=%.1f" % [trap_blocked, p.role_cooldown_remaining(2)])

	# --- runner kit -----------------------------------------------------
	m.it_actor = m.bots[0]
	m._apply_roles()
	p.debug_reset_ability_cooldowns()
	p.velocity = Vector3.ZERO
	var escape_ok := p.try_ability()
	await _wait(0.05)
	var escape_speed := p.horizontal_speed()
	var escape_blocked := not p.try_ability()
	print("ABILITY runner_escape fired=%s speed=%.2f cd_block=%s" % [escape_ok, escape_speed, escape_blocked])
	_assert("runner escape fires and moves", escape_ok and escape_speed > 5.0,
		"fired=%s speed=%.2f" % [escape_ok, escape_speed])
	_assert("runner escape respects cooldown", escape_blocked and p.get_cooldown_ratio() > 0.0,
		"blocked=%s cd=%.2f" % [escape_blocked, p.get_cooldown_ratio()])

	p.debug_reset_ability_cooldowns()
	var decoy_ok := p.try_role_ability(1)
	await _wait(0.06)
	var decoy_node: Node3D = m._decoy
	m._update_bots()
	var decoy_pulled: bool = m.it_actor != null and (m.it_actor as ClubBot).target == decoy_node
	var decoy_blocked := not p.try_role_ability(1)
	print("ABILITY runner_decoy fired=%s chaser_pulled=%s cd_block=%s" % [decoy_ok, decoy_pulled, decoy_blocked])
	_assert("runner decoy pulls the chaser", decoy_ok and decoy_node != null and decoy_pulled,
		"fired=%s node=%s pulled=%s" % [decoy_ok, str(decoy_node), decoy_pulled])
	_assert("runner decoy respects cooldown", decoy_blocked and p.role_cooldown_remaining(1) > 0.0,
		"blocked=%s cd=%.1f" % [decoy_blocked, p.role_cooldown_remaining(1)])

	p.debug_reset_ability_cooldowns()
	var stamina_ok := p.try_role_ability(2)
	p.velocity = Vector3.ZERO
	p.in_sprint = true
	p.in_wish = Vector2(0, 1)
	await _wait(1.2)
	var stamina_speed := p.horizontal_speed()
	var stamina_blocked := not p.try_role_ability(2)
	print("ABILITY runner_stamina fired=%s speed=%.2f sprint=%.2f cd_block=%s" % [stamina_ok, stamina_speed, Cfg.SPRINT, stamina_blocked])
	_assert("runner stamina raises top speed", stamina_ok and stamina_speed > Cfg.SPRINT * 1.08,
		"fired=%s speed=%.2f sprint=%.2f" % [stamina_ok, stamina_speed, Cfg.SPRINT])
	_assert("runner stamina respects cooldown", stamina_blocked and p.role_cooldown_remaining(2) > 0.0,
		"blocked=%s cd=%.1f" % [stamina_blocked, p.role_cooldown_remaining(2)])

	p.in_sprint = false
	p.in_wish = Vector2.ZERO
	m.queue_free()
	await _wait(0.15)


func _test_tag_win() -> void:
	var m := Match.new()
	m.name = "TagWin"
	add_child(m)
	m.start(Vector3.ZERO, "tag")
	await _wait(0.25)
	for b in m.bots:
		b.set_physics_process(false)
		b.velocity = Vector3.ZERO
	m.it_actor = m.bots[0]
	m._apply_roles()
	m.debug_expire(0.1)
	await _wait(0.45)
	var result := last_result_text(m)
	print("ROUND tag_finish running=%s result=%s" % [m.running, result])
	_assert("tag round reaches a win/lose state", not m.running and (result.contains("WINS") or result.contains("YOU WIN")),
		"running=%s result=%s" % [m.running, result])
	_assert("tag round rewards the clean runner", result.contains("YOU"),
		"result=%s" % result)
	m.queue_free()
	await _wait(0.15)


func last_result_text(m: Match) -> String:
	return m.last_result


func _test_animations() -> void:
	var a := AnimatedCharacter.new()
	add_child(a)
	a.build(Color.WHITE)
	var required := [
		"idle", "walk", "run", "jump", "crouch_down", "crouch_up", "crouch",
		"dash", "slide", "run_stairs", "walk_stairs",
		"punch1", "punch2", "punch3", "punch4",
	]
	var missing: Array[String] = []
	for clip: String in required:
		if not a.has_animation(clip):
			missing.append(clip)
	print("ANIMATION clips=%d missing=%s" % [required.size(), str(missing)])
	_assert("all authored animation clips are present", missing.is_empty(),
		"missing=%s" % str(missing))
	var worst_root := 0.0
	var worst_any := 0.0
	for clip: String in required:
		worst_root = maxf(worst_root, a.clip_horizontal_travel(clip))
		worst_any = maxf(worst_any, a.clip_position_travel(clip))
	print("ANIMATION root_horizontal_travel=%.5f root_position_travel=%.5f" % [worst_root, worst_any])
	_assert("animation roots have no horizontal travel", worst_root < 0.00001,
		"worst=%.5f" % worst_root)
	_assert("all animation position tracks are static", worst_any < 0.00001,
		"worst=%.5f" % worst_any)
	_assert("punch has four distinct beats",
		a.animation_length("punch1") > 0.1 and a.animation_length("punch4") > 0.1,
		"p1=%.2f p4=%.2f" % [a.animation_length("punch1"), a.animation_length("punch4")])
	_assert("jump uses the full authored length", a.animation_length("jump") > 1.7,
		"jump=%.2f s" % a.animation_length("jump"))
	_assert("turn and 180 clips are not loaded",
		not a.has_animation("run_180") and not a.has_animation("change_direction"),
		"run_180=%s change=%s" % [a.has_animation("run_180"), a.has_animation("change_direction")])

	a.clear_punch_history()
	a.punch()
	await _anim_ticks(a, 1.45)
	var one := a.punch_history()
	print("ANIMATION one_click=%s" % str(one))
	_assert("one punch click plays the full four-beat combo",
		one.size() == 4 and one[0] == "punch1" and one[1] == "punch2"
		and one[2] == "punch3" and one[3] == "punch4",
		"history=%s" % str(one))

	a.queue_free()
	await _wait(0.1)


## Drive the real motor with held scripted inputs. Every physics frame compares
## the visible mesh root and skinned bone origins against the player root, and
## the lowest foot against the floor. This catches animation root motion that a
## state-name assertion alone cannot.
func _test_driven_animation() -> void:
	var pair := _world()
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	await _wait(0.5)
	p.test_capture = true

	await _reset_driven(p)
	var idle := await _run_driven(p, "idle", 0.45, "idle", 0.0, 0.001)
	_assert_driven(idle, "idle", 0.0, 0.001)

	await _reset_driven(p)
	p.in_wish = Vector2(0, 1)
	var walk := await _run_driven(p, "walk", 0.8, "walk", 0.35, 0.004)
	_assert_driven(walk, "walk", 0.35, 0.004)

	await _reset_driven(p)
	p.in_wish = Vector2(1, 0)
	var strafe := await _run_driven(p, "strafe", 0.8, "walk", 0.35, 0.004)
	_assert_driven(strafe, "strafe", 0.35, 0.004)

	await _reset_driven(p)
	p.in_wish = Vector2(0, 1)
	p.in_jump = true
	await get_tree().physics_frame
	p.in_jump = false
	var jump := await _run_driven(p, "jump", 1.0, "jump", 0.35, 0.004)
	_assert_driven(jump, "jump", 0.35, 0.004)

	await _reset_driven(p)
	p.in_crouch = true
	p.in_wish = Vector2(0, 1)
	await _wait(0.7)
	var crouch := await _run_driven(p, "crouch", 0.8, "crouch", 0.15, 0.002)
	_assert_driven(crouch, "crouch", 0.15, 0.002)

	await _reset_driven(p)
	p.in_wish = Vector2.ZERO
	p.test_capture = true
	p.body.clear_punch_history()
	Input.action_press("punch")
	await get_tree().physics_frame
	Input.action_release("punch")
	var punch := await _run_driven(p, "punch", 1.4, "punch", 0.0, 0.004)
	_assert_driven(punch, "punch", 0.0, 0.004)
	var history := p.body.punch_history()
	print("DRIVEN punch_history=%s" % str(history))
	_assert("driven punch starts the full authored combo", history.size() == 4,
		"history=%s" % str(history))

	p.in_crouch = false
	p.in_wish = Vector2.ZERO
	p.test_capture = false
	root.queue_free()
	await _wait(0.2)


func _reset_driven(p: ClubPlayer) -> void:
	p.in_wish = Vector2.ZERO
	p.in_sprint = false
	p.in_crouch = false
	p.in_jump = false
	Input.action_release("punch")
	p.global_position = Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	p.rotation.y = 0.0
	await _wait(0.55)


func _run_driven(p: ClubPlayer, label: String, seconds: float,
		expected: String, min_move: float, min_pose: float) -> Dictionary:
	var root_start := p.global_position
	var mesh_worst := 0.0
	var hips_worst := 0.0
	var feet_min := INF
	var states: Dictionary = {}
	var first_pose := PackedVector3Array()
	var pose_motion := 0.0
	var frames := 0
	var t := 0.0
	while t < seconds:
		await get_tree().physics_frame
		t += STEP
		frames += 1
		if p.body == null:
			break
		var rp := p.global_position
		var mesh := p.body.mesh_world_position()
		var hips := p.body.hips_world_position()
		mesh_worst = maxf(mesh_worst, Vector2(mesh.x - rp.x, mesh.z - rp.z).length())
		hips_worst = maxf(hips_worst, Vector2(hips.x - rp.x, hips.z - rp.z).length())
		var foot := p.body.lowest_foot_world_y()
		if not is_nan(foot):
			feet_min = minf(feet_min, foot)
		var state := p.body.current_state()
		states[state] = int(states.get(state, 0)) + 1
		var pose := p.body.pose_world_points()
		if first_pose.is_empty():
			first_pose = pose
		else:
			for i in mini(pose.size(), first_pose.size()):
				pose_motion = maxf(pose_motion, (pose[i] - first_pose[i]).length())

	var root_move := Vector2(p.global_position.x - root_start.x,
		p.global_position.z - root_start.z).length()
	var saw := false
	for s: String in states.keys():
		if expected == "punch" and s.begins_with("punch"):
			saw = true
		elif s == expected:
			saw = true
	var result := {
		"label": label, "frames": frames, "root_move": root_move,
		"mesh_worst": mesh_worst, "hips_worst": hips_worst,
		"feet_min": feet_min, "pose_motion": pose_motion,
		"states": str(states), "saw": saw,
	}
	print("DRIVEN %s frames=%d root_move=%.3f mesh_vs_root=%.5f hips_vs_root=%.5f feet_min=%.3f pose_motion=%.4f states=%s" % [
		label, frames, root_move, mesh_worst, hips_worst, feet_min, pose_motion, str(states)])
	return result


func _assert_driven(r: Dictionary, label: String, min_move: float, min_pose: float) -> void:
	_assert("%s state was reached" % label, bool(r["saw"]), "states=%s" % r["states"])
	_assert("%s covers ground from motor input" % label, float(r["root_move"]) >= min_move,
		"moved=%.3f need=%.3f" % [r["root_move"], min_move])
	_assert("%s mesh root tracks the player root" % label, float(r["mesh_worst"]) < 0.002,
		"worst=%.5f" % r["mesh_worst"])
	_assert("%s hip root tracks the player root" % label, float(r["hips_worst"]) < 0.02,
		"worst=%.5f" % r["hips_worst"])
	_assert("%s feet stay out of the floor" % label, float(r["feet_min"]) >= -0.02,
		"lowest=%.3f" % r["feet_min"])
	_assert("%s animation is not frozen" % label, float(r["pose_motion"]) >= min_pose,
		"pose=%.5f need=%.5f" % [r["pose_motion"], min_pose])


func _test_air_animation() -> void:
	var a := AnimatedCharacter.new()
	add_child(a)
	a.build(Color.WHITE)
	a.animate(STEP, 6.0, false)
	_assert("airborne movement keeps the jump clip",
		a.current_state() == "jump", "state=%s" % a.current_state())
	a.queue_free()
	await _wait(0.1)


func _anim_ticks(a: AnimatedCharacter, seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		a.animate(STEP, 0.0, true)
		await get_tree().physics_frame
		t += STEP


func _test_walls() -> void:
	var pair := _world()
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	await _wait(0.3)

	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 2.0, -3.0)
	wall.collision_layer = 1
	wall.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(12, 4, 0.5)
	cs.shape = sh
	wall.add_child(cs)
	root.add_child(wall)

	p.global_position = Vector3(0, 1.2, 0)
	p.velocity = Vector3.ZERO
	p.in_sprint = true
	p.in_wish = Vector2(0, 1)
	await _wait(2.0)
	var z := p.global_position.z

	_assert("player reaches the wall", z < -1.2, "z=%.2f" % z)
	_assert("player does not pass through the wall", z > -3.0, "z=%.2f wall at -3.0" % z)
	_assert("player is stopped outside the wall face", z > -2.9, "z=%.2f" % z)

	p.in_sprint = false
	p.in_wish = Vector2.ZERO
	root.queue_free()
	await _wait(0.1)


func _test_jump_height() -> void:
	var pair := _world()
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	await _wait(0.4)

	var base_y := p.global_position.y
	var peak := base_y
	p.in_jump = true
	await _wait(0.05)
	p.in_jump = false
	for i in 70:
		await get_tree().physics_frame
		peak = maxf(peak, p.global_position.y)
	var apex := peak - base_y

	_assert("jump clears a 1 m crate", apex >= 1.0, "apex=%.2f m" % apex)
	_assert("jump stays readable, not floaty", apex < 1.6, "apex=%.2f m" % apex)

	root.queue_free()
	await _wait(0.1)


func _test_hub_doorway() -> void:
	var hub := Hub.new()
	add_child(hub)
	await _wait(0.4)

	var p: ClubPlayer = hub.player
	p.set_scripted(true)
	# clear approach between the centre lounge and the north doorway
	p.global_position = Vector3(0, 1.2, -14.5)
	p.rotation_degrees.y = 0.0
	p.in_sprint = true
	p.in_wish = Vector2(0, 1)
	await _wait(2.6)

	var z := p.global_position.z
	var y := p.global_position.y
	_assert("hub doorway is walkable into the wing", z < -19.0,
		"z=%.2f (wing mouth at -17)" % z)
	_assert("player stays on the floor while crossing", y > -1.0, "y=%.2f" % y)

	p.in_sprint = false
	p.in_wish = Vector2.ZERO
	hub.queue_free()
	await _wait(0.2)


func _test_bhop() -> void:
	var pair := _world()
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	await _wait(0.3)

	p.in_sprint = true
	p.in_wish = Vector2(0, 1)
	await _wait(1.2)
	var run_speed := p.horizontal_speed()

	var best := run_speed
	var hops := 0
	var was_floor := p.is_on_floor()
	var t := 0.0
	while t < 6.5:
		p.in_jump = p.is_on_floor()
		await get_tree().physics_frame
		t += STEP
		var s := p.horizontal_speed()
		best = maxf(best, s)
		if p.is_on_floor() and not was_floor:
			hops += 1
		was_floor = p.is_on_floor()
	p.in_jump = false

	_assert("bhop chains hops", hops >= 4, "hops=%d" % hops)
	_assert("bhop gains speed beyond sprint", best > Cfg.SPRINT * 1.05,
		"best=%.2f sprint=%.2f" % [best, Cfg.SPRINT])
	_assert("bhop gains speed beyond walk by 25%", best > Cfg.WALK * 1.25,
		"best=%.2f walk=%.2f" % [best, Cfg.WALK])
	_assert("speed cap holds", best <= Cfg.SPEED_CAP + 0.02,
		"best=%.2f cap=%.2f" % [best, Cfg.SPEED_CAP])

	root.queue_free()
	await _wait(0.1)


## Every admin-selectable mode must assign its roles and reach an end state.
func _test_modes() -> void:
	for id: String in ["hush", "infection", "potato"]:
		var origin := Vector3(30, 0, 30)
		var m := Match.new()
		m.name = "Test_%s" % id
		add_child(m)
		m.start(origin, id)
		await _wait(0.35)

		var roles_ok := false
		var detail := ""
		match id:
			"hush":
				roles_ok = m.it_actor != null and m._seek_delay > 0.0
				detail = "seekers=1 blind=%.1fs" % m._seek_delay
			"infection":
				roles_ok = m._infected.size() == 1
				detail = "infected=%d" % m._infected.size()
			"potato":
				roles_ok = m._potato_holder != null
				detail = "holder=%s" % m._actor_name(m._potato_holder)

		_assert("%s assigns its roles" % id, roles_ok, detail)
		_assert("%s follows the admin origin" % id,
			m.arena.position.distance_to(origin) < 0.01
			and m.player.global_position.distance_to(origin) < 60.0,
			"arena=%s player dist=%.1f" % [str(m.arena.position), m.player.global_position.distance_to(origin)])

		m.debug_expire(0.2)
		await _wait(0.7)
		_assert("%s reaches an end state" % id, not m.running and m.last_result != "",
			"running=%s result=%s" % [m.running, m.last_result])

		m.queue_free()
		await _wait(0.15)


## The signature win condition of each mode, driven through the real rules.
func _test_mode_wins() -> void:
	var hush := Match.new()
	add_child(hush)
	hush.start(Vector3.ZERO, "hush")
	await _wait(0.25)
	for a in hush.actors:
		if a != hush.it_actor:
			hush._find_hider(a)
	await _wait(0.1)
	_assert("hush ends when every hider is found",
		not hush.running and hush.last_result.begins_with("SEEKER WINS"), hush.last_result)
	hush.queue_free()
	await _wait(0.1)

	var inf := Match.new()
	add_child(inf)
	inf.start(Vector3.ZERO, "infection")
	await _wait(0.25)
	for a in inf.actors:
		if not inf._infected.has(a):
			inf._infect(a)
	await _wait(0.1)
	_assert("infection ends when everyone is turned",
		not inf.running and inf.last_result.begins_with("INFECTED WIN"), inf.last_result)
	inf.queue_free()
	await _wait(0.1)

	var spud := Match.new()
	add_child(spud)
	spud.start(Vector3.ZERO, "potato")
	await _wait(0.25)
	var guard := 0
	while spud.running and guard < 12:
		spud._potato_blow()
		guard += 1
		await _wait(0.08)
	Engine.time_scale = 1.0
	_assert("potato ends on the last survivor",
		not spud.running and spud.last_result.begins_with("LAST ONE STANDING"), spud.last_result)
	spud.queue_free()
	await _wait(0.15)


## Sitting must use the furniture's seat height, even if E is pressed mid-jump.
func _test_seat_height() -> void:
	var pair := _world()
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	p.global_position = Vector3(0, 2.4, 4)
	p.sit_at(Vector3(0.5, 0.53, 4.0), 0.0)
	_assert("sitting snaps to the seat height from mid-air",
		absf(p.global_position.y - 0.53) < 0.001,
		"y=%.3f" % p.global_position.y)
	p.stand_up()
	root.queue_free()
	await _wait(0.1)


## Sprint and dash must visibly pitch the camera into the run.
func _test_lean() -> void:
	var pair := _world()
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	Loadout.ability = "dash"
	await _wait(0.4)

	p.in_sprint = true
	p.in_wish = Vector2(0, 1)
	await _wait(1.5)
	var sprint_lean := p.camera_lean()

	p.try_ability()
	await _wait(0.12)
	var dash_lean := p.camera_lean()

	_assert("sprint leans the camera forward", sprint_lean < -0.02,
		"lean=%.3f rad" % sprint_lean)
	_assert("dash leans harder than sprint", dash_lean < sprint_lean - 0.03,
		"sprint=%.3f dash=%.3f" % [sprint_lean, dash_lean])

	p.in_sprint = false
	p.in_wish = Vector2.ZERO
	root.queue_free()
	await _wait(0.1)


## Third-person pitch must follow the mouse in the intuitive direction, clamp at
## both ends, and scale linearly with the sensitivity setting. Real events only.
func _test_camera_pitch() -> void:
	var ct := CameraTest.new()
	add_child(ct)
	var pair := ct.rig()
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	Loadout.third_person = true
	Loadout.sensitivity = 1.0
	p.camera_override = -1
	ct.capture()
	await ct.settle(0.5)

	var base := p.camera_pitch()
	ct.mouse(0.0, 90.0)
	await ct.settle(0.4)
	var down := p.camera_pitch()
	var expected := -90.0 * Cfg.MOUSE_SENS
	_assert("3P mouse-down looks down by the input delta",
		down < base - 0.05 and absf(down - expected) < 0.04,
		"base=%.3f down=%.3f expected=%.3f calls=%d rel=%s" % [base, down, expected, p.motion_calls, str(p.last_motion)])

	p.debug_set_pitch(0.0)
	await ct.settle(0.35)
	ct.mouse(0.0, 900.0)
	await ct.settle(0.5)
	var low := p.camera_pitch()
	_assert("3P down pitch clamps at the boom limit", low <= -0.85 and low >= -1.02,
		"pitch=%.3f limit=%.2f" % [low, ClubPlayer.THIRD_MIN_PITCH])

	p.debug_set_pitch(0.0)
	await ct.settle(0.35)
	ct.mouse(0.0, -900.0)
	await ct.settle(0.5)
	var high := p.camera_pitch()
	_assert("3P mouse-up looks up and clamps", high >= 0.75 and high <= 0.92,
		"pitch=%.3f limit=%.2f" % [high, ClubPlayer.THIRD_MAX_PITCH])

	# sensitivity: the same 20 px nudge should scale nearly linearly
	Loadout.sensitivity = 0.5
	p.debug_set_pitch(0.0)
	await ct.settle(0.4)
	ct.mouse(0.0, 20.0)
	await ct.settle(0.4)
	var slow := absf(p.debug_pitch())
	Loadout.sensitivity = 1.5
	p.debug_set_pitch(0.0)
	await ct.settle(0.4)
	ct.mouse(0.0, 20.0)
	await ct.settle(0.4)
	var fast := absf(p.debug_pitch())
	_assert("3P sensitivity scales the look rate",
		fast > slow * 2.4 and fast < slow * 3.6 and slow < 0.06 and fast < 0.12,
		"0.5x=%.4f 1.5x=%.4f ratio=%.2f" % [slow, fast, fast / maxf(slow, 0.0001)])

	Loadout.sensitivity = 1.0
	Loadout.third_person = false
	ct.release_all()
	root.queue_free()
	await _wait(0.15)


## Back into a wall: shorten along the arm, keep height, never enter the wall,
## then re-extend smoothly when the wall is left behind.
func _test_camera_wall() -> void:
	var ct := CameraTest.new()
	add_child(ct)
	var pair := ct.rig(3.2)
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	Loadout.third_person = true
	p.camera_override = -1
	p.set_scripted(false)
	ct.capture()
	await ct.settle(0.6)

	# S walks backward into the wall behind the player
	ct.key(KEY_S, true)
	await ct.settle(1.2)
	ct.key(KEY_S, false)
	await ct.settle(0.2)

	var wall_face := 3.0
	var z := p.camera_world_pos().z
	var y := p.camera_world_pos().y
	var d := p.camera_distance()
	_assert("3P boom shortens against a wall", d < 3.3 and d > 0.15,
		"arm=%.2f m" % d)
	_assert("3P boom never enters the wall", z < wall_face - 0.05,
		"camera z=%.2f wall face=%.2f" % [z, wall_face])
	_assert("3P wall contact does not drop the camera", y > p.global_position.y + 0.5,
		"cam y=%.2f player y=%.2f" % [y, p.global_position.y])
	_assert("3P body hide state matches the arm length",
		p.body_visible() == (d > ClubPlayer.BODY_HIDE_DIST),
		"visible=%s arm=%.2f threshold=%.2f" % [p.body_visible(), d, ClubPlayer.BODY_HIDE_DIST])

	# walk away: the arm must grow back without a pop
	ct.key(KEY_W, true)
	var worst_step := 0.0
	var lowest := 99.0
	var prev := p.camera_distance()
	var t := 0.0
	while t < 1.8:
		await get_tree().physics_frame
		t += STEP
		var cur := p.camera_distance()
		worst_step = maxf(worst_step, absf(cur - prev))
		lowest = minf(lowest, p.camera_world_pos().y)
		prev = cur
	ct.key(KEY_W, false)
	await ct.settle(0.4)

	_assert("3P boom re-extends fully", p.camera_distance() > 3.9,
		"arm=%.2f m" % p.camera_distance())
	_assert("3P boom re-extends without snapping", worst_step < 0.45,
		"worst frame step=%.2f m" % worst_step)
	_assert("3P re-extension never dips to the floor", lowest > 0.5,
		"lowest camera y=%.2f" % lowest)

	# a wall closer than the minimum arm: hide the body, keep the near plane clear
	ct.release_all()
	root.queue_free()
	await _wait(0.15)
	var pair2 := ct.rig(1.2)
	var root2: Node3D = pair2[0]
	var p2: ClubPlayer = pair2[1]
	Loadout.third_person = true
	p2.camera_override = -1
	await ct.settle(0.8)
	_assert("3P close wall hides the body instead of clipping it",
		not p2.body_visible() and p2.camera_distance() > 0.15 and p2.camera_distance() < 1.55,
		"visible=%s arm=%.2f" % [p2.body_visible(), p2.camera_distance()])
	_assert("3P close wall stays on the player's side",
		p2.camera_world_pos().z < 1.0, "camera z=%.2f wall face=1.0" % p2.camera_world_pos().z)

	ct.release_all()
	root2.queue_free()
	Loadout.third_person = false
	await _wait(0.15)


## Strafing along a wall must not push the camera through it or make it chatter.
func _test_camera_strafe() -> void:
	var ct := CameraTest.new()
	add_child(ct)
	var pair := ct.rig(2.8, 14.0)
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	Loadout.third_person = true
	p.camera_override = -1
	p.set_scripted(false)
	ct.capture()
	await ct.settle(0.6)

	ct.key(KEY_D, true)
	var deepest := -99.0
	var min_len := 99.0
	var max_len := 0.0
	var min_y := 99.0
	var t := 0.0
	while t < 1.4:
		await get_tree().physics_frame
		t += STEP
		var cp := p.camera_world_pos()
		deepest = maxf(deepest, cp.z)
		min_y = minf(min_y, cp.y)
		min_len = minf(min_len, p.camera_distance())
		max_len = maxf(max_len, p.camera_distance())
	ct.key(KEY_D, false)
	await ct.settle(0.2)

	var face := 2.6
	_assert("3P strafe never punches through the wall", deepest < face - 0.05,
		"deepest camera z=%.2f wall face=%.2f" % [deepest, face])
	_assert("3P strafe keeps a stable arm", max_len - min_len < 0.6,
		"arm range %.2f..%.2f" % [min_len, max_len])
	_assert("3P strafe never drops to the floor", min_y > p.global_position.y + 0.35,
		"min cam y=%.2f player y=%.2f" % [min_y, p.global_position.y])

	ct.release_all()
	Loadout.third_person = false
	root.queue_free()
	await _wait(0.15)


## Swapping camera mid-run must not leave a boom offset, a hidden body or a
## stale pitch. Covers the loadout toggle and the host session override.
func _test_camera_swap() -> void:
	var ct := CameraTest.new()
	add_child(ct)
	var pair := ct.rig()
	var root: Node3D = pair[0]
	var p: ClubPlayer = pair[1]
	Loadout.third_person = false
	p.camera_override = -1
	await ct.settle(0.5)

	_assert("first person is the default", not p.third_person_active() and not p.body_visible(),
		"third=%s body=%s" % [p.third_person_active(), p.body_visible()])
	_assert("first-person camera sits on the eye", absf(p.camera_distance()) < 0.08,
		"offset=%.3f m" % p.camera_distance())

	# host forces third person for the session
	p.camera_override = 1
	await ct.settle(0.35)
	_assert("host third-person override applies immediately",
		p.third_person_active() and p.body_visible() and p.camera_distance() > 3.5,
		"third=%s body=%s arm=%.2f" % [p.third_person_active(), p.body_visible(), p.camera_distance()])

	var pitch_third := p.camera_pitch()
	p.camera_override = 0
	await ct.settle(0.35)
	_assert("swap back to first leaves no boom offset", absf(p.camera_distance()) < 0.12,
		"offset=%.3f m" % p.camera_distance())
	_assert("swap back hides the body", not p.body_visible(), "visible=%s" % p.body_visible())
	_assert("swap keeps the aim pitch", absf(p.camera_pitch() - pitch_third) < 0.06,
		"3P=%.3f 1P=%.3f" % [pitch_third, p.camera_pitch()])

	# player choice path, not the override
	p.camera_override = -1
	Loadout.third_person = true
	await ct.settle(0.35)
	_assert("loadout third-person choice applies",
		p.third_person_active() and p.body_visible() and p.camera_distance() > 3.5,
		"arm=%.2f" % p.camera_distance())

	Loadout.third_person = false
	ct.release_all()
	root.queue_free()
	await _wait(0.15)


func _test_tag() -> void:
	var m := Match.new()
	m.name = "TestMatch"
	add_child(m)
	m.start()
	await _wait(0.25)

	# freeze the bots so the tag test is deterministic, not a moving-target race
	for b in m.bots:
		b.set_physics_process(false)
		b.velocity = Vector3.ZERO

	var old_it: Node3D = m.it_actor
	var tags_before := m.tags_total
	var time_before := m.time_left

	# clear floor, away from the stage and from every spawn point
	var spot := Vector3(20.0, 1.2, 30.0)
	m.player.global_position = spot
	m.player.velocity = Vector3.ZERO
	old_it.global_position = spot
	await _wait(0.05)

	m._check_tags()
	var player_is_it := m.player_is_it()
	var counted := m.tags_total == tags_before + 1

	# the chaser who was just tagged cannot be tagged straight back
	m._check_tags()
	var immune_holds := m.it_actor == m.player

	await _real_wait(0.25)
	var scale_after := Engine.time_scale

	_assert("tag resolves", player_is_it, "player_is_it=%s" % player_is_it)
	_assert("tag increments the round counter", counted,
		"%d -> %d" % [tags_before, m.tags_total])
	_assert("immunity blocks an instant pass-back", immune_holds,
		"it is still %s" % ("player" if immune_holds else "someone else"))
	_assert("round state advanced", m.running and m.time_left < time_before,
		"running=%s time_left=%.2f" % [m.running, m.time_left])
	_assert("tag hit-stop releases time scale", absf(scale_after - 1.0) < 0.001,
		"time_scale=%.3f" % scale_after)

	Engine.time_scale = 1.0
	m.queue_free()
	await _wait(0.1)
