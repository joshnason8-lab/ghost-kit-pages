extends SceneTree
## The 3D crowd keeps to its budget, takes the spots nearest the action, and its authored motions keep the feet on
## the ground and the hands together when clapping. Seated fans sit on their seats: every seated frame of every fan,
## skinned as the crowd draws it, on a seat level with the step behind, one in front of a taller step, and a tall step
## sat on - the seat of the trousers and the thighs never below the seat, nothing inside the step behind (and the
## placement before this check, run the same way, must fail it).
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
	for q in [1, 2, 3]:
		var crowd := WsgCrowd3D.new()
		root.add_child(crowd)
		var used := crowd.build(spots, facings, 1.0, 3, true, q, Vector3.ZERO)
		var budget: Array = WsgFoundation.crowd_budget(q)
		var tris := 0
		var fans := 0
		for m in crowd.meshes:
			fans += m.multimesh.instance_count
			tris += m.multimesh.instance_count * m.multimesh.mesh.get_faces().size() / 3
		var far_d := 0.0
		for i in used:
			far_d = maxf(far_d, WsgCrowd3D.nearness(spots[i], Vector3.ZERO))
		var nearer := 0
		for i in spots.size():
			if WsgCrowd3D.nearness(spots[i], Vector3.ZERO) < far_d * 0.98 and not used.has(i):
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
	fails.append_array(_looks(spots, facings))
	# Shirts: white, off-white, pale blue and plain colours come back near what was asked (the old hash could not make
	# white or pale ones: white came out mint), and the codes stay clear of the old ones (< 1).
	for want in [Color(0.95, 0.94, 0.9), Color(1, 1, 1), Color(0.7, 0.8, 0.95), Color(0.8, 0.1, 0.1), Color(0.1, 0.3, 0.8), Color(0.95, 0.75, 0.1)]:
		var code := WsgCrowd3D.shirt_palette_code(want)
		var got := WsgCrowd3D.shirt_palette(int((code - 1.0) * 256.0))
		var err := Vector3(got.r - want.r, got.g - want.g, got.b - want.b).length()
		if code < 1.0 or err > 0.15:   # (a hue between two of the twenty: gold for amber)
			fails.append("shirts: %s comes back %s (code %.4f, off by %.2f)" % [want, got, code, err])
	print("shirts: white comes back %s" % WsgCrowd3D.shirt_palette(int((WsgCrowd3D.shirt_palette_code(Color(0.95, 0.94, 0.9)) - 1.0) * 256.0)))
	fails.append_array(_seats(true))
	if _seats(false).is_empty():
		fails.append("seats: the old placement (no lift, no room) passes the seat check: it checks nothing")
	for f in fails:
		printerr("FAIL: ", f)
	print("CROWD TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


## Looks: every fan has its parts (skin, hair, the legs' clothes) marked as crowd.json counts them, hair is never
## the shirt (long hair took the team's colour), set_looks reaches every material, and fan_weights picks the fans in
## those shares.
func _looks(spots: Array, facings: Array) -> Array:
	var fails := []
	var md := WsgCrowd3D.meta()
	for f in md.fans:
		var lk: Dictionary = md.fans[f].get("looks", {})
		if lk.is_empty():
			fails.append("looks: %s has no parts (a crowd baked before them: run tools/wsg/fetch_assets.sh again)" % f)
			continue
		var mesh: ArrayMesh = load(WsgCrowd3D.DIR + f + "_crowd.res")
		var arr := mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var col: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		var n := [0, 0, 0, 0]
		var hair_shirt := 0
		for v in uv.size():
			var part := int(round(uv[v].y * 4.0))
			n[part] += 1
			if part == 2 and col[v].a > 0.01:
				hair_shirt += 1
		var want := [int(lk.skin[3]), int(lk.hair[3]), int(lk.legs[3])]
		print("looks %-5s skin %d, hair %d, legs %d of %d" % [f, n[1], n[2], n[3], uv.size()])
		if [n[1], n[2], n[3]] != want:
			fails.append("looks: %s's mesh marks %s, crowd.json says %s" % [f, str([n[1], n[2], n[3]]), str(want)])
		if n[1] < 5 or n[2] < 5 or n[3] < 20:
			fails.append("looks: %s has too few parts marked (%s)" % [f, str(n)])
		if hair_shirt > 0:
			fails.append("looks: %s has %d hair vertices taking the shirt's colour" % [f, hair_shirt])
	var crowd := WsgCrowd3D.new()
	root.add_child(crowd)
	crowd.fan_weights = {"fan2": 4.0, "fan5": 4.0}
	crowd.build(spots, facings, 1.0, 3, true, 2, Vector3.ZERO)
	var women := 0
	var all := 0
	for m in crowd.meshes:
		var nm := String(m.multimesh.mesh.resource_path.get_file())
		all += m.multimesh.instance_count
		if nm.begins_with("fan2_") or nm.begins_with("fan5_"):
			women += m.multimesh.instance_count
	var share := float(women) / maxf(1, all)
	var expect: float = 8.0 / (8.0 + md.fans.size() - 2)
	print("fan_weights {fan2: 4, fan5: 4}: %.2f of %d fans are fan2 or fan5 (expected %.2f)" % [share, all, expect])
	if absf(share - expect) > 0.05:
		fails.append("fan_weights: %.2f of the fans are fan2/fan5, expected %.2f" % [share, expect])
	crowd.set_looks(WsgCrowd3D.LOOKS.skin, WsgCrowd3D.LOOKS.hair, WsgCrowd3D.LOOKS.legs)
	for m in crowd.materials:
		if int(m.get_shader_parameter("n_skins")) != WsgCrowd3D.LOOKS.skin.size() \
				or int(m.get_shader_parameter("n_hairs")) != WsgCrowd3D.LOOKS.hair.size() \
				or int(m.get_shader_parameter("n_legs")) != WsgCrowd3D.LOOKS.legs.size():
			fails.append("set_looks: a material did not get the palettes")
			break
	crowd.set_looks()
	if int(crowd.materials[0].get_shader_parameter("n_skins")) != 0:
		fails.append("set_looks(): the palettes were not cleared")
	crowd.free()
	return fails


## Seats: [seat over the feet, the step behind's height, how far behind the feet it rises] (m).
const SEATS := [[0.44, 0.42, 0.44], [0.44, 0.6, 0.44], [0.6, 0.6, 0.47]]


func _seats(fixed: bool) -> Array:
	var fails := []
	var md := WsgCrowd3D.meta()
	var rows := WsgCrowd3D.seated_rows(md)
	for fan in md.fans:
		var img := (load(WsgCrowd3D.DIR + fan + "_pos.res") as Texture2D).get_image()
		var nv := int(md.fans[fan].vertices)
		var mask := WsgCrowd3D.seat_mask(fan)
		if mask.is_empty():
			fails.append("%s: crowd.json has no seat_vertices (bake it again with tools/bake_crowd.gd)" % fan)
			continue
		var worst_sunk := 0.0
		var worst_in := 0.0
		for spec in SEATS:
			for h in [0.93, 1.07]:
				var pl: Array = WsgCrowd3D.place(Vector3.ZERO, Vector3.BACK, h, fan, spec[0], spec[2]) if fixed else \
					[Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * h), Vector3(0, 0, -WsgCrowd3D.FEET_FORWARD * h)), 0.0]
				var xf: Transform3D = pl[0]
				for r in rows:
					for v in nv:
						var c := img.get_pixel(v, r)
						var m := Vector3(c.r, c.g, c.b)
						var p := xf * (m + Vector3(0, pl[1], 0))
						# The seat of the trousers and the thighs on the seat (not a foot tucked back under it).
						if mask[v] == 1 and m.z < WsgCrowd3D.FEET_FORWARD - 0.1:
							worst_sunk = maxf(worst_sunk, spec[0] - p.y)
						# Nothing inside the step behind (behind its face, below its top).
						if p.z < -spec[2] and p.y < spec[1]:
							worst_in = maxf(worst_in, minf(spec[1] - p.y, -spec[2] - p.z))
		print("%-5s seated%s: at worst %.3f m into the seat, %.3f m into the step behind" % [fan, "" if fixed else " (the old placement)", worst_sunk, worst_in])
		if worst_sunk > 0.02:
			fails.append("%s sinks %.2f m into the seat" % [fan, worst_sunk])
		if worst_in > 0.02:
			fails.append("%s sits %.2f m into the step behind" % [fan, worst_in])
	return fails
