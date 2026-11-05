extends WsgSimGame
## Kabaddi Raid's side of WsgSim (ADOPTING 5.17): matches played by the game's own Match - its raiders' and defenders'
## AI, the grapple, the cant, the officials, every rule - from a seed (Match.rng: config.seed; every other roll in the
## match is derived from it or cosmetic, tools/wsg/rng_lint.sh). Only the drawing is skipped (headless).
##   godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- batch --out DIR --smoke --input
## The kabaddi rules checked every frame (rules()): the seven each side always accounted for (on the mat, out in the
## order they went, or suspended); revivals in the order players went out; a raid started within its five seconds and
## over by its time; the next raid waiting no longer than it should; a do-or-die raid after two empty ones; one
## raider, of the raiding side; no defender in the lobby before the struggle; each side's score its points' sum.

const Match := preload("res://game/match.gd")
const SHORT_HALF := 240.0     # s of match clock in a shortened half (config.short): two to four raids a half
const SCORE_STEPS := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]   # a raid's touches and bonus with an all out (2) on top
const ACTIONS := ["touch", "kick", "dodge", "dubki", "jump", "cant", "ankle", "thigh", "waist", "dash", "chain",
	"switch", "camera", "skip"]

var m: Node = null
var host: Node = null
var _result := {}
var _seen := 0                 # the last event_log number handed out
var _queues := [[], []]        # each side's out queue last frame
var _human := -1
var _list: Array = []          # every body, in one order
var _free := {}                # instance id -> frames on his feet between moves, in a row
var _seg := {}                 # instance id -> how many stretches on his feet so far
var _audit: WsgPropAudit = null
var _prop_told := false
## On his feet between moves: standing, the defenders' ready stance, walking, the raider's raid.
const FREE := ["idle", "ready", "walk", "raid"]
const SETTLE := 9              # frames (0.3 s) on his feet before his pose and feet are checked


func game_name() -> String:
	return "Kabaddi Raid"


## The lead, 2026-11-03: Medium and High's planted-step slides (2.0-7.6 cm in the 328d7dd smoke, officials and players
## alike, on the foundation's WsgBody and planter) are the foundation's planted-slide fix, due 11-13, the same as Sepak
## Takraw's. Only a planted slide up to 8 cm is put off; a skid or a jump still fails. Low (our own RiggedBody, the
## foundation's planter on it) had none in 39 matches - if one shows there it is put off too: deferred() is asked
## before start() and is not told the match's graphics level.
func deferred() -> Dictionary:
	return {"planted slip": ["2026-11-13T12:00Z", "Foundation planted-slide fix (the lead, 2026-11-03)", 8.0]}


## random and extreme, and the targeted cases: the 30-second raid clock instead of the cant; a drawn knockout
## (tie-breaker raids, then the golden raid); short-handed sides (all outs and revivals); the local grounds' props
## (chairs, stools, the scorers' table, the benches); and the human's own side (the stick and the buttons).
func scenarios() -> Array:
	return ["random", "extreme", "targeted:raid_clock", "targeted:knockout", "targeted:all_out", "targeted:props",
		"targeted:human"]


func config(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var ids: Array = DB.teams.keys()
	ids.sort()
	var arenas: Array = DB.ARENAS.map(func(a): return String(a.id))
	var home: String = ids[rng.randi() % ids.size()]
	var away: String = ids[rng.randi() % ids.size()]
	while away == home:
		away = ids[rng.randi() % ids.size()]
	var c := {"home": home, "away": away, "arena": arenas[rng.randi() % arenas.size()], "difficulty": rng.randi() % 3,
		"length": 0, "raid_rule": [Match.RULE_CANT_AUTO, Match.RULE_CLOCK][rng.randi() % 2], "human": -1,
		"knockout": rng.randf() < 0.25, "graphics": [Game.GFX_LOW, Game.GFX_MEDIUM][rng.randi() % 2]}
	match kind:
		"extreme":
			# The strongest side against the weakest, the hardest and easiest AI, the longest and shortest clocks.
			var by := ids.duplicate()
			by.sort_custom(func(a, b): return _rating(a) > _rating(b))
			c.home = by[0] if rng.randf() < 0.5 else by[-1]
			c.away = by[-1] if c.home == by[0] else by[0]
			c.difficulty = [0, 2][rng.randi() % 2]
			c.length = [0, 1][rng.randi() % 2]
		"targeted:raid_clock":
			c.raid_rule = Match.RULE_CLOCK
		"targeted:knockout":
			# Two equal sides, short halves: often level at the end - the tie-breaker's five raids, then golden raids.
			var near := ids.filter(func(id): return id != c.home)
			near.sort_custom(func(a, b): return absi(_rating(a) - _rating(c.home)) < absi(_rating(b) - _rating(c.home)))
			c.away = near[0]
			c.knockout = true
			c.short = true
		"targeted:all_out":
			c.players = [3 + rng.randi() % 3, 3 + rng.randi() % 3]
		"targeted:props":
			c.arena = ["village", "beach", "monsoon"][rng.randi() % 3]
		"targeted:human":
			c.human = 0
	if kind.begins_with("targeted:"):
		c.short = true   # (each tests its one rule hard: shortened halves are enough)
	if kind == "random" and rng.randf() < 0.3:
		c.human = 0
	return c


static func _rating(id: String) -> int:
	return DB.team_rating(DB.team(id).squad)


func start(cfg: Dictionary, seed: int, tree: SceneTree) -> Node:
	host = Node.new()
	host.name = "SimMatch"
	tree.root.add_child(host)
	Game.main = host
	Game.settings.sound = false
	Game.loading_overlay = false
	Game.settings.graphics = int(cfg.get("graphics", Game.GFX_LOW))
	WsgFoundation.tier = Game.settings.graphics
	_human = int(cfg.get("human", -1))
	_result = {}
	_seen = 0
	_queues = [[], []]
	_list = []
	_prop_told = false
	_free = {}
	_seg = {}
	var mc := {"home": cfg.home, "away": cfg.away, "arena": cfg.arena, "mode": "quick", "length": int(cfg.length),
		"difficulty": int(cfg.difficulty), "raid_rule": int(cfg.raid_rule), "seed": seed,
		"knockout": bool(cfg.get("knockout", false)), "autoplay_no_report": true}
	if cfg.has("players"):
		mc.players = cfg.players
	if bool(cfg.get("short", false)):
		mc.half_len = SHORT_HALF
	if _human < 0:
		mc.autoplay = true
		mc.watch = true
	else:
		for id in ACTIONS:
			if not InputMap.has_action("btn_" + id):
				InputMap.add_action("btn_" + id)
	await Game.start_match(mc)
	m = Game.current
	if m == null or not m.has_signal("finished"):
		return null
	if not m.is_built:
		await m.built
	var mine: Node = m
	_audit = WsgPropAudit.new(m.arena.solid)
	m.finished.connect(func(r: Dictionary): if mine == m and _result.is_empty(): _result = r)
	return host


func state() -> Dictionary:
	if not _live():
		return {"finished": true}
	var raid: Dictionary = m.raid
	return {"score": [m.teams[0].score, m.teams[1].score], "clock": snappedf(m.clock, 0.001),
		"clock_running": m.phase == "raid" and m.clock > 0.0 and not m.paused,
		"phase": "%s%d%s" % [m.phase, m.half, "tb" if m.tiebreak else ("gr" if m.golden else "")],
		"possession": m.raiding, "finished": not _result.is_empty(),
		"raid": {"t": snappedf(float(raid.get("t", 0.0)), 0.01), "entered": bool(raid.get("entered", false)),
			"holders": (raid.get("holders", []) as Array).size(), "dod": bool(raid.get("dod", false))},
		"on_mat": [m.on_mat(0).size(), m.on_mat(1).size()], "paused": m.paused}


func events() -> Array:
	var out := []
	if not _live():
		return out
	for e in m.event_log:
		var info: Dictionary = e[3]
		if int(info.get("n", 0)) <= _seen:
			continue
		_seen = int(info.n)
		var ev := {"type": String(e[2]), "raid": int(e[1])}
		for k in info:
			var v: Variant = info[k]
			ev[k] = v.pid() if v is Athlete else v
		out.append(ev)
	return out


## Every player and official, in one order all match (WsgSim follows a quarter of them by their place in the list).
## Each one's shared body (Medium: FoundationLink) is handed over for the feet and T/A-pose checks only while he is
## on his feet between moves - standing, ready, walking, raiding: a dive's or a hold's arms are out at full stretch, a
## referee's signal is arms out by design, a tackled man's foot is dragged - and each such stretch is a new name (its
## feet measured from its own start, no gap in the middle). Where his AI sends him (Athlete._goal): the stuck check.
func bodies() -> Array:
	var out := []
	if not _live():
		return out
	if _list.is_empty():
		_list = m.athletes.duplicate()
		_list.append_array(m.officials.find_children("*", "Athlete", false, false))
	for a: Athlete in _list:
		if not is_instance_valid(a):
			continue
		var id := a.get_instance_id()
		var free: bool = a.state in FREE and a not in m.officials.scorers and not (a.model and a.model.seated > 0.1) \
			and m.phase != "replay"
		# Frames on his feet in a row: his shared body is handed over once the move before has blended out (SETTLE).
		var run: int = int(_free.get(id, 0)) + 1 if free else 0
		if run == SETTLE:
			_seg[id] = int(_seg.get(id, 0)) + 1
		_free[id] = run
		var wb: WsgBody = a.model.link.body if run >= SETTLE and a.model and a.model.link else null
		out.append({"name": "%s %s #%d" % ["official" if a.team >= 2 else "player", a.pid(), int(_seg.get(id, 0))],
			"pos": a.position, "radius": Athlete.PROP_R, "height": 1.8, "body": wb,
			"active": free and not m.paused and m.phase not in ["timeout", "replay"], "target": a._goal})
	return out


## The props are checked here (rules()), not by WsgSim's own audit: it would take every body in the list, and the
## out players sit on their bench and the scorers at their table - inside them, as they should be.
func solid() -> WsgSolidProps:
	return null


## The court, its lobbies and surrounds, the benches and the officials' places: nobody is ever 30 m out.
func bounds() -> AABB:
	return AABB(Vector3(-30, -1, -30), Vector3(60, 8, 60))


func score_steps() -> Array:
	return SCORE_STEPS


## A full match at the quick clock: two 20-minute halves at six times speed, raid gaps, a tie-breaker and golden raids
## (about 9 minutes); the fast clock (three times) twice that; shortened halves far less.
func max_seconds(cfg: Dictionary) -> float:
	var speed: float = Match.CLOCK_SPEEDS[clampi(int(cfg.get("length", 0)), 0, 2)]
	var half: float = SHORT_HALF if bool(cfg.get("short", false)) else Match.HALF_LEN
	var limit := 2.0 * half / speed * 1.6 + 600.0
	# The human's matches stand paused much of the time: the app sent to the background pauses a match (as it does for
	# a player) and WsgSimInput's pause key then toggles it, so it sits paused until the next press.
	return limit * 3.0 if int(cfg.get("human", -1)) >= 0 else limit


func rules() -> Array:
	var bad := []
	if not _live():
		return bad
	var raid: Dictionary = m.raid
	for t in 2:
		var tm: Dictionary = m.teams[t]
		var queue: Array = tm.out_queue
		var on := 0
		var off := 0
		for a: Athlete in tm.players:
			if a.on_mat:
				on += 1
				if a in queue:
					bad.append("%s is on the mat and in the out queue" % a.pid())
			elif a.suspended >= 0.0:
				off += 1
		if on + off + queue.size() != (tm.players as Array).size():
			bad.append("side %d: %d on the mat, %d suspended, %d out: not its %d players" % [t, on, off, queue.size(), (tm.players as Array).size()])
		# Revivals in the order they went out: whoever came back must have been at the front of the queue.
		var before: Array = _queues[t]
		var back := before.filter(func(a): return is_instance_valid(a) and not a in queue and a.on_mat)
		for i in back.size():
			if before.find(back[i]) != i and queue.size() > 0:
				bad.append("side %d revived %s before %s, out earlier" % [t, back[i].pid(), before[i].pid()])
				break
		_queues[t] = queue.duplicate()
		var pts: Dictionary = tm.pts
		if int(tm.score) != int(pts.raid) + int(pts.tackle) + int(pts.allout) + int(pts.extra):
			bad.append("side %d's score %d is not its points' sum %s" % [t, tm.score, pts])
	# Nobody on his feet inside a prop (the bodies sitting down, the scorers at their table and those still rising
	# off the bench aside, as tools/wsg/prop_audit.gd checks them: game/prop_runs.gd).
	if _audit and m.phase != "replay":
		var before_n := _audit.body_cases
		for a: Athlete in _list:
			if is_instance_valid(a) and a.state != "sit" and a not in m.officials.scorers and not (a.model and a.model.seated > 0.1):
				_audit.body("%s (%s)" % [a.pid(), a.state], a.position, Athlete.PROP_R, 1.8)
		_audit.tick(1.0 / 30.0)
		if _audit.body_cases > before_n:
			var w: Dictionary = (_audit.report().worst as Array)[0] if not (_audit.report().worst as Array).is_empty() else {}
			if not w.is_empty() and not _prop_told:
				_prop_told = true
				bad.append("prop: %s %.0f cm into the %s" % [w.who, float(w.depth) * 100.0, w.prop])
	if m.paused:
		return bad
	match String(m.phase):
		"setup":
			if m.phase_t > Match.SETUP_WAIT + 0.5:
				bad.append("the next raid waited %.1f s (at most %.0f)" % [m.phase_t, Match.SETUP_WAIT])
		"raid":
			var r: Athlete = m.raider
			if r == null or r.team != m.raiding or not r.on_mat:
				bad.append("the raider is not one of the raiding side's on the mat")
			if not bool(raid.entered) and m.phase_t > Match.START_LIMIT + 0.2:
				bad.append("the raid did not start within %.0f s (%.1f s)" % [Match.START_LIMIT, m.phase_t])
			if float(raid.t) < -0.25:
				bad.append("the raid ran %.1f s past its time" % -float(raid.t))
			var tm: Dictionary = m.teams[m.raiding]
			if int(tm.empty) >= 2 and not m.tiebreak and not m.golden and not bool(raid.dod):
				bad.append("a third raid after two empty ones is not do-or-die")
			# The lobby is in play only once the struggle starts: a defender on his feet in it before then is out.
			var edge: float = Arena.HALF_W + (Arena.LOBBY if bool(raid.struggle) else 0.0) + 0.35
			for d: Athlete in m.on_mat(1 - m.raiding):
				if d.state not in Match.BUSY and d.state != "sit" and absf(d.position.x) > edge:
					bad.append("%s is %.2f m out to the side (%s) and still on the mat" % [d.pid(), absf(d.position.x) - edge + 0.35, "lobby" if not bool(raid.struggle) else "past the lobby"])
	return bad


func result() -> Dictionary:
	if _result.is_empty():
		return {}
	var r := _result
	var raids: Array = r.get("raid_log", [])
	var kinds := {}
	for x: Dictionary in raids:
		kinds[String(x.kind)] = int(kinds.get(String(x.kind), 0)) + 1
	return {"winner": int(r.winner), "score": r.score, "raids": raids.size(), "raid_ends": kinds,
		"all_outs": [int(r.breakdown[0].allout) / 2, int(r.breakdown[1].allout) / 2],
		"tiebreak": m != null and is_instance_valid(m) and (m.tiebreak or m.golden)}


func balance_keys(cfg: Dictionary) -> Dictionary:
	var a := _rating(String(cfg.home))
	var b := _rating(String(cfg.away))
	return {"fair": absi(a - b) <= 3, "stronger": "home" if a > b + 3 else ("away" if b > a + 3 else "even"),
		"difficulty": int(cfg.difficulty), "arena": String(cfg.arena),
		"raid_rule": "clock" if int(cfg.raid_rule) == Match.RULE_CLOCK else "cant", "human": int(cfg.get("human", -1)) >= 0}


func stop() -> void:
	Engine.time_scale = 1.0
	get_tree_safe().paused = false
	if m and is_instance_valid(m):
		m.process_mode = Node.PROCESS_MODE_DISABLED
		m.queue_free()
	if host and is_instance_valid(host):
		host.queue_free()
	m = null
	host = null
	Game.current = null


func get_tree_safe() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func human_team() -> int:
	return _human


func input_actions() -> Array:
	return ACTIONS.map(func(id): return "btn_" + id) if _human >= 0 else []


## The game's own touch stick (TouchControls: the match reads move_vec()).
func stick(v: Vector2) -> bool:
	if _live() and m.controls:
		m.controls.sim_stick(v)
		return true
	return false


func cameras() -> Array:
	return [Game.CAM_TV, Game.CAM_THIRD]


func set_camera(i: int) -> void:
	if _live():
		m.cam.mode = cameras()[i % cameras().size()]


func _live() -> bool:
	return m != null and is_instance_valid(m) and m.is_inside_tree()
