extends SceneTree
## Bakes the owner's netball player model (src/player.glb) for the game: the mesh moved onto the game's own
## seventeen-bone skeleton (ToonBody.BONES: every rest rotation the identity, the arms and legs hanging straight), cut
## down to two sizes for phones, and the model's own Mixamo clips (Running, Walking) turned into the game's poses on
## that skeleton. The sprint, Fast_Run, is the owner's Mixamo clip shared with Hurling, already baked there as poses
## on the same seventeen bones (clips/fast_run.json): it is copied in as it is.
##
## Run by build.sh in a scratch project where Godot has imported the model with the humanoid retarget
## (mixamo_map.tres; src/player.glb.import), so its bones have Godot's humanoid names.
##   godot --headless --path <scratch> -s bake.gd -- <out dir>
## Writes <out>/hero_hi.res and hero_lo.res (the body's mesh: rest space, bone indices into ToonBody.BONES, the rest
## position in the vertex colour and in UV2) and <out>/hero.json (the skeleton's offsets, the torso's measurements
## for the bib, the clips).

const NAMES := ["hips", "spine", "chest", "neck", "head", "upperarm_l", "forearm_l", "hand_l", "upperarm_r",
	"forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const PARENT := [-1, 0, 1, 2, 3, 2, 5, 6, 2, 8, 9, 0, 11, 12, 0, 14, 15]
## Each of the model's bones and the game's bone that carries it.
const CARRIER := {"Hips": "hips", "Spine": "spine", "Chest": "spine", "UpperChest": "chest", "LeftShoulder": "chest",
	"RightShoulder": "chest", "Neck": "neck", "Head": "head", "headfront": "head",
	"LeftUpperArm": "upperarm_l", "LeftLowerArm": "forearm_l", "LeftHand": "hand_l",
	"RightUpperArm": "upperarm_r", "RightLowerArm": "forearm_r", "RightHand": "hand_r",
	"LeftUpperLeg": "thigh_l", "LeftLowerLeg": "shin_l", "LeftFoot": "foot_l", "LeftToes": "foot_l",
	"RightUpperLeg": "thigh_r", "RightLowerLeg": "shin_r", "RightFoot": "foot_r", "RightToes": "foot_r"}
## Each game bone's joint (where it turns) and the model's bone whose turning it takes in a clip.
const JOINT := {"hips": "Hips", "spine": "Spine", "chest": "UpperChest", "neck": "Neck", "head": "Head",
	"upperarm_l": "LeftUpperArm", "forearm_l": "LeftLowerArm", "hand_l": "LeftHand",
	"upperarm_r": "RightUpperArm", "forearm_r": "RightLowerArm", "hand_r": "RightHand",
	"thigh_l": "LeftUpperLeg", "shin_l": "LeftLowerLeg", "foot_l": "LeftFoot",
	"thigh_r": "RightUpperLeg", "shin_r": "RightLowerLeg", "foot_r": "RightFoot"}
const TURN := {"spine": "Chest"}
const HEIGHT := 1.76          # the game's bodies are 1.76 m tall at scale 1 (ToonBody scales by a player's height)
const ARM_OUT := 6.0          # the arms hang this far out from straight down, clear of the hips
const TRIS := [6000, 1800]    # about how many triangles each size keeps
const OWN_CLIPS := ["Running", "Walking"]   # the model's own clips, each one stride of each leg

var sk: Skeleton3D
var rest_g := []              # the model's bones in the game's rest stance (skeleton space)
var skin_g := []              # the same, with the feet as the mesh was bound (what the mesh is skinned with)
var shift := Vector3.ZERO
var k := 1.0


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var p: Node3D = load("res://src/player.glb").instantiate()
	sk = p.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = sk.find_children("*", "MeshInstance3D", true, false)[0]
	_stance()
	var arrays := _skin_to_stance(mi)
	var json := {"offsets": {}, "clips": {}}
	for i in NAMES.size():
		var at := _joint(NAMES[i])
		var par := _joint(NAMES[PARENT[i]]) if PARENT[i] >= 0 else Vector3.ZERO
		json.offsets[NAMES[i]] = _v(at - par)
	json.torso = _torso(arrays)
	for lod in TRIS.size():
		var mesh := _cut(arrays, TRIS[lod])
		var path := "%s/hero_%s.res" % [out, ["hi", "lo"][lod]]
		print(path, " ", ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS))
	json.clips = _clips(p)
	json.clips.Fast_Run = JSON.parse_string(FileAccess.get_file_as_string("res://clips/fast_run.json"))
	var f := FileAccess.open(out + "/hero.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(json, "", false))
	f.close()
	p.free()
	quit()


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]


## A game bone's joint in the baked mesh's space (metres, the soles at y = 0, the hips over the origin).
func _joint(name: String) -> Vector3:
	return (rest_g[sk.find_bone(JOINT[name])].origin - shift) * k


## The game's rest stance: the model's T-pose with the arms hanging (a little out) and the legs straight down; the
## feet keep their own turn, everything else follows its parent.
func _stance() -> void:
	var a := deg_to_rad(ARM_OUT)
	var straight := {
		"LeftUpperArm": ["LeftLowerArm", Vector3(sin(a), -cos(a), 0)], "LeftLowerArm": ["LeftHand", Vector3(sin(a), -cos(a), 0)],
		"RightUpperArm": ["RightLowerArm", Vector3(-sin(a), -cos(a), 0)], "RightLowerArm": ["RightHand", Vector3(-sin(a), -cos(a), 0)],
		"LeftUpperLeg": ["LeftLowerLeg", Vector3.DOWN], "LeftLowerLeg": ["LeftFoot", Vector3.DOWN],
		"RightUpperLeg": ["RightLowerLeg", Vector3.DOWN], "RightLowerLeg": ["RightFoot", Vector3.DOWN]}
	rest_g = []
	for b in sk.get_bone_count():
		var par := sk.get_bone_parent(b)
		var t: Transform3D = (rest_g[par] * sk.get_bone_rest(b)) if par >= 0 else sk.get_bone_rest(b)
		var nm := sk.get_bone_name(b)
		if straight.has(nm):
			var c := sk.find_bone(straight[nm][0])
			var dir := (t * sk.get_bone_rest(c).origin - t.origin).normalized()
			t.basis = Basis(Quaternion(dir, (straight[nm][1] as Vector3).normalized())) * t.basis
		elif nm in ["LeftFoot", "RightFoot"]:
			t.basis = sk.get_bone_global_rest(b).basis
		rest_g.append(t)
	# The feet as modelled: the import's rest fixer turns the foot bones level (toes up 45 degrees in the mesh), so
	# the mesh is skinned to the stance with the feet and toes as they were bound, flat on the floor. The clips'
	# turns stay measured from rest_g's feet, so a foot at its rest in a clip is flat too.
	skin_g = rest_g.duplicate()
	var skin: Skin = sk.find_children("*", "MeshInstance3D", true, false)[0].skin
	var bind := {}
	for i in skin.get_bind_count():
		bind[String(skin.get_bind_name(i))] = skin.get_bind_pose(i).affine_inverse()
	for side in ["Left", "Right"]:
		var f := sk.find_bone(side + "Foot")
		var tz := sk.find_bone(side + "Toes")
		var bf: Transform3D = bind[side + "Foot"]
		var bt: Transform3D = bind[side + "Toes"]
		skin_g[f] = Transform3D(bf.basis, rest_g[f].origin)
		skin_g[tz] = Transform3D(bt.basis, skin_g[f] * (bf.affine_inverse() * bt.origin))


## The model's vertices skinned into the stance, scaled to the game's height, with each vertex's weights moved onto
## the game's bones. The vertex colour carries the rest position (r, g, b over the box below) and the part (a: 1 on
## the shins and feet); UV2 the rest position's x and y again at full precision (a vertex colour has 8 bits a
## channel), for the bib, which the shader paints on the dress with its letters.
func _skin_to_stance(mi: MeshInstance3D) -> Array:
	var src := mi.mesh.surface_get_arrays(0)
	var skin := mi.skin
	var mats := []
	var tb := []
	for i in skin.get_bind_count():
		var bn := skin.get_bind_name(i)
		var bi := sk.find_bone(bn)
		mats.append(skin_g[bi] * skin.get_bind_pose(i))
		tb.append(NAMES.find(CARRIER[String(bn)]))
	var vs: PackedVector3Array = src[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = src[Mesh.ARRAY_NORMAL]
	var bs: PackedInt32Array = src[Mesh.ARRAY_BONES]
	var ws: PackedFloat32Array = src[Mesh.ARRAY_WEIGHTS]
	var n := vs.size()
	var pv := PackedVector3Array()
	pv.resize(n)
	var pn := PackedVector3Array()
	pn.resize(n)
	var ob := PackedInt32Array()
	ob.resize(n * 4)
	var ow := PackedFloat32Array()
	ow.resize(n * 4)
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for v in n:
		var p := Vector3.ZERO
		var nn := Vector3.ZERO
		var acc := {}
		for j in 4:
			var w := ws[v * 4 + j]
			if w <= 0.0:
				continue
			var m: Transform3D = mats[bs[v * 4 + j]]
			p += (m * vs[v]) * w
			nn += (m.basis * ns[v]) * w
			var t: int = tb[bs[v * 4 + j]]
			acc[t] = float(acc.get(t, 0.0)) + w
		pv[v] = p
		pn[v] = nn.normalized()
		lo = lo.min(p)
		hi = hi.max(p)
		var ks := acc.keys()
		ks.sort_custom(func(x, y): return acc[x] > acc[y])
		var tot := 0.0
		for j in mini(4, ks.size()):
			tot += acc[ks[j]]
		for j in 4:
			ob[v * 4 + j] = ks[j] if j < ks.size() else 0
			ow[v * 4 + j] = acc[ks[j]] / tot if j < ks.size() else 0.0
	var hips: Vector3 = rest_g[sk.find_bone("Hips")].origin
	shift = Vector3(hips.x, lo.y, hips.z)
	k = HEIGHT / (hi.y - lo.y)
	var col := PackedColorArray()
	col.resize(n)
	var uv2 := PackedVector2Array()
	uv2.resize(n)
	for v in n:
		pv[v] = (pv[v] - shift) * k
		var main := ob[v * 4]
		var leg := 1.0 if main in [12, 13, 15, 16] else 0.0
		col[v] = Color(clampf(pv[v].x / 1.6 + 0.5, 0, 1), clampf(pv[v].y / 2.0, 0, 1), clampf(pv[v].z / 1.6 + 0.5, 0, 1), leg)
		uv2[v] = Vector2(pv[v].x, pv[v].y)
	print("verts ", n, " height ", hi.y - lo.y, " -> ", HEIGHT, " (x", k, ")")
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = pv
	out[Mesh.ARRAY_NORMAL] = pn
	out[Mesh.ARRAY_TEX_UV] = src[Mesh.ARRAY_TEX_UV]
	out[Mesh.ARRAY_TEX_UV2] = uv2
	out[Mesh.ARRAY_COLOR] = col
	out[Mesh.ARRAY_BONES] = ob
	out[Mesh.ARRAY_WEIGHTS] = ow
	out[Mesh.ARRAY_INDEX] = src[Mesh.ARRAY_INDEX]
	return out


## Where the bib goes, measured on the torso at rest: the middle of the body front to back at the chest (front of it
## is the bib's front, behind it the back), and the neckline's height in front.
func _torso(arrays: Array) -> Dictionary:
	var pv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var ob: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var chest := _joint("chest")
	var zf := -INF
	var zb := INF
	for v in pv.size():
		var p := pv[v]
		if ob[v * 4] in [1, 2] and absf(p.x) < 0.05 and absf(p.y - chest.y) < 0.03:
			zf = maxf(zf, p.z)
			zb = minf(zb, p.z)
	print("torso at the chest: front ", zf, " back ", zb)
	return {"mid_z": snappedf((zf + zb) * 0.5, 0.001), "front": snappedf(zf, 0.001), "back": snappedf(zb, 0.001),
		"chest_y": snappedf(chest.y, 0.001)}


## The mesh cut down (meshoptimizer, through Godot's own LOD generator) to about tris triangles, keeping only the
## vertices the cut-down triangles use; with its own smaller levels for far away.
func _cut(arrays: Array, tris: int) -> ArrayMesh:
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var a := im.get_surface_arrays(0)
	var best: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for l in im.get_surface_lod_count(0):
		var ix := im.get_surface_lod_indices(0, l)
		if absi(ix.size() / 3 - tris) < absi(best.size() / 3 - tris):
			best = ix
	var remap := {}
	var keep := PackedInt32Array()
	var idx := PackedInt32Array()
	idx.resize(best.size())
	for i in best.size():
		var v := best[i]
		if not remap.has(v):
			remap[v] = keep.size()
			keep.append(v)
		idx[i] = remap[v]
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	var vs := PackedVector3Array()
	var ns := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()
	var bs := PackedInt32Array()
	var ws := PackedFloat32Array()
	for v in keep:
		vs.append(a[Mesh.ARRAY_VERTEX][v])
		ns.append(a[Mesh.ARRAY_NORMAL][v])
		uv.append(a[Mesh.ARRAY_TEX_UV][v])
		uv2.append(a[Mesh.ARRAY_TEX_UV2][v])
		col.append(a[Mesh.ARRAY_COLOR][v])
		for j in 4:
			bs.append(a[Mesh.ARRAY_BONES][v * 4 + j])
			ws.append(a[Mesh.ARRAY_WEIGHTS][v * 4 + j])
	out[Mesh.ARRAY_VERTEX] = vs
	out[Mesh.ARRAY_NORMAL] = ns
	out[Mesh.ARRAY_TEX_UV] = uv
	out[Mesh.ARRAY_TEX_UV2] = uv2
	out[Mesh.ARRAY_COLOR] = col
	out[Mesh.ARRAY_BONES] = bs
	out[Mesh.ARRAY_WEIGHTS] = ws
	out[Mesh.ARRAY_INDEX] = idx
	# Its own levels of detail below that, for the renderer to pick by how big she is on the screen.
	var cut := ImporterMesh.new()
	cut.add_surface(Mesh.PRIMITIVE_TRIANGLES, out)
	cut.generate_lods(25.0, 60.0, [])
	var lods := []
	for l in cut.get_surface_lod_count(0):
		lods.append(cut.get_surface_lod_indices(0, l).size() / 3)
	print(" cut to ", idx.size() / 3, " triangles, ", keep.size(), " vertices; levels ", lods)
	return cut.get_mesh()


## The model's own clips as the game's poses: for each frame (30 a second), each game bone's turn from the rest stance
## as degrees (x, y, z; Euler YXZ, as ToonBody.apply reads them), and the hips' lift (m). The hips stay over the spot:
## the game moves the player. "left_forward": the time the left thigh is furthest forward (the stride's phase 1/4).
func _clips(model: Node) -> Dictionary:
	var out := {}
	var ap: AnimationPlayer = model.find_children("*", "AnimationPlayer", true, false)[0]
	for name in OWN_CLIPS:
		var an: Animation = ap.get_animation(name)
		var frames := []
		var n := int(round(an.length * 30.0))
		for f in n + 1:
			var g := _sample(an, minf(f / 30.0, an.length))
			var turn := []
			for i in NAMES.size():
				var j := sk.find_bone(TURN.get(NAMES[i], JOINT[NAMES[i]]))
				turn.append(Basis(g[j].basis.get_rotation_quaternion() * rest_g[j].basis.get_rotation_quaternion().inverse()))
			var pose := {}
			for i in NAMES.size():
				var local: Basis = turn[i] if PARENT[i] < 0 else turn[PARENT[i]].inverse() * turn[i]
				var e := local.get_euler(EULER_ORDER_YXZ) * (180.0 / PI)
				pose[NAMES[i]] = [snappedf(e.x, 0.1), snappedf(e.y, 0.1), snappedf(e.z, 0.1)]
			var hips := sk.find_bone("Hips")
			pose.hips_y = snappedf((g[hips].origin.y - rest_g[hips].origin.y) * k, 0.001)
			frames.append(pose)
		var fwd := 0
		for f in frames.size():
			if frames[f].thigh_l[0] < frames[fwd].thigh_l[0]:
				fwd = f
		out[name] = {"fps": 30, "left_forward": snappedf(fwd / 30.0, 0.001), "frames": frames}
		print(name, ": ", frames.size(), " frames, ", snappedf(an.length, 0.01), " s; left thigh forward at ", fwd / 30.0)
	return out


## Every bone of the model at time t of the clip (skeleton space): the clip's turns, the hips' height (the clip's
## position tracks are kept relative to the hips' height at rest: motion_scale), the rest elsewhere.
func _sample(an: Animation, t: float) -> Array:
	var rot := {}
	var pos := {}
	for tr in an.get_track_count():
		var bn := String(an.track_get_path(tr).get_concatenated_subnames())
		if an.track_get_type(tr) == Animation.TYPE_ROTATION_3D:
			rot[bn] = an.rotation_track_interpolate(tr, t)
		elif an.track_get_type(tr) == Animation.TYPE_POSITION_3D:
			pos[bn] = an.position_track_interpolate(tr, t) * sk.motion_scale
	var g := []
	for b in sk.get_bone_count():
		var nm := sk.get_bone_name(b)
		var r := sk.get_bone_rest(b)
		var q: Quaternion = rot.get(nm, r.basis.get_rotation_quaternion())
		var o: Vector3 = pos.get(nm, r.origin)
		var local := Transform3D(Basis(q), o)
		var par := sk.get_bone_parent(b)
		g.append(g[par] * local if par >= 0 else local)
	return g
