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
var _ball_id := -1            # the ball's flight (changes on each strike)

## By level: reaction (s), timing error (s, either way), aim error (m), the share of low skidding drives.
const REACT := [0.24, 0.15, 0.08]
const TIMING := [0.075, 0.045, 0.022]
const AIM_ERR := [3.2, 2.0, 1.1]
const DRIVES := [0.25, 0.4, 0.55]


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
	# On the lively stone of the Yucatán courts players wait for the ball to come up off the bounce and take it with the
	# hip standing, as in the games played there; on ulama's dead earth a low ball is dived for sooner.
	var dive_cost := 0.9 if m.court.classic() else 0.25
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
		if pt.y >= 0.42 and pt.y < 1.15:
			kind = "hip"
		elif pt.y >= Player.STRIKE_MIN_Y + 0.02 and not grounded:
			# A low ball still in the air: a player sinks right down for it, not quite a dive.
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
			var need: float = dist / (p.max_speed * 0.85) + float(REACT[level]) + lead
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
			if t <= go_at + 0.017 and Vector2(p.global_position.x - intercept.stand.x, p.global_position.z - intercept.stand.z).length() < 0.7:
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
	var ang := rng.randf_range(8.0, 14.0) if drive else rng.randf_range(26.0, 42.0)
	return Vector3(x, ang, z)
