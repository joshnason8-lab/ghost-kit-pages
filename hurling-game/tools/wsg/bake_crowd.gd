extends SceneTree
## Bakes fans for the 3D crowd: each fan (a character baked onto the rig) cut down to a few hundred triangles, its
## texture turned into vertex colours, and every frame of every crowd motion (WsgCrowdClips, or the ActorCore
## crowd clips when this build has them) skinned through the rig and its drivers into vertex-animation textures:
## one row of vertex positions (and one of normals) per frame. The crowd's shader plays them, all on the GPU.
##   godot --headless --path <foundation> -s tools/bake_crowd.gd -- <out dir> <tris> <char dir> <albedo dir> <fan> [fan..]
## For each fan writes <out>/<fan>_crowd.res (ArrayMesh: UV.x picks the vertex's column, UV2 = how much of the
## torso and the head turns to watch, COLOR = its colour and in alpha how much is shirt), <fan>_vat.exr-like
## textures (<fan>_pos.res RGBAH, <fan>_nrm.res RGBA8) and one crowd.json (the clips' rows and lengths).
## With the authored clips the output is the studio's own; with ActorCore's it is licensed (addons/.../data only).

const FPS := 15.0
const PIVOTS := ["Spine1", "Neck"]     # extra columns: the torso's and the head's turning points, each frame

var out_dir := ""
var src = null          # WsgCrowdMocap when the build has the ActorCore crowd clips (licensed), else the authored
var clips := {}         # name -> [length s, loop]


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out_dir = a[0]
	var tris := int(a[1])
	var char_dir: String = a[2]
	var tex_dir: String = a[3]
	var fans: Array = a.slice(4)
	if WsgCrowdMocap.available() and not OS.has_environment("AUTHORED"):
		src = WsgCrowdMocap.new()
		clips = src.clips
	else:
		clips = WsgCrowdClips.CLIPS
	var meta := {"fps": FPS, "clips": {}, "fans": {}, "pivots": PIVOTS,
		"source": "ActorCore (licensed: build only)" if src != null else "authored (WsgCrowdClips)"}
	print("crowd motions: ", meta.source)
	var rows := 0
	for c in WsgCrowdClips.CLIPS:
		var spec: Array = clips[c]
		var n := int(round(spec[0] * FPS)) + (0 if spec[1] else 1)
		meta.clips[c] = {"row": rows, "frames": n, "length": spec[0], "loop": spec[1]}
		rows += n
	for fan in fans:
		var ch := WsgBody.load_character(char_dir, fan)
		var albedo := Image.load_from_file(tex_dir.path_join(fan + ".jpg"))
		var m := _crowd_mesh(ch, albedo, tris)
		var vat := await _bake_vat(ch, m, rows, meta)
		ResourceSaver.save(m.mesh, out_dir.path_join(fan + "_crowd.res"), ResourceSaver.FLAG_COMPRESS)
		ResourceSaver.save(m.far, out_dir.path_join(fan + "_crowd_far.res"), ResourceSaver.FLAG_COMPRESS)
		ResourceSaver.save(ImageTexture.create_from_image(vat[0]), out_dir.path_join(fan + "_pos.res"), ResourceSaver.FLAG_COMPRESS)
		ResourceSaver.save(ImageTexture.create_from_image(vat[1]), out_dir.path_join(fan + "_nrm.res"), ResourceSaver.FLAG_COMPRESS)
		meta.fans[fan] = {"vertices": m.count, "triangles": m.tris, "far_triangles": m.far_tris, "width": vat[0].get_width(), "rows": rows,
			"hips": snappedf((ch.joints["Hips"] as Vector3).y, 0.001)}
		var mask := _seat_mask(m)
		var seat := WsgCrowd3D.measure_seat(vat[0], m.count, WsgCrowd3D.seated_rows(meta), mask)
		meta.fans[fan]["seat"] = [snappedf(seat.x, 0.001), snappedf(seat.y, 0.001)]
		var ids := []
		for v in mask.size():
			if mask[v] == 1:
				ids.append(v)
		meta.fans[fan]["seat_vertices"] = ids
		print("%s: %d triangles (far %d), %d vertices, VAT %dx%d" % [fan, m.tris, m.far_tris, m.count, vat[0].get_width(), rows])
	var f := FileAccess.open(out_dir.path_join("crowd.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	quit()


## The fan's mesh for the crowd: welded (UV seams gone, so it can be cut right down), coloured from its texture,
## simplified to about tris triangles. Keeps its rig weights for the bake.
func _crowd_mesh(ch: Dictionary, albedo: Image, tris: int) -> Dictionary:
	var src: Array = (ch.meshes[0] as ArrayMesh).surface_get_arrays(0)
	var vs: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = src[Mesh.ARRAY_TEX_UV]
	var bs: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var ws: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = src[Mesh.ARRAY_INDEX]
	var key_of := {}
	var group := PackedInt32Array()
	group.resize(vs.size())
	var pos := PackedVector3Array()
	var acc_n := []
	var acc_c := []
	var acc_w := []
	for i in vs.size():
		var k := Vector3i((vs[i] * 1000.0).round())
		if not key_of.has(k):
			key_of[k] = pos.size()
			pos.append(vs[i])
			acc_n.append(Vector3.ZERO)
			acc_c.append([Vector3.ZERO, 0])
			acc_w.append({})
		var g: int = key_of[k]
		group[i] = g
		acc_n[g] += ns[i]
		var c := albedo.get_pixelv(Vector2i((uv[i] * Vector2(albedo.get_size())).clamp(Vector2.ZERO, Vector2(albedo.get_size()) - Vector2.ONE)))
		acc_c[g][0] += Vector3(c.r, c.g, c.b)
		acc_c[g][1] += 1
		for j in 4:
			if ws[i * 4 + j] > 0.0:
				acc_w[g][bs[i * 4 + j]] = float(acc_w[g].get(bs[i * 4 + j], 0.0)) + ws[i * 4 + j]
	var n := pos.size()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var bones := PackedInt32Array()
	var wts := PackedFloat32Array()
	var torso := ["Spine", "Spine1", "Spine2", "LeftShoulder", "RightShoulder", "LeftShoulderHelper",
		"RightShoulderHelper", "LeftArmRoll", "RightArmRoll", "LeftArm", "RightArm", "Hips"]
	for g in n:
		nrm.append((acc_n[g] as Vector3).normalized())
		var w: Dictionary = acc_w[g]
		var ks := w.keys()
		ks.sort_custom(func(x, y): return w[x] > w[y])
		var tot := 0.0
		for j in mini(4, ks.size()):
			tot += w[ks[j]]
		var shirt := 0.0
		for j in 4:
			bones.append(ks[j] if j < ks.size() else 0)
			var wj: float = w[ks[j]] / tot if j < ks.size() else 0.0
			wts.append(wj)
			if j < ks.size() and WsgRig.BONES[ks[j]][0] in torso:
				shirt += wj
		var cc: Vector3 = acc_c[g][0] / maxf(1, acc_c[g][1])
		# Shirt: the torso and upper arms, above the belt.
		if pos[g].y < (ch.joints["Hips"] as Vector3).y + 0.05:
			shirt = 0.0
		col.append(Color(cc.x, cc.y, cc.z, clampf(shirt, 0.0, 1.0)))
	var index := PackedInt32Array()
	for t in range(0, idx.size(), 3):
		var x := group[idx[t]]
		var y := group[idx[t + 1]]
		var z := group[idx[t + 2]]
		if x != y and y != z and x != z:
			index.append_array([x, y, z])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = pos
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = wts
	arr[Mesh.ARRAY_INDEX] = index
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arr)
	im.generate_lods(60.0, 60.0, [])
	var best := index
	for l in im.get_surface_lod_count(0):
		var ix := im.get_surface_lod_indices(0, l)
		if absi(ix.size() / 3 - tris) < absi(best.size() / 3 - tris):
			best = ix
	# The far version: about a third of that, over the same vertices (so the same animation textures play it).
	var far := best
	for l in im.get_surface_lod_count(0):
		var ix := im.get_surface_lod_indices(0, l)
		if ix.size() < best.size() and absi(ix.size() / 3 - tris / 3) < absi(far.size() / 3 - tris / 3):
			far = ix
	# Keep the vertices the cut uses.
	var remap := {}
	var keep := []
	var out_idx := PackedInt32Array()
	for v in best:
		if not remap.has(v):
			remap[v] = keep.size()
			keep.append(v)
		out_idx.append(remap[v])
	var kp := PackedVector3Array()
	var kn := PackedVector3Array()
	var kc := PackedColorArray()
	var kb := PackedInt32Array()
	var kw := PackedFloat32Array()
	for v in keep:
		kp.append(pos[v])
		kn.append(nrm[v])
		kc.append(col[v])
		for j in 4:
			kb.append(bones[v * 4 + j])
			kw.append(wts[v * 4 + j])
	# The far cut may use vertices the near one does not: drop those triangles (it is only for the far stands).
	var far_idx := PackedInt32Array()
	for t in range(0, far.size(), 3):
		if remap.has(far[t]) and remap.has(far[t + 1]) and remap.has(far[t + 2]):
			far_idx.append_array([remap[far[t]], remap[far[t + 1]], remap[far[t + 2]]])
	return {"pos": kp, "nrm": kn, "col": kc, "bones": kb, "weights": kw, "index": out_idx, "count": keep.size(),
		"tris": out_idx.size() / 3, "far_index": far_idx, "far_tris": far_idx.size() / 3, "mesh": null, "far": null}


## Every frame of every clip, skinned through the rig and its drivers: [positions image, normals image]. Also
## finishes the mesh (UV.x: the vertex's column; UV2: how much of the torso, and of the head, turns to watch).
## The vertices that are the seat of the trousers and the thighs: weighted mostly to the hips and thighs.
func _seat_mask(m: Dictionary) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(m.count)
	for v in m.count:
		var w := 0.0
		for j in 4:
			var nm: String = WsgRig.BONES[m.bones[v * 4 + j]][0]
			if nm == "Hips" or nm.contains("UpLeg") or nm.contains("Hip"):
				w += m.weights[v * 4 + j]
		mask[v] = 1 if w >= 0.6 else 0
	return mask


func _bake_vat(ch: Dictionary, m: Dictionary, rows: int, meta: Dictionary) -> Array:
	var body := WsgBody.new({"joints": ch.joints})
	root.add_child(body)
	await process_frame
	var sk := body.skeleton
	var nv: int = m.count
	var width := nv + PIVOTS.size()
	var pos_img := Image.create(width, rows, false, Image.FORMAT_RGBAH)
	var nrm_img := Image.create(width, rows, false, Image.FORMAT_RGBA8)
	var hips_scale: float = (ch.joints["Hips"] as Vector3).y / 0.98
	var row := 0
	for c in WsgCrowdClips.CLIPS:
		var info: Dictionary = meta.clips[c]
		print("  %s: %d frames" % [c, info.frames])
		for f in info.frames:
			var t: float = float(f) / FPS
			if not info.loop and info.frames > 1:
				t = float(f) / (info.frames - 1) * float(info.length)
			var pose: Dictionary = src.pose(c, t) if src != null else WsgCrowdClips.pose(c, t)
			body.reset_pose()
			for k in pose:
				if k == "@hips":
					var h := sk.find_bone("Hips")
					sk.set_bone_pose_position(h, sk.get_bone_rest(h).origin + (pose[k] as Vector3) * hips_scale)
				else:
					body.set_turn(k, pose[k])
			# (A frame the same as the last would not make the skeleton update, and skeleton_updated would never come:
			# the hips are nudged by a hair, alternately, so every frame is new.)
			var h0 := sk.find_bone("Hips")
			sk.set_bone_pose_position(h0, sk.get_bone_pose_position(h0) + Vector3(0, 1e-5 * float(row % 2 + 1), 0))
			await process_frame
			await sk.skeleton_updated
			var mats := []
			for i in sk.get_bone_count():
				mats.append(sk.get_bone_global_pose(i) * Transform3D(Basis.IDENTITY, -sk.get_bone_global_rest(i).origin))
			for v in nv:
				var p := Vector3.ZERO
				var nn := Vector3.ZERO
				for j in 4:
					var w: float = m.weights[v * 4 + j]
					if w > 0.0:
						var mt: Transform3D = mats[m.bones[v * 4 + j]]
						p += (mt * (m.pos[v] as Vector3)) * w
						nn += (mt.basis * (m.nrm[v] as Vector3)) * w
				pos_img.set_pixel(v, row, Color(p.x, p.y, p.z, 1.0))
				nn = nn.normalized()
				nrm_img.set_pixel(v, row, Color(nn.x * 0.5 + 0.5, nn.y * 0.5 + 0.5, nn.z * 0.5 + 0.5, 1.0))
			for pi in PIVOTS.size():
				var pp := sk.get_bone_global_pose(sk.find_bone(PIVOTS[pi])).origin
				pos_img.set_pixel(nv + pi, row, Color(pp.x, pp.y, pp.z, 1.0))
			row += 1
			await process_frame
	body.queue_free()
	# The mesh the crowd draws: rest positions (the first frame's, seated), the column, the turning shares.
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var torso_ids := {}
	for b in ["Spine1", "Spine2", "LeftShoulder", "RightShoulder", "LeftShoulderHelper", "RightShoulderHelper",
			"LeftArmRoll", "RightArmRoll", "LeftArm", "RightArm", "LeftElbowHelper", "RightElbowHelper",
			"LeftForeArm", "RightForeArm", "LeftForeArmRoll", "RightForeArmRoll", "LeftForeArmRoll2",
			"RightForeArmRoll2", "LeftHand", "RightHand"]:
		torso_ids[WsgRig.index(b)] = true
	var head_ids := {WsgRig.index("Neck"): 0.5, WsgRig.index("Head"): 1.0}
	var first := PackedVector3Array()
	for v in nv:
		uv.append(Vector2((v + 0.5) / float(width), 0.0))
		var tw := 0.0
		var hw := 0.0
		for j in 4:
			var b: int = m.bones[v * 4 + j]
			var w: float = m.weights[v * 4 + j]
			if torso_ids.has(b) or WsgRig.is_finger(WsgRig.BONES[b][0]):
				tw += w
			if head_ids.has(b):
				hw += w * float(head_ids[b])
				tw += w
		uv2.append(Vector2(tw, hw))
		var c := pos_img.get_pixel(v, 0)
		first.append(Vector3(c.r, c.g, c.b))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = first
	arr[Mesh.ARRAY_NORMAL] = m.nrm
	arr[Mesh.ARRAY_COLOR] = m.col
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_INDEX] = m.index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# Big enough for any frame (standing, arms up).
	mesh.custom_aabb = AABB(Vector3(-0.8, -0.1, -0.8), Vector3(1.6, 2.4, 1.6))
	m.mesh = mesh
	arr[Mesh.ARRAY_INDEX] = m.far_index
	var far := ArrayMesh.new()
	far.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	far.custom_aabb = mesh.custom_aabb
	m.far = far
	return [pos_img, nrm_img]
