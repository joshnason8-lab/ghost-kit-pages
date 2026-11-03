extends WsgSimGame
## Floorball's side of WsgSim (the shared foundation's match simulator, ADOPTING 5.17): its matches built and played by
## the game's own match code (Match: its AI, ball, rules, players and the shared foundation's bodies), headless, on a
## fixed step, every random roll from the seed.
##   godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- batch --game res://game/sim.gd --out DIR --smoke
## (The results of matches the player does not see - a cup's other games - are ResultSim's, game/result_sim.gd.)

const MATCH := "res://game/match.gd"
const VENUES := ["arena", "hall", "school"]
## How long a goalkeeper may hold the ball (Rules 507.15: he must play it within three seconds; the game's own release
## comes well before - the owner's 0.9.7 note, "he releases and grabs over and over" - so this is the bug's bound).
const KEEPER_HOLD_MAX_S := 8.0

var m: Node = null
var _log_seen := 0
var _held := 0.0
var _last_t := -1.0


func game_name() -> String:
	return "floorball"


func scenarios() -> Array:
	return ["random", "extreme", "targeted:scoring", "targeted:overtime", "targeted:penalties", "targeted:completion"]


## A match's conditions, from RNG only: the teams (any two of the game's), men's or women's, the venue, the period's
## length (short: the batch's quick matches), the clock rule, the AI level and a knockout or not.
func config(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var ids: Array = DB.team_ids()
	var a: String = ids[rng.randi() % ids.size()]
	var b: String = a
	while b == a:
		b = ids[rng.randi() % ids.size()]
	var c := {"home": a, "away": b, "venue": VENUES[rng.randi() % VENUES.size()], "women": rng.randf() < 0.5,
		"period": [4.0, 8.0, 12.0, 20.0][rng.randi() % 4], "rules": rng.randi() % 2, "difficulty": rng.randi() % 4,
		"knockout": rng.randf() < 0.3, "user_team": -1, "demo": true, "mode": "quick"}
	match kind:
		"extreme":
			# The strongest side against the weakest, the longest periods, the hardest AI.
			var by := ids.duplicate()
			by.sort_custom(func(x, y): return DB.rating(x) > DB.rating(y))
			c.home = by[0]
			c.away = by[-1]
			c.period = 20.0
			c.difficulty = 3
			c.knockout = true
		"targeted:scoring":
			c.period = 3.0
		"targeted:overtime":
			# Two sides alike, short periods, a knockout: overtime and penalty shots come often.
			c.away = c.home
			while c.away == c.home:
				c.away = ids[rng.randi() % ids.size()]
			c.knockout = true
			c.period = 2.0
		"targeted:penalties":
			c.difficulty = 3
			c.period = 3.0
		"targeted:completion":
			c.knockout = true
			c.period = 2.0
	return c


func start(cfg: Dictionary, seed: int, tree: SceneTree) -> Node:
	var c := cfg.duplicate(true)
	c["seed"] = seed
	if bool(c.get("short", false)):
		c.period = minf(float(c.get("period", 4.0)), 2.0)   # every rule as it is, the periods shortened
	m = (load(MATCH) as Script).new()
	m.config = c
	_log_seen = 0
	_held = 0.0
	_last_t = -1.0
	_ball_last = Vector3.INF
	tree.root.add_child(m)
	return m


## The clock as shown, run on across the periods (each period's starts at 0 on the board; here they add up, so the
## clock only ever goes forward).
func _clock() -> float:
	var r = m.rules
	var p: int = int(r.period)
	var before := float(p - 1) * float(r.period_s) if p <= Rules.PERIODS else float(Rules.PERIODS) * float(r.period_s)
	return before + float(r.clock)


func state() -> Dictionary:
	if m == null or not is_instance_valid(m) or m.rules == null:
		return {}
	var b = m.ball
	var poss := -1
	if b and b.carrier != null:
		poss = int(b.carrier.team)
	elif b and b.held_by != null:
		poss = int(b.held_by.team)
	return {"score": (m.rules.goals as Array).duplicate(), "clock": _clock(), "clock_running": bool(m.clock_live),
		"phase": "%s/%s p%d" % [m.phase, m.rules.phase, int(m.rules.period)], "possession": poss,
		"finished": String(m.phase) == "done_sent", "shots": (m.rules.shots as Array).duplicate()}


func events() -> Array:
	if m == null or not is_instance_valid(m) or m.rules == null:
		return []
	var lg: Array = m.rules.log
	var out := []
	for i in range(_log_seen, lg.size()):
		var e: Dictionary = (lg[i] as Dictionary).duplicate()
		e["type"] = String(e.get("kind", "event"))
		out.append(e)
	_log_seen = lg.size()
	return out


func _name(p) -> String:
	return "ref%d" % m.refs.find(p) if int(p.team) < 0 else "%d:%s%d" % [int(p.team), String(p.role), int(p.slot)]


func bodies() -> Array:
	if m == null or not is_instance_valid(m):
		return []
	var out := []
	var live: bool = String(m.phase) == "live"
	for p in m.everyone():
		var body: WsgBody = p.link.body if p.link != null else null
		out.append({"name": _name(p), "pos": Vector3(p.pos.x, 0.0, p.pos.y), "radius": Player.BODY_R,
			"height": 1.9, "body": body if p.visible else null,
			"active": live and p.visible and bool(p.on_rink) and not bool(p.in_box), "target": Vector3.INF})
	return out


## The ball. "live" (in free flight, so its path is checked against the props) as the prop audit has it
## (game/prop_runs.gd): not on a blade or in a goalkeeper's hands (it is carried with them, not flown), not put
## somewhere new (a restart's spot), and in play.
func ball() -> Dictionary:
	if m == null or not is_instance_valid(m) or m.ball == null:
		return {}
	var b = m.ball
	var flying: bool = bool(b.live) and String(m.phase) == "live" and b.carrier == null and b.held_by == null \
		and (_ball_last == Vector3.INF or b.pos.distance_to(_ball_last) <= 2.0)
	_ball_last = b.pos
	return {"pos": b.pos, "radius": Ball.R, "live": flying}


var _ball_last := Vector3.INF


func solid() -> WsgSolidProps:
	if m == null or not is_instance_valid(m) or m.arena == null:
		return null
	return m.arena.solid


## The hall: the rink (40 x 20 m) with its benches, stands and walls round it; the ball may fly up to the roof.
func bounds() -> AABB:
	return AABB(Vector3(-45, -1, -35), Vector3(90, 30, 70))


func score_steps() -> Array:
	return [1]


## Three periods of effective time (the clock stops when the ball is out), two intervals, ten minutes' overtime and the
## penalty shots: at most three times the periods' time, and twenty minutes more.
func max_seconds(cfg: Dictionary) -> float:
	var per := float(cfg.get("period", 4.0)) * 60.0
	if bool(cfg.get("short", false)):
		per = minf(per, 120.0)
	return per * Rules.PERIODS * 3.0 + 1200.0


## Floorball's own rules, every frame: never more than six of a side on the rink (five and the goalkeeper, or six
## skaters with the net empty), the score the goals logged, and a goalkeeper never holding the ball for long (the
## owner's 0.9.7 note: he grabbed and released it over and over, never letting go).
func rules() -> Array:
	if m == null or not is_instance_valid(m) or m.rules == null:
		return []
	var bad := []
	var now: float = float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)
	var dt := 0.0 if _last_t < 0.0 else now - _last_t
	_last_t = now
	if String(m.phase) == "live":
		for t in 2:
			var n := 0
			for p in m.players[t]:
				if p.visible and p.on_rink and not p.in_box:
					n += 1
			if n > 6:
				bad.append("team %d has %d players on the rink" % [t, n])
	var logged := [0, 0]
	for e: Dictionary in m.rules.log:
		if String(e.get("kind", "")) == "goal":
			logged[int(e.team)] += 1
	if logged != (m.rules.goals as Array):
		bad.append("the score %s is not the goals logged %s" % [m.rules.goals, logged])
	if m.ball and m.ball.held_by != null and String(m.phase) == "live":
		_held += dt
		if _held > KEEPER_HOLD_MAX_S:
			bad.append("a goalkeeper has held the ball %.1f s" % _held)
	else:
		_held = 0.0
	return bad


func result() -> Dictionary:
	if m == null or not is_instance_valid(m):
		return {}
	var r: Dictionary = m.result()
	return {"winner": int(r.winner), "score": r.goals, "ot": bool(r.ot), "so": bool(r.so), "shots": m.rules.shots,
		"penalties": (r.calls as Array).filter(func(c): return String(c.get("kind", "")).begins_with("pen")).size()}


func balance_keys(cfg: Dictionary) -> Dictionary:
	var women := bool(cfg.get("women", false))
	var d := absf(DB.team_rating(String(cfg.home), women) - DB.team_rating(String(cfg.away), women))
	return {"fair": d < 2.0, "venue": String(cfg.get("venue", "hall")), "women": women, "knockout": bool(cfg.get("knockout", false))}


func stop() -> void:
	if m != null and is_instance_valid(m):
		m.queue_free()
	m = null


func paused() -> int:
	if m == null or not is_instance_valid(m):
		return -1
	return 1 if bool(m.paused) else 0


func human_team() -> int:
	if m == null or not is_instance_valid(m):
		return -1
	return int(m.user_team)
