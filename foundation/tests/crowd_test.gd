extends SceneTree
## The 3D crowd keeps to its budget, takes the spots nearest the action, and its authored motions keep the feet on
## the ground and the hands together when clapping.
##   godot --headless --path . -s tests/crowd_test.gd

func _initialize() -> void:
	var fails := []
	if not WsgCrowd3D.available():
		print("CROWD TEST: SKIPPED (no crowd data)")
		quit(0)
		return
	var spots := []
	var facings := []
	for i in 6000:
		spots.append(Vector3(randf_range(-80, 80), randf_range(0, 12), randf_range(40, 60)))
		facings.append(Vector3(0, 0, -1))
	for q in [1, 2]:
		var crowd := WsgCrowd3D.new()
		root.add_child(crowd)
		var used := crowd.build(spots, facings, 1.0, 3, true, q, Vector3.ZERO)
		var budget: Array = WsgCrowd3D.BUDGET[q]
		var tris := 0
		var fans := 0
		for m in crowd.meshes:
			fans += m.multimesh.instance_count
			tris += m.multimesh.instance_count * m.multimesh.mesh.get_faces().size() / 3
		var far_d := 0.0
		for i in used:
			far_d = maxf(far_d, (spots[i] as Vector3).length())
		var nearer := 0
		for i in spots.size():
			if (spots[i] as Vector3).length() < far_d * 0.98 and not used.has(i):
				nearer += 1
		print("quality %d: %d fans in %d draw calls, %d triangles; %d spots nearer the action left out" % [q, fans, crowd.meshes.size(), tris, nearer])
		if fans > budget[1] or used.size() != fans:
			fails.append("quality %d draws %d fans (budget %d)" % [q, fans, budget[1]])
		if nearer > spots.size() * 0.02:
			fails.append("quality %d leaves %d nearer spots for billboards" % [q, nearer])
		crowd.free()
	# The motions: feet on the ground (seated and standing), hands meeting in a clap (forward kinematics on the rest).
	var j := WsgRig.default_joints()
	for c in ["sit_idle", "stand_idle", "sit_clap", "cheer"]:
		var pose := WsgCrowdClips.pose(c, 0.0)
		var g := {}
		var p := {}
		for b in WsgRig.BONES:
			var nm: String = b[0]
			var q: Quaternion = pose.get(nm, Quaternion.IDENTITY)
			if b[1] == "":
				g[nm] = q
				p[nm] = (j[nm] as Vector3) + (pose.get("@hips", Vector3.ZERO) as Vector3)
			else:
				g[nm] = (g[b[1]] as Quaternion) * q
				p[nm] = (p[b[1]] as Vector3) + (g[b[1]] as Quaternion) * ((j[nm] as Vector3) - (j[b[1]] as Vector3))
		var low := minf(p.LeftFoot.y - (j.LeftFoot as Vector3).y, p.LeftToeBase.y - (j.LeftToeBase as Vector3).y)
		var apart: float = (p.LeftHandMiddle1 as Vector3).distance_to(p.RightHandMiddle1)
		print("%-10s feet %+.3f m off the ground; hands %.2f m apart" % [c, low, apart])
		if absf(low) > 0.04:
			fails.append("%s: the feet are %.2f m off the ground" % [c, low])
		if c == "sit_clap" and apart > 0.12:
			fails.append("sit_clap: the hands do not meet (%.2f m apart)" % apart)
	for f in fails:
		printerr("FAIL: ", f)
	print("CROWD TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
