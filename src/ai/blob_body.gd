class_name BlobBody
extends Node3D
## A humanoid bean-blob: no rig, no imported skeleton, no random assets.
## Authored geometry (capsule bean + head bump + stubby limbs + eyes) animated
## in code with squash, bob and limb swing. Three silhouettes, one palette.

enum Shape { BEAN, ROUND, LANKY }

var shape: Shape = Shape.BEAN
var tint: Color = Cfg.MINT
var is_it := false

var _root: Node3D
var _bean: MeshInstance3D
var _eyes: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _t := 0.0
var _squash := 1.0
var _squash_v := 0.0
var _phase := 0.0


func build(body_tint: Color, body_shape: Shape) -> void:
	tint = body_tint
	shape = body_shape
	_phase = randf() * TAU

	_root = Node3D.new()
	add_child(_root)

	var skin := _mat(tint, 0.42)
	var tall := 1.0
	var wide := 1.0
	match shape:
		Shape.ROUND:
			tall = 0.92
			wide = 1.16
		Shape.LANKY:
			tall = 1.10
			wide = 0.86

	# bean body
	_bean = MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.33
	cap.height = 0.98 * tall
	_bean.mesh = cap
	_bean.position.y = 0.49 * tall
	_bean.scale = Vector3(wide, 1.0, wide * 0.92)
	_bean.material_override = skin
	_root.add_child(_bean)

	# head bump, blended into the bean so the silhouette reads "little guy"
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.27 * wide
	hs.height = 0.5 * wide
	head.mesh = hs
	head.position.y = 1.06 * tall
	head.scale = Vector3(1.0, 0.95, 0.95)
	head.material_override = skin
	_root.add_child(head)

	# eyes: two ovals on the front (-Z)
	_eyes = Node3D.new()
	_eyes.position = Vector3(0, 1.08 * tall, -0.22 * wide)
	_root.add_child(_eyes)

	var white := _mat(Color(0.98, 0.97, 0.94), 0.2)
	var pupil := _mat(Color(0.06, 0.05, 0.09), 0.15)
	for i in 2:
		var x := -0.105 if i == 0 else 0.105
		var e := MeshInstance3D.new()
		var es := SphereMesh.new()
		es.radius = 0.072
		es.height = 0.144
		e.mesh = es
		e.position = Vector3(x, 0.0, 0.0)
		e.material_override = white
		_eyes.add_child(e)

		var p := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.036
		ps.height = 0.072
		p.mesh = ps
		p.position = Vector3(x, 0.0, -0.055)
		p.material_override = pupil
		_eyes.add_child(p)

	# stubby limbs
	_arm_l = _limb(Vector3(-0.34 * wide, 0.74 * tall, 0.0), 0.072, 0.34, skin, 18.0)
	_arm_r = _limb(Vector3(0.34 * wide, 0.74 * tall, 0.0), 0.072, 0.34, skin, -18.0)
	_leg_l = _limb(Vector3(-0.145 * wide, 0.20 * tall, 0.0), 0.088, 0.30, skin, 0.0)
	_leg_r = _limb(Vector3(0.145 * wide, 0.20 * tall, 0.0), 0.088, 0.30, skin, 0.0)


func _limb(pos: Vector3, radius: float, length: float, mat: Material, tilt: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	pivot.rotation_degrees.z = tilt
	_root.add_child(pivot)

	var m := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = length
	m.mesh = c
	m.position.y = -length * 0.42
	m.material_override = mat
	pivot.add_child(m)
	return pivot


func _mat(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = 0.03
	return m


func set_tint(c: Color) -> void:
	tint = c
	var skin := _mat(c, 0.42)
	for n in [_bean]:
		(n as MeshInstance3D).material_override = skin
	# head/limb children keep their own copies; retint by walking the root
	for child in _root.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = skin
		if child is Node3D:
			for sub in child.get_children():
				if sub is MeshInstance3D and (sub as MeshInstance3D).material_override != null:
					var mm := (sub as MeshInstance3D).material_override as StandardMaterial3D
					if mm != null and mm.albedo_color != Color(0.98, 0.97, 0.94) and mm.albedo_color != Color(0.06, 0.05, 0.09):
						(sub as MeshInstance3D).material_override = skin


func set_role(it: bool) -> void:
	is_it = it
	# the body keeps its member colour; the eyes go hot when you are IT
	for e in _eyes.get_children():
		var mi := e as MeshInstance3D
		var m := mi.material_override as StandardMaterial3D
		if m == null:
			continue
		if m.albedo_color == Color(0.06, 0.05, 0.09):
			m.emission_enabled = it
			m.emission = Cfg.CORAL
			m.emission_energy_multiplier = 4.0


func land(impact: float) -> void:
	_squash_v -= clampf(impact, 0.0, 1.0) * 1.6


func jump() -> void:
	_squash_v += 1.1


## speed: horizontal m/s · grounded: on floor · dt: seconds
func animate(dt: float, speed: float, grounded: bool) -> void:
	_t += dt
	var moving := clampf(speed / Cfg.SPRINT, 0.0, 1.4)

	# spring the squash back to rest
	_squash_v += (1.0 - _squash) * 38.0 * dt
	_squash_v *= 1.0 - minf(1.0, 9.0 * dt)
	_squash += _squash_v * dt
	_squash = clampf(_squash, 0.72, 1.26)

	_root.scale = Vector3(1.0 / sqrt(_squash), _squash, 1.0 / sqrt(_squash))

	var swing := sin(_t * (7.0 + moving * 6.0)) * (0.12 + moving * 0.55)
	if grounded:
		_leg_l.rotation.x = swing
		_leg_r.rotation.x = -swing
		_arm_l.rotation.x = -swing * 0.8
		_arm_r.rotation.x = swing * 0.8
		_root.position.y = absf(sin(_t * (7.0 + moving * 6.0))) * 0.035 * moving
	else:
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, 0.55, 0.2)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -0.35, 0.2)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -1.5, 0.15)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -1.5, 0.15)
		_root.position.y = lerpf(_root.position.y, 0.02, 0.2)

	# idle breathing + a slow look-around
	var idle := 1.0 - clampf(moving, 0.0, 1.0)
	_bean.scale.y = 1.0 + sin(_t * 1.8 + _phase) * 0.012 * idle
	_eyes.rotation.y = sin(_t * 0.7 + _phase) * 0.28 * idle
