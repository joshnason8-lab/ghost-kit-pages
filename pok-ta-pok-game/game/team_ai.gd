class_name TeamAI
extends RefCounted
## A side's brain, as the hip game is played: everyone keeps his place down the length of his half (the malero at the
## front by the analco, the chivero at the back by the end line, the others between), shifting across with the ball;
## when the ball comes, the one who can meet it soonest at hip height (or, if it is low, on the ground with a dive)
## goes for it, turning side-on so it comes to his hip, and strikes as it arrives. He sends it deep, or low and hard
## so it skids along the earth where the other side must go down to it. Whoever the ball would run into steps out of
## its way (a touch with anything but the hip is a fault). The numbers are in docs/AI.md.

var m                         # the match
var team := 0
var players: Array = []
var taker: Player = null
var intercept := {}           # the taker's plan: pos (where the ball is met), stand, t (s from now), kind, side, yaw
var level := 1                # 0 Village, 1 Regional, 2 Champion
var rng := RandomNumberGenerator.new()
var _jitter := 0.0            # this ball's timing error (s)
var _lapse := false           # this ball is misjudged (LAPSE)
var _ball_id := -1            # the ball's flight (changes on each strike)

## By level: reaction (s), timing error (s, either way), aim error (m), the share of low skidding drives.
const REACT := [0.24, 0.15, 0.08]
const TIMING := [0.075, 0.045, 0.022]
const AIM_ERR := [3.2, 2.0, 1.1]
const DRIVES := [0.12, 0.18, 0.25]
## By level: the share of balls he misjudges outright (late or early by a good deal: a miss, a mistimed return).
const LAPSE := [0.18, 0.12, 0.07]


func _init(p_m, p_team: int, p_players: Array, p_level: int, seed_: int) -> void:
	m = p_m
	team = p_team
	players = p_players
	level = clampi(p_level, 0, 2)
	rng.seed = seed_ * 7 + team


func dirn() -> float:
	return Rules.dir(team)


## Where each player keeps his place: a depth down his half and a line across, shifted toward the ball.
func home_spot(i: int, ball_z := 0.0) -> Vector3:
	var n := players.size()
	var depth: Array
	var court: Court = m.court
	var hl := Court.ALLEY_HALF_L if court.classic() else Court.ULAMA_HALF_L
	match n:
		2:
			depth = [0.3, 0.75]
		3:
			depth = [0.22, 0.5, 0.8]
		4:
			depth = [0.14, 0.38, 0.62, 0.86]
		_:
			depth = [0.1, 0.3, 0.5, 0.7, 0.9]
	var d: float = depth[mini(i, depth.size() - 1)]
	var hw := court.half_w_at(-dirn() * d * hl) * 0.55
	var lane := (0.55 if i % 2 == 0 else -0.55) * hw
	return Vector3(-dirn() * d * hl, 0, clampf(lane + ball_z * 0.4, -hw, hw))


## The role by depth (docs/RULES.md "Positions"): the front man by the analco, the one at the back, and between.
func role_of(i: int) -> String:
	var n := players.size()
	if i == 0:
		return "malero"
	if i == n - 1:
		return "chivero"
	if i == n - 2 and n >= 4:
		return "topador"
	return "medio"


func update(dt: float) -> void:
	var path: Array = m.ball_path
	var live: bool = m.is_live()
	if _ball_id != m.ball_flight:
		_ball_id = m.ball_flight
		_jitter = rng.randf_range(-float(TIMING[level]), float(TIMING[level]))
		_lapse = rng.randf() < float(LAPSE[level])
		if _lapse:
			_jitter = rng.randf_range(0.11, 0.2) * (1.0 if rng.randf() < 0.5 else -1.0)
		taker = null
		intercept = {}
	if live:
		_plan(path)
	else:
		taker = null
		intercept = {}
	for i in players.size():
		var p: Player = players[i]
		if p.user and p.steer_by_dir:
			continue
		if p.user and int(Game.settings.assist) == 0 and live:
			# No help: your player stands where you left him.
			p.want = p.global_position
			continue
		_place(p, i, live, path, dt)


## Who goes for the ball, where and when: the soonest any of them can be there.
func _plan(path: Array) -> void:
	if path.is_empty():
		return
	var best := {}
	var best_p: Player = null
	var court: Court = m.court
	# Players wait for the ball to come up off the bounce and take it with the hip standing, as the game is played; a
	# dive is the last resort for a ball that will not come up in time (the rubber ball bounces on the earth too).
	var dive_cost := 0.9 if m.court.classic() else 0.8
	# The bounced serve is let come down and played off the bounce, never taken on the full.
	var bounced: bool = m.serve_bounced
	for i in path.size():
		var pt: Vector3 = path[i][0]
		var t: float = path[i][2]
		if not bounced:
			if pt.y < Ball.RADIUS + 0.04:
				bounced = true
			continue
		if Rules.half_of(pt.x) != team or absf(pt.x) < 0.7:
			continue
		if absf(pt.z) > court.half_w_at(pt.x) + 0.3:
			continue
		var fy := court.floor_y(pt.x, pt.z)
		if fy > 0.05:
			continue
		var kind := ""
		var grounded: bool = path[i][1]
		if pt.y >= 0.42 and pt.y < Player.HIP_H + Player.STRIKE_MAX_UP - 0.05:
			kind = "hip"
		elif pt.y >= Player.STRIKE_MIN_Y + 0.02 and pt.y < 0.42 and not grounded:
			# A low ball still in the air: a player sinks right down for it, not quite a dive. (Only below the hip: an
			# airborne ball over the head was planned for the hip too, and missed.)
			kind = "hip"
		elif grounded or pt.y < Player.STRIKE_MIN_Y + 0.02:
			# Lower, or rolling on the earth: only by going down to the ground with the hip (the dive).
			kind = "dive"
		else:
			continue
		var lead := Moves.STRIKE_T * Moves.STRIKE_HIT if kind == "hip" else Moves.DIVE_T * Moves.DIVE_HIT
		for p: Player in players:
			if p.busy() and p != taker:
				continue
			var side := _side_for(p)
			var stand := _stand_for(pt, kind, side)
			var dist := Vector2(stand.x - p.global_position.x, stand.z - p.global_position.z).length()
			var need: float = run_time(p, dist) + float(REACT[level]) + lead
			if dist < 0.35:
				need = lead
			var score := t + (dive_cost if kind == "dive" else 0.0)
			if need <= t + 0.02 and (best.is_empty() or score < float(best.score)):
				best = {"pos": pt, "stand": stand, "t": t, "kind": kind, "side": side, "score": score, "lead": lead}
				best_p = p
		if not best.is_empty() and t > float(best.score) + maxf(0.3, dive_cost + 0.1):
			break
	if best_p == null:
		# Nobody can be there in time at the right height: the nearest goes toward where it will come down anyway.
		taker = null
		intercept = {}
		return
	taker = best_p
	intercept = best


## How long he takes to cover dist metres from where he is, speeding up from his present speed (Player.ACCEL) to a
## little under his best (the plan once took him to be at speed already: from a standstill he came late, and the ball
## went by or died).
static func run_time(p: Player, dist: float) -> float:
	var top := p.max_speed * 0.9
	var a := Player.ACCEL
	var v0 := clampf(Vector2(p.vel.x, p.vel.z).length() * 0.5, 0.0, top)
	var t_acc := (top - v0) / a
	var d_acc := (v0 + top) * 0.5 * t_acc
	if dist <= d_acc:
		return (-v0 + sqrt(v0 * v0 + 2.0 * a * dist)) / a
	return t_acc + (dist - d_acc) / top


## Which hip: side-on to the ball's coming, the hip toward the other side's end (docs/AI.md): facing across the court
## one way, the left hip; the other way, the right. Each keeps his own habit.
func _side_for(p: Player) -> float:
	return dirn() if p.num % 2 == 0 else -dirn()


## Where to stand so the ball meets the hip: just back from the point, on the ball's line.
func _stand_for(pt: Vector3, kind: String, side: float) -> Vector3:
	var back := 0.2 if kind == "hip" else 0.5
	var s: Vector3 = m.court.clamp_feet(Vector3(pt.x - dirn() * back, 0, pt.z))
	return s


## The yaw that puts the side's hip toward the other end: his left (+X locally) is (cos yaw, 0, -sin yaw).
func _yaw_for(side: float) -> float:
	# side * left must point toward +dir x: yaw 0 when side*dir > 0, PI otherwise.
	return 0.0 if side * dirn() > 0.0 else PI


func _place(p: Player, i: int, live: bool, path: Array, _dt: float) -> void:
	var ball_z: float = m.ball.pos.z
	p.face_to = m.ball.pos
	p.face_yaw = NAN
	if m.server == p and m.ball.held:
		# The ball is in his hand: he faces the other side, not the ball (which would turn with him).
		p.face_yaw = atan2(dirn(), 0.0)
	if not live:
		if m.server == p and m.phase == m.P.SERVE:
			p.want = m.serve_spot(team)
		else:
			p.want = home_spot(i, 0.0)
		return
	if p == taker and not intercept.is_empty():
		p.want = intercept.stand
		var t: float = intercept.t
		var side: float = intercept.side
		if t < 0.9:
			p.face_yaw = _yaw_for(side)
		p.low = 0.9 if intercept.kind == "dive" else 0.75
		# Strike as the ball arrives: the strike's moment lined up with the ball's, give or take this level's error.
		if not p.user and not p.busy():
			var go_at: float = float(intercept.lead) + _jitter
			var off := Vector2(p.global_position.x - intercept.stand.x, p.global_position.z - intercept.stand.z).length()
			# Already on his spot, he goes as the ball arrives, late at the worst by a frame: the plan, made afresh each
			# frame, never has the ball later than "now" for a man standing there, so a late timing error once kept
			# him waiting, backing off with a slow ball until it died at his feet.
			if off < 0.35 and not _lapse:
				go_at = maxf(go_at, float(intercept.lead) + 0.02)
			if t <= go_at + 0.017 and off < 1.0:
				var aim := choose_aim()
				if intercept.kind == "hip":
					p.start_strike(side, aim, m.ai_ring_shot(p))
				else:
					p.start_dive(side, aim)
		return
	p.low = 0.5
	var spot := home_spot(i, ball_z)
	# Out of the ball's way: if it would run into him, a step across.
	for k in mini(path.size(), 40):
		var pt: Vector3 = path[k][0]
		if pt.y < 1.7 and Vector2(pt.x - p.global_position.x, pt.z - p.global_position.z).length() < 0.75:
			var away := 1.0 if p.global_position.z >= pt.z else -1.0
			spot = Vector3(p.global_position.x, 0, p.global_position.z + away * 1.4)
			break
	p.want = m.court.clamp_feet(spot)


## Where to send it: deep into the other half or low and hard along the earth, somewhere across the court, with this
## level's error. Returns the aim as [target point, kind] packed in a Vector3: x, z the target; y the launch angle (deg).
func choose_aim() -> Vector3:
	var court: Court = m.court
	var hl := Court.ALLEY_HALF_L if court.classic() else Court.ULAMA_HALF_L
	var drive: bool = rng.randf() < float(DRIVES[level])
	var depth := rng.randf_range(0.4, 0.85) if not drive else rng.randf_range(0.3, 0.65)
	var x := dirn() * depth * hl
	var hw := court.half_w_at(x)
	var z := rng.randf_range(-hw * 0.7, hw * 0.7)
	var e: float = AIM_ERR[level]
	x += rng.randf_range(-e, e) * 1.5
	z += rng.randf_range(-e, e) * 0.35
	# A drive is low and hard, but off the ground: it skips up off the earth to the other side's hips.
	var ang := rng.randf_range(16.0, 22.0) if drive else rng.randf_range(26.0, 42.0)
	return Vector3(x, ang, z)
