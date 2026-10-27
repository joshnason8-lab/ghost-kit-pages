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


## A dodge: a hard cut aside, over len seconds, to dir (the match moves him; this is how he looks doing it). The
## recorded cut goes to his left; a cut to his right plays it mirrored.
func dodge(dir: Vector3, len: float) -> void:
	do("dodge", len, dir.dot(Vector3(cos(yaw), 0.0, -sin(yaw))) < 0.0)


## Round the pole as the real chasers do (docs/AI.md, "The pole turn"): a hand on it, he swings round it from angle
## a0 to a1 (radians round c, from +x toward +z), drawn in from where he took hold (r0 out) to a tight circle (r),
## his speed rising evenly from v_in to v_out, faster than he came in: the pole's slingshot. The swing takes as long
## as that speed needs to cover it.
func pole_swing(c: Vector3, r0: float, r: float, a0: float, a1: float, v_in: float, v_out: float) -> void:
	var arc := absf(a1 - a0) * (r0 + r) * 0.5
	var len := 2.0 * arc / maxf(v_in + v_out, 0.1)
	swing = {"c": c, "r0": r0, "r": r, "a0": a0, "a1": a1, "v_in": v_in, "v": v_out, "arc": arc}
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
		"rise", "getup":
			w = w.limit_length(2.0)
	if w.length() > top:
		w = w.normalized() * top
	var dv := w - vel
	var rate := ACCEL if w.length() >= vel.length() else DECEL
	if act == "dive" and act_t > 0.25:
		dv = -vel
		rate = 10.0   # he lands and slides to a stop
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
	# Distance round, with the speed rising evenly from v_in to v_out: s = (v_in f + (v_out - v_in) f^2 / 2) T.
	var done := (v_in * f + (v_out - v_in) * f * f * 0.5) * act_len / maxf(float(swing.arc), 0.001)
	var a := lerpf(float(swing.a0), float(swing.a1), clampf(done, 0.0, 1.0))
	var r := lerpf(float(swing.r0), float(swing.r), smoothstep(0.0, 0.25, act_t))
	var dir := signf(float(swing.a1) - float(swing.a0))
	var tangent := Vector3(-sin(a), 0, cos(a)) * dir
	position = c + Vector3(cos(a), 0, sin(a)) * r
	vel = tangent * lerpf(v_in, v_out, f)
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


## A dive, start to finish (the dive clip alone is a dive into water, and held, it left him leaning in the air): he
## launches, his body pitches forward from the feet until he is down flat, arms reaching (DIVE_PITCH), a little off the
## ground on the way; he slides on the ground (lie); then he pushes up through a kneel to his feet (getup).
const DIVE_PITCH := 1.4     # radians: down on the ground, the chest just above it
const DIVE_CLIP := Vector2(0.2, 0.36)   # the stretch of the dive clip a dive plays (s)
const LIE_S := 0.55
const GETUP_S := 0.7


func _dive_body() -> void:
	var pitch := 0.0
	var lift := 0.0
	var f := clampf(act_t / act_len, 0.0, 1.0) if act_len > 0.0 else 1.0
	match act:
		"dive", "pole_dive":
			pitch = DIVE_PITCH * smoothstep(0.0, 1.0, f)
			lift = 0.3 * sin(PI * minf(f * 1.15, 1.0))
		"lie":
			pitch = DIVE_PITCH
			lift = 0.05
		"getup":
			# The first half brings his chest up to kneeling; the rest is the kneel, backwards, to standing.
			pitch = DIVE_PITCH * (1.0 - smoothstep(0.0, 0.55, f))
	body.rotation.x = pitch
	body.rotation.z = 0.0
	body.position.y = lift


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
		"kho", "reach":
			# The hand out to the seated chaser's back (or the defender): the reach's second half, fast.
			c = "reach"
			var span := body.clip_length("reach") * 0.55
			rate = span / maxf(act_len, 0.1)
			at = body.clip_length("reach") - span
			blend = 0.08
		"dive", "pole_dive":
			# Only the clip's spring and stretch (DIVE_CLIP): after it the recorded diver tumbles into the water.
			c = "dive"
			rate = (DIVE_CLIP.y - DIVE_CLIP.x) / maxf(act_len, 0.2)
			at = DIVE_CLIP.x
			blend = 0.06
		"lie":
			c = "dive"
			rate = 0.0001
		"getup":
			# Up from the ground: on to his knees as his chest comes up, then to his feet.
			c = "kneel" if f < 0.5 else "idle"
			blend = 0.15 if f < 0.5 else 0.3
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
