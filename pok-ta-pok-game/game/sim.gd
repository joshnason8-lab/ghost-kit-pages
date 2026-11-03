extends WsgSimGame
## Pok Ta Pok Rivals for the shared match simulator (WsgSim, ADOPTING §5.17; docs/SIM.md): the real match (Match, its
## TeamAI, Ball.simulate, Court, the props, the bodies), built from a seed, played headless step by step; the sport's
## own checks every step (RuleChecks); a human side played through the game's own touch layer when asked.
##   sh tools/wsg/sim_shard.sh . "$OUT" --smoke --input

const LENGTHS := [0.0, 6.0, 10.0]      # the menus' match lengths (minutes of play; 0: to eight rayas)
const SHORT_LENGTH := 2.0              # a shortened match (config.short): two minutes, every rule the same

var m: Node = null
var _main: Node = null
var _rc: RuleChecks = null
var _events: Array = []
var _logged := 0
var _menu_root: Node = null


func game_name() -> String:
	return "Pok Ta Pok Rivals"


func scenarios() -> Array:
	return ["random", "extreme", "targeted:scoring", "targeted:timer", "targeted:possession", "targeted:collisions",
		"targeted:completion", "targeted:ring", "targeted:copal", "targeted:fair"]


func config(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var venue: String = DB.VENUE_ORDER[rng.randi() % DB.VENUE_ORDER.size()]
	var rules := String(DB.VENUES[venue].rules)
	var teams: Array = DB.teams_for(rules)
	var home: String = teams[rng.randi() % teams.size()]
	var away: String = teams[rng.randi() % teams.size()]
	while away == home:
		away = teams[rng.randi() % teams.size()]
	var sides: Array = Rules.side_sizes(rules)
	var c := {"home": home, "away": away, "venue": venue, "rules": rules, "side": sides[rng.randi() % sides.size()],
		"length": LENGTHS[rng.randi() % LENGTHS.size()], "urria": ["3_7", "3_5_7", "none"][rng.randi() % 3],
		"levels": [rng.randi_range(0, 2), rng.randi_range(0, 2)], "ritual": rng.randf() < 0.3,
		"graphics": [Game.GFX_LOW, Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH][rng.randi() % 4],
		"user_team": 0 if rng.randf() < 0.35 else -1}   # a person's side (WsgSimInput plays it with --input; idle without)
	match kind:
		"extreme":
			c.levels = [0, 2] if rng.randf() < 0.5 else [2, 0]
			c.side = sides[0] if rng.randf() < 0.5 else sides[-1]
			c.length = [1.0, 15.0][rng.randi() % 2]
		"targeted:scoring":
			c.levels = [0, 0]           # the weakest: rayas come quickest
		"targeted:timer":
			c.length = rng.randf_range(0.5, 2.0)   # time runs out: the holder wins, or level, the next raya (R14)
		"targeted:possession":
			c.length = 3.0              # serve after serve: the last raya's side serves (R11)
		"targeted:collisions":
			c.venue = ["village", "festival"][rng.randi() % 2]   # the most props round an earth court
			c.rules = Rules.ULAMA
			c.home = "ESC"
			c.away = "LLA"
			c.levels = [2, 2]
		"targeted:completion":
			c.length = 0.0              # to eight rayas, urria and all
			c.urria = "none"
			c.levels = [0, 2]
		"targeted:ring":
			c.venue = "stone"
			c.rules = Rules.CLASSIC
			c.home = "PIS"
			c.away = "VAL"
			c.levels = [2, 2]
			c.length = 4.0
		"targeted:copal":
			c.venue = ["stone", "night"][rng.randi() % 2]
			c.rules = Rules.CLASSIC
			c.home = "PIS"
			c.away = "VAL"
			c.ritual = true
			c.length = 1.0
		"targeted:fair":
			c.levels = [1, 1]
	return c


func start(cfg: Dictionary, seed: int, tree: SceneTree) -> Node:
	if bool(cfg.get("short", false)):
		var l := float(cfg.length)
		cfg.length = SHORT_LENGTH if l <= 0.0 or l > SHORT_LENGTH else l
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.graphics = int(cfg.get("graphics", Game.GFX_LOW))
	# The level is the config's for the whole match: auto graphics (Match._check_frame_rate) counts frames against
	# game time, which a fixed 30-a-second step always reads as 30 - under its 36 - and would drop Medium and High.
	Game.settings.auto_gfx = false
	Game.apply_graphics(tree.root)
	_main = Node.new()
	_main.name = "SimMain"
	tree.root.add_child(_main)
	Game.main = _main
	m = (load("res://game/match.gd") as Script).new()
	var mc := cfg.duplicate(true)
	mc.seed = seed
	mc.difficulty = int((cfg.levels as Array).max())
	mc.mode = "quick" if int(cfg.get("user_team", -1)) >= 0 else "watch"
	m.config = mc
	Game.current = m
	_main.add_child(m)
	_rc = RuleChecks.new()
	_events = []
	_logged = 0
	return m


func state() -> Dictionary:
	if not is_instance_valid(m) or not m.built:
		return {"score": [0, 0], "clock": 0.0, "clock_running": false, "phase": "building", "possession": -1, "finished": false}
	var c: Rules.Count = m.count
	# The score the harness may only see rise: the rayas each side has won (the ulama count itself goes up and down:
	# R3's cancel and R4's urria are rules, not the score falling).
	var won := [0, 0]
	for h in c.history:
		won[int(h[0])] += 1
	var live: bool = m.phase == m.P.LIVE and not m.paused
	# (The rule checks: each frame's, kept for rules().)
	_rc_out = _rc.step(m) if live or m.phase != m.P.REPLAY else []
	# What happened: each raya called.
	var log: Array = m.log_rayas
	while _logged < log.size():
		var r: Array = log[_logged]
		_events.append({"kind": "raya", "team": int(r[0]), "why": String(r[1])})
		_logged += 1
	return {"score": won, "clock": float(m.clock), "clock_running": live and m._hitstop <= 0.0, "phase": String(m.P.keys()[m.phase]),
		"possession": int(m.ball.last_team), "finished": bool(m._finished) or m.phase == m.P.OVER}


var _rc_out: Array = []


func events() -> Array:
	var e := _events
	_events = []
	return e


func bodies() -> Array:
	var out := []
	if not is_instance_valid(m) or not m.built:
		return out
	var live: bool = m.phase == m.P.LIVE and not m.paused
	for p: Player in m.all_players():
		# The foundation's drawn body (Medium and High). Low draws the game's own body, the toon driver posing it from
		# a capture body of its own that is never drawn: nothing there for the feet and pose checks to follow.
		var wb: WsgBody = null
		# (Not while a replay shows: it puts the bodies back where they were, a frame at a time from its recording.)
		if m.phase != m.P.REPLAY and p.toon == null and p.body != null and p.body.link != null and p.body.link.body != null and p.body.link.body.is_inside_tree():
			wb = p.body.link.body
		out.append({"name": String(p.name), "pos": p.global_position, "radius": Player.WALK_R, "height": 1.8, "body": wb,
			"active": live and not p.busy(), "target": p.want if live and not p.steer_by_dir else Vector3.INF})
	for j in m.officials.judges:
		var link: FoundationLink = (j as Body).link
		out.append({"name": "judge", "pos": (j as Node3D).global_position, "radius": Player.WALK_R, "height": 1.8,
			"body": link.body if link and link.body and link.body.is_inside_tree() else null, "active": false})
	if m.ritual != null and not m.ritual.done:
		out.append({"name": "elder", "pos": m.ritual.elder.global_position, "radius": Player.WALK_R, "height": 1.7, "active": false})
	return out


func ball() -> Dictionary:
	if not is_instance_valid(m) or not m.built:
		return {"pos": Vector3.ZERO, "radius": Ball.RADIUS, "live": false}
	return {"pos": m.ball.pos, "radius": Ball.RADIUS, "live": not m.ball.held and m.phase != m.P.REPLAY}


func solid() -> WsgSolidProps:
	return m.venue.solid if is_instance_valid(m) and m.venue else null


## Anywhere a ball can run on to after a call (the props stop it short of the trees and houses), with room to spare.
func bounds() -> AABB:
	return AABB(Vector3(-140, -1.0, -120), Vector3(280, 80, 240))


func score_steps() -> Array:
	return [1]


## The match's own time and its calls, intros, replays, the copal, and sudden death at time; to eight rayas, the
## longest a weak side can hold one off.
func max_seconds(cfg: Dictionary) -> float:
	var l := float(cfg.get("length", 0.0))
	return (l * 60.0 * 1.6 + 420.0) if l > 0.0 else 3600.0


func rules() -> Array:
	return _rc_out


func result() -> Dictionary:
	var c: Rules.Count = m.count
	var won := [0, 0]
	for h in c.history:
		won[int(h[0])] += 1
	return {"winner": c.winner, "score": won}


func balance_keys(cfg: Dictionary) -> Dictionary:
	return {"fair": int(cfg.levels[0]) == int(cfg.levels[1]), "levels": "%d-%d" % [int(cfg.levels[0]), int(cfg.levels[1])],
		"venue": String(cfg.venue), "side": int(cfg.side), "length": float(cfg.length)}


func stop() -> void:
	if is_instance_valid(_main):
		_main.queue_free()
	m = null
	_main = null
	Game.current = null
	if is_instance_valid(_menu_root):
		_menu_root.queue_free()
	_menu_root = null


# ---------------------------------------------------------------- a person playing

## When the harness plays a human (--input), the home side is theirs (config user_team 0).
func human_team() -> int:
	return int(m.user_team) if is_instance_valid(m) else -1


## Paused (the pause menu up: the player's pause, or the app sent to the background) - the input fuzzer then taps the
## pause key once, as a person taps Resume.
func paused() -> int:
	if not is_instance_valid(m) or not m.built:
		return -1
	return 1 if bool(m.paused) else 0


func input_actions() -> Array:
	TouchControls.ensure_actions()
	return ["pok_a", "pok_b", "pok_switch"]


## The game's own touch joystick: the match reads it from there (Hud.joystick).
func stick(v: Vector2) -> bool:
	if not is_instance_valid(m) or m.hud == null or m.hud.touch == null or not m.hud.touch.stick:
		return false
	m.hud.touch.joystick = v.limit_length(1.0)
	return true


func cameras() -> Array:
	return [Game.CAM_TV, Game.CAM_HIGH, Game.CAM_END]


func set_camera(i: int) -> void:
	if is_instance_valid(m) and m.cam and not m.watching():
		Game.settings.camera = cameras()[i]
		m.cam.mode = int(Game.settings.camera)


# ---------------------------------------------------------------- the menus

func menu_start(tree: SceneTree) -> Node:
	Game.settings.sound = false
	_menu_root = Node.new()
	_menu_root.name = "SimMenus"
	tree.root.add_child(_menu_root)
	Game.main = _menu_root
	Game.goto_menu()
	return _menu_root


func in_match() -> bool:
	return Game.current != null and is_instance_valid(Game.current) and String(Game.current.get_script().resource_path).ends_with("match.gd")


## The menus' invariants: always one screen up, and it is in the tree.
func menu_check() -> Array:
	var out := []
	if Game.current == null or not is_instance_valid(Game.current):
		out.append("no screen up")
	elif not Game.current.is_inside_tree():
		out.append("the screen up is not in the tree")
	return out


func save_paths() -> Array:
	return [Game.SETTINGS_PATH, Game.CUP_PATH, Game.RECORDS_PATH]
