extends Node
## Tackle scenarios in the match's lab mode (a scripted raid, the same every run), measuring whether holds
## are real contact and stay real:
##   - contact gap: how far the diver's hand was from the part he grabbed when contact was made (the game's own
##     check), and the first frame's grip (his hands, after reaching, from the part he holds);
##   - grip error: while they hold, how far the holders' hands are from what they hold (the lower leg for an
##     ankle hold, the thigh for a thigh hold, the raider's middle for a waist hold or a block), every holder,
##     every frame: median, 90th percentile, worst;
##   - holder jumps: a holder moving faster than any body can in one frame;
##   - overlap: a holder's middle closer to the raider's than two people can be; and holders' middles to each
##     other, when there are several;
##   - what happened: each player's states over time, the messages put up, the gameplay events, the end.
## Scenarios (after the realism plan's list): "miss" (an ankle dive whose grip fails), "catch" (an ankle hold
## that brings the raider down), "escape" (a lion jump out of an ankle hold), "whiff" (a dive from too far: no
## hand reaches him, so no hold may be given), "thigh" and "waist" (those holds, bringing him down), "chain"
## (a hold, then team-mates coming to help, each to a hold of his own), "join" (the raider going down as a
## team-mate runs in to help: one takedown, no hold after it), "committed" (a holder told to tackle again:
## refused), "crowd" (three team-mates helping at once: no two on the same hold, nobody inside anybody),
## "touch" (a hand touch and home: the points given once, the score up by exactly them) and "flurry" (a touch,
## the touched defender grabbing straight back, another diving in, help, a takedown, all within a second or
## two: every event in order, the raid scored once).
## --json writes the numbers; "view SCENARIO" plays one on screen, from the side, for recording ("plain" leaves
## the debug overlay off):
##   godot --headless --path . --fixed-fps 30 res://tests/tackle_check.tscn -- [SCENARIO ...] [--json FILE] [--log]
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 --write-movie out.avi \
##       --fixed-fps 30 res://tests/tackle_check.tscn -- view catch [plain]

const SCENARIOS := ["miss", "catch", "escape", "whiff", "thigh", "waist", "chain", "join", "committed", "crowd", "touch", "flurry"]
const JUMP_SPEED := 10.0        # m/s in one frame
const BODY_R := 0.12            # m: the raider's middle is this thick, for measuring holds round it
# Per scenario: defenders (style each; the first dives), where the first starts (metres in front), helpers.
const SETUP := {
	"miss": {"styles": ["ankle"], "hold": false},
	"catch": {"styles": ["ankle"]},
	"escape": {"styles": ["ankle"]},
	"whiff": {"styles": ["ankle"]},
	"thigh": {"styles": ["thigh"]},
	"waist": {"styles": ["waist"]},
	"chain": {"styles": ["ankle", "thigh", "waist"], "help": true},
	"join": {"styles": ["ankle", "thigh"], "help": true},
	"committed": {"styles": ["ankle"]},
	"crowd": {"styles": ["ankle", "thigh", "thigh", "waist"], "help": true},
	"touch": {"styles": ["thigh", "thigh"], "touch": true, "no_dive": true, "passive": true},
	"flurry": {"styles": ["thigh", "ankle", "waist"], "touch": true, "help": true},
}

var _chosen := []
var _json := ""
var _log := false
var _view := false
var _plain := false
var _results := {}
var _cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] in SCENARIOS:
			_chosen.append(args[i])
		elif args[i] == "view":
			_view = true
		elif args[i] == "plain":
			_plain = true
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
	var setup: Dictionary = SETUP[sc]
	var styles: Array = setup.styles
	seed(11)   # the bodies' own small variations (idle sway, which clip) come from the global generator
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "autoplay": true,
		"autoplay_no_report": true, "length": 0, "difficulty": 1, "players": [7, styles.size()], "style": styles[0],
		"first_raider": 0, "lab": true, "raid_rule": 0, "passive": bool(setup.get("passive", false)), "debug_draw": _view and not _plain}
	add_child(m)
	m.rng.seed = 11
	while m.phase != "raid":
		await get_tree().process_frame
	var r: Athlete = m.raider
	var defs: Array = m.defenders()
	var d: Athlete = defs[0]
	for i in defs.size():
		var a: Athlete = defs[i]
		a.style = String(styles[i])
		a.tackle_kind = ""
		a.dmoves[a.style] = 90
	var home := Vector3(0, 0, m.side(m.raiding))
	var into := -home
	# Set the scene: the raider working the cover past the baulk line, the diver in front of him, any
	# team-mates spread across the line behind.
	r.position = m.pos_in(1, 0.0, 2.6 if sc == "whiff" else 3.9)
	r.facing = into
	# The diver close enough for his dive to reach the part it goes for (a waist dive has to get in closer).
	d.position = m.pos_in(1, 0.0 if styles.size() > 1 else 0.3, 3.9 + {"ankle": 1.6, "thigh": 1.2, "waist": 1.1}.get(d.style, 1.3))
	d.facing = -into
	var touched_one: Athlete = null
	if bool(setup.get("touch", false)):
		# The first defender stands within the raider's hand's reach, to be touched; the diver is the next.
		touched_one = d
		d.position = m.pos_in(1, 0.6, 3.9 + 0.95)
		if defs.size() > 1:
			d = defs[1]
	for i in range(1, defs.size()):
		var a: Athlete = defs[i]
		if a == d and touched_one != null:
			a.position = m.pos_in(1, -0.3, 3.9 + 1.6)
		else:
			a.position = m.pos_in(1, [-2.2, 2.4, -0.6][(i - 1) % 3], [5.6, 5.4, 6.1][(i - 1) % 3])
		a.facing = -into
	var score0: Array = [int(m.teams[0].score), int(m.teams[1].score)]
	# lab_move is a share of his top speed, as a stick would give: about 0.8 m/s sideways.
	m.lab_move = Vector3(0.2, 0, 0)
	m.lab_force = {"hold": bool(setup.get("hold", true))}
	var touch_t := 0.4 if touched_one != null else -1.0
	var touched := false
	if _view:
		_stage(m)
	var out := {"scenario": sc, "attached": false, "attach_t": -1.0, "contact_gap": -1.0, "first_grip": -1.0,
		"grip": [], "jumps": 0, "max_holder_speed": 0.0, "min_overlap": INF, "min_holder_gap": INF, "states_r": [],
		"states_d": [], "shown": [], "end": "", "t_end": -1.0, "refused": true}
	var t := 0.0
	var dived := false
	var escaped := false
	var forced := false
	var retried := false
	var ended_t := -1.0
	var last := {}
	for a in defs:
		last[a] = a.position
	var last_r_state := ""
	var last_d_state := ""
	var shown_n: int = m.hud.shown.size()
	var ev0: int = m.event_log.size()
	var placed := true
	# Motion samples (see _motion): [t, raider state, torso lean (deg), waist height, held foot, free foot,
	# raider body motion, first holder's body motion].
	var mo := []
	var pts_last := {}
	while t < 12.0:
		var dt := get_process_delta_time()
		dt = dt if dt > 0.0005 else 1.0 / 30.0
		# The script.
		if touch_t >= 0.0 and not touched and t >= touch_t:
			touched = true
			m._raider_touch(false)
		if sc == "touch" and touched and t > 0.9:
			m.lab_move = home * 1.0
		if not dived and t >= 0.5 and not bool(setup.get("no_dive", false)):
			dived = true
			m._defender_tackle(d, d.style)
		var holding: bool = m.raid.get("holders", []).has(d)
		if holding and not out.attached:
			out.attached = true
			out.attach_t = snappedf(t, 0.01)
			m.lab_move = home * 0.5
			if bool(setup.get("help", false)):
				m.lab_force["help"] = true
				m.lab_force["pile"] = true   # a helper within reach takes hold at once
		if sc == "escape" and holding and not escaped and t > float(out.attach_t) + 0.9:
			escaped = true
			m.lab_force["escape"] = true
			m._raider_escape("lion", home)
			m.lab_move = home * 1.0
		if sc == "join" and holding and not forced and t > float(out.attach_t) + 0.35:
			forced = true
			m.raid.progress = 1.0   # he goes down now, as the team-mate is still on his way
		if sc == "committed" and holding and not retried and t > float(out.attach_t) + 0.3:
			retried = true
			var n_before: int = m.event_log.size()
			m._defender_tackle(d, "waist")
			out.refused = m.event_log.size() == n_before and d.state == "holding"
		if sc in ["miss", "whiff"] and dived and t > 1.6:
			m.lab_move = home * 1.0
		if sc == "touch" and t > 6.0 and m.phase == "raid":
			break
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
		var holders: Array = m.raid.get("holders", []).duplicate()
		if m.phase == "post":
			holders = defs.filter(func(a): return a.state == "holding")
		for a in defs:
			var step := Vector2(a.position.x - last[a].x, a.position.z - last[a].z).length() / dt
			last[a] = a.position
			if holders.has(a) and not placed:
				out.max_holder_speed = maxf(out.max_holder_speed, step)
				if step > JUMP_SPEED:
					out.jumps += 1
		placed = false
		for a in holders:
			var e := _grip(a, r)
			if a == d and float(out.first_grip) < 0.0:
				out.first_grip = snappedf(e, 0.001)
			out.grip.append(e)
			var w1: Vector3 = a.model.anchor("waist")
			var w2: Vector3 = r.model.anchor("waist")
			out.min_overlap = minf(out.min_overlap, Vector2(w1.x - w2.x, w1.z - w2.z).length())
			for b in holders:
				if b != a:
					var w3: Vector3 = b.model.anchor("waist")
					out.min_holder_gap = minf(out.min_holder_gap, Vector2(w1.x - w3.x, w1.z - w3.z).length())
			if _log:
				print("%5.2f %s %s grip %.3f  %s r %s" % [t, sc, a.style, e, a.state, r.state])
		mo.append(_sample(m, r, d, pts_last, t, dt))
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
	out.slots = []
	out.in_order = true
	var last_n := 0
	var after_down := false
	out.hold_after_takedown = 0
	for e in m.event_log.slice(ev0):
		var k := String(e[2])
		out.events.append(k)
		var info: Dictionary = e[3]
		if int(info.get("n", 0)) <= last_n:
			out.in_order = false
		last_n = int(info.get("n", 0))
		# The hand's distance from the part it grabbed, as the hold was given (the game's own contact check).
		if k == "tackle_contact" and float(out.contact_gap) < 0.0:
			out.contact_gap = snappedf(float(info.get("gap", -1.0)), 0.001)
		if k == "hold":
			out.slots.append(String(info.get("slot", info.get("part", ""))))
			if after_down:
				out.hold_after_takedown += 1
		if k == "takedown":
			after_down = true
	var g: Array = out.grip
	out.grip_median = snappedf(_pct(g, 50), 0.001)
	out.grip_p90 = snappedf(_pct(g, 90), 0.001)
	out.grip_max = snappedf(_pct(g, 100), 0.001)
	out.hold_frames = g.size()
	out.erase("grip")
	for k in ["min_overlap", "min_holder_gap"]:
		out[k] = -1.0 if out[k] == INF else snappedf(out[k], 0.01)
	out.max_holder_speed = snappedf(out.max_holder_speed, 0.1)
	_motion(out, mo)
	# What each scenario must do: holds given once each, on different parts of him; one takedown, and only
	# for a tackle; nothing held after a miss or after the takedown.
	var holds: int = out.events.count("hold")
	var downs: int = out.events.count("takedown")
	# The score moved once, by exactly what the raid gave (plus an all out's two).
	out.scored_once = true
	if not m.raid_log.is_empty() and out.events.count("raid_end") == 1:
		var rl: Dictionary = m.raid_log[-1]
		var atk_gain: int = int(m.teams[0].score) - int(score0[0])
		var def_gain: int = int(m.teams[1].score) - int(score0[1])
		var allout := 2 if m.hud.shown.any(func(x): return String(x) == tr("EV_ALL_OUT")) else 0
		out.score_gain = [atk_gain, def_gain]
		out.raid_pts = [int(rl.raid_pts), int(rl.def_pts)]
		out.scored_once = atk_gain - int(rl.raid_pts) in [0, allout] and def_gain - int(rl.def_pts) in [0, allout]
	elif out.events.count("raid_end") > 1:
		out.scored_once = false
	var distinct := true
	for s in out.slots:
		if out.slots.count(s) > 1:
			distinct = false
	match sc:
		"catch", "thigh", "waist":
			out.ok = out.attached and out.end == "tackle" and holds == 1 and downs == 1
		"escape":
			out.ok = out.attached and out.end == "return" and holds == 1 and out.events.count("release") == 1 \
				and out.events.count("escape") == 1 and downs == 0
		"miss", "whiff":
			out.ok = not out.attached and holds == 0 and downs == 0
		"chain":
			out.ok = out.attached and holds >= 2 and distinct and downs == 1 and out.end == "tackle"
		"join":
			out.ok = out.attached and downs == 1 and out.hold_after_takedown == 0 and out.end == "tackle"
		"committed":
			out.ok = out.attached and out.refused and out.events.count("tackle_attempt") == 1
		"crowd":
			out.ok = out.attached and holds >= 3 and distinct and downs == 1 and float(out.min_holder_gap) > 0.25
		"touch":
			out.ok = out.events.count("touch") == 1 and out.events.count("raid_end") == 1 and out.end == "return" and holds == 0 \
				and out.scored_once and out.in_order
		"flurry":
			out.ok = out.events.count("touch") == 1 and holds >= 1 and downs == 1 and out.events.count("raid_end") == 1 \
				and out.end == "tackle" and out.scored_once and out.in_order and out.hold_after_takedown == 0
	m.queue_free()
	await get_tree().process_frame
	return out


## One frame's motion sample. Body motion: how fast the hands, shoulders, waist and feet move against the
## player's own root (m/s, averaged over the points): a held pose with nothing moving reads near 0.
func _sample(m: Node, r: Athlete, d: Athlete, pts_last: Dictionary, t: float, dt: float) -> Array:
	var sh: Vector3 = (r.model.anchor("shoulder_l") + r.model.anchor("shoulder_r")) * 0.5
	var w: Vector3 = r.model.anchor("waist")
	var up := sh - w
	var lean := rad_to_deg(up.angle_to(Vector3.UP)) if up.length() > 0.01 else 0.0
	var held_side := ""
	if m.grapple:
		for h in m.grapple.holds:
			if h.who == d and String(h.slot).begins_with("leg_"):
				held_side = String(h.slot).substr(4)
	var held_foot := Vector3.INF
	var free_foot := Vector3.INF
	if held_side != "":
		held_foot = r.model.anchor("ankle_" + held_side)
		free_foot = r.model.anchor("ankle_" + ("r" if held_side == "l" else "l"))
	return [t, r.state, lean, w.y, held_foot, free_foot, _body_speed(r, pts_last, dt), _body_speed(d, pts_last, dt),
		d.state]


func _body_speed(a: Athlete, pts_last: Dictionary, dt: float) -> float:
	var pts := []
	for part in ["hand_l", "hand_r", "shoulder_l", "shoulder_r", "waist", "foot_l", "foot_r"]:
		pts.append(a.model.anchor(part) - a.position)
	var last: Array = pts_last.get(a, [])
	pts_last[a] = pts
	if last.size() != pts.size():
		return 0.0
	var sum := 0.0
	for i in pts.size():
		sum += (pts[i] as Vector3).distance_to(last[i]) / maxf(dt, 0.001)
	return sum / pts.size()


## The hold and fall in numbers, from the motion samples:
##   hold_time        s from the first hold to the takedown (or the end of the hold);
##   raider_motion, holder_motion   body motion while held (m/s, median): near 0 is a frozen pose;
##   lean_while_held  the raider's torso lean from upright (deg) early in the hold, halfway and at the end:
##                    rising means he is losing his balance;
##   held_foot_moved  how far the held foot went over the hold (m, along the floor);
##   free_foot_slide  the free foot's speed along the floor while it is down (m/s, 90th percentile);
##   fall_to_floor    s from the takedown to his waist below 0.35 m;
##   fall_lean_rate, fall_drop_rate   the fastest the torso tips (deg/s) and the waist drops (m/s) from 0.3 s
##                    before the takedown to 1.2 s after: how sudden the fall is.
func _motion(out: Dictionary, mo: Array) -> void:
	var held := mo.filter(func(x): return String(x[1]) == "held")
	var down_i := -1
	for i in mo.size():
		if String(mo[i][1]) == "fallen":
			down_i = i
			break
	if held.is_empty():
		return
	var t0: float = held[0][0]
	var t1: float = mo[down_i][0] if down_i >= 0 else float(held[-1][0])
	out.hold_time = snappedf(t1 - t0, 0.01)
	var rm := []
	var hm := []
	for x in held:
		rm.append(x[6])
		if String(x[8]) == "holding":
			hm.append(x[7])
	out.raider_motion = snappedf(_pct(rm, 50), 0.01)
	out.holder_motion = snappedf(_pct(hm, 50), 0.01)
	var early: Array = held[mini(9, held.size() - 1)]
	var mid: Array = held[held.size() / 2]
	out.lean_while_held = [snappedf(float(early[2]), 0.1), snappedf(float(mid[2]), 0.1), snappedf(float(held[-1][2]), 0.1)]
	var feet := held.filter(func(x): return x[4] != Vector3.INF)
	if feet.size() > 1:
		var a: Vector3 = feet[0][4]
		var b: Vector3 = feet[-1][4]
		out.held_foot_moved = snappedf(Vector2(b.x - a.x, b.z - a.z).length(), 0.01)
		var slide := []
		var floor_y := INF
		for x in feet:
			floor_y = minf(floor_y, (x[5] as Vector3).y)
		for i in range(1, feet.size()):
			var p: Vector3 = feet[i][5]
			var q: Vector3 = feet[i - 1][5]
			var dt: float = float(feet[i][0]) - float(feet[i - 1][0])
			if p.y < floor_y + 0.03 and q.y < floor_y + 0.03 and dt > 0.0:
				slide.append(Vector2(p.x - q.x, p.z - q.z).length() / dt)
		out.free_foot_slide = snappedf(_pct(slide, 90), 0.01)
	if down_i < 0:
		return
	var td: float = mo[down_i][0]
	for i in range(down_i, mo.size()):
		if float(mo[i][3]) < 0.35:
			out.fall_to_floor = snappedf(float(mo[i][0]) - td, 0.01)
			break
	var lr := 0.0
	var dr := 0.0
	for i in range(1, mo.size()):
		var tt: float = mo[i][0]
		if tt < td - 0.3 or tt > td + 1.2:
			continue
		var dt: float = tt - float(mo[i - 1][0])
		if dt <= 0.0:
			continue
		lr = maxf(lr, absf(float(mo[i][2]) - float(mo[i - 1][2])) / dt)
		dr = maxf(dr, (float(mo[i - 1][3]) - float(mo[i][3])) / dt)
	out.fall_lean_rate = snappedf(lr, 1.0)
	out.fall_drop_rate = snappedf(dr, 0.01)


## How far, on average, a holder's two hands are from what he holds: the lower leg (ankle to mid shin) for an
## ankle hold, the thigh (mid thigh to above the knee) for a thigh hold, the raider's middle for the rest. The
## nearer leg counts.
func _grip(d: Athlete, r: Athlete) -> float:
	var k: String = d.get("hold_style") if d.get("hold_style") else ""
	if k == "":
		k = d.kind()
	k = {"chain": "thigh", "block": "waist"}.get(k, k)
	var hands: Array = [d.model.anchor("hand_l"), d.model.anchor("hand_r")]
	if k in ["ankle", "thigh"]:
		var best := INF
		for s in ["l", "r"]:
			var a: Vector3
			var b: Vector3
			if k == "ankle":
				a = r.model.anchor("ankle_" + s)
				b = r.model.anchor("shin_" + s)
			else:
				a = r.model.anchor("thigh_" + s)
				b = r.model.anchor("knee_" + s)
				if b == r.model.rig.global_position:   # a body that knows no "knee"
					b = a.lerp(r.model.anchor("shin_" + s), 0.6)
			best = minf(best, (_seg_dist(hands[0], a, b) + _seg_dist(hands[1], a, b)) * 0.5)
		return best
	var w: Vector3 = r.model.anchor("waist")
	return (maxf(0.0, (hands[0] as Vector3).distance_to(w) - BODY_R) + maxf(0.0, (hands[1] as Vector3).distance_to(w) - BODY_R)) * 0.5


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
	for k in ["attached", "attach_t", "contact_gap", "first_grip", "hold_frames", "grip_median", "grip_p90", "grip_max",
			"jumps", "max_holder_speed", "min_overlap", "min_holder_gap", "slots", "end", "t_end", "in_order", "scored_once",
			"score_gain", "raid_pts", "hold_time", "raider_motion", "holder_motion", "lean_while_held", "held_foot_moved",
			"free_foot_slide", "fall_to_floor", "fall_lean_rate", "fall_drop_rate"]:
		print("  %-20s %s" % [k, str(r.get(k, "-"))])
	print("  raider   %s" % [str(r.states_r)])
	print("  defender %s" % [str(r.states_d)])
	print("  shown    %s" % [str(r.shown)])
	print("  events   %s" % [str(r.events)])


## Keep the raider and the first defender in view, from the side.
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
