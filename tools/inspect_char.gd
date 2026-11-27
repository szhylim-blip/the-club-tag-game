extends SceneTree

func _initialize() -> void:
	var base = load("res://Animated Characters 1/Animations/idle.fbx").instantiate()
	root.add_child(base)
	await process_frame
	var meshes: Array = base.find_children("*", "MeshInstance3D", true, false)
	print("MESHES ", meshes.size())
	for m in meshes:
		var mi := m as MeshInstance3D
		print("MESH ", mi.name, " path=", base.get_path_to(mi), " aabb=", mi.get_aabb(),
			" global_aabb=", mi.global_transform * mi.get_aabb())
		print("  surfaces=", mi.mesh.get_surface_count() if mi.mesh else 0,
			" material_override=", mi.material_override)
	var sk: Skeleton3D = base.find_child("Skeleton3D", true, false)
	for name in ["Hips", "Head", "LeftFoot", "RightFoot", "LeftHand", "RightHand"]:
		var i := sk.find_bone(name)
		print("BONE_GLOBAL ", name, " ", sk.global_transform * sk.get_bone_global_pose(i).origin)
	quit()
