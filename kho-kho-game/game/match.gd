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
var speed := 1                 # Watch AI: the match at 1x or 2x (Engine.time_scale; toggle_speed)
var women := false
var knockout := false
var teams := ["", ""]
var arena: Arena
var cam: Camera3D
var hud = null                 # MatchHud
var controls: TouchControls
var dev = null
var coach: Coach = null
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
var _cheer_t := 99.0          # seconds since an out, for the crowd
var _tension := 0.0            # 0-1: how close the crowd is to its feet (_crowd_roar)
var _roar_t := 0.0
var _was_diving := false
var _tag_at: Athlete = null   # TAG: the defender your chaser's arm goes out for
var _reach_ready := 0.0       # a chaser's reach for a touch: one at a time, not one every frame he is close
var cam_locked := false       # the camera left where it is (pictures for the store and the docs)
var khos_since := 0
var powerplay_used := false
var powerplay_on := false
var powerplay_offer := 0.0     # s left to call a power play (you, the chasing side)
var user_def: Athlete = null
var _user_idle := 0.0
var _dodge_until := -1.0
var _dodge_ready := 0.0
var _dodge_dir := Vector3.ZERO
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
var _user_slip := 0.55         # how often a touch slips off your defender as you steer him (difficulty: USER_SLIP)
var _end_reason := ""
var _last_kho_t := 0.0
var _kho_armed := {}           # a kho pressed a moment early: {i, until}
var _min_turns := 0            # minimum-chase turns played, plus one
var staged := false            # built in steps (Game.play_match, under the loading overlay), not all in _ready
var built := false             # all of it built ...
var live := false              # ... and running: the clock, the AI, the play (kick_off, once the loading overlay settles)
var replay: MatchReplay = null # the moments shown again (the shared foundation's WsgReplay: Medium and High), else null
var _detail_t := 0.0


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	Crowd.watch_target = Vector3.INF
	WsgCrowd3D.set_excite(0.0)
	WsgCrowd3D.set_tension(0.0)
	FoundationLink.in_match = false
	FoundationLink.frozen = false
	FoundationLink.paused = false


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
	_user_slip = USER_SLIP[clampi(diff, 0, 3)]
	if user >= 0:
		_diff[1 - user] = ai_k
	_foul_rate = [0.05, 0.035, 0.02, 0.012][clampi(diff, 0, 3)]
	live = not staged
	if staged:
		return   # built in steps under the loading overlay (Game.play_match): build_ground, build_players, build_rest
	build_ground()
	build_players()
	build_rest()


## Play starts (Game.play_match, once the loading overlay has warmed the shaders and the frames have settled): the
## first frame the player sees is smooth play, not the clock already running behind the overlay.
func kick_off() -> void:
	live = true


## The ground, its stands and its crowd (the longest part of a match's start).
func build_ground() -> void:
	arena = Arena.new(String(config.get("venue", "maidan")), fmt, [DB.kit(teams[0])[0], DB.kit(teams[1])[0]])
	add_child(arena)
	# The shared foundation draws the bodies made from here on (Medium and High: FoundationLink), not behind the menus.
	FoundationLink.in_match = not attract
	FoundationLink.frozen = false
	FoundationLink.paused = false
	WsgFoundation.tier = int(Game.settings.graphics)


## The players, the officials and the markers on the field.
func build_players() -> void:
	_build_people()
	if everyone().any(func(a): return a.link != null):
		replay = MatchReplay.new(self)
		add_child(replay)
	_build_markers()


## The camera, the HUD and the first turn: from here the match runs.
func build_rest() -> void:
	cam = Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.3
	cam.far = 160.0
	add_child(cam)
	cam.current = true
	_cam_mode = int(Game.settings.camera)
	if bool(config.get("watch", false)):
		_cam_mode = Game.CAM_TV   # Watch AI opens on the broadcast camera (the camera button still changes it)
	Game.apply_graphics(get_viewport())
	if not attract:
		hud = (load("res://game/hud.gd") as Script).new(self)
		add_child(hud)
		controls = hud.controls
		controls.action.connect(_on_action)
		if bool(Game.settings.get("dev", false)):
			dev = (load("res://game/dev_overlay.gd") as Script).new(self)
			add_child(dev)
		if not demo and bool(Game.settings.get("coach", true)) and not bool(config.get("test", false)):
			coach = Coach.new(self)
			add_child(coach)
	var first := int(config.get("chase_first", 0))
	order = KhoRules.chase_order(first)
	turn = 0
	_start_turn()
	if not attract:
		Sfx.crowd(0.4 * arena.atmosphere())
		Sfx.venue(arena.kind, arena.surface())
	built = true


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
	_arrow = _arrow_mesh()


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


## Your direction, drawn on the ground ahead of your chaser: a gold chevron toward the pole he must keep running to.
var _arrow: MeshInstance3D


func _arrow_mesh() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pt in [Vector3(0.95, 0, 0), Vector3(0.55, 0, 0.32), Vector3(0.55, 0, -0.32), Vector3(0.55, 0, 0.13), Vector3(0.2, 0, 0.13), Vector3(0.2, 0, -0.13),
			Vector3(0.55, 0, 0.13), Vector3(0.2, 0, -0.13), Vector3(0.55, 0, -0.13)]:
		st.add_vertex(pt)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(Game.C_GOLD, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	# In front of the teams' benches (which stand at W + lobby + 1.5 to 1.9), clear of the tents' front poles (W + lobby
	# + 0.4): until 0.12.2 they knelt on the benches' own place, inside them (the owner: nobody through a bench).
	var z: float = -(W + f.lobby + 1.0)
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
	# The timekeeper's long whistle ends the turn; the last turn's is the final whistle (short, short, long).
	Sfx.whistle("final" if KhoRules.over_after(turn, order, score) else "long", arena.table_pos())
	Sfx.drums(-1.0)
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
		if bool(Game.settings.get("coach", true)):
			Game.settings.coach = false   # one match with the coach is enough; Settings turns it on again
			Game.save_settings()
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
	if not built or not live:
		return   # still being built, or warmed and settled, under the loading overlay
	if paused:
		return
	_rank_detail(delta)
	if replay and replay.playing():
		replay.step(delta)
		return
	var dt := minf(delta, 0.05)
	t_match += dt
	phase_t += dt
	match phase:
		"ready":
			if phase_t >= 1.6:
				phase = "play"
				phase_t = 0.0
				# The timekeeper's long whistle and a short one: the turn is on.
				Sfx.whistle("long", arena.table_pos())
				get_tree().create_timer(1.3).timeout.connect(func(): Sfx.whistle("short", arena.table_pos(), -2.0))
				if not attract:
					Sfx.drums(0.3 * arena.atmosphere())
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
	if phase == "play":
		_separate()
	_update_markers()
	# The crowd follows the chase: where the active chaser and the defender nearest him are.
	if active and phase == "play":
		var near := _nearest_defender(active.position, 6.0)
		Crowd.watch_target = active.position if near == null else active.position.lerp(near.position, 0.4)
	_camera(dt)
	_auto_graphics(delta)
	if replay:
		replay.live(dt)


## Auto graphics (Settings, on by default): a level lower when play stutters on this phone - the shared foundation's
## WsgAutoTier watches every frame of play (slow on average, or hitching), all match long, and a level comes off at
## once after two bad windows in a row; again later if it still stutters. As before: only in play, not in a match the
## AI plays on its own, nor with the battery saver's frame rate (its 30 a second is not slow).
var _auto_tier := WsgAutoTier.new(Game.frame_cap())


func _auto_graphics(delta: float) -> void:
	if attract or demo or phase != "play" or not bool(Game.settings.auto_gfx) or Game.frame_cap() == Game.saver_cap(Game.screen_hz()):
		return
	if _auto_tier.feed(delta) and int(Game.settings.graphics) > Game.GFX_LOW:
		lower_graphics()


## A level lower, now (WsgAutoTier, or a test): the picture as the level has it; on Low the foundation's bodies give
## way to the game's own (Low draws exactly what it always did) and no replays are kept.
func lower_graphics() -> void:
	var g := int(Game.settings.graphics) - 1
	Game.settings.graphics = g
	Game.save_settings()
	Game.apply_graphics(get_viewport())
	WsgFoundation.tier = g
	if g == Game.GFX_LOW:
		if replay:
			replay.end()
			replay.queue_free()
			replay = null
		for a in everyone():
			if a.link:
				a.link.release()
	_detail_t = 0.0
	_auto_tier.reset()
	game_event.emit("graphics")


# ---------------------------------------------------------------- the foundation's bodies (FoundationLink)

## Metres from the camera within which a body is posed every frame, and every second (beyond: every third), by
## graphics level: a budget phone's Medium poses the far side's bodies less often.
const POSE_NEAR := [[9.0, 15.0], [9.0, 15.0], [14.0, 24.0]]


## Twice a second: the foundation's bodies in full detail nearest the camera only (WsgFoundation: kho kho is "budget",
## its nearest 6 on Medium, all on High), and the far ones posed every second or third frame - never the active
## chaser, a defender in play, or anyone diving, turning at the pole or giving a kho, who are posed every frame. The
## seated (kneeling chasers, the waiting batches, the table) hardly move: every second or third.
func _rank_detail(dt: float) -> void:
	_detail_t -= dt
	if _detail_t > 0.0 or replay == null:
		return
	_detail_t = 0.5
	WsgFoundation.tier = int(Game.settings.graphics)
	var c3 := get_viewport().get_camera_3d()
	var camp := c3.global_position if c3 else Vector3.ZERO
	var near: Array = POSE_NEAR[clampi(int(Game.settings.graphics), 0, 2)]
	var list := []
	for a in everyone():
		var link: FoundationLink = a.link
		if link == null or link.body == null:
			continue
		list.append(link.body)
		var d: float = a.global_position.distance_to(camp)
		var busy: bool = a == active or d_state.get(a, "") == "in" or a.act in ["dive", "pole_dive", "lie", "getup", "pole_turn", "kho", "reach", "rise", "dodge"]
		link.pose_every = 1 if busy or d < float(near[0]) else (2 if d < float(near[1]) else 3)
		if a.act == "sit" and not busy:
			link.pose_every = maxi(link.pose_every, 2)
	if not list.is_empty():
		WsgFoundation.rank_detail(list, camp)


## The players' blob shadows under their bodies as drawn (a replay shows them where they were).
func shadows_at_drawn() -> void:
	var mm := _shadows.multimesh
	var i := 0
	for a in everyone():
		if i >= mm.instance_count:
			break
		var p: Vector3 = a.link.body.global_position if a.link and a.link.body else a.position
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(p.x, 0.015, p.z)))
		i += 1


## The interval between turns is over (the HUD's Next turn).
func next_turn() -> void:
	if phase == "interval":
		_after_turn()


var _drum_t := 0.0


## The crowd's roar: it builds as a chaser closes on a defender, through a dive, with the last of a batch left, and
## in a turn's last half-minute, and falls back as the chase draws off; a near thing (a dive or touch that just
## misses, _near_miss) brings it up at once. The murmur's level and how many are on their feet follow it.
func _crowd_roar(dt: float) -> void:
	if attract:
		return
	var want := 0.0
	if active:
		var d := _nearest_defender(active.position, 3.0)
		if d and KhoRules.touch_counts(f, chase, active.position, d.position):
			want += clampf((3.0 - (d.position - active.position).length()) / 2.2, 0.0, 1.0) * 0.6
		var diving: bool = active.act in ["dive", "pole_dive"]
		if diving:
			want += 0.4
		elif _was_diving and _cheer_t > 0.8:
			# Down, and no one out: a dive that just missed, if a defender is still close.
			if _nearest_defender(active.position, 2.8):
				_near_miss(true)
		_was_diving = diving
	var left := 0
	for a in batch:
		if d_state.get(a, "") == "in":
			left += 1
	if left == 1:
		want += 0.15
	if clock < 30.0:
		want += 0.15
	want = clampf(want, 0.0, 1.0)
	_tension = move_toward(_tension, want, dt * (2.5 if want > _tension else 0.5))
	_roar_t -= dt
	if _roar_t <= 0.0:
		_roar_t = 0.25
		Sfx.crowd((0.4 + 0.6 * _tension) * arena.atmosphere())


func _near_miss(loud: bool) -> void:
	if attract:
		return
	Sfx.react("ooh", -3.0 if loud else -8.0)
	_tension = 1.0
	# A dive that just missed: a moment to see again (the window's out may show it).
	if loud and replay and active:
		replay.moment("near_miss", active)


func _play(dt: float) -> void:
	clock -= dt
	since_out += dt
	# The crowd up on its feet at an out, settling over a few seconds.
	_cheer_t += dt
	_crowd_roar(dt)
	if arena.crowd:
		Crowd.set_excite(maxf(0.75 * exp(-_cheer_t / 2.5), 0.4 * _tension))
		# The shared crowd's cards get up and cheer by the foundation's excitement.
		WsgCrowd3D.set_excite(0.75 * exp(-_cheer_t / 2.5))
		WsgCrowd3D.set_tension(_tension)
	# The crowd's drums: up with an out, settling back as the chase goes on.
	_drum_t -= dt
	if _drum_t <= 0.0 and not attract:
		_drum_t = 0.5
		Sfx.drums((0.3 + 0.5 * exp(-since_out / 6.0)) * arena.atmosphere())
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
				if d_state.get(a, "") == "in":
					_brake_at_line(a, dt)   # a defender means to stay in; a quarter of the AI's outs were overruns
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
		var dir_was := chase.dir
		var foul := KhoRules.step_chase(f, chase, active.position, active.vel, dt)
		# Round the pole: he takes hold of it and swings round, coming out faster (the pole turn).
		if dir_was != 0 and chase.dir == -dir_was and active.act == "":
			_pole_turn()
		if foul != "":
			_on_foul(foul)
	if chase.foul != "":
		_foul_whistle -= dt
		if _foul_whistle <= 0.0:
			_foul_whistle = FOUL_REMIND
			# A reminder now and then until it is put right (the foul's bar shows it all along). Every 0.32 s, as
			# until 0.12, the whistles "went nuts" (the owner).
			Sfx.whistle("short", _umpire_for(active.position.x).global_position if active else arena.table_pos(), -5.0)
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
	var speed := want.length()
	if not KhoRules.in_free_zone(f, p):
		if chase.dir != 0 and not chase.wazir and not (String(active.data.id) in wazir_ids):
			w.x = float(chase.dir) * maxf(w.x * float(chase.dir), 0.0)
		var edge: float = f.lane_w * 0.5 + 0.22
		# Room to stop short of the lane at the speed he is coming at it.
		var vz_in := maxf(0.0, -float(chase.half) * active.vel.z)
		var stop := vz_in * vz_in / (2.0 * Athlete.DECEL * active.agility)
		if float(chase.half) * p.z < edge + 0.25 + stop and float(chase.half) * w.z < 0.0:
			w.z = 0.0
			# Pushed at the lane (at a seated chaser's back): run along it, at the speed asked for, his way.
			var along := float(chase.dir) if chase.dir != 0 else (signf(w.x) if absf(w.x) > 0.05 else 1.0)
			if chase.wazir or (String(active.data.id) in wazir_ids):
				along = signf(w.x) if absf(w.x) > 0.05 else along
			w.x = along * maxf(absf(w.x), speed * 0.95)
			if float(chase.half) * p.z < edge:
				w.z = float(chase.half) * 1.0
	var L: float = f.length * 0.5 - 0.3
	var W: float = f.width * 0.5 - 0.3
	if (p.x > L and w.x > 0.0) or (p.x < -L and w.x < 0.0):
		w.x = 0.0
	if (p.z > W and w.z > 0.0) or (p.z < -W and w.z < 0.0):
		w.z = 0.0
	return w


## The stick as a direction on the ground, as the camera sees it (the owner: with a camera not alongside the field
## the stick went the wrong way): up on the stick is up the screen, right is right, whatever the camera. Read at the
## player you run, where he is on the screen (a low camera, behind the pole, sees the ground in perspective: its
## heading alone was 18 degrees out off to one side). After a camera change the mapping blends over 0.2 s (STICK_BLEND), so a
## camera change in the middle of a run does not turn him round in a frame. Length as the stick's (0-1).
const STICK_BLEND := 0.2  # s: from one camera's stick to the next's
var _stick_mode := -1
var _stick_from := []
var _stick_blend := STICK_BLEND
var _stick_sx := Vector2.INF   # the ground direction (x, z) that is right on the screen at your player
var _stick_sy := Vector2.INF   # ... and down the screen


func stick_world(j: Vector2) -> Vector3:
	if j.length() < 0.0001:
		return Vector3.ZERO
	var m := _stick_map() if _stick_sx == Vector2.INF else [_stick_sx, _stick_sy]
	var w: Vector2 = m[0] * j.x + m[1] * j.y
	if w.length() < 0.0001:
		return Vector3.ZERO
	w = w.normalized() * minf(j.length(), 1.0)
	return Vector3(w.x, 0.0, w.y)


## The other way: the stick that runs him along w (a direction on the ground), as the camera sees it.
func world_to_stick(w: Vector3) -> Vector2:
	var m := _stick_map() if _stick_sx == Vector2.INF else [_stick_sx, _stick_sy]
	var sx: Vector2 = m[0]
	var sy: Vector2 = m[1]
	var det := sx.x * sy.y - sy.x * sx.y
	if absf(det) < 0.000001:
		return Vector2.ZERO
	var j := Vector2(w.x * sy.y - sy.x * w.z, sx.x * w.z - w.x * sx.y) / det
	return j.normalized() * Vector2(w.x, w.z).length() if j.length() > 0.0001 else Vector2.ZERO


## The camera's forward on the ground, as a heading (radians: 0 is +z).
func camera_yaw() -> float:
	if cam == null:
		return PI   # the broadcast camera's: looking across the field toward -z
	var f := -cam.global_transform.basis.z
	if Vector2(f.x, f.z).length() < 0.01:
		f = cam.global_transform.basis.y   # looking straight down: up the screen is the camera's up
	return atan2(f.x, f.z)


## Where the stick is read: the player you run (your chaser, or your defender), else the middle of the field.
func _stick_point() -> Vector3:
	if user >= 0 and active and _user_chasing():
		return active.position
	if user_def:
		return user_def.position
	return Vector3.ZERO


## [right, down]: the ground directions (x, z) that move a point at your player right and down the screen, scaled
## together (the larger 1). From the camera's projection there; from its heading if the projection fails.
func _stick_map() -> Array:
	var yaw := camera_yaw()
	var fwd := Vector2(sin(yaw), cos(yaw))
	var fallback := [Vector2(-fwd.y, fwd.x), -fwd]
	if cam == null or not cam.is_inside_tree():
		return fallback
	var p := _stick_point()
	if cam.is_position_behind(p):
		return fallback
	var s0 := cam.unproject_position(p)
	var a := cam.unproject_position(p + Vector3(0.5, 0, 0)) - s0   # the screen's move for 0.5 m along x
	var b := cam.unproject_position(p + Vector3(0, 0, 0.5)) - s0   # ... and along z
	var det := a.x * b.y - b.x * a.y
	if absf(det) < 0.01:
		return fallback
	var sx := Vector2(b.y, -a.y) / det
	var sy := Vector2(-b.x, a.x) / det
	var k := maxf(sx.length(), sy.length())
	return [sx / k, sy / k]


func _ease_stick(dt: float) -> void:
	var want := _stick_map()
	if _stick_sx == Vector2.INF:
		_stick_sx = want[0]
		_stick_sy = want[1]
		_stick_mode = _cam_mode
		return
	# A cut to another camera: from the old mapping to the new over STICK_BLEND; otherwise it follows the camera
	# exactly (a camera that pans with the play would leave an eased mapping behind it).
	if _cam_mode != _stick_mode:
		_stick_mode = _cam_mode
		_stick_from = [_stick_sx, _stick_sy]
		_stick_blend = 0.0
	if _stick_blend < STICK_BLEND and dt > 0.0:
		_stick_blend = minf(_stick_blend + dt, STICK_BLEND)
		var t := smoothstep(0.0, STICK_BLEND, _stick_blend)
		var sx: Vector2 = (_stick_from[0] as Vector2).lerp(want[0], t)
		var sy: Vector2 = (_stick_from[1] as Vector2).lerp(want[1], t)
		# A cut that turns the view right round passes through nothing on the way: there, take the new one.
		if absf(sx.x * sy.y - sy.x * sx.y) > 0.05:
			_stick_sx = sx
			_stick_sy = sy
			return
		_stick_blend = STICK_BLEND
	if _stick_blend >= STICK_BLEND:
		_stick_sx = want[0]
		_stick_sy = want[1]


func _user_chaser(_dt: float) -> void:
	var j := controls.joystick if controls else Vector2.ZERO
	var w := stick_world(j) * active.top
	if bool(Game.settings.lane_assist):
		w = _legal(w)
	if not _kho_armed.is_empty():
		var i: int = _kho_armed.i
		var r := KhoRules.kho_check(f, chase, active.position, float(f.square_x[i]), int(sq_face[i]))
		if t_match > float(_kho_armed.until) or r == "late" or _to_square.values().has(i):
			_kho_armed = {}
		elif r == "ok" and absf(active.position.x - float(f.square_x[i])) < 0.6:
			_kho_armed = {}
			_give_kho(i)
			return
		else:
			# Brake into his back: to just short of his cross lane, on this side of the lane.
			var kp := Vector3(float(f.square_x[i]) - float(chase.dir if chase.dir != 0 else 1) * 0.3, 0, float(chase.half) * 0.55)
			var to := kp - active.position
			to.y = 0
			w = _legal(to.normalized() * minf(active.top, 2.2 + to.length() * 2.5))
	if not active.busy():
		active.want = w
	active.top = _top_speed(active, true)
	var ids := ["KHO", "DIVE", "TAG"]
	if powerplay_offer > 0.0 and not powerplay_used:
		ids.append("POWERPLAY")
	controls.set_buttons(ids)
	controls.lit = "KHO" if _kho_target(false) >= 0 or not _kho_armed.is_empty() else ""


## The next seated chaser ahead of your chaser whose back is to him, within reach of a few strides; -1 none.
func _next_kho_ahead(within: float) -> int:
	if active == null:
		return -1
	var best := -1
	var bd := within
	for i in squares.size():
		if _to_square.values().has(i) or int(sq_face[i]) != -chase.half:
			continue
		var dx := float(f.square_x[i]) - active.position.x
		var ahead: float = dx * float(chase.dir) if chase.dir != 0 else absf(dx)
		if ahead > -0.2 and ahead < bd:
			bd = ahead
			best = i
	return best


func _top_speed(a: Athlete, chaser: bool) -> float:
	var r: float = a.speed_rating() + float(_diff[a.side])
	# A defender turns sharper than a chaser: it is all he does (his turn rating); a chaser runs straight lines.
	var turn: float = float(a.data.get("turn", 70)) + float(_diff[a.side])
	a.agility = 0.9 if chaser else lerpf(1.15, 1.6, clampf(turn / 100.0, 0.0, 1.0))
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
				else:
					# Pressed a moment early: the kho is armed, and he brakes into the seated chaser's back and gives it.
					var j := _next_kho_ahead(3.5)
					if j >= 0:
						_kho_armed = {"i": j, "until": t_match + 1.2}
		"DIVE":
			if _user_chasing() and not active.busy():
				_dive_at(_nearest_defender(active.position, 3.0))
		"TAG":
			if _user_chasing() and not active.busy():
				_tag()
		"POWERPLAY":
			if _user_chasing() and powerplay_offer > 0.0:
				_call_powerplay()
		"DODGE":
			_dodge()
		"SWITCH":
			_switch_defender()


const DODGE_TIME := 0.4
const DODGE_COOL := 1.1
const DODGE_SLIP := 0.9    # a touch slips off a defender in his side-step this often


## DODGE: a hard side-step, square to the chaser's line at him (the side your stick leans to, else away from the
## nearer side line), a burst over top speed for 0.4 s, and a touch in it slips off him nine times in ten. Until
## 0.3 it added 1.6 m/s along his run, which his top speed took straight back off: it did nothing you could see.
func _dodge() -> void:
	var a := user_def
	if a == null or a.busy() or t_match < _dodge_ready:
		return
	var from := active.position if active else a.position + Vector3(0, 0, 1)
	var line := a.position - from
	line.y = 0
	if line.length() < 0.05:
		line = Vector3(1, 0, 0)
	line = line.normalized()
	var side := Vector3(-line.z, 0, line.x)
	var j := controls.joystick if controls else Vector2.ZERO
	if j.length() > 0.2:
		if side.dot(stick_world(j)) < 0.0:
			side = -side
	elif side.dot(-a.position) < 0.0:
		side = -side   # toward the middle of the field
	var dir := (side * 0.85 + line * 0.35).normalized()
	if bool(Game.settings.lane_assist):
		dir = _keep_in(a, dir)
	_dodge_dir = dir.normalized()
	a.dodge(_dodge_dir, DODGE_TIME)
	_dodge_until = t_match + DODGE_TIME
	_dodge_ready = t_match + DODGE_COOL
	a.vel = a.vel * 0.3 + _dodge_dir * maxf(a.vel.length(), 5.0)
	a.stamina = maxf(0.0, a.stamina - 0.06)
	Sfx.voice("hup", -6.0)
	Sfx.play("whoosh", -12.0)
	game_event.emit("dodge")


const TAG_TIME := 0.32
const TAG_REACH := 1.05    # from his middle to the hand, the arm out at full stretch
const TAG_RANGE := 2.2     # TAG reaches for the nearest defender within this (else his arm goes out ahead)


## TAG: not every touch is a dive. His arm goes out for the nearest defender in reach (one arm, body.grip) as he
## runs on, for about a third of a second; the hand reaches further than a running touch, not as far as a dive, and
## he never leaves his feet. Whether it counts is _touches' (the swerve, the rules).
func _tag() -> void:
	if t_match < _reach_ready - 0.5:
		return
	var d := _nearest_defender(active.position, TAG_RANGE)
	_tag_at = d
	active.do("reach", TAG_TIME)
	active.body.grip_arms = 1
	var fwd := Vector3(sin(active.yaw), 0, cos(active.yaw))
	active.body.grip = (d.position if d else active.position + fwd * TAG_REACH) + Vector3(0, 1.0, 0)
	_reach_ready = t_match + 0.6
	Sfx.play("whoosh", -16.0)
	game_event.emit("tag")


func dodging() -> bool:
	return user_def != null and t_match < _dodge_until


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
	active.body.grip_arms = 1
	active.body.grip = squares[i].position + Vector3(0, 0.75, 0)
	_pending_kho = {"i": i, "t": 0.16, "giver": active}
	_kho_armed = {}
	_last_kho_t = t_match
	# The palm on his back, as it sounds: a slap (the owner: the voice raised a pitch over it sounded like a
	# cartoon), from where it lands.
	Sfx.play_at("slap", squares[i].position + Vector3(0, 1.0, 0), -3.0, randf_range(0.9, 1.04))
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
			a.watch = Vector3.INF
			continue
		a.want = Vector3.ZERO
		if a.act != "sit" and a.act != "foul":
			a.do("sit")
		# Seated, he watches the chase: the active chaser coming, or the defender on his side nearest him.
		a.watch = active.position if active else Vector3.INF
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
				var reach := 1.3 + float(active.data.get("reach", 70)) / 100.0 * 0.6
				var near_line: bool = absf(d.position.z) > f.width * 0.5 - 1.6 or absf(d.position.x) > f.length * 0.5 - 1.4
				var closing := d.vel.length() < 3.0 or (d.position - p).normalized().dot(d.vel.normalized()) < 0.3
				if dist < reach and dist > 1.1 and _dive_cool <= 0.0 and KhoRules.touch_counts(f, chase, p, d.position) \
						and (near_line or closing) and rng.randf() < 0.08:
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
	# A foul being whistled: no touch of his counts until he puts it right, by a kho or the free zone, so that is his
	# plan; any seated chaser ahead will do.
	var fouled := chase.foul != ""
	for d in live:
		var dp: Vector3 = d.position
		var dist := (dp - p).length()
		# Chase him where he is: on this side, and ahead (or anywhere for the wazir, or from the free zone).
		var same := KhoRules.half_of(dp.z) == chase.half or absf(dp.z) < 0.3
		var ahead: bool = chase.dir == 0 or chase.wazir or fz or (dp.x - p.x) * float(chase.dir) > -0.4
		if same and ahead and not fouled:
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
			if not fouled and not (KhoRules.half_of(dp.z) == int(sq_face[i]) or absf(dp.z) < 0.3):
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


## The pole turn, as the owner's video of real chasers shows it (docs/AI.md, "The pole turn"): running at the pole,
## the chaser takes hold of it with both hands at his chest, swings round it close (about half a metre out) in about
## half a second, and lets go running down the other side, still moving: the pole slings him on, where turning
## without it he would have to stop. He comes out
## on the side the play needs: the AI's plan, your stick, or the side he is on.
const SWING_R := 0.55
const SWING_OUT := 0.75       # his speed out, against his speed in: not stopped, as a turn without the pole would
const SWING_MIN_OUT := 4.2    # m/s; he is then off at his own acceleration
const SWING_MAX_OUT := 5.2


func _pole_turn() -> void:
	var px: float = signf(active.position.x) * f.pole_gap * 0.5
	var pole := Vector3(px, 0, 0)
	var rel := active.position - pole
	rel.y = 0.0
	if rel.length() > 1.6:
		return
	# The side he comes out on.
	var out_half := KhoRules.half_of(active.position.z)
	var sw := stick_world(controls.joystick) if controls else Vector3.ZERO
	if _user_chasing() and absf(sw.z) > 0.3:
		out_half = 1 if sw.z > 0.0 else -1
	elif not _user_chasing() and String(_chase_plan.get("kind", "")) == "pole":
		out_half = int(_chase_plan.get("half", out_half))
	# He lets go just past the pole on that side, heading back down the field (toward the middle).
	var exit := Vector3(-signf(px) * 0.35, 0, float(out_half)).normalized()
	var a_exit := atan2(exit.z, exit.x)
	var a0 := atan2(rel.z, rel.x)
	var turn := signf(px) * float(out_half)   # the way round: behind the pole, away from the field
	var sweep := fposmod((a_exit - a0) * turn, TAU)
	if sweep < 1.2:
		return   # already round, or nearly: he runs on out of it
	sweep = minf(sweep, PI * 1.25)
	var a1 := a0 + sweep * turn
	var v_in := maxf(Vector2(active.vel.x, active.vel.z).length(), 3.0)
	var v_out := clampf(v_in * SWING_OUT, SWING_MIN_OUT, SWING_MAX_OUT)
	# He takes hold from where he is and is drawn in to the tight circle as he swings.
	active.pole_swing(pole, rel.length(), SWING_R, a0, a1, v_in, v_out)
	stats[active.data.id].pole_turns = int(stats[active.data.id].get("pole_turns", 0)) + 1
	if replay:
		replay.moment("pole_turn", active)
	game_event.emit("pole_turn")


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
	# Never across the lane: a dive is within the direction rules (and the lane's).
	if not KhoRules.in_free_zone(f, p) and float(chase.half) * dir.z < 0.0:
		dir.z = 0.0
		dir = dir.normalized() if dir.length() > 0.01 else Vector3(float(chase.dir), 0, 0)
	active.vel = dir * maxf(active.vel.length(), 5.6)
	active.yaw = atan2(dir.x, dir.z)
	active.dive_target = d
	active.do("dive", 0.5)
	_dive_cool = 3.0
	if d:
		_see_dive(d, dir)
	stats[active.data.id].dives += 1
	Sfx.play("whoosh", -6.0)
	Sfx.voice("grunt", -6.0)
	if _user_chasing():
		Game.haptic("dive")
	game_event.emit("dive")


## A defender sees the dive coming and jumps aside, if he reads it in time: his reaction is 0.12 s for the best
## and 0.32 s for the slowest, and the dive's hands arrive 0.25-0.35 s after it starts (docs/AI.md).
func _see_dive(d: Athlete, dir: Vector3) -> void:
	if d == user_def and not _user_auto():
		return
	var read := float(d.data.get("read", 70)) + float(_diff[d.side])
	var react := lerpf(0.32, 0.12, clampf(read / 100.0, 0.0, 1.0)) + rng.randf_range(-0.05, 0.08)
	var side := Vector3(-dir.z, 0, dir.x)
	if side.dot(d.position - active.position) < 0.0:
		side = -side
	var ai: Dictionary = _ai[d]
	ai.dodge_at = t_match + react
	ai.dodge_dir = (side * 1.0 + dir * 0.35).normalized()


func _pole_dive_at(d: Athlete) -> void:
	var pole := Vector3(signf(active.position.x) * f.pole_gap * 0.5, 0, 0)
	var dir := (d.position - pole)
	dir.y = 0
	dir = dir.normalized()
	active.vel = dir * 3.0
	active.yaw = atan2(dir.x, dir.z)
	active.dive_target = d
	active.do("pole_dive", 0.45, dir.z * signf(pole.x) < 0.0)
	_dive_cool = 3.0
	_see_dive(d, dir)
	stats[active.data.id].pole_dives += 1
	Sfx.voice("grunt", -6.0)
	game_event.emit("pole_dive")


## Has the active chaser's hand found a defender? A touch counts unless a foul is on (KhoRules.touch_counts).
func _touches() -> void:
	if active == null:
		return
	var fwd := Vector3(sin(active.yaw), 0, cos(active.yaw))
	var hand := active.position + fwd * TOUCH_AHEAD
	var hand_r := TOUCH_R
	var kind := KhoRules.OUT_TOUCH
	if active.act == "dive":
		if active.act_t < 0.08 or active.act_t > 0.45:
			return
		hand = active.position + fwd * 1.3
		hand_r = 0.45
		kind = KhoRules.OUT_DIVE
	elif active.act == "pole_dive":
		if active.act_t < 0.1:
			return
		hand = Vector3(signf(active.position.x) * f.pole_gap * 0.5, 0, 0) + fwd * 1.9
		hand_r = 0.7
		kind = KhoRules.OUT_POLE
	elif active.busy():
		return
	elif active.act == "reach" and _tag_at != null and is_instance_valid(_tag_at):
		# TAG: the hand goes out toward him (and follows him), at full stretch from 0.06 s.
		if active.act_t < 0.06:
			return
		var to := _tag_at.position - active.position
		to.y = 0.0
		hand = active.position + to.normalized() * minf(to.length(), TAG_REACH) if to.length() > 0.01 else hand
		hand_r = 0.42
		active.body.grip = _tag_at.position + Vector3(0, 1.0, 0)
	for d in batch:
		if d_state.get(d, "") != "in":
			continue
		var gap := Vector2(d.position.x - hand.x, d.position.z - hand.z).length()
		if gap < hand_r and KhoRules.touch_counts(f, chase, active.position, d.position):
			# The attempt is seen: his arm goes out for the touch, whether it lands or slips off.
			if active.act == "" and t_match > _reach_ready:
				active.do("reach", 0.3)
				_tag_at = null
				active.body.grip_arms = 1
				active.body.grip = d.position + Vector3(0, 1.0, 0)
				_reach_ready = t_match + 0.9
			if _swerves(d, kind):
				continue
			if active.act in ["dive", "pole_dive"]:
				active.lock_reach(d.global_position + Vector3(0, 0.18, 0))   # the hand stays on his leg
			_out(d, kind, active)
			return


## The last-moment swerve: as the hand comes, a defender may twist away from it. The chance is his turn rating
## against the chaser's reach (and a dive is harder to escape). Calibrated so that equal sides put out about
## 1.3-2 defenders a minute, as real matches do (docs/AI.md). Once a defender has swerved a hand, it has missed him.
const SWERVE_TOUCH := 0.9   # a running touch at arm's length: he twists clear this often (0.78 until 0.12.2, when
const SWERVE_MAX := 0.93    # a slip was unseen and the hand reached less far; match_sim 20 matches: classic 1.46)
const TOUCH_AHEAD := 0.45   # m: the middle of a running touch's reach, ahead of him ...
const TOUCH_R := 0.42       # ... and how far round it the hand finds a man (0.4 and 0.36 until 0.12.2)
const CONTACT := 0.62       # m between middles: body to body ...
const CONTACT_SLIP := 0.55  # ... where a twist takes him clear of the hand this much as often
const SWERVE_DIVE := 0.5


func _swerves(d: Athlete, kind: String) -> bool:
	var ai: Dictionary = _ai[d]
	if float(ai.get("slip_until", 0.0)) > t_match:
		return true
	# Yours steered by your thumb: his reflexes still work (a touch can slip off him), a little less often than when
	# he runs himself, and DODGE is yours on top. Without them a new player's defenders fell at 9 outs a minute
	# against the AI's 2 (docs/PLAYTEST.md).
	var steered := d == user_def and not _user_auto()
	if d == user_def and dodging() and rng.randf() < DODGE_SLIP:
		ai.slip_until = t_match + 0.5
		_near_miss(false)
		game_event.emit("swerve")
		return true
	var turn := float(d.data.get("turn", 70)) + float(_diff[d.side])
	var reach := float(active.data.get("reach", 70)) + float(_diff[active.side])
	var base := SWERVE_TOUCH if kind == KhoRules.OUT_TOUCH else SWERVE_DIVE
	var p := clampf(base + (turn - reach) / 150.0, 0.15, SWERVE_MAX)
	# Body to body (the owner, 0.12: "so close it's obvious there would be a tag, but they just run right by"): at
	# arm's length a twist may take him clear of the hand; this close, rarely.
	if (d.position - active.position).length() < CONTACT:
		p *= CONTACT_SLIP
	if steered:
		# Yours: the difficulty decides, so a harder side's chasers really do catch you (the owner: on the hardest
		# they still ran past). Your defender's own turn against the chaser's reach still counts a little.
		var raw := float(d.data.get("turn", 70)) - float(active.data.get("reach", 70))
		p = clampf((_user_slip + raw / 300.0) * (1.0 if kind == KhoRules.OUT_TOUCH else 0.6), 0.08, 0.85)
		if (d.position - active.position).length() < CONTACT:
			p *= CONTACT_SLIP
	if rng.randf() >= p:
		return false
	ai.slip_until = t_match + (0.5 if kind == KhoRules.OUT_TOUCH else 0.6)
	var away := d.position - active.position
	away.y = 0
	var back := Vector3(-float(chase.dir), 0, 0) if chase.dir != 0 else Vector3.ZERO
	var dir := (away.normalized() + back * 0.8).normalized()
	ai.juke_at = t_match
	ai.juke_until = t_match + 0.45
	ai.juke_dir = dir
	if steered:
		d.vel += dir * 3.0
	elif d.act == "":
		# Seen: he twists away from the hand (the recorded dodge), not a hand passing through him.
		d.dodge(dir, 0.4)
	_near_miss(kind != KhoRules.OUT_TOUCH)
	game_event.emit("swerve")
	return true


func _out(d: Athlete, kind: String, by: Athlete = null) -> void:
	d_state[d] = "out"
	d.do("")
	var pts := KhoRules.points_for_out(fmt)
	score[chasing] += pts
	_turn_out_count += 1
	since_out = 0.0
	_cheer_t = 0.0
	khos_since = 0
	var st: Dictionary = stats[d.data.id]
	st.times_out += 1
	st.best_run = maxf(float(st.best_run), float(st.run))
	st.run = 0.0
	if by:
		stats[by.data.id].outs += 1
	_log("out", {"how": kind, "side": d.side, "who": d.data.id, "by": by.data.id if by else "", "pts": pts, "since_kho": t_match - _last_kho_t,
		"dz": absf(d.position.z), "x": d.position.x})
	var ump := _umpire_for(d.position.x)
	ump.do("out", 1.4)
	ump.face_to = d.position
	Sfx.whistle("short", ump.global_position, -2.0)   # an out: one short whistle from that half's umpire
	if not attract:
		Sfx.react("cheer" if (user < 0 or chasing == user) else "groan", -6.0)
		Sfx.drums(0.8 * arena.atmosphere())
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
	if replay:
		# No replays of a tag (the owner, 0.12: they will never look good on a phone's level of detail): the window of
		# moments before an out is dropped, and nothing is shown for it.
		replay.moments = []
		replay._due = -1.0   # and none already due (a near thing just before) plays over it
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
		if replay:
			for a in batch:
				if d_state.get(a, "") == "in":
					replay.moment("survival", a)
					break
			replay.close()
		game_event.emit("dream")


const FOUL_REMIND := 2.5   # s between the umpire's reminders while a foul stands


func _on_foul(kind: String, who: Athlete = null) -> void:
	var a := who if who else active
	var ump := _umpire_for(a.position.x)
	ump.do("foul", 1.5, false)
	ump.face_to = a.position
	if a.data.has("id"):
		stats[a.data.id].fouls += 1
	_log("foul", {"how": kind, "by": a.data.get("id", ""), "act": a.act, "x": a.position.x, "z": a.position.z,
		"vz": a.vel.z, "half": chase.half, "plan": String(_chase_plan.get("kind", ""))})
	# Two short blasts as he calls it; then a reminder every FOUL_REMIND s while it stands.
	Sfx.whistle("short", ump.global_position, -2.0)
	get_tree().create_timer(0.3).timeout.connect(func(): Sfx.whistle("short", ump.global_position, -3.0))
	_foul_whistle = FOUL_REMIND
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


## A defender is out of danger when the chase is this far off (reach_time, s); then he stands unless a spot is better
## than his own by STAY_BONUS, and walks rather than jogs (docs/AI.md, "Watched").
const SAFE_S := 3.2
const STAY_BONUS := 0.8
const SETTLE_M := 1.0


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
	if ai.has("dodge_at") and t_match >= float(ai.dodge_at) and t_match < float(ai.dodge_at) + 0.4:
		if float(ai.get("dodge_seen", -1.0)) != float(ai.dodge_at):
			ai.dodge_seen = ai.dodge_at
			a.dodge(ai.dodge_dir, 0.4)
		a.top = top * 1.15
		a.want = _keep_in(a, (ai.dodge_dir as Vector3) * a.top)
		a.vel += _keep_in(a, (ai.dodge_dir as Vector3)) * 9.0 * dt   # a quick, hard step aside
		return
	# The juke: the active chaser closing in, the defender waits for him to commit, then slips behind him, where his
	# direction will not let him turn (the wazir and a chaser in the free zone can still follow).
	if active and not active.busy() and not ai.has("juke_until"):
		var to_me := a.position - active.position
		to_me.y = 0
		var closing := active.vel.dot(to_me.normalized()) > 2.0
		if to_me.length() < 2.4 and closing:
			var read := float(a.data.get("read", 70)) + float(_diff[a.side])
			var c_read := float(active.data.get("read", 70)) + float(_diff[active.side])
			var react := clampf(0.16 + (c_read - read) * 0.006 + rng.randf_range(-0.06, 0.1), 0.06, 0.4)
			var back := -float(chase.dir) if chase.dir != 0 and not chase.wazir else (-signf(active.vel.x) if absf(active.vel.x) > 0.5 else 1.0)
			var lateral := signf(to_me.z) if absf(to_me.z) > 0.2 else (1.0 if rng.randf() < 0.5 else -1.0)
			ai.juke_at = t_match + react
			ai.juke_until = t_match + react + 0.45
			ai.juke_dir = Vector3(back * 0.85, 0, lateral * 0.55).normalized()
	if ai.has("juke_until"):
		if t_match > float(ai.juke_until):
			ai.erase("juke_until")
		elif t_match >= float(ai.juke_at):
			a.top = top * 1.1
			a.want = _keep_in(a, (ai.juke_dir as Vector3) * a.top)
			a.vel += _keep_in(a, (ai.juke_dir as Vector3)) * 7.0 * dt
			_stamina(a, dt)
			return
	var here := reach_time(a.position)
	if float(ai.cool) <= 0.0:
		var read := float(a.data.get("read", 70)) + float(_diff[a.side])
		ai.cool = lerpf(0.42, 0.16, clampf(read / 100.0, 0.0, 1.0))
		ai.target = _pick_spot(a, here, read)
	var tgt: Vector3 = ai.target
	var to2: Vector3 = tgt - a.position
	to2.y = 0
	# Out of danger he settles: stands where he is, facing the chase, saving his legs (both real matches watched,
	# docs/AI.md): he moves only to a spot clearly better than his own, and walks there unless the chase is coming.
	if active:
		a.face_to = active.position
		a.watch = active.position
	var safe := here > SAFE_S
	if safe and to2.length() < SETTLE_M:
		a.want = Vector3.ZERO
		_stamina(a, dt)
		return
	var urgency := clampf((4.2 - here) / 2.8, 0.0, 1.0)
	var spd := lerpf(1.6 if safe else 3.4, top, urgency)
	var w := to2.normalized() * minf(spd, to2.length() * 3.0 + 0.5) if to2.length() > 0.05 else Vector3.ZERO
	w = _avoid(a, w)
	a.want = _keep_in(a, w)
	_stamina(a, dt)


## The defender's next spot: the safest within a few strides, from the threat (reach_time), the lines, the seated
## chasers and his team-mates. In danger, a little wander, so he is hard to pin; out of it, his own spot unless another
## is clearly safer: real defenders out of danger stand still and watch (docs/AI.md, "Watched").
func _pick_spot(a: Athlete, here: float, read: float) -> Vector3:
	var best := a.position
	var bs := -99.0
	var p := a.position
	var safe := here > SAFE_S
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
			s += _chain_bias(q)
			for m in batch:
				if m != a and d_state.get(m, "") == "in":
					var dm: float = (m.position - q).length()
					if dm < 2.5:
						s -= (2.5 - dm) * 0.35
			if ring > 0.0 and not safe:
				s += wander_dir.dot((q - p).normalized()) * 0.25
			elif ring == 0.0 and safe:
				s += STAY_BONUS
			s += rng.randf_range(-noise, noise) * 0.3
			if s > bs:
				bs = s
				best = q
	return best


## The chain: defenders play close to the lane, round the seated chasers, and best of all beside one whose back is
## to them (he cannot rise toward them); far out in the field there is nothing to hide behind.
func _chain_bias(q: Vector3) -> float:
	var az := absf(q.z)
	var b := 0.0
	if az >= 0.8 and az <= 4.0:
		b += 0.35
	elif az > 5.0:
		b -= (az - 5.0) * 0.25
	if az < 2.2:
		var hq := KhoRules.half_of(q.z)
		for i in squares.size():
			if absf(float(f.square_x[i]) - q.x) < 1.2 and int(sq_face[i]) != hq:
				b += 0.3
				break
	return b


func _edge_cost(q: Vector3) -> float:
	var mx: float = f.length * 0.5 - absf(q.x)
	var mz: float = f.width * 0.5 - absf(q.z)
	var c := 0.0
	if mx < 1.4:
		c += (1.4 - mx) * 1.5
	if mz < 1.4:
		c += (1.4 - mz) * 1.5
	return c


## Round the seated chasers rather than through them.
func _avoid(a: Athlete, w: Vector3) -> Vector3:
	# Round the seated chasers, not through them (the owner: "like ghosts"): looking 2 m ahead
	# along his way, a body he would pass within reach of turns him aside, the more the nearer it is; already inside
	# one, he is steered straight out. _separate keeps them apart whatever gets past this.
	var out := w
	var speed := w.length()
	var fwd := w / speed if speed > 0.1 else Vector3.ZERO
	var bodies := []
	for s in squares:
		if s != active and s != a and (s as Athlete).act in ["sit", ""]:
			bodies.append([s.position, BODY_SEATED + 0.1])
	# Not round the active chaser: running into him is his touch (and steering round him made defenders slip a fifth
	# of the classic game's outs, match_sim 1.52 to 1.24 a minute); _separate keeps the two from passing through.
	for b in bodies:
		var d: Vector3 = (b[0] as Vector3) - a.position
		d.y = 0.0
		var dl := d.length()
		var r: float = b[1]
		if dl < r:
			out -= (d / dl if dl > 0.001 else fwd) * (r - dl) * 8.0
		elif speed > 0.1 and dl < 2.0:
			var along := d.dot(fwd)
			if along > 0.0:
				var lat := d - fwd * along
				var ll := lat.length()
				if ll < r:
					var away := -lat / ll if ll > 0.01 else Vector3(-fwd.z, 0.0, fwd.x)
					out += away * speed * (1.0 - ll / r) * clampf(1.0 - along / 2.0, 0.0, 1.0) * 1.6
	return out.limit_length(maxf(w.length(), 0.1)) if w.length() > 0.1 else out.limit_length(1.0)


## Inside the limits: a defender running at a line stops at it (you can still step over, and are out).
func _keep_in(a: Athlete, w: Vector3) -> Vector3:
	# Room to stop: at speed v he needs v^2 / 2a to pull up.
	var stop := a.vel.length_squared() / (2.0 * Athlete.DECEL * a.agility)
	var L: float = f.length * 0.5 - 0.45 - stop
	var W: float = f.width * 0.5 - 0.45 - stop
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


const USER_IDLE := 0.5
## How often a touch slips off your defender as you steer him, by difficulty (Beginner, Club, State,
## International). The AI's own defenders keep SWERVE_TOUCH, calibrated against real matches.
const USER_SLIP := [0.7, 0.55, 0.4, 0.25]


func _user_defender(dt: float) -> void:
	var a := user_def
	var j := controls.joystick if controls else Vector2.ZERO
	a.top = _top_speed(a, false)
	_user_idle = _user_idle + dt if j.length() < 0.1 else 0.0
	controls.set_buttons(["DODGE", "SWITCH"])
	controls.lit = ""
	# Coming on, or your thumb off the stick for a moment: he runs as the AI would (a first-time player is not left
	# standing in front of the chaser); the stick takes him back at once.
	if d_state.get(a, "") == "enter" or (_user_auto() and not dodging()):
		_defender_think(a, dt)
		return
	a.want = stick_world(j) * a.top
	a.want = _avoid(a, a.want) if a.want.length() > 0.1 else a.want
	if dodging():
		a.top *= 1.25
		a.want = _dodge_dir * a.top
		a.vel += _dodge_dir * 9.0 * dt
	# With the assist on (Settings > Lane assist) he pulls up at the line as the AI's defenders do, rather than run
	# out of limits from a thumb pushed the wrong way under an angled camera (the playtest's second worst find).
	if bool(Game.settings.lane_assist):
		a.want = _keep_in(a, a.want)
		_brake_at_line(a, dt)
	_stamina(a, dt)


## The assist's brake: his speed toward a line he is about to cross goes, at his full braking, as soon as he needs
## all of it to stop inside (a turn of the stick alone spends his grip on turning and carries him over).
func _brake_at_line(a: Athlete, dt: float) -> void:
	var brake := Athlete.DECEL * a.agility
	for k in [0, 2]:
		var lim: float = (f.length if k == 0 else f.width) * 0.5 - 0.3
		var p: float = a.position[k]
		var out: float = a.vel[k] * signf(p)
		if out <= 0.0:
			continue
		var room := lim - absf(p)
		if out * out / (2.0 * brake) >= room:
			a.vel[k] -= signf(p) * minf(out, brake * dt)
			if a.want[k] * signf(p) > 0.0:
				a.want[k] = 0.0


## Bodies are solid (the owner: runners went through the kneeling chasers, and a touch through the man touched, "like
## ghosts"). After everyone has moved: a defender is kept out of each seated chaser (who does not move) and of the
## other defenders (each giving way by half), and the active chaser out of a defender (he gives way); only where they stand (their
## speed is their own, so nobody jerks), and never a man diving, lying, getting up or swinging round the pole. A
## touch still lands: the hand reaches 0.76 m ahead (_touches), the bodies keep 0.5 m.
const BODY_SEATED := 0.62   # m between a seated chaser's middle and a defender's
const BODY_STANDING := 0.5  # m between two standing men's middles
const PUSH_MAX := 0.06      # m a frame they are moved apart at most


func _solid(a: Athlete) -> bool:
	return not (a.act in ["dive", "pole_dive", "lie", "getup", "pole_turn"])


func _separate() -> void:
	var movers: Array = []
	for d in batch:
		if d_state.get(d, "") == "in" and _solid(d):
			movers.append(d)
	for d in movers:
		for sq in squares:
			if sq == active or not (sq as Athlete).act in ["sit", ""] or (sq as Athlete).vel.length() > 0.5:
				continue
			_push_apart(d, sq, BODY_SEATED, 1.0)
	for i in movers.size():
		for k in range(i + 1, movers.size()):
			_push_apart(movers[i], movers[k], BODY_STANDING, 0.5)
	# The chaser and a defender: the chaser gives way, all of it. Pushing the defender too (half each, 0.11.2) shoved
	# him on, away from the hand, every frame they met: a free burst that cut the classic game's outs from 1.52 to
	# 1.18 a minute (match_sim, 10 matches).
	if active and _solid(active):
		for d in movers:
			_push_apart(active, d, BODY_STANDING, 1.0, PUSH_MAX * 0.5)


## Moves a (and b by the rest of it) apart along the ground until they are gap apart; share: a's part of it.
func _push_apart(a: Athlete, b: Athlete, gap: float, share: float, most := PUSH_MAX) -> void:
	var off := a.position - b.position
	off.y = 0.0
	var dist := off.length()
	if dist >= gap:
		return
	var dir := off / dist if dist > 0.001 else Vector3(1, 0, 0)
	var over := minf(gap - dist, most)   # a little a frame: never a jump (the steering keeps them clear)
	a.position += dir * over * share
	if share < 1.0:
		b.position -= dir * over * (1.0 - share)


## Your defender is yours alone (the owner: "the player is moving himself and dodging by himself when I'm supposed to
## be playing"): with your thumb off the stick he stands, and nothing dodges for him. Only a test's stand-in thumb
## (autopilot: tests/match_sim's "user") lets him run himself after USER_IDLE seconds, as he did before 0.11.2.
var autopilot := false


func _user_auto() -> bool:
	return autopilot and user_def != null and _user_idle > USER_IDLE


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
	var show_dir: bool = _user_chasing() and active != null and chase.dir != 0 and not chase.wazir \
		and not KhoRules.in_free_zone(f, active.position) and phase == "play"
	_arrow.visible = show_dir
	if show_dir:
		_arrow.position = Vector3(active.position.x, 0.035, active.position.z)
		_arrow.rotation.y = 0.0 if chase.dir > 0 else PI
	var ti := _kho_target(false) if _user_chasing() else -1
	if ti < 0 and not _kho_armed.is_empty():
		ti = int(_kho_armed.i)
	_target_ring.visible = ti >= 0
	if ti >= 0:
		_target_ring.position = Vector3(float(f.square_x[ti]), 0.03, 0)


func _camera(dt: float) -> void:
	_ease_stick(dt)
	if cam_locked:
		return
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
	arena.show_near(_cam_mode == Game.CAM_POLE)
	match _cam_mode:
		Game.CAM_CLOSE:
			# Low and near, at the chase's level: the players large, the crowd behind them.
			cam.position = Vector3(_cam_x, 4.0, W + 5.0)
			cam.look_at(Vector3(_cam_x, 0.6, -1.0))
		Game.CAM_POLE:
			cam.position = Vector3(-L - 7.0, 6.5, 0.0)
			cam.look_at(Vector3(active.position.x if active else 0.0, 0.0, 0.0) * 0.4 + Vector3(L * 0.2, 0, 0))
		_:
			if attract:
				cam.position = Vector3(_cam_x * 0.6 + sin(t_match * 0.05) * 3.0, 11.0, W + 15.0)
			else:
				cam.position = Vector3(_cam_x, 10.0, W + 10.5)
			cam.look_at(Vector3(_cam_x, 0.0, -1.2))


## The next camera: there at once (paused too, so the pause menu's button shows it behind the menu), its name called.
func cycle_camera() -> void:
	_cam_mode = (_cam_mode + 1) % 3
	Game.settings.camera = _cam_mode
	Game.save_settings()
	_camera(0.0)
	if hud and not paused:
		hud.callout(hud.camera_name(_cam_mode), Game.C_INK)


# ---------------------------------------------------------------- pause and back

## Watch AI (the owner's request for every game): the match at twice the speed, or back to its own. The whole game
## runs faster (Engine.time_scale), the clock, the players and the replays together; paused, the menus run at 1x.
func toggle_speed() -> void:
	speed = 2 if speed == 1 else 1
	Engine.time_scale = 1.0 if paused else float(speed)


func set_paused(on: bool) -> void:
	paused = on
	Engine.time_scale = 1.0 if on else float(speed)
	FoundationLink.paused = on
	Sfx.pause(on)
	if hud:
		hud.show_pause(on)


func on_back() -> void:
	if phase == "over":
		return
	if replay and replay.playing() and not paused:
		replay.end()
		return
	set_paused(not paused)


func quit_to_menu() -> void:
	Sfx.stop_all()
	Game.goto_menu()
