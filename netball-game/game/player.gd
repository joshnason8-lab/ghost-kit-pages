class_name Player
extends Node3D
## One player on the court: her squad entry (data), her position, the body that draws her, and her movement. Her
## position is written in one place only, advance(), once a frame by the match: the AI and the controls set where she
## wants to go (target) and how fast (want_speed), never her position. She accelerates and turns at a person's rate,
## so nothing snaps from one frame to the next; her feet step with the floor (Gait: the stride goes on by the distance
## she covers). tests/test_runner checks both ("_motion", "_gait_steps").

const ACCEL := 9.0           # m/s² speeding up
const DECEL := 12.0          # m/s² stopping (a landing on the catch takes about one step)
const TURN := 9.0            # rad/s
const TOP := 7.2             # m/s, a sprint at speed 99
const LAND_DECEL := 40.0     # m/s² at most, landing with the ball: the landing's own pace (it takes about a step)
const LAND_MIN := 1.5        # m/s: caught slower than this, she simply stops (no landing)
const BODY_R := 0.25         # m: her body, as the props keep her out of them (WsgSolidProps)
const BODY_H := 1.8
const SPOT_R := BODY_R + 0.08  # a spot she heads for keeps this clear of the props (she reaches it without scraping one)
const LOOSE_REACH := 0.75    # m: a loose ball within her hands' reach, from her middle (Match._run_loose)
const LEAP_UP := 0.45        # m: how much higher her hands go at the top of a leap (reach, hands_top)
const EASY_REACH := 0.85     # of her arm's length: a loose ball she meets over her hands, within it (meets)
const LEAP_S := 0.7          # s: a leap, take-off to landing (Poses.leap: the top 0.35 s in)

var match_ref = null         # the Match
var team := 0
var pos := "C"               # her position (bib) now
var data := {}               # her squad entry (DB.squad)
var dir := 1                 # the end her team attacks this quarter
var body: ToonBody
var link: FoundationLink      # the shared foundation drawing her (Medium and High, with the licensed clips), else null
var pose_every := 1           # the foundation's body posed every frame, or every 2nd or 3rd (far from the camera)
var _lod_skip := 0            # frames since it was posed (each player starts at her own count: not all on one frame)
var _link_dt := 0.0
var want_vel := Vector2.ZERO  # the velocity she is steering to this frame (the foundation's starts, cuts and stops)

var p := Vector2.ZERO        # where she is on the court (x along, y across), metres
var vel := Vector2.ZERO
var facing := 0.0            # yaw, radians: 0 faces +z
var target := Vector2.ZERO
var want_speed := 0.0        # m/s she wants to go toward target
var look_at_p := Vector2.ZERO
var look_on := false         # face look_at_p (the ball) rather than where she runs

var act := "ready"           # what her body does: ready, run, hold, pass, catch, shoot, defend, defend_shot, mark,
                             # leap, out_of_play, cheer, post (a shooter holding by the post), huddle (a break)
var act_t := 0.0
var act_kind := ""           # the pass's kind, for "pass"
var act_up := 0.0            # where the ball is met, for "catch" (-1 low .. 1 high)
var landing := Vector2.ZERO  # her landing foot while she holds the ball
var stopped := false         # holding the ball: she may not run (footwork), only pivot
var reaction := 0.0          # seconds before she reacts to a new read (the AI's)
var lead_t := 0.0            # the AI: time left on her current lead or hold
var lead_to := Vector2.ZERO
var moves := 0               # tests: how many times this frame her position was written (must be 1)
var gait: Gait               # her feet, legs and arms on the move (the one place her locomotion is made)
var body_yaw := 0.0          # where her body faces as drawn (Player._body_yaw); facing stays the game's
var arms_w := 0.0            # how much of her arms her move has (0: the run's swing), eased
var legs_w := 1.0            # how much of her legs the gait has (0: the move's own, the leap), eased
## Through her stride pair (0-1), by the distance she has covered (Gait).
var stride_phase: float:
	get:
		return gait.phase if gait else 0.0
var out_until := 0.0         # standing out of play beside the thrower of a penalty pass
var keep_out := Vector3.ZERO # a ring she does not step into (x, y its middle, z its radius; 0: none): 0.9 m and more
                             # off the landing foot of an opponent with the ball (TeamAI.keep_clear)
var suspended := 0.0         # seconds of playing time left on a suspension (R18): off the court, by the bench
var warned := false          # the umpire has warned her (R18)
var suspensions := 0         # how many times she has been suspended
var ordered_off := false     # ordered off: no further part (a replacement may come on after four minutes)
var pens := 0                # penalties since her last sanction
var was_offside := false     # offside last frame (an offside is called when she steps in, not while she walks out)
var fenced := true           # she keeps to her areas (the AI always; you with Keep me onside): she pulls up at a line
                             # rather than running over it
var land_clip := ""          # the landing (motion capture) she is in: land_l or land_r (her landing foot), or ""
var land_d := 0.0            # how far along the clip's path she is (m of the clip)
var land_w := 0.0            # how much of her legs and body it has
var land_dir := Vector2.ZERO # the way she was going as she caught it
var land_t := 0.0            # seconds since she caught it
var land_t0 := 0.0           # the clip's time she came in at
var _pose := {}
var _airborne := 0.0
var _ready_hands := 0.0       # her hands up to take a pass (0 hanging relaxed .. 1 up), eased
var _idle_t := 0.0            # seconds she has been about (her breathing, her weight shifting: never restarting)
var _var := Vector4(0.5, 0.5, 0.5, 0.5)   # her own way of standing (each 0-1: Poses.idle), from her name
var _ball_c := Vector3.INF    # the ball's centre between her palms this frame (world), while she holds it
var _solid_memo := {}         # her side round a prop in her way (WsgSolidProps.move)
var bounds := Rect2()         # the ground she keeps to in play (no area: none): your player, the run-off round the court
var held_off := Vector2.ZERO  # how far a prop held the ball she holds off her hands (Ball.step): she gives way by it
var _way := PackedVector3Array()   # an out-of-play walk's waypoints round the props (WsgSolidProps.path)
var _way_to := Vector2.INF
var _rounding := false       # her way to her target goes round a goal circle she may not enter (_goal)
## Set to shoot and still turning to the post (pivoting on her landing foot): the shot waits (act_t held at 0, and
## Match._run_shot's clock) until her body faces the post within SQUARE_DEG, or SQUARE_MAX seconds have gone.
var squaring := false
var _square_t := 0.0
const SQUARE_DEG := 8.0
const SQUARE_MAX := 0.6
var _arm_travel := [0.0, 0.0]  # how far each upper arm is from her move's still (0 there .. 1 a long way: Player._animate)


func _init(p_team: int, p_data: Dictionary, p_pos: String) -> void:
	team = p_team
	data = p_data
	pos = p_pos


func _ready() -> void:
	var t := DB.team(String(data.team))
	var c1: Color = t.get("c1", Color.WHITE)
	var c2: Color = t.get("c2", Color.BLACK)
	body = HeroBody.new({"skin": Color(String(data.skin)), "dress": c1, "trim": c2, "bib": DB.bib_colour(String(data.team)),
		"shoe": Color("f3f1ee"), "hair": Color("15100c") if int(data.hair) != 2 else Color("2a1d14"),
		"hair_style": int(data.hair), "height": float(data.height), "pos": pos})
	add_child(body)
	var hv := hash(String(data.get("id", data.get("name", pos))))
	_var = Vector4(float(hv & 255) / 255.0, float((hv >> 8) & 255) / 255.0, float((hv >> 16) & 255) / 255.0, float((hv >> 24) & 255) / 255.0)
	_idle_t = _var.z * 10.0
	_pose = Poses.idle(_idle_t, 0.0, _var)
	body.apply(_pose)
	gait = Gait.new(body)
	body_yaw = facing
	# Drawn with the shared foundation (the owner's model on the shared rig, motion-capture locomotion) on Medium and
	# High when this build has the licensed library (FoundationLink); the game's own body stays, posed and measured,
	# unseen. (Again after a substitution: a new body, a new link.)
	if link and is_instance_valid(link):
		link.queue_free()
	link = null
	if FoundationLink.enabled():
		link = FoundationLink.new(self, body)
		add_child(link)
		_lod_skip = (Rules.POSITIONS.find(pos) + team * 4) % 3


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
	body_yaw = facing
	if body:
		body.rotation.y = 0.0
	if gait:
		gait.reset(at, face_dir)


## The one place her position changes, once a frame.
func advance(dt: float) -> void:
	moves += 1
	var solid := _solid()
	# Where she heads: her target (moved out of a prop it is in), or the next corner of an out-of-play walk round them.
	var goal := _goal(solid)
	var to := goal - p
	var dist := to.length() + (goal.distance_to(target) if goal != target and (not _way.is_empty() or _rounding) else 0.0)
	var cap := minf(want_speed, speed_cap())
	if stopped:
		cap = 0.0
	# The speed she wants: slowing as she arrives, so she stops on the spot rather than past it.
	var desired := Vector2.ZERO
	if dist > 0.05 and cap > 0.0 and to.length() > 0.001:
		var arrive := sqrt(2.0 * DECEL * 0.8 * dist)
		desired = to / to.length() * minf(cap, arrive)
	# Pulling up at a line she may not cross: no faster than she can stop before it. (Over one already, after an AI
	# slip offside (TeamAI._slips) or put there, nothing holds her in: she steps back out.)
	if fenced and desired.length() > 0.1 and not Rules.offside(pos, p, dir):
		var room := _room_along(desired.normalized())
		if room < 3.0:
			desired = desired.limit_length(sqrt(2.0 * DECEL * 0.85 * maxf(0.0, room - 0.12)))
	var bounded: bool = bounds.has_area() and not away() and match_ref != null and match_ref.phase != "break"
	if bounded:
		# Pulling up at the edge of her ground (the run-off's): no faster toward it than she can stop before it.
		var lo := p - bounds.position
		var hi := bounds.end - p
		desired.x = clampf(desired.x, -_pull_up(lo.x), _pull_up(hi.x))
		desired.y = clampf(desired.y, -_pull_up(lo.y), _pull_up(hi.y))
	want_vel = desired
	var rate := ACCEL if desired.length() > vel.length() else DECEL
	if stopped and land_clip != "":
		# Landing with the ball: she stops as the landing does (motion capture), at its pace, never faster than she
		# was going, so the landing foot stays where it came down.
		desired = land_dir * minf(HeroBody.mocap_speed(land_clip, land_d) * _scale(), vel.length())
		rate = LAND_DECEL
	var dv := desired - vel
	var step := rate * dt
	vel = vel + dv.limit_length(step)
	var next := p + vel * dt
	var solid_moved := false     # the props turned or stopped her step (else it stands exactly as she meant it)
	if solid:
		# Her step among the venue's props (WsgSolidProps.move: steered round what is in her way, never into it).
		var m := solid.move(Vector3(p.x, 0, p.y), Vector3(vel.x, 0, vel.y), dt, BODY_R, BODY_H, Vector3(goal.x, 0, goal.y), _solid_memo)
		var q := Vector2(m[0].x, m[0].z)
		if q.distance_squared_to(next) > 1e-10:
			next = q
			solid_moved = true
	if keep_out.z > 0.0:
		# Not a step nearer the player with the ball once inside 0.9 m and a little of her (obstruction): round her.
		var kc := Vector2(keep_out.x, keep_out.y)
		var nd := next.distance_to(kc)
		var floor_d := minf(keep_out.z, p.distance_to(kc))
		if nd < floor_d and nd > 0.001:
			# (Never a longer step than the one she was taking.)
			next = p + (kc + (next - kc) / nd * floor_d - p).limit_length((next - p).length())
			vel = (next - p) / maxf(dt, 0.001)
	if bounded and not bounds.has_point(next):
		next = next.clamp(bounds.position, bounds.end)
		vel = (next - p) / maxf(dt, 0.001)
	if fenced and Rules.offside(pos, next, dir) and not Rules.offside(pos, p, dir):
		# At the line: she stops on her side of it.
		next = Rules.onside_point(pos, next, dir, 0.02)
		vel = (next - p) / maxf(dt, 0.001)
	if solid:
		# The ball in her hands met a prop (Ball.step held it off them): she gives way, a step back from it.
		var kept := next + held_off.limit_length(0.15)
		held_off = Vector2.ZERO
		# On the venue's floor (inside its boards, walls or fences), and out of every prop whatever moved her.
		kept = _keep_clear(solid, kept)
		if kept.distance_squared_to(next) > 1e-10:
			next = kept
			solid_moved = true
		if solid_moved and dt > 0.0:
			vel = (next - p) / dt   # the velocity she really moved at (her gait steps with it)
	if land_clip != "":
		land_d += (next - p).length() / _scale()
	p = next
	position = Vector3(p.x, 0, p.y)
	# Facing: what her move aims at (the post she shoots at, the team-mate she passes to), else the ball (or a look
	# target) when set, else where she runs.
	var want_face := facing
	var aim := _aim_at()
	if aim != Vector2.INF:
		var d := aim - p
		if d.length() > 0.05:
			want_face = atan2(d.x, d.y)
	elif look_on:
		var d := look_at_p - p
		if d.length() > 0.05:
			want_face = atan2(d.x, d.y)
	elif vel.length() > 0.4:
		want_face = atan2(vel.x, vel.y)
	facing = rotate_toward(facing, want_face, (TURN * 1.6 if act == "shoot" else TURN) * dt)
	rotation.y = facing
	_body_yaw(dt)
	_animate(dt)
	_update_cap_legs(dt)
	if link:
		_pose_link(dt)


## The fastest she may go toward an edge `room` metres off and still stop before it.
static func _pull_up(room: float) -> float:
	return sqrt(2.0 * DECEL * 0.85 * maxf(0.0, room - 0.05))


## The venue's solid props (Arena.solid), or null (a body without a match: the tests' views).
func _solid() -> WsgSolidProps:
	if match_ref == null or match_ref.arena == null:
		return null
	return match_ref.arena.solid


## Where she heads this frame: her target, or the nearest spot clear of the props to it; on an out-of-play walk (to
## and from the bench, to a break's huddle) the next corner of her way round the props (WsgSolidProps.path).
func _goal(solid: WsgSolidProps) -> Vector2:
	_rounding = false
	if solid == null:
		return target
	var g := target
	var g3 := Vector3(g.x, 0, g.y)
	if float(solid.penetration(g3, SPOT_R, BODY_H)[0]) > 0.0:
		g3 = solid.free_spot(g3, SPOT_R, BODY_H)
		g = Vector2(g3.x, g3.z)
	if not (away() or match_ref.phase == "break"):
		_way = PackedVector3Array()
		_way_to = Vector2.INF
		# Round a goal circle she may not enter, not into its line and stopped there (Match.round_circles).
		var r := Match.round_circles(pos, dir, p, g) if fenced else g
		_rounding = r != g
		return r
	if _way_to.distance_to(g) > 0.25:
		_way = solid.path(Vector3(p.x, 0, p.y), g3, BODY_R, BODY_H)
		_way_to = g
	while _way.size() > 1 and Vector2(_way[0].x, _way[0].z).distance_to(p) < 0.4:
		_way.remove_at(0)
	return Vector2(_way[0].x, _way[0].z) if not _way.is_empty() else g


## A step's end kept on the venue's floor (Arena.floor_rect: the user's player with Keep me onside off has no line to
## pull up at) and out of every prop.
func _keep_clear(solid: WsgSolidProps, at: Vector2) -> Vector2:
	var r: Rect2 = match_ref.arena.floor_rect
	at = Vector2(clampf(at.x, r.position.x + BODY_R, r.end.x - BODY_R), clampf(at.y, r.position.y + BODY_R, r.end.y - BODY_R))
	var q := solid.push_out(Vector3(at.x, 0, at.y), BODY_R, BODY_H)
	return Vector2(q.x, q.z)


## The foundation's body: posed on her frames only (pose_every, set by the match by her distance from the camera;
## every frame while she has the ball or it is coming to her) with the game seconds since it was last posed (all of
## them: cut short, the capture fell behind the ground she covered), and between them carried along with its
## planted feet held (FoundationLink.follow).
func _pose_link(dt: float) -> void:
	_link_dt += dt
	_lod_skip += 1
	var ball := game_hand_point() if has_ball() else Vector3.INF
	if _lod_skip >= pose_every or ball != Vector3.INF:
		_lod_skip = 0
		link.update(minf(_link_dt, 0.25), vel, want_vel, body_yaw, act, ball, dt)
		_link_dt = 0.0
	else:
		link.follow(dt)


## Where her move has her face (court x, z), or INF: the post from the moment she sets to shoot, and while she holds
## the ball in her circle in range of it (a shooter squares up to the post before the shot: the AI's shooters shoot
## from there, Match.shoot), unless you have the ball and aim elsewhere; the team-mate she passes to as she passes.
## (The owner: "a player shooting, the woman facing the wrong direction and not at the hoop": the shot kept the look
## at her last passing option, set while she held it.)
func _aim_at() -> Vector2:
	if act == "shoot":
		return Court.goal_post(dir)
	if act == "pass" and act_t < 0.45 and match_ref and match_ref.pass_info.get("from") == self and match_ref.pass_info.get("to"):
		return (match_ref.pass_info.to as Player).p
	if has_ball() and pos in ["GS", "GA"] and match_ref.me != self and in_range():
		return Court.goal_post(dir)
	return Vector2.INF


## In her circle, in range of the post (as the AI shoots: Match's TeamAI._holder), free to shoot.
func in_range() -> bool:
	if match_ref == null or not Rules.may_shoot(pos, landing, dir, bool(match_ref.from_free)):
		return false
	return landing.distance_to(Court.goal_post(dir)) < (3.6 if pos == "GS" else 4.5)


## She has the ball in her hands.
func has_ball() -> bool:
	return match_ref != null and match_ref.ball != null and match_ref.ball.holder == self and match_ref.ball.state == "held"


## How far she can run in direction d before a line her position may not cross (up to 3 m).
func _room_along(d: Vector2) -> float:
	var s := 0.25
	while s <= 3.0:
		if Rules.offside(pos, p + d * s, dir):
			return s - 0.25
		s += 0.25
	return 3.0


## Her body's pose this frame: her locomotion (Gait: the feet stepping with the floor, the arms swinging bent), with
## what she is doing laid over it (Poses: the catch, the pass, holding the ball, defending, the leap); nothing jumps.
func _animate(dt: float) -> void:
	act_t += dt
	if squaring:
		# (The owner: "a player shooting ... facing the wrong direction and not at the hoop": a shooter who caught
		# facing away, 1 m out from the post, shot 140 degrees off it. The shot starts once she has turned.)
		_square_t += dt
		if post_off() <= deg_to_rad(SQUARE_DEG) or _square_t >= SQUARE_MAX or act != "shoot":
			squaring = false
		else:
			act_t = 0.0
	var spd := vel.length()
	var k := 1.0 - exp(-14.0 * dt)
	_idle_t += dt
	_ready_hands = move_toward(_ready_hands, 1.0 if _wants_pass() else 0.0, dt / 0.35)
	var want := _act_pose()
	_pose = Poses.blend(_pose, want, k)
	# How far each upper arm still has to go to her move's (one move to the next: marking's or the ready hands' to
	# arms up over the ball): its elbow is bent the more on the way (see the lay below).
	for i in 2:
		var b: String = ["upperarm_l", "upperarm_r"][i]
		var d := HeroBody.turn(_pose.get(b, Vector3.ZERO)).angle_to(HeroBody.turn(want.get(b, Vector3.ZERO)))
		_arm_travel[i] = smoothstep(deg_to_rad(6.0), deg_to_rad(40.0), d)
	# How much of her arms (and, standing, her lean and crouch) are the move's: the move's own, a catch, a pass, the
	# ball held, the shot, the leap; on the run her arms swing with her legs, whatever she means to do when she stops.
	var aw := _arms_want(spd)
	arms_w = lerpf(arms_w, aw, 1.0 - exp(-(16.0 if aw < arms_w else 12.0) * dt))
	legs_w = lerpf(legs_w, 0.0 if act == "leap" else 1.0, 1.0 - exp(-(20.0 if act == "leap" else 10.0) * dt))
	# The landing with the ball: her legs and body from the motion capture while she holds it where she came down.
	if land_clip != "":
		land_t += dt
		var keep := stopped and act in ["hold", "catch"]
		land_w = lerpf(land_w, 1.0 if keep else 0.0, 1.0 - exp(-(30.0 if keep else 6.0) * dt))
		if not keep and land_w < 0.02:
			land_clip = ""
			land_w = 0.0
	if body == null:
		return
	gait.width = 0.07 if act in ["mark", "post", "defend", "defend_shot"] else 0.0
	gait.pinned = landing if stopped else Vector2.INF
	gait.update(dt, p, vel, body_yaw)
	var body_w := maxf(1.0 - gait.move, 1.0 if act in ["shoot", "leap"] else 0.0)
	var out := Gait.lay(gait.loco_pose(), _pose, arms_w, maxf(body_w, arms_w * 0.6), angle_difference(body_yaw, facing))
	# Her elbows bent the more while her arms go between the run's (or hanging) and her move's (arms rising over the
	# ball, out to take a pass, an arm into the lane): the two lerped at their angles straightened the elbow on the way,
	# arms held straight out to the sides as she closed in or moved off (the owner's "arms just stretched out").
	# And so while her arms go from one move's to the next's.
	var mid := 4.0 * arms_w * (1.0 - arms_w)
	for i in 2:
		var bend := 36.0 * maxf(mid, _arm_travel[i] * arms_w)
		if bend > 0.3:
			var s: String = ["forearm_l", "forearm_r"][i]
			out[s] = HeroBody.turn(out.get(s, Vector3.ZERO)) * HeroBody.turn(Vector3(-bend, 0, 0)) if out.get(s) is Quaternion \
				else (out.get(s, Vector3.ZERO) as Vector3) + Vector3(-bend, 0, 0)
	if act in ["shoot", "leap"]:
		out.hips_y = float(_pose.get("hips_y", 0.0))
	# (Her weight shifting from foot to foot standing: not on the run.)
	out.hips_x = float(_pose.get("hips_x", 0.0)) * body_w
	var feet_w := legs_w * (1.0 - land_w)
	out = gait.solve(out, feet_w)
	if land_w > 0.01:
		out = _with_landing(out)
	body.apply(out)
	if feet_w < 0.5:
		gait.follow_body()
	# The ball in her hands: her palms on it (after the pose, this frame, so the ball is drawn in them now).
	_ball_c = Vector3.INF
	if has_ball():
		_hands_on_ball()


## The pose of what she is doing (degrees), standing: Poses' moves; ready to take a pass when she is only running.
func _act_pose() -> Dictionary:
	match act:
		"hold":
			return Poses.hold()
		"pass":
			return Poses.pass_(act_kind, clampf(act_t / 0.45, 0.0, 1.0))
		"catch":
			return Poses.catch_(clampf(act_t / 0.2, 0.0, 1.0), act_up)
		"shoot":
			return Poses.shoot(clampf(act_t / 0.9, 0.0, 1.0))
		"defend":
			return Poses.defend_ball(1.0)
		"defend_shot":
			return Poses.defend_ball(1.0, true)
		"leap":
			return Poses.leap(clampf(act_t / 0.7, 0.0, 1.0))
		"cheer":
			return Poses.cheer(act_t)
		"post":
			return Poses.post(act_kind, _pulse(2.4, 0.6))
		"huddle":
			return Poses.huddle()
		"mark":
			# Low and side-on, arms loose; now and then an arm out into the passing lane (her own rhythm).
			return Poses.mark(1.0 if int((_idle_t + _var.x * 7.0) / 3.1) % 2 == 0 else -1.0, _pulse(3.1, 0.3), _var)
		"out_of_play":
			return Poses.idle(_idle_t, 0.0, _var, true)
	# Standing in play, or on her way (the run's arms are Gait's): at ease, her hands up in front of her only while
	# she is the one the ball may come to.
	return Poses.idle(_idle_t, _ready_hands, _var)


## A beat of her own: 1 for share of every period seconds (eased in and out), else 0.
func _pulse(period: float, share: float) -> float:
	var u := fposmod(_idle_t + _var.y * period, period) / period
	return smoothstep(0.0, 0.08, u) * (1.0 - smoothstep(share - 0.08, share, u)) if u < share else 0.0


## She is the one the holder is looking to pass to (or a pass is on its way to her): her hands come up to take it.
func _wants_pass() -> bool:
	if match_ref == null or act != "ready" and act != "run":
		return false
	var h: Player = match_ref.holder
	if h == null or h == self or h.team != team or match_ref.phase != "live":
		return false
	return h.look_at_p.distance_to(p) < 1.2 and h.p.distance_to(p) < 16.0


## How much of her arms the move has at speed spd: a catch, a pass, the ball, the shot and the leap all of them; arms
## up over the ball (defending) while she closes in at a walk; the celebration's fists at a jog; the ready hands,
## marking's arm out and posting's call for the ball only standing or edging (and on her way somewhere, walking, her
## arms hang and swing). Running, her arms are the run's.
func _arms_want(spd: float) -> float:
	match act:
		"catch", "pass", "hold", "shoot", "leap":
			return 1.0
		"defend", "defend_shot":
			return 1.0 - smoothstep(1.2, 2.2, spd)
		"cheer":
			return 1.0 - smoothstep(2.0, 3.0, spd)
		"run", "huddle", "out_of_play":
			return 1.0 - smoothstep(0.3, 1.0, spd)
	return 1.0 - smoothstep(0.8, 1.8, spd)


## Which of her body the shared foundation takes from the game's (FoundationLink): "full" (the game's whole pose:
## its legs, hips and facing as well as its arms), "upper" (the game's arms over the motion capture's legs) or "move"
## (the capture's all). The capture draws her only standing still (its idle: breathing, weight shifting, the odd
## fidget, her feet planted): on the move her legs are always the game's (Gait: each foot planted where it comes down,
## forwards, sideways, backwards, at any pace), as are her moves. The capture's own run slid its feet: 26 cm a step
## walking, 10-13 cm from 5 m/s, its sprint's stride (2.6 m a cycle) short of a sprint's (3.6 m), a side-step 10 cm,
## its starts and cuts up to 2 m in a match (tests/test_runner _foundation_steps): the owner's "players floating
## around and not moving legs".
func anim_layer() -> String:
	if not _cap_legs:
		return "full"
	if has_ball() or act in ["leap", "shoot", "hold", "pass", "catch", "cheer", "defend", "defend_shot", "huddle", "out_of_play"]:
		return "full"
	return "upper" if arms_w > 0.5 and _arms_up() else "move"


## Her arms are doing something of their own standing (hands up to take a pass, an arm out marking or posting), not
## hanging at rest: the capture's idle has them otherwise.
func _arms_up() -> bool:
	return act in ["mark", "post"] or _ready_hands > 0.3


## Whether the capture has her legs this frame (anim_layer): she has stood still a moment (her feet down under her);
## she goes back to the game's legs the moment she moves off, before the capture would start a step of its own.
var _cap_legs := true
var _still_t := 0.0


func _update_cap_legs(dt: float) -> void:
	var spd := vel.length()
	var still := spd < 0.08 and want_vel.length() < 0.08 and legs_w > 0.99 and land_w <= 0.0
	if still and gait and not gait.striding and gait.feet[0].down and gait.feet[1].down:
		_still_t += dt
	else:
		_still_t = 0.0
	if _cap_legs:
		_cap_legs = spd < 0.25 and want_vel.length() < 0.3 and legs_w > 0.99 and land_w <= 0.0
	else:
		_cap_legs = _still_t > 0.3


## Where her body faces (drawn): where she faces (the ball, mostly) standing and edging, side-stepping or backing off;
## running at a jog or faster, the way she runs, her head and chest turned to the ball (Gait.lay), unless her arms
## are busy with the ball (a catch on the run).
func _body_yaw(dt: float) -> void:
	var spd := vel.length()
	var want := facing
	if spd > 0.4:
		var w := smoothstep(2.6, 4.0, spd) * (1.0 - arms_w)
		want = lerp_angle(facing, atan2(vel.x, vel.y), w)
	# (Turning to shoot: a pivot, as quick as her facing turns.)
	body_yaw = rotate_toward(body_yaw, want, (TURN * 1.6 if act == "shoot" else TURN) * dt)
	if body:
		body.rotation.y = angle_difference(facing, body_yaw)


## The landing laid over pose p (her legs and body; her arms, on the ball, stay p's), at the point of the clip
## that matches how far she has come since the catch.
func _with_landing(p: Dictionary) -> Dictionary:
	var t := maxf(HeroBody.mocap_time_at(land_clip, land_d), land_t0 + land_t - 0.15)
	var c := HeroBody.mocap_pose(land_clip, t)
	var out := p.duplicate()
	for i in ToonBody.BONES.size():
		var n: String = ToonBody.BONES[i][0]
		if n in _MOCAP_BONES:
			out[n] = HeroBody.turn(p.get(n, Vector3.ZERO)).slerp(c[0][i], land_w)
	var sh: Vector3 = c[1]
	out.hips_y = lerpf(float(p.get("hips_y", 0.0)), sh.y, land_w)
	out.hips_x = lerpf(float(p.get("hips_x", 0.0)), sh.x, land_w)
	out.hips_fwd = lerpf(float(p.get("hips_fwd", 0.0)), sh.z, land_w)
	return out


## The bones the motion capture moves under her own pose: not her neck and head, which keep watching the play.
const _MOCAP_BONES := ["hips", "spine", "chest", "thigh_l", "shin_l", "foot_l", "thigh_r", "shin_r", "foot_r"]


## Her body's size against the model's (the clips' metres are the model's).
func _scale() -> float:
	return body.scale.x if body else 1.0


## She has caught the ball on the move and lands on foot ("l", "r"; "both" when she was all but stopped): the
## landing from the motion capture, picked up at the moment of its stride that matches her speed.
func start_landing(foot: String) -> void:
	land_clip = ""
	var spd := vel.length()
	if foot == "both" or spd < LAND_MIN or not (body is HeroBody):
		return
	land_clip = "land_" + foot
	land_dir = vel / spd
	land_d = HeroBody.mocap_travel_at_speed(land_clip, spd / _scale())
	land_t = 0.0
	land_t0 = HeroBody.mocap_time_at(land_clip, land_d)
	# Where her landing foot comes down: ahead of her by what is left of the clip's path to that moment.
	var at := HeroBody.mocap_plant_at(land_clip, foot)   # the foot against the clip's path then (her left, ahead)
	var left := Vector2(land_dir.y, -land_dir.x)
	landing = p + (land_dir * (maxf(0.0, HeroBody.mocap_plant_travel(land_clip, foot) - land_d) + at.y) + left * at.x) * _scale()
	if fenced and Rules.offside(pos, landing, dir) and not Rules.offside(pos, p, dir):
		landing = Rules.onside_point(pos, landing, dir, 0.02)


func set_act(a: String, kind := "") -> void:
	if a == act and kind == act_kind:
		return
	act = a
	act_kind = kind
	act_t = 0.0
	squaring = a == "shoot"
	_square_t = 0.0


## How far (radians) her body as drawn (body_yaw) is turned from the post she shoots at.
func post_off() -> float:
	var d := Court.goal_post(dir) - p
	if d.length() < 0.05:
		return 0.0
	return absf(angle_difference(body_yaw, atan2(d.x, d.y)))


## Where her hands hold the ball, in the world: the drawn hands' (the foundation's) when it draws her holding it.
func hand_point() -> Vector3:
	if link and link.holding and link.ball_at != Vector3.INF:
		return link.ball_at
	return game_hand_point()


## Where the game's own body has the ball in its hands: the centre of the ball between her palms (_hands_on_ball, this
## frame), or, not holding it, between her palms as posed.
func game_hand_point() -> Vector3:
	if body == null or body.skeleton == null:
		return match_ref.ball.eased(position + Vector3(0, 1.3, 0)) if has_ball() else position + Vector3(0, 1.3, 0)
	if _ball_c != Vector3.INF:
		return _ball_c
	return (body.bone_world("hand_l") + body.bone_world("hand_r")) * 0.5 + Vector3(0, -0.06, 0)


## The middle of the palm against the wrist (the hand bone's own space: the owner's model's m, the fingers down -y
## from the wrist at rest, arms hanging, the left palm facing in, -x) and from there to the skin of the palm.
const PALM := Vector3(0.0, -0.075, 0.0)
const PALM_T := 0.016
## How far behind the ball's sides her palms go (rad): the hands spread on its sides and a little behind it.
const GRIP_BACK := 0.38
## The shot's set with the shooting hand under the ball (off: both hands on its sides, as held; the foundation's arms
## could not reach a hand turned under the ball overhead, its palm up to 15 cm off it).
const UNDER_GRIP := false


## Her hands on the ball, after her pose: the ball where her move has it (between her palms as posed, never in her
## chest), each palm on its side of it, a little behind (its skin on the ball: R + PALM_T from its centre), facing
## its centre, her fingers spread forward and up round it; the arm reaching there (two-bone IK, the elbow where the
## move bends it), never further out than her arms reach. Low draws the
## ball there (game_hand_point); the foundation's body puts its own hands there too (FoundationLink.holds). The owner:
## "their hands aren't holding the ball, it looks like the forearms are holding the ball" (the ball was put at the
## midpoint of the wrists, the hands themselves past it).
func _hands_on_ball() -> void:
	var sk := body.skeleton
	var ch := sk.get_bone_global_pose(body.bone("chest"))
	var left := ch.basis.x.normalized()
	var up := ch.basis.y.normalized()
	var fwd := ch.basis.z.normalized()
	var r := Ball.R / body.scale.x + PALM_T
	var pl := sk.get_bone_global_pose(body.bone("hand_l")) * PALM
	var pr := sk.get_bone_global_pose(body.bone("hand_r")) * PALM
	var c := (pl + pr) * 0.5
	# (The shot's grip comes in over its first moments: nothing jumps as she sets.)
	var shot := smoothstep(0.0, 0.3, act_t) if act == "shoot" else 0.0
	# In front of her chest's middle, as the move holds it: her hands either side of it.
	c -= left * (c - ch.origin).dot(left) * 0.85 * (1.0 - shot)
	var ahead := (c - ch.origin).dot(fwd)
	var need := Ball.R / body.scale.x + 0.21
	if ahead < need:
		c += fwd * (need - ahead)
	var grip := {}
	for s in ["l", "r"]:
		var sx := 1.0 if s == "l" else -1.0
		var n := (left * sx * cos(GRIP_BACK) - fwd * sin(GRIP_BACK)).normalized()   # the ball's centre to the palm
		var fingers := (fwd * 0.55 + up * 0.85)
		if s == "r" and shot > 0.0 and UNDER_GRIP:
			# The shooting hand under and behind the ball.
			n = n.slerp((-up * 0.8 - fwd * 0.45 - left * 0.15).normalized(), shot)
			fingers = fingers.lerp(fwd * 0.3 + up * 0.95 - left * 0.4, shot)
		fingers = (fingers - n * fingers.dot(n)).normalized()
		# The hand's axes: its palm (-x on the left hand, +x on the right) toward the ball, its fingers (-y) on round it.
		var x_ax := n * sx
		var y_ax := -fingers
		grip[s] = [n, Basis(x_ax, y_ax, x_ax.cross(y_ax)).orthonormalized()]
	# Never further than her arms reach: the ball comes in toward her shoulders until both hands are on it.
	var sh_l := sk.get_bone_global_pose(body.bone("upperarm_l")).origin
	var sh_r := sk.get_bone_global_pose(body.bone("upperarm_r")).origin
	for it in 4:
		var excess := 0.0
		for s in ["l", "r"]:
			var sh := sh_l if s == "l" else sh_r
			var g: Array = grip[s]
			var wrist: Vector3 = c + (g[0] as Vector3) * r - (g[1] as Basis) * PALM
			excess = maxf(excess, wrist.distance_to(sh) - _arm_len(s) * 0.97)
		if excess <= 0.0:
			break
		c += ((sh_l + sh_r) * 0.5 - c).normalized() * (excess + 0.005)
	# A loose ball she met: the ball, and her hands reaching for it, brought in from where she met it (Ball.hold; one
	# lower than she reaches, stooping, her hands go as far down to it as they reach).
	c = sk.global_transform.affine_inverse() * match_ref.ball.eased(sk.global_transform * c)
	for s in ["l", "r"]:
		var sx := 1.0 if s == "l" else -1.0
		var g: Array = grip[s]
		var hb: Basis = g[1]
		_arm_to(s, c + (g[0] as Vector3) * r - hb * PALM, hb, -up * 0.75 + left * sx * 0.55 - fwd * 0.2)
	_ball_c = sk.global_transform * c


## Her arm's length, shoulder to wrist (the model's m).
func _arm_len(s: String) -> float:
	var sk := body.skeleton
	return (sk.get_bone_rest(body.bone("forearm_" + s)).origin.length() + sk.get_bone_rest(body.bone("hand_" + s)).origin.length())


## Her arm (side "l" or "r") reaching for its wrist at wrist (skeleton space) with the hand turned to hand: the shoulder
## and elbow turned (two-bone IK), the elbow bending the way the move's does, eased toward bend (down and out: never
## up into her chest).
func _arm_to(s: String, wrist: Vector3, hand: Basis, bend: Vector3) -> void:
	var sk := body.skeleton
	var iu := body.bone("upperarm_" + s)
	var i_f := body.bone("forearm_" + s)
	var ih := body.bone("hand_" + s)
	var u := sk.get_bone_global_pose(iu)
	var f := sk.get_bone_global_pose(i_f)
	var h := sk.get_bone_global_pose(ih)
	var sh := u.origin
	var el := f.origin
	var a := sh.distance_to(el)
	var b := el.distance_to(h.origin)
	var to := wrist - sh
	var d := clampf(to.length(), absf(a - b) + 0.001, (a + b) * 0.999)
	var dir := to.normalized()
	var x := (a * a - b * b + d * d) / (2.0 * d)
	var hh := sqrt(maxf(0.0, a * a - x * x))
	var pole := (el - sh) - dir * dir.dot(el - sh)
	var want := bend - dir * dir.dot(bend)
	pole = (pole.normalized() + want.normalized() * 1.5) if pole.length() > 0.01 else want
	var e2 := sh + dir * x + pole.normalized() * hh
	var w2 := sh + dir * d
	var ub := Basis(Quaternion((el - sh).normalized(), (e2 - sh).normalized())) * u.basis
	var par := sk.get_bone_global_pose(sk.get_bone_parent(iu)).basis
	sk.set_bone_pose_rotation(iu, (par.inverse() * ub).get_rotation_quaternion())
	var f_now := ub * (u.basis.inverse() * f.basis)
	var fdir := (f_now * (f.basis.inverse() * (h.origin - el))).normalized()
	var fb := Basis(Quaternion(fdir, (w2 - e2).normalized())) * f_now
	# The forearm turned about its length with the hand (the wrist turns the forearm: it does not twist the hand off it).
	var ax := (f.basis.inverse() * (h.origin - el)).normalized()
	var q := (fb.inverse() * hand).get_rotation_quaternion()
	var tw := Quaternion.IDENTITY
	var pr := Vector3(q.x, q.y, q.z).dot(ax)
	if absf(pr) > 1e-5 or absf(q.w) > 1e-5:
		tw = Quaternion(ax.x * pr, ax.y * pr, ax.z * pr, q.w).normalized()
	fb = fb * Basis(tw)
	sk.set_bone_pose_rotation(i_f, (ub.inverse() * fb).get_rotation_quaternion())
	sk.set_bone_pose_rotation(ih, (fb.inverse() * hand).get_rotation_quaternion())


## The height she can reach for a ball, standing (and with a leap).
func reach(leap := false) -> float:
	var h := float(data.get("height", 1.75))
	return h * 1.28 + (LEAP_UP if leap else 0.0)


## Whether her hands meet a loose ball at pt (world) now: one lower than her hands she stoops to; one higher only
## within her arms' easy reach of her shoulders, as her body is posed (standing, or up in a leap: TeamAI._play),
## where both bodies' arms (hers and the foundation's) reach it. Without a body, her hands' model (hands_top).
func meets(pt: Vector3) -> bool:
	if pt.y >= hands_top():
		return false
	if not over_hands(pt):
		return true
	var k := body.skeleton.global_transform.basis.get_scale().x
	for s in ["l", "r"]:
		if body.bone_world("upperarm_" + s).distance_to(pt) > _arm_len(s) * k * EASY_REACH:
			return false
	return true


## A ball at pt is higher than her hands as posed: she reaches up to meet it.
func over_hands(pt: Vector3) -> bool:
	return body != null and body.skeleton != null and pt.y > game_hand_point().y


## The highest her hands can meet a ball now: her standing reach, and in a leap as high as it has her (Poses.leap).
func hands_top() -> float:
	if act == "leap":
		return reach() + LEAP_UP * sin(clampf(act_t / LEAP_S, 0.0, 1.0) * PI)
	return reach()


## Not available to play: out of play for a penalty, or suspended.
func away() -> bool:
	return out_until > 0.0 or suspended > 0.0


func tag() -> String:
	return pos


func surname() -> String:
	var n := String(data.get("name", ""))
	var i := n.find(" ")
	return n.substr(i + 1) if i > 0 else n
