extends SceneTree
## The replay (WsgReplay): a body moving (its arm swung by a pose layer, the body walking along) kept for two seconds,
## then shown again: every bone at each moment as it was drawn then (within the 16-bit keep: under half a degree),
## the body where it stood, everything back as it was after; the ring as big as the profile says.
##   godot --headless --path . --fixed-fps 30 -s tests/replay_test.gd

func _initialize() -> void:
	var fails := []
	var ch := WsgBody.load_character("res://tests/character", "hero")
	var body := WsgBody.new(ch)
	root.add_child(body)
	var layer := WsgPoseLayer.new()
	body.skeleton.add_child(layer)
	body.skeleton.move_child(layer, 0)
	layer.weight = 1.0
	var rp := WsgReplay.new()
	root.add_child(rp)
	# The truth: the final global pose of a few bones at each moment, read as the body is drawn.
	var truth := {}
	var now := 0.0
	var watch := ["RightHand", "RightForeArm", "LeftHand", "Head", "Hips"]
	body.posed.connect(func():
		var g := {}
		for b in watch:
			g[b] = body.global_transform * body.skeleton.get_bone_global_pose(body.skeleton.find_bone(b))
		truth[snappedf(now, 0.0001)] = g)
	for f in 60:
		now = f / 30.0
		var a := sin(now * 5.0) * 1.2
		layer.set_pose({"RightArm": Quaternion(Vector3.FORWARD, 0.3 + a), "RightForeArm": Quaternion(Vector3.UP, 0.8 + a * 0.5),
			"LeftArm": Quaternion(Vector3.BACK, 1.0 - a * 0.6)})
		body.position = Vector3(now * 1.5, 0, 0)
		rp.record(now)
		await process_frame
	var keys := truth.keys()
	keys.sort()
	var live := body.transform
	print("kept %d frames, %.0f KB (%.0f s at %d a second)" % [rp._frames.size(), rp.memory() / 1024.0, rp.seconds, rp.rate])
	# Shown again: at each kept moment, the bones as they were drawn then.
	rp.play(0.5, 1.8)
	var worst_deg := 0.0
	var worst_mm := 0.0
	var n := 0
	for f in rp._frames:
		var t: float = f[0]
		if t < 0.5 or t > 1.8:
			continue
		# (The pose kept at a moment is the one drawn the frame before it was recorded.)
		var want_t := -1.0
		for k in keys:
			if k <= t + 0.0001:
				want_t = k
		if want_t < 0.0 or not truth.has(want_t):
			continue
		rp.seek(t)
		await process_frame
		await body.skeleton.skeleton_updated
		for b in watch:
			var got: Transform3D = body.global_transform * body.skeleton.get_bone_global_pose(body.skeleton.find_bone(b))
			var want: Transform3D = truth[want_t][b]
			worst_deg = maxf(worst_deg, rad_to_deg(got.basis.get_rotation_quaternion().angle_to(want.basis.get_rotation_quaternion())))
			worst_mm = maxf(worst_mm, got.origin.distance_to(want.origin) * 1000.0)
		n += 1
	print("replayed %d moments: bones within %.2f degrees and %.1f mm of what was drawn" % [n, worst_deg, worst_mm])
	if n < 10 or worst_deg > 0.5 or worst_mm > 5.0:
		fails.append("replay: %d moments, %.2f deg, %.1f mm" % [n, worst_deg, worst_mm])
	rp.stop()
	await process_frame
	if not body.transform.is_equal_approx(live):
		fails.append("after the replay the body is not back where it was")
	# A body freed while the ring still holds it (a substitute, a match rebuilt): the replay goes on without it.
	var gone := WsgBody.new(ch)
	root.add_child(gone)
	for f in 6:
		now += 1.0 / 30.0
		rp.record(now)
		await process_frame
	gone.free()
	rp.play(now - 0.15, now)
	rp.seek(now - 0.1)
	await process_frame
	rp.stop()
	rp.record(now + 0.1)
	print("a body freed while kept: played, sought, stopped, recorded on (no errors above)")
	# A body whose modifiers run when told (WsgBody.set_manual: a far player posed every few frames): drawn only when
	# advanced, and the replay advances it itself - each moment sought shows that moment's pose, and live again after.
	var lazy := WsgBody.new(ch)
	root.add_child(lazy)
	lazy.set_manual(true)
	var lz := WsgPoseLayer.new()
	lazy.skeleton.add_child(lz)
	lazy.skeleton.move_child(lz, 0)
	lz.weight = 1.0
	var drawn := [0, Quaternion.IDENTITY]
	lazy.posed.connect(func():
		drawn[0] += 1
		drawn[1] = lazy.skeleton.get_bone_global_pose(lazy.skeleton.find_bone("RightForeArm")).basis.get_rotation_quaternion())
	var ring := WsgReplay.new()
	root.add_child(ring)
	var lazy_t := 0.0
	for f in 30:
		lazy_t = f / 30.0
		lz.set_pose({"RightArm": Quaternion(Vector3.FORWARD, lazy_t * 2.0)})
		ring.record(lazy_t)
		if f % 3 == 0:
			lazy.advance(1.0 / 10.0)
		await process_frame
	var advanced: int = drawn[0]
	var turns := []
	ring.play(0.2, 0.9)
	for t in [0.3, 0.6, 0.9]:
		var before: int = drawn[0]
		ring.seek(t)
		await process_frame     # (the skeleton updates at the end of the frame)
		turns.append(drawn[1])
		if drawn[0] == before:
			fails.append("a manual body is not drawn when the replay seeks")
			break
	ring.stop()
	if turns.size() < 3:
		turns = [Quaternion.IDENTITY, Quaternion.IDENTITY, Quaternion.IDENTITY]
	print("a manual body: drawn %d times in 30 frames (advanced every third); the replay drew it at each moment sought, %.0f and %.0f degrees apart" % [
		advanced, rad_to_deg((turns[0] as Quaternion).angle_to(turns[1])), rad_to_deg((turns[1] as Quaternion).angle_to(turns[2]))])
	if advanced > 11 or (turns[0] as Quaternion).angle_to(turns[1]) < 0.05:
		fails.append("manual body: drawn %d times; replay moments the same" % advanced)
	# The ring's size: a budget phone's Low (4 s at 15) for 38 bodies.
	var per_body: int = (rp._frames[-1][1] as Dictionary).values()[0].size() * 4
	WsgFoundation.profile = "budget"
	WsgFoundation.tier = WsgFoundation.LOW
	var spec := WsgFoundation.replay_spec()
	var budget_mb: float = per_body * 38 * spec[0] * spec[1] / 1048576.0
	WsgFoundation.profile = "premium"
	WsgFoundation.tier = WsgFoundation.HIGH
	spec = WsgFoundation.replay_spec()
	var premium_mb: float = per_body * 38 * spec[0] * spec[1] / 1048576.0
	print("a body's frame %d bytes: 38 bodies kept %.1f MB on a budget phone's Low, %.1f MB on a premium High" % [per_body, budget_mb, premium_mb])
	if budget_mb > 1.5 or premium_mb > 6.0:
		fails.append("the ring is too big: %.1f / %.1f MB" % [budget_mb, premium_mb])
	for f in fails:
		printerr("FAIL: ", f)
	print("REPLAY TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
