extends RefCounted
## Who moves each player, frame by frame, and what a viewer sees go wrong (tests/motion_audit, tests/tackle_check
## --audit). The raid's frame moves players in stages (Match.audit names each as it ends: the raider, the defence, keeping
## apart, the court's edges, the grapple, holders kept on); this records how far each stage moved each player and
## measures:
##   - conflicts: two stages in one frame moving a player opposite ways, each over CONFLICT_M; double drives: a player
##     steered (Athlete.drive) twice in one frame, by two owners;
##   - reversals: a player's motion along the floor turning back on itself from one frame to the next, both frames
##     over REV_SPEED: shaking on the spot. On his root (where the game has him) and on his drawn body (the waist);
##   - lurches: a change of velocity in one frame no body makes (over LURCH_ACC), root and drawn body;
##   - facing wobble: the drawn turn swinging one way then back, both frames over WOBBLE_RATE;
##   - avoid flicker: a player's steering round another (Athlete.avoid, from keeping players apart) on, off and on
##     again (or off, on, off) in three frames running: keeping apart and what he steers for at odds, every frame;
##   - state flicker: a state left and come back to within FLICKER_S; hold flicker: a holder let go and back on (or
##     on and let go) within FLICKER_S;
##   - the camera: reversals and lurches of its position, wobble of its turn;
##   - frame cost: wall-clock ms per frame of the whole game (headless: no drawing), the worst frames, what changed in
##     them.
## Use: attach(match) once it is made, frame(dt) once a frame (at the start of the next: everything posed), report().

# The stages come in the order Match.audit names them: "start" first, then (raiding) raider, defence, apart, court,
# grapple, attach, contacts, or (after the raid) grapple, post, apart, walk. "pre" is whatever moved him between the
# last frame's last stage and this one's start.
const CONFLICT_M := 0.004       # m in a frame, each way
const REV_SPEED := 0.15         # m/s: slower than this is standing still, not shaking
const LURCH_ACC := 40.0         # m/s² in one frame: harder than any start, stop or dive launch here
const WOBBLE_RATE := 45.0       # deg/s each way
const FLICKER_S := 0.3

var m: Node = null
var log_events := false
var t := 0.0
var _stage_pos := {}            # athlete -> {stage: position at its end, this frame}
var _end_pos := {}              # athlete -> position at the end of the last frame's raid stages
var _per := {}                  # athlete -> Track
var _cam := {"p": Vector3.INF, "v": Vector3.ZERO, "yaw": INF, "rate": 0.0, "pitch": INF, "prate": 0.0,
	"reversals": 0, "lurches": 0, "wobbles": 0, "frames": 0}
var _cpu := []                  # [ms, t, what happened]
var _last_usec := -1
var _frame_note := []           # what happened this frame (state changes, holds)
var _holders := {}              # athlete -> [on (bool), since]
var hold_flicker := 0
var conflicts := {}             # "stageA+stageB" -> frames
var conflict_frames := 0
var movers := {}                # how many stages moved a player in a frame -> frames (players x frames)


class Track:
	var a: Athlete
	var role := ""
	var p := Vector3.INF
	var v := Vector3.ZERO
	var w := Vector3.INF
	var wv := Vector3.ZERO
	var yaw := INF
	var rate := 0.0
	var state := ""
	var states := []            # [t, state]
	var frames := 0
	var reversals := 0
	var lurches := 0
	var body_reversals := 0
	var body_lurches := 0
	var wobbles := 0
	var flicker := 0
	var conflicts := 0
	var double := 0
	var avoid_on := []          # the last three frames: steering round someone or not
	var avoid_flicker := 0
	var by_state := {}          # state -> {frames, reversals, body_reversals, wobbles, conflicts}

	func bump(st: String, k: String) -> void:
		if not by_state.has(st):
			by_state[st] = {"frames": 0, "reversals": 0, "body_reversals": 0, "lurches": 0, "wobbles": 0, "conflicts": 0, "double": 0,
			"avoid_flicker": 0}
		by_state[st][k] = int(by_state[st][k]) + 1


func attach(p_m: Node) -> void:
	m = p_m
	m.audit = _on_stage
	for a in m.athletes:
		a.drives = 0   # what drove them before this is not counted


func _on_stage(stage: String) -> void:
	for a in m.athletes:
		if not a.on_mat:
			continue
		if not _stage_pos.has(a) or stage == "start":
			_stage_pos[a] = []
		_stage_pos[a].append([stage, a.position])


func role_of(a: Athlete) -> String:
	if a == m.raider:
		return "raider"
	return "defender" if a.team != m.raiding else "team-mate"


## Once a frame, at the start of the next (the last one's moves made and the bodies posed).
func frame(dt: float) -> void:
	t += dt
	var now := Time.get_ticks_usec()
	var ms := float(now - _last_usec) / 1000.0 if _last_usec >= 0 else -1.0
	_last_usec = now
	_frame_note = []
	if m == null or not is_instance_valid(m):
		return
	_stages(dt)
	for a in m.athletes:
		if a.on_mat:
			_track(a, dt)
	_holds()
	_camera(dt)
	if ms >= 0.0:
		_cpu.append([ms, t, ", ".join(_frame_note)])   # the frame just gone, and what changed in it


func _stages(_dt: float) -> void:
	for a in _end_pos.keys():
		if not _stage_pos.has(a):
			_end_pos.erase(a)   # no stages this frame (between raids): the next starts afresh
	for a in _stage_pos:
		if not is_instance_valid(a):
			continue
		var sp: Array = _stage_pos[a]
		if sp.is_empty() or String(sp[0][0]) != "start":
			continue
		var deltas := {}
		var start: Vector3 = sp[0][1]
		var prev: Vector3 = _end_pos.get(a, start)
		deltas["pre"] = start - prev if start.distance_to(prev) < 1.0 else Vector3.ZERO   # put somewhere new: not a move
		var last: Vector3 = start
		for i in range(1, sp.size()):
			var k: String = sp[i][0]
			deltas[k] = (deltas.get(k, Vector3.ZERO) as Vector3) + (sp[i][1] as Vector3) - last
			last = sp[i][1]
		_end_pos[a] = last
		var moving := []
		for st in deltas:
			var d: Vector3 = deltas[st]
			d.y = 0.0
			if d.length() > CONFLICT_M:
				moving.append([st, d])
		movers[moving.size()] = int(movers.get(moving.size(), 0)) + 1
		var hit := false
		for i in moving.size():
			for j in range(i + 1, moving.size()):
				var di: Vector3 = moving[i][1]
				var dj: Vector3 = moving[j][1]
				if di.normalized().dot(dj.normalized()) < -0.5:
					var k := "%s+%s" % [moving[i][0], moving[j][0]]
					conflicts[k] = int(conflicts.get(k, 0)) + 1
					hit = true
					if log_events:
						print("%6.2f CONFLICT %s %s %s %.3f vs %.3f m state=%s" % [t, a.name, moving[i][0], moving[j][0],
							di.length(), dj.length(), a.state])
		if hit:
			conflict_frames += 1
			var tr: Track = _per.get(a)
			if tr:
				tr.conflicts += 1
				tr.bump(a.state, "conflicts")
	_stage_pos.clear()


func _track(a: Athlete, dt: float) -> void:
	if not _per.has(a):
		var nt := Track.new()
		nt.a = a
		_per[a] = nt
	var tr: Track = _per[a]
	tr.role = role_of(a)
	tr.frames += 1
	tr.bump(a.state, "frames")
	if a.drives > 1:
		tr.double += 1
		tr.bump(a.state, "double")
		if log_events:
			print("%6.2f DOUBLE %s driven %d times state=%s phase=%s" % [t, a.name, a.drives, a.state, m.phase])
	a.drives = 0
	# Steering round someone switched on and off every frame.
	tr.avoid_on.append(a.avoid.length() > 0.001)
	if tr.avoid_on.size() > 3:
		tr.avoid_on.pop_front()
	if tr.avoid_on.size() == 3 and tr.avoid_on[0] == tr.avoid_on[2] and tr.avoid_on[0] != tr.avoid_on[1]:
		tr.avoid_flicker += 1
		tr.bump(a.state, "avoid_flicker")
		if log_events:
			print("%6.2f AVOID FLICKER %s state=%s role=%s" % [t, a.name, a.state, m.defence.role_of(a) if m.get("defence") else "-"])
	# State changes, and a state come back to within FLICKER_S of leaving it.
	if a.state != tr.state:
		_frame_note.append("%s %s>%s" % [a.name, tr.state, a.state])
		tr.states.append([t, a.state])
		var n := tr.states.size()
		if n >= 3 and String(tr.states[n - 3][1]) == a.state and t - float(tr.states[n - 2][0]) < FLICKER_S:
			tr.flicker += 1
			if log_events:
				print("%6.2f FLICKER %s %s>%s>%s" % [t, a.name, tr.states[n - 3][1], tr.states[n - 2][1], a.state])
		tr.state = a.state
	var p := Vector3(a.position.x, 0.0, a.position.z)
	if tr.p != Vector3.INF:
		var step := p - tr.p
		if step.length() > 1.0:
			tr.p = p   # put somewhere new (a new raid, the bench): not motion
			tr.v = Vector3.ZERO
			tr.w = Vector3.INF
			return
		var v := step / dt
		if v.length() > REV_SPEED and tr.v.length() > REV_SPEED and v.normalized().dot(tr.v.normalized()) < -0.5:
			tr.reversals += 1
			tr.bump(a.state, "reversals")
			if log_events:
				print("%6.2f REVERSE %s %.2f>%.2f m/s state=%s" % [t, a.name, tr.v.length(), v.length(), a.state])
		if (v - tr.v).length() / dt > LURCH_ACC:
			tr.lurches += 1
			tr.bump(a.state, "lurches")
			if log_events:
				print("%6.2f LURCH %s %.0f m/s2 state=%s" % [t, a.name, (v - tr.v).length() / dt, a.state])
		tr.v = v
	tr.p = p
	# The drawn body: its middle.
	if a.model and a.model.rig:
		var w: Vector3 = a.model.anchor("waist")
		w.y = 0.0
		if tr.w != Vector3.INF:
			var wv := (w - tr.w) / dt
			if wv.length() > REV_SPEED and tr.wv.length() > REV_SPEED and wv.normalized().dot(tr.wv.normalized()) < -0.5:
				tr.body_reversals += 1
				tr.bump(a.state, "body_reversals")
			if (wv - tr.wv).length() / dt > LURCH_ACC * 1.5:
				tr.body_lurches += 1
			tr.wv = wv
		tr.w = w
	# The drawn turn.
	var yaw := a.rotation.y
	if tr.yaw != INF:
		var r := rad_to_deg(wrapf(yaw - tr.yaw, -PI, PI)) / dt
		if absf(r) > WOBBLE_RATE and absf(tr.rate) > WOBBLE_RATE and signf(r) != signf(tr.rate):
			tr.wobbles += 1
			tr.bump(a.state, "wobbles")
			if log_events:
				print("%6.2f WOBBLE %s %.0f>%.0f deg/s state=%s" % [t, a.name, tr.rate, r, a.state])
		tr.rate = r
	tr.yaw = yaw


func _holds() -> void:
	var now: Array = m.raid.get("holders", []) if m.raid is Dictionary else []
	for a in m.athletes:
		var on := now.has(a)
		var h = _holders.get(a)
		if h == null:
			_holders[a] = [on, t]
			continue
		if bool(h[0]) != on:
			if t - float(h[1]) < FLICKER_S and h.size() > 2:
				hold_flicker += 1
				if log_events:
					print("%6.2f HOLD FLICKER %s %s" % [t, a.name, "back on" if on else "let go again"])
			_frame_note.append("%s %s" % [a.name, "takes hold" if on else "lets go"])
			_holders[a] = [on, t, true]


func _camera(dt: float) -> void:
	var c: Camera3D = m.get_viewport().get_camera_3d()
	if c == null:
		return
	var p := c.global_position
	var f := -c.global_basis.z
	var yaw := atan2(f.x, f.z)
	var pitch := asin(clampf(f.y, -1.0, 1.0))
	_cam.frames += 1
	if _cam.p != Vector3.INF:
		var v: Vector3 = (p - (_cam.p as Vector3)) / dt
		var pv: Vector3 = _cam.v
		if v.length() > REV_SPEED and pv.length() > REV_SPEED and v.normalized().dot(pv.normalized()) < -0.5:
			_cam.reversals += 1
		if (v - pv).length() / dt > LURCH_ACC:
			_cam.lurches += 1
		_cam.v = v
		var r := rad_to_deg(wrapf(yaw - float(_cam.yaw), -PI, PI)) / dt
		var pr := rad_to_deg(pitch - float(_cam.pitch)) / dt
		if (absf(r) > 10.0 and absf(float(_cam.rate)) > 10.0 and signf(r) != signf(float(_cam.rate))) \
				or (absf(pr) > 10.0 and absf(float(_cam.prate)) > 10.0 and signf(pr) != signf(float(_cam.prate))):
			_cam.wobbles += 1
		_cam.rate = r
		_cam.prate = pr
	_cam.p = p
	_cam.yaw = yaw
	_cam.pitch = pitch


func report() -> Dictionary:
	var out := {"players": {}, "conflict_frames": conflict_frames, "conflicts": conflicts, "movers": movers,
		"hold_flicker": hold_flicker}
	var sum := {"frames": 0, "reversals": 0, "lurches": 0, "body_reversals": 0, "body_lurches": 0, "wobbles": 0,
		"flicker": 0, "conflicts": 0, "double": 0, "avoid_flicker": 0}
	var by_state := {}
	for a in _per:
		var tr: Track = _per[a]
		var name := "%s (%s)" % [tr.a.name if is_instance_valid(tr.a) else "?", tr.role]
		out.players[name] = {"frames": tr.frames, "reversals": tr.reversals, "lurches": tr.lurches,
			"body_reversals": tr.body_reversals, "body_lurches": tr.body_lurches, "wobbles": tr.wobbles,
			"flicker": tr.flicker, "conflicts": tr.conflicts, "double": tr.double, "avoid_flicker": tr.avoid_flicker}
		for k in sum:
			sum[k] = int(sum[k]) + int(out.players[name][k])
		for st in tr.by_state:
			if not by_state.has(st):
				by_state[st] = {}
			for k in tr.by_state[st]:
				by_state[st][k] = int(by_state[st].get(k, 0)) + int(tr.by_state[st][k])
	out["all"] = sum
	out["by_state"] = by_state
	out["camera"] = {"frames": _cam.frames, "reversals": _cam.reversals, "lurches": _cam.lurches, "wobbles": _cam.wobbles}
	var ms := _cpu.map(func(e): return float(e[0]))
	ms.sort()
	var worst := _cpu.duplicate()
	worst.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
	out["frame_ms"] = {"median": snappedf(_q(ms, 0.5), 0.1), "p99": snappedf(_q(ms, 0.99), 0.1),
		"max": snappedf(ms[-1] if not ms.is_empty() else 0.0, 0.1),
		"worst": worst.slice(0, 5).map(func(e): return "%.1f ms at %.2f s: %s" % [e[0], e[1], e[2]])}
	return out


func _q(v: Array, q: float) -> float:
	if v.is_empty():
		return 0.0
	return float(v[clampi(int(round(q * (v.size() - 1))), 0, v.size() - 1)])
