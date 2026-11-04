extends SceneTree
## Watch mode (WsgSpectator): the follow camera keeps up with a moving play within its easing and never crosses the
## line; paused, it holds still; 2x is twice the game time a real second with a physics step as long as before, and
## stop() puts the speed, the physics ticks and the game's camera back exactly; a moment runs its package and replay
## once, not again within the cooldown, and no more than the cap; Escape (and Back) asks to leave; the overlay's
## buttons work.
##   godot --headless --path . --fixed-fps 30 -s tests/spectator_test.gd

const FPS := 30.0

var fails := []
var phys_steps := 0
var phys_dt := 0.0
var ball := Vector3.ZERO           # (a member: the focus function reads it as it moves)


class Probe:
	extends Node
	var t: Object
	func _physics_process(delta: float) -> void:
		t.phys_steps += 1
		t.phys_dt = delta


func _initialize() -> void:
	WsgFoundation.profile = "premium"
	WsgFoundation.tier = WsgFoundation.MEDIUM
	Engine.physics_ticks_per_second = 50            # (not the default: restored exactly, whatever it was)
	var probe := Probe.new()
	probe.t = self
	root.add_child(probe)
	var live := Camera3D.new()
	root.add_child(live)
	live.position = Vector3(0, 30, 60)
	live.current = true
	var spec := WsgSpectator.new()
	root.add_child(spec)
	spec.long_axis = Vector3.RIGHT
	ball = Vector3(-30, 0.3, 0)
	var players := func() -> Array:
		var out: Array[Vector3] = []
		for i in 4:
			out.append(ball + Vector3(cos(i * 1.7) * 4.0, 0, sin(i * 1.7) * 4.0))
		for i in 6:
			out.append(Vector3(-40 + i * 16, 0, -20 + i * 7))
		return out
	spec.focus_source = func(): return [ball, players.call()]
	await process_frame
	spec.start(live)
	var hud := []
	spec.hud_visible.connect(func(v: bool): hud.append(v))
	print("started: the spectator's camera current %s" % spec.camera.current)
	if not spec.camera.current:
		fails.append("start: its camera is not current")

	# --- Following: the ball along the pitch at 6 m/s, then across it toward the camera's side and back.
	var out := Vector3.BACK          # (long axis +X: the camera's side is +Z)
	var worst_lag := 0.0
	var side_ok := true
	var right_ok := true
	var in_frame := true
	var v := 6.0
	for f in 300:
		ball.x += v / FPS
		await process_frame
		if f > 45:
			worst_lag = maxf(worst_lag, Vector2(spec.aim.x - ball.x, spec.aim.z - ball.z).length())
		side_ok = side_ok and (spec.camera.global_position - spec.pitch_center).dot(out) > 1.0
		right_ok = right_ok and spec.camera.global_basis.x.dot(Vector3.RIGHT) > 0.0
		if f > 45:
			in_frame = in_frame and spec.camera.is_position_in_frustum(ball)
	for f in 240:
		ball.z = lerpf(0.0, 28.0, sin(f / 240.0 * PI))        # (to the camera's touchline and back)
		await process_frame
		side_ok = side_ok and (spec.camera.global_position - spec.pitch_center).dot(out) > 1.0
		right_ok = right_ok and spec.camera.global_basis.x.dot(Vector3.RIGHT) > 0.0
	# The lag of a critically damped follow of a steady run: the speed times its smoothing, plus the dead zone (and the
	# framing's pull toward the players: within 2 m).
	var bound := spec.dead_zone + v * spec.smooth_time + 2.0
	print("follow at %.0f m/s: the aim at most %.1f m behind the ball (bound %.1f), ball in frame %s; on its side %s, the pitch's left to right kept %s" % [v, worst_lag, bound, in_frame, side_ok, right_ok])
	if worst_lag > bound or not in_frame:
		fails.append("follow: lag %.1f m (bound %.1f), in frame %s" % [worst_lag, bound, in_frame])
	if not side_ok or not right_ok:
		fails.append("the camera crossed the line (side %s, left-right %s)" % [side_ok, right_ok])
	# Eased: a sudden jump of the play is not followed at once, then is.
	ball = Vector3(spec.aim.x - 20.0, 0.3, 0)
	var a0 := spec.aim
	await process_frame
	var first := a0.distance_to(spec.aim) / 20.0
	for f in int(spec.smooth_time * 4.0 * FPS):
		await process_frame
	var settled := Vector2(spec.aim.x - ball.x, spec.aim.z - ball.z).length()
	print("a 20 m jump: %.0f%% of it in the first frame, %.1f m off after %.1f s" % [first * 100.0, settled, spec.smooth_time * 4.0])
	if first > 0.25 or settled > spec.dead_zone + 2.0:
		fails.append("easing: %.2f of a jump in one frame, %.1f m off after" % [first, settled])

	# --- Pause: the camera holds still while the play moves; then follows again.
	var pz := []
	spec.paused.connect(func(on: bool): pz.append(on))
	spec.pause()
	var xf := spec.camera.global_transform
	var fov := spec.camera.fov
	for f in 30:
		ball.x += 0.5
		await process_frame
	var still := spec.camera.global_transform.is_equal_approx(xf) and is_equal_approx(spec.camera.fov, fov)
	spec.resume()
	for f in 15:
		await process_frame
	var moves := not spec.camera.global_transform.is_equal_approx(xf)
	print("paused: the camera still %s while the play moved 15 m; resumed, it follows %s; signals %s" % [still, moves, pz])
	if not still or not moves or pz != [true, false]:
		fails.append("pause: still %s, follows after %s, signals %s" % [still, moves, pz])

	# --- Speed: 2x is twice the game time a real second (FPS frames), the physics step as long, the ticks doubled.
	var e0 := [Engine.time_scale, Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame]
	var rates := []
	for s in [1.0, 2.0]:
		spec.set_speed(s)
		await process_frame
		var game := 0.0
		phys_steps = 0
		for f in int(FPS):
			await process_frame
			game += root.get_process_delta_time()
		rates.append([game, phys_steps, phys_dt])
	print("speed: 1x %.2f s of game a real second (%d physics steps of %.4f s); 2x %.2f s (%d steps of %.4f s)" % [rates[0][0], rates[0][1], rates[0][2], rates[1][0], rates[1][1], rates[1][2]])
	if absf(rates[1][0] / rates[0][0] - 2.0) > 0.05:
		fails.append("2x gave %.2f times the game time" % [rates[1][0] / rates[0][0]])
	if absf(float(rates[1][2]) - float(rates[0][2])) > 1e-5 or absf(float(rates[1][1]) / float(rates[0][1]) - 2.0) > 0.1:
		fails.append("physics at 2x: steps %d against %d, step %.4f against %.4f" % [rates[1][1], rates[0][1], rates[1][2], rates[0][2]])

	# --- Moments: once within the cooldown, and no more than the cap; at 1x while they run, the chosen speed after.
	var scorer := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
	root.add_child(scorer)
	scorer.position = Vector3(ball.x, 0, 0)
	var rp := WsgReplay.new()
	root.add_child(rp)
	spec.replay = rp
	spec.replay_secs = 1.0
	spec.cooldown = 3.0
	spec.max_moments = 2
	var now := [0.0]
	var started := []
	var frames := [0]
	spec.moment_started.connect(func(k: String, _d: Dictionary): started.append(k))
	spec.replay_frame.connect(func(_t: float): frames[0] += 1)
	for f in 60:
		now[0] += root.get_process_delta_time()
		rp.record(now[0])
		await process_frame
	hud.clear()
	var ok1 := spec.moment("score", {"target": scorer})
	var again := spec.moment("score", {"target": scorer})
	var during_speed := Engine.time_scale
	var director_cam := false
	var replayed := false
	var f0 := Engine.get_process_frames()
	while spec.in_moment:
		now[0] += root.get_process_delta_time()
		rp.record(now[0])
		director_cam = director_cam or (spec.director != null and spec.director.camera.current)
		replayed = replayed or rp.playing
		await process_frame
	var secs := (Engine.get_process_frames() - f0) / FPS
	var back_cam := spec.camera.current
	var after_end := spec.moment("score", {"target": scorer})
	for f in int((spec.cooldown + 0.2) * FPS):
		await process_frame
	var second := spec.moment("save")
	while spec.in_moment:
		await process_frame
	for f in int((spec.cooldown + 0.2) * FPS):
		await process_frame
	var third := spec.moment("score")
	print("moment: ran %s (%.1f s: the director's close-up %s, a replay %s of %d frames, at %.0fx then %.0fx), again at once %s, after it within the cooldown %s, after the cooldown %s, past the cap of %d %s; started %s; HUD %s; the follow camera back %s"
		% [ok1, secs, director_cam, replayed, frames[0], during_speed, Engine.time_scale, again, after_end, second, spec.max_moments, third, started, hud, back_cam])
	if not ok1 or again or after_end or not second or third or started != ["score", "save"]:
		fails.append("moments: %s %s %s %s %s, started %s" % [ok1, again, after_end, second, third, started])
	if not director_cam or not replayed or frames[0] < 10 or not back_cam:
		fails.append("the moment: director %s, replay %s (%d frames), camera back %s" % [director_cam, replayed, frames[0], back_cam])
	if not is_equal_approx(during_speed, e0[0]) or not is_equal_approx(Engine.time_scale, e0[0] * 2.0):
		fails.append("a moment at 2x: %.1f during, %.1f after" % [during_speed, Engine.time_scale])
	if hud.is_empty() or hud[0] != false or hud[-1] != true:
		fails.append("the HUD during a moment: %s" % [hud])

	# --- Exit: Escape (ui_cancel), Back, and the go-back request.
	var exits := [0]
	spec.exit_requested.connect(func(): exits[0] += 1)
	for k in [KEY_ESCAPE, KEY_BACK]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = true
		root.push_input(ev)
		await process_frame
		var up := ev.duplicate()
		up.pressed = false
		root.push_input(up)
		await process_frame
	spec.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	print("exit: asked %d times (Escape, Back, go-back)" % exits[0])
	if exits[0] != 3:
		fails.append("exit_requested %d times for Escape, Back and go-back" % exits[0])

	# --- The overlay: speed, pause and exit buttons; hidden with the HUD.
	var ov := spec.make_overlay()
	spec.scorebug.setup(["KIL", Color.BLACK, Color.GOLD], ["TIP", Color.BLUE, Color.GOLD])
	spec.scorebug.set_score("1-07", "0-09")
	spec.set_speed(1.0)
	spec._speed_btn.pressed.emit()
	var sp2 := spec.speed
	spec._speed_btn.pressed.emit()
	var sp1 := spec.speed
	spec._pause_btn.pressed.emit()
	var p_on := spec.is_paused
	spec._pause_btn.pressed.emit()
	spec.toggle_hud()
	var hidden := not ov.visible
	spec.toggle_hud()
	print("overlay: speed button %.0fx then %.0fx, pause button %s, hidden with the HUD %s, shown again %s" % [sp2, sp1, p_on, hidden, ov.visible])
	if sp2 != 2.0 or sp1 != 1.0 or not p_on or spec.is_paused or not hidden or not ov.visible:
		fails.append("overlay: %s %s %s %s %s" % [sp2, sp1, p_on, hidden, ov.visible])

	# --- stop(): the speed and physics as they were, its camera gone, the game's camera current. (At 2x, mid-moment.)
	spec.cooldown = 0.0
	spec.max_moments = 0
	spec.set_speed(2.0)
	spec.moment("score", {"target": scorer})
	for f in 5:
		await process_frame
	var cam := spec.camera
	spec.stop()
	await process_frame
	var e1 := [Engine.time_scale, Engine.physics_ticks_per_second, Engine.max_physics_steps_per_frame]
	print("stop: engine %s (was %s), its camera freed %s, the game's camera current %s, replay stopped %s" % [e1, e0, not is_instance_valid(cam), live.current, not rp.playing])
	if e1 != e0 or is_instance_valid(cam) or not live.current or rp.playing:
		fails.append("stop: engine %s against %s, camera freed %s, live current %s" % [e1, e0, not is_instance_valid(cam), live.current])
	# (Started again for the next match, and freed straight after a stop mid-moment: nothing left running.)
	spec.start(live)
	spec.set_speed(2.0)
	spec.moment("score", {"target": scorer})
	await process_frame
	spec.stop()
	spec.queue_free()
	for f in 90:
		await process_frame
	if Engine.time_scale != e0[0] or Engine.physics_ticks_per_second != e0[1] or not live.current:
		fails.append("a second start and stop left the engine at %s" % [[Engine.time_scale, Engine.physics_ticks_per_second]])

	for f in fails:
		printerr("FAIL: ", f)
	print("SPECTATOR TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
