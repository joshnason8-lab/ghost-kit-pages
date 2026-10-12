extends Node
## Ordinary AI-v-AI raids, audited frame by frame: whole matches played headless from fixed seeds (the same
## seed plays the same match), every frame of every raid sampled, for every player on the mat when it began (a
## raider tackled or a defender put out too, going down, getting up and walking off, until the raid is over), for
## whether the holds, the bodies and the events hold together outside the scripted scenes of tackle_check:
##   contacts    every hold given: valid if a hand was on the part it holds (within CONTACT_R) once the hands had
##               had time to close on it (CLOSE); and the dive's own contact gap, as the game measured it;
##   grip        every holder, every frame he holds after that: his hands from the part they hold (m);
##   held foot   a foot held at the ankle, every frame: the foot from where the hold has it (m);
##   jumps       a body moving further in one frame than any run, dive or jump carries it (JUMP), and a body's
##               middle moving further than the body itself in a frame (POSE_JUMP): corrections nothing explains;
##   pops        a joint of the body as drawn turning faster than a body can swing it (POP_DEG a 30th of a second);
##   accel       how sharply each body's speed over the floor changes (m/s²), and the frames past HARD_ACCEL;
##   conflicts   states that contradict each other: held with no one holding him, a holder not holding or holding
##               outside a hold, hands left on a body after letting go, a foot held by no one, lying on the floor
##               while moving, standing on one leg with no leg held. Counted in episodes (frames in a row);
##   events      a hold given twice to one holder or on a part already held, a release or an escape from a hold
##               that was not there, a hold after the takedown, two takedowns or raid ends in a raid, points that
##               do not add up;
##   phases      how long each part of a tackle took: winding up, the dive, the hold, the fall to the floor, on
##               the floor, getting up; holders letting go and up after a takedown;
##   overlap     bodies inside one another: spheres round each pelvis, chest and head, overlapping (m);
##   softlocks   a timed state running long past its length, a hold or a raid that does not end, a match that does
##               not finish.
## Prints each measure's distribution (median, 90th and 99th percentile, worst) and the worst cases with where
## they happened (match, raid, seconds into it, player, state). --json writes it all. --digest FILE checks the run
## is the same, event for event, as an earlier run in another process (the first such run writes FILE): the same
## seeds play the same matches. --again plays the first match a second time in the same process (that can part by a
## millimetre after a while: something Godot keeps between matches in one process); --trace adds every player's place
## and state, every frame, to what is compared.
##   godot --headless --path . --fixed-fps 30 res://tests/raid_audit.tscn -- [matches] [first seed] [--json FILE]
##       [--digest FILE] [--again] [--trace]

const JUMP := 9.0            # m/s over the floor in one frame: past any sprint, dive or jump
const POSE_JUMP := 0.2       # m a body's middle moves in one frame beyond what the body itself moved
const POP_DEG := 40.0        # deg a joint turns in a 30th of a second (1200 deg/s)
const HARD_ACCEL := 40.0     # m/s²: a hard cut is about 20
const CONTACT_R := 0.3       # m: a hand this close to the part it holds is on it (Grapple.CONTACT_R)
const CLOSE := 0.25          # s after a hold is given for the hands to have closed on it (Grapple.CLOSE_IN is 0.2)
const OVERLAP := 0.05        # m two bodies' spheres may overlap (skin and kit give) before one is inside the other
const LINGER := 1.5          # s a timed state may run past its length before it is stuck
const STUCK_HOLD := 20.0     # s held before a hold is stuck
const STUCK_RAID := 75.0     # s of raid before a raid is stuck
const SPHERES := [["waist", 0.13], ["chest", 0.15], ["head", 0.11]]
const BONES := ["hips", "spine", "chest", "head", "upperarm_l", "upperarm_r", "forearm_l", "forearm_r", "thigh_l",
	"thigh_r", "shin_l", "shin_r", "foot_l", "foot_r"]
# Timed states that end on their own when their time is up (the match moves them on).
const TIMED := ["touch", "kick", "backkick", "dodge", "dubki", "jump", "telegraph", "dive", "recover", "rise", "shoved",
	"evade"]
# A raider with holds on him is in one of these.
const HELD_OK := ["held", "jump", "dubki", "dodge", "touch", "kick", "backkick", "fallen"]

var _m: Node = null
var _mi := 0
var _seed := 0
var _done := false
var _result := {}
var _clock := 0.0
var _cur = null              # the raid (Match.raid) being sampled
var _raider: Athlete = null  # its raider (Match.raider moves on to the next raid's before the raid is closed)
var _rn := 0                 # raids so far, over every match
var _rt := 0.0               # s into this raid
var _last := {}              # athlete -> [root (flat), middle, velocity (flat), {bone: rotation}]
var _ev := []                # this raid's events: [s into the raid, kind, info]
var _hold_at := {}           # holder -> [s into the raid he took hold, style, slot]
var _pending := []           # holds given, waiting for the hands to close: [holder, at, style, slot, kind]
var _ep := {}                # conflict -> [frames in a row, first frame's context]
var _one_leg := 0            # frames in a row on one leg with no leg held
var _states := {}            # athlete -> [state, s into the raid it began]
var _in_raid := {}           # athlete -> true: on the mat when the raid began (sampled to its end, put out or not)
var _tl := {}                # this raid's tackle timeline (see _phases)
var _down_at := -1.0
var _floor_at := -1.0
var _stuck := {}             # athlete -> state already reported stuck
var _digest := []            # every event and score change, for --again
var _lim := {}               # athlete -> his body's RiggedBody.limited last frame
var _rn0 := 0                # raids before this match
var _trace := false          # --trace: every player's place and state, every frame, into the digest (finding where two
                             # plays of one seed part)

var d := {"grip": [], "held_foot": [], "accel": [], "pose_jump": [], "overlap": [], "contact_gap": []}
var worst := {}              # measure -> [[value, where], ...] (the worst first)
var n := {"frames": 0, "body_frames": 0, "holds": 0, "valid": 0, "invalid": 0, "jumps": 0, "pose_jumps": 0,
	"pops": 0, "hard_accel": 0, "overlaps": 0, "softlocks": 0, "raids": 0, "tackles": 0, "escapes": 0, "limited": 0}
var conflicts := {}          # kind -> [episodes, frames, longest (frames)]
var ev_bad := {}             # kind -> count
var phases := {"telegraph": [], "dive": [], "hold": [], "fall": [], "on_floor": [], "getting_up": [], "let_go": [],
	"holder_up": [], "jump_gather": []}
var score_errors := []
var softlocks := []
var by_state := {}           # measure -> state -> [frames, over the limit]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var count := 4
	var first := 1
	var json := ""
	var digest_file := ""
	var again := false
	var all_digest := []
	var nums := []
	for i in args.size():
		if args[i] == "--json" and i + 1 < args.size():
			json = args[i + 1]
		elif args[i] == "--again":
			again = true
		elif args[i] == "--trace":
			_trace = true
		elif args[i] == "--digest" and i + 1 < args.size():
			digest_file = args[i + 1]
		elif args[i].is_valid_int() and (i == 0 or args[i - 1] not in ["--json", "--digest"]):
			nums.append(int(args[i]))
	if nums.size() > 0:
		count = nums[0]
	if nums.size() > 1:
		first = nums[1]
	var pairs := [["MUM", "DEL"], ["PAT", "BLR"], ["IND", "IRN"], ["KOL", "JAI"]]
	var t0 := Time.get_ticks_msec()
	var first_digest := []
	for i in count:
		_mi = i + 1
		_seed = first + i
		await _play(pairs[i % pairs.size()])
		if i == 0:
			first_digest = _digest.duplicate()
		all_digest.append_array(_digest)
		print("match %d (seed %d): %s %d - %d %s, %d raids so far, %.0f s" % [_mi, _seed, pairs[i % pairs.size()][0],
			_result.score[0], _result.score[1], pairs[i % pairs.size()][1], _rn, (Time.get_ticks_msec() - t0) / 1000.0])
	var same := ""
	if again:
		_mi = 1
		_seed = first
		var keep := [d.duplicate(true), worst.duplicate(true), n.duplicate(), conflicts.duplicate(true), ev_bad.duplicate(),
			phases.duplicate(true), score_errors.duplicate(), softlocks.duplicate(), _rn]
		await _play(pairs[0])
		same = "yes" if _digest == first_digest else "NO (%d events and score changes against %d)" % [_digest.size(), first_digest.size()]
		if _digest != first_digest:
			for k in mini(_digest.size(), first_digest.size()):
				if str(_digest[k]) != str(first_digest[k]):
					if _trace and first_digest[k][0] == "frame" and _digest[k][0] == "frame":
						var a: Array = first_digest[k][3]
						var b: Array = _digest[k][3]
						var diff := []
						for j in mini(a.size(), b.size()):
							if a[j] != b[j]:
								diff.append("%s | %s" % [a[j], b[j]])
						same += "; first difference: raid %d %.3f s: %s (%d against %d players: %s / %s)" % [int(first_digest[k][1]),
							float(first_digest[k][2]), str(diff.slice(0, 6)), a.size(), b.size(), str(a.slice(mini(a.size(), b.size()))),
							str(b.slice(mini(a.size(), b.size())))]
					else:
						same += "; first difference: %s against %s" % [str(first_digest[k]), str(_digest[k])]
					break
		d = keep[0]
		worst = keep[1]
		n = keep[2]
		conflicts = keep[3]
		ev_bad = keep[4]
		phases = keep[5]
		score_errors = keep[6]
		softlocks = keep[7]
		_rn = keep[8]
	var across := ""
	if digest_file != "":
		var mine := JSON.stringify(all_digest)
		if FileAccess.file_exists(digest_file):
			var theirs := FileAccess.get_file_as_string(digest_file)
			across = "yes (%d events and score changes)" % all_digest.size() if theirs == mine else "NO"
			if theirs != mine:
				var a: Array = JSON.parse_string(theirs)
				for k in mini(a.size(), all_digest.size()):
					if JSON.stringify(a[k]) != JSON.stringify(all_digest[k]):
						across += " (first difference: %s against %s)" % [JSON.stringify(a[k]), JSON.stringify(all_digest[k])]
						break
		else:
			var f := FileAccess.open(digest_file, FileAccess.WRITE)
			if f:
				f.store_string(mine)
				f.close()
			across = "written to %s, for the next run to compare" % digest_file
	print("same as the earlier run in another process: %s" % (across if across != "" else "not checked (--digest)"))
	_report(same, json)
	get_tree().quit()


func _play(pair: Array) -> void:
	seed(_seed)
	_digest = []
	_rn0 = _rn
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": pair[0], "away": pair[1], "arena": "dome", "mode": "quick", "autoplay": true,
		"autoplay_no_report": true, "length": 0, "difficulty": 1, "seed": _seed}
	_done = false
	m.finished.connect(func(r):
		_result = r
		_done = true)
	add_child(m)
	m.rng.seed = _seed
	m.game_event.connect(_on_event)
	_m = m
	_cur = null
	_last.clear()
	var frames := 0
	while not _done:
		await get_tree().process_frame
		frames += 1
		_clock += 1.0 / 30.0
		_frame(1.0 / 30.0)
		if frames > 30 * 60 * 15:
			softlocks.append(["match %d did not finish" % _mi, 0.0])
			n.softlocks += 1
			break
	_close_raid()
	_check_points(_result)
	_digest.append(["final", _result.get("score", [])])
	m.queue_free()
	await get_tree().process_frame


func _on_event(kind: String, info: Dictionary) -> void:
	_ev.append([_rt, kind, info.duplicate()])
	if kind == "tackle_contact" and info.has("gap") and String(info.get("kind", "")) != "dash":
		d.contact_gap.append(float(info.gap))   # a dash grips nothing: its "gap" is the bodies' distance
	var same := info.duplicate()
	same.erase("grapple")   # a count kept across matches (Grapple._next_id), not part of the play
	_digest.append([snappedf(_rt, 0.001), kind, str(same)])


# ---------------------------------------------------------------- every frame

func _frame(dt: float) -> void:
	var m := _m
	if m.phase not in ["raid", "post"] or m.raider == null:
		_last.clear()
		return
	if not is_same(m.raid, _cur):
		_close_raid()
		_open_raid(m)
	_rt += dt
	n.frames += 1
	var r: Athlete = m.raider
	if _trace:
		var row := []
		for a in m.athletes:
			if a.on_mat:
				row.append("%s %.4f %.4f %s %.3f" % [a.pid(), a.position.x, a.position.z, a.state, a.st_t])
		_digest.append(["frame", _rn - _rn0, snappedf(_rt, 0.001), row])
	var g = m.grapple
	# Everyone on the mat, and everyone who was when the raid began: a raider tackled or a defender put out is out
	# of the game at once, but still there to be seen, going down, getting up and walking off.
	var mat: Array = []
	for a in m.athletes:
		if (a.on_mat or _in_raid.has(a)) and a.model != null:
			mat.append(a)
	for a in mat:
		_body(a, dt)
	_states_tick(mat)
	_holds(m, r, g)
	_conflicts(m, r, g, mat)
	_overlaps(mat, r, g)
	_timeline(m, r)


func _where(a: Athlete) -> String:
	return "m%d r%d %.2fs %s %s %s" % [_mi, _rn, _rt, _m.phase if _m else "", a.pid() if a else "-", a.state if a else ""]


func _keep(measure: String, v: float, where: String) -> void:
	var w: Array = worst.get(measure, [])
	if w.size() < 5 or v > float(w[-1][0]):
		w.append([snappedf(v, 0.001), where])
		w.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
		if w.size() > 5:
			w.resize(5)
		worst[measure] = w


## A body: how far its root moved (and how sharply its speed changed), its middle beyond that, its joints.
func _body(a: Athlete, dt: float) -> void:
	n.body_frames += 1
	var p := Vector3(a.position.x, 0.0, a.position.z)
	var w: Vector3 = a.model.anchor("waist")
	var rig = a.model.rig
	if rig and rig.get("limited") != null:
		n.limited += int(rig.limited) - int(_lim.get(a, rig.limited))
		_lim[a] = int(rig.limited)
	var rots := {}
	if rig and rig.skeleton:
		for b in BONES:
			if rig._bone.has(b):
				rots[b] = rig.skeleton.get_bone_global_pose(int(rig._bone[b])).basis.get_rotation_quaternion()
	var v := Vector3.ZERO
	if _last.has(a):
		var was: Array = _last[a]
		var step := p - (was[0] as Vector3)
		v = step / dt
		var speed := v.length()
		if speed > JUMP:
			n.jumps += 1
			_keep("jump (m/s)", speed, _where(a))

		var acc := (v - (was[2] as Vector3)).length() / dt
		d.accel.append(acc)
		_tally("accel", a.state, acc > HARD_ACCEL)
		if acc > HARD_ACCEL:
			n.hard_accel += 1
			_keep("accel (m/s²)", acc, _where(a))
		var extra := ((w - (was[1] as Vector3)) - step).length()
		d.pose_jump.append(extra)
		if extra > POSE_JUMP:
			n.pose_jumps += 1
			_keep("pose jump (m)", extra, _where(a))
		var old: Dictionary = was[3]
		var popped := ""
		for b in rots:
			if old.has(b):
				var deg := rad_to_deg((old[b] as Quaternion).angle_to(rots[b])) / (dt * 30.0)
				if deg > POP_DEG:
					n.pops += 1
					popped = b
					_tally("pop bone", b, true)
					_keep("joint pop (deg/30th s)", deg, _where(a) + " " + b)
		_tally("pops", a.state, popped != "")
		if step.length() / dt > JUMP:
			_tally("jumps", a.state, true)
	_last[a] = [p, w, v, rots]


## One frame of a measure, by state (or bone): frames seen, and frames over its limit.
func _tally(measure: String, key: String, over: bool) -> void:
	var m: Dictionary = by_state.get(measure, {})
	var c: Array = m.get(key, [0, 0])
	c[0] = int(c[0]) + 1
	if over:
		c[1] = int(c[1]) + 1
	m[key] = c
	by_state[measure] = m


## Timed states that overstay, and how long each state lasts (for the phases).
func _states_tick(mat: Array) -> void:
	for a in mat:
		var s: Array = _states.get(a, ["", 0.0])
		if String(s[0]) != a.state:
			_states[a] = [a.state, _rt]
			_stuck.erase(a)
			var seq: Array = _tl.states.get(a, [])
			seq.append([a.state, _rt])
			_tl.states[a] = seq
		if a.state in TIMED and a.st_len > 0.0 and a.st_t > a.st_len + LINGER and not _stuck.has(a):
			_stuck[a] = a.state
			n.softlocks += 1
			softlocks.append([_where(a) + " past its length (%.1f s of %.1f)" % [a.st_t, a.st_len], a.st_t - a.st_len])
		if a.state in ["held", "holding"] and a.st_t > STUCK_HOLD and not _stuck.has(a):
			_stuck[a] = a.state
			n.softlocks += 1
			softlocks.append([_where(a) + " for %.1f s" % a.st_t, a.st_t])


## Holds: each new one checked once the hands have had time to close; every hold's grip, every frame after; a
## foot held at the ankle against where the hold has it.
func _holds(m: Node, r: Athlete, g) -> void:
	if g == null:
		return
	var now := {}
	for h in g.holds:
		var who: Athlete = h.who
		now[who] = true
		if not _hold_at.has(who):
			_hold_at[who] = [_rt, String(h.style), String(h.slot)]
			_pending.append([who, _rt, String(h.style), String(h.slot)])
	for who in _hold_at.keys():
		if not now.has(who):
			_hold_at.erase(who)
	for p in _pending.duplicate():
		var who: Athlete = p[0]
		if not now.has(who):
			# Let go before the hands had closed: judged on the last frame he held.
			_pending.erase(p)
			continue
		if _rt - float(p[1]) >= CLOSE:
			_pending.erase(p)
			n.holds += 1
			var e := _grip(who, r, String(p[2]), String(p[3]))
			if e <= CONTACT_R:
				n.valid += 1
			else:
				n.invalid += 1
				_keep("invalid contact (m)", e, _where(who) + " " + String(p[2]))
	for h in g.holds:
		var who: Athlete = h.who
		if who.state != "holding" or _rt - float(_hold_at.get(who, [_rt])[0]) < CLOSE:
			continue
		if String(g.state) != "holding":
			continue   # going down: the holds come off as he falls (a leg pulled out of hands)
		var e := _grip(who, r, String(h.style), String(h.slot))
		d.grip.append(e)
		_keep("grip (m)", e, _where(who) + " " + String(h.style))
		if String(h.style) == "ankle" and r.model.rig:
			var s := String(h.slot).substr(4)
			var fg: Array = r.model.rig.foot_goal.get(s, [])
			if fg.size() >= 2 and float(fg[1]) >= 0.99:
				var off := (fg[0] as Vector3).distance_to(r.model.anchor("foot_" + s))
				d.held_foot.append(off)
				_keep("held foot (m)", off, _where(r))


## A holder's hands from the part he holds (m): the lower leg for an ankle, the thigh for a thigh hold, round the
## middle otherwise.
func _grip(h: Athlete, r: Athlete, style: String, slot: String) -> float:
	var hands: Array = [h.model.anchor("hand_l"), h.model.anchor("hand_r")]
	if slot.begins_with("leg_"):
		var s := slot.substr(4)
		var a: Vector3 = r.model.anchor(("ankle_" if style == "ankle" else "thigh_") + s)
		var b: Vector3 = r.model.anchor(("shin_" if style == "ankle" else "knee_") + s)
		return (_seg_dist(hands[0], a, b) + _seg_dist(hands[1], a, b)) * 0.5
	var w: Vector3 = r.model.anchor("waist")
	return (maxf(0.0, (hands[0] as Vector3).distance_to(w) - 0.12) + maxf(0.0, (hands[1] as Vector3).distance_to(w) - 0.12)) * 0.5


## States that contradict each other, counted in episodes (frames in a row).
func _conflicts(m: Node, r: Athlete, g, mat: Array) -> void:
	var seen := {}
	if m.phase == "raid":
		var holders: Array = m.raid.get("holders", [])
		if holders.is_empty() and r.state == "held":
			seen["held, no one holding"] = r
		if not holders.is_empty() and r.state not in HELD_OK:
			seen["holds on him, raider %s" % r.state] = r
		for a in mat:
			if a == r:
				continue
			var in_g: bool = g != null and g.has(a)
			if a.state == "holding" and not holders.has(a) and not in_g:
				seen["holding outside a hold"] = a
			if holders.has(a) and a.state != "holding":
				seen["holder not holding (%s)" % a.state] = a
	for a in mat:
		if a == r:
			continue
		var rig = a.model.rig
		if rig == null:
			continue
		var in_g: bool = g != null and g.has(a)
		for hs in rig.hand_target:
			var ht: Dictionary = rig.hand_target[hs]
			if ht.get("model") != null and float(ht.get("fade", 0.0)) <= 0.0 and not in_g:
				seen["hands on a body after letting go"] = a
	var rr = r.model.rig
	if rr:
		for s in rr.foot_goal:
			var fg: Array = rr.foot_goal[s]
			var fading := fg.size() > 2 and float(fg[2]) > 0.0
			var held := false
			if g != null:
				for h in g.holds:
					if String(h.slot) == "leg_" + s:
						held = true
			if not fading and not held:
				seen["a foot held by no one"] = r
	for a in mat:
		var speed := 0.0
		if _last.has(a):
			speed = (_last[a][2] as Vector3).length()
		var lying: bool = float(a.model.fallen) > 0.7 or (float(a.model.dive) > 0.7 and a.state not in ["dive", "holding"])
		if lying and speed > 2.5:
			seen["lying on the floor, moving over 2.5 m/s"] = a
	var one = r.model.get("one_leg")
	var ankle := false
	if g != null:
		for h in g.holds:
			if String(h.style) == "ankle":
				ankle = true
	if one != null and float(one) > 0.5 and not ankle:
		_one_leg += 1
		if _one_leg > 9:
			seen["on one leg, no leg held (over 0.3 s)"] = r
	else:
		_one_leg = 0
	for k in seen:
		var e: Array = _ep.get(k, [0, ""])
		if int(e[0]) == 0:
			e[1] = _where(seen[k])
		e[0] = int(e[0]) + 1
		_ep[k] = e
	for k in _ep.keys():
		if not seen.has(k):
			_end_episode(k)


func _end_episode(k: String) -> void:
	var e: Array = _ep[k]
	_ep.erase(k)
	var c: Array = conflicts.get(k, [0, 0, 0])
	c[0] = int(c[0]) + 1
	c[1] = int(c[1]) + int(e[0])
	c[2] = maxi(int(c[2]), int(e[0]))
	conflicts[k] = c
	_keep("conflict: " + k + " (frames)", float(e[0]), String(e[1]))


## Bodies inside one another: each body as three spheres (pelvis, chest, head); for every pair close enough to
## touch, the deepest overlap of any two of their spheres.
func _overlaps(mat: Array, r: Athlete, g) -> void:
	var sph := {}
	for a in mat:
		var w: Vector3 = a.model.anchor("waist")
		var sh: Vector3 = (a.model.anchor("shoulder_l") + a.model.anchor("shoulder_r")) * 0.5
		var up := sh - w
		up = up.normalized() if up.length() > 0.01 else Vector3.UP
		sph[a] = [w, sh - up * 0.08, sh + up * 0.22]
	for i in mat.size():
		var a: Athlete = mat[i]
		for j in range(i + 1, mat.size()):
			var b: Athlete = mat[j]
			if Vector2(a.position.x - b.position.x, a.position.z - b.position.z).length() > 1.6:
				continue
			var deep := -INF
			for x in 3:
				for y in 3:
					var gap: float = (sph[a][x] as Vector3).distance_to(sph[b][y]) - float(SPHERES[x][1]) - float(SPHERES[y][1])
					deep = maxf(deep, -gap)
			if deep <= 0.0:
				continue
			d.overlap.append(deep)
			var kind := "other"
			var ha: bool = g != null and g.has(a)
			var hb: bool = g != null and g.has(b)
			if (a == r and hb) or (b == r and ha):
				kind = "raider and his holder"
			elif ha and hb:
				kind = "two holders"
			elif a == r or b == r:
				kind = "raider and a defender"
			_tally("overlap", kind, deep > OVERLAP)
			if deep > OVERLAP:
				n.overlaps += 1
				_keep("overlap (m): " + kind, deep, _where(a) + " / " + b.pid() + " " + b.state)


## The tackle's timeline this raid, from the players' states and the events (see _phases).
func _timeline(m: Node, r: Athlete) -> void:
	if r.state == "fallen" and _down_at < 0.0:
		_down_at = _rt
	if _down_at >= 0.0 and _floor_at < 0.0 and r.model.anchor("waist").y < 0.4:
		_floor_at = _rt
	if _rt > STUCK_RAID and m.phase == "raid" and not _tl.has("stuck"):
		_tl.stuck = true
		n.softlocks += 1
		softlocks.append(["m%d r%d: raid still going after %.0f s" % [_mi, _rn, _rt], _rt])


func _open_raid(m: Node) -> void:
	_cur = m.raid
	_raider = m.raider
	_rn += 1
	n.raids += 1
	_rt = 0.0
	_ev = []
	_hold_at.clear()
	_pending.clear()
	_states.clear()
	_stuck.clear()
	_in_raid.clear()
	for a in m.athletes:
		if a.on_mat:
			_in_raid[a] = true
	_tl = {"states": {}}
	_down_at = -1.0
	_floor_at = -1.0
	_one_leg = 0


func _close_raid() -> void:
	if _cur == null:
		return
	for k in _ep.keys():
		_end_episode(k)
	_events()
	_phases()
	_cur = null


# ---------------------------------------------------------------- after each raid

## The raid's events together: holds given twice, on a part already held, after the takedown; releases and
## escapes of holds that were not there; takedowns and raid ends more than once.
func _events() -> void:
	var holding := {}   # pid -> slot
	var downs := 0
	var ends := 0
	var after_down := false
	for e in _ev:
		var k: String = e[1]
		var info: Dictionary = e[2]
		match k:
			"hold":
				var who := String(info.get("who", ""))
				var slot := String(info.get("slot", ""))
				if holding.has(who):
					_bad("hold given to a holder already holding", e)
				if slot != "" and holding.values().has(slot):
					_bad("hold on a part already held", e)
				if after_down:
					_bad("hold after the takedown", e)
				holding[who] = slot
			"release":
				var who := String(info.get("who", ""))
				if not holding.has(who):
					_bad("release of a hold that was not there", e)
				holding.erase(who)
			"escape":
				n.escapes += 1
				if not holding.has(String(info.get("from", ""))):
					_bad("escape from a hold that was not there", e)
			"takedown":
				downs += 1
				after_down = true
				n.tackles += 1
			"raid_end":
				ends += 1
	if downs > 1:
		_bad("takedowns in one raid: %d" % downs, [])
	if ends != 1:
		_bad("raid ends in one raid: %d" % ends, [])


func _bad(kind: String, e: Array) -> void:
	ev_bad[kind] = int(ev_bad.get(kind, 0)) + 1
	_keep("event: " + kind, 1.0, "m%d r%d %s" % [_mi, _rn, ("%.2fs %s" % [float(e[0]), str(e[2])]) if e.size() > 2 else ""])


## How long each part of this raid's tackle took, from the events and the players' states: winding up
## (telegraph) and the dive of each defender who went in; the hold, first hold to the takedown or the last hold
## let go; the fall, takedown to the raider's middle at the floor; on the floor until he starts getting up; getting
## up; each holder letting go after the takedown and up on his feet; a lion jump's gather out of a hold to the hold
## letting go.
func _phases() -> void:
	var first_hold := -1.0
	var hold_end := -1.0
	var takedown := -1.0
	var tl: Dictionary = _tl.states
	# When the raider called for a lion jump out of a hold (held, then jump).
	var presses := []
	var rseq: Array = tl.get(_raider, [])
	for i in range(1, rseq.size()):
		if String(rseq[i][0]) == "jump" and String(rseq[i - 1][0]) == "held":
			presses.append(float(rseq[i][1]))
	for e in _ev:
		var t: float = e[0]
		var k: String = e[1]
		match k:
			"hold":
				if first_hold < 0.0:
					first_hold = t
			"takedown":
				takedown = t
				hold_end = t
			"release":
				hold_end = t
			"escape":
				if String(e[2].get("how", "")) == "lion":
					var press := -1.0
					for pt in presses:
						if float(pt) <= t + 0.001:
							press = float(pt)
					if press >= 0.0:
						phases.jump_gather.append(t - press)
			"raid_end":
				if first_hold >= 0.0 and hold_end < 0.0:
					hold_end = t
	if first_hold >= 0.0 and hold_end >= first_hold:
		phases.hold.append(hold_end - first_hold)
	if takedown >= 0.0 and _floor_at >= takedown:
		phases.fall.append(_floor_at - takedown)
	for a in tl:
		var seq: Array = tl[a]
		for i in seq.size():
			var st: String = seq[i][0]
			var t0: float = seq[i][1]
			var t1: float = seq[i + 1][1] if i + 1 < seq.size() else _rt
			var ended := i + 1 < seq.size()   # over before the raid was (not cut off by its end)
			match st:
				"telegraph":
					phases.telegraph.append(t1 - t0)
				"dive":
					phases.dive.append(t1 - t0)
				"fallen":
					if a == _raider and ended and _floor_at >= 0.0 and t1 > _floor_at:
						phases.on_floor.append(t1 - _floor_at)
				"recover":
					if a == _raider and ended and takedown >= 0.0 and t0 > takedown:
						phases.getting_up.append(t1 - t0)
				"holding":
					if takedown >= 0.0 and t1 > takedown and t1 < _rt:
						phases.let_go.append(t1 - takedown)
						for k2 in range(i + 1, seq.size()):
							if String(seq[k2][0]) not in ["recover", "rise", "holding", "fallen"]:
								phases.holder_up.append(float(seq[k2][1]) - takedown)
								break



func _check_points(res: Dictionary) -> void:
	if res.is_empty() or not res.has("raid_log"):
		return
	var rsum := [0, 0]
	var dsum := [0, 0]
	for r in res.raid_log:
		if not r.has("team"):
			return
		rsum[int(r.team)] += int(r.raid_pts)
		dsum[1 - int(r.team)] += int(r.def_pts)
	for t in 2:
		var b: Dictionary = res.breakdown[t]
		if int(res.score[t]) != int(b.raid) + int(b.tackle) + int(b.allout) + int(b.extra) or rsum[t] != int(b.raid) \
				or dsum[t] != int(b.tackle):
			score_errors.append("match %d team %d: score %d, breakdown %s, raids %d, tackles %d" % [_mi, t, int(res.score[t]),
				str(b), rsum[t], dsum[t]])


# ---------------------------------------------------------------- the report

func _pct(v: Array, q: float) -> float:
	if v.is_empty():
		return -1.0
	var s := v.duplicate()
	s.sort()
	return float(s[clampi(int(round(q / 100.0 * (s.size() - 1))), 0, s.size() - 1)])


func _dist(v: Array) -> Dictionary:
	return {"n": v.size(), "median": snappedf(_pct(v, 50), 0.001), "p90": snappedf(_pct(v, 90), 0.001),
		"p99": snappedf(_pct(v, 99), 0.001), "max": snappedf(_pct(v, 100), 0.001)}


func _report(same: String, json: String) -> void:
	var out := {"matches": _mi if same == "" else _mi, "raids": n.raids, "tackles": n.tackles, "escapes": n.escapes,
		"frames": n.frames, "body_frames": n.body_frames, "deterministic": same if same != "" else "-",
		"contacts": {"holds": n.holds, "valid": n.valid, "invalid": n.invalid}, "dist": {}, "counts": {}, "conflicts": conflicts,
		"events": ev_bad, "score_errors": score_errors, "phases": {}, "softlocks": softlocks, "worst": worst}
	for k in d:
		out.dist[k] = _dist(d[k])
	for k in phases:
		out.phases[k] = _dist(phases[k])
	for k in ["jumps", "pose_jumps", "pops", "hard_accel", "overlaps", "softlocks"]:
		out.counts[k] = n[k]
	print("")
	print("raid audit: %d raids (%d tackles, %d escapes), %d frames, %d body-frames" % [n.raids, n.tackles, n.escapes, n.frames, n.body_frames])
	print("deterministic (the first match again): %s" % (same if same != "" else "not checked (--again)"))
	print("contacts: %d holds checked, %d valid, %d invalid (hands over %.2f m from the part once closed)" % [n.holds, n.valid, n.invalid, CONTACT_R])
	print("distributions                  n        median   p90      p99      worst")
	for k in d:
		var x: Dictionary = out.dist[k]
		print("  %-26s %-8d %-8.3f %-8.3f %-8.3f %.3f" % [k, x.n, x.median, x.p90, x.p99, x.max])
	print("counts: jumps over %.0f m/s %d; a body's middle jumping over %.2f m %d; joint pops %d; speed changes over %.0f m/s² %d; bodies inside one another (over %.2f m) %d; softlocks %d" % [
		JUMP, n.jumps, POSE_JUMP, n.pose_jumps, n.pops, HARD_ACCEL, n.hard_accel, OVERLAP, n.overlaps, n.softlocks])
	print("bone turns held back by the final pose stage (RiggedBody._limit_turns): %d (%.2f%% of bone-frames)" % [n.limited,
		100.0 * float(n.limited) / maxf(1.0, float(n.body_frames) * BONES.size())])
	out.counts.limited = n.limited
	print("conflicting states (episodes, frames, longest in frames):")
	if conflicts.is_empty():
		print("  none")
	for k in conflicts:
		print("  %-48s %s" % [k, str(conflicts[k])])
	print("events: %s" % ("all consistent" if ev_bad.is_empty() else str(ev_bad)))
	print("points: %s" % ("every match adds up" if score_errors.is_empty() else str(score_errors)))
	print("tackle phases (s)              n        median   p90      p99      worst")
	for k in phases:
		var x: Dictionary = out.phases[k]
		print("  %-26s %-8d %-8.3f %-8.3f %-8.3f %.3f" % [k, x.n, x.median, x.p90, x.p99, x.max])
	print("softlocks: %s" % ("none" if softlocks.is_empty() else str(softlocks.slice(0, 10))))
	print("by state (frames, over the limit), the ten with the most over:")
	for meas in by_state:
		var rows: Array = []
		for k in by_state[meas]:
			rows.append([k, by_state[meas][k]])
		rows.sort_custom(func(x, y): return int(x[1][1]) > int(y[1][1]))
		var txt := []
		for r in rows.slice(0, 10):
			txt.append("%s %d/%d" % [r[0], int(r[1][1]), int(r[1][0])])
		print("  %-10s %s" % [meas, ", ".join(txt)])
	out.by_state = by_state
	print("worst cases:")
	var keys := worst.keys()
	keys.sort()
	for k in keys:
		print("  %s" % k)
		for w in worst[k]:
			print("      %-9s %s" % [str(w[0]), w[1]])
	if json != "":
		var f := FileAccess.open(json, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(out, "  "))
			f.close()


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * k)
