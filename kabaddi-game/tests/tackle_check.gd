extends Node
## Tackle scenarios: one raider against one defender in the match's lab mode (scripted, the same every run),
## measuring whether a hold is real contact and stays real:
##   - contact gap: how far the holder's hands are from the raider's lower leg when the hold is given;
##   - grip error: while he holds, how far his hands are from the leg he holds (median, 90th percentile, worst);
##   - holder jumps: the holder moving faster than any body can in one frame while he holds;
##   - overlap: the two bodies' middles closer than two people can be;
##   - what happened: each player's states over time, the messages put up, how the raid ended.
## Scenarios (as in the realism plan): "miss" (an ankle dive whose grip fails), "catch" (an ankle hold that
## brings the raider down), "escape" (a raider jumping out of an ankle hold), "whiff" (a dive from too far:
## no hand reaches him, so no hold may be given). --json writes the numbers; "view SCENARIO" plays one on
## screen, from the side, for recording:
##   godot --headless --path . --fixed-fps 30 res://tests/tackle_check.tscn -- [SCENARIO ...] [--json FILE] [--log]
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 --write-movie out.avi \
##       --fixed-fps 30 res://tests/tackle_check.tscn -- view catch

const SCENARIOS := ["miss", "catch", "escape", "whiff"]
const JUMP_SPEED := 10.0        # m/s in one frame
const OVERLAP := 0.25           # m between the two bodies' middles

var _chosen := []
var _json := ""
var _log := false
var _view := false
var _results := {}
var _cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] in SCENARIOS:
			_chosen.append(args[i])
		elif args[i] == "view":
			_view = true
		elif args[i] == "--json" and i + 1 < args.size():
			_json = args[i + 1]
		elif args[i] == "--log":
			_log = true
	if _chosen.is_empty():
		_chosen = SCENARIOS.duplicate()
	Game.settings.models = 1
	Game.settings.camera = Game.CAM_TV
	var failed := 0
	for sc in _chosen:
		var r: Dictionary = await _run(sc)
		_results[sc] = r
		_print(sc, r)
		if not r.ok:
			failed += 1
	if _json != "":
		var f := FileAccess.open(_json, FileAccess.WRITE)
		f.store_string(JSON.stringify(_results, "  "))
	print("tackle_check: %d of %d scenarios as expected" % [_chosen.size() - failed, _chosen.size()])
	get_tree().quit()


func _run(sc: String) -> Dictionary:
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "autoplay": true,
		"autoplay_no_report": true, "length": 0, "difficulty": 1, "players": [7, 1], "style": "ankle",
		"first_raider": 0, "lab": true, "raid_rule": 0}
	add_child(m)
	m.rng.seed = 11
	while m.phase != "raid":
		await get_tree().process_frame
	var r: Athlete = m.raider
	var d: Athlete = m.defenders()[0]
	var home := Vector3(0, 0, m.side(m.raiding))
	var into := -home
	# Set the scene: the raider working the cover past the baulk line, the defender in front of him.
	r.position = m.pos_in(1, 0.0, 2.6 if sc == "whiff" else 3.9)
	r.facing = into
	d.position = m.pos_in(1, 0.3, 5.2)
	d.facing = -into
	# lab_move is a share of his top speed, as a stick would give: about 0.8 m/s sideways.
	m.lab_move = Vector3(0.2, 0, 0)
	if sc != "whiff":
		m.lab_force = {"hold": sc != "miss"}
	else:
		m.lab_force = {"hold": true}   # a hold would be given if there were contact: there must not be
	if _view:
		_stage(m)
	var out := {"scenario": sc, "attached": false, "attach_t": -1.0, "contact_gap": -1.0, "centre_gap": -1.0,
		"grip": [], "jumps": 0, "max_holder_speed": 0.0, "min_overlap": INF, "states_r": [], "states_d": [],
		"shown": [], "end": "", "t_end": -1.0}
	var t := 0.0
	var dived := false
	var escaped := false
	var ended_t := -1.0
	var last_d := d.position
	var last_r_state := ""
	var last_d_state := ""
	var shown_n: int = m.hud.shown.size()
	var ev0: int = m.event_log.size()
	var placed := true
	while t < 12.0:
		var dt := get_process_delta_time()
		dt = dt if dt > 0.0005 else 1.0 / 30.0
		# The script.
		if not dived and t >= 0.5:
			dived = true
			m._defender_tackle(d, "ankle")
		var holding: bool = m.raid.get("holders", []).has(d)
		if holding and not out.attached:
			out.attached = true
			out.attach_t = snappedf(t, 0.01)
			m.lab_move = home * 0.5
		if sc == "escape" and holding and not escaped and t > float(out.attach_t) + 0.9:
			escaped = true
			m.lab_force["escape"] = true
			m._raider_escape("lion", home)
			m.lab_move = home * 1.0
		if sc in ["miss", "whiff"] and dived and t > 1.6:
			m.lab_move = home * 1.0
		await get_tree().process_frame
		t += dt
		if _view:
			_follow(r, d, dt)
		# What the frame did.
		if r.state != last_r_state:
			last_r_state = r.state
			out.states_r.append([snappedf(t, 0.01), r.state])
		if d.state != last_d_state:
			last_d_state = d.state
			out.states_d.append([snappedf(t, 0.01), d.state])
		while shown_n < m.hud.shown.size():
			out.shown.append([snappedf(t, 0.01), String(m.hud.shown[shown_n])])
			shown_n += 1
		var step := Vector2(d.position.x - last_d.x, d.position.z - last_d.z).length() / dt
		last_d = d.position
		holding = m.raid.get("holders", []).has(d)
		if holding and not placed:
			out.max_holder_speed = maxf(out.max_holder_speed, step)
			if step > JUMP_SPEED:
				out.jumps += 1
		placed = false
		if holding:
			var e := _grip(d, r)
			if float(out.contact_gap) < 0.0:
				out.contact_gap = snappedf(e.y, 0.001)
				out.centre_gap = snappedf(Vector2(d.position.x - r.position.x, d.position.z - r.position.z).length(), 0.01)
			out.grip.append(e.x)
			var w1: Vector3 = d.model.anchor("waist")
			var w2: Vector3 = r.model.anchor("waist")
			out.min_overlap = minf(out.min_overlap, Vector2(w1.x - w2.x, w1.z - w2.z).length())
			if _log:
				print("%5.2f %s grip %.3f  d %s r %s" % [t, sc, e.x, d.state, r.state])
		if m.phase != "raid" and ended_t < 0.0:
			ended_t = t
			out.t_end = snappedf(t, 0.01)
			if not m.raid_log.is_empty():
				out.end = String(m.raid_log[-1].kind)
		if ended_t >= 0.0 and t > ended_t + 3.0:
			break
		if ended_t < 0.0 and sc in ["miss", "whiff"] and t > 9.0:
			break
	out.events = []
	for e in m.event_log.slice(ev0):
		out.events.append(String(e[2]))
	var g: Array = out.grip
	out.grip_median = snappedf(_pct(g, 50), 0.001)
	out.grip_p90 = snappedf(_pct(g, 90), 0.001)
	out.grip_max = snappedf(_pct(g, 100), 0.001)
	out.hold_frames = g.size()
	out.erase("grip")
	if out.min_overlap == INF:
		out.min_overlap = -1.0
	out.min_overlap = snappedf(out.min_overlap, 0.01)
	out.max_holder_speed = snappedf(out.max_holder_speed, 0.1)
	# What each scenario must do.
	# One hold, given once; a takedown only for a tackle; nothing held after a miss.
	var holds: int = out.events.count("hold")
	match sc:
		"catch":
			out.ok = out.attached and out.end == "tackle" and holds == 1 and out.events.count("takedown") == 1
		"escape":
			out.ok = out.attached and out.end == "return" and holds == 1 and out.events.count("release") == 1 and out.events.count("escape") == 1 \
				and out.events.count("takedown") == 0
		"miss", "whiff":
			out.ok = not out.attached and holds == 0 and out.events.count("takedown") == 0
	m.queue_free()
	await get_tree().process_frame
	return out


## Grip error (x): how far, on average, the holder's two hands are from the nearest of the raider's lower
## legs (ankle to mid shin). Contact gap (y): the nearer hand's distance.
func _grip(d: Athlete, r: Athlete) -> Vector2:
	var best := Vector2(INF, INF)
	for s in ["l", "r"]:
		var a: Vector3 = r.model.anchor("ankle_" + s)
		var b: Vector3 = r.model.anchor("shin_" + s)
		var e1 := _seg_dist(d.model.anchor("hand_l"), a, b)
		var e2 := _seg_dist(d.model.anchor("hand_r"), a, b)
		var v := Vector2((e1 + e2) * 0.5, minf(e1, e2))
		if v.x < best.x:
			best = v
	return best


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * k)


func _pct(v: Array, q: float) -> float:
	if v.is_empty():
		return -1.0
	var s := v.duplicate()
	s.sort()
	return float(s[clampi(int(round(q / 100.0 * (s.size() - 1))), 0, s.size() - 1)])


func _print(sc: String, r: Dictionary) -> void:
	print("== %s  %s" % [sc, "as expected" if r.ok else "NOT AS EXPECTED"])
	for k in ["attached", "attach_t", "contact_gap", "centre_gap", "hold_frames", "grip_median", "grip_p90", "grip_max",
			"jumps", "max_holder_speed", "min_overlap", "end", "t_end"]:
		print("  %-20s %s" % [k, str(r[k])])
	print("  raider   %s" % [str(r.states_r)])
	print("  defender %s" % [str(r.states_d)])
	print("  shown    %s" % [str(r.shown)])
	print("  events   %s" % [str(r.events)])


## Keep both players in view, from the side.
func _follow(r: Athlete, d: Athlete, dt: float) -> void:
	var mid := (r.position + d.position) * 0.5
	var at := _cam.position - Vector3(5.2, 1.6, 0.0)
	at = at.lerp(Vector3(mid.x, 0.0, mid.z), clampf(dt * 3.0, 0.0, 1.0))
	_cam.position = at + Vector3(5.2, 1.6, 0.0)
	_cam.look_at(at + Vector3(0, 0.5, 0), Vector3.UP)


## Side-on camera for watching a scenario.
func _stage(m: Node) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		add_child(_cam)
		_cam.fov = 40.0
	var mid: Vector3 = m.pos_in(1, 0.2, 4.6)
	_cam.position = mid + Vector3(5.2, 1.6, 0.0)
	_cam.look_at(mid + Vector3(0, 0.5, 0), Vector3.UP)
	_cam.current = true
	m.hud.visible = true
