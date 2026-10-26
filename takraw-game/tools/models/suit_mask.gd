extends SceneTree
## Makes the officials' suit from the man's model: a mask over his texture saying, for each texel, how much is the
## suit's cloth (red: the jacket and trousers), the white shirt (green: its front, collar and cuffs), the tie (blue) and
## the shoes (alpha); the rest (his face, neck, hands, hair) stays his own. Each texel is classed by where it is on the
## body in its rest pose and which bones move it, so the suit follows the model's arms and legs in every pose.
##   godot --headless --path . -s tools/models/suit_mask.gd   (writes assets/models/man_suit.png)

const SIZE := 512
const OUT := "res://assets/models/man_suit.png"

const HEM := 0.84          # the jacket's hem (m above the soles): trousers below it
const SHOE_TOP := 0.105    # the shoes' tops
const COLLAR := [1.405, 1.47]   # the shirt's collar round the neck, from and to
const V_LOW := 1.16        # the jacket's opening: from here up to the collar, the shirt shows at the front
const V_HALF := [0.018, 0.085]  # half the opening's width, at its foot and at the collar
const TIE_HALF := [0.016, 0.011]   # half the tie's width, at its foot and at the knot
const CUFF := 0.05         # the shirt's cuff: this far up the arm from the wrist
const COLLAR_R := 0.072    # the collar's reach from the neck's middle (beyond it, the jacket's shoulders)


func _initialize() -> void:
	var sc: Node3D = (load("res://assets/models/man.glb") as PackedScene).instantiate()
	root.add_child(sc)
	var sk: Skeleton3D = sc.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = sk.find_children("*", "MeshInstance3D", true, false)[0]
	var a := mi.mesh.surface_get_arrays(0)
	var pos: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	var per := bones.size() / pos.size()   # bone influences a vertex
	# Each vertex's weight on the hands, the feet, the arms, the head and neck (the rest is the body and legs).
	var group := {}
	for b in mi.skin.get_bind_count():
		var n := String(mi.skin.get_bind_name(b)).trim_prefix("mixamorig_")
		if n.ends_with("Hand"):
			group[b] = 0
		elif n.ends_with("Foot") or n.ends_with("ToeBase"):
			group[b] = 1
		elif n.ends_with("Arm") or n.ends_with("ForeArm"):
			group[b] = 2
		elif n in ["Neck", "Head", "headfront"]:
			group[b] = 3
	var gw := []   # per vertex: Vector4(hand, foot, arm, head)
	for v in pos.size():
		var w := Vector4.ZERO
		for k in per:
			var g: int = group.get(bones[v * per + k], -1)
			if g >= 0:
				w[g] += weights[v * per + k]
		gw.append(w)
	# The wrists and which way the forearm runs from each, for the cuffs (the skeleton is in centimetres).
	var neck := sk.get_bone_global_rest(sk.find_bone("mixamorig_Neck")).origin * 0.01
	var wrists: Array[Vector3] = []
	var ups: Array[Vector3] = []
	for s in ["Left", "Right"]:
		var wr := sk.get_bone_global_rest(sk.find_bone("mixamorig_%sHand" % s)).origin * 0.01
		var el := sk.get_bone_global_rest(sk.find_bone("mixamorig_%sForeArm" % s)).origin * 0.01
		wrists.append(wr)
		ups.append((el - wr).normalized())
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var done := PackedByteArray()
	done.resize(SIZE * SIZE)
	for t in range(0, idx.size(), 3):
		var i0 := idx[t]
		var i1 := idx[t + 1]
		var i2 := idx[t + 2]
		var p0 := uv[i0] * SIZE
		var p1 := uv[i1] * SIZE
		var p2 := uv[i2] * SIZE
		var area := (p1 - p0).cross(p2 - p0)
		if absf(area) < 1e-9:
			continue
		var x0 := maxi(0, floori(minf(p0.x, minf(p1.x, p2.x))))
		var x1 := mini(SIZE - 1, ceili(maxf(p0.x, maxf(p1.x, p2.x))))
		var y0 := maxi(0, floori(minf(p0.y, minf(p1.y, p2.y))))
		var y1 := mini(SIZE - 1, ceili(maxf(p0.y, maxf(p1.y, p2.y))))
		for y in range(y0, y1 + 1):
			for x in range(x0, x1 + 1):
				var c := Vector2(x + 0.5, y + 0.5)
				var b0 := (p1 - c).cross(p2 - c) / area
				var b1 := (p2 - c).cross(p0 - c) / area
				var b2 := 1.0 - b0 - b1
				var e := -0.6 / sqrt(absf(area))   # a little past the edge, so neighbouring triangles meet
				if b0 < e or b1 < e or b2 < e:
					continue
				var p := pos[i0] * b0 + pos[i1] * b1 + pos[i2] * b2
				var n := (nrm[i0] * b0 + nrm[i1] * b1 + nrm[i2] * b2).normalized()
				var w: Vector4 = gw[i0] * b0 + gw[i1] * b1 + gw[i2] * b2
				img.set_pixel(x, y, _class(p, n, w, neck, wrists, ups))
				done[y * SIZE + x] = 1
	# Grow each piece a few texels into the empty space round it, so filtering never reaches past its edge.
	for pass_i in 6:
		var grown := done.duplicate()
		for y in SIZE:
			for x in SIZE:
				if done[y * SIZE + x]:
					continue
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + d
					if q.x >= 0 and q.y >= 0 and q.x < SIZE and q.y < SIZE and done[q.y * SIZE + q.x]:
						img.set_pixel(x, y, img.get_pixel(q.x, q.y))
						grown[y * SIZE + x] = 1
						break
		done = grown
	img.save_png(ProjectSettings.globalize_path(OUT))
	print("wrote ", OUT)
	quit()


## What the suit is at a point of the body (rest pose, metres, facing +Z): Color(cloth, shirt, tie, shoe).
func _class(p: Vector3, n: Vector3, w: Vector4, neck: Vector3, wrists: Array[Vector3], ups: Array[Vector3]) -> Color:
	var hand := w.x
	var foot := w.y
	var arm := w.z
	var head := w.w
	if hand > 0.5:
		return Color(0, 0, 0, 0)   # his own hands
	if arm > 0.5 or (p.y > HEM and absf(p.x) > 0.2):
		for i in wrists.size():
			var along := (p - wrists[i]).dot(ups[i])
			if along < 0.0 and p.distance_to(wrists[i]) < 0.12:
				return Color(0, 0, 0, 0)   # past the wrist: his hand
			if along < CUFF and p.distance_to(wrists[i]) < 0.1:
				return Color(0, 1, 0, 0)   # the shirt's cuff
		return Color(1, 0, 0, 0)   # the sleeve
	if p.y < SHOE_TOP or (foot > 0.5 and p.y < SHOE_TOP + 0.03):
		return Color(0, 0, 0, 1)
	var from_neck := Vector2(p.x - neck.x, p.z - neck.z).length()
	if p.y >= 1.52 or (p.y >= COLLAR[1] and from_neck < COLLAR_R + 0.02) or (head > 0.5 and p.y >= COLLAR[0]):
		return Color(0, 0, 0, 0)   # his neck and head
	if p.y >= COLLAR[0] and from_neck < COLLAR_R:
		return Color(0, 1, 0, 0)   # the collar
	if p.y >= V_LOW and n.z > 0.2 and p.z > 0.0:
		var f := clampf((p.y - V_LOW) / (COLLAR[0] - V_LOW), 0.0, 1.0)
		if absf(p.x) < lerpf(TIE_HALF[0], TIE_HALF[1], f) and p.y < COLLAR[0] - 0.012:
			return Color(0, 0, 1, 0)
		if absf(p.x) < lerpf(V_HALF[0], V_HALF[1], f):
			return Color(0, 1, 0, 0)
	return Color(1, 0, 0, 0)   # the jacket, and below the hem the trousers
