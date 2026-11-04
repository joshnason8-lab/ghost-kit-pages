class_name Athlete
extends Node3D
## One player on (or beside) the mat: movement, ratings, current action, and the body.

var data: Dictionary
var team := 0
var slot := 0            # defensive slot index, left to right
var model: HumanModel
var on_mat := true
var vel := Vector3.ZERO
var facing := Vector3(0, 0, -1)
var lock_facing := false
var step_surface := ""   # what his feet sound on (Arena.step_surface), "" for none (the menus' match behind)
var _stride := 0.0       # m gone since his last footstep

# state: idle, ready, raid, touch, kick, backkick, dodge, dubki, jump, telegraph, dive, recover, rise, held, holding, fallen, walk, sit,
# celebrate
var state := "idle"
var st_t := 0.0
var st_len := 0.0
var wait := 0.0             # s at the start of the state before its move plays (gathering for a lion jump out of a
                            # hold; lying a moment, the leg torn from his hands, before getting up)
var cooldown := 0.0
var reach_t := 0.0          # a dive has landed and his arms are still out: seconds he can still grip
var hands_prev: Array = []  # a diving defender's hands last frame (world), for the contact check
var fall_kind := ""         # how a tackled raider goes down ("trip": caught by a leg; "takedown")
var hold_style := ""        # how he is holding the raider (Grapple: "ankle", "thigh", "waist", "block")
# A hold being worked (set by Grapple every frame): the held raider's balance going (0..1) and how hard he is
# being pulled back now (0..1) and by which leg (-1 left, 1 right); a holder's haul now (0..1).
var balance := 0.0
var tug := 0.0
var tug_side := 0.0
var haul := 0.0
var bear := 0.0             # a holder going down with the raider he takes down, 0..1 (Grapple)
# Held by the ankle (Grapple._footwork): which leg (-1 left, 1 right; 0 neither or both), how low he sinks on the
# free leg for the held one to reach back (hip height over his leg's length), how far into a hop on the free
# foot (0..1 in the air, 1..2 coming down onto it; -1 on the floor) and how high off the floor (m), and a pull
# through the held leg he did not expect (0..1). A holder: how hard the raider pulls against him (0..1).
var held_leg := 0.0
var stance := 0.95
var hop := -1.0
var hop_air := 0.0
var jolt := 0.0
var strain := 0.0
var touched := false
var hold_offset := Vector3.ZERO
var dive_dir := Vector3.ZERO
var dive_from := Vector3.ZERO      # his velocity as his dive began: he drives off from it (Match._dive_motion)
var dive_t := 0.0                  # s of his dive's motion so far, from the frame he went (Match._dive_motion)
var dive_launch := 4.0             # m/s his dive drives off to (Match._defender_tackle)
var push := Vector3.ZERO           # how fast he is being moved out of someone's way (Match._push_all) ...
var avoid := Vector3.ZERO          # ... or, steering himself, how he steers round them: added to where he means to go
var drove := false                 # he steered himself this frame (drive)
var drives := 0                    # times drive() moved him (tests/motion_probe counts frames with more than one: two owners)
var held_by := 0                   # raider: how many hold him now (Match), for how his body takes it
var walk_target := Vector3.ZERO
var evade_to := Vector3.INF       # where an evasion pulls up, a line in its way (Match._evade); INF: none
var energy := 1.0
var body_file := ""      # a body to wear instead of his own (Match: a featured body), set before setup
var _sweat := 0.0        # how wet his skin is (from his energy, see _process)
var _sweat_t := 0.0
var raids_made := 0
var is_user := false
var is_career := false
var chain_partner: Athlete = null   # team-mate whose hand this defender is holding
var chain_offset := Vector3.ZERO     # where to stand relative to that partner
var chain_dive := false              # this dive is part of a chain tackle
var shove_target: Athlete = null
var cards := 0                       # cards shown to him this match (green, then yellow)
var suspended := -1.0                # yellow card: match clock when he may return (-1: not suspended)
var suspended_half := 0
var sig_kind := 0                    # an official's signal, see HumanModel.SIGNALS
var cele_kind := 0                   # how he celebrates, see HumanModel.cele
var cele_partner: Athlete = null     # team-mate he is going to high-five
var moves := {}                      # raiding move ratings, see DB.moves
var dmoves := {}                     # defensive skill ratings, see DB.def_moves
var style := "ankle"                 # his default grip: ankle, thigh or waist hold
var tackle_kind := ""                # the tackle he is going in with right now
var kick_back := 0.0                 # back/side kick: how far behind the target is (0..1)
var kick_side := 0.0                 # ... and how far to the side (-1 left .. 1 right)
var kick_dir := Vector3.ZERO         # world direction of the kick

var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _ring_color := Color(0, 0, 0, 0)

# Ratings converted to physical numbers.
var max_speed := 4.6
var accel := 18.0
# What the body on screen does, kept apart from the gameplay values above it (vel, facing): the legs follow
# how fast he really moves over the floor, whatever moved him (his own running, a team-mate's hold, a
# shove, the spacing that keeps players apart), and the body turns toward facing no faster than a person
# can, quicker standing than at a sprint.
const TURN_STILL := 900.0    # deg/s, pivoting on the spot
const TURN_SPRINT := 420.0   # deg/s at 5 m/s
const READY_CROUCH := 0.85    # a defender's crouch, ready (and what getting up rises into)
const BRACE := 0.1            # how far a held raider crouches into his struggle, caught (and BRACE_LOSS more as his balance
const BRACE_LOSS := 0.15      # goes); his hips go back over it (HumanModel.HELD_HINGE)
var move_vel := Vector3.ZERO
var _vis_yaw := INF
var _last_pos := Vector3.INF
var reach := 1.0
var strength := 1.0
var tackle := 1.0
var agility := 1.0


func setup(p_data: Dictionary, p_team: int, kit: Color, trim: Color, barefoot: bool) -> void:
	data = p_data
	team = p_team
	var a: Dictionary = data.attrs
	max_speed = 4.1 + (float(a.speed) - 50.0) * 0.03
	accel = 14.0 + (float(a.agility) - 50.0) * 0.18
	reach = 0.95 + (float(a.reach) - 50.0) * 0.008
	strength = 1.0 + (float(a.strength) - 60.0) * 0.015
	tackle = 0.55 + (float(a.tackle) - 50.0) * 0.01
	agility = 1.0 + (float(a.agility) - 60.0) * 0.015
	moves = DB.moves(data)
	dmoves = DB.def_moves(data)
	style = DB.style(data)
	model = HumanModel.new()
	model.body_kind = "referee" if team == 2 else "player"
	model.body_seed = hash(String(data.get("id", data.get("name", ""))))
	model.body_file = String(data.get("body", "")) if body_file == "" else body_file
	model.setup(Color(DB.SKIN_TONES[int(data.skin)]), Color(DB.HAIR_COLORS[int(data.hair)]), kit, trim, int(data.number), float(data.height), float(data.build), barefoot)
	add_child(model)
	_make_ring()


func _make_ring() -> void:
	_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.52
	t.rings = 24
	t.ring_segments = 6
	_ring.mesh = t
	_ring.scale = Vector3(1, 0.04, 1)
	_ring.position.y = 0.02
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


func set_ring(c: Color) -> void:
	_ring_color = c
	_ring.visible = c.a > 0.0
	_ring_mat.albedo_color = c


func pid() -> String:
	return String(data.id)


func display_name() -> String:
	return String(data.name)


## His name as his tag shows it: an initial and the surname ("K. RAO").
func tag_name() -> String:
	var words := String(data.name).strip_edges().split(" ", false)
	if words.size() < 2:
		return String(data.name).to_upper()
	return ("%s. %s" % [words[0].substr(0, 1), words[words.size() - 1]]).to_upper()


## Where his tag goes: over his head as he is now, standing, diving or lying down.
func tag_point() -> Vector3:
	return model.anchor("head") + Vector3(0, 0.15, 0)


func is_raider_type() -> bool:
	return data.role != "defender"


func ground_pos() -> Vector3:
	return Vector3(position.x, 0, position.z)


## How far a held raider crouches into his struggle: BRACE (and BRACE_LOSS more as his balance goes), and never less
## than he was caught at plus BRACE - caught out of the raid's deep stance or a touch's lunge he sinks into the brace,
## not up into it (since the raider's stance came from the training footage, he stood up 9 cm as he was grabbed).
var _caught_crouch := 0.0


func _brace() -> float:
	return maxf(BRACE + BRACE_LOSS * balance, minf(_caught_crouch + 0.3, 0.9))


func set_state(s: String, length := 0.0, wait_first := 0.0) -> void:
	if s == "held" and state not in ["held", "dodge"] and model:
		_caught_crouch = model.crouch   # as low as he was caught (a lunge, a touch, the raid's crouch): see _brace()
	if state == "sit" and s != "sit":
		_off_seat = true   # getting up from the bench: he comes forward off it first (_step)
	if s != "holding":
		hold_style = ""
		haul = 0.0
		bear = 0.0
		strain = 0.0
	if s != "held":
		held_leg = 0.0
		hop = -1.0
		hop_air = 0.0
		jolt = 0.0
	state = s
	st_t = 0.0
	st_len = length
	wait = wait_first
	if model:
		# Real captured motion for this move, if there is any: which celebration, which way a dodge goes.
		var variant := ""
		match s:
			"celebrate":
				variant = str(cele_kind)
			"dodge":
				variant = "right" if dive_dir.dot(facing.cross(Vector3.UP)) > 0.0 else "left"
			"dive":
				variant = kind()
				if variant == "ankle":
					# The only captured dive is a flying tackle at thigh height; an ankle dive goes in low, arms
					# out along the floor, as the hand-made dive does.
					model.play_state("", length)
					return
			"fallen":
				variant = fall_kind
		if s == "dodge" and held_by > 0:
			model.play_state("held")   # a twist against the holds, not a sidestep: the struggle's own motion carries on
			return
		model.play_state(s, length - wait, variant, wait)


func busy() -> bool:
	return state in ["touch", "kick", "backkick", "dubki", "jump", "shoved", "telegraph", "dive", "recover", "rise", "fallen", "held", "holding"]


## 0..1 skill at a raiding move.
func move_skill(move: String) -> float:
	return float(moves.get(move, 50)) / 100.0


## 0..1 skill at a defensive skill.
func dskill(kind: String) -> float:
	return float(dmoves.get(kind, 50)) / 100.0


## The tackle being made now, or his usual one.
func kind() -> String:
	return tackle_kind if tackle_kind != "" else style


## Pitch of his voice, the same every time for the same player.
func voice_pitch() -> float:
	return 0.88 + float(absi(hash(String(data.get("id", name)))) % 1000) / 1000.0 * 0.26


## Airborne part of a lion jump (after any gathering for it).
func airborne() -> bool:
	if state != "jump":
		return false
	var p := (st_t - wait) / maxf(st_len - wait, 0.01)
	return p > 0.12 and p < 0.88


## Accelerate toward a desired ground velocity and integrate: no faster than his acceleration, or than rate (m/s²)
## for a hard step.
func drive(desired: Vector3, dt: float, rate := -1.0) -> void:
	desired.y = 0
	var meant := desired   # where he means to go, before stepping round anyone
	if avoid != Vector3.ZERO:
		# Round anyone he is about to walk into (Match._push_all): no further toward them, and out of their way.
		var away := avoid.normalized()
		desired -= away * minf(0.0, desired.dot(away))
		desired += avoid
	drove = true
	drives += 1
	# Round the props on his way: the way he means to go turned (at its speed) toward the clear way most like it, so
	# he accelerates along it rather than into the prop (WsgSolidProps.steer; he keeps to the side he chose).
	if solid != null and desired.length() > 0.05 and float(solid.penetration(position, PROP_R)[0]) <= 0.01:
		desired = solid.steer(position, desired, PROP_R, 1.8, _goal, _prop_memo)
	vel = vel.move_toward(desired, (accel if rate < 0.0 else rate) * dt)
	_step(dt)
	# He turns the way he is going while it is the way he means to go: stepped aside by someone (avoid) with nowhere he
	# means to go, he does not turn to it (one stood still and stepped aside and back was turned to and fro with each step,
	# tests/motion_audit); pulling up from a sprint to go back, he faces the way he was running until he is going back.
	if not lock_facing and vel.length() > 0.4 and vel.dot(meant) > 0.0:
		facing = facing.slerp(vel.normalized(), clampf(dt * 10.0, 0.0, 1.0)).normalized()


## The ground's props (WsgSolidProps, set by the match): nobody walks through a bench, a table, a chair, a board.
static var solid: WsgSolidProps
const PROP_R := 0.28   # a body's radius among the props
var _prop_memo := {}   # the side he chose round a long prop (WsgSolidProps.steer keeps to it)
var _goal := Vector3.INF
var _off_seat := false # up from the bench, still over it: stepping forward off it


## The step itself: round the props on his way (steered, keeping his speed), never into one. One already in a prop
## (sat on the bench, or put there) walks out of it as he means to, not jumped out.
func _step(dt: float) -> void:
	if solid == null:
		position += vel * dt
		return
	if float(solid.penetration(position, PROP_R)[0]) > 0.01:
		if not _off_seat:
			position += vel * dt
		return   # (getting up off the bench: _rise_off_seat moves him, every frame)
	_off_seat = false
	# (steered in drive) moved, and never into one: pushed out of anything he would still touch.
	var to := solid.push_out(position + vel * dt, PROP_R, 1.8)
	var real := (to - position) / dt if dt > 0.0 else vel
	real.y = 0.0
	position = to
	vel = real.limit_length(maxf(vel.length(), 0.5))


## Sat on the bench his hips were over the seat and his feet in front: standing, he comes forward onto them (about
## 0.4 m) as he rises, every frame until he is clear of it, whether or not anyone drives him meanwhile.
func _rise_off_seat(dt: float) -> void:
	if not _off_seat or solid == null or state == "sit":
		return
	if float(solid.penetration(position, PROP_R)[0]) <= 0.01:
		_off_seat = false
		return
	position = position.move_toward(solid.free_spot(position, PROP_R), 2.4 * dt)


func seek(target: Vector3, speed: float, dt: float, arrive := 0.6) -> void:
	_goal = target
	var to := target - position
	to.y = 0
	var d := to.length()
	if d < 0.05:
		_goal = Vector3.INF
		drive(Vector3.ZERO, dt)
		return
	var s := speed * clampf(d / arrive, 0.0, 1.0)
	drive(to / d * s, dt)
	_goal = Vector3.INF


func face_toward(p: Vector3, dt: float, rate := 8.0) -> void:
	var to := p - position
	to.y = 0
	if to.length() > 0.05:
		facing = facing.slerp(to.normalized(), clampf(dt * rate, 0.0, 1.0)).normalized()


## Turn toward p no faster than max_rate (rad/s): a body that cannot spin freely (held round the middle).
func turn_toward(p: Vector3, dt: float, max_rate: float) -> void:
	var to := p - position
	to.y = 0
	if to.length() <= 0.05:
		return
	var a := facing.signed_angle_to(to.normalized(), Vector3.UP)
	facing = facing.rotated(Vector3.UP, clampf(a, -max_rate * dt, max_rate * dt)).normalized()


func _process(delta: float) -> void:
	_rise_off_seat(delta)
	st_t += delta
	cooldown = maxf(0.0, cooldown - delta)
	reach_t = maxf(0.0, reach_t - delta)
	# Sweat builds as he tires and dries slowly once he has his breath back (his skin's shine, RiggedBody.set_sweat).
	var wet := clampf((1.0 - energy) * 1.8, 0.0, 1.0)
	_sweat = wet if wet > _sweat else move_toward(_sweat, wet, delta * 0.01)
	_sweat_t -= delta
	if _sweat_t <= 0.0 and model and model.rig:
		_sweat_t = 0.5
		model.rig.set_sweat(snappedf(_sweat, 0.02))
	_track_motion(delta)
	if step_surface != "" and on_mat:
		_footsteps(delta)
	rotation.y = _vis_yaw
	_pose(delta)
	if _ring.visible:
		_ring.rotation.y += delta * 1.5


## Measured ground velocity and the body's turn on screen. A move of more than a metre in one frame is a
## placement (the start of a raid, back to the bench), not running: the body is simply put there.
func _track_motion(delta: float) -> void:
	var dt := maxf(delta, 0.0001)
	var flat := Vector3.ZERO if _last_pos == Vector3.INF else Vector3(position.x - _last_pos.x, 0.0, position.z - _last_pos.z)
	var placed := _last_pos == Vector3.INF or flat.length() > 1.0
	_last_pos = position
	if placed:
		move_vel = Vector3(vel.x, 0.0, vel.z)
	else:
		move_vel = move_vel.lerp(flat / dt, 1.0 - exp(-dt * 30.0))
	var target := atan2(-facing.x, -facing.z)
	if placed or _vis_yaw == INF:
		_vis_yaw = target
		return
	var cap := deg_to_rad(lerpf(TURN_STILL, TURN_SPRINT, clampf(move_vel.length() / 5.0, 0.0, 1.0))) * dt
	_vis_yaw = wrapf(_vis_yaw + clampf(wrapf(target - _vis_yaw, -PI, PI) * (1.0 - exp(-dt * 20.0)), -cap, cap), -PI, PI)


## A footstep (Sfx.step) each step's length he goes on his feet: short creeping steps, long running ones.
func _footsteps(delta: float) -> void:
	var speed := move_vel.length()
	if speed < 0.6 or airborne() or state in ["fallen", "held", "dive", "rise", "sit"]:
		_stride = 0.0
		return
	_stride += speed * delta
	var length := 0.55 + 0.1 * speed
	if _stride >= length:
		_stride -= length
		Sfx.step(step_surface, global_position, speed)


## The way his body faces on screen (see _track_motion).
func body_facing() -> Vector3:
	return Vector3(-sin(_vis_yaw), 0.0, -cos(_vis_yaw)) if _vis_yaw != INF else facing


## How fast the dive pose eases out (per second; it eases in at 14): letting go to get up, the arms come back from
## the hold over a third of a second, not in one tenth (5 m/s at the hands, from 9-11).
const DIVE_OUT := 3.0


func _pose(delta: float) -> void:
	var m := model
	var k := clampf(delta * 10.0, 0.0, 1.0)
	# A holder is moved by the grapple to keep his hold, not running: no stride for that (it would feed back into
	# where the grapple puts him next frame). Nor for a raider held round the middle, who steps a foot at a time
	# (Grapple._steps, RiggedBody.step), or held by both legs, who cannot step at all.
	var want_speed := 0.0 if state == "holding" or (state == "held" and held_leg == 0.0) else move_vel.length()
	# Standing ready (or idle) and shuffling his place in starts and stops, his legs ease with it: the crouch follows
	# his speed, and fed each burst it jerked his knees (0.1-0.25 rad in a frame; the owner's "twitching", 2026-11-02).
	if state in ["ready", "idle"] and want_speed < 1.0 and m.speed < 1.0:
		m.speed = lerpf(m.speed, want_speed, clampf(delta * 6.0, 0.0, 1.0))
	else:
		m.speed = want_speed
	# The held clip's own leg work would fight his steps (its feet lifting and shifting under a planted foot): his legs
	# are the braced stance underneath while he steps or is held by both legs. Standing ready, the same: the stance clip
	# (a goalkeeper's) stood him with his knees and toes turned out and a leg straight out to the side, a foot left
	# planted at its widest; his legs are the hand-made crouch (HumanModel._animate), the clip keeps his trunk and arms.
	# A raider working the cover the same: his legs dance (HumanModel's tap), the stance clip keeps his trunk and arms
	# (the old clip's legs stood him nearly straight-kneed).
	var own_legs := (state == "held" and held_leg == 0.0) or state in ["ready", "raid"]
	m.clip_legs = move_toward(m.clip_legs, 0.0 if own_legs else 1.0, delta * 4.0)
	var want_crouch := 0.0
	var want_lean := 0.0
	var want_reach := 0.0
	var want_kick := 0.0
	var want_dive := 0.0
	var want_fallen := 0.0
	var want_struggle := 0.0
	var want_celebrate := 0.0
	var want_hold := 0.0
	var want := {"roar": 0.0, "slump": 0.0, "shove": 0.0, "argue": 0.0, "slap": 0.0}
	var want_back_kick := 0.0
	var want_dubki := 0.0
	var want_jump := 0.0
	var want_seated := 0.0
	var want_signal := 0.0
	var want_bounce := 0.0
	var want_wrench := 0.0
	var p := clampf((st_t - wait) / maxf(st_len - wait, 0.01), 0.0, 1.0)
	var waiting := st_t < wait
	match state:
		"ready":
			want_crouch = READY_CROUCH
		"raid":
			# Hips about 0.9 of their standing height, as the footage's raider works the cover; past HumanModel's 0.55, so
			# working the cover slowly he walks on the crouched walks (on the upright ones his knees passed straight at
			# every step).
			want_crouch = 0.6
			want_lean = -0.2
			want_bounce = 1.0
		"touch":
			want_reach = sin(p * PI)
			want_crouch = 0.3
		"kick":
			want_kick = sin(p * PI)
		"backkick":
			want_back_kick = sin(p * PI)
		"dodge":
			want_crouch = 0.5
			if held_by > 0:
				# Break free, held: a wrench against the holds (HumanModel.wrench) out of his braced stance, not a sidestep
				# in the air (the sidestep's clip and stance stood him up out of the struggle at every try).
				want_struggle = 1.0
				want_crouch = _brace()
				want_wrench = sin(p * PI)
		"evade":
			# Pulling back from a touch: hips back, stomach in.
			want_crouch = 0.6
			want_lean = 0.25
		"dubki":
			want_dubki = clampf(sin(p * PI) * 1.6, 0.0, 1.0)
		"jump":
			want_jump = sin(p * PI)
			if waiting:
				# Gathering himself on the free leg to spring out of the hold.
				want_crouch = clampf(st_t / maxf(wait, 0.01) * 1.5, 0.0, 1.0)
		"telegraph":
			# The wind-up shows how he will tackle: low for an ankle hold, upright and wide
			# for a thigh hold or a block.
			match kind():
				"ankle":
					want_crouch = 1.0
					want_lean = -0.35
					want_hold = 0.35
				"waist":
					want_crouch = 0.45
					want_hold = 1.0
				"dash":
					want_crouch = 0.55
					want_lean = -0.3
					want.shove = 0.5
				_:
					want_crouch = 0.75
					want_hold = 0.7
		"dive":
			var depth := {"ankle": 1.0, "thigh": 0.72, "waist": 0.45, "dash": 0.3}.get(kind(), 0.8) as float
			want_dive = clampf(p * 2.5, 0.0, 1.0) * depth
			if kind() in ["dash", "waist"]:
				want.shove = 1.0 if kind() == "dash" else 0.4
		"shoved":
			want_struggle = 0.6
			want_lean = 0.25
		"recover":
			want_fallen = 1.0 - clampf((p - 0.55) * 2.2, 0.0, 1.0)
			# Up into the ready crouch he goes on in (stood up straight, then dropping into it, he bobbed).
			want_crouch = READY_CROUCH * clampf((p - 0.55) * 2.2, 0.0, 1.0)
			if waiting:
				# Flat on the floor where the leg was torn from his hands, reaching after it, before he gets up.
				want_dive = 1.0
				want_fallen = 0.0
		"rise":
			# Up off his knees, or out of the bend he went down with the raider in: the crouch and the reach for
			# the hold come out of him as he comes up (an ease, slow at both ends).
			var q := 1.0 - p * p * (3.0 - 2.0 * p)
			want_crouch = lerpf(READY_CROUCH, 1.0, q)   # up into the ready crouch he goes on in, not up straight and down again
			want_dive = 0.55 * q * q
			want_hold = 0.4 * q
		"fallen":
			want_fallen = 1.0
		"held":
			want_struggle = 1.0
			# Braced from the moment he is caught (knees bent, hips back and down, leaning into his drive for the line),
			# lower as his balance goes: not stood upright until the takedown.
			want_crouch = _brace()
		"holding":
			# Each hold drawn its own way (Grapple), the arms reaching the rest of the way (RiggedBody): an ankle
			# hold lying on the floor, arms out; a thigh hold down low, bent over the leg; round the waist bent
			# into his back; a block upright, chest to chest.
			match hold_style:
				"ankle":
					want_dive = 1.0
				"thigh":
					want_dive = 0.72
					want_crouch = 1.0
					want_hold = 1.0
				"waist":
					want_dive = 0.38
					want_crouch = 0.7
					want_hold = 1.0
				"block":
					want_dive = 0.22
					want_crouch = 0.75
					want_hold = 1.0
				_:
					want_dive = 0.55
					want_hold = 1.0
			# Taking him down from on his feet, he goes down with him, bending right over.
			want_dive = maxf(want_dive, bear * 0.75)
			want_crouch = maxf(want_crouch, bear)
		"signal":
			want_signal = 1.0
		"celebrate":
			want_celebrate = 1.0
			# A high five waits until the two of them meet.
			if cele_partner != null and position.distance_to(cele_partner.position) > 1.15:
				want_celebrate = 0.0
		"sit":
			want_seated = 1.0
		"roar", "slump", "shove", "argue":
			want[state] = 1.0
			if state == "slump":
				want_crouch = 0.25
		"slap":
			want.slap = 1.0
			want_crouch = 0.45
	m.crouch = lerpf(m.crouch, want_crouch, k)
	m.lean = lerpf(m.lean, want_lean, k)
	m.reach = lerpf(m.reach, want_reach, clampf(delta * 20.0, 0.0, 1.0))
	m.kick = lerpf(m.kick, want_kick, clampf(delta * 18.0, 0.0, 1.0))
	# Into a dive at once; out of it more slowly (DIVE_OUT), with the get-up clip coming in (HumanModel.GETUP_IN).
	m.dive = lerpf(m.dive, want_dive, clampf(delta * (14.0 if want_dive > m.dive else DIVE_OUT), 0.0, 1.0))
	m.fallen = lerpf(m.fallen, want_fallen, k)
	m.struggle = lerpf(m.struggle, want_struggle, k)
	m.celebrate = lerpf(m.celebrate, want_celebrate, k)
	m.hold_arms = lerpf(m.hold_arms, want_hold, k)
	m.roar = lerpf(m.roar, want.roar, k)
	m.slump = lerpf(m.slump, want.slump, k)
	m.shove = lerpf(m.shove, want.shove, clampf(delta * 16.0, 0.0, 1.0))
	m.argue = lerpf(m.argue, want.argue, k)
	m.slap = lerpf(m.slap, want.slap, k)
	m.back_kick = lerpf(m.back_kick, want_back_kick, clampf(delta * 18.0, 0.0, 1.0))
	m.kick_back = kick_back
	m.kick_side = kick_side
	m.dubki = lerpf(m.dubki, want_dubki, clampf(delta * 16.0, 0.0, 1.0))
	# A hold being worked: the raider's balance goes as the struggle does and stays gone as he falls (the fall
	# takes over from it); the hauls come and go quickly.
	if state == "held":
		m.balance = move_toward(m.balance, balance, delta * 2.0)
	else:
		m.balance = move_toward(m.balance, 0.0, delta * (1.6 if state == "fallen" else 4.0))
	m.tug = lerpf(m.tug, tug if state == "held" else 0.0, clampf(delta * 18.0, 0.0, 1.0))
	m.tug_side = tug_side
	# An ankle holder on the floor stays braced between hauls (head and chest up off the mat, knees a little
	# drawn up), rather than lying flat until the next one.
	var braced := maxf(haul, 0.3 * clampf(st_t / 0.4, 0.0, 1.0)) if hold_style == "ankle" else haul
	m.haul = lerpf(m.haul, braced if state == "holding" else 0.0, clampf(delta * 18.0, 0.0, 1.0))
	m.haul_drive = hold_style == "block"
	m.strain = lerpf(m.strain, strain if state == "holding" else 0.0, clampf(delta * 10.0, 0.0, 1.0))
	# On one leg, the other held by the ankle: in quickly as the foot is caught, out as he goes down or gets free. A
	# move made while it is held (a dubki or a sidestep, gathering for a jump) is made on the free leg: the hold
	# does not go away for it.
	var one := 1.0 if (state in ["held", "dubki", "dodge"] or (state == "jump" and waiting)) and held_leg != 0.0 else 0.0
	m.one_leg = move_toward(m.one_leg, one, delta * (8.0 if one > 0.0 else (2.5 if state == "fallen" else 6.0)))
	if held_leg != 0.0:
		m.held_leg = held_leg
	m.stance = lerpf(m.stance, stance, clampf(delta * 12.0, 0.0, 1.0))
	m.hop = hop
	m.hop_air = hop_air
	m.jolt = jolt
	m.jump = want_jump
	m.cele = cele_kind
	m.bounce = lerpf(m.bounce, want_bounce, k)
	m.wrench = lerpf(m.wrench, want_wrench, clampf(delta * 14.0, 0.0, 1.0))
	m.stance_ready = move_toward(m.stance_ready, 1.0 if state == "ready" else 0.0, delta * 4.0)
	if want_wrench > 0.0:
		m.wrench_side = 1.0 if dive_dir.dot(facing.cross(Vector3.UP)) >= 0.0 else -1.0
	m.ref_sig = sig_kind
	m.ref_amt = lerpf(m.ref_amt, want_signal, clampf(delta * 9.0, 0.0, 1.0))
	m.seated = lerpf(m.seated, want_seated, clampf(delta * 4.0, 0.0, 1.0))
	# Which way he is moving relative to where his body faces: forward, backpedalling or sideways.
	var flat := move_vel
	if flat.length() > 0.3:
		var dir := flat.normalized()
		var fwd := body_facing()
		var right := fwd.cross(Vector3.UP).normalized()
		m.move_fwd = lerpf(m.move_fwd, dir.dot(fwd), k)
		m.move_side = lerpf(m.move_side, dir.dot(right), k)
	else:
		m.move_fwd = lerpf(m.move_fwd, 1.0, k)
		m.move_side = lerpf(m.move_side, 0.0, k)
	# Players with nothing to do look around; players in the action keep their eyes on it.
	m.look_around = 1.0 if state in ["idle", "sit", "walk"] or not on_mat else 0.25
