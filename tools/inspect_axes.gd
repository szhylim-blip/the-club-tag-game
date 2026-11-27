extends SceneTree

func _initialize() -> void:
	var packed := load("res://Animated Characters 1/Model/characterMedium.fbx") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	var sk := scene.find_child("Skeleton3D", true, true) as Skeleton3D
	for bone in ["Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg",
			"RightFoot", "LeftArm", "LeftForeArm", "LeftHand", "LeftHandIndex1",
			"LeftHandIndex2", "LeftHandThumb1", "RightArm", "RightForeArm", "RightHand",
			"RightHandIndex1"]:
		var i := sk.find_bone(bone)
		if i < 0:
			continue
		var g := sk.get_bone_global_rest(i)
		print(bone, " origin=", g.origin)
		print("  X=", g.basis.x, " Y=", g.basis.y, " Z=", g.basis.z)
	quit()
