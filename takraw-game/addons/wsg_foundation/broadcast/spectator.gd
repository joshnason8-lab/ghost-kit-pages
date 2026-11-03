class_name WsgSpectator
extends Node3D
## Watch mode: the game's AI against itself, shown as television shows a match. The game keeps its own match (the
## menu entry, the teams, the rules, the AI); this gives it the picture and the controls:
##   the follow camera: on a rail along one touchline (or fixed high on it), framing the ball and the nearest players,
##          eased (critically damped, a dead zone round its aim) and never crossing the line (the 180-degree rule:
##          always on its own side of the pitch's long axis);
##   moments: at a score, a WsgDirector package (a close-up, the crowd) where the tier allows it, then a replay of
##          the last seconds (if the game gives it its WsgReplay), then the follow camera again; a cooldown and a cap
##          a match keep them from stacking;
##   speed: 1x or 2x (Engine.time_scale, with the physics ticks scaled so a physics step stays as long in game time:
##          the AI runs the same steps, only faster), restored exactly by stop();
##   pause, exit (Back / Escape), a HUD toggle for the game's own HUD, and an optional minimal overlay (the score bug,
##          the clock, pause, speed and exit buttons) for a game without one.
##   var spec := WsgSpectator.new(); add_child(spec)
##   spec.long_axis = Vector3.RIGHT; spec.replay = my_replay          # (optional) its WsgReplay
##   spec.start(game_camera)                                          # its camera now; game_camera current again on stop()
##   spec.focus_source = func(): return [ball.global_position, my_players_positions()]   # or set_focus(...) every frame
##   spec.exit_requested.connect(func(): spec.stop(); back_to_menu())
##   spec.moment("score", {"target": scorer})                          # at a score: cut-aways, replay, back
## Moments run at 1x (then the chosen speed again); the director's own camera is the spectator's live one, so its
## close-ups keep to the same side of the line.

## A moment begins (kind, data as given to moment()) and ends: hold your restart till moment_finished if you like.
signal moment_started(kind: String, data: Dictionary)
signal moment_finished(kind: String)
## Show or hide the game's own HUD (connect it to your HUD's visible): hidden during a moment's cut-aways and replay,
## and on toggle_hud().
signal hud_visible(visible: bool)
## Paused (true) or resumed (false): pause your match's AI and clock on it (or set pause_tree).
signal paused(on: bool)
## The player asked to leave (Back, Escape, the overlay's exit): call stop() and go back to your menu.
signal exit_requested
signal speed_changed(speed: float)
## Each frame of a moment's replay, the replay's time (the game's clock, as given to WsgReplay.record): draw your own
## things (the ball, bodies that are not the foundation's) as they were then.
signal replay_frame(t: float)

## The pitch: its middle, its long axis (world, horizontal; the camera's touchline is on the side of
## long_axis x up, or the other with side = -1).
var pitch_center := Vector3.ZERO
var long_axis := Vector3.RIGHT
var side := 1.0
## The camera: on a rail along the touchline (rail; following the play along it by rail_follow, no farther than
## rail_limit from the middle), or fixed high at the halfway line (rail false: it only turns and zooms).
var rail := true
var rail_follow := 0.85
var rail_limit := 40.0
## m above the pitch, and out from the long axis (on its side).
var height := 14.0
var distance := 30.0
## Vertical field of view, degrees: as tight as frames the play, within these.
var fov_min := 24.0
var fov_max := 55.0
## How many players nearest the ball it frames (with the ball), and the room round them (1.0: just in).
var nearest := 4
var frame_pad := 1.3
## s: how long the camera takes to catch up (critically damped: no overshoot). Real seconds (the same at 2x).
var smooth_time := 0.7
## m: the play moves this far from the camera's aim before the camera follows (no drift on every touch).
var dead_zone := 2.5
## m: the aim above the play's ground (the players' chests).
var look_lift := 1.0

## Moments: real seconds from the end of one to the next, and how many a match (0: no cap).
var cooldown := 20.0
var max_moments := 8
## The game's WsgReplay (null: no replays): the last replay_secs of it shown at replay_rate (0.5: half speed).
var replay: WsgReplay
var replay_secs := 4.0
var replay_rate := 0.5
## The stand for the default package's crowd shot (Vector3.INF: none) and where it is seen from (INF: the director's).
var crowd_at := Vector3.INF
var crowd_from := Vector3.INF
## Hide the game's HUD (hud_visible false) during a moment.
var hide_hud_in_moments := true

## The speeds the speed button cycles through.
var speeds: Array = [1.0, 2.0]
## Also pause the scene tree on pause() (the spectator and its overlay keep running). Off: the game pauses its own
## match on `paused`.
var pause_tree := false
## The action that asks to leave (Escape is ui_cancel; Android's Back comes as a go-back request, and KEY_BACK).
var exit_action := "ui_cancel"

## A function returning [ball: Vector3, players: Array of Vector3] (or {"ball":, "players":}), called every frame;
## or call set_focus() yourself.
var focus_source := Callable()

var camera: Camera3D
var director: WsgDirector
## The overlay (make_overlay): its layer and score bug, null until made.
var overlay: CanvasLayer
var scorebug: WsgScorebug
var lower_third: WsgLowerThird
var theme_b: WsgBroadcastTheme

var running := false
var is_paused := false
var in_moment := false
## A Skip button over a moment's cut-aways and replay (and a tap anywhere skips too: the owner's games all have one);
## made with the overlay or by skip_button(), shown only during a moment.
var tap_to_skip := true
var _skip_layer: CanvasLayer
var _skip_btn: Button
var speed := 1.0
var moments_run := 0
var hud_shown := true
## The camera's aim now (world), eased.
var aim := Vector3.ZERO

var _ball := Vector3.ZERO
var _players: Array = []
var _has_focus := false
var _goal := Vector3.ZERO
var _aim_v := Vector3.ZERO
var _along := 0.0
var _along_v := 0.0
var _fov := 40.0
var _fov_v := 0.0
var _snap := true
var _game_camera: Camera3D
var _saved := []                    # [time_scale, physics ticks, max steps] before the spectator changed them
var _clock := 0.0                   # real seconds while running and not paused
var _last_end := -INF
var _moment_seq := 0
var _pause_btn: Button
var _speed_btn: Button
var _tree_was_paused := false
var _moment_kind := ""


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Takes the picture (its own camera current; the game's camera kept to give back on stop()).
func start(game_camera: Camera3D = null) -> void:
	if running:
		return
	_game_camera = game_camera if game_camera else get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		camera = Camera3D.new()
		camera.name = "SpectatorCamera"
		camera.near = 0.2
		camera.far = 1200.0
		add_child(camera)
	if not is_instance_valid(director):
		director = WsgDirector.new()
		director.name = "Director"
		add_child(director)
	_save_engine()
	if not is_equal_approx(speed, 1.0):
		_apply_speed(speed)       # (a speed set before the start)
	running = true
	is_paused = false
	in_moment = false
	moments_run = 0
	_clock = 0.0
	_last_end = -INF
	_snap = true
	camera.make_current()
	_poll_focus()
	_follow(0.0)
	_set_hud(hud_shown)


## Gives the picture back: the speed and physics ticks as they were, its camera freed, the game's camera current.
func stop() -> void:
	if not running:
		return
	_end_moment()
	if is_paused and pause_tree and is_inside_tree():
		get_tree().paused = _tree_was_paused
	running = false
	is_paused = false
	_restore_engine()
	speed = 1.0
	if is_instance_valid(director):
		if director.running:
			# (Its shot list ends next frame: let it finish on its own, away from this node, then go.)
			director.skip()
			if is_inside_tree():
				director.reparent(get_tree().root)
			director.finished.connect(director.queue_free, CONNECT_ONE_SHOT)
		else:
			director.queue_free()
		director = null
	if is_instance_valid(camera):
		camera.current = false
		camera.queue_free()
		camera = null
	if is_instance_valid(_game_camera):
		_game_camera.make_current()
	if is_instance_valid(overlay):
		overlay.visible = false


## The play this frame: the ball, and the players (Vector3 positions; Node3Ds are read where they are).
func set_focus(ball_pos: Vector3, players: Array = []) -> void:
	_ball = ball_pos
	_players = players
	_has_focus = true


func pause() -> void:
	if not running or is_paused:
		return
	_end_moment()
	is_paused = true
	if pause_tree:
		_tree_was_paused = get_tree().paused
		get_tree().paused = true
	_update_buttons()
	paused.emit(true)


func resume() -> void:
	if not running or not is_paused:
		return
	is_paused = false
	if pause_tree:
		get_tree().paused = _tree_was_paused
	_update_buttons()
	paused.emit(false)


func toggle_pause() -> void:
	if is_paused:
		resume()
	else:
		pause()


## 1.0, 2.0 (or any of speeds): Engine.time_scale times what it was at start, the physics ticks (and the most steps a
## frame) times it too, so a physics step stays as long in game time. A moment runs at 1x and comes back to it.
func set_speed(s: float) -> void:
	speed = clampf(s, 0.1, 8.0)
	if running and not in_moment:
		_apply_speed(speed)
	_update_buttons()
	speed_changed.emit(speed)


## The next of speeds (the overlay's speed button).
func cycle_speed() -> void:
	var i := -1
	for k in speeds.size():
		if is_equal_approx(float(speeds[k]), speed):
			i = k
	set_speed(float(speeds[(i + 1) % speeds.size()]) if not speeds.is_empty() else 1.0)


func toggle_hud() -> void:
	_set_hud(not hud_shown)


## A big moment (a score, a save): the director's package where the tier allows it (WsgDirector.packages()), then a
## replay of the last replay_secs (with a replay), then the follow camera. Not while one runs, within cooldown of the
## last, after max_moments, or paused: false then. data (all optional):
##   "shots": a WsgDirector shot list (else: a close-up of "target", a Node3D, and the crowd at crowd_at);
##   "replay": false (no replay this time); "replay_secs": float;
##   "title", "sub", "colour": a lower third over the replay (with the overlay).
func moment(kind: String, data := {}) -> bool:
	if not running or is_paused or in_moment:
		return false
	if _clock - _last_end < cooldown:
		return false
	if max_moments > 0 and moments_run >= max_moments:
		return false
	moments_run += 1
	_run_moment(kind, data)
	return true


## Ends a running moment now (the follow camera back).
func skip_moment() -> void:
	_end_moment()


## The Skip button (bottom right, a thumb's size, the theme's look): shown only while a moment runs, pressed: the
## moment ends and the follow camera is back. Made by make_overlay too; call it for a game with its own HUD.
func skip_button(p_theme: WsgBroadcastTheme = null) -> Button:
	if is_instance_valid(_skip_btn):
		return _skip_btn
	if theme_b == null:
		theme_b = p_theme if p_theme else WsgBroadcastTheme.default()
	_skip_layer = CanvasLayer.new()
	_skip_layer.name = "SpectatorSkip"
	_skip_layer.layer = 21
	add_child(_skip_layer)
	var box := MarginContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 24)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip_layer.add_child(box)
	_skip_btn = _button(box, skip_moment)
	_skip_btn.text = tr("Skip") + " \u25B6"
	_skip_layer.visible = in_moment
	return _skip_btn


func _show_skip(on: bool) -> void:
	if is_instance_valid(_skip_layer):
		_skip_layer.visible = on


## The minimal overlay (for a game without its own HUD): the score bug, the clock, pause, speed and exit. Feed it
## with scorebug.setup / set_score / set_clock. Made once; shown with the HUD (hud_visible).
func make_overlay(p_theme: WsgBroadcastTheme = null) -> CanvasLayer:
	if is_instance_valid(overlay):
		return overlay
	theme_b = p_theme if p_theme else WsgBroadcastTheme.default()
	overlay = CanvasLayer.new()
	overlay.name = "SpectatorOverlay"
	overlay.layer = 20
	add_child(overlay)
	scorebug = WsgScorebug.new(theme_b)
	overlay.add_child(scorebug)
	lower_third = WsgLowerThird.new(theme_b)
	overlay.add_child(lower_third)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 18)
	bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.add_theme_constant_override("separation", 8)
	overlay.add_child(bar)
	_pause_btn = _button(bar, toggle_pause)
	_speed_btn = _button(bar, cycle_speed)
	var ex := _button(bar, func(): exit_requested.emit())
	ex.text = tr("Exit")
	_update_buttons()
	overlay.visible = hud_shown
	skip_button(theme_b)
	return overlay


func _button(parent: Control, on: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", theme_b.sub_size)
	b.add_theme_color_override("font_color", theme_b.text)
	for st in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(st, theme_b.style(theme_b.panel if st != "pressed" else theme_b.accent.darkened(0.4)))
	if theme_b.font:
		b.add_theme_font_override("font", theme_b.font)
	b.custom_minimum_size = Vector2(64, 48)    # (a thumb)
	b.pressed.connect(on)
	parent.add_child(b)
	return b


func _update_buttons() -> void:
	if is_instance_valid(_pause_btn):
		_pause_btn.text = tr("Play") if is_paused else tr("Pause")
	if is_instance_valid(_speed_btn):
		_speed_btn.text = ("%dx" % roundi(speed)) if is_equal_approx(speed, roundf(speed)) else ("%.1fx" % speed)


func _set_hud(v: bool) -> void:
	hud_shown = v
	if is_instance_valid(overlay):
		overlay.visible = v and running
	hud_visible.emit(v)


func _unhandled_input(event: InputEvent) -> void:
	if not running or event.is_echo():
		return
	var back: bool = event is InputEventKey and event.pressed and ((event as InputEventKey).keycode == KEY_BACK or (event as InputEventKey).keycode == KEY_ESCAPE)
	if in_moment and tap_to_skip and event.is_pressed() and (event is InputEventScreenTouch or event is InputEventMouseButton):
		get_viewport().set_input_as_handled()
		skip_moment()
		return
	if back or (exit_action != "" and InputMap.has_action(exit_action) and event.is_action_pressed(exit_action)):
		get_viewport().set_input_as_handled()
		exit_requested.emit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and running:
		exit_requested.emit()
	elif what == NOTIFICATION_PREDELETE and running:
		_restore_engine()


func _process(delta: float) -> void:
	if not running:
		return
	var real := delta / Engine.time_scale if Engine.time_scale > 0.0 else delta
	if is_paused:
		return
	_clock += real
	_poll_focus()
	_follow(real)


func _poll_focus() -> void:
	if focus_source.is_valid():
		var f: Variant = focus_source.call()
		if f is Dictionary:
			set_focus(f.get("ball", _ball), f.get("players", []))
		elif f is Array and (f as Array).size() > 0:
			set_focus(f[0], f[1] if (f as Array).size() > 1 else [])


## The follow camera, dt real seconds on (0: placed outright).
func _follow(dt: float) -> void:
	if not is_instance_valid(camera) or not _has_focus:
		return
	var ax := Vector3(long_axis.x, 0.0, long_axis.z).normalized()
	if ax == Vector3.ZERO:
		ax = Vector3.RIGHT
	var out := ax.cross(Vector3.UP).normalized() * (1.0 if side >= 0.0 else -1.0)
	# What it frames: the ball and the nearest players to it.
	var pts: Array = [_ball]
	var near: Array = []
	for p in _players:
		var v: Vector3 = (p as Node3D).global_position if p is Node3D else p
		near.append(v)
	near.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.distance_squared_to(_ball) < b.distance_squared_to(_ball))
	pts.append_array(near.slice(0, maxi(nearest, 0)))
	var lo: Vector3 = pts[0]
	var hi: Vector3 = pts[0]
	for p: Vector3 in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	var want := _ball.lerp((lo + hi) * 0.5, 0.5)
	want.y = (lo.y + hi.y) * 0.5 + look_lift
	# The dead zone (across the ground): the aim's goal moves only once the play is dead_zone from it.
	if _snap:
		_goal = want
	else:
		var d := Vector3(want.x - _goal.x, 0.0, want.z - _goal.z)
		if d.length() > dead_zone:
			_goal += d - d.normalized() * dead_zone
		_goal.y = want.y
	var along_want := clampf((_goal - pitch_center).dot(ax) * rail_follow, -rail_limit, rail_limit) if rail else 0.0
	if _snap or dt <= 0.0:
		aim = _goal
		_aim_v = Vector3.ZERO
		_along = along_want
		_along_v = 0.0
	else:
		var r := _damp3(aim, _goal, _aim_v, dt)
		aim = r[0]
		_aim_v = r[1]
		var r2 := _damp(_along, along_want, _along_v, dt)
		_along = r2[0]
		_along_v = r2[1]
	var pos := pitch_center + ax * _along + out * distance + Vector3.UP * height
	# (Always looking in across the pitch from its own side, whatever it is asked to aim at.)
	var look := aim
	if (look - pos).dot(out) > -1.0:
		look -= out * ((look - pos).dot(out) + 1.0)
	camera.global_position = pos
	camera.look_at(look, Vector3.UP)
	# As tight as frames them all (padded), within the range.
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(16, 9)
	var aspect := size.x / maxf(size.y, 1.0)
	var need := 0.0
	var inv := camera.global_transform.affine_inverse()
	for p: Vector3 in pts:
		for y in [0.0, 1.8]:     # (feet and heads)
			var c := inv * (p + Vector3(0, y, 0))
			if c.z < -0.5:
				need = maxf(need, maxf(absf(c.y), absf(c.x) / maxf(aspect, 0.1)) / -c.z)
	var fov_want := clampf(rad_to_deg(2.0 * atan(need * frame_pad)), fov_min, fov_max)
	if _snap or dt <= 0.0:
		_fov = fov_want
		_fov_v = 0.0
	else:
		var r3 := _damp(_fov, fov_want, _fov_v, dt)
		_fov = r3[0]
		_fov_v = r3[1]
	camera.fov = _fov
	_snap = false


## A critically damped spring (no overshoot), smooth_time to catch up: [value, velocity].
func _damp(cur: float, target: float, vel: float, dt: float) -> Array:
	var w := 2.0 / maxf(smooth_time, 0.01)
	var x := w * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var ch := cur - target
	var tmp := (vel + w * ch) * dt
	return [target + (ch + tmp) * e, (vel - w * tmp) * e]


func _damp3(cur: Vector3, target: Vector3, vel: Vector3, dt: float) -> Array:
	var w := 2.0 / maxf(smooth_time, 0.01)
	var x := w * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var ch := cur - target
	var tmp := (vel + ch * w) * dt
	return [target + (ch + tmp) * e, (vel - tmp * w) * e]


func _run_moment(kind: String, data: Dictionary) -> void:
	_moment_seq += 1
	var seq := _moment_seq
	in_moment = true
	_show_skip(true)
	_moment_kind = kind
	_apply_speed(1.0)
	moment_started.emit(kind, data)
	if hide_hud_in_moments:
		hud_visible.emit(false)
		if is_instance_valid(overlay):
			overlay.visible = false
	# Where the replay ends: now (taken before the cut-aways, which the game's clock runs on through).
	var clip := []
	var t0 := 0.0
	var t1 := 0.0
	if replay != null and is_instance_valid(replay) and bool(data.get("replay", true)):
		var sp := replay.span()
		if not sp.is_empty():
			t1 = float(sp[1])
			t0 = maxf(float(sp[0]), t1 - float(data.get("replay_secs", replay_secs)))
			clip = replay.clip(t0, t1)
	if WsgDirector.packages() and is_instance_valid(director):
		var shots: Array = data.get("shots", [])
		if shots.is_empty():
			var tgt: Variant = data.get("target")
			if tgt is Node3D and is_instance_valid(tgt):
				shots.append({"shot": "close", "target": tgt, "secs": 1.8})
			if crowd_at != Vector3.INF:
				var c := {"shot": "crowd", "at": crowd_at, "secs": 1.6}
				if crowd_from != Vector3.INF:
					c["from"] = crowd_from
				shots.append(c)
		if not shots.is_empty():
			await director.run(shots, camera)
	if seq != _moment_seq:
		return
	if not clip.is_empty():
		if is_instance_valid(lower_third) and data.has("title"):
			lower_third.show_card(String(data.title), String(data.get("sub", "")), data.get("colour", Color()))
		replay.play(t0, t1, clip)
		var t := t0
		while t < t1 and seq == _moment_seq:
			replay.seek(t)
			replay_frame.emit(t)
			await get_tree().process_frame
			t += get_process_delta_time() / maxf(Engine.time_scale, 0.001) * replay_rate
		if seq != _moment_seq:
			return
		replay.stop()
	_end_moment()


## The moment over (finished, skipped, paused or stopped): the follow camera, the HUD and the speed back.
func _end_moment() -> void:
	if not in_moment:
		return
	_moment_seq += 1
	in_moment = false
	_show_skip(false)
	if is_instance_valid(director) and director.running:
		director.skip()
	if replay != null and is_instance_valid(replay) and replay.playing:
		replay.stop()
	if is_instance_valid(lower_third):
		lower_third.hide_card()
	_last_end = _clock
	if running:
		_apply_speed(speed)
		if is_instance_valid(camera):
			camera.make_current()
		if hide_hud_in_moments:
			_set_hud(hud_shown)
	moment_finished.emit(_moment_kind)


func _save_engine() -> void:
	if _saved.is_empty():
		_saved = [Engine.time_scale, Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame]


func _apply_speed(s: float) -> void:
	_save_engine()
	Engine.time_scale = float(_saved[0]) * s
	Engine.physics_ticks_per_second = maxi(1, roundi(int(_saved[1]) * s))
	Engine.max_physics_steps_per_frame = maxi(1, roundi(int(_saved[2]) * maxf(s, 1.0)))


func _restore_engine() -> void:
	if _saved.is_empty():
		return
	Engine.time_scale = _saved[0]
	Engine.physics_ticks_per_second = _saved[1]
	Engine.max_physics_steps_per_frame = _saved[2]
	_saved = []
