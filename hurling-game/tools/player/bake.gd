extends SceneTree
## Bakes the owner's player model (src/player.glb) for the game: the mesh moved onto the game's own seventeen-bone
## skeleton (ToonBody.BONES: every rest rotation the identity, the arms and legs hanging straight), cut down to two
## sizes for phones, and the four Mixamo clips turned into the game's poses on that skeleton.
##
## Run by build.sh in a scratch project where Godot has imported the model and the clips with the humanoid retarget
## (mixamo_map.tres, or meshy_map.tres for a Meshy rig; the .import files here), so all of them share Godot's humanoid
## bone names.
##   godot --headless --path <scratch> -s bake.gd -- <out dir> [model.glb name] [prefix] [tris hi] [tris lo] [clips 0/1]
## (by default: player hero 6000 2000 1). Writes <out>/<prefix>_hi.res and _lo.res (the body's mesh: rest space, bone
## indices into ToonBody.BONES, the rest position and the part in the vertex colour) and <out>/<prefix>.json (the
## skeleton's offsets; the clips, when asked for). The officials are Meshy models baked the same way (build_people.sh).

const NAMES := ["hips", "spine", "chest", "neck", "head", "upperarm_l", "forearm_l", "hand_l", "upperarm_r",
	"forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]
const PARENT := [-1, 0, 1, 2, 3, 2, 5, 6, 2, 8, 9, 0, 11, 12, 0, 14, 15]
## Each of the model's bones and the game's bone that carries it.
const CARRIER := {"Hips": "hips", "Spine": "spine", "Chest": "spine", "UpperChest": "chest", "LeftShoulder": "chest",
	"RightShoulder": "chest", "Neck": "neck", "Head": "head", "headfront": "head",
	"LeftUpperArm": "upperarm_l", "LeftLowerArm": "forearm_l", "LeftHand": "hand_l",
	"RightUpperArm": "upperarm_r", "RightLowerArm": "forearm_r", "RightHand": "hand_r",
	"LeftUpperLeg": "thigh_l", "LeftLowerLeg": "shin_l", "LeftFoot": "foot_l", "LeftToes": "foot_l",
	"RightUpperLeg": "thigh_r", "RightLowerLeg": "shin_r", "RightFoot": "foot_r", "RightToes": "foot_r",
	"head_end": "head"}
## Each game bone's joint (where it turns) and the model's bone whose turning it takes in a clip.
const JOINT := {"hips": "Hips", "spine": "Spine", "chest": "UpperChest", "neck": "Neck", "head": "Head",
	"upperarm_l": "LeftUpperArm", "forearm_l": "LeftLowerArm", "hand_l": "LeftHand",
	"upperarm_r": "RightUpperArm", "forearm_r": "RightLowerArm", "hand_r": "RightHand",
	"thigh_l": "LeftUpperLeg", "shin_l": "LeftLowerLeg", "foot_l": "LeftFoot",
	"thigh_r": "RightUpperLeg", "shin_r": "RightLowerLeg", "foot_r": "RightFoot"}
const TURN := {"spine": "Chest"}
const HEIGHT := 1.80          # the game's bodies are 1.80 m tall at scale 1 (ToonBody scales by a player's height)
const ARM_OUT := 6.0          # the arms hang this far out from straight down, clear of the hips
const TRIS := [6000, 2000]    # about how many triangles each size keeps
## The part of each swing kept (seconds before and after the bas meets the ball): the clips stand at the plate or the
## tee for seconds before they swing. The run is kept whole (one stride of each leg).
const WINDOW := {"Baseball_Hit": [0.8, 0.7], "Baseball_Strike": [0.8, 0.7], "Golf_Drive": [0.9, 0.7]}

var fps := 30.0              # the clips' frames a second (60 for the HD pack: the 7th argument)
var sk: Skeleton3D
var rest_g := []              # the model's bones in the game's rest stance (skeleton space)
var shift := Vector3.ZERO
var k := 1.0


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	var model := a[1] if a.size() > 1 else "player"
	var prefix := a[2] if a.size() > 2 else "hero"
	var tris := [int(a[3]), int(a[4])] if a.size() > 4 else TRIS
	var with_clips := (a[5] == "1") if a.size() > 5 else true
	fps = float(a[6]) if a.size() > 6 else 30.0
	var meshes := not (a.size() > 7 and a[7] == "clips_only")
	var p: Node3D = load("res://src/%s.glb" % model).instantiate()
	sk = p.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = sk.find_children("*", "MeshInstance3D", true, false)[0]
	_stance()
	var arrays := _skin_to_stance(mi)
	var json := {"offsets": {}, "clips": {}}
	for i in NAMES.size():
		var at := _joint(NAMES[i])
		var par := _joint(NAMES[PARENT[i]]) if PARENT[i] >= 0 else Vector3.ZERO
		json.offsets[NAMES[i]] = _v(at - par)
	for lod in (tris.size() if meshes else 0):
		var mesh := _cut(arrays, tris[lod])
		var path := "%s/%s_%s.res" % [out, prefix, ["hi", "lo"][lod]]
		print(path, " ", ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS))
	if with_clips:
		json.clips = _clips()
	var f := FileAccess.open("%s/%s.json" % [out, prefix], FileAccess.WRITE)
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


## The model's vertices skinned into the stance, scaled to the game's height, with each vertex's weights moved onto
## the game's bones. The vertex colour carries the rest position (r, g, b over the box below) and the part (a: 1 on
## the shins and feet, where the jersey's green is the socks).
func _skin_to_stance(mi: MeshInstance3D) -> Array:
	var src := mi.mesh.surface_get_arrays(0)
	var skin := mi.skin
	var mats := []
	var tb := []
	for i in skin.get_bind_count():
		var bn := skin.get_bind_name(i)
		var bi := sk.find_bone(bn)
		mats.append(rest_g[bi] * skin.get_bind_pose(i))
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
	for v in n:
		pv[v] = (pv[v] - shift) * k
		var main := ob[v * 4]
		var leg := 1.0 if main in [12, 13, 15, 16] else 0.0
		col[v] = Color(clampf(pv[v].x / 1.6 + 0.5, 0, 1), clampf(pv[v].y / 2.0, 0, 1), clampf(pv[v].z / 1.6 + 0.5, 0, 1), leg)
	print("verts ", n, " height ", hi.y - lo.y, " -> ", HEIGHT, " (x", k, ")")
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = pv
	out[Mesh.ARRAY_NORMAL] = pn
	out[Mesh.ARRAY_TEX_UV] = src[Mesh.ARRAY_TEX_UV]
	out[Mesh.ARRAY_COLOR] = col
	out[Mesh.ARRAY_BONES] = ob
	out[Mesh.ARRAY_WEIGHTS] = ow
	out[Mesh.ARRAY_INDEX] = src[Mesh.ARRAY_INDEX]
	return out


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
	var col := PackedColorArray()
	var bs := PackedInt32Array()
	var ws := PackedFloat32Array()
	for v in keep:
		vs.append(a[Mesh.ARRAY_VERTEX][v])
		ns.append(a[Mesh.ARRAY_NORMAL][v])
		uv.append(a[Mesh.ARRAY_TEX_UV][v])
		col.append(a[Mesh.ARRAY_COLOR][v])
		for j in 4:
			bs.append(a[Mesh.ARRAY_BONES][v * 4 + j])
			ws.append(a[Mesh.ARRAY_WEIGHTS][v * 4 + j])
	out[Mesh.ARRAY_VERTEX] = vs
	out[Mesh.ARRAY_NORMAL] = ns
	out[Mesh.ARRAY_TEX_UV] = uv
	out[Mesh.ARRAY_COLOR] = col
	out[Mesh.ARRAY_BONES] = bs
	out[Mesh.ARRAY_WEIGHTS] = ws
	out[Mesh.ARRAY_INDEX] = idx
	# Its own levels of detail below that, for the renderer to pick by how big the man is on the screen.
	var cut := ImporterMesh.new()
	cut.add_surface(Mesh.PRIMITIVE_TRIANGLES, out)
	cut.generate_lods(25.0, 60.0, [])
	var lods := []
	for l in cut.get_surface_lod_count(0):
		lods.append(cut.get_surface_lod_indices(0, l).size() / 3)
	print(" cut to ", idx.size() / 3, " triangles, ", keep.size(), " vertices; levels ", lods)
	return cut.get_mesh()


## The clips as the game's poses: for each frame (30 a second), each game bone's turn from the rest stance as
## degrees (x, y, z; Euler YXZ, as ToonBody.apply reads them), and the hips' lift (m). The hips stay over the spot:
## the game moves the man.
func _clips() -> Dictionary:
	var out := {}
	for name in ["Fast_Run", "Baseball_Hit", "Baseball_Strike", "Golf_Drive"]:
		var scene: Node = load("res://src/%s.fbx" % name).instantiate()
		var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
		var an: Animation = ap.get_animation("mixamo_com")
		var frames := []
		var hand := []
		var n := int(round(an.length * fps))
		for f in n + 1:
			var g := _sample(an, minf(f / fps, an.length))
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
			# The bas: where ToonBody's hurley puts it, off the right hand.
			var bas: Vector3 = turn[NAMES.find("hand_r")] * (Vector3(0, -0.06, 0.01) + Vector3(0.05, -0.62, 0.78).normalized() * 0.78)
			hand.append(g[sk.find_bone("RightHand")].origin * k + bas)
		# The moment of contact in a swing: as the bas, at its fastest, comes past him from behind (crosses z = 0
		# beside him, going forward: a hurler meets the ball side-on); the way it moves then, flat, is the way the
		# ball goes, and "yaw" (degrees) turns the man so that it is the way he faces.
		var best := 1
		var top := 0.0
		for f in range(1, hand.size()):
			var sp: float = (hand[f] - hand[f - 1]).length() * fps
			if sp > top:
				top = sp
				best = f
		var cross := float(best)
		var d := Vector3.FORWARD
		for f in range(maxi(1, best - 4), mini(hand.size(), best + 5)):
			var za: float = hand[f - 1].z
			var zb: float = hand[f].z
			if za < 0.0 and zb >= 0.0:
				cross = f - 1 + (-za) / (zb - za)
				d = hand[f] - hand[f - 1]
				break
		var c := {"fps": int(fps)}
		if WINDOW.has(name):
			var a := maxi(0, int(cross) - int(WINDOW[name][0] * fps))
			var b := mini(frames.size() - 1, int(cross) + int(WINDOW[name][1] * fps))
			c.contact = snappedf((cross - a) / fps, 0.001)
			c.yaw = snappedf(rad_to_deg(atan2(-d.x, d.z)), 0.1)
			frames = frames.slice(a, b + 1)
		else:
			# The run: the frame with the left thigh furthest forward (ToonBody's stride phase pi/2).
			var fwd := 0
			for f in frames.size():
				if frames[f].thigh_l[0] < frames[fwd].thigh_l[0]:
					fwd = f
			c.left_forward = snappedf(fwd / fps, 0.001)
		c.frames = frames
		out[name] = c
		print(name, ": ", frames.size(), " frames kept of ", snappedf(an.length, 0.01), " s; ", c.keys().filter(func(x): return x != "frames").map(func(x): return "%s %s" % [x, c[x]]))
		scene.free()
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
