class_name Athlete
extends Node3D
## One player, or an official, on the field: his body (ToonBody), where he wants to go, and what he is doing. The match
## decides what he does (want, act); integrate() is the one place his position is written each frame, so nothing
## else moves him and nothing snaps: speed changes within his acceleration, a turn bends his run, his strides keep pace
## with his speed (tests/motion_audit.gd checks all three).

const ACCEL := 9.0          # m/s^2 a sprinter gathers speed ...
const DECEL := 13.0         # ... and sheds it (kho kho turns are sharp: players stop dead on a line)

var data := {}              # DB.squad's player, or {} for an official
var side := 0               # 0 or 1 (-1 an official)
var body: ToonBody
var want := Vector3.ZERO    # the velocity he is trying for (m/s, flat)
var vel := Vector3.ZERO
var top := 7.0              # his flat-out speed now (m/s)
var face_to := Vector3.ZERO # a point to face when still (a seated chaser faces his half; an umpire the play)
var act := ""               # "", "sit", "rise", "kho", "dive", "pole_dive", "lie", "getup", "whistle", "out", "foul", "end", "cheer"
var act_t := 0.0            # seconds into it
var act_len := 0.0          # its length (0: held until changed)
var mirror := false         # play the act mirrored (left-handed for a pole dive round the other side)
var stamina := 1.0          # 0-1: a defender tires as he runs flat out
var agility := 1.0          # how sharply he gathers, sheds and turns his speed (a defender's turn rating)
var yaw := 0.0
var _ph := 0.0
var _pose := {}
var _prev_act := ""
var _blend := 1.0


func _init(p_data := {}, p_side := 0, look := {}) -> void:
	data = p_data
	side = p_side
	body = ToonBody.new(look)


func _ready() -> void:
	add_child(body)
	body.rotation.y = yaw
	_pose = Poses.STAND


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
	_blend = 0.0


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
			return
		"lie":
			act = "getup"
			act_t = 0.0
			act_len = 0.45
			return
		"getup", "out", "foul", "end", "cheer":
			act = ""
	act_len = 0.0
	act_t = 0.0


## Strides at a rate set by his speed (one stride each half turn of the phase), so his feet keep pace with the ground.
func stride_rate(spd: float) -> float:
	return PI * spd / Poses.stride(spd)


func _animate(dt: float, spd: float) -> void:
	_ph += dt * stride_rate(spd)
	var k := clampf(spd / 8.0, 0.0, 1.0)
	var local := vel.rotated(Vector3.UP, -yaw)
	var sidestep := clampf(local.x / maxf(spd, 0.01), -1.0, 1.0) if spd > 0.4 else 0.0
	var base: Dictionary = Poses.run(_ph, k, sidestep) if spd > 0.35 else Poses.blend(Poses.READY, Poses.run(_ph, 0.0), spd / 0.35)
	if data.is_empty() and spd < 0.35:
		base = Poses.STAND
	var target := base
	var f := act_t / act_len if act_len > 0.0 else 1.0
	match act:
		"sit":
			target = Poses.SIT
		"rise":
			target = Poses.blend(Poses.SIT, base, smoothstep(0.0, 1.0, f))
		"kho":
			target = Poses.blend(base, Poses.KHO, sin(PI * clampf(f, 0.0, 1.0)))
		"dive":
			target = Poses.blend(Poses.READY, Poses.DIVE, smoothstep(0.0, 0.35, f))
		"pole_dive":
			target = Poses.blend(Poses.READY, Poses.POLE_DIVE, smoothstep(0.0, 0.3, f))
		"lie":
			target = Poses.LIE
		"getup":
			target = Poses.blend(Poses.LIE, Poses.READY, smoothstep(0.0, 1.0, f))
		"whistle":
			target = Poses.WHISTLE
		"out":
			target = Poses.SIGNAL_OUT
		"foul":
			target = Poses.SIGNAL_FOUL
		"end":
			target = Poses.SIGNAL_END
		"cheer":
			target = Poses.CHEER
	if mirror:
		target = Poses.mirrored(target)
	# Into a new pose over a few frames, never in one.
	_blend = minf(1.0, _blend + dt * (10.0 if act in ["dive", "pole_dive", "kho"] else 6.0))
	_pose = Poses.blend(_pose, target, _blend if _blend < 1.0 else 1.0)
	body.apply(_pose)
