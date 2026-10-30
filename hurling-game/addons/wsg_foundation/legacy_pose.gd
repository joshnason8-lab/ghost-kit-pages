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
var _ix := {}
var _corr := {}          # rig bone -> its rest turned onto the 17's rest (arms: T to hanging)
var _hips_k := 1.0
var _hips_rest := Vector3.ZERO


func _init(toon_skeleton: Skeleton3D, rig_joints: Dictionary) -> void:
	sk = toon_skeleton
	joints = rig_joints
	for k in MAP:
		_ix[k] = sk.find_bone(k)
	for k in CHILD:
		var c := sk.find_bone(CHILD[k])
		var b := sk.find_bone(k)
		if b < 0 or c < 0:
			continue
		var toon_dir := (sk.get_bone_global_rest(c).origin - sk.get_bone_global_rest(b).origin).normalized()
		var rig_dir := WsgRig.bone_axis(joints, MAP[k])
		_corr[MAP[k]] = Quaternion(rig_dir, toon_dir)
	# The hand follows the forearm's correction (it has no child in the 17).
	for side in ["Left", "Right"]:
		_corr[side + "Hand"] = _corr.get(side + "ForeArm", Quaternion.IDENTITY)
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
		var par := sk.get_bone_parent(i)
		var pq: Quaternion = tg.get(sk.get_bone_name(par), Quaternion.IDENTITY) if par >= 0 else Quaternion.IDENTITY
		tg[k] = (pq * local).normalized()
	var g := {}
	for k in tg:
		g[MAP[k]] = ((tg[k] as Quaternion) * _corr.get(MAP[k], Quaternion.IDENTITY)).normalized()
	g["Spine1"] = (g["Spine"] as Quaternion).slerp(g["Spine2"], 0.5)
	for side in ["Left", "Right"]:
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
	out["@hips"] = (sk.get_bone_pose_position(_ix["hips"]) - _hips_rest) * _hips_k
	_last_global = g
	return out


var _last_global := {}


## The rig's bones as they lie in the body (skeleton space) in the last read(): for WsgPoseLayer.body_pose, when a
## part must be where the game's body has it (a hand holding a stick) rather than turned like it.
func body_space(bones: Array) -> Dictionary:
	var out := {}
	for b in bones:
		if _last_global.has(b):
			out[b] = _last_global[b]
	return out
