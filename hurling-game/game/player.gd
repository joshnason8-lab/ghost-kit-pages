class_name Player
extends Node3D
## One hurler (or an official) on the pitch: his body (HeroBody; an official's PersonBody), how he moves and the move he is making. The match
## and the AI decide what he does by setting want_vel, face_to and starting actions; this is the only code that moves
## him (integrate), so nothing else writes his position and nothing jumps in a frame: his speed changes by at most
## his acceleration, he turns at a person's rate, and his strides lengthen and quicken with his speed.

const ACCEL := 6.5          # m/s^2 to speed up
const DECEL := 9.0          # m/s^2 to slow down
const TURN := 7.0           # rad/s he can turn his body at a jog (slower at a sprint)
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
	# Facing: where he runs, or where he is told to look when standing.
	var sp := vel.length()
	var want_yaw := yaw
	if sp > 1.2 and face_to == Vector3.ZERO:
		want_yaw = atan2(vel.x, vel.z)
	elif face_to != Vector3.ZERO:
		var d := face_to - position
		if Vector2(d.x, d.z).length() > 0.2:
			want_yaw = atan2(d.x, d.z)
	elif sp > 0.3:
		want_yaw = atan2(vel.x, vel.z)
	var turn := TURN * (1.0 - clampf((sp - 5.0) / 6.0, 0.0, 0.5)) * dt * (USER_TURN_K if agility > 1.0 else 1.0)
	yaw += clampf(wrapf(want_yaw - yaw, -PI, PI), -turn, turn)
	body.rotation.y = yaw
	# The stride: a foot down twice a cycle.
	var stride := stride_at(sp, body.scale.x if body != null else DRAW_SCALE)
	_prev_ph = _ph
	_ph += sp / stride * PI * dt
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
	body.apply(_pose(now))


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
		for i in (RUN_ARMS if is_official() else (RUN_BODY if ball_stick or ball_hand else RUN_ARM_L)):
			p[BONE_NAMES[i]] = HeroBody.turn(p.get(BONE_NAMES[i], Vector3.ZERO)).slerp(run_p[0][i], wg)
		p.hips_y = lerpf(float(p.get("hips_y", 0.0)), float(run_p[1]), wg)
		if wr > 0.0 and not is_official() and not ball_stick:
			# The hurley carried as hurlers carry it at a run (round five: "running looks a bit awkward with the
			# hurley"): the right arm swings with the stride, a little less than the free arm, and the wrist turns
			# the hurley up to point forward, clear of the legs and the grass, rather than hanging straight down.
			for i in [8, 9]:
				p[BONE_NAMES[i]] = HeroBody.turn(p.get(BONE_NAMES[i], Vector3.ZERO)).slerp(run_p[0][i], wr * 0.65)
			p.hand_r = HeroBody.turn(p.get("hand_r", Vector3.ZERO)).slerp(HeroBody.turn(Vector3(-42.0, 0, 0)), wr)
	if action != "" and action_t <= action_len + 0.001:
		var t := clampf(action_t / maxf(0.01, action_len), 0.0, 1.0)
		if SWING_CLIP.has(action):
			_swing_pose(p, action, t, run)
		else:
			_action_pose(p, action, t, now)
	return p


## The gaits, slowest first: [clip, the speed (m/s) at which it alone is shown]. Between two, both, blended.
const GAITS := [["CMU_Walk", 1.3], ["CMU_Jog", 2.6], ["Fast_Run", 5.5]]


## The body's turns and the hips' lift moving at sp m/s, at stride phase ph: the gait clips nearest sp, blended, each
## at the point of its own cycle that phase ph is.
static func gait_pose(sp: float, ph: float) -> Array:
	var a := 0
	while a < GAITS.size() - 1 and sp > float(GAITS[a + 1][1]):
		a += 1
	var b := mini(a + 1, GAITS.size() - 1)
	var w := 0.0 if a == b else smoothstep(float(GAITS[a][1]), float(GAITS[b][1]), sp)
	var pa := _gait_clip(String(GAITS[a][0]), ph)
	if w <= 0.0:
		return pa
	var pb := _gait_clip(String(GAITS[b][0]), ph)
	var turns := []
	for i in pa[0].size():
		turns.append((pa[0][i] as Quaternion).slerp(pb[0][i], w))
	return [turns, lerpf(pa[1], pb[1], w)]


static func _gait_clip(name: String, ph: float) -> Array:
	var c: Dictionary = HeroBody.data().clips[name]
	var cycle := float(c.frames.size() - 1) / float(c.fps)
	return HeroBody.clip_pose(name, float(c.left_forward) + (ph / TAU - 0.25) * cycle, true)


## A stride's length (m) at sp m/s for a man drawn scale times the model's size, so the foot on the ground stays put:
## the CMU walk's and jog's own steps (measured on the drawn man: tests/test_runner.gd _foot_slide), then the sprint
## at a sprinter's cadence, 4.4 steps a second (the Mixamo clip's feet sit still only at five, a whirl of legs).
static func stride_at(sp: float, scale := DRAW_SCALE) -> float:
	var u := sp * DRAW_SCALE / scale           # the speed for a man of the standard drawn size
	var s := u / 4.4
	if u < 5.5:
		var i := 0
		while i < STEPS.size() - 2 and u > STEPS[i + 1].x:
			i += 1
		var a: Vector2 = STEPS[i]
		var b: Vector2 = STEPS[i + 1]
		s = lerpf(a.y, b.y, clampf((u - a.x) / (b.x - a.x), 0.0, 1.0))
	return s * scale / DRAW_SCALE


## (speed m/s, stride m) for the standard drawn man: standing to a walk, the CMU walk, the jog, on to the sprint.
const STEPS := [Vector2(0.0, 0.5), Vector2(1.3, 0.65), Vector2(2.0, 0.8), Vector2(2.6, 1.0), Vector2(3.25, 1.05),
	Vector2(4.2, 1.2), Vector2(5.5, 5.5 / 4.4)]


const BONE_NAMES := ["hips", "spine", "chest", "neck", "head", "upperarm_l", "forearm_l", "hand_l", "upperarm_r",
	"forearm_r", "hand_r", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]   # ToonBody.BONES' order
const RUN_BODY := [0, 1, 2, 3, 4, 11, 12, 13, 14, 15, 16]   # the body and legs
const RUN_ARM_L := RUN_BODY + [5, 6, 7]                    # and the free (left) arm
const RUN_ARMS := RUN_ARM_L + [8, 9, 10]                   # an official: both arms
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
		"sig_point", "sig_goal":
			var wave := sin(now * 9.0) * 25.0
			p.upperarm_r = Vector3(-150.0, 0, -20.0 + wave)
			p.forearm_r = Vector3(10.0, 0, 0)
		"sig_wide":
			var wave := sin(now * 6.0) * 20.0
			p.upperarm_l = Vector3(-165.0, 0, -35.0 + wave)
			p.upperarm_r = Vector3(-165.0, 0, 35.0 - wave)
			p.forearm_l = Vector3(20.0, 0, 0)
			p.forearm_r = Vector3(20.0, 0, 0)
		"sig_65":
			var later := _k(t, 0.45, 0.6)
			p.upperarm_r = Vector3(lerpf(-178.0, -90.0, later), 0, -5.0)
			p.forearm_r = Vector3(0, 0, 0)
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
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_flag.material_override = mat
	var key := kind if kind != "sig_card" else "sig_card_" + card_colour
	(_flag.material_override as StandardMaterial3D).albedo_color = FLAG_COLOURS.get(key, Color.WHITE)
	# A card is small: a flag's cloth shrunk to a card in the fingers.
	_flag.scale = Vector3(1, 0.3, 0.25) if kind == "sig_card" else Vector3.ONE
	_flag.visible = true
