extends SceneTree
## Officials: he faces the play while he moves along the line; his signals are sound - a raised arm straight up from
## the side with the collarbone lifted, a pointing arm on its target, elbows straight when they should be.
##   godot --headless --path . --fixed-fps 30 -s tests/officials_test.gd [-- <char dir> <prefix>]

func _initialize() -> void:
	create_timer(300.0).timeout.connect(func():
		printerr("OFFICIALS TEST: timed out")
		quit(2))
	var a := OS.get_cmdline_user_args()
	var fails := []
	var ch := WsgBody.load_character(a[0] if a.size() > 0 else "res://tests/character", a[1] if a.size() > 1 else "hero")
	var ref := WsgOfficial.new(ch)
	root.add_child(ref)
	await process_frame
	var dt := 1.0 / 30.0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var worst := 0.0
	# Along the touchline (+Z), the play out on the pitch to his left (+X), moving up and down.
	for f in 240:
		var t := f * dt
		var want := Vector3(0, 0, 3.0 if t < 4.0 else -2.5)
		vel = vel.move_toward(want, 6.0 * dt)
		pos += vel * dt
		ref.position = pos
		var play := Vector3(20.0, 0, pos.z + sin(t) * 10.0)
		ref.follow(dt, vel, play)
		await process_frame
		if t > 1.5 and (t < 3.8 or t > 4.8):
			var to := play - pos
			var err := absf(rad_to_deg(wrapf(atan2(to.x, to.z) - ref.loco.yaw, -PI, PI)))
			worst = maxf(worst, err)
	print("facing the play while moving: worst %.0f degrees off" % worst)
	if worst > 35.0:
		fails.append("does not face the play (%.0f degrees off)" % worst)
	# Signals, standing.
	for g in [["score", Vector3.INF], ["both_arms_up", Vector3.INF], ["point", Vector3(-15, 1.0, 5)]]:
		var toward: Vector3 = g[1] if g[1] == Vector3.INF else pos + g[1]
		ref.signal_gesture(g[0], toward)
		for f in 20:
			ref.follow(dt, Vector3.ZERO, pos + Vector3(10, 0, 0))
			await process_frame
		await ref.body.skeleton.skeleton_updated
		var sk := ref.body.skeleton
		var gp := func(n): return ref.body.global_transform * sk.get_bone_global_pose(sk.find_bone(n)).origin
		for side in (["Right"] if g[0] == "score" else (["Left", "Right"] if g[0] == "both_arms_up" else [])):
			var sh: Vector3 = gp.call(side + "Arm")
			var el: Vector3 = gp.call(side + "ForeArm")
			var wr: Vector3 = gp.call(side + "Hand")
			var up := rad_to_deg((wr - sh).angle_to(Vector3.UP))
			var bend := rad_to_deg((el - sh).angle_to(wr - el))
			var lift: float = rad_to_deg(sk.get_bone_pose_rotation(sk.find_bone(side + "Shoulder")).get_angle())
			print("%-13s %-5s arm %.0f degrees off vertical, elbow bent %.0f, collarbone lifted %.0f" % [g[0], side, up, bend, lift])
			if up > 15.0 or bend > 12.0 or lift < 10.0:
				fails.append("%s %s: arm %.0f off vertical, elbow %.0f, collarbone %.0f" % [g[0], side, up, bend, lift])
		if g[0] == "point":
			var side := "Left" if (ref.body.global_transform.affine_inverse() * toward).x > 0 else "Right"
			var sh: Vector3 = gp.call(side + "Arm")
			var wr: Vector3 = gp.call(side + "Hand")
			var flat := Vector3(toward.x - sh.x, 0, toward.z - sh.z)
			var aim := Vector3(wr.x - sh.x, 0, wr.z - sh.z)
			var off := rad_to_deg(aim.angle_to(flat))
			print("point         %-5s %.0f degrees off its target" % [side, off])
			if off > 15.0:
				fails.append("point: %.0f degrees off its target" % off)
		await process_frame
		for f in 50:
			ref.follow(dt, Vector3.ZERO, pos + Vector3(10, 0, 0))
			await process_frame
	for f in fails:
		printerr("FAIL: ", f)
	print("OFFICIALS TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
