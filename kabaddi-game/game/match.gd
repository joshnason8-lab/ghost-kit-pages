extends Node3D
## A full kabaddi match: two halves of alternating 30-second raids under Pro-style rules.
##
## Rules covered: touch points, bonus line (6+ defenders on the mat), baulk line, raid clock,
## out of bounds with lobbies opening after a struggle, tackles and super tackles, chain
## holds, empty raids and do-or-die, revival in order of dismissal, all outs, half time,
## and a golden-raid shoot-out for tied knockout matches.
##
## Team 0 is always the player's side. It defends the z > 0 half and raids toward -z.

signal finished(result: Dictionary)
signal tutorial_event(name: String)

const RAID_TIME := 30.0
const RAID_GAP := 5.0          # seconds between raids (scaled by the clock speed)
const TIMEOUTS_PER_HALF := 2   # Pro rule: two 30-second timeouts per team per half
const TIMEOUT_TIME := 5.0      # real seconds the huddle lasts on screen
const HALF_LEN := 1200.0       # 20-minute halves, as in the pro game
const CLOCK_SPEEDS := [6.0, 3.0, 1.0]   # quick (about 7 min), fast (about 14 min), real time (40 min)
const BEAT := 0.6              # cant rhythm: one "kabaddi" per beat
# Raid rules. Pro: a 30-second raid clock and no chant. Traditional: no clock; the raider
# chants "kabaddi" on one breath, and the raid lasts as long as that breath.
const RULE_CLOCK := 0
const RULE_CANT_TAP := 1
const RULE_CANT_AUTO := 2     # "Breath": the chant runs by itself; effort costs breath
## Breath each move costs (seconds of the one breath), and the extra drain per second of
## sprinting or struggling in a hold.
const BREATH_COST := {"touch": 0.35, "toe": 0.6, "backkick": 0.6, "dodge": 0.5, "dubki": 0.9, "lion": 1.2}
const BREATH_SPRINT := 0.5
const BREATH_STRUGGLE := 0.8

# Difficulty profiles: how sharp the AI is and how forgiving the cant is.
const PROFILES := [
	{"tackle": 0.55, "telegraph": 0.48, "raider_skill": 0.45, "react": 0.55, "cant_window": 0.17, "miss_beats": 4.0, "assist": 1.6, "user_hold": 1.3},
	{"tackle": 0.85, "telegraph": 0.36, "raider_skill": 0.70, "react": 0.80, "cant_window": 0.13, "miss_beats": 3.0, "assist": 1.4, "user_hold": 1.1},
	{"tackle": 1.15, "telegraph": 0.29, "raider_skill": 0.92, "react": 1.00, "cant_window": 0.10, "miss_beats": 2.5, "assist": 1.2, "user_hold": 1.0},
	{"tackle": 1.45, "telegraph": 0.23, "raider_skill": 1.10, "react": 1.15, "cant_window": 0.075, "miss_beats": 2.0, "assist": 1.0, "user_hold": 0.9},
]
const SUSPEND_TIME := 120.0   # yellow card: two minutes of match time
const START_LIMIT := 5.0      # seconds to start a raid after the whistle
const C_GREEN_CARD := Color("3fbf6a")
const C_YELLOW_CARD := Color("ffd23f")
const CELE_ARMS := 0
const CELE_FIST := 1
const CELE_CLAP := 2
const CELE_FIVE := 3
const CELE_POINT := 4
const CELE_THUMP := 5
const TOUCH_TIME := 0.34
const KICK_TIME := 0.5
const DODGE_TIME := 0.26
const BACKKICK_TIME := 0.46
const DUBKI_TIME := 0.42
const JUMP_TIME := 0.62
const SHOVE_TIME := 0.42
const DIVE_TIME := 0.3

var config := {}
var arena: Arena
var cam: CameraRig
var _fps_frames := 0
var _fps_time := 0.0
var _fps_done := false
var _switch_ms := 0
var hud: MatchHud
var controls: TouchControls
var rng := RandomNumberGenerator.new()

var teams: Array = []          # [{id, name, kit, trim, players, score, out_queue, empty, pts{}}]
var athletes: Array = []       # every Athlete
var raiding := 0
var first_raider := 0
var phase := "intro"
var phase_t := 0.0
var half := 1
var clock := 180.0
var half_len := 180.0
var golden := false           # golden raid: sudden death after a drawn tie-breaker
var golden_raids := 0
var tiebreak := false         # five raids each by different raiders, for drawn knockouts
var timeout_team := -1
var officials: Officials
var tb_raids := [0, 0]
var tb_used := [[], []]       # raiders who have had their tie-breaker raid
var difficulty := 1
var prof: Dictionary = PROFILES[1]
var clock_speed := 6.0
var attract := false           # AI match running behind the main menu
var tutorial: Node = null
var _links: Array = []         # mesh pool for chain hand-holds
var control_mode := "all"      # "all" (quick, cup) or "career" (only your player)
var career_pid := ""
var paused := false
var events_left := 0

var raider: Athlete = null
var controlled: Athlete = null
var raid := {}
var stats := {}                # pid -> {raid, tackle}
var _pending_end := ""
var _post_messages: Array = []
var _hints_shown := 0
var raid_log: Array = []      # one entry per raid, for stats and tuning
var raid_rule := RULE_CANT_AUTO
var move_tries := {}          # move -> attempts, for tuning


func _ready() -> void:
	rng.randomize()
	difficulty = clampi(int(config.get("difficulty", Game.settings.difficulty)), 0, PROFILES.size() - 1)
	prof = PROFILES[difficulty]
	raid_rule = int(config.get("raid_rule", Game.settings.get("raid_rule", RULE_CANT_AUTO)))
	half_len = HALF_LEN
	clock_speed = CLOCK_SPEEDS[clampi(int(config.get("length", Game.settings.length)), 0, 2)]
	attract = bool(config.get("attract", false))
	if String(config.get("mode", "")) == "tutorial":
		clock_speed = 0.0
	clock = half_len
	control_mode = String(config.get("control", "all"))
	if bool(config.get("autoplay", false)):
		control_mode = "none"   # AI plays both sides (tests, attract mode)
	var cp = config.get("career_player", null)
	if cp is Dictionary:
		career_pid = String(cp.id)
	Game.apply_graphics(get_viewport())

	var kit := DB.kits(config.home, config.away)
	_make_team(0, String(config.home), kit[0])
	_make_team(1, String(config.away), kit[1])

	arena = Arena.new()
	add_child(arena)
	var banner := tr("LEAGUE_NAME").to_upper() if DB.team(config.home).kind == "league" else tr("MENU_CUP").to_upper()
	arena.build(String(config.get("arena", "dome")), kit[0], kit[1], banner)

	for t in 2:
		var tm: Dictionary = teams[t]
		var squad: Array = config.get("home_squad" if t == 0 else "away_squad", DB.team(tm.id).squad)
		var seven := DB.starting_seven(squad.duplicate())
		var limit: Array = config.get("players", [7, 7])
		seven = seven.slice(0, int(limit[t]))
		if t == 0 and cp is Dictionary:
			seven = _insert_career_player(seven, cp)
		for i in seven.size():
			var a := Athlete.new()
			a.setup(seven[i], t, tm.kit, tm.trim, arena.barefoot)
			if String(config.get("style", "")) != "":
				a.style = String(config.style)
				a.dmoves[a.style] = 90
			a.slot = i
			a.is_career = (String(seven[i].id) == career_pid)
			add_child(a)
			tm.players.append(a)
			athletes.append(a)
			stats[a.pid()] = {"raid": 0, "tackle": 0}
	_order_slots()
	officials = Officials.new()
	add_child(officials)
	officials.setup(self)

	cam = CameraRig.new()
	add_child(cam)
	cam.mode = int(Game.settings.camera)

	hud = MatchHud.new()
	add_child(hud)
	hud.setup(self)
	controls = hud.controls
	controls.action.connect(_on_action)
	controls.tapped.connect(_on_tap)

	if attract:
		hud.visible = false
		controls.enabled = false
		cam.mode = Game.CAM_TV
	if String(config.get("mode", "")) == "tutorial":
		tutorial = Tutorial.new()
		add_child(tutorial)
		tutorial.setup(self, String(config.get("lesson", "cant")))
	first_raider = rng.randi() % 2
	if config.has("first_raider"):
		first_raider = int(config.first_raider)
	raiding = first_raider
	_place_all_instant()
	Sfx.crowd(0.35)
	Sfx.drums(true)
	_set_phase("intro")
	if not attract:
		hud.show_intro(DB.team_name(teams[0].id), DB.team_name(teams[1].id), tr(_arena_name()))


func _arena_name() -> String:
	for a in DB.ARENAS:
		if a.id == config.get("arena", "dome"):
			return a.name
	return "ARENA_DOME"


func _make_team(t: int, id: String, kit: Color) -> void:
	var src := DB.team(id)
	var trim: Color = src.c2 if kit == src.c1 else src.c1
	if trim.is_equal_approx(kit):
		trim = Color.WHITE
	teams.append({
		"id": id, "kit": kit, "trim": trim, "players": [], "score": 0, "out_queue": [], "empty": 0,
		"pts": {"raid": 0, "tackle": 0, "allout": 0, "extra": 0},
		"timeouts": TIMEOUTS_PER_HALF, "timeout_pending": false, "run_against": 0,
	})


func _insert_career_player(seven: Array, cp: Dictionary) -> Array:
	for p in seven:
		if String(p.id) == String(cp.id):
			return seven
	# Replace the weakest player of the same broad role.
	var worst := -1
	var worst_ovr := 999
	for i in seven.size():
		var p: Dictionary = seven[i]
		var same: bool = (p.role == "defender") == (cp.role == "defender")
		if same and DB.overall(p) < worst_ovr:
			worst_ovr = DB.overall(p)
			worst = i
	if worst < 0:
		worst = seven.size() - 1
	seven[worst] = cp
	return seven


# ---------------------------------------------------------------- geometry helpers

func side(t: int) -> float:
	return 1.0 if t == 0 else -1.0


func depth_in(t: int, p: Vector3) -> float:
	return p.z * side(t)


func pos_in(t: int, x: float, d: float) -> Vector3:
	return Vector3(x * side(t), 0, d * side(t))


func defenders() -> Array:
	return teams[1 - raiding].players.filter(func(a): return a.on_mat)


func on_mat(t: int) -> Array:
	return teams[t].players.filter(func(a): return a.on_mat)


func _order_slots() -> void:
	for t in 2:
		var ps: Array = teams[t].players
		for i in ps.size():
			ps[i].slot = i


## Defensive shape: on-mat defenders in slot order, spread across the court in a shallow arc.
func formation_spot(a: Athlete) -> Vector3:
	var t := a.team
	var mates := on_mat(t)
	mates.sort_custom(func(x, y): return x.slot < y.slot)
	var n := mates.size()
	var i := mates.find(a)
	var width := minf(4.2, 0.75 * (n - 1))
	var lat := 0.0 if n <= 1 else lerpf(-width, width, float(i) / (n - 1))
	var d := 3.35 + 0.5 * (absf(lat) / 4.2)
	return pos_in(t, lat, d)


func bench_spot(t: int, k: int) -> Vector3:
	return Vector3(-3.5 + k * 1.0, 0, side(t) * (Arena.HALF_L + 2.5))


func _place_all_instant() -> void:
	for t in 2:
		for a in teams[t].players:
			a.position = formation_spot(a)
			a.facing = Vector3(0, 0, -side(t))


# ---------------------------------------------------------------- phases

func _set_phase(p: String) -> void:
	phase = p
	phase_t = 0.0
	for a in athletes:
		a.lock_facing = false


func _process(delta: float) -> void:
	if paused:
		return
	var dt := minf(delta, 0.05)
	_check_frame_rate(delta)
	phase_t += dt
	match phase:
		"intro":
			_walk_to_positions(dt, false)
			if phase_t > 3.0:
				_begin_setup()
		"setup":
			_walk_to_positions(dt, true)
			if phase_t > 2.2:
				_begin_raid()
		"raid":
			_tick_raid(dt)
		"post":
			_tick_post(dt)
		"timeout":
			_tick_timeout(dt)
		"halftime":
			_walk_to_positions(dt, false)
			if phase_t > 4.0:
				for a in athletes:
					_rest(a, 0.3)
				for tm in teams:
					tm.timeouts = TIMEOUTS_PER_HALF
				half = 2
				clock = half_len
				raiding = 1 - first_raider
				_begin_setup()
		"fulltime":
			_tick_celebrate(dt)
			if phase_t > 4.5:
				_finish()
	_update_chain_links()
	cam.follow(self, dt)
	hud.refresh()


func _begin_setup() -> void:
	_set_phase("setup")
	_end_suspensions()
	raider = _pick_raider(raiding)
	raider.raids_made += 1
	_tire(raider, 0.04)
	if tiebreak:
		tb_used[raiding].append(raider)
		tb_raids[raiding] += 1
	for a in athletes:
		a.touched = false
		a.set_ring(Color(0, 0, 0, 0))
		if a.on_mat and a.state != "walk":
			a.set_state("idle")
	raider.position = pos_in(raiding, 0.0, 1.4)
	raider.facing = Vector3(0, 0, -side(raiding))
	raider.set_state("raid")
	var tm: Dictionary = teams[raiding]
	raid = {
		"t": RAID_TIME, "entered": false, "baulk": false, "bonus": false, "touched": [], "holders": [],
		"progress": 0.0, "struggle": false, "dod": tm.empty >= 2 and not tiebreak and not golden, "alarm": false,
		"ai_mode": "approach", "ai_lane": rng.randf_range(-3.0, 3.0), "ai_t": 0.0, "ai_target": null,
		"probe_t": 0.0, "ai_step": "work", "ai_step_t": rng.randf_range(0.8, 1.6), "feint_on": null, "feint_t": 0.0, "feint_bit": false,
		"ai_bonus": false, "ai_dodge_cd": 0.0, "user_raids": raiding == 0 and _user_controls_raider(),
		"breath": 1.0, "beat_t": 0.0, "last_beat": -99, "chant_t": 0.0, "cant_tap": false, "last_ok": 0.0, "air_max": RAID_TIME,
		"shouted": false, "taunts": 0, "cross_cd": 0.0, "moves": [], "chain_caught": false, "kicks": 0, "def_moves": [], "dashed_by": null, "dash_t": 0.0,
	}
	controlled = null
	if raiding == 0 and _user_controls_raider():
		controlled = raider
	elif raiding == 1:
		controlled = _default_user_defender()
	for a in athletes:
		a.is_user = (a == controlled)
	for a in athletes:
		a.chain_partner = null
	raid.cant_tap = raider == controlled and raid_rule == RULE_CANT_TAP
	if raid_rule != RULE_CLOCK:
		# One breath: longer for fitter, fresher raiders.
		var stam := float(raider.data.attrs.stamina)
		raid.air_max = clampf(19.0 + 12.0 * (stam - 50.0) / 50.0, 15.0, 32.0) * (0.75 + 0.25 * raider.energy)
		raid.t = raid.air_max
	if controlled:
		controlled.set_ring(Game.C_SAFFRON)
	raider.set_ring(Game.C_SAFFRON if raider == controlled else Color(1, 1, 1, 0.65))
	hud.on_raid_setup()
	if _hints_shown < 2 and controlled:
		_hints_shown += 1
		var raid_hint := "HINT_RAID_CLOCK" if raid_rule == RULE_CLOCK else ("HINT_RAID" if raid.cant_tap else "HINT_RAID_AUTO")
		hud.hint(tr(raid_hint) if controlled == raider else tr("HINT_DEFEND"))
	if raid.dod:
		hud.hint(tr("HINT_DOD"))
	if not attract:
		# Who is coming, and what he likes to do.
		var sig := DB.signature(raider.data)
		hud.event("%s · %s: %s" % [raider.display_name(), tr("SIGNATURE"), tr(DB.MOVE_KEYS[sig])], Game.C_MUTED, true)


func _user_controls_raider() -> bool:
	if control_mode == "none":
		return false
	if control_mode == "all":
		return true
	return raider != null and raider.is_career


func _default_user_defender() -> Athlete:
	if control_mode == "none":
		return null
	if control_mode == "career":
		for a in on_mat(0):
			if a.is_career:
				return a
		return null
	# The defender closest to the raider's start, so the user is in the action.
	var best: Athlete = null
	var bd := 1e9
	for a in on_mat(0):
		var d = a.position.distance_to(raider.position)
		if d < bd:
			bd = d
			best = a
	return best


func _pick_raider(t: int) -> Athlete:
	var pool := on_mat(t)
	if tiebreak:
		var fresh := pool.filter(func(a): return not tb_used[t].has(a))
		if not fresh.is_empty():
			pool = fresh
	if t == 0 and control_mode == "career":
		for a in pool:
			if a.is_career and a.is_raider_type():
				return a
	var cands := pool.filter(func(a): return a.is_raider_type())
	if cands.is_empty():
		cands = pool
	# Lean on the best raider but rotate a little.
	# Best raider first, but tired legs and recent raids count against him.
	var score := func(a: Athlete) -> float: return DB.overall(a.data) - a.raids_made * 3 - (1.0 - a.energy) * 30.0
	cands.sort_custom(func(x, y): return score.call(x) > score.call(y))
	if cands.size() > 1 and rng.randf() < 0.25:
		return cands[1]
	return cands[0]


func _walk_to_positions(dt: float, with_raider: bool) -> void:
	var raider_team_k := 0
	for t in 2:
		var k := 0
		for a in teams[t].players:
			if not a.on_mat:
				_to_bench(a, dt)
				continue
			if with_raider and a == raider:
				a.seek(pos_in(t, 0.0, 1.4), 3.0, dt)
				a.face_toward(Vector3(0, 0, -side(t) * 5.0), dt)
				# The raider slaps his thighs before going in.
				if phase_t > 0.6 and phase_t < 1.9 and a.state != "slap":
					a.set_state("slap")
				elif phase_t >= 1.9 and a.state == "slap":
					a.set_state("raid")
				continue
			if t == raiding and phase == "setup":
				# Raider's team-mates wait deep in their own half.
				var spot := pos_in(t, -3.0 + raider_team_k * 1.2, 5.6)
				raider_team_k += 1
				a.seek(spot, 3.0, dt)
				a.face_toward(Vector3.ZERO, dt)
				if a.state == "ready":
					a.set_state("idle")
			else:
				a.seek(formation_spot(a), 3.2, dt)
				a.face_toward(Vector3(0, 0, 0), dt)
				if a.state == "celebrate" and a.st_t < 1.7:
					continue
				if a.state in ["idle", "walk", "celebrate", "sit"]:
					a.set_state("ready")
			k += 1


func _begin_raid() -> void:
	_set_phase("raid")
	raider.set_state("raid")
	Sfx.play("whistle", -4.0)
	arena.excite(0.3)
	hud.chant(raid_rule != RULE_CLOCK)


# ---------------------------------------------------------------- the raid

func _tick_raid(dt: float) -> void:
	raid.t -= dt
	clock = maxf(0.0, clock - dt * clock_speed)
	raid.ai_dodge_cd = maxf(0.0, raid.ai_dodge_cd - dt)
	raid.cross_cd = maxf(0.0, float(raid.cross_cd) - dt)
	raid.dash_t = maxf(0.0, float(raid.dash_t) - dt)
	_tick_cant(dt)
	if phase != "raid":
		return
	# The raider has five seconds from the whistle to start his raid.
	if not raid.entered and config.get("mode", "") != "tutorial":
		if phase_t > START_LIMIT - 2.0 and raider == controlled and not raid.get("late_warned", false):
			raid["late_warned"] = true
			hud.hint(tr("HINT_FIVE_SECONDS"))
		if phase_t > START_LIMIT:
			_end_raid("late")
			return
	_tick_shouts(dt)
	# The crowd builds as the raider goes deep and roars through a struggle.
	var tension := clampf(depth_in(1 - raiding, raider.position) / Arena.BONUS, 0.0, 1.0)
	Sfx.crowd(0.3 + 0.35 * tension + (0.35 if raid.struggle and not raid.holders.is_empty() else 0.0))
	var defs := defenders()
	var holders: Array = raid.holders

	# Raider movement.
	if raider.state in ["touch", "kick", "backkick", "shoved"] and raider.st_t >= raider.st_len:
		raider.set_state("raid")
	if raider.state in ["dubki", "jump"] and raider.st_t >= raider.st_len:
		# Land and plant: the burst does not carry on.
		raider.vel *= 0.35
	if raider.state in ["dodge", "dubki", "jump"] and raider.st_t >= raider.st_len:
		raider.set_state("held" if holders.size() > 0 else "raid")
	if holders.size() > 0 and raider.state == "raid":
		raider.set_state("held")

	var move := Vector3.ZERO
	var watch := _raider_watch()
	if raider == controlled:
		move = cam.input_to_world(controls.move_vec())
		if cam.mode == Game.CAM_FIRST:
			raider.lock_facing = true
			raider.facing = cam.flat_forward()
		else:
			raider.lock_facing = watch != null
	else:
		raider.lock_facing = watch != null
		move = _ai_raider(dt)
	_move_raider(move, dt)
	if watch != null and not (raider == controlled and cam.mode == Game.CAM_FIRST):
		raider.face_toward(watch.position, dt, 9.0)

	# Defenders.
	for d in defs:
		if d == controlled:
			_user_defender(d, dt)
		elif d.chain_partner != null and d.state in ["ready", "idle"]:
			_chained_follow(d, dt)
		else:
			_ai_defender(d, dt)
	_separate(defs, dt)
	_tick_bystanders(dt)
	for h in holders:
		_tire(h, 0.02 * dt)
		h.position = raider.position + h.hold_offset
		h.vel = raider.vel
		h.face_toward(raider.position, dt, 20.0)

	_check_contacts(defs)
	if phase == "raid":
		_check_chain_cross()
	_check_lines()
	_check_end(dt)


func _move_raider(move: Vector3, dt: float) -> void:
	var holders: Array = raid.holders
	var mid_dir := Vector3(0, 0, side(raiding))   # toward the raider's own half
	if raider.state == "dodge":
		raider.drive(raider.dive_dir * raider.max_speed * 1.9, dt)
	elif raider.state == "shoved":
		raider.drive(raider.dive_dir * raid.get("shove_speed", 4.0) + move * 0.8, dt)
	elif raider.state == "dubki" and holders.is_empty():
		raider.drive(raider.dive_dir * raider.max_speed * 1.5, dt)
	elif raider.state == "jump" and holders.is_empty():
		raider.drive(raider.dive_dir * raider.max_speed * (1.15 + 0.3 * raider.move_skill("lion")), dt)
	elif raider.state == "backkick":
		raider.drive(move * raider.max_speed * 0.6, dt)
	elif raider.state in ["touch", "kick"]:
		raider.drive(move * raider.max_speed * 0.35, dt)
	elif holders.size() > 0:
		# Struggle: push toward the midline against the holders.
		var hold_power := 0.0
		for h in holders:
			# A waist hold lifts him off his feet; a block or thigh hold pins him.
			var grip: float = {"waist": 1.35, "thigh": 1.1, "block": 1.15, "chain": 1.1}.get(h.kind(), 1.0)
			hold_power += h.tackle * grip * (0.8 + 0.4 * float(h.data.attrs.strength) / 100.0)
		var push := maxf(0.0, move.dot(mid_dir))
		# One defender can be dragged to the line; two or three usually win.
		var net := raider.strength * raider.energy * push * 1.4 - hold_power * 0.5
		var v := mid_dir * net * 1.3
		if net < 0.0:
			v = mid_dir * net * 0.5
		v.x += move.x * 0.4 * maxf(0.2, 1.0 - hold_power)
		raider.vel = v
		raider.position += v * dt
		raider.face_toward(raider.position + mid_dir, dt)
		if rng.randf() < dt * 1.4:
			var who: Athlete = raider if rng.randf() < 0.55 else holders[rng.randi() % holders.size()]
			Sfx.voice("grunt", -7.0 if who == raider else -10.0, who.voice_pitch())
		var rate := 0.16 + 0.32 * hold_power - 0.2 * raider.strength * push
		raid.progress = clampf(raid.progress + maxf(0.05, rate) * dt, 0.0, 1.0)
	else:
		raider.drive(move * raider.max_speed * (0.55 + 0.45 * raider.energy), dt)
	# The court: lobbies come into play only once there has been a struggle.
	var bound := Arena.HALF_W + (Arena.LOBBY if raid.struggle else 0.0)
	if absf(raider.position.x) > bound + 0.25 or depth_in(1 - raiding, raider.position) > Arena.HALF_L + 0.2:
		_end_raid("out_of_bounds")
		return
	raider.position.z = clampf(raider.position.z, -Arena.HALF_L - 1.0, Arena.HALF_L + 1.0)
	if depth_in(1 - raiding, raider.position) > 0.0:
		raider.energy = maxf(0.4, raider.energy - dt * 0.004)


## While he is stepping sideways or backing off with defenders close, the raider keeps his
## eyes on the nearest one rather than turning his back. Returns that defender, or null
## when he should just face where he is running (going for a touch, or racing home).
func _raider_watch() -> Athlete:
	if raider.state != "raid" or not raid.holders.is_empty():
		return null
	if depth_in(1 - raiding, raider.position) < 1.2:
		return null
	var near: Athlete = null
	var nd := 2.8
	for d in defenders():
		var off = d.position - raider.position
		off.y = 0
		if off.length() < nd:
			nd = off.length()
			near = d
	if near == null:
		return null
	var to := near.position - raider.position
	to.y = 0
	var v := Vector3(raider.vel.x, 0, raider.vel.z)
	# Running at him (to touch) or a defender right on his heels after a touch: run.
	if v.length() > 0.5 and v.normalized().dot(to.normalized()) > 0.4:
		return null
	if raid.touched.size() > 0 and nd < 1.3:
		return null
	return near


## Everyone not in the raid: the raider's team-mates watch from their half, and out
## players sit in the sitting block in the order they went out.
func _tick_bystanders(dt: float) -> void:
	for t in 2:
		for a in teams[t].players:
			if a == raider or (t != raiding and a.on_mat):
				continue
			if not a.on_mat:
				_to_bench(a, dt)
				continue
			a.drive(Vector3.ZERO, dt)
			a.face_toward(raider.position, dt, 3.0)


## Walk to his place in the sitting block and sit down; get up and shuffle along when the
## queue moves.
func _to_bench(a: Athlete, dt: float) -> void:
	if a.state in ["fallen", "recover", "roar", "slump", "argue", "shove", "celebrate"]:
		a.drive(Vector3.ZERO, dt)
		return
	var spot := bench_spot(a.team, teams[a.team].out_queue.find(a))
	var off := spot - a.position
	off.y = 0
	if a.state == "sit":
		a.vel = Vector3.ZERO
		if off.length() > 0.35:
			a.set_state("walk")
		else:
			a.position += off * minf(1.0, dt * 2.0)
			a.face_toward(Vector3(spot.x, 0, 0), dt, 4.0)
		return
	a.lock_facing = false
	a.seek(spot, 2.6, dt, 0.5)
	if off.length() < 0.2:
		a.vel = Vector3.ZERO
		a.set_state("sit")


func _separate(defs: Array, dt: float) -> void:
	# Set defenders give the raider room rather than bumping into him.
	if raid.holders.is_empty():
		for d in defs:
			if d.state in ["ready", "idle"] and d != controlled:
				var off: Vector3 = d.position - raider.position
				off.y = 0
				var l := off.length()
				if l < 0.55 and l > 0.001:
					d.position += off / l * (0.55 - l) * 0.6
	for i in defs.size():
		var a: Athlete = defs[i]
		if a.state == "holding":
			continue
		for j in range(i + 1, defs.size()):
			var b: Athlete = defs[j]
			if b.state == "holding":
				continue
			var d := b.position - a.position
			d.y = 0
			var l := d.length()
			if l < 0.6 and l > 0.001:
				var push := d / l * (0.6 - l) * 0.5
				a.position -= push
				b.position += push


func _clamp_defender(d: Athlete) -> void:
	var bound := Arena.HALF_W + (Arena.LOBBY if raid.struggle else 0.0) - 0.25
	if d != controlled:
		d.position.x = clampf(d.position.x, -bound, bound)
	var dep := depth_in(d.team, d.position)
	if dep < 0.25:
		d.position.z = side(d.team) * 0.25
	if dep > Arena.HALF_L - 0.25 and d != controlled:
		d.position.z = side(d.team) * (Arena.HALF_L - 0.25)


# ---------------------------------------------------------------- actions

func _on_action(id: String) -> void:
	match id:
		"pause":
			set_paused(not paused)
			return
		"camera":
			# Third person and broadcast (first person is gone: it played badly on a phone).
			cam.mode = Game.CAM_TV if cam.mode == Game.CAM_THIRD else Game.CAM_THIRD
			Game.settings.camera = cam.mode
			Game.save_settings()
			return
		"skip":
			if phase == "intro":
				_begin_setup()
			return
		"switch":
			# Pick your defender before the raid starts, too.
			if not paused and phase == "setup" and controlled != null and controlled != raider:
				_switch_defender()
				return
	if paused or phase != "raid" or controlled == null:
		return
	if controlled == raider:
		match id:
			"touch":
				_raider_touch(false)
			"kick":
				_raider_kick()
			"dodge", "tackle":
				_raider_dodge(Vector3.ZERO)
			"dubki":
				_raider_escape("dubki")
			"jump":
				_raider_escape("lion")
			"cant":
				_cant_tap()
	else:
		match id:
			"tackle", "dodge":
				_defender_tackle(controlled)
			"ankle", "thigh", "waist", "dash":
				_defender_tackle(controlled, id)
			"switch":
				_unchain(controlled)
				_switch_defender()
			"chain":
				_toggle_chain(controlled)


## The phone's back button: pause, or resume from the pause menu.
func on_back() -> void:
	if phase != "fulltime":
		set_paused(not paused)


## Lower the graphics by itself if the first raids run slowly on this phone.
func _check_frame_rate(delta: float) -> void:
	if _fps_done or phase != "raid":
		return
	if not bool(Game.settings.get("auto_gfx", true)) or bool(config.get("autoplay", false)) \
			or DisplayServer.get_name() == "headless" or OS.get_cmdline_args().has("--write-movie"):
		_fps_done = true
		return
	_fps_frames += 1
	_fps_time += delta
	if _fps_time < 6.0:
		return
	_fps_done = true
	var fps := _fps_frames / _fps_time
	var g := int(Game.settings.graphics)
	if fps < 36.0 and g > Game.GFX_LOW:
		Game.settings.graphics = g - 1
		Game.save_settings()
		Game.apply_graphics(get_viewport())
		if arena.sun:
			arena.sun.shadow_enabled = Game.shadows_enabled()
		hud.event(tr("GFX_LOWERED").format({"level": tr(["GFX_LOW", "GFX_MEDIUM", "GFX_HIGH"][g - 1])}), Game.C_MUTED)


func set_paused(p: bool) -> void:
	paused = p
	hud.show_pause(p)
	get_tree().paused = false


## How far a touch reaches. Better hands and toes reach further.
func _reach_for(move: String) -> float:
	match move:
		"toe":
			return raider.reach + 0.8 + 0.35 * (raider.move_skill("toe") - 0.6)
		"kick":
			return raider.reach + 0.55 + 0.4 * (raider.move_skill("kick") - 0.6)
	return raider.reach + 0.35 + 0.25 * (raider.move_skill("hand") - 0.6)


func _raider_touch(toe: bool) -> void:
	if raider.state not in ["raid", "dodge"] or raider.cooldown > 0.0:
		return
	if depth_in(1 - raiding, raider.position) < -0.3:
		return
	# Aim assist: turn toward the nearest untouched defender within reach.
	var r := _reach_for("toe" if toe else "hand")
	var best: Athlete = null
	var bd := r + 0.6
	for d in defenders():
		if d.touched:
			continue
		var dist = d.position.distance_to(raider.position)
		var ang := raider.facing.angle_to((d.position - raider.position).normalized())
		var limit: float = float(prof.assist) if raider == controlled else 1.4
		if cam.mode == Game.CAM_FIRST and raider == controlled:
			limit = 1.0
		if dist < bd and ang < limit:
			bd = dist
			best = d
	if best:
		raider.facing = (best.position - raider.position).normalized()
	# Sharp defenders see it coming and pull back out of reach.
	for d in defenders():
		if d == controlled or d.touched or d.state not in ["ready", "idle"] or d.cooldown > 0.0:
			continue
		var off = d.position - raider.position
		off.y = 0
		if off.length() < r + 0.3 and raider.facing.angle_to(off.normalized()) < 1.0:
			var p_ev = (0.06 + 0.24 * float(prof.react)) * (0.5 + 0.5 * d.agility) * (0.6 if toe else 1.0)
			if rng.randf() < p_ev:
				_evade(d)
	raider.set_state("kick" if toe else "touch", KICK_TIME if toe else TOUCH_TIME)
	_spend_breath("toe" if toe else "touch")
	raider.cooldown = (KICK_TIME if toe else TOUCH_TIME) + 0.15
	raid.touch_hit = false
	Sfx.play("whoosh", -12.0, 1.3 if toe else 1.6)


## The Kick button: a toe touch at a defender in front, or a back or side kick at one
## behind or beside the raider.
func _raider_kick() -> void:
	if raider.state not in ["raid", "dodge"] or raider.cooldown > 0.0:
		return
	var r := _reach_for("kick")
	var best: Athlete = null
	var bd := r + 0.3
	for d in defenders():
		if d.touched:
			continue
		var dist = d.position.distance_to(raider.position)
		if dist < bd:
			bd = dist
			best = d
	if best == null or raider.facing.angle_to((best.position - raider.position).normalized()) < 0.95:
		_raider_touch(true)
		return
	_raider_back_kick(best)


func _raider_back_kick(target: Athlete) -> void:
	if raider.state not in ["raid", "dodge"] or raider.cooldown > 0.0:
		return
	if depth_in(1 - raiding, raider.position) < -0.3:
		return
	var to := target.position - raider.position
	to.y = 0
	raider.kick_dir = to.normalized()
	var right := raider.facing.cross(Vector3.UP).normalized()
	raider.kick_side = clampf(raider.kick_dir.dot(right), -1.0, 1.0)
	raider.kick_back = clampf(-raider.kick_dir.dot(raider.facing), 0.0, 1.0)
	raider.set_state("backkick", BACKKICK_TIME)
	_spend_breath("backkick")
	move_tries["kick"] = move_tries.get("kick", 0) + 1
	raid.kicks = int(raid.kicks) + 1
	raider.cooldown = BACKKICK_TIME + 0.2
	raid.touch_hit = false
	Sfx.play("whoosh", -9.0, 1.1)


## Dubki (duck under the arms) or lion jump (leap over a low tackle).
func _raider_escape(kind: String, dir := Vector3.ZERO) -> void:
	if raider.state in ["touch", "kick", "backkick", "dodge", "dubki", "jump", "shoved"] or raider.cooldown > 0.0:
		return
	var holders: Array = raid.holders
	var move := cam.input_to_world(controls.move_vec()) if raider == controlled else dir
	if move.length() < 0.2:
		move = Vector3(0, 0, side(raiding))
	move = _safe_dir(move.normalized(), 3.8 if kind == "lion" else 3.0)
	raider.dive_dir = move
	move_tries[kind] = move_tries.get(kind, 0) + 1
	if kind == "dubki":
		raider.set_state("dubki", DUBKI_TIME)
		raider.cooldown = DUBKI_TIME + 0.5
		raider.energy = maxf(0.4, raider.energy - 0.02)
		_spend_breath("dubki")
		Sfx.play("whoosh", -6.0, 0.8)
		Sfx.voice("grunt", -10.0, raider.voice_pitch())
	else:
		raider.set_state("jump", JUMP_TIME)
		raider.cooldown = JUMP_TIME + 0.6
		raider.energy = maxf(0.4, raider.energy - 0.035)
		_spend_breath("lion")
		Sfx.play("whoosh", -4.0, 0.6)
		Sfx.voice("hup", -8.0, raider.voice_pitch())
	if holders.size() > 0:
		# Slipping a hold: a dubki slides out of a high grip, a jump kicks free of an ankle
		# hold. The wrong move against the grip rarely works.
		var h: Athlete = holders[rng.randi() % holders.size()]
		var right_move := (kind == "dubki") != (h.kind() == "ankle")
		var chance := (0.62 if right_move else 0.2) * (0.4 + raider.move_skill(kind)) * raider.strength / (holders.size() * (0.6 + h.tackle * 0.6))
		if rng.randf() < chance:
			_release(h, true)
			raider.set_state("dubki" if kind == "dubki" else "jump", DUBKI_TIME if kind == "dubki" else JUMP_TIME)
			_move_moment(kind)
			hud.event(tr("EV_BROKE_FREE"), Game.C_GOLD, true)
			_ooh()
			if raider == controlled:
				tutorial_event.emit("broke_free")
			if holders.is_empty():
				raid.progress = maxf(0.0, raid.progress - 0.35)


## The escape that beats what is coming: "jump" for a low tackle, "dubki" for a high one
## or for linked hands ahead. Lights the button on the easier levels.
func escape_hint() -> String:
	if raider == null:
		return ""
	var best: Athlete = null
	var bd := 2.6
	for d in defenders():
		if d.state in ["telegraph", "dive"]:
			var dist = d.position.distance_to(raider.position)
			if dist < bd:
				bd = dist
				best = d
	if best:
		return "jump" if best.kind() == "ankle" else "dubki"
	if raid.holders.size() > 0:
		var low := 0
		for h in raid.holders:
			if h.kind() == "ankle":
				low += 1
		return "jump" if low * 2 >= raid.holders.size() else "dubki"
	var home := Vector3(0, 0, side(raiding))
	if raider.vel.dot(home) > 0.5 and _link_ahead(home) != null:
		return "dubki"
	return ""


## AI escapes never carry the raider over a line it cannot cross.
func _safe_dir(move: Vector3, dist: float) -> Vector3:
	if raider == controlled:
		return move
	var land := raider.position + move * dist
	var bound := Arena.HALF_W + (Arena.LOBBY if raid.struggle else 0.0) - 0.6
	if absf(land.x) > bound:
		move.x = (signf(land.x) * bound - raider.position.x) / dist
	if depth_in(1 - raiding, land) > Arena.HALF_L - 0.6:
		move.z = -move.z
	if move.length() < 0.3:
		move = Vector3(0, 0, side(raiding))
	return move.normalized()


## A named move came off: shout it, count it, and tell the tutorial.
func _move_moment(move: String) -> void:
	raid.moves.append(move)
	var key: String = {"dubki": "EV_DUBKI", "lion": "EV_LION", "backkick": "EV_BACK_KICK", "sidekick": "EV_SIDE_KICK", "toe": "EV_TOE"}.get(move, "")
	if key != "":
		hud.event(tr(key), Game.C_GOLD, move in ["toe", "backkick", "sidekick"])
	if move in ["dubki", "lion"]:
		arena.excite(0.6)
		Sfx.play("roar", -14.0)
	if raider == controlled:
		tutorial_event.emit({"dubki": "dubki", "lion": "lion_jump", "backkick": "back_kick", "sidekick": "back_kick", "toe": "toe_touch"}.get(move, move))


func _raider_dodge(dir: Vector3) -> void:
	if raider.state in ["touch", "kick", "backkick", "dodge", "dubki", "jump", "shoved"] or raider.cooldown > 0.0:
		return
	var holders: Array = raid.holders
	var move := cam.input_to_world(controls.move_vec()) if raider == controlled else dir
	if move.length() < 0.2:
		move = Vector3(0, 0, side(raiding)) if holders.size() > 0 else raider.facing.cross(Vector3.UP)
	move = move.normalized()
	if raider != controlled:
		# AI dodges never carry the raider over a line it cannot cross.
		var land := raider.position + move * 1.2
		var bound := Arena.HALF_W + (Arena.LOBBY if raid.struggle else 0.0) - 0.5
		if absf(land.x) > bound:
			move.x = -signf(land.x) * absf(move.x)
		if depth_in(1 - raiding, land) > Arena.HALF_L - 0.6:
			move.z = -move.z
		move = move.normalized()
	raider.dive_dir = move
	raider.set_state("dodge", DODGE_TIME)
	_spend_breath("dodge")
	raider.cooldown = DODGE_TIME + 0.55
	raider.energy = maxf(0.4, raider.energy - 0.015)
	Sfx.play("whoosh", -6.0)
	if holders.size() > 0:
		var h: Athlete = holders[rng.randi() % holders.size()]
		var chance := 0.5 * raider.agility * raider.strength / (holders.size() * (0.6 + h.tackle * 0.6))
		if rng.randf() < chance:
			_release(h, true)
			hud.event(tr("EV_BROKE_FREE"), Game.C_GOLD)
			if raider == controlled:
				tutorial_event.emit("broke_free")
			if holders.is_empty():
				raid.progress = maxf(0.0, raid.progress - 0.35)


func _release(h: Athlete, knocked: bool) -> void:
	raid.holders.erase(h)
	h.position = raider.position + h.hold_offset * 1.8
	if knocked:
		h.set_state("recover", 1.1)
	else:
		h.set_state("ready")
	if raid.holders.is_empty():
		raider.set_state("raid")


func _defender_tackle(d: Athlete, kind := "") -> void:
	if d.state in ["dive", "recover", "holding"] or (d.state == "telegraph" and d == controlled) or d.cooldown > 0.0:
		return
	if kind != "":
		d.tackle_kind = kind
	elif d.tackle_kind == "" or d == controlled:
		d.tackle_kind = d.style
	var to := raider.position - d.position
	to.y = 0
	var dist := to.length()
	var dir := to.normalized() if dist > 0.01 else d.facing
	if dist > 2.6:
		# Too far: a short lunge forward that wastes time.
		dir = d.facing
	var lead := raider.vel * 0.12
	var aim := (raider.position + lead - d.position)
	aim.y = 0
	if aim.length() > 0.01 and dist <= 2.6:
		dir = aim.normalized()
	d.dive_dir = dir
	d.facing = dir
	d.set_state("dive", DIVE_TIME)
	d.cooldown = 1.4
	_tire(d, 0.035)
	d.chain_dive = false
	Sfx.play("whoosh", -8.0, 0.8)
	Sfx.voice("grunt", -9.0, d.voice_pitch())
	# A chained pair goes in together.
	var p: Athlete = d.chain_partner
	if p != null:
		_unchain(d)
		d.chain_dive = true
		if p.state in ["ready", "idle"] and p.position.distance_to(raider.position) < 3.0:
			_defender_tackle(p, p.style)
			p.chain_dive = true


## Switch: the defender nearest the raider; pressed again soon after, the next nearest,
## and so on round the cover.
func _switch_defender() -> void:
	if control_mode == "career":
		return
	var cands := defenders().filter(func(a): return a.state != "holding")
	if cands.is_empty():
		return
	cands.sort_custom(func(x, y): return x.position.distance_to(raider.position) < y.position.distance_to(raider.position))
	var now := Time.get_ticks_msec()
	var i := cands.find(controlled)
	var pick: Athlete = cands[0]
	if i >= 0 and (i == 0 or now - _switch_ms < 1500):
		pick = cands[(i + 1) % cands.size()]
	_switch_ms = now
	_select_defender(pick)


func _select_defender(a: Athlete) -> void:
	if a == null or a == controlled:
		return
	if controlled:
		_unchain(controlled)
		controlled.set_ring(Color(0, 0, 0, 0))
		controlled.is_user = false
	controlled = a
	controlled.is_user = true
	controlled.set_ring(Game.C_SAFFRON)
	Sfx.click()


## Tap a defender to take him over.
func _on_tap(pos: Vector2) -> void:
	if paused or control_mode == "career" or controlled == null or controlled == raider or phase not in ["setup", "raid"]:
		return
	var c: Camera3D = cam.cam
	var best: Athlete = null
	var bd := 80.0
	for a in on_mat(controlled.team):
		if a == raider or a.state == "holding":
			continue
		var p: Vector3 = a.global_position + Vector3(0, 0.9, 0)
		if c.is_position_behind(p):
			continue
		var d := c.unproject_position(p).distance_to(pos)
		if d < bd:
			bd = d
			best = a
	_select_defender(best)


func _user_defender(d: Athlete, dt: float) -> void:
	match d.state:
		"dive":
			d.drive(d.dive_dir * 8.0, dt)
			if d.st_t >= d.st_len:
				d.set_state("recover", 0.9)
		"recover":
			d.drive(Vector3.ZERO, dt)
			if d.st_t >= d.st_len:
				d.set_state("ready")
		"holding":
			pass
		_:
			var move := cam.input_to_world(controls.move_vec())
			if cam.mode == Game.CAM_FIRST:
				d.lock_facing = true
				d.facing = cam.flat_forward()
			else:
				# Keep him in view: shuffle and backpedal rather than turn your back,
				# unless you are running a long way.
				var gap := raider.position - d.position
				gap.y = 0
				d.lock_facing = move.length() < 0.1 or gap.length() < 4.5
				if d.lock_facing:
					d.face_toward(raider.position, dt, 10.0)
			d.drive(move * d.max_speed * (0.78 if d.chain_partner else 0.92), dt)
			if d.state not in ["ready", "idle"]:
				d.set_state("ready")
	# Stepping out before a struggle puts you out.
	var bound := Arena.HALF_W + (Arena.LOBBY if raid.struggle else 0.0)
	if d.state != "holding" and (absf(d.position.x) > bound + 0.2 or depth_in(d.team, d.position) > Arena.HALF_L + 0.2):
		_defender_out_of_bounds(d)
		return
	# Crossing the midline into the raider's half during a raid is out.
	if depth_in(d.team, d.position) < -0.12 and d.state != "holding":
		hud.event(tr("EV_CROSSED_MIDLINE"), Game.C_DANGER)
		_put_out(d)
		teams[raiding].score += 1
		teams[raiding].pts.extra += 1
		_revive(raiding, 1)
		_switch_defender_after_loss()
		if on_mat(1 - raiding).is_empty():
			_end_raid("all_out_lobby")
		return


func _defender_out_of_bounds(d: Athlete) -> void:
	hud.event(tr("EV_OUT_OF_BOUNDS"), Game.C_DANGER)
	_put_out(d)
	teams[raiding].score += 1
	teams[raiding].pts.extra += 1
	_revive(raiding, 1)
	_switch_defender_after_loss()
	if on_mat(1 - raiding).is_empty():
		_end_raid("all_out_lobby")


func _switch_defender_after_loss() -> void:
	if control_mode == "all" and raiding == 1:
		controlled = null
		_switch_defender()
	else:
		controlled = null


# ---------------------------------------------------------------- AI: raider

func _ai_raider(dt: float) -> Vector3:
	var defs := defenders()
	var opp := 1 - raiding
	var my_depth := depth_in(opp, raider.position)
	var skill: float = float(prof.raider_skill) + (float(raider.data.attrs.agility) - 60.0) * 0.006
	var holders: Array = raid.holders
	var home := pos_in(opp, raider.position.x * 0.8 * side(opp), -1.2)

	if holders.size() > 0:
		if raid.ai_dodge_cd <= 0.0 and rng.randf() < 0.35 * skill:
			raid.ai_dodge_cd = rng.randf_range(0.6, 1.1)
			var low := 0
			for h in holders:
				if h.kind() == "ankle":
					low += 1
			_ai_escape(low * 2 >= holders.size(), skill, Vector3(0, 0, side(raiding)))
		return Vector3(0, 0, side(raiding))

	# Threats: defenders winding up or diving nearby.
	var threat: Athlete = null
	var td := 1e9
	for d in defs:
		var dist = d.position.distance_to(raider.position)
		if d.state in ["telegraph", "dive"] and dist < 2.4 and dist < td:
			threat = d
			td = dist
	if threat and raid.ai_dodge_cd <= 0.0 and rng.randf() < clampf(skill * 0.6, 0.15, 0.8):
		raid.ai_dodge_cd = rng.randf_range(0.7, 1.4)
		var away := (raider.position - threat.position)
		away.y = 0
		var sidestep := away.normalized().cross(Vector3.UP) * (1.0 if rng.randf() < 0.5 else -1.0)
		var homeward := Vector3(0, 0, side(raiding))
		_ai_escape(threat.kind() == "ankle", skill, (sidestep + homeward * 0.8 + away.normalized() * 0.5).normalized())

	# Linked hands across the way home: duck under, leap, or go round.
	if raid.ai_mode == "return" and raid.ai_dodge_cd <= 0.0:
		var link = _link_ahead(Vector3(0, 0, side(raiding)))
		if link != null:
			raid.ai_dodge_cd = rng.randf_range(0.5, 0.9)
			var w := {"dubki": _tend("dubki") * 1.4, "lion": _tend("lion"), "round": 0.5}
			match _pick(w):
				"dubki":
					_raider_escape("dubki", Vector3(0, 0, side(raiding)))
				"lion":
					_raider_escape("lion", Vector3(0, 0, side(raiding)))
				_:
					raid["ai_round_x"] = signf(raider.position.x - (link as Vector3).x + 0.01) * 4.0

	# Back and side kicks at defenders closing in from behind or beside.
	var kick_cap := 1 + (1 if _tend("kick") > 1.2 else 0)
	if raider.cooldown <= 0.0 and raider.state == "raid" and raid.ai_mode in ["probe", "return"] and raid.baulk \
			and int(raid.kicks) < kick_cap:
		for d in defs:
			if d.touched or d.state == "holding":
				continue
			var dd = d.position.distance_to(raider.position)
			# Only at a defender coming at him, not at one standing off.
			var closing: bool = d.state == "telegraph" or d.vel.dot((raider.position - d.position).normalized()) > 0.8
			if closing and dd < _reach_for("kick") and raider.facing.angle_to((d.position - raider.position).normalized()) > 1.5 \
					and rng.randf() < dt * (0.05 + 0.5 * _tend("kick")) * skill \
					and (raid.touched.is_empty() or raid.get("ai_greedy", false)):
				_raider_back_kick(d)
				break

	var time_home := my_depth / raider.max_speed + 2.0
	var touched_n: int = raid.touched.size()
	var crowded := 0
	for d in defs:
		if d.position.distance_to(raider.position) < 1.7:
			crowded += 1
	if raid.ai_mode != "return":
		# Most raiders take the point and go; a greedy few hunt a second touch.
		if touched_n > 0 and not raid.has("ai_greedy"):
			raid["ai_greedy"] = rng.randf() < 0.2 + 0.25 * _tend("kick")
		var greedy: bool = raid.get("ai_greedy", false)
		if raid.t < time_home + 1.5 or (touched_n > 0 and (not greedy or crowded >= 2 or rng.randf() < dt * 1.2)) or (touched_n >= 2) or (raid.bonus and rng.randf() < dt * 2.0):
			raid.ai_mode = "return"

	var target: Vector3
	var speed := 0.75
	match raid.ai_mode:
		"approach":
			var lane: float = raid.ai_lane + sin(raid.t * 2.2) * 0.8
			target = pos_in(opp, lane * side(opp), 2.6)
			if my_depth > 2.2:
				raid.ai_mode = "baulk" if not raid.baulk else "probe"
				raid.ai_bonus = (defs.size() >= 6 and rng.randf() < 0.35) or bool(config.get("wide", false))
		"baulk":
			# Cross the baulk line through the widest gap in the chain.
			target = pos_in(opp, _gap_x(defs, opp), Arena.BAULK + 0.35)
			if raid.baulk:
				raid.ai_mode = "bonus" if raid.ai_bonus else "probe"
		"bonus":
			var bx := 4.3 if raider.position.x * side(opp) > 0.0 else -4.3
			target = pos_in(opp, bx, Arena.BONUS - 0.45)
			speed = 0.95
			if my_depth > Arena.BONUS - 0.75 and raider.cooldown <= 0.0 and raider.state == "raid":
				# Plant one foot and stretch the other across the line.
				raider.facing = Vector3(0, 0, -side(raiding))
				_raider_touch(true)
			if raid.bonus or raid.t < 14.0:
				raid.ai_mode = "probe"
		"probe":
			target = _ai_probe(defs, skill, dt)
			speed = float(raid.get("ai_speed", 0.6))
			if raid.ai_mark == null:
				target = home
		_:
			target = home
			speed = 1.0
	if raid.ai_mode == "return" and raid.has("ai_round_x") and _link_ahead(Vector3(0, 0, side(raiding))) != null:
		target.x = float(raid.ai_round_x)
	# Steer around defenders on the way. Going in, only sidestep (never back off over
	# the midline); coming home, steer freely.
	var steer := Vector3.ZERO
	for d in defs:
		var off: Vector3 = raider.position - d.position
		off.y = 0
		var l := off.length()
		if l < 1.6 and l > 0.01 and raid.ai_mode != "probe":
			steer += off / l * (1.6 - l) * 1.2
		elif l < 1.5 and l > 0.01 and raid.ai_mode == "probe" and d != raid.get("ai_mark") and raid.get("ai_step") == "work":
			# Working the cover: keep clear of everyone but the man he is testing.
			steer += off / l * (1.5 - l) * 1.5
	if raid.ai_mode not in ["return", "probe"]:
		steer.z = 0.0
		steer *= 0.6
	target.x = clampf(target.x, -4.3, 4.3)
	var to_t := target - raider.position
	to_t.y = 0
	var dir := to_t.normalized() if to_t.length() > 0.2 else Vector3.ZERO
	dir = (dir + steer).limit_length(1.0)
	# Stay off the side lines until the lobbies are live.
	if not raid.struggle and absf(raider.position.x) > 4.5:
		dir.x = -signf(raider.position.x) * 0.8
	return dir * speed


## A dash connects: no grip, just a shove toward the nearest line. Near the line it puts the
## raider out; in open court it only knocks him off his stride.
func _dash_hit(d: Athlete) -> void:
	raid.struggle = true   # contact: the lobby is now in play
	var bound := Arena.HALF_W + Arena.LOBBY
	var side_gap := bound - absf(raider.position.x)
	var end_gap := Arena.HALF_L - depth_in(1 - raiding, raider.position)
	var push := Vector3(signf(raider.position.x + 0.001), 0, 0)
	if end_gap < side_gap:
		push = Vector3(0, 0, -side(raiding))
	push = (push * 0.75 + d.dive_dir * 0.25).normalized()
	var power := 3.2 + 3.0 * d.dskill("dash") + 1.5 * (d.strength - raider.strength)
	raid["shove_speed"] = clampf(power, 2.0, 7.5)
	raider.dive_dir = push
	raider.set_state("shoved", SHOVE_TIME)
	raider.cooldown = SHOVE_TIME
	raid.dashed_by = d
	raid.dash_t = 1.2
	raid.alarm = true
	d.set_state("recover", 0.8)
	hud.event(tr("EV_DASH"), Game.C_MAGENTA)
	Sfx.play("thud", -2.0, 1.2)
	arena.excite(0.6)
	Game.vibrate(40)


## Metres from the raider to the nearest line he can be pushed over.
func _line_gap() -> float:
	if raider == null:
		return 99.0
	# After a dash the lobby is live, so it is the outer lobby line that counts.
	var bound := Arena.HALF_W + Arena.LOBBY
	return minf(bound - absf(raider.position.x), Arena.HALF_L - depth_in(1 - raiding, raider.position))


## Which tackle an AI defender goes in with: his strong skills far more than his weak ones,
## a dash only when the raider is near a line, and a sharp defender reads the raider.
func _ai_pick_tackle(d: Athlete) -> String:
	var forced := String(config.get("style", ""))
	if forced != "":
		return forced
	var w := {}
	for k in ["ankle", "thigh", "waist"]:
		w[k] = pow(d.dskill(k), 3.0) * 3.0
	if _line_gap() < 2.0:
		w["dash"] = pow(d.dskill("dash"), 3.0) * 6.0
	if raider.vel.dot(Vector3(0, 0, -side(d.team))) > 1.0:
		w.ankle *= 1.3      # ankle holds are the classic answer to a raider turning for home
	if rng.randf() < float(prof.react) * 0.5:
		w.ankle *= 1.3 - raider.move_skill("lion")
		w.thigh *= 1.3 - raider.move_skill("dubki")
		w.waist *= 1.3 - raider.move_skill("dubki")
	return _pick(w)


## The tackle that suits the moment, for the defend buttons on easier levels.
func defend_hint() -> String:
	if raider == null or phase != "raid":
		return ""
	if raider.airborne():
		return "waist"
	if _line_gap() < 1.8 and depth_in(1 - raiding, raider.position) > 0.3:
		return "dash"
	return ""


## How much this raider likes a move: strong moves get used far more than weak ones.
func _tend(move: String) -> float:
	return pow(raider.move_skill(move), 3.0) * 3.0


func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += maxf(0.0, float(weights[k]))
	var roll := rng.randf() * total
	for k in weights:
		roll -= maxf(0.0, float(weights[k]))
		if roll <= 0.0:
			return String(k)
	return String(weights.keys()[0])


## Escape a tackle or a hold. A good raider reads it: jump the low ones, duck the high ones.
func _ai_escape(low: bool, skill: float, dir: Vector3) -> void:
	var w := {"dodge": 0.9, "dubki": _tend("dubki"), "lion": _tend("lion")}
	if raid.ai_mode != "return" and raid.holders.is_empty():
		# Going in, a sidestep keeps the raid alive; the big moves are for the way home.
		w.dubki *= 0.25
		w.lion *= 0.25
		dir.z = 0.0
		if dir.length() < 0.2:
			dir = Vector3(1.0 if rng.randf() < 0.5 else -1.0, 0, 0)
		dir = dir.normalized()
	if rng.randf() < clampf(skill, 0.2, 0.95):
		if low:
			w.lion *= 2.5
			w.dubki *= 0.2
		else:
			w.dubki *= 2.5
			w.lion *= 0.3
	match _pick(w):
		"dubki":
			_raider_escape("dubki", dir)
		"lion":
			_raider_escape("lion", dir)
		_:
			_raider_dodge(dir)


## Midpoint of a pair of linked hands just ahead of the raider in direction dir, or null.
func _link_ahead(dir: Vector3):
	var probe := raider.position + dir * 0.8
	for d in defenders():
		var p: Athlete = d.chain_partner
		if p == null or d.get_instance_id() > p.get_instance_id() or d.state not in ["ready", "idle"]:
			continue
		var ab = p.position - d.position
		ab.y = 0
		var l2 = ab.length_squared()
		if l2 < 0.09 or l2 > 3.6:
			continue
		var t := clampf((probe - d.position).dot(ab) / l2, 0.1, 0.9)
		var c = d.position + ab * t
		var to_c = c - raider.position
		to_c.y = 0
		if to_c.length() < 1.0 and to_c.dot(dir) > 0.0:
			return (d.position + p.position) * 0.5
	return null


func _gap_x(defs: Array, opp: int) -> float:
	var xs := []
	for d in defs:
		xs.append(d.position.x * side(opp))
	xs.append(-Arena.HALF_W)
	xs.append(Arena.HALF_W)
	xs.sort()
	var best := 0.0
	var bw := -1.0
	for i in xs.size() - 1:
		var w: float = xs[i + 1] - xs[i]
		if w > bw:
			bw = w
			best = (xs[i] + xs[i + 1]) * 0.5
	return clampf(best, -4.2, 4.2)


## Working the cover. A good raider takes his time: light steps side to side just outside
## a defender's reach, the odd feint to draw a dive, a toe tap at a foot left in range, and
## he goes in when there is an opening (an isolated or out-of-position defender, a thin
## defence) or when the clock says he must.
func _ai_probe(defs: Array, skill: float, dt: float) -> Vector3:
	raid.probe_t = float(raid.probe_t) + dt
	raid.ai_step_t = float(raid.ai_step_t) - dt
	raid.feint_t = maxf(0.0, float(raid.feint_t) - dt)
	var mark: Athlete = raid.get("ai_mark") if raid.get("ai_step") == "strike" else null
	if mark == null or mark.touched or not mark.on_mat:
		mark = _ai_mark(defs)
	raid["ai_mark"] = mark
	if mark == null:
		return raider.position
	var to := mark.position - raider.position
	to.y = 0
	var dist := to.length()
	var home_dir := Vector3(0, 0, side(raiding))
	var across := to.normalized().cross(Vector3.UP) if dist > 0.01 else Vector3.RIGHT
	var open := _opening(mark, defs)
	var urgency := clampf(float(raid.probe_t) / (7.0 + 7.0 * skill), 0.0, 1.0)
	var target := raider.position
	match String(raid.ai_step):
		"feint":
			# A sharp step at him, then straight back out.
			target = mark.position
			raid.ai_speed = 1.0
			if float(raid.ai_step_t) <= 0.0:
				raid.ai_step = "work"
				raid.ai_step_t = rng.randf_range(0.8, 2.2)
		"strike":
			target = mark.position + home_dir * 0.4
			raid.ai_speed = 1.0
			var toe: bool = raid.get("strike_toe", false)
			if dist < _reach_for("toe" if toe else "hand") - 0.15 and raider.cooldown <= 0.0 and raider.state == "raid":
				raider.facing = to.normalized()
				_raider_touch(toe)
				raid.ai_step = "work"
				raid.ai_step_t = rng.randf_range(0.6, 1.4)
			elif float(raid.ai_step_t) <= 0.0:
				raid.ai_step = "work"
				raid.ai_step_t = rng.randf_range(0.6, 1.4)
		_:
			# Light steps side to side, just outside his reach.
			var sway := sin(float(raid.probe_t) * (1.0 + 0.6 * skill) + float(raid.ai_lane)) * 0.9
			target = mark.position + home_dir * (2.0 - 0.4 * urgency) + across * sway
			raid.ai_speed = 0.3 + 0.1 * skill
			if float(raid.ai_step_t) <= 0.0 and raider.cooldown <= 0.0:
				var go := (0.05 + 0.45 * open) * (0.2 + 0.8 * urgency) + urgency * urgency * 0.4
				var r := rng.randf()
				# A tight cover and the clock running down: a careful raider takes the empty raid.
				if urgency >= 0.75 and open < 0.4 and not raid.dod and rng.randf() < 0.4:
					raid.ai_mode = "return"
					return raider.position + home_dir
				if r < go:
					raid.ai_step = "strike"
					raid.ai_step_t = 1.1
					raid["strike_toe"] = _pick({"hand": _tend("hand") * 1.6, "toe": _tend("toe")}) == "toe"
				elif r < go + 0.35 * skill and dist < 2.6:
					raid.ai_step = "feint"
					raid.ai_step_t = 0.26
					raid.feint_on = mark
					raid.feint_t = 0.45
					raid.feint_bit = false
				else:
					raid.ai_step_t = rng.randf_range(0.5, 1.3)
			# A toe tap at a foot left in range: little risk, so take it.
			elif float(raid.probe_t) > 2.0 and dist < _reach_for("toe") - 0.1 and raider.cooldown <= 0.0 and raider.state == "raid" \
					and mark.state not in ["telegraph", "dive"] and rng.randf() < dt * (0.05 + 0.2 * _tend("toe")) * (0.3 + open):
				raider.facing = to.normalized()
				_raider_touch(true)
	return target


## 0..1: how much of an opening this defender offers.
func _opening(d: Athlete, defs: Array) -> float:
	if d.state in ["recover", "dive", "fallen"]:
		return 1.0
	var near := 9.0
	var depth_sum := 0.0
	for o in defs:
		depth_sum += depth_in(d.team, o.position)
		if o != d:
			near = minf(near, o.position.distance_to(d.position))
	var v := clampf((near - 1.1) / 1.6, 0.0, 1.0) * 0.6
	if defs.size() <= 3:
		v += 0.3
	# Stepped up in front of the others.
	if depth_in(d.team, d.position) < depth_sum / maxf(1.0, defs.size()) - 0.5:
		v += 0.25
	if d.chain_partner != null:
		v -= 0.3
	return clampf(v, 0.0, 1.0)


## A defender sees the touch coming and pulls back out of reach, eyes on the raider.
func _evade(d: Athlete) -> void:
	var away := d.position - raider.position
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3(0, 0, side(d.team))
	var sidestep := away.cross(Vector3.UP) * (0.6 if rng.randf() < 0.5 else -0.6)
	d.dive_dir = (away + sidestep).normalized()
	d.set_state("evade", 0.34)
	d.cooldown = 0.35


func _ai_mark(defs: Array) -> Athlete:
	# Prefer an isolated defender who is not already winding up.
	var best: Athlete = null
	var bs := -1e9
	for d in defs:
		if d.touched or d.state in ["holding"]:
			continue
		var iso := 0.0
		for o in defs:
			if o != d:
				iso += minf(2.5, o.position.distance_to(d.position))
		var score: float = iso - d.position.distance_to(raider.position) * 1.5
		# Corners (the ends of the cover) and weak tacklers are the usual targets.
		var lat := absf(d.position.x)
		var widest := true
		for o in defs:
			if absf(o.position.x) > lat + 0.3 and signf(o.position.x) == signf(d.position.x):
				widest = false
		if widest:
			score += 0.8
		score += (1.0 - d.dskill(d.style)) * 1.5
		if d.state in ["recover", "dive"]:
			score += 3.0
		if score > bs:
			bs = score
			best = d
	return best


# ---------------------------------------------------------------- AI: defenders

func _ai_defender(d: Athlete, dt: float) -> void:
	var opp_depth := depth_in(d.team, raider.position)
	var to := raider.position - d.position
	to.y = 0
	var dist := to.length()
	var holders: Array = raid.holders
	var diff: float = float(prof.tackle)
	var react: float = float(prof.react)
	match d.state:
		"telegraph":
			d.drive(Vector3.ZERO, dt)
			d.face_toward(raider.position, dt, 14.0)
			if d.st_t >= d.st_len:
				_defender_tackle(d)
			return
		"dive":
			d.drive(d.dive_dir * 8.0, dt)
			if d.st_t >= d.st_len:
				d.set_state("recover", 1.15 - 0.25 * react)
				if not raid.holders.has(d) and raid.holders.is_empty() and d.position.distance_to(raider.position) < 2.2:
					_ooh()
			# A dive that carries him over a boundary line (the lobby only counts once
			# there has been contact) puts him out.
			var bound := Arena.HALF_W + (Arena.LOBBY if raid.struggle else 0.0)
			if absf(d.position.x) > bound + 0.2 or depth_in(d.team, d.position) > Arena.HALF_L + 0.2:
				_defender_out_of_bounds(d)
				return
			_clamp_defender(d)
			return
		"recover":
			d.drive(Vector3.ZERO, dt)
			if d.st_t >= d.st_len:
				d.set_state("ready")
			return
		"holding":
			return
		"evade":
			d.lock_facing = true
			d.drive(d.dive_dir * d.max_speed * 1.2, dt)
			d.face_toward(raider.position, dt, 14.0)
			if d.st_t >= d.st_len:
				d.set_state("ready")
			_clamp_defender(d)
			return
	var inside = raid.entered and opp_depth > 0.0
	var alarm: bool = raid.alarm or (inside and opp_depth > Arena.BONUS + 0.3)
	var target := formation_spot(d)
	var spd := 2.4
	if holders.size() > 0 and dist < 3.2:
		# A team-mate has him: pile on.
		target = raider.position
		spd = d.max_speed
	elif alarm and inside:
		# Cut off the way home: get between the raider and the midline.
		var lat := (formation_spot(d).x - raider.position.x) * 0.35
		var cut := raider.position + Vector3(lat, 0, -side(d.team) * 1.15)
		if depth_in(d.team, cut) < 0.35:
			cut.z = side(d.team) * 0.35
		target = cut
		spd = 2.6 + 0.8 * react
	else:
		# Chain slides with the raider and gives ground when he gets close.
		target.x += raider.position.x * 0.28
		if inside and dist < 1.9 and dist > 0.01:
			target -= to / dist * (1.9 - dist) * 1.2
	# Defenders never turn their back on the raider: they shuffle and backpedal.
	d.lock_facing = true
	d.seek(target, spd, dt)
	d.face_toward(raider.position, dt, 10.0)
	if d.state not in ["ready"]:
		d.set_state("ready")
	_clamp_defender(d)

	# Neighbours link hands while the raider is in their half.
	var link_rate := 6.0 if bool(config.get("chains", false)) else 0.6
	if inside and not alarm and d.chain_partner == null and rng.randf() < dt * link_rate:
		for o in on_mat(d.team):
			if o != d and o != controlled and o.chain_partner == null and absi(o.slot - d.slot) == 1 \
					and o.state in ["ready", "idle"] and o.position.distance_to(d.position) < 1.6:
				_link(d, o)
				break
	# Tackle decision.
	if bool(config.get("passive", false)):
		return
	if not inside or d.cooldown > 0.0 or raider.state == "dodge":
		return
	# Once he is held, team-mates join the struggle rather than dive in.
	if holders.size() > 0:
		return
	var engaging := 0
	for o in defenders():
		if o.state in ["telegraph", "dive"]:
			engaging += 1
	var max_engage := 2 if alarm else 1
	if engaging >= max_engage:
		return
	var rng_range := 1.45 + 0.3 * react
	# A feint at him: a jumpy defender bites and goes in early.
	if raid.feint_on == d and float(raid.feint_t) > 0.0 and not raid.feint_bit and dist < rng_range + 0.4:
		raid.feint_bit = true
		if rng.randf() < 0.6 - 0.4 * react:
			d.tackle_kind = _ai_pick_tackle(d)
			d.set_state("telegraph", float(prof.telegraph) * 0.8)
			d.cooldown = 0.2
			return
	if dist > rng_range:
		return
	var p := 0.06 * diff * (0.6 + d.tackle)
	var heading_home := raider.vel.dot(Vector3(0, 0, -side(d.team))) > 1.0
	if _line_gap() < 2.0 and d.dskill("dash") > 0.55:
		p *= 1.5
	if heading_home:
		p *= 2.2
	if raider.state in ["touch", "kick"]:
		p *= 2.0
	# The raider stepping in to strike is the moment to go.
	var stepping_in: bool = raid.baulk and dist < 1.7 and dist > 0.01 and raider.vel.dot(-to.normalized()) > 1.6
	var striking: bool = raid.get("ai_step") == "strike" and raid.get("ai_mark") == d
	if stepping_in or striking or raider.state in ["touch", "kick"]:
		p = maxf(p, 2.2 * diff * (0.6 + d.tackle) * react)
	elif heading_home and not raid.touched.is_empty():
		p = maxf(p, 1.8 * diff * (0.6 + d.tackle) * react)
	# Behind his back: a raider looking the other way is there to be caught.
	if dist > 0.01 and dist < 2.0 and raid.baulk and raider.facing.dot(-to.normalized()) < -0.3:
		p = maxf(p, 1.2 * diff * (0.6 + d.tackle) * react)
	if alarm:
		p *= 1.6
	if d.touched:
		p *= 1.5
	if rng.randf() < p * dt:
		d.tackle_kind = _ai_pick_tackle(d)
		d.set_state("telegraph", float(prof.telegraph) * (1.15 if d.tackle_kind == "waist" else 1.0))
		d.cooldown = 0.2


# ---------------------------------------------------------------- contacts and lines

func _check_contacts(defs: Array) -> void:
	var opp := 1 - raiding
	var piling := []
	var in_half := depth_in(opp, raider.position) > -0.1
	for d in defs:
		if d.state == "holding":
			continue
		var dist = d.position.distance_to(raider.position)
		# Raider's touches.
		if in_half and not d.touched:
			# Body contact: a raider running into a defender, or a defender who is going for
			# him. Defenders standing their ground keep out of reach (see _separate).
			var to_d: Vector3 = (d.position - raider.position).normalized() if dist > 0.01 else raider.facing
			var hit = dist < 0.42 and (d.state in ["dive", "telegraph", "recover"] or raider.vel.dot(to_d) > 1.0)
			var via := ""
			if raider.state in ["touch", "kick"]:
				var p := raider.st_t / maxf(raider.st_len, 0.01)
				var active := p > 0.2 and p < 0.75
				var r := _reach_for("toe" if raider.state == "kick" else "hand")
				var ang := raider.facing.angle_to((d.position - raider.position).normalized())
				# A leg tags one defender; a hand can sweep two.
				if active and dist < r and ang < 1.2 and not (raider.state == "kick" and raid.get("touch_hit", false)):
					hit = true
					via = "toe" if raider.state == "kick" else "hand"
					raid.touch_hit = true
			elif raider.state == "backkick":
				var p2 := raider.st_t / maxf(raider.st_len, 0.01)
				var ang2 := raider.kick_dir.angle_to((d.position - raider.position).normalized())
				if p2 > 0.25 and p2 < 0.75 and dist < _reach_for("kick") and ang2 < 0.6 and not raid.get("touch_hit", false):
					hit = true
					raid.touch_hit = true
					via = "backkick" if raider.kick_back > 0.55 else "sidekick"
			if hit:
				_touch(d, via)
				# A defender touched while set may grab straight back.
				if d != controlled and d.state in ["ready", "telegraph"] and raider.state not in ["dodge", "dubki", "jump"] and not bool(config.get("passive", false)):
					var counter = 0.08 + 0.2 * d.tackle + 0.08 * float(prof.tackle)
					if d.state == "telegraph":
						counter += 0.3
					# Running straight into a set defender: he blocks.
					var into := raider.vel.dot((d.position - raider.position).normalized()) > 1.2 and via == ""
					if into:
						counter += 0.3 + 0.4 * (d.dskill("block") - 0.4)
					# A leg at full stretch is hard to grab from a set position.
					if via in ["toe", "backkick", "sidekick"]:
						counter *= 0.45
					if rng.randf() < counter:
						d.tackle_kind = "block" if into else d.style
						_attach(d, into)
						continue
		# Tackles.
		var kind = d.kind()
		var catch_r: float = {"ankle": 0.9, "waist": 0.75, "dash": 0.85}.get(kind, 0.8)
		if d.state == "dive" and dist < catch_r and raider.state != "shoved":
			if raider.state == "dodge" and rng.randf() < 0.6 * raider.agility:
				continue
			var low = kind == "ankle"
			# Lion jump: sail over a dive at the ankles (a waist hold can pluck him out of
			# the air). Dubki: duck under a high one.
			var clear: float = {"ankle": 0.55 + 0.45 * raider.move_skill("lion"), "waist": 0.12 * raider.move_skill("lion"),
				"dash": 0.4 * raider.move_skill("lion")}.get(kind, 0.25 * raider.move_skill("lion"))
			if raider.airborne() and rng.randf() < clear:
				d.set_state("recover", 1.1)
				_move_moment("lion")
				continue
			if raider.state == "dubki" and not low and rng.randf() < 0.5 + 0.45 * raider.move_skill("dubki"):
				d.set_state("recover", 1.1)
				_move_moment("dubki")
				continue
			if kind == "dash":
				_dash_hit(d)
				continue
			var hold_chance = 0.5 + 0.35 * d.tackle - 0.25 * (raider.agility - 1.0)
			hold_chance += {"thigh": 0.04, "waist": 0.06}.get(kind, 0.0) as float
			hold_chance += 0.3 * (d.dskill(kind) - 0.6)
			if raider.state == "dubki" and low:
				hold_chance += 0.15
			if raider.airborne():
				hold_chance += 0.3 if kind == "waist" else (0.1 if not low else 0.0)
			if raider.state in ["kick", "backkick"]:
				hold_chance += 0.12
			var behind := raider.facing.dot((d.position - raider.position).normalized()) < -0.2
			if behind:
				hold_chance += 0.2
			if d.chain_dive:
				hold_chance += 0.1 + 0.2 * d.dskill("chain")
			hold_chance *= 0.75 + 0.25 * d.energy
			if d == controlled:
				hold_chance *= float(prof.user_hold)
			if rng.randf() < hold_chance:
				_attach(d)
			else:
				d.set_state("recover", 1.0)
		elif raid.holders.size() > 0 and raid.holders.size() < 4 and d.state in ["ready", "idle"] and dist < 0.85 and d != controlled:
			piling.append(d)
		elif raid.holders.size() > 0 and d == controlled and dist < 0.75 and d.state != "recover":
			d.tackle_kind = "thigh"
			_attach(d)
	_pile_on(piling)


func _pile_on(piling: Array) -> void:
	# Team-mates pile in one at a time, a little faster the more of them are close.
	if piling.is_empty() or raid.holders.is_empty():
		return
	var rate := (0.45 + 0.2 * piling.size()) * float(prof.tackle)
	if rng.randf() < get_process_delta_time() * rate:
		var d: Athlete = piling[rng.randi() % piling.size()]
		d.tackle_kind = "thigh"
		_attach(d)


func _touch(d: Athlete, via := "") -> void:
	d.touched = true
	raid["vias"] = raid.get("vias", []) + [via if via != "" else ("contact_" + d.state)]
	raid.touched.append(d)
	raid.alarm = true
	d.set_ring(Color(Game.C_SAFFRON, 0.9))
	Sfx.play("slap", -2.0)
	if raider == controlled:
		tutorial_event.emit("touch")
	if via in ["toe", "backkick", "sidekick"]:
		_move_moment(via)
	hud.float_points(d, "+1")
	arena.excite(0.5)
	Game.vibrate(25)


func _attach(d: Athlete, block := false) -> void:
	if raid.holders.has(d):
		return
	var was_dive := d.state == "dive" or block
	var first: bool = raid.holders.is_empty()
	raid.holders.append(d)
	raid.struggle = true
	raid.alarm = true
	var off := d.position - raider.position
	off.y = 0
	if off.length() < 0.05:
		off = -raider.facing
	d.hold_offset = off.normalized() * 0.55
	d.set_state("holding")
	raider.set_state("held")
	Sfx.play("thud", -2.0)
	Sfx.voice("oof" if first else "grunt", -6.0, raider.voice_pitch())
	var chained := d.chain_dive and not first
	var hold_key: String = {"ankle": "EV_HOLD", "thigh": "EV_THIGH", "waist": "EV_WAIST", "block": "EV_BLOCK"}.get(d.kind(), "EV_HOLD") if was_dive else "EV_HOLD"
	raid.def_moves.append(d.kind() if was_dive else "pile")
	if first:
		raid["first_hold"] = (d.kind() if was_dive else "counter") + ("_chain" if d.tackle_kind == "chain" else "")
		raid["hold_depth"] = depth_in(1 - raiding, raider.position)
		raid["hold_t"] = float(raid.t)
	if d == controlled and was_dive:
		tutorial_event.emit(d.kind() + "_hold")
	hud.event(tr("EV_CHAIN") if (chained or not first) else tr(hold_key), Game.C_MAGENTA)
	if first and rng.randf() < 0.6:
		hud.bubble(d, tr("BUBBLE_PAKAD"), Game.C_MAGENTA.lightened(0.3))
		Sfx.yell("pakad", -6.0)
	if d == controlled:
		tutorial_event.emit("tackle")
	if chained and (d == controlled or (d.chain_partner == null and raid.holders.any(func(h): return h == controlled))):
		tutorial_event.emit("chain_tackle")
	arena.excite(0.7)
	Game.vibrate(40)


func _check_lines() -> void:
	var opp := 1 - raiding
	var dep := depth_in(opp, raider.position)
	if dep > 0.4 and not raid.entered:
		raid.entered = true
		if raider == controlled:
			tutorial_event.emit("entered")
	if not raid.baulk and dep > Arena.BAULK:
		raid.baulk = true
		if raider == controlled:
			tutorial_event.emit("baulk")
	# Bonus: one foot over the bonus line while the other is in the air, so a leg stretched
	# across it (a toe touch toward the end line) counts as well as stepping over. In a
	# golden raid the baulk line counts as the bonus line, whatever the numbers.
	var line := Arena.BAULK if golden else Arena.BONUS
	var foot := dep
	var airborne := false
	if raider.state == "kick":
		var p := raider.st_t / maxf(raider.st_len, 0.01)
		var into := Vector3(0, 0, -side(raiding))
		if p > 0.2 and p < 0.8 and raider.facing.dot(into) > 0.5:
			foot = dep + raider.facing.dot(into) * (raider.reach + 0.5)
			airborne = foot > line and dep <= line
	if not raid.bonus and foot > line and (golden or on_mat(opp).size() >= 6) and raid.holders.is_empty():
		raid.bonus = true
		hud.event(tr("EV_BONUS_AIR") if airborne else tr("EV_BONUS"), Game.C_GOLD)
		if raider == controlled:
			tutorial_event.emit("bonus")
		Sfx.play("slap", 0.0, 0.8)
		arena.excite(0.6)


func _check_end(dt: float) -> void:
	if phase != "raid":
		return
	var opp := 1 - raiding
	var dep := depth_in(opp, raider.position)
	var holders: Array = raid.holders
	if raid.entered:
		if holders.is_empty() and dep < -0.35:
			_end_raid("return")
			return
		if holders.size() > 0 and dep - raider.reach * 0.9 < 0.0:
			# Stretched out and touched the midline while held.
			_end_raid("return")
			return
	if holders.size() >= 3 and raid.progress > 0.5:
		_end_raid("tackle")
		return
	if raid.progress >= 1.0:
		_end_raid("tackle")
		return
	if raid.t <= 0.0:
		_end_raid("time" if raid_rule == RULE_CLOCK else "cant")


# ---------------------------------------------------------------- scoring

func _end_raid(kind: String) -> void:
	if phase != "raid":
		return
	_set_phase("post")
	hud.chant(false)
	var atk: int = raiding
	var dfn := 1 - raiding
	var touched: Array = raid.touched.filter(func(d): return d.on_mat)
	var bonus := 1 if raid.bonus else 0
	var on_def := on_mat(dfn).size()
	var raid_pts := 0
	var def_pts := 0
	var msg := ""
	var col := Game.C_INK
	var raider_out := false
	var tm_atk: Dictionary = teams[atk]
	var tm_def: Dictionary = teams[dfn]

	match kind:
		"return":
			if touched.is_empty() and bonus == 0:
				if not raid.baulk:
					raider_out = true
					def_pts = 1
					msg = tr("EV_BAULK_FAIL")
					col = Game.C_DANGER
				elif raid.dod:
					raider_out = true
					def_pts = 1
					msg = tr("EV_DOD_FAIL")
					col = Game.C_DANGER
				else:
					if not tiebreak and not golden:
						tm_atk.empty += 1
					msg = tr("EV_EMPTY")
			else:
				raid_pts = touched.size() + bonus
				msg = tr("EV_SUPER_RAID") if raid_pts >= 3 else tr("EV_RAID_OK")
				col = Game.C_GOLD if raid_pts >= 3 else Game.C_SAFFRON
		"tackle":
			raider_out = true
			def_pts = 2 if on_def <= 3 else 1
			raid_pts = bonus
			msg = tr("EV_SUPER_TACKLE") if on_def <= 3 else tr("EV_TACKLE")
			col = Game.C_MAGENTA
			for h in holders_copy():
				stats[h.pid()].tackle += 1
			raider.set_state("fallen")
			Sfx.play("thud", 2.0, 0.8)
			Sfx.voice("oof", -4.0, raider.voice_pitch())
		"out_of_bounds":
			raider_out = true
			def_pts = 1
			raid_pts = bonus
			msg = tr("EV_OUT_OF_BOUNDS")
			var dasher = raid.get("dashed_by")
			if dasher != null and float(raid.dash_t) > 0.0:
				msg = tr("EV_DASHED_OUT")
				stats[dasher.pid()].tackle += 1
				raid.def_moves.append("dash")
				if dasher == controlled:
					tutorial_event.emit("dash_out")
			col = Game.C_DANGER
		"time":
			raider_out = true
			def_pts = 1
			raid_pts = bonus
			msg = tr("EV_TIME_UP")
			col = Game.C_DANGER
		"cant":
			raider_out = true
			def_pts = 1
			raid_pts = bonus
			msg = tr("EV_CANT_LOST")
			col = Game.C_DANGER
		"all_out_lobby":
			pass
		"late":
			# Too slow to start the raid: a technical point to the defence.
			def_pts = 1
			msg = tr("EV_LATE_RAID")
			col = Game.C_DANGER
	if raid_pts > 0 or def_pts > 0:
		tm_atk.empty = 0
	elif kind == "return" and not raider_out:
		pass
	if raider_out:
		tm_atk.empty = 0

	# Runs of points against, for timeout calls.
	if raid_pts > def_pts:
		tm_def.run_against = int(tm_def.run_against) + raid_pts
		tm_atk.run_against = 0
	elif def_pts > 0:
		tm_atk.run_against = int(tm_atk.run_against) + def_pts
		tm_def.run_against = 0
	# Apply points.
	tm_atk.score += raid_pts
	tm_atk.pts.raid += raid_pts
	stats[raider.pid()].raid += raid_pts
	tm_def.score += def_pts
	tm_def.pts.tackle += def_pts

	# Outs, in order.
	if kind == "return" and not raider_out:
		for d in touched:
			_put_out(d)
	if raider_out:
		_put_out(raider)

	# Revivals: one per touch or tackle point (bonus points do not revive).
	_revive(atk, raid_pts - bonus)
	_revive(dfn, 1 if def_pts > 0 else 0)

	raid_log.append({"kind": kind, "raider_out": raider_out, "raid_pts": raid_pts, "def_pts": def_pts, "touches": touched.size(), "bonus": bonus, "t": float(raid.air_max) - float(raid.t), "moves": raid.moves.duplicate(), "chain_caught": raid.chain_caught, "def_moves": raid.def_moves.duplicate(), "first_hold": raid.get("first_hold", ""), "hold_depth": raid.get("hold_depth", -1.0), "held_for": float(raid.get("hold_t", raid.t)) - float(raid.t), "holders_end": raid.holders.size(), "vias": raid.get("vias", []), "probe_t": float(raid.get("probe_t", 0.0))})
	_post_messages = [[msg, col]]
	var all_out := false
	# All outs.
	for t in 2:
		if on_mat(t).is_empty():
			var other := 1 - t
			teams[other].score += 2
			teams[other].pts.allout += 2
			_post_messages.append([tr("EV_ALL_OUT"), Game.C_GOLD])
			all_out = true
			for a in teams[t].players:
				if not a.on_mat and a.suspended < 0.0:
					a.on_mat = true
					a.set_state("walk")
			teams[t].out_queue.clear()
	_milestones()
	if raid_pts > def_pts:
		officials.signal_points(atk, all_out, raid_pts + (2 if all_out else 0), bonus > 0)
	elif def_pts > 0:
		officials.signal_points(dfn, all_out, def_pts + (2 if all_out else 0))
	var holders_were := holders_copy()
	for h in holders_were:
		h.set_state("ready")
	raid.holders = []
	_react(kind, raid_pts, def_pts, raider_out, touched, holders_were)
	if raid_pts > 0 and not raider_out and raider == controlled:
		tutorial_event.emit("raid_point")

	var good_for_user := (raid_pts > 0 and atk == 0) or (def_pts > 0 and dfn == 0)
	var good_for_cpu := (raid_pts > 0 and atk == 1) or (def_pts > 0 and dfn == 1)
	if good_for_user or good_for_cpu:
		arena.excite(1.0 if good_for_user else 0.6)
		# The crowd is behind the home side (on the left of the scoreboard).
		var pts := raid_pts + def_pts
		var home_scored := (raid_pts > 0 and atk == 0) or (def_pts > 0 and dfn == 0)
		if home_scored:
			Sfx.react("cheer", -6.0 if pts >= 2 else -9.0)
			Sfx.react("applause", -10.0)
			if pts >= 3:
				Sfx.play("roar", -6.0)
		else:
			Sfx.react("groan", -10.0)
			Sfx.react("applause", -18.0)
	if kind == "return" and not raider_out:
		Sfx.voice("exhale", -9.0, raider.voice_pitch())
	Sfx.play("whistle", -6.0)
	for m in _post_messages:
		hud.event(m[0], m[1])
	if raid_pts + def_pts > 0:
		hud.event(tr("EV_POINTS").format({"n": raid_pts + def_pts}), Game.C_INK, true)
	clock = maxf(0.0, clock - RAID_GAP * clock_speed)


## Celebrate one way or another (see HumanModel.cele).
func _celebrate(a: Athlete, how := -1) -> void:
	a.cele_partner = null
	a.cele_kind = how if how >= 0 else [CELE_ARMS, CELE_FIST, CELE_CLAP, CELE_POINT, CELE_THUMP][rng.randi() % 5]
	a.set_state("celebrate")
	if a.cele_kind == CELE_POINT:
		a.face_toward(Vector3(signf(a.position.x + 0.01) * 20.0, 0, a.position.z), 1.0, 100.0)


## Two team-mates jog together and slap hands.
func _high_five(a: Athlete, b: Athlete) -> void:
	for pair in [[a, b], [b, a]]:
		var p: Athlete = pair[0]
		p.set_state("celebrate")
		p.cele_kind = CELE_FIVE
		p.cele_partner = pair[1]


## The team-mate nearest a player, among those standing around.
func _nearest_mate(a: Athlete, pool: Array) -> Athlete:
	var best: Athlete = null
	var bd := 1e9
	for o in pool:
		if o == a or o.state not in ["idle", "ready", "walk"]:
			continue
		var dd: float = o.position.distance_to(a.position)
		if dd < bd:
			bd = dd
			best = o
	return best


## The crowd gasps at a near thing: a dive that just misses, a raider breaking a hold.
func _ooh() -> void:
	if raid.has("ooh_t") and float(raid.ooh_t) - float(raid.t) < 2.0:
		return
	raid["ooh_t"] = float(raid.t)
	Sfx.react("ooh", -7.0)


## Players react: roars, slumps, appeals to the referee, the odd shove. Not every point
## gets a celebration, and no two look the same: roars, fist pumps, claps, high fives,
## pointing to the crowd. Big moments bring the whole team in.
func _react(kind: String, raid_pts: int, def_pts: int, raider_out: bool, touched: Array, holders_were: Array) -> void:
	var atk: int = raiding
	var dfn := 1 - raiding
	if raid_pts > 0 and not raider_out:
		var big := raid_pts >= 3 or on_mat(dfn).is_empty()
		var mates := on_mat(atk)
		var buddy := _nearest_mate(raider, mates)
		var r := rng.randf()
		if buddy != null and r < (0.45 if big else 0.25):
			_high_five(raider, buddy)
		elif big or r < 0.55:
			raider.set_state("roar")
		elif r < 0.75:
			_celebrate(raider, CELE_FIST)
		elif r < 0.85:
			_celebrate(raider, CELE_POINT)
		# Otherwise he just jogs back: job done.
		if raider.state in ["roar", "celebrate"] or rng.randf() < 0.4:
			hud.bubble(raider, tr("BUBBLE_HAAN") if rng.randf() < 0.5 else tr("BUBBLE_AAJA"), Game.C_GOLD)
			Sfx.yell("haan" if rng.randf() < 0.5 else "aaja", -2.0)
		for a in mates:
			if a != raider and a.state in ["idle", "ready"] and rng.randf() < (0.8 if big else 0.3):
				_celebrate(a, [CELE_ARMS, CELE_CLAP, CELE_FIST, CELE_CLAP][rng.randi() % 4] if not big else -1)
		for d in touched:
			d.set_state("slump")
		# Sometimes the defence disputes the touch.
		var defs := on_mat(dfn)
		if not defs.is_empty() and rng.randf() < 0.35:
			var who: Athlete = defs[rng.randi() % defs.size()]
			who.set_state("argue")
			who.face_toward(Vector3(Arena.HALF_W + 3.0, 0, 0), 1.0, 100.0)
			hud.bubble(who, tr("BUBBLE_NO_TOUCH"), Game.C_INK)
			Sfx.yell("nahi", -6.0)
	elif def_pts > 0:
		var big := def_pts >= 2
		var stars: Array = holders_were.duplicate()
		if stars.size() >= 2 and rng.randf() < 0.45:
			_high_five(stars[0], stars[1])
		for d in stars:
			if d.state == "celebrate":
				continue
			var r := rng.randf()
			if big or r < 0.5:
				d.set_state("roar")
			elif r < 0.8:
				_celebrate(d, CELE_FIST if r < 0.68 else CELE_THUMP)
		for d in on_mat(dfn):
			if not stars.has(d) and rng.randf() < (0.85 if big else 0.3):
				_celebrate(d, -1 if big else [CELE_CLAP, CELE_FIST, CELE_ARMS][rng.randi() % 3])
		if not stars.is_empty():
			var lead: Athlete = stars[0]
			hud.bubble(lead, tr("BUBBLE_SHABASH"), Game.C_MAGENTA.lightened(0.3))
			Sfx.yell("shabash", -3.0)
		if kind == "tackle" and not holders_were.is_empty() and rng.randf() < 0.35:
			# A shove as the raider gets up; he claims he got a touch.
			var pusher: Athlete = holders_were[rng.randi() % holders_were.size()]
			pusher.set_state("shove")
			pusher.shove_target = raider
			if rng.randf() < 0.4:
				_card(pusher)
			raider.set_state("argue")
			hud.bubble(raider, tr("BUBBLE_TOUCH"), Game.C_INK)
			Sfx.yell("touch", -5.0)
		elif kind != "tackle":
			raider.set_state("slump")
		for a in on_mat(atk):
			if a != raider and rng.randf() < 0.5:
				a.set_state("slump")


func _tick_shouts(dt: float) -> void:
	# Defenders call for the catch when the raider goes deep.
	if not raid.shouted and (raid.alarm or depth_in(1 - raiding, raider.position) > Arena.BAULK):
		raid.shouted = true
		var defs := defenders()
		if not defs.is_empty():
			var who: Athlete = defs[rng.randi() % defs.size()]
			hud.bubble(who, tr("BUBBLE_PAKAD") if rng.randf() < 0.6 else tr("BUBBLE_CHAIN"), Game.C_MAGENTA.lightened(0.35))
			Sfx.yell("pakad", -8.0)
	# The raider taunts the chain.
	if raid.taunts < 1 and raid.touched.is_empty() and rng.randf() < dt * 0.35:
		for d in defenders():
			if d.position.distance_to(raider.position) < 2.4:
				raid.taunts += 1
				hud.bubble(raider, tr("BUBBLE_AAJA"), Game.C_GOLD)
				Sfx.yell("aaja", -7.0)
				break


# ---------------------------------------------------------------- the cant

func _tick_cant(dt: float) -> void:
	raid.beat_t += dt
	if raid_rule == RULE_CLOCK:
		return
	var in_half := depth_in(1 - raiding, raider.position) > 0.0
	# The whole raid is one breath. Sprinting and struggling in a hold burn it faster.
	var extra := 0.0
	if Vector2(raider.vel.x, raider.vel.z).length() > raider.max_speed * 0.75:
		extra += BREATH_SPRINT
	if not (raid.holders as Array).is_empty():
		extra += BREATH_STRUGGLE
	raid.t = float(raid.t) - extra * dt
	raid.breath = clampf(float(raid.t) / float(raid.air_max), 0.0, 1.0)
	if raid.cant_tap:
		# The chant must not stop: miss a few beats in their half and the cant is broken.
		# A move is a "kabaddi" too, so pressing Touch or Dubki never costs you the cant.
		if not in_half or raider.state in ["touch", "kick", "backkick", "dodge", "dubki", "jump", "held", "shoved"]:
			raid.last_ok = maxf(float(raid.last_ok), float(raid.beat_t) - BEAT)
		elif float(raid.beat_t) - float(raid.last_ok) > float(prof.miss_beats) * BEAT:
			_end_raid("cant")
	else:
		# AI raiders, and Breath mode, keep the chant going on their own.
		raid.chant_t -= dt
		if raid.chant_t <= 0.0:
			raid.chant_t = 0.42
			Sfx.chant_word(-9.0 if raider == controlled else -15.0)
			if raider == controlled:
				tutorial_event.emit("cant")


## A move costs breath under the traditional rules.
func _spend_breath(move: String) -> void:
	if raid_rule != RULE_CLOCK and phase == "raid":
		raid.t = float(raid.t) - float(BREATH_COST.get(move, 0.4))


func _cant_tap() -> void:
	if not raid.cant_tap:
		return
	var b := int(round(raid.beat_t / BEAT))
	var d := absf(raid.beat_t - b * BEAT)
	var w: float = float(prof.cant_window)
	var gain := 0.0
	var kind := ""
	if b == int(raid.last_beat):
		gain = -0.6
		kind = "fast"
	elif d < w * 0.6:
		kind = "perfect"
	elif d < w:
		kind = "good"
	else:
		gain = -0.6
		kind = "off"
	raid.last_beat = b
	# A clean "kabaddi" keeps the cant alive; a ragged one wastes breath.
	if gain >= 0.0:
		raid.last_ok = raid.beat_t
	else:
		raid.t = float(raid.t) + gain
	if gain >= 0.0:
		Sfx.chant_word(-3.0)
		tutorial_event.emit("cant")
	hud.cant_feedback(kind)


# ---------------------------------------------------------------- chains

## Linked hands are a wall at waist height. Run into one and the pair closes on you,
## unless you duck under it (dubki) or leap it (lion jump).
func _check_chain_cross() -> void:
	if float(raid.cross_cd) > 0.0 or raid.holders.size() > 0 or depth_in(1 - raiding, raider.position) <= 0.0:
		return
	for d in defenders():
		var p: Athlete = d.chain_partner
		if p == null or not p.on_mat or d.get_instance_id() > p.get_instance_id():
			continue
		if d.state not in ["ready", "idle"] or p.state not in ["ready", "idle"]:
			continue
		var ab = p.position - d.position
		ab.y = 0
		var l2 = ab.length_squared()
		if l2 < 0.09 or l2 > 3.6:
			continue
		var t := clampf((raider.position - d.position).dot(ab) / l2, 0.0, 1.0)
		if t < 0.15 or t > 0.85:
			continue
		var off = raider.position - (d.position + ab * t)
		off.y = 0
		if off.length() > 0.3:
			continue
		raid.cross_cd = 0.8
		if raider.state == "dubki":
			if rng.randf() < 0.45 + 0.5 * raider.move_skill("dubki"):
				_move_moment("dubki")
				return
		elif raider.state == "jump":
			if rng.randf() < 0.3 + 0.45 * raider.move_skill("lion"):
				_move_moment("lion")
				return
		if bool(config.get("passive", false)):
			return
		var catch = 0.4 + 0.15 * (d.tackle + p.tackle) * float(prof.tackle) + 0.25 * (d.dskill("chain") + p.dskill("chain") - 1.0)
		if raider.state == "dodge":
			catch *= 0.6
		if rng.randf() < catch:
			_unchain(d)
			raid.chain_caught = true
			d.chain_dive = true
			p.chain_dive = true
			d.tackle_kind = "chain"
			p.tackle_kind = "chain"
			_attach(d)
			_attach(p)
		else:
			# Barged through: the hands come apart.
			_unchain(d)
			hud.event(tr("EV_BROKE_FREE"), Game.C_GOLD, true)
		return

func _link(a: Athlete, b: Athlete) -> void:
	a.chain_partner = b
	b.chain_partner = a
	var off := b.position - a.position
	off.y = 0
	b.chain_offset = off.normalized() * 0.9 if off.length() > 0.05 else Vector3(0.9, 0, 0)
	a.chain_offset = -b.chain_offset


func _unchain(a: Athlete) -> void:
	if a == null:
		return
	var p: Athlete = a.chain_partner
	a.chain_partner = null
	if p:
		p.chain_partner = null


func _toggle_chain(d: Athlete) -> void:
	if d.chain_partner:
		_unchain(d)
		Sfx.click()
		return
	var best: Athlete = null
	var bd := 2.6
	for o in defenders():
		if o == d or o.chain_partner != null or o.state not in ["ready", "idle"]:
			continue
		var dist = o.position.distance_to(d.position)
		if dist < bd:
			bd = dist
			best = o
	if best:
		_link(d, best)
		hud.bubble(d, tr("BUBBLE_CHAIN"), Game.C_SAFFRON)
		Sfx.yell("chal", -6.0)
		tutorial_event.emit("chain")
	else:
		hud.hint(tr("HINT_NO_PARTNER"))


## A defender holding hands with the user's defender moves with them.
func _chained_follow(d: Athlete, dt: float) -> void:
	var lead: Athlete = d.chain_partner
	if lead == null or not lead.on_mat or lead.state in ["dive", "recover", "holding"]:
		_unchain(d)
		return
	if lead != controlled:
		# AI pairs: each keeps its own place, the link just shows.
		_ai_defender(d, dt)
		if d.position.distance_to(lead.position) > 1.9:
			_unchain(d)
		return
	d.lock_facing = true
	d.seek(lead.position + d.chain_offset, d.max_speed, dt, 0.3)
	d.face_toward(raider.position, dt, 10.0)
	if d.state != "ready":
		d.set_state("ready")
	_clamp_defender(d)


func _update_chain_links() -> void:
	var pairs := []
	if phase == "raid":
		for a in defenders():
			var b: Athlete = a.chain_partner
			if b != null and b.on_mat and a.get_instance_id() < b.get_instance_id():
				pairs.append([a, b])
	while _links.size() < pairs.size():
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.045
		cyl.height = 1.0
		cyl.radial_segments = 8
		mi.mesh = cyl
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Game.C_GOLD
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_links.append(mi)
	for i in _links.size():
		var mi: MeshInstance3D = _links[i]
		mi.visible = i < pairs.size()
		if not mi.visible:
			continue
		var a: Athlete = pairs[i][0]
		var b: Athlete = pairs[i][1]
		var pa := a.position + Vector3(0, 0.95, 0)
		var pb := b.position + Vector3(0, 0.95, 0)
		var mid := (pa + pb) * 0.5
		var length := maxf(0.05, pa.distance_to(pb) - 0.35)
		mi.position = mid
		mi.basis = _align_y((pb - pa).normalized(), length)
		var user_pair := a == controlled or b == controlled
		(mi.material_override as StandardMaterial3D).albedo_color = Game.C_SAFFRON if user_pair else Game.C_GOLD


func _align_y(dir: Vector3, length: float) -> Basis:
	# Basis whose Y axis points along dir (cylinders are built along Y).
	var y := dir.normalized()
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y * length, z)


func holders_copy() -> Array:
	return (raid.holders as Array).duplicate()


func _put_out(a: Athlete) -> void:
	if not a.on_mat:
		return
	a.on_mat = false
	a.touched = false
	a.set_ring(Color(0, 0, 0, 0))
	if not teams[a.team].out_queue.has(a):
		teams[a.team].out_queue.append(a)
	if a.state != "fallen":
		a.set_state("walk")


## Rough play: a green card is a warning; a second offence is a yellow card, two
## minutes off and a technical point to the other side.
func _card(a: Athlete) -> void:
	a.cards += 1
	Sfx.play("whistle", -4.0, 1.15)
	if a.cards == 1:
		officials.show_card(C_GREEN_CARD)
		_post_messages.append([tr("EV_GREEN_CARD").format({"name": a.display_name()}), C_GREEN_CARD])
		return
	officials.show_card(C_YELLOW_CARD)
	var opp := 1 - a.team
	teams[opp].score += 1
	teams[opp].pts.extra += 1
	_post_messages.append([tr("EV_YELLOW_CARD").format({"name": a.display_name()}), C_YELLOW_CARD])
	# Off he goes, unless he is the last man on the mat.
	if a.on_mat and on_mat(a.team).size() > 1:
		a.on_mat = false
		a.suspended = maxf(0.0, clock - SUSPEND_TIME)
		a.suspended_half = half
		teams[a.team].out_queue.erase(a)
		if a.state != "shove":
			a.set_state("walk")


## Suspended players come back once their two minutes are up (or at half time).
func _end_suspensions() -> void:
	for a in athletes:
		if a.suspended >= 0.0 and (clock <= a.suspended or half != a.suspended_half):
			a.suspended = -1.0
			a.on_mat = true
			a.set_state("walk")
			hud.event(tr("EV_SUSPENSION_OVER").format({"name": a.display_name()}), Game.C_GOOD)


## Super 10 (ten raid points in a match) and High 5 (five tackle points).
func _milestones() -> void:
	for a in athletes:
		var st: Dictionary = stats.get(a.pid(), {})
		if st.is_empty():
			continue
		if int(st.raid) >= 10 and not a.has_meta("super10"):
			a.set_meta("super10", true)
			_post_messages.append([tr("EV_SUPER_10").format({"name": a.display_name()}), Game.C_GOLD])
			Sfx.react("cheer", -5.0)
		if int(st.tackle) >= 5 and not a.has_meta("high5"):
			a.set_meta("high5", true)
			_post_messages.append([tr("EV_HIGH_5").format({"name": a.display_name()}), Game.C_GOLD])
			Sfx.react("cheer", -5.0)


func _revive(t: int, n: int) -> void:
	var revived := 0
	for i in n:
		if teams[t].out_queue.is_empty():
			break
		var a: Athlete = teams[t].out_queue.pop_front()
		a.on_mat = true
		a.set_state("walk")
		revived += 1
	if revived > 0:
		_post_messages.append([tr("EV_REVIVED").format({"n": revived}), Game.C_GOOD])


func _tick_post(dt: float) -> void:
	# Let the moment breathe, then reset.
	for a in athletes:
		if a.state == "fallen" and phase_t > 1.2:
			a.set_state("walk")
		if a.state == "shove" and a.shove_target != null and a.st_t < 0.35:
			var push: Vector3 = a.shove_target.position - a.position
			push.y = 0
			if push.length() > 0.01:
				a.shove_target.position += push.normalized() * 1.6 * dt
		if a.state in ["roar", "slump", "shove", "argue"] and phase_t > 2.0:
			a.set_state("walk" if not a.on_mat else "idle")
		if a.state == "celebrate" and a.cele_partner != null:
			# Jog over to the team-mate and slap hands.
			var p: Athlete = a.cele_partner
			var gap = p.position - a.position
			gap.y = 0
			a.lock_facing = true
			a.face_toward(p.position, dt, 10.0)
			if gap.length() > 0.95:
				a.drive(gap.normalized() * 3.2, dt)
			else:
				a.drive(Vector3.ZERO, dt)
				if not a.has_meta("fived"):
					a.set_meta("fived", true)
					p.set_meta("fived", true)
					Sfx.play("clap", -6.0)
		elif a.state == "celebrate":
			a.drive(Vector3.ZERO, dt)
		elif a.state in ["walk", "sit"] or not a.on_mat:
			pass
		else:
			a.drive(Vector3.ZERO, dt)
	if phase_t > 1.0:
		_walk_to_positions(dt, false)
	if phase_t > 2.6:
		_next_raid()


func _next_raid(after_timeout := false) -> void:
	for a in athletes:
		a.cele_partner = null
		a.remove_meta("fived")
		if a.state in ["celebrate", "roar", "slump", "shove", "argue", "slap"]:
			a.set_state("idle")
	if not after_timeout:
		# Get some breath back between raids; more on the bench.
		for a in athletes:
			if a != raider:
				_rest(a, 0.012 if a.on_mat else 0.035)
		if _maybe_timeout():
			return
	if tutorial:
		raiding = tutorial.next_raiding_team(raiding)
		_begin_setup()
		return
	if golden:
		# Sudden death: the first raid that scores (either way) settles it.
		golden_raids += 1
		if teams[0].score != teams[1].score:
			_end_match()
			return
	elif tiebreak:
		if tb_raids[0] >= 5 and tb_raids[1] >= 5:
			if teams[0].score != teams[1].score:
				_end_match()
				return
			_start_golden()
			return
	elif clock <= 0.0:
		if half == 1:
			_set_phase("halftime")
			officials.signal_call("half")
			hud.banner(tr("HALF_TIME"))
			Sfx.play("buzzer", -4.0)
			return
		if teams[0].score == teams[1].score and bool(config.get("knockout", false)):
			_start_tiebreak()
			return
		_end_match()
		return
	raiding = 1 - raiding
	_begin_setup()


## Tire a player. Fitter players tire more slowly; nobody drops below a third of his legs.
func _tire(a: Athlete, amount: float) -> void:
	var stam := float(a.data.attrs.stamina)
	a.energy = maxf(0.35, a.energy - amount * clampf(1.35 - stam / 100.0, 0.4, 1.0))


func _rest(a: Athlete, amount: float) -> void:
	a.energy = minf(1.0, a.energy + amount)


func team_energy(t: int) -> float:
	var mat := on_mat(t)
	if mat.is_empty():
		return 1.0
	var s := 0.0
	for a in mat:
		s += a.energy
	return s / mat.size()


## A timeout the user asked for, or one the AI wants: tired legs, or a run of points
## against. Only between raids, never in the tie-breaker or golden raid.
func _maybe_timeout() -> bool:
	if tiebreak or golden or tutorial or clock <= 0.0 or attract:
		return false
	for t in 2:
		var tm: Dictionary = teams[t]
		if int(tm.timeouts) <= 0:
			tm.timeout_pending = false
			continue
		var ai_team := t == 1 or bool(config.get("autoplay", false))
		var wants: bool = tm.timeout_pending
		if ai_team and not wants:
			wants = team_energy(t) < 0.6 or int(tm.run_against) >= 6
		if wants:
			_start_timeout(t)
			return true
	return false


func request_timeout() -> bool:
	if int(teams[0].timeouts) <= 0 or tiebreak or golden:
		return false
	teams[0].timeout_pending = true
	return true


func _start_timeout(t: int) -> void:
	var tm: Dictionary = teams[t]
	tm.timeouts = int(tm.timeouts) - 1
	tm.timeout_pending = false
	tm.run_against = 0
	timeout_team = t
	_set_phase("timeout")
	officials.signal_call("timeout")
	hud.banner(tr("TIMEOUT_BY").format({"team": String(tm.id)}))
	Sfx.play("whistle", -4.0)
	for a in athletes:
		if a.on_mat:
			a.set_state("walk")
	# A 30-second timeout off the match clock... the clock stops, so nothing to take off.


func _tick_timeout(dt: float) -> void:
	# Each team huddles near its own end line.
	for t in 2:
		var mat := on_mat(t)
		for i in mat.size():
			var a: Athlete = mat[i]
			var ang := TAU * float(i) / maxf(1.0, mat.size())
			var spot := pos_in(t, cos(ang) * 0.9, Arena.HALF_L - 1.6 + sin(ang) * 0.9)
			a.seek(spot, 2.2, dt)
			if a.position.distance_to(spot) < 0.3:
				a.face_toward(pos_in(t, 0.0, Arena.HALF_L - 1.6), dt)
				if a.state != "idle":
					a.set_state("idle")
	if phase_t > TIMEOUT_TIME:
		for a in athletes:
			_rest(a, 0.22 if a.team == timeout_team else 0.08)
		_next_raid(true)


## Drawn knockout: all seven back on each side, then five raids each by five different
## raiders, alternating. Points count as normal.
func _start_tiebreak() -> void:
	tiebreak = true
	tb_raids = [0, 0]
	tb_used = [[], []]
	_all_back()
	hud.banner(tr("TIEBREAK"))
	Sfx.play("buzzer", -4.0)
	raiding = first_raider
	_begin_setup()


## Still level after the tie-breaker: a coin toss, then golden raids until one scores. The
## baulk line counts as the bonus line.
func _start_golden() -> void:
	tiebreak = false
	golden = true
	golden_raids = 0
	_all_back()
	raiding = rng.randi() % 2
	hud.banner(tr("GOLDEN_RAID"))
	hud.event(tr("EV_TOSS").format({"team": String(teams[raiding].id)}), Game.C_GOLD)
	Sfx.play("buzzer", -4.0)
	_begin_setup()


func _all_back() -> void:
	for t in 2:
		for a in teams[t].players:
			if not a.on_mat and a.suspended < 0.0:
				a.on_mat = true
				a.set_state("walk")
		teams[t].out_queue.clear()
		teams[t].empty = 0


func _end_match() -> void:
	_set_phase("fulltime")
	officials.signal_call("end")
	Sfx.play("buzzer", -2.0)
	Sfx.drums(false)
	var w := _winner()
	hud.banner(tr("FULL_TIME"))
	arena.excite(1.0)
	if w >= 0:
		var ps: Array = teams[w].players
		for a in ps:
			a.on_mat = true
			_celebrate(a, CELE_ARMS if rng.randf() < 0.5 else -1)
		for i in range(0, ps.size() - 1, 3):
			_high_five(ps[i], ps[i + 1])
		for a in teams[1 - w].players:
			if rng.randf() < 0.6:
				a.set_state("slump")


func _winner() -> int:
	if teams[0].score > teams[1].score:
		return 0
	if teams[1].score > teams[0].score:
		return 1
	return -1


func _tick_celebrate(dt: float) -> void:
	for a in athletes:
		if a.state == "celebrate" and a.cele_partner != null and a.position.distance_to(a.cele_partner.position) > 0.95:
			a.lock_facing = true
			a.face_toward(a.cele_partner.position, dt, 10.0)
			a.drive((a.cele_partner.position - a.position).normalized() * 3.0, dt)
		else:
			a.drive(Vector3.ZERO, dt)


func _finish() -> void:
	Sfx.crowd(-1.0)
	Sfx.drums(false)
	var best_pid := ""
	var best_pts := -1
	var best_team := 0
	var best_name := ""
	for t in 2:
		for a in teams[t].players:
			var s: Dictionary = stats[a.pid()]
			var pts: int = s.raid + s.tackle
			if pts > best_pts:
				best_pts = pts
				best_pid = a.pid()
				best_team = t
				best_name = a.display_name()
	var career_stats := {"raid": 0, "tackle": 0}
	if career_pid != "" and stats.has(career_pid):
		career_stats = stats[career_pid]
	var player_stats := {}
	for t in 2:
		for a in teams[t].players:
			var st: Dictionary = stats[a.pid()]
			player_stats[a.pid()] = {"name": a.display_name(), "team": String(teams[t].id), "raid": int(st.raid), "tackle": int(st.tackle)}
	var result := {
		"player_stats": player_stats,
		"config": config,
		"home": teams[0].id,
		"away": teams[1].id,
		"score": [teams[0].score, teams[1].score],
		"breakdown": [teams[0].pts.duplicate(), teams[1].pts.duplicate()],
		"winner": _winner(),
		"mvp": {"pid": best_pid, "name": best_name, "team": teams[best_team].id, "pts": best_pts},
		"career_stats": career_stats,
		"raid_log": raid_log, "move_tries": move_tries,
		"quit": false,
	}
	finished.emit(result)
	if attract or bool(config.get("autoplay_no_report", false)):
		return
	Game.on_match_finished(result)


func quit_match() -> void:
	Sfx.stop_all()
	get_tree().paused = false
	if String(config.get("mode", "quick")) in ["quick", "tutorial"]:
		if String(config.get("mode", "")) == "tutorial":
			Game.show_screen("res://ui/tutorial_menu.gd")
		else:
			Game.goto_menu()
		return
	# In a tournament or career, quitting forfeits: record a result from the score so far,
	# with the user's side losing if level.
	var s0: int = teams[0].score
	var s1: int = teams[1].score
	if s0 >= s1:
		s1 = s0 + 1
	var result := {
		"config": config, "home": teams[0].id, "away": teams[1].id, "score": [s0, s1],
		"breakdown": [teams[0].pts.duplicate(), teams[1].pts.duplicate()], "winner": 1,
		"mvp": {"pid": "", "name": "", "team": teams[1].id, "pts": 0},
		"career_stats": stats.get(career_pid, {"raid": 0, "tackle": 0}), "quit": true,
	}
	Game.on_match_finished(result)


# ---------------------------------------------------------------- helpers for HUD and camera

func clock_text() -> String:
	var s := int(ceil(clock))
	return "%d:%02d" % [s / 60, s % 60]


func focus_athlete() -> Athlete:
	if controlled and controlled.on_mat:
		return controlled
	return raider
