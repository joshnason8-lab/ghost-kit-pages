class_name Player
extends Node3D
## One player on the court: her squad entry (data), her position, the body that draws her, and her movement. Her
## position is written in one place only, advance(), once a frame by the match: the AI and the controls set where she
## wants to go (target) and how fast (want_speed), never her position. She accelerates and turns at a person's rate,
## so nothing snaps from one frame to the next; her stride is matched to her speed (Poses.run). tests/test_runner
## checks both ("_motion").

const ACCEL := 9.0           # m/s² speeding up
const DECEL := 12.0          # m/s² stopping (a landing on the catch takes about one step)
const TURN := 9.0            # rad/s
const TOP := 7.2             # m/s, a sprint at speed 99

var match_ref = null         # the Match
var team := 0
var pos := "C"               # her position (bib) now
var data := {}               # her squad entry (DB.squad)
var dir := 1                 # the end her team attacks this quarter
var body: ToonBody

var p := Vector2.ZERO        # where she is on the court (x along, y across), metres
var vel := Vector2.ZERO
var facing := 0.0            # yaw, radians: 0 faces +z
var target := Vector2.ZERO
var want_speed := 0.0        # m/s she wants to go toward target
var look_at_p := Vector2.ZERO
var look_on := false         # face look_at_p (the ball) rather than where she runs

var act := "ready"           # what her body does: ready, run, hold, pass, catch, shoot, defend, defend_shot, mark,
                             # leap, out_of_play, cheer
var act_t := 0.0
var act_kind := ""           # the pass's kind, for "pass"
var act_up := 0.0            # where the ball is met, for "catch" (-1 low .. 1 high)
var landing := Vector2.ZERO  # her landing foot while she holds the ball
var stopped := false         # holding the ball: she may not run (footwork), only pivot
var reaction := 0.0          # seconds before she reacts to a new read (the AI's)
var lead_t := 0.0            # the AI: time left on her current lead or hold
var lead_to := Vector2.ZERO
var moves := 0               # tests: how many times this frame her position was written (must be 1)
var stride_phase := 0.0
var out_until := 0.0         # standing out of play beside the thrower of a penalty pass
var suspended := 0.0         # seconds of playing time left on a suspension (R6): off the court, by the bench
var warned := false          # the umpire has warned her (R6)
var pens := 0                # penalties since her last sanction
var was_offside := false     # offside last frame (an offside is called when she steps in, not while she walks out)
var fenced := true           # she keeps to her areas (the AI always; you with Keep me onside): she pulls up at a line
                             # rather than running over it
var _pose := {}
var _airborne := 0.0


func _init(p_team: int, p_data: Dictionary, p_pos: String) -> void:
	team = p_team
	data = p_data
	pos = p_pos


func _ready() -> void:
	var t := DB.team(String(data.team))
	var c1: Color = t.get("c1", Color.WHITE)
	var c2: Color = t.get("c2", Color.BLACK)
	body = ToonBody.new({"skin": Color(String(data.skin)), "dress": c1, "trim": c2, "bib": DB.bib_colour(String(data.team)),
		"shoe": Color("f3f1ee"), "hair": Color("15100c") if int(data.hair) != 2 else Color("2a1d14"),
		"hair_style": int(data.hair), "height": float(data.height), "pos": pos})
	add_child(body)
	_pose = Poses.ready(0.6)
	body.apply(_pose)


func speed_cap() -> float:
	return TOP * lerpf(0.78, 1.0, float(data.get("speed", 70)) / 99.0)


## Puts her on a spot at once: only between plays (the start of a quarter), never while she is seen running.
func place(at: Vector2, face_dir := 0.0) -> void:
	p = at
	vel = Vector2.ZERO
	target = at
	want_speed = 0.0
	facing = face_dir
	position = Vector3(p.x, 0, p.y)
	rotation.y = facing


## The one place her position changes, once a frame.
func advance(dt: float) -> void:
	moves += 1
	var to := target - p
	var dist := to.length()
	var cap := minf(want_speed, speed_cap())
	if stopped:
		cap = 0.0
	# The speed she wants: slowing as she arrives, so she stops on the spot rather than past it.
	var desired := Vector2.ZERO
	if dist > 0.05 and cap > 0.0:
		var arrive := sqrt(2.0 * DECEL * 0.8 * dist)
		desired = to / dist * minf(cap, arrive)
	# Pulling up at a line she may not cross: no faster than she can stop before it.
	if fenced and desired.length() > 0.1:
		var room := _room_along(desired.normalized())
		if room < 3.0:
			desired = desired.limit_length(sqrt(2.0 * DECEL * 0.85 * maxf(0.0, room - 0.12)))
	var dv := desired - vel
	var rate := ACCEL if desired.length() > vel.length() else DECEL
	var step := rate * dt
	vel = vel + dv.limit_length(step)
	var next := p + vel * dt
	if fenced and Rules.offside(pos, next, dir) and not Rules.offside(pos, p, dir):
		# At the line: she stops on her side of it.
		next = Rules.onside_point(pos, next, dir, 0.02)
		vel = (next - p) / maxf(dt, 0.001)
	p = next
	position = Vector3(p.x, 0, p.y)
	# Facing: the ball (or a look target) when set, else where she runs.
	var want_face := facing
	if look_on:
		var d := look_at_p - p
		if d.length() > 0.05:
			want_face = atan2(d.x, d.y)
	elif vel.length() > 0.4:
		want_face = atan2(vel.x, vel.y)
	facing = rotate_toward(facing, want_face, TURN * dt)
	rotation.y = facing
	_animate(dt)


## How far she can run in direction d before a line her position may not cross (up to 3 m).
func _room_along(d: Vector2) -> float:
	var s := 0.25
	while s <= 3.0:
		if Rules.offside(pos, p + d * s, dir):
			return s - 0.25
		s += 0.25
	return 3.0


## Picks her body's pose from what she is doing and blends to it (nothing jumps).
func _animate(dt: float) -> void:
	act_t += dt
	var spd := vel.length()
	# Strides: a stride pair is longer the faster she runs, so her feet keep pace with the floor.
	var pair := lerpf(1.3, 2.9, clampf(spd / 7.0, 0.0, 1.0))
	stride_phase = fposmod(stride_phase + spd / pair * dt, 1.0)
	var want: Dictionary
	match act:
		"hold":
			want = Poses.hold()
		"pass":
			want = Poses.pass_(act_kind, clampf(act_t / 0.45, 0.0, 1.0))
		"catch":
			want = Poses.catch_(clampf(act_t / 0.2, 0.0, 1.0), act_up)
		"shoot":
			want = Poses.shoot(clampf(act_t / 0.9, 0.0, 1.0))
		"defend":
			want = Poses.defend_ball(1.0)
		"defend_shot":
			want = Poses.defend_ball(1.0, true)
		"leap":
			want = Poses.leap(clampf(act_t / 0.7, 0.0, 1.0))
		"out_of_play":
			want = Poses.blend(Poses.ready(0.2), Poses.out_of_play(), 1.0)
		"cheer":
			want = Poses.cheer(act_t)
		"mark":
			want = Poses.with_arms(Poses.run(stride_phase, spd), Poses.mark(1.0 if int(act_t * 0.7) % 2 == 0 else -1.0)) if spd > 0.6 else Poses.mark()
		_:
			want = Poses.run(stride_phase, spd) if spd > 0.3 else Poses.ready(0.9)
	if act == "run" or act == "ready":
		if spd > 0.3 and spd < 1.2:
			want = Poses.blend(Poses.ready(0.9), want, (spd - 0.3) / 0.9)
	var k := 1.0 - exp(-14.0 * dt)
	_pose = Poses.blend(_pose, want, k)
	if body:
		body.apply(_pose)


func set_act(a: String, kind := "") -> void:
	if a == act and kind == act_kind:
		return
	act = a
	act_kind = kind
	act_t = 0.0


## Where her hands hold the ball, in the world.
func hand_point() -> Vector3:
	if body == null or body.skeleton == null:
		return position + Vector3(0, 1.3, 0)
	return (body.bone_world("hand_l") + body.bone_world("hand_r")) * 0.5 + Vector3(0, -0.04, 0)


## The height she can reach for a ball, standing (and with a leap).
func reach(leap := false) -> float:
	var h := float(data.get("height", 1.75))
	return h * 1.28 + (0.45 if leap else 0.0)


## Not available to play: out of play for a penalty, or suspended.
func away() -> bool:
	return out_until > 0.0 or suspended > 0.0


func tag() -> String:
	return pos


func surname() -> String:
	var n := String(data.get("name", ""))
	var i := n.find(" ")
	return n.substr(i + 1) if i > 0 else n
