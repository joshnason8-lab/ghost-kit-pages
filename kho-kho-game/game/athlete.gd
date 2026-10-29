class_name Athlete
extends Node3D
## One player, or an official, on the field: his body (ModelBody), where he wants to go, and what he is doing. The match
## decides what he does (want, act); integrate() is the one place his position is written each frame, so nothing
## else moves him and nothing snaps: speed changes within his acceleration, a turn bends his run, his strides keep pace
## with his speed (tests/motion_audit.gd checks all three).

const ACCEL := 9.0          # m/s^2 a sprinter gathers speed ...
const DECEL := 13.0         # ... and sheds it (kho kho turns are sharp: players stop dead on a line)

var data := {}              # DB.squad's player, or {} for an official
var side := 0               # 0 or 1 (-1 an official)
var body: ModelBody
var want := Vector3.ZERO    # the velocity he is trying for (m/s, flat)
var vel := Vector3.ZERO
var top := 7.0              # his flat-out speed now (m/s)
var face_to := Vector3.ZERO # a point to face when still (a seated chaser faces his half; an umpire the play)
var act := ""               # "", "sit", "rise", "kho", "dive", "pole_dive", "lie", "getup", "whistle", "out", "foul", "end", "cheer", "dodge"
var act_t := 0.0            # seconds into it
var act_len := 0.0          # its length (0: held until changed)
var mirror := false         # play the act mirrored (left-handed for a pole dive round the other side)
var stamina := 1.0          # 0-1: a defender tires as he runs flat out
var agility := 1.0          # how sharply he gathers, sheds and turns his speed (a defender's turn rating)
var yaw := 0.0
var watch := Vector3.INF    # a point his head turns to follow (a seated chaser watches the play), INF none
var _head := 0.0
var _prev_act := ""
var _knelt := false
var _stride := 0.0          # through his stride: a footstep at each half
var _dive_v0 := 0.0         # m/s he leaves the ground at in a dive
var swing := {}             # round the pole, a hand on it: {c: the pole, r, a0, a1, v: speed out} (pole_swing)


func _init(p_data := {}, p_side := 0, look := {}) -> void:
	data = p_data
	side = p_side
	body = ModelBody.new(look, int(Game.settings.graphics) <= Game.GFX_LOW)


func _ready() -> void:
	add_child(body)
	body.rotation.y = yaw


func speed_rating() -> float:
	return float(data.get("speed", 70))


## Starts an act (a pose held or played over len seconds).
func do(p_act: String, len := 0.0, p_mirror := false) -> void:
	if p_act == act and len == 0.0:
		return
	_prev_act = act
	act = p_act
	act_t = 0.0
	act_len = len
	mirror = p_mirror
	if act in ["dive", "pole_dive"]:
		_dive_v0 = Vector2(vel.x, vel.z).length()
		if act == "dive":
			_dive_v0 = maxf(_dive_v0, 5.6)   # a pole dive lunges out from the pole at its own pace


## A dodge: a hard cut aside, over len seconds, to dir (the match moves him; this is how he looks doing it). The
## recorded cut goes to his left; a cut to his right plays it mirrored.
func dodge(dir: Vector3, len: float) -> void:
	do("dodge", len, dir.dot(Vector3(cos(yaw), 0.0, -sin(yaw))) < 0.0)


## Round the pole as the real chasers do (docs/AI.md, "The pole turn"): a hand on it, he swings round it from angle
## a0 to a1 (radians round c, from +x toward +z), drawn in from where he took hold (r0 out) to a tight circle (r).
## He comes in at v_in, slows as he takes the pole's weight, swings round at SWING_V on average (the video: half a
## turn in about half a second) and goes out at v_out: v(f) = v_in + (v_out - v_in) f + k f (1 - f), with k such that
## the mean is SWING_V, so his speed never jumps.
const SWING_V := 3.6


func pole_swing(c: Vector3, r0: float, r: float, a0: float, a1: float, v_in: float, v_out: float) -> void:
	var arc := absf(a1 - a0) * (r0 + r) * 0.5
	var len := arc / SWING_V
	var k := 6.0 * (SWING_V - (v_in + v_out) * 0.5)
	swing = {"c": c, "r0": r0, "r": r, "a0": a0, "a1": a1, "v_in": v_in, "v": v_out, "k": k, "arc": arc}
	do("pole_turn", len, a1 > a0)


func busy() -> bool:
	return act in ["rise", "kho", "dive", "pole_dive", "lie", "getup"]


## Moves him: toward want, within his acceleration; in a dive his body carries on as it was launched; seated, he
## stays where he is. Then faces and poses him.
func integrate(dt: float) -> void:
	act_t += dt
	if act_len > 0.0 and act_t >= act_len:
		_finish_act()
	if act == "pole_turn" and not swing.is_empty():
		_swing_step()
		return
	var w := want
	w.y = 0.0
	match act:
		"sit", "kho", "lie", "whistle", "out", "foul", "end":
			w = Vector3.ZERO
		"dive", "pole_dive":
			w = vel   # in the air: no steering
		"rise":
			w = w.limit_length(2.0)
		"getup":
			w = Vector3.ZERO   # up from the ground where he lies; he runs once on his feet
	if w.length() > top:
		w = w.normalized() * top
	var dv := w - vel
	var rate := ACCEL if w.length() >= vel.length() else DECEL
	if act in ["dive", "pole_dive"]:
		# Off the ground at his run's speed (no slower than a dive's), losing speed through the air to land with
		# DIVE_LAND left; then he slides to a stop on his front (lie).
		var f := clampf(act_t / maxf(act_len, 0.1), 0.0, 1.0)
		var sp := vel.length()
		if sp > 0.01:
			vel = vel.normalized() * move_toward(sp, lerpf(_dive_v0, DIVE_LAND, f * f), 30.0 * dt)
		dv = Vector3.ZERO
	elif act == "lie":
		dv = -vel
		rate = 8.0
	vel += dv.limit_length(rate * agility * dt)
	position += vel * dt
	position.y = 0.0
	# Facing: where he runs, or the point he watches when still.
	var spd := Vector2(vel.x, vel.z).length()
	var want_yaw := yaw
	if spd > 0.6 and not (act in ["sit"]):
		want_yaw = atan2(vel.x, vel.z)
	elif face_to != Vector3.ZERO:
		var to := face_to - position
		if Vector2(to.x, to.z).length() > 0.2:
			want_yaw = atan2(to.x, to.z)
	var turn_rate := 14.0 if act == "sit" or act == "rise" else 9.0
	yaw = lerp_angle(yaw, want_yaw, minf(1.0, turn_rate * dt))
	body.rotation.y = yaw
	_dive_body()
	_animate(dt, spd)


func _swing_step() -> void:
	var f := clampf(act_t / maxf(act_len, 0.01), 0.0, 1.0)
	var c: Vector3 = swing.c
	var v_in: float = swing.v_in
	var v_out: float = swing.v
	var k: float = swing.k
	# Distance round: the integral of v(f) (pole_swing) over the swing so far.
	var done := (v_in * f + (v_out - v_in) * f * f * 0.5 + k * (f * f * 0.5 - f * f * f / 3.0)) * act_len / maxf(float(swing.arc), 0.001)
	var a := lerpf(float(swing.a0), float(swing.a1), clampf(done, 0.0, 1.0))
	var r := lerpf(float(swing.r0), float(swing.r), smoothstep(0.0, 0.25, act_t))
	var dir := signf(float(swing.a1) - float(swing.a0))
	var tangent := Vector3(-sin(a), 0, cos(a)) * dir
	position = c + Vector3(cos(a), 0, sin(a)) * r
	vel = tangent * (v_in + (v_out - v_in) * f + k * f * (1.0 - f))
	# He leans out from the pole, facing between it and the way he swings; his hands reach for it.
	var to_pole := (c - position).normalized()
	var face := (tangent + to_pole * 0.9).normalized()
	yaw = atan2(face.x, face.z)
	body.rotation.y = yaw
	body.rotation.x = 0.0
	body.position.y = 0.0
	# Leaning out from the pole, his arms holding him in, as the turn pulls him round.
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	body.rotation.z = signf(to_pole.dot(right)) * 0.3 * sin(PI * f)
	body.grip_arms = 2
	body.grip = c + Vector3(0, 1.1, 0)
	if act_t + get_physics_process_delta_time() >= act_len:
		# Letting go: out along the tangent, at the swing's speed and more.
		vel = tangent * float(swing.v)
		yaw = atan2(tangent.x, tangent.z)
		swing = {}
		body.grip = Vector3.INF
	_animate(0.0, vel.length())


func _finish_act() -> void:
	body.grip = Vector3.INF
	match act:
		"rise":
			act = ""
		"kho":
			act = ""
		"dive", "pole_dive":
			act = "lie"
			act_t = 0.0
			act_len = LIE_S
			Sfx.play_at("thud", global_position, -2.0, randf_range(0.9, 1.05))   # down on the ground
			return
		"lie":
			act = "getup"
			act_t = 0.0
			act_len = GETUP_S
			return
		"getup", "out", "foul", "end", "cheer", "pole_turn", "dodge":
			act = ""
	if act == "":
		mirror = false   # his run after a mirrored act is his own again
	act_len = 0.0
	act_t = 0.0


## A dive, start to finish, made by hand as Kabaddi Raid's is (ModelBody.DivePose; the only recorded dive is a dive
## into water, which left him leaning on one leg in the air): off his run he tips over about his hips, arms reaching
## out and down, legs trailing, his hips on a short arc from their running height down to lying on the ground as he
## lands (dive); he slides on his front to a stop (lie); then pushes up onto his hands and knees, and from there gets
## to his feet (getup). The time he is down is what it always was (LIE_S + GETUP_S).
const DIVE_PITCH := 1.5     # radians from upright: lying on his front, his chest just off level
const DIVE_LAND := 2.0      # m/s he has left as he lands; he slides the rest away on the ground
const HIP_RUN := 0.92       # m: his hips running (the run clip's) ...
const HIP_LIE := 0.13       # ... lying on his front ...
const HIP_FOURS := 0.5      # ... and on his hands and knees
const LIE_S := 0.3
const GETUP_S := 0.95
const FOURS_AT := 0.4       # the share of the get-up he takes to be on his hands and knees


func _dive_body() -> void:
	body.rotation.x = 0.0
	body.position.y = 0.0
	var f := clampf(act_t / act_len, 0.0, 1.0) if act_len > 0.0 else 1.0
	match act:
		"dive", "pole_dive":
			body.dive = smoothstep(0.0, 0.3, f)
			body.dive_pitch = DIVE_PITCH * smoothstep(0.0, 0.8, f)
			body.dive_push = 0.0
			# Up a little off his last stride, then down onto the ground as he lands.
			body.dive_h = HIP_RUN + 0.08 * sin(PI * minf(f / 0.6, 1.0)) - (HIP_RUN - HIP_LIE) * smoothstep(0.1, 1.0, f)
		"lie":
			body.dive = 1.0
			body.dive_pitch = DIVE_PITCH
			body.dive_push = 0.0
			body.dive_h = HIP_LIE
		"getup":
			if f < FOURS_AT:
				# Hands under his shoulders, knees under his hips: up onto all fours.
				var g := smoothstep(0.0, 1.0, f / FOURS_AT)
				body.dive = 1.0
				body.dive_pitch = lerpf(DIVE_PITCH, 1.35, g)
				body.dive_push = g
				body.dive_h = lerpf(HIP_LIE, HIP_FOURS, g)
			else:
				# From all fours up to his feet: the hand-made pose gives way to his standing one as his hips rise.
				var g := smoothstep(0.0, 1.0, (f - FOURS_AT) / (1.0 - FOURS_AT))
				body.dive = 1.0 - g
				body.dive_pitch = lerpf(1.35, 0.25, g)
				body.dive_push = 1.0
				body.dive_h = lerpf(HIP_FOURS, HIP_RUN, g)
		_:
			body.dive = 0.0


## Which of the model's clips he plays, and how fast: his run or walk at the rate that keeps his feet with the
## ground; the act's clip fitted to the act's length.
func _animate(dt: float, spd: float) -> void:
	var f := act_t / act_len if act_len > 0.0 else 1.0
	var c := ""
	var rate := 1.0
	var blend := 0.18
	var at := -1.0
	match act:
		"sit":
			# Down on to his knees, then kneeling, watching.
			if not _knelt:
				c = "kneel_down"
				rate = 2.2
				if body.clip == "kneel_down" and not body.anim.is_playing():
					_knelt = true
			if _knelt:
				c = "kneel"
		"rise":
			c = "run"
			blend = 0.3
		"reach", "kho" when spd > 1.2:
			# Reaching on the run (for a defender, or the seated chaser's back as he slows into the kho): his legs keep
			# running, his arm goes out (body.grip, one arm).
			c = "run" if spd > 2.6 else "walk"
			rate = ModelBody.rate_for(c, spd)
		"kho", "reach":
			# The hand out to the seated chaser's back (or the defender): the reach's second half, fast.
			c = "reach"
			var span := body.clip_length("reach") * 0.55
			rate = span / maxf(act_len, 0.1)
			at = body.clip_length("reach") - span
			blend = 0.08
		"dive", "pole_dive", "lie":
			# Under the hand-made dive (_dive_body), his last stride, slowing to a stop.
			c = "run"
			rate = 0.25 if act != "lie" else 0.0001
			blend = 0.25
		"getup":
			# Under it as he gets up, his standing at ease, which he comes up into.
			c = "idle"
			blend = 0.4
		"whistle":
			c = "whistle"
		"out":
			c = "signal_out"
		"foul":
			c = "signal_foul"
		"end":
			c = "signal_end"
		"cheer":
			c = "cheer"
		"dodge":
			# The recorded cut, fitted to the dodge, faster still if he moves faster than the actor did.
			c = "dodge"
			rate = maxf(body.clip_length("dodge") / maxf(act_len, 0.2), ModelBody.rate_for("dodge", spd))
			at = 0.0
			blend = 0.08
		"pole_turn":
			# His feet run round the pole; his hands hold it (body.grip, set in _swing_step).
			c = "run"
			rate = ModelBody.rate_for("run", spd)
			blend = 0.1
	if c == "":
		if spd > 2.6:
			c = "run"
			rate = ModelBody.rate_for("run", spd)
		elif spd > 0.35:
			c = "walk"
			rate = ModelBody.rate_for("walk", spd)
		else:
			# Standing at ease: the recorded idle, each man at his own point in it so a line of them does not sway
			# as one.
			c = "idle"
			at = fposmod(float(get_instance_id() % 997) * 0.37, body.clip_length("idle"))
	if act != "sit":
		_knelt = false
	body.play(c, rate, blend, at)
	# His feet: two steps to each cycle of his run or walk, as fast as the clip plays.
	if c in ["run", "walk"] and spd > 0.5:
		_stride += dt * 2.0 * rate / body.clip_length(c)
		if _stride >= 1.0:
			_stride -= 1.0
			Sfx.step(global_position, spd)
	body.scale.x = -absf(body.scale.x) if mirror else absf(body.scale.x)
	# A head that follows the play: up to 70 degrees either way of where his body faces, eased.
	var want_head := 0.0
	if watch != Vector3.INF:
		var to := watch - position
		var rel := wrapf(atan2(to.x, to.z) - yaw, -PI, PI)
		want_head = clampf(rad_to_deg(rel), -70.0, 70.0)
	_head = lerpf(_head, want_head, minf(1.0, dt * 6.0))
	body.head_yaw = _head
