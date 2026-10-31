extends SceneTree
## A loose garment's webbing under the arms taken out of a character's T: a coat modelled arms-down and posed into the
## rig's T stretches from its side up into the sleeve (Hurling's umpire: down to 26 cm below the arm, where a shirt
## stops at 8), and every arm held out shows it as a wing. Under each arm, beyond the garment's side (its width at
## the hips), a vertex skinned to the arm goes up to the sleeve's underside (the sleeve as thick below the arm as above
## it), the rest hangs straight down at the garment's side. Normals and tangents remade where it moved. Writes
## <prefix>_hi.res in place (make the light mesh from it after: tools/blender/make_lod.sh; then cloth_weights.gd).
##   godot --headless --path <project> -s <this> -- <char dir> <prefix> [margin 0.02]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0]
	var prefix: String = a[1]
	var margin := float(a[2]) if a.size() > 2 else 0.02
	var joints: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(prefix + "_rig.json"))).joints
	var arm_bones := {}
	for i in WsgRig.BONES.size():
		var n: String = WsgRig.BONES[i][0]
		for side in ["Left", "Right"]:
			for part in ["Arm", "ForeArm", "Hand", "ElbowHelper", "ShoulderHelper"]:
				if n.begins_with(side + part):
					arm_bones[i] = true
	var path := dir.path_join(prefix + "_hi.res")
	var mesh := load(path) as ArrayMesh
	var arr := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var per := bs.size() / vs.size()
	var moved := {}
	var report := []
	for side in ["Left", "Right"]:
		var sgn := 1.0 if side == "Left" else -1.0
		var sh := _v(joints[side + "Arm"])
		var arm_y := sh.y
		# (Not the hand - beyond the wrist - and not the skirt below the chest.)
		var wrist := absf(_v(joints[side + "Hand"]).x) - 0.03
		var low := _v(joints["Spine1"]).y - 0.08
		# The garment's side: its half-width at the hips (where a coat or jacket is belted or hangs straight; higher, the
		# webbing widens it towards the arm, and a coarse garment has few vertices to measure by).
		var waist := 0.0
		for p in vs:
			if p.x * sgn > 0.0 and absf(p.y - _v(joints["Hips"]).y) < 0.03:
				waist = maxf(waist, absf(p.x))
		# The sleeve's thickness above the arm's line, along the arm (5 cm bins): as thick below it.
		var top := {}
		for p in vs:
			if p.x * sgn > waist and absf(p.x) < wrist and absf(p.z - sh.z) < 0.15:
				var k := int(absf(p.x) / 0.05)
				top[k] = maxf(float(top.get(k, 0.0)), p.y - arm_y)
		var n_arm := 0
		var n_coat := 0
		for v in vs.size():
			var p := vs[v]
			if p.x * sgn <= waist + margin or absf(p.x) >= wrist or p.y < low:
				continue
			var k := int(absf(p.x) / 0.05)
			var under := arm_y - float(top.get(k, 0.08))
			if p.y >= under - margin:
				continue
			var on_arm := 0.0
			for j in per:
				if arm_bones.has(bs[v * per + j]):
					on_arm += ws[v * per + j]
			if on_arm > 0.5:
				vs[v] = Vector3(p.x, under, p.z)
				n_arm += 1
			else:
				vs[v] = Vector3((waist + margin) * sgn, p.y, p.z)
				n_coat += 1
			moved[v] = true
		report.append("%s: side at %.2f m, %d up to the sleeve, %d down the side" % [side, waist, n_arm, n_coat])
	arr[Mesh.ARRAY_VERTEX] = vs
	_renormal(arr, moved)
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_tangents()
	arr = st.commit_to_arrays()
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, null, "", Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0)
	im.generate_lods(25.0, 60.0, [])
	var err := ResourceSaver.save(im.get_mesh(), path)
	print("cloth_drape: %s: %s %s" % [path.get_file(), "; ".join(report), "" if err == OK else "FAILED %d" % err])
	quit(0 if err == OK else 1)


static func _v(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## The moved vertices' normals again, from their faces (area-weighted), shared by every copy of the same place (the
## mesh's seams split them).
static func _renormal(arr: Array, moved: Dictionary) -> void:
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var at := {}
	for v in moved:
		at[Vector3i((vs[v] * 10000.0).round())] = Vector3.ZERO
	for t in range(0, idx.size(), 3):
		var p0 := vs[idx[t]]
		var p1 := vs[idx[t + 1]]
		var p2 := vs[idx[t + 2]]
		# (Godot's front faces are clockwise.)
		var fn := (p2 - p0).cross(p1 - p0)
		for k in 3:
			var key := Vector3i((vs[idx[t + k]] * 10000.0).round())
			if at.has(key):
				at[key] += fn
	for v in vs.size():
		var key := Vector3i((vs[v] * 10000.0).round())
		if at.has(key) and (at[key] as Vector3).length() > 1e-9:
			ns[v] = (at[key] as Vector3).normalized()
	arr[Mesh.ARRAY_NORMAL] = ns
