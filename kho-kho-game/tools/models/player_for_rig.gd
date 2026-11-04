extends SceneTree
## The owner's athlete (assets/models/player.glb) as one rigged mesh for the shared foundation's bake
## (tools/wsg/bake_character.sh): its full mesh (player_lod0, the 3,600 triangles Medium and High draw) on its Mixamo
## skeleton, the light mesh and the GLB's own clips left out (no animation goes into the bake). Writes a scratch scene:
##   godot --headless --path . -s tools/models/player_for_rig.gd -- <out.scn>
## (tools/models/bake_foundation.sh runs it and the bake.)

func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var s: Node = load("res://assets/models/player.glb").instantiate()
	for n in s.find_children("*", "", true, false):
		if n is AnimationPlayer or n is MeshInstance3D and n.name != "player_lod0":
			n.get_parent().remove_child(n)
			n.free()
	for n in s.find_children("*", "", true, false):
		n.owner = s
		if n is MeshInstance3D:
			# (Its material stays the game's: the bake needs the mesh only, and a scratch project has no textures.)
			var m: ArrayMesh = (n as MeshInstance3D).mesh.duplicate()
			for i in m.get_surface_count():
				m.surface_set_material(i, null)
			(n as MeshInstance3D).mesh = m
	var ps := PackedScene.new()
	ps.pack(s)
	var err := ResourceSaver.save(ps, out)
	print("player_for_rig: ", out, " ", error_string(err))
	s.free()
	quit(0 if err == OK else 1)
