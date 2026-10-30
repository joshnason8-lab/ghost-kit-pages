class_name WsgFootPlanter
extends SkeletonModifier3D
## Planted feet: when a foot comes down (the clip's ankle low over the ground and all but still in the world) it is
## held where it landed, and the leg reaches it (two-bone IK, the knee bending the way it was, the foot keeping the way
## the clip turns it) until the clip lifts it; then it eases back to the clip over `release` seconds. No foot ever
## goes below the ground. This is what stops gliding feet when the game's speed and the clip's stride do not quite
## agree, or when the body turns. Contacts are found on the pose being shown, so they are right for any blend of clips.
## It also sets the hips' height for the body's own proportions (hips_offset, from WsgLocomotor).
## Runs after WsgRigDriver(NORMALIZE) and before the helpers (WsgBody.add_modifier puts it there).

const LEGS := [["LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase"], ["RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]]

## Each foot is down (found on the pose this frame; read it, do not set it).
var contact := [0.0, 0.0]
## The body's speed over the ground (m/s), from the locomotor: a foot moving much slower than it is planted.
var body_speed := 0.0
## Added to the hips' height after the clips (the body's hips against the clips' for its leg length).
var hips_offset := 0.0
## Down this frame and not last: a step (left 0, right 1), for footstep sounds.
signal landed(foot: int)
var _prev := [Vector3.INF, Vector3.INF]
var _tick := 0
var _done := -1
var _tick_dt := 1.0 / 30.0
## World height of the ground under the body.
var ground_y := 0.0
@export var release := 0.12
## Off: the feet do whatever the clip does (to measure what planting saves).
@export var enabled := true

var _lock := [Vector3.INF, Vector3.INF]     # world ankle position held
var _w := [0.0, 0.0]                         # how much the lock applies
var _hold := [Vector3.INF, Vector3.INF]     # where it was last held (eases from there when let go)
var _lifted := [false, false]               # let go at its reach's end: lifting, whatever its height says
var _toe_rest := 0.02
var _ix := []
var _ankle_rest := 0.08                      # ankle height over the soles at rest (model)
var _for := -1
## What each foot did this frame (world ankle), for measuring slide.
var ankle_world := [Vector3.ZERO, Vector3.ZERO]


func _cache(sk: Skeleton3D) -> void:
	if _for == sk.get_instance_id():
		return
	_for = sk.get_instance_id()
	_ix.clear()
	for leg in LEGS:
		_ix.append(leg.map(func(n): return sk.find_bone(n)))
	_ankle_rest = sk.get_bone_global_rest(_ix[0][2]).origin.y
	_toe_rest = sk.get_bone_global_rest(_ix[0][3]).origin.y


## Lets go of both feet at once (a teleport, a new play).
func reset() -> void:
	_lock = [Vector3.INF, Vector3.INF]
	_hold = [Vector3.INF, Vector3.INF]
	_w = [0.0, 0.0]
	_prev = [Vector3.INF, Vector3.INF]


## One step of the game's time (the locomotor calls it from drive()): the feet's contacts and holds are worked out
## once a step, on the step's own time, however often the skeleton redraws in between.
func tick(delta: float) -> void:
	_tick += 1
	_tick_dt = delta


func _process_modification_with_delta(_frame_delta: float) -> void:
	var fresh := _tick != _done
	_done = _tick
	var delta := _tick_dt if fresh else 0.0
	var sk := get_skeleton()
	if sk == null:
		return
	_cache(sk)
	if hips_offset != 0.0:
		var h := sk.find_bone("Hips")
		sk.set_bone_pose_position(h, sk.get_bone_pose_position(h) + Vector3(0, hips_offset, 0))
	var xf := sk.global_transform
	var inv := xf.affine_inverse()
	var sc := xf.basis.get_scale().y
	var floor_ankle := ground_y + _ankle_rest * sc
	for i in 2:
		var leg: Array = _ix[i]
		var ank := xf * sk.get_bone_global_pose(leg[2]).origin
		var hip := xf * sk.get_bone_global_pose(leg[0]).origin
		var reach := (sk.get_bone_global_rest(leg[0]).origin.distance_to(sk.get_bone_global_rest(leg[1]).origin)
			+ sk.get_bone_global_rest(leg[1]).origin.distance_to(sk.get_bone_global_rest(leg[2]).origin)) * sc * 0.995
		# Down: the clip's ankle near the ground and nearly still in the world (a stance foot moves back under the
		# body as fast as the body goes forward).
		# Height over the ground: the ankle's or the toe's, whichever is lower (a side-step rolls onto the foot's edge).
		var toe := xf * sk.get_bone_global_pose(leg[3]).origin
		var h := minf(ank.y - floor_ankle, toe.y - (ground_y + _toe_rest * sc))
		var was: bool = contact[i] > 0.5
		var is_down := was
		if fresh:
			var vel := 0.0
			if _prev[i] != Vector3.INF and delta > 0.0:
				vel = Vector2(ank.x - _prev[i].x, ank.z - _prev[i].z).length() / delta
			_prev[i] = ank
			# A landing foot is still moving as it touches (a heel strike decelerates over a frame or two): it sticks
			# where it lands. A swinging foot skimming the ground moves at about twice the body's speed: it does not.
			# Once down it stays down until the clip lifts it.
			is_down = h < 0.05 * sc if was else (h < 0.03 * sc and vel < 0.6 + body_speed * 0.8)
			# A foot let go at the end of its reach is lifting: not down again until it has left the ground.
			if _lifted[i]:
				if h > 0.05 * sc or vel < 0.2:
					_lifted[i] = false
				else:
					is_down = false
			if is_down and not was:
				landed.emit(i)
			contact[i] = 1.0 if is_down else 0.0
		var down: bool = enabled and is_down
		if down:
			if _lock[i] == Vector3.INF:
				# Planted means on the ground: the foot comes down until its lowest point (heel or ball) touches.
				_lock[i] = Vector3(ank.x, maxf(ank.y - maxf(h, 0.0), floor_ankle - 0.5 * _toe_rest * sc), ank.z)
			if hip.distance_to(_lock[i]) > reach * 1.5:
				# Far beyond the leg (the body put somewhere else: a restart, the next free): planted afresh under the foot
				# (drawn after it, the leg pointed at the old place, level with the hips).
				_lock[i] = Vector3(ank.x, maxf(ank.y - maxf(h, 0.0), floor_ankle - 0.5 * _toe_rest * sc), ank.z)
			if hip.distance_to(_lock[i]) > reach:
				# The body has gone on further than the leg reaches: the foot is drawn after it just far enough (the
				# least slide there can be), and stays down until the clip lifts it.
				_lock[i] = hip + (_lock[i] - hip).normalized() * reach
				_lock[i].y = maxf(_lock[i].y, floor_ankle)
				# (Drawn on and on - a clip that keeps a foot down while the body is carried on - each draw lifts it a
				# little, and it climbed to the hips: past a step's height it is let go to the clip instead.)
				if (_lock[i] as Vector3).y > floor_ankle + 0.2 * sc:
					_lock[i] = Vector3.INF
					down = false
		if down:
			_w[i] = 1.0
			_hold[i] = _lock[i]
		else:
			_lock[i] = Vector3.INF
			_w[i] = maxf(0.0, _w[i] - delta / release)
		var target := ank
		if _w[i] > 0.0 and _hold[i] != Vector3.INF:
			# Held, or easing back to the clip from where it was held: up first, then across, so a foot let go does
			# not skate over the ground catching up.
			var hw: float = smoothstep(0.0, 0.6, _w[i])
			var vw: float = _w[i] * _w[i]
			target = Vector3(lerpf(ank.x, _hold[i].x, hw), lerpf(ank.y, _hold[i].y, vw), lerpf(ank.z, _hold[i].z, hw))
		# Never through the ground.
		target.y = maxf(target.y, floor_ankle)
		if not target.is_equal_approx(ank):
			_leg_ik(sk, leg, inv * target)
		# Nor the toes: a foot pitched into the ground is turned up about the ankle until its toe is on it.
		var ft := sk.get_bone_global_pose(leg[2])
		var toe_now := xf * sk.get_bone_global_pose(leg[3]).origin
		var toe_floor := ground_y + _toe_rest * sc
		if toe_now.y < toe_floor - 0.002:
			var ank_now := xf * ft.origin
			var arm := toe_now - ank_now
			var want := Vector3(arm.x, 0, arm.z).normalized() * sqrt(maxf(0.0, arm.length_squared() - pow(toe_floor - ank_now.y, 2.0))) + Vector3(0, toe_floor - ank_now.y, 0)
			if arm.length() > 0.01 and want.length() > 0.01:
				var turn := Quaternion((xf.basis.inverse() * arm).normalized(), (xf.basis.inverse() * want).normalized())
				var parent := sk.get_bone_global_pose(sk.get_bone_parent(leg[2])).basis
				sk.set_bone_pose_rotation(leg[2], (parent.inverse() * (Basis(turn) * ft.basis)).get_rotation_quaternion())
		ankle_world[i] = xf * sk.get_bone_global_pose(leg[2]).origin


## The leg (thigh, shin) turned so its ankle is at target (skeleton space), the knee bending the way it was; the foot
## keeps its turn in the world. (As Hurling's player.gd _leg_ik, on the rig's bones.)
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
	if pole.length() < 0.0001:
		pole = th.basis * Vector3(0, 0, 1)
	var new_knee := hip + dir * x + pole.normalized() * h
	var ankle := hip + dir * d
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(leg[0])).basis
	var th_b := Basis(Quaternion((knee - hip).normalized(), (new_knee - hip).normalized())) * th.basis
	sk.set_bone_pose_rotation(leg[0], (parent.inverse() * th_b).get_rotation_quaternion())
	var sh_now := th_b * (th.basis.inverse() * sh.basis)
	var sh_dir := sh_now * (sh.basis.inverse() * (ft.origin - knee)).normalized()
	var sh_b := Basis(Quaternion(sh_dir.normalized(), (ankle - new_knee).normalized())) * sh_now
	sk.set_bone_pose_rotation(leg[1], (th_b.inverse() * sh_b).get_rotation_quaternion())
	sk.set_bone_pose_rotation(leg[2], (sh_b.inverse() * ft.basis).get_rotation_quaternion())
