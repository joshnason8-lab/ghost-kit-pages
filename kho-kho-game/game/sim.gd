extends WsgSimGame
## Kho Kho Rush's side of WsgSim (the shared match simulator, ADOPTING 5.17): real matches of game/match.gd - its AI,
## its movement, its rules, its umpire and timekeeper - played headless from a seed, checked every frame by the
## foundation's generic checks and kho kho's own laws (tests/kho_rules_check.gd, as match_sim's KK_CHECK=1 runs them).
## Built on what match_sim already does: the same match, the same config keys; no second copy of the game.
##   godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- run --kind random --seeds 5

const VENUES := ["maidan", "school", "arena", "floodlit"]
const CHECK := "res://tests/kho_rules_check.gd"

var m: Node = null
var cfg := {}
var _chk: RefCounted = null
var _seen := 0                 # match log entries already given out as events
var _phase := ""
var _rng := RandomNumberGenerator.new()   # the person's answers the match asks for (follow on?), from the seed
var _fails_given := 0


func game_name() -> String:
	return "Kho Kho Rush"


## random: anything; extreme: the strongest side against the weakest, the shortest and longest turns, hardest AI;
## targeted: one law each, hard.
##   timer       - turns of 20 to 45 s: the clock, turn ends, innings and the result decided by time
##   scoring     - a strong chasing side against a weak one: outs, batches coming on, all out, the follow-on
##   dream       - the fast game, its defenders far stronger: dream-run points (a batch three minutes on the field)
##   fouls       - the classic game on the hardest level, every foul the umpire can call
##   collisions  - the school ground (its tables, benches, canopy) with you defending: bodies against props and men
##   completion  - turns of 5 s: a match that must still end, in its turns
##   fair        - two sides of equal rating: the balance report's 50/50
##   human       - your side, played through your own touch controls by WsgSimInput
func scenarios() -> Array:
	return ["random", "extreme", "targeted:timer", "targeted:scoring", "targeted:dream", "targeted:fouls",
		"targeted:collisions", "targeted:completion", "targeted:fair", "targeted:human"]


func _teams() -> Array:
	return DB.nation_ids() + DB.state_ids()


func config(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var ids := _teams()
	ids.sort()   # (the same pick for the same seed, whatever order the data lists them in)
	var home: String = ids[rng.randi() % ids.size()]
	var away: String = home
	while away == home:
		away = ids[rng.randi() % ids.size()]
	var fmt := KhoRules.FAST if rng.randf() < 0.5 else KhoRules.CLASSIC
	var c := {"home": home, "away": away, "venue": VENUES[rng.randi() % VENUES.size()], "format": fmt,
		"turn_len": [90.0, 120.0, 180.0, KhoRules.real_turn(fmt)][rng.randi() % 4], "user_team": -1,
		"difficulty": rng.randi() % 4, "chase_first": rng.randi() % 2, "follow_on": rng.randf() < 0.5,
		"powerplay": rng.randf() < 0.7, "women": rng.randf() < 0.25, "knockout": rng.randf() < 0.3,
		"gfx": [0, 0, 1, 2][rng.randi() % 4], "mode": "quick", "test": true}
	if rng.randf() < 0.2:
		c.user_team = rng.randi() % 2
	match kind:
		"extreme":
			ids.sort_custom(func(a, b): return DB.team_rating(a) < DB.team_rating(b))
			c.home = ids[0]
			c.away = ids[ids.size() - 1]
			if rng.randf() < 0.5:
				var t: String = c.home
				c.home = c.away
				c.away = t
			c.turn_len = [30.0, KhoRules.real_turn(fmt)][rng.randi() % 2]
			c.difficulty = 3 if rng.randf() < 0.5 else 0
			c.knockout = true
		"targeted:timer":
			c.turn_len = rng.randf_range(20.0, 45.0)
		"targeted:scoring":
			ids.sort_custom(func(a, b): return DB.team_rating(a) < DB.team_rating(b))
			c.home = ids[ids.size() - 1 - rng.randi() % 3]
			c.away = ids[rng.randi() % 3]
			c.format = KhoRules.CLASSIC
			c.follow_on = true
			c.turn_len = 150.0
		"targeted:dream":
			ids.sort_custom(func(a, b): return DB.team_rating(a) < DB.team_rating(b))
			c.home = ids[rng.randi() % 3]
			c.away = ids[ids.size() - 1 - rng.randi() % 3]
			c.format = KhoRules.FAST
			c.turn_len = KhoRules.real_turn(KhoRules.FAST)
		"targeted:fouls":
			c.format = KhoRules.CLASSIC
			c.difficulty = 3
			c.turn_len = 120.0
		"targeted:collisions":
			c.venue = "school"
			c.user_team = rng.randi() % 2
			c.turn_len = 90.0
		"targeted:completion":
			c.turn_len = 5.0
		"targeted:fair":
			var by := {}
			for id in ids:
				var r := DB.team_rating(id)
				if not by.has(r):
					by[r] = []
				(by[r] as Array).append(id)
			var pairs := []
			for r in by:
				if (by[r] as Array).size() >= 2:
					pairs.append(by[r])
			pairs.sort_custom(func(a, b): return String(a[0]) < String(b[0]))
			if not pairs.is_empty():
				var p: Array = pairs[rng.randi() % pairs.size()]
				c.home = p[0]
				c.away = p[1]
			c.turn_len = 150.0
		"targeted:human":
			c.user_team = rng.randi() % 2
			c.turn_len = 120.0
	return c


## The match as a Start builds it (Match: config, built in its stages, kick_off), every roll from the seed.
func start(p_cfg: Dictionary, seed: int, tree: SceneTree) -> Node:
	cfg = p_cfg
	_rng.seed = seed + 104729
	Game.main = tree.root
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.graphics = int(cfg.get("gfx", 0))
	var c := cfg.duplicate()   # (the config as given stays as it is: it is what a replay starts from)
	c.seed = seed
	c.turn_len = _turn_len(cfg)
	m = (load("res://game/match.gd") as Script).new()
	m.config = c
	tree.root.add_child(m)
	var guard := 0
	while not bool(m.built) and guard < 600:
		await tree.process_frame
		guard += 1
	_chk = (load(CHECK) as Script).new(m)
	_seen = 0
	_fails_given = 0
	_phase = ""
	return m


func _answer() -> void:
	# What a person is asked mid-match: "Next turn" at the interval; follow on or not (a choice drawn from the seed).
	if m.phase == "interval" and m.hud and m.hud._interval:
		m.hud._interval.queue_free()
		m.hud._interval = null
		m.next_turn()
	elif m.phase == "choose":
		m.choose_follow_on(_rng.randf() < 0.5)


func state() -> Dictionary:
	if not is_instance_valid(m):
		return {"finished": true}
	_answer()
	var running: bool = m.phase == "play" and not bool(m.paused) and not (m.replay and m.replay.playing())
	return {"score": (m.score as Array).duplicate(), "clock": float(m.clock), "clock_running": running,
		"phase": "%s %d" % [m.phase, int(m.turn)], "possession": int(m.chasing), "finished": m.phase == "over",
		"outs": int(m._turn_out_count), "dream_paid": int(m.dream_paid)}


func events() -> Array:
	if not is_instance_valid(m):
		return []
	var out := []
	var log: Array = m.log
	while _seen < log.size():
		var e: Dictionary = (log[_seen] as Dictionary).duplicate()
		e["type"] = String(e.get("kind", ""))
		out.append(e)
		_seen += 1
	if String(m.phase) != _phase:
		_phase = String(m.phase)
		out.append({"type": "phase", "phase": _phase, "turn": int(m.turn)})
	return out


func bodies() -> Array:
	var out := []
	if not is_instance_valid(m):
		return out
	var walking: Dictionary = m._to_square
	for a: Athlete in m.everyone():
		if not is_instance_valid(a) or not a.is_inside_tree():
			continue
		var tgt := Vector3.INF
		if a.goal != Vector3.INF:
			tgt = a.goal                    # walking off the field, to his bench or place
		elif walking.has(a):
			tgt = Vector3(float(m.f.square_x[int(walking[a])]), 0, 0)   # to his square
		var wb: WsgBody = a.link.body if a.link != null else null
		out.append({"name": _who(a), "pos": a.position, "radius": Athlete.BODY_R, "height": 1.8, "body": wb,
			"active": m.phase == "play" and not bool(m.paused), "target": tgt})
	return out


## A body by its side, its part and its shirt number ("away defender 7", "umpire"): a failure's signature (its message,
## numbers out) then groups the same fault across matches, whoever the players are.
func _who(a: Athlete) -> String:
	if a.side < 0:
		for k in m.officials:
			if m.officials[k] == a:
				return String(k)
		return "official"
	var part := "defender" if a.side != int(m.chasing) else "chaser"
	return "%s %s %d" % [["home", "away"][a.side], part, int(a.data.get("num", 0))]


func solid() -> WsgSolidProps:
	return m.arena.solid if is_instance_valid(m) and m.arena else null


func bounds() -> AABB:
	# The ground and its surrounds (the benches, the scorers' table, the stands): as the rules check's own limit.
	var L := 60.0
	var W := 40.0
	if is_instance_valid(m) and m.f:
		L = float(m.f.length) + 30.0
		W = float(m.f.width) + 30.0
	return AABB(Vector3(-L, -1.0, -W), Vector3(2.0 * L, 30.0, 2.0 * W))


## An out: 1 (classic) or 2 (fast); a dream run's points come one at a time.
func score_steps() -> Array:
	return [1, 2]


## A turn's length as played: a shortened match's (the length mix) a quarter as long, at least 30 s, every law the same.
static func _turn_len(c: Dictionary) -> float:
	var tl := float(c.get("turn_len", 180.0))
	if bool(c.get("short", false)) and tl > 30.0:
		tl = maxf(tl * 0.25, 30.0)
	return tl


## Every turn at its length, with the breaks between, the follow-on's and knockouts' extra innings, and room to spare.
func max_seconds(c: Dictionary) -> float:
	return 8.0 * (_turn_len(c) + 25.0) + 120.0


func rules() -> Array:
	if _chk == null or not is_instance_valid(m):
		return []
	_chk.frame(m.get_process_delta_time())
	var out := []
	var fails: Array = _chk.fails
	while _fails_given < fails.size():
		var f: Dictionary = fails[_fails_given]
		out.append("%s: %s (turn %d, %s)" % [f.rule, f.detail, f.turn, f.phase])
		_fails_given += 1
	return out


func result() -> Dictionary:
	if not is_instance_valid(m):
		return {}
	var s: Array = m.score
	return {"winner": 0 if s[0] > s[1] else (1 if s[1] > s[0] else -1), "score": s.duplicate(), "turns": int(m.turn) + 1,
		"format": "fast" if int(cfg.format) == KhoRules.FAST else "classic"}


func balance_keys(c: Dictionary) -> Dictionary:
	var rh := DB.team_rating(String(c.home), bool(c.get("women", false)))
	var ra := DB.team_rating(String(c.away), bool(c.get("women", false)))
	return {"fair": rh == ra, "format": "fast" if int(c.format) == KhoRules.FAST else "classic",
		"chase_first": "home" if int(c.chase_first) == 0 else "away", "venue": String(c.venue),
		"stronger": "home" if rh > ra else ("away" if ra > rh else "even"), "difficulty": int(c.get("difficulty", 1))}


func stop() -> void:
	if is_instance_valid(m):
		m.queue_free()
	m = null
	_chk = null


func human_team() -> int:
	return int(cfg.get("user_team", -1))


func input_actions() -> Array:
	return []   # (the game reads its own touch controls and keys, not the InputMap)


## The touch joystick, as the thumb gives it.
func stick(v: Vector2) -> bool:
	if is_instance_valid(m) and m.controls:
		m.controls.joystick = v.limit_length(1.0)
		return true
	return false


func cameras() -> Array:
	return [Game.CAM_TV, Game.CAM_CLOSE, Game.CAM_POLE]


func set_camera(i: int) -> void:
	if is_instance_valid(m):
		m._cam_mode = [Game.CAM_TV, Game.CAM_CLOSE, Game.CAM_POLE][posmod(i, 3)]


func menu_start(tree: SceneTree) -> Node:
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	return main


func in_match() -> bool:
	return Game.current != null and is_instance_valid(Game.current) and Game.current.has_method("kick_off")


func save_paths() -> Array:
	return [Game.SETTINGS_PATH, Game.CUP_PATH, Game.RECORDS_PATH]
