extends SceneTree
## WsgFootPlanter on a skeleton of the game's own (its own body at Low): the rig's leg bones found through bone_map
## (or bone_prefix), a standing body's feet read as down, and kept where they stand when the body is moved 3 cm under
## them; a game's own contact rule (contact_fn) is the one used.
##   godot --headless --fixed-fps 30 --path . -s tests/planter_bone_map_test.gd

var fails := []


func _initialize() -> void:
	await process_frame
	var hero := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
	root.add_child(hero)
	await process_frame
	var src := hero.skeleton
	# 1. Every name changed (as a game's own rig names them), found through bone_map.
	var map := {}
	for i in src.get_bone_count():
		map[src.get_bone_name(i)] = "own_" + src.get_bone_name(i).to_lower()
	var pl := WsgFootPlanter.new()
	for nm in ["Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]:
		pl.bone_map[nm] = map[nm]
	var r: Array = await _stand(src, func(nm: String) -> String: return map[nm], pl, map["LeftFoot"])
	print("bone_map: bones found %s; contact %s; the left ankle moved %.1f cm when the body moved 3 cm" % [r[0], r[1], r[2] * 100.0])
	_check("bone_map", r, [1.0, 1.0])
	# 2. Every name with a prefix (a Mixamo rig: "mixamorig_LeftUpLeg"), found through bone_prefix.
	pl = WsgFootPlanter.new()
	pl.bone_prefix = "mixamorig_"
	r = await _stand(src, func(nm: String) -> String: return "mixamorig_" + nm, pl, "mixamorig_LeftFoot")
	print("bone_prefix: bones found %s; contact %s; the left ankle moved %.1f cm when the body moved 3 cm" % [r[0], r[1], r[2] * 100.0])
	_check("bone_prefix", r, [1.0, 1.0])
	# 3. The game's own contact rule: its left foot never down, its right as the planter would have it.
	pl = WsgFootPlanter.new()
	var calls := [0]
	pl.contact_fn = func(i: int, _ank: Vector3, _toe: Vector3, _was: bool) -> bool:
		calls[0] += 1
		return i == 1
	r = await _stand(src, func(nm: String) -> String: return nm, pl, "LeftFoot")
	print("contact_fn: called %d times; contact %s" % [calls[0], r[1]])
	if calls[0] == 0:
		fails.append("contact_fn was never called")
	if float(r[1][0]) > 0.5 or float(r[1][1]) < 0.5:
		fails.append("contact_fn's rule not the one used (contact %s, wanted [0, 1])" % [r[1]])
	hero.queue_free()
	print("PLANTER BONE MAP TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)


## A copy of SRC's skeleton, each bone named NAME_OF(its rig name), standing at rest with PL under it: moved 3 cm after
## 6 frames. [every leg bone found, contact, how far the left ankle (ANKLE) moved as drawn].
func _stand(src: Skeleton3D, name_of: Callable, pl: WsgFootPlanter, ankle_name: String) -> Array:
	var own := Skeleton3D.new()
	for i in src.get_bone_count():
		own.add_bone(String(name_of.call(src.get_bone_name(i))))
	for i in src.get_bone_count():
		own.set_bone_parent(i, src.get_bone_parent(i))
		own.set_bone_rest(i, src.get_bone_rest(i))
		own.set_bone_pose_position(i, src.get_bone_rest(i).origin)
		own.set_bone_pose_rotation(i, src.get_bone_rest(i).basis.get_rotation_quaternion())
	var holder := Node3D.new()
	root.add_child(holder)
	holder.add_child(own)
	own.add_child(pl)
	var ankle := own.find_bone(ankle_name)
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
	var out := [found, pl.contact.duplicate(), moved]
	holder.queue_free()
	return out


func _check(what: String, r: Array, _want: Array) -> void:
	if not bool(r[0]):
		fails.append("%s: a leg bone not found" % what)
	if float(r[1][0]) < 0.5 or float(r[1][1]) < 0.5:
		fails.append("%s: a standing foot on the game's own skeleton not read as down (%s)" % [what, r[1]])
	if float(r[2]) > 0.01:
		fails.append("%s: a planted foot on the game's own skeleton moved %.1f cm with the body" % [what, float(r[2]) * 100.0])
