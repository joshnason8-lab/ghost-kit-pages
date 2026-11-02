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
	_pose = Poses.ready(0.6)
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
	if fenced and Rules.offside(pos, next, dir) and not Rules.offside(pos, p, dir):
		# At the line: she stops on her side of it.
		next = Rules.onside_point(pos, next, dir, 0.02)
		vel = (next - p) / maxf(dt, 0.001)
	if land_clip != "":
		land_d += (next - p).length() / _scale()
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
	_body_yaw(dt)
	_animate(dt)
	if link:
		_pose_link(dt)


## The foundation's body: posed on her frames only (pose_every, set by the match by her distance from the camera;
## every frame while she has the ball or it is coming to her), carried along between them (its modifiers run when
## it is posed: WsgBody.set_manual).
func _pose_link(dt: float) -> void:
	_link_dt += dt
	_lod_skip += 1
	var ball := game_hand_point() if has_ball() else Vector3.INF
	if _lod_skip >= pose_every or ball != Vector3.INF:
		_lod_skip = 0
		link.update(minf(_link_dt, 0.1), vel, want_vel, facing, act, ball)
		_link_dt = 0.0
	else:
		link.follow()


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
	var spd := vel.length()
	var k := 1.0 - exp(-14.0 * dt)
	_pose = Poses.blend(_pose, _act_pose(), k)
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
	if act in ["shoot", "leap"]:
		out.hips_y = float(_pose.get("hips_y", 0.0))
	var feet_w := legs_w * (1.0 - land_w)
	out = gait.solve(out, feet_w)
	if land_w > 0.01:
		out = _with_landing(out)
	body.apply(out)
	if feet_w < 0.5:
		gait.follow_body()


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
		"out_of_play":
			return Poses.blend(Poses.ready(0.2), Poses.out_of_play(), 1.0)
		"cheer":
			return Poses.cheer(act_t)
		"post":
			return Poses.post(act_kind)
		"huddle":
			return Poses.huddle()
		"mark":
			return Poses.mark(1.0 if int(act_t * 0.7) % 2 == 0 else -1.0)
	return Poses.ready(0.9)


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


## Which of her body the shared foundation takes from the game's (FoundationLink): "full" (the game's whole pose: a
## move made standing, the ball in her hands, the leap), "upper" (the game's arms over the motion capture's legs) or
## "move" (the capture's all). On the run a move keeps only what its arms do, and marking's and posting's arms go
## with the run (they are for standing).
func anim_layer() -> String:
	if has_ball() or act in ["leap", "shoot", "hold", "pass"]:
		return "full"
	var spd := vel.length()
	if act in ["catch", "cheer", "defend", "defend_shot", "huddle", "out_of_play"] and spd < 0.6:
		return "full"
	return "upper" if arms_w > 0.5 else "move"


## Where her body faces (drawn): where she faces (the ball, mostly) standing and edging, side-stepping or backing off;
## running at a jog or faster, the way she runs, her head and chest turned to the ball (Gait.lay), unless her arms
## are busy with the ball (a catch on the run).
func _body_yaw(dt: float) -> void:
	var spd := vel.length()
	var want := facing
	if spd > 0.4:
		var w := smoothstep(2.6, 4.0, spd) * (1.0 - arms_w)
		want = lerp_angle(facing, atan2(vel.x, vel.y), w)
	body_yaw = rotate_toward(body_yaw, want, TURN * dt)
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


## Where her hands hold the ball, in the world: the drawn hands' (the foundation's) when it draws her holding it.
func hand_point() -> Vector3:
	if link and link.holding and link.ball_at != Vector3.INF:
		return link.ball_at
	return game_hand_point()


## Where the game's own body has her hands round the ball (the midpoint of its hands, a little under them).
func game_hand_point() -> Vector3:
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
