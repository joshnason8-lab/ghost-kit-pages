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
## On a skeleton of the game's own (its own body at Low - what the owner sees): the rig's bone names to its own, e.g.
## {"Hips": "hips", "LeftUpLeg": "thigh_l", "LeftLeg": "shin_l", "LeftFoot": "foot_l", "LeftToeBase": "toe_l", ...}.
## The planter reads contact from the pose as drawn (heights and speed), so any body whose clips or code pose its legs
## can have its feet planted: add it under the skeleton, after what poses it; each game step call tick(dt) and set
## ground_y and body_speed (WsgLocomotor does this for the foundation's own bodies). ADOPTING 5.21.
@export var bone_map := {}
## Put before every bone's name (after bone_map): a rig whose bones are all "mixamorig_LeftUpLeg" and so on.
@export var bone_prefix := ""
## Metres per skeleton unit (0: found from the leg's rest length - 1 on a rig in metres, 0.01 on one in centimetres
## under a 0.01 node, as Sepak Takraw's RealBody: its skeleton's world scale 0.0101 took every metre tolerance here
## down 100 times, 3 cm to 0.3 mm, and its feet were hardly planted).
@export var unit_scale := 0.0
## The game's own rule for a foot being down, if it has one: (foot: int, ankle: Vector3, toe: Vector3, was_down: bool)
## -> bool, world positions as the pose has them before planting; the planter's own gate (heights and speed) otherwise.
var contact_fn := Callable()
var _hips := -1

## Each foot is down (found on the pose this frame; read it, do not set it).
var contact := [0.0, 0.0]
## The body's speed over the ground (m/s), from the locomotor: a foot moving much slower than it is planted.
var body_speed := 0.0
## Added to the hips' height after the clips (the body's hips against the clips' for its leg length).
var hips_offset := 0.0
## Down this frame and not last: a step (left 0, right 1), for footstep sounds.
signal landed(foot: int)
var _prev := [Vector3.INF, Vector3.INF]
## A foot coming down with its toe slower than LAND_TOE (m/s) over the ground across the last LAND_SPAN (s) is landing,
## whatever its ankle does: the feet rule (WsgNoteChecks.SWING, frame to frame at 30 fps) reads it down from then, and
## planted later it slid the 3-4 cm it moved into its hold (Floorball's referee stopping: its toe at 1.0 m/s over the
## frame, 1.7 in its last 60 Hz tick).
const LAND_TOE := 1.2
## How low a foot coming down is touching if its ankle is already as slow as a stance foot's, or the body is nearly still
## (TOUCH_STILL) (landing, not a swing - on a body moving, its toe slow or the foot flat alone planted a swing that high,
## stopped dead in the air: Kabaddi's Low walker's jump 2.8 -> 12.6 cm; a body standing, its idle's foot hovering 3.8 cm
## up, toe slow, was never planted and drifted 9.2 cm under the rule - Kho Kho's referee, extreme#28; else 3 cm as before)
## (m over its floor; never less on a body scaled down - Kho Kho's defenders at 0.95: 3.2 cm): over the feet rule's
## 3 cm touch (WsgNoteChecks.TOUCH, unscaled, its ankle's floor where the planted ankle stands - higher than a heel-up
## stance's rest), so a foot the rule reads down is one the planter has planted - at 3.0 cm the rule read a landing foot
## down a draw before the planter did, and counted what it moved then (Kabaddi's far players: 4.4-7.6 cm; PUN_9, scaled
## 0.95, its toe 3.50 cm up against the planter's 3.32: 6.4 cm).
const TOUCH_H := 0.04
## ...nearly still: the body slower than this (m/s).
const TOUCH_STILL := 0.5
const LAND_SPAN := 1.0 / 30.0
var _toe_back := [[], []]                    # each toe's last few ticks: [tick time, toe (world)]
var _drawn_move := [0.0, 0.0]                # how far across each foot was drawn to move last tick
var _tick := 0
var _done := -1
var _tick_dt := 1.0 / 30.0
var _tick_acc := 0.0                         # the game time of every tick since the planter last ran
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
## How far a step's toe stays over the floor until it lands (m, the body's scale 1): over the feet rule's 3 cm touch.
const STEP_CLEAR := 0.035
## How far off where a let-go foot is held the clip may stand it down before it steps there instead (m, scale 1): the
## feet rule reads 2 cm a step as a slide.
const STEP_OFF := 0.02
## ...and only on a body slower than this (m/s): running, every stride's toe-off is let go at the leg's reach and the
## clip's next stance foot stands a stride on - planted there, as before, not stepped (a referee at 5.4 m/s stepped at
## 52 cm a frame and stopped dead: a 26.6 cm jump, Floorball's extreme#3).
const STEP_OFF_SPEED := 2.5
## ...and only a step's way off (m, scale 1), not a stride's: a referee, his feet 28-39 cm off where they were held,
## stepped there just before he sprinted off, and his next strides went wrong (a 26.6 cm jump, Floorball's extreme#3);
## Kabaddi's official, moving at 1.2 m/s, was 23 cm off.
const STEP_OFF_MAX := 0.3
## ...and only on a body moving (over this, m/s): nearly still, the clip's own shuffle puts its feet down where it will.
const STEP_OFF_MIN_SPEED := 0.5
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
## The most a foot easing back to the clip's moves across in a frame (m, the body's scale 1): CHASE_MAX, or CHASE_OVER
## more than the clip's own foot moves that frame if that is more - it catches up, never jumping the gap, and a
## sprint's own swing (up to 30-37 cm a frame low over the ground - tools/feet_calibrate, every game's walker) is not
## slowed. (35 cm flat let a stop from 8 m/s still jump 24 cm; the clip's move plus 15, 29.)
const CHASE_MAX := 0.25
const CHASE_OVER := 0.10
## A released foot's catch-up is held to CHASE_OVER of change a frame only once it moves more than this a frame (m;
## never less on a body scaled down - the feet rule's jump bound is unscaled: a 23.8 cm catch-up on a body at 0.94, held
## back, snapped the next frame, a 26.6 cm jump - Kabaddi's BAN_5, random#13).
const RELEASE_RATE_FROM := 0.25
## ...and only while the body speeds up faster than this over ACCEL_SPAN (m/s^2): a walk's speed wavers a little every
## frame (Kho Kho's Low walk 1.5 -> 3.2 cm held back on every waver, its turned jog 0.2 -> 1.7).
const RELEASE_ACCEL := 4.0
var _clip_move := [0.0, 0.0]                 # how far the clip moved each ankle this frame
var _clip_mv := [Vector2.ZERO, Vector2.ZERO] # that move across
var _clip_turn := [0.0, 0.0]                 # how much that move changed from the frame before
var _rel_prev := [Vector2.ZERO, Vector2.ZERO] # each foot's drawn move across last tick, while the planter has it
var _chase_from := [Vector3.ZERO, Vector3.ZERO] # where each foot was drawn the frame before
var _step_at := [Vector3.ZERO, Vector3.ZERO]   # where a foot taking its own step is across, this frame
var _step_vel := [Vector2.ZERO, Vector2.ZERO] # that step's move across last tick
var _chasing := [false, false]               # catching up with the clip's foot at CHASE_MAX
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
var _unit := 1.0                             # metres per skeleton unit (unit_scale, or found)
## A leg (hip to ankle) about this long in metres, to tell a rig's unit by (its power of ten).
const LEG_REF := 0.8
var _for := -1
## What each foot did this frame (world ankle), for measuring slide.
var ankle_world := [Vector3.ZERO, Vector3.ZERO]


func _cache(sk: Skeleton3D) -> void:
	if _for == sk.get_instance_id():
		return
	_for = sk.get_instance_id()
	_ix.clear()
	for leg in LEGS:
		_ix.append(leg.map(func(n): return sk.find_bone(bone_prefix + String(bone_map.get(n, n)))))
	_hips = sk.find_bone(bone_prefix + String(bone_map.get("Hips", "Hips")))
	for leg in _ix:
		for b in leg:
			if int(b) < 0:
				push_error("WsgFootPlanter: a leg bone is missing on %s (bone_map: %s, bone_prefix: '%s')" % [sk.name, bone_map, bone_prefix])
	_ankle_rest = sk.get_bone_global_rest(_ix[0][2]).origin.y
	_toe_rest = sk.get_bone_global_rest(_ix[0][3]).origin.y
	# (Which way the thigh's +Z faces on this rig at rest, against the foot's way (heel to toe): forward on ours, backward
	# on a Mixamo RealBody - Sepak Takraw's, whose every bent knee was flipped behind, the owner's "broken backwards knees".)
	var rest_fwd: Vector3 = sk.get_bone_global_rest(_ix[0][3]).origin - sk.get_bone_global_rest(_ix[0][2]).origin
	var rest_z: Vector3 = sk.get_bone_global_rest(_ix[0][0]).basis * Vector3(0, 0, 1)
	_thigh_z_fwd = 1.0 if Vector2(rest_z.x, rest_z.z).dot(Vector2(rest_fwd.x, rest_fwd.z)) >= 0.0 else -1.0
	_unit = unit_scale
	if _unit <= 0.0:
		var leg_len: float = sk.get_bone_global_rest(_ix[0][0]).origin.distance_to(sk.get_bone_global_rest(_ix[0][1]).origin) \
			+ sk.get_bone_global_rest(_ix[0][1]).origin.distance_to(sk.get_bone_global_rest(_ix[0][2]).origin)
		_unit = pow(10.0, roundf(log(LEG_REF / maxf(leg_len, 0.0001)) / log(10.0))) if leg_len > 0.0 else 1.0


## Lets go of both feet at once (a teleport, a new play).
## How many times reset() has been called: WsgSim reads a reset as a cut (the body put somewhere new - a restart, an
## official snapped to his spot), not as the feet sliding there (Hurling: umpires snapped 20-35 cm read as skids).
var resets := 0


## Whether the planter has this foot (0 left, 1 right): planted, held, or easing back from a hold - not the clip's own
## swing. (WsgSim's skid counts only these: a clip's low swing before it lands skims within the measure's 2 cm, and a
## body posed every 2nd frame showed it as a 13 cm "skid" - Pok Ta Pok's hard turns.)
func holding(i: int) -> bool:
	return float(contact[i]) > 0.5 or float(_w[i]) > 0.0 or float(_across[i]) > 0.0


func reset() -> void:
	resets += 1
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
	_chasing = [false, false]
	_chase_from = [Vector3.ZERO, Vector3.ZERO]
	_w = [0.0, 0.0]
	_prev = [Vector3.INF, Vector3.INF]
	_toe_back = [[], []]
	_drawn_move = [0.0, 0.0]
	_clip_mv = [Vector2.ZERO, Vector2.ZERO]
	_speed_back = []
	_accel = 0.0
	_clip_turn = [0.0, 0.0]
	_rel_prev = [Vector2.ZERO, Vector2.ZERO]
	# (What it last drew goes too: a planter not run for a while - a body the game posed whole, the planter off - kept
	# its feet down and where they were drawn then, and back on, the foot was planted there, far behind, and let go: it
	# slid 7 cm with the game's pose fading out under it - Sepak Takraw's players out of a set piece.)
	contact = [0.0, 0.0]
	_lifted = [false, false]
	_aired = [false, false]
	_hip_vel = [Vector3.ZERO, Vector3.ZERO]
	ankle_world = [Vector3.ZERO, Vector3.ZERO]


## A planter not run for more than this many frames (inactive, or its body not drawn) starts afresh when it runs again:
## what it last drew is no longer where the body is (WsgSim reads the reset as a cut, as it does a body not posed for
## more than its GAP_CUT frames).
const STALE_FRAMES := 3
var _ran_at := -1
var _thigh_z_fwd := 1.0                     # the thigh's +Z forward (1) or backward (-1) on this rig (_cache)


## One step of the game's time (the locomotor calls it from drive()): the feet's contacts and holds are worked out
## once a step, on the step's own time, however often the skeleton redraws in between.
func tick(delta: float) -> void:
	_tick += 1
	_tick_acc += delta


var _speed_back := []                        # the last ticks' [time, body_speed]
var _accel := 0.0                            # how fast the body sped up over the last ACCEL_SPAN (m/s^2)
const ACCEL_SPAN := 0.2


func _process_modification_with_delta(_frame_delta: float) -> void:
	var fresh := _tick != _done
	_done = _tick
	# (A run's time is every tick's since the last run, not the last tick's: a far body drawn every 3rd frame moved
	# 3 frames' worth between runs, read as 3 times as fast - a landing foot too fast to plant, so planted a draw
	# late, 6.4 cm on (Kabaddi's far players). A game ticking twice a draw read its feet twice as fast too.)
	if fresh:
		_tick_dt = _tick_acc if _tick_acc > 0.0 else _tick_dt
		_tick_acc = 0.0
		# (The body's speeding up over the last ACCEL_SPAN: a frame's own change wavers.)
		_speed_back.append([_tick_dt, body_speed])
		if _speed_back.size() > 24:
			_speed_back.pop_front()
		var span := 0.0
		for k in range(_speed_back.size() - 1, 0, -1):
			span += float(_speed_back[k][0])
			if span >= ACCEL_SPAN - 0.0001:
				_accel = (body_speed - float(_speed_back[k - 1][1])) / span
				break
	var now := Engine.get_process_frames()
	if _ran_at >= 0 and now - _ran_at > STALE_FRAMES and not keep_pose:
		reset()
		# (Back after a while: not the whole while as one tick.)
		_tick_dt = minf(_tick_dt, 1.0 / 30.0)
	_ran_at = now
	var delta := _tick_dt if fresh else 0.0
	var sk := get_skeleton()
	if sk == null:
		return
	_cache(sk)
	if hips_offset != 0.0:
		if _hips >= 0:
			sk.set_bone_pose_position(_hips, sk.get_bone_pose_position(_hips) + Vector3(0, hips_offset, 0))
	var xf := sk.global_transform
	if keep_pose:
		reset()
		contact = [0.0, 0.0]
		_lifted = [false, false]
		for i in 2:
			ankle_world[i] = xf * sk.get_bone_global_pose(_ix[i][2]).origin
		return
	var inv := xf.affine_inverse()
	# (sc: the skeleton's world scale - for its own rest lengths and heights, in its units; sz: the body's size - for
	# tolerances in metres. The same on a rig in metres; on one in centimetres sc is 100 times smaller.)
	var sc := xf.basis.get_scale().y
	var sz := sc / _unit
	var floor_ankle := ground_y + _ankle_rest * sc
	for i in 2:
		var leg: Array = _ix[i]
		if fresh:
			# (Its move over the last tick, redraws and all: where it was drawn as this tick began against the last.)
			_drawn_move[i] = Vector2(ankle_world[i].x - _chase_from[i].x, ankle_world[i].z - _chase_from[i].z).length() \
				if _chase_from[i] != Vector3.ZERO and ankle_world[i] != Vector3.ZERO else 0.0
			_chase_from[i] = ankle_world[i]
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
			_clip_move[i] = vel * delta
			var cm := Vector2(ank.x - _prev[i].x, ank.z - _prev[i].z) if _prev[i] != Vector3.INF else Vector2.ZERO
			_clip_turn[i] = (cm - (_clip_mv[i] as Vector2)).length()
			_clip_mv[i] = cm
			_prev[i] = ank
			var back: Array = _toe_back[i]
			back.append([delta, toe])
			if back.size() > 6:
				back.pop_front()
			var tvel := INF
			var span := 0.0
			for k in range(back.size() - 1, 0, -1):
				span += float(back[k][0])
				if span >= LAND_SPAN - 0.0001:
					var t0: Vector3 = back[k - 1][1]
					tvel = Vector2(toe.x - t0.x, toe.z - t0.z).length() / span
					break
			if _hip_prev[i] != Vector3.INF and delta > 0.0:
				_hip_vel[i] = Vector3(hip.x - _hip_prev[i].x, 0.0, hip.z - _hip_prev[i].z) / delta
			_hip_prev[i] = hip
			# A landing foot is still moving as it touches (a heel strike decelerates over a frame or two): it sticks
			# where it lands. A swinging foot skimming the ground moves at about twice the body's speed: it does not.
			# Once down it stays down until the clip lifts it.
			# A foot FLAT on the ground (heel and toe both down) is planted however fast the clip moves it: a swing never
			# comes through flat, and one let slide there glided on the floor (a hard stop from a run: the clip brought
			# the foot in flat 23 cm a frame and snapped it back 7 cm, read as swinging - the lead, 2026-11-03).
			var flat := maxf(ank.y - floor_ankle, toe.y - (ground_y + _toe_rest * sc)) < 0.02 * sz
			var landing := vel < 0.6 + body_speed * 0.8 or flat or tvel < LAND_TOE
			is_down = h < 0.05 * sz if was else ((h < 0.03 * maxf(sz, 1.0) and landing) \
				or (h < TOUCH_H * maxf(sz, 1.0) and (vel < 0.6 + body_speed * 0.8 or (body_speed < TOUCH_STILL and landing))))
			if contact_fn.is_valid():
				is_down = bool(contact_fn.call(i, ank, toe, was))
			# A foot let go at the end of its reach is lifting: not down again until it has left the ground.
			if _lifted[i] and float(_step[i]) < 0.0:
				_waited[i] = int(_waited[i]) + 1
				# (Still on the ground, the clip's foot standing still - a step off where it is held, and that out of the
				# leg's reach: it steps there (not under a game's own contact rule, which says when a foot is down: Kho Kho's
				# Low body, its standing feet stepped - 0.3 -> 2.1 cm),
				# not planted there at once - it crossed 11 cm along the floor in a frame, Kabaddi's referee handed back
				# into a sidestep, his foot let go out of reach and the clip's standing 11 cm on.)
				var off := Vector2(ank.x - (ankle_world[i] as Vector3).x, ank.z - (ankle_world[i] as Vector3).z).length() \
					if ankle_world[i] != Vector3.ZERO else 0.0
				if not contact_fn.is_valid() and body_speed > STEP_OFF_MIN_SPEED and body_speed < STEP_OFF_SPEED and h <= 0.05 * sz and vel < 0.2 and off > STEP_OFF * sz and off < STEP_OFF_MAX * sz \
						and hip.distance_to(Vector3((ankle_world[i] as Vector3).x, floor_ankle, (ankle_world[i] as Vector3).z)) > reach:
					is_down = false
					_step[i] = 0.0
					_step_vel[i] = Vector2.ZERO
					_step_from[i] = ankle_world[i]
					_step_at[i] = ankle_world[i]
				elif h > 0.05 * sz or vel < 0.2:
					_lifted[i] = false
				else:
					is_down = false
					# Let go, and the clip keeps it on the ground (its stride too short for the body: a sharp turn, a
					# start or stop harder than its clips): it steps. A foot the clip is lifting - every running
					# stride's toe-off is let go at the leg's reach - just goes with the clip (stepping those too
					# doubled the landings: Kho Kho's runners at 7.6 steps a second). Kept where it was across while
					# that is told (the release below).
					_low_ticks[i] = int(_low_ticks[i]) + (1 if h < 0.03 * sz else 0)
					if int(_low_ticks[i]) >= 2:
						_step[i] = 0.0
						_step_vel[i] = Vector2.ZERO
						_step_from[i] = ankle_world[i]
						_step_at[i] = ankle_world[i]
					elif int(_waited[i]) >= 3:
						# (Skimming, neither lifted nor kept down: to the clip.)
						_lifted[i] = false
			# A footstep is a foot that went up and came down: one let go at its reach and planted again without
			# leaving the ground (the clip's stance foot, still in the world) is the same footfall, not another - it
			# fired landed twice a stride (Kho Kho's sprinters: 5.3 footsteps a second, 4.8 the most).
			if h > 0.05 * sz:
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
			var side := clampf((ank - hip).dot(right), -0.2 * sz, 0.2 * sz)
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
				# Across, an even share of what is left to where it is going each frame the step has left (the aim moves
				# with the body: on a smoothstep from where it began to the aim now, a stop's step crept 3-6 cm a frame,
				# then crossed 35 in one - Floorball's referee); up and down as before.
				if fresh:
					var left := roundf((1.0 - st) * STEP_TIME / maxf(delta, 0.0001)) + 1.0
					var at: Vector3 = _step_at[i]
					var mv := Vector2(to.x - at.x, to.z - at.z) / left
					# (Its move across changing by no more than CHASE_OVER a frame (30 fps), in size or way: an aim running on
					# ahead of a body speeding up, the share left for the step's last tick or two crossed 28-54 cm in a frame,
					# then stood - a jump (Floorball's referees, Kho Kho's chasers starting); its size alone held, the aim
					# turning with the body swung it 33 cm a frame round (Kho Kho's defender). Where it cannot keep up, it is
					# put down where it has got to.)
					var grow := CHASE_OVER * sz * pow(delta * 30.0, 2.0)
					var dv: Vector2 = mv - (_step_vel[i] as Vector2)
					if dv.length() > grow:
						mv = (_step_vel[i] as Vector2) + dv.normalized() * grow
					_step_vel[i] = mv
					_step_at[i] = Vector3(at.x + mv.x, 0.0, at.z + mv.y)
				var at2: Vector3 = _step_at[i]
				stepping = Vector3(at2.x, lerpf(from.y, to.y, smoothstep(0.0, 1.0, st)), at2.z) + Vector3(0.0, 0.08 * sz * sin(PI * st), 0.0)
				is_down = false
				contact[i] = 0.0
		var down: bool = enabled and is_down
		var ball := Vector3.INF
		if down:
			if _lock[i] == Vector3.INF:
				# Planted means on the ground: the foot comes down until its lowest point (heel or ball) touches.
				_lock[i] = Vector3(ank.x, maxf(ank.y - maxf(h, 0.0), floor_ankle - 0.5 * _toe_rest * sc), ank.z)
				if (_w[i] > 0.0 and _hold[i] != Vector3.INF or bool(_chasing[i])) and ankle_world[i] != Vector3.ZERO:
					# Down again while still easing back from where it was last held (a stop from a sprint: the clip lifts
					# the foot for a frame and puts it down a stride on): planted where it is drawn, not where the clip
					# has it - it jumped there, 80-95 cm in a frame. If that is beyond the leg, it steps (as any foot).
					_lock[i].x = (ankle_world[i] as Vector3).x
					_lock[i].z = (ankle_world[i] as Vector3).z
				elif _chase_from[i] != Vector3.ZERO:
					# Coming down, it moves across no further than it was drawn to move the tick before: the clips changing
					# under a landing foot (a stop's into a start's) carried it 28-40 cm across in the frame it came down,
					# from 18, then it stood dead still - a jump (Floorball's referee, 27 cm). (A landing slowing down, as
					# landings do, is planted where the clip has it.)
					var d := Vector2(ank.x - _chase_from[i].x, ank.z - _chase_from[i].z)
					if d.length() > float(_drawn_move[i]) + 0.005 * sz:
						d = d.normalized() * float(_drawn_move[i])
						_lock[i].x = (_chase_from[i] as Vector3).x + d.x
						_lock[i].z = (_chase_from[i] as Vector3).z + d.y
			if hip.distance_to(_lock[i]) > reach * 1.5 and (_hip_vel[i] as Vector3).length() * _tick_dt > 0.5 * sz:
				# Far beyond the leg (the body put somewhere else: a restart, the next free): planted afresh under the foot
				# (drawn after it, the leg pointed at the old place, level with the hips).
				_lock[i] = Vector3(ank.x, maxf(ank.y - maxf(h, 0.0), floor_ankle - 0.5 * _toe_rest * sc), ank.z)
				_toe_lock[i] = Vector3.INF
			elif hip.distance_to(_lock[i]) > reach * 1.5:
				# Left that far behind by the body running on (not put there): it steps, as at its reach's end - planted
				# afresh under the clip's foot, it jumped 66-85 cm in a frame (Kho Kho's chasers stopping from 7 m/s).
				_let_go(i)
				down = false
			# The heel coming up (the clip's ankle rising off the ground) or the body gone on past the leg's reach, with
			# the ball of the foot down: the foot rolls over its ball - the toe stays where it is and the ankle goes up
			# about it (the clip's own foot pitch, steeper if the leg must reach further), instead of the whole foot
			# sliding after the body (the last 1-3 cm a step slid at heel-off).
			_low[i] = minf(_low[i], ank.y)
			if _toe_lock[i] != Vector3.INF and (_foot[i] != Vector3.INF or ank.y > float(_low[i]) + 0.015 * sz or hip.distance_to(_lock[i]) > reach):
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
				if (_lock[i] as Vector3).y > floor_ankle + 0.2 * sz:
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
			# Held, or easing back to the clip from where it was held: up first (vw, quicker), across over the whole
			# release (hw), lifting over the floor on the way, so a foot let go does not skate over the ground catching up.
			# (Across only in the release's last frames - smoothstep(0, 0.6) - it stood still, then crossed 30-90 cm in
			# a frame stopping from a sprint: Netball's walker 23 cm read as a jump, now 0.1.)
			var hw: float = smoothstep(0.0, 1.0, _w[i])
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
			if not down and stepping == Vector3.INF and not (_lifted[i] and float(_step[i]) < 0.0) and float(_across[i]) <= 0.0 \
					and _chase_from[i] != Vector3.ZERO:
				# Released as the clip lifts it: across, an even share of what is left between where it was drawn and
				# the clip's foot each frame the release has left - a steady catch-up, never still then a stride at once
				# (stopping from a sprint it stood, then crossed 30-90 cm in a frame: read as a jump).
				var from: Vector3 = _chase_from[i]
				var left := maxf(1.0, ceilf(_w[i] * release / maxf(_tick_dt, 0.0001) - 0.001))
				target.x = from.x + (ank.x - from.x) / left
				target.z = from.z + (ank.z - from.z) / left
			if not down and stepping == Vector3.INF:
				# Across to a clip's foot that is on the ground some way off, it goes over, not along: "up first" is the
				# ground there (a foot held across while let go, then eased 10-70 cm along the floor - Hurling's walk
				# start).
				var gap := Vector2(_hold[i].x - ank.x, _hold[i].z - ank.z).length()
				# (Over the ease across too, not only the hold's: let go, lifted by the clip a frame or two and put down
				# again a stride off (a turn's first step), it was eased across along the floor after the hold had run out
				# - 7.8 cm a frame, flat: Kho Kho's defender turning to run; Sepak Takraw's own bodies at Low, 25 m of flat
				# glide a match.)
				var ease := maxf(float(_w[i]), float(_across[i])) if float(_across[i]) < 1.0 else float(_w[i])
				target.y += minf(0.08 * sz, gap * 0.6) * sin(PI * clampf(1.0 - ease, 0.0, 1.0))
		# Easing back to the clip's foot (or still catching up with it): across no faster than CHASE_MAX/CHASE_OVER
		# allow, until it has caught up (a stop from a sprint: the ease covered 50-90 cm of the gap
		# in one frame, in the air).
		if down or stepping != Vector3.INF:
			_chasing[i] = false
			if fresh:
				_rel_prev[i] = Vector2.ZERO if down else (_step_vel[i] as Vector2)
		elif (_w[i] > 0.0 or float(_across[i]) > 0.0 or bool(_chasing[i])) and _chase_from[i] != Vector3.ZERO:
			var from: Vector3 = _chase_from[i]
			var gap := Vector2(target.x - from.x, target.z - from.z)
			var cap := maxf(CHASE_MAX * sz, CHASE_OVER * sz + float(_clip_move[i]))
			var capped := false
			if gap.length() > cap:
				gap = gap.normalized() * cap
				capped = true
			# (Its move across changing from the frame before by no more than CHASE_OVER (30 fps) more than the clip's own
			# foot's does: easing back to a clip foot running on ahead of a body speeding up, the ease's last frame took the
			# whole lead at once - 40 cm in a frame, then planted dead - a 33 cm jump (Kho Kho's defenders starting hard).)
			var grow := CHASE_OVER * sz * pow(maxf(delta, _tick_dt) * 30.0, 2.0) + float(_clip_turn[i])
			var dv: Vector2 = gap - (_rel_prev[i] as Vector2)
			# (Not under a game's own contact rule - Sepak Takraw's Low officials' dodges, held back, skidded - and only while
			# the body speeds up - a stop's release held back slid its foot 7.5 cm, Kho Kho's Low stop - and
			# only a move big enough to read as a jump: a walk's release, held back, dragged its foot along the floor -
			# Kabaddi's Low walk 0.9 -> 2.1 cm from 15 cm a frame; from 25, 0.5.)
			if gap.length() > RELEASE_RATE_FROM * maxf(sz, 1.0) and dv.length() > grow and _accel > RELEASE_ACCEL and not contact_fn.is_valid():
				gap = (_rel_prev[i] as Vector2) + dv.normalized() * grow
				capped = true
			if capped:
				target.x = from.x + gap.x
				target.z = from.z + gap.y
			if fresh:
				_chasing[i] = capped
				_rel_prev[i] = gap
		elif fresh:
			# (To the clip's: moving as it moves.)
			_rel_prev[i] = _clip_mv[i]
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
			# (Aimed where the foot reaches over its place: the toe turned toward a point nearer than the foot is long
			# sits past it, across - a foot flattening as its heel rose drew its toe 0.5-0.8 cm a frame, 2.3 cm a step,
			# Floorball's referee walking back. Its height is what gives, down to the floor, never up: lifted over its
			# hold, a planted toe stood 0.5 cm off the ground and a standing heel 3 cm up - Sepak Takraw's walker.)
			var aim: Vector3 = _toe_lock[i]
			var an := xf * sk.get_bone_global_pose(leg[2]).origin
			var foot_len := an.distance_to(tn)
			var across := Vector2(aim.x - an.x, aim.z - an.z).length()
			if across < foot_len:
				var y := an.y - sqrt(foot_len * foot_len - across * across)
				if y >= ground_y + _toe_rest * sc - 0.002 and y <= aim.y:
					aim.y = y
			_aim_foot(sk, leg, xf, aim)
			_toe_hold[i] = _toe_lock[i]
		elif not down and stepping == Vector3.INF and _w[i] > 0.0 and _toe_hold[i] != Vector3.INF:
			# Released to the clip while the clip's toe is still on the floor: the toe keeps its place across as the
			# ankle eases (it snapped 3 cm across, on the ground - the hurler scaled 1.08 walking); once the clip lifts
			# the toe, it goes with the clip (held then, it was kept low and dragged).
			var tn := xf * sk.get_bone_global_pose(leg[3]).origin
			var th: Vector3 = _toe_hold[i]
			var on_floor: float = 1.0 - smoothstep(0.02 * sz, 0.035 * sz, tn.y - (ground_y + _toe_rest * sc))
			var hw2: float = smoothstep(0.0, 0.6, _w[i]) * on_floor
			if hw2 > 0.0:
				_aim_foot(sk, leg, xf, Vector3(lerpf(tn.x, th.x, hw2), tn.y, lerpf(tn.z, th.z, hw2)))
		elif stepping != Vector3.INF and _step_toe[i] != Vector3.INF:
			var an := xf * sk.get_bone_global_pose(leg[2]).origin
			var tn := xf * sk.get_bone_global_pose(leg[3]).origin
			var k := smoothstep(0.0, 1.0, clampf(float(_step[i]), 0.0, 1.0))
			_aim_foot(sk, leg, xf, (an + (_step_toe[i] as Vector3)).lerp(tn, k))
		if stepping != Vector3.INF:
			# A step's toe clears the floor by STEP_CLEAR until it lands, the ankle raised as far as it takes: the clip's
			# foot pitched toe-down under an ankle 20 cm up skimmed its toe over the floor across the step's last frames,
			# 3-4 cm a frame, read as a planted foot sliding (Sepak Takraw's players). It comes straight down as it lands.
			var tw := xf * sk.get_bone_global_pose(leg[3]).origin
			var need := ground_y + _toe_rest * sc + STEP_CLEAR * sz * smoothstep(0.0, 0.25, float(_step[i])) - tw.y
			if need > 0.001:
				var toe_rel := tw - xf * sk.get_bone_global_pose(leg[2]).origin
				target.y += need
				_leg_ik(sk, leg, inv * target)
				_aim_foot(sk, leg, xf, target + toe_rel)
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
			if tn.y < toe_floor + 0.025 * sz:
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
	var fwd := th.basis * Vector3(0, 0, _thigh_z_fwd)
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
