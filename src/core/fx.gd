extends Node
## Fx — the effects layer. Every texture here is from the downloaded CC0
## Kenney Particle Pack (79 sprites, assets/vfx/pack). No runtime-drawn stand-ins.

const PACK := "res://assets/vfx/pack/"
const GLOW: Texture2D = preload("res://assets/vfx/pack/light_01.png")
const BURST := [
	preload("res://assets/vfx/pack/star_05.png"),
	preload("res://assets/vfx/pack/spark_01.png"),
	preload("res://assets/vfx/pack/magic_03.png"),
	preload("res://assets/vfx/pack/flare_01.png"),
]
const PUFF := [
	preload("res://assets/vfx/pack/smoke_03.png"),
	preload("res://assets/vfx/pack/smoke_06.png"),
	preload("res://assets/vfx/pack/dirt_02.png"),
]
const STREAK := [
	preload("res://assets/vfx/pack/trace_04.png"),
	preload("res://assets/vfx/pack/trace_06.png"),
	preload("res://assets/vfx/pack/slash_03.png"),
]

var _pick := 0


func burst(pos: Vector3, color: Color, size := 1.0, amount := 64) -> void:
	var p := _particles(pos, color, BURST[_pick % BURST.size()], size * 0.42, amount)
	_pick += 1
	if p == null:
		return
	var pm := p.process_material as ParticleProcessMaterial
	pm.initial_velocity_min = 2.4 * size
	pm.initial_velocity_max = 7.0 * size
	pm.gravity = Vector3(0, -8.0, 0)
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


## Ground shockwave: an expanding emissive ring plus a low puff ring.
func shock(pos: Vector3, color: Color, radius := 6.0) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.94
	tm.outer_radius = 1.0
	tm.rings = 48
	tm.ring_segments = 12
	ring.mesh = tm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	ring.material_override = mat
	add_child(ring)
	ring.global_position = pos + Vector3(0, 0.08, 0)
	ring.scale = Vector3(0.3, 1.0, 0.3)
	var tw := create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.42)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(ring.queue_free)
	burst(pos + Vector3(0, 0.7, 0), color, 1.3, 48)


func puff(pos: Vector3, color := Color(0.72, 0.66, 0.6, 0.5), amount := 12) -> void:
	var p := _particles(pos, color, PUFF[_pick % PUFF.size()], 0.3, amount)
	_pick += 1
	if p == null:
		return
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3.UP
	pm.spread = 70.0
	pm.initial_velocity_min = 0.25
	pm.initial_velocity_max = 1.1
	pm.gravity = Vector3(0, 0.3, 0)
	get_tree().create_timer(1.1).timeout.connect(p.queue_free)


## Slow floating dust in a box around the room. Cheap, long-lived atmosphere.
func motes(parent: Node3D, center: Vector3, extents: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 110
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.16
	pm.gravity = Vector3(0, -0.004, 0)
	pm.scale_min = 0.35
	pm.scale_max = 1.0
	pm.color = Color(0.92, 0.84, 1.0, 0.32)
	p.process_material = pm

	var q := QuadMesh.new()
	q.size = Vector2(0.055, 0.055)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = GLOW
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = Color(0.86, 0.78, 1.0)
	mat.emission_energy_multiplier = 1.2
	q.material = mat
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(center - extents - Vector3(2, 2, 2), extents * 2.0 + Vector3(4, 4, 4))
	parent.add_child(p)
	p.global_position = center
	p.emitting = true
	return p


## A short-lived streak attached to a moving actor (dash, blink, lunge).
func trail(node: Node3D, color: Color) -> void:
	if node == null:
		return
	var p := _particles(node.global_position + Vector3(0, 0.9, 0), color,
		STREAK[_pick % STREAK.size()], 0.30, 22, 0.45)
	_pick += 1
	if p == null:
		return
	var pm := p.process_material as ParticleProcessMaterial
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 22.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3.ZERO
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


func _particles(pos: Vector3, color: Color, tex: Texture2D, size: float, amount: int, lifetime := 1.0) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(amount, 4)
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 0.92
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 1.0
	pm.initial_velocity_max = 3.0
	pm.damping_min = 0.4
	pm.damping_max = 1.2
	pm.scale_min = 0.55
	pm.scale_max = 1.25
	pm.color = color
	p.process_material = pm

	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = tex
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = true
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.6
	q.material = mat
	p.draw_pass_1 = q

	add_child(p)
	p.global_position = pos
	p.emitting = true
	return p
