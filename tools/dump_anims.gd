extends SceneTree

const DIR := "res://Animated Characters 1/Animations/"
const FILES := [
	"idle.fbx", "Walking.fbx", "Standard Run.fbx", "run.fbx",
	"Jumping.fbx", "jump.fbx", "Crouch To Stand.fbx", "Change Direction.fbx",
	"Dashing Pose.fbx", "Punching.fbx", "Running Slide.fbx",
	"Running Turn 180.fbx", "Running Up Stairs.fbx", "Ascending Stairs.fbx",
]


func _initialize() -> void:
	for file in FILES:
		var packed := load(DIR + file) as PackedScene
		if packed == null:
			print("MISSING ", file)
			continue
		var scene := packed.instantiate()
		var ap := scene.find_child("AnimationPlayer", true, true) as AnimationPlayer
		if ap == null:
			print("NO_ANIM ", file)
			scene.free()
			continue
		var names := ap.get_animation_list()
		print("FILE %s clips=%d" % [file, names.size()])
		for n in names:
			var a: Animation = ap.get_animation(n)
			var t0 := 0.0
			var keys := 0
			for t in a.get_track_count():
				keys += a.track_get_key_count(t)
				if a.track_get_key_count(t) > 0:
					t0 = minf(t0, a.track_get_key_time(t, 0))
			print("  CLIP %s len=%.3f tracks=%d keys=%d first=%.3f loop=%d" % [n, a.length, a.get_track_count(), keys, t0, a.loop_mode])
		scene.free()
	quit()
