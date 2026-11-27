extends SceneTree

func _initialize() -> void:
	var a := AnimatedCharacter.new()
	root.add_child(a)
	a.build(Color.WHITE, 0)
	var scene := a.get_node("Visual").get_child(0)
	var sk := scene.find_child("Skeleton3D", true, true) as Skeleton3D
	var mi: MeshInstance3D = null
	for n in scene.find_children("*", "", true, true):
		if n is MeshInstance3D:
			mi = n
			break
	var hips := sk.find_bone("Hips")
	var head := sk.find_bone("Head")
	var lfoot := sk.find_bone("LeftFoot")
	print("MESH=", mi, " aabb=", mi.get_aabb() if mi else "nil")
	for state in ["idle", "walk", "dash", "crouch", "slide", "sit"]:
		a.force_state(state)
		a._anim.advance(0.02)
		sk.force_update_all_bone_transforms()
		var gp := sk.global_transform
		print(state, " hips=", gp * sk.get_bone_global_pose(hips).origin,
			" head=", gp * sk.get_bone_global_pose(head).origin,
			" lfoot=", gp * sk.get_bone_global_pose(lfoot).origin,
			" sk_scale=", sk.global_transform.basis.get_scale())
	quit()
