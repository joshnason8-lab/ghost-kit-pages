class_name FloorLegs
extends SkeletonModifier3D
## The feet on the floor under the game's whole-body pose (FoundationLink, mode "full"). The game turns this rig's
## legs as it turns its own, and this rig's legs are not the game's lengths: a crouch or a bent knee put its toes up to
## 16 cm under the floor (the owner, penalty shots: "the player on the penalty mini games feet are under the floor").
## Raising the whole body put its shoulders over the game's, and the lower hand could no longer reach the stick; so
## the legs bend instead: an ankle or toe lower than it stands is brought up to the floor by two-bone IK (thigh and
## shin; the knee bending the way it was, the foot keeping its turn in the world), the hips, trunk and arms as they
## were. Nothing is held or eased (the planter's work, off under the game's pose): a frame's floor only.

const LEGS := WsgFootPlanter.LEGS
var ground_y := 0.0
var _ix := []
var _ankle_rest := 0.08
var _toe_rest := 0.02
var _for := -1
## The most an ankle or toe lacked of its standing height this frame, before the IK and after it (for the tests).
var lacked := 0.0
var worst := 0.0


func _cache(sk: Skeleton3D) -> void:
	if _for == sk.get_instance_id():
		return
	_for = sk.get_instance_id()
	_ix.clear()
	for leg in LEGS:
		_ix.append(leg.map(func(n): return sk.find_bone(n)))
	_ankle_rest = sk.get_bone_global_rest(_ix[0][2]).origin.y
	_toe_rest = sk.get_bone_global_rest(_ix[0][3]).origin.y


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	_cache(sk)
	if _ix.is_empty() or (_ix[0] as Array).has(-1) or (_ix[1] as Array).has(-1):
		return
	var xf := sk.global_transform
	var inv := xf.affine_inverse()
	var sc := xf.basis.get_scale().y
	var floor_ankle := ground_y + _ankle_rest * sc
	var floor_toe := ground_y + _toe_rest * sc
	lacked = 0.0
	worst = 0.0
	for leg: Array in _ix:
		var ank := xf * sk.get_bone_global_pose(leg[2]).origin
		var toe := xf * sk.get_bone_global_pose(leg[3]).origin
		var lack := maxf(floor_ankle - ank.y, floor_toe - toe.y)
		if lack <= 0.001:
			continue
		# The foot keeps its turn in the world, so the ankle raised by what it lacks raises the toe as much.
		_leg_ik(sk, leg, inv * (ank + Vector3(0, lack, 0)))
		lacked = maxf(lacked, lack)
		var ank2 := xf * sk.get_bone_global_pose(leg[2]).origin
		var toe2 := xf * sk.get_bone_global_pose(leg[3]).origin
		worst = maxf(worst, maxf(floor_ankle - ank2.y, floor_toe - toe2.y))


## As WsgFootPlanter._leg_ik (Hurling's player.gd _leg_ik): the thigh and shin turned so the ankle is at target
## (skeleton space), the knee bending the way it was (forward of the thigh), its hinge square to the leg's plane; the
## foot keeping its turn.
func _leg_ik(sk: Skeleton3D, leg: Array, target: Vector3) -> void:
	var th := sk.get_bone_global_pose(leg[0])
	var sh := sk.get_bone_global_pose(leg[1])
	var ft := sk.get_bone_global_pose(leg[2])
	var hip := th.origin
	var knee := sh.origin
	var a := hip.distance_to(knee)
	var b := knee.distance_to(ft.origin)
	var to := target - hip
	var d := clampf(to.length(), absf(a - b) + 0.001, (a + b) * 0.999)
	var dir := to.normalized()
	var x := (a * a - b * b + d * d) / (2.0 * d)
	var h := sqrt(maxf(0.0, a * a - x * x))
	var pole := (knee - hip) - dir * (knee - hip).dot(dir)
	var fwd := th.basis * Vector3(0, 0, 1)
	fwd -= dir * fwd.dot(dir)
	if pole.length() < 0.0001 or pole.dot(fwd) <= 0.0:
		pole = fwd
	var new_knee := hip + dir * x + pole.normalized() * h
	var ankle := hip + dir * d
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(leg[0])).basis
	var th_b := Basis(Quaternion((knee - hip).normalized(), (new_knee - hip).normalized())) * th.basis
	var tdir := (new_knee - hip).normalized()
	var normal := tdir.cross(ankle - new_knee)
	if normal.length() > 1e-4:
		normal = normal.normalized()
		var hx := th_b * Vector3.RIGHT
		if hx.dot(normal) < 0.0:
			normal = -normal
		var hx_flat := (hx - tdir * hx.dot(tdir)).normalized()
		th_b = Basis(Quaternion(hx_flat, normal)) * th_b
	sk.set_bone_pose_rotation(leg[0], (parent.inverse() * th_b).get_rotation_quaternion())
	var sh_now := th_b * (th.basis.inverse() * sh.basis)
	var sh_dir := sh_now * (sh.basis.inverse() * (ft.origin - knee)).normalized()
	var sh_b := Basis(Quaternion(sh_dir.normalized(), (ankle - new_knee).normalized())) * sh_now
	sk.set_bone_pose_rotation(leg[1], (th_b.inverse() * sh_b).get_rotation_quaternion())
	sk.set_bone_pose_rotation(leg[2], (sh_b.inverse() * ft.basis).get_rotation_quaternion())
