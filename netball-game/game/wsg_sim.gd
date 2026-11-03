extends WsgSimGame
## Netball Unleashed's WsgSim adapter (the shared foundation's simulated matches, ADOPTING.md §5.17; docs/SIM.md).
## Named wsg_sim.gd: res://game/sim.gd is the game's own numbers-only results simulator (Sim.play, the cup's and the
## season's other matches). Pass it to the foundation's tools:
##   godot --headless --fixed-fps 30 --path . -s res://tools/wsg/sim.gd -- batch --game res://game/wsg_sim.gd --out DIR --smoke
##   sh tools/wsg/sim_shard.sh . "$OUT" --smoke --input --game res://game/wsg_sim.gd
## Each match is the game's own: Game.start_match with a config, game/match.gd and everything under it, every random
## roll from the match's generator seeded with the seed (Match.rng; docs/SIM.md lists every roll). The netball rules
## are tests/sim/netball_checks.gd, checked every frame (its error-level findings fail the match; its warnings, the
## umpire's discretion, go in the events and the result's counts). Nothing here changes how the game plays.
##
## Two things this adapter keeps as the game plays them, and why:
## - A replay after a goal or an intercept is skipped at once, as a tap skips it (the person watching may; the match
##   then goes on exactly as it would after the replay).
## - Every player's foundation body is posed in full (WsgSim's sampled pose is undone): the ball a player holds is
##   where the foundation's hands hold it (FoundationLink.ball_at, made by its pose layer), so where a pass or shot
##   leaves her hands, and so the play, would change without the layers. NETBALL_SIM_SAMPLED_POSE=1 allows it (to
##   measure what it changes).

const CHECKS := "res://tests/sim/netball_checks.gd"
const QUARTERS := [5, 8, 10, 15]
const LEVELS := ["low", "medium", "high"]
## The human's buttons through the game's own input path: the keys the controls read (Space, J, K: the first, second
## and third button showing; Esc: Back, which pauses and resumes).
const BUTTON_KEYS := {"nb_button_1": KEY_SPACE, "nb_button_2": KEY_J, "nb_button_3": KEY_K, "ui_cancel": KEY_ESCAPE}

var m: Match = null
var cfg := {}
var checks = null
var holder_node: Node = null
var _events: Array = []
var _done := false
var _final := {}
var _result := {}
var _seen := 0                # checks.violations already reported
var _warns := {}
var _resume_in := -1          # frames until the person taps Resume after the app came back
var _pose_fixed := false
var _epoch := 0               # stretches of play (bodies(): names)
var _clock_was := 0.0


func game_name() -> String:
	return "Netball Unleashed"


func scenarios() -> Array:
	return ["random", "extreme", "human", "targeted:scoring", "targeted:timer", "targeted:completion", "targeted:fouls",
		"targeted:variants"]


func config(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var ids: Array = DB.team_ids()
	ids.sort()
	var home: String = ids[rng.randi() % ids.size()]
	var away: String = ids[rng.randi() % ids.size()]
	while away == home:
		away = ids[rng.randi() % ids.size()]
	var c := {"home": home, "away": away, "venue": ["arena", "outdoor", "hall"][rng.randi() % 3],
		"quarter": QUARTERS[rng.randi() % QUARTERS.size()], "need_winner": rng.randf() < 0.25,
		"double_zone": rng.randf() < 0.35, "timeouts": rng.randf() < 0.35, "rolling": rng.randf() < 0.25,
		"whistles": rng.randi_range(0, 2), "level": LEVELS[rng.randi() % 3], "user_team": -1, "control": 0, "bib": "C",
		"camera": rng.randi() % 3, "onside": rng.randf() < 0.5, "difficulty": rng.randi() % 4}
	if rng.randf() < 0.3:
		c.away = _nearest(home, ids)   # near-equal sides: draws, extra time
	match kind:
		"extreme":
			ids.sort_custom(func(a, b): return DB.team_rating(a) > DB.team_rating(b))
			var pick := rng.randi() % 3
			if pick == 0:
				c.home = ids[0]                 # the strongest against the weakest (either way round)
				c.away = ids[-1]
			elif pick == 1:
				c.home = ids[-1]
				c.away = ids[-2]                # the two weakest
			else:
				c.home = ids[0]
				c.away = ids[1]                 # the two strongest
			if rng.randf() < 0.5:
				var t: String = c.home
				c.home = c.away
				c.away = t
			c.quarter = [5, 15][rng.randi() % 2]
			c.whistles = [0, 2][rng.randi() % 2]
		"human":
			c.user_team = rng.randi() % 2
			c.control = rng.randi() % 2          # whole team, or one bib
			c.bib = Rules.POSITIONS[rng.randi() % 7]
		"targeted:scoring":
			c.double_zone = true                 # one- and two-point goals, the window's edges
			c.quarter = 5
		"targeted:timer":
			c.quarter_s = rng.randf_range(4.0, 30.0)   # quarters of seconds: ends of periods, shots in the air
			c.need_winner = true
			c.away = _nearest(home, ids)
		"targeted:completion":
			c.need_winner = true                 # equal sides: extra time, on to a two-goal lead
			c.away = _nearest(home, ids)
			c.quarter_s = rng.randf_range(15.0, 60.0)
		"targeted:fouls":
			c.whistles = 2                       # the real rate: warnings, suspensions, ordering off, injuries
			c.quarter = 15
			c.quarter_s = 240.0
		"targeted:variants":
			c.double_zone = true
			c.timeouts = true
			c.rolling = true
			c.need_winner = true
	return c


static func _nearest(home: String, ids: Array) -> String:
	var near := ids.filter(func(x): return x != home)
	near.sort_custom(func(a, b): return absf(DB.team_rating(a) - DB.team_rating(home)) < absf(DB.team_rating(b) - DB.team_rating(home)))
	return near[0]


## The match length: a quarter of the batch's matches play the quarters set (5, 8, 10 or 15 minutes); short ones
## (config.short) play quarters a fifth as long, every rule the same (extra time scales with them).
static func quarter_seconds(c: Dictionary) -> float:
	var q := float(c.get("quarter_s", float(c.get("quarter", 5)) * 60.0))
	return q * 0.2 if bool(c.get("short", false)) and q > 5.0 else q


func start(config: Dictionary, seed: int, tree: SceneTree) -> Node:
	cfg = config
	if OS.get_environment("NETBALL_SIM_SHORT") == "1":
		cfg["short"] = true   # (every match short: the fps probe in minutes rather than hours)
	_events = []
	_done = false
	_final = {}
	_result = {}
	_seen = 0
	_warns = {}
	_pose_fixed = false
	_epoch = 0
	_clock_was = 0.0
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.coached = true
	Game.settings.auto_gfx = false
	Game.settings.dev = false
	Game.settings.graphics = LEVELS.find(String(cfg.get("level", "low")))
	Game.settings.camera = int(cfg.get("camera", 0))
	Game.settings.control = int(cfg.get("control", 0))
	Game.settings.bib = String(cfg.get("bib", "C"))
	Game.settings.onside = bool(cfg.get("onside", true))
	Game.settings.difficulty = int(cfg.get("difficulty", 1))
	WsgFoundation.tier = int(Game.settings.graphics)
	Engine.max_fps = 0
	for a in BUTTON_KEYS:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	holder_node = SimMain.new()
	holder_node.name = "SimMain"
	holder_node.adapter = self
	tree.root.add_child(holder_node)
	Game.main = holder_node
	var mc := {"home": cfg.home, "away": cfg.away, "venue": cfg.venue, "quarter": int(cfg.quarter), "seed": seed,
		"user_team": int(cfg.user_team), "demo": int(cfg.user_team) < 0, "headless_hud": true, "mode": "quick",
		"need_winner": bool(cfg.need_winner), "double_zone": bool(cfg.double_zone), "timeouts": bool(cfg.timeouts),
		"rolling": bool(cfg.rolling), "whistles": int(cfg.whistles), "difficulty": int(cfg.difficulty),
		"control": int(cfg.control), "bib": String(cfg.bib), "quarter_s": quarter_seconds(cfg)}
	Game.start_match(mc)
	m = Game.current as Match
	if m == null:
		return null
	_clock_was = m.clock
	checks = (load(CHECKS) as Script).new()
	checks.begin(m)
	m.game_event.connect(_on_event)
	m.finished.connect(_on_finished)
	return holder_node


func _on_event(kind: String, info: Dictionary) -> void:
	if kind in ["replay", "substitution", "replacement", "period_end", "centre_setup"]:
		_epoch += 1
	if kind == "period_end":
		# A line a period: tools/wsg/sim_shard.sh takes a Godot that prints nothing for HANG seconds for a frozen one, and
		# a netball match is minutes of play.
		print("  netball seed %s: period %d over at %d-%d" % [cfg.get("seed", "?"), m.q, m.score[0], m.score[1]])
	if checks:
		checks.check_event(m, kind, info)
	var e := {"type": kind}
	for k in info:
		e[k] = info[k] if not (info[k] is Object) else str(info[k])
	_events.append(e)


func _on_finished(r: Dictionary) -> void:
	_done = true
	_result = r
	_final = _state_now()
	if checks:
		checks.finish(m, r, true)


func _alive() -> bool:
	return m != null and is_instance_valid(m)


func _state_now() -> Dictionary:
	var tl := float(m.time_left)
	var runs: bool = m.phase in ["setup", "live", "stop", "goal"] and m._cp_whistled and tl > 0.0 and not is_inf(tl) and not m.paused
	return {"score": [int(m.score[0]), int(m.score[1])], "clock": 0.0 if is_inf(tl) else tl, "clock_running": runs,
		"phase": ("paused" if m.paused else String(m.phase)) + " q%d" % m.q, "possession": int(m.possession),
		"finished": _done, "q": m.q, "holder": (m.holder.pos + str(m.holder.team)) if m.holder else "", "ball": m.ball.state}


func state() -> Dictionary:
	if not _alive():
		var f := _final.duplicate()
		f["finished"] = true
		return f
	if m.phase == "replay":
		m._end_replay()   # a tap skips it
		_epoch += 1
	if not _pose_fixed and OS.get_environment("NETBALL_SIM_SAMPLED_POSE") != "1":
		# (After WsgSim's sampled pose: every player's foundation body in full again; see the header.)
		_pose_fixed = true
		for pl in m.players[0] + m.players[1]:
			if pl.link and pl.link.body:
				pl.link.body.set_sim_full(true)
	if _resume_in > 0:
		_resume_in -= 1
		if _resume_in == 0 and m.paused:
			m.set_paused(false)   # the person back in the game taps Resume
	return _state_now()


func events() -> Array:
	var e := _events
	_events = []
	return e


func bodies() -> Array:
	if not _alive():
		return []
	var out := []
	for t in 2:
		for pl in m.players[t]:
			# (A body not yet posed is not drawn: the foundation shows it from its first pose. Before the match's first
			# step, its bones are at rest.)
			var body: WsgBody = pl.link.body if pl.link and is_instance_valid(pl.link) and pl.link.body.visible else null
			var active: bool = m.phase == "live" and not m.paused and not pl.away() and pl != m.holder and not pl.stopped
			# Named for the stretch of play she is in: a new quarter places everyone at once, a replay shows the play again
			# and a change brings on another player, so the feet are measured afresh (a jump there is a cut, not a slide).
			out.append({"name": "%s%d.%d" % [pl.pos, t, _epoch], "pos": Vector3(pl.p.x, 0.0, pl.p.y), "radius": 0.25,
				"height": float(pl.data.get("height", 1.75)), "body": body, "active": active,
				"target": Vector3(pl.target.x, 0.0, pl.target.y)})
	return out


func ball() -> Dictionary:
	if not _alive():
		return {}
	return {"pos": m.ball.pos, "radius": Ball.R, "live": m.phase == "live" and m.ball.state in ["flight", "loose"]}


func bounds() -> AABB:
	# The court, its run-off, the benches and the umpires' lines, and the ball's highest lob.
	return AABB(Vector3(-Court.HALF_L - 8.0, -0.5, -Court.HALF_W - 8.0), Vector3(Court.LENGTH + 16.0, 16.0, Court.WIDTH + 16.0))


func score_steps() -> Array:
	return [1, 2] if bool(cfg.get("double_zone", false)) else [1]


func max_seconds(c: Dictionary) -> float:
	var q := quarter_seconds(c)
	# Four quarters, extra time's two halves, the intervals and stoppages, and playing on to a two-goal lead.
	return q * 4.0 + q * 0.5 * 2.0 + 600.0 + q * 2.0


func rules() -> Array:
	if not _alive() or checks == null:
		return _new_findings()
	if not _done:
		# The play this frame: the match's own clock of play (it stands while paused or in a replay).
		var dt: float = m.clock - _clock_was
		_clock_was = m.clock
		checks.check_frame(m, dt)
	return _new_findings()


func _new_findings() -> Array:
	var out := []
	if checks == null:
		return out
	var v: Array = checks.violations
	while _seen < v.size():
		var x: Dictionary = v[_seen]
		_seen += 1
		if x.severity == "error":
			out.append("%s: %s" % [x.check, x.msg])
		else:
			_warns[x.check] = int(_warns.get(x.check, 0)) + 1
			_events.append({"type": "warn", "check": x.check, "msg": x.msg})
	return out


func result() -> Dictionary:
	var sc: Array = _result.get("score", _final.get("score", [0, 0]))
	var r := {"winner": int(_result.get("winner", -1)), "score": sc, "periods": int(_result.get("periods", 0))}
	if checks:
		for k in checks.counts:
			if not k in r:
				r["n_" + String(k)] = int(checks.counts[k])
		r["goals"] = int(checks.stats.get("goals", 0))
		r["two_pointers"] = int(checks.stats.get("two_pointers", 0))
	return r


func balance_keys(c: Dictionary) -> Dictionary:
	var gap := absf(DB.team_rating(String(c.home)) - DB.team_rating(String(c.away)))
	return {"fair": gap < 2.0, "gap": "0-2" if gap < 2.0 else ("2-8" if gap < 8.0 else ("8-20" if gap < 20.0 else "20+")),
		"venue": c.venue, "level": c.level, "double_zone": c.double_zone, "whistles": c.whistles}


func stop() -> void:
	if _alive():
		m.queue_free()
	if holder_node and is_instance_valid(holder_node):
		holder_node.queue_free()
	Game.current = null
	Game.main = null
	m = null
	checks = null


# ---------------------------------------------------------------- the human

func human_team() -> int:
	return int(cfg.get("user_team", -1))


func input_actions() -> Array:
	return ["nb_button_1", "nb_button_2", "nb_button_3"]


## The touch joystick's value, as the controls make it from a thumb (x right, y down, length 0..1).
func stick(v: Vector2) -> bool:
	if _alive() and m.controls:
		m.controls.joystick = v.limit_length(1.0)
		return true
	return false


func cameras() -> Array:
	return ["tv", "courtside", "end"]


func set_camera(i: int) -> void:
	Game.settings.camera = i
	if _alive() and m.cam:
		m.cam.mode = i


## The adapter's node: the game's main (Game.main), and the human's buttons turned into the keys the game reads.
class SimMain extends Node:
	var adapter = null

	func _input(event: InputEvent) -> void:
		if event is InputEventAction and BUTTON_KEYS.has(event.action):
			var k := InputEventKey.new()
			k.physical_keycode = BUTTON_KEYS[event.action]
			k.keycode = BUTTON_KEYS[event.action]
			k.pressed = event.pressed
			get_viewport().set_input_as_handled()
			Input.parse_input_event(k)

	func _notification(what: int) -> void:
		# Back in the game after the home button: the person taps Resume a moment later (Game paused the match).
		if what == NOTIFICATION_APPLICATION_FOCUS_IN and adapter:
			adapter._resume_in = 20
