extends Node3D
## A match: four turns of chasing and defending (two innings), played by the laws in KhoRules, with the umpires, the
## referee and the timekeeper calling it as they do. You control the active chaser when your side chases (each kho
## hands you the next one) and a defender when it defends. The AI plays both sides the way the game is played: the
## chasers chain their khos toward the defender, dive when he is in reach, and turn at the poles; the defenders keep
## behind the active chaser's direction and across the lane from the seated chasers who could rise at them.
## config: see Game.start_match. Every number the AI uses is in docs/AI.md.

signal finished(result: Dictionary)
signal game_event(kind: String)

var config := {}
var fmt := KhoRules.CLASSIC
var f := {}
var turn_len := 180.0
var user := -1                 # the side you play, -1 none
var demo := false              # the AI plays both sides (no haptics, no buttons)
var attract := false           # behind the home screen: on a loop, quiet
var women := false
var knockout := false
var teams := ["", ""]
var arena: Arena
var cam: Camera3D
var hud = null                 # MatchHud
var controls: TouchControls
var dev = null
var roster := [[], []]         # Athletes in this match, per side
var chase_line := [[], []]     # the chasers, per side: [active first, then the seated]
var def_order := [[], []]      # the defenders in batch order, per side
var officials := {}
var score := [0, 0]
var turn := 0
var order: Array = []
var follow_on := false
var phase := "intro"
var phase_t := 0.0
var clock := 0.0
var chasing := 0
var chase := KhoRules.Chase.new()
var active: Athlete = null
var squares: Array = []        # the seated chaser in each square
var sq_face: Array = []
var wazir_ids: Array = []      # the players free of the direction rule now (the wazir; two in a power play)
var d_state := {}              # Athlete -> "wait", "enter", "in", "out"
var batch_k := 0
var batch: Array = []
var batch_time := 0.0
var dream_paid := 0
var since_out := 0.0
var khos_since := 0
var powerplay_used := false
var powerplay_on := false
var powerplay_offer := 0.0     # s left to call a power play (you, the chasing side)
var user_def: Athlete = null
var stats := {}
var turns_log: Array = []
var log: Array = []
var min_chase := false
var min_times := [-1.0, -1.0]
var extra := 0                 # innings played after the four turns (the tie-break)
var paused := false
var rng := RandomNumberGenerator.new()
var t_match := 0.0

var _pending_kho := {}         # a kho in the giving: {i, t, giver, late}
var _to_square := {}           # Athlete -> square index he is walking to after his kho
var _foul_whistle := 0.0
var _ai := {}                  # Athlete -> its thinking: {cool, target, plan}
var _chase_cool := 0.0
var _chase_plan := {}
var _dive_cool := 0.0
var _turn_out_count := 0
var _cam_x := 0.0
var _cam_mode := 0
var _shadows: MultiMeshInstance3D
var _ring: MeshInstance3D
var _target_ring: MeshInstance3D
var _foul_rate := 0.02
var _diff := [0.0, 0.0]        # the AI's rating change per side (difficulty)
var _end_reason := ""
var _min_turns := 0            # minimum-chase turns played, plus one


func _ready() -> void:
	rng.seed = int(config.get("seed", Time.get_ticks_usec()))
	fmt = int(config.get("format", KhoRules.CLASSIC))
	f = KhoRules.field(fmt)
	turn_len = float(config.get("turn_len", 180.0))
	user = int(config.get("user_team", -1))
	demo = user < 0
	attract = bool(config.get("attract", false))
	women = bool(config.get("women", false))
	knockout = bool(config.get("knockout", false))
	teams = [String(config.get("home", "IND")), String(config.get("away", "NEP"))]
	var diff := int(config.get("difficulty", Game.settings.difficulty))
	var ai_k: float = [-16.0, -7.0, 0.0, 5.0][clampi(diff, 0, 3)]
	if user >= 0:
		_diff[1 - user] = ai_k
	_foul_rate = [0.05, 0.035, 0.02, 0.012][clampi(diff, 0, 3)]
	arena = Arena.new(String(config.get("venue", "maidan")), fmt, [DB.kit(teams[0])[0], DB.kit(teams[1])[0]])
	add_child(arena)
	_build_people()
	_build_markers()
	cam = Camera3D.new()
	cam.fov = 46.0
	cam.near = 0.3
	cam.far = 160.0
	add_child(cam)
	cam.current = true
	_cam_mode = int(Game.settings.camera)
	Game.apply_graphics(get_viewport())
	if not attract:
		hud = (load("res://game/hud.gd") as Script).new(self)
		add_child(hud)
		controls = hud.controls
		controls.action.connect(_on_action)
		if bool(Game.settings.get("dev", false)):
			dev = (load("res://game/dev_overlay.gd") as Script).new(self)
			add_child(dev)
	var first := int(config.get("chase_first", 0))
	order = KhoRules.chase_order(first)
	turn = 0
	_start_turn()
	if not attract:
		Sfx.crowd(0.4 * arena.atmosphere())


# ---------------------------------------------------------------- people

func _look(side: int, p: Dictionary) -> Dictionary:
	var k := DB.kit(teams[side])
	var skin_tones := [Color("8d5a3b"), Color("a86b45"), Color("c48a5c"), Color("6e4430"), Color("d9a77a")]
	var tone: Color = skin_tones[int(float(p.get("skin", 0.5)) * skin_tones.size()) % skin_tones.size()]
	return {"skin": tone, "jersey": k[0], "shorts": k[1], "trim": k[2], "shoe": Color("f3efe6"), "hair": Color("16110d"),
		"band": k[2], "hair_style": int(p.get("hair", 0)) if not women else 2, "height": float(p.get("height", 1.75)),
		"barefoot": arena.surface() == "mud" and rng.randf() < 0.5, "long_hair": women}


func _build_people() -> void:
	var n := 12 if fmt == KhoRules.FAST else 9
	for side in 2:
		var squad: Array = DB.pick(teams[side], women, n, false)
		for p in squad:
			var a := Athlete.new(p, side, _look(side, p))
			add_child(a)
			roster[side].append(a)
			stats[p.id] = {"name": p.name, "num": p.num, "side": side, "outs": 0, "dives": 0, "pole_dives": 0, "khos": 0,
				"def_time": 0.0, "best_run": 0.0, "run": 0.0, "times_out": 0, "fouls": 0}
		# The chasers: the best at it; the defenders in batches, the best three first.
		var chasers: Array = roster[side].duplicate()
		chasers.sort_custom(func(a, b): return DB._value(a.data, true) > DB._value(b.data, true))
		chase_line[side] = chasers.slice(0, f.squares + 1)
		var defs: Array = roster[side].duplicate()
		defs.sort_custom(func(a, b): return DB._value(a.data, false) > DB._value(b.data, false))
		def_order[side] = defs.slice(0, (defs.size() / 3) * 3)
	# The officials: two umpires in the lobby, one on each side line; the referee, timekeeper and scorer at the table.
	var ump_look := {"skin": Color("a86b45"), "jersey": Color("f2f2ee"), "shorts": Color("1c1c22"), "trim": Color("1c1c22"),
		"shoe": Color("1c1c22"), "hair": Color("16110d"), "band": Color("f2f2ee"), "hair_style": 1, "height": 1.74}
	var ref_look := ump_look.duplicate()
	ref_look.jersey = Color("1b2a5c")
	ref_look.band = Color("1b2a5c")
	var W: float = f.width * 0.5
	var tz: float = -(W + f.lobby + 1.4)
	for spec in [["ump_a", ump_look, Vector3(-6, 0, W + f.lobby * 0.55)], ["ump_b", ump_look, Vector3(6, 0, -W - f.lobby * 0.55)],
			["referee", ref_look, Vector3(0, 0, tz + 0.9)], ["timekeeper", ref_look, Vector3(-1.0, 0, tz - 0.7)],
			["scorer", ref_look, Vector3(1.0, 0, tz - 0.7)]]:
		var o := Athlete.new({}, -1, spec[1])
		o.position = spec[2]
		o.top = 3.0
		add_child(o)
		officials[spec[0]] = o
	officials.timekeeper.do("sit")
	officials.scorer.do("sit")


func _build_markers() -> void:
	# Every player's shadow is one instance of one quad: one draw call for them all.
	_shadows = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(0.85, 0.85)
	q.orientation = PlaneMesh.FACE_Y
	mm.mesh = q
	mm.instance_count = roster[0].size() + roster[1].size() + officials.size()
	_shadows.multimesh = mm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = _blob_texture()
	sm.albedo_color = Color(0, 0, 0, 0.42)
	_shadows.material_override = sm
	_shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadows)
	_ring = _ring_mesh(Game.C_GOLD, 0.5)
	_target_ring = _ring_mesh(Game.C_CHALK, 0.42)


func _ring_mesh(col: Color, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.07
	tm.outer_radius = r
	tm.rings = 24
	tm.ring_segments = 4
	mi.mesh = tm
	mi.scale = Vector3(1, 0.05, 1)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	mi.material_override = m
	mi.visible = false
	add_child(mi)
	return mi


static var _blob: ImageTexture


static func _blob_texture() -> ImageTexture:
	if _blob:
		return _blob
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d * d, 0.0, 1.0)))
	_blob = ImageTexture.create_from_image(img)
	return _blob


func everyone() -> Array:
	var out: Array = roster[0] + roster[1]
	out.append_array(officials.values())
	return out


# ---------------------------------------------------------------- turns

func defending() -> int:
	return 1 - chasing


func _bench_pos(side: int, i: int) -> Vector3:
	var W: float = f.width * 0.5
	var z: float = -(W + f.lobby + 1.7)
	var s := -1.0 if side == 0 else 1.0
	return Vector3(s * (4.6 + i * 0.75), 0, z)


## Where the next batch waits: standing in the lobby on the far side, ready to come on.
func _wait_pos(i: int) -> Vector3:
	var W: float = f.width * 0.5
	return Vector3(-2.0 + i * 2.0, 0, -(W + f.lobby * 0.5))


func _start_turn() -> void:
	chasing = int(order[turn])
	_turn_out_count = 0
	powerplay_used = false
	powerplay_on = false
	powerplay_offer = 0.0
	_pending_kho = {}
	_to_square = {}
	clock = turn_len
	var d := defending()
	# Everyone to his place: done behind the curtain the HUD draws between turns, so no one is seen to jump.
	for side in 2:
		for i in roster[side].size():
			var a: Athlete = roster[side][i]
			a.position = _bench_pos(side, i)
			a.vel = Vector3.ZERO
			a.want = Vector3.ZERO
			a.do("sit")
			a.face_to = Vector3(a.position.x, 0, 0)
	var line: Array = chase_line[chasing]
	squares = []
	sq_face = []
	for i in f.squares:
		var a: Athlete = line[i + 1]
		a.position = Vector3(float(f.square_x[i]), 0, 0)
		a.face_to = Vector3(a.position.x, 0, 3.0 * KhoRules.square_face(i))
		a.yaw = atan2(0.0, float(KhoRules.square_face(i)))
		a.do("sit")
		squares.append(a)
		sq_face.append(KhoRules.square_face(i))
	active = line[0]
	var pg: float = f.pole_gap * 0.5
	active.position = Vector3(-pg - 0.6, 0, 0.7)
	active.do("")
	active.yaw = PI * 0.5
	chase.reset_at(active.position.x, 1, false)
	# The fast game's wazir: the chasing side's best, free of the direction rule.
	wazir_ids = []
	if fmt == KhoRules.FAST:
		wazir_ids = [String(line[0].data.id)]
	chase.wazir = String(active.data.id) in wazir_ids
	# The defenders: the first batch in the field, the rest waiting in the lobby.
	d_state = {}
	batch_k = 0
	for a in def_order[d]:
		d_state[a] = "wait"
	batch = KhoRules.batch(def_order[d], 0)
	var starts := [Vector3(-3.0, 0, 4.0), Vector3(2.5, 0, -4.5), Vector3(5.5, 0, 3.0)]
	for i in batch.size():
		var a: Athlete = batch[i]
		a.position = starts[i]
		a.do("")
		d_state[a] = "in"
	_place_waiting()
	batch_time = 0.0
	dream_paid = 0
	since_out = 0.0
	khos_since = 0
	user_def = batch[0] if user == d else null
	for a in roster[0] + roster[1]:
		_ai[a] = {"cool": rng.randf() * 0.3, "target": a.position, "wander": rng.randf() * TAU}
	_chase_plan = {}
	_cam_x = 0.0
	phase = "ready"
	phase_t = 0.0
	if hud:
		hud.on_turn_start()
	game_event.emit("turn_start")


## The waiting batches' places in the lobby. At a turn's start they are put there (behind the curtain); in play they
## walk there (_waiting).
var _wait_spot := {}


func _place_waiting(now := true) -> void:
	var d := defending()
	var k := 0
	_wait_spot = {}
	for a in def_order[d]:
		if d_state[a] == "wait":
			var spot := _wait_pos(k % 6) + Vector3(0, 0, -0.9 * floorf(k / 6.0))
			_wait_spot[a] = spot
			if now:
				a.position = spot
				a.do("sit")
				a.face_to = Vector3(a.position.x, 0, 0)
			k += 1


func _waiting() -> void:
	for a in _wait_spot.keys():
		if d_state.get(a, "") != "wait":
			continue
		var to: Vector3 = _wait_spot[a] - a.position
		to.y = 0
		if to.length() < 0.15:
			a.want = Vector3.ZERO
			if a.act != "sit" and a.vel.length() < 0.3:
				a.do("sit")
				a.face_to = Vector3(a.position.x, 0, 0)
		else:
			if a.act == "sit":
				a.do("rise", 0.3)
			a.want = to.normalized() * minf(2.0, to.length() * 3.0)


func _end_turn(reason := "time") -> void:
	if phase != "play":
		return
	phase = "turn_end"
	phase_t = 0.0
	_end_reason = reason
	_pending_kho = {}
	Sfx.play("whistle_long", -2.0)
	officials.referee.do("end", 2.0)
	officials.timekeeper.do("whistle", 1.0)
	for a in roster[0] + roster[1]:
		a.want = Vector3.ZERO
	var pts := 0
	for e in log:
		if int(e.get("turn", -1)) == turn and e.kind == "out":
			pts += int(e.pts)
	var dream := 0
	for e in log:
		if int(e.get("turn", -1)) == turn and e.kind == "dream":
			dream += int(e.pts)
	turns_log.append({"turn": turn, "chaser": chasing, "points": pts, "outs": _turn_out_count, "dream": dream,
		"min_time": min_times[chasing] if min_chase else -1.0})
	game_event.emit("turn_end")
	if hud:
		hud.on_turn_end(reason)


## After a turn: the next, the follow-on choice, the tie-break, or the end.
func _after_turn() -> void:
	if min_chase and _min_turns > 0:
		_min_turns += 1
		if _min_turns % 2 == 1:
			# Both sides have had a minimum chase: the quicker out wins; level, another pair.
			var w := KhoRules.min_chase_winner(min_times)
			if w >= 0:
				_finish(w)
				return
			min_times = [-1.0, -1.0]
			order.append(order[0])
			order.append(order[1])
		turn += 1
		_start_turn()
		return
	if turn == 1 and fmt == KhoRules.CLASSIC and bool(config.get("follow_on", Game.settings.follow_on)) \
			and KhoRules.can_follow_on(fmt, turn_len, int(order[0]), score):
		var a := int(order[0])
		if a == user and hud:
			hud.ask_follow_on()
			phase = "choose"
			return
		follow_on = true   # the AI always makes a side that far behind follow on
		order = KhoRules.chase_order(a, true)
		_log("follow_on", {"side": a})
		if hud:
			hud.callout(tr("CALL_FOLLOW_ON"), Game.C_GOLD)
	if turn < 3 and KhoRules.over_after(turn, order, score):
		_finish(KhoRules.winner(score))
		return
	if turn >= 3 + extra * 2:
		var w := KhoRules.winner(score)
		if w < 0 and knockout:
			if extra == 0:
				# One more innings: each side chases a turn, in the first innings' order.
				extra = 1
				order.append(order[0])
				order.append(order[1])
				if hud:
					hud.callout(tr("CALL_EXTRA_INNINGS"), Game.C_GOLD)
			else:
				# Still level: minimum chases.
				min_chase = true
				_min_turns = 1
				min_times = [-1.0, -1.0]
				order.append(order[0])
				order.append(order[1])
				if hud:
					hud.callout(tr("CALL_MIN_CHASE"), Game.C_GOLD)
			turn += 1
			_start_turn()
			return
		_finish(w)
		return
	turn += 1
	_start_turn()


## Your answer to the follow-on question (the HUD's).
func choose_follow_on(yes: bool) -> void:
	if yes:
		follow_on = true
		order = KhoRules.chase_order(int(order[0]), true)
		_log("follow_on", {"side": int(order[0])})
	phase = "turn_end"
	phase_t = 99.0
	if KhoRules.over_after(turn, order, score):
		_finish(KhoRules.winner(score))
		return
	turn += 1
	_start_turn()


func _finish(w: int) -> void:
	phase = "over"
	for a in roster[0] + roster[1]:
		a.want = Vector3.ZERO
		if w >= 0 and a.side == w and a.act != "sit":
			a.do("cheer", 2.0)
	var result := {"config": config, "score": score.duplicate(), "winner": w, "turns": turns_log, "stats": stats, "log": log,
		"follow_on": follow_on, "extra": extra, "min_chase": min_chase, "teams": teams}
	if not demo and not attract:
		Sfx.react("applause", -4.0)
	game_event.emit("over")
	finished.emit(result)
	if attract or bool(config.get("test", false)):
		return
	await get_tree().create_timer(2.5).timeout
	if is_inside_tree():
		Game.on_match_finished(result)


func _log(kind: String, extra_data := {}) -> void:
	var e := {"kind": kind, "turn": turn, "t": turn_len - clock}
	e.merge(extra_data)
	log.append(e)


# ---------------------------------------------------------------- the frame

func _process(delta: float) -> void:
	if paused:
		return
	var dt := minf(delta, 0.05)
	t_match += dt
	phase_t += dt
	match phase:
		"ready":
			if phase_t >= 1.6:
				phase = "play"
				phase_t = 0.0
				Sfx.play("whistle", -2.0)   # the timekeeper's long and short whistle: the turn is on
				officials.timekeeper.do("whistle", 0.8)
				game_event.emit("play")
		"play":
			_play(dt)
		"turn_end":
			var wait := 3.0 if not demo else 1.6
			if attract:
				wait = 2.0
			if phase_t >= wait and phase_t < 50.0:
				phase_t = 99.0
				if hud and not demo and user >= 0:
					hud.show_interval()
					phase = "interval"
				else:
					_after_turn()
	_officials(dt)
	for a in everyone():
		a.integrate(dt)
	_update_markers()
	_camera(dt)
	_auto_graphics(delta)


## Auto graphics: if the first stretch of play runs under about 36 frames a second, a level lower (once a match).
var _perf_t := 0.0
var _perf_frames := 0
var _perf_done := false


func _auto_graphics(delta: float) -> void:
	if _perf_done or attract or demo or phase != "play" or not bool(Game.settings.auto_gfx):
		return
	_perf_t += delta
	_perf_frames += 1
	if _perf_t < 8.0:
		return
	_perf_done = true
	var fps := float(_perf_frames) / _perf_t
	if fps < 36.0 and int(Game.settings.graphics) > Game.GFX_LOW and Game.frame_cap() != Game.saver_cap(Game.screen_hz()):
		Game.settings.graphics = int(Game.settings.graphics) - 1
		Game.save_settings()
		Game.apply_graphics(get_viewport())
		ToonBody.material(int(Game.settings.graphics) > Game.GFX_LOW)
		game_event.emit("graphics")


## The interval between turns is over (the HUD's Next turn).
func next_turn() -> void:
	if phase == "interval":
		_after_turn()


func _play(dt: float) -> void:
	clock -= dt
	since_out += dt
	_dive_cool -= dt
	if powerplay_offer > 0.0:
		powerplay_offer -= dt
	if clock <= 0.0:
		clock = 0.0
		_end_turn("time")
		return
	# Who wants to go where.
	_chase_input(dt)
	_sitters(dt)
	_kho_step(dt)
	for a in batch:
		if d_state.get(a, "") in ["in", "enter"]:
			if a == user_def:
				_user_defender(dt)
			else:
				_defender_think(a, dt)
	for a in d_state.keys():
		if d_state[a] == "out":
			var home := _bench_pos(defending(), roster[defending()].find(a))
			var to: Vector3 = home - a.position
			to.y = 0
			if to.length() < 0.25:
				a.want = Vector3.ZERO
				if a.act != "sit":
					a.do("sit")
			else:
				a.want = to.normalized() * minf(2.4, to.length() * 3.0)
	_waiting()
	for a in _to_square.keys():
		var i: int = _to_square[a]
		var sq := Vector3(float(f.square_x[i]), 0, 0)
		var to2: Vector3 = sq - a.position
		to2.y = 0
		if to2.length() < 0.06:
			a.want = Vector3.ZERO
			a.vel = Vector3.ZERO
			a.do("sit")
			a.face_to = Vector3(sq.x, 0, 3.0 * float(sq_face[i]))
			_to_square.erase(a)
		else:
			a.want = to2.normalized() * minf(2.2, to2.length() * 6.0)
	# The umpires watch the active chaser.
	if active and not active.busy():
		var foul := KhoRules.step_chase(f, chase, active.position, active.vel, dt)
		if foul != "":
			_on_foul(foul)
	if chase.foul != "":
		_foul_whistle -= dt
		if _foul_whistle <= 0.0:
			_foul_whistle = 0.32
			Sfx.play("whistle_short", -6.0)   # short whistles, again and again, until it is put right
	_touches()
	_limits_and_entry(dt)
	_dream(dt)


# ---------------------------------------------------------------- the chase

func _user_chasing() -> bool:
	return user >= 0 and user == chasing and not demo


func _chase_input(dt: float) -> void:
	if active == null:
		return
	if _user_chasing():
		_user_chaser(dt)
	else:
		_chaser_think(dt)


## Keeps a want legal for the active chaser: no turning back off his direction, no crossing the lane, inside the
## limits. The AI always; you with the lane assist on.
func _legal(want: Vector3) -> Vector3:
	var p := active.position
	var w := want
	if not KhoRules.in_free_zone(f, p):
		if chase.dir != 0 and not chase.wazir and not (String(active.data.id) in wazir_ids):
			w.x = float(chase.dir) * maxf(w.x * float(chase.dir), 0.0)
		var edge: float = f.lane_w * 0.5 + 0.22
		if float(chase.half) * p.z < edge + 0.25 and float(chase.half) * w.z < 0.0:
			w.z = 0.0
			if float(chase.half) * p.z < edge:
				w.z = float(chase.half) * 1.0
	var L: float = f.length * 0.5 - 0.3
	var W: float = f.width * 0.5 - 0.3
	if (p.x > L and w.x > 0.0) or (p.x < -L and w.x < 0.0):
		w.x = 0.0
	if (p.z > W and w.z > 0.0) or (p.z < -W and w.z < 0.0):
		w.z = 0.0
	return w


func _user_chaser(_dt: float) -> void:
	var j := controls.joystick if controls else Vector2.ZERO
	var w := Vector3(j.x, 0, j.y) * active.top
	if bool(Game.settings.lane_assist):
		w = _legal(w)
	if not active.busy():
		active.want = w
	active.top = _top_speed(active, true)
	var ids := ["KHO", "DIVE"]
	if powerplay_offer > 0.0 and not powerplay_used:
		ids.append("POWERPLAY")
	controls.set_buttons(ids)
	controls.lit = "KHO" if _kho_target(false) >= 0 else ""


func _top_speed(a: Athlete, chaser: bool) -> float:
	var r: float = a.speed_rating() + float(_diff[a.side])
	var top := 5.7 + 2.3 * clampf(r / 100.0, 0.2, 1.05)
	if not chaser:
		top *= lerpf(0.82, 1.0, a.stamina)
	return top


## The square whose seated chaser the active chaser can kho now: the nearest ok one; with late, also one he has just
## passed (a late kho, a foul). -1 none.
func _kho_target(late: bool) -> int:
	if active == null or active.busy():
		return -1
	var best := -1
	var bd := 9.0
	for i in squares.size():
		if _to_square.values().has(i):
			continue
		var r := KhoRules.kho_check(f, chase, active.position, float(f.square_x[i]), int(sq_face[i]))
		if r == "ok" or (late and r == "late"):
			var d: float = absf(active.position.x - float(f.square_x[i]))
			if r == "late":
				d += 2.0
			if d < bd:
				bd = d
				best = i
	return best


func _on_action(id: String) -> void:
	if paused or phase != "play":
		return
	match id:
		"KHO":
			if _user_chasing():
				var i := _kho_target(true)
				if i >= 0:
					_give_kho(i)
		"DIVE":
			if _user_chasing() and not active.busy():
				_dive_at(_nearest_defender(active.position, 3.0))
		"POWERPLAY":
			if _user_chasing() and powerplay_offer > 0.0:
				_call_powerplay()
		"DODGE":
			if user_def and not user_def.busy():
				user_def.vel += user_def.vel.normalized() * 1.6 if user_def.vel.length() > 0.5 else Vector3.ZERO
				user_def.stamina = maxf(0.0, user_def.stamina - 0.08)
				Sfx.voice("hup", -12.0)
		"SWITCH":
			_switch_defender()


func _switch_defender() -> void:
	if user != defending():
		return
	var live: Array = []
	for a in batch:
		if d_state.get(a, "") == "in":
			live.append(a)
	if live.is_empty():
		return
	var i := live.find(user_def)
	user_def = live[(i + 1) % live.size()]


func _nearest_defender(p: Vector3, within: float) -> Athlete:
	var best: Athlete = null
	var bd := within
	for a in batch:
		if d_state.get(a, "") != "in":
			continue
		var d: float = (a.position - p).length()
		if d < bd:
			bd = d
			best = a
	return best


## A kho to the seated chaser in square i: the giver's palm on his back and the call; a moment later he is up and
## the chase is his, and the giver takes his square.
func _give_kho(i: int) -> void:
	if not _pending_kho.is_empty():
		return
	var check := KhoRules.kho_check(f, chase, active.position, float(f.square_x[i]), int(sq_face[i]))
	if check == "late":
		_on_foul(KhoRules.FOUL_LATE_KHO)
		return
	if check != "ok":
		return
	active.want = Vector3.ZERO
	active.face_to = squares[i].position
	active.do("kho", 0.3)
	_pending_kho = {"i": i, "t": 0.16, "giver": active}
	Sfx.voice("hup", -4.0, 1.25)
	Sfx.play("slap", -8.0)
	if hud:
		hud.callout(tr("CALL_KHO"), Game.C_SAFFRON, active.position)
	if _user_chasing():
		Game.haptic("kho")
	stats[active.data.id].khos += 1
	khos_since += 1
	_log("kho", {"by": active.data.id, "square": i})
	game_event.emit("kho")


func _kho_step(dt: float) -> void:
	if _pending_kho.is_empty():
		return
	_pending_kho.t = float(_pending_kho.t) - dt
	if float(_pending_kho.t) > 0.0:
		return
	var i: int = _pending_kho.i
	var giver: Athlete = _pending_kho.giver
	var riser: Athlete = squares[i]
	_pending_kho = {}
	riser.do("rise", 0.32)
	riser.want = Vector3(0, 0, float(sq_face[i]) * 3.0)
	active = riser
	chase.reset_at(float(f.square_x[i]), int(sq_face[i]), String(riser.data.id) in wazir_ids)
	squares[i] = giver
	_to_square[giver] = i
	_chase_plan = {}
	_chase_cool = 0.12
	# The classic game: a batch not in by the time of this kho is out.
	_late_entry_check()


func _sitters(dt: float) -> void:
	for a in squares:
		if a == active or _to_square.has(a):
			continue
		a.want = Vector3.ZERO
		if a.act != "sit" and a.act != "foul":
			a.do("sit")
	# Now and then a seated chaser rises before the kho is on his back: a foul, and he goes down again.
	if not _user_chasing() and rng.randf() < _foul_rate * 0.04 * dt and _pending_kho.is_empty():
		var i := rng.randi() % squares.size()
		var a: Athlete = squares[i]
		if a != active and not _to_square.has(a):
			_on_foul(KhoRules.FOUL_EARLY, a)


## The AI's active chaser: weighs chasing his man where he is, a kho to the seated chaser nearest him on the other
## side, and running round the pole, and takes the quickest.
func _chaser_think(dt: float) -> void:
	if active.busy():
		return
	active.top = _top_speed(active, true)
	_chase_cool -= dt
	if _chase_cool <= 0.0:
		var read := float(active.data.get("read", 70)) + float(_diff[chasing])
		_chase_cool = lerpf(0.32, 0.1, clampf(read / 100.0, 0.0, 1.0))
		_chase_plan = _plan_chase()
	var plan := _chase_plan
	var p := active.position
	var target: Vector3 = plan.get("at", p)
	var speed := active.top
	match String(plan.get("kind", "")):
		"kho":
			var i: int = plan.i
			var r := KhoRules.kho_check(f, chase, p, float(f.square_x[i]), int(sq_face[i]))
			if r == "ok" and absf(p.x - float(f.square_x[i])) < 0.55:
				_give_kho(i)
				return
			if r == "late":
				if rng.randf() < _foul_rate:
					_give_kho(i)   # a late kho all the same: the umpire whistles it
				_chase_plan = {}
				_chase_cool = 0.0
				return
			# Slow into the kho, so as not to run past the cross lane.
			var dx := absf(p.x - float(f.square_x[i]))
			speed = minf(speed, 2.6 + dx * 2.2)
		"chase":
			var d: Athlete = plan.d
			if d_state.get(d, "") != "in":
				_chase_plan = {}
			else:
				var dist := (d.position - p).length()
				var reach := 1.5 + float(active.data.get("reach", 70)) / 100.0 * 0.8
				var near_line: bool = absf(d.position.z) > f.width * 0.5 - 1.6 or absf(d.position.x) > f.length * 0.5 - 1.4
				if dist < reach and dist > 0.9 and _dive_cool <= 0.0 and KhoRules.touch_counts(f, chase, p, d.position) \
						and (near_line or rng.randf() < 0.35):
					_dive_at(d)
					return
				target = d.position + d.vel * clampf(dist / 8.0, 0.1, 0.5)
		"pole":
			pass
		"pole_dive":
			var d2: Athlete = plan.d
			if d_state.get(d2, "") == "in" and KhoRules.in_free_zone(f, p) and (d2.position - p).length() < 2.6:
				_pole_dive_at(d2)
				return
	var to := target - p
	to.y = 0.0
	var w := to.normalized() * speed if to.length() > 0.1 else Vector3.ZERO
	# Round the pole: in the free zone, swing round it to the side the plan wants.
	if String(plan.get("kind", "")) == "pole" and KhoRules.in_free_zone(f, p):
		var out_half: int = plan.get("half", chase.half)
		w = Vector3(-signf(p.x) * 2.0, 0, float(out_half) * 4.0).normalized() * speed
		if absf(p.z) < 0.6:
			w.x = signf(p.x) * speed * 0.4
	active.want = _legal(w)


func _plan_chase() -> Dictionary:
	var p := active.position
	var v := active.top
	var best := {"kind": "", "at": p + Vector3(float(chase.dir) * 2.0, 0, 0), "t": 99.0}
	var live: Array = []
	for a in batch:
		if d_state.get(a, "") == "in":
			live.append(a)
	if live.is_empty():
		# No one to chase: hold near the middle of his half, ready.
		best.at = Vector3(clampf(p.x + float(chase.dir) * 1.0, -6, 6), 0, float(chase.half) * 3.0)
		return best
	var fz := KhoRules.in_free_zone(f, p)
	for d in live:
		var dp: Vector3 = d.position
		var dist := (dp - p).length()
		# Chase him where he is: on this side, and ahead (or anywhere for the wazir, or from the free zone).
		var same := KhoRules.half_of(dp.z) == chase.half or absf(dp.z) < 0.3
		var ahead: bool = chase.dir == 0 or chase.wazir or fz or (dp.x - p.x) * float(chase.dir) > -0.4
		if same and ahead:
			var t := dist / (v * 0.34) + 0.3
			if t < float(best.t):
				best = {"kind": "chase", "d": d, "at": dp, "t": t}
		# A kho: to a seated chaser whose back is to this side, ahead of him, facing the defender's side.
		for i in squares.size():
			if _to_square.values().has(i):
				continue
			if int(sq_face[i]) != -chase.half:
				continue
			var sx := float(f.square_x[i])
			var ahead_k: bool = chase.dir == 0 or chase.wazir or (sx - p.x) * float(chase.dir) > 0.15
			if not ahead_k and not fz:
				continue
			if not (KhoRules.half_of(dp.z) == int(sq_face[i]) or absf(dp.z) < 0.3):
				continue
			var kp := Vector3(sx - float(chase.dir if chase.dir != 0 else signf(sx - p.x)) * 0.25, 0, float(chase.half) * 0.55)
			var t2 := (kp - p).length() / v + 0.5 + (dp - Vector3(sx, 0, 0)).length() / (v * 0.34)
			if t2 < float(best.t):
				best = {"kind": "kho", "i": i, "at": kp, "t": t2}
	# Round the pole, when what he wants is behind him.
	if not fz and chase.dir != 0 and not chase.wazir:
		var px: float = float(chase.dir) * (f.pole_gap * 0.5 + 0.7)
		var tp := absf(px - p.x) / v + 1.0
		for d in live:
			var t3: float = tp + (d.position - Vector3(px, 0, 0)).length() / (v * 0.34)
			if absf(d.position.x) > f.pole_gap * 0.5 - 2.2 and signf(d.position.x) == float(chase.dir):
				# Near that pole: a pole dive may reach him.
				t3 -= 1.2
			if t3 < float(best.t):
				best = {"kind": "pole", "at": Vector3(px, 0, float(chase.half) * 0.8), "t": t3, "half": KhoRules.half_of(d.position.z), "d": d}
	if fz:
		var nd := _nearest_defender(Vector3(signf(p.x) * f.pole_gap * 0.5, 0, 0), 2.4)
		if nd:
			best = {"kind": "pole_dive", "d": nd, "at": nd.position, "t": 0.5}
	return best


func _dive_at(d: Athlete) -> void:
	var p := active.position
	var dir := Vector3(sin(active.yaw), 0, cos(active.yaw))
	if d:
		dir = (d.position + d.vel * 0.2 - p)
		dir.y = 0
		dir = dir.normalized()
	if KhoRules.in_free_zone(f, p) and absf(absf(p.x) - f.pole_gap * 0.5) < 1.4 and d:
		_pole_dive_at(d)
		return
	active.vel = dir * maxf(active.vel.length(), 5.6)
	active.yaw = atan2(dir.x, dir.z)
	active.do("dive", 0.5)
	_dive_cool = 1.6
	stats[active.data.id].dives += 1
	Sfx.play("whoosh", -6.0)
	Sfx.voice("grunt", -6.0)
	if _user_chasing():
		Game.haptic("dive")
	game_event.emit("dive")


func _pole_dive_at(d: Athlete) -> void:
	var pole := Vector3(signf(active.position.x) * f.pole_gap * 0.5, 0, 0)
	var dir := (d.position - pole)
	dir.y = 0
	dir = dir.normalized()
	active.vel = dir * 3.0
	active.yaw = atan2(dir.x, dir.z)
	active.do("pole_dive", 0.45, dir.z * signf(pole.x) < 0.0)
	_dive_cool = 1.6
	stats[active.data.id].pole_dives += 1
	Sfx.voice("grunt", -6.0)
	game_event.emit("pole_dive")


## Has the active chaser's hand found a defender? A touch counts unless a foul is on (KhoRules.touch_counts).
func _touches() -> void:
	if active == null:
		return
	var fwd := Vector3(sin(active.yaw), 0, cos(active.yaw))
	var hand := active.position + fwd * 0.4
	var hand_r := 0.55
	var kind := KhoRules.OUT_TOUCH
	if active.act == "dive":
		if active.act_t < 0.08 or active.act_t > 0.45:
			return
		hand = active.position + fwd * 1.35
		hand_r = 0.65
		kind = KhoRules.OUT_DIVE
	elif active.act == "pole_dive":
		if active.act_t < 0.1:
			return
		hand = Vector3(signf(active.position.x) * f.pole_gap * 0.5, 0, 0) + fwd * 1.9
		hand_r = 0.7
		kind = KhoRules.OUT_POLE
	elif active.busy():
		return
	for d in batch:
		if d_state.get(d, "") != "in":
			continue
		var gap := Vector2(d.position.x - hand.x, d.position.z - hand.z).length()
		if gap < hand_r and KhoRules.touch_counts(f, chase, active.position, d.position):
			_out(d, kind, active)
			return


func _out(d: Athlete, kind: String, by: Athlete = null) -> void:
	d_state[d] = "out"
	d.do("")
	var pts := KhoRules.points_for_out(fmt)
	score[chasing] += pts
	_turn_out_count += 1
	since_out = 0.0
	khos_since = 0
	var st: Dictionary = stats[d.data.id]
	st.times_out += 1
	st.best_run = maxf(float(st.best_run), float(st.run))
	st.run = 0.0
	if by:
		stats[by.data.id].outs += 1
	_log("out", {"kind": kind, "who": d.data.id, "by": by.data.id if by else "", "pts": pts})
	var ump := _umpire_for(d.position.x)
	ump.do("out", 1.4)
	ump.face_to = d.position
	Sfx.play("whistle", -3.0)
	if not attract:
		Sfx.react("cheer" if (user < 0 or chasing == user) else "groan", -6.0)
	if hud:
		var key: String = {"touch": "CALL_OUT", "dive": "CALL_SKY_DIVE", "pole": "CALL_POLE_DIVE", "limits": "CALL_OUT_LIMITS",
			"late": "CALL_LATE_ENTRY"}[kind]
		hud.callout(tr(key), Game.C_DANGER if chasing != user else Game.C_GOOD, d.position)
	if not demo:
		if by and chasing == user:
			Game.haptic("tag")
		elif d == user_def:
			Game.haptic("tagged")
	if d == user_def:
		user_def = null
		_switch_defender()
	game_event.emit("out")
	if min_chase:
		min_times[chasing] = turn_len - clock
		_end_turn("min_chase")
		return
	# The batch is all out: the next must come on.
	var all_out := true
	for a in batch:
		if d_state.get(a, "") != "out":
			all_out = false
	if all_out:
		_next_batch()


func _next_batch() -> void:
	var d := defending()
	if powerplay_on:
		powerplay_on = false
		wazir_ids = wazir_ids.slice(0, 1)
		chase.wazir = String(active.data.id) in wazir_ids
	for a in batch:
		var st: Dictionary = stats[a.data.id]
		st.best_run = maxf(float(st.best_run), float(st.run))
	batch_k += 1
	batch = KhoRules.batch(def_order[d], batch_k)
	for a in batch:
		d_state[a] = "enter"
		a.do("")
		stats[a.data.id].run = 0.0
		var ai: Dictionary = _ai[a]
		ai.cool = rng.randf_range(0.0, 0.25)
		ai.target = Vector3(a.position.x + rng.randf_range(-3, 3), 0, -f.width * 0.5 + 2.5 + rng.randf() * 3.0)
	batch_time = 0.0
	dream_paid = 0
	if user == d:
		user_def = batch[0]
	# The fast game's power play: the chasing side may call it once a turn as a batch comes on.
	if fmt == KhoRules.FAST and bool(config.get("powerplay", Game.settings.powerplay)) and not powerplay_used:
		if _user_chasing():
			powerplay_offer = 8.0
		elif batch_k == 1 or (batch_k == 2 and rng.randf() < 0.5):
			_call_powerplay()
	_place_waiting(false)
	game_event.emit("batch")


func _call_powerplay() -> void:
	powerplay_used = true
	powerplay_on = true
	powerplay_offer = 0.0
	# A second wazir: the next best chaser.
	var line: Array = chase_line[chasing]
	for a in line:
		if not (String(a.data.id) in wazir_ids):
			wazir_ids.append(String(a.data.id))
			break
	chase.wazir = String(active.data.id) in wazir_ids
	_log("powerplay", {"side": chasing})
	if hud:
		hud.callout(tr("CALL_POWERPLAY"), Game.C_TEAL)


func _limits_and_entry(dt: float) -> void:
	for a in batch:
		var s: String = d_state.get(a, "")
		if s == "in":
			stats[a.data.id].def_time = float(stats[a.data.id].def_time) + dt
			stats[a.data.id].run = float(stats[a.data.id].run) + dt
			if KhoRules.out_of_limits(f, a.position):
				_out(a, KhoRules.OUT_LIMITS)
				return
		elif s == "enter":
			if KhoRules.in_limits(f, a.position, -0.2):
				d_state[a] = "in"
	if fmt == KhoRules.FAST:
		_late_entry_check()


func _late_entry_check() -> void:
	for a in batch:
		if d_state.get(a, "") == "enter" and KhoRules.late_entry(fmt, since_out, khos_since):
			_out(a, KhoRules.OUT_LATE)
			return


func _dream(dt: float) -> void:
	var on := false
	for a in batch:
		if d_state.get(a, "") == "in":
			on = true
	if not on:
		return
	batch_time += dt
	var dp := KhoRules.dream_points(fmt, batch_time)
	if dp > dream_paid:
		var add := dp - dream_paid
		dream_paid = dp
		score[defending()] += add
		_log("dream", {"side": defending(), "pts": add})
		if hud:
			hud.callout(tr("CALL_DREAM_RUN").format({"n": add}), Game.C_GOLD)
		if defending() == user and not demo:
			Game.haptic("dream")
		Sfx.react("cheer", -8.0)
		game_event.emit("dream")


func _on_foul(kind: String, who: Athlete = null) -> void:
	var a := who if who else active
	var ump := _umpire_for(a.position.x)
	ump.do("foul", 1.5, false)
	ump.face_to = a.position
	if a.data.has("id"):
		stats[a.data.id].fouls += 1
	_log("foul", {"kind": kind, "by": a.data.get("id", "")})
	Sfx.play("whistle_short", -3.0)
	_foul_whistle = 0.32
	if who and kind == KhoRules.FOUL_EARLY:
		who.do("foul", 0.6)   # half up, then back down
	if hud:
		hud.callout(tr("FOUL_" + kind.to_upper()), Game.C_DANGER, a.position, true)
	if _user_chasing() and a.side == user:
		Game.haptic("foul")
	game_event.emit("foul")


# ---------------------------------------------------------------- the defence

## How soon the chase could reach the point q: the active chaser straight there if he may go that way, round the
## pole if not, or a kho to a seated chaser who faces q's side, and his rise. The defenders' sense of danger.
func reach_time(q: Vector3) -> float:
	if active == null:
		return 9.0
	var p := active.position
	var v := maxf(active.top, 5.0)
	var hq := KhoRules.half_of(q.z)
	var on_lane := absf(q.z) < 0.35
	var t := 99.0
	var fz := KhoRules.in_free_zone(f, p)
	var free_dir: bool = chase.dir == 0 or chase.wazir or fz
	if hq == chase.half or on_lane or fz:
		if free_dir or (q.x - p.x) * float(chase.dir) > -0.5:
			t = (q - p).length() / v
		else:
			var px: float = float(chase.dir) * f.pole_gap * 0.5
			t = (absf(px - p.x) + 1.5 + (q - Vector3(px, 0, 0)).length()) / v
	for i in squares.size():
		if int(sq_face[i]) != hq or int(sq_face[i]) == chase.half:
			continue
		var sx := float(f.square_x[i])
		if not free_dir and (sx - p.x) * float(chase.dir) < 0.1:
			continue
		var tk := (Vector3(sx, 0, float(chase.half) * 0.5) - p).length() / v + 0.45 + (q - Vector3(sx, 0, 0)).length() / v
		t = minf(t, tk)
	return t


func _defender_think(a: Athlete, dt: float) -> void:
	var ai: Dictionary = _ai[a]
	ai.cool = float(ai.cool) - dt
	var top := _top_speed(a, false)
	a.top = top
	if d_state.get(a, "") == "enter":
		var to := (ai.target as Vector3) - a.position
		to.y = 0
		a.want = to.normalized() * top * 0.9
		return
	var here := reach_time(a.position)
	if float(ai.cool) <= 0.0:
		var read := float(a.data.get("read", 70)) + float(_diff[a.side])
		ai.cool = lerpf(0.42, 0.16, clampf(read / 100.0, 0.0, 1.0))
		ai.target = _pick_spot(a, here, read)
	var tgt: Vector3 = ai.target
	var to2: Vector3 = tgt - a.position
	to2.y = 0
	var urgency := clampf((3.2 - here) / 2.4, 0.0, 1.0)
	var spd := lerpf(3.4, top, urgency)
	var w := to2.normalized() * minf(spd, to2.length() * 3.0 + 0.5) if to2.length() > 0.05 else Vector3.ZERO
	w = _avoid(a, w)
	a.want = _keep_in(a, w)
	_stamina(a, dt)


## The defender's next spot: the safest within a few strides, from the threat (reach_time), the lines, the seated
## chasers and his team-mates; a little wander so that he keeps moving, as defenders do.
func _pick_spot(a: Athlete, here: float, read: float) -> Vector3:
	var best := a.position
	var bs := -99.0
	var p := a.position
	var ai: Dictionary = _ai[a]
	ai.wander = float(ai.wander) + rng.randf_range(-0.6, 0.6)
	var wander_dir := Vector3(cos(float(ai.wander)), 0, sin(float(ai.wander)))
	var noise := lerpf(0.9, 0.2, clampf(read / 100.0, 0.0, 1.0))
	for ring in [0.0, 1.6, 3.2]:
		var n := 1 if ring == 0.0 else 10
		for k in n:
			var ang := TAU * float(k) / float(n)
			var q: Vector3 = p + Vector3(cos(ang), 0, sin(ang)) * ring
			if not KhoRules.in_limits(f, q, -0.7):
				continue
			var s := minf(reach_time(q), 5.0)
			s -= ring / 6.0 * 0.6
			s -= _edge_cost(q)
			for m in batch:
				if m != a and d_state.get(m, "") == "in":
					var dm: float = (m.position - q).length()
					if dm < 2.5:
						s -= (2.5 - dm) * 0.35
			if ring > 0.0:
				s += wander_dir.dot((q - p).normalized()) * 0.25
			s += rng.randf_range(-noise, noise) * 0.3
			if s > bs:
				bs = s
				best = q
	return best


func _edge_cost(q: Vector3) -> float:
	var mx: float = f.length * 0.5 - absf(q.x)
	var mz: float = f.width * 0.5 - absf(q.z)
	var c := 0.0
	if mx < 1.4:
		c += (1.4 - mx) * 1.5
	if mz < 1.4:
		c += (1.4 - mz) * 1.5
	return c


## Round the seated chasers and the other runners rather than through them.
func _avoid(a: Athlete, w: Vector3) -> Vector3:
	var out := w
	for s in squares:
		var d: Vector3 = a.position - s.position
		d.y = 0
		var dl := d.length()
		if dl < 0.7 and dl > 0.001:
			out += d / dl * (0.7 - dl) * 8.0
	if active and active != a:
		pass
	return out.limit_length(maxf(w.length(), 0.1)) if w.length() > 0.1 else out.limit_length(1.0)


## Inside the limits: a defender running at a line stops at it (you can still step over, and are out).
func _keep_in(a: Athlete, w: Vector3) -> Vector3:
	var L: float = f.length * 0.5 - 0.45
	var W: float = f.width * 0.5 - 0.45
	var p := a.position
	if (p.x > L and w.x > 0.0) or (p.x < -L and w.x < 0.0):
		w.x = -signf(p.x) * 0.5
	if (p.z > W and w.z > 0.0) or (p.z < -W and w.z < 0.0):
		w.z = -signf(p.z) * 0.5
	return w


func _stamina(a: Athlete, dt: float) -> void:
	var spd := a.vel.length()
	var drain := clampf((spd - 5.0) / 3.0, 0.0, 1.0) * 0.012 * (1.4 - float(a.data.get("stamina", 70)) / 100.0)
	a.stamina = clampf(a.stamina - drain * dt * 10.0 + (0.02 * dt if spd < 4.0 else 0.0), 0.0, 1.0)


func _user_defender(dt: float) -> void:
	var a := user_def
	var j := controls.joystick if controls else Vector2.ZERO
	a.top = _top_speed(a, false)
	if d_state.get(a, "") == "enter":
		_defender_think(a, dt)
		if j.length() < 0.1:
			return
	a.want = Vector3(j.x, 0, j.y) * a.top
	a.want = _avoid(a, a.want) if a.want.length() > 0.1 else a.want
	_stamina(a, dt)
	controls.set_buttons(["DODGE", "SWITCH"])
	controls.lit = ""


# ---------------------------------------------------------------- officials, markers, camera

func _umpire_for(x: float) -> Athlete:
	return officials.ump_a if x < 0.0 else officials.ump_b


func _officials(_dt: float) -> void:
	var focus := active.position if active else Vector3.ZERO
	var L: float = f.length * 0.5
	for k in ["ump_a", "ump_b"]:
		var u: Athlete = officials[k]
		var lo := -L if k == "ump_a" else 0.0
		var hi := 0.0 if k == "ump_a" else L
		var tx := clampf(focus.x, lo + 1.0, hi - 1.0)
		var to := tx - u.position.x
		u.want = Vector3(clampf(to * 1.5, -3.0, 3.0), 0, 0) if absf(to) > 0.4 and not (u.act in ["out", "foul"]) else Vector3.ZERO
		if not (u.act in ["out", "foul"]):
			u.face_to = focus
	officials.referee.face_to = focus


func _update_markers() -> void:
	var mm := _shadows.multimesh
	var i := 0
	for a in everyone():
		if i >= mm.instance_count:
			break
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(a.position.x, 0.015, a.position.z)))
		i += 1
	var mine: Athlete = null
	if _user_chasing():
		mine = active
	elif user_def and phase == "play":
		mine = user_def
	_ring.visible = mine != null and not attract
	if mine:
		_ring.position = Vector3(mine.position.x, 0.03, mine.position.z)
	var ti := _kho_target(false) if _user_chasing() else -1
	_target_ring.visible = ti >= 0
	if ti >= 0:
		_target_ring.position = Vector3(float(f.square_x[ti]), 0.03, 0)


func _camera(dt: float) -> void:
	var fx := 0.0
	if active:
		fx = active.position.x
		var d := _nearest_defender(active.position, 8.0)
		if d:
			fx = lerpf(fx, d.position.x, 0.35)
	var L: float = f.length * 0.5
	fx = clampf(fx, -L + 7.0, L - 7.0)
	_cam_x = lerpf(_cam_x, fx, minf(1.0, dt * 1.6))
	var W: float = f.width * 0.5
	match _cam_mode:
		Game.CAM_CLOSE:
			cam.position = Vector3(_cam_x, 7.5, W + 9.0)
			cam.look_at(Vector3(_cam_x, 0.0, -0.5))
		Game.CAM_POLE:
			cam.position = Vector3(-L - 7.0, 6.5, 0.0)
			cam.look_at(Vector3(active.position.x if active else 0.0, 0.0, 0.0) * 0.4 + Vector3(L * 0.2, 0, 0))
		_:
			if attract:
				cam.position = Vector3(_cam_x * 0.6 + sin(t_match * 0.05) * 3.0, 11.0, W + 15.0)
			else:
				cam.position = Vector3(_cam_x, 12.5, W + 14.0)
			cam.look_at(Vector3(_cam_x, 0.0, -0.8))


func cycle_camera() -> void:
	_cam_mode = (_cam_mode + 1) % 3
	Game.settings.camera = _cam_mode
	Game.save_settings()


# ---------------------------------------------------------------- pause and back

func set_paused(on: bool) -> void:
	paused = on
	if hud:
		hud.show_pause(on)


func on_back() -> void:
	if phase == "over":
		return
	set_paused(not paused)


func quit_to_menu() -> void:
	Sfx.stop_all()
	Game.goto_menu()
