extends Node3D
## WsgSim's demo game (the foundation's own: the harness is proved on it before a game adopts it): three a side, a ball,
## two goals with posts, a crossbar and nets, a bench and a scorers' table beside the court; two halves on a clock that
## counts down; AI that presses or holds a zone, dribbles, passes and shoots; the ball bouncing off every prop
## (WsgSolidProps); with config "bodies", every player a WsgBody on the licensed locomotion. Every random roll from the
## match's own generator. config "bug" breaks it on purpose (tests/sim_test.gd: each check must catch its bug).

const HALF_L := 15.0
const HALF_W := 10.0
const GOAL_W := 1.5
const R := 0.3
const H := 1.8
const BALL_R := 0.11

var cfg := {}
var rng := RandomNumberGenerator.new()
var solid := WsgSolidProps.new()
var players: Array = []
var ball_pos := Vector3(0, BALL_R, 0)
var ball_vel := Vector3.ZERO
var holder := -1
var score := [0, 0]
var clock := 0.0
var phase := "first half"
var finished := false
var events: Array = []
var goals := 0
var t := 0.0
var _break := 0.0
var _bug := ""
var _shot_from := Vector3.ZERO
var _last_touch := -1         # who last played the ball (a shot or a pass) ...
var _touch_until := 0.0       # ... cannot touch it again until then (it was re-catching its own shots: no goals)
var fetch_spot := Vector3.INF # the ball dead behind a prop (WsgSim's fetch case) ...
var fetcher := -1             # ... and who goes for it


func setup(config: Dictionary, seed: int) -> void:
	cfg = config
	rng.seed = seed
	_bug = String(cfg.get("bug", ""))
	clock = float(cfg.get("half", 45.0))
	solid.add({"name": "court", "kind": "floor", "y": 0.0})
	solid.add({"name": "bench", "kind": "box", "position": Vector3(0, 0, HALF_W + 1.2), "size": Vector3(6.0, 0.45, 0.45)})
	solid.add({"name": "scorers' table", "kind": "box", "position": Vector3(-8, 0, HALF_W + 1.4), "size": Vector3(1.8, 0.76, 0.8), "material": "plastic"})
	for s in [-1.0, 1.0]:
		for z in [-GOAL_W, GOAL_W]:
			solid.add({"name": "post", "kind": "cylinder", "position": Vector3(s * HALF_L, 0, z), "radius": 0.05, "height": 2.0, "material": "metal"})
		solid.add({"name": "crossbar", "kind": "capsule", "a": Vector3(s * HALF_L, 2.0, -GOAL_W), "b": Vector3(s * HALF_L, 2.0, GOAL_W), "radius": 0.05, "material": "metal"})
		solid.add({"name": "net", "kind": "box", "position": Vector3(s * (HALF_L + 1.0), 0, 0), "size": Vector3(0.05, 2.0, GOAL_W * 2.0), "material": "net"})
	var bodies := bool(cfg.get("bodies", false)) and WsgClips.available()
	var ch := WsgBody.load_character("res://tests/character", "hero") if bodies else {}
	for team in 2:
		for k in 3:
			var p := {"team": team, "pos": Vector3((-6.0 if team == 0 else 6.0) + rng.randf_range(-2, 2), 0, -4.0 + k * 4.0),
				"speed": float(cfg.speed[team]) * rng.randf_range(0.9, 1.1), "skill": float(cfg.skill[team]) * rng.randf_range(0.85, 1.15),
				"target": Vector3.INF, "memo": {}, "body": null, "loco": null, "vel": Vector3.ZERO, "facing": 0.0}
			if String(cfg.get("start", "")) == "in props" and k == 0:
				p.pos = Vector3(rng.randf_range(-2, 2), 0, HALF_W + 1.2)     # on the bench: the resolve must free it
			p.pos = solid.push_out(p.pos, R, H)
			if bodies:
				var b := WsgBody.new(ch)
				add_child(b)
				b.position = p.pos
				p.body = b
				p.loco = WsgLocomotor.attach(b)
			players.append(p)
	if String(cfg.get("start", "")) == "near goal":
		ball_pos = Vector3(HALF_L - 3.0, BALL_R, rng.randf_range(-2, 2))


func _process(dt: float) -> void:
	if finished:
		return
	t += dt
	_bugs()
	if phase == "half time":
		_break -= dt
		if _break <= 0.0:
			phase = "second half"
			clock = float(cfg.get("half", 45.0))
			_kickoff(1)
		return
	if _bug != "endless":
		clock -= dt
	if clock <= 0.0:
		clock = 0.0
		if phase == "first half":
			phase = "half time"
			_break = 3.0
			events.append({"type": "half time", "score": score.duplicate()})
		else:
			phase = "full time"
			finished = true
			events.append({"type": "full time", "score": score.duplicate()})
		return
	# The sides take turns moving first, frame by frame: home always first gave away 47% of wins to home's 22% with
	# equal sides - away saw where home had just gone (WsgSim's balance flag; reversed, it flipped to level).
	var n := players.size()
	var flip := int(t * 30.0) % 2 == 1
	for k in n:
		_think(n - 1 - k if flip else k, dt)
	_ball(dt)


func _think(i: int, dt: float) -> void:
	var p: Dictionary = players[i]
	var team: int = p.team
	var goal := Vector3((HALF_L if team == 0 else -HALF_L), 0, 0)
	var own := Vector3((-HALF_L if team == 0 else HALF_L), 0, 0)
	var strat: String = cfg.strategy[team]
	var tgt: Vector3
	if holder == i:
		tgt = goal
		var d := Vector2(goal.x - p.pos.x, goal.z - p.pos.z).length()
		# (Not from inside the goal: a shot from under the bar went straight up, 30 m - WsgSim's first find here.)
		tgt = goal - Vector3(signf(goal.x) * 1.0, 0, 0)
		if d < 9.0 and d > 2.0 and rng.randf() < 0.05 * float(p.skill):
			_shoot(i, goal)
		elif rng.randf() < 0.01:
			_pass(i)
	elif holder >= 0 and int(players[holder].team) == team:
		tgt = (players[holder].pos as Vector3) + Vector3((4.0 if team == 0 else -4.0), 0, (i % 3 - 1) * 4.0)
	elif strat == "press" or (ball_pos - p.pos).length() < 6.0:
		tgt = Vector3(ball_pos.x, 0, ball_pos.z)
	else:
		tgt = own.lerp(Vector3(ball_pos.x, 0, ball_pos.z), 0.4) + Vector3(0, 0, (i % 3 - 1) * 3.0)
	if _bug == "wallclock" and Time.get_ticks_usec() % 2 == 1:
		tgt += Vector3(0, 0, 1.5)
	tgt = Vector3(clampf(tgt.x, -HALF_L - 1.5, HALF_L + 1.5), 0, clampf(tgt.z, -HALF_W - 0.5, HALF_W - 0.5))
	if i == fetcher:
		tgt = Vector3(fetch_spot.x, 0, fetch_spot.z)
		if _bug == "fetch_dither":
			# (Its side round the prop forgotten and chosen again each third of a second, the other way: Sepak Takraw's
			# fetcher, turning back and forth in front of a bench.)
			p.memo["side"] = 1.0 if int(t * 3.0) % 2 == 0 else -1.0
	p.target = solid.free_spot(tgt, R, H)
	var want: Vector3 = p.target - p.pos
	want.y = 0.0
	var v := want.normalized() * minf(float(p.speed), want.length() * 3.0) if want.length() > 0.05 else Vector3.ZERO
	# A player speeds up and slows down as people do (9 and 12 m/s/s), not from still to a sprint in a frame (that
	# left the locomotion's feet 13 to 19 cm behind each step: WsgSim's foot check).
	var asked := v
	var lim: float = (9.0 if v.length() > (p.vel as Vector3).length() else 12.0) * dt
	v = (p.vel as Vector3).move_toward(v, lim)
	if _bug == "stuck" and i == 0 and t > 10.0:
		v = Vector3.ZERO
	var to: Vector3
	if _bug == "through_bench" and i == 1:
		p.target = Vector3(0, 0, HALF_W + 2.5)
		to = p.pos + ((p.target as Vector3) - p.pos).normalized() * minf(float(p.speed) * dt, ((p.target as Vector3) - p.pos).length())
	else:
		to = solid.move(p.pos, v, dt, R, H, p.target, p.memo)[0]
	p.vel = (to - p.pos) / dt
	p.pos = to
	if p.vel.length() > 0.3:
		p.facing = atan2(p.vel.x, p.vel.z)
	if p.body:
		(p.body as WsgBody).position = p.pos
		# (The AI's asked-for velocity as the wanted one: given the body's own, a start from standing took the walk's
		# start clip up to a jog, its stride too short for the body, and the feet slid 3-5 cm a step.)
		(p.loco as WsgLocomotor).drive(dt, p.vel, p.facing, asked)
	# Picking the ball up.
	if holder < 0 and (Vector2(ball_pos.x - p.pos.x, ball_pos.z - p.pos.z)).length() < 0.6 and ball_pos.y < 0.6 \
			and not (i == _last_touch and t < _touch_until) and (fetcher < 0 or i == fetcher):
		if fetcher >= 0:
			# (Fetched: back in at the line, the other side's ball, as any ball gone out.)
			fetcher = -1
			fetch_spot = Vector3.INF
			ball_pos = Vector3(clampf(ball_pos.x, -HALF_L + 0.5, HALF_L - 0.5), BALL_R, clampf(ball_pos.z, -HALF_W + 0.5, HALF_W - 0.5))
			events.append({"type": "out", "to": 1 - team})
			return
		if holder != i:
			events.append({"type": "possession", "team": team})
		holder = i


func _shoot(i: int, goal: Vector3) -> void:
	var p: Dictionary = players[i]
	var aim := goal + Vector3(0, rng.randf_range(0.2, 2.4), rng.randf_range(-GOAL_W * 1.6, GOAL_W * 1.6))
	var from := (p.pos as Vector3) + Vector3(0, 0.5, 0)
	ball_pos = from
	var dir := (aim - from).normalized()
	dir.y = minf(dir.y, 0.35)
	ball_vel = dir.normalized() * rng.randf_range(14.0, 28.0) + Vector3(0, 2.0, 0)
	_shot_from = from
	holder = -1
	_last_touch = i
	_touch_until = t + 0.5
	events.append({"type": "shot", "team": p.team})


func _pass(i: int) -> void:
	var p: Dictionary = players[i]
	var mates := []
	for j in players.size():
		if j != i and int(players[j].team) == int(p.team):
			mates.append(j)
	var m: Dictionary = players[mates[rng.randi() % mates.size()]]
	ball_pos = (p.pos as Vector3) + Vector3(0, 0.3, 0)
	ball_vel = ((m.pos as Vector3) - (p.pos as Vector3)).normalized() * rng.randf_range(9.0, 14.0) + Vector3(0, 1.5, 0)
	holder = -1
	_last_touch = i
	_touch_until = t + 0.5
	events.append({"type": "pass", "team": p.team})


## The ball dead at SPOT (behind a prop), the nearest player sent for it: its index.
func fetch(spot: Vector3) -> int:
	holder = -1
	fetch_spot = spot
	ball_pos = spot + Vector3(0, BALL_R, 0)
	ball_vel = Vector3.ZERO
	var bd := INF
	for j in players.size():
		var d: float = (players[j].pos as Vector3).distance_to(spot)
		if d < bd:
			bd = d
			fetcher = j
	events.append({"type": "fetch", "who": fetcher})
	return fetcher


func _ball(dt: float) -> void:
	if fetch_spot != Vector3.INF and holder < 0:
		ball_pos = fetch_spot + Vector3(0, BALL_R, 0)
		ball_vel = Vector3.ZERO
		return
	if holder >= 0:
		var hp: Vector3 = players[holder].pos
		ball_pos = hp + Vector3(0.3 * sin(players[holder].facing), BALL_R, 0.3 * cos(players[holder].facing))
		ball_vel = Vector3.ZERO
		return
	var before := ball_pos
	ball_vel.y -= 9.8 * dt
	if _bug == "ball_through":
		ball_pos += ball_vel * dt
		if ball_pos.y < BALL_R:
			ball_pos.y = BALL_R
			ball_vel.y = absf(ball_vel.y) * 0.5
	else:
		var r := solid.bounce(ball_pos, ball_vel, BALL_R, dt)
		ball_pos = r.pos
		ball_vel = r.vel
	if ball_pos.y <= BALL_R + 0.01:
		ball_vel.x *= 0.985
		ball_vel.z *= 0.985
	# A goal: across the line between the posts, under the bar.
	for s in [-1.0, 1.0]:
		var line: float = s * HALF_L
		if signf(before.x - line) != signf(ball_pos.x - line) and absf(ball_pos.z) < GOAL_W and ball_pos.y < 2.0:
			var team := 0 if s > 0.0 else 1
			score[team] += 2 if _bug == "score_twice" else 1
			goals += 1
			events.append({"type": "goal", "team": team, "score": score.duplicate()})
			_kickoff(1 - team)
			return
	# Out of play: across a line elsewhere - back in at the line, the other side's ball (a ball flying on into the
	# bench and the table first: they are solid).
	if (absf(ball_pos.x) > HALF_L + 0.5 or absf(ball_pos.z) > HALF_W + 0.5) and (ball_pos.y < 0.2 or absf(ball_pos.z) > HALF_W + 3.0 or absf(ball_pos.x) > HALF_L + 3.0):
		var near := -1
		var bd := INF
		var restart := Vector3(clampf(ball_pos.x, -HALF_L + 0.5, HALF_L - 0.5), BALL_R, clampf(ball_pos.z, -HALF_W + 0.5, HALF_W - 0.5))
		for j in players.size():
			var d: float = (players[j].pos as Vector3).distance_to(restart)
			if d < bd:
				bd = d
				near = j
		ball_pos = restart
		ball_vel = Vector3.ZERO
		events.append({"type": "out", "to": int(players[near].team)})


func _kickoff(team: int) -> void:
	ball_pos = Vector3(0, BALL_R, 0)
	ball_vel = Vector3.ZERO
	holder = -1
	for j in players.size():
		if int(players[j].team) == team:
			holder = j
			players[j].pos = Vector3(-0.4 if team == 0 else 0.4, 0, 0)
			break


func _bugs() -> void:
	match _bug:
		"nan":
			if t > 5.0:
				ball_pos = Vector3(NAN, 0, 0)
		"script_error":
			if t > 3.0 and t < 3.0 + 1.0 / 30.0:
				var a: Array = []
				print(a[3])
		"clock_back":
			if t > 6.0 and t < 6.0 + 1.0 / 30.0:
				clock += 1.0
		"ball_through":
			# A hard shot at the bench, the ball moved without the props' sweep.
			if t > 2.0 and t < 2.0 + 1.0 / 30.0:
				holder = -1
				ball_pos = Vector3(0, 0.3, HALF_W - 1.0)
				ball_vel = Vector3(0, 0, 30.0)
		"freeze":
			if t > 2.0:
				while true:
					pass
