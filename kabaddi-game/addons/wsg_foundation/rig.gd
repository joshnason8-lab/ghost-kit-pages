class_name WsgRig
extends RefCounted
## The World Stage Games humanoid rig: one skeleton for every player, official and fan in every game.
##
## Names follow Mixamo / HumanIK (no "mixamorig:" prefix), so Mixamo, MoCap Online (HumanIK) and ActorCore clips map
## onto it by name. 70 bones: 22 for the body, 30 for the fingers (three joints each), 18 helpers that keep the
## elbows, knees, shoulders, hips and forearms in shape (they are driven by WsgRigDriver, never by a clip).
##
## Conventions (the "canonical rest"):
##   - metres, the soles at y = 0, the hips over the origin, facing +Z, the character's left is +X;
##   - the rest is a T-pose: arms straight out along +-X with the palms down, legs straight down, feet flat;
##   - EVERY bone's rest rotation is the identity, so a bone's pose is simply its turn from that T-pose, and a world
##     direction means the same thing on every bone (+Y up, +Z forward, +X the character's left).
## A character (the owner's hurler, an official, a fan) is baked into this rest by tools/bake_character.gd; clips are
## retargeted onto it by tools/bake_clips.gd. Neither the rig nor this file holds any licensed data.

## name, parent, default position in the rest (metres, for a 1.80 m body; a baked character brings its own).
const BONES := [
	["Hips", "", Vector3(0, 0.98, 0)],
	["Spine", "Hips", Vector3(0, 1.08, 0)],
	["Spine1", "Spine", Vector3(0, 1.22, 0)],
	["Spine2", "Spine1", Vector3(0, 1.36, 0)],
	["Neck", "Spine2", Vector3(0, 1.55, 0)],
	["Head", "Neck", Vector3(0, 1.64, 0.01)],
	["LeftShoulder", "Spine2", Vector3(0.03, 1.50, 0)],
	["LeftArm", "LeftShoulder", Vector3(0.18, 1.47, 0)],
	["LeftForeArm", "LeftArm", Vector3(0.47, 1.47, 0)],
	["LeftHand", "LeftForeArm", Vector3(0.73, 1.47, 0)],
	["RightShoulder", "Spine2", Vector3(-0.03, 1.50, 0)],
	["RightArm", "RightShoulder", Vector3(-0.18, 1.47, 0)],
	["RightForeArm", "RightArm", Vector3(-0.47, 1.47, 0)],
	["RightHand", "RightForeArm", Vector3(-0.73, 1.47, 0)],
	["LeftUpLeg", "Hips", Vector3(0.09, 0.93, 0)],
	["LeftLeg", "LeftUpLeg", Vector3(0.09, 0.50, 0)],
	["LeftFoot", "LeftLeg", Vector3(0.09, 0.08, -0.02)],
	["LeftToeBase", "LeftFoot", Vector3(0.09, 0.02, 0.12)],
	["RightUpLeg", "Hips", Vector3(-0.09, 0.93, 0)],
	["RightLeg", "RightUpLeg", Vector3(-0.09, 0.50, 0)],
	["RightFoot", "RightLeg", Vector3(-0.09, 0.08, -0.02)],
	["RightToeBase", "RightFoot", Vector3(-0.09, 0.02, 0.12)],
	# Fingers: palm down, along the arm. 1 at the knuckle, 3 the last joint.
	["LeftHandThumb1", "LeftHand", Vector3(0.755, 1.455, 0.03)],
	["LeftHandThumb2", "LeftHandThumb1", Vector3(0.785, 1.445, 0.052)],
	["LeftHandThumb3", "LeftHandThumb2", Vector3(0.81, 1.44, 0.066)],
	["LeftHandIndex1", "LeftHand", Vector3(0.82, 1.465, 0.033)],
	["LeftHandIndex2", "LeftHandIndex1", Vector3(0.862, 1.465, 0.034)],
	["LeftHandIndex3", "LeftHandIndex2", Vector3(0.89, 1.465, 0.034)],
	["LeftHandMiddle1", "LeftHand", Vector3(0.825, 1.467, 0.011)],
	["LeftHandMiddle2", "LeftHandMiddle1", Vector3(0.871, 1.467, 0.011)],
	["LeftHandMiddle3", "LeftHandMiddle2", Vector3(0.902, 1.467, 0.011)],
	["LeftHandRing1", "LeftHand", Vector3(0.82, 1.465, -0.011)],
	["LeftHandRing2", "LeftHandRing1", Vector3(0.862, 1.465, -0.012)],
	["LeftHandRing3", "LeftHandRing2", Vector3(0.89, 1.465, -0.012)],
	["LeftHandPinky1", "LeftHand", Vector3(0.81, 1.46, -0.031)],
	["LeftHandPinky2", "LeftHandPinky1", Vector3(0.842, 1.46, -0.033)],
	["LeftHandPinky3", "LeftHandPinky2", Vector3(0.864, 1.46, -0.034)],
	["RightHandThumb1", "RightHand", Vector3(-0.755, 1.455, 0.03)],
	["RightHandThumb2", "RightHandThumb1", Vector3(-0.785, 1.445, 0.052)],
	["RightHandThumb3", "RightHandThumb2", Vector3(-0.81, 1.44, 0.066)],
	["RightHandIndex1", "RightHand", Vector3(-0.82, 1.465, 0.033)],
	["RightHandIndex2", "RightHandIndex1", Vector3(-0.862, 1.465, 0.034)],
	["RightHandIndex3", "RightHandIndex2", Vector3(-0.89, 1.465, 0.034)],
	["RightHandMiddle1", "RightHand", Vector3(-0.825, 1.467, 0.011)],
	["RightHandMiddle2", "RightHandMiddle1", Vector3(-0.871, 1.467, 0.011)],
	["RightHandMiddle3", "RightHandMiddle2", Vector3(-0.902, 1.467, 0.011)],
	["RightHandRing1", "RightHand", Vector3(-0.82, 1.465, -0.011)],
	["RightHandRing2", "RightHandRing1", Vector3(-0.862, 1.465, -0.012)],
	["RightHandRing3", "RightHandRing2", Vector3(-0.89, 1.465, -0.012)],
	["RightHandPinky1", "RightHand", Vector3(-0.81, 1.46, -0.031)],
	["RightHandPinky2", "RightHandPinky1", Vector3(-0.842, 1.46, -0.033)],
	["RightHandPinky3", "RightHandPinky2", Vector3(-0.864, 1.46, -0.034)],
	# Helpers (positions follow from the joints: helper_positions()).
	["LeftShoulderHelper", "LeftShoulder", Vector3.ZERO],
	["LeftArmRoll", "LeftArm", Vector3.ZERO],
	["LeftElbowHelper", "LeftArm", Vector3.ZERO],
	["LeftForeArmRoll", "LeftForeArm", Vector3.ZERO],
	["LeftForeArmRoll2", "LeftForeArm", Vector3.ZERO],
	["RightShoulderHelper", "RightShoulder", Vector3.ZERO],
	["RightArmRoll", "RightArm", Vector3.ZERO],
	["RightElbowHelper", "RightArm", Vector3.ZERO],
	["RightForeArmRoll", "RightForeArm", Vector3.ZERO],
	["RightForeArmRoll2", "RightForeArm", Vector3.ZERO],
	["LeftHipHelper", "Hips", Vector3.ZERO],
	["LeftUpLegRoll", "LeftUpLeg", Vector3.ZERO],
	["LeftKneeHelper", "LeftUpLeg", Vector3.ZERO],
	["LeftLegRoll", "LeftLeg", Vector3.ZERO],
	["RightHipHelper", "Hips", Vector3.ZERO],
	["RightUpLegRoll", "RightUpLeg", Vector3.ZERO],
	["RightKneeHelper", "RightUpLeg", Vector3.ZERO],
	["RightLegRoll", "RightLeg", Vector3.ZERO],
]

const FINGERS := ["Thumb", "Index", "Middle", "Ring", "Pinky"]

## Each helper: [the joint it sits at or the bone it lies along, where along it (0..1 from that bone's joint to its
## child's), what drives it]. Drivers (WsgRigDriver):
##   "half_swing": half of the named bone's swing (its turn with the twist about its own length removed) - keeps a
##                 ball joint round: the shoulder, the hip;
##   "half_bend":  half of the named bone's turn - keeps a hinge round: the elbow, the knee;
##   "untwist":    the named bone's own twist taken back by the fraction - the top of the upper arm and thigh do not
##                 spin with the bone (no candy-wrap at the shoulder or the hip);
##   "twist":      the fraction of the named child's twist about this bone's length - the forearm turns with the hand
##                 a little more toward the wrist (pronation), the shin with the foot.
const HELPERS := {
	"ShoulderHelper": ["Arm", 0.0, "half_swing", "Arm", 0.5],
	"ArmRoll": ["Arm", 0.45, "untwist", "Arm", 0.5],
	"ElbowHelper": ["ForeArm", 0.0, "half_bend", "ForeArm", 0.5],
	"ForeArmRoll": ["ForeArm", 0.4, "twist", "Hand", 0.33],
	"ForeArmRoll2": ["ForeArm", 0.72, "twist", "Hand", 0.66],
	"HipHelper": ["UpLeg", 0.0, "half_swing", "UpLeg", 0.5],
	"UpLegRoll": ["UpLeg", 0.45, "untwist", "UpLeg", 0.5],
	"KneeHelper": ["Leg", 0.0, "half_bend", "Leg", 0.5],
	"LegRoll": ["Leg", 0.6, "twist", "Foot", 0.4],
}

## Corrective push (metres at a 90 degree bend, in the parent bone's frame): a bent elbow's point and a bent knee's
## cap stand out from the joint as the bone ends meet; plain skinning flattens them. The helper moves out by this
## much times the bend, carrying the skin over the joint's outside with it.
const PUSH := {"ElbowHelper": Vector3(0, 0, -0.022), "KneeHelper": Vector3(0, 0, 0.026)}

## The limbs the bake spreads weights along (chain parameter s: 0 at the first joint, 1 at the second, 2 at the end)
## and where each bone's influence peaks on that chain. See tools/bake_character.gd.
const ARM_CHAIN := [["ShoulderHelper", 0.0], ["ArmRoll", 0.45], ["Arm", 0.84], ["ElbowHelper", 1.0], ["ForeArm", 1.12],
	["ForeArmRoll", 1.4], ["ForeArmRoll2", 1.72], ["Hand", 2.04]]
const LEG_CHAIN := [["HipHelper", 0.0], ["UpLegRoll", 0.45], ["UpLeg", 0.84], ["KneeHelper", 1.0], ["Leg", 1.16],
	["LegRoll", 1.6], ["Foot", 2.04]]

## Hinge limits (degrees) the driver keeps the elbows and knees inside: no inverted elbows or knees, ever.
const ELBOW_MAX := 150.0
const KNEE_MAX := 160.0

static var _index := {}


static func bone_count() -> int:
	return BONES.size()


static func index(name: String) -> int:
	if _index.is_empty():
		for i in BONES.size():
			_index[BONES[i][0]] = i
	return int(_index.get(name, -1))


static func parent_name(name: String) -> String:
	return BONES[index(name)][1]


static func is_helper(name: String) -> bool:
	return HELPERS.has(name.trim_prefix("Left").trim_prefix("Right"))


static func is_finger(name: String) -> bool:
	return name.contains("Hand") and name != "LeftHand" and name != "RightHand"


## The default joints (bone -> rest position), helpers included.
static func default_joints() -> Dictionary:
	var j := {}
	for b in BONES:
		if not is_helper(b[0]):
			j[b[0]] = b[2]
	return with_helpers(j)


## Fills in the helpers' positions from the body's joints.
static func with_helpers(joints: Dictionary) -> Dictionary:
	var out := joints.duplicate()
	for side in ["Left", "Right"]:
		var next := {"Arm": "ForeArm", "ForeArm": "Hand", "UpLeg": "Leg", "Leg": "Foot"}
		for h in HELPERS:
			var spec: Array = HELPERS[h]
			var a: Vector3 = joints[side + spec[0]]
			var b: Vector3 = joints[side + next[spec[0]]]
			out[side + h] = a.lerp(b, spec[1])
	return out


## A Skeleton3D in the canonical rest for these joints (every rest rotation the identity).
static func build_skeleton(joints: Dictionary) -> Skeleton3D:
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	for b in BONES:
		sk.add_bone(b[0])
	for i in BONES.size():
		var b: Array = BONES[i]
		var pos: Vector3 = joints[b[0]]
		var origin := pos
		if b[1] != "":
			sk.set_bone_parent(i, index(b[1]))
			origin = pos - (joints[b[1]] as Vector3)
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, origin))
	sk.reset_bone_poses()
	return sk


## The Skin that binds a baked character's mesh (vertices in the canonical rest) to that skeleton.
static func build_skin(joints: Dictionary) -> Skin:
	var skin := Skin.new()
	for i in BONES.size():
		skin.add_named_bind(BONES[i][0], Transform3D(Basis.IDENTITY, -(joints[BONES[i][0]] as Vector3)))
	return skin


## Rest direction of a bone (toward its child joint), in the rest (= world, = its own local frame).
static func bone_axis(joints: Dictionary, name: String) -> Vector3:
	var child := {"Arm": "ForeArm", "ForeArm": "Hand", "UpLeg": "Leg", "Leg": "Foot", "Hand": "HandMiddle1",
		"Foot": "ToeBase", "Shoulder": "Arm"}
	var side := "Left" if name.begins_with("Left") else ("Right" if name.begins_with("Right") else "")
	var base := name.trim_prefix(side)
	if child.has(base):
		return ((joints[side + child[base]] as Vector3) - (joints[name] as Vector3)).normalized()
	return Vector3.UP


## Swing-twist split of q about the unit axis: q = swing * twist, twist a turn about axis.
static func swing_twist(q: Quaternion, axis: Vector3) -> Array:
	var p := Vector3(q.x, q.y, q.z).project(axis)
	var twist := Quaternion(p.x, p.y, p.z, q.w)
	if twist.length_squared() < 1e-9:
		twist = Quaternion.IDENTITY
	else:
		twist = twist.normalized()
	return [q * twist.inverse(), twist]


## The signed angle (radians) of a twist quaternion about axis.
static func twist_angle(twist: Quaternion, axis: Vector3) -> float:
	var a := 2.0 * atan2(Vector3(twist.x, twist.y, twist.z).dot(axis), twist.w)
	return wrapf(a, -PI, PI)
