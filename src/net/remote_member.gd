class_name RemoteMember
extends Node3D
## A network puppet: the same BlobBody the local member uses, fed by the host's
## snapshots. Position/yaw are interpolated; abilities replay through Fx.

var peer_id := 0
var member_name := "MEMBER"
var body: AnimatedCharacter
var is_it := false
var tint: Color = Cfg.MINT

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _speed := 0.0
var _has_target := false
var _ring: MeshInstance3D
var _label: Label3D


func setup(id: int, data: Dictionary) -> void:
	peer_id = id
	member_name = str(data.get("name", "MEMBER"))
	tint = Color(str(data.get("color", Cfg.MINT.to_html())))
	var shape := clampi(int(data.get("shape", 0)), 0, 2)

	body = AnimatedCharacter.new()
	add_child(body)
	body.build(tint, shape)

	_label = Label3D.new()
	_label.text = member_name
	_label.font_size = 44
	_label.pixel_size = 0.006
	_label.modulate = Color(0.95, 0.93, 0.9)
	_label.outline_size = 8
	_label.outline_modulate = Color(0.02, 0.02, 0.04, 0.9)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, 1.55, 0)
	add_child(_label)

	_ring = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.42
	tor.outer_radius = 0.47
	tor.rings = 32
	tor.ring_segments = 8
	_ring.mesh = tor
	_ring.material_override = _ring_mat(Cfg.MINT)
	_ring.position.y = 0.03
	add_child(_ring)


func _ring_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.2
	return m


func set_role(it: bool) -> void:
	is_it = it
	if body != null:
		body.set_role(it)
	if _ring != null:
		_ring.material_override = _ring_mat(Cfg.CORAL if it else tint)


## Found hiders and detonated potato carriers leave the visible playfield.
func set_out(v: bool) -> void:
	visible = not v


func apply_state(pos: Vector3, yaw: float, speed: float) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_speed = speed
	_has_target = true


func snap_to(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation.y = yaw
	_target_pos = pos
	_target_yaw = yaw
	_has_target = true


func _process(dt: float) -> void:
	if not _has_target:
		return
	var k := 1.0 - exp(-14.0 * dt)
	global_position = global_position.lerp(_target_pos, k)
	rotation.y = lerp_angle(rotation.y, _target_yaw, k)
	if body != null:
		body.animate(dt, _speed, true)


func play_ability(kind: String, color := Color(0.55, 0.9, 1.0)) -> void:
	var pos := global_position + Vector3(0, 0.9, 0)
	match kind:
		"shock":
			Fx.shock(global_position + Vector3(0, 0.2, 0), Color("#7de3ff"), 6.0)
			Fx.burst(pos, Color("#7de3ff"), 1.3)
		"blink":
			Fx.shock(global_position + Vector3(0, 0.2, 0), Color("#8fb6ff"), 2.2)
			Fx.burst(pos, Color("#8fb6ff"), 1.0)
		"shield":
			Fx.shock(global_position + Vector3(0, 0.2, 0), Color("#8fb6ff"), 1.6)
		_:
			Fx.trail(self, color)
			Fx.puff(global_position, Color(0.8, 0.75, 0.7, 0.4), 8)
