class_name Hub
extends Node3D
## The Club — a four-leaf-clover lobby. One central room with four open doorways;
## each doorway is a real hole in the wall into a themed waiting room that is
## always loaded. Walk through, no prompt, no key, no transition.
##
##   N  THE FLOOR     practice arena: ramps, bhop line, spots
##   W  THE HUSH      dark parkour and hiding nooks
##   E  THE PARLOUR   warm tables, chairs, lamps
##   S  THE BASEMENT  cold room, item stands, lore plaques

signal entered_room(room: String)

const PROP_TABLE: PackedScene = preload("res://assets/props/table_long.glb")
const PROP_CRATES: PackedScene = preload("res://assets/props/crates_stacked.glb")
const DOOR_W := 4.6
const DOOR_H := 3.4
const HUB_HALF := 18.0
const WING_DIST := 27.0
const WING_HALF := 10.0

var player: ClubPlayer
var _t := 0.0
var _beat: Array[OmniLight3D] = []
var _sofas: Array[Dictionary] = []
var _nearest_sofa := -1
var _prompt: Label


func _ready() -> void:
	_environment()
	_hub_shell()
	_bar()
	_dance_floor()
	_centre_piece()
	_door_arrows()
	_wings()
	_ambience()
	_player()
	_prompt_ui()


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#141026")
	sky_mat.sky_horizon_color = Color("#4a3456")
	sky_mat.ground_horizon_color = Color("#241d31")
	sky_mat.ground_bottom_color = Color("#0a0812")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.06
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.95
	env.ssao_enabled = true
	env.ssao_radius = 1.3
	env.ssao_intensity = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color("#33284a")
	env.fog_light_energy = 0.6
	env.fog_density = 0.008
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.05
	env.adjustment_saturation = 1.07
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-62, 28, 0)
	moon.light_color = Color("#c6d2ff")
	moon.light_energy = 1.15
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 80.0
	add_child(moon)


# --- geometry helpers ---------------------------------------------------

func _mat(c: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _emit(c: Color, energy := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.3
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, solid := true, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	if solid:
		var body := StaticBody3D.new()
		body.position = pos
		body.rotation_degrees = rot
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		body.add_child(cs)
		parent.add_child(body)
	return mi


func _label(parent: Node3D, text: String, pos: Vector3, col: Color, size := 64) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = Style.display
	l.font_size = size
	l.pixel_size = 0.0075
	l.modulate = col
	l.outline_size = 0
	l.position = pos
	parent.add_child(l)


func _light(parent: Node3D, pos: Vector3, col: Color, energy: float, range_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = range_m
	l.omni_attenuation = 1.2
	parent.add_child(l)
	return l


## A wall with a doorway-sized hole cut in the middle.
func _wall_with_door(parent: Node3D, center: Vector3, length: float, height: float, along_x: bool, mat: Material) -> void:
	var side := (length - DOOR_W) * 0.5
	var offset := DOOR_W * 0.5 + side * 0.5
	# center already carries the wall's half-height, so the lintel uses absolute y
	var lintel_y := DOOR_H + (height - DOOR_H) * 0.5
	if along_x:
		_box(parent, center + Vector3(-offset, 0, 0), Vector3(side, height, 0.8), mat)
		_box(parent, center + Vector3(offset, 0, 0), Vector3(side, height, 0.8), mat)
		_box(parent, Vector3(center.x, lintel_y, center.z),
			Vector3(DOOR_W, height - DOOR_H, 0.8), mat)
	else:
		_box(parent, center + Vector3(0, 0, -offset), Vector3(0.8, height, side), mat)
		_box(parent, center + Vector3(0, 0, offset), Vector3(0.8, height, side), mat)
		_box(parent, Vector3(center.x, lintel_y, center.z),
			Vector3(0.8, height - DOOR_H, DOOR_W), mat)


func _hub_shell() -> void:
	var wall := _mat(Color("#574a67"), 0.78)
	_box(self, Vector3(0, -0.5, 0), Vector3(HUB_HALF * 2, 1, HUB_HALF * 2), _mat(Color("#4e4360"), 0.8))
	# inlaid ring so the centre reads as a room, not a corridor
	_box(self, Vector3(0, 0.02, 0), Vector3(26, 0.04, 26), _mat(Color("#6a5a7e"), 0.7), false)
	_box(self, Vector3(0, 0.03, 0), Vector3(18, 0.04, 18), _mat(Color("#7a688f"), 0.65), false)

	# four lamp posts, so the room reads at a glance without relying on the sky
	for x in [-9.0, 9.0]:
		for z in [-9.0, 9.0]:
			_box(self, Vector3(x, 1.5, z), Vector3(0.22, 3.0, 0.22), _mat(Color("#2a2238"), 0.6))
			_box(self, Vector3(x, 3.1, z), Vector3(0.7, 0.3, 0.7), _emit(Color("#ffe6c2"), 2.6), false)
			_light(self, Vector3(x, 3.4, z), Color("#ffdfae"), 3.4, 14.0)

	var h := 7.0
	_wall_with_door(self, Vector3(0, h * 0.5, -HUB_HALF), HUB_HALF * 2, h, true, wall)
	_wall_with_door(self, Vector3(0, h * 0.5, HUB_HALF), HUB_HALF * 2, h, true, wall)
	_wall_with_door(self, Vector3(-HUB_HALF, h * 0.5, 0), HUB_HALF * 2, h, false, wall)
	_wall_with_door(self, Vector3(HUB_HALF, h * 0.5, 0), HUB_HALF * 2, h, false, wall)

	# corner ribs + the club's four ceiling bulbs
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box(self, Vector3(17.2 * x, 3.5, 17.2 * z), Vector3(0.7, 7.0, 0.7),
				_mat(Color("#2a2238"), 0.7))
			_light(self, Vector3(13.0 * x, 5.0, 13.0 * z), Cfg.GOLD, 3.2, 20.0)


func _bar() -> void:
	var counter := _mat(Color("#4a3a2c"), 0.55, 0.1)
	_box(self, Vector3(-13, 0.6, 12.4), Vector3(11, 1.2, 1.4), counter)
	_box(self, Vector3(-13, 1.25, 12.4), Vector3(11.4, 0.1, 1.8), _mat(Color("#6b5334"), 0.4, 0.2), false)
	for k in 8:
		var x := -17.5 + k * 1.3
		var col: Color = [Cfg.GOLD, Cfg.MINT, Cfg.CORAL][k % 3]
		_box(self, Vector3(x, 1.6, 16.2), Vector3(0.22, 0.7, 0.22), _emit(col, 2.2), false)
	_box(self, Vector3(-13, 1.8, 16.6), Vector3(11, 3.4, 0.7), _mat(Color("#241c2e"), 0.7))
	for k in 5:
		var x := -17.0 + k * 2.0
		_box(self, Vector3(x, 0.55, 10.6), Vector3(0.5, 0.14, 0.5), _mat(Color("#3a2c40"), 0.6), false)
		_box(self, Vector3(x, 0.28, 10.6), Vector3(0.14, 0.56, 0.14), _mat(Color("#2a2034"), 0.5, 0.4), false)


func _centre_piece() -> void:
	# a round lounge in the middle, so the clover has a heart
	var rug := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 4.2
	cyl.bottom_radius = 4.2
	cyl.height = 0.06
	rug.mesh = cyl
	rug.position = Vector3(0, 0.04, 0)
	rug.material_override = _mat(Color("#5a2f3e"), 0.9)
	add_child(rug)

	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 4.05
	tor.outer_radius = 4.22
	ring.mesh = tor
	ring.position.y = 0.07
	ring.material_override = _mat(Cfg.GOLD_DIM, 0.4, 0.6)
	add_child(ring)

	_box(self, Vector3(0, 0.44, 0), Vector3(2.0, 0.1, 2.0), _mat(Color("#4a3a2c"), 0.5, 0.1))
	_box(self, Vector3(0, 0.22, 0), Vector3(0.3, 0.44, 0.3), _mat(Color("#2a2034"), 0.6))
	_box(self, Vector3(0, 0.52, 0), Vector3(0.34, 0.1, 0.34), _emit(Cfg.GOLD, 1.4), false)

	for k in 4:
		var ang := TAU * 0.25 * k + PI * 0.25
		var p := Vector3(cos(ang), 0, sin(ang)) * 3.55
		_sofa(p)

	# chandelier over the lounge
	_box(self, Vector3(0, 5.2, 0), Vector3(0.1, 2.2, 0.1), _mat(Color("#2a2238"), 0.5), false)
	for k in 6:
		var ang := TAU / 6.0 * k
		_box(self, Vector3(cos(ang) * 1.1, 4.05, sin(ang) * 1.1), Vector3(0.18, 0.18, 0.18),
			_emit(Color("#ffe6c2"), 3.0), false)
	_light(self, Vector3(0, 3.9, 0), Color("#ffdfae"), 6.0, 16.0)


## A real sofa, not a block: plinth, two cushions, back with lumbar, rolled arms
## on stubby legs. Seat height 0.53 m, and the seat centre is the sit anchor.
func _sofa(center: Vector3) -> void:
	var toward := Vector3(-center.x, 0, -center.z).normalized()
	var node := Node3D.new()
	node.position = center
	node.rotation.y = atan2(toward.x, toward.z)
	add_child(node)

	var fabric := _mat(Color("#5e2735"), 0.94)
	var cushion := _mat(Color("#84394b"), 0.96)
	var trim := _mat(Color("#9a4557"), 0.9)
	var leg := _mat(Color("#2a2030"), 0.35, 0.55)

	_box(node, Vector3(0, 0.22, 0.02), Vector3(2.1, 0.18, 0.95), fabric, true)
	for sx in [-0.86, 0.86]:
		for sz in [-0.30, 0.32]:
			_box(node, Vector3(sx, 0.09, sz), Vector3(0.11, 0.18, 0.11), leg, true)
	_box(node, Vector3(-0.48, 0.43, 0.06), Vector3(0.94, 0.22, 0.84), cushion, true)
	_box(node, Vector3(0.48, 0.43, 0.06), Vector3(0.94, 0.22, 0.84), cushion, true)
	_box(node, Vector3(0, 0.56, 0.06), Vector3(1.98, 0.06, 0.90), trim, false)

	_box(node, Vector3(0, 0.82, -0.38), Vector3(2.1, 0.78, 0.22), fabric, true)
	_box(node, Vector3(0, 0.62, -0.25), Vector3(1.9, 0.24, 0.16), cushion, false)

	for ax in [-0.96, 0.96]:
		_box(node, Vector3(ax, 0.56, 0.02), Vector3(0.22, 0.40, 0.98), fabric, true)
		_box(node, Vector3(ax, 0.79, 0.02), Vector3(0.26, 0.10, 1.02), trim, false)
		_box(node, Vector3(ax, 0.36, 0.02), Vector3(0.18, 0.12, 0.92), leg, false)

	_sofas.append({
		"pos": center,
		"sit_pos": center + toward * 0.08 + Vector3(0, 0.53, 0),
		"sit_yaw": rad_to_deg(atan2(toward.x, toward.z)) + 180.0,
	})


func _prompt_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	cc.offset_top = -118.0
	cc.offset_bottom = -78.0
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cc)
	_prompt = Label.new()
	_prompt.text = ""
	_prompt.add_theme_font_size_override("font_size", 17)
	_prompt.add_theme_color_override("font_color", Cfg.GOLD)
	_prompt.add_theme_color_override("font_outline_color", Color(0.02, 0.01, 0.04, 0.9))
	_prompt.add_theme_constant_override("outline_size", 6)
	cc.add_child(_prompt)


func _update_prompt() -> void:
	if player == null:
		return
	_nearest_sofa = -1
	var best := 2.6
	for i in _sofas.size():
		var p: Vector3 = _sofas[i]["pos"]
		var d := Vector2(player.global_position.x - p.x, player.global_position.z - p.z).length()
		if d < best:
			best = d
			_nearest_sofa = i
	if player.is_seated():
		_prompt.text = "E    STAND"
	elif _nearest_sofa >= 0:
		_prompt.text = "E    SIT"
	else:
		_prompt.text = ""


## Used by the screenshot harness: sit on the first sofa exactly as E would.
func debug_sit() -> void:
	print("DEBUG_SIT sofas=%d player=%s" % [_sofas.size(), str(player != null)])
	if _sofas.is_empty() or player == null:
		return
	var s: Dictionary = _sofas[0]
	player.sit_at(s["sit_pos"], s["sit_yaw"])
	print("DEBUG_SIT seated=", player.is_seated())


func teleport_to(wing: String) -> void:
	var targets := {
		"floor": Vector3(0, 1.2, -23),
		"hush": Vector3(-23, 1.2, 0),
		"parlour": Vector3(23, 1.2, 0),
		"basement": Vector3(0, 1.2, 23),
		"lounge": Vector3(0, 1.2, 7),
	}
	if player == null:
		return
	player.global_position = targets.get(wing, targets["lounge"])
	player.velocity = Vector3.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo or k.keycode != KEY_E:
		return
	if player == null:
		return
	if player.is_seated():
		player.stand_up()
		get_viewport().set_input_as_handled()
	elif _nearest_sofa >= 0:
		var s: Dictionary = _sofas[_nearest_sofa]
		player.sit_at(s["sit_pos"], s["sit_yaw"])
		get_viewport().set_input_as_handled()


func _door_arrows() -> void:
	# inlaid gold strips pointing at each doorway: orientation, not signage
	var dirs := [
		[Vector3(0, 0, -1), 0.0],
		[Vector3(-1, 0, 0), 90.0],
		[Vector3(1, 0, 0), -90.0],
		[Vector3(0, 0, 1), 180.0],
	]
	for entry: Array in dirs:
		var d: Vector3 = entry[0]
		var yaw: float = entry[1]
		_box(self, d * 12.0 + Vector3(0, 0.035, 0), Vector3(0.18, 0.02, 6.0),
			_emit(Cfg.GOLD, 1.1), false, Vector3(0, yaw, 0))


func _dance_floor() -> void:
	var cols := [Cfg.GOLD, Cfg.MINT, Cfg.CORAL, Color("#8fb6ff")]
	_box(self, Vector3(10, 0.04, -10), Vector3(11, 0.08, 11), _emit(Color("#2a1c3c"), 1.0), false)
	var i := 0
	for x in 3:
		for z in 3:
			if (x + z) % 2 == 0:
				var c: Color = cols[i % 4]
				_box(self, Vector3(10 - 3.4 + x * 3.4, 0.09, -10 - 3.4 + z * 3.4),
					Vector3(2.8, 0.04, 2.8), _emit(c, 0.9), false)
				i += 1
	for k in 4:
		var ang := TAU * 0.25 * k
		var l := _light(self, Vector3(10 + cos(ang) * 4.5, 6.0, -10 + sin(ang) * 4.5),
			cols[k % 4], 3.0, 14.0)
		_beat.append(l)


# --- the four wings -----------------------------------------------------

func _wings() -> void:
	_wing(Vector3(0, 0, -1), "floor", Cfg.GOLD, Color("#2a1f18"))
	_wing(Vector3(-1, 0, 0), "hush", Cfg.MINT, Color("#101a18"))
	_wing(Vector3(1, 0, 0), "parlour", Cfg.CORAL, Color("#2a1418"))
	_wing(Vector3(0, 0, 1), "basement", Color("#8fb6ff"), Color("#121722"))


func _wing(dir: Vector3, id: String, col: Color, floor_col: Color) -> void:
	var room := Node3D.new()
	room.name = "Wing_" + id
	room.position = dir * WING_DIST
	room.rotation_degrees.y = rad_to_deg(atan2(dir.x, dir.z))
	add_child(room)

	var w := WING_HALF * 2.0
	var depth := WING_HALF * 2.0
	var h := 6.0

	# floor + ceilingless perimeter; the -Z side is the mouth facing the hub
	_box(room, Vector3(0, -0.5, 0), Vector3(w, 1, depth), _mat(floor_col, 0.85))
	_box(room, Vector3(0, 0.02, 0), Vector3(w - 3, 0.04, depth - 3), _mat(floor_col.lightened(0.08), 0.7), false)
	var wall_mat := _mat(Color("#3a3048").lerp(floor_col, 0.45), 0.78)
	_box(room, Vector3(0, h * 0.5, WING_HALF), Vector3(w, h, 0.8), wall_mat)
	_box(room, Vector3(-WING_HALF, h * 0.5, 0), Vector3(0.8, h, depth), wall_mat)
	_box(room, Vector3(WING_HALF, h * 0.5, 0), Vector3(0.8, h, depth), wall_mat)
	# mouth wall: two stubs + lintel, so the opening lines up with the hub door
	_box(room, Vector3(-(WING_HALF - (WING_HALF - DOOR_W * 0.5) * 0.5), h * 0.5, -WING_HALF),
		Vector3(WING_HALF - DOOR_W * 0.5, h, 0.8), wall_mat)
	_box(room, Vector3((WING_HALF - (WING_HALF - DOOR_W * 0.5) * 0.5), h * 0.5, -WING_HALF),
		Vector3(WING_HALF - DOOR_W * 0.5, h, 0.8), wall_mat)
	_box(room, Vector3(0, DOOR_H + (h - DOOR_H) * 0.5, -WING_HALF),
		Vector3(DOOR_W, h - DOOR_H, 0.8), wall_mat)

	# threshold light and name plate, both on the hub side of the mouth
	_light(room, Vector3(0, 2.6, -WING_HALF + 0.8), col, 8.0, 16.0)
	_box(room, Vector3(0, DOOR_H + 0.35, -WING_HALF + 0.45), Vector3(DOOR_W + 0.6, 0.14, 0.1),
		_emit(col, 4.2), false)
	# a lit strip just inside the mouth: you can see the room's colour from the hub
	_box(room, Vector3(0, 0.05, -WING_HALF + 1.6), Vector3(DOOR_W - 0.4, 0.04, 1.2),
		_emit(col, 1.6), false)
	_label(room, id.to_upper(), Vector3(0, DOOR_H + 0.9, -WING_HALF + 0.4), col, 56)

	match id:
		"floor":
			_wing_floor(room, col)
		"hush":
			_wing_hush(room, col)
		"parlour":
			_wing_parlour(room, col)
		"basement":
			_wing_basement(room, col)


func _wing_floor(room: Node3D, col: Color) -> void:
	# practice arena: two ramps, a raised platform, a bhop line
	_box(room, Vector3(0, 0.6, 1.0), Vector3(7, 1.2, 7), _mat(Color("#4a3a2c"), 0.7))
	_box(room, Vector3(0, 1.22, 1.0), Vector3(6.4, 0.06, 6.4), _emit(Color("#3a2a1c"), 0.7), false)
	_box(room, Vector3(-3.2, 0.6, 6.6), Vector3(3.4, 0.3, 4.6), _mat(Color("#3d3348"), 0.65), true, Vector3(12, 0, 0))
	_box(room, Vector3(3.2, 0.6, 6.6), Vector3(3.4, 0.3, 4.6), _mat(Color("#3d3348"), 0.65), true, Vector3(12, 0, 0))
	for k in 3:
		_box(room, Vector3(-6.0 + k * 2.6, 1.0 + k * 0.55, -5.5), Vector3(1.8, 0.35, 1.8),
			_mat(Color("#43364f"), 0.6), true)
	_light(room, Vector3(0, 5.2, 0), col, 5.0, 16.0)
	_light(room, Vector3(0, 5.0, 7), Color("#fff0d2"), 2.4, 10.0)


func _wing_hush(room: Node3D, col: Color) -> void:
	# dark parkour: staggered blocks and two hiding alcoves
	var block := _mat(Color("#22302c"), 0.75)
	for k in 5:
		_box(room, Vector3(-6.5 + k * 3.2, 0.7 + k * 0.7, -2.0 + (k % 2) * 3.0),
			Vector3(1.6, 1.4 + k * 1.4, 1.6), block)
	_box(room, Vector3(-7.5, 1.2, 6.5), Vector3(3.2, 2.4, 2.4), _mat(Color("#1b2622"), 0.8))
	_box(room, Vector3(7.5, 1.2, 6.5), Vector3(3.2, 2.4, 2.4), _mat(Color("#1b2622"), 0.8))
	_light(room, Vector3(-7.5, 3.0, 6.5), col, 1.6, 7.0)
	_light(room, Vector3(7.5, 3.0, 6.5), col, 1.6, 7.0)
	_light(room, Vector3(0, 5.0, 0), Color("#3f6b5c"), 1.8, 14.0)


func _wing_parlour(room: Node3D, col: Color) -> void:
	var table_mat := _mat(Color("#5a3a28"), 0.5, 0.15)
	for k in 3:
		var x := -5.5 + k * 5.5
		_box(room, Vector3(x, 0.75, 0), Vector3(3.2, 0.14, 1.6), table_mat)
		_box(room, Vector3(x, 0.38, 0), Vector3(0.25, 0.76, 0.25), _mat(Color("#3a2a1c"), 0.6))
		# chairs
		_box(room, Vector3(x, 0.45, -1.3), Vector3(0.7, 0.9, 0.7), _mat(Color("#4a1f2a"), 0.7))
		_box(room, Vector3(x, 0.45, 1.3), Vector3(0.7, 0.9, 0.7), _mat(Color("#4a1f2a"), 0.7))
		# chips and a lamp on each table
		_box(room, Vector3(x - 0.6, 0.88, 0.1), Vector3(0.3, 0.08, 0.3), _emit(Cfg.GOLD, 1.4), false)
		_box(room, Vector3(x + 0.6, 0.95, -0.2), Vector3(0.12, 0.34, 0.12), _emit(Color("#ffe6b0"), 3.0), false)
		_light(room, Vector3(x, 1.6, 0), Color("#ffb066"), 2.2, 7.5)
	_box(room, Vector3(0, 1.2, -8.6), Vector3(6, 2.4, 0.4), _emit(Color("#3a1418"), 0.8), false)
	_light(room, Vector3(0, 4.6, 0), col, 2.6, 16.0)


func _wing_basement(room: Node3D, col: Color) -> void:
	# item stands + lore plaques. Dim, cold, no music.
	var pedestal := _mat(Color("#2a3242"), 0.7, 0.2)
	var items := [
		["FLASHLIGHT", Color("#ffe6b0")],
		["FUSE", Color("#ff9e6b")],
		["BEACON", Cfg.MINT],
		["KEY CARD", Color("#8fb6ff")],
	]
	for k in items.size():
		var x := -6.0 + k * 4.0
		_box(room, Vector3(x, 0.5, 3.0), Vector3(1.0, 1.0, 1.0), pedestal)
		_box(room, Vector3(x, 1.35, 3.0), Vector3(0.4, 0.4, 0.4), _emit(items[k][1], 2.2), false)
		_light(room, Vector3(x, 1.9, 3.0), items[k][1], 1.4, 5.0)
		_label(room, items[k][0], Vector3(x, 2.35, 3.0), items[k][1], 28)
	_box(room, Vector3(0, 1.6, 8.8), Vector3(9, 3.0, 0.4), _mat(Color("#1b2230"), 0.8))
	_label(room, "ENTITY ARCHIVE  ·  NOT ALL OF THEM", Vector3(0, 2.4, 8.4), col, 34)
	_light(room, Vector3(0, 4.6, 2), Color("#4a6a9a"), 2.0, 14.0)


## Real light-sprite motes plus soft additive shafts under the chandelier.
func _ambience() -> void:
	var motes := GPUParticles3D.new()
	motes.amount = 70
	motes.lifetime = 11.0
	motes.preprocess = 5.0
	motes.position = Vector3(0, 1.0, 0)
	motes.visibility_aabb = AABB(Vector3(-20, -3, -20), Vector3(40, 12, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(15, 0.6, 15)
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.22
	pm.gravity = Vector3(0.03, 0.02, 0.0)
	pm.scale_min = 0.05
	pm.scale_max = 0.17
	pm.color = Color(1.0, 0.93, 0.76, 0.55)
	motes.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.32)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = preload("res://assets/vfx/light_00.png")
	mat.vertex_color_use_as_albedo = true
	q.material = mat
	motes.draw_pass_1 = q
	add_child(motes)

	for k in 4:
		var ang := TAU * 0.25 * k + PI * 0.25
		var shaft := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.18
		cone.bottom_radius = 1.35
		cone.height = 5.0
		shaft.mesh = cone
		shaft.position = Vector3(cos(ang) * 1.15, 2.4, sin(ang) * 1.15)
		var sm := StandardMaterial3D.new()
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.cull_mode = BaseMaterial3D.CULL_DISABLED
		sm.albedo_texture = preload("res://assets/vfx/light_01.png")
		sm.albedo_color = Color(1.0, 0.86, 0.62, 0.07)
		shaft.material_override = sm
		add_child(shaft)


func _player() -> void:
	player = ClubPlayer.new()
	player.name = "Player"
	player.member_name = "YOU"
	player.is_local = true
	add_child(player)
	player.ground_surface = "wood"
	Sfx.start_casino_bed()
	player.global_position = Vector3(0, 1.2, 8)
	player.rotation_degrees.y = 0.0
	player.cam.current = true


func _process(dt: float) -> void:
	_t += dt
	var beat := pow(maxf(0.0, sin(_t * 4.2)), 6.0)
	for l in _beat:
		l.light_energy = 1.4 + beat * 2.4
	_update_prompt()
