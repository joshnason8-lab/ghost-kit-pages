extends SceneTree
## Bakes a rigged character (a .glb or .fbx with a Mixamo-named skeleton: the owner's hurler, a Meshy auto-rig, a
## Mixamo or ActorCore character) onto the World Stage Games rig (addons/wsg_foundation/rig.gd):
##   1. poses its skeleton into the canonical rest (T-pose, arms straight out palms down, legs straight down, feet
##      flat) and skins the mesh into it with the character's own weights;
##   2. scales it to 1.80 m, soles at y = 0, facing +Z, and takes the rig's joints from its own;
##   3. makes the fingers: three-joint chains laid along the hand it really has (separate fingers or a mitten), the
##      hand's vertices weighted to them by where they lie, so the hand can close round a hurley or a stick;
##   4. spreads each arm's and leg's weights along the limb over the rig's twist and joint helpers (so the shoulder,
##      elbow, hip and knee keep their shape and the forearm does not candy-wrap);
##   5. cuts it down for phones (meshoptimizer, through Godot's LOD generator) and writes
##      <out>/<prefix>_hi.res, <prefix>_lo.res (ArrayMesh: rest = the canonical rest, bones = WsgRig.BONES order) and
##      <out>/<prefix>_rig.json (the joints, the hand's grip radius, what the bake measured).
## Run in a scratch Godot project where the model has been imported (tools/bake_character.sh does all of this):
##   godot --headless --path <scratch> -s bake_character.gd -- <res://model.glb> <out dir> <prefix> [tris_hi] [tris_lo]
## The output holds the character's own mesh only; no animation data.

const HEIGHT := 1.80
const ALIASES := {
	"Spine01": "Spine1", "Spine02": "Spine2", "Spine03": "Spine2", "neck": "Neck", "head": "Head", "Chest": "Spine1",
	"UpperChest": "Spine2", "LeftToe": "LeftToeBase", "RightToe": "RightToeBase", "LeftUpperArm": "LeftArm",
	"RightUpperArm": "RightArm", "LeftLowerArm": "LeftForeArm", "RightLowerArm": "RightForeArm",
	"LeftUpperLeg": "LeftUpLeg", "RightUpperLeg": "RightUpLeg", "LeftLowerLeg": "LeftLeg", "RightLowerLeg": "RightLeg",
	"LeftToes": "LeftToeBase", "RightToes": "RightToeBase", "headfront": "Head", "head_end": "Head", "HeadTop_End": "Head",
}
const CORE := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm",
	"LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot",
	"LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]

var sk: Skeleton3D
var canon := {}         # source bone index -> canonical name (or "")
var stance := []        # source bones posed into the canonical rest (skeleton space)
var report := {}
var finger_w := {}      # side -> {vertex: {finger bone: share of the hand's weight}}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var src: String = a[0]
	var out: String = a[1]
	var prefix: String = a[2]
	var tris := [int(a[3]) if a.size() > 3 else 6000, int(a[4]) if a.size() > 4 else 2000]
	var scene: Node = load(src).instantiate()
	sk = scene.find_children("*", "Skeleton3D", true, false)[0]
	var meshes := sk.find_children("*", "MeshInstance3D", true, false)
	for b in sk.get_bone_count():
		canon[b] = _canonical(sk.get_bone_name(b))
	for n in CORE:
		if not canon.values().has(n):
			push_error("the model has no bone for %s (bones: %s)" % [n, range(sk.get_bone_count()).map(func(i): return sk.get_bone_name(i))])
			quit(1)
			return
	_pose_stance()
	var body := _skin_to_stance(meshes)
	_square_hands(body)
	var joints := _joints(body)
	_flatten_feet(body, joints)
	_fingers(body, joints)
	joints = WsgRig.with_helpers(joints)
	var arrays := _weights(body, joints)
	# Every joint near its parent (a joint left at the origin skinned a finger 1.6 m long).
	for b in WsgRig.BONES:
		if b[1] != "" and joints.has(b[0]) and joints.has(b[1]):
			var gap := (joints[b[0]] as Vector3).distance_to(joints[b[1]])
			if gap > 0.7:
				printerr("bake_character: %s is %.2f m from its parent %s: not saved" % [b[0], gap, b[1]])
				quit(1)
				return
	var meta := {"joints": {}, "height": HEIGHT, "report": report}
	for k in joints:
		meta.joints[k] = _v(joints[k])
	for lod in 2:
		var mesh := _cut(arrays, tris[lod])
		var path := "%s/%s_%s.res" % [out, prefix, ["hi", "lo"][lod]]
		print(path, " ", error_string(ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)))
	var f := FileAccess.open("%s/%s_rig.json" % [out, prefix], FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t"))
	f.close()
	print(JSON.stringify(report))
	scene.free()
	quit()


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]


func _canonical(n: String) -> String:
	for p in ["mixamorig:", "mixamorig_", "mixamorig1:", "mixamorig1_", "mixamorig2_", "Bip01_", "CC_Base_"]:
		n = n.trim_prefix(p)
	n = ALIASES.get(n, n)
	return n if WsgRig.index(n) >= 0 else ""


func _find(name: String) -> int:
	for b in canon:
		if canon[b] == name:
			return b
	return -1


## The source skeleton posed into the canonical rest: upper and lower arms straight out along +-X, thighs and shins
## straight down; the feet keep the way they were modelled (flat); everything else follows its parent.
func _pose_stance() -> void:
	var straight := {"LeftArm": ["LeftForeArm", Vector3.RIGHT], "LeftForeArm": ["LeftHand", Vector3.RIGHT],
		"RightArm": ["RightForeArm", Vector3.LEFT], "RightForeArm": ["RightHand", Vector3.LEFT],
		"LeftUpLeg": ["LeftLeg", Vector3.DOWN], "LeftLeg": ["LeftFoot", Vector3.DOWN],
		"RightUpLeg": ["RightLeg", Vector3.DOWN], "RightLeg": ["RightFoot", Vector3.DOWN]}
	# Godot's skeleton space has +Z forward only if the model was made facing +Z; Mixamo and Meshy models are.
	stance = []
	for b in sk.get_bone_count():
		var par := sk.get_bone_parent(b)
		var t: Transform3D = (stance[par] * sk.get_bone_rest(b)) if par >= 0 else sk.get_bone_rest(b)
		var nm: String = canon[b]
		if straight.has(nm):
			var c := _find(straight[nm][0])
			var dir := (t * sk.get_bone_rest(c).origin - t.origin).normalized()
			t.basis = Basis(Quaternion(dir, straight[nm][1])) * t.basis
		elif nm in ["LeftFoot", "RightFoot"]:
			t.basis = sk.get_bone_global_rest(b).basis
		stance.append(t)


## Every vertex of every mesh skinned into the stance with the character's own weights (summed per canonical bone),
## then scaled to HEIGHT with the soles at y = 0 and the hips over the origin.
## Returns {pos, nrm, uv, w (Array of {bone name: weight}), index, surfaces}.
func _skin_to_stance(meshes: Array) -> Dictionary:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var has_uv2 := false
	var ws := []
	var index := PackedInt32Array()
	for mi: MeshInstance3D in meshes:
		var skin := mi.skin
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var mats := []
			var names := []
			for i in skin.get_bind_count():
				var bi := sk.find_bone(skin.get_bind_name(i)) if skin.get_bind_name(i) != &"" else skin.get_bind_bone(i)
				mats.append(stance[bi] * skin.get_bind_pose(i))
				var nm: String = canon[bi]
				if nm == "":
					# A bone the rig has no place for: its weight goes to the nearest named ancestor.
					var p := bi
					while p >= 0 and canon[p] == "":
						p = sk.get_bone_parent(p)
					nm = canon[p] if p >= 0 else "Hips"
				names.append(nm)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var ww: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var per := bs.size() / vs.size()
			var base := pos.size()
			for v in vs.size():
				var p := Vector3.ZERO
				var nn := Vector3.ZERO
				var acc := {}
				for j in per:
					var w := ww[v * per + j]
					if w <= 0.0:
						continue
					var m: Transform3D = mats[bs[v * per + j]]
					p += (m * vs[v]) * w
					nn += (m.basis * ns[v]) * w
					var nm: String = names[bs[v * per + j]]
					acc[nm] = float(acc.get(nm, 0.0)) + w
				pos.append(p)
				nrm.append(nn.normalized())
				ws.append(acc)
			uv.append_array(arr[Mesh.ARRAY_TEX_UV])
			# A second UV set (a game's own per-vertex data, e.g. Kabaddi's kit regions) is carried through unchanged.
			var u2 = arr[Mesh.ARRAY_TEX_UV2]
			if u2 is PackedVector2Array and (u2 as PackedVector2Array).size() == vs.size():
				uv2.append_array(u2)
				has_uv2 = true
			else:
				var z := PackedVector2Array()
				z.resize(vs.size())
				uv2.append_array(z)
			for i: int in arr[Mesh.ARRAY_INDEX]:
				index.append(base + i)
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for p in pos:
		lo = lo.min(p)
		hi = hi.max(p)
	var hips: Vector3 = stance[_find("Hips")].origin
	var shift := Vector3(hips.x, lo.y, hips.z)
	var k := HEIGHT / (hi.y - lo.y)
	for i in pos.size():
		pos[i] = (pos[i] - shift) * k
	report.source_height = snappedf(hi.y - lo.y, 0.001)
	report.vertices = pos.size()
	return {"pos": pos, "nrm": nrm, "uv": uv, "uv2": uv2 if has_uv2 else null, "w": ws, "index": index, "shift": shift, "k": k}


## The feet made to stand flat: some models (Meshy's officials) are made with the feet pitched up at the ankle, toes
## to the sky. Each foot's sole is measured on the mesh (its lowest point toward the toe against its lowest point
## at the heel) and the foot turned down about the ankle until only a shoe's own toe spring is left.
const TOE_SPRING := 4.0      # degrees of a shoe's sole rising to the toe, left as it is


func _flatten_feet(body: Dictionary, joints: Dictionary) -> void:
	for side in ["Left", "Right"]:
		var ank: Vector3 = joints[side + "Foot"]
		var pts := []
		for i in body.pos.size():
			var w := float(body.w[i].get(side + "Foot", 0.0)) + float(body.w[i].get(side + "ToeBase", 0.0))
			if w >= 0.5:
				pts.append(body.pos[i])
		if pts.size() < 10:
			continue
		var zmin := INF
		var zmax := -INF
		for p: Vector3 in pts:
			zmin = minf(zmin, p.z)
			zmax = maxf(zmax, p.z)
		var span := zmax - zmin
		var heel := INF
		var front := INF
		for p: Vector3 in pts:
			if p.z < zmin + span * 0.25:
				heel = minf(heel, p.y)
			elif p.z > zmin + span * 0.6 and p.z < zmin + span * 0.85:
				front = minf(front, p.y)
		var pitch := rad_to_deg(atan2(front - heel, span * 0.47))
		report[side + "_foot_pitch_deg"] = snappedf(pitch, 0.1)
		var fix := pitch - TOE_SPRING
		if absf(fix) < 4.0:
			continue
		var q := Quaternion(Vector3.RIGHT, deg_to_rad(fix))
		for i in body.pos.size():
			var w := float(body.w[i].get(side + "Foot", 0.0)) + float(body.w[i].get(side + "ToeBase", 0.0))
			if w <= 0.0:
				continue
			var p: Vector3 = body.pos[i] - ank
			body.pos[i] = ank + p.lerp(q * p, minf(w, 1.0))
			body.nrm[i] = body.nrm[i].slerp(q * body.nrm[i], minf(w, 1.0)).normalized()
		joints[side + "ToeBase"] = ank + q * ((joints[side + "ToeBase"] as Vector3) - ank)
		# Back on the ground: the lowest point of the turned foot at the soles' height.
		var low := INF
		for i in body.pos.size():
			if float(body.w[i].get(side + "Foot", 0.0)) + float(body.w[i].get(side + "ToeBase", 0.0)) >= 0.5:
				low = minf(low, body.pos[i].y)
		report[side + "_foot_turned_down_deg"] = snappedf(fix, 0.1)
		report[side + "_foot_low_after"] = snappedf(low, 0.003)
		print("turned the ", side, " foot down by ", snappedf(fix, 0.1), " degrees so it stands flat")


## The rig's body joints from the posed skeleton.
func _joints(body: Dictionary) -> Dictionary:
	var j := {}
	for n in CORE:
		j[n] = (stance[_find(n)].origin - body.shift) * body.k
	# Straight limbs exactly on their line (the posing leaves rounding errors of a millimetre).
	return j


## The hands turned about the forearm so the palms face down (the canonical rest): the flattest way through the
## hand's vertices is the palm's plane.
func _square_hands(body: Dictionary) -> void:
	for side in ["Left", "Right"]:
		var hb := _find(side + "Hand")
		var fb := _find(side + "ForeArm")
		var wrist: Vector3 = (stance[hb].origin - body.shift) * body.k
		var axis := Vector3.RIGHT if side == "Left" else Vector3.LEFT
		var pts := []
		for i in body.pos.size():
			if float(body.w[i].get(side + "Hand", 0.0)) > 0.5 and (body.pos[i] - wrist).dot(axis) > 0.02:
				pts.append(body.pos[i] - wrist)
		# Covariance across the arm (y, z): the palm's normal is its smallest axis.
		var syy := 0.0
		var szz := 0.0
		var syz := 0.0
		var my := 0.0
		var mz := 0.0
		for p: Vector3 in pts:
			my += p.y
			mz += p.z
		my /= maxf(1, pts.size())
		mz /= maxf(1, pts.size())
		for p: Vector3 in pts:
			syy += (p.y - my) * (p.y - my)
			szz += (p.z - mz) * (p.z - mz)
			syz += (p.y - my) * (p.z - mz)
		# The angle of the widest direction in the (z, y) plane, from +z: the palm's width should lie along z.
		var ang := 0.5 * atan2(2.0 * syz, szz - syy)
		report[side + "_palm_tilt_deg"] = snappedf(rad_to_deg(ang), 0.1)
		if absf(ang) < deg_to_rad(4.0):
			continue
		# Turn the hand (and its vertices) about the forearm's line by -ang.
		var q := Quaternion(Vector3.RIGHT, -ang)
		for i in body.pos.size():
			var w := float(body.w[i].get(side + "Hand", 0.0))
			if w <= 0.0:
				continue
			var p: Vector3 = body.pos[i] - wrist
			body.pos[i] = wrist + p.lerp(q * p, w)
			body.nrm[i] = body.nrm[i].slerp(q * body.nrm[i], w).normalized()
		print("turned the ", side, " hand by ", rad_to_deg(-ang), " degrees so the palm faces down")
		var _f := fb


## The fingers: laid along the hand the model really has. Past the knuckles a hand's fingers are separate pieces of
## mesh, so the hand's vertices beyond a cut across it fall into five connected pieces (four fingers and the thumb);
## the cut is moved along the hand until they do. Each piece's joints lie on its own centre line (rings of equal
## distance from its base, measured over the surface), and its vertices are weighted along it. A mitten (fewer
## pieces) falls back to the default layout, the fingers' weights by bands across the hand.
func _fingers(body: Dictionary, joints: Dictionary) -> void:
	# Welded connectivity of the whole mesh (glTF splits vertices at UV seams).
	var weld := PackedInt32Array()
	weld.resize(body.pos.size())
	var at := {}
	for i in body.pos.size():
		var key := Vector3i((body.pos[i] as Vector3) * 4000.0)
		if not at.has(key):
			at[key] = i
		weld[i] = at[key]
	for side in ["Left", "Right"]:
		var res := _finger_pieces(body, joints, side, weld)
		if res.is_empty():
			report[side + "_fingers"] = "mitten: default layout"
			var L: float = report[side + "_hand_len"]
			_default_fingers(joints, side, L)
			_band_weights(body, joints, side)


## Returns {} when the hand is not five pieces at any cut.
func _finger_pieces(body: Dictionary, joints: Dictionary, side: String, weld: PackedInt32Array) -> Dictionary:
	var sgn := 1.0 if side == "Left" else -1.0
	var wrist: Vector3 = joints[side + "Hand"]
	var hand := {}   # welded vertex -> u (along the hand)
	for i in body.pos.size():
		if float(body.w[i].get(side + "Hand", 0.0)) >= 0.4:
			hand[weld[i]] = ((body.pos[i] as Vector3) - wrist).x * sgn
	var nbr := {}
	var idx: PackedInt32Array = body.index
	for t in range(0, idx.size(), 3):
		for e in 3:
			var x := weld[idx[t + e]]
			var y := weld[idx[t + (e + 1) % 3]]
			if x != y and hand.has(x) and hand.has(y):
				if not nbr.has(x):
					nbr[x] = {}
				if not nbr.has(y):
					nbr[y] = {}
				nbr[x][y] = true
				nbr[y][x] = true
	var us: Array = hand.values()
	us.sort()
	var L: float = us[int(us.size() * 0.995)]
	report[side + "_hand_len"] = snappedf(L, 0.001)
	# Distance over the surface from the wrist: past the knuckles its level sets fall apart into the five digits,
	# however they are curled.
	var all := hand.keys()
	var from_wrist := _geodesic(body, nbr, all, all.filter(func(v): return hand[v] < 0.012))
	var G := 0.0
	for v in all:
		G = maxf(G, from_wrist[v])
	var geo := {}
	for v in all:
		geo[v] = from_wrist[v]
	var min_size := maxi(8, int(hand.size() * 0.006))
	# Follow the pieces as the cut moves out: a digit is a piece that, once split off, never splits again. Each is
	# taken whole from where it split off.
	var prev := {}       # vertex -> piece id at the last level
	var pieces_at := {}  # piece id -> {"verts", "level", "parent"}
	var kids := {}       # piece id -> number of significant pieces it split into
	var next_id := 0
	var counts := []
	for step in range(20, 99):
		var c := G * step / 100.0
		var comps := _components(geo, nbr, c).filter(func(x): return x.size() >= min_size)
		counts.append(comps.size())
		var by_parent := {}
		var cur := {}
		for comp: Array in comps:
			var par: int = prev.get(comp[0], -1)
			if not by_parent.has(par):
				by_parent[par] = []
			by_parent[par].append(comp)
		for par in by_parent:
			var list: Array = by_parent[par]
			if list.size() == 1 and par >= 0:
				for v in list[0]:
					cur[v] = par
				continue
			if par >= 0:
				kids[par] = list.size()
			for comp: Array in list:
				pieces_at[next_id] = {"verts": comp, "level": c, "parent": par}
				for v in comp:
					cur[v] = next_id
				next_id += 1
		prev = cur
	var found := []
	var cut := 0.0
	for id in pieces_at:
		if not kids.has(id) and pieces_at[id].parent >= 0:
			found.append(pieces_at[id].verts)
	found.sort_custom(func(x, y): return x.size() > y.size())
	report[side + "_finger_cuts"] = counts
	report[side + "_digits_found"] = found.size()
	if found.size() < 5:
		return {}
	found = found.slice(0, 5)
	cut = 0.0
	hand = geo
	# Each piece: its base (the vertices at the cut), its length over the surface, its side-to-side place.
	var pieces := []
	for comp: Array in found:
		var g0: float = comp.map(func(v): return hand[v]).min()
		var base := comp.filter(func(v): return hand[v] < g0 + 0.004)
		var dist := _geodesic(body, nbr, comp, base)
		var far := 0.0
		var mv := 0.0
		for v in comp:
			far = maxf(far, dist[v])
			mv += (body.pos[v] as Vector3).z
		pieces.append({"comp": comp, "dist": dist, "len": far, "v": mv / comp.size(),
			"base_u": comp.map(func(v): return hand[v]).min()})
	# The thumb: the piece that leaves the hand nearest the wrist (it is the lowest u even at the cut, being widest
	# there) - failing that the one furthest to the side.
	var thumb := 0
	var best := INF
	for i in pieces.size():
		var score: float = _ring(body, pieces[i], 0.0, 0.15).distance_to(wrist)
		if score < best:
			best = score
			thumb = i
	var th: Dictionary = pieces[thumb]
	pieces.remove_at(thumb)
	pieces.sort_custom(func(x, y): return x.v > y.v)
	# The thumb must be on the forward side (+z) with the palm down; a hand modelled palm-up has it behind.
	var palm_v := 0.0
	for pc in pieces:
		palm_v += pc.v / 4.0
	report[side + "_thumb_forward"] = th.v > palm_v
	if th.v < palm_v:
		pieces.reverse()
		push_warning("%s thumb is behind the fingers: the palm may face up (check the render)" % side)
	var order := ["Index", "Middle", "Ring", "Pinky"]
	pieces = _to_knuckles(body, nbr, geo, pieces, th)
	var fw := {}
	var lens := []
	for i in 5:
		var pc: Dictionary = th if i == 0 else pieces[i - 1]
		var f: String = "Thumb" if i == 0 else order[i - 1]
		var names := [side + "Hand" + f + "1", side + "Hand" + f + "2", side + "Hand" + f + "3"]
		var marks := [0.0, 0.42, 0.72] if f != "Thumb" else [0.0, 0.38, 0.7]
		for k in 3:
			var at := _ring(body, pc, marks[k], 0.06)
			if at == Vector3.INF:
				# Nothing there: on along the finger from the joints before it.
				var back: Vector3 = wrist if k == 0 else joints[names[k - 1]]
				var before: Vector3 = wrist if k < 2 else joints[names[k - 2]]
				var along := (back - before).normalized() if back != before else (back - wrist).normalized()
				at = back + along * maxf(pc.len, 0.03) * 0.3
				push_warning("%s: no vertices at %.0f%% of the finger: placed along it" % [names[k], marks[k] * 100.0])
			joints[names[k]] = at
		# The thumb's knuckle sits a little back inside the palm from where it leaves it (the fingers' pieces already
		# reach back to theirs: _to_knuckles).
		if i == 0:
			var dir: Vector3 = ((joints[names[1]] as Vector3) - (joints[names[0]] as Vector3)).normalized()
			joints[names[0]] = (joints[names[0]] as Vector3) - dir * 0.012
		lens.append(snappedf(pc.len, 0.001))
		var nodes := [[side + "Hand", -0.12], [names[0], 0.12], [names[1], 0.5], [names[2], 0.82]]
		for v in pc.comp:
			var g: float = pc.dist[v] / maxf(pc.len, 0.001)
			fw[v] = _hats(nodes, g)
	report[side + "_finger_lengths"] = lens
	# Every vertex (welded twins too) takes its welded vertex's share; the hand's own name is what is left.
	var out := {}
	for i in body.pos.size():
		if fw.has(weld[i]):
			var d: Dictionary = fw[weld[i]].duplicate()
			d.erase(side + "Hand")
			out[i] = d
	finger_w[side] = out
	return {"ok": true}


## The four fingers' pieces reached back to their knuckles. A hand whose fingers are joined part of the way (a Meshy
## hand, a curled one) splits into its pieces only near the tips, and fingers whose first joint sat there bent from
## their middle - the skin between still on the hand - and spiked when they closed. Each finger's knuckle is
## KNUCKLE_AT of the way (over the surface) from the wrist to its tip, or a little behind where its piece splits off
## if that is nearer; the joined skin out from there goes to the finger it lies in line with across the hand.
## Returns the pieces with comp, dist (over the surface from the knuckle) and len made so.
const KNUCKLE_AT := 0.52


static func _to_knuckles(body: Dictionary, nbr: Dictionary, geo: Dictionary, pieces: Array, thumb: Dictionary) -> Array:
	var gk := []
	var g0s := []
	var tips := []
	var lo := INF
	for pc: Dictionary in pieces:
		var g0 := INF
		var tip := 0.0
		for v in pc.comp:
			g0 = minf(g0, geo[v])
			tip = maxf(tip, geo[v])
		var k := minf(g0 - 0.012, tip * KNUCKLE_AT)
		gk.append(k)
		g0s.append(g0)
		tips.append(tip)
		lo = minf(lo, k)
	# Across the hand (z, the palm down), each finger where its piece leaves the hand.
	var zs := []
	for i in pieces.size():
		var sum := 0.0
		var n := 0
		for v in pieces[i].comp:
			if float(geo[v]) < g0s[i] + 0.006:
				sum += (body.pos[v] as Vector3).z
				n += 1
		zs.append(sum / maxf(n, 1))
	var label := {}
	for i in pieces.size():
		for v in pieces[i].comp:
			label[v] = i
	var skip := {}
	for v in thumb.comp:
		skip[v] = true
	for v in geo:
		if label.has(v) or skip.has(v) or float(geo[v]) < lo:
			continue
		var best := 0
		for i in pieces.size():
			if absf((body.pos[v] as Vector3).z - zs[i]) < absf((body.pos[v] as Vector3).z - zs[best]):
				best = i
		label[v] = best
	var out := []
	for i in pieces.size():
		out.append({"comp": [], "dist": {}, "v": pieces[i].v})
	for v in label:
		var i: int = label[v]
		if float(geo[v]) >= gk[i]:
			out[i].comp.append(v)
	# (The knuckle no nearer the wrist than the finger's first vertices: a joint where the finger has none was placed
	# by guesswork.)
	for i in out.size():
		var k := INF
		for v in out[i].comp:
			k = minf(k, geo[v])
		for v in out[i].comp:
			out[i].dist[v] = float(geo[v]) - k
		out[i].len = maxf(tips[i] - k, 0.01)
	return out


## Connected pieces of the hand beyond u = c.
static func _components(hand: Dictionary, nbr: Dictionary, c: float) -> Array:
	var seen := {}
	var comps := []
	for v in hand:
		if hand[v] <= c or seen.has(v):
			continue
		var comp := [v]
		seen[v] = true
		var i := 0
		while i < comp.size():
			for w in nbr.get(comp[i], {}):
				if not seen.has(w) and hand[w] > c:
					seen[w] = true
					comp.append(w)
			i += 1
		comps.append(comp)
	return comps


## Distance over the surface from the base vertices to each vertex of the piece (Dijkstra on the edges).
static func _geodesic(body: Dictionary, nbr: Dictionary, comp: Array, base: Array) -> Dictionary:
	var inside := {}
	for v in comp:
		inside[v] = true
	var dist := {}
	var open := []
	for v in base:
		dist[v] = 0.0
		open.append(v)
	# Small pieces (a few hundred vertices): a simple label-correcting sweep is plenty.
	while not open.is_empty():
		var v = open.pop_back()
		for w in nbr.get(v, {}):
			if not inside.has(w):
				continue
			var d: float = dist[v] + (body.pos[v] as Vector3).distance_to(body.pos[w])
			if d < float(dist.get(w, INF)) - 1e-6:
				dist[w] = d
				open.append(w)
	for v in comp:
		if not dist.has(v):
			dist[v] = 0.0
	return dist


## The centre of the ring of a piece's vertices at fraction t (+- half a width) of its length from its base.
## The middle of a finger's vertices at t (0 the knuckle, 1 the tip) of its length; INF when there are none even in a
## wider band (it was the origin: a joint 1.6 m from its hand, and the finger's skin stretched to it when posed).
static func _ring(body: Dictionary, pc: Dictionary, t: float, width: float) -> Vector3:
	for w in [width, width * 2.0, width * 4.0]:
		var sum := Vector3.ZERO
		var n := 0
		var lo: float = (t - w) * pc.len
		var hi: float = (t + w) * pc.len
		for v in pc.comp:
			var d: float = pc.dist[v]
			if d >= lo and d <= hi:
				sum += body.pos[v]
				n += 1
		if n > 0:
			return sum / n
	return Vector3.INF


## Mitten fallback: the hand's vertices past the knuckles shared over the four fingers by where they lie across it.
func _band_weights(body: Dictionary, joints: Dictionary, side: String) -> void:
	var sgn := 1.0 if side == "Left" else -1.0
	var k1: Vector3 = joints[side + "HandMiddle1"]
	var out := {}
	var order := ["Index", "Middle", "Ring", "Pinky"]
	for i in body.pos.size():
		if float(body.w[i].get(side + "Hand", 0.0)) < 0.4:
			continue
		var p: Vector3 = body.pos[i]
		var along := (p - k1).x * sgn
		if along < -0.01:
			continue
		var best := ""
		var bd := INF
		for f in order:
			var d := absf(p.z - (joints[side + "Hand" + f + "1"] as Vector3).z)
			if d < bd:
				bd = d
				best = f
		var j1: Vector3 = joints[side + "Hand" + best + "1"]
		var j3: Vector3 = joints[side + "Hand" + best + "3"]
		var g := (p - j1).x * sgn / maxf(0.001, (j3 - j1).x * sgn * 1.3)
		var nodes := [[side + "Hand", -0.12], [side + "Hand" + best + "1", 0.12], [side + "Hand" + best + "2", 0.5],
			[side + "Hand" + best + "3", 0.82]]
		var d := _hats(nodes, g)
		d.erase(side + "Hand")
		out[i] = d
	finger_w[side] = out


## The rig's default finger layout, scaled to this hand's length.
func _default_fingers(joints: Dictionary, side: String, L: float) -> void:
	var d := WsgRig.default_joints()
	var k := L / 0.19
	var w: Vector3 = d[side + "Hand"]
	for b in WsgRig.BONES:
		if b[0].begins_with(side + "Hand") and WsgRig.is_finger(b[0]):
			joints[b[0]] = (joints[side + "Hand"] as Vector3) + ((d[b[0]] as Vector3) - w) * k


## Final weights: the character's own, by canonical bone; then each limb's share spread along it over the rig's
## helpers (ARM_CHAIN / LEG_CHAIN by the chain parameter s), the hand's over the fingers (finger_w); the four
## strongest kept. Vertex colour: the rest position (rgb over a 1.6 x 2.0 x 1.6 box) and a = 1 below the knee (the
## socks), as the games' kit shaders read it.
func _weights(body: Dictionary, joints: Dictionary) -> Array:
	var n: int = body.pos.size()
	var bones := PackedInt32Array()
	bones.resize(n * 4)
	var wts := PackedFloat32Array()
	wts.resize(n * 4)
	var col := PackedColorArray()
	col.resize(n)
	var limbs := []
	for side in ["Left", "Right"]:
		limbs.append([side, ["Arm", "ForeArm", "Hand"], WsgRig.ARM_CHAIN, side + "Arm", side + "ForeArm", side + "Hand"])
		limbs.append([side, ["UpLeg", "Leg"], WsgRig.LEG_CHAIN, side + "UpLeg", side + "Leg", side + "Foot"])
	var hist := {}
	for v in n:
		var p: Vector3 = body.pos[v]
		var src: Dictionary = body.w[v]
		var out := {}
		for k in src:
			out[k] = float(src[k])
		for limb in limbs:
			var side: String = limb[0]
			var a: Vector3 = joints[limb[3]]
			var m: Vector3 = joints[limb[4]]
			var e: Vector3 = joints[limb[5]]
			var s := _chain_s(p, a, m, e)
			var mass := 0.0
			for b in limb[1]:
				# The hand's own share stays on the hand past the wrist (a curled hand's fingertips come back to it).
				if b == "Hand" and s >= 1.97:
					continue
				mass += float(out.get(side + b, 0.0))
				out.erase(side + b)
			if mass <= 0.0:
				continue
			# Loose cloth well clear of the thigh (a long coat's skirt) hangs from the hips rather than going with the
			# leg (the umpires' coats lifted with their knees).
			if limb[3].ends_with("UpLeg") and s < 1.0:
				var off := _seg_dist(p, a, m)
				var loose := smoothstep(SKIRT_R, SKIRT_R + 0.05, off) * 0.8
				if loose > 0.0:
					out["Hips"] = float(out.get("Hips", 0.0)) + mass * loose
					mass *= 1.0 - loose
			var spread := _hats(limb[2], s)
			for b in spread:
				var nm: String = side + b
				out[nm] = float(out.get(nm, 0.0)) + mass * float(spread[b])
		# The hand's share over the fingers.
		for side in ["Left", "Right"]:
			var hw := float(out.get(side + "Hand", 0.0))
			if hw > 0.0 and finger_w.has(side) and finger_w[side].has(v):
				var fw: Dictionary = finger_w[side][v]
				var left := 1.0
				for f in fw:
					out[f] = float(out.get(f, 0.0)) + hw * float(fw[f])
					left -= float(fw[f])
				out[side + "Hand"] = hw * maxf(0.0, left)
		var ks := out.keys().filter(func(x): return float(out[x]) > 0.0005)
		ks.sort_custom(func(x, y): return out[x] > out[y])
		var tot := 0.0
		for j in mini(4, ks.size()):
			tot += float(out[ks[j]])
		for j in 4:
			bones[v * 4 + j] = WsgRig.index(ks[j]) if j < ks.size() else 0
			wts[v * 4 + j] = float(out[ks[j]]) / tot if j < ks.size() else 0.0
		if ks.size() > 0:
			hist[ks[0]] = int(hist.get(ks[0], 0)) + 1
		var below := 1.0 if p.y < (joints["LeftLeg"] as Vector3).y - 0.04 else 0.0
		col[v] = Color(clampf(p.x / 1.6 + 0.5, 0, 1), clampf(p.y / 2.0, 0, 1), clampf(p.z / 1.6 + 0.5, 0, 1), below)
	report.main_bone_vertices = hist
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = body.pos
	out[Mesh.ARRAY_NORMAL] = body.nrm
	out[Mesh.ARRAY_TEX_UV] = body.uv
	if body.get("uv2") != null:
		out[Mesh.ARRAY_TEX_UV2] = body.uv2
	out[Mesh.ARRAY_COLOR] = col
	out[Mesh.ARRAY_BONES] = bones
	out[Mesh.ARRAY_WEIGHTS] = wts
	out[Mesh.ARRAY_INDEX] = body.index
	return out


const SKIRT_R := 0.115       # m from the thigh's line: beyond this a leg's skin is loose cloth (a coat, a skirt)
const SLEEVE_R := 0.07       # m from the upper arm's line: beyond this an arm's skin is a loose sleeve


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var d := b - a
	var t := clampf((p - a).dot(d) / d.length_squared(), 0.0, 1.0)
	return p.distance_to(a + d * t)


## Where p lies along a straight two-segment limb a-m-e: 0 at a, 1 at m, 2 at e (beyond, past the ends).
static func _chain_s(p: Vector3, a: Vector3, m: Vector3, e: Vector3) -> float:
	var d1 := m - a
	var t1 := (p - a).dot(d1) / d1.length_squared()
	if t1 <= 1.0:
		return t1
	var d2 := e - m
	return 1.0 + (p - m).dot(d2) / d2.length_squared()


## Tent functions over the chain's nodes at s (they sum to 1; flat past either end).
static func _hats(chain: Array, s: float) -> Dictionary:
	if s <= chain[0][1]:
		return {chain[0][0]: 1.0}
	for i in range(1, chain.size()):
		if s <= chain[i][1]:
			var t: float = (s - chain[i - 1][1]) / (chain[i][1] - chain[i - 1][1])
			t = t * t * (3.0 - 2.0 * t)
			return {chain[i - 1][0]: 1.0 - t, chain[i][0]: t}
	return {chain[-1][0]: 1.0}


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
	var has_uv2: bool = a[Mesh.ARRAY_TEX_UV2] != null
	var col := PackedColorArray()
	var bs := PackedInt32Array()
	var ws := PackedFloat32Array()
	for v in keep:
		vs.append(a[Mesh.ARRAY_VERTEX][v])
		ns.append(a[Mesh.ARRAY_NORMAL][v])
		uv.append(a[Mesh.ARRAY_TEX_UV][v])
		if has_uv2:
			uv2.append(a[Mesh.ARRAY_TEX_UV2][v])
		col.append(a[Mesh.ARRAY_COLOR][v])
		for j in 4:
			bs.append(a[Mesh.ARRAY_BONES][v * 4 + j])
			ws.append(a[Mesh.ARRAY_WEIGHTS][v * 4 + j])
	out[Mesh.ARRAY_VERTEX] = vs
	out[Mesh.ARRAY_NORMAL] = ns
	out[Mesh.ARRAY_TEX_UV] = uv
	if has_uv2:
		out[Mesh.ARRAY_TEX_UV2] = uv2
	out[Mesh.ARRAY_COLOR] = col
	out[Mesh.ARRAY_BONES] = bs
	out[Mesh.ARRAY_WEIGHTS] = ws
	out[Mesh.ARRAY_INDEX] = idx
	# Tangents (MikkTSpace, as Blender bakes normal maps against: tools/blender), for a normal map on the cut.
	var st := SurfaceTool.new()
	st.create_from_arrays(out)
	st.generate_tangents()
	out = st.commit_to_arrays()
	var cut := ImporterMesh.new()
	cut.add_surface(Mesh.PRIMITIVE_TRIANGLES, out)
	cut.generate_lods(25.0, 60.0, [])
	var lods := []
	for l in cut.get_surface_lod_count(0):
		lods.append(cut.get_surface_lod_indices(0, l).size() / 3)
	print(" cut to ", idx.size() / 3, " triangles, ", keep.size(), " vertices; levels ", lods)
	report["tris_%d" % tris] = [idx.size() / 3, lods]
	return cut.get_mesh()
