extends SceneTree
## Prints a GLB's skeleton (rest pose, model space), mesh size and animations. godot --headless --script ... -- file.glb
func _init() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(path, st)
	print("load ", err)
	var root := doc.generate_scene(st)
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	for i in sk.get_bone_count():
		var g := sk.get_bone_global_rest(i)
		print("%2d %-26s parent %2d  pos %s  y-axis %s" % [i, sk.get_bone_name(i), sk.get_bone_parent(i), g.origin.snapped(Vector3.ONE * 0.001), g.basis.y.snapped(Vector3.ONE * 0.01)])
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		print("mesh ", mi.name, " aabb ", (mi as MeshInstance3D).get_aabb(), " xf ", mi.transform, " skel_xf ", sk.global_transform if sk.is_inside_tree() else sk.transform)
	print("skeleton node xf ", sk.transform, " parent ", sk.get_parent().name, " ", sk.get_parent().transform if sk.get_parent() is Node3D else "")
	for ap in root.find_children("*", "AnimationPlayer", true, false):
		for n in (ap as AnimationPlayer).get_animation_list():
			var a := (ap as AnimationPlayer).get_animation(n)
			print("anim ", n, " len ", a.length, " tracks ", a.get_track_count())
			for t in mini(a.get_track_count(), 4):
				print("   ", a.track_get_path(t), " type ", a.track_get_type(t), " keys ", a.track_get_key_count(t))
			var hp := -1
			for t in a.get_track_count():
				if String(a.track_get_path(t)).ends_with("Hips") and a.track_get_type(t) == Animation.TYPE_POSITION_3D:
					hp = t
			if hp >= 0:
				print("   hips pos first ", a.track_get_key_value(hp, 0), " last ", a.track_get_key_value(hp, a.track_get_key_count(hp) - 1))
	quit()
