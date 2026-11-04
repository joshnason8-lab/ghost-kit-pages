extends WsgSimGame
## The demo game's WsgSim adapter (tests/sim_demo/demo_match.gd): the shape a game's res://game/sim.gd takes.

const Match := preload("res://tests/sim_demo/demo_match.gd")

var m: Node3D = null


func game_name() -> String:
	return "WsgSim demo"


func scenarios() -> Array:
	return ["random", "extreme", "targeted:scoring", "targeted:timer", "targeted:collisions", "targeted:completion",
		"targeted:fair"]


func config(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var c := {"half": rng.randf_range(20.0, 45.0), "speed": [rng.randf_range(4.5, 6.5), rng.randf_range(4.5, 6.5)],
		"skill": [rng.randf_range(0.6, 1.4), rng.randf_range(0.6, 1.4)],
		"strategy": [["press", "zone"][rng.randi() % 2], ["press", "zone"][rng.randi() % 2]], "start": ""}
	if rng.randf() < 0.3:
		c.speed[1] = c.speed[0]
		c.skill[1] = c.skill[0]
	match kind:
		"extreme":
			# (Either side the strong one: always the away side made away win 65% of batches - the generator's bias.)
			c.speed = [rng.randf_range(1.0, 2.0), rng.randf_range(8.0, 10.0)] if rng.randf() < 0.5 else [9.5, 9.5]
			c.skill = [0.1, 3.0] if rng.randf() < 0.5 else [3.0, 3.0]
			if rng.randf() < 0.5:
				c.speed.reverse()
				c.skill.reverse()
			c.half = [3.0, 120.0][rng.randi() % 2]
		"targeted:scoring":
			c.start = "near goal"
			c.skill = [2.5, 2.5]
		"targeted:timer":
			c.half = rng.randf_range(0.5, 4.0)
		"targeted:collisions":
			c.start = "in props"
		"targeted:completion":
			c.half = 1.0 / 30.0
		"targeted:fair":
			c.speed = [5.5, 5.5]
			c.skill = [1.0, 1.0]
		"bodies":
			c.bodies = true
			c.half = 15.0
	if kind.begins_with("bug:fetch"):
		c.fetch_behind_prop = true
	if kind.begins_with("bug:"):
		c.bug = kind.substr(4)
		c.half = 20.0
		if c.bug in ["snap", "snap_reset"]:
			c.bodies = true
			c.half = 6.0
		if c.bug == "score_twice":
			c.start = "near goal"
			c.skill = [2.5, 2.5]
	return c


func start(cfg: Dictionary, seed: int, tree: SceneTree) -> Node:
	# The length mix: a shortened match is a fifth as long, every rule the same. (On a copy: never change the config
	# you are given - it is the one saved for the replay, which would shorten it again.)
	var c := cfg.duplicate(true)
	c.half = _half(cfg)
	m = Match.new()
	tree.root.add_child(m)
	m.setup(c, seed)
	return m


static func _half(cfg: Dictionary) -> float:
	var h := float(cfg.half)
	return maxf(h * 0.2, 2.0) if bool(cfg.get("short", false)) and h > 2.0 else h


func state() -> Dictionary:
	return {"score": m.score.duplicate(), "clock": m.clock, "clock_running": m.phase.ends_with("half"), "phase": m.phase,
		"possession": int(m.players[m.holder].team) if m.holder >= 0 else -1, "finished": m.finished}


func events() -> Array:
	var e: Array = m.events
	m.events = []
	return e


func bodies() -> Array:
	var out := []
	for i in m.players.size():
		var p: Dictionary = m.players[i]
		out.append({"name": "%s %d" % [["home", "away"][p.team], i % 3 + 1], "pos": p.pos, "radius": 0.3, "height": 1.8,
			"body": p.body, "active": m.phase.ends_with("half"), "target": p.target})
	return out


func ball() -> Dictionary:
	return {"pos": m.ball_pos, "radius": 0.11, "live": m.holder < 0 and m.fetch_spot == Vector3.INF}


## Checks put off (tests/sim_test.gd sets it).
var defer := {}


func deferred() -> Dictionary:
	return defer


## The fetch-behind-prop case: the ball dead at SPOT, the nearest player sent for it.
var no_fetch := false
var exempt := ""
var court_only := false


func fetch(spot: Vector3) -> Dictionary:
	if exempt != "":
		return {"exempt": exempt}
	if no_fetch:
		return {}
	var i: int = m.fetch(spot)
	return {"who": "%s %d" % [["home", "away"][m.players[i].team], i % 3 + 1], "seconds": 20.0}


## (court_only: the players kept to the court and its run-off, as a court-bound game.)
func fetch_reach(p: Vector3) -> bool:
	return not court_only or (absf(p.x) <= Match.HALF_L + 1.0 and absf(p.z) <= Match.HALF_W + 0.3)


func solid() -> WsgSolidProps:
	return m.solid


func bounds() -> AABB:
	return AABB(Vector3(-20, -0.5, -14), Vector3(40, 30, 28))


func score_steps() -> Array:
	return [1]


func max_seconds(cfg: Dictionary) -> float:
	return _half(cfg) * 2.0 + 3.0 + 10.0


func rules() -> Array:
	var out := []
	if m.score[0] + m.score[1] != m.goals:
		out.append("the scoreboard (%d) is not the goals scored (%d)" % [m.score[0] + m.score[1], m.goals])
	if m.holder >= 0 and absf((m.players[m.holder].pos as Vector3).x) > Match.HALF_L + 2.0:
		out.append("a player holds the ball off the court")
	return out


func result() -> Dictionary:
	return {"winner": 0 if m.score[0] > m.score[1] else (1 if m.score[1] > m.score[0] else -1), "score": m.score.duplicate()}


func balance_keys(cfg: Dictionary) -> Dictionary:
	return {"fair": cfg.speed[0] == cfg.speed[1] and cfg.skill[0] == cfg.skill[1], "strategy_home": cfg.strategy[0],
		"strategy_away": cfg.strategy[1]}


## The demo's menus: Play (a short match, then back), Settings (a box, an option, a slider, Back), and - with
## menu_bug - a Credits button that breaks (a script error) and a Help screen with no way back (a dead end).
var menu_bug := ""
var _menu: Control = null
var _playing := 0


func menu_start(tree: SceneTree) -> Node:
	_menu = Control.new()
	tree.root.add_child(_menu)
	_main()
	return _menu


func _clear() -> void:
	for c in _menu.get_children():
		c.queue_free()


func _button(text: String, f: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.name = text
	b.pressed.connect(f)
	_menu.add_child(b)
	return b


func _main() -> void:
	_clear()
	_button("Play", func():
		_clear()
		_playing = 20
		_menu.get_tree().process_frame.connect(_tick_match))
	_button("Settings", _settings)
	if menu_bug == "credits":
		_button("Credits", func():
			var a: Array = []
			print(a[7]))
	if menu_bug == "dead end":
		_button("Help", func(): _clear())


func _tick_match() -> void:
	_playing -= 1
	if _playing <= 0:
		_menu.get_tree().process_frame.disconnect(_tick_match)
		_main()


func _settings() -> void:
	_clear()
	var cb := CheckBox.new()
	cb.name = "Haptics"
	_menu.add_child(cb)
	var ob := OptionButton.new()
	ob.name = "Graphics"
	for g in ["Low", "Medium", "High"]:
		ob.add_item(g)
	_menu.add_child(ob)
	var sl := HSlider.new()
	sl.name = "Volume"
	_menu.add_child(sl)
	_button("Back", _main)


func in_match() -> bool:
	return _playing > 0


func stop() -> void:
	if is_instance_valid(m):
		m.queue_free()
	m = null
	if is_instance_valid(_menu):
		_menu.queue_free()
