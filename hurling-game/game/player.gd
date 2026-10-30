class_name Player
extends Node3D
## One hurler (or an official) on the pitch: his body (HeroBody; an official's PersonBody), how he moves and the move he is making. The match
## and the AI decide what he does by setting want_vel, face_to and starting actions; this is the only code that moves
## him (integrate), so nothing else writes his position and nothing jumps in a frame: his speed changes by at most
## his acceleration, he turns at a person's rate, and his strides lengthen and quicken with his speed.

const ACCEL := 6.5          # m/s^2 to speed up
const DECEL := 9.0          # m/s^2 to slow down
const TURN := 7.0           # rad/s he can turn his body at a jog (slower at a sprint)
const BACKPEDAL := 3.2      # m/s: the fastest a man moves backward facing the way he came; faster, he turns
## The man under your thumb answers it quicker than the computer's men move: a game's player has to feel the stick
## (round three: "the players barely react to the joystick"; 6.5 m/s^2 took well over a second to top speed).
const USER_ACCEL_K := 2.0
## Bodies are drawn a little larger than life, as sports games draw them, so a player reads on a phone across a
## 140 m pitch; where they stand, reach and collide is unchanged.
const DRAW_SCALE := 1.15
const USER_TURN_K := 1.8

## Actions: how long each lasts and, for those that meet the ball, when (seconds from the start).
const ACTIONS := {
	"strike": [0.62, 0.36],      # from the hand: the toss, the backswing over the right shoulder, the swing through
	"strike_stick": [0.55, 0.3], # from the hurley: flicked up off the bas and struck
	"ground": [0.5, 0.26],       # a ground stroke: pulled first time along the grass
	"pull": [0.45, 0.22],        # a first-time pull in the air, overhead
	"hand_pass": [0.36, 0.16],
	"catch": [0.45, 0.22],       # the hand up for it, a jump if it is high
	"lift": [0.42, 0.24],        # a roll lift or jab lift: the bas under the ball, up onto the hurley
	"solo": [0.3, 0.12],         # from the hand onto the bas
	"to_hand": [0.25, 0.12],     # from the bas back into the hand
	"tackle": [0.45, 0.2],       # a shoulder, side to side
	"hook": [0.4, 0.2],          # the hurley in over the striker's swing from behind
	"block": [0.5, 0.18],        # the hurley up in front of the striker
	"flick": [0.35, 0.16],       # the ball knocked off a soloing player's hurley
	"fall": [1.6, 0.0],          # knocked down, and up again
	"save": [0.7, 0.2],          # the goalkeeper's dive
	"celebrate": [2.2, 0.0],
	"puck_out": [0.7, 0.42],     # the goalkeeper's toss and long strike
	"cut": [0.7, 0.44],          # a sideline cut: struck off the ground, low and side-on
	"dejected": [2.0, 0.0],
	"free_set": [600.0, 0.0],    # standing over it side-on, the hurley in both hands, while the free is aimed (held)
	"free_strike": [2.45, 1.8],  # from there: down to it, the lift onto the hurley, the toss, the strike (assets/player/free.json)
	# Officials' signals, held while the match wants them.
	"sig_free": [1.8, 0.0],      # the referee's arm out towards the goal the free attacks
	"sig_advantage": [5.0, 0.0], # one arm straight up for the five seconds
	"sig_card": [2.2, 0.0],      # the card held up
	"sig_throw": [1.2, 0.5],     # the throw-in
	"sig_point": [2.4, 0.0],     # the umpire waves the white flag
	"sig_goal": [2.6, 0.0],      # the green flag
	"sig_wide": [2.0, 0.0],      # arms crossed over the head
	"sig_65": [2.2, 0.0],        # an arm straight up, then pointing in at the 65
	"sig_sideline": [1.8, 0.0],  # the linesman's flag out, the way the cut goes
	"sig_penalty": [2.0, 0.0],   # both arms pointing to the 20 m line
	"sig_sinbin": [2.4, 0.0],    # ten fingers held up
	"sig_whistle": [0.8, 0.0],
}

var data := {}             # from DB.squad (an official: {num 0, line -1})
var team := 0              # 0 or 1; -1 an official
var num := 0               # the number on his back
var pos_num := 0           # his place in the side's shape, 1-15 (a substitute takes the place of the man he replaces)
var role := ""             # "" a player; "referee", "linesman", "umpire"
var body: ToonBody
var max_speed := 7.5       # m/s, from his speed rating (8.4 m/s is a hurler's top speed)

var vel := Vector3.ZERO
var want_vel := Vector3.ZERO
var face_to := Vector3.ZERO      # a point to face when standing (else the way he runs)
var yaw := 0.0
var step_n := 0                  # every foot put down (the footsteps' sound follows it)
var steps_taken := 0             # feet put down since the match last read them (the carry rules count them)

var action := ""
var action_t := 0.0
var action_len := 0.0
var action_mirror := 1.0         # -1 for a mirrored version
var action_dir := Vector3.ZERO   # the way the action points (a signal, a dive)
var _ph := 0.0
var _prev_ph := 0.0
var _lod_skip := 0
var _pose_every := 1
var _flag: MeshInstance3D
var _flag_att: BoneAttachment3D
var fatigue := 0.0               # 0 fresh .. 1 spent: slower, and his striking less true, through the game
var agility := 1.0               # USER_ACCEL_K while you control him, else 1
var came_on := 0                 # how many times a substitute has taken this place (the movement audit skips the change)
var tire_k := 1.0                # match seconds a real second while the ball is live (the match sets it): tiring
                                 # goes by the match clock, so a short match tires a man as a full one does
var down_until := 0.0            # on the ground until then (match time)
var sent_off := false
var sin_bin_until := -1.0        # match clock (s) he may come back
var yellows := 0
var blacks := 0
var ball_hand := false           # the ball shows in his left hand
var ball_stick := false          # the ball rides on his bas
var visible_on_screen := true


func _init(p_data := {}, p_team := 0, look := {}, p_role := "") -> void:
	data = p_data
	team = p_team
	role = p_role
	num = int(p_data.get("num", 0))
	pos_num = num
	# (Far men are posed every second or third frame: each on his own frame, not all on the same one - a frame that
	# posed them all at once was a hitch.)
	_lod_skip = (num + p_team * 7 + p_role.length()) % 3
	body = _new_body(look)
	if p_data.has("speed"):
		max_speed = speed_of(p_data)
	elif role == "referee":
		max_speed = 7.2
	elif role != "":
		max_speed = 6.0


func _ready() -> void:
	add_child(body)
	body.scale = Vector3.ONE * DRAW_SCALE
	body.rotation.y = yaw
	_link_foundation()


## Drawn with the shared foundation (the owner's model on the shared rig, motion-capture locomotion) when this build
## has the licensed library (FoundationLink); the game's own body stays, posed and measured, unseen.
var link: FoundationLink


func _link_foundation() -> void:
	if link:
		link.queue_free()
		link = null
	if FoundationLink.enabled():
		link = FoundationLink.new(self, body)
		add_child(link)


## A hurler is drawn with the owner's model; an official with a Meshy model (the referee's for the referee and the
## linesmen, the umpire's in his white coat for the umpires).
func _new_body(look: Dictionary) -> ToonBody:
	if role == "" and String(look.get("kind", "player")) == "player":
		return HeroBody.new(look)
	return PersonBody.new(look)


static func speed_of(pd: Dictionary) -> float:
	return lerpf(6.6, 8.4, clampf((float(pd.get("speed", 70)) - 40.0) / 59.0, 0.0, 1.0))


## A substitute comes on in this man's place: his data and looks, fresh legs, no cards; the place in the shape
## (line, side of the field, pos_num) stays.
func take_over(pd: Dictionary, look: Dictionary) -> void:
	came_on += 1
	var d := pd.duplicate()
	d.line = data.get("line", d.get("line", 0))
	d.place = data.get("place", d.get("place", 0.0))
	data = d
	num = int(pd.get("num", num))
	max_speed = speed_of(pd)
	fatigue = 0.0
	yellows = 0
	blacks = 0
	stop_action()
	ball_hand = false
	ball_stick = false
	var lod: int = body._lod
	body.queue_free()
	body = _new_body(look)
	add_child(body)
	body.scale = Vector3.ONE * DRAW_SCALE
	body.set_lod(lod)
	body.rotation.y = yaw
	_link_foundation()


## How tired he is, as a share of what he can give: 1 fresh.
func freshness() -> float:
	return 1.0 - fatigue

func is_official() -> bool:
	return role != ""


func line() -> int:
	return int(data.get("line", -1))


func is_keeper() -> bool:
	return role == "" and line() == DB.POS_GK


func on_pitch() -> bool:
	return not sent_off and sin_bin_until < 0.0


func busy() -> bool:
	return action != "" and action_t < action_len and not action.begins_with("sig_")


func down(now: float) -> bool:
	return now < down_until


## Start an action now (it replaces any that is playing). mirror -1 plays it the other way round.
func play(name: String, dir := Vector3.ZERO, mirror := 1.0) -> void:
	action = name
	action_t = 0.0
	action_len = float(ACTIONS.get(name, [0.5, 0.0])[0])
	action_dir = dir
	action_mirror = mirror
	if name in ["sig_point", "sig_goal", "sig_sideline", "sig_card"]:
		_show_flag(name)
	elif _flag:
		_flag.visible = false


func contact_time(name: String) -> float:
	return float(ACTIONS.get(name, [0.5, 0.0])[1])


func stop_action() -> void:
	action = ""
	action_t = 0.0
	if _flag:
		_flag.visible = false


## How fast he can run now: his top speed, a little less when tired or soloing.
func top_speed() -> float:
	var k := 1.0 - fatigue * 0.12
	if ball_stick:
		k *= 0.93
	elif ball_hand:
		k *= 0.97
	return max_speed * k


## The one place his position changes. want_vel is clamped to his top speed; his velocity moves toward it at his
## acceleration (faster when braking); he turns toward the way he runs (or toward face_to) at a person's rate.
func integrate(dt: float, now: float) -> void:
	if down(now):
		want_vel = Vector3.ZERO
	var w := Vector3(want_vel.x, 0, want_vel.z)
	var top := top_speed()
	if action in ["catch", "lift", "strike", "puck_out", "cut", "hand_pass", "save", "block"] and action_t < action_len:
		top *= 0.55 if action in ["strike", "puck_out", "cut"] else 0.8
	if w.length() > top:
		w = w.normalized() * top
	var dv := w - vel
	var rate := (ACCEL if w.length() >= vel.length() else DECEL) * agility
	if dv.length() > rate * dt:
		dv = dv.normalized() * rate * dt
	vel += dv
	position += vel * dt
	# Facing: where he runs, or where he is told to look. A man told to look one way while moving the other
	# backpedals if he is slow about it; faster than a backpedal, he turns and runs (a man facing the ball while
	# running away from it looked to run forward while sliding backward: the owner's report).
	var sp := vel.length()
	var want_yaw := yaw
	var look := Vector3.ZERO
	if face_to != Vector3.ZERO:
		look = face_to - position
		look.y = 0.0
	var away := sp > 0.5 and look.length() > 0.2 and look.normalized().dot(vel / sp) < -0.3
	if sp > 1.2 and (face_to == Vector3.ZERO or (away and sp > BACKPEDAL)):
		want_yaw = atan2(vel.x, vel.z)
	elif look.length() > 0.2:
		want_yaw = atan2(look.x, look.z)
	elif sp > 0.3:
		want_yaw = atan2(vel.x, vel.z)
	var turn := TURN * (1.0 - clampf((sp - 5.0) / 6.0, 0.0, 0.5)) * dt * (USER_TURN_K if agility > 1.0 else 1.0)
	yaw += clampf(wrapf(want_yaw - yaw, -PI, PI), -turn, turn)
	body.rotation.y = yaw
	# The stride: a foot down twice a cycle; run backward (the clip in reverse) when he moves the way he faces away
	# from: a backpedal.
	var stride := stride_at(sp, body.scale.x if body != null else DRAW_SCALE)
	_prev_ph = _ph
	var back := sp > 0.3 and forward().dot(vel / sp) < -0.3
	_ph += sp / stride * PI * dt * (-1.0 if back else 1.0)
	if floor(_ph / PI) != floor(_prev_ph / PI) and sp > 0.4:
		steps_taken += 1
		step_n += 1
	if action != "":
		action_t += dt
		if action_t >= action_len and not action.begins_with("sig_"):
			action = ""
	# Tiring: a little all the time, much more in a sprint; less for a man with stamina. Over a full match a
	# hard-working player ends about two-thirds spent (docs/AI.md).
	if role == "":
		var st := clampf(float(data.get("stamina", 70)) / 100.0, 0.3, 1.0)
		fatigue = minf(1.0, fatigue + dt * tire_k * (0.00004 + sp * sp * 0.000011) * lerpf(1.35, 0.75, st))


func take_steps() -> int:
	var n := steps_taken
	steps_taken = 0
	return n


## The direction he faces.
func forward() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


## Pose the body for this frame. Far players are posed every second or third frame (set_pose_rate); a player off
## the screen not at all.
func set_pose_rate(n: int) -> void:
	_pose_every = maxi(1, n)


func animate(now: float) -> void:
	if not visible_on_screen:
		return
	_lod_skip += 1
	if _lod_skip < _pose_every:
		return
	_lod_skip = 0
	var p := _pose(now)
	if Ultra.lit():
		p = _crossfade(p, now)
	body.apply(p)
	_plant_feet(now)
	if link:
		link.update(now)


## The feet kept still on the grass while he runs (the owner: "too many steps and the players are floating"): a foot
## coming down is held where it lands, the leg turned to it (two-bone IK) as the body goes on over it, till the clip
## lifts it or the leg is straight behind him; then it eases back to the clip's swing. So the planted foot never
## slides, whatever his speed and step.
var _lock := [Vector3.INF, Vector3.INF]     # where each foot is held (world), INF: free
var _lock_w := [0.0, 0.0]                   # how much it is held (eases out when let go)
var _lock_at := [Vector3.ZERO, Vector3.ZERO]
var _lock_now := 0.0
const LEGS := [[11, 12, 13], [14, 15, 16]]  # thigh, shin, foot (ToonBody.BONES)


func _plant_feet(now: float) -> void:
	var dt := clampf(now - _lock_now, 0.0, 0.1)
	_lock_now = now
	var sk := body.skeleton
	var sp := Vector2(vel.x, vel.z).length()
	if sk == null or sp < 0.6 or action != "":
		_lock = [Vector3.INF, Vector3.INF]
		_lock_w = [0.0, 0.0]
		return
	if _leg_len <= 0.0:
		var hip_r := sk.get_bone_global_rest(LEGS[0][0]).origin
		var ank_r := sk.get_bone_global_rest(LEGS[0][2]).origin
		_leg_len = hip_r.distance_to(ank_r)
		_rest_ankle = ank_r.y
	var xf := sk.global_transform
	var inv := xf.affine_inverse()
	var ground := global_position.y + float(_rest_ankle) * body.scale.y
	var ankles := []
	for leg in LEGS:
		ankles.append(xf * sk.get_bone_global_pose(leg[2]).origin)
	for i in 2:
		var leg: Array = LEGS[i]
		var a: Vector3 = ankles[i]
		var other: Vector3 = ankles[1 - i]
		var down := a.y < ground + 0.035 and a.y <= other.y + 0.01
		var hip := xf * sk.get_bone_global_pose(leg[0]).origin
		var reach := _leg_len * body.scale.y * 0.995
		if _lock[i] == Vector3.INF:
			if down and _lock_w[i] <= 0.0:
				_lock[i] = Vector3(a.x, ground, a.z)
				_lock_at[i] = _lock[i]
		elif not down and a.y > ground + 0.07 or hip.distance_to(_lock[i]) > reach:
			_lock[i] = Vector3.INF          # let go: it eases back to the clip
		if _lock[i] != Vector3.INF:
			_lock_w[i] = 1.0
			_lock_at[i] = _lock[i]
		else:
			_lock_w[i] = maxf(0.0, _lock_w[i] - dt / 0.1)
		if _lock_w[i] <= 0.0:
			continue
		_leg_ik(sk, leg, inv * a.lerp(_lock_at[i], _lock_w[i]))


## The leg (thigh, shin) turned so its ankle is at target (skeleton space), the knee bending the way it was; the foot
## keeps its turn in the world.
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


var _rest_ankle := 0.0      # the ankles' height off the grass at rest (model units)
var _leg_len := 0.0         # hip to ankle at rest


const FADE := 0.18               # High: seconds to blend from one move into the next
var _fade_from := {}
var _fade := 0.0
var _fade_action := ""
var _fade_now := 0.0


## High (on Vulkan): a move starting or ending blends from where the body was over FADE seconds, rather than jumping
## to the move's first frame (every level's moves are clips sampled in time; High also smooths the joins between them).
func _crossfade(p: Dictionary, now: float) -> Dictionary:
	var dt := clampf(now - _fade_now, 0.0, 0.1)
	_fade_now = now
	if action != _fade_action:
		_fade_action = action
		if not _fade_from.is_empty():
			_fade = FADE
	if _fade > 0.0:
		_fade = maxf(0.0, _fade - dt)
		var w := 1.0 - _fade / FADE
		w = w * w * (3.0 - 2.0 * w)
		for b in BONE_NAMES:
			p[b] = HeroBody.turn(_fade_from.get(b, Quaternion.IDENTITY)).slerp(HeroBody.turn(p.get(b, Vector3.ZERO)), w)
		p.hips_y = lerpf(float(_fade_from.get("hips_y", 0.0)), float(p.get("hips_y", 0.0)), w)
	var keep := {}
	for b in BONE_NAMES:
		keep[b] = HeroBody.turn(p.get(b, Vector3.ZERO))
	keep.hips_y = float(p.get("hips_y", 0.0))
	_fade_from = keep
	return p


# ---------------------------------------------------------------- poses

func _pose(now: float) -> Dictionary:
	var p := {}
	var sp := Vector2(vel.x, vel.z).length()
	var run := clampf(sp / 7.5, 0.0, 1.0)
	var s := sin(_ph)
	var c := cos(_ph)
	# Legs and arms in a run, from a walk to a sprint.
	var amp := lerpf(4.0, 48.0, run) if sp > 0.25 else 0.0
	p.thigh_l = Vector3(-s * amp - 4.0 * run, 0, 2)
	p.thigh_r = Vector3(s * amp - 4.0 * run, 0, -2)
	p.shin_l = Vector3(maxf(0.0, c) * amp * 1.3 + 5.0, 0, 0)
	p.shin_r = Vector3(maxf(0.0, -c) * amp * 1.3 + 5.0, 0, 0)
	p.foot_l = Vector3(-6.0 * run, 0, 0)
	p.foot_r = Vector3(-6.0 * run, 0, 0)
	p.hips_y = -absf(s) * 0.03 * run - 0.02 * run
	p.spine = Vector3(6.0 + 10.0 * run, 0, 0)
	p.chest = Vector3(2.0, -s * 6.0 * run, 0)
	p.head = Vector3(-8.0 * run, 0, 0)
	p.upperarm_l = Vector3(s * amp * 0.8 - 6.0, 0, 8)
	p.forearm_l = Vector3(30.0 + 40.0 * run, 0, 0)
	# The hurley carried in the right hand, down and forward; it swings a little with the stride.
	p.upperarm_r = Vector3(-18.0 - s * 6.0 * run, 0, -10)
	p.forearm_r = Vector3(28.0, 0, 0)
	p.hand_r = Vector3(-10.0, 0, 0)
	if is_official():
		p.upperarm_r = Vector3(-s * amp * 0.8 - 6.0, 0, -8)
		p.forearm_r = Vector3(30.0 + 40.0 * run, 0, 0)
	if ball_stick:
		# The solo: the bas held out in front at waist height, the sliotar balanced or hopping on it.
		p.upperarm_r = Vector3(-55.0, 0, -6)
		p.forearm_r = Vector3(18.0 + sin(_ph * 2.0) * 6.0, 0, 0)
		p.hand_r = Vector3(-30.0, 0, 0)
		p.upperarm_l = Vector3(-30.0, 0, -14)
		p.forearm_l = Vector3(40.0, 0, 0)
	elif ball_hand:
		# The sliotar in the left hand, held in front.
		p.upperarm_l = Vector3(-38.0, 0, 6)
		p.forearm_l = Vector3(62.0, 0, 0)
	# Moving, the legs, the body and the free arm from motion capture: a walk and a jog from the CMU library, the
	# Mixamo sprint, each in step with the stride (the left thigh furthest forward at phase pi/2 as above) and blended
	# by speed; the right arm keeps the hurley as it is carried.
	var wg := smoothstep(0.25, 0.8, sp)
	var wr := smoothstep(2.6, 5.5, sp)
	if wg > 0.0:
		var run_p := gait_pose(sp, _ph)
		# (An official's arms are the swing above, beside the body: the clips' arms, retargeted onto the officials'
		# models, came up in front of the chest like a boxer's guard.)
		for i in (RUN_BODY if is_official() or ball_stick or ball_hand else RUN_ARM_L):
			p[BONE_NAMES[i]] = HeroBody.turn(p.get(BONE_NAMES[i], Vector3.ZERO)).slerp(run_p[0][i], wg)
		p.hips_y = lerpf(float(p.get("hips_y", 0.0)), float(run_p[1]), wg)
		if sp > 0.3 and forward().dot(Vector3(vel.x, 0, vel.z) / sp) < -0.3:
			# A backpedal: the clip run in reverse (integrate), the body upright rather than leaning into a run.
			for bn in ["spine", "chest"]:
				p[bn] = HeroBody.turn(p.get(bn, Vector3.ZERO)).slerp(Quaternion.IDENTITY, 0.6)
		if wr > 0.0 and not is_official() and not ball_stick:
			# The hurley carried as hurlers carry it at a run: the arm forward and bent, swinging a little with the
			# stride, the stick held steady forward and down across the body. (Taking the sprint clip's pumping arm
			# swung the hurley through half a circle each stride, up over the head and back: the owner found it
			# unnatural, not smooth.)
			var carry := [Vector3(-40.0 - s * 5.0, 0, -12), Vector3(52.0 + c * 4.0, 0, 0), Vector3(-42.0, 0, 0)]
			for j in 3:
				var bn: String = ["upperarm_r", "forearm_r", "hand_r"][j]
				p[bn] = HeroBody.turn(p.get(bn, Vector3.ZERO)).slerp(HeroBody.turn(carry[j]), wr)
	if action != "" and action_t <= action_len + 0.001:
		var t := clampf(action_t / maxf(0.01, action_len), 0.0, 1.0)
		if SWING_CLIP.has(action):
			_swing_pose(p, action, t, run)
		elif action in ["free_set", "free_strike"]:
			_free_pose(p, action, action_t)
		else:
			_action_pose(p, action, t, now)
	return p


## A free struck from the grass, as the owner's slow-motion video shows it (tools/mocap/free_clip.py): he stands over
## it side-on to the posts, his left shoulder to them, the hurley in both hands (free_set, held while the free is aimed), then bends to it, slides the bas under it and lifts it, the sliotar
## rising on the hurley to his head, tosses it, swings back over his right shoulder and strikes it as it drops past
## his waist out in front of him (free_strike). The clips face +Z in the stance; FREE_YAW turns him from the posts.
const FREE_YAW := -100.0
## Where the sliotar lies from his feet as he stands over it, in his own frame (+Z the way the player faces, the
## posts): under the bas as he slides it under the ball in the strike (the clip's scoop), measured once from a man
## posed so (measure_free_bas); till then, a stride ahead of his right foot.
static var _free_bas := Vector3.INF
static var _free_hit := Vector3(0.6, 0.95, 0.9)   # the bas at contact, the same way


static func free_ball_offset() -> Vector3:
	if _free_bas != Vector3.INF:
		return _free_bas
	return Quaternion(Vector3.UP, deg_to_rad(FREE_YAW)) * Vector3(0.0, 0, 0.9)


## Where the bas meets the sliotar in the strike, from his feet in his own frame.
static func free_hit_offset() -> Vector3:
	return _free_hit


## The free's moments from the clip (seconds into free_strike): "scoop" (the bas under the ball, it comes up on it),
## "release" (tossed off the bas) and "contact".
static func free_moment(which: String) -> float:
	return float(HeroBody.data().clips.Free_Strike.get(which, 0.0))


## Poses this man at the free's scoop for a moment and notes where his bas is, from his feet in his own frame.
func measure_free_bas() -> void:
	if _free_bas != Vector3.INF or body == null:
		return
	var keep := [action, action_t, visible_on_screen]
	play("free_strike")
	action_t = free_moment("scoop")
	visible_on_screen = true
	_lod_skip = _pose_every
	animate(0.0)
	var b := body.bas_world()
	var local := Basis(Vector3.UP, body.global_rotation.y).inverse() * (b - global_position)
	_free_bas = Vector3(local.x, 0.0, local.z)
	# And where it meets the ball, for the toss to come down to.
	action_t = free_moment("contact")
	_lod_skip = _pose_every
	animate(0.0)
	_free_hit = Basis(Vector3.UP, body.global_rotation.y).inverse() * (body.bas_world() - global_position)
	action = keep[0]
	action_t = keep[1]
	visible_on_screen = keep[2]


func _free_pose(p: Dictionary, name: String, at: float) -> void:
	var cp: Array
	var w := 1.0
	match name:
		"free_set":
			cp = HeroBody.clip_pose("Free_Ready", 0.0)
			w = smoothstep(0.0, 0.3, at)
		_:
			cp = HeroBody.clip_pose("Free_Strike", at)
	var yaw := Quaternion(Vector3.UP, deg_to_rad(FREE_YAW))
	# Standing tall while he waits and aims (the owner: "more upright before the swing"), settling into the video's
	# address - hips hinged, eyes on the ball - in the strike's first 0.4 s: lift and set, then strike.
	var up := 1.0 if name == "free_set" else 1.0 - smoothstep(0.0, 0.4, at)
	if up > 0.0 and not OS.has_environment("NO_UP"):
		cp = [_free_upright(cp[0], up), cp[1], cp[2]]
	# (The follow-through only: from just before contact. The set-up, the lift and the toss are as the video has them.)
	var c := free_moment("contact")
	var lw := smoothstep(c - 0.15, c + 0.05, at) if name == "free_strike" else 0.0
	for i in BONE_NAMES.size():
		var q: Quaternion = cp[0][i] if i > 0 else yaw * cp[0][0]
		# (The shins and feet throughout: the video's shins turn 40 degrees about their length and its ankles point
		# down, tip up and turn past an ankle's range from the set on - the owner saw the skin wrung thin above the
		# ankle, a "pinched shin".)
		var wi := 1.0 if BONE_NAMES[i].begins_with("foot") or BONE_NAMES[i].begins_with("shin") else lw
		if wi > 0.0 and FREE_LIMITS.has(BONE_NAMES[i]):
			q = q.slerp(_limited(q, FREE_LIMITS[BONE_NAMES[i]]), wi)
		p[BONE_NAMES[i]] = HeroBody.turn(p.get(BONE_NAMES[i], Vector3.ZERO)).slerp(q, w)
	var lift := float(cp[1])
	if name == "free_set":
		lift += sin(at * 1.7) * 0.006      # standing over it, breathing
	p.hips_y = lerpf(float(p.get("hips_y", 0.0)), lift, w)
	var tr: Vector2 = cp[2]
	var off := yaw * Vector3(tr.x, 0.0, tr.y)
	p.hips_side = lerpf(float(p.get("hips_side", 0.0)), off.x, w)
	p.hips_fwd = lerpf(float(p.get("hips_fwd", 0.0)), off.z, w)


## The free's stance made upright by `up` (0 as the clip has it, 1 standing tall): the hips' 30-degree hinge forward
## taken out but 6 (the thighs turned back as much, so the legs stay as they stand), the head up from the ball and
## level.
static func _free_upright(turns: Array, up: float) -> Array:
	var out := turns.duplicate()
	var hinge := deg_to_rad(24.0) * up
	out[0] = Quaternion(Vector3.RIGHT, -hinge) * (turns[0] as Quaternion)
	for b in ["thigh_l", "thigh_r"]:
		var i := BONE_NAMES.find(b)
		out[i] = Quaternion(Vector3.RIGHT, hinge) * (turns[i] as Quaternion)
	for b in ["neck", "head"]:
		var i := BONE_NAMES.find(b)
		out[i] = (turns[i] as Quaternion).slerp(Quaternion.IDENTITY, 0.6 * up)
	return out


## The free's follow-through within what a body does (Euler YXZ degrees, [min, max] about x, y, z). The clip is the
## video's landmarks (tools/mocap/free_clip.py), which lose the legs and the head after the strike: a knee bent 35 degrees
## sideways, the trailing boot spun half round and back between frames, the neck and the head each tipped back 20 and
## the chest twisted 28 on the spine's 28 - the owner saw "the shin very odd, the body seems to break". A knee is a
## hinge (its bend only); a foot turns a little from its shin; the head goes back with the neck about 30 in all.
const FREE_LIMITS := {
	"shin_l": [Vector3(0, -10, -8), Vector3(140, 10, 8)], "shin_r": [Vector3(0, -10, -8), Vector3(140, 10, 8)],
	"foot_l": [Vector3(-25, -20, -15), Vector3(45, 20, 15)], "foot_r": [Vector3(-25, -20, -15), Vector3(45, 20, 15)],
	"spine": [Vector3(-12, -22, -15), Vector3(40, 22, 15)], "chest": [Vector3(-12, -22, -15), Vector3(40, 22, 15)],
	"neck": [Vector3(-6, -40, -20), Vector3(40, 40, 20)], "head": [Vector3(-6, -40, -20), Vector3(40, 40, 20)],
}


static func _limited(q: Quaternion, lim: Array) -> Quaternion:
	var e := q.get_euler(EULER_ORDER_YXZ) * (180.0 / PI)
	e = e.clamp(lim[0], lim[1])
	return Basis.from_euler(e * (PI / 180.0), EULER_ORDER_YXZ).get_rotation_quaternion()


## The gaits, slowest first: [clip, the speed (m/s) at which it alone is shown]. Between two, both, blended.
## Each with its own step at that speed (m, for the standard drawn man, measured on the clip: the planted foot's
## speed back under the hips times a step's time).
const GAITS := [["CMU_Walk", 1.3, 0.627], ["CMU_Jog", 2.6, 1.039], ["Fast_Run", 4.0, 1.364]]
const TOP_STEP := [8.5, 2.2]   # past the sprint's own pace, the step grows to this at this speed


## The body's turns and the hips' lift moving at sp m/s, at stride phase ph: the gait clips nearest sp, blended, each
## at the point of its own cycle that phase ph is.
static func gait_pose(sp: float, ph: float) -> Array:
	var a := 0
	while a < GAITS.size() - 1 and sp > float(GAITS[a + 1][1]):
		a += 1
	var b := mini(a + 1, GAITS.size() - 1)
	var w := 0.0 if a == b else smoothstep(float(GAITS[a][1]), float(GAITS[b][1]), sp)
	var pa := _gait_clip(String(GAITS[a][0]), ph)
	var out := pa
	if w > 0.0:
		var pb := _gait_clip(String(GAITS[b][0]), ph)
		var turns := []
		for i in pa[0].size():
			turns.append((pa[0][i] as Quaternion).slerp(pb[0][i], w))
		out = [turns, lerpf(pa[1], pb[1], w)]
	return out





static func _gait_clip(name: String, ph: float) -> Array:
	var c: Dictionary = HeroBody.data().clips[name]
	var cycle := float(c.frames.size() - 1) / float(c.fps)
	return HeroBody.clip_pose(name, float(c.left_forward) + (ph / TAU - 0.25) * cycle, true)


## A stride's length (m) at sp m/s for a man drawn scale times the model's size: the step of the gait clips blended
## at that speed, just as gait_pose blends them; standing to a walk, from half a metre; past the sprint's own pace,
## longer, to 2.2 m at full pelt. A walk is about two steps a second, a run three to just under four (the owner saw
## "too many steps"); the planted foot is held still by _plant_feet (tests/test_runner.gd _foot_slide).
static func stride_at(sp: float, scale := DRAW_SCALE) -> float:
	var u := sp * DRAW_SCALE / scale           # the speed for a man of the standard drawn size
	var s: float
	var last: Array = GAITS[GAITS.size() - 1]
	if u <= float(GAITS[0][1]):
		s = lerpf(0.5, float(GAITS[0][2]), u / float(GAITS[0][1]))
	elif u >= float(last[1]):
		s = lerpf(float(last[2]), float(TOP_STEP[1]), smoothstep(float(last[1]), float(TOP_STEP[0]), u))
	else:
		var a := 0
		while u > float(GAITS[a + 1][1]):
			a += 1
		var w := smoothstep(float(GAITS[a][1]), float(GAITS[a + 1][1]), u)
		s = lerpf(float(GAITS[a][2]), float(GAITS[a + 1][2]), w)
	return s * scale / DRAW_SCALE


const BONE_NAMES := ["hips", "spine", "chest", "neck", "head", "upperarm_l", "forearm_l", "hand_l", "upperarm_r",
	"forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]   # ToonBody.BONES' order
const RUN_BODY := [0, 1, 2, 3, 4, 11, 12, 13, 14, 15, 16]   # the body and legs
const RUN_ARM_L := RUN_BODY + [5, 6, 7]                    # and the free (left) arm
## The swings from the owner's Mixamo clips: from the hand and off the hurley a baseball hit (the backswing over
## the right shoulder, level through the ball), the overhead pull the bigger swing, along the ground the golf drive.
const SWING_CLIP := {"strike": "Baseball_Hit", "strike_stick": "Baseball_Hit", "puck_out": "Baseball_Hit",
	"pull": "Baseball_Strike", "ground": "Golf_Drive", "cut": "Golf_Drive"}
const SWING_BEFORE := 0.6   # seconds of the clip played before the bas meets the ball
const SWING_AFTER := 0.5    # and after


## A swing from its clip, timed so the bas meets the ball at the action's contact time, turned so the ball goes the
## way he faces (the clip's "yaw"), eased in from his run and out again; his legs keep more of the run the faster he
## is going.
func _swing_pose(p: Dictionary, name: String, t: float, run: float) -> void:
	var c: Dictionary = HeroBody.data().clips[SWING_CLIP[name]]
	var ct := contact_time(name) / action_len
	var hit := float(c.contact)
	var ct_clip := lerpf(hit - SWING_BEFORE, hit, t / ct) if t < ct else lerpf(hit, hit + SWING_AFTER, (t - ct) / (1.0 - ct))
	var sw := HeroBody.clip_pose(SWING_CLIP[name], ct_clip)
	var w := smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.86, 1.0, t))
	var wl := w * (1.0 - 0.6 * run)
	var yaw := Quaternion(Vector3.UP, deg_to_rad(float(c.yaw)))
	for i in BONE_NAMES.size():
		var q: Quaternion = sw[0][i] if i > 0 else yaw * sw[0][0]
		p[BONE_NAMES[i]] = HeroBody.turn(p.get(BONE_NAMES[i], Vector3.ZERO)).slerp(q, wl if i >= 11 else w)
	p.hips_y = lerpf(float(p.get("hips_y", 0.0)), float(sw[1]), wl)


static func _k(t: float, a: float, b: float) -> float:
	return smoothstep(a, b, t)


func _action_pose(p: Dictionary, name: String, t: float, now: float) -> void:
	var m := action_mirror
	match name:
		"hand_pass":
			var k := _k(t, 0.0, 0.45) * (1.0 - _k(t, 0.7, 1.0))
			p.upperarm_l = Vector3(-30.0 - 60.0 * k, 0, -10.0 * k)
			p.forearm_l = Vector3(60.0 - 50.0 * k, 0, 0)
			p.chest = Vector3(6.0, -25.0 * k, 0)
		"catch":
			# The left hand up for the ball; a leap when it is high (action_dir.y: how high to reach).
			var up := _k(t, 0.0, 0.45) * (1.0 - _k(t, 0.75, 1.0))
			var jump := clampf(action_dir.y, 0.0, 0.6)
			p.upperarm_l = Vector3(-60.0 - 115.0 * up, 0, 6)
			p.forearm_l = Vector3(20.0 * (1.0 - up), 0, 0)
			p.upperarm_r = Vector3(-60.0 * up - 20.0, 0, -20)
			p.hips_y = sin(t * PI) * jump
			p.thigh_l = Vector3(-35.0 * up * (jump / 0.6), 0, 2)
			p.shin_l = Vector3(60.0 * up * (jump / 0.6), 0, 0)
			p.head = Vector3(-25.0 * up, 0, 0)
		"lift":
			var down := _k(t, 0.0, 0.5) * (1.0 - _k(t, 0.6, 1.0))
			p.spine = Vector3(45.0 * down + 6.0, 0, 0)
			p.chest = Vector3(15.0 * down, 0, 0)
			p.thigh_l = Vector3(-35.0 * down, 0, 4)
			p.shin_l = Vector3(45.0 * down, 0, 0)
			p.thigh_r = Vector3(-10.0 * down, 0, -4)
			p.shin_r = Vector3(30.0 * down, 0, 0)
			p.hips_y = -0.16 * down
			p.upperarm_r = Vector3(-40.0 * down - 15.0, 0, -6)
			p.forearm_r = Vector3(10.0, 0, 0)
			p.hand_r = Vector3(-35.0 * down, 0, 0)
			p.upperarm_l = Vector3(-50.0 * down, 0, 0)
		"solo", "to_hand":
			var k := sin(t * PI)
			p.upperarm_r = Vector3(-55.0, 0, -6)
			p.forearm_r = Vector3(18.0, 0, 0)
			p.upperarm_l = Vector3(-40.0 - 20.0 * k, 0, -12)
			p.forearm_l = Vector3(50.0, 0, 0)
		"tackle":
			var k := sin(t * PI)
			p.spine = Vector3(14.0, 0, -18.0 * k * m)
			p.chest = Vector3(4.0, 20.0 * k * m, -10.0 * k * m)
			p.upperarm_l = Vector3(-20.0, 0, 24.0 * k)
		"hook", "block", "flick":
			var k := sin(t * PI)
			var high := name == "block"
			p.upperarm_r = Vector3((-150.0 if high else -70.0) * k - 20.0, 0, -15.0)
			p.forearm_r = Vector3(10.0, 0, 0)
			p.upperarm_l = Vector3((-140.0 if high else -50.0) * k, 0, -30.0 * k)
			p.spine = Vector3(10.0 + (0.0 if high else 18.0 * k), 0, 0)
			if high:
				p.hips_y = 0.18 * k
		"fall":
			var dn := _k(t, 0.0, 0.25) * (1.0 - _k(t, 0.65, 1.0))
			p.hips_x = Vector3(-70.0 * dn, 0, 0)
			p.hips = Vector3(-70.0 * dn, 0, 0)
			p.hips_y = -0.75 * dn
			p.thigh_l = Vector3(-50.0 * dn, 0, 6)
			p.thigh_r = Vector3(-30.0 * dn, 0, -6)
			p.upperarm_l = Vector3(-40.0 * dn, 0, 40.0 * dn)
			p.upperarm_r = Vector3(-40.0 * dn, 0, -40.0 * dn)
		"save":
			var k := _k(t, 0.0, 0.3) * (1.0 - _k(t, 0.7, 1.0))
			var sd := signf(action_dir.x) if action_dir.x != 0.0 else 1.0
			p.hips = Vector3(0, 0, -50.0 * k * sd)
			p.hips_y = -0.3 * k
			p.upperarm_l = Vector3(-170.0 * k, 0, 0)
			p.upperarm_r = Vector3(-160.0 * k, 0, 0)
		"celebrate":
			var pump := sin(t * 18.0)
			p.upperarm_l = Vector3(-150.0 - 20.0 * pump, 0, 25)
			p.forearm_l = Vector3(30.0 + 30.0 * pump, 0, 0)
			p.upperarm_r = Vector3(-120.0, 0, -35)
			p.head = Vector3(-20.0, 0, 0)
		"dejected":
			p.spine = Vector3(25.0, 0, 0)
			p.head = Vector3(30.0, 0, 0)
			p.upperarm_l = Vector3(-10.0, 0, 4)
		"sig_free":
			# Facing across the pitch, the right arm straight out toward the goal the free attacks.
			p.upperarm_r = Vector3(-90.0 * _side_k(), 0, -85.0)
			p.forearm_r = Vector3(0, 0, 0)
			p.upperarm_l = Vector3(-10.0, 0, 4)
		"sig_advantage":
			p.upperarm_r = Vector3(-178.0, 0, -6)
			p.forearm_r = Vector3(0, 0, 0)
		"sig_card", "sig_sinbin":
			p.upperarm_r = Vector3(-170.0, 0, -10)
			p.forearm_r = Vector3(5.0, 0, 0)
			if name == "sig_sinbin":
				p.upperarm_l = Vector3(-120.0, 0, 20)
				p.upperarm_r = Vector3(-120.0, 0, -20)
		"sig_throw":
			var up := _k(t, 0.0, 0.4) * (1.0 - _k(t, 0.45, 0.8))
			p.upperarm_r = Vector3(-60.0 - 100.0 * up, 0, -10)
			p.upperarm_l = Vector3(-50.0, 0, 10)
		# The umpires' signals: the arm raised out from the side with the elbow straight, as umpires do (raised
		# forwards to overhead, the models' coats folded at the shoulder and the arm looked broken: the owner's
		# report); eased up and down, the flag waved slowly side to side.
		"sig_point", "sig_goal":
			var up := _k(t, 0.0, 0.16) * (1.0 - _k(t, 0.86, 1.0))
			var wave := sin(now * 3.6) * 9.0 * up
			p.upperarm_r = Vector3(-12.0 * up, 0, -8.0 - 140.0 * up + wave)
			p.forearm_r = Vector3(4.0, 0, 0)
		"sig_wide":
			# Both arms up from the sides to cross over his head, and swung there.
			var up := _k(t, 0.0, 0.18) * (1.0 - _k(t, 0.86, 1.0))
			var wave := sin(now * 3.0) * 7.0 * up
			p.upperarm_l = Vector3(-14.0 * up, 0, 8.0 + 168.0 * up - wave)
			p.upperarm_r = Vector3(-14.0 * up, 0, -8.0 - 168.0 * up + wave)
			p.forearm_l = Vector3(4.0, 0, 0)
			p.forearm_r = Vector3(4.0, 0, 0)
		"sig_65":
			# Straight up, then down to point in at the 65.
			var up := _k(t, 0.0, 0.15) * (1.0 - _k(t, 0.88, 1.0))
			var later := _k(t, 0.45, 0.62)
			p.upperarm_r = Vector3(lerpf(-8.0, -88.0, later) * up, 0, lerpf(-164.0, -6.0, later) * up - 8.0 * (1.0 - up))
			p.forearm_r = Vector3(4.0, 0, 0)
		"sig_sideline":
			p.upperarm_r = Vector3(-90.0, 0, -80.0)
			p.forearm_r = Vector3(0, 0, 0)
		"sig_penalty":
			p.upperarm_r = Vector3(-70.0, 0, -10)
			p.upperarm_l = Vector3(-70.0, 0, 10)
			p.forearm_l = Vector3(0, 0, 0)
			p.forearm_r = Vector3(0, 0, 0)
		"sig_whistle":
			p.upperarm_r = Vector3(-60.0, 0, 20)
			p.forearm_r = Vector3(100.0, 0, 0)


## Which way the referee's free arm points: he faces the camera side, so it is his right arm or his left.
func _side_k() -> float:
	return 1.0


# ---------------------------------------------------------------- flags and cards

const FLAG_COLOURS := {"sig_point": Color("f6f6f2"), "sig_goal": Color("2fa34a"), "sig_sideline": Color("f2c230"),
	"sig_card_yellow": Color("f2d21e"), "sig_card_red": Color("d4202a"), "sig_card_black": Color("141414")}

var card_colour := "yellow"


func _show_flag(kind: String) -> void:
	if _flag == null:
		_flag_att = BoneAttachment3D.new()
		_flag_att.bone_name = "hand_r"
		body.skeleton.add_child(_flag_att)
		_flag = MeshInstance3D.new()
		var g := Geo.new()
		g.cylinder(Vector3(0, 0, 0), Vector3(0, -0.62, 0), 0.012, 0.012, Color("2a2a2a"), 5, false)
		g.wall(Vector3(0, 0, 0), Vector3(0.42, 0, 0), -0.62, -0.32, Color.WHITE, true)
		_flag.mesh = g.commit(Geo.material(false)).mesh
		_flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flag_att.add_child(_flag)
		if body is PersonBody:
			# Held as before: the officials' hands are turned to hang naturally (PersonBody.TWIST).
			_flag.rotation.y = -deg_to_rad((body as PersonBody).right_turn())
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_flag.material_override = mat
	var key := kind if kind != "sig_card" else "sig_card_" + card_colour
	(_flag.material_override as StandardMaterial3D).albedo_color = FLAG_COLOURS.get(key, Color.WHITE)
	# A card is small: a flag's cloth shrunk to a card in the fingers.
	_flag.scale = Vector3(1, 0.3, 0.25) if kind == "sig_card" else Vector3.ONE
	_flag.visible = true
