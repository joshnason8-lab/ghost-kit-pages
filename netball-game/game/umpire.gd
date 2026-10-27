class_name Umpire
extends Node3D
## One of the two umpires (R4). Each controls half the court, split at the centre line across it: one goal third and
## half the centre third, the side line down that half and the goal line at its end, and she keeps that half all
## match. She walks her side line, outside the court, level with play in her half, and goes round the corner onto
## her goal line when the ball is in her circle or deep in her goal third, to see the shot and the contact from the
## end (as the umpires of a real international do, docs/MATCH_STUDY.md). She jogs, never sprints (unless play has
## run away from her); she stands still to blow, call and signal each decision as World Netball's signals show it
## (Poses.signal), then points the award's direction. At a break she walks to the middle. A light teal shirt, dark
## trousers.

const SPEED := 5.0            # catching up with play
const JOG := 3.5              # her usual pace
const WALK := 2.2             # to the middle at a break
const LINE := 0.8             # how far outside the line she stands
const END_Y := 3.5            # where on her goal line: this far from its middle, on her side

var half := -1                # -1: the half at x < 0; +1: x > 0
var side := 1                 # the side line she walks: z = side * (HALF_W + LINE)
var body: ToonBody
var p := Vector2.ZERO
var vel := Vector2.ZERO
var target := Vector2.ZERO
var pace := JOG
var at_end := false           # working from her goal line (the ball in her circle)
var facing := 0.0
var sig := ""                 # the signal she is making, or ""
var sig_t := 0.0
var sig_side := 1.0
var _pose := {}


func _init(p_half: int) -> void:
	half = p_half
	side = 1 if p_half < 0 else -1


func _ready() -> void:
	body = ToonBody.new({"umpire": true, "skin": Color("c48f62") if half < 0 else Color("8a5636"), "dress": Color("6fd6c6"),
		"trim": Color("1c1b26"), "hair": Color("15100c"), "hair_style": 1 if half < 0 else 3, "height": 1.7, "pos": ""})
	add_child(body)
	p = Vector2(7.0 * half, side * (Court.HALF_W + LINE))
	position = Vector3(p.x, 0, p.y)
	_pose = Poses.ready(0.3)


## Whether a point is in her half (her calls).
func controls(at: Vector2) -> bool:
	return (at.x < 0.0) == (half < 0)


## The corner of the court on her side and at her end, outside the lines: her way between side line and goal line.
func corner() -> Vector2:
	return Vector2(half * (Court.HALF_L + LINE), side * (Court.HALF_W + LINE))


## Where she stands on her goal line.
func end_spot() -> Vector2:
	return Vector2(half * (Court.HALF_L + LINE), side * END_Y)


## Follows the ball: along her side line, a little behind play, while it is in her half (or near the middle); round
## the corner to her goal line while it is in her circle or deep in her goal third (back to the side line once it
## has gone up the court). Never across the court: by way of the corner.
func follow(ball: Vector2) -> void:
	pace = JOG
	var deep := ball.x * half
	if not at_end and (deep > Court.HALF_L - 3.5 or Court.in_circle(ball, half)):
		at_end = true
	elif at_end and deep < Court.HALF_L - 6.5 and not Court.in_circle(ball, half):
		at_end = false
	var past_end := absf(p.x) > Court.HALF_L + LINE * 0.6 and signf(p.x) == float(half)
	if at_end:
		target = end_spot() if past_end else corner()
		return
	if past_end and absf(p.y) < Court.HALF_W + LINE * 0.6:
		target = corner()   # back round the corner first
		return
	var x := ball.x
	if half < 0:
		x = clampf(x, -Court.HALF_L + 1.0, 3.0)
	else:
		x = clampf(x, -3.0, Court.HALF_L - 1.0)
	target = Vector2(x, side * (Court.HALF_W + LINE))


## A break: to the middle of the court, walking, beside her colleague.
func to_middle() -> void:
	at_end = false
	pace = WALK
	target = Vector2(half * 0.8, 0.0)


func call_signal(kind: String, award_dir: int) -> void:
	sig = kind
	sig_t = 0.0
	# The award's direction as seen by her: she faces the court, so +x is on her left on the -z side line, on her
	# right on the +z one.
	var facing_court := -side
	sig_side = float(award_dir * facing_court)


## The one place her position changes, once a frame.
func advance(dt: float, ball: Vector2) -> void:
	var to := target - p
	# Her pace (play far from her and she runs to catch up); still while she signals.
	var spd := pace if to.length() < 6.0 or pace == WALK else SPEED
	var want := to.limit_length(spd) if to.length() > 0.2 else Vector2.ZERO
	if sig != "":
		want = Vector2.ZERO
	vel = vel.move_toward(want, 10.0 * dt)
	p += vel * dt
	position = Vector3(p.x, 0, p.y)
	var d := ball - p
	if d.length() > 0.1:
		facing = rotate_toward(facing, atan2(d.x, d.y), 6.0 * dt)
	rotation.y = facing
	var want_pose: Dictionary
	if sig != "":
		sig_t += dt
		want_pose = Poses.umpire_signal(sig, sig_t, sig_side)
		if sig_t > 1.6:
			sig = ""
	elif vel.length() > 0.4:
		want_pose = Poses.run(fposmod(Time.get_ticks_msec() / 1000.0 * vel.length() / 1.6, 1.0), vel.length())
	else:
		want_pose = Poses.ready(0.3)
	_pose = Poses.blend(_pose, want_pose, 1.0 - exp(-12.0 * dt))
	body.apply(_pose)
