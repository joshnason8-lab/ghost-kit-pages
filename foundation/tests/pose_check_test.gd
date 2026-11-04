extends SceneTree
## WsgNoteChecks.t_or_a_pose: a body left in its rest pose (arms out to the sides, straight) is a T-pose; arms held
## out to the sides at 45 degrees an A-pose; arms raised overhead (a catch at the top of a leap, a defended shot) or
## reaching forward (a catch, a mark) are moves, not a rest pose (Netball's false flags at 61-146 degrees).
##   godot --headless --path . -s tests/pose_check_test.gd

var fails := []


func _initialize() -> void:
	await process_frame
	var body := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
	root.add_child(body)
	body.set_manual(true)
	await process_frame
	var sk := body.skeleton
	var cases := [["rest (T)", 0.0, 0.0, "T-pose"], ["arms 45 down, to the sides (A)", 45.0, 0.0, "A-pose"],
		["arms overhead", -60.0, 0.0, ""], ["arms forward", 0.0, 90.0, ""], ["arms hanging", 85.0, 0.0, ""]]
	for c in cases:
		body.reset_pose()
		# Each upper arm turned about the body's forward axis (down from level) and then about up (forward).
		for side in ["Left", "Right"]:
			var b := sk.find_bone(side + "Arm")
			var g := sk.get_bone_global_pose(b)
			var sgn := 1.0 if side == "Left" else -1.0
			var rot := Basis(Vector3.UP, deg_to_rad(float(c[2])) * -sgn) * Basis(Vector3(0, 0, 1), deg_to_rad(float(c[1])) * -sgn)
			g.basis = rot * g.basis
			sk.set_bone_global_pose(b, g)
		sk.force_update_all_bone_transforms()
		var got := WsgNoteChecks.t_or_a_pose(body)
		var a := WsgNoteChecks.arms(body)
		var ok := got.begins_with(c[3]) if c[3] != "" else got == ""
		print("%-32s arms out %3.0f/%3.0f: %s %s" % [c[0], a.Left[0], a.Right[0], got if got != "" else "a person", "ok" if ok else "WRONG"])
		if not ok:
			fails.append("%s: '%s'" % [c[0], got])
	print("POSE CHECK TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)
