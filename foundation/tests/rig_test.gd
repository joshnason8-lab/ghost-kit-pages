extends SceneTree
## The rig's shape tests: a baked character in extreme poses, its mesh skinned on the CPU exactly as the GPU does.
##   godot --headless --path . -s tests/rig_test.gd -- [char dir] [prefix]      (default: tests/character, hero)
## Fails (exit 1) on:
##   candy-wrap: a twisted forearm or upper arm thinning (the skin's distance from the bone falling) at its middle;
##   collapsing joints: the elbow, knee, shoulder or hip losing volume when bent hard;
##   inverted elbows or knees, and toes pointing up, even when the pose asks for them (the drivers must refuse);
##   a hand that cannot close on a handle, or whose fingers go through it;
##   loose clothes that hang from an arm held out (a wing) or rise with the arms up.
## Every shape check is also run with the rig's helpers switched off, and must FAIL there: that proves the check can
## see the fault it is there for.

const R := 0.016   # a hurley's handle: 3.2 cm across
const BALL_R := 0.112   # a netball (WsgGrip.solve_sphere)
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
		["feet_turned", ["shin"]],
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
	await _cloth(poses)
	_soles()
	await _hinges(poses)
	await _grip(poses)
	await _grip_sphere(poses)
	await _torso()
	await _planter_off()
	await _hold_point()
	await _hips_first()
	await _stick()
	await _limb()
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


## Loose clothes (an umpire's coat): in the T (an arm held out) nothing hangs from the arm far below it - a coat
## modelled arms-down and posed into the T stretches from its side into the sleeve, a wing; and with the arms raised,
## what hangs below the chest stays down (a coat's side skinned to the arm lifts with it).
const SLEEVE_MAX := 0.14   # m below the arm's line the sleeve's underside may hang, between the shoulder and the wrist
const LIFT_MAX := 0.06     # m the clothes below the chest may rise with the arms up


func _cloth(poses: Dictionary) -> void:
	var sk := body.skeleton
	var rest := func(n: String) -> Vector3: return sk.get_bone_global_rest(sk.find_bone(n)).origin
	for side in ["Left", "Right"]:
		var sh: Vector3 = rest.call(side + "Arm")
		var hand: Vector3 = rest.call(side + "Hand")
		var x0 := absf(sh.x) + 0.08
		var x1 := absf(hand.x) - 0.05
		var deepest := 0.0
		for p: Vector3 in src:
			if signf(p.x) == signf(hand.x) and absf(p.x) > x0 and absf(p.x) < x1 and absf(p.z - sh.z) < 0.15:
				deepest = maxf(deepest, sh.y - p.y)
		var ok := deepest <= SLEEVE_MAX
		lines.append("T            %-5s sleeve hangs %2d cm below the arm  %s" % [side, roundi(deepest * 100), "ok" if ok else "FAIL"])
		if not ok:
			failures.append("%s arm: the clothes hang %d cm below it in the T (a wing)" % [side, roundi(deepest * 100)])
	var posed := await _skin(poses.arms_up)
	var chest: float = rest.call("Spine1").y
	var hips: float = rest.call("Hips").y
	var lift := 0.0
	for v in src.size():
		var p: Vector3 = src[v]
		if p.y < chest and p.y > hips - 0.4:
			lift = maxf(lift, (posed.pos[v] as Vector3).y - p.y)
	var ok := lift <= LIFT_MAX
	lines.append("arms_up      the clothes below the chest rise %2d cm  %s" % [roundi(lift * 100), "ok" if ok else "FAIL"])
	if not ok:
		failures.append("arms up: the clothes below the chest rise %d cm with them" % roundi(lift * 100))


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
	# Above the ankle (the owner's free: "the shin pinches to half its width just above the boot").
	"shin": [["UpLeg", "Leg", "Foot"], 1.45, 1.85, "twist"],
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


## The soles stand flat at rest: the lowest point toward the toe against the lowest at the heel, on the mesh itself
## (a model made with its feet pitched up shows here even though every joint angle is fine).
## The chest kept clear (WsgPoseLayer.torso_r): an arm laid across the chest by a pose made for a slimmer body - the
## forearm through it - is swung out about the shoulder till the forearm is outside.
func _torso() -> void:
	var layer := WsgPoseLayer.new()
	body.skeleton.add_child(layer)
	layer.weight = 1.0
	var inside := []
	var in_cap := []
	var cap0 := body.torso_capsule(true)
	for r in [0.0, 0.1, -1.0]:
		# (-1: torso_from_body, the chest as the mesh is: WsgBody.torso_capsule)
		layer.torso_r = maxf(r, 0.0)
		layer.torso_from_body = r < 0.0
		layer.set_pose({"RightArm": Quaternion(Vector3.UP, deg_to_rad(90.0)) * Quaternion(Vector3.BACK, deg_to_rad(70.0)),
			"RightForeArm": Quaternion(Vector3.UP, deg_to_rad(120.0))})
		var deepest := [0.0, -INF]
		var f := func():
			var sk := body.skeleton
			var a := sk.get_bone_global_pose(sk.find_bone("Hips")).origin
			var b := sk.get_bone_global_pose(sk.find_bone("Neck")).origin
			var e := sk.get_bone_global_pose(sk.find_bone("RightForeArm")).origin
			var h := sk.get_bone_global_pose(sk.find_bone("RightHand")).origin
			var cap := body.torso_capsule(true)
			for k in [0.3, 0.6, 0.9]:
				var q := e.lerp(h, k)
				var t := clampf((q - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
				deepest[0] = maxf(deepest[0], 0.1 - q.distance_to(a + (b - a) * t))
				# The forearm's own surface against the chest as drawn.
				var c: Array = WsgPoseLayer._seg_seg(q, q, cap[0], cap[1])
				deepest[1] = maxf(deepest[1], float(cap[2]) + WsgPoseLayer.FOREARM_R - float(c[2]))
		body.posed.connect(f, CONNECT_ONE_SHOT)
		body.reset_pose()
		await process_frame
		await process_frame
		inside.append(deepest[0] * 1000.0)
		in_cap.append(deepest[1] * 1000.0)
	lines.append("chest: a forearm laid through it %.0f mm deep, kept clear %.0f mm" % [inside[0], inside[1]])
	if inside[0] < 20.0 or inside[1] > 5.0:
		failures.append("chest clearance: %.0f mm in without, %.0f with" % [inside[0], inside[1]])
	lines.append("chest as drawn (torso_capsule, r %.0f mm): the forearm's surface %.0f mm into it without, %.0f with torso_r 0.1, %.0f with torso_from_body" % [float(cap0[2]) * 1000.0, in_cap[0], in_cap[1], in_cap[2]])
	if in_cap[0] < 20.0 or in_cap[2] > 5.0:
		failures.append("torso_from_body: the forearm %.0f mm into the drawn chest without, %.0f with" % [in_cap[0], in_cap[2]])
	layer.torso_from_body = false
	layer.queue_free()
	await process_frame


## The foot planter under a game's pose of the whole body (the hips lowered half a metre, the legs as posed: their
## feet under its floor): keep_pose leaves the legs exactly as the pose has them (only the hips' lift added), where
## enabled = false still bends them to keep the ankles over its floor.
func _planter_off() -> void:
	var b := WsgBody.new(body.character)
	root.add_child(b)
	var layer := WsgPoseLayer.new()
	b.skeleton.add_child(layer)
	b.skeleton.move_child(layer, 0)
	layer.weight = 1.0
	layer.lift_after = 0.04
	layer.set_pose({"@hips": Vector3(0, -0.5, 0)})
	var planter := WsgFootPlanter.new()
	b.add_modifier(planter)
	planter.hips_offset = 0.04
	var got := {}
	for how in ["off", "disabled", "keep_pose"]:
		planter.active = how != "off"
		planter.enabled = how != "disabled"
		planter.keep_pose = how == "keep_pose"
		planter.tick(1.0 / 30.0)
		var f := func():
			var sk := b.skeleton
			var hp := sk.get_bone_global_pose(sk.find_bone("Hips")).origin
			got[how] = [hp, sk.get_bone_global_pose(sk.find_bone("LeftFoot")).origin - hp, sk.get_bone_global_pose(sk.find_bone("RightFoot")).origin - hp]
		b.posed.connect(f, CONNECT_ONE_SHOT)
		b.reset_pose()
		await process_frame
		await process_frame
	var bent := maxf((got.disabled[1] - got.off[1]).length(), (got.disabled[2] - got.off[2]).length())
	var kept := maxf((got.keep_pose[1] - got.off[1]).length(), (got.keep_pose[2] - got.off[2]).length())
	var lift: float = got.keep_pose[0].y - got.off[0].y
	lines.append("planter under a whole-body pose: enabled=false moves the feet %.1f cm, keep_pose %.2f mm (hips lifted %.1f cm, want 4.0)" % [bent * 100.0, kept * 1000.0, lift * 100.0])
	if kept > 0.0005 or absf(lift - 0.04) > 0.0005:
		failures.append("keep_pose: the legs moved %.2f mm, the hips lifted %.1f cm" % [kept * 1000.0, lift * 100.0])
	b.queue_free()
	await process_frame


## A hand held on a point in the world (WsgPoseLayer.hold_point: a pole), on a body moved, turned and scaled, the
## foot planter lifting its hips after the layer (lift_after): the hand's grip line comes onto the pole's axis there.
func _hold_point() -> void:
	var b := WsgBody.new(body.character)
	root.add_child(b)
	b.position = Vector3(3.0, 0.0, -2.0)
	b.rotation.y = 0.7
	b.scale = Vector3.ONE * 0.95
	var layer := WsgPoseLayer.new()
	b.skeleton.add_child(layer)
	b.skeleton.move_child(layer, 0)
	layer.weight = 1.0
	layer.lift_after = 0.05
	var planter := WsgFootPlanter.new()
	b.add_modifier(planter)
	planter.hips_offset = 0.05
	planter.keep_pose = true
	layer.arms = WsgLegacyPose.arm_maker(b.joints)
	await process_frame
	# The pole half a metre out to the left of the shoulder, a little forward, at chest height.
	var pole: Vector3 = b.global_transform * ((b.joints["LeftArm"] as Vector3) + Vector3(0.45, -0.15, 0.15))
	var r := 0.0475
	layer.hold_point = {"Left": [pole, 1.0, Vector3.UP, r]}
	var off := [INF]
	var f := func():
		var g := b.grip_point("Left", r)
		var v := g.origin - pole
		off[0] = (v - Vector3.UP * v.dot(Vector3.UP)).length()
	b.posed.connect(f)
	b.reset_pose()
	await process_frame
	await process_frame
	b.posed.disconnect(f)
	lines.append("hold_point: the grip line %.1f mm off the pole's axis (moved, turned, scaled 0.95, hips lifted after); reach %.2f of the arm" % [off[0] * 1000.0, layer.hold_point_reach.get("Left", -1.0)])
	if off[0] > 0.005:
		failures.append("hold_point: the hand is %.1f mm off the pole" % [off[0] * 1000.0])
	b.queue_free()
	await process_frame


## Holds made against the hips (WsgPoseLayer.make_holds) in a fade (the layer at half weight, the hips going down
## and forward): with hips_first and hold_weight_own the hand is where the hold puts it; laid after the holds (the
## old order), the hips carry it off.
func _hips_first() -> void:
	var b := WsgBody.new(body.character)
	root.add_child(b)
	var layer := WsgPoseLayer.new()
	b.skeleton.add_child(layer)
	b.skeleton.move_child(layer, 0)
	layer.weight = 0.5
	layer.set_pose({"@hips": Vector3(0, -0.2, 0.1)})
	layer.arms = WsgLegacyPose.arm_maker(b.joints)
	await process_frame
	var want := Transform3D(Basis.IDENTITY, (b.joints["LeftArm"] as Vector3) + Vector3(0.2, -0.3, 0.3))
	layer.make_holds = func(_sk: Skeleton3D, hips_g: Transform3D, lift: Vector3) -> Dictionary:
		return {"Left": ["Hips", hips_g.affine_inverse() * Transform3D(want.basis, want.origin - lift), 1.0]}
	var miss := {}
	for how in [["old", false, false], ["after", false, true], ["first", true, true]]:
		layer.hips_first = how[1]
		layer.hold_weight_own = how[2]
		var f := func():
			var sk := b.skeleton
			miss[how[0]] = sk.get_bone_global_pose(sk.find_bone("LeftHand")).origin.distance_to(want.origin)
		b.posed.connect(f)
		b.reset_pose()
		await process_frame
		await process_frame
		b.posed.disconnect(f)
	lines.append("holds in a fade: the hand %.1f mm from its hold with the hips laid first and its own weight; %.0f mm with the hips laid after it; %.0f mm laid after at the layer's weight (the defaults)" % [miss.first * 1000.0, miss.after * 1000.0, miss.old * 1000.0])
	if miss.first > 0.002:
		failures.append("hips_first: the hand is %.1f mm off its hold" % [miss.first * 1000.0])
	b.queue_free()
	await process_frame


## A stick through the body (Hurling's free-take: the hurley through the torso at the end of the swing): the torso's
## capsule (WsgBody.torso_capsule: measured from the mesh, moved and scaled with the body), and the least turn about
## the top fist that takes the shaft clear of it (WsgPoseLayer.clear_segment): clear by the margin, IDENTITY when it
## is clear already, and no bigger than the least found by trying every direction (a degree apart).
func _stick() -> void:
	var b := WsgBody.new(body.character)
	root.add_child(b)
	b.position = Vector3(3, 0, 2)
	b.rotation.y = deg_to_rad(30.0)
	b.scale = Vector3.ONE * 1.1
	await process_frame
	var cap := b.torso_capsule()
	var m := WsgBody.measure_torso(b.joints, (b.character.meshes as Array)[0])
	var xf := b.global_transform
	var want_a: Vector3 = xf * ((b.joints.Hips as Vector3) + Vector3(0, 0, m[1]))
	var r: float = cap[2]
	lines.append("torso capsule: radius %.0f mm (the chest's half-depth, measured: %.0f mm at scale 1), its axis %.0f mm along the chest's forward" % [r * 1000.0, float(m[0]) * 1000.0, float(m[1]) * 1000.0])
	var cap_sk := b.torso_capsule(true)
	if (b.skeleton.global_transform * (cap_sk[1] as Vector3)).distance_to(cap[1]) > 0.001:
		failures.append("torso_capsule(true) is not the skeleton-space capsule: %s against %s" % [cap_sk, cap])
	if m.is_empty() or (cap[0] as Vector3).distance_to(want_a) > 0.002 or absf(r - float(m[0]) * 1.1) > 0.001 or r < 0.08 or r > 0.2:
		failures.append("torso_capsule: %s (measured %s)" % [cap, m])
	var ca: Vector3 = cap[0]
	var cb: Vector3 = cap[1]
	var mid := ca.lerp(cb, 0.55)
	var fwd := xf.basis.z.normalized()
	var right := -xf.basis.x.normalized()
	var margin := 0.03
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var worst := -INF
	var through := 0
	var t0 := Time.get_ticks_usec()
	var calls := 0
	var cases := []
	for i in 8:
		# The top fist in front of the body and to its right; the shaft from there back and across through the chest.
		var pivot := mid + fwd * rng.randf_range(0.3, 0.45) + right * rng.randf_range(0.1, 0.3) + Vector3.UP * rng.randf_range(-0.15, 0.15)
		var aim := mid + (fwd * rng.randf_range(-0.08, 0.04) + right * rng.randf_range(-0.08, 0.08) + Vector3.UP * rng.randf_range(-0.1, 0.1))
		var dir := (aim - pivot).normalized()
		cases.append([pivot - dir * 0.08, pivot + dir * 0.9, pivot])
	for c in cases:
		var d0 := WsgPoseLayer._seg_seg(c[0], c[1], ca, cb)[2] as float - r
		var q := WsgPoseLayer.clear_segment(c[0], c[1], c[2], cap, margin)
		calls += 1
		var a2: Vector3 = c[2] + q * (c[0] - c[2])
		var b2: Vector3 = c[2] + q * (c[1] - c[2])
		var d1: float = float(WsgPoseLayer._seg_seg(a2, b2, ca, cb)[2]) - r
		var ours := rad_to_deg(q.get_angle())
		var best := _least_turn(c[0], c[1], c[2], cap, margin)
		worst = maxf(worst, ours - best)
		if d0 < 0.0:
			through += 1
		lines.append("stick: %.0f mm into the chest, turned %.1f degrees about the top fist (least by search %.1f): %.0f mm clear" % [-d0 * 1000.0, ours, best, d1 * 1000.0])
		if d1 < margin - 0.0005:
			failures.append("clear_segment left the stick %.1f mm off the chest (margin %.0f)" % [d1 * 1000.0, margin * 1000.0])
		if ours > best + 1.5:
			failures.append("clear_segment turned %.1f degrees, the least is %.1f" % [ours, best])
	var us := float(Time.get_ticks_usec() - t0)
	var clear_q := WsgPoseLayer.clear_segment(mid + fwd * 0.4 + right * 0.2, mid + fwd * 0.5 + right * 1.0, mid + fwd * 0.4 + right * 0.2, cap, margin)
	t0 = Time.get_ticks_usec()
	for i in 100:
		WsgPoseLayer.clear_segment(cases[i % cases.size()][0], cases[i % cases.size()][1], cases[i % cases.size()][2], cap, margin)
	var per := (Time.get_ticks_usec() - t0) / 100.0
	lines.append("stick: %d of %d through the chest, at most %.2f degrees over the least; held out in front: %s; %.0f us a call" % [through, cases.size(), worst, "IDENTITY" if clear_q == Quaternion.IDENTITY else str(clear_q), per])
	if through < cases.size() - 1:
		failures.append("clear_segment test: only %d of the sticks went through the chest" % through)
	if clear_q != Quaternion.IDENTITY:
		failures.append("clear_segment turned a stick already clear: %s" % clear_q)
	b.queue_free()
	await process_frame


## A limb as a capsule (WsgBody.limb_capsule: from one joint to the next, its girth measured from the mesh, moved and
## scaled with the body), and a stick through the upper arm turned clear of it about the top fist (clear_segment).
func _limb() -> void:
	var b := WsgBody.new(body.character)
	root.add_child(b)
	b.position = Vector3(-2, 0, 1)
	b.rotation.y = deg_to_rad(-40.0)
	b.scale = Vector3.ONE * 1.1
	await process_frame
	var mesh: Mesh = (b.character.meshes as Array)[0]
	for pair in [["LeftArm", "LeftForeArm", 0.04, 0.09], ["LeftForeArm", "LeftHand", 0.025, 0.065], ["RightArm", "RightForeArm", 0.04, 0.09]]:
		var cap := b.limb_capsule(pair[0], pair[1])
		var m := WsgBody.measure_limb(b.joints, mesh, pair[0], pair[1])
		var xf := b.skeleton.global_transform
		var wa: Vector3 = xf * b.skeleton.get_bone_global_pose(b.bone(pair[0])).origin
		var wb: Vector3 = xf * b.skeleton.get_bone_global_pose(b.bone(pair[1])).origin
		lines.append("limb capsule %s-%s: radius %.0f mm (measured %.0f mm at scale 1)" % [pair[0], pair[1], float(cap[2]) * 1000.0, m * 1000.0])
		if cap.size() != 3 or (cap[0] as Vector3).distance_to(wa) > 0.001 or (cap[1] as Vector3).distance_to(wb) > 0.001:
			failures.append("limb_capsule %s-%s is not on the joints: %s" % [pair[0], pair[1], cap])
		elif m < float(pair[2]) or m > float(pair[3]) or absf(float(cap[2]) - m * 1.1) > 0.001:
			failures.append("limb_capsule %s-%s: radius %.3f (measured %.3f)" % [pair[0], pair[1], cap[2], m])
		var sk_cap := b.limb_capsule(pair[0], pair[1], true)
		if (xf * (sk_cap[1] as Vector3)).distance_to(cap[1]) > 0.001:
			failures.append("limb_capsule(true) is not the skeleton-space capsule")
	if not b.limb_capsule("LeftArm", "NoSuchBone").is_empty():
		failures.append("limb_capsule with a bone not on the rig is not []")
	# A stick from a fist in front of the upper arm back through its middle, turned clear about the fist.
	var arm := b.limb_capsule("LeftArm", "LeftForeArm")
	var mid: Vector3 = (arm[0] as Vector3).lerp(arm[1], 0.5)
	var fwd := b.global_transform.basis.z.normalized()
	var pivot := mid + fwd * 0.35 + Vector3.UP * 0.05
	var dir := (mid - pivot).normalized()
	var sa := pivot - dir * 0.08
	var sb := pivot + dir * 0.9
	var d0: float = float(WsgPoseLayer._seg_seg(sa, sb, arm[0], arm[1])[2]) - float(arm[2])
	var q := WsgPoseLayer.clear_segment(sa, sb, pivot, arm, 0.03)
	var d1: float = float(WsgPoseLayer._seg_seg(pivot + q * (sa - pivot), pivot + q * (sb - pivot), arm[0], arm[1])[2]) - float(arm[2])
	lines.append("stick through the upper arm: %.0f mm in, turned %.1f degrees about the fist: %.0f mm clear" % [-d0 * 1000.0, rad_to_deg(q.get_angle()), d1 * 1000.0])
	if d0 >= 0.0 or d1 < 0.03 - 0.0005:
		failures.append("clear_segment against the upper arm: %.1f mm before, %.1f after" % [d0 * 1000.0, d1 * 1000.0])
	# Without a mesh: LIMB_K of the length.
	var bare := WsgBody.new({"joints": b.joints})
	root.add_child(bare)
	await process_frame
	var bc := bare.limb_capsule("LeftArm", "LeftForeArm")
	var want := WsgBody.LIMB_K * ((b.joints.LeftForeArm as Vector3) - (b.joints.LeftArm as Vector3)).length()
	if bc.size() != 3 or absf(float(bc[2]) - want) > 0.0005:
		failures.append("limb_capsule without a mesh: %s (want radius %.3f)" % [bc, want])
	bare.queue_free()
	b.queue_free()
	await process_frame


## The least turn (degrees) of the shaft's direction about the pivot that leaves it clear by margin: every direction,
## about a degree apart (a Fibonacci sphere), then a tenth of a degree round the best.
func _least_turn(sa: Vector3, sb: Vector3, pivot: Vector3, cap: Array, margin: float) -> float:
	var la := (sa - pivot).dot((sb - sa).normalized())
	var lb := (sb - pivot).dot((sb - sa).normalized())
	var d0 := (sb - sa).normalized()
	var ok := func(d: Vector3) -> bool:
		return float(WsgPoseLayer._seg_seg(pivot + d * la, pivot + d * lb, cap[0], cap[1])[2]) >= float(cap[2]) + margin
	var best := PI
	var best_d := d0
	var n := 40000
	for i in n:
		var y := 1.0 - 2.0 * (i + 0.5) / n
		var ph := i * PI * (3.0 - sqrt(5.0))
		var d := Vector3(cos(ph) * sqrt(1.0 - y * y), y, sin(ph) * sqrt(1.0 - y * y))
		var ang := d0.angle_to(d)
		if ang < best and ok.call(d):
			best = ang
			best_d = d
	# (Finer, round the best: between it and the start, and either side.)
	var axis := d0.cross(best_d).normalized()
	for k in 41:
		for j in 41:
			var d := best_d.rotated(axis, deg_to_rad((k - 20) * 0.1)).rotated(d0, deg_to_rad((j - 20) * 0.1))
			var ang := d0.angle_to(d)
			if ang < best and ok.call(d):
				best = ang
	return rad_to_deg(best)


func _soles() -> void:
	for side in ["Left", "Right"]:
		var ids := {WsgRig.index(side + "Foot"): true, WsgRig.index(side + "ToeBase"): true}
		var pts := []
		for v in src.size():
			var w := 0.0
			for k in 4:
				if ids.has(bones[v * 4 + k]):
					w += weights[v * 4 + k]
			if w >= 0.5:
				pts.append(src[v])
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
		lines.append("sole  %-5s toes up %.1f degrees at rest" % [side, pitch])
		if pitch > 10.0:
			failures.append("%s foot: toes pitched up %.0f degrees at rest (the bake must flatten it)" % [side, pitch])


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


## The hands close round a ball (grip_sphere): every fingertip comes onto it, no finger goes into it. Closed as a
## ball-sized handle (grip) for comparison, which is what a game had before.
func _grip_sphere(poses: Dictionary) -> void:
	for as_sphere in [false, true]:
		var posed := await _skin(poses.arms_down, func():
			for side in ["Left", "Right"]:
				if as_sphere:
					body.grip_sphere(side, BALL_R)
				else:
					body.grip(side, BALL_R))
		for side in ["Left", "Right"]:
			var hand: Transform3D = posed.g[side + "Hand"]
			# (The ball where each grip puts it: a handle's axis point, or the ball's own centre.)
			var at := WsgGrip.sphere_point(body.joints, side, BALL_R) if as_sphere else WsgGrip.axis_point(body.joints, side, BALL_R)
			var c := hand * (at - (body.joints[side + "Hand"] as Vector3))
			var finger_ids := {}
			for f in ["Index", "Middle", "Ring", "Pinky"]:
				for k in 3:
					finger_ids[WsgRig.index(side + "Hand" + f + str(k + 1))] = f
			var deep := {}
			var tips := {}
			for v in src.size():
				var b := bones[v * 4]
				if weights[v * 4] < 0.5 or not finger_ids.has(b):
					continue
				var r: float = (posed.pos[v] as Vector3).distance_to(c)
				var f: String = finger_ids[b]
				deep[f] = minf(float(deep.get(f, INF)), r)
				if WsgRig.BONES[b][0].ends_with("3"):
					tips[f] = minf(float(tips.get(f, INF)), r)
			var far := 0.0
			var deepest := INF
			var each := []
			for f in ["Index", "Middle", "Ring", "Pinky"]:
				if tips.has(f):
					far = maxf(far, tips[f])
				deepest = minf(deepest, deep.get(f, INF))
				each.append("%s %+.1f" % [f.left(1), (float(deep.get(f, INF)) - BALL_R) * 1000.0])
			lines.append("ball %-5s as a %-6s fingertips within %.1f cm of it; deepest %.1f mm inside (each finger's nearest, mm: %s)" % [side, "sphere" if as_sphere else "handle", (far - BALL_R) * 100.0, maxf(0.0, BALL_R - deepest) * 1000.0, ", ".join(each)])
			if as_sphere:
				if far > BALL_R + 0.025:
					failures.append("%s hand does not close on the ball: a fingertip is %.1f cm off it" % [side, (far - BALL_R) * 100.0])
				if deepest < BALL_R - 0.006:
					failures.append("%s hand: a finger goes %.1f mm into the ball" % [side, (BALL_R - deepest) * 1000.0])


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
