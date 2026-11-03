extends WsgSimGame
## Sepak Takraw Unleashed's side of WsgSim (ADOPTING §5.17; tools/wsg/sim.gd and sim_shard.sh run it): matches played
## by the game's own code - built by Game.start_match as a Start tap builds them (the loading overlay aside: the sim
## draws nothing), the AI, the ball, the rules, the officials and the props all the game's own - each from a seed.
## Every random roll of a match comes from it: Match.rng, and the players' idle and the camera's shake seeded from
## the same seed (tools/wsg/rng_lint.sh). The game's own numbers-only results simulator is Sim, game/score_sim.gd.
## A person's side, when the input fuzzer plays it, goes through the game's own touch controls: the stick
## (TouchControls.joystick), the buttons (TouchControls._fire, as their keys do) and the phone's Back (Game.go_back:
## the pause menu).

const EVENTS := ["regu", "doubles", "quadrant", "team"]
const PER_SIDE := {"regu": 3, "doubles": 2, "quadrant": 4, "team": 3}
const BUTTONS := ["takraw_button_1", "takraw_button_2", "takraw_button_3"]

var m: Node = null
var _cfg := {}
var _holder: Node = null
var _relay: Node = null
var _logged := 0
var _sets_checked := 0


func game_name() -> String:
	return "Sepak Takraw Unleashed"


## random: any two sides, any event, venue, length and level; extreme: the strongest against the weakest, the longest
## match, the hardest and easiest AI; targeted: scoring (close sides, short sets: deuce and the cap), collisions (the
## venues with the most props, the most players), completion (best of three to 21: every rule of a long match), human
## (a person's side, for the input fuzzer).
func scenarios() -> Array:
	return ["random", "extreme", "targeted:scoring", "targeted:collisions", "targeted:completion", "targeted:human"]


func config(kind: String, rng: RandomNumberGenerator) -> Dictionary:
	var women := rng.randf() < 0.3
	var clubs := not women and rng.randf() < 0.35
	var ids: Array = DB.league_clubs(["MY", "TH", "ID"][rng.randi_range(0, 2)]) if clubs else DB.countries_ranked(women)
	var i := rng.randi_range(0, ids.size() - 1)
	var j := (i + 1 + rng.randi_range(0, ids.size() - 2)) % ids.size()
	var venues: Array = DB.VENUES.map(func(v): return String(v[0]))
	var c := {"home": String(ids[i]), "away": String(ids[j]), "venue": venues[rng.randi_range(0, venues.size() - 1)],
		"event": EVENTS[rng.randi_range(0, EVENTS.size() - 1)], "sets": [1, 3][rng.randi_range(0, 1)],
		"points": [15, 21][rng.randi_range(0, 1)], "women": women, "difficulty": rng.randi_range(0, 2),
		"user_team": 0 if rng.randf() < 0.25 else -1, "graphics": [Game.GFX_LOW, Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH][rng.randi_range(0, 3)],
		"camera": rng.randi_range(0, 2), "mode": "quick", "demo": true}
	match kind:
		"extreme":
			var ranked := DB.countries_ranked(women)
			c.home = String(ranked[0]) if rng.randf() < 0.5 else String(ranked[-1])
			c.away = String(ranked[-1]) if c.home == String(ranked[0]) else String(ranked[0])
			c.sets = 3
			c.points = 21
			c.difficulty = [0, 2][rng.randi_range(0, 1)]
			c.event = ["regu", "quadrant"][rng.randi_range(0, 1)]
		"targeted:scoring":
			var ranked := DB.countries_ranked(women)
			var k := rng.randi_range(0, ranked.size() - 2)
			c.home = String(ranked[k])
			c.away = String(ranked[k + 1])
			c.sets = 1
			c.points = 15
		"targeted:collisions":
			c.venue = ["park", "mall", "national", "provincial"][rng.randi_range(0, 3)]
			c.event = "quadrant"
			c.graphics = Game.GFX_LOW
		"targeted:completion":
			c.sets = 3
			c.points = 21
		"targeted:human":
			c.user_team = 0
	if int(c.user_team) >= 0:
		c.demo = true   # (no result screens after it: the sim frees it)
	return c


func start(config: Dictionary, seed: int, tree: SceneTree) -> Node:
	_cfg = config
	var c := config.duplicate(true)
	c.seed = seed
	if bool(config.get("short", false)):
		c.sets = 1   # (one set to its points: every rule as in a whole match)
	Game.reset_settings_for_tests()
	Game.settings.sound = false
	var g := int(config.get("graphics", Game.GFX_LOW))
	Game.settings.graphics = g
	Game.settings.gfx_auto = false
	Game.settings.camera = int(config.get("camera", 0))
	Game.settings.difficulty = int(config.get("difficulty", 1))
	WsgFoundation.tier = g
	FoundationLink.off = g == Game.GFX_LOW
	_holder = Node.new()
	_holder.name = "Sim"
	tree.root.add_child(_holder)
	Game.main = _holder
	Game.current = null
	Game.start_match(c)
	m = Game.current
	_logged = 0
	_sets_checked = 0
	for a in BUTTONS + ["pause"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	_relay = _Relay.new()
	_relay.sim = self
	_holder.add_child(_relay)
	return m


func _alive() -> bool:
	return m != null and is_instance_valid(m)


func state() -> Dictionary:
	if not _alive():
		return {"finished": true}
	var over: bool = int(m.sets[0]) >= int(m.sets_to_win) or int(m.sets[1]) >= int(m.sets_to_win)
	var total := [0, 0]
	for sc in m.set_scores:
		total[0] += int(sc[0])
		total[1] += int(sc[1])
	if not over:   # (the set being played: at the end, its points are the last set's, already counted)
		total[0] += int(m.points[0])
		total[1] += int(m.points[1])
	var st := int(m.state)
	return {"score": total, "clock": float(m.now), "clock_running": not bool(m.paused) and st != int(m.S.REPLAY) and st != int(m.S.OVER),
		"phase": "over" if st == int(m.S.OVER) else "set %d" % (m.set_scores.size() + 1), "possession": m._serving_side(),
		"finished": st == int(m.S.OVER), "sets": [int(m.sets[0]), int(m.sets[1])], "points": [int(m.points[0]), int(m.points[1])],
		"state": st}


## Each rally since the last call: who won it, how it ended, in how many touches.
func events() -> Array:
	if not _alive():
		return []
	var out := []
	var log: Array = m.log
	while _logged < log.size():
		var e: Array = log[_logged]
		out.append({"type": "point", "team": e[2], "why": e[1], "touches": e[0]})
		_logged += 1
	return out


func bodies() -> Array:
	if not _alive():
		return []
	var out := []
	var st := int(m.state)
	var on := not bool(m.paused) and not st in [int(m.S.REPLAY), int(m.S.OVER), int(m.S.INTRO)]
	for side in 2:
		for pp in m.players_on(side):
			var pl: Player = pp
			var link: FoundationLink = pl.body.link
			out.append({"name": "side %d player %d" % [side, pl.slot], "pos": pl.global_position,
				"radius": Player.BODY_R, "height": Player.BODY_H, "body": link.body if link else null, "active": on and pl.move == "",
				"target": pl.target})
	var offs: Officials = m.get("_officials")
	for o in offs.list:
		if not o.standing:
			continue
		var link: FoundationLink = (o.body as RealBody).link
		out.append({"name": "official", "pos": (o.body as Node3D).global_position, "radius": 0.25, "height": 1.8,
			"body": link.body if link else null, "active": on, "target": o.home + o.off_to})
	return out


func ball() -> Dictionary:
	if not _alive():
		return {}
	var b: Ball = m.ball
	if b.global_position.y < -1.0:
		return {}   # (put away out of sight before the first serve: Match keeps it at y -5)
	# (In play: flying or loose - not in a replay, which moves it along the rally's path again from its start.)
	return {"pos": b.global_position, "radius": Ball.RADIUS, "live": (b.flying or b.loose) and int(m.state) != int(m.S.REPLAY)}


func solid() -> WsgSolidProps:
	return m.arena.solid if _alive() and m.arena else null


## The venue's walls (Ball.bounds), a metre round them, and up to the roof.
func bounds() -> AABB:
	if not _alive():
		return super.bounds()
	var r: Rect2 = m.ball.bounds
	return AABB(Vector3(r.position.x - 1.0, -0.5, r.position.y - 1.0), Vector3(r.size.x + 2.0, 40.0, r.size.y + 2.0))


## Rally-point scoring: a point at a time (the score here: the points won over every set, never going down).
func score_steps() -> Array:
	return [1]


## The longest match (best of three to 21, deuce to 25, with replays and the breaks) is under 40 minutes; a short one,
## one set, under 15.
func max_seconds(config: Dictionary) -> float:
	if bool(config.get("short", false)) or int(config.get("sets", 3)) == 1:
		return 900.0 if int(config.get("points", 15)) == 15 else 1200.0
	return 2400.0


## Takraw's own rules, every frame: three touches a side at most; a set's points never past its cap (17 or 25); every
## set won is a legal score (to 15 or 21, two clear, or at the cap); each side has its event's players on court.
func rules() -> Array:
	if not _alive():
		return []
	var out := []
	if int(m.state) == int(m.S.RALLY) and int(m.touches) > 3:
		out.append("a side touched the ball %d times" % int(m.touches))
	var pts := int(m.set_points)
	var cap := 17 if pts == 15 else 25
	for side in 2:
		if int(m.points[side]) > cap:
			out.append("a set's points past its cap: %d (at most %d)" % [int(m.points[side]), cap])
	while _sets_checked < m.set_scores.size():
		var sc: Array = m.set_scores[_sets_checked]
		if not _legal_set(int(sc[0]), int(sc[1]), pts):
			out.append("set %d won %d-%d: not a legal score to %d" % [_sets_checked + 1, sc[0], sc[1], pts])
		_sets_checked += 1
	var want := int(PER_SIDE.get(String(m.event), 3))
	for side in 2:
		var n: int = m.players_on(side).size()
		if n != want:
			out.append("side %d has %d players on court (%s: %d)" % [side, n, m.event, want])
	return out


static func _legal_set(a: int, b: int, points: int) -> bool:
	var cap := 17 if points == 15 else 25
	var hi := maxi(a, b)
	var lo := mini(a, b)
	if hi == cap:
		return lo == cap - 1 or lo == cap - 2
	return hi >= points and hi < cap and hi - lo >= 2 and (hi == points or hi - lo == 2)


func result() -> Dictionary:
	if not _alive():
		return {}
	var s: Array = m.sets
	return {"winner": 0 if int(s[0]) > int(s[1]) else (1 if int(s[1]) > int(s[0]) else -1), "score": [int(s[0]), int(s[1])],
		"set_scores": m.set_scores.duplicate(true), "points": state().score, "rallies": (m.log as Array).size()}


## The balance report's groups: equal sides (team ratings within 3), which side is stronger, the event, the venue,
## the AI's level, the set length.
func balance_keys(config: Dictionary) -> Dictionary:
	var w := bool(config.get("women", false))
	var rh := DB.team_rating(String(config.home), w)
	var ra := DB.team_rating(String(config.away), w)
	return {"fair": absf(rh - ra) < 3.0, "stronger": "home" if rh > ra + 3.0 else ("away" if ra > rh + 3.0 else "even"),
		"event": String(config.event), "venue": String(config.venue), "difficulty": int(config.get("difficulty", 1)),
		"points": int(config.get("points", 15))}


func stop() -> void:
	if _holder and is_instance_valid(_holder):
		_holder.queue_free()
	_holder = null
	m = null
	Game.current = null


func paused() -> int:
	return (1 if bool(m.paused) else 0) if _alive() else -1


func human_team() -> int:
	return int(_cfg.get("user_team", -1))


## The match's three buttons (as their keys, Space, J and K, press them) and the phone's Back (pause and resume).
func input_actions() -> Array:
	return BUTTONS + ["pause"]


## The touch stick: the game's own (TouchControls.joystick, which the match reads every frame).
func stick(v: Vector2) -> bool:
	if not _alive() or m.controls == null:
		return false
	m.controls.joystick = v.limit_length(1.0)
	return true


func cameras() -> Array:
	return [Game.CAM_TV, Game.CAM_SIDE, Game.CAM_END]


func set_camera(i: int) -> void:
	if _alive() and m.cam:
		m.cam.mode = int(cameras()[clampi(i, 0, 2)])
		m.cam.snap()


func menu_start(tree: SceneTree) -> Node:
	_holder = Node.new()
	_holder.name = "Menus"
	tree.root.add_child(_holder)
	Game.main = _holder
	Game.current = null
	return Game.show_screen("res://ui/main_menu.gd")


func in_match() -> bool:
	return Game.current != null and is_instance_valid(Game.current) and Game.current.has_method("set_paused")


func save_paths() -> Array:
	return [Game.SETTINGS_PATH, Game.RECORDS_PATH]


## The input relay: the fuzzer's actions into the game's own controls.
class _Relay extends Node:
	const BUTTONS := ["takraw_button_1", "takraw_button_2", "takraw_button_3"]
	var sim: Object

	func _process(_dt: float) -> void:
		var mm: Node = sim.m
		if mm == null or not is_instance_valid(mm):
			return
		if Input.is_action_just_pressed("pause"):
			Game.go_back()   # (the phone's Back: the pause menu, and Resume)
		var ids: Array = mm.controls.ids if mm.controls else []
		for i in BUTTONS.size():
			if Input.is_action_just_pressed(BUTTONS[i]) and i < ids.size():
				mm.controls._fire(String(ids[i]))
