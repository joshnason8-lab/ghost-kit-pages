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
## Off: no foot is planted (the feet do whatever the clip does: to measure what planting saves). The rest still runs:
## no ankle or toe lower than a standing one's over ground_y (by IK), a foot let go easing back over `release` (on
## tick()'s steps), the hips' lift. Under a pose the game makes of the whole body, use keep_pose instead.
@export var enabled := true
## The legs exactly as the pose before it has them (a game's own pose of the whole body: a dive, a kneel, a kick): no
## planting, no release easing, no floor or toe clamp, and whatever it held let go (nothing is held over when it is
## turned back off). Only the hips' lift (hips_offset) still applies, so a WsgPoseLayer under it keeps
## lift_after = hips_offset. Off by default. (enabled = false still lifts ankles to its floor and eases a released
## foot - on the locomotor's steps, which do not run under a game's pose - which bent a game's legs by up to 10 cm and
## held feet where the last stride left them (Sepak Takraw, Kho Kho); active = false skips the hips' lift too, so a
## layer's lift_after must then be 0.)
@export var keep_pose := false

var _lock := [Vector3.INF, Vector3.INF]     # world ankle position held
var _w := [0.0, 0.0]                         # how much the lock applies
var _hold := [Vector3.INF, Vector3.INF]     # where it was last held (eases from there when let go)
var _lifted := [false, false]               # let go at its reach's end: lifting, whatever its height says
## A foot let go at its reach's end takes a step of its own (STEP_TIME seconds, up and over to under its hip, where
## the body is going), and is planted there: the clip, its stride too short for the body (a sharp turn, a start or
## stop harder than its clips), kept it on the ground behind, and it slid there 3 to 13 cm (WsgSim's demo).
const STEP_TIME := 0.2
var _low_ticks := [0, 0]                     # ticks a foot let go has stayed on the ground (it steps at 2)
var _waited := [0, 0]                        # ticks since it was let go, neither stepping nor lifted (at 3: to the clip)
var _aired := [true, true]                   # off the ground since it last landed (a footstep needs it)
var _step_toe := [Vector3.INF, Vector3.INF] # the held toe from the ankle as the step began
var _toe_hold := [Vector3.INF, Vector3.INF] # where its toe was held (a foot released keeps its toe's place across)
## How far a planted foot's leg may twist (radians) before the foot turns with the body.
const TWIST_MAX := deg_to_rad(40.0)
var _yaw := [NAN, NAN]                       # the way a planted foot points (world yaw), held while its heel is down
var _drawn_yaw := [NAN, NAN]                 # the way each foot pointed as last drawn
var _drawn_basis := [Basis(), Basis()]       # each foot's turn as last drawn (world)
var _step_landed := [false, false]           # put down by its own step, its toe not yet down
var _across := [0.0, 0.0]                    # easing across from where a let-go foot was held (1 -> 0 over release)
var _step := [-1.0, -1.0]                    # how far through that step (0..1); -1: none
var _step_from := [Vector3.INF, Vector3.INF]
var _hip_prev := [Vector3.INF, Vector3.INF]
var _hip_vel := [Vector3.ZERO, Vector3.ZERO]
var _toe_lock := [Vector3.INF, Vector3.INF] # world toe (ball of the foot) held once it is down on the ground
var _low := [INF, INF]                       # the clip's lowest ankle height in this contact (its heel down)
var _foot := [Vector3.INF, Vector3.INF]     # toe to ankle as the heel came up (rolling over the ball from there)
var _up0 := [0.0, 0.0]                       # the clip's foot pitch then (sine)
var _ball := [Vector3.INF, Vector3.INF]     # the ankle rolling over the ball this step
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
	_step = [-1.0, -1.0]
	_low_ticks = [0, 0]
	_waited = [0, 0]
	_toe_hold = [Vector3.INF, Vector3.INF]
	_yaw = [NAN, NAN]
	_hip_prev = [Vector3.INF, Vector3.INF]
	_toe_lock = [Vector3.INF, Vector3.INF]
	_low = [INF, INF]
	_foot = [Vector3.INF, Vector3.INF]
	_ball = [Vector3.INF, Vector3.INF]
	_step_landed = [false, false]
	_across = [0.0, 0.0]
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
	if keep_pose:
		reset()
		contact = [0.0, 0.0]
		_lifted = [false, false]
		for i in 2:
			ankle_world[i] = xf * sk.get_bone_global_pose(_ix[i][2]).origin
		return
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
			if _hip_prev[i] != Vector3.INF and delta > 0.0:
				_hip_vel[i] = Vector3(hip.x - _hip_prev[i].x, 0.0, hip.z - _hip_prev[i].z) / delta
			_hip_prev[i] = hip
			# A landing foot is still moving as it touches (a heel strike decelerates over a frame or two): it sticks
			# where it lands. A swinging foot skimming the ground moves at about twice the body's speed: it does not.
			# Once down it stays down until the clip lifts it.
			# A foot FLAT on the ground (heel and toe both down) is planted however fast the clip moves it: a swing never
			# comes through flat, and one let slide there glided on the floor (a hard stop from a run: the clip brought
			# the foot in flat 23 cm a frame and snapped it back 7 cm, read as swinging - the lead, 2026-11-03).
			var flat := maxf(ank.y - floor_ankle, toe.y - (ground_y + _toe_rest * sc)) < 0.02 * sc
			is_down = h < 0.05 * sc if was else (h < 0.03 * sc and (vel < 0.6 + body_speed * 0.8 or flat))
			# A foot let go at the end of its reach is lifting: not down again until it has left the ground.
			if _lifted[i] and float(_step[i]) < 0.0:
				_waited[i] = int(_waited[i]) + 1
				if h > 0.05 * sc or vel < 0.2:
					_lifted[i] = false
				else:
					is_down = false
					# Let go, and the clip keeps it on the ground (its stride too short for the body: a sharp turn, a
					# start or stop harder than its clips): it steps. A foot the clip is lifting - every running
					# stride's toe-off is let go at the leg's reach - just goes with the clip (stepping those too
					# doubled the landings: Kho Kho's runners at 7.6 steps a second). Kept where it was across while
					# that is told (the release below).
					_low_ticks[i] = int(_low_ticks[i]) + (1 if h < 0.03 * sc else 0)
					if int(_low_ticks[i]) >= 2:
						_step[i] = 0.0
						_step_from[i] = ankle_world[i]
					elif int(_waited[i]) >= 3:
						# (Skimming, neither lifted nor kept down: to the clip.)
						_lifted[i] = false
			# A footstep is a foot that went up and came down: one let go at its reach and planted again without
			# leaving the ground (the clip's stance foot, still in the world) is the same footfall, not another - it
			# fired landed twice a stride (Kho Kho's sprinters: 5.3 footsteps a second, 4.8 the most).
			if h > 0.05 * sc:
				_aired[i] = true
			if is_down and not was and bool(_aired[i]):
				_aired[i] = false
				landed.emit(i)
			contact[i] = 1.0 if is_down else 0.0
		var stepping := Vector3.INF
		if float(_step[i]) >= 0.0:
			if fresh:
				_step[i] = float(_step[i]) + delta / STEP_TIME
			var st := minf(float(_step[i]), 1.0)
			var right := Vector3(xf.basis.x.x, 0.0, xf.basis.x.z).normalized()
			var side := clampf((ank - hip).dot(right), -0.2 * sc, 0.2 * sc)
			var to := Vector3(hip.x, floor_ankle, hip.z) + right * side + (_hip_vel[i] as Vector3) * (STEP_TIME * (1.0 - st) + 0.1)
			if st >= 1.0:
				# Down where it stepped to (until the clip lifts it, as any foot).
				_step[i] = -1.0
				_lifted[i] = false
				# Where the step drew it down (its last frame), not where the step would now aim: the body has gone on
				# since, and the foot was planted 4-8 cm further on in the next frame, flat on the floor.
				_lock[i] = Vector3(_hold[i].x, floor_ankle, _hold[i].z) if _hold[i] != Vector3.INF else to
				# Pointing the way the step drew it (as the heel's twist hold, up to TWIST_MAX): the clip's foot, in the
				# air in a hard stop, swung its toe 12 cm about the planted ankle as it landed.
				_yaw[i] = float(_drawn_yaw[i])
				_step_landed[i] = true
				_toe_lock[i] = Vector3.INF
				_low[i] = INF
				is_down = true
				if contact[i] < 0.5 and bool(_aired[i]):
					_aired[i] = false
					landed.emit(i)
				contact[i] = 1.0
			else:
				var from: Vector3 = _step_from[i]
				stepping = from.lerp(to, smoothstep(0.0, 1.0, st)) + Vector3(0.0, 0.08 * sc * sin(PI * st), 0.0)
				is_down = false
				contact[i] = 0.0
		var down: bool = enabled and is_down
		var ball := Vector3.INF
		if down:
			if _lock[i] == Vector3.INF:
				# Planted means on the ground: the foot comes down until its lowest point (heel or ball) touches.
				_lock[i] = Vector3(ank.x, maxf(ank.y - maxf(h, 0.0), floor_ankle - 0.5 * _toe_rest * sc), ank.z)
				if _w[i] > 0.0 and _hold[i] != Vector3.INF and ankle_world[i] != Vector3.ZERO:
					# Down again while still easing back from where it was last held (a stop from a sprint: the clip lifts
					# the foot for a frame and puts it down a stride on): planted where it is drawn, not where the clip
					# has it - it jumped there, 80-95 cm in a frame. If that is beyond the leg, it steps (as any foot).
					_lock[i].x = (ankle_world[i] as Vector3).x
					_lock[i].z = (ankle_world[i] as Vector3).z
			if hip.distance_to(_lock[i]) > reach * 1.5:
				# Far beyond the leg (the body put somewhere else: a restart, the next free): planted afresh under the foot
				# (drawn after it, the leg pointed at the old place, level with the hips).
				_lock[i] = Vector3(ank.x, maxf(ank.y - maxf(h, 0.0), floor_ankle - 0.5 * _toe_rest * sc), ank.z)
				_toe_lock[i] = Vector3.INF
			# The heel coming up (the clip's ankle rising off the ground) or the body gone on past the leg's reach, with
			# the ball of the foot down: the foot rolls over its ball - the toe stays where it is and the ankle goes up
			# about it (the clip's own foot pitch, steeper if the leg must reach further), instead of the whole foot
			# sliding after the body (the last 1-3 cm a step slid at heel-off).
			_low[i] = minf(_low[i], ank.y)
			if _toe_lock[i] != Vector3.INF and (_foot[i] != Vector3.INF or ank.y > float(_low[i]) + 0.015 * sc or hip.distance_to(_lock[i]) > reach):
				var tl: Vector3 = _toe_lock[i]
				var foot := ank - toe
				var up := clampf(foot.y / maxf(foot.length(), 0.001), -1.0, 1.0)
				if _foot[i] == Vector3.INF:
					# (The foot as it is held, toe to ankle, from here raised as the clip's foot is raised: the clip's
					# own foot points a little elsewhere, and the ankle jumped a centimetre or two as the heel came up.)
					_foot[i] = ankle_world[i] - tl
					_up0[i] = up
				if fresh or _ball[i] == Vector3.INF:
					var held: Vector3 = _foot[i]
					var length := held.length()
					var flat := Vector2(held.x, held.z)
					# (Never lower than it was held: a stop's clip pitches its foot back toe-up as the body goes over it, the
					# ankle went below where it was planted, the floor took it back up, and the toe was dragged a centimetre
					# off its place and back - 2.7 cm a stop, summed frame by frame.)
					var lift := clampf(held.y / maxf(length, 0.001) + maxf(0.0, up - float(_up0[i])), -1.0, 1.0)
					_ball[i] = Vector3.INF
					if flat.length() > 0.01:
						var across := flat.normalized() * sqrt(1.0 - lift * lift)
						_ball[i] = _ball_ankle(hip, reach, tl, Vector3(across.x, lift, across.y) * length)
				ball = _ball[i]
				if ball == Vector3.INF:
					# Beyond the leg even on tiptoe: it steps (_let_go), rather than being dragged over the ground.
					_let_go(i)
					down = false
			if down and ball == Vector3.INF and hip.distance_to(_lock[i]) > reach:
				_toe_lock[i] = Vector3.INF
				# The body has gone on further than the leg reaches: the foot is drawn after it just far enough (the
				# least slide there can be), and stays down until the clip lifts it.
				_lock[i] = hip + (_lock[i] - hip).normalized() * reach
				_lock[i].y = maxf(_lock[i].y, floor_ankle)
				# (Drawn on and on - a clip that keeps a foot down while the body is carried on - each draw lifts it a
				# little, and it climbed to the hips: past a step's height it is let go to the clip instead.)
				if (_lock[i] as Vector3).y > floor_ankle + 0.2 * sc:
					_let_go(i)
					down = false
		var on_heel := false
		var heel_b := Basis()
		if down:
			_w[i] = 1.0
			_across[i] = 0.0
			_hold[i] = ball if ball != Vector3.INF else _lock[i]
			if ball == Vector3.INF and _toe_lock[i] == Vector3.INF:
				# On its heel, the toe not yet down: it keeps the way it pointed as it landed (the body turns over a
				# planted foot, the leg twisting) up to TWIST_MAX off the clip's: its toe swung 4-7 cm round about the
				# held ankle in a sharp turn (WsgSim's demo).
				var bc := sk.get_bone_global_pose(leg[2]).basis
				var yaw := atan2(toe.x - ank.x, toe.z - ank.z)
				if is_nan(float(_yaw[i])):
					_yaw[i] = yaw
				var turn := clampf(angle_difference(yaw, float(_yaw[i])), -TWIST_MAX, TWIST_MAX)
				_yaw[i] = yaw + turn
				heel_b = Basis((inv.basis * Vector3.UP).normalized(), turn) * bc
				if bool(_step_landed[i]):
					# Just put down by its own step: turned and pitched as the step drew it, until its toe is down (the
					# clip's foot, still in the air in a hard stop, turned it about the planted ankle: 8-12 cm at the toe).
					heel_b = (inv.basis * (_drawn_basis[i] as Basis)).orthonormalized()
				on_heel = true
		elif stepping != Vector3.INF:
			_w[i] = 1.0
			_across[i] = 0.0
			_hold[i] = stepping
			_lock[i] = Vector3.INF
			_toe_lock[i] = Vector3.INF
			_low[i] = INF
			_foot[i] = Vector3.INF
			_ball[i] = Vector3.INF
		else:
			_lock[i] = Vector3.INF
			_toe_lock[i] = Vector3.INF
			_low[i] = INF
			_foot[i] = Vector3.INF
			_ball[i] = Vector3.INF
			_w[i] = maxf(0.0, _w[i] - delta / release)
		var target := ank
		if (_w[i] > 0.0 or float(_across[i]) > 0.0) and _hold[i] != Vector3.INF:
			# Held, or easing back to the clip from where it was held: up first, then across, so a foot let go does
			# not skate over the ground catching up.
			var hw: float = smoothstep(0.0, 0.6, _w[i])
			# (Let go and not yet told whether the clip lifts it or keeps it down - a tick or two: kept where it was
			# across, not eased over the ground toward the clip's foot - 7 cm in a frame, Hurling's gliding note.)
			if _lifted[i] and float(_step[i]) < 0.0:
				hw = 1.0
				_across[i] = 1.0
			elif float(_across[i]) > 0.0:
				# (Then eased across from there over `release`, not all at once: the ease back had run down while it was
				# held, and the foot jumped the whole way to the clip's in a frame - 72 cm, Hurling's walk start.)
				_across[i] = maxf(0.0, float(_across[i]) - delta / release)
				hw = maxf(hw, smoothstep(0.0, 1.0, float(_across[i])))
			var vw: float = _w[i] * _w[i]
			target = Vector3(lerpf(ank.x, _hold[i].x, hw), lerpf(ank.y, _hold[i].y, vw), lerpf(ank.z, _hold[i].z, hw))
			if not down and stepping == Vector3.INF:
				# Across to a clip's foot that is on the ground some way off, it goes over, not along: "up first" is the
				# ground there (a foot held across while let go, then eased 10-70 cm along the floor - Hurling's walk
				# start).
				var gap := Vector2(_hold[i].x - ank.x, _hold[i].z - ank.z).length()
				target.y += minf(0.08 * sc, gap * 0.6) * sin(PI * (1.0 - hw))
		# Never through the ground.
		target.y = maxf(target.y, floor_ankle)
		if not target.is_equal_approx(ank):
			_leg_ik(sk, leg, inv * target)
		# A foot down with its ball on the ground keeps its ball where it touched: the foot turned about the ankle until its
		# toe is there (the body turning, or the clip's foot creeping, swung it 1-2 cm about a held ankle).
		if down and _toe_lock[i] != Vector3.INF:
			# (Held across from when it is nearly down; its height comes on down with the clip's to the ground, so a
			# foot still flattening from its heel strike is not held toe-up.)
			var tn := xf * sk.get_bone_global_pose(leg[3]).origin
			_toe_lock[i].y = maxf(ground_y + _toe_rest * sc, minf(_toe_lock[i].y, tn.y))
			_aim_foot(sk, leg, xf, _toe_lock[i])
			_toe_hold[i] = _toe_lock[i]
		elif not down and stepping == Vector3.INF and _w[i] > 0.0 and _toe_hold[i] != Vector3.INF:
			# Released to the clip while the clip's toe is still on the floor: the toe keeps its place across as the
			# ankle eases (it snapped 3 cm across, on the ground - the hurler scaled 1.08 walking); once the clip lifts
			# the toe, it goes with the clip (held then, it was kept low and dragged).
			var tn := xf * sk.get_bone_global_pose(leg[3]).origin
			var th: Vector3 = _toe_hold[i]
			var on_floor: float = 1.0 - smoothstep(0.02 * sc, 0.035 * sc, tn.y - (ground_y + _toe_rest * sc))
			var hw2: float = smoothstep(0.0, 0.6, _w[i]) * on_floor
			if hw2 > 0.0:
				_aim_foot(sk, leg, xf, Vector3(lerpf(tn.x, th.x, hw2), tn.y, lerpf(tn.z, th.z, hw2)))
		elif stepping != Vector3.INF and _step_toe[i] != Vector3.INF:
			var an := xf * sk.get_bone_global_pose(leg[2]).origin
			var tn := xf * sk.get_bone_global_pose(leg[3]).origin
			var k := smoothstep(0.0, 1.0, clampf(float(_step[i]), 0.0, 1.0))
			_aim_foot(sk, leg, xf, (an + (_step_toe[i] as Vector3)).lerp(tn, k))
		elif on_heel:
			var parent := sk.get_bone_global_pose(sk.get_bone_parent(leg[2])).basis
			sk.set_bone_pose_rotation(leg[2], (parent.inverse() * heel_b).get_rotation_quaternion())
		if not down:
			_yaw[i] = NAN
			if _w[i] <= 0.0 or stepping != Vector3.INF:
				_toe_hold[i] = Vector3.INF
		elif _toe_lock[i] == Vector3.INF:
			_toe_hold[i] = Vector3.INF
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
		var toe_drawn := xf * sk.get_bone_global_pose(leg[3]).origin
		_drawn_yaw[i] = atan2(toe_drawn.x - ankle_world[i].x, toe_drawn.z - ankle_world[i].z)
		_drawn_basis[i] = xf.basis * sk.get_bone_global_pose(leg[2]).basis
		if not down or _toe_lock[i] != Vector3.INF:
			_step_landed[i] = false
		if down and _toe_lock[i] == Vector3.INF:
			var tn := xf * sk.get_bone_global_pose(leg[3]).origin
			if tn.y < toe_floor + 0.025 * sc:
				_toe_lock[i] = Vector3(tn.x, maxf(tn.y, toe_floor), tn.z)


## Let go mid-contact (beyond the leg's reach): it steps (STEP_TIME), not down again (this frame's redraws included)
## until it has.
func _let_go(i: int) -> void:
	_lifted[i] = true
	_lock[i] = Vector3.INF
	contact[i] = 0.0
	_low_ticks[i] = 0
	_waited[i] = 0
	# (If the clip then keeps it on the ground it steps - see tick's lifted case; its toe goes with the ankle from
	# where it was held, the clip's foot taking over as the step goes on: it snapped 4 cm across at the step's start.)
	_step_toe[i] = _toe_lock[i] - ankle_world[i] if _toe_lock[i] != Vector3.INF else Vector3.INF


## Where the ankle goes with the toe held at TOE_AT: the clip's foot (FOOT: toe to ankle) about the toe, turned up
## towards the hip as far as the leg must to reach it (its REACH from HIP); INF if it cannot without standing the foot
## on its tip (then the foot is drawn after the body instead).
static func _ball_ankle(hip: Vector3, reach: float, toe_at: Vector3, foot: Vector3) -> Vector3:
	var length := foot.length()
	if length < 0.01:
		return Vector3.INF
	var d0 := foot / length
	if hip.distance_to(toe_at + d0 * length) <= reach:
		return toe_at + d0 * length
	var d1 := (hip - toe_at).normalized()
	if hip.distance_to(toe_at + d1 * length) > reach:
		return Vector3.INF
	var lo := 0.0
	var hi := 1.0
	for k in 10:
		var mid := (lo + hi) * 0.5
		if hip.distance_to(toe_at + d0.slerp(d1, mid) * length) <= reach:
			hi = mid
		else:
			lo = mid
	var d := d0.slerp(d1, hi)
	# (Steeper than 80 degrees is on tiptoe: let it go.)
	if d.y > sin(deg_to_rad(80.0)):
		return Vector3.INF
	return toe_at + d * length


## The foot turned about its ankle so its toe points at AT (world).
func _aim_foot(sk: Skeleton3D, leg: Array, xf: Transform3D, at: Vector3) -> void:
	var ft := sk.get_bone_global_pose(leg[2])
	var ank_now := xf * ft.origin
	var arm := xf * sk.get_bone_global_pose(leg[3]).origin - ank_now
	var want := at - ank_now
	if arm.length() < 0.01 or want.length() < 0.01:
		return
	var bi := xf.basis.inverse()
	var turn := Quaternion((bi * arm).normalized(), (bi * want).normalized())
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(leg[2])).basis
	sk.set_bone_pose_rotation(leg[2], (parent.inverse() * (Basis(turn) * ft.basis)).get_rotation_quaternion())


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
	# Forward of the thigh, the way a knee bends: a knee that was a hair past straight (a standing clip's locked
	# knees) was bent on the wrong side, backwards, as the foot was held nearer (the officials stood so, 29 degrees).
	var fwd := th.basis * Vector3(0, 0, 1)
	fwd -= dir * fwd.dot(dir)
	if pole.length() < 0.0001 or pole.dot(fwd) <= 0.0:
		pole = fwd
	var new_knee := hip + dir * x + pole.normalized() * h
	var ankle := hip + dir * d
	var parent := sk.get_bone_global_pose(sk.get_bone_parent(leg[0])).basis
	var th_b := Basis(Quaternion((knee - hip).normalized(), (new_knee - hip).normalized())) * th.basis
	# The thigh rolled about its length so the knee's hinge (the thigh's own x) is square to the leg's plane (hip,
	# knee, ankle): the shortest turn alone left it askew, and the shin then bent off the hinge (a knee sideways).
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
