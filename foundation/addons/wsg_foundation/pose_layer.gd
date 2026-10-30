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

var _target := 0.0
var _rate := 0.0
var _ix := {}
var _for := -1


## The pose: {bone: local Quaternion}, and "@hips" (the hips' offset from the rest) if it moves them.
func set_pose(p: Dictionary) -> void:
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
	if hips != Vector3.INF:
		var h := sk.find_bone("Hips")
		sk.set_bone_pose_position(h, sk.get_bone_pose_position(h).lerp(sk.get_bone_rest(h).origin + hips, w))
