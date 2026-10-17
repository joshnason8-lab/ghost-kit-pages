extends Node
## Movement stability (tests/motion_probe.gd says what is measured): repeatable encounters and AI play, with who moved
## each player in each frame, whether stages fought over him, and what a viewer would see shake.
## Encounters (lab raids, the same every run):
##   "approach"  one defender, placed by the team's plan (not tackling): the raider steps in, stops, backs off, jinks
##               left and right in front of him, steps in close and goes home: no contact;
##   "approach3" the same with three defenders;
##   "linger"    one defender: the raider walks in to LINGER_DEPTH, 1.6 m short of the defender's place, and stands
##               there LINGER_T, then goes home: a defender giving ground to a raider standing close, and holding it;
##   "ai"        an AI match (SECONDS, 60 by default), every player.
## The holds, escapes, chains, misses and takedowns are tackle_check's scenarios, run with --audit.
##   godot --headless --path . --fixed-fps 30 res://tests/motion_audit.tscn -- [approach|approach3|linger|ai ...] [SECONDS]
##       [--json FILE] [--log] [--seed N]   (N: which AI match)
##   xvfb-run -a godot --path . --rendering-driver opengl3 --write-movie out.avi --fixed-fps 30 \
##       res://tests/motion_audit.tscn -- view approach [tv]
## "view" records one, from a fixed camera side-on (or the game's broadcast camera with "tv").

const Probe := preload("res://tests/motion_probe.gd")
const ENCOUNTERS := ["approach", "approach3", "linger", "ai"]
const LINGER_DEPTH := 3.6     # m into the half the raider stops at in "linger" ...
const LINGER_T := 3.5         # ... and stands there this long

var _chosen := []
var _secs := 60.0
var _json := ""
var _log := false
var _view := false
var _tv := false
var _results := {}
var _seed := 7


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] in ENCOUNTERS:
			_chosen.append(args[i])
		elif args[i] == "view":
			_view = true
		elif args[i] == "tv":
			_tv = true
		elif args[i] == "--json" and i + 1 < args.size():
			_json = args[i + 1]
		elif args[i] == "--log":
			_log = true
		elif args[i] == "--seed" and i + 1 < args.size():
			_seed = int(args[i + 1])
		elif args[i].is_valid_float() and not (i > 0 and args[i - 1] == "--seed"):
			_secs = float(args[i])
	if _chosen.is_empty():
		_chosen = ["approach", "approach3", "linger", "ai"]
	Game.settings.models = 1
	Game.settings.graphics = Game.GFX_LOW if not _view else Game.GFX_MEDIUM
	Game.settings.camera = Game.CAM_TV
	for e in _chosen:
		var r: Dictionary
		if e == "ai":
			r = await _ai()
		else:
			r = await _approach(e)
		_results[e] = r
		_print(e, r)
	if _json != "":
		var f := FileAccess.open(_json, FileAccess.WRITE)
		f.store_string(JSON.stringify(_results, "  "))
	get_tree().quit()


## The raider's stick through the encounter, by time: [until (s), along the court (+ into the half), across].
const SCRIPT := [
	[1.2, 0.6, 0.0],     # in toward the defender
	[1.7, 0.0, 0.0],     # stop
	[2.5, -0.5, 0.0],    # back off
	[3.0, 0.15, 0.6],    # jinks: right ...
	[3.5, 0.15, -0.6],   # ... left ...
	[4.0, 0.15, 0.6],
	[4.5, 0.15, -0.6],
	[5.0, 0.0, 0.6],
	[5.5, 0.0, -0.6],
	[6.4, 0.5, 0.0],     # in close
	[9.0, -1.0, 0.0],    # home
]


func _approach(e: String) -> Dictionary:
	var n := 3 if e == "approach3" else 1
	seed(11)
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "autoplay": true,
		"autoplay_no_report": true, "length": 0, "difficulty": 1, "players": [7, n], "first_raider": 0, "lab": true,
		"raid_rule": 0, "passive": true, "seed": 11}
	add_child(m)
	m.rng.seed = 11
	while m.phase != "raid":
		await get_tree().process_frame
	var r: Athlete = m.raider
	var defs: Array = m.defenders()
	var home := Vector3(0, 0, m.side(m.raiding))
	var into := -home
	var across := into.cross(Vector3.UP)
	r.position = m.pos_in(1, 0.0, 2.2)
	r.facing = into
	for i in defs.size():
		var a: Athlete = defs[i]
		a.position = m.pos_in(1, [0.3, -2.2, 2.4][i], [5.2, 5.6, 5.4][i])
		a.facing = -into
	m.lab_force = {"ai_defence": true}   # placed by the team's plan, as in a match; passive: no tackles
	var probe = Probe.new()
	probe.log_events = _log
	probe.attach(m)
	if _view:
		_stage(m, r)
	var t := 0.0
	var stood := -1.0   # "linger": when he stopped close
	while t < (12.0 if e == "linger" else 9.5) and is_instance_valid(m) and m.phase == "raid":
		var dt := get_process_delta_time()
		dt = dt if dt > 0.0005 else 1.0 / 30.0
		var stick := Vector3.ZERO
		if e == "linger":
			if stood < 0.0 and m.depth_in(1 - m.raiding, r.position) >= LINGER_DEPTH:
				stood = t
			if stood < 0.0:
				stick = into * 0.5
			elif t - stood > LINGER_T:
				stick = -into
		else:
			for s in SCRIPT:
				if t < float(s[0]):
					stick = into * float(s[1]) + across * float(s[2])
					break
		m.lab_move = stick
		await get_tree().process_frame
		t += dt
		probe.frame(dt)
	var out: Dictionary = probe.report()
	if is_instance_valid(m):
		m.queue_free()
	await get_tree().process_frame
	return out


func _ai() -> Dictionary:
	seed(_seed)
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "autoplay": true,
		"autoplay_no_report": true, "length": 0, "difficulty": 1, "seed": _seed}
	add_child(m)
	var probe = Probe.new()
	probe.log_events = _log
	probe.attach(m)
	var t := 0.0
	while t < _secs and is_instance_valid(m):
		var dt := get_process_delta_time()
		dt = dt if dt > 0.0005 else 1.0 / 30.0
		await get_tree().process_frame
		t += dt
		probe.frame(dt)
	var out: Dictionary = probe.report()
	if is_instance_valid(m):
		m.queue_free()
	await get_tree().process_frame
	return out


## Recording: a fixed camera side-on to where the encounter happens (or the game's own broadcast camera with "tv").
func _stage(m: Node, r: Athlete) -> void:
	if _tv:
		return
	m.cam.frozen = true
	var c: Camera3D = m.cam.cam
	var mid := r.position + Vector3(0, 0, -m.side(m.raiding)) * 1.6
	c.global_position = mid + Vector3(7.5, 2.6, 0.0)
	c.look_at(mid + Vector3(0, 0.7, 0))
	c.fov = 45.0


func _print(e: String, r: Dictionary) -> void:
	print("== ", e)
	print("  all          ", r.all)
	print("  camera       ", r.camera)
	print("  conflicts    ", r.conflict_frames, " frames: ", r.conflicts)
	print("  movers       ", r.movers)
	print("  hold flicker ", r.hold_flicker)
	print("  frame ms     median %s p99 %s max %s" % [r.frame_ms.median, r.frame_ms.p99, r.frame_ms.max])
	for w in r.frame_ms.worst:
		print("      ", w)
	for p in r.players:
		print("  %-28s %s" % [p, r.players[p]])
	for st in r.by_state:
		print("  state %-12s %s" % [st, r.by_state[st]])
