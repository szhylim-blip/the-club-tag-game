class_name AnimatedCharacter
extends Node3D
## The playable member: Kenney/Kay Lousberg's rigged humanoid (CC0), stripped
## to a single monochrome material. The current pack ships authored locomotion,
## crouch, slide, stair, turn and punch clips; this controller plays those clips
## directly and keeps the small surface used by player/AI/network code.

const MODEL_SCENE := "res://Animated Characters 1/Model/characterMedium.fbx"
const IDLE_SCENE := "res://Animated Characters 1/Animations/idle.fbx"
const WALK_SCENE := "res://Animated Characters 1/Animations/Walking.fbx"
const RUN_SCENE := "res://Animated Characters 1/Animations/Standard Run.fbx"
const JUMP_SCENE := "res://Animated Characters 1/Animations/Jumping.fbx"
const CROUCH_SCENE := "res://Animated Characters 1/Animations/Crouch To Stand.fbx"
const DASH_SCENE := "res://Animated Characters 1/Animations/Dashing Pose.fbx"
const PUNCH_SCENE := "res://Animated Characters 1/Animations/Punching.fbx"
const SLIDE_SCENE := "res://Animated Characters 1/Animations/Running Slide.fbx"
const RUN_STAIRS_SCENE := "res://Animated Characters 1/Animations/Running Up Stairs.fbx"
const WALK_STAIRS_SCENE := "res://Animated Characters 1/Animations/Ascending Stairs.fbx"
const MODEL_SCALE := 0.5
## The imported character faces +Z; member roots face -Z (Godot forward).
const MODEL_YAW := PI

var _visual: Node3D
var _skeleton: Skeleton3D
var _anim: AnimationPlayer
var _mat: StandardMaterial3D
var _base_tint := Color.WHITE
var _rest_rot: Dictionary = {}
var _state := ""
var _debug_state := ""
var _speed := 0.0
var _foot_bones: Array[int] = []

# Animation state that must survive a frame of locomotion input.
var _was_crouching := false
var _transition_t := 0.0
var _transition_next := ""
var _punch_t := 0.0
var _punch_index := 0
var _punch_queue: Array[int] = []
var _punch_history: Array[String] = []


func build(tint: Color, _shape: int = 0) -> void:
	_base_tint = _mono(tint)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base_tint
	_mat.roughness = 0.58
	_mat.metallic = 0.02
	_mat.rim_enabled = true
	_mat.rim = 0.45
	_mat.rim_tint = 0.65
	_mat.cull_mode = BaseMaterial3D.CULL_BACK

	var packed := load(MODEL_SCENE) as PackedScene
	if packed == null:
		push_error("AnimatedCharacter: missing %s" % MODEL_SCENE)
		return
	var scene := packed.instantiate()
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.rotation.y = MODEL_YAW
	_visual.scale = Vector3.ONE * MODEL_SCALE
	add_child(_visual)
	_visual.add_child(scene)

	_skeleton = scene.find_child("Skeleton3D", true, true) as Skeleton3D
	if _skeleton == null:
		push_error("AnimatedCharacter: rig missing")
		return
	_anim = scene.find_child("AnimationPlayer", true, true) as AnimationPlayer
	if _anim == null:
		_anim = AnimationPlayer.new()
		_anim.name = "AnimationPlayer"
		scene.add_child(_anim)
	_anim.root_node = NodePath("..")
	for i in _skeleton.get_bone_count():
		_rest_rot[_skeleton.get_bone_name(i)] = \
			_skeleton.get_bone_rest(i).basis.get_rotation_quaternion()
	for foot in ["LeftFoot", "RightFoot"]:
		var fi := _skeleton.find_bone(foot)
		if fi >= 0:
			_foot_bones.append(fi)

	var meshes: Array = []
	_collect_meshes(scene, meshes)
	for m in meshes:
		var mi := m as MeshInstance3D
		mi.material_override = _mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	_build_clips()
	_anim.play("idle")
	_state = "idle"


## The FBX clips carry a HipsCtrl root-control track that bakes root motion into
## the take. The character motor owns position, so that one root-control
## transform is removed; all other authored bone tracks remain and still play.
## This stops the body sliding forward/back and restores the skeleton's rest
## height instead of sinking the legs through the floor.
func _strip_root_motion(clip: Animation) -> void:
	for t in range(clip.get_track_count() - 1, -1, -1):
		if _bone_of(clip, t) == "HipsCtrl":
			clip.remove_track(t)


func _add_clip(clip_name: String, clip: Animation) -> void:
	var lib: AnimationLibrary
	if _anim.has_animation_library(""):
		lib = _anim.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		_anim.add_animation_library("", lib)
	lib.add_animation(clip_name, clip)


func _collect_meshes(n: Node, out: Array) -> void:
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)


func _build_clips() -> void:
	var idle := _extract_clip(IDLE_SCENE)
	idle.loop_mode = Animation.LOOP_LINEAR
	_add_clip("idle", idle)

	var walk := _extract_clip(WALK_SCENE)
	walk.loop_mode = Animation.LOOP_LINEAR
	_add_clip("walk", walk)

	var run := _extract_clip(RUN_SCENE)
	run.loop_mode = Animation.LOOP_LINEAR
	_add_clip("run", run)

	# Jumping is the authored takeoff/air/landing take, not the old short jump.
	var jump := _extract_clip(JUMP_SCENE)
	jump.loop_mode = Animation.LOOP_NONE
	_add_clip("jump", jump)

	# Crouch To Stand runs crouched -> standing. Reverse it for the down edge;
	# the first authored crouch pose is the hold pose between the two edges.
	var crouch_up := _extract_clip(CROUCH_SCENE)
	crouch_up.loop_mode = Animation.LOOP_NONE
	_retime(crouch_up, 0.16)
	_add_clip("crouch_up", crouch_up)
	var crouch_down := _reverse_clip(crouch_up)
	_add_clip("crouch_down", crouch_down)
	var crouch_hold := _slice_clip(crouch_up, 0.0, 0.03)
	crouch_hold.loop_mode = Animation.LOOP_LINEAR
	_add_clip("crouch", crouch_hold)

	var dash := _extract_clip(DASH_SCENE)
	dash.loop_mode = Animation.LOOP_NONE
	_add_clip("dash", dash)

	var slide := _extract_clip(SLIDE_SCENE)
	slide.loop_mode = Animation.LOOP_NONE
	_retime(slide, 0.52)
	_add_clip("slide", slide)

	var run_stairs := _extract_clip(RUN_STAIRS_SCENE)
	run_stairs.loop_mode = Animation.LOOP_LINEAR
	_add_clip("run_stairs", run_stairs)

	var walk_stairs := _extract_clip(WALK_STAIRS_SCENE)
	walk_stairs.loop_mode = Animation.LOOP_LINEAR
	_add_clip("walk_stairs", walk_stairs)

	# Punching is authored as a four-beat sequence. Keep each beat as its own
	# one-shot so clicks 1..4 map to the real jab/cross/jab/cross cadence.
	var punch := _extract_clip(PUNCH_SCENE)
	punch.loop_mode = Animation.LOOP_NONE
	var seg := punch.length / 4.0
	for i in 4:
		var beat := _slice_clip(punch, seg * i, seg * (i + 1))
		beat.loop_mode = Animation.LOOP_NONE
		_add_clip("punch%d" % (i + 1), beat)

	# Seating is still a furniture pose, not a locomotion state.
	var sit := idle.duplicate(true)
	sit.loop_mode = Animation.LOOP_LINEAR
	_add_rotation(sit, ["LeftUpLeg", "RightUpLeg"], deg_to_rad(-86.0))
	_add_rotation(sit, ["LeftLeg", "RightLeg"], deg_to_rad(86.0))
	_add_rotation(sit, ["LeftFoot", "RightFoot"], deg_to_rad(-2.0))
	_add_rotation(sit, ["Spine"], deg_to_rad(-4.0))
	_add_rotation(sit, ["Chest"], deg_to_rad(-2.0))
	_add_clip("sit", sit)


func _extract_clip(path: String) -> Animation:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("AnimatedCharacter: missing %s" % path)
		return Animation.new()
	var scene := packed.instantiate()
	var ap := scene.find_child("AnimationPlayer", true, true) as AnimationPlayer
	if ap == null or ap.get_animation_list().is_empty():
		push_error("AnimatedCharacter: no clips in %s" % path)
		scene.free()
		return Animation.new()
	var names := ap.get_animation_list()
	var clip := ap.get_animation(names[names.size() - 1]).duplicate(true)
	_strip_root_motion(clip)
	scene.free()
	return clip


func _retime(clip: Animation, factor: float) -> void:
	clip.length = maxf(clip.length * factor, 0.05)
	for t in clip.get_track_count():
		for k in clip.track_get_key_count(t):
			clip.track_set_key_time(t, k, clip.track_get_key_time(t, k) * factor)


## Crop a clip to [start, end] and rebase it to zero. Used for the four punches
## and for the held crouch pose. It preserves each track's authored values.
func _slice_clip(src: Animation, start: float, end: float) -> Animation:
	var out := src.duplicate(true)
	var dur := maxf(end - start, 0.02)
	for t in out.get_track_count():
		var count: int = int(out.track_get_key_count(t))
		var keys: Array = []
		var before: Variant = null
		for k in count:
			var kt: float = float(out.track_get_key_time(t, k))
			var kv: Variant = out.track_get_key_value(t, k)
			if kt <= start:
				before = kv
			if kt >= start - 0.0001 and kt <= end + 0.0001:
				keys.append({"t": kt - start, "v": kv})
		for k in range(count - 1, -1, -1):
			out.track_remove_key(t, k)
		if keys.is_empty() and before != null:
			keys.append({"t": 0.0, "v": before})
		elif not keys.is_empty() and float(keys[0]["t"]) > 0.001 and before != null:
			keys.push_front({"t": 0.0, "v": before})
		for key: Dictionary in keys:
			out.track_insert_key(t, float(key["t"]), key["v"])
	out.length = dur
	out.loop_mode = Animation.LOOP_NONE
	return out


## Reverse a one-shot clip. Crouch To Stand is authored up-only, so this gives
## the matching stand -> crouch edge without inventing a new pose.
func _reverse_clip(src: Animation) -> Animation:
	var out := src.duplicate(true)
	var length: float = float(out.length)
	for t in out.get_track_count():
		var count: int = int(out.track_get_key_count(t))
		var keys: Array = []
		for k in count:
			keys.append({
				"t": out.track_get_key_time(t, k),
				"v": out.track_get_key_value(t, k),
			})
		for k in range(count - 1, -1, -1):
			out.track_remove_key(t, k)
		for k in range(keys.size() - 1, -1, -1):
			var key: Dictionary = keys[k]
			out.track_insert_key(t, length - float(key["t"]), key["v"])
	out.loop_mode = Animation.LOOP_NONE
	return out


func _set_rotation(clip: Animation, bone: String, angle: float) -> void:
	_set_rotation_axis(clip, bone, Vector3.RIGHT, angle)


func _set_rotation_axis(clip: Animation, bone: String, axis: Vector3, angle: float) -> void:
	var rest: Quaternion = _rest_rot.get(bone, Quaternion.IDENTITY)
	var posed := rest * Quaternion(axis, angle)
	for t in clip.get_track_count():
		if clip.track_get_type(t) == Animation.TYPE_ROTATION_3D and _bone_of(clip, t) == bone:
			for k in clip.track_get_key_count(t):
				clip.track_set_key_value(t, k, posed)


func _add_rotation(clip: Animation, bones: Array, angle: float) -> void:
	_add_rotation_axis(clip, bones, Vector3.RIGHT, angle)


func _add_rotation_axis(clip: Animation, bones: Array, axis: Vector3, angle: float) -> void:
	for t in clip.get_track_count():
		if clip.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		if not bones.has(_bone_of(clip, t)):
			continue
		for k in clip.track_get_key_count(t):
			var q: Quaternion = clip.track_get_key_value(t, k)
			clip.track_set_key_value(t, k, (q * Quaternion(axis, angle)).normalized())


func _bone_of(clip: Animation, track: int) -> String:
	var path := str(clip.track_get_path(track))
	var cut := path.rfind(":")
	return path.substr(cut + 1) if cut >= 0 else ""


static func _mono(c: Color) -> Color:
	return c


func animate(dt: float, speed: float, grounded: bool,
		crouch: bool = false, slide: bool = false, dash: bool = false,
		seated: bool = false, on_stairs: bool = false) -> void:
	_speed = speed
	if _anim == null:
		return

	# Finish a punch beat and immediately start the next queued beat. A single
	# click plays one clip; four rapid clicks play all four authored punches.
	if _punch_t > 0.0:
		_punch_t -= dt
		if _punch_t <= 0.0:
			if not _punch_queue.is_empty():
				_start_punch(_punch_queue.pop_front())
			else:
				_punch_index = 0

	# Pressing crouch starts the authored down edge; releasing starts the up
	# edge. A running slide owns the first crouch frame instead.
	if crouch and not _was_crouching:
		_was_crouching = true
		if not slide and not dash:
			_start_transition("crouch_down", "crouch")
	elif not crouch and _was_crouching:
		_was_crouching = false
		_start_transition("crouch_up", "")

	var state := _debug_state
	if state == "":
		if _punch_t > 0.0:
			state = "punch%d" % _punch_index
		elif not grounded:
			state = "jump"
		elif _transition_t > 0.0:
			state = _state
		elif seated:
			state = "sit"
		elif slide:
			state = "slide"
		elif crouch:
			state = "crouch"
		elif dash:
			state = "dash"
		elif on_stairs and speed > Cfg.WALK + 0.8:
			state = "run_stairs"
		elif on_stairs and speed > 0.35:
			state = "walk_stairs"
		elif speed > Cfg.WALK + 1.4:
			state = "run"
		elif speed > 0.35:
			state = "walk"
		else:
			state = "idle"
	if state != _state:
		_anim.play(state, 0.15)
		_state = state

	var rate := 1.0
	match state:
		"walk":
			rate = clampf(speed / 3.2, 0.62, 1.12)
		"run":
			rate = clampf(speed / 5.6, 0.78, 1.26)
		"walk_stairs":
			rate = clampf(speed / 3.2, 0.62, 1.12)
		"run_stairs":
			rate = clampf(speed / 5.6, 0.78, 1.26)
	_anim.speed_scale = rate

	var drop := 0.0
	if state == "crouch" or state == "slide":
		# Plant the lowest ankle on the floor instead of guessing a body height.
		var lowest := INF
		for fi in _foot_bones:
			var wp := _skeleton.global_transform * _skeleton.get_bone_global_pose(fi).origin
			lowest = minf(lowest, to_local(wp).y)
		if lowest < INF:
			drop = _visual.position.y - lowest + 0.035
	elif state == "sit":
		drop = 0.22
	drop = clampf(drop, -0.85, 0.10)
	_visual.position.y = lerpf(_visual.position.y, drop, 1.0 - pow(0.001, dt))

	var lean := 0.0
	if dash:
		lean = -0.20
	elif slide:
		lean = 0.18
	elif crouch:
		lean = -0.06
	elif speed > Cfg.WALK:
		lean = -0.05 * clampf((speed - Cfg.WALK) / (Cfg.SPRINT - Cfg.WALK), 0.0, 1.0)
	_visual.rotation.x = lerp_angle(_visual.rotation.x, lean, 1.0 - pow(0.001, dt))

	if _transition_t > 0.0:
		_transition_t = maxf(0.0, _transition_t - dt)
		if _transition_t <= 0.0:
			_transition_next = ""


func _start_punch(index: int) -> void:
	_punch_index = clampi(index, 1, 4)
	_punch_t = _clip_length("punch%d" % _punch_index)
	_punch_history.append("punch%d" % _punch_index)
	_anim.play("punch%d" % _punch_index, 0.04)
	_state = "punch%d" % _punch_index


func _start_transition(clip: String, next: String) -> void:
	_transition_t = _clip_length(clip)
	_transition_next = next
	_anim.play(clip, 0.10)
	_state = clip


func _clip_length(clip: String) -> float:
	if _anim == null or not _anim.has_animation(clip):
		return 0.2
	return _anim.get_animation(clip).length


## One click = one punch; clicks during the active beat queue the next authored
## punch. More than four clicks in one combo are ignored.
func punch() -> void:
	if _anim == null:
		return
	if _punch_t > 0.0:
		return
	# One click plays the whole authored jab/cross/jab/cross sequence. The
	# queue is consumed beat-by-beat, so the animation cannot collapse to one
	# static punch when the next clip is selected.
	_punch_queue.clear()
	_punch_queue.append(2)
	_punch_queue.append(3)
	_punch_queue.append(4)
	_start_punch(1)


func is_punching() -> bool:
	return _punch_t > 0.0


func punch_index() -> int:
	return _punch_index


func punch_history() -> Array[String]:
	return _punch_history.duplicate()


func clear_punch_history() -> void:
	_punch_history.clear()


func current_state() -> String:
	return _state


## Root-relative probes used by the driven-input animation test. `mesh_world`
## is the visible mesh root; the hip/foot probes expose the actual skinned rig
## moving inside that root.
func mesh_world_position() -> Vector3:
	if _visual == null:
		return global_position
	return _visual.global_transform.origin


func hips_world_position() -> Vector3:
	if _skeleton == null:
		return global_position
	var i := _skeleton.find_bone("Hips")
	if i < 0:
		return global_position
	return _skeleton.global_transform * _skeleton.get_bone_global_pose(i).origin


func lowest_foot_world_y() -> float:
	if _skeleton == null or _foot_bones.is_empty():
		return NAN
	var lowest := INF
	for fi in _foot_bones:
		var world: Vector3 = _skeleton.global_transform * _skeleton.get_bone_global_pose(fi).origin
		lowest = minf(lowest, world.y)
	return lowest


## All skinned bone origins in world space. Comparing this snapshot between
## frames catches arm/torso motion that a feet-only probe would miss.
func pose_world_points() -> PackedVector3Array:
	var out := PackedVector3Array()
	if _skeleton == null:
		return out
	for i in _skeleton.get_bone_count():
		out.append(_skeleton.global_transform * _skeleton.get_bone_global_pose(i).origin)
	return out


func clip_horizontal_travel(clip: String) -> float:
	if _anim == null or not _anim.has_animation(clip):
		return 999.0
	var a := _anim.get_animation(clip)
	var worst := 0.0
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var n := a.track_get_key_count(t)
		if n < 2:
			continue
		var first: Vector3 = a.track_get_key_value(t, 0)
		var lo := Vector2(first.x, first.z)
		var hi := lo
		for k in n:
			var v: Vector3 = a.track_get_key_value(t, k)
			lo.x = minf(lo.x, v.x); lo.y = minf(lo.y, v.z)
			hi.x = maxf(hi.x, v.x); hi.y = maxf(hi.y, v.z)
		worst = maxf(worst, (hi - lo).length())
	return worst


func clip_position_travel(clip: String) -> float:
	if _anim == null or not _anim.has_animation(clip):
		return 999.0
	var a := _anim.get_animation(clip)
	var worst := 0.0
	for t in a.get_track_count():
		if a.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var n := a.track_get_key_count(t)
		if n < 2:
			continue
		var first: Vector3 = a.track_get_key_value(t, 0)
		var lo := first
		var hi := first
		for k in n:
			var v: Vector3 = a.track_get_key_value(t, k)
			lo.x = minf(lo.x, v.x); lo.y = minf(lo.y, v.y); lo.z = minf(lo.z, v.z)
			hi.x = maxf(hi.x, v.x); hi.y = maxf(hi.y, v.y); hi.z = maxf(hi.z, v.z)
		worst = maxf(worst, (hi - lo).length())
	return worst


func has_animation(clip: String) -> bool:
	return _anim != null and _anim.has_animation(clip)


func animation_length(clip: String) -> float:
	return _clip_length(clip)


func _process(_dt: float) -> void:
	if _debug_state == "crouch" or _debug_state == "slide":
		_plant_debug_feet()


func _plant_debug_feet() -> void:
	if _skeleton == null or _foot_bones.is_empty():
		return
	var lowest := INF
	for fi in _foot_bones:
		var wp := _skeleton.global_transform * _skeleton.get_bone_global_pose(fi).origin
		lowest = minf(lowest, to_local(wp).y)
	if lowest < INF:
		_visual.position.y = clampf(_visual.position.y - lowest + 0.035, -0.85, 0.10)


func force_state(state: String) -> void:
	_debug_state = state
	if _anim != null and _anim.has_animation(state):
		_anim.play(state, 0.0)
		_state = state
	var drop := 0.0
	match state:
		"crouch":
			drop = 0.30
		"slide":
			drop = 0.32
		"sit":
			drop = 0.22
	_visual.position.y = drop


func set_tint(c: Color) -> void:
	_base_tint = _mono(c)
	if _mat != null:
		_mat.albedo_color = _base_tint


func set_role(it: bool) -> void:
	# The body stays the member's chosen monochrome; IT glows instead of recolor.
	if _mat == null:
		return
	_mat.emission_enabled = it
	_mat.emission = Cfg.CORAL
	_mat.emission_energy_multiplier = 0.85


func land(_impact: float) -> void:
	pass


func jump() -> void:
	pass
