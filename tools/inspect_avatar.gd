extends SceneTree

func _initialize() -> void:
	var a := AnimatedCharacter.new()
	root.add_child(a)
	a.build(Color.WHITE, 0)
	a.print_tree_pretty()
	var scene := a.get_node("Visual").get_child(0)
	print("SCENE ", scene.name, " class=", scene.get_class(), " children=", scene.get_child_count())
	_dump(scene, 0)
	print("AVATAR transform=", a.transform, " visible=", a.visible)
	quit()


func _dump(n: Node, depth: int) -> void:
	print("  ".repeat(depth), n.name, " [", n.get_class(), "]")
	for c in n.get_children():
		_dump(c, depth + 1)
