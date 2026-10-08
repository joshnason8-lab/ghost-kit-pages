extends Node
## A bot that plays a match the way a person would: it moves the on-screen thumbstick and
## presses the same buttons (Cant on the beat, Hand touch, Kick, Dodge, Dubki, Lion jump;
## Ankle/Thigh/Waist hold, Dash, Chain), so the controls light up as it plays. Run with
## Godot's movie writer to make a gameplay video:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --write-movie out.avi --fixed-fps 30 \
##       res://tests/play_video.tscn -- SECONDS

var m: Node
var seconds := 90.0
var _t := 0.0
var _plan := ""           # raid plan: approach, probe, home
var _mark: Athlete = null
var _cd := 0.0            # button cooldown so presses look human
var _last_beat := -1
var _linked_raid := -1
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		seconds = float(args[0])
	_rng.seed = 7
	Game.main = self
	Game.settings.graphics = Game.GFX_HIGH
	Game.settings.camera = Game.CAM_THIRD
	Game.start_match({"home": "MUM", "away": "CHD", "arena": "dome", "mode": "quick", "control": "all",
		"length": 0, "difficulty": 1, "first_raider": 0, "raid_rule": 1, "autoplay_no_report": true})
	m = Game.current


func _process(delta: float) -> void:
	_t += delta
	if _t > seconds:
		get_tree().quit()
		return
	if m == null or not is_instance_valid(m):
		return
	_cd = maxf(0.0, _cd - delta)
	var c: TouchControls = m.controls
	if m.phase == "intro" and _t > 2.5:
		c._fire("skip")
	if m.phase != "raid" or m.controlled == null:
		_stick(Vector3.ZERO)
		if m.phase == "setup":
			_plan = "approach"
			_mark = null
		return
	if m.controlled == m.raider:
		_raid(delta)
	else:
		_defend(delta)


## Push the thumbstick toward a ground direction (drawn on screen like a real thumb).
func _stick(dir: Vector3) -> void:
	var c: TouchControls = m.controls
	if dir.length() < 0.05:
		c._stick_id = -1
		c._stick_vec = Vector2.ZERO
		c.queue_redraw()
		return
	var fwd: Vector3 = m.cam.flat_forward()
	var right := Vector3(-fwd.z, 0, fwd.x)
	var v := Vector2(dir.dot(right), -dir.dot(fwd)).limit_length(1.0)
	c._stick_id = 99
	c._stick_origin = Vector2(170, c.get_viewport_rect().size.y - 160)
	c._stick_vec = v
	c.queue_redraw()


func _press(id: String, cooldown := 0.25) -> void:
	if _cd > 0.0:
		return
	m.controls._fire(id)
	_cd = cooldown


func _raid(_dt: float) -> void:
	var r: Athlete = m.raider
	var opp: int = 1 - m.raiding
	var home := Vector3(0, 0, m.side(m.raiding))
	# Chant on every beat.
	var beat := int(floor(float(m.raid.beat_t) / m.BEAT + 0.08))
	if m.raid.cant_tap and beat != _last_beat and fmod(float(m.raid.beat_t), m.BEAT) < 0.06:
		_last_beat = beat
		m.controls._fire("cant")
	# Held: push for the line and use the right escape.
	if m.raid.holders.size() > 0:
		_stick(home)
		var h: String = m.escape_hint()
		_press(h if h != "" else "dodge", 0.7)
		return
	# A tackle coming: read it.
	var hint: String = m.escape_hint()
	if hint != "" and _rng.randf() < 0.5:
		_press(hint, 0.8)
	var depth: float = m.depth_in(opp, r.position)
	match _plan:
		"approach":
			_stick((m.pos_in(opp, 0.6, 4.0) - r.position).normalized())
			if depth > Arena.BAULK + 0.2:
				_plan = "probe"
		"probe":
			if _mark == null or _mark.touched or not _mark.on_mat:
				_mark = _pick_mark()
			if _mark == null or float(m.raid.t) < 8.0 or m.raid.touched.size() > 0:
				_plan = "home"
				return
			var to: Vector3 = _mark.position - r.position
			to.y = 0
			var stand: Vector3 = _mark.position + home * 1.1
			var go: Vector3 = stand - r.position
			go.y = 0
			_stick(go.normalized() * clampf(go.length(), 0.25, 1.0))
			if to.length() < r.reach + 0.45:
				_press("touch" if _rng.randf() < 0.6 else "kick", 0.6)
		_:
			# Home, swerving away from the closest defender; a back kick if one chases.
			var away := Vector3.ZERO
			for d in m.defenders():
				var off: Vector3 = r.position - d.position
				off.y = 0
				if off.length() < 1.8 and off.length() > 0.01:
					away += off.normalized() * (1.8 - off.length())
					if not d.touched and r.facing.dot(-off.normalized()) < -0.4 and off.length() < 1.6:
						_press("kick", 0.9)
			away.z = 0
			_stick((home + away * 0.6).normalized())


func _pick_mark() -> Athlete:
	var best: Athlete = null
	var bd := 1e9
	for d in m.defenders():
		if d.touched or d.state == "holding":
			continue
		var dist: float = d.position.distance_to(m.raider.position)
		if dist < bd:
			bd = dist
			best = d
	return best


func _defend(_dt: float) -> void:
	var d: Athlete = m.controlled
	var r: Athlete = m.raider
	var to: Vector3 = r.position - d.position
	to.y = 0
	var dist := to.length()
	# Link hands once per raid while the raider is still coming.
	if _linked_raid != m.raid_log.size() and d.chain_partner == null and m.depth_in(d.team, r.position) < 1.0:
		_linked_raid = m.raid_log.size()
		_press("chain", 0.4)
	# Shadow the raider from the midline side, a couple of metres off.
	var mid := Vector3(0, 0, -m.side(d.team))
	var spot: Vector3 = r.position - mid * -1.6
	if m.depth_in(d.team, spot) < 0.6:
		spot.z = m.side(d.team) * 0.6
	var go: Vector3 = spot - d.position
	go.y = 0
	_stick(go.normalized() * clampf(go.length(), 0.0, 1.0) if go.length() > 0.3 else Vector3.ZERO)
	# Go in when he is close and committed: turning for home, mid-touch or near a line.
	var turning: bool = r.vel.dot(mid) > 1.0
	var committed: bool = r.state in ["touch", "kick", "backkick"]
	if dist < 1.7 and m.depth_in(d.team, r.position) > 0.8 and (turning or committed or m.defend_hint() != ""):
		var hint: String = m.defend_hint()
		var kind = hint if hint != "" else ["ankle", "thigh", "waist"][_rng.randi() % 3]
		_press(kind, 1.2)
	elif dist > 4.0:
		_press("switch", 1.5)
