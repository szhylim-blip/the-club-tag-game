class_name ClubPlayer
extends CharacterBody3D
## Club Sprint: Source-lineage movement with a camera that sells it.
## The motor is written as a pure-ish state machine driven by PlayerInput-like
## calls so it can later be moved into a rollback tick unchanged.

signal stepped(world_pos: Vector3, surface: String)
signal landed(world_pos: Vector3, strength: float)
signal ability_fired(kind: String)
signal role_ability_fired(kind: String)

## Third person shares one pitch clamp between the boom and the camera. The
## first-person limit stays wider, but never leaks into the boom.
const THIRD_MIN_PITCH := -0.95
const THIRD_MAX_PITCH := 0.85
const BOOM_BASE := 4.3
const BODY_HIDE_DIST := 1.55

var is_it := false
var is_local := true
## set by the map: concrete arena floor, wood lobby, grass or carpet elsewhere
var ground_surface := "concrete"
var member_name := "YOU"
var body_color: Color = Cfg.MINT

var cam: Camera3D
var _pivot: Node3D
var _cap: CollisionShape3D
var _shape: CapsuleShape3D
var _mesh: MeshInstance3D

var _pitch := 0.0
var _coyote := 0.0
var _buffer := 0.0
var _bhop := 0.0
var _land := 0.0
var _crouching := false
var _sliding := false
var _slide_time := 0.0
var _dip := 0.0
var _bob := 0.0
var _step_acc := 0.0
var _cooldown := 0.0
var _role_cd := [0.0, 0.0]
var _stamina_t := 0.0
var _slow_t := 0.0
var _dash := 0.0
var _shake := 0.0
var _tilt := 0.0
var _fov := Cfg.FOV_BASE
var _speed := 0.0
var _input_enabled := true
var _air_time := 0.0

# --- sitting on furniture -------------------------------------------------
var _frozen := false
var _seated := false
var _lean := 0.0
var _shield_t := 0.0
var body: AnimatedCharacter
var _sit_blend := 0.0
var _seat_pos := Vector3.ZERO
var _seat_yaw := 0.0
var _knees: Node3D
var _knee_mat: StandardMaterial3D

# --- scripted input seam: headless tests drive the real motor -----------
var scripted := false
var in_wish := Vector2.ZERO   # x = strafe, y = forward
var in_jump := false
var _boom_len := BOOM_BASE
var in_crouch := false
var in_sprint := false

## -1 = the player's own loadout, 0 = first person, 1 = third person. The host
## can force a session default, and a test can prove the swap is clean.
var camera_override := -1
## Headless has no real cursor; tests feed genuine events with this seam.
var test_capture := false
## Test surface: proves how many motion events actually reached the handler and
## with what delta, so a passing look test cannot hide re-delivered input.
var motion_calls := 0
var last_motion := Vector2.ZERO
var _was_third := false
var _snap_boom := true


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	_shape = CapsuleShape3D.new()
	_shape.radius = Cfg.RADIUS
	_shape.height = Cfg.STAND_H
	_cap = CollisionShape3D.new()
	_cap.shape = _shape
	_cap.position.y = Cfg.STAND_H * 0.5
	add_child(_cap)

	var mesh := CapsuleMesh.new()
	mesh.radius = Cfg.RADIUS
	mesh.height = Cfg.STAND_H
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mesh
	_mesh.position.y = Cfg.STAND_H * 0.5
	_mesh.material_override = _mat(body_color, 0.55)
	_mesh.visible = false
	add_child(_mesh)

	# the member's actual silhouette, customisable in the loadout screen
	body = AnimatedCharacter.new()
	add_child(body)
	body.build(Loadout.body_color, Loadout.shape)
	body.visible = third_person_active()

	_pivot = Node3D.new()
	_pivot.position.y = Cfg.EYE
	add_child(_pivot)

	# knees that swing into frame when seated: what actually sells sitting
	_knees = Node3D.new()
	_knees.visible = false
	_pivot.add_child(_knees)
	_knee_mat = _mat(Loadout.body_color, 0.6)
	for sx in [-0.105, 0.105]:
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.072
		leg_mesh.height = 0.34
		var leg := MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.material_override = _knee_mat
		leg.position = Vector3(sx, -0.40, -0.46)
		leg.rotation_degrees.x = -68.0
		_knees.add_child(leg)
		var foot := MeshInstance3D.new()
		var fm := CapsuleMesh.new()
		fm.radius = 0.058
		fm.height = 0.18
		foot.mesh = fm
		foot.material_override = _knee_mat
		foot.position = Vector3(sx, -0.53, -0.66)
		foot.rotation_degrees.x = -88.0
		_knees.add_child(foot)

	cam = Camera3D.new()
	cam.fov = Cfg.FOV_BASE
	cam.near = 0.04
	cam.far = 220.0
	_pivot.add_child(cam)
	cam.current = false


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.05
	return m


func set_role(it: bool) -> void:
	is_it = it
	body_color = Loadout.body_color
	(_mesh.material_override as StandardMaterial3D).albedo_color = body_color
	if body != null:
		body.set_role(it)
	if _knee_mat != null:
		_knee_mat.albedo_color = body_color


func set_input_enabled(v: bool) -> void:
	_input_enabled = v
	if not v:
		velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not is_local or not _input_enabled:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or test_capture
	if event is InputEventMouseMotion and captured:
		var mm := event as InputEventMouseMotion
		motion_calls += 1
		last_motion = mm.relative
		var sens := Cfg.MOUSE_SENS * clampf(Loadout.sensitivity, 0.2, 3.0)
		rotate_y(-mm.relative.x * sens)
		_pitch = clampf(_pitch - mm.relative.y * sens, -Cfg.PITCH_LIMIT, Cfg.PITCH_LIMIT)


func _physics_process(dt: float) -> void:
	_cooldown = maxf(0.0, _cooldown - dt)
	_role_cd[0] = maxf(0.0, _role_cd[0] - dt)
	_role_cd[1] = maxf(0.0, _role_cd[1] - dt)
	_stamina_t = maxf(0.0, _stamina_t - dt)
	_slow_t = maxf(0.0, _slow_t - dt)
	_shield_t = maxf(0.0, _shield_t - dt)
	_coyote = maxf(0.0, _coyote - dt)
	_buffer = maxf(0.0, _buffer - dt)
	_bhop = maxf(0.0, _bhop - dt)
	_land = maxf(0.0, _land - dt)
	_dash = maxf(0.0, _dash - dt)

	if _frozen:
		velocity = Vector3.ZERO
		_speed = 0.0
		_update_camera(dt, Vector3.ZERO, false)
		return

	_sit_blend = move_toward(_sit_blend, 1.0 if _seated else 0.0, dt * 4.5)
	if _seated:
		global_position = global_position.lerp(_seat_pos, 1.0 - pow(0.0015, dt))
		rotation.y = lerp_angle(rotation.y, deg_to_rad(_seat_yaw), 1.0 - pow(0.0015, dt))
		velocity = Vector3.ZERO
		_speed = 0.0
		_update_camera(dt, Vector3.ZERO, false)
		return

	var on_floor := is_on_floor()
	var wish := Vector3.ZERO
	var sprinting := false
	var crouch_held := false

	if scripted:
		wish = (transform.basis * Vector3(in_wish.x, 0.0, -in_wish.y)).normalized()
		sprinting = in_sprint
		crouch_held = in_crouch
		if in_jump:
			_buffer = Cfg.JUMP_BUFFER
	elif is_local and _input_enabled:
		var v := Input.get_vector("left", "right", "back", "forward")
		wish = (transform.basis * Vector3(v.x, 0.0, -v.y)).normalized()
		sprinting = Input.is_action_pressed("sprint")
		crouch_held = Input.is_action_pressed("crouch")
		if Input.is_action_just_pressed("jump"):
			_buffer = Cfg.JUMP_BUFFER
		if Input.is_action_just_pressed("ability"):
			try_ability()
		if Input.is_action_just_pressed("ability_two"):
			try_role_ability(1)
		if Input.is_action_just_pressed("ability_three"):
			try_role_ability(2)
		if Input.is_action_just_pressed("punch") and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or test_capture):
			if body != null:
				body.punch()

	# Headless tests use scripted movement but still need the real punch input
	# path. Keep this outside the scripted branch so production behavior is
	# unchanged and the test exercises the same controller call.
	if test_capture and scripted and Input.is_action_just_pressed("punch") and body != null:
		body.punch()

	_handle_crouch(crouch_held, dt)

	# --- vertical ---------------------------------------------------------
	if not on_floor:
		velocity.y -= Cfg.GRAVITY * dt
		_air_time += dt
	else:
		# no friction while sliding, or during the bhop landing window: those
		# are exactly the frames where momentum is supposed to survive
		var chaining := _land > 0.0 and _bhop > 0.0
		if not _sliding and not chaining:
			_apply_friction(dt)
		_air_time = 0.0

	# --- horizontal -------------------------------------------------------
	var max_speed := Cfg.WALK
	if sprinting and not _crouching and not _sliding:
		max_speed = Cfg.SPRINT
	if _sliding:
		max_speed = maxf(max_speed, Cfg.SPRINT * Cfg.SLIDE_BOOST)
	if _stamina_t > 0.0:
		max_speed *= Cfg.STAMINA_MULT
	if _slow_t > 0.0:
		max_speed *= Cfg.SLOW_MULT

	if on_floor and not _sliding:
		# ground steering never brakes momentum that came from the air: above
		# max_speed the motor leaves the velocity alone so hop chains accumulate
		var cur := Vector2(velocity.x, velocity.z)
		if cur.length() <= max_speed + 0.01:
			var target := wish * max_speed
			var hv := cur.move_toward(Vector2(target.x, target.z), Cfg.GROUND_ACCEL * dt)
			velocity.x = hv.x
			velocity.z = hv.y
	elif not on_floor:
		_air_accelerate(wish, max_speed, dt)

	if _sliding:
		var hv2 := Vector2(velocity.x, velocity.z)
		hv2 = hv2.move_toward(Vector2.ZERO, Cfg.SLIDE_FRICTION * dt)
		velocity.x = hv2.x
		velocity.z = hv2.y
		_slide_time -= dt
		if _slide_time <= 0.0 or hv2.length() < 2.0:
			_end_slide()

	if _slow_t > 0.0:
		# A trap is an active drag, not just a lower sprint target: it must be
		# felt immediately even if the runner arrived carrying hop momentum.
		var slowed := Vector2(velocity.x, velocity.z)
		slowed = slowed.move_toward(Vector2.ZERO, Cfg.SLOW_DRAG * dt)
		velocity.x = slowed.x
		velocity.z = slowed.y

	# --- jump -------------------------------------------------------------
	if _buffer > 0.0 and (_coyote > 0.0 or on_floor):
		var preserving := _land > 0.0 and _bhop > 0.0
		velocity.y = Cfg.JUMP * (1.02 if preserving else 1.0)
		_buffer = 0.0
		_coyote = 0.0
		_bhop = 0.35 if preserving else 0.0
		if preserving:
			# a chained hop keeps momentum and adds a slice, up to the cap
			var hv := Vector2(velocity.x, velocity.z) * Cfg.BHOP_GAIN
			hv = hv.limit_length(Cfg.SPEED_CAP)
			velocity.x = hv.x
			velocity.z = hv.y
		_end_slide()
		if is_local:
			Sfx.play("jump", -16.0, randf_range(0.95, 1.06))
	elif on_floor and _buffer > 0.0:
		velocity.y = Cfg.JUMP
		_buffer = 0.0

	if velocity.y < -Cfg.TERMINAL:
		velocity.y = -Cfg.TERMINAL

	var was_air := not on_floor
	move_and_slide()
	# absolute horizontal cap: momentum is readable, never unbounded
	var capped := Vector2(velocity.x, velocity.z)
	if capped.length() > Cfg.SPEED_CAP:
		capped = capped.limit_length(Cfg.SPEED_CAP)
		velocity.x = capped.x
		velocity.z = capped.y
	var now_floor := is_on_floor()

	if was_air and now_floor:
		var impact := clampf(-velocity.y * 0.010, 0.0, 0.16)
		_dip = maxf(_dip, impact)
		_shake = maxf(_shake, impact * 1.6)
		_land = Cfg.BHOP_WINDOW
		_bhop = Cfg.BHOP_WINDOW
		if is_local and impact > 0.02:
			Sfx.play_step(ground_surface, -13.0, 0.92)
			Sfx.play("land", -16.0, randf_range(0.94, 1.06))
		landed.emit(global_position, impact)

	if now_floor:
		_coyote = Cfg.COYOTE

	_speed = Vector2(velocity.x, velocity.z).length()
	if now_floor and _speed > 0.4:
		_step_acc += _speed * dt
		if _step_acc > 2.0:
			_step_acc = 0.0
			var surface := "metal" if _on_metal() else ground_surface
			Sfx.play_step(surface, -19.0, randf_range(0.92, 1.1))
			stepped.emit(global_position, surface)

	if body != null:
		var on_stairs := false
		if now_floor:
			var n := get_floor_normal()
			on_stairs = n.y < 0.995 and n.angle_to(Vector3.UP) > 0.04
		body.animate(dt, _speed, now_floor, _crouching, _sliding, _dash > 0.0, _seated, on_stairs)
	_update_camera(dt, wish, sprinting)


func _on_metal() -> bool:
	if get_slide_collision_count() == 0:
		return false
	return false


func _apply_friction(dt: float) -> void:
	var hv := Vector2(velocity.x, velocity.z)
	var spd := hv.length()
	if spd < 0.05:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var drop := maxf(spd, 2.0) * Cfg.FRICTION * dt
	var new_spd := maxf(spd - drop, 0.0)
	hv = hv.normalized() * new_spd
	velocity.x = hv.x
	velocity.z = hv.y


func _air_accelerate(wish: Vector3, max_speed: float, dt: float) -> void:
	if wish.length_squared() < 0.0001:
		return
	var current := velocity.x * wish.x + velocity.z * wish.z
	var add := max_speed - current
	if add <= 0.0:
		# During a chained hop, a strafe still shapes the arc and can nibble
		# toward the cap. Without this, max-speed bhops feel like a rail.
		if _bhop > 0.0:
			var spd := Vector2(velocity.x, velocity.z).length()
			if spd < Cfg.SPEED_CAP:
				var push := minf(Cfg.AIR_STRAFE_ACCEL * dt, Cfg.SPEED_CAP - spd)
				velocity.x += wish.x * push
				velocity.z += wish.z * push
		return
	var accel_speed := minf(Cfg.AIR_ACCEL * max_speed * dt, Cfg.AIR_CAP)
	accel_speed = minf(accel_speed, add)
	velocity.x += wish.x * accel_speed
	velocity.z += wish.z * accel_speed


func _handle_crouch(held: bool, dt: float) -> void:
	if held and not _crouching:
		_crouching = true
		_set_height(Cfg.CROUCH_H)
		if _speed > Cfg.SLIDE_MIN_SPEED and is_on_floor() and not _sliding:
			_start_slide()
	elif not held and _crouching:
		if _can_stand():
			_crouching = false
			_set_height(Cfg.STAND_H)
			_end_slide()
	# camera height easing
	var target_eye := Cfg.EYE_CROUCH if _crouching else Cfg.EYE
	_pivot.position.y = lerpf(_pivot.position.y, target_eye, 1.0 - pow(0.001, dt))


func _can_stand() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var s := CapsuleShape3D.new()
	s.radius = Cfg.RADIUS * 0.95
	s.height = Cfg.STAND_H
	q.shape = s
	q.transform = Transform3D(Basis(), global_position + Vector3(0, Cfg.STAND_H * 0.5, 0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return space.intersect_shape(q, 1).is_empty()


func _set_height(h: float) -> void:
	_shape.height = h
	_cap.position.y = h * 0.5
	(_mesh.mesh as CapsuleMesh).height = h
	_mesh.position.y = h * 0.5


func _start_slide() -> void:
	_sliding = true
	_slide_time = 0.75
	var hv := Vector2(velocity.x, velocity.z)
	if hv.length() > 0.1:
		# SLIDE_BOOST was previously dead tuning. The slide now starts at a
		# genuine burst over sprint, then preserves it with very light friction.
		hv = hv.normalized() * maxf(hv.length() * 1.04, Cfg.SPRINT * Cfg.SLIDE_BOOST)
		velocity.x = hv.x
		velocity.z = hv.y
	_shake = maxf(_shake, 0.02)


func _end_slide() -> void:
	_sliding = false
	_slide_time = 0.0


func try_ability() -> bool:
	if _cooldown > 0.0:
		return false
	var kind := Loadout.ability
	_cooldown = Loadout.ability_cooldown()
	var fwd := -transform.basis.z

	match kind:
		"blink":
			var from := global_position + Vector3(0, 0.6, 0)
			var to := global_position + fwd * 8.0 + Vector3(0, 0.4, 0)
			var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				to = hit["position"] - fwd * 0.55
			global_position = to
			velocity = Vector3(fwd.x * 5.0, 1.5, fwd.z * 5.0)
			ability_fired.emit("blink")
			_fov = minf(Cfg.FOV_BASE + Cfg.FOV_MAX_BONUS + 14.0, _fov + 16.0)
			_shake = maxf(_shake, 0.08)
			Sfx.play("ability_blink", -10.0, 1.0)
		"shock":
			ability_fired.emit("shock")
			_shake = maxf(_shake, 0.12)
			Sfx.play("ability_zap", -8.0, 0.95)
		"shield":
			_shield_t = 2.0
			ability_fired.emit("shield")
			Sfx.play("ability_power", -9.0, 1.2)
			_shake = maxf(_shake, 0.04)
		_:
			_dash = 0.55
			if is_it:
				velocity += fwd * 9.0 + Vector3.UP * 1.6
				ability_fired.emit("lunge")
			else:
				velocity += fwd * 7.2
				ability_fired.emit("dash")
			Sfx.play("dash", -10.0, 1.1 if is_it else 1.0)
			_fov = minf(Cfg.FOV_BASE + Cfg.FOV_MAX_BONUS + 16.0, _fov + 22.0)
	return true


## E / F role kit. Q remains the loadout tech; this layer is always available and
## changes with the role so a chaser and a runner never share the same round.
func try_role_ability(slot: int) -> bool:
	slot = clampi(slot, 1, 2)
	if _role_cd[slot - 1] > 0.0:
		return false
	var kind := role_ability_key(slot)
	_role_cd[slot - 1] = float(Cfg.ROLE_COOLDOWNS.get(kind, 8.0))
	if kind == "stamina":
		_stamina_t = Cfg.STAMINA_TIME
		_shake = maxf(_shake, 0.03)
	role_ability_fired.emit(kind)
	return true


func role_ability_key(slot: int) -> String:
	if is_it:
		return "scan" if slot == 1 else "trap"
	return "decoy" if slot == 1 else "stamina"


func role_ability_name(slot: int) -> String:
	match role_ability_key(slot):
		"scan": return "SCAN"
		"trap": return "TRAP"
		"decoy": return "DECOY"
		"stamina": return "STAMINA"
	return ""


func primary_ability_name() -> String:
	if is_it and Loadout.ability == "dash":
		return "LUNGE"
	return Loadout.ability_name()


func role_cooldown_ratio(slot: int) -> float:
	slot = clampi(slot, 1, 2)
	var kind := role_ability_key(slot)
	return clampf(float(_role_cd[slot - 1]) / maxf(0.1, float(Cfg.ROLE_COOLDOWNS.get(kind, 8.0))), 0.0, 1.0)


func role_cooldown_remaining(slot: int) -> float:
	slot = clampi(slot, 1, 2)
	return maxf(0.0, float(_role_cd[slot - 1]))


func apply_slow(seconds: float) -> void:
	_slow_t = maxf(_slow_t, seconds)


func stamina_active() -> bool:
	return _stamina_t > 0.0


func debug_reset_ability_cooldowns() -> void:
	_cooldown = 0.0
	_role_cd[0] = 0.0
	_role_cd[1] = 0.0
	_stamina_t = 0.0
	_slow_t = 0.0


func is_shielded() -> bool:
	return _shield_t > 0.0


## Negative is forward lean, in radians.
func camera_lean() -> float:
	return _lean


func get_cooldown_ratio() -> float:
	return clampf(_cooldown / maxf(0.1, Loadout.ability_cooldown()), 0.0, 1.0)


## Sit on a piece of furniture: snap to the seat anchor and play the eased pose.
func sit_at(pos: Vector3, yaw_deg: float) -> void:
	_seated = true
	# snap to the seat itself, never to whatever height you jumped from
	_seat_pos = Vector3(pos.x, pos.y, pos.z)
	global_position = Vector3(global_position.x, pos.y, global_position.z)
	_seat_yaw = yaw_deg
	velocity = Vector3.ZERO
	_sliding = false
	Sfx.play("thud", -22.0, 1.25)


func stand_up() -> void:
	if not _seated:
		return
	_seated = false
	# step off the front edge so we do not stand inside the sofa
	global_position += -transform.basis.z * 0.55
	Sfx.play_step(ground_surface, -23.0, 1.12)


func is_seated() -> bool:
	return _seated


## Round modes freeze actors that are found / infected out of play.
func set_frozen(v: bool) -> void:
	_frozen = v
	velocity = Vector3.ZERO
	if v:
		_seated = false
		set_input_enabled(false)
	else:
		set_input_enabled(true)


func _update_camera(dt: float, wish: Vector3, sprinting: bool) -> void:
	var third := third_person_active()
	# seated pose: eye drops to the cushion, body squashes, knees fill the frame
	var sit_eye := lerpf(Cfg.EYE, 0.98, _sit_blend)
	_pivot.position.y = lerpf(_pivot.position.y, sit_eye, 1.0 - pow(0.0001, dt))
	_mesh.scale.y = lerpf(1.0, 0.58, _sit_blend)
	_mesh.position.y = lerpf(Cfg.STAND_H * 0.5, Cfg.STAND_H * 0.33, _sit_blend)
	if body != null:
		body.visible = third
	if _knees != null:
		_knees.visible = (not third) and _sit_blend > 0.2

	# forward lean: a little at sprint, a lot at dash
	var lean_target := 0.0
	if _dash > 0.0:
		lean_target = -deg_to_rad(12.0)
	elif _speed > Cfg.WALK:
		lean_target = -deg_to_rad(4.5) * clampf((_speed - Cfg.WALK) / maxf(0.1, Cfg.SPRINT - Cfg.WALK), 0.0, 1.0)
	_lean = lerpf(_lean, lean_target, 1.0 - pow(0.0008, dt))

	if third != _was_third:
		# Entering or leaving 3P must not ease from a stale boom through a wall.
		_boom_len = BOOM_BASE
		_snap_boom = true
	_was_third = third

	# look pitch (plus lean); third person uses the same clamp for the camera and
	# the boom, so the view can never pitch past where the arm is allowed to go.
	var look := _pitch + _lean
	if third:
		look = clampf(look, THIRD_MIN_PITCH, THIRD_MAX_PITCH)
	cam.rotation.x = lerp_angle(cam.rotation.x, look, 1.0 - pow(0.0001, dt))

	# speed FOV
	var t := clampf((_speed - Cfg.WALK) / maxf(1.0, Cfg.SPRINT * Cfg.SLIDE_BOOST - Cfg.WALK), 0.0, 1.0)
	_fov = lerpf(_fov, Cfg.FOV_BASE + Cfg.FOV_MAX_BONUS * t, 1.0 - pow(0.02, dt))
	cam.fov = _fov

	# strafe tilt
	var strafe := wish.dot(transform.basis.x)
	_tilt = lerpf(_tilt, -strafe * 2.6, 1.0 - pow(0.005, dt))

	# head bob (grounded, moving)
	if is_on_floor() and _speed > 0.5:
		_bob += dt * (6.0 + _speed * 1.6)
	else:
		_bob = lerpf(_bob, 0.0, 1.0 - pow(0.02, dt))
	var bob_y := sin(_bob * 2.0) * 0.012 * clampf(_speed / Cfg.SPRINT, 0.0, 1.2)
	var bob_x := cos(_bob) * 0.010 * clampf(_speed / Cfg.SPRINT, 0.0, 1.2)

	_dip = lerpf(_dip, 0.0, 1.0 - pow(0.0005, dt))

	_shake = maxf(0.0, _shake - dt * 2.4)
	var sh := _shake * 0.06
	var shake_off := Vector3(randf_range(-sh, sh), randf_range(-sh, sh), 0.0)

	if third:
		# Orbit boom. Pitch is applied once here and once to the camera above, so
		# the player stays framed at every angle. A hit shortens the arm along its
		# own ray; it never reshapes it into the floor.
		var boom := Vector3(0.58 + bob_x, 0.62 + bob_y, BOOM_BASE).rotated(Vector3.RIGHT, look)
		var want_len := boom.length()
		var from := _pivot.global_position
		var space := get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(from, _pivot.to_global(boom), 1, [get_rid()])
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			# A hit closer than the minimum still wins: never leave the camera on
			# the far side of the surface just to satisfy a minimum arm length.
			want_len = clampf(from.distance_to(hit["position"]) - 0.26, 0.18, want_len)
		if _snap_boom:
			_boom_len = want_len
			_snap_boom = false
		else:
			_boom_len = lerpf(_boom_len, want_len, 1.0 - pow(0.0002, dt))

		var cam_pos := boom.normalized() * _boom_len
		var world := _pivot.to_global(cam_pos)
		# Never let the orbit dip under the floor when looking up.
		var floor_q := PhysicsRayQueryParameters3D.create(world + Vector3(0, 0.6, 0),
			world + Vector3(0, -2.5, 0), 1, [get_rid()])
		var fhit := space.intersect_ray(floor_q)
		if not fhit.is_empty():
			var min_y: float = fhit["position"].y + 0.35
			if world.y < min_y:
				world.y = min_y
				cam_pos = _pivot.to_local(world)
		cam.position = cam_pos + shake_off
		if body != null:
			body.visible = cam_pos.length() > BODY_HIDE_DIST and not _seated
	else:
		_boom_len = BOOM_BASE
		cam.position = Vector3(bob_x, -_dip + bob_y, 0.0) + shake_off
	cam.rotation.z = deg_to_rad(_tilt)


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


# --- test surface -------------------------------------------------------
func collision_height() -> float:
	return _shape.height


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func is_crouching() -> bool:
	return _crouching


func is_sliding() -> bool:
	return _sliding


func set_scripted(active: bool) -> void:
	scripted = active


func third_person_active() -> bool:
	if camera_override >= 0:
		return camera_override == 1
	return Loadout.third_person


func camera_pitch() -> float:
	return cam.rotation.x


func camera_distance() -> float:
	return cam.position.length()


func camera_world_pos() -> Vector3:
	return cam.global_position


func body_visible() -> bool:
	return body != null and body.visible





## Deterministic starting pitch for the camera tests.
func debug_set_pitch(v: float) -> void:
	_pitch = clampf(v, -Cfg.PITCH_LIMIT, Cfg.PITCH_LIMIT)


func debug_pitch() -> float:
	return _pitch
