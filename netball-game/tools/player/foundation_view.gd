extends Node
## Close-ups of the players and umpires in an AI match, for comparing the shared foundation's bodies (FoundationLink)
## with the game's own: holding the ball (both hands), a shot, a pass, running and sprinting, an umpire walking her
## line and signalling, the reserves on the bench, the crowd from the broadcast camera:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/player/foundation_view.tscn -- OUT_DIR [graphics] [venue] [seed]
## Each still is taken with the match held at the moment. Runs on a build without the foundation too (the beta's
## bodies), so the same moments can be put side by side. Prints how far the drawn hands are from the ball.

var m: Node
var cam: Camera3D
var out := "/tmp"


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "/tmp"
	DirAccess.make_dir_recursive_absolute(out)
	get_tree().root.size = Vector2i(1280, 720)
	Game.main = self
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	Game.settings.graphics = int(a[1]) if a.size() > 1 else Game.GFX_MEDIUM
	ToonBody.material(int(Game.settings.graphics) > Game.GFX_LOW)
	var venue: String = a[2] if a.size() > 2 else "arena"
	Game.start_match({"home": "AUS", "away": "NZL", "venue": venue, "user_team": -1, "headless_hud": true,
		"seed": int(a[3]) if a.size() > 3 else 5, "quarter": 15})
	m = Game.current
	cam = Camera3D.new()
	add_child(cam)
	for q in _people():
		if q.get("link") != null:
			q.link.measure = true
	await _frames(120)
	await _broadcast("crowd_tv")
	var p: Node3D = await _wait(func(q): return q.act == "hold" and q.act_t > 0.5 and q.vel.length() < 0.3, 6000)
	if p:
		await _shoot(p, "hold_front", Vector3(1.6, 1.45, 0.35), -1.0, 26.0)
		await _shoot(p, "hold_side", Vector3(0.3, 1.45, 1.6), -1.0, 26.0)
		await _shoot(p, "hold_hands", Vector3(0.75, 1.3, 0.35), -1.0, 22.0)
	p = await _wait(func(q): return q.act == "shoot" and q.act_t > 0.6 and q.act_t < 0.74, 12000)
	if p:
		await _shoot(p, "shot_front", Vector3(2.4, 1.6, 0.8), 1.5, 30.0)
		await _shoot(p, "shot_side", Vector3(0.4, 1.6, 2.6), 1.5, 30.0)
	# (The AI sets her next act the frame after the ball leaves: the pass is seen as it is thrown.)
	p = await _wait(func(q): return q.act == "pass", 6000)
	if p:
		await _shoot(p, "pass_front", Vector3(2.4, 1.4, 0.6), 1.1, 30.0)
		await _shoot(p, "pass_side", Vector3(0.3, 1.4, 2.6), 1.1, 30.0)
	p = await _wait(func(q): return q.act == "run" and q.vel.length() > 3.0 and q.vel.length() < 5.0, 6000)
	if p:
		await _shoot(p, "run_side", Vector3(0.0, 1.1, 3.4), 0.95, 32.0, true)
		await _shoot(p, "run_front", Vector3(3.4, 1.1, 0.4), 0.95, 32.0, true)
	p = await _wait(func(q): return q.act == "run" and q.vel.length() > 6.0, 9000)
	if p:
		await _shoot(p, "sprint_side", Vector3(0.0, 1.1, 3.6), 0.95, 32.0, true)
		await _shoot(p, "sprint_front", Vector3(3.6, 1.1, 0.4), 0.95, 32.0, true)
	var u: Node3D = m.umpires[0]
	await _shoot(u, "umpire", Vector3(3.0, 1.3, 1.0), 1.0, 30.0)
	u = await _wait(func(q): return q.sig != "" and q.sig_t > 0.4, 12000, true)
	if u:
		await _shoot(u, "umpire_signal", Vector3(3.2, 1.3, 0.9), 1.1, 30.0)
	var res: Node3D = m.get_node_or_null("Reserves")
	if res and res.get_child_count() > 0:
		var r0: Node3D = res.get_child(0)
		cam.fov = 34.0
		cam.make_current()
		cam.global_position = r0.global_position + Vector3(1.2, 1.5, -4.8)
		cam.look_at(r0.global_position + Vector3(1.2, 0.95, 0.0))
		await _still("reserves")
	await _goal_replay()
	get_tree().quit()


## The next goal: the TV camera's close shot of the post; then, with the foundation, its replay (the feed, the shot in
## the air, the ball through the ring).
func _goal_replay() -> void:
	m.paused = false
	m.cam.make_current()
	RenderingServer.render_loop_enabled = false
	var n := 0
	while m.phase != "goal" and n < 30000:
		await get_tree().process_frame
		n += 1
	while m.phase == "goal" and m.phase_t < 1.0:
		await get_tree().process_frame
	RenderingServer.render_loop_enabled = true
	m.paused = true
	await _still("goal_close")
	if m.get("wsg_replay") == null:
		return
	m.paused = false
	RenderingServer.render_loop_enabled = false
	n = 0
	while m.phase != "replay" and n < 400:
		await get_tree().process_frame
		n += 1
	if m.phase != "replay":
		RenderingServer.render_loop_enabled = true
		print("foundation_view: no replay")
		return
	for k in [["replay_feed", 2.4], ["replay_shot", 1.0], ["replay_goal", -0.1]]:
		while m.phase == "replay" and float(m._replay.t) < m._goal_clock - float(k[1]):
			await get_tree().process_frame
		if m.phase != "replay":
			break
		RenderingServer.render_loop_enabled = true
		m.paused = true
		await _still(k[0])
		print("%s: replay at %.2f s of %.2f" % [k[0], float(m._replay.t), m._goal_clock])
		m.paused = false
		RenderingServer.render_loop_enabled = false
	RenderingServer.render_loop_enabled = true


func _people() -> Array:
	return m.players[0] + m.players[1] + m.umpires


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(cond: Callable, limit: int, umpires := false) -> Node3D:
	m.paused = false
	m.cam.make_current()
	# (Nothing drawn while waiting: software rendering makes each frame cost a third of a second.)
	RenderingServer.render_loop_enabled = false
	for i in limit:
		for q in (m.umpires if umpires else m.players[0] + m.players[1]):
			if q.visible and cond.call(q):
				m.paused = true
				RenderingServer.render_loop_enabled = true
				return q
		await get_tree().process_frame
	RenderingServer.render_loop_enabled = true
	print("foundation_view: not seen in time")
	return null


## The broadcast camera's own picture (the crowd, the court) at this moment.
func _broadcast(name: String) -> void:
	m.paused = true
	m.cam.make_current()
	await _still(name)


## A still of q from off (her frame: x ahead, y up, z to her left), looking at her height y_at (negative: the ball in
## her hands); moving: the camera on the way she runs rather than her facing.
func _shoot(q: Node3D, name: String, off: Vector3, y_at: float, fov := 32.0, moving := false) -> void:
	cam.fov = fov
	cam.make_current()
	var yaw: float = q.facing
	if moving and q.vel.length() > 0.5:
		yaw = atan2(q.vel.x, q.vel.y)
	var f := Vector3(sin(yaw), 0, cos(yaw))
	var l := Vector3(f.z, 0, -f.x)
	var at := Vector3(q.global_position.x, 0, q.global_position.z)
	var look := at + Vector3.UP * y_at
	if y_at < 0.0:
		look = m.ball.global_position
		at = Vector3(look.x, 0, look.z)
		off.y += look.y - 1.3
	cam.global_position = at + f * off.x + Vector3.UP * off.y + l * off.z
	cam.look_at(look)
	await _still(name)
	var msg := "%s: %s act=%s speed=%.1f" % [name, q.get("pos") if q.get("pos") != null else "umpire", q.get("act") if q.get("act") != null else q.get("sig"), q.vel.length()]
	var link = q.get("link")
	if link != null:
		msg += " mode=%s" % link.mode
		if link.holding:
			msg += " hands off the ball: L %.1f cm, R %.1f cm" % [float(link.last_hands.get("Left", -1.0)) * 100.0, float(link.last_hands.get("Right", -1.0)) * 100.0]
	print(msg)


func _still(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
