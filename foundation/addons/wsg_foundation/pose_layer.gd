class_name WsgPoseLayer
extends SkeletonModifier3D
## A pose laid over whatever the clips are doing, bone by bone, with a weight: an official's signal over his jog, a
## player's catch over his run, or a game's own hand-made pose (WsgLegacyPose turns the games' 17-bone poses into
## one). It runs first among the modifiers, so the rig's drivers then keep the result sound (hinges, ankles, helpers).
##   layer.set_pose({"RightArm": q, "RightForeArm": q2})   # local turns from the canonical rest
##   layer.weight = 1.0                                   # or fade it: layer.fade_to(1.0, 0.25)

## Bone name -> local Quaternion (from the rest).
var pose := {}
## 0: the clips alone; 1: the pose on the bones it names.
var weight := 0.0
## Hips position offset (from the rest), when the pose moves the hips (a crouch, a dive), weighted too.
var hips := Vector3.INF
## A lift a later modifier adds to the hips (the foot planter's hips_offset, which fits the clips' hips to this body's
## legs): taken off the pose's hips, so the body stands where the pose has it (it floated by that much).
var lift_after := 0.0
## Bones to put where they are in the body (skeleton space, Quaternion), whatever the clips do to their parents:
## a hand that holds something must be where the game's body has it, not where its turns put it on a chest that
## leans and twists differently. Applied after `pose`, parents first (give them in that order).
var body_pose := {}
## Given (the WsgLegacyPose reading the game's body): an arm laid in body space is made anatomical under this body's
## own chest (WsgLegacyPose.sound_arm), which turns differently from the game's.
var arms: WsgLegacyPose
## Hands kept on something another bone holds (a two-handed grip: the top hand on a hurley's handle): {side: [the bone
## it is held to, Transform3D - the hand (rig-convention frame) in that bone's frame, weight 0-1, and optionally the
## handle's direction in that frame and a point on its axis in the hand's frame: a hand that cannot reach slides
## along it to the nearest place it can, and may roll round it (still holding it) to spare the wrist]}. Applied
## after body_pose: the arm reaches there (two bones, the elbow kept on its side), the hand turned as given, then made
## anatomical (arms).
var hold := {}
## Free hands kept off something another bone holds (a hurley's handle in the other hand: a runner's swinging fist
## went through it): {side: [the bone, a point on the handle's axis and its direction in that bone's frame, the
## handle's half length, its radius]}. A fist (wrist to knuckles, FIST_R round) that would meet it is moved straight
## off it, its turn kept. Applied last; not to a side in `hold`.
var clear := {}
const FIST_R := 0.045
## The chest kept clear of the forearms (m: the torso's radius about the line from the hips to the neck; 0: not
## kept). A pose made for a slimmer body (a game's own, a clip from video) laid on this one swept a forearm through
## the chest: the arm is swung out about the shoulder till the forearm is outside it. After body_pose, and again
## after the holds.
var torso_r := 0.0
const FOREARM_R := 0.04
## The forearms kept out of the chest as this body draws it (its WsgBody.torso_capsule: the chest's own half-depth
## round the middle of its depth, measured from the mesh) instead of torso_r round the hips-to-neck joint line, which
## sits toward the back: a torso_r small enough for the back let a forearm across the front of a deep chest sink in
## (Hurling's free, the striking forearm across the chest through the follow-through, 2-4 cm into it). Needs the layer
## under a WsgBody's skeleton; on its own (torso_r 0) it turns the clearing on. Off (the default): torso_r, as before.
var torso_from_body := false
## The hips laid once, first (their turn in `pose` and the `hips` offset, at the layer's weight), before the bones
## and the holds, and not again after: holds made against the hips (make_holds) stay where they were made. Off (the
## default), the hips are laid last, as before - a hold worked out against the hips before they are laid is carried
## off by them, and a subclass that laid them itself first had them laid twice in a fade (Floorball's StickLayer:
## its holds drifted up to 4 cm; Netball's BallLayer laid them once and took them out of the pose).
var hips_first := false
## Each hold's weight (hold, hold_point) is its own, not times the layer's: a catch's hands come onto the ball at the
## ball's weight while the layer fades the game's pose in (Netball: the palms 5-18 cm off the ball for the first
## frames of a catch). With it the layer runs while any hold is given, even at weight 0. Off (the default): times
## the layer's, as before.
var hold_weight_own := false
## Called as the layer runs, once the hips (with hips_first), the pose and body_pose are laid, to make `hold` against
## the body as it will be drawn: func(sk: Skeleton3D, hips: Transform3D (the hips' global pose), lift: Vector3 (the
## lift a later modifier adds, lift_after)) -> Dictionary (the hold). Unset (the default): `hold` as the game set it.
##   layer.hips_first = true; layer.hold_weight_own = true; layer.make_holds = link.holds
var make_holds := Callable()
## Hands held on a point in the world (a pole, a rail, a post: something that does not move with the body):
## {side: [the point (world: on the bar's axis, where that hand grips it), weight 0-1, the bar's direction (world;
## default up), its radius (default 0.0475)]}. The hand's grip line (WsgGrip.axis_point) is put on the bar, the palm
## to it from the shoulder's side, the bar along the hand's width; the arm reaches it (rolling round the bar to spare
## the wrist). Aimed lower by lift_after (the foot planter lifts the hips after this layer). Applied last. Empty (the
## default): none. (From Kho Kho's pole turn.)
var hold_point := {}
## After each run: side -> how far each hold_point is from its shoulder against the arm's length (over 1: out of
## reach, the arm straight toward it), for a game to let go of a hand that cannot reach.
var hold_point_reach := {}

var _target := 0.0
var _rate := 0.0
var _ix := {}
var _for := -1


## The pose: {bone: local Quaternion}, and "@hips" (the hips' offset from the rest) if it moves them (a pose without
## it leaves the hips to the clips: the last one's are not kept).
func set_pose(p: Dictionary) -> void:
	hips = Vector3.INF
	if p.has("@hips"):
		hips = p["@hips"]
		p = p.duplicate()
		p.erase("@hips")
	if p.keys() != pose.keys():
		_ix.clear()
	pose = p


## Eases the weight to w over secs (called once; it then moves on its own).
func fade_to(w: float, secs: float) -> void:
	_target = clampf(w, 0.0, 1.0)
	_rate = absf(_target - weight) / maxf(secs, 0.001)


func _process_modification_with_delta(delta: float) -> void:
	if _rate > 0.0:
		weight = move_toward(weight, _target, _rate * delta)
		if weight == _target:
			_rate = 0.0
	if weight <= 0.0 and not (hold_weight_own and (not hold.is_empty() or not hold_point.is_empty() or make_holds.is_valid())):
		return
	var sk := get_skeleton()
	if sk == null:
		return
	if _for != sk.get_instance_id() or _ix.size() != pose.size():
		_for = sk.get_instance_id()
		_ix.clear()
		for b in pose:
			_ix[b] = sk.find_bone(b)
	var w := smoothstep(0.0, 1.0, weight)
	if hips_first:
		var hb := sk.find_bone("Hips")
		if pose.has("Hips"):
			sk.set_bone_pose_rotation(hb, sk.get_bone_pose_rotation(hb).slerp(pose["Hips"], w))
		if hips != Vector3.INF:
			sk.set_bone_pose_position(hb, sk.get_bone_pose_position(hb).lerp(sk.get_bone_rest(hb).origin + hips - Vector3(0, lift_after, 0), w))
	for b in pose:
		var i: int = _ix.get(b, -1)
		if i < 0 or hips_first and b == "Hips":
			continue
		var q: Quaternion = pose[b]
		sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp(q, w))
	var targets := body_pose
	for b in body_pose:
		var i := sk.find_bone(b)
		if i < 0:
			continue
		var par := sk.get_bone_parent(i)
		var pq := sk.get_bone_global_pose(par).basis.get_rotation_quaternion() if par >= 0 else Quaternion.IDENTITY
		var side := "Left" if b.begins_with("Left") else "Right"
		if arms != null and b == side + "Arm" and targets.has(side + "ForeArm"):
			var chest := sk.get_bone_global_pose(sk.find_bone("Spine2")).basis.get_rotation_quaternion()
			var r := arms.sound_arm(chest, side, targets[b], targets[side + "ForeArm"], targets.get(side + "Hand", targets[side + "ForeArm"]))
			targets = targets.duplicate()
			targets[b] = r[0]
			targets[side + "ForeArm"] = r[1]
			if targets.has(side + "Hand"):
				targets[side + "Hand"] = r[2]
		var want: Quaternion = (pq.inverse() * (targets[b] as Quaternion)).normalized()
		sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp(want, w))
	if torso_r > 0.0 or torso_from_body:
		for side in ["Left", "Right"]:
			_clear_torso(sk, side, w, 0.0)
	if make_holds.is_valid():
		hold = make_holds.call(sk, sk.get_bone_global_pose(sk.find_bone("Hips")), Vector3(0, lift_after, 0))
	for side in hold:
		var h: Array = hold[side]
		var hw: float = _hold_w(h[2], w)
		var ai := sk.find_bone(h[0])
		if hw > 0.0 and ai >= 0:
			var ag := sk.get_bone_global_pose(ai)
			var target := ag * (h[1] as Transform3D)
			var grip := []
			if h.size() > 4:
				target.origin += _slide(sk, side, target.origin, ag.basis * (h[3] as Vector3))
				grip = [h[4], ag.basis * (h[3] as Vector3)]
			_reach(sk, side, target, hw, grip)
	for side in clear:
		if not hold.has(side) or _hold_w((hold[side] as Array)[2], w) <= 0.0:
			_keep_clear(sk, side, clear[side])
	if torso_r > 0.0 or torso_from_body:
		# (A held hand too, when the arm is well into the chest: better a hand a little off the handle than an arm
		# through the chest; a graze is left, the hand kept closed on the handle.)
		for side in ["Left", "Right"]:
			var held := hold.has(side) and _hold_w((hold[side] as Array)[2], w) > 0.0
			_clear_torso(sk, side, w, 0.03 if held else 0.0)
	if hips != Vector3.INF and not hips_first:
		var h := sk.find_bone("Hips")
		sk.set_bone_pose_position(h, sk.get_bone_pose_position(h).lerp(sk.get_bone_rest(h).origin + hips - Vector3(0, lift_after, 0), w))
	if not hold_point.is_empty():
		_hold_points(sk, w)


## A hold's weight this run: its own (hold_weight_own), or times the layer's.
func _hold_w(own, w: float) -> float:
	return minf(float(own), 1.0) if hold_weight_own else float(own) * w


var _rest_j := {}
var _rest_for := -1


## Each hold_point's hand on its bar (see hold_point).
func _hold_points(sk: Skeleton3D, w: float) -> void:
	if _rest_for != sk.get_instance_id():
		# (The hand's rest joints, for its grip line: the rig's skeleton is built from the character's joints.)
		_rest_for = sk.get_instance_id()
		_rest_j = {}
		for side in ["Left", "Right"]:
			for n in ["Hand", "HandMiddle1", "HandIndex1", "HandPinky1"]:
				var i := sk.find_bone(side + n)
				if i >= 0:
					_rest_j[side + n] = sk.get_bone_global_rest(i).origin
	var inv := sk.global_transform.affine_inverse()
	for side in hold_point:
		var e: Array = hold_point[side]
		if not _rest_j.has(side + "HandPinky1"):
			continue
		var hw := _hold_w(e[1], w)
		var r: float = float(e[3]) if e.size() > 3 else 0.0475
		# (The foot planter lifts the hips after this, by lift_after: the hand is put that much lower.)
		var a: Vector3 = inv * (e[0] as Vector3) - Vector3(0.0, lift_after, 0.0)
		var up: Vector3 = (inv.basis * (e[2] as Vector3 if e.size() > 2 else Vector3.UP)).normalized()
		var ia := sk.find_bone(side + "Arm")
		var sh := sk.get_bone_global_pose(ia).origin
		var arm := sk.get_bone_rest(sk.find_bone(side + "ForeArm")).origin.length() + sk.get_bone_rest(sk.find_bone(side + "Hand")).origin.length()
		var d := (a - sh) - up * (a - sh).dot(up)
		if d.length() < 0.01:
			continue
		d = d.normalized()
		var x := d if side == "Left" else -d
		var b := Basis(x, up.cross(x), up).orthonormalized()
		var g: Vector3 = WsgGrip.axis_point(_rest_j, side, r) - (_rest_j[side + "Hand"] as Vector3)
		var t := Transform3D(b, a - b * g)
		hold_point_reach[side] = (t.origin - sh).length() / maxf(arm, 0.01)
		if hw > 0.0:
			_reach(sk, side, t, hw, [g, up])


## The least turn about pivot that takes the segment seg_a-seg_b (a stick's shaft, world or skeleton space - all in
## one space) clear of the capsule [a, b, radius] (WsgBody.torso_capsule()) by margin (m: give the stick's own radius
## in it). IDENTITY if it is clear already, or if the pivot itself is inside (no turn about it can help). Cheap: the
## nearest points of the segment and the capsule's axis, then the segment's far end turned straight away from the
## axis about the pivot (a few passes: the turn moves the nearest point too), given as one turn of the far end's
## direction when that is clear too (no roll round the shaft). With the pivot on the shaft (the top fist) it is the
## least turn to within a degree or two (tests/rig_test.gd measures it against a search of every direction).
##   var q := WsgPoseLayer.clear_segment(butt, tip, top_fist, body.torso_capsule())
##   # the stick and both hands turned by q about top_fist (ADOPTING.md: "A stick through the body")
static func clear_segment(seg_a: Vector3, seg_b: Vector3, pivot: Vector3, capsule: Array, margin := 0.03) -> Quaternion:
	var ca: Vector3 = capsule[0]
	var cb: Vector3 = capsule[1]
	var r: float = float(capsule[2]) + margin
	if _seg_seg(seg_a, seg_b, ca, cb)[2] >= r:
		return Quaternion.IDENTITY
	if _seg_seg(pivot, pivot, ca, cb)[2] < r:
		return Quaternion.IDENTITY
	var turn := Quaternion.IDENTITY
	for pass_i in 4:
		var c := _seg_seg(pivot + turn * (seg_a - pivot), pivot + turn * (seg_b - pivot), ca, cb)
		if float(c[2]) >= r:
			break
		var off: Vector3 = c[0] - c[1]
		var out := off / float(c[2]) if float(c[2]) > 1e-5 else Vector3.ZERO
		if out == Vector3.ZERO:
			# (Through the axis: square to both, which is the short way out.)
			out = (turn * (seg_b - seg_a)).cross(cb - ca)
			if out.length_squared() < 1e-10:
				out = (cb - ca).cross(Vector3.RIGHT if absf((cb - ca).normalized().x) < 0.9 else Vector3.UP)
			out = out.normalized()
		var u: Vector3 = c[0] - pivot
		var w: Vector3 = (c[1] as Vector3) + out * (r + 0.002) - pivot
		if u.length_squared() < 1e-8 or w.length_squared() < 1e-8:
			break
		turn = (Quaternion(u.normalized(), w.normalized()) * turn).normalized()
	# The same as one turn of the far end's direction (the least that moves it there), if that is clear too.
	var far := seg_b if seg_b.distance_squared_to(pivot) >= seg_a.distance_squared_to(pivot) else seg_a
	var d0 := far - pivot
	if d0.length_squared() > 1e-8:
		var d1 := turn * d0
		var arc := Quaternion(d0.normalized(), d1.normalized()) if d0.normalized().dot(d1.normalized()) < 0.999999 else Quaternion.IDENTITY
		if _seg_seg(pivot + arc * (seg_a - pivot), pivot + arc * (seg_b - pivot), ca, cb)[2] >= r - 1e-4:
			return arc
	return turn


## The nearest points of the segments p1-q1 and p2-q2: [on the first, on the second, the distance between them].
static func _seg_seg(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> Array:
	var d1 := q1 - p1
	var d2 := q2 - p2
	var rr := p1 - p2
	var a := d1.length_squared()
	var e := d2.length_squared()
	var f := d2.dot(rr)
	var s := 0.0
	var t := 0.0
	if a <= 1e-12 and e <= 1e-12:
		return [p1, p2, p1.distance_to(p2)]
	if a <= 1e-12:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(rr)
		if e <= 1e-12:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var den := a * e - b * b
			s = clampf((b * f - c * e) / den, 0.0, 1.0) if den > 1e-12 else 0.0
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	var x := p1 + d1 * s
	var y := p2 + d2 * t
	return [x, y, x.distance_to(y)]


## The side's forearm out of the chest (torso_r round the hips-to-neck line, or the body's torso_capsule with
## torso_from_body): the arm turned about the shoulder, the
## least turn that takes the forearm's deepest point out (a few passes: the turn moves the rest of it too).
func _clear_torso(sk: Skeleton3D, side: String, w: float, slack: float) -> void:
	var ia := sk.find_bone(side + "Arm")
	var ifo := sk.find_bone(side + "ForeArm")
	var ih := sk.find_bone(side + "Hand")
	var a := sk.get_bone_global_pose(sk.find_bone("Hips")).origin
	var b := sk.get_bone_global_pose(sk.find_bone("Neck")).origin
	var rad := torso_r
	if torso_from_body:
		var body := sk.get_parent() as WsgBody
		if body != null:
			var cap := body.torso_capsule(true)
			a = cap[0]
			b = cap[1]
			rad = cap[2]
	var ab := b - a
	for pass_i in 3:
		var s := sk.get_bone_global_pose(ia).origin
		var e := sk.get_bone_global_pose(ifo).origin
		var h := sk.get_bone_global_pose(ih).origin
		var deepest := 0.0
		var at := Vector3.ZERO
		var out := Vector3.ZERO
		for k in [0.2, 0.4, 0.6, 0.8, 1.0]:
			var q := e.lerp(h, k)
			var t := clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var off := q - (a + ab * t)
			var need := rad + FOREARM_R - off.length()
			if need > deepest:
				deepest = need
				at = q
				out = off.normalized() if off.length() > 1e-4 else Vector3.FORWARD
		if deepest <= 0.002 + (slack if pass_i == 0 else 0.0):
			return
		var to := at + out * (deepest + 0.005)
		var turn := Quaternion((at - s).normalized(), (to - s).normalized())
		var par := sk.get_bone_global_pose(sk.get_bone_parent(ia)).basis.get_rotation_quaternion()
		var g := turn * sk.get_bone_global_pose(ia).basis.get_rotation_quaternion()
		sk.set_bone_pose_rotation(ia, sk.get_bone_pose_rotation(ia).slerp((par.inverse() * g).normalized(), w))


func _keep_clear(sk: Skeleton3D, side: String, c: Array) -> void:
	var ai := sk.find_bone(c[0])
	var ih := sk.find_bone(side + "Hand")
	var ik := sk.find_bone(side + "HandMiddle1")
	if ai < 0 or ih < 0 or ik < 0:
		return
	var ag := sk.get_bone_global_pose(ai)
	var p: Vector3 = ag * (c[1] as Vector3)
	var d: Vector3 = (ag.basis * (c[2] as Vector3)).normalized()
	var half: float = c[3]
	var hand := sk.get_bone_global_pose(ih)
	var a := hand.origin
	var b := sk.get_bone_global_pose(ik).origin
	# The nearest points of the fist (wrist to knuckles) and the handle's axis (along its tape).
	var best := [INF, Vector3.ZERO]
	for i in 5:
		var q := a.lerp(b, i / 4.0)
		var along := clampf((q - p).dot(d), -half, half)
		var off := q - (p + d * along)
		if off.length() < float(best[0]):
			best = [off.length(), off]
	var need: float = FIST_R + float(c[4]) - float(best[0])
	if need <= 0.0:
		return
	var out: Vector3 = best[1]
	out = out.normalized() if out.length() > 1e-5 else hand.basis.z.normalized()
	_reach(sk, side, Transform3D(hand.basis, a + out * need), 1.0)


## How far along dir (skeleton space) a hand's target must move for the side's arm to reach it comfortably (zero if
## it can): no farther than the arm's length, no nearer the shoulder than half of it (folded tighter, the hand cannot
## be put there).
func _slide(sk: Skeleton3D, side: String, t: Vector3, dir: Vector3) -> Vector3:
	var ia := sk.find_bone(side + "Arm")
	var s := sk.get_bone_global_pose(ia).origin
	var arm := sk.get_bone_rest(sk.find_bone(side + "ForeArm")).origin.length() + sk.get_bone_rest(sk.find_bone(side + "Hand")).origin.length()
	var v := t - s
	var want := clampf(v.length(), arm * 0.5, arm * 0.97)
	if is_equal_approx(want, v.length()) or dir.length_squared() < 1e-8:
		return Vector3.ZERO
	var d := dir.normalized()
	# |v + d x| = want: the root nearer zero; none (the line never comes that near): the nearest point of the line.
	var b := v.dot(d)
	var disc := b * b - (v.length_squared() - want * want)
	if disc < 0.0:
		return -d * b
	var r := sqrt(disc)
	var x1 := -b - r
	var x2 := -b + r
	return d * (x1 if absf(x1) < absf(x2) else x2)


## The side's arm reaching target (skeleton space: the hand's place and turn), by w. grip: given (a point on the
## handle in the hand's frame, and the handle's direction, skeleton space), the hand may roll round the handle -
## still holding it (every 15 degrees round) - to where the arm can reach it without wringing the wrist.
func _reach(sk: Skeleton3D, side: String, target: Transform3D, w: float, grip := []) -> void:
	var ia := sk.find_bone(side + "Arm")
	var ifo := sk.find_bone(side + "ForeArm")
	var ih := sk.find_bone(side + "Hand")
	var best := _reach_solve(sk, side, target, not grip.is_empty())
	if not grip.is_empty() and best[3] > 0.0:
		var p: Vector3 = target * (grip[0] as Vector3)
		var d: Vector3 = (grip[1] as Vector3).normalized()
		for i in range(1, 24):
			var phi := deg_to_rad(15.0 * ((i + 1) / 2) * (1 if i % 2 == 1 else -1))
			var roll := Transform3D(Basis(Quaternion(d, phi)), Vector3.ZERO)
			var t := Transform3D(Basis.IDENTITY, p) * roll * Transform3D(Basis.IDENTITY, -p) * target
			var c := _reach_solve(sk, side, t, true)
			if c[3] + absf(phi) * 0.02 < best[3]:
				best = c
	var par := sk.get_bone_global_pose(sk.get_bone_parent(ia)).basis.get_rotation_quaternion()
	var qa: Quaternion = best[0]
	var qf: Quaternion = best[1]
	var qh: Quaternion = best[2]
	sk.set_bone_pose_rotation(ia, sk.get_bone_pose_rotation(ia).slerp((par.inverse() * qa).normalized(), w))
	sk.set_bone_pose_rotation(ifo, sk.get_bone_pose_rotation(ifo).slerp((qa.inverse() * qf).normalized(), w))
	sk.set_bone_pose_rotation(ih, sk.get_bone_pose_rotation(ih).slerp((qf.inverse() * qh).normalized(), w))


## [upper arm, forearm, hand (skeleton space), how far out of range] for the side's arm reaching target. on_handle:
## the hand keeps the target's turn exactly (it is on something), the wrist counted in the range.
func _reach_solve(sk: Skeleton3D, side: String, target: Transform3D, on_handle: bool) -> Array:
	var ia := sk.find_bone(side + "Arm")
	var ifo := sk.find_bone(side + "ForeArm")
	var ih := sk.find_bone(side + "Hand")
	var ga := sk.get_bone_global_pose(ia)
	var gf := sk.get_bone_global_pose(ifo)
	var s := ga.origin
	var e := gf.origin
	var l1 := sk.get_bone_rest(ifo).origin.length()
	var l2 := sk.get_bone_rest(ih).origin.length()
	var qh := target.basis.get_rotation_quaternion()
	var to := target.origin - s
	if to.length_squared() < 1e-8:
		return [ga.basis.get_rotation_quaternion(), gf.basis.get_rotation_quaternion(), qh, 0.0]
	var tdir := to.normalized()
	var d := clampf(to.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	# The elbow on the side it is on now.
	var pole := (e - s) - tdir * (e - s).dot(tdir)
	if pole.length_squared() < 1e-8:
		pole = Vector3.DOWN - tdir * Vector3.DOWN.dot(tdir)
	var x := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var e2 := s + tdir * x + pole.normalized() * sqrt(maxf(l1 * l1 - x * x, 0.0))
	var t2 := s + tdir * d
	var qa0 := ga.basis.get_rotation_quaternion()
	var qa := Quaternion((e - s).normalized(), (e2 - s).normalized()) * qa0
	var qf := qa * qa0.inverse() * gf.basis.get_rotation_quaternion()
	var f_axis := sk.get_bone_rest(ih).origin.normalized()
	qf = Quaternion((qf * f_axis).normalized(), (t2 - e2).normalized()) * qf
	var out := 0.0
	if arms != null:
		var chest := sk.get_bone_global_pose(sk.find_bone("Spine2")).basis.get_rotation_quaternion()
		if on_handle:
			var r := arms._sound(chest, side, qa, qf, qh, true)
			return [r[0], r[1], qh, r[2]]
		var r2 := arms.sound_arm(chest, side, qa, qf, qh)
		return [r2[0], r2[1], r2[2], 0.0]
	return [qa, qf, qh, out]
