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
const HALF_LEN := 1200.0       # 20-minute halves, as in the pro game
const CLOCK_SPEEDS := [6.0, 3.0, 1.0]   # quick (about 7 min), fast (about 14 min), real time (40 min)
const BEAT := 0.6              # cant rhythm: one "kabaddi" per beat

# Difficulty profiles: how sharp the AI is and how forgiving the cant is.
const PROFILES := [
	{"tackle": 0.55, "telegraph": 0.48, "raider_skill": 0.45, "react": 0.55, "cant_window": 0.17, "breath_drain": 0.065, "assist": 1.6, "user_hold": 1.3},
	{"tackle": 0.85, "telegraph": 0.36, "raider_skill": 0.70, "react": 0.80, "cant_window": 0.13, "breath_drain": 0.085, "assist": 1.4, "user_hold": 1.1},
	{"tackle": 1.15, "telegraph": 0.29, "raider_skill": 0.92, "react": 1.00, "cant_window": 0.10, "breath_drain": 0.105, "assist": 1.2, "user_hold": 1.0},
	{"tackle": 1.45, "telegraph": 0.23, "raider_skill": 1.10, "react": 1.15, "cant_window": 0.075, "breath_drain": 0.125, "assist": 1.0, "user_hold": 0.9},
]
const TOUCH_TIME := 0.34
const KICK_TIME := 0.5
const DODGE_TIME := 0.26
const DIVE_TIME := 0.3

var config := {}
var arena: Arena
var cam: CameraRig
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
var golden := false
var golden_raids := 0
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


func _ready() -> void:
	rng.randomize()
	difficulty = clampi(int(config.get("difficulty", Game.settings.difficulty)), 0, PROFILES.size() - 1)
	prof = PROFILES[difficulty]
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
			a.slot = i
			a.is_career = (String(seven[i].id) == career_pid)
			add_child(a)
			tm.players.append(a)
			athletes.append(a)
			stats[a.pid()] = {"raid": 0, "tackle": 0}
	_order_slots()

	cam = CameraRig.new()
	add_child(cam)
	cam.mode = int(Game.settings.camera)

	hud = MatchHud.new()
	add_child(hud)
	hud.setup(self)
	controls = hud.controls
	controls.action.connect(_on_action)

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


func _process(delta: float) -> void:
	if paused:
		return
	var dt := minf(delta, 0.05)
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
		"halftime":
			_walk_to_positions(dt, false)
			if phase_t > 4.0:
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
	raider = _pick_raider(raiding)
	raider.raids_made += 1
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
		"progress": 0.0, "struggle": false, "dod": tm.empty >= 2, "alarm": false,
		"ai_mode": "approach", "ai_lane": rng.randf_range(-3.0, 3.0), "ai_t": 0.0, "ai_target": null,
		"ai_bonus": false, "ai_dodge_cd": 0.0, "user_raids": raiding == 0 and _user_controls_raider(),
		"breath": 1.0, "beat_t": 0.0, "last_beat": -99, "chant_t": 0.0, "cant_tap": false,
		"shouted": false, "taunts": 0,
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
	raid.cant_tap = raider == controlled and int(Game.settings.get("cant", 0)) == 0
	if controlled:
		controlled.set_ring(Game.C_SAFFRON)
	raider.set_ring(Game.C_SAFFRON if raider == controlled else Color(1, 1, 1, 0.65))
	hud.on_raid_setup()
	if _hints_shown < 2 and controlled:
		_hints_shown += 1
		hud.hint(tr("HINT_RAID") if controlled == raider else tr("HINT_DEFEND"))
	if raid.dod:
		hud.hint(tr("HINT_DOD"))


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
	if t == 0 and control_mode == "career":
		for a in pool:
			if a.is_career and a.is_raider_type():
				return a
	var cands := pool.filter(func(a): return a.is_raider_type())
	if cands.is_empty():
		cands = pool
	# Lean on the best raider but rotate a little.
	cands.sort_custom(func(x, y): return DB.overall(x.data) - x.raids_made * 3 > DB.overall(y.data) - y.raids_made * 3)
	if cands.size() > 1 and rng.randf() < 0.25:
		return cands[1]
	return cands[0]


func _walk_to_positions(dt: float, with_raider: bool) -> void:
	var raider_team_k := 0
	for t in 2:
		var k := 0
		for a in teams[t].players:
			if not a.on_mat:
				a.seek(bench_spot(t, teams[t].out_queue.find(a)), 3.0, dt)
				if a.vel.length() < 0.2:
					if a.state != "sit":
						a.set_state("sit")
					a.face_toward(Vector3.ZERO, dt)
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
				if a.state in ["idle", "walk", "celebrate", "sit"]:
					a.set_state("ready")
			k += 1


func _begin_raid() -> void:
	_set_phase("raid")
	raider.set_state("raid")
	Sfx.play("whistle", -4.0)
	arena.excite(0.3)
	hud.chant(true)


# ---------------------------------------------------------------- the raid

func _tick_raid(dt: float) -> void:
	raid.t -= dt
	clock = maxf(0.0, clock - dt * clock_speed)
	raid.ai_dodge_cd = maxf(0.0, raid.ai_dodge_cd - dt)
	_tick_cant(dt)
	if phase != "raid":
		return
	_tick_shouts(dt)
	var defs := defenders()
	var holders: Array = raid.holders

	# Raider movement.
	if raider.state in ["touch", "kick"] and raider.st_t >= raider.st_len:
		raider.set_state("raid")
	if raider.state == "dodge" and raider.st_t >= raider.st_len:
		raider.set_state("held" if holders.size() > 0 else "raid")
	if holders.size() > 0 and raider.state == "raid":
		raider.set_state("held")

	var move := Vector3.ZERO
	if raider == controlled:
		move = cam.input_to_world(controls.move_vec())
		if cam.mode == Game.CAM_FIRST:
			raider.lock_facing = true
			raider.facing = cam.flat_forward()
		else:
			raider.lock_facing = false
	else:
		raider.lock_facing = false
		move = _ai_raider(dt)
	_move_raider(move, dt)

	# Defenders.
	for d in defs:
		if d == controlled:
			_user_defender(d, dt)
		elif d.chain_partner != null and d.state in ["ready", "idle"]:
			_chained_follow(d, dt)
		else:
			_ai_defender(d, dt)
	_separate(defs, dt)
	for h in holders:
		h.position = raider.position + h.hold_offset
		h.vel = raider.vel
		h.face_toward(raider.position, dt, 20.0)

	_check_contacts(defs)
	_check_lines()
	_check_end(dt)


func _move_raider(move: Vector3, dt: float) -> void:
	var holders: Array = raid.holders
	var mid_dir := Vector3(0, 0, side(raiding))   # toward the raider's own half
	if raider.state == "dodge":
		raider.drive(raider.dive_dir * raider.max_speed * 1.9, dt)
	elif raider.state in ["touch", "kick"]:
		raider.drive(move * raider.max_speed * 0.35, dt)
	elif holders.size() > 0:
		# Struggle: push toward the midline against the holders.
		var hold_power := 0.0
		for h in holders:
			hold_power += h.tackle * (0.8 + 0.4 * float(h.data.attrs.strength) / 100.0)
		var push := maxf(0.0, move.dot(mid_dir))
		var net := raider.strength * raider.energy * push - hold_power * 0.85
		var v := mid_dir * net * 1.3
		if net < 0.0:
			v = mid_dir * net * 0.5
		v.x += move.x * 0.4 * maxf(0.2, 1.0 - hold_power)
		raider.vel = v
		raider.position += v * dt
		raider.face_toward(raider.position + mid_dir, dt)
		var rate := 0.22 + 0.42 * hold_power - 0.18 * raider.strength * push
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


func _separate(defs: Array, dt: float) -> void:
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
			cam.mode = (cam.mode + 1) % 3
			Game.settings.camera = cam.mode
			Game.save_settings()
			return
		"skip":
			if phase == "intro":
				_begin_setup()
			return
	if paused or phase != "raid" or controlled == null:
		return
	if controlled == raider:
		match id:
			"touch":
				_raider_touch(false)
			"kick":
				_raider_touch(true)
			"dodge", "tackle":
				_raider_dodge(Vector3.ZERO)
			"cant":
				_cant_tap()
	else:
		match id:
			"tackle", "dodge":
				_defender_tackle(controlled)
			"switch":
				_unchain(controlled)
				_switch_defender()
			"chain":
				_toggle_chain(controlled)


func set_paused(p: bool) -> void:
	paused = p
	hud.show_pause(p)
	get_tree().paused = false


func _raider_touch(toe: bool) -> void:
	if raider.state not in ["raid", "dodge"] or raider.cooldown > 0.0:
		return
	if depth_in(1 - raiding, raider.position) < -0.3:
		return
	# Aim assist: turn toward the nearest untouched defender within reach.
	var r := raider.reach + (0.45 if toe else 0.0) + 0.35
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
	raider.set_state("kick" if toe else "touch", KICK_TIME if toe else TOUCH_TIME)
	raider.cooldown = (KICK_TIME if toe else TOUCH_TIME) + 0.15
	raid.touch_hit = false
	Sfx.play("whoosh", -12.0, 1.3 if toe else 1.6)


func _raider_dodge(dir: Vector3) -> void:
	if raider.state in ["touch", "kick", "dodge"] or raider.cooldown > 0.0:
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


func _defender_tackle(d: Athlete) -> void:
	if d.state in ["dive", "recover", "holding", "telegraph"] or d.cooldown > 0.0:
		return
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
	d.chain_dive = false
	Sfx.play("whoosh", -8.0, 0.8)
	# A chained pair goes in together.
	var p: Athlete = d.chain_partner
	if p != null:
		_unchain(d)
		d.chain_dive = true
		if p.state in ["ready", "idle"] and p.position.distance_to(raider.position) < 3.0:
			_defender_tackle(p)
			p.chain_dive = true


func _switch_defender() -> void:
	var best: Athlete = null
	var bd := 1e9
	for a in defenders():
		if a == controlled or a.state == "holding":
			continue
		var d = a.position.distance_to(raider.position)
		if d < bd:
			bd = d
			best = a
	if best:
		if controlled:
			controlled.set_ring(Color(0, 0, 0, 0))
			controlled.is_user = false
		controlled = best
		controlled.is_user = true
		controlled.set_ring(Game.C_SAFFRON)
		Sfx.click()


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
				d.lock_facing = move.length() < 0.1
				if d.lock_facing:
					d.face_toward(raider.position, dt)
			d.drive(move * d.max_speed * (0.78 if d.chain_partner else 0.92), dt)
			if d.state not in ["ready", "idle"]:
				d.set_state("ready")
	# Stepping out before a struggle puts you out.
	var bound := Arena.HALF_W + (Arena.LOBBY if raid.struggle else 0.0)
	if d.state != "holding" and (absf(d.position.x) > bound + 0.2 or depth_in(d.team, d.position) > Arena.HALF_L + 0.2):
		_defender_out_of_bounds(d)
		return
	if depth_in(d.team, d.position) < 0.2:
		d.position.z = side(d.team) * 0.2


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
			_raider_dodge(Vector3(0, 0, side(raiding)))
		return Vector3(0, 0, side(raiding))

	# Threats: defenders winding up or diving nearby.
	var threat: Athlete = null
	var td := 1e9
	for d in defs:
		var dist = d.position.distance_to(raider.position)
		if d.state in ["telegraph", "dive"] and dist < 2.4 and dist < td:
			threat = d
			td = dist
	if threat and raid.ai_dodge_cd <= 0.0 and rng.randf() < clampf(skill * 0.85, 0.2, 0.95):
		raid.ai_dodge_cd = rng.randf_range(0.7, 1.4)
		var away := (raider.position - threat.position)
		away.y = 0
		var sidestep := away.normalized().cross(Vector3.UP) * (1.0 if rng.randf() < 0.5 else -1.0)
		var homeward := Vector3(0, 0, side(raiding))
		_raider_dodge((sidestep + homeward * 0.8 + away.normalized() * 0.5).normalized())

	var time_home := my_depth / raider.max_speed + 2.0
	var touched_n: int = raid.touched.size()
	var crowded := 0
	for d in defs:
		if d.position.distance_to(raider.position) < 1.7:
			crowded += 1
	if raid.ai_mode != "return":
		if raid.t < time_home + 1.5 or (touched_n > 0 and (crowded >= 2 or rng.randf() < dt * 1.2)) or (touched_n >= 2) or (raid.bonus and rng.randf() < dt * 2.0):
			raid.ai_mode = "return"

	var target: Vector3
	var speed := 0.75
	match raid.ai_mode:
		"approach":
			var lane: float = raid.ai_lane + sin(raid.t * 2.2) * 0.8
			target = pos_in(opp, lane * side(opp), 2.6)
			if my_depth > 2.2:
				raid.ai_mode = "baulk" if not raid.baulk else "probe"
				raid.ai_bonus = defs.size() >= 6 and rng.randf() < 0.35
		"baulk":
			# Cross the baulk line through the widest gap in the chain.
			target = pos_in(opp, _gap_x(defs, opp), Arena.BAULK + 0.35)
			if raid.baulk:
				raid.ai_mode = "bonus" if raid.ai_bonus else "probe"
		"bonus":
			var bx := 4.3 if raider.position.x * side(opp) > 0.0 else -4.3
			target = pos_in(opp, bx, Arena.BONUS + 0.35)
			speed = 0.95
			if raid.bonus or raid.t < 14.0:
				raid.ai_mode = "probe"
		"probe":
			var mark := _ai_mark(defs)
			if mark:
				var to := mark.position - raider.position
				to.y = 0
				var dist := to.length()
				# Hover just outside reach from the midline side, then strike.
				var stand := mark.position + Vector3(0, 0, side(raiding)) * 1.1 + to.normalized().cross(Vector3.UP) * sin(raid.t * 3.0) * 0.6
				target = stand
				if dist < raider.reach + 0.55 and raider.cooldown <= 0.0 and mark.state not in ["telegraph", "dive"] and rng.randf() < dt * (2.0 + skill * 3.0):
					raider.facing = to.normalized()
					_raider_touch(dist > raider.reach + 0.15)
			else:
				target = home
		_:
			target = home
			speed = 1.0
	# Steer around defenders on the way. Going in, only sidestep (never back off over
	# the midline); coming home, steer freely.
	var steer := Vector3.ZERO
	for d in defs:
		var off: Vector3 = raider.position - d.position
		off.y = 0
		var l := off.length()
		if l < 1.6 and l > 0.01 and raid.ai_mode != "probe":
			steer += off / l * (1.6 - l) * 1.2
	if raid.ai_mode != "return":
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
			_clamp_defender(d)
			return
		"recover":
			d.drive(Vector3.ZERO, dt)
			if d.st_t >= d.st_len:
				d.set_state("ready")
			return
		"holding":
			return
	var inside = raid.entered and opp_depth > 0.0
	var alarm: bool = raid.alarm or (inside and opp_depth > Arena.BAULK + 0.2)
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
	d.seek(target, spd, dt)
	d.face_toward(raider.position, dt)
	if d.state not in ["ready"]:
		d.set_state("ready")
	_clamp_defender(d)

	# Neighbours link hands while the raider is in their half.
	if inside and not alarm and d.chain_partner == null and rng.randf() < dt * 0.6:
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
	var engaging := 0
	for o in defenders():
		if o.state in ["telegraph", "dive"]:
			engaging += 1
	var max_engage := 2 if alarm else 1
	if engaging >= max_engage:
		return
	var rng_range := 1.45 + 0.3 * react
	if dist > rng_range:
		return
	var p := 0.55 * diff * (0.6 + d.tackle)
	var heading_home := raider.vel.dot(Vector3(0, 0, -side(d.team))) > 1.0
	if heading_home:
		p *= 2.2
	if raider.state in ["touch", "kick"]:
		p *= 2.0
	if alarm:
		p *= 1.6
	if d.touched:
		p *= 1.5
	if rng.randf() < p * dt:
		d.set_state("telegraph", float(prof.telegraph))
		d.cooldown = 0.2


# ---------------------------------------------------------------- contacts and lines

func _check_contacts(defs: Array) -> void:
	var opp := 1 - raiding
	var in_half := depth_in(opp, raider.position) > -0.1
	for d in defs:
		if d.state == "holding":
			continue
		var dist = d.position.distance_to(raider.position)
		# Raider's touches.
		if in_half and not d.touched:
			var hit = dist < 0.55
			if raider.state in ["touch", "kick"]:
				var p := raider.st_t / maxf(raider.st_len, 0.01)
				var active := p > 0.2 and p < 0.75
				var r := raider.reach + 0.35 + (0.45 if raider.state == "kick" else 0.0)
				var ang := raider.facing.angle_to((d.position - raider.position).normalized())
				if active and dist < r and ang < 1.2:
					hit = true
			if hit:
				_touch(d)
				# A defender touched while set may grab straight back.
				if d != controlled and d.state in ["ready", "telegraph"] and raider.state != "dodge" and not bool(config.get("passive", false)):
					var counter = 0.16 + 0.25 * d.tackle + 0.08 * float(prof.tackle)
					if d.state == "telegraph":
						counter += 0.3
					if rng.randf() < counter:
						_attach(d)
						continue
		# Tackles.
		if d.state == "dive" and dist < 0.8:
			if raider.state == "dodge" and rng.randf() < 0.75 * raider.agility:
				continue
			var hold_chance = 0.55 + 0.35 * d.tackle - 0.25 * (raider.agility - 1.0)
			var behind := raider.facing.dot((d.position - raider.position).normalized()) < -0.2
			if behind:
				hold_chance += 0.2
			if d.chain_dive:
				hold_chance += 0.2
			if d == controlled:
				hold_chance *= float(prof.user_hold)
			if rng.randf() < hold_chance:
				_attach(d)
			else:
				d.set_state("recover", 1.0)
		elif raid.holders.size() > 0 and d.state in ["ready", "idle"] and dist < 0.85 and d != controlled:
			_attach(d)
		elif raid.holders.size() > 0 and d == controlled and dist < 0.75 and d.state != "recover":
			_attach(d)


func _touch(d: Athlete) -> void:
	d.touched = true
	raid.touched.append(d)
	raid.alarm = true
	d.set_ring(Color(Game.C_SAFFRON, 0.9))
	Sfx.play("slap", -2.0)
	if raider == controlled:
		tutorial_event.emit("touch")
		if raider.state == "kick":
			tutorial_event.emit("toe_touch")
	hud.float_points(d, "+1")
	arena.excite(0.5)
	Game.vibrate(25)


func _attach(d: Athlete) -> void:
	if raid.holders.has(d):
		return
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
	var chained := d.chain_dive and not first
	hud.event(tr("EV_CHAIN") if (chained or not first) else tr("EV_HOLD"), Game.C_MAGENTA)
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
	if not raid.bonus and dep > Arena.BONUS and on_mat(opp).size() >= 6 and raid.holders.is_empty():
		raid.bonus = true
		hud.event(tr("EV_BONUS"), Game.C_GOLD)
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
	if holders.size() >= 3 and raid.progress > 0.25:
		_end_raid("tackle")
		return
	if raid.progress >= 1.0:
		_end_raid("tackle")
		return
	if raid.t <= 0.0:
		_end_raid("time")


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
		"out_of_bounds":
			raider_out = true
			def_pts = 1
			raid_pts = bonus
			msg = tr("EV_OUT_OF_BOUNDS")
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
	if raid_pts > 0 or def_pts > 0:
		tm_atk.empty = 0
	elif kind == "return" and not raider_out:
		pass
	if raider_out:
		tm_atk.empty = 0

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

	raid_log.append({"kind": kind, "raider_out": raider_out, "raid_pts": raid_pts, "def_pts": def_pts, "touches": touched.size(), "bonus": bonus, "t": RAID_TIME - float(raid.t)})
	_post_messages = [[msg, col]]
	# All outs.
	for t in 2:
		if on_mat(t).is_empty():
			var other := 1 - t
			teams[other].score += 2
			teams[other].pts.allout += 2
			_post_messages.append([tr("EV_ALL_OUT"), Game.C_GOLD])
			for a in teams[t].players:
				if not a.on_mat:
					a.on_mat = true
					a.set_state("walk")
			teams[t].out_queue.clear()
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
		Sfx.play("roar", -6.0 if good_for_user else -12.0)
	Sfx.play("whistle", -6.0)
	for m in _post_messages:
		hud.event(m[0], m[1])
	if raid_pts + def_pts > 0:
		hud.event(tr("EV_POINTS").format({"n": raid_pts + def_pts}), Game.C_INK, true)
	clock = maxf(0.0, clock - RAID_GAP * clock_speed)


## Players react: roars, slumps, appeals to the referee, the odd shove.
func _react(kind: String, raid_pts: int, def_pts: int, raider_out: bool, touched: Array, holders_were: Array) -> void:
	var atk: int = raiding
	var dfn := 1 - raiding
	if raid_pts > 0 and not raider_out:
		raider.set_state("roar")
		hud.bubble(raider, tr("BUBBLE_HAAN") if rng.randf() < 0.5 else tr("BUBBLE_AAJA"), Game.C_GOLD)
		Sfx.yell("haan" if rng.randf() < 0.5 else "aaja", -2.0)
		for a in on_mat(atk):
			if a != raider and a.state in ["idle", "ready"]:
				a.set_state("celebrate")
		for d in touched:
			d.set_state("slump")
		# Sometimes the defence disputes the touch.
		var mates := on_mat(dfn)
		if not mates.is_empty() and rng.randf() < 0.35:
			var who: Athlete = mates[rng.randi() % mates.size()]
			who.set_state("argue")
			who.face_toward(Vector3(Arena.HALF_W + 3.0, 0, 0), 1.0, 100.0)
			hud.bubble(who, tr("BUBBLE_NO_TOUCH"), Game.C_INK)
			Sfx.yell("nahi", -6.0)
	elif def_pts > 0:
		var stars: Array = holders_were if not holders_were.is_empty() else on_mat(dfn)
		for d in on_mat(dfn):
			d.set_state("roar" if stars.has(d) else "celebrate")
		if not stars.is_empty():
			var lead: Athlete = stars[0]
			hud.bubble(lead, tr("BUBBLE_SHABASH"), Game.C_MAGENTA.lightened(0.3))
			Sfx.yell("shabash", -3.0)
		if kind == "tackle" and not holders_were.is_empty() and rng.randf() < 0.35:
			# A shove as the raider gets up; he claims he got a touch.
			var pusher: Athlete = holders_were[rng.randi() % holders_were.size()]
			pusher.set_state("shove")
			pusher.shove_target = raider
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
	var in_half := depth_in(1 - raiding, raider.position) > 0.0
	if raid.cant_tap:
		if in_half:
			raid.breath = maxf(0.0, raid.breath - float(prof.breath_drain) * dt)
			if raid.breath <= 0.0:
				_end_raid("cant")
	else:
		# AI raiders, and auto-cant mode, keep the chant going on their own.
		raid.chant_t -= dt
		if raid.chant_t <= 0.0:
			raid.chant_t = 0.42
			Sfx.chant_word(-9.0 if raider == controlled else -15.0)


func _cant_tap() -> void:
	if not raid.cant_tap:
		return
	var b := int(round(raid.beat_t / BEAT))
	var d := absf(raid.beat_t - b * BEAT)
	var w: float = float(prof.cant_window)
	var gain := 0.0
	var kind := ""
	if b == int(raid.last_beat):
		gain = -0.05
		kind = "fast"
	elif d < w * 0.6:
		gain = 0.16
		kind = "perfect"
	elif d < w:
		gain = 0.08
		kind = "good"
	else:
		gain = -0.05
		kind = "off"
	raid.last_beat = b
	raid.breath = clampf(raid.breath + gain, 0.0, 1.0)
	if gain > 0.0:
		Sfx.chant_word(-3.0)
		tutorial_event.emit("cant")
	hud.cant_feedback(kind)


# ---------------------------------------------------------------- chains

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
	d.seek(lead.position + d.chain_offset, d.max_speed, dt, 0.3)
	d.face_toward(raider.position, dt)
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
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
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
		(mi.material_override as StandardMaterial3D).albedo_color = Game.C_SAFFRON if user_pair else Color(1, 1, 1, 0.9)


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
		if a.state == "celebrate":
			a.drive(Vector3.ZERO, dt)
		elif a.state in ["walk", "sit"] or not a.on_mat:
			pass
		else:
			a.drive(Vector3.ZERO, dt)
	if phase_t > 1.0:
		_walk_to_positions(dt, false)
	if phase_t > 2.6:
		_next_raid()


func _next_raid() -> void:
	for a in athletes:
		if a.state in ["celebrate", "roar", "slump", "shove", "argue", "slap"]:
			a.set_state("idle")
	if tutorial:
		raiding = tutorial.next_raiding_team(raiding)
		_begin_setup()
		return
	if golden:
		golden_raids += 1
		if golden_raids % 2 == 0 and teams[0].score != teams[1].score:
			_end_match()
			return
	elif clock <= 0.0:
		if half == 1:
			_set_phase("halftime")
			hud.banner(tr("HALF_TIME"))
			Sfx.play("buzzer", -4.0)
			return
		if teams[0].score == teams[1].score and bool(config.get("knockout", false)):
			golden = true
			golden_raids = 0
			hud.banner(tr("HUD_DOD"))
		else:
			_end_match()
			return
	raiding = 1 - raiding
	_begin_setup()


func _end_match() -> void:
	_set_phase("fulltime")
	Sfx.play("buzzer", -2.0)
	Sfx.drums(false)
	var w := _winner()
	hud.banner(tr("FULL_TIME"))
	arena.excite(1.0)
	if w >= 0:
		for a in teams[w].players:
			a.on_mat = true
			a.set_state("celebrate")


func _winner() -> int:
	if teams[0].score > teams[1].score:
		return 0
	if teams[1].score > teams[0].score:
		return 1
	return -1


func _tick_celebrate(dt: float) -> void:
	for a in athletes:
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
	var result := {
		"config": config,
		"home": teams[0].id,
		"away": teams[1].id,
		"score": [teams[0].score, teams[1].score],
		"breakdown": [teams[0].pts.duplicate(), teams[1].pts.duplicate()],
		"winner": _winner(),
		"mvp": {"pid": best_pid, "name": best_name, "team": teams[best_team].id, "pts": best_pts},
		"career_stats": career_stats,
		"raid_log": raid_log,
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
