class_name WsgReplayPose
extends SkeletonModifier3D
## A body's kept pose put back during a replay (WsgReplay): every bone's turn and the hips' place, blended between
## two kept frames. The skeleton's last modifier, so what the drivers and helpers did is already in what it puts back.

var _a := PackedInt32Array()
var _b := PackedInt32Array()
var _w := 0.0


func set_frames(a: PackedInt32Array, b: PackedInt32Array, w: float) -> void:
	_a = a
	_b = b
	_w = w


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or _a.is_empty():
		return
	var n := mini(sk.get_bone_count(), (_a.size() - 15) / 2)
	var ha := Vector3(_a[12], _a[13], _a[14]) / 10000.0
	var hb := Vector3(_b[12], _b[13], _b[14]) / 10000.0
	sk.set_bone_pose_position(0, ha.lerp(hb, _w))
	for i in n:
		var k := 15 + i * 2
		var qa := _unpack(_a[k], _a[k + 1])
		var qb := _unpack(_b[k], _b[k + 1])
		sk.set_bone_pose_rotation(i, qa.slerp(qb, _w))


static func _unpack(i0: int, i1: int) -> Quaternion:
	var s := func(v: int) -> float:
		v &= 0xFFFF
		return float(v - 65536 if v >= 32768 else v) / 32767.0
	return Quaternion(s.call(i0), s.call(i0 >> 16), s.call(i1), s.call(i1 >> 16)).normalized()
