class_name CameraTest
extends Node
## Scripted camera proof for third person. It drives genuine InputEvents through
## the viewport and the real Input singleton (mouse look and WASD), against the
## real ClubPlayer, then reads the live Camera3D transform.
##
## The self-test harness owns the assertions; this file owns the rig and the
## event plumbing so the test code reads as input -> wait -> measure.

const STEP := 1.0 / 60.0

var _key_held: Dictionary = {}
var _mouse_pos := Vector2(800, 450)


func rig(wall_z := 0.0, wall_half_x := 8.0) -> Array:
	var root := Node3D.new()
	root.name = "CameraRig"
	add_child(root)

	var floor_body := StaticBody3D.new()
	floor_body.position = Vector3(0, -0.5, 0)
	floor_body.collision_layer = 1
	floor_body.collision_mask = 0
	var fcs := CollisionShape3D.new()
	var fbox := BoxShape3D.new()
	fbox.size = Vector3(80, 1, 80)
	fcs.shape = fbox
	floor_body.add_child(fcs)
	root.add_child(floor_body)

	if wall_z != 0.0:
		var wall := StaticBody3D.new()
		wall.position = Vector3(0, 2.0, wall_z)
		wall.collision_layer = 1
		wall.collision_mask = 0
		var wcs := CollisionShape3D.new()
		var wbox := BoxShape3D.new()
		wbox.size = Vector3(wall_half_x * 2.0, 4.0, 0.4)
		wcs.shape = wbox
		wall.add_child(wcs)
		root.add_child(wall)

	var p := ClubPlayer.new()
	p.name = "CameraPlayer"
	p.set_scripted(true)
	p.is_local = true
	p.test_capture = true
	root.add_child(p)
	p.global_position = Vector3(0, 0.0, 0)
	p.rotation.y = 0.0
	return [root, p]


func capture() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_mouse_pos = Vector2(800, 450)


func mouse(dx: float, dy: float) -> void:
	# The viewport rebuilds `relative` from the absolute cursor delta, so anchor
	# each event to the cursor it actually has and move it by exactly (dx, dy).
	var before := get_viewport().get_mouse_position()
	var ev := InputEventMouseMotion.new()
	ev.relative = Vector2(dx, dy)
	ev.position = before + Vector2(dx, dy)
	# Real event path: viewport input -> _unhandled_input, not a method call.
	get_viewport().push_input(ev, true)
	_mouse_pos = ev.position
	await get_tree().process_frame


## Real key events through the Input singleton, so Input.get_vector and
## Input.is_action_pressed see them exactly as a player's keyboard would.
func key(code: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = down
	Input.parse_input_event(ev)
	if down:
		_key_held[code] = true
	else:
		_key_held.erase(code)


func release_all() -> void:
	for code in _key_held.keys():
		key(int(code) as Key, false)
	_key_held.clear()


func wait(sec: float) -> void:
	var t := 0.0
	while t < sec:
		await get_tree().physics_frame
		t += STEP


func settle(sec := 0.35) -> void:
	await wait(sec)
