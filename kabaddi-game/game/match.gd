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
signal game_event(kind: String, info: Dictionary)   # see _event

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
const SETUP_WAIT := 9.0       # s the next raid waits at most for players put out to reach the sitting block
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
const JUMP_GATHER := 0.18      # s a held raider gathers himself on his free leg before a lion jump out of the hold
const LOST_GRIP := 0.3         # s a holder lies reaching after a leg torn out of his hands before he gets up
const SHOVE_TIME := 0.42
const DIVE_TIME := 0.3
const DIVE_PUSH := 0.13        # s a dive drives off the floor for, from the speed he had ...
const DIVE_LAUNCH := 4.0       # ... to this (m/s), out of his wind-up (the defence's own dives) ...
const DIVE_LAUNCH_NOW := 5.0   # ... or this, made at once (the player's, at the button): each the reach it always had
const DIVE_LAND := 1.5         # ... and has this much left as he lands (no long slide on the floor)
const ARMS_OUT_AFTER := 0.15   # s a landed ankle dive can still grip, arms out
const LUNGE := 0.45            # how much further a lunge's touch reaches, stepping in as it goes (defenders' evades)
const STRIKE_REACH := {"touch": 0.9, "kick": 0.9, "backkick": 0.75}  # m centre to centre a hand or foot steered at a
                               # defender surely gets to him from without a step (stood still, it lands from up to 1.0,
                               # 1.1 and 1.0 m)
const STRIKE_STEP := 0.5       # a touch or kick steps in at him at up to this share of his top speed ...
const LUNGE_STEP := 0.95       # ... and a lunge (the AI's strike from further off) at nearly a sprint (_strike_vel)
const TOUCH_GAP := 0.05        # m: a hand or foot this near a defender's body (past its thickness) touches him
const LIE_TIME := 0.9          # s a tackled raider stays down once he hits the floor
const COUNTER_REACT := 0.18    # s a touched defender takes to grab back ...
const COUNTER_STEP := 0.5      # ... with a step in toward him (m)
const GETUP_RAIDER := 1.4      # s he takes to get up (the get-up clips' own pace)
const GETUP_HOLDER := 1.2      # s a holder lying on the floor takes to get up after a takedown ...
const RISE_KNEES := 0.75       # ... one down on his knees or crouched over a leg, to come up off them ...
const RISE_BENT := 0.4         # ... and one still on his feet, bent over the raider, to straighten up
const RISE_SLIPPED := 0.55     # s a holder whose arms a dubki slipped takes to straighten up from his lunge
const SEPARATE := 0.6          # m between two players' middles (along the floor) who do not hold one another ...
const NUDGE := 3.0             # ... kept apart no faster than this (m/s): out of each other's way, not put there ...
const NUDGE_ACCEL := 15.0      # ... and getting up to that speed, or off it, no quicker (m/s²): eased aside, not knocked
const SEPARATE_LOOK := 0.2     # s ahead keeping apart looks, at how players are going: aside before they meet, not after
const AVOID_TIME := 0.15       # s a player steering round another means to be clear of him in
const APART_HYST := 0.08       # m further apart than the gap players kept apart last frame are kept apart to (_gap)
const SHUFFLE := 0.6           # m/s a player getting up off the floor shuffles out from under another body at, at most
const BODY_GAP := 0.4          # m kept between a body on the floor, getting up or bent into a hold (its trunk, _trunk)
                               # and anyone else's: lying, a body is a body's length along the floor, not a point
const DOWN_STATES := ["holding", "dive", "recover", "rise", "fallen"]   # on the floor, or in the grapple: not pushed
const WATCH_HOLD := 0.4        # s the raider keeps watching the defender he chose (or not watching), at least
const CHAIN_LAG := 0.08        # s after the lead of a chained pair goes that the partner goes, at least ...
const CHAIN_LAG_SPREAD := 0.1  # ... and up to this much later, each partner his own
const HELD_TURN := 1.5         # rad/s a raider held other than by the ankle turns toward home at most
const SPRING := 35.0           # m/s² a lion jump out of a hold drives off the free leg at, up to the spring's speed
const EVADE_REACH := 1.4       # m an evading defender can cover (_evade: 0.34 s from a standstill), and a little more
const PLANT := 38.0            # m/s² a raider sheds a dubki's or a jump's burst at, landing and planting ...
const PLANT_TIME := 0.15       # ... over this long, then runs on as usual
# Down, getting up, or in the middle of a move: a reaction to the end of the raid waits until he is up or down from it
# (_react_as). Cutting in would snap him from the floor, or out of the air, to his feet in a frame.
const BUSY := ["fallen", "holding", "recover", "rise", "dive", "jump", "dubki", "dodge", "kick", "backkick", "touch",
	"shoved", "evade"]

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
var _push_want := {}           # Athlete -> how far keeping players apart would move him this frame (_push_all)
var _kept := {}               # pairs kept apart last frame (_gap) ...
var _kept_now := {}           # ... and this frame
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
# Lab (tests/tackle_check): a scripted raid. The raider moves as lab_move says and makes only the moves he is
# told to; defenders keep their place and go in only when told (with lab_force.help, team-mates come to help
# once he is held); lab_force settles a chance ("hold", "escape", "pile") one way or the other so a scenario plays
# out the same every time. Contact itself is never forced.
var lab := false
var lab_move := Vector3.ZERO
var lab_force := {}
# Tests (tests/motion_audit): called with the name of each stage of the raid's frame that moves players, as it ends.
var audit := Callable()
var grapple: Grapple = null   # the raider in defenders' hands (see Grapple)
var defence: DefenceCoach      # the defending team's roles and places (see DefenceCoach)
var event_log: Array = []      # the last gameplay events: [match seconds, raid number, kind, info]
var _event_n := 0
var crowd_lift := 0.0          # a derby or a final: the crowd louder all match
var walkout := false           # a final: the teams walk out and line up across the midline before the start
const WALKOUT_HOLD := 3.6      # ... standing in line this long
const WALKOUT_LEN := 7.0       # ... and the intro this long in all


func _ready() -> void:
	# A seed in the config plays the same match every time (tests); otherwise each match is its own.
	if config.has("seed"):
		rng.seed = int(config.seed)
	else:
		rng.randomize()
	difficulty = clampi(int(config.get("difficulty", Game.settings.difficulty)), 0, PROFILES.size() - 1)
	prof = PROFILES[difficulty]
	raid_rule = int(config.get("raid_rule", Game.settings.get("raid_rule", RULE_CANT_AUTO)))
	half_len = HALF_LEN
	clock_speed = CLOCK_SPEEDS[clampi(int(config.get("length", Game.settings.length)), 0, 2)]
	attract = bool(config.get("attract", false))
	lab = bool(config.get("lab", false))
	walkout = bool(config.get("walkout", false)) and not attract
	crowd_lift = 0.25 if walkout else (0.15 if String(config.get("derby", "")) != "" else 0.0)
	defence = DefenceCoach.new(self)
	if bool(config.get("debug_draw", false)):
		add_child(DebugDraw.new(self))
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
		# The seven picked for the match (League Season), else the best seven.
		var seven: Array = (config.get("home_seven" if t == 0 else "away_seven", []) as Array).duplicate()
		if seven.is_empty():
			seven = DB.starting_seven(squad.duplicate())
		var fit_map: Dictionary = config.get("fitness", {})
		var limit: Array = config.get("players", [7, 7])
		seven = seven.slice(0, int(limit[t]))
		if t == 0 and cp is Dictionary:
			seven = _insert_career_player(seven, cp)
		var on_show: Array = RiggedBody.featured() if bool(config.get("featured", false)) else []
		for i in seven.size():
			var a := Athlete.new()
			if i < on_show.size() and String(seven[i].get("body", "")) == "":
				a.body_file = on_show[i]   # the bodies on show (bodies.json "featured"), on each side's first players
			a.setup(seven[i], t, tm.kit, tm.trim, arena.barefoot)
			if String(config.get("style", "")) != "":
				a.style = String(config.style)
				# His own copy: the ratings are the player's, and a lesson's tackle must not carry into later matches.
				a.dmoves = a.dmoves.duplicate()
				a.dmoves[a.style] = 90
			a.slot = i
			a.is_career = (String(seven[i].id) == career_pid)
			if fit_map.has(a.pid()):
				a.energy = clampf(float(fit_map[a.pid()]), 0.5, 1.0)   # tired from earlier matches
			add_child(a)
			tm.players.append(a)
			athletes.append(a)
			stats[a.pid()] = {"raid": 0, "tackle": 0}
	_order_slots()
	officials = Officials.new()
	add_child(officials)
	officials.setup(self)
	_floor_shadows()

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
	Sfx.crowd(0.35 + crowd_lift)
	Sfx.drums(true)
	_set_phase("intro")
	if walkout:
		arena.excite(1.0)
		Sfx.play("roar", -4.0)
	if not attract:
		var occasion := ""
		if walkout:
			occasion = tr("THE_FINAL")
		elif String(config.get("derby", "")) != "":
			occasion = tr(String(config.derby))
		hud.show_intro(DB.team_name(teams[0].id), DB.team_name(teams[1].id), tr(_arena_name()), occasion,
			[teams[0].id, teams[1].id] if walkout else [])


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
## As in match footage (tools/mocap/footage): the line stands 4.4-4.9 m from the midline, a metre
## behind the baulk line, so a raider has to come in to touch it; three defenders still cover
## most of the width.
func formation_spot(a: Athlete) -> Vector3:
	var t := a.team
	var mates := on_mat(t)
	mates.sort_custom(func(x, y): return x.slot < y.slot)
	var n := mates.size()
	var i := mates.find(a)
	var width := minf(4.2, 1.3 * (n - 1))
	var lat := 0.0 if n <= 1 else lerpf(-width, width, float(i) / (n - 1))
	var d := 4.35 + 0.35 * (absf(lat) / 4.2)
	# Each player's own place in it: a little deeper or shallower, a little to one side (people do not stand
	# on a ruled line).
	var k := float(hash(a.pid()) % 1000) / 1000.0
	var k2 := float(hash(a.pid() + "x") % 1000) / 1000.0
	return pos_in(t, lat + 0.2 * (k2 * 2.0 - 1.0), d + 0.45 * (k * 2.0 - 1.0))


## Every player put out has reached his place in the sitting block, or nearly.
func _outs_off() -> bool:
	for t in 2:
		for a in teams[t].players:
			if a.on_mat or a.state == "sit":
				continue
			var spot := bench_spot(t, teams[t].out_queue.find(a))
			if Vector2(a.position.x - spot.x, a.position.z - spot.z).length() > 1.5:
				return false
	return true


func bench_spot(t: int, k: int) -> Vector3:
	return Vector3(-3.5 + k * 1.0, 0, side(t) * (Arena.HALF_L + 2.5))


func _place_all_instant() -> void:
	for t in 2:
		var ps: Array = teams[t].players
		for a in ps:
			if walkout:
				# The final: both teams in a line along the midline's side of their halves, facing the main stand.
				a.position = Vector3(1.6, 0, side(t) * (0.8 + ps.find(a) * 0.85))
				a.facing = Vector3(1, 0, 0)
			else:
				a.position = formation_spot(a)
				a.facing = Vector3(0, 0, -side(t))


## The walk-out: the teams stand in their lines, facing the cameras and the crowd, before going to their places.
func _stand_lined_up(dt: float) -> void:
	for a in athletes:
		a.drive(Vector3.ZERO, dt)
		a.face_toward(a.position + Vector3(4, 0, 0), dt)


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
			if walkout and phase_t < WALKOUT_HOLD:
				_stand_lined_up(dt)
			else:
				_walk_to_positions(dt, false)
			if phase_t > (WALKOUT_LEN if walkout else 3.0):
				_begin_setup()
		"setup":
			_walk_to_positions(dt, true)
			# The next raid waits for anyone put out in the last to be off to the sitting block (it began with a
			# tackled raider still walking off across the court), or for long enough.
			if phase_t > 2.2 and (_outs_off() or phase_t > SETUP_WAIT):
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
	if phase not in ["raid", "post"]:
		_push_all(dt)   # no one is kept apart now: whoever was still being moved aside eases off
	_update_chain_links()
	cam.follow(self, dt)
	hud.refresh()


func _begin_setup() -> void:
	_set_phase("setup")
	if grapple:
		grapple.clear()
		grapple = null
	defence.reset()
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
			# The raiding side waits idle in its own half, the defence is ready (_walk_to_positions): straight there. (All
			# put idle here, the defence was put ready again the next frame, each player's stance started twice.)
			var want := "idle" if a.team == raiding else "ready"
			if a.state != want:
				a.set_state(want)
		elif not a.on_mat and a.state in BUSY:
			a.set_state("walk")   # out, and still down or in a move as the next raid is set up: off he goes
	# He walks to the start spot through the setup (_walk_to_positions); only from far off is he put there.
	if raider.position.distance_to(pos_in(raiding, 0.0, 1.4)) > 7.0:
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
	if lab:
		raid.t = 999.0
		raid.air_max = 999.0
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
		hud.event("%s · %s: %s" % [raider.display_name(), tr("SIGNATURE"), tr(DB.MOVE_KEYS[sig])], Game.C_MUTED, true, MatchHud.EV_INFO)


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
			if a.state == "holding":
				continue   # the grapple moves him, letting go (driving him as well moved him twice a frame)
			if a.state in ["recover", "rise", "fallen"]:
				a.drive(Vector3.ZERO, dt)   # getting up first
				continue
			if a.state == "celebrate" and a.cele_partner != null:
				continue   # jogging over to slap hands (_tick_post): not walked back at the same time as well
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
	if not raid.holders.is_empty():
		raid["hold_age"] = float(raid.get("hold_age", 0.0)) + dt
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
	Sfx.crowd(0.3 + crowd_lift + 0.35 * tension + (0.35 if raid.struggle and not raid.holders.is_empty() else 0.0))
	var defs := defenders()
	var holders: Array = raid.holders

	# Raider movement.
	if raider.state in ["touch", "kick", "backkick", "shoved"] and raider.st_t >= raider.st_len:
		raider.set_state("raid")
	if raider.state in ["dubki", "jump"] and raider.st_t >= raider.st_len:
		# Land and plant: the burst does not carry on. He sheds it over a step (_move_raider), not in a frame.
		raid["plant"] = raider.vel * 0.35
	if raider.state in ["dodge", "dubki", "jump"] and raider.st_t >= raider.st_len:
		raider.set_state("held" if holders.size() > 0 else "raid")
	if holders.size() > 0 and raider.state == "raid":
		raider.set_state("held")
	raider.held_by = holders.size()
	_tick_escape(dt)

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
		move = lab_move if lab else _ai_raider(dt)
	_audit("start")
	_move_raider(move, dt)
	if watch != null and not (raider == controlled and cam.mode == Game.CAM_FIRST):
		raider.face_toward(watch.position, dt, 9.0)
	_audit("raider")

	# Defenders: the team's plan first, then each one at it.
	_chain_follow()
	defence.update(dt)
	for d in defs:
		if d == controlled:
			_user_defender(d, dt)
		elif d.chain_partner != null and d.state in ["ready", "idle"]:
			_chained_follow(d, dt)
		else:
			_ai_defender(d, dt)
	_audit("defence")
	_separate(defs)
	_push_all(dt)
	_audit("apart")
	# Inside the court after being moved aside as well: a push past the line was pulled back only on his next step, in
	# one frame, and if that step was a dive's first, a lurch sideways as he left the floor.
	for d in defs:
		if d.state not in DOWN_STATES:
			_clamp_defender(d)
	_tick_bystanders(dt)
	_audit("court")
	if grapple:
		grapple.update(dt)
	_audit("grapple")
	for h in holders:
		_tire(h, 0.02 * dt)
		if grapple and grapple.has(h):
			continue   # placed by the grapple, his hands on the part he holds
		# A new holder closes in to arm's length over a few frames rather than appearing there.
		h.hold_offset = h.hold_offset.move_toward(h.hold_offset.normalized() * 0.55, 3.0 * dt)
		h.position = raider.position + h.hold_offset
		h.vel = raider.vel
		h.face_toward(raider.position, dt, 20.0)
	_audit("attach")

	_aim_limb()
	_check_contacts(defs)
	if phase == "raid":
		_check_chain_cross()
	_check_lines()
	_check_end(dt)
	_audit("contacts")


func _audit(stage: String) -> void:
	if audit.is_valid():
		audit.call(stage)


func _move_raider(move: Vector3, dt: float) -> void:
	var holders: Array = raid.holders
	var mid_dir := Vector3(0, 0, side(raiding))   # toward the raider's own half
	if raider.state == "dodge" and holders.is_empty():
		raider.drive(raider.dive_dir * raider.max_speed * 1.9, dt)
	elif raider.state == "shoved":
		raider.drive(raider.dive_dir * raid.get("shove_speed", 4.0) + move * 0.8, dt)
	elif raider.state == "dubki" and holders.is_empty():
		raider.drive(raider.dive_dir * raider.max_speed * 1.5, dt)
	elif raider.state == "jump" and holders.is_empty():
		if raider.wait > 0.0:
			# Sprung out of a hold: he drives off the free leg up to the spring's speed (_tick_escape) over his first
			# frames off the floor rather than having it in one, and in the air it stays.
			raider.vel = raider.vel.move_toward(raid.get("spring", raider.vel), SPRING * dt)
			raider.position += raider.vel * dt
			raider.face_toward(raider.position + raider.vel, dt, 10.0)
		else:
			raider.drive(raider.dive_dir * _jump_speed(), dt)
	elif raider.state in ["touch", "kick", "backkick"]:
		raider.drive(_strike_vel(move), dt)
	elif holders.size() > 0:
		# Struggle: push toward the midline against the holders.
		var hold_power := 0.0
		for h in holders:
			# A waist hold lifts him off his feet; a block or thigh hold pins him.
			var grip: float = {"waist": 1.35, "thigh": 1.1, "block": 1.15, "chain": 1.1}.get(h.kind(), 1.0)
			hold_power += h.tackle * grip * (0.8 + 0.4 * float(h.data.attrs.strength) / 100.0)
		var push := maxf(0.0, move.dot(mid_dir))
		# Where he is trying to go and how hard, against how hard they hold him: the grapple works its ankle holds
		# and his footwork with these.
		if grapple:
			grapple.want = move.limit_length(1.0)
			grapple.force = raider.strength * raider.energy * 1.4
			grapple.resist = hold_power * 0.5
		# Every haul (Grapple) pulls him back a little, and that is when his balance goes: over a whole haul the
		# pace is the same, but it comes in heaves rather than evenly.
		var pace := 1.0
		if grapple and not grapple.holds.is_empty():
			pace = 0.4 + 1.2 * grapple.tug_mean()
		if grapple and grapple.footwork():
			# One leg held (at the ankle or the thigh): he hops on his free foot against the held leg, and the grapple
			# moves him (Grapple._footwork). He faces between where he is trying to go and away from the hold, the held
			# leg out behind him, turning as he hops (on the spot he would drag his planted foot round).
			if grapple.turn:
				var go := (move if move.length() > 0.2 else mid_dir).normalized()
				var away := grapple.away_from_hold()
				var to := raider.position + (go + away).normalized() if (go + away).length() > 0.1 else raider.position + go
				if grapple.held_round():
					raider.turn_toward(to, dt, HELD_TURN)   # arms round his middle too: they swing round with him
				else:
					raider.face_toward(to, dt, 7.0)
		elif grapple and grapple.pinned():
			# Both legs held: he cannot take a step, nor turn on the spot. He stays where he is and fights the holds
			# with his trunk (the struggle goes on, below). He used to be slid along by it, legs and all.
			raider.vel = Vector3.ZERO
		else:
			# One defender can be dragged to the line; two or three usually win.
			var net := raider.strength * raider.energy * push * 1.4 - hold_power * 0.5
			var v := mid_dir * net * 1.3
			if net < 0.0:
				v = mid_dir * net * 0.5
			else:
				# The hit stops him dead; he gets going again about a second later, while help runs in.
				v *= clampf(float(raid.get("hold_age", 0.0)) / 1.0, 0.2, 1.0)
			v.x += move.x * 0.4 * maxf(0.2, 1.0 - hold_power)
			if grapple and not grapple.holds.is_empty():
				v -= mid_dir * grapple.tug_total() * 0.6
				# Held only round the middle: he steps that ground, a foot at a time (Grapple._steps), rather than being
				# slid over it, and turns only as he steps: no faster than the holds let him (his holders round his
				# middle swing round with him: Grapple.update).
				grapple.drive_vel = v
				if grapple.turn:
					raider.turn_toward(raider.position + mid_dir, dt, HELD_TURN * 0.5)   # pivoting on the planted foot
			else:
				raider.vel = v
				raider.position += v * dt
				raider.turn_toward(raider.position + mid_dir, dt, HELD_TURN)
		if rng.randf() < dt * 1.4:
			var who: Athlete = raider if rng.randf() < 0.55 else holders[rng.randi() % holders.size()]
			Sfx.voice("grunt", -7.0 if who == raider else -10.0, who.voice_pitch())
		var rate := 0.16 + 0.32 * hold_power - 0.2 * raider.strength * push
		raid.progress = clampf(raid.progress + maxf(0.05, rate) * pace * dt, 0.0, 1.0)
		if grapple:
			grapple.progress = raid.progress
	elif raid.has("plant") and raider.state == "raid" and raider.st_t < PLANT_TIME:
		raider.drive(raid.plant, dt, PLANT)   # planting out of a dubki or a jump
	else:
		raid.erase("plant")
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
## Whom the raider watches as he works the cover (he faces him), or null (he faces where he runs). What he chooses is
## kept for WATCH_HOLD at least: chosen afresh each frame, two defenders about as near, or running at one and then not,
## threw his eyes and shoulders from one to the other and to where he ran, and back, frame by frame (tests/motion_audit).
## Not free to look about (in a move, held) or the one he watches out of reach or down, it changes at once.
func _raider_watch() -> Athlete:
	if raider.state != "raid" or not raid.holders.is_empty():
		raid.erase("watch")
		return null
	var want := _watch_pick()
	var cur: Array = raid.get("watch", [])
	if cur.is_empty() or want == cur[0] or phase_t - float(cur[1]) >= WATCH_HOLD:
		if cur.is_empty() or want != cur[0]:
			raid["watch"] = [want, phase_t]
		return want
	var keep = cur[0]
	if keep != null and (not is_instance_valid(keep) or keep.state in DOWN_STATES \
			or Vector2(keep.position.x - raider.position.x, keep.position.z - raider.position.z).length() > 3.4):
		raid["watch"] = [want, phase_t]
		return want
	return keep


func _watch_pick() -> Athlete:
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
	# Put out while down or in the middle of a move, he finishes it where he is first: a dive lands and he gets up, a
	# move runs its course (_after_getup). Then he walks off.
	if a.state == "dive" and a.st_t >= a.st_len:
		_land(a, 0.9)
	elif a.state in BUSY and a.state not in ["fallen", "holding", "dive"] and a.st_len > 0.0 and a.st_t >= a.st_len:
		_after_getup(a)
	if a.state in BUSY or a.state in ["roar", "slump", "argue", "shove", "celebrate"] or a.has_meta("walk_at"):
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
	if a.state != "walk":
		a.set_state("walk")
	a.seek(spot, 3.3 if phase == "setup" and off.length() > 3.0 else 2.6, dt, 0.5)   # a jog when the next raid waits
	if off.length() < 0.2:
		a.vel = Vector3.ZERO
		a.set_state("sit")


func _separate(defs: Array) -> void:
	# Defenders give the raider room rather than bumping into him: set defenders always, and with holds on him
	# anyone on his feet who is not holding him (a helper waiting to get a hand on, a defender closing round). A body
	# on the floor or in the grapple is not pushed about: those on their feet step off it. Eased out of the way
	# (_push_all), never put there in one frame.
	var held: bool = not raid.holders.is_empty()
	var down := defs.filter(func(a): return a.state in DOWN_STATES)
	var up := defs.filter(func(a): return a.state not in DOWN_STATES)
	for d in up:
		if d == controlled:
			continue
		if held and defence.role_of(d) == "help":
			continue   # coming in to take hold: his place (Grapple.approach) is nearer him than this would keep him
		if held or d.state in ["ready", "idle"]:
			# (A free raider is where he is: no one gives way to where he is going, which would take a touch away.)
			_nudge(d, _ahead(raider) if held else raider.position, 0.55)
	_keep_apart(up, down, [controlled])


## Keeping apart, this frame (_push_all moves them): those on their feet keep a body's width apart (_apart), and
## keep clear of anyone on the floor, getting up or in the grapple by where his body is now (_nudge_body); one
## getting up off the floor next to another body there shuffles out from under it as he gets up (no faster than
## SHUFFLE), rather than rising inside it. Kept apart by their feet alone, a player walked into a holder bent over
## the raider, or two divers getting up side by side lay inside one another, their feet a body's width apart.
## Those in keep (the player's own man) are not steered off a body on the floor.
func _keep_apart(up: Array, down: Array, keep: Array = []) -> void:
	for d in down:
		if d.state in ["recover", "rise"] and d != raider:
			for o in down:
				if o != d:
					_nudge_body(d, o, BODY_GAP)
	for d in up:
		if keep.has(d):
			continue
		for o in down:
			_nudge_body(d, o, BODY_GAP)
	_apart(up)


## Players who do not hold one another kept a body's width apart (SEPARATE), each giving way half (_push_all), where
## they are about to be (_ahead): eased aside as they come together, so they are apart by the time they would meet.
func _apart(list: Array) -> void:
	for i in list.size():
		var a: Athlete = list[i]
		for j in range(i + 1, list.size()):
			var b: Athlete = list[j]
			var d := _ahead(b) - _ahead(a)
			d.y = 0
			var l := d.length()
			var gap := _gap(a, b, SEPARATE)
			if l < gap and l > 0.001:
				_kept_now[_pair(a, b)] = true
				# The one on the move gives way, most of it: one standing at his place is not jostled by everyone who
				# walks past (each giving half, a player stood at his spot was nudged to and fro as team-mates went by).
				var va := Vector2(a.vel.x, a.vel.z).length() + 0.2
				var vb := Vector2(b.vel.x, b.vel.z).length() + 0.2
				var push := d / l * (gap - l)
				_push_want[a] = (_push_want.get(a, Vector3.ZERO) as Vector3) - push * va / (va + vb)
				_push_want[b] = (_push_want.get(b, Vector3.ZERO) as Vector3) + push * vb / (va + vb)


## a moved out of the way of a body at p, to at least gap from it (along the floor), from where he is about to be
## (_push_all).
func _nudge(a: Athlete, p: Vector3, gap: float) -> void:
	var off := _ahead(a) - p
	off.y = 0
	var l := off.length()
	gap = _gap(a, null, gap)
	if l < gap and l > 0.001:
		_kept_now[_pair(a, null)] = true
		_push_want[a] = (_push_want.get(a, Vector3.ZERO) as Vector3) + off / l * (gap - l)


## a moved out of the way of o's body as it is now (_trunk), to at least gap between the two trunks, from where each is
## about to be: along the floor, away from the nearest part of the other. Standing over a man lying on the floor, his
## trunk is a body's height above the other's and nothing moves him (a helper stepping in past the man at the ankle).
func _nudge_body(a: Athlete, o: Athlete, gap: float) -> void:
	var ta := _trunk(a)
	var tb := _trunk(o)
	var c := Geometry3D.get_closest_points_between_segments(ta[0], ta[1], tb[0], tb[1])
	var l := (c[0] as Vector3).distance_to(c[1])
	gap = _gap(a, o, gap)
	if l >= gap or not is_finite(l):
		return
	_kept_now[_pair(a, o)] = true
	var off: Vector3 = c[0] - c[1]
	off.y = 0.0
	if off.length() <= 0.05:
		off = _ahead(a) - _ahead(o)   # one right over the other: away from his feet
		off.y = 0.0
		if off.length() <= 0.001:
			return
	_push_want[a] = (_push_want.get(a, Vector3.ZERO) as Vector3) + off.normalized() * (gap - l)


## The gap a and b are kept apart by (b null: a and the raider, _nudge), noted as kept this frame: one kept apart last
## frame is kept so until he is APART_HYST further off. Kept apart only while closer than the gap itself, looking
## SEPARATE_LOOK ahead, two players walking past each other were apart one frame (steering away) and not the next
## (steering back), and shook from side to side every frame (tests/motion_audit).
func _gap(a: Athlete, b: Athlete, gap: float) -> float:
	return gap + APART_HYST if _kept.has(_pair(a, b)) else gap


func _pair(a: Athlete, b: Athlete) -> String:
	return "%d:%d" % [a.get_instance_id(), b.get_instance_id() if b != null else 0]


## Where a player is about to be (SEPARATE_LOOK ahead, going the way he means to), for keeping players apart. Without
## the step aside he is making to keep apart (Athlete.avoid): with it, each step aside, made to be clear in AVOID_TIME,
## counted 1.3 times over in where he was going, so the next frame had him clear, he stopped stepping aside and came
## back, and two players near each other went to and fro every frame (tests/motion_probe, "avoid flicker").
func _ahead(a: Athlete) -> Vector3:
	var v := a.vel - a.avoid + a.push
	return a.position + Vector3(v.x, 0.0, v.z) * SEPARATE_LOOK


## A body's trunk, where it is about to be (moved on as _ahead): from his middle to the top of his head. On his feet,
## upright over his feet; bent into a hold, it reaches over what he holds; lying, it is his length along the floor.
func _trunk(a: Athlete) -> Array:
	var sv := a.vel - a.avoid + a.push   # (as _ahead)
	var shift := Vector3(sv.x, 0.0, sv.z) * SEPARATE_LOOK
	if a.model == null:
		var p := Vector3(a.position.x, 0.9, a.position.z) + shift
		return [p, p + Vector3(0.0, 0.8, 0.0)]
	var w: Vector3 = a.model.anchor("waist")
	var sh: Vector3 = (a.model.anchor("shoulder_l") + a.model.anchor("shoulder_r")) * 0.5
	if not (w.is_finite() and sh.is_finite() and shift.is_finite()):
		var p := Vector3(a.position.x, 0.9, a.position.z)
		return [p, p + Vector3(0.0, 0.8, 0.0)]   # (a body not posed yet: upright over his feet)
	var up := sh - w
	var top := sh + (up.normalized() * 0.22 if up.length() > 0.01 else Vector3.ZERO)
	return [w + shift, top + shift]


## The frame's keeping apart (_separate, _apart). A player who steers himself (Athlete.drive) steers round the bodies
## he is about to walk into, at his own pace, clear of them in AVOID_TIME (Athlete.avoid): the way he goes is what
## keeps him apart, rather than a push against it. One standing still is eased aside: as far as asked, no faster than
## NUDGE, getting up to that speed and off it no quicker than NUDGE_ACCEL. Pushed aside in one frame, as it used to
## be (nothing to NUDGE at once, 90 m/s²), a player was knocked; pushed against his own steering, he was pushed late
## and walked into the other first. A body on the floor or in the grapple, and a diver (who drives off with what he
## had, _defender_tackle), is not moved.
func _push_all(dt: float) -> void:
	for a in athletes:
		if (a.state in DOWN_STATES and a.state not in ["recover", "rise"]) or a.state == "held":
			a.push = Vector3.ZERO
			a.avoid = Vector3.ZERO
			a.drove = false
			continue
		var want: Vector3 = _push_want.get(a, Vector3.ZERO)
		var l := want.length()
		var v := Vector3.ZERO
		a.avoid = Vector3.ZERO
		if l > 0.0001:
			var most := SHUFFLE if a.state in ["recover", "rise"] else NUDGE
			if a.drove:
				a.avoid = want / l * minf(most, l / AVOID_TIME)
			else:
				v = want / l * minf(minf(most, sqrt(2.0 * NUDGE_ACCEL * l)), l / maxf(dt, 0.0001))
		a.push = a.push.move_toward(v, NUDGE_ACCEL * dt)
		a.position += a.push * dt
		a.drove = false
	_push_want.clear()
	_kept = _kept_now
	_kept_now = {}


## A defender kept inside his half: stopped at a line, the speed he had into it gone with it (kept, he went on running
## into the line while it held him there, and was off at that speed, sideways, the moment it let go: a wind-up).
func _clamp_defender(d: Athlete) -> void:
	var bound := Arena.HALF_W + (Arena.LOBBY if raid.struggle else 0.0) - 0.25
	if d != controlled and absf(d.position.x) > bound:
		d.position.x = signf(d.position.x) * bound
		if d.vel.x * d.position.x > 0.0:
			d.vel.x = 0.0
	var dep := depth_in(d.team, d.position)
	var back := 0.0   # which way along the court he was held to it: 1 at the end line, -1 at the midline
	if dep < 0.25:
		d.position.z = side(d.team) * 0.25
		back = -1.0
	if dep > Arena.HALF_L - 0.25 and d != controlled:
		d.position.z = side(d.team) * (Arena.HALF_L - 0.25)
		back = 1.0
	if back != 0.0 and d.vel.z * side(d.team) * back > 0.0:
		d.vel.z = 0.0


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
				_break_free()
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
	if fps < 36.0 and int(Game.settings.graphics) > Game.GFX_LOW:
		lower_graphics()


## One graphics level down, for this match and the ones after (Settings shows it).
func lower_graphics() -> void:
	var g := int(Game.settings.graphics) - 1
	Game.settings.graphics = g
	Game.save_settings()
	Game.apply_graphics(get_viewport())
	arena.graphics_changed()
	_floor_shadows()   # on Low the sun's shadows go: each body's own take their place
	hud.event(tr("GFX_LOWERED").format({"level": tr(["GFX_LOW", "GFX_MEDIUM", "GFX_HIGH"][g])}), Game.C_MUTED, false, MatchHud.EV_INFO)


## Every body's shadow on the floor: the sun's own on Medium and High, each body's drawn flat on Low (where the sun
## casts none, as a shadowed light costs a phone a second pass over the whole ground).
func _floor_shadows() -> void:
	var mat: Material = null if Game.shadows_enabled() else arena.floor_shadow
	for a in athletes:
		a.model.set_floor_shadow(mat)
	officials.set_floor_shadow(mat)


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


## The body's part in a touch or kick: a step in at the defender it goes for (raid.aim), wherever he goes, as far as
## the hand or foot needs to get to him (STRIKE_REACH) and no further, by the time it is fully out (halfway through
## the move). A lunge (the AI's strike from further off) steps in at nearly a sprint, anything else at up to half
## his speed, so from too far off it falls short. With nobody to go for, or once it is out, he goes where the stick
## or the AI wants, slowly. (A lunge used to run straight on for most of the move, past him or short of him.)
func _strike_vel(move: Vector3) -> Vector3:
	var slow: Vector3 = move * raider.max_speed * (0.6 if raider.state == "backkick" else 0.35)
	var aim = raid.get("aim")
	if aim == null or not is_instance_valid(aim) or raider.st_t >= raider.st_len * 0.6:
		return slow
	var to: Vector3 = (aim as Athlete).position - raider.position
	to.y = 0.0
	var gap: float = to.length() - float(STRIKE_REACH[raider.state])
	if gap <= 0.0:
		return Vector3.ZERO
	var left := maxf(raider.st_len * 0.5 - raider.st_t, 1.0 / 15.0)
	var top: float = raider.max_speed * (LUNGE_STEP if raid.get("lunge", false) else STRIKE_STEP)
	return to / to.length() * minf(gap / left, top)


## How far off a touch or kick at d gets to him: the hand's or foot's own reach and the step in the body can take by
## the time it is out (_strike_vel), from the speed he has toward d now and d's toward him. The AI strikes from
## within it.
func _strike_from(move: String, d: Athlete, lunge := false) -> float:
	var to: Vector3 = d.position - raider.position
	to.y = 0.0
	var dir: Vector3 = to.normalized() if to.length() > 0.01 else raider.facing
	var t: float = 0.5 * float({"touch": TOUCH_TIME, "kick": KICK_TIME, "backkick": BACKKICK_TIME}[move])
	var top: float = raider.max_speed * (LUNGE_STEP if lunge else STRIKE_STEP)
	var v0 := clampf(raider.vel.dot(dir), 0.0, top)
	var t_top := (top - v0) / maxf(raider.accel, 0.1)
	var step := v0 * t + 0.5 * raider.accel * t * t if t < t_top else (v0 + top) * 0.5 * t_top + top * (t - t_top)
	return float(STRIKE_REACH[move]) + step + maxf(0.0, -d.vel.dot(dir)) * t


func _raider_touch(toe: bool, lunge := false) -> void:
	if raider.state not in ["raid", "dodge"] or raider.cooldown > 0.0:
		return
	raid["lunge"] = lunge
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
	raid["aim"] = best   # the hand or foot goes for him (_aim_limb)
	# Sharp defenders see it coming and pull back out of reach.
	for d in defenders():
		if d == controlled or d.touched or d.state not in ["ready", "idle"] or d.cooldown > 0.0:
			continue
		var off = d.position - raider.position
		off.y = 0
		if off.length() < r + 0.3 + (LUNGE if lunge else 0.0) and raider.facing.angle_to(off.normalized()) < 1.0:
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
	raid["aim"] = target   # the foot goes for him (_aim_limb)
	raid["lunge"] = false
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
		# Out of a hold he gathers himself on the free leg first, and springs from there.
		var gather := JUMP_GATHER if holders.size() > 0 else 0.0
		raider.set_state("jump", JUMP_TIME + gather, gather)
		raider.cooldown = JUMP_TIME + gather + 0.6
		raider.energy = maxf(0.4, raider.energy - 0.035)
		_spend_breath("lion")
		Sfx.play("whoosh", -4.0, 0.6)
		Sfx.voice("hup", -8.0, raider.voice_pitch())
	if holders.size() > 0:
		# Slipping a hold, judged on the hold he is actually in (the grapple's): the move goes against the grip
		# it suits best (a dubki against arms round his middle, a jump against a held ankle), and a move that
		# cannot slip any of them (a dubki with only his ankle held) slips none (Grapple.ESCAPES).
		var pick: Array = grapple.best_escape("dubki" if kind == "dubki" else "lion", holders) if grapple else [holders[0], 0.0]
		var h: Athlete = pick[0]
		var fit: float = pick[1]
		var chance := 0.62 * fit * (0.4 + raider.move_skill(kind)) * raider.strength / (holders.size() * (0.6 + h.tackle * 0.6))
		var slips := fit > 0.0 and bool(lab_force.get("escape", rng.randf() < chance))
		# Decided now, done with the body (_tick_escape). A lion jump: halfway from the end of the gather to the
		# jump clip's own takeoff, so the foot is out of the holder's hands (Grapple.TORN_FREE) as he leaves the
		# floor. A dubki: as he is down under the arms (the dubki clip's lowest).
		var at := 0.0
		if kind == "lion":
			var up: float = raider.model.takeoff_in() if raider.model else -1.0
			at = JUMP_GATHER + (up - JUMP_GATHER) * 0.5 if up >= JUMP_GATHER else JUMP_GATHER + JUMP_TIME * 0.06
		else:
			var down: float = raider.model.ducked_in() if raider.model else -1.0
			at = down if down >= 0.0 else DUBKI_TIME * 0.3
		raid.escape = {"kind": kind, "state": raider.state, "from": h if slips else null, "at": at}


## A move out of a hold comes off when the body does it, not when it is called for (_raider_escape), and that is
## when it is shown: a lion jump's leg comes out of the holder's hands as the raider leaves the floor; a dubki slips
## the arms round him as he is down under them. A jump the holds keep (it did not slip the hold, or another hold is
## still on him) goes no further: they stop him leaving the floor, and he comes back down onto his free foot,
## jolted. A dubki under arms with his ankle still held is a duck of his top half: he stays on the free leg, held.
func _tick_escape(dt: float) -> void:
	if not raid.has("escape"):
		return
	var e: Dictionary = raid.escape
	if raider.state != String(e.state):
		raid.erase("escape")   # taken down in the middle of it, or the raid is over
		return
	if raider.st_t + dt < float(e.at):
		return   # (his body is posed this frame at st_t + dt: the match runs first)
	raid.erase("escape")
	var h: Athlete = e.get("from")
	if h != null and raid.holders.has(h):
		var free: bool = raid.holders.size() == 1
		_event("escape", {"how": e.kind, "from": h.pid(), "kind": h.kind(),
			"hold": grapple.style_of_hold(h) if grapple else "", "free": free})
		_release(h, true, true)
		# "Broke free!" only when he is: slipping one of several holds is not getting away. It clears the hold's line,
		# and the move's name goes up under it.
		if free:
			hud.event(tr("EV_BROKE_FREE"), Game.C_GOLD, true, MatchHud.EV_FREE)
			_ooh()
			if raider == controlled:
				tutorial_event.emit("broke_free")
		_move_moment(String(e.kind))
		if raid.holders.is_empty():
			raid.progress = maxf(0.0, raid.progress - 0.35)
	if e.kind != "lion":
		return
	if raid.holders.is_empty():
		raid["spring"] = raider.dive_dir * _jump_speed() * 0.75   # the spring off the free leg (_move_raider)
	else:
		raider.set_state("held")
		if grapple:
			grapple.jolt = 1.0
		Sfx.voice("grunt", -8.0, raider.voice_pitch())


## How fast a lion jump carries him (m/s).
func _jump_speed() -> float:
	return raider.max_speed * (1.15 + 0.3 * raider.move_skill("lion"))


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
			if _held_low(h):
				low += 1
		return "jump" if low * 2 >= raid.holders.size() else "dubki"
	var home := Vector3(0, 0, side(raiding))
	if raider.vel.dot(home) > 0.5 and _link_ahead(home) != null:
		return "dubki"
	return ""


## Whether h holds him low (an ankle), by the hold he actually has (the grapple's), not his tackle's name.
func _held_low(h: Athlete) -> bool:
	var st: String = grapple.style_of_hold(h) if grapple and grapple.has(h) else Grapple.style_of(h.kind())
	return st == "ankle"


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
	_event("move", {"move": move})
	raid.moves.append(move)
	var key: String = {"dubki": "EV_DUBKI", "lion": "EV_LION", "backkick": "EV_BACK_KICK", "sidekick": "EV_SIDE_KICK", "toe": "EV_TOE"}.get(move, "")
	if key != "":
		hud.event(tr(key), Game.C_GOLD, move in ["toe", "backkick", "sidekick"], MatchHud.EV_TOUCH)
	if move in ["dubki", "lion"]:
		arena.excite(0.6)
		Sfx.play("roar", -14.0)
	if raider == controlled:
		tutorial_event.emit({"dubki": "dubki", "lion": "lion_jump", "backkick": "back_kick", "sidekick": "back_kick", "toe": "toe_touch"}.get(move, move))


## The player's Dodge button, which is Break free while he is held (TouchControls.held): held, the escape that suits
## the holds on him best (Grapple.ESCAPES: a lion jump out of hands on his ankle, a dubki out of arms round him, a
## sidestep out of a thigh hold), rather than a sidestep, which no ankle hold gives way to. Dubki and Lion jump stay
## there to pick one himself.
func _break_free() -> void:
	var holders: Array = raid.holders
	if holders.is_empty() or grapple == null:
		_raider_dodge(Vector3.ZERO)
		return
	var best := "dodge"
	var fit := float(grapple.best_escape("dodge", holders)[1])
	for mv in ["dubki", "lion"]:
		var f := float(grapple.best_escape(mv, holders)[1])
		if f > fit:
			best = mv
			fit = f
	if best == "dodge":
		_raider_dodge(Vector3.ZERO)
	else:
		_raider_escape(best)


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
		# A sidestep twists out of the hold it suits best, judged on the holds he is in (Grapple.ESCAPES): not out
		# of hands on his ankle. "Broke free!" only when he is.
		var pick: Array = grapple.best_escape("dodge", holders) if grapple else [holders[0], 0.0]
		var h: Athlete = pick[0]
		var fit: float = pick[1]
		var chance := 0.5 * fit * raider.agility * raider.strength / (holders.size() * (0.6 + h.tackle * 0.6))
		if fit > 0.0 and bool(lab_force.get("escape", rng.randf() < chance)):
			var free := holders.size() == 1
			_event("escape", {"how": "dodge", "from": h.pid(), "kind": h.kind(), "hold": grapple.style_of_hold(h),
				"free": free})
			_release(h, true)
			if free:
				hud.event(tr("EV_BROKE_FREE"), Game.C_GOLD, false, MatchHud.EV_FREE)
				if raider == controlled:
					tutorial_event.emit("broke_free")
			if holders.is_empty():
				raid.progress = maxf(0.0, raid.progress - 0.35)
		elif grapple:
			grapple.clamp_down()   # it fails: they feel him go and heave him back


func _release(h: Athlete, knocked: bool, torn := false) -> void:
	raid.holders.erase(h)
	# Thrown off: he staggers back from the raider over a few frames (rather than appearing further off),
	# about as far as he used to be put, and needs a moment before he can grab on again. A man holding an
	# ankle is on the floor already: the leg is pulled out of his hands and he stays where he is.
	var away := h.hold_offset.normalized() if h.hold_offset.length() > 0.01 else -h.facing
	var style := grapple.style_of_hold(h) if grapple else ""
	if style != "":
		grapple.release(h, torn)
		_event("release", {"who": h.pid(), "grapple": grapple.id})
	h.vel = Vector3(away.x, 0.0, away.z) * {"ankle": 0.6, "thigh": 1.5, "waist": 3.0, "block": 3.0}.get(style, 4.0)
	h.cooldown = maxf(h.cooldown, 0.15)
	# Knocked off: a man on the floor (an ankle or thigh hold) gets up; one on his feet staggers back. Slipped by
	# the body he held moving out of his hands (torn: a lion jump's leg, a dubki's middle), he is not thrown back:
	# down on the floor, he lies a moment where it left him, reaching after it, before he gets up; on his feet, his
	# arms close on nothing, bent over where the raider was, and he straightens up.
	if torn and style in ["ankle", "thigh"]:
		h.vel = Vector3.ZERO
		h.set_state("recover", 1.1 + LOST_GRIP, LOST_GRIP)
	elif torn:
		h.vel = Vector3.ZERO
		h.set_state("rise", RISE_SLIPPED)
	elif knocked and style not in ["waist", "block"]:
		h.set_state("recover", 1.1)
	else:
		h.set_state("ready")
	# Free of every hold: he raids on, or carries on with the move that freed him.
	if raid.holders.is_empty() and raider.state not in ["jump", "dubki", "dodge"]:
		raider.set_state("raid")


func _defender_tackle(d: Athlete, kind := "", windup := false) -> void:
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
	# Aim at what the tackle goes for (the nearer ankle or thigh, his middle), leading him a little.
	var lead := raider.vel * 0.12
	var aim := (_aim_point(d) + lead - d.position)
	aim.y = 0
	if aim.length() > 0.01 and dist <= 2.6:
		dir = aim.normalized()
	d.dive_dir = dir
	d.facing = dir
	d.set_state("dive", DIVE_TIME)
	d.dive_from = d.move_vel   # how he is moving over the floor now, pushed or not (his vel can be stale: kept in a chain)
	d.dive_t = 0.0
	# Out of a wind-up the dive went a frame late and lost its first frame's ground (0.81 m); made at once, at the
	# button, it went in the frame (0.95 m). Each keeps its reach, driven off over four frames now.
	d.dive_launch = DIVE_LAUNCH if windup else DIVE_LAUNCH_NOW
	d.push = Vector3.ZERO
	d.reach_t = 0.0
	d.cooldown = 1.4
	_event("tackle_attempt", {"who": d.pid(), "kind": d.kind(), "gap": snappedf(dist, 0.01)})
	_tire(d, 0.035)
	d.chain_dive = false
	Sfx.play("whoosh", -8.0, 0.8)
	Sfx.voice("grunt", -9.0, d.voice_pitch())
	# A chained pair goes in together: the partner a beat after the lead (his own reaction to him going), at the other
	# part of the raider (one low, one high; _chain_follow). In the same frame, at the same part, they read as one dive
	# twice, and went down and got up as one.
	var p: Athlete = d.chain_partner
	if p != null:
		_unchain(d)
		d.chain_dive = true
		if p.state in ["ready", "idle"] and p.position.distance_to(raider.position) < 3.0:
			var lag := CHAIN_LAG + CHAIN_LAG_SPREAD * float(absi(hash(p.pid())) % 100) / 100.0
			p.set_meta("chain_go", [phase_t + lag, _chain_kind(d.kind(), p.style), windup])


## A chained partner going in after the lead (_defender_tackle) when his beat comes, if he still can.
func _chain_follow() -> void:
	for p in defenders():
		if not p.has_meta("chain_go"):
			continue
		var go: Array = p.get_meta("chain_go")
		if phase_t < float(go[0]):
			continue
		p.remove_meta("chain_go")
		if p.state in ["ready", "idle"] and p != controlled and raider.state != "fallen" \
				and p.position.distance_to(raider.position) < 3.2:
			_defender_tackle(p, String(go[1]), bool(go[2]))
			p.chain_dive = true


## The partner's tackle in a chain: his own, unless it is the lead's, then the part of the raider the lead is not going
## for (the lead at his ankle, the partner at his thigh; at his thigh, round his middle; round his middle, his thigh).
static func _chain_kind(lead: String, own: String) -> String:
	if Grapple.style_of(own) != Grapple.style_of(lead):
		return own
	match Grapple.style_of(lead):
		"ankle":
			return "thigh"
		"thigh":
			return "waist"
	return "thigh"


## The point on the raider a defender's tackle goes for (the ground under it).
func _aim_point(d: Athlete) -> Vector3:
	var style := Grapple.style_of(d.tackle_kind if d.tackle_kind != "" else d.style)
	if raider.model == null or style == "":
		return raider.position
	var p: Vector3 = raider.model.anchor("waist")
	if style in ["ankle", "thigh"]:
		var part := "ankle_" if style == "ankle" else "thigh_"
		var l: Vector3 = raider.model.anchor(part + "l")
		var r: Vector3 = raider.model.anchor(part + "r")
		p = l if Vector2(l.x - d.position.x, l.z - d.position.z).length() < Vector2(r.x - d.position.x, r.z - d.position.z).length() else r
	return Vector3(p.x, 0.0, p.z)


## A dive: driven off the floor from the crouch (DIVE_PUSH), slowing through the air, landing with little left to
## slide. (It used to start from a standstill at running acceleration, so most of its ground was covered sliding on
## the floor after it; then it left the crouch at full speed in one frame, a change of speed of 120 m/s². Driven off
## over four frames from the frame he goes, it covers the ground the old dive did, frame for frame to within 4 cm
## (from the fifth frame, made at the button), and the sharpest change is 31 m/s² (38 at the button). Started a frame
## late, and driven off more slowly, it was 0.2 m behind it when the old one reached the ankle, so the same dive came
## to the raider three frames later, his other leg; ahead of it, it held more often.)
func _dive_motion(d: Athlete, dt: float) -> void:
	var first := d.dive_t <= 0.0
	d.dive_t += dt
	var want := d.dive_dir * d.dive_launch
	if d.dive_t > DIVE_PUSH:
		want = d.dive_dir * lerpf(d.dive_launch, DIVE_LAND, clampf((d.dive_t - DIVE_PUSH) / maxf(d.st_len - DIVE_PUSH, 0.01), 0.0, 1.0))
	# Toward it no quicker than the push off a standstill (the launch over DIVE_PUSH), whichever way he was going: a
	# defender stepping across or back as he goes takes longer to get going his dive's way, rather than being turned
	# round in the frame.
	var was := d.dive_from if first else Vector3(d.vel.x, 0.0, d.vel.z)
	d.vel = was.move_toward(want, d.dive_launch / DIVE_PUSH * dt)
	d.position += d.vel * dt


## A dive comes down: on the floor, getting up. His arms are still out for a moment.
func _land(d: Athlete, getup: float) -> void:
	# Up at his own pace, and sooner from a dive that left him low on his knees than from one flat on the floor (an
	# ankle dive): two who went down together were up together, to the frame.
	var depth: float = {"ankle": 1.0, "thigh": 0.72, "waist": 0.45, "dash": 0.3}.get(d.kind(), 0.8)
	var pace := 0.9 + 0.25 * float(absi(hash(d.pid())) % 100) / 100.0
	d.set_state("recover", getup * pace * (0.7 + 0.3 * depth))
	if Grapple.style_of(d.kind()) != "":
		d.reach_t = ARMS_OUT_AFTER


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
			_dive_motion(d, dt)
			if d.st_t >= d.st_len:
				_land(d, 0.9)
		"recover", "rise":
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
		_event("defender_out", {"who": d.pid(), "why": "midline"})
		hud.event(tr("EV_CROSSED_MIDLINE"), Game.C_DANGER, false, MatchHud.EV_RESULT)
		_put_out(d)
		teams[raiding].score += 1
		teams[raiding].pts.extra += 1
		_revive(raiding, 1)
		_switch_defender_after_loss()
		if on_mat(1 - raiding).is_empty():
			_end_raid("all_out_lobby")
		return


func _defender_out_of_bounds(d: Athlete) -> void:
	_event("defender_out", {"who": d.pid(), "why": "bounds"})
	hud.event(tr("EV_OUT_OF_BOUNDS"), Game.C_DANGER, false, MatchHud.EV_RESULT)
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
				if _held_low(h):
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
			if closing and dd < _strike_from("backkick", d) and raider.facing.angle_to((d.position - raider.position).normalized()) > 1.5 \
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
				raid.erase("aim")   # the foot goes over the line, not at a defender (and he does not step in at one)
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
		elif l < 1.8 and l > 0.01 and raid.ai_mode == "probe" and d != raid.get("ai_mark") and raid.get("ai_step") == "work":
			# Working the cover: keep clear of everyone but the man he is testing.
			steer += off / l * (1.8 - l) * 1.5
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
	_event("dash", {"who": d.pid()})
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
			# Real raiders go for the touch from about 2 m, a lunge step carrying the hand or foot in: from as far as
			# that step gets the hand or foot to him at the speed he is coming in at.
			if dist < _strike_from("kick" if toe else "touch", mark, true) and raider.cooldown <= 0.0 and raider.state == "raid":
				raider.facing = to.normalized()
				_raider_touch(toe, true)
				raid.ai_step = "work"
				raid.ai_step_t = rng.randf_range(0.6, 1.4)
			elif float(raid.ai_step_t) <= 0.0:
				raid.ai_step = "work"
				raid.ai_step_t = rng.randf_range(0.6, 1.4)
		_:
			# Light steps side to side, just outside his reach.
			var sway := sin(float(raid.probe_t) * (1.0 + 0.6 * skill) + float(raid.ai_lane)) * 0.9
			target = mark.position + home_dir * (2.4 - 0.5 * urgency) + across * sway
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
			elif float(raid.probe_t) > 2.0 and dist < _strike_from("kick", mark) - 0.05 and raider.cooldown <= 0.0 and raider.state == "raid" \
					and mark.state not in ["telegraph", "dive"] and rng.randf() < dt * (0.025 + 0.1 * _tend("toe")) * (0.3 + open):
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
	# On the court: a sidestep toward a line he is near goes the other way, and nothing takes him back over the end
	# line or forward over the midline (the court's edge would stop him dead: _clamp_defender).
	var bound := Arena.HALF_W + (Arena.LOBBY if raid.struggle else 0.0) - 0.25
	if absf(d.position.x + (away + sidestep).normalized().x * EVADE_REACH) > bound:
		sidestep = -sidestep
	var to := d.position + (away + sidestep).normalized() * EVADE_REACH
	var inside := Vector3(clampf(to.x, -bound, bound), 0.0,
		side(d.team) * clampf(depth_in(d.team, to), 0.25, Arena.HALF_L - 0.25))
	# A line within his reach: he pulls up at it (the evade's seek), rather than running into the court's edge.
	d.evade_to = inside if Vector2(inside.x - to.x, inside.z - to.z).length() > 0.01 else Vector3.INF
	var dir := Vector3(inside.x - d.position.x, 0.0, inside.z - d.position.z)
	d.dive_dir = dir.normalized() if dir.length() > 0.1 else Vector3.ZERO
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
			d.face_toward(raider.position, dt, 14.0)
			if d.st_t >= d.st_len:
				_defender_tackle(d, "", true)
			if d.state == "dive":
				_dive_motion(d, dt)   # off the floor in the frame he goes, not the one after
			else:
				d.drive(Vector3.ZERO, dt)
			return
		"dive":
			_dive_motion(d, dt)
			if d.st_t >= d.st_len:
				_land(d, 1.15 - 0.25 * react)
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
		"recover", "rise":
			d.drive(Vector3.ZERO, dt)
			if d.st_t >= d.st_len:
				d.set_state("ready")
			return
		"holding":
			return
		"evade":
			d.lock_facing = true
			if d.evade_to != Vector3.INF:
				# Pulling up short of a line, no faster than he can stop by it at his own acceleration. (Eased in over
				# the last 0.9 m, as he was, he could not stop from a sprint: he ran on into the court's edge, which
				# stopped him dead, _clamp_defender.)
				var gap := d.evade_to - d.position
				gap.y = 0.0
				var room := gap.length()
				var stop_speed := minf(d.max_speed * 1.2, sqrt(2.0 * d.accel * maxf(room - 0.05, 0.0)))
				d.drive(gap / room * stop_speed if room > 0.01 else Vector3.ZERO, dt)
			else:
				d.drive(d.dive_dir * d.max_speed * 1.2, dt)
			d.face_toward(raider.position, dt, 14.0)
			if d.st_t >= d.st_len:
				d.set_state("ready")
			_clamp_defender(d)
			return
	if lab and not bool(lab_force.get("ai_defence", false)) and not (bool(lab_force.get("help", false)) and not holders.is_empty()):
		d.lock_facing = true
		d.drive(Vector3.ZERO, dt)
		d.face_toward(raider.position, dt, 10.0)
		if d.state != "ready":
			d.set_state("ready")
		return
	var inside = raid.entered and opp_depth > 0.0
	var alarm: bool = raid.alarm or (inside and opp_depth > Arena.BONUS + 0.3)
	# Where to be comes from the team's plan (DefenceCoach): a role and a place of his own, so they cover the
	# raider between them instead of all going for the same spot. Help runs in flat out (from the deeper line
	# that takes about the 0.65-1.15 s help took in the footage); the way home is cut at a run.
	var order: Array = defence.order(d)
	var target: Vector3 = order[0]
	var spd := 2.4
	match String(order[2]):
		"help":
			spd = d.max_speed
		"lane":
			spd = d.max_speed   # cutting him off: flat out
		"contain":
			spd = 2.6 + 0.8 * react
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
	var heading_home := raider.vel.dot(Vector3(0, 0, -side(d.team))) > 1.0
	# Once he has touched someone he is getting away with the point unless they stop him: the last chance. Whoever
	# he comes near goes for him, the ones standing off in his way home too, up to three at once, from further off
	# when he is running at them, and with less of a wind-up: a dive at his ankles rather than watching him go.
	var last_ditch: bool = not raid.touched.is_empty()
	# Once he is held, team-mates join the struggle rather than dive in; and the ones standing off in his way
	# home are there to stop him, not to dive at him from out there (until the last chance).
	if holders.size() > 0 or (defence.role_of(d) == "contain" and not last_ditch):
		return
	var engaging := 0
	for o in defenders():
		if o.state in ["telegraph", "dive"]:
			engaging += 1
	var max_engage := 3 if last_ditch else (2 if alarm else 1)
	if engaging >= max_engage:
		return
	# In the footage defenders went for the raider from 1.4-3 m (median 1.8), as he stepped in.
	var rng_range := 1.75 + 0.3 * react
	if last_ditch and dist > 0.01:
		# Running at him, he comes into the dive's reach as it goes.
		rng_range += clampf(raider.vel.dot(-to / dist) * 0.25, 0.0, 0.8)
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
	elif last_ditch:
		p = maxf(p, 5.0 * diff * (0.6 + d.tackle) * react)
	# Behind his back: a raider looking the other way is there to be caught.
	if dist > 0.01 and dist < 2.0 and raid.baulk and raider.facing.dot(-to.normalized()) < -0.3:
		p = maxf(p, 1.2 * diff * (0.6 + d.tackle) * react)
	if alarm:
		p *= 1.6
	if d.touched:
		p *= 1.5
	if rng.randf() < p * dt:
		d.tackle_kind = _ai_pick_tackle(d)
		d.set_state("telegraph", float(prof.telegraph) * (1.15 if d.tackle_kind == "waist" else 1.0) * (0.75 if last_ditch else 1.0))
		d.cooldown = 0.2


# ---------------------------------------------------------------- contacts and lines

var _limb_last := {}   # the raider's touching hand or kicking foot last frame (_limbs)


## A touch or kick reaching for the defender it goes for (raid.aim): the right hand (RiggedBody.hand_target) or the
## kicking foot (RiggedBody.kick_goal) steered to the nearest of him over the move's own curve, as far as the arm or
## leg reaches. Out of its reach, it falls short of him and no touch is given (_check_contacts).
func _aim_limb() -> void:
	var rig: RiggedBody = raider.model.rig if raider and raider.model else null
	if rig == null:
		return
	var moving: bool = raider.state in ["touch", "kick", "backkick"]
	var aim = raid.get("aim")
	if not moving or aim == null or not is_instance_valid(aim) or (aim as Athlete).model == null:
		rig.kick_w = 0.0
		rig.kick_goal = Vector3.INF
		if raid.has("aim_part"):
			rig.hand_target.erase("r")
			raid.erase("aim_part")
		if not moving:
			raid.erase("aim")
		return
	var m: HumanModel = (aim as Athlete).model
	var w := sin(clampf(raider.st_t / maxf(raider.st_len, 0.01), 0.0, 1.0) * PI)
	if raider.state == "touch":
		if not raid.has("aim_part"):
			# The nearest of him to the shoulder the hand goes from, on the side of him facing the raider.
			var sh: Vector3 = raider.model.anchor("shoulder_r")
			var part := "waist"
			for p in ["shoulder_l", "shoulder_r", "thigh_l", "thigh_r"]:
				if sh.distance_to(m.anchor(p)) < sh.distance_to(m.anchor(part)):
					part = p
			var off := sh - m.anchor(part)
			off.y = 0.0
			raid["aim_part"] = part
			# On his surface, the part's own thickness out from it (as _gap_to has it): 3 cm further out, a hand that
			# got there was still short of a touch by the width of a finger.
			var skin: float = {"waist": 0.15, "shoulder": 0.05}.get(part.substr(0, part.length() - 2) if part != "waist" else part, 0.08)
			rig.hand_target["r"] = {"model": m, "part": part, "offset": off.normalized() * skin, "w": 0.0, "fade": 0.0}
		if rig.hand_target.has("r"):
			rig.hand_target["r"]["w"] = w
		return
	# A toe touch goes for his nearest shin, along the floor; a back or side kick for a shin or thigh.
	var from: Vector3 = raider.model.anchor("waist")
	var goal := Vector3.INF
	var bd := INF
	for s in ["l", "r"]:
		var segs := [[m.anchor("ankle_" + s), m.anchor("knee_" + s), 0.06]]
		if raider.state == "backkick":
			segs.append([m.anchor("knee_" + s), m.anchor("hip_" + s), 0.08])
		for sg in segs:
			var q := Geometry3D.get_closest_point_to_segment(from, sg[0], sg[1])
			var out := Vector3(from.x - q.x, 0.0, from.z - q.z)
			if out.length() < bd:
				bd = out.length()
				goal = q + out.normalized() * float(sg[2])   # on the near side of the leg, on it, not inside it
	rig.kick_goal = goal
	rig.kick_w = w


## The raider's touching hands or kicking feet as drawn this frame, and halfway back to where they were last frame
## (a fast foot does not pass through a leg between two frames); none when he is not touching or kicking.
func _limbs() -> Array:
	var out := []
	if raider == null or raider.model == null or raider.state not in ["touch", "kick", "backkick"]:
		_limb_last.clear()
		return out
	for part in (["hand_l", "hand_r"] if raider.state == "touch" else ["toe_l", "toe_r", "foot_l", "foot_r"]):
		var p: Vector3 = raider.model.anchor(part)
		out.append(p)
		if _limb_last.has(part):
			out.append(p.lerp(_limb_last[part], 0.5))
		_limb_last[part] = p
	return out


## How far the nearest of these points is from d's body as drawn, past its thickness (m): his feet, shins and
## thighs, trunk and arms.
func _gap_to(d: Athlete, pts: Array) -> float:
	if d.model == null or pts.is_empty():
		return INF
	var m: HumanModel = d.model
	var segs := [[m.anchor("waist"), (m.anchor("shoulder_l") + m.anchor("shoulder_r")) * 0.5, 0.15]]
	for s in ["l", "r"]:
		segs.append([m.anchor("toe_" + s), m.anchor("ankle_" + s), 0.05])
		segs.append([m.anchor("ankle_" + s), m.anchor("knee_" + s), 0.06])
		segs.append([m.anchor("knee_" + s), m.anchor("hip_" + s), 0.08])
		segs.append([m.anchor("shoulder_" + s), m.anchor("hand_" + s), 0.05])
	var best := INF
	for p in pts:
		for sg in segs:
			best = minf(best, Grapple._seg_dist(p, sg[0], sg[1]) - float(sg[2]))
	return best

func _check_contacts(defs: Array) -> void:
	_counter_grabs(defs)
	# The touching hand or kicking foot as drawn: a touch is given when it is on a defender's body (_gap_to), not
	# for the two bodies being within a reach of each other (kicks were given from up to 2.2 m apart, the foot well
	# short of him or past him).
	var limbs := _limbs()
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
				var on_him: bool = _gap_to(d, limbs) <= TOUCH_GAP if not limbs.is_empty() \
						else dist < _reach_for("toe" if raider.state == "kick" else "hand") and raider.facing.angle_to((d.position - raider.position).normalized()) < 1.2
				# A leg tags one defender; a hand can sweep two, but not on a lunge, which goes for one man.
				var one: bool = raider.state == "kick" or raid.get("lunge", false)
				if active and on_him and not (one and raid.get("touch_hit", false)):
					hit = true
					via = "toe" if raider.state == "kick" else "hand"
					raid.touch_hit = true
			elif raider.state == "backkick":
				var p2 := raider.st_t / maxf(raider.st_len, 0.01)
				var on_him2: bool = _gap_to(d, limbs) <= TOUCH_GAP if not limbs.is_empty() \
						else dist < _reach_for("kick") and raider.kick_dir.angle_to((d.position - raider.position).normalized()) < 0.6
				if p2 > 0.25 and p2 < 0.75 and on_him2 and not raid.get("touch_hit", false):
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
					# A lunge commits him: the step that carries the hand in puts him within the defender's grasp
					# (in the footage, raiders were caught on the step in).
					if raid.get("lunge", false):
						counter += 0.15
					# Running straight into a set defender: he blocks.
					var into := raider.vel.dot((d.position - raider.position).normalized()) > 1.2 and via == ""
					if into:
						counter += 0.3 + 0.4 * (d.dskill("block") - 0.4)
					# A leg at full stretch is hard to grab from a set position.
					if via in ["toe", "backkick", "sidekick"]:
						counter *= 0.45
					if rng.randf() < counter:
						# He grabs back after a moment's reaction, and only if the raider is still in his reach then
						# (see _counter_grabs), not in the same instant as the touch.
						d.tackle_kind = "block" if into else d.style
						d.set_meta("grab_at", phase_t + COUNTER_REACT)
						d.set_meta("grab_block", into)
						# Committed: he winds up to grab (and, if the raider is out of his reach by then, carries on
						# into a tackle at him) rather than pulling away from the touch.
						d.set_state("telegraph", COUNTER_REACT + float(prof.telegraph) * 0.6)
						continue
		# Tackles. A dive holds only with a hand on the part it goes for (the lower leg, the thigh, his middle)
		# while the arms are out, checked on the bodies as drawn (Grapple.contact). The dash is a shoulder,
		# not a hold, and still goes by the distance between the two.
		var kind = d.kind()
		var catch_r: float = {"ankle": 0.9, "waist": 0.75, "dash": 0.85}.get(kind, 0.8)
		var style := Grapple.style_of(kind)
		var contact := {}
		var reached := false
		if style != "":
			if (d.state == "dive" or d.reach_t > 0.0) and raider.state not in ["shoved", "fallen"]:
				# Hands on him (along their path since the last frame, so a fast hand cannot pass through a leg
				# between frames), and the bodies no further apart than the dive's stretch: about the reach tackles
				# had before contact was checked. An ankle dive's hands are a whole body's length out along the
				# floor, so it reaches from further than the others, and nearer than that they go past his feet.
				var stretch: float = {"ankle": 1.25, "thigh": 0.9, "waist": 0.85, "block": 0.85}.get(style, catch_r)
				contact = Grapple.contact(d, raider, style, grapple.taken() if grapple else [], raider.airborne(), stretch, d.hands_prev)
				reached = not contact.is_empty()
			d.hands_prev = [d.model.anchor("hand_l"), d.model.anchor("hand_r")] if d.model and d.state in ["dive", "recover"] else []
		else:
			reached = d.state == "dive" and dist < catch_r and raider.state != "shoved"
		if reached:
			d.reach_t = 0.0   # the grip is taken or lost now
			_event("tackle_contact", {"who": d.pid(), "kind": kind, "gap": snappedf(float(contact.get("gap", dist)), 0.001)})
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
				if raid.holders.is_empty():
					_dash_hit(d)
				else:
					# Held, he goes nowhere a shove would put him: the dash only bumps into the struggle.
					d.set_state("recover", 0.8)
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
			if bool(lab_force.get("hold", rng.randf() < hold_chance)):
				_attach(d, false, String(contact.get("slot", "")), true)
			else:
				# Touched him but the grip would not hold: down he goes, empty-handed.
				_event("grip_lost", {"who": d.pid(), "kind": kind})
				d.set_state("recover", 1.0)
		elif raid.holders.size() > 0 and raid.holders.size() < 4 and d.state in ["ready", "idle"] and d != controlled \
				and d.cooldown <= 0.0 and grapple:
			# Helping: each helper takes the hold he ran to (Grapple.claim), once it is within his reach.
			var slot := grapple.claim(d)
			if slot != "" and grapple.can_reach(d, slot):
				piling.append([d, slot])
		elif raid.holders.size() > 0 and d == controlled and d.state in ["ready", "idle"] and grapple:
			var slot := grapple.claim(d)
			if slot != "" and grapple.can_reach(d, slot):
				d.tackle_kind = "thigh"
				_attach(d, false, slot)
	_pile_on(piling)


## Touched defenders grabbing back (see the touch in _check_contacts): when his reaction is up, he takes hold
## if the raider is still within reach of his hands and a step (Grapple.reachable, COUNTER_STEP; the grapple
## then brings him in, which is the step), and not in the middle of a move that takes him out of it.
## Otherwise the moment has gone, and his wind-up carries on into a tackle.
func _counter_grabs(defs: Array) -> void:
	for d in defs:
		if not d.has_meta("grab_at") or phase_t < float(d.get_meta("grab_at")):
			continue
		var block: bool = d.get_meta("grab_block", false)
		d.remove_meta("grab_at")
		d.remove_meta("grab_block")
		if d.state not in ["ready", "idle", "telegraph", "evade"] or raider.state in ["dodge", "dubki", "jump", "fallen"]:
			continue
		var styles := ["block"] if block else ["thigh", "waist"]
		if styles.any(func(st): return Grapple.reachable(d, raider, st, COUNTER_STEP)):
			_attach(d, block)
		else:
			_event("grab_missed", {"who": d.pid()})


func _pile_on(piling: Array) -> void:
	# Team-mates pile in one at a time, a little faster the more of them are close.
	if piling.is_empty() or raid.holders.is_empty():
		return
	var rate := (0.45 + 0.2 * piling.size()) * float(prof.tackle)
	if bool(lab_force.get("pile", rng.randf() < get_process_delta_time() * rate)):
		var pick: Array = piling[rng.randi() % piling.size()]
		var d: Athlete = pick[0]
		d.tackle_kind = "thigh"
		_attach(d, false, String(pick[1]))


func _touch(d: Athlete, via := "") -> void:
	_event("touch", {"who": d.pid(), "via": via if via != "" else "contact"})
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


func _attach(d: Athlete, block := false, slot := "", reached := false) -> void:
	if raid.holders.has(d):
		return
	# Every hold is made on a slot of the raider's body, one defender each (Grapple). A hold that did not come
	# from a dive's hands (a counter-grab, piling on, a chain) takes the slot nearest him, if one is free.
	if grapple == null or grapple.state == "done":
		grapple = Grapple.new(raider)
	var style := Grapple.style_of(d.kind())
	if style == "":
		style = "thigh"
	if slot != "" and grapple.taken().has(slot):
		slot = ""   # held already (one defender a slot): the nearest free one, if any
	if slot == "":
		var want := Grapple.slot_for(style, d, raider)
		var free := grapple.free_slots(d)
		slot = want if free.has(want) else grapple.claim(d)
		if slot == "" or not free.has(slot):
			grapple.unclaim(d)
			return   # nowhere left to hold him
	if slot.begins_with("leg_") and style not in ["ankle", "thigh"]:
		style = "thigh"
	elif not slot.begins_with("leg_") and style in ["ankle", "thigh"]:
		style = "waist" if slot == "back" else "block"
	var was_dive := d.state in ["dive", "recover"] or block
	var first: bool = raid.holders.is_empty()
	raid.holders.append(d)
	raid.struggle = true
	raid.alarm = true
	var off := d.position - raider.position
	off.y = 0
	if off.length() < 0.05:
		off = -raider.facing * 0.55
	d.hold_offset = off   # where he is; closes in to the hold (see _tick_raid)
	d.set_state("holding")
	grapple.add(d, style, slot, reached)
	_event("hold", {"who": d.pid(), "kind": d.kind() if was_dive else "pile", "style": style, "slot": slot, "grapple": grapple.id,
		"holders": raid.holders.size()})
	raider.set_state("held")
	Sfx.play("thud", -2.0)
	Sfx.voice("oof" if first else "grunt", -6.0, raider.voice_pitch())
	var chained := d.chain_dive and not first
	# The message names the hold actually made (a counter-grab on a thigh is a thigh hold, not an ankle hold).
	var hold_key: String = {"ankle": "EV_HOLD", "thigh": "EV_THIGH", "waist": "EV_WAIST", "block": "EV_BLOCK"}.get(style, "EV_HOLD")
	raid.def_moves.append(d.kind() if was_dive else "pile")
	if first:
		raid["first_hold"] = (d.kind() if was_dive else "counter") + ("_chain" if d.tackle_kind == "chain" else "")
		raid["hold_depth"] = depth_in(1 - raiding, raider.position)
		raid["hold_t"] = float(raid.t)
	if d == controlled and was_dive:
		tutorial_event.emit(d.kind() + "_hold")
	# One message per hold on him: the first hold's own, "Chain tackle!" when help first arrives, then none.
	if first:
		hud.event(tr(hold_key), Game.C_MAGENTA)
	elif not grapple.chain_called:
		grapple.chain_called = true
		hud.event(tr("EV_CHAIN"), Game.C_MAGENTA)
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
		_event("bonus", {"airborne": airborne})
		hud.event(tr("EV_BONUS_AIR") if airborne else tr("EV_BONUS"), Game.C_GOLD, false, MatchHud.EV_TOUCH)
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
		if holders.size() > 0 and _over_midline():
			# Held, he has got back to the midline: a foot dragged onto it, or any of him down on it or beyond it.
			_end_raid("return")
			return
	# Down he goes once the struggle is won, but only when every hold on him is a hold (Grapple.established):
	# a team-mate who has just got his hands on him heaves with the rest first.
	var holds_set: bool = grapple == null or grapple.established()
	if holders.size() >= 3 and raid.progress > 0.5 and holds_set:
		_end_raid("tackle")
		return
	if raid.progress >= 1.0 and holds_set:
		_end_raid("tackle")
		return
	if raid.t <= 0.0:
		_end_raid("time" if raid_rule == RULE_CLOCK else "cant")


## Whether the raider, as drawn, has any of himself on the midline or over it into his own half: a toe or foot, a
## knee, his middle, or a hand down at the floor (a hand held up over the line has not touched it). Held, that is
## home. (It was being within his reach of the line, 0.86 m, stretched out or not: he was given the points
## standing short of it.)
func _over_midline() -> bool:
	var opp := 1 - raiding
	var on := Arena.LINE_W * 0.8   # the midline's half width
	if raider.model == null:
		return depth_in(opp, raider.position) < on
	for part in ["toe_l", "toe_r", "foot_l", "foot_r", "knee_l", "knee_r", "waist", "hand_l", "hand_r"]:
		var p: Vector3 = raider.model.anchor(part)
		var low: float = {"hand": 0.35, "knee": 0.25}.get(part.substr(0, part.length() - 2), INF)
		if depth_in(opp, p) < on and p.y < low:
			return true
	return false


# ---------------------------------------------------------------- scoring

func _end_raid(kind: String) -> void:
	if phase != "raid":
		return
	_set_phase("post")
	raider.held_by = 0
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
			# Caught by the ankle, he trips and goes down with the foot still held; the holders keep hold
			# until he is down (Grapple.takedown).
			raider.fall_kind = grapple.fall_kind() if grapple and not grapple.holds.is_empty() else ""
			# Held only by the ankle, he goes down forward, away from the hold (the leg pulled out from under him);
			# with arms round him as well he goes down the way they hold him.
			var away := grapple.away_from_hold() if grapple and grapple.ankle_only() else Vector3.ZERO
			if away != Vector3.ZERO:
				raider.facing = away
			raider.vel = Vector3.ZERO   # going down: the struggle's push is spent, not carried along the floor
			raider.set_state("fallen")
			raider.remove_meta("landed")
			if grapple and not grapple.holds.is_empty():
				grapple.takedown()
			# Time to go down, lie there a moment and get up at a person's pace (_tick_post).
			raid["post_extra"] = 1.8
			_event("takedown", {"raider": raider.pid(), "holders": holders_copy().map(func(h): return h.pid()),
				"grapple": grapple.id if grapple else 0})
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

	raid_log.append({"team": atk, "kind": kind, "raider_out": raider_out, "raid_pts": raid_pts, "def_pts": def_pts, "touches": touched.size(), "bonus": bonus, "t": float(raid.air_max) - float(raid.t), "moves": raid.moves.duplicate(), "chain_caught": raid.chain_caught, "def_moves": raid.def_moves.duplicate(), "first_hold": raid.get("first_hold", ""), "hold_depth": raid.get("hold_depth", -1.0), "held_for": float(raid.get("hold_t", raid.t)) - float(raid.t), "holders_end": raid.holders.size(), "vias": raid.get("vias", []), "probe_t": float(raid.get("probe_t", 0.0))})
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
					# The last man, tackled and going down (or anyone in the middle of a move), finishes it first and
					# then walks back: set walking at once, he was up and off in a frame with his holders still on
					# him, and they were swung round with him.
					if a.state not in BUSY:
						a.set_state("walk")
			teams[t].out_queue.clear()
	_milestones()
	if raid_pts > def_pts:
		officials.signal_points(atk, all_out, raid_pts + (2 if all_out else 0), bonus > 0)
	elif def_pts > 0:
		officials.signal_points(dfn, all_out, def_pts + (2 if all_out else 0))
	var holders_were := holders_copy()
	for h in holders_were:
		if grapple and grapple.has(h):
			if kind == "tackle":
				continue   # still holding as he goes down; up after (_tick_post)
			# The raid is over with him holding on: he lets go (and gets up, if he was down holding a leg).
			var low := grapple.style_of_hold(h) in ["ankle", "thigh"]
			grapple.release(h)
			if low:
				h.set_state("recover", 0.8)
			else:
				h.set_state("ready")
		else:
			h.set_state("ready")
	raid.holders = []
	_event("raid_end", {"kind": kind, "raid_pts": raid_pts, "def_pts": def_pts, "raider_out": raider_out})
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
		hud.event(m[0], m[1], false, MatchHud.EV_RESULT)
	if raid_pts + def_pts > 0:
		hud.event(tr("EV_POINTS").format({"n": raid_pts + def_pts}), Game.C_INK, true, MatchHud.EV_RESULT)
	clock = maxf(0.0, clock - RAID_GAP * clock_speed)


## A reaction to the end of the raid (the codes _after_getup takes): now if he is on his feet and between moves, else
## once he is up or down from the move (BUSY; _tick_post, _after_getup).
func _react_as(a: Athlete, how: int) -> void:
	a.set_meta("cheer", how)
	if a.state not in BUSY:
		_after_getup(a)


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
## Lying on the floor holding the raider (or getting up from it): cheering waits until he is on his feet.
func _on_floor(a: Athlete) -> bool:
	return a.state in ["holding", "recover", "rise"]


## A gameplay event, as it really happened (the HUD's messages follow these): "tackle_attempt" (a dive),
## "tackle_contact" (a hand or body reached him), "grip_lost", "hold" (a hold confirmed; "pile" for help),
## "grab_missed" (a touched defender's grab back, out of reach by then), "release", "escape" (with the hold it
## slipped and whether he is free), "takedown", "touch", "raid_end". Each gets a number, in order.
func _event(kind: String, info := {}) -> void:
	_event_n += 1
	info["n"] = _event_n
	event_log.append([snappedf(half_len - clock, 0.01), raid_log.size() + 1, kind, info])
	if event_log.size() > 400:
		event_log.pop_front()
	if cam:
		cam.on_event(kind)
	game_event.emit(kind, info)


func _react(kind: String, raid_pts: int, def_pts: int, raider_out: bool, touched: Array, holders_were: Array) -> void:
	var atk: int = raiding
	var dfn := 1 - raiding
	if raid_pts > 0 and not raider_out:
		var big := raid_pts >= 3 or on_mat(dfn).is_empty()
		var mates := on_mat(atk)
		var buddy := _nearest_mate(raider, mates)
		var r := rng.randf()
		if buddy != null and r < (0.45 if big else 0.25) and raider.state not in BUSY:
			_high_five(raider, buddy)
		elif big or r < 0.55:
			_react_as(raider, -2)
		elif r < 0.75:
			_react_as(raider, CELE_FIST)
		elif r < 0.85:
			_react_as(raider, CELE_POINT)
		# Otherwise he just jogs back: job done.
		if raider.state in ["roar", "celebrate"] or rng.randf() < 0.4:
			hud.bubble(raider, tr("BUBBLE_HAAN") if rng.randf() < 0.5 else tr("BUBBLE_AAJA"), Game.C_GOLD)
			Sfx.yell("haan" if rng.randf() < 0.5 else "aaja", -2.0)
		for a in mates:
			if a != raider and a.state in ["idle", "ready"] and rng.randf() < (0.8 if big else 0.3):
				_celebrate(a, [CELE_ARMS, CELE_CLAP, CELE_FIST, CELE_CLAP][rng.randi() % 4] if not big else -1)
		for d in touched:
			_react_as(d, -5)
		# Sometimes the defence disputes the touch (one on his feet).
		var defs := on_mat(dfn)
		if not defs.is_empty() and rng.randf() < 0.35:
			var who: Athlete = defs[rng.randi() % defs.size()]
			if who.state not in BUSY:
				who.set_state("argue")
				who.face_toward(Vector3(Arena.HALF_W + 3.0, 0, 0), 1.0, 100.0)
				hud.bubble(who, tr("BUBBLE_NO_TOUCH"), Game.C_INK)
				Sfx.yell("nahi", -6.0)
	elif def_pts > 0:
		var big := def_pts >= 2
		var stars: Array = holders_were.duplicate()
		if stars.size() >= 2 and rng.randf() < 0.45 and not _on_floor(stars[0]) and not _on_floor(stars[1]):
			_high_five(stars[0], stars[1])
		for d in stars:
			if d.state == "celebrate":
				continue
			var r := rng.randf()
			var how := -2 if big or r < 0.5 else (CELE_FIST if r < 0.68 else CELE_THUMP) if r < 0.8 else -3
			if _on_floor(d):
				d.set_meta("cheer", how)   # once he is up (_tick_post)
			elif how == -2:
				d.set_state("roar")
			elif how >= 0:
				_celebrate(d, how)
		for d in on_mat(dfn):
			if not stars.has(d) and rng.randf() < (0.85 if big else 0.3):
				_react_as(d, -1 if big else [CELE_CLAP, CELE_FIST, CELE_ARMS][rng.randi() % 3])
		if not stars.is_empty():
			var lead: Athlete = stars[0]
			hud.bubble(lead, tr("BUBBLE_SHABASH"), Game.C_MAGENTA.lightened(0.3))
			Sfx.yell("shabash", -3.0)
		var standing := holders_were.filter(func(h): return not _on_floor(h))
		if kind == "tackle" and not standing.is_empty() and rng.randf() < 0.35:
			# A shove as the raider gets up; he claims he got a touch.
			var pusher: Athlete = standing[rng.randi() % standing.size()]
			pusher.set_state("shove")
			pusher.shove_target = raider
			if rng.randf() < 0.4:
				_card(pusher)
			_react_as(raider, -6)   # once he is up
			hud.bubble(raider, tr("BUBBLE_TOUCH"), Game.C_INK)
			Sfx.yell("touch", -5.0)
		elif kind != "tackle":
			_react_as(raider, -5)
		for a in on_mat(atk):
			if a != raider and rng.randf() < 0.5:
				_react_as(a, -5)


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
			_event("chain_broken", {"who": [d.pid(), p.pid()]})
			hud.event(tr("EV_BROKE_FREE"), Game.C_GOLD, true, MatchHud.EV_FREE)
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
	if a.state not in BUSY:
		a.set_state("walk")   # down or in a move, he gets up or lands first, then walks off (_to_bench)


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
			hud.event(tr("EV_SUSPENSION_OVER").format({"name": a.display_name()}), Game.C_GOOD, false, MatchHud.EV_INFO)


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
		if a.state not in BUSY:
			a.set_state("walk")   # (down or in a move, he finishes it first, as at an all out)
		revived += 1
	if revived > 0:
		_post_messages.append([tr("EV_REVIVED").format({"n": revived}), Game.C_GOOD])


func _tick_post(dt: float) -> void:
	# Let the moment breathe, then reset.
	_audit("start")
	_aim_limb()   # a touch or kick the raid ended in the middle of reaches on to its end, then lets go
	if grapple:
		grapple.update(dt)
	_audit("grapple")
	for a in athletes:
		# Caught in the middle of a move as the raid ended, a player finishes it as he would have: a dive lands and
		# he gets up; a wind-up comes to nothing; any other move (the raider's jump or dubki over the line, a kick, a
		# sidestep) runs its course and he stands, rather than walking back held in its last frame.
		if a.state == "dive" and a.st_t >= a.st_len:
			_land(a, 0.9)
		elif a.state == "telegraph":
			a.set_state("ready")
		elif a.state in ["touch", "kick", "backkick", "shoved", "dodge", "dubki", "jump", "evade"] and a.st_t >= a.st_len:
			_after_getup(a)   # stands, or the reaction waiting for him (_react_as)
		# Holders let go once he is down, each at his own moment (Grapple.takedown), and get up from where they are;
		# one under the man on the floor waits for him to get off first. Then they cheer.
		if a.state == "holding" and (grapple == null or not grapple.has(a)):
			if not a.has_meta("under"):
				_get_up_from_hold(a)
			elif raider == null or raider.state != "fallen":
				a.remove_meta("under")
				_get_up_from_hold(a)
		# The tackled raider: once he is down (the floor, not the takedown, is the thud), a moment there, then up
		# at a person's pace (the get-up clip's own length), and a breath on his feet before he walks off.
		if a.state == "fallen":
			var down: float = a.model.down_for if a.model else -1.0
			if down >= 0.0 and not a.has_meta("landed"):
				a.set_meta("landed", true)
				Sfx.play("thud", 2.0, 0.8)
			if down >= LIE_TIME or phase_t > 3.0:
				a.set_state("recover", GETUP_RAIDER)
				if not a.has_meta("cheer"):
					a.set_meta("cheer", -4)
		if a.state in ["recover", "rise"] and a.st_t >= a.st_len:
			_after_getup(a)
		if a.has_meta("cheer_at") and phase_t >= float(a.get_meta("cheer_at")):
			a.remove_meta("cheer_at")
			_after_getup(a)
		if a.has_meta("walk_at") and phase_t >= float(a.get_meta("walk_at")):
			a.remove_meta("walk_at")
			if a.state == "idle":
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
			if phase_t <= 1.0:
				a.drive(Vector3.ZERO, dt)   # (from a second in, _walk_to_positions walks him: both drove him twice a frame)
		elif not a.on_mat:
			# Out: off to the bench (or slowing to a stop where he is first, slumping or arguing) from the moment the raid
			# ends, not stood still and then sliding off on the speed he had. From a second in, _walk_to_positions.
			if phase_t <= 1.0:
				_to_bench(a, dt)
		elif a.state in ["walk", "sit"]:
			pass
		elif a.state == "holding":
			pass   # the grapple moves him (driving him as well would move him twice)
		elif phase_t <= 1.0:
			a.drive(Vector3.ZERO, dt)   # (from a second in, _walk_to_positions moves him: both moved him twice a frame)
	# Walking back and cheering, players do not walk through one another, nor through anyone on the floor, getting up
	# or still holding (_keep_apart): a player put out too, walking off through his team-mates (the bench aside, and the
	# raider, who is not moved).
	_audit("post")
	var around := athletes.filter(func(a): return a != raider and (a.on_mat or absf(a.position.z) < Arena.HALF_L + 1.5))
	var down := around.filter(func(a): return a.state in DOWN_STATES)
	if raider.state in DOWN_STATES:
		down.append(raider)
	_keep_apart(around.filter(func(a): return a.state in ["ready", "idle", "celebrate", "roar", "slump", "walk", "argue"]), down)
	_push_all(dt)
	_audit("apart")
	if phase_t > 1.0:
		_walk_to_positions(dt, false)
	_audit("walk")
	if phase_t > 2.6 + float(raid.get("post_extra", 0.0)):
		_next_raid()


## A holder who has let go after a takedown gets up from where he is, at his own pace: lying on the floor (an ankle
## hold, or ridden down flat), all the way up (the get-up clips); down on his knees or crouched over a leg, up off
## his knees; still on his feet, bent over the raider, he straightens up. One lying under the man on the floor (his
## middle within a body's width of the raider's trunk) stays down until the raider gets off him.
func _get_up_from_hold(a: Athlete) -> void:
	a.vel = Vector3.ZERO   # what the grapple last moved him by is not his own running
	var low: float = a.model.anchor("waist").y if a.model else 1.0
	var pace := 0.9 + 0.25 * float(absi(hash(a.pid())) % 100) / 100.0
	if low < 0.42 and raider and raider.state == "fallen" and raider.model and a.model:
		var rw: Vector3 = raider.model.anchor("waist")
		var rs: Vector3 = (raider.model.anchor("shoulder_l") + raider.model.anchor("shoulder_r")) * 0.5
		var aw: Vector3 = a.model.anchor("waist")
		if Grapple._seg_dist(Vector3(aw.x, 0.0, aw.z), Vector3(rw.x, 0.0, rw.z), Vector3(rs.x, 0.0, rs.z)) < 0.3:
			a.set_meta("under", true)
			return
	if low < 0.42:
		a.set_state("recover", GETUP_HOLDER * pace)
	elif low < 0.75:
		a.set_state("rise", RISE_KNEES * pace)
	else:
		a.set_state("rise", RISE_BENT * pace)


## Up off the floor (or out of a bend): what he does next, as _react decided (meta "cheer").
func _after_getup(a: Athlete) -> void:
	var how: int = a.get_meta("cheer", -3)
	a.remove_meta("cheer")
	match how:
		-2:
			a.set_state("roar")
		-5:
			a.set_state("slump")
		-6:
			a.set_state("argue")
		-4:
			a.set_state("idle")
			a.set_meta("walk_at", phase_t + 0.5)   # a breath on his feet, then off he walks
		-3:
			a.set_state("idle")
		_:
			_celebrate(a, how)


func _next_raid(after_timeout := false) -> void:
	for a in athletes:
		a.cele_partner = null
		a.remove_meta("fived")
		a.remove_meta("cheer")
		a.remove_meta("cheer_at")
		a.remove_meta("grab_at")
		a.remove_meta("chain_go")
		a.remove_meta("under")
		if a.has_meta("walk_at"):
			a.remove_meta("walk_at")
			if a.state == "idle" and not a.on_mat:
				a.set_state("walk")
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
	hud.event(tr("EV_TOSS").format({"team": String(teams[raiding].id)}), Game.C_GOLD, false, MatchHud.EV_INFO)
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
