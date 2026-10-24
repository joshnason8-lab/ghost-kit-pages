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


func busy() -> bool:
	return act in ["rise", "kho", "dive", "pole_dive", "lie", "getup"]


## Moves him: toward want, within his acceleration; in a dive his body carries on as it was launched; seated, he
## stays where he is. Then faces and poses him.
func integrate(dt: float) -> void:
	act_t += dt
	if act_len > 0.0 and act_t >= act_len:
		_finish_act()
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
	_animate(dt, spd)


func _finish_act() -> void:
	match act:
		"rise":
			act = ""
		"kho":
			act = ""
		"dive", "pole_dive":
			act = "lie"
			act_t = 0.0
			act_len = 0.55
			Sfx.play_at("thud", global_position, -2.0, randf_range(0.9, 1.05))   # down on the ground
			return
		"lie":
			act = "getup"
			act_t = 0.0
			act_len = 0.45
			return
		"getup", "out", "foul", "end", "cheer", "pole_turn", "dodge":
			act = ""
	if act == "":
		mirror = false   # his run after a mirrored act is his own again
	act_len = 0.0
	act_t = 0.0


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
			c = "dive"
			rate = body.clip_length("dive") / maxf(act_len, 0.2) * 0.6
			at = 0.25
			blend = 0.06
		"lie":
			c = "dive"
			rate = 0.0001
		"getup":
			c = "idle"
			blend = 0.35
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
			c = "turn"
			rate = body.clip_length("turn") * 0.6 / maxf(act_len, 0.2)
			at = body.clip_length("turn") * 0.2
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
