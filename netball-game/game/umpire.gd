class_name Umpire
extends Node3D
## One of the two umpires (R4). Each controls half the court, split at the centre line across it: one goal third and
## half the centre third, the side line down that half and the goal line at its end, and she keeps that half all
## match. She moves along her side line, outside the court, level with play in her half; she blows, calls and
## signals each decision as World Netball's signals show it (Poses.signal), then points the award's direction.

const SPEED := 5.0

var half := -1                # -1: the half at x < 0; +1: x > 0
var side := 1                 # the side line she walks: z = side * (HALF_W + 0.8)
var body: ToonBody
var p := Vector2.ZERO
var vel := Vector2.ZERO
var target := Vector2.ZERO
var facing := 0.0
var sig := ""                 # the signal she is making, or ""
var sig_t := 0.0
var sig_side := 1.0
var _pose := {}


func _init(p_half: int) -> void:
	half = p_half
	side = 1 if p_half < 0 else -1


func _ready() -> void:
	body = ToonBody.new({"umpire": true, "skin": Color("c48f62") if half < 0 else Color("8a5636"), "dress": Color("f2f2f2"),
		"trim": Color("2ec4b6"), "hair": Color("15100c"), "hair_style": 1 if half < 0 else 3, "height": 1.7, "pos": ""})
	add_child(body)
	p = Vector2(-7.0 * -half, side * (Court.HALF_W + 0.8))
	p.x = 7.0 * half
	position = Vector3(p.x, 0, p.y)
	_pose = Poses.ready(0.3)


## Whether a point is in her half (her calls).
func controls(at: Vector2) -> bool:
	return (at.x < 0.0) == (half < 0)


## Follows the ball along her side line while it is in her half (or near the middle), a little behind play.
func follow(ball: Vector2) -> void:
	var x := ball.x
	if half < 0:
		x = clampf(x, -Court.HALF_L + 1.0, 3.0)
	else:
		x = clampf(x, -3.0, Court.HALF_L - 1.0)
	target = Vector2(x, side * (Court.HALF_W + 0.8))


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
	var want := to.limit_length(SPEED) if to.length() > 0.2 else Vector2.ZERO
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
