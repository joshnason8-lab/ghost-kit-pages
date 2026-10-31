class_name WsgRigDriver
extends SkeletonModifier3D
## Keeps a WsgRig body anatomically sound whatever poses it (a clip, a game's own pose, IK):
##   mode NORMALIZE (put it before any IK): the elbows and knees become true hinges inside their limits - never bent
##     backwards - and their twist moves to the hand or foot, so the hand and foot keep the way they face; the ankles
##     stay inside their range (no toes pointing up at the sky).
##   mode HELPERS (put it last): drives the 18 helper bones from the body - half of each shoulder's and hip's swing,
##     half of each elbow's and knee's bend, the upper arm and thigh untwisted at the top, the forearm turning with
##     the hand toward the wrist - which is what keeps the mesh round at the joints (no candy-wrap, no collapsing
##     elbows). Cheap: about 30 quaternion operations a body a frame.
## WsgBody adds both. A game that poses the skeleton itself gets the same protection for free.

enum Mode { NORMALIZE, HELPERS }

@export var mode: Mode = Mode.HELPERS
## Ankle range (degrees): how far the toes may come up (dorsiflexion) and point down, and roll to either side.
@export var ankle_up := 30.0
@export var ankle_down := 55.0
@export var ankle_roll := 25.0

var _ready_for := -1
var _ix := {}
var _axis := {}     # bone -> its rest direction (unit), in its own (= the rest) frame


func _cache(sk: Skeleton3D) -> void:
	if _ready_for == sk.get_instance_id():
		return
	_ready_for = sk.get_instance_id()
	_ix.clear()
	for b in WsgRig.BONES:
		_ix[b[0]] = sk.find_bone(b[0])
	var j := {}
	for b in WsgRig.BONES:
		var i: int = _ix[b[0]]
		if i >= 0:
			j[b[0]] = sk.get_bone_global_rest(i).origin
	for side in ["Left", "Right"]:
		for base in ["Arm", "ForeArm", "UpLeg", "Leg"]:
			_axis[side + base] = WsgRig.bone_axis(j, side + base)


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_cache(sk)
	if _ix.get("Hips", -1) < 0:
		return
	for side in ["Left", "Right"]:
		if mode == Mode.NORMALIZE:
			_hinge(sk, side + "ForeArm", side + "Hand", Vector3.DOWN if side == "Left" else Vector3.UP, WsgRig.ELBOW_MAX)
			_hinge(sk, side + "Leg", side + "Foot", Vector3.RIGHT, WsgRig.KNEE_MAX)
			_ankle(sk, side + "Foot")
		else:
			_helpers(sk, side)


## The child bone made a hinge about axis (its parent's frame), bent 0..max_deg; whatever else it turned (twist,
## turning out of the hinge's plane) handed down to the end bone so that keeps the way it faced.
func _hinge(sk: Skeleton3D, bone: String, end: String, axis: Vector3, max_deg: float) -> void:
	var i: int = _ix[bone]
	var e: int = _ix[end]
	var q := sk.get_bone_pose_rotation(i)
	var rest_dir: Vector3 = _axis[bone]
	var d := q * rest_dir
	var flat := d - axis * d.dot(axis)
	var ang := 0.0
	if flat.length_squared() > 1e-8:
		ang = rest_dir.signed_angle_to(flat.normalized(), axis)
	ang = clampf(ang, deg_to_rad(-2.0), deg_to_rad(max_deg))
	var qh := Quaternion(axis, ang)
	sk.set_bone_pose_rotation(i, qh)
	sk.set_bone_pose_rotation(e, (qh.inverse() * q * sk.get_bone_pose_rotation(e)).normalized())


## The foot inside the ankle's range, about the shin (x: toes down +, z: roll).
func _ankle(sk: Skeleton3D, foot: String) -> void:
	var i: int = _ix[foot]
	var e := Basis(sk.get_bone_pose_rotation(i)).get_euler(EULER_ORDER_YXZ)
	var c := Vector3(clampf(e.x, deg_to_rad(-ankle_up), deg_to_rad(ankle_down)), e.y,
		clampf(e.z, deg_to_rad(-ankle_roll), deg_to_rad(ankle_roll)))
	if not c.is_equal_approx(e):
		sk.set_bone_pose_rotation(i, Basis.from_euler(c, EULER_ORDER_YXZ).get_rotation_quaternion())


func _helpers(sk: Skeleton3D, side: String) -> void:
	for h in WsgRig.HELPERS:
		var hi: int = _ix.get(side + h, -1)
		if hi < 0:
			continue
		var spec: Array = WsgRig.HELPERS[h]
		var src: String = side + spec[3]
		var q := sk.get_bone_pose_rotation(_ix[src])
		var f: float = spec[4]
		var out := Quaternion.IDENTITY
		match spec[2]:
			"half_swing":
				var st := WsgRig.swing_twist(q, _axis[src])
				out = Quaternion.IDENTITY.slerp(st[0], f)
			"half_bend":
				out = Quaternion.IDENTITY.slerp(q, f)
				if WsgRig.PUSH.has(h):
					var bend := q.get_angle()
					sk.set_bone_pose_position(hi, sk.get_bone_rest(hi).origin + (WsgRig.PUSH[h] as Vector3) * (bend / (PI * 0.5)))
			"untwist":
				var ax: Vector3 = _axis[src]
				var tw: Quaternion = WsgRig.swing_twist(q, ax)[1]
				out = Quaternion(ax, -WsgRig.twist_angle(tw, ax) * f)
			"twist":
				# The child's twist about the length of the bone the helper hangs from.
				var ax: Vector3 = _axis[side + spec[0]]
				var tw: Quaternion = WsgRig.swing_twist(q, ax)[1]
				out = Quaternion(ax, WsgRig.twist_angle(tw, ax) * f)
		sk.set_bone_pose_rotation(hi, out)
