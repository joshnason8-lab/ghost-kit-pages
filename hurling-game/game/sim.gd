extends WsgSimGame
## Hurling's adapter for the shared foundation's match simulator (WsgSim, ADOPTING §5.17): thousands of seeded
## matches on the game's own code - the match, its AI, the ball, the rules, the bodies - headless and faster than
## real time, each failure replayable from its seed.
##   sh tools/wsg/sim_shard.sh . "$OUT" --smoke --input
## Built on what the game's own sims do (tests/match_sim.gd, user_bot.gd): a match made as Game makes one, with its
## seed; every random roll of play from the match's rng.

var m: Node = null
var host: Node = null
var cfg := {}
var _ev := 0                 # how many of the match's events have been handed on
var _phase_names := {}
var _seed := 0
var _sampled := false        # the sampled pose laid on (WsgBody.set_sim_full), once every body is made
## The sampled pose (the harness's default; its --full-pose: set false before start for every body in full).
var sampled_pose := not OS.get_cmdline_user_args().has("--full-pose")


func game_name() -> String:
	return "Hurling Heroes"


func scenarios() -> Array:
	return ["random", "extreme", "targeted:scoring", "targeted:timer", "targeted:completion", "targeted:collisions",
		"targeted:fair", "targeted:human"]


## One match's conditions, from rng only: the two counties, the ground, the AI's level, the match's length, a
## knock-out (extra time and penalties), the side a person plays.
func config(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var ids: Array = DB.counties_ranked()
	var a := rng.randi() % ids.size()
	var b := (a + 1 + rng.randi() % (ids.size() - 1)) % ids.size()
	var c := {"home": ids[a], "away": ids[b], "venue": ["parish", "county", "stadium"][rng.randi() % 3],
		"difficulty": rng.randi() % 3, "length": [8.0, 14.0, 20.0][rng.randi() % 3], "knockout": rng.randf() < 0.3,
		"user_team": 0 if rng.randf() < 0.3 else -1, "camera": rng.randi() % 3,
		# (The graphics level changes nothing in play - the crowd, detail, shadows - but every level's code runs.)
		"graphics": [0, 0, 1, 2][rng.randi() % 4]}
	match kind:
		"extreme":
			# The strongest against the weakest, either way round; the shortest and the longest match.
			c.home = ids[0] if rng.randf() < 0.5 else ids[-1]
			c.away = ids[-1] if c.home == ids[0] else ids[0]
			c.length = [4.0, 35.0][rng.randi() % 2]
			c.difficulty = [0, 2][rng.randi() % 2]
		"targeted:scoring":
			# Two of the best attacks, the hardest AI: the most scores, goals and frees.
			c.home = ids[0]
			c.away = ids[1]
			c.difficulty = 2
			c.length = 8.0
		"targeted:timer":
			c.length = rng.randf_range(2.0, 4.0)
		"targeted:completion":
			# A knock-out between equals, short: draws go to extra time and the shoot-out.
			c.home = ids[2]
			c.away = ids[3]
			c.knockout = true
			c.length = 3.0
		"targeted:collisions":
			# The parish field: the rail, the dugouts, the ball-stop nets closest to play.
			c.venue = "parish"
			c.length = 6.0
		"targeted:fair":
			c.home = ids[4]
			c.away = ids[5]
			c.difficulty = 1
		"targeted:human":
			c.user_team = 0
			c.length = 6.0
	return c


func start(config: Dictionary, seed: int, tree: SceneTree) -> Node:
	cfg = config.duplicate()
	# The length mix: a shortened match has halves a quarter as long, and lasts a quarter as long, so its clock runs
	# at a normal match's pace; every rule the same.
	if bool(cfg.get("short", false)):
		cfg.half = Rules.half_minutes(0) * 0.25
		cfg.length = maxf(float(cfg.length) * 0.25, 2.0)
	host = Node.new()
	host.name = "SimHost"
	tree.root.add_child(host)
	Game.main = host
	Game.settings.sound = false
	Game.settings.camera = int(cfg.get("camera", Game.CAM_TV))
	Game.settings.graphics = int(cfg.get("graphics", Game.GFX_LOW))
	var user := int(cfg.get("user_team", -1))
	var mcfg := {"home": cfg.home, "away": cfg.away, "venue": cfg.venue, "user_team": user, "seed": seed,
		"length": float(cfg.length), "difficulty": int(cfg.difficulty), "knockout": bool(cfg.knockout),
		"mode": "quick" if user >= 0 else "watch"}
	if cfg.has("half"):
		mcfg.half = float(cfg.half)
	m = load("res://game/match.gd").new()
	m.config = mcfg
	Game.current = m
	host.add_child(m)
	_ev = 0
	_seed = seed
	_sampled = false
	for k in m.P:
		_phase_names[int(m.P[k])] = String(k)
	return host


func _total(s: Array) -> int:
	return Rules.total(int(s[0]), int(s[1]))


## The score as points (a goal is three), and the clock as the score bug shows it - the match's own watch moves on
## by a stoppage's cost at once, which the bug runs up to (the owner's "a large time jump").
func state() -> Dictionary:
	var c: Array = m.score
	var shown: float = m.hud._shown_clock if m.hud and float(m.hud._shown_clock) >= 0.0 else float(m.clock)
	return {"score": [_total(c[0]), _total(c[1])], "clock": shown,
		"clock_running": m.phase == m.P.LIVE and not bool(m.paused),
		"phase": "%s %d" % [_phase_names.get(int(m.phase), str(m.phase)), int(m.half)],
		"possession": int(m.carrier.team) if m.carrier != null and is_instance_valid(m.carrier) else -1,
		"finished": m.phase == m.P.OVER}


func events() -> Array:
	var all: Array = m.events
	var out := all.slice(_ev)
	_ev = all.size()
	return out


## Every player and official on the field; where each means to go (from what his brain asked of his legs).
## (Always the same list, in the same order: the harness follows a quarter of them by their place in it. A body
## not drawn yet - posed for the first time when the camera first sees it - is listed without its WsgBody: its rest
## pose is no pose.)
func bodies() -> Array:
	var out := []
	var live: bool = m.phase in [m.P.LIVE, m.P.THROW_IN]
	var people: Array = m.all_players() + m.officials.people
	if not _sampled and sampled_pose:
		# The sampled pose (ADOPTING §5.17), as the harness lays it on bodies it is given at the start, but on all of
		# them, drawn yet or not: a quarter posed in full, a different quarter each seed.
		_sampled = true
		for bi in people.size():
			var lk: FoundationLink = (people[bi] as Player).link
			if lk:
				lk.body.set_sim_full(bi % 4 == _seed % 4)
	for p in people + m._leaving:
		var pl := p as Player
		if not is_instance_valid(pl):
			continue
		var w := Vector3(pl.want_vel.x, 0, pl.want_vel.z)
		var tgt := pl.global_position + w.normalized() * 3.0 if w.length() > 1.0 else Vector3.INF
		var b := {"name": "%s %d" % [pl.role if pl.role != "" else ["home", "away"][pl.team], pl.num],
			"pos": pl.global_position, "radius": Player.BODY_R, "height": 1.8,
			"body": pl.link.body if pl.visible and pl.link and pl.link.body.is_visible_in_tree() else null, "active": live and not pl.down(float(m.now)) and pl.role == "",
			"target": tgt}
		# (An official's signal raises the arms out from the sides, straight - a wide's both arms up to cross overhead
		# pass through a T and an A on the way: by design, counted, not failed.)
		if pl.role != "" and String(pl.action).begins_with("sig_"):
			b["pose_excuse"] = "an official's signal (%s): arms raised straight out from the sides" % String(pl.action).trim_prefix("sig_")
		out.append(b)
	return out


func ball() -> Dictionary:
	# (Not live while a score or a wide is shown again: Replay puts the ball where it was, a jump over whatever is
	# between - the parish ground's low wall behind the goal read as the ball gone through it, seeds 2, 3 and 4.)
	return {"pos": m.ball.global_position, "radius": Sliotar.RADIUS,
		"live": (m.ball.state == Sliotar.FREE or m.ball.state == Sliotar.OUT) and not _replaying()}


func _replaying() -> bool:
	return m.replay != null and m.replay.playing


## The fetch-behind-prop case: the ball dead at SPOT, behind one of the ground's big props, and the nearest outfield
## man sent for it (Match.send_fetch), round the props by their path, as he would run for it.
func fetch(spot: Vector3) -> Dictionary:
	var pl: Player = m.send_fetch(spot)
	if pl == null:
		return {}
	# (The time his way round takes at his top speed, and half as long again - a stand's length is a long way round
	# to its back - never less than the foundation's own.)
	var secs := maxf(WsgSim.FETCH_S, m.fetch_way_length() / pl.top_speed() * 1.5 + 3.0)
	return {"who": "%s %d" % [["home", "away"][pl.team], pl.num], "seconds": secs, "arrive": WsgSim.FETCH_ARRIVE_M}


func solid() -> WsgSolidProps:
	return m.stadium.solid


## The ground's whole bowl: the pitch, its surrounds and stands, and the sky a sliotar is struck into.
func bounds() -> AABB:
	var x := Pitch.HALF_L + 60.0
	var z := Pitch.HALF_W + 60.0
	return AABB(Vector3(-x, -1.0, -z), Vector3(x * 2.0, 90.0, z * 2.0))


func score_steps() -> Array:
	return [1, 3]


## The most simulated time a match may take: its length, the shoot-out and the breaks, with room.
func max_seconds(config: Dictionary) -> float:
	var l := float(config.get("length", 14.0))
	if bool(config.get("short", false)):
		l = maxf(l * 0.25, 2.0)
	return l * 60.0 * (2.2 if bool(config.get("knockout", false)) else 1.6) + 180.0


## Hurling's own rules, every frame.
func rules() -> Array:
	var out := []
	# The score bug is the scores: every goal and point on it was scored (the match's events), none lost or doubled.
	var tally := [[0, 0], [0, 0]]
	for e in m.events:
		var k := String(e.get("kind", ""))
		if k == "goal":
			tally[int(e.team)][0] += 1
		elif k == "point":
			tally[int(e.team)][1] += 1
	for t in 2:
		if tally[t][0] != int(m.score[t][0]) or tally[t][1] != int(m.score[t][1]):
			out.append("side %d's score %s is not what was scored (%s)" % [t, Rules.fmt(m.score[t][0], m.score[t][1]), Rules.fmt(tally[t][0], tally[t][1])])
	# Fifteen a side at most on the field; a man sent off or in the sin bin is not on it.
	for t in 2:
		var on := 0
		for p in m.teams[t].players:
			var pl := p as Player
			if pl.visible and pl.on_pitch():
				on += 1
			if pl.visible and pl.sent_off and m.phase in [m.P.LIVE, m.P.THROW_IN]:
				out.append("side %d's %d plays on though sent off" % [t, pl.num])
		if on > 15:
			out.append("side %d has %d on the field" % [t, on])
	# The ball: held only by a man on the field; never carried in the hand more than four steps (the sim's tally of
	# steps resets with a bounce, a toss onto the hurley or a pass).
	if m.carrier != null and is_instance_valid(m.carrier):
		var c := m.carrier as Player
		if not c.visible or not c.on_pitch():
			out.append("the ball is held by %d, who is not on the field" % c.num)
		if m.phase == m.P.LIVE and c.ball_hand:
			var steps := int(m.carry_of(c).steps)
			if steps > 6:
				out.append("%d has run %d steps with the ball in his hand (four are allowed)" % [c.num, steps])
	# The watch: never past the half and what was added by more than the last play's grace.
	if m.phase in [m.P.LIVE, m.P.THROW_IN] and float(m.clock) > m.half_len_now() + float(m.added) + 120.0:
		out.append("half %d runs on %.0f s past its time" % [m.half, float(m.clock) - m.half_len_now() - float(m.added)])
	return out


func result() -> Dictionary:
	var a := _total(m.score[0])
	var b := _total(m.score[1])
	var w := 0 if a > b else (1 if b > a else -1)
	var so: Dictionary = m.shootout
	if w < 0 and so.has("goals") and so.has("taken"):
		w = int(Rules.shootout_winner(so.goals, so.taken))
	return {"winner": w, "score": [a, b]}


func balance_keys(config: Dictionary) -> Dictionary:
	var ids: Array = DB.counties_ranked()
	var gap: int = ids.find(config.away) - ids.find(config.home)     # (positive: the home side is the stronger)
	return {"fair": absi(gap) <= 1, "gap": "%+d" % clampi(gap / 3 * 3, -9, 9), "venue": config.venue,
		"difficulty": config.difficulty, "human": int(config.user_team) >= 0}


func stop() -> void:
	if is_instance_valid(m):
		m.queue_free()
	if is_instance_valid(host):
		host.queue_free()
	if Game.current == m:
		Game.current = null
	m = null
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- a person

func human_team() -> int:
	return int(cfg.get("user_team", -1))


## The buttons as actions (TouchControls.ACTIONS: the first to fourth button showing, SWITCH) and Back.
func input_actions() -> Array:
	return TouchControls.ACTIONS + ["ui_cancel"]


## The game's own touch joystick.
func stick(v: Vector2) -> bool:
	if m == null or not is_instance_valid(m) or m.controls == null:
		return false
	m.controls.joystick = v
	return true


func cameras() -> Array:
	return [Game.CAM_TV, Game.CAM_HIGH, Game.CAM_END]


func set_camera(i: int) -> void:
	if m != null and is_instance_valid(m) and m.cam != null:
		m.cam.mode = cameras()[i % 3]


func menu_start(tree: SceneTree) -> Node:
	host = Node.new()
	host.name = "SimMenus"
	tree.root.add_child(host)
	Game.main = host
	Game.settings.sound = false
	Game.goto_menu()
	return host


func in_match() -> bool:
	return Game.current != null and is_instance_valid(Game.current) and Game.current.has_method("is_watch")


func save_paths() -> Array:
	return [Game.SETTINGS_PATH, Game.CHAMP_PATH, Game.RECORDS_PATH]
