extends SceneTree
## The rig's shape tests: a baked character in extreme poses, its mesh skinned on the CPU exactly as the GPU does.
##   godot --headless --path . -s tests/rig_test.gd -- [char dir] [prefix]      (default: tests/character, hero)
## Fails (exit 1) on:
##   candy-wrap: a twisted forearm or upper arm thinning (the skin's distance from the bone falling) at its middle;
##   collapsing joints: the elbow, knee, shoulder or hip losing volume when bent hard;
##   inverted elbows or knees, and toes pointing up, even when the pose asks for them (the drivers must refuse);
##   a hand that cannot close on a handle, or whose fingers go through it.
## Every shape check is also run with the rig's helpers switched off, and must FAIL there: that proves the check can
## see the fault it is there for.

const R := 0.016   # a hurley's handle: 3.2 cm across
const KEEP := 0.85  # a joint's skin must keep this much of its distance from the bones when bent or twisted hard

var body: WsgBody
var src := []          # the mesh's rest positions
var bones := PackedInt32Array()
var weights := PackedFloat32Array()
var tris := PackedInt32Array()
var samples := []      # points on the mesh's triangles: [[i0, i1, i2], rest position, [w0, w1, w2]]
var failures := []
var lines := []


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var dir: String = a[0] if a.size() > 0 else "res://tests/character"
	var prefix: String = a[1] if a.size() > 1 else "hero"
	var ch := WsgBody.load_character(dir, prefix)
	body = WsgBody.new(ch)
	root.add_child(body)
	var arr: Array = (ch.meshes[0] as ArrayMesh).surface_get_arrays(0)
	src = Array(arr[Mesh.ARRAY_VERTEX])
	bones = arr[Mesh.ARRAY_BONES]
	weights = arr[Mesh.ARRAY_WEIGHTS]
	tris = arr[Mesh.ARRAY_INDEX]
	await process_frame
	var poses := WsgTestPoses.all()
	# name, pose, regions that must keep their shape
	var checks := [
		["arms_up", ["shoulder", "upper_arm"]],
		["arms_down", ["shoulder", "upper_arm"]],
		["elbows_bent", ["elbow", "forearm"]],
		["wrist_twist", ["forearm", "wrist"]],
		["arm_twist", ["upper_arm", "elbow"]],
		["crouch", ["knee", "hip", "thigh"]],
		["lunge", ["knee", "hip"]],
	]
	for helpers_on in [true, false]:
		body.helpers.active = helpers_on
		var tag := "" if helpers_on else " [helpers off]"
		var any_fail := false
		for c in checks:
			var posed := await _skin(poses[c[0]])
			for region in c[1]:
				for side in ["Left", "Right"]:
					var m := _region_keep(posed, side, region)
					var ok: bool = m[0] >= KEEP
					lines.append("%-12s %-5s %-9s keeps %3d%% of its girth (%d points)  %s%s" % [c[0], side, region, roundi(m[0] * 100), m[1], ("ok" if ok else "FAIL") if helpers_on else ("-" if ok else "fault seen"), tag])
					if not ok:
						any_fail = true
						if helpers_on:
							failures.append("%s %s %s: keeps only %d%% of its girth" % [c[0], side, region, roundi(m[0] * 100)])
		if not helpers_on and not any_fail:
			failures.append("with the helpers off every shape check still passed: the checks cannot see candy-wrap or collapse")
	body.helpers.active = true
	await _hinges(poses)
	await _grip(poses)
	for l in lines:
		print(l)
	if failures.is_empty():
		print("RIG TEST: PASS")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)
		print("RIG TEST: FAIL (%d)" % failures.size())
		quit(1)


## Poses the body and returns {"pos": skinned vertices, "g": bone globals} once the skeleton's modifiers have run.
func _skin(pose: Dictionary, extra := Callable()) -> Dictionary:
	WsgTestPoses.apply(body, pose)
	if extra.is_valid():
		extra.call()
	# (skeleton_updated fires more than once a frame: wait for the next frame's, which has run this pose's modifiers.)
	await process_frame
	await body.skeleton.skeleton_updated
	var sk := body.skeleton
	var mats := []
	var g := {}
	for i in sk.get_bone_count():
		var gp := sk.get_bone_global_pose(i)
		g[sk.get_bone_name(i)] = gp
		mats.append(gp * Transform3D(Basis.IDENTITY, -sk.get_bone_global_rest(i).origin))
	var out := PackedVector3Array()
	out.resize(src.size())
	for v in src.size():
		var p := Vector3.ZERO
		for j in 4:
			var w := weights[v * 4 + j]
			if w > 0.0:
				p += (mats[bones[v * 4 + j]] as Transform3D) * (src[v] as Vector3) * w
		out[v] = p
	# Leave the skeleton's update before anything sets a pose again: setting one from inside skeleton_updated is
	# undone when the skeleton puts back the poses it had before its modifiers ran.
	await process_frame
	return {"pos": out, "g": g}


## Each region: the three points of the chain it bends or twists on (bone names; "^" before one: a point 22 cm
## above that bone's joint, carried by its parent - the pelvis over the hip), its span on that chain (0 the first
## point, 1 the joint, 2 the last), whether it bends (only the outside of the bend must keep its distance from the
## bone: the inside folds) or twists (the whole ring must), and the bones whose skin it is.
const REGIONS := {
	"shoulder": [["Shoulder", "Arm", "ForeArm"], 0.8, 1.25, "bend"],
	"upper_arm": [["Arm", "ForeArm", "Hand"], 0.3, 0.65, "twist"],
	"elbow": [["Arm", "ForeArm", "Hand"], 0.8, 1.2, "bend"],
	"forearm": [["Arm", "ForeArm", "Hand"], 1.3, 1.7, "twist"],
	"wrist": [["Arm", "ForeArm", "Hand"], 1.75, 2.0, "twist"],
	"hip": [["^UpLeg", "UpLeg", "Leg"], 0.85, 1.2, "bend"],
	"thigh": [["UpLeg", "Leg", "Foot"], 0.3, 0.65, "twist"],
	"knee": [["UpLeg", "Leg", "Foot"], 0.85, 1.15, "bend"],
}


## How much of its distance from the bones the skin keeps in a region (the worst-kept tenth excluded as noise):
## [mean ratio (stretching capped at 1, so it cannot hide thinning)].
func _region_keep(posed: Dictionary, side: String, region: String) -> Array:
	var spec: Array = REGIONS[region]
	var r := []
	var p := []
	for n: String in spec[0]:
		r.append(_point(side, n, {}))
		p.append(_point(side, n, posed.g))
	var arm: bool = spec[0][1] in ["Arm", "ForeArm"]
	var inner := Vector3.ZERO
	if spec[3] == "bend":
		var b: Vector3 = (p[0] - p[1]).normalized() + (p[2] - p[1]).normalized()
		inner = b.normalized() if b.length() > 0.05 else Vector3.ZERO
	var ratios := []
	if samples.is_empty():
		_make_samples()
	for smp: Array in samples:
		var q: Vector3 = smp[1]
		var sp := _chain_s(q, r[0], r[1], r[2])
		if sp < spec[1] or sp > spec[2]:
			continue
		var lw := 0.0
		for c in 3:
			var v: int = smp[0][c]
			for k in 4:
				var n: String = WsgRig.BONES[bones[v * 4 + k]][0]
				var limb := (n.contains("Arm") or n.contains("Elbow") or n == side + "ShoulderHelper" or n == side + "Hand") if arm \
					else (n.contains("Leg") or n.contains("Knee") or n.contains("Hip"))
				if n.begins_with(side) and limb:
					lw += weights[v * 4 + k] * float(smp[2][c])
		if lw < 0.5:
			continue
		var r0 := _seg_dist(q, r[0], r[1], r[2])
		if r0 < 0.015:
			continue
		var q1: Vector3 = posed.pos[smp[0][0]] * smp[2][0] + posed.pos[smp[0][1]] * smp[2][1] + posed.pos[smp[0][2]] * smp[2][2]
		if inner != Vector3.ZERO and (q1 - (p[1] as Vector3)).dot(inner) > -0.01:
			continue
		ratios.append(minf(1.0, _seg_dist(q1, p[0], p[1], p[2]) / r0))
	if ratios.size() < 5:
		return [0.0, ratios.size()]
	ratios.sort()
	var keep := ratios.slice(int(ratios.size() * 0.1))
	var mean := 0.0
	for x in keep:
		mean += x
	return [mean / keep.size(), ratios.size()]


## Seven points on every triangle (its middle, and toward each corner and each edge): the surface as drawn, which is
## what has to keep its shape - a coarse mesh has few vertices at a joint.
func _make_samples() -> void:
	var bary := [[1.0 / 3, 1.0 / 3, 1.0 / 3], [0.6, 0.2, 0.2], [0.2, 0.6, 0.2], [0.2, 0.2, 0.6], [0.45, 0.45, 0.1],
		[0.1, 0.45, 0.45], [0.45, 0.1, 0.45]]
	for t in range(0, tris.size(), 3):
		var ids := [tris[t], tris[t + 1], tris[t + 2]]
		for b in bary:
			samples.append([ids, (src[ids[0]] as Vector3) * b[0] + (src[ids[1]] as Vector3) * b[1] + (src[ids[2]] as Vector3) * b[2], b])


## A chain point in the rest (g empty) or posed (g: bone globals).
func _point(side: String, n: String, g: Dictionary) -> Vector3:
	var above := n.begins_with("^")
	var name := side + n.trim_prefix("^")
	var j: Vector3 = body.joints[name]
	if not above:
		return j if g.is_empty() else (g[name] as Transform3D).origin
	var par: String = WsgRig.parent_name(name)
	var rest := j + Vector3(0, 0.22, 0)
	if g.is_empty():
		return rest
	return (g[par] as Transform3D) * (rest - (body.joints[par] as Vector3))


static func _chain_s(p: Vector3, a: Vector3, m: Vector3, e: Vector3) -> float:
	var d1 := m - a
	var t1 := (p - a).dot(d1) / d1.length_squared()
	if t1 <= 1.0:
		return t1
	var d2 := e - m
	return 1.0 + (p - m).dot(d2) / d2.length_squared()


static func _seg_dist(p: Vector3, a: Vector3, m: Vector3, e: Vector3) -> float:
	return minf(_dist_seg(p, a, m), _dist_seg(p, m, e))


static func _dist_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var d := b - a
	var t := clampf((p - a).dot(d) / d.length_squared(), 0.0, 1.0)
	return p.distance_to(a + d * t)


## Elbows and knees bend only the right way and the ankles stay in range, whatever the pose asks; with the
## normalising driver off, the same pose must show the faults (so the check can see them).
func _hinges(poses: Dictionary) -> void:
	for on in [true, false]:
		body.normalize.active = on
		var bad := []
		for name in ["broken", "elbows_bent", "crouch", "lunge", "arms_up"]:
			var posed := await _skin(poses[name])
			for side in ["Left", "Right"]:
				var el := _bend(posed.g, side + "Arm", side + "ForeArm", side + "Hand", Vector3.DOWN if side == "Left" else Vector3.UP)
				var kn := _bend(posed.g, side + "UpLeg", side + "Leg", side + "Foot", Vector3.RIGHT)
				var toe := _toe_up(posed.g, side)
				var tag := "" if on else " [normalize off]"
				lines.append("%-12s %-5s elbow %6.1f  knee %6.1f  toes up %5.1f deg%s" % [name, side, el, kn, toe, tag])
				if el < -3.0:
					bad.append("%s %s elbow bent backwards %.1f deg" % [name, side, el])
				if kn < -3.0:
					bad.append("%s %s knee bent backwards %.1f deg" % [name, side, kn])
				if toe > body.normalize.ankle_up + 1.0:
					bad.append("%s %s toes pointing up %.1f deg past the shin's square" % [name, side, toe])
		if on:
			failures.append_array(bad)
		elif bad.is_empty():
			failures.append("with the normaliser off the broken pose still passed: the hinge check cannot see it")
	body.normalize.active = true


## The hinge's bend in degrees (+: the right way), from the joints' places and the parent's hinge axis.
func _bend(g: Dictionary, a: String, b: String, c: String, axis_local: Vector3) -> float:
	var u: Vector3 = (g[b].origin - g[a].origin).normalized()
	var f: Vector3 = (g[c].origin - g[b].origin).normalized()
	var axis: Vector3 = (g[a].basis * axis_local).normalized()
	return rad_to_deg(u.signed_angle_to(f, axis))


## How far the toes are cocked up past square to the shin (degrees; the foot's rest is square to it).
func _toe_up(g: Dictionary, side: String) -> float:
	var shin: Basis = g[side + "Leg"].basis
	var foot: Basis = g[side + "Foot"].basis
	var local := (shin.inverse() * foot).get_euler(EULER_ORDER_YXZ)
	return -rad_to_deg(local.x)


## The hands close round a 3.2 cm handle: every fingertip comes round to it, no finger goes through it. An open
## hand must fail the closing check.
func _grip(poses: Dictionary) -> void:
	for closed in [true, false]:
		var posed := await _skin(poses.arms_down, func():
			if closed:
				body.grip("Left", R)
				body.grip("Right", R))
		var bad := []
		for side in ["Left", "Right"]:
			var hand: Transform3D = posed.g[side + "Hand"]
			var c := hand * (WsgGrip.axis_point(body.joints, side, R) - (body.joints[side + "Hand"] as Vector3))
			var ax := (hand.basis * Vector3.BACK).normalized()
			var deepest := INF
			var finger_ids := {}
			for f in ["Index", "Middle", "Ring", "Pinky"]:
				for k in 3:
					finger_ids[WsgRig.index(side + "Hand" + f + str(k + 1))] = f
			var tips := {}
			for v in src.size():
				var b := bones[v * 4]
				if weights[v * 4] < 0.5 or not finger_ids.has(b):
					continue
				var d: Vector3 = posed.pos[v] - c
				var r := (d - ax * d.dot(ax)).length()
				deepest = minf(deepest, r)
				if WsgRig.BONES[b][0].ends_with("3"):
					var f: String = finger_ids[b]
					tips[f] = minf(float(tips.get(f, INF)), r)
			var far := 0.0
			for f in tips:
				far = maxf(far, tips[f])
			lines.append("grip %-5s %-6s fingertips within %.1f cm of the handle's surface; deepest finger %.1f cm inside it" % [side, "closed" if closed else "open", (far - R) * 100.0, maxf(0.0, R - deepest) * 100.0])
			if far > R + 0.025:
				bad.append("%s hand does not close: a fingertip is %.1f cm off the handle" % [side, (far - R) * 100.0])
			if closed and deepest < R - 0.007:
				bad.append("%s hand: a finger goes %.1f cm into the handle" % [side, (R - deepest) * 100.0])
		if closed:
			failures.append_array(bad)
		elif bad.is_empty():
			failures.append("an open hand passed the grip check: it cannot tell open from closed")
