class_name Umpire
extends Node3D
## One of the two umpires (R4). Each controls half the court, split at the centre line across it: one goal third and
## half the centre third, the side line down that half and the goal line at its end, and she keeps that half all
## match. She walks her side line, outside the court, level with play in her half, and goes round the corner onto
## her goal line when the ball is in her circle or deep in her goal third, to see the shot and the contact from the
## end (as the umpires of a real international do, docs/MATCH_STUDY.md). She jogs, never sprints (unless play has
## run away from her); she stands still to blow, call and signal each decision as World Netball's signals show it
## (Poses.signal), then points the award's direction. At a break she walks to the middle. Drawn on every level with
## the players' model (HeroBody: the owner's player, in the umpires' kit, a light teal shirt and dark trousers), her
## feet stepping with the floor (Gait), standing at ease between calls (Poses.idle).

const SPEED := 5.0            # catching up with play
const JOG := 3.5              # her usual pace
const WALK := 2.2             # to the middle at a break
const LINE := 0.8             # how far outside the line she stands
const END_Y := 3.5            # where on her goal line: this far from its middle, on her side

var half := -1                # -1: the half at x < 0; +1: x > 0
var side := 1                 # the side line she walks: z = side * (HALF_W + LINE)
var body: ToonBody
var link: FoundationLink      # the shared foundation drawing her (on the player's model, in the umpires' kit), else null
var p := Vector2.ZERO
var vel := Vector2.ZERO
var target := Vector2.ZERO
var pace := JOG
var at_end := false           # working from her goal line (the ball in her circle)
var facing := 0.0
var sig := ""                 # the signal she is making, or ""
var sig_t := 0.0
var sig_side := 1.0
var gait: Gait                # her feet, legs and arms on the move (as the players')
var body_yaw := 0.0           # where her body faces as drawn: the ball, or the way she runs when she jogs
var _arms_w := 1.0
var _pose := {}
var _idle_t := 0.0
var _var := Vector4(0.5, 0.5, 0.5, 0.5)   # her own way of standing (Poses.idle)
var solid: WsgSolidProps      # the venue's props (Arena.solid): she walks round them, never through
var floor_rect := Rect2(-50, -50, 100, 100)   # the venue's floor (Arena.floor_rect)
var _memo := {}
var _way := PackedVector3Array()
var _way_to := Vector2.INF


func _init(p_half: int) -> void:
	half = p_half
	side = 1 if p_half < 0 else -1


func _ready() -> void:
	# (A human, not the old code-built figure: the owner's "the referees look too much like block figures".)
	body = HeroBody.new({"umpire": true, "skin": Color("c48f62") if half < 0 else Color("8a5636"), "dress": Color("6fd6c6"),
		"trim": Color("6fd6c6"), "bib": Color("6fd6c6"), "trousers": Color("1c1b26"), "shoe": Color("f3f1ee"),
		"hair": Color("15100c") if half < 0 else Color("2a1d14"), "hair_style": 1 if half < 0 else 3, "height": 1.7 if half < 0 else 1.66, "pos": ""})
	add_child(body)
	if FoundationLink.enabled():
		link = FoundationLink.new(self, body, "umpire")
		add_child(link)
	p = Vector2(7.0 * half, side * (Court.HALF_W + LINE))
	position = Vector3(p.x, 0, p.y)
	var m := get_parent()
	if m is Match and (m as Match).arena:
		solid = (m as Match).arena.solid
		floor_rect = (m as Match).arena.floor_rect
	_var = Vector4(0.3, 0.7, 0.4, 0.6) if half < 0 else Vector4(0.8, 0.2, 0.7, 0.3)
	_pose = Poses.idle(0.0, 0.0, _var)
	gait = Gait.new(body)


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
	# At a break, her walk to the middle goes round the props (WsgSolidProps.path); in play she keeps to her lines.
	var goal := target
	if solid and pace == WALK:
		if _way_to.distance_to(target) > 0.25:
			_way = solid.path(Vector3(p.x, 0, p.y), Vector3(target.x, 0, target.y), Player.BODY_R, Player.BODY_H)
			_way_to = target
		while _way.size() > 1 and Vector2(_way[0].x, _way[0].z).distance_to(p) < 0.4:
			_way.remove_at(0)
		if not _way.is_empty():
			goal = Vector2(_way[0].x, _way[0].z)
	elif solid:
		_way_to = Vector2.INF
		var g := solid.free_spot(Vector3(target.x, 0, target.y), Player.SPOT_R, Player.BODY_H)
		goal = Vector2(g.x, g.z)
	var to := goal - p
	# Her pace (play far from her and she runs to catch up); still while she signals.
	var spd := pace if to.length() < 6.0 or pace == WALK else SPEED
	var want := to.limit_length(spd) if to.length() > 0.2 else Vector2.ZERO
	if sig != "":
		want = Vector2.ZERO
	vel = vel.move_toward(want, 10.0 * dt)
	if solid:
		# Her step among the venue's props (WsgSolidProps.move), the velocity she really moved at handed on.
		var m := solid.move(Vector3(p.x, 0, p.y), Vector3(vel.x, 0, vel.y), dt, Player.BODY_R, Player.BODY_H, Vector3(goal.x, 0, goal.y), _memo)
		var q: Vector3 = m[0]
		var r := floor_rect
		q = solid.push_out(Vector3(clampf(q.x, r.position.x + Player.BODY_R, r.end.x - Player.BODY_R), 0,
			clampf(q.z, r.position.y + Player.BODY_R, r.end.y - Player.BODY_R)), Player.BODY_R, Player.BODY_H)
		var plain := p + vel * dt
		var to2 := Vector2(q.x, q.z)
		if to2.distance_squared_to(plain) > 1e-10:
			if dt > 0.0:
				vel = (to2 - p) / dt
			p = to2
		else:
			p = plain   # (nothing in her way: her step exactly as meant)
	else:
		p += vel * dt
	position = Vector3(p.x, 0, p.y)
	var d := ball - p
	if d.length() > 0.1:
		facing = rotate_toward(facing, atan2(d.x, d.y), 6.0 * dt)
	rotation.y = facing
	# Her body: facing the play standing or edging along her line; jogging or running, the way she goes, her head and
	# chest turned to the ball. Her feet step with the floor (Gait), her arms swing bent as she runs.
	var v := vel.length()
	var face := facing
	if v > 0.4 and sig == "":
		face = lerp_angle(facing, atan2(vel.x, vel.y), smoothstep(1.8, 3.0, v))
	body_yaw = rotate_toward(body_yaw, face, 8.0 * dt)
	body.rotation.y = angle_difference(facing, body_yaw)
	var want_pose: Dictionary
	if sig != "":
		sig_t += dt
		want_pose = Poses.umpire_signal(sig, sig_t, sig_side)
		if sig_t > 1.6:
			sig = ""
	else:
		_idle_t += dt
		want_pose = Poses.idle(_idle_t, 0.0, _var)
	_pose = Poses.blend(_pose, want_pose, 1.0 - exp(-12.0 * dt))
	# (A signal's arm comes up as she pulls up, not while she is still running.)
	_arms_w = lerpf(_arms_w, 1.0 - smoothstep(1.4, 2.6, v) if sig != "" else 1.0 - smoothstep(0.8, 1.8, v), 1.0 - exp(-12.0 * dt))
	gait.update(dt, p, vel, body_yaw)
	var body_w := maxf(1.0 - gait.move, _arms_w * 0.6)
	var out := Gait.lay(gait.loco_pose(), _pose, _arms_w, body_w, angle_difference(body_yaw, facing))
	out.hips_x = float(_pose.get("hips_x", 0.0)) * (1.0 - gait.move)
	body.apply(gait.solve(out))
	_still_t = _still_t + dt if v < 0.08 and want.length() < 0.08 and gait.feet[0].down and gait.feet[1].down and not gait.striding else 0.0
	if link:
		link.update(dt, vel, want, body_yaw, "signal" if sig != "" else "")


## Which of her the shared foundation takes from the game's (FoundationLink, as Player.anim_layer): on the move her
## whole body is the game's (her gait's planted feet; the capture's walk and jog slid), standing still the capture's
## idle, with her arms over it while she signals.
var _still_t := 0.0


func anim_layer() -> String:
	if _still_t < 0.3:
		return "full"
	return "upper" if sig != "" else "move"
