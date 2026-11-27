class_name ClubBot
extends CharacterBody3D
## A member of the club: a humanoid bean-blob (authored geometry, code-animated).
## Steering stays simple and readable: pursue, flee, avoid walls.

var is_it := false
var member_name := "MEMBER"
var target: Node3D = null
var flee_from: Node3D = null
var body_color: Color = Cfg.MINT
var shape_id := 0

var body: AnimatedCharacter
var _ring: MeshInstance3D
var _cap: CollisionShape3D
var _speed := 4.35
var _strafe := 0.0
var _jump_cd := 0.0
var _repath := 0.0
var _wander := Vector3.ZERO
var _was_floor := true
var slow_t := 0.0
var frozen := false
var eliminated := false


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = Cfg.RADIUS
	shape.height = Cfg.STAND_H
	_cap = CollisionShape3D.new()
	_cap.shape = shape
	_cap.position.y = Cfg.STAND_H * 0.5
	add_child(_cap)

	body = AnimatedCharacter.new()
	add_child(body)
	body.build(body_color, shape_id)

	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.26
	t.outer_radius = 0.34
	t.rings = 24
	t.ring_segments = 8
	_ring.mesh = t
	_ring.position.y = 0.04
	_ring.material_override = _ring_mat(Cfg.MINT)
	add_child(_ring)

	_strafe = randf_range(-1.0, 1.0)
	_repath = randf_range(0.0, 1.0)


func _ring_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.2
	return m


func set_role(it: bool) -> void:
	is_it = it
	if body != null:
		body.set_role(it)
	if _ring != null:
		_ring.material_override = _ring_mat(Cfg.CORAL if it else Cfg.MINT)


func _physics_process(dt: float) -> void:
	_jump_cd = maxf(0.0, _jump_cd - dt)
	slow_t = maxf(0.0, slow_t - dt)
	_repath -= dt
	if _repath <= 0.0:
		_repath = randf_range(0.5, 1.2)
		_strafe = randf_range(-0.8, 0.8)

	if eliminated or frozen:
		velocity = Vector3.ZERO
		return

	if not is_on_floor():
		velocity.y -= Cfg.GRAVITY * dt

	var goal := Vector3.ZERO
	if target != null:
		goal = target.global_position
	elif flee_from != null:
		goal = global_position + (global_position - flee_from.global_position)
	else:
		_wander = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		goal = global_position + _wander * 8.0

	var dir := goal - global_position
	dir.y = 0.0
	if dir.length() > 0.15:
		dir = dir.normalized()
	else:
		dir = Vector3.ZERO

	if dir.length() > 0.1:
		var probe := dir.rotated(Vector3.UP, _strafe * 0.55)
		if _blocked(probe):
			if not _blocked(dir.rotated(Vector3.UP, 0.9)):
				dir = dir.rotated(Vector3.UP, 0.9)
			elif not _blocked(dir.rotated(Vector3.UP, -0.9)):
				dir = dir.rotated(Vector3.UP, -0.9)
			elif is_on_floor() and _jump_cd <= 0.0:
				velocity.y = Cfg.JUMP * 0.92
				_jump_cd = 1.1

	var speed := _speed * (1.06 if is_it else 1.0)
	if slow_t > 0.0:
		speed *= Cfg.SLOW_MULT
	var hv := Vector2(velocity.x, velocity.z).move_toward(Vector2(dir.x, dir.z) * speed, 34.0 * dt)
	velocity.x = hv.x
	velocity.z = hv.y

	move_and_slide()

	if dir.length() > 0.2:
		var flat := Vector3(velocity.x, 0, velocity.z)
		if flat.length() > 0.5:
			rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), 1.0 - pow(0.001, dt))

	var now_floor := is_on_floor()
	if now_floor and not _was_floor and body != null:
		body.land(clampf(-velocity.y * 0.04, 0.0, 1.0))
	_was_floor = now_floor
	if body != null:
		body.animate(dt, Vector2(velocity.x, velocity.z).length(), now_floor)


func apply_slow(seconds: float) -> void:
	slow_t = maxf(slow_t, seconds)


## Hush: hold the seeker still through the blind window.
func freeze(v: bool) -> void:
	frozen = v
	velocity = Vector3.ZERO
	set_physics_process(not v)


## Hush found / potato eliminated: out of play, no collision, off screen.
func eliminate() -> void:
	eliminated = true
	velocity = Vector3.ZERO
	visible = false
	collision_layer = 0
	set_physics_process(false)


func _blocked(dir: Vector3) -> bool:
	var from := global_position + Vector3(0, 0.55, 0)
	var to := from + dir * 1.5
	var q := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
