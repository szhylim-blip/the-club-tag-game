class_name HouseArena
extends Node3D
## THE HUSH — "The House". You are 1.3 m tall inside a house built for giants:
## a sofa you can stand on the arm of, a dining table three times your height,
## a kitchen island to break line of sight, a loft reached by a ramp.
## Hand-placed, no scatter: every prop is a hiding spot or a route.

var spawn_points: Array[Vector3] = []
var _mats: Dictionary = {}


func build() -> void:
	_environment()
	_lighting()
	_shell()
	_living()
	_kitchen()
	_dining()
	_hall_and_loft()
	_spawns()


func _mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [c.to_html(), rough, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


func _emit(c: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "e_%s_%.2f" % [c.to_html(), energy]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	_mats[key] = m
	return m


func _box(pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO, solid := true) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation_degrees = rot
	body.collision_layer = 1
	body.collision_mask = 0
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	if solid:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
	add_child(body)


func _light(pos: Vector3, col: Color, energy: float, range_m: float) -> void:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.1
	add_child(l)


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#1b1430")
	sky_mat.sky_horizon_color = Color("#6b4056")
	sky_mat.ground_horizon_color = Color("#2b2033")
	sky_mat.ground_bottom_color = Color("#0a0812")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.15
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1
	env.ssao_enabled = true
	env.ssao_radius = 1.1
	env.ssao_intensity = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color("#4a3040")
	env.fog_light_energy = 0.7
	env.fog_density = 0.006
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _lighting() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 28, 0)
	sun.light_color = Color("#ffd9b8")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 205, 0)
	fill.light_color = Color("#9fb6ff")
	fill.light_energy = 0.3
	add_child(fill)

	_light(Vector3(-16, 8.2, 8), Color("#ffcf9a"), 5.5, 30.0)
	_light(Vector3(18, 7.6, 10), Color("#ffe4b5"), 4.5, 24.0)
	_light(Vector3(0, 8.4, -17), Color("#ffd6a5"), 5.0, 26.0)
	_light(Vector3(22, 5.6, 20), Color("#ffc98a"), 3.0, 18.0)
	_light(Vector3(-26, 4.0, 20), Color("#8fb6ff"), 2.0, 14.0)


func _shell() -> void:
	# wooden floor: plank rows, so scale reads immediately
	_box(Vector3(0, -0.5, 0), Vector3(66, 1, 54), _mat(Color("#5a4030"), 0.9))
	for k in 26:
		var z := -25.0 + k * 2.0
		_box(Vector3(0, 0.02, z), Vector3(64, 0.03, 0.07), _mat(Color("#3c2a1f"), 0.9), Vector3.ZERO, false)

	var wall := _mat(Color("#c9b79c"), 0.9)
	_box(Vector3(0, 5.5, -26), Vector3(66, 11, 1.2), wall)
	_box(Vector3(0, 5.5, 26), Vector3(66, 11, 1.2), wall)
	_box(Vector3(-32, 5.5, 0), Vector3(1.2, 11, 54), wall)
	_box(Vector3(32, 5.5, 0), Vector3(1.2, 11, 54), wall)

	# skirting + chair rail: details that make the room read as a house
	var trim := _mat(Color("#3a2a22"), 0.8)
	for z in [-25.3, 25.3]:
		_box(Vector3(0, 0.35, z), Vector3(64, 0.7, 0.18), trim, Vector3.ZERO, false)
	for x in [-31.3, 31.3]:
		_box(Vector3(x, 0.35, 0), Vector3(0.18, 0.7, 52), trim, Vector3.ZERO, false)

	# interior walls with wide open doorways (no prompts, no doors)
	# living/kitchen divider at x = 4, openings at z -2..4 and z 16..22
	_box(Vector3(4, 5.5, -6), Vector3(0.8, 11, 12), wall)
	_box(Vector3(4, 5.5, 10), Vector3(0.8, 11, 12), wall)
	_box(Vector3(4, 5.5, 23), Vector3(0.8, 11, 6), wall)
	# dining divider at z = -8, openings x -4..2 and x 12..20
	_box(Vector3(-18, 5.5, -8), Vector3(28, 11, 0.8), wall)
	_box(Vector3(7, 5.5, -8), Vector3(10, 11, 0.8), wall)
	_box(Vector3(26, 5.5, -8), Vector3(12, 11, 0.8), wall)

	# ceiling beams, open to the sky above
	var beam := _mat(Color("#4a3427"), 0.85)
	for k in 5:
		_box(Vector3(-24.0 + k * 12.0, 10.6, 0), Vector3(0.8, 0.8, 51), beam, Vector3.ZERO, false)


func _sofa(base: Vector3) -> void:
	var fabric := _mat(Color("#6e3a44"), 0.95)
	var cushion := _mat(Color("#8c4a56"), 0.96)
	# 9 m wide, 1.6 m seat: giant sofa to a 1.3 m member
	_box(base + Vector3(0, 0.8, 0), Vector3(3.6, 1.0, 9.0), fabric)
	_box(base + Vector3(0.1, 1.55, -2.3), Vector3(3.2, 0.4, 3.9), cushion)
	_box(base + Vector3(0.1, 1.55, 2.3), Vector3(3.2, 0.4, 3.9), cushion)
	_box(base + Vector3(-1.6, 2.4, 0), Vector3(0.5, 3.0, 9.0), fabric)
	_box(base + Vector3(-1.2, 1.6, 0), Vector3(0.7, 1.6, 9.0), fabric)
	_box(base + Vector3(0.5, 1.4, -4.4), Vector3(3.2, 1.6, 0.5), fabric)
	_box(base + Vector3(0.5, 1.4, 4.4), Vector3(3.2, 1.6, 0.5), fabric)
	_box(base + Vector3(0.5, 0.9, -4.4), Vector3(3.0, 0.5, 0.4), cushion)
	_box(base + Vector3(0.5, 0.9, 4.4), Vector3(3.0, 0.5, 0.4), cushion)


func _living() -> void:
	var rug := _mat(Color("#5b2b33"), 0.95)
	_box(Vector3(-16, 0.03, 9), Vector3(16, 0.05, 11), rug, Vector3.ZERO, false)
	_box(Vector3(-16, 0.04, 9), Vector3(15, 0.04, 10), _mat(Color("#6e343e"), 0.95), Vector3.ZERO, false)
	_sofa(Vector3(-27.0, 0, 9.0))

	# coffee table: 1.7 m top, a platform you can stand on
	var wood := _mat(Color("#4a3123"), 0.7)
	_box(Vector3(-17, 1.55, 9), Vector3(7.0, 0.35, 4.0), wood)
	for sx in [-3.0, 3.0]:
		for sz in [-1.5, 1.5]:
			_box(Vector3(-17 + sx, 0.78, 9 + sz), Vector3(0.4, 1.55, 0.4), wood)

	# TV unit + giant screen, the light source of the room
	_box(Vector3(-3.4, 0.6, 9), Vector3(1.6, 1.2, 8.0), _mat(Color("#241a20"), 0.7))
	_box(Vector3(-3.5, 3.2, 9), Vector3(0.3, 5.4, 9.2), _mat(Color("#101018"), 0.4, 0.4))
	_box(Vector3(-3.62, 3.2, 9), Vector3(0.06, 4.8, 8.6), _emit(Color("#3d6fbf"), 1.3), Vector3.ZERO, false)

	# floor lamp
	_box(Vector3(-6.0, 3.0, 2.0), Vector3(0.3, 6.0, 0.3), _mat(Color("#c8b48a"), 0.4, 0.6))
	_box(Vector3(-6.0, 6.3, 2.0), Vector3(2.2, 1.4, 2.2), _emit(Color("#ffe3b0"), 1.4), Vector3.ZERO, false)
	_light(Vector3(-6.0, 6.0, 2.0), Color("#ffe0ae"), 2.2, 12.0)

	# bookshelf on the south wall, with actual books
	_box(Vector3(-20, 3.2, 24.6), Vector3(9.0, 6.4, 1.2), _mat(Color("#3b2a20"), 0.8))
	for shelf in 4:
		var y := 1.0 + shelf * 1.5
		_box(Vector3(-20, y, 23.8), Vector3(8.4, 0.2, 1.0), _mat(Color("#2b1d16"), 0.8), Vector3.ZERO, false)
		for b in 7:
			var col: Color = [Cfg.GOLD, Cfg.MINT, Cfg.CORAL, Color("#8fb6ff")][(shelf + b) % 4]
			_box(Vector3(-23.5 + b * 1.15, y + 0.55, 23.8), Vector3(0.5, 0.9, 0.7),
				_mat(col, 0.9), Vector3.ZERO, false)

	# plant in the corner
	_box(Vector3(-29, 1.0, 22), Vector3(1.6, 2.0, 1.6), _mat(Color("#7a4a34"), 0.9))
	_box(Vector3(-29, 3.0, 22), Vector3(2.6, 2.4, 2.6), _mat(Color("#3e6b47"), 0.95), Vector3.ZERO, false)


func _kitchen() -> void:
	var counter := _mat(Color("#8d8577"), 0.65, 0.1)
	var cabinet := _mat(Color("#5a3f2c"), 0.8)
	# run of counters along the east wall
	_box(Vector3(29.6, 1.2, 9), Vector3(2.6, 2.4, 22.0), cabinet)
	_box(Vector3(29.6, 2.55, 9), Vector3(2.9, 0.3, 22.4), counter)
	# sink basin
	_box(Vector3(29.4, 2.6, 4.0), Vector3(1.4, 0.3, 2.6), _mat(Color("#2c3138"), 0.35, 0.5), Vector3.ZERO, false)
	# island
	_box(Vector3(18, 1.15, 10), Vector3(7.0, 2.3, 4.0), cabinet)
	_box(Vector3(18, 2.45, 10), Vector3(7.4, 0.3, 4.4), counter)
	# fridge: 6 m tall
	_box(Vector3(28.8, 3.0, -3.5), Vector3(3.0, 6.0, 3.4), _mat(Color("#b9c2c6"), 0.35, 0.65))
	_box(Vector3(27.2, 3.0, -3.5), Vector3(0.08, 5.6, 3.0), _mat(Color("#d9e0e3"), 0.3, 0.4), Vector3.ZERO, false)
	# handles
	for y in [4.2, 2.4]:
		_box(Vector3(26.9, y, -3.5), Vector3(0.12, 1.0, 0.12), _mat(Color("#33383c"), 0.3, 0.8), Vector3.ZERO, false)
	# hanging pans above the island
	_box(Vector3(18, 8.0, 10), Vector3(0.15, 3.0, 0.15), _mat(Color("#2a2a2e"), 0.5, 0.7), Vector3.ZERO, false)
	for k in 3:
		var p := Vector3(17.0 + k * 1.1, 7.0, 10)
		_box(p, Vector3(0.9, 0.9, 0.12), _mat(Color("#3a3a40"), 0.35, 0.8), Vector3(0, 0, 90), false)
		_box(p + Vector3(0, 0.9, 0), Vector3(0.08, 1.4, 0.08), _mat(Color("#2a2a2e"), 0.5, 0.7), Vector3.ZERO, false)


func _chair(pos: Vector3, yaw: float) -> void:
	var wood := _mat(Color("#4a3123"), 0.75)
	var seat := _mat(Color("#6a4a33"), 0.85)
	_box(pos + Vector3(0, 1.1, 0), Vector3(2.2, 0.25, 2.2), seat, Vector3(0, yaw, 0))
	for sx in [-0.85, 0.85]:
		for sz in [-0.85, 0.85]:
			var off := Vector3(sx, 0, sz).rotated(Vector3.UP, deg_to_rad(yaw))
			_box(pos + off + Vector3(0, 0.55, 0), Vector3(0.25, 1.1, 0.25), wood)
	var back_off := Vector3(0, 0, -0.95).rotated(Vector3.UP, deg_to_rad(yaw))
	_box(pos + back_off + Vector3(0, 2.2, 0), Vector3(2.2, 2.4, 0.25), seat, Vector3(0, yaw, 0))


func _dining() -> void:
	var wood := _mat(Color("#4a3123"), 0.75)
	var cloth := _mat(Color("#7a3f46"), 0.95)
	# table: 10 x 5, top at 3 m
	_box(Vector3(0, 3.0, -17), Vector3(10.0, 0.35, 5.0), wood)
	_box(Vector3(0, 3.2, -17), Vector3(9.4, 0.06, 4.4), cloth, Vector3.ZERO, false)
	for sx in [-4.2, 4.2]:
		for sz in [-2.0, 2.0]:
			_box(Vector3(sx, 1.5, -17 + sz), Vector3(0.45, 3.0, 0.45), wood)

	_chair(Vector3(-3.0, 0, -23.0), 0)
	_chair(Vector3(0.0, 0, -23.0), 0)
	_chair(Vector3(3.0, 0, -23.0), 0)
	_chair(Vector3(-3.0, 0, -11.0), 180)
	_chair(Vector3(0.0, 0, -11.0), 180)
	_chair(Vector3(3.0, 0, -11.0), 180)

	# pendant over the table
	_box(Vector3(0, 9.4, -17), Vector3(0.16, 3.2, 0.16), _mat(Color("#231a16"), 0.6), Vector3.ZERO, false)
	_box(Vector3(0, 7.8, -17), Vector3(2.4, 1.0, 2.4), _emit(Color("#ffd9a0"), 1.6), Vector3.ZERO, false)

	# sideboard on the north wall
	_box(Vector3(-8, 1.4, -24.8), Vector3(8.0, 2.8, 1.4), wood)
	_box(Vector3(-8, 2.85, -24.8), Vector3(8.3, 0.2, 1.6), _mat(Color("#6a4a33"), 0.8), Vector3.ZERO, false)


func _hall_and_loft() -> void:
	var wood := _mat(Color("#4a3123"), 0.75)
	# ramp along the south wall up to the loft (walkable, not a ladder)
	_box(Vector3(10, 1.65, 22.0), Vector3(14.0, 0.35, 5.0), wood, Vector3(0, 0, -13.5))
	# loft deck over the kitchen half
	_box(Vector3(22.5, 3.35, 17.0), Vector3(15.0, 0.3, 16.0), wood)
	for k in 3:
		_box(Vector3(22.5, 1.65, 9.5 + k * 7.0), Vector3(1.0, 3.3, 1.0), wood)
	# railing
	for x in [15.2, 22.5, 29.8]:
		_box(Vector3(x, 4.1, 9.2), Vector3(0.25, 1.5, 0.25), _mat(Color("#2c211b"), 0.7), Vector3.ZERO, false)
	_box(Vector3(22.5, 4.6, 9.2), Vector3(15.0, 0.2, 0.2), _mat(Color("#2c211b"), 0.7), Vector3.ZERO, false)

	# front door: a giant slab of light at the end of the hall
	_box(Vector3(0, 5.0, 25.7), Vector3(8.0, 10.0, 0.5), _mat(Color("#2f2118"), 0.8))
	_box(Vector3(0, 4.6, 25.4), Vector3(6.4, 8.6, 0.2), _emit(Color("#ffd9a8"), 0.6), Vector3.ZERO, false)
	_box(Vector3(0, 0.05, 20.0), Vector3(10.0, 0.06, 12.0), _mat(Color("#7a5a3f"), 0.9), Vector3.ZERO, false)

	# coats and a hall table
	_box(Vector3(-10, 1.1, 24.6), Vector3(4.0, 2.2, 1.2), wood)
	_box(Vector3(-10, 2.3, 24.6), Vector3(4.3, 0.15, 1.4), _mat(Color("#6a4a33"), 0.8), Vector3.ZERO, false)

	# loft detail: a rug and a low chest
	_box(Vector3(23, 3.52, 18), Vector3(9.0, 0.04, 7.0), _mat(Color("#3f4a63"), 0.95), Vector3.ZERO, false)
	_box(Vector3(27, 4.1, 20), Vector3(3.0, 0.8, 3.0), _mat(Color("#5a3f2c"), 0.85))


func _spawns() -> void:
	spawn_points = [
		Vector3(-16, 1.0, 16), Vector3(18, 1.0, 4), Vector3(0, 1.0, -20),
		Vector3(-27, 1.0, 4), Vector3(24, 1.0, 18), Vector3(-6, 1.0, -2),
		Vector3(10, 1.0, 14), Vector3(28, 1.0, -6),
		Vector3(-22, 1.0, 22), Vector3(2, 1.0, 22),
	]
