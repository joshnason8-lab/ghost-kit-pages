class_name WsgLegacyPose
extends RefCounted
## The games' own 17-bone poses (the ToonBody convention six of the seven games share: hips, spine, chest, neck,
## head, upperarm/forearm/hand, thigh/shin/foot; every rest rotation the identity, arms hanging) on the shared rig,
## so a game keeps every move it has made by hand (a hurling swing, a catch, a solo, a referee's card) while the
## foundation draws the body. Read straight off the game's own skeleton each frame:
##   var lp := WsgLegacyPose.new(toon_skeleton, body.joints)
##   layer.set_pose(lp.read())          # WsgPoseLayer: over the clips, with a weight
## What the 17 bones do not have is filled in: Spine1 halfway between spine and chest; the collarbones lift as an arm
## goes up past level (the officials' "broken shoulders"); the toes follow the foot.
## Arms are rebuilt from where the game puts the hand: the games' poses often bend an elbow backwards or turn the
## upper arm so the elbow points where no elbow can (a 17-bone arm hides it: the rig's hinge cannot follow it, and
## straightened it, so the arm snapped). The hand stays exactly where the game has it, the elbow bends forward in its
## hinge, and an elbow pointing the wrong way swivels about the line from shoulder to wrist until it is inside
## TURN_MAX of the way an arm in that place bends.

## Degrees an elbow may point away from the way an arm in that place bends with the upper arm not turned (a humerus
## turns about 70 in and 90 out).
const TURN_MAX := 95.0
## Degrees a hand may turn about its forearm from the T-pose's palm down (which is the forearm half turned, as an arm
## hanging with the palm to the thigh): the forearm turns about 90 each way.
const WRIST_MAX := 95.0

const MAP := {"hips": "Hips", "spine": "Spine", "chest": "Spine2", "neck": "Neck", "head": "Head",
	"upperarm_l": "LeftArm", "forearm_l": "LeftForeArm", "hand_l": "LeftHand", "upperarm_r": "RightArm",
	"forearm_r": "RightForeArm", "hand_r": "RightHand", "thigh_l": "LeftUpLeg", "shin_l": "LeftLeg",
	"foot_l": "LeftFoot", "thigh_r": "RightUpLeg", "shin_r": "RightLeg", "foot_r": "RightFoot"}
## Each limb bone's child in the 17 (the way it points at rest).
const CHILD := {"upperarm_l": "forearm_l", "forearm_l": "hand_l", "upperarm_r": "forearm_r", "forearm_r": "hand_r",
	"thigh_l": "shin_l", "shin_l": "foot_l", "thigh_r": "shin_r", "shin_r": "foot_r"}

var sk: Skeleton3D
var joints: Dictionary
## Corrections a game laid on its own skeleton for its own mesh, taken back out before reading (17-bone name ->
## the Quaternion it multiplied that bone's turn by): Hurling's officials have their arms twisted and their feet
## turned down to suit the Meshy models; the rig's bake has made the models right instead.
var undo := {}
## Off: the arms as the game turns them (only for tests that show what the rebuilding fixes).
var sound_arms := true
## The hands that hold something drawn in them ("Left", "Right" -> true): their turn is the game's, exactly, whatever
## the arm must do for it. The others give a little (turned back about the forearm to WRIST_MAX) where the game's turn
## is more than a forearm can.
var held := {}
var _ix := {}
var _corr := {}          # rig bone -> its rest turned onto the 17's rest (arms: T to hanging)
var _arm := {}           # side -> [upper arm rest axis, forearm rest axis, upper arm length, forearm length]
var _hips_k := 1.0
var _hips_rest := Vector3.ZERO
## The game's skeleton turned onto the rig's facing (+Z): a game whose body is built facing another way (Kabaddi's,
## facing -Z: Quaternion(Vector3.UP, PI)) has its rests and turns read as if turned by this.
var face := Quaternion.IDENTITY
var _face_inv := Quaternion.IDENTITY


func _init(toon_skeleton: Skeleton3D, rig_joints: Dictionary, p_face := Quaternion.IDENTITY) -> void:
	sk = toon_skeleton
	joints = rig_joints
	face = p_face
	_face_inv = face.inverse()
	for k in MAP:
		_ix[k] = sk.find_bone(k)
	for k in CHILD:
		var c := sk.find_bone(CHILD[k])
		var b := sk.find_bone(k)
		if b < 0 or c < 0:
			continue
		var toon_dir := face * (sk.get_bone_global_rest(c).origin - sk.get_bone_global_rest(b).origin).normalized()
		var rig_dir := WsgRig.bone_axis(joints, MAP[k])
		_corr[MAP[k]] = Quaternion(rig_dir, toon_dir)
	# The hand follows the forearm's correction (it has no child in the 17).
	for side in ["Left", "Right"]:
		_corr[side + "Hand"] = _corr.get(side + "ForeArm", Quaternion.IDENTITY)
	for side in ["Left", "Right"]:
		_arm[side] = [WsgRig.bone_axis(joints, side + "Arm"), WsgRig.bone_axis(joints, side + "ForeArm"),
			(joints[side + "ForeArm"] as Vector3).distance_to(joints[side + "Arm"]),
			(joints[side + "Hand"] as Vector3).distance_to(joints[side + "ForeArm"])]
	var h: int = _ix["hips"]
	_hips_rest = sk.get_bone_rest(h).origin
	_hips_k = (joints["Hips"] as Vector3).y / maxf(_hips_rest.y, 0.01)


## The pose now on the game's skeleton, as the rig's local turns (and "@hips": the hips' offset from the rest).
func read() -> Dictionary:
	# The game's turns, its own corrections taken out, through its hierarchy (every rest rotation the identity).
	var tg := {}
	for k in MAP:
		var i: int = _ix[k]
		if i < 0:
			continue
		var local := sk.get_bone_pose_rotation(i)
		if undo.has(k):
			local = local * (undo[k] as Quaternion).inverse()
		if face != Quaternion.IDENTITY:
			local = face * local * _face_inv
		var par := sk.get_bone_parent(i)
		var pq: Quaternion = tg.get(sk.get_bone_name(par), Quaternion.IDENTITY) if par >= 0 else Quaternion.IDENTITY
		tg[k] = (pq * local).normalized()
	var g := {}
	for k in tg:
		g[MAP[k]] = ((tg[k] as Quaternion) * _corr.get(MAP[k], Quaternion.IDENTITY)).normalized()
	g["Spine1"] = (g["Spine"] as Quaternion).slerp(g["Spine2"], 0.5)
	for side in ["Left", "Right"]:
		if sound_arms and g.has(side + "Arm") and g.has(side + "ForeArm"):
			_sound_arm(g, side)
		# The collarbone carries part of an arm raised past level.
		var arm: Quaternion = g[side + "Arm"]
		var up := (arm * WsgRig.bone_axis(joints, side + "Arm")).y
		var lift := clampf(up, 0.0, 1.0) * deg_to_rad(18.0)
		g[side + "Shoulder"] = (g["Spine2"] as Quaternion) * Quaternion(Vector3.BACK if side == "Left" else Vector3.FORWARD, lift)
		g[side + "ToeBase"] = g[side + "Foot"]
	var out := {}
	for b in WsgRig.BONES:
		var nm: String = b[0]
		if not g.has(nm):
			continue
		var par: String = b[1]
		out[nm] = ((g[par] as Quaternion).inverse() * g[nm]).normalized() if par != "" and g.has(par) else g[nm]
	out["@hips"] = face * (sk.get_bone_pose_position(_ix["hips"]) - _hips_rest) * _hips_k
	_last_global = g
	return out


var _last_global := {}


## The arm through the same shoulder and wrist, made anatomical (see TURN_MAX).
func _sound_arm(g: Dictionary, side: String) -> void:
	var r := sound_arm(g["Spine2"], side, g[side + "Arm"], g[side + "ForeArm"], g.get(side + "Hand", g[side + "ForeArm"]))
	g[side + "Arm"] = r[0]
	g[side + "ForeArm"] = r[1]
	if g.has(side + "Hand"):
		g[side + "Hand"] = r[2]


## An arm's upper arm, forearm and hand (skeleton space) made anatomical under a chest (skeleton space): [upper arm,
## forearm, hand]. The elbow bent forward in its hinge, and the arm swivelled about the line from the shoulder to the
## wrist (which keeps the hand where it is) the least way that has the elbow pointing within TURN_MAX of the way an
## arm in that place bends and - a held hand - the hand turned within WRIST_MAX of the forearm (beyond it the forearm
## wrings like a sweet wrapper); a hand not held is then turned back to WRIST_MAX if it must be. WsgPoseLayer calls it
## again with the body's own chest when it lays an arm in body space (body_pose) over a chest of the motion capture's.
func sound_arm(chest: Quaternion, side: String, arm: Quaternion, fore: Quaternion, hand: Quaternion) -> Array:
	var r := _sound(chest, side, arm, fore, hand, held.has(side))
	if held.has(side):
		return [r[0], r[1], hand]
	var f0: Vector3 = _arm[side][1]
	var st := WsgRig.swing_twist((r[1] as Quaternion).inverse() * hand, f0)
	var a := WsgRig.twist_angle(st[1], f0)
	var lim := deg_to_rad(WRIST_MAX)
	if absf(a) > lim:
		hand = (r[1] as Quaternion) * (st[0] as Quaternion) * Quaternion(f0, clampf(a, -lim, lim))
	return [r[0], r[1], hand]


func _sound(chest: Quaternion, side: String, arm: Quaternion, fore: Quaternion, hand: Quaternion, wrist: bool) -> Array:
	var best := _arm_at(chest, side, arm, fore, hand, 0.0, wrist)
	if best[2] <= 0.0:
		return best
	# Swivelled: every 15 degrees round, then the best of them narrowed down.
	var step := deg_to_rad(15.0)
	var at := 0.0
	for i in range(1, 24):
		var s := -PI + step * i if i < 12 else step * (i - 11)
		var c := _arm_at(chest, side, arm, fore, hand, s, wrist)
		if c[2] < best[2]:
			best = c
			at = s
	var span := step * 0.5
	for _j in 4:
		for s in [at - span, at + span]:
			var c := _arm_at(chest, side, arm, fore, hand, s, wrist)
			if c[2] < best[2]:
				best = c
				at = s
		span *= 0.5
	return best


## The arm swivelled by s (radians, about the shoulder-wrist line) and its elbow made a forward hinge: [upper arm,
## forearm, how far out of range it is (the elbow; and the wrist, wrist_too) (radians, plus a little for every degree swivelled: the game's own elbow is
## best)].
func _arm_at(chest: Quaternion, side: String, arm: Quaternion, fore: Quaternion, hand: Quaternion, s: float, wrist_too: bool) -> Array:
	var spec: Array = _arm[side]
	var a0: Vector3 = spec[0]
	var f0: Vector3 = spec[1]
	var ci := chest.inverse()
	var u := ci * (arm * a0)
	var f := ci * (fore * f0)
	var w := u * float(spec[2]) + f * float(spec[3])
	if s != 0.0:
		var r := Quaternion(w.normalized(), s)
		arm = chest * r * ci * arm
		fore = chest * r * ci * fore
		u = r * u
		f = r * f
	var bend := u.angle_to(f)
	var k := smoothstep(deg_to_rad(4.0), deg_to_rad(14.0), bend)
	if k > 0.0:
		var b := f - u * f.dot(u)
		if b.length_squared() > 1e-8:
			b = b.normalized()
			# The upper arm turned so its hinge bends toward the wrist; the forearm bent about the hinge.
			var c0 := (Vector3.BACK - a0 * Vector3.BACK.dot(a0)).normalized()
			var rest := Basis(a0, c0, a0.cross(c0))
			var want := Basis(u, b, u.cross(b))
			var q_arm := (chest * (want * rest.inverse()).get_rotation_quaternion()).normalized()
			var q_fore := q_arm * Quaternion(Vector3.DOWN if side == "Left" else Vector3.UP, bend)
			arm = arm.slerp(q_arm, k)
			fore = fore.slerp(q_fore, k)
	# The forearm a true hinge, as WsgRigDriver makes it (or that would hand the rest of its turn on to the hand).
	var axis := Vector3.DOWN if side == "Left" else Vector3.UP
	var d := (arm.inverse() * fore) * f0
	var flat := d - axis * d.dot(axis)
	var ang := f0.signed_angle_to(flat.normalized(), axis) if flat.length_squared() > 1e-8 else 0.0
	fore = arm * Quaternion(axis, clampf(ang, deg_to_rad(-2.0), deg_to_rad(WsgRig.ELBOW_MAX)))
	var turn := absf(elbow_turn(u, f)) * k
	var out := maxf(0.0, turn - deg_to_rad(TURN_MAX))
	if wrist_too:
		var tw: Quaternion = WsgRig.swing_twist(fore.inverse() * hand, f0)[1]
		out += maxf(0.0, absf(WsgRig.twist_angle(tw, f0)) - deg_to_rad(WRIST_MAX))
	return [arm, fore, out + (absf(s) * 0.02 if out > 0.0 or s != 0.0 else 0.0)]


## Which way an elbow points (radians, signed about the upper arm): 0 when the forearm bends the way an arm in that
## place bends with the upper arm not turned (forward when it hangs; carried along by the shortest turn from hanging
## when it is raised or swung), ±PI when it points the opposite way. u: the upper arm's direction, f: the forearm's,
## in the chest (+Z forward, +Y up). 0 for a straight arm or one pointing almost straight up.
static func elbow_turn(u: Vector3, f: Vector3) -> float:
	var b := f - u * f.dot(u)
	if b.length_squared() < 1e-6 or u.y > 0.9:
		return 0.0
	var n := Quaternion(Vector3.DOWN, u) * Vector3.BACK
	n = n - u * n.dot(u)
	return n.normalized().signed_angle_to(b.normalized(), u)


## The rig's bones as they lie in the body (skeleton space) in the last read(): for WsgPoseLayer.body_pose, when a
## part must be where the game's body has it (a hand holding a stick) rather than turned like it.
func body_space(bones: Array) -> Dictionary:
	var out := {}
	for b in bones:
		if _last_global.has(b):
			out[b] = _last_global[b]
	return out
