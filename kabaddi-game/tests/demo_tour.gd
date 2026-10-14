extends Node
## A tour of the game for a video, with its sound: the home screen and its music, the Quick Match screen, then a
## quick match in which the player's raids are played through the controls a thumb would use (the stick and the
## buttons, drawn on screen as it is pressed): in at a defender, a toe touch or a hand touch, back home, and Break
## free when he is held. The player's team defends by itself (the AI). Partway, the pause menu; after a few raids
## the match is ended and the result screen shown.
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . --rendering-driver opengl3 --resolution 1560x720 \
##       --write-movie out.avi --fixed-fps 30 res://tests/demo_tour.tscn [-- RAIDS]
## Movie Maker records at the project's window size whatever --resolution says (1280x720, with a 1560-wide game laid
## out in it, cropped): for a phone's 19.5:9, record from a copy of the project with
## display/window/size/window_width_override=1560 and window_height_override=720 in project.godot.
## It prints what happens and when ("TOUR 12.3 s ..."), to cut the recording by.

var m: Node = null
var _t := 0.0           # s since the tour began (the movie's clock)
var _step := "menu"
var _step_t := 0.0
var _raids := 5         # the player's raids before the match is ended
var _ours := 0          # the player's raids so far
var _bot := {}          # this raid's plan: target, stage, when
var _last_phase := ""
var _paused_once := false
var _pause_t := -1.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		_raids = int(args[0])
	Game.main = self
	Game.settings.sound = true
	Game.settings.music = true
	Game.settings.graphics = Game.GFX_MEDIUM   # the default, as on a phone
	Game.settings.auto_gfx = false
	Game.show_screen("res://ui/main_menu.gd")
	_say("home screen")


func _say(what: String) -> void:
	print("TOUR %.1f s %s" % [_t, what])


func _process(delta: float) -> void:
	_t += delta
	_step_t += delta
	match _step:
		"menu":
			if _step_t > 9.0:
				Game.show_screen("res://ui/quick_setup.gd")
				_go("setup_screen")
		"setup_screen":
			if _step_t > 3.5:
				Game.start_match({"home": "MUM", "away": "PAT", "arena": "dome", "mode": "quick", "control": "all",
					"length": 0, "difficulty": 1, "knockout": false})
				m = Game.current
				_go("match")
		"match":
			_drive(delta)
		"result":
			if _step_t > 8.0:
				_say("end")
				get_tree().quit()


func _go(step: String) -> void:
	_step = step
	_step_t = 0.0
	_say(step)


## The match, frame by frame (this node runs before the match each frame: it sees the last frame).
func _drive(dt: float) -> void:
	if not is_instance_valid(m) or Game.current != m:
		# The match is over and the result screen is up.
		_go("result")
		return
	var c: TouchControls = m.controls
	var phase: String = m.phase
	if phase != _last_phase:
		_say("phase " + phase + ("" if m.raider == null else " (raider %s)" % m.raider.display_name()))
		_last_phase = phase
		if phase == "setup":
			_bot = {}
		if phase == "post" and not m.raid_log.is_empty():
			var e: Dictionary = m.raid_log[-1]
			_say("  %s raid: %s, raid points %d, defence points %d, touches by %s" % ["our" if int(e.team) == 0 else "their",
				String(e.kind), int(e.raid_pts), int(e.def_pts), str(e.get("vias", []))])
	if phase == "intro" and _step_t > 2.0:
		c._fire("skip")
	# The pause menu, once, as the player's third raid is set up.
	if phase == "setup" and m.raiding == 0 and _ours == 2 and not _paused_once and m.phase_t > 0.5:
		_paused_once = true
		_pause_t = _t
		c._fire("pause")
		_say("pause menu")
	if m.paused:
		if _pause_t >= 0.0 and _t - _pause_t > 3.5:
			c._fire("pause")
			_pause_t = -1.0
			_say("resume")
		return
	if m.raiding == 1 and phase in ["setup", "raid"] and m.controlled != null:
		# Defending: the AI plays the player's defenders too.
		m.controlled.set_ring(Color(0, 0, 0, 0))
		m.controlled = null
		for a in m.athletes:
			a.is_user = false
	if phase == "raid" and m.raider != null and m.controlled == m.raider:
		_raid(dt, c)
	else:
		_stick(c, Vector3.ZERO)
	if phase == "post" and m.raiding == 0 and not _bot.has("counted"):
		_bot["counted"] = true
		_ours += 1
		_say("our raid %d over" % _ours)
	if _ours >= _raids and phase == "setup" and m.phase_t > 1.0:
		_say("full time")
		m._end_match()


## The player's raid: in at the nearest defender, a toe touch (or a hand touch every other raid) from where the leg
## or arm reaches him, then home, pressing Break free whenever he is held.
func _raid(_dt: float, c: TouchControls) -> void:
	var r: Athlete = m.raider
	var home := Vector3(0, 0, m.side(m.raiding))
	if not _bot.has("stage"):
		_bot = {"stage": "in", "since": _t, "move": "kick" if _ours % 2 == 0 else "touch", "dodge_t": 0.0}
	var held: bool = not (m.raid.get("holders", []) as Array).is_empty()
	if held:
		if _t - float(_bot.dodge_t) > 0.55:
			_bot.dodge_t = _t
			c._fire("dodge")
			_say("break free pressed")
		_stick(c, home)
		return
	if String(_bot.stage) == "in":
		var target: Athlete = null
		var bd := INF
		for d in m.defenders():
			if d.touched:
				continue
			var dd: float = d.position.distance_to(r.position)
			if dd < bd:
				bd = dd
				target = d
		if target == null or _t - float(_bot.since) > 9.0:
			_bot.stage = "home"
			return
		var to: Vector3 = target.position - r.position
		to.y = 0.0
		var reach := 1.15 if String(_bot.move) == "kick" else 1.0
		if to.length() < reach and r.state == "raid" and r.cooldown <= 0.0:
			_stick(c, to.normalized() * 0.3)
			c._fire(String(_bot.move))
			_say("%s at %s from %.2f m" % [_bot.move, target.display_name(), to.length()])
			_bot.stage = "home"
			_bot.since = _t
			return
		# Toward him, slowing as he gets near.
		var spot: Vector3 = target.position + home * 0.9
		var go := spot - r.position
		go.y = 0.0
		_stick(c, go.normalized() * clampf(go.length() * 0.6, 0.35, 0.85))
		return
	# Home, once the touch has had its moment.
	if _t - float(_bot.since) > 0.45:
		_stick(c, home)


## Holds the on-screen stick so the world direction w comes out of it (CameraRig.input_to_world), drawn as a thumb
## on the stick.
func _stick(c: TouchControls, w: Vector3) -> void:
	if w.length() < 0.05:
		if c._stick_id == 99:
			c._stick_id = -1
			c._stick_vec = Vector2.ZERO
			c.queue_redraw()
		return
	var fwd: Vector3 = m.cam.flat_forward()
	var right := Vector3(-fwd.z, 0, fwd.x)
	var v := Vector2(w.dot(right), -w.dot(fwd))
	var s := c.get_viewport_rect().size
	c._stick_id = 99
	c._stick_origin = Vector2(170.0 if not Game.settings.left_handed else s.x - 170.0, s.y - 160.0)
	c._stick_vec = v.limit_length(1.0)
	c.queue_redraw()
