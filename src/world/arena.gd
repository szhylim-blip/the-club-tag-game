class_name Arena
extends Node3D
## THE FLOOR — "Members' Room". Hand-authored, not generated:
## a raised stage under a catwalk ring, crate cover, four ramps for bhop lines,
## wall panelling, and club practicals that actually light the room.

const TEX_FLOOR_D := "res://assets/textures/floor_concrete_diff.jpg"
const TEX_FLOOR_N := "res://assets/textures/floor_concrete_nor.jpg"
const TEX_FLOOR_R := "res://assets/textures/floor_concrete_rough.jpg"
const TEX_WALL_D := "res://assets/textures/wall_plaster_diff.jpg"
const TEX_WALL_N := "res://assets/textures/wall_plaster_nor.jpg"
const TEX_WALL_R := "res://assets/textures/wall_plaster_rough.jpg"
const PROP_BOX: PackedScene = preload("res://assets/props/box_large.glb")
const PROP_CRATES: PackedScene = preload("res://assets/props/crates_stacked.glb")

var spawn_points: Array[Vector3] = []
var _mats: Dictionary = {}


func build() -> void:
	_environment()
	_lighting()
	_shell()
	_stage()
	_cover()
	_ramps()
	_catwalk()
	_catwalk_access()
	_detail()
	_props()
	_spawns()


func _mat(c: Color, rough: float = 0.82, metal: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [c.to_html(), rough, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


## PBR material from the downloaded Poly Haven maps (CC0), tinted to the club.
func _tex_mat(tint: Color, d: String, n: String, r: String, uv: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = load(d)
	m.normal_enabled = true
	m.normal_texture = load(n)
	m.normal_scale = 0.85
	m.roughness_texture = load(r)
	m.roughness = 1.0
	m.metallic = metal
	m.uv1_scale = Vector3(uv, uv, 1.0)
	m.uv1_triplanar = false
	return m


## Instance a downloaded glb prop, fit it to a height, and give it a simple box collider.
func _prop(pos: Vector3, scene: PackedScene, target_h: float, yaw_deg := 0.0) -> void:
	var n := scene.instantiate() as Node3D
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	add_child(n)

	var box := AABB()
	var first := true
	for child in n.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		var b: AABB = mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return

	var s := target_h / maxf(box.size.y, 0.01)
	n.scale = Vector3.ONE * s
	n.position.y = pos.y - box.position.y * s

	var body := StaticBody3D.new()
	body.position = pos + Vector3(0, target_h * 0.5, 0)
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(box.size.x * s, target_h, box.size.z * s)
	cs.shape = sh
	body.add_child(cs)
	add_child(body)


## Authored prop placements — fixed positions, no random scatter.
func _props() -> void:
	_prop(Vector3(19.0, 0.0, 22.0), PROP_BOX, 1.0, 18.0)
	_prop(Vector3(20.2, 0.0, 20.8), PROP_BOX, 0.6, -38.0)
	_prop(Vector3(-20.0, 0.0, -22.0), PROP_BOX, 1.0, 8.0)
	_prop(Vector3(6.0, 0.0, -30.0), PROP_BOX, 1.0, 26.0)
	_prop(Vector3(-26.0, 0.0, 6.0), PROP_CRATES, 1.0, -12.0)
	_prop(Vector3(26.5, 0.0, -6.0), PROP_CRATES, 1.0, 96.0)


func _emit_mat(c: Color, energy: float) -> StandardMaterial3D:
	var key := "emit_%s_%.2f" % [c.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


func _box(pos: Vector3, size: Vector3, color: Color, rot_deg := Vector3.ZERO, rough := 0.82, metal := 0.0) -> StaticBody3D:
	return _box_mat(pos, size, _mat(color, rough, metal), rot_deg)


func _box_mat(pos: Vector3, size: Vector3, mat: Material, rot_deg := Vector3.ZERO, solid := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot_deg
	body.collision_layer = 1
	body.collision_mask = 0

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)

	if solid:
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = size
		shape.shape = b
		body.add_child(shape)

	add_child(body)
	return body


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#171128")
	sky_mat.sky_horizon_color = Color("#4b3454")
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color("#2a2036")
	sky_mat.ground_bottom_color = Color("#0c0912")
	sky_mat.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.95
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.40
	env.glow_bloom = 0.055
	env.glow_hdr_threshold = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color("#3a2b44")
	env.fog_light_energy = 0.8
	env.fog_density = 0.009
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.06

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _lighting() -> void:
	# key: cold moonlight through the high windows
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 34, 0)
	sun.light_color = Color("#c9d4ff")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	sun.shadow_bias = 0.04
	add_child(sun)

	# fill: warm bounce so nothing reads as black
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-22, 214, 0)
	fill.light_color = Color("#ffb98a")
	fill.light_energy = 0.45
	fill.shadow_enabled = false
	add_child(fill)

	# practicals: the club lighting rig, spread so every corner is reachable
	var rig := [
		[Vector3(-22, 7.0, -20), Cfg.GOLD, 6.0],
		[Vector3(22, 7.0, -20), Color("#8fb6ff"), 6.0],
		[Vector3(-22, 7.0, 20), Color("#8fb6ff"), 6.0],
		[Vector3(22, 7.0, 20), Cfg.GOLD, 6.0],
		[Vector3(0, 8.0, 0), Color("#ffd9a8"), 7.0],
		[Vector3(0, 6.0, 26), Cfg.CORAL, 4.5],
		[Vector3(0, 6.0, -26), Color("#7de3ff"), 4.5],
		[Vector3(-28, 5.0, 0), Cfg.GOLD, 4.0],
		[Vector3(28, 5.0, 0), Color("#8fb6ff"), 4.0],
		[Vector3(0, 4.0, 34), Cfg.MINT, 3.0],
	]
	for entry: Array in rig:
		var l := OmniLight3D.new()
		l.position = entry[0]
		l.light_color = entry[1]
		l.light_energy = entry[2]
		l.omni_range = 34.0
		l.omni_attenuation = 1.1
		add_child(l)

	# four stage spots: pools of warm light with visible cones
	for k in 4:
		var ang := TAU * 0.25 * k + PI * 0.25
		var sp := SpotLight3D.new()
		sp.position = Vector3(cos(ang) * 11.0, 11.5, sin(ang) * 11.0)
		sp.rotation_degrees = Vector3(-78, rad_to_deg(-ang), 0)
		sp.light_color = Cfg.GOLD if k % 2 == 0 else Color("#a9c4ff")
		sp.light_energy = 5.6
		sp.spot_range = 22.0
		sp.spot_angle = 34.0
		sp.spot_attenuation = 0.9
		sp.shadow_enabled = true
		add_child(sp)


func _shell() -> void:
	_box_mat(Vector3(0, -0.5, 0), Vector3(76, 1, 76),
		_tex_mat(Color(0.62, 0.57, 0.72), TEX_FLOOR_D, TEX_FLOOR_N, TEX_FLOOR_R, 12.0),
		Vector3.ZERO)

	# floor border + inlay strips: reads as a members' parquet, not a grey box
	_box_mat(Vector3(0, 0.015, 0), Vector3(72, 0.03, 72), _mat(Color("#1b1626"), 0.8), Vector3.ZERO, false)
	_box_mat(Vector3(0, 0.03, 0), Vector3(66, 0.03, 66), _mat(Color("#2a2337"), 0.78), Vector3.ZERO, false)
	for k in 7:
		var z := -30.0 + k * 10.0
		_box(Vector3(0, 0.04, z), Vector3(64, 0.03, 0.14), Cfg.GOLD_DIM, Vector3.ZERO, 0.35, 0.65)
	for k in 7:
		var x := -30.0 + k * 10.0
		_box(Vector3(x, 0.04, 0), Vector3(0.14, 0.03, 64), Cfg.GOLD_DIM, Vector3.ZERO, 0.35, 0.65)

	# perimeter walls: plaster maps, tinted, tiled 4x
	var wall_mat := _tex_mat(Color(0.42, 0.36, 0.52), TEX_WALL_D, TEX_WALL_N, TEX_WALL_R, 4.0)
	_box_mat(Vector3(0, 7, -38), Vector3(76, 14, 1.2), wall_mat)
	_box_mat(Vector3(0, 7, 38), Vector3(76, 14, 1.2), wall_mat)
	_box_mat(Vector3(-38, 7, 0), Vector3(1.2, 14, 76), wall_mat)
	_box_mat(Vector3(38, 7, 0), Vector3(1.2, 14, 76), wall_mat)

	# wall panelling: vertical ribs + gold sconces on a 5 m grid
	for side in 4:
		for k in 12:
			var t := -33.0 + k * 6.0
			var p := Vector3.ZERO
			var s := Vector3(0.5, 9.0, 0.5)
			var wall_n := Vector3.ZERO
			match side:
				0:
					p = Vector3(t, 4.5, -37.2)
					wall_n = Vector3(0, 0, 1)
				1:
					p = Vector3(t, 4.5, 37.2)
					wall_n = Vector3(0, 0, -1)
				2:
					p = Vector3(-37.2, 4.5, t)
					s = Vector3(0.5, 9.0, 0.5)
					wall_n = Vector3(1, 0, 0)
				3:
					p = Vector3(37.2, 4.5, t)
					wall_n = Vector3(-1, 0, 0)
			_box_mat(p, s, _mat(Color("#211a2b"), 0.72))
			if k % 3 == 1:
				# sconce: gold bar that also glows
				var sp := p + wall_n * 0.35 + Vector3(0, 1.2, 0)
				var ss := Vector3(0.3, 1.4, 0.3) if side < 2 else Vector3(0.3, 1.4, 0.3)
				_box_mat(sp, ss, _emit_mat(Cfg.GOLD, 3.2), Vector3.ZERO, false)
				var l := OmniLight3D.new()
				l.position = sp + wall_n * 0.6
				l.light_color = Cfg.GOLD
				l.light_energy = 2.2
				l.omni_range = 9.0
				add_child(l)

	# open to the night sky: a high truss ring only, so moonlight reaches the floor
	for side in 4:
		for k in 6:
			var t := -30.0 + k * 12.0
			if side == 0:
				_box_mat(Vector3(t, 13.0, -37.0), Vector3(1.0, 0.6, 1.0), _mat(Color("#1b1526"), 0.7))
			elif side == 1:
				_box_mat(Vector3(t, 13.0, 37.0), Vector3(1.0, 0.6, 1.0), _mat(Color("#1b1526"), 0.7))
			elif side == 2:
				_box_mat(Vector3(-37.0, 13.0, t), Vector3(1.0, 0.6, 1.0), _mat(Color("#1b1526"), 0.7))
			else:
				_box_mat(Vector3(37.0, 13.0, t), Vector3(1.0, 0.6, 1.0), _mat(Color("#1b1526"), 0.7))


func _stage() -> void:
	var stage_color := Color("#443a54")
	_box(Vector3(0, 0.6, 0), Vector3(18, 1.2, 18), stage_color, Vector3.ZERO, 0.72)
	_box_mat(Vector3(0, 1.22, 0), Vector3(17.4, 0.06, 17.4), _mat(Color("#544663"), 0.55), Vector3.ZERO, false)
	# stage edge glow
	for k in 4:
		var ang := TAU * 0.25 * k
		var p := Vector3(cos(ang), 0, sin(ang)) * 8.9
		_box_mat(Vector3(p.x, 0.18, p.z), Vector3(3.0, 0.06, 0.1), _emit_mat(Cfg.GOLD, 4.0),
			Vector3(0, rad_to_deg(-ang), 0), false)

	# four pillars at stage corners
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box(Vector3(9.0 * x, 4.6, 9.0 * z), Vector3(1.1, 9.2, 1.1), Color("#2c2438"), Vector3.ZERO, 0.68)
			_box(Vector3(9.0 * x, 9.3, 9.0 * z), Vector3(1.5, 0.2, 1.5), Cfg.GOLD_DIM, Vector3.ZERO, 0.32, 0.7)

	# backdrop wall behind the stage with a lit sign band
	_box(Vector3(0, 5.0, -9.4), Vector3(19, 8.0, 0.5), Color("#251e31"), Vector3.ZERO, 0.7)
	_box_mat(Vector3(0, 7.2, -9.1), Vector3(12, 1.1, 0.12), _emit_mat(Cfg.GOLD, 3.0), Vector3.ZERO, false)
	_box_mat(Vector3(0, 3.4, -9.1), Vector3(10, 0.18, 0.12), _emit_mat(Cfg.CORAL, 2.6), Vector3.ZERO, false)


func _cover() -> void:
	# 1 m crates: the jump apex is 1.18 m, so every one of these is climbable.
	# The stacks are deliberate two-step routes, not scatter.
	var crates := [
		Vector3(-22, 0.5, -6), Vector3(-22, 1.5, -6), Vector3(-19.4, 0.5, -8.2),
		Vector3(21, 0.5, 7), Vector3(23.6, 0.5, 9.4), Vector3(21, 1.5, 7),
		Vector3(-7, 0.5, -18), Vector3(-4.4, 0.5, -18), Vector3(-5.7, 1.5, -18),
		Vector3(-12, 0.5, 24), Vector3(-9.4, 0.5, 24),
		Vector3(14, 0.5, -24), Vector3(16.6, 0.5, -24), Vector3(15.3, 1.5, -24),
		Vector3(-28, 0.5, 14), Vector3(28, 0.5, -14),
	]
	var i := 0
	for p: Vector3 in crates:
		var c: Color = Cfg.GOLD_DIM.lerp(Color("#6b5334"), 0.45)
		if i % 3 == 1:
			c = Color("#4b3f5c")
		_box(p, Vector3(1.0, 1.0, 1.0), c, Vector3(0, (i * 17) % 30, 0), 0.84)
		i += 1

	# stage stairs: 0.6 m then 1.2 m, so you can walk up without hunting a ramp
	for k in 2:
		var h := 0.6 * (k + 1)
		_box(Vector3(-10.6, h * 0.5, 0), Vector3(1.6, h, 4.0), Color("#3d3349"), Vector3.ZERO, 0.7)

	# long low walls creating lanes (two gaps each: no dead ends)
	_box(Vector3(-10, 1.2, 12), Vector3(26, 2.4, 0.7), Color("#332942"), Vector3.ZERO, 0.78)
	_box(Vector3(12, 1.2, -12), Vector3(0.7, 2.4, 26), Color("#332942"), Vector3.ZERO, 0.78)


func _ramps() -> void:
	var ramp_color := Color("#3d3349")
	_box(Vector3(0, 0.62, 12.5), Vector3(7, 0.3, 10), ramp_color, Vector3(11.5, 0, 0), 0.68)
	_box(Vector3(0, 0.62, -12.5), Vector3(7, 0.3, 10), ramp_color, Vector3(-11.5, 0, 0), 0.68)
	_box(Vector3(12.5, 0.62, 0), Vector3(10, 0.3, 7), ramp_color, Vector3(0, 0, -11.5), 0.68)
	_box(Vector3(-12.5, 0.62, 0), Vector3(10, 0.3, 7), ramp_color, Vector3(0, 0, 11.5), 0.68)


func _catwalk() -> void:
	var metal := Color("#4a4059")
	var y := 5.2
	_box(Vector3(-18, y, -18), Vector3(14, 0.3, 2.2), metal, Vector3.ZERO, 0.42, 0.55)
	_box(Vector3(18, y, -18), Vector3(14, 0.3, 2.2), metal, Vector3.ZERO, 0.42, 0.55)
	_box(Vector3(-18, y, 18), Vector3(14, 0.3, 2.2), metal, Vector3.ZERO, 0.42, 0.55)
	_box(Vector3(18, y, 18), Vector3(14, 0.3, 2.2), metal, Vector3.ZERO, 0.42, 0.55)
	_box(Vector3(-18, y, 0), Vector3(2.2, 0.3, 34), metal, Vector3.ZERO, 0.42, 0.55)
	_box(Vector3(18, y, 0), Vector3(2.2, 0.3, 34), metal, Vector3.ZERO, 0.42, 0.55)

	# edge strips so the catwalk silhouette reads against the room
	for k in 4:
		var ang := TAU * 0.25 * k + PI * 0.25
		var p := Vector3(cos(ang), 0, sin(ang)) * 26.5
		_box_mat(Vector3(p.x, y + 0.2, p.z), Vector3(3.2, 0.05, 0.08), _emit_mat(Cfg.MINT, 2.4),
			Vector3(0, rad_to_deg(-ang), 0), false)

	for x in [-24.0, -12.0, 12.0, 24.0]:
		_box(Vector3(x, 2.6, -18), Vector3(0.4, 5.2, 0.4), metal, Vector3.ZERO, 0.5, 0.5)
		_box(Vector3(x, 2.6, 18), Vector3(0.4, 5.2, 0.4), metal, Vector3.ZERO, 0.5, 0.5)


## Stair blocks at opposite corners make the catwalk a real route, not scenery.
func _catwalk_access() -> void:
	var step_col := Color("#3a3147")
	for corner in [Vector3(-24, 0, 22), Vector3(24, 0, -22)]:
		for k in 5:
			var y := 0.5 + k * 1.0
			_box(corner + Vector3(0, y, 0), Vector3(3.0, 1.0, 3.0), step_col, Vector3.ZERO, 0.78)
		_box(corner + Vector3(0, 5.3, 0), Vector3(4.0, 0.3, 4.0), Color("#4a4059"), Vector3.ZERO, 0.5, 0.4)


## Detail pass: neon gateways, hanging banners, festoon run and two corner booths.
## Everything is a route or a landmark; nothing is random scatter.
func _detail() -> void:
	# two lit gateways frame the long lanes and read from across the room
	for x in [-22.0, 22.0]:
		var col: Color = Cfg.MINT if x < 0 else Color("#8fb6ff")
		for z in [-7.0, 7.0]:
			_box(Vector3(x, 4.4, z), Vector3(0.9, 8.8, 0.9), Color("#241d30"), Vector3.ZERO, 0.55, 0.35)
		_box(Vector3(x, 8.8, 0), Vector3(0.9, 0.7, 14.6), Color("#2c2438"), Vector3.ZERO, 0.5, 0.3)
		_box_mat(Vector3(x, 8.4, 0), Vector3(0.7, 0.10, 13.8), _emit_mat(col, 4.0), Vector3.ZERO, false)
		for z in [-7.0, 7.0]:
			_box_mat(Vector3(x, 3.4, z), Vector3(0.7, 3.4, 0.10), _emit_mat(col, 2.2), Vector3.ZERO, false)

	# banners hanging from the truss, each with a gold hem
	for k in 5:
		var x := -24.0 + k * 12.0
		var banner := Color("#4a3350") if k % 2 == 0 else Color("#3a2a44")
		_box(Vector3(x, 9.6, -2.0), Vector3(3.2, 3.8, 0.08), banner, Vector3.ZERO, 0.9)
		_box_mat(Vector3(x, 7.75, -2.02), Vector3(3.2, 0.12, 0.06), _emit_mat(Cfg.GOLD, 2.0), Vector3.ZERO, false)

	# festoon run: small warm bulbs on two crossing lines
	for line in 2:
		for k in 9:
			var t := -32.0 + k * 8.0
			var p := Vector3(t, 10.6 - absf(t) * 0.035, -26.0 + line * 52.0)
			_box_mat(p, Vector3(0.16, 0.16, 0.16), _emit_mat(Color("#ffe6c2"), 2.4), Vector3.ZERO, false)

	# corner booths: a step up, a banquette and a table. Real cover, real landmark.
	for corner in [Vector3(-32.0, 0, 0), Vector3(32.0, 0, 0)]:
		var inward := 1.0 if corner.x < 0.0 else -1.0
		_box(corner + Vector3(0, 0.35, 0), Vector3(8.0, 0.7, 11.0), Color("#2a2236"), Vector3.ZERO, 0.8)
		_box(corner + Vector3(-inward * 3.3, 1.6, 0), Vector3(0.5, 2.8, 10.6), Color("#4a3350"), Vector3.ZERO, 0.85)
		_box(corner + Vector3(-inward * 2.5, 1.25, 0), Vector3(1.4, 0.9, 9.0), Color("#5e2735"), Vector3.ZERO, 0.9)
		_box(corner + Vector3(inward * 1.0, 1.0, 0), Vector3(2.2, 0.2, 3.0), Color("#4a3123"), Vector3.ZERO, 0.7)
		_box(corner + Vector3(inward * 1.0, 0.45, 0), Vector3(0.35, 0.9, 0.35), Color("#2a2030"), Vector3.ZERO, 0.5, 0.4)
		_light_add(corner + Vector3(inward * 2.0, 3.2, 0), Cfg.GOLD, 2.6, 10.0)

	# low cover walls to break the long sightlines from the stage
	_box(Vector3(-6, 0.8, 28), Vector3(12, 1.6, 0.6), Color("#332942"), Vector3.ZERO, 0.8)
	_box(Vector3(6, 0.8, -28), Vector3(12, 1.6, 0.6), Color("#332942"), Vector3.ZERO, 0.8)

	# --- landmark pass: sign, chandelier, floor ring ----------------------
	var sign := Label3D.new()
	sign.text = "THE FLOOR"
	sign.font = Style.display
	sign.font_size = 180
	sign.pixel_size = 0.012
	sign.modulate = Cfg.GOLD
	sign.outline_size = 12
	sign.outline_modulate = Color(0.05, 0.03, 0.08, 0.95)
	sign.position = Vector3(0, 5.9, -8.85)
	add_child(sign)

	var halo := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 2.55
	tor.outer_radius = 2.72
	tor.rings = 40
	tor.ring_segments = 10
	halo.mesh = tor
	halo.material_override = _emit_mat(Cfg.GOLD, 3.0)
	halo.position = Vector3(0, 10.2, 0)
	add_child(halo)
	for k in 8:
		var a := TAU * k / 8.0
		_box_mat(Vector3(cos(a) * 2.6, 10.0, sin(a) * 2.6), Vector3(0.18, 0.18, 0.18),
			_emit_mat(Color("#ffe6c2"), 3.4), Vector3.ZERO, false)
	_light_add(Vector3(0, 9.7, 0), Color("#ffe0ae"), 5.0, 24.0)

	var floor_ring := MeshInstance3D.new()
	var fr := TorusMesh.new()
	fr.inner_radius = 4.7
	fr.outer_radius = 4.85
	fr.rings = 64
	fr.ring_segments = 8
	floor_ring.mesh = fr
	floor_ring.material_override = _emit_mat(Cfg.GOLD, 2.2)
	floor_ring.position = Vector3(0, 1.27, 0)
	add_child(floor_ring)


func _light_add(pos: Vector3, col: Color, energy: float, range_m: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.1
	add_child(l)


func _spawns() -> void:
	spawn_points = [
		Vector3(0, 1.0, 26), Vector3(30, 1.0, -30), Vector3(-30, 1.0, 30),
		Vector3(30, 1.0, 30), Vector3(0, 2.4, 0), Vector3(-14, 1.0, -2),
		Vector3(14, 1.0, 2), Vector3(2, 1.0, 20),
	]
