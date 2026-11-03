extends SceneTree
## WsgFootPlanter on a skeleton of the game's own (its own body at Low): the rig's leg bones found through bone_map,
## a standing body's feet read as down, and kept where they stand when the body is moved 3 cm under them.
##   godot --headless --fixed-fps 30 --path . -s tests/planter_bone_map_test.gd

var fails := []


func _initialize() -> void:
	await process_frame
	var hero := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
	root.add_child(hero)
	await process_frame
	# A skeleton of its own: the hero's bones, every name changed (as a game's own rig names them).
	var src := hero.skeleton
	var own := Skeleton3D.new()
	var map := {}
	for i in src.get_bone_count():
		var nm := src.get_bone_name(i)
		own.add_bone("own_" + nm.to_lower())
		map[nm] = "own_" + nm.to_lower()
	for i in src.get_bone_count():
		own.set_bone_parent(i, src.get_bone_parent(i))
		own.set_bone_rest(i, src.get_bone_rest(i))
		own.set_bone_pose_position(i, src.get_bone_rest(i).origin)
		own.set_bone_pose_rotation(i, src.get_bone_rest(i).basis.get_rotation_quaternion())
	var holder := Node3D.new()
	root.add_child(holder)
	holder.add_child(own)
	hero.queue_free()
	var pl := WsgFootPlanter.new()
	pl.bone_map = {"Hips": map["Hips"], "LeftUpLeg": map["LeftUpLeg"], "LeftLeg": map["LeftLeg"], "LeftFoot": map["LeftFoot"],
		"LeftToeBase": map["LeftToeBase"], "RightUpLeg": map["RightUpLeg"], "RightLeg": map["RightLeg"],
		"RightFoot": map["RightFoot"], "RightToeBase": map["RightToeBase"]}
	own.add_child(pl)
	var ankle := own.find_bone(map["LeftFoot"])
	pl.ground_y = 0.0     # (the rest pose stands on y 0: its ankles at their rest height over the floor)
	var drawn := []
	# (Read as drawn - in skeleton_updated, after the planter; outside it the bones are back to the pose it was given.)
	own.skeleton_updated.connect(func(): drawn.append(own.global_transform * own.get_bone_global_pose(ankle).origin))
	for f in 12:
		if f == 6:
			holder.position.x += 0.03
		pl.tick(1.0 / 30.0)
		await process_frame
	var found := pl._ix.all(func(leg: Array) -> bool: return leg.all(func(b) -> bool: return int(b) >= 0))
	var moved := Vector2((drawn[-1] as Vector3).x - (drawn[4] as Vector3).x, (drawn[-1] as Vector3).z - (drawn[4] as Vector3).z).length()
	print("bones found through the map: %s; contact %s; the left ankle moved %.1f cm when the body moved 3 cm" % [found, pl.contact, moved * 100.0])
	if not found:
		fails.append("a leg bone not found through bone_map")
	if float(pl.contact[0]) < 0.5 or float(pl.contact[1]) < 0.5:
		fails.append("a standing foot on the game's own skeleton not read as down (%s)" % [pl.contact])
	if moved > 0.01:
		fails.append("a planted foot on the game's own skeleton moved %.1f cm with the body" % (moved * 100.0))
	print("PLANTER BONE MAP TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)
