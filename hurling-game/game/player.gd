class_name Player
extends Node3D
## One hurler (or an official) on the pitch: his body (ToonBody), how he moves and the move he is making. The match
## and the AI decide what he does by setting want_vel, face_to and starting actions; this is the only code that moves
## him (integrate), so nothing else writes his position and nothing jumps in a frame: his speed changes by at most
## his acceleration, he turns at a person's rate, and his strides lengthen and quicken with his speed.

const ACCEL := 6.5          # m/s^2 to speed up
const DECEL := 9.0          # m/s^2 to slow down
const TURN := 7.0           # rad/s he can turn his body at a jog (slower at a sprint)
const STRIDE_K := 0.32      # a stride's length grows with speed: 0.7 m walking to about 2 m at a sprint

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
	body = ToonBody.new(look)
	if p_data.has("speed"):
		max_speed = speed_of(p_data)
	elif role == "referee":
		max_speed = 7.2
	elif role != "":
		max_speed = 6.0


func _ready() -> void:
	add_child(body)
	body.rotation.y = yaw


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
	body = ToonBody.new(look)
	add_child(body)
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
	var rate := ACCEL if w.length() >= vel.length() else DECEL
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
	var turn := TURN * (1.0 - clampf((sp - 5.0) / 6.0, 0.0, 0.5)) * dt
	yaw += clampf(wrapf(want_yaw - yaw, -PI, PI), -turn, turn)
	body.rotation.y = yaw
	# The stride: a foot down twice a cycle.
	var stride := maxf(0.7, sp * STRIDE_K + 0.45)
	_prev_ph = _ph
	_ph += sp / stride * PI * dt
	if floor(_ph / PI) != floor(_prev_ph / PI) and sp > 0.4:
		steps_taken += 1
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
	if action != "" and action_t <= action_len + 0.001:
		_action_pose(p, action, clampf(action_t / maxf(0.01, action_len), 0.0, 1.0), now)
	return p


static func _k(t: float, a: float, b: float) -> float:
	return smoothstep(a, b, t)


func _action_pose(p: Dictionary, name: String, t: float, now: float) -> void:
	var m := action_mirror
	match name:
		"strike", "strike_stick", "puck_out", "pull":
			# Side on, the hurley drawn back over the right shoulder, swung down through the ball and on round.
			var ct := contact_time(name) / action_len
			var back := _k(t, 0.0, ct * 0.75) * (1.0 - _k(t, ct * 0.8, ct))
			var through := _k(t, ct * 0.8, 1.0)
			p.chest = Vector3(10.0, lerpf(55.0 * back, -55.0, through) if t > ct * 0.8 else 55.0 * back, 0)
			p.spine = Vector3(14.0, 20.0 * back - 20.0 * through, 0)
			p.upperarm_r = Vector3(lerpf(-20.0, -165.0, back) if t < ct * 0.8 else lerpf(-150.0, -60.0, _k(t, ct * 0.8, ct)) - 70.0 * through, 0, -30.0 * back + 25.0 * through)
			p.forearm_r = Vector3(lerpf(28.0, 70.0, back) * (1.0 - through) + 15.0 * through, 0, 0)
			p.hand_r = Vector3(-20.0 - 30.0 * back, 0, 0)
			p.upperarm_l = Vector3(-60.0 * (1.0 - through) - 20.0, 0, -20.0)
			p.forearm_l = Vector3(30.0, 0, 0)
			p.thigh_l = Vector3(-22.0 * back, 0, 4)
			p.thigh_r = Vector3(14.0 * through, 0, -4)
			p.shin_r = Vector3(18.0 * through, 0, 0)
		"ground", "cut":
			# Low over the ball, the hurley swung along the grass.
			var ct := contact_time(name) / action_len
			var back := _k(t, 0.0, ct) * (1.0 - _k(t, ct, ct + 0.1))
			var through := _k(t, ct, 1.0)
			p.spine = Vector3(38.0, 0, 0)
			p.chest = Vector3(14.0, 40.0 * back - 45.0 * through, 0)
			p.thigh_l = Vector3(-30.0, 0, 6)
			p.shin_l = Vector3(40.0, 0, 0)
			p.thigh_r = Vector3(-10.0, 0, -6)
			p.shin_r = Vector3(35.0, 0, 0)
			p.hips_y = -0.12
			p.upperarm_r = Vector3(-30.0 + 100.0 * back - 120.0 * through, 0, -20.0 + 30.0 * through)
			p.forearm_r = Vector3(20.0, 0, 0)
			p.upperarm_l = Vector3(-40.0, 0, -30.0)
			p.forearm_l = Vector3(20.0, 0, 0)
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
