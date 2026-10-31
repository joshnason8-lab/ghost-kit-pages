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
	if weight <= 0.0:
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
	for b in pose:
		var i: int = _ix.get(b, -1)
		if i < 0:
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
	if torso_r > 0.0:
		for side in ["Left", "Right"]:
			_clear_torso(sk, side, w, 0.0)
	for side in hold:
		var h: Array = hold[side]
		var hw: float = float(h[2]) * w
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
		if not hold.has(side) or float((hold[side] as Array)[2]) * w <= 0.0:
			_keep_clear(sk, side, clear[side])
	if torso_r > 0.0:
		# (A held hand too, when the arm is well into the chest: better a hand a little off the handle than an arm
		# through the chest; a graze is left, the hand kept closed on the handle.)
		for side in ["Left", "Right"]:
			var held := hold.has(side) and float((hold[side] as Array)[2]) * w > 0.0
			_clear_torso(sk, side, w, 0.03 if held else 0.0)
	if hips != Vector3.INF:
		var h := sk.find_bone("Hips")
		sk.set_bone_pose_position(h, sk.get_bone_pose_position(h).lerp(sk.get_bone_rest(h).origin + hips - Vector3(0, lift_after, 0), w))


## The side's forearm out of the chest (torso_r round the hips-to-neck line): the arm turned about the shoulder, the
## least turn that takes the forearm's deepest point out (a few passes: the turn moves the rest of it too).
func _clear_torso(sk: Skeleton3D, side: String, w: float, slack: float) -> void:
	var ia := sk.find_bone(side + "Arm")
	var ifo := sk.find_bone(side + "ForeArm")
	var ih := sk.find_bone(side + "Hand")
	var a := sk.get_bone_global_pose(sk.find_bone("Hips")).origin
	var b := sk.get_bone_global_pose(sk.find_bone("Neck")).origin
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
			var need := torso_r + FOREARM_R - off.length()
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
