extends Node
## Close-ups of the players and umpires in an AI match, for comparing the shared foundation's bodies (FoundationLink)
## with the game's own: holding the ball (both hands), a shot, a pass, running and sprinting, an umpire walking her
## line and signalling, the reserves on the bench, the crowd from the broadcast camera:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tools/player/foundation_view.tscn -- OUT_DIR [graphics] [venue] [seed] [gaits]
## (At a fixed frame rate the match plays the same in both builds: the same moments come up in each.)
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
	if a.size() > 4 and a[4] == "gaits":
		# Only the run and the sprint.
		await _gait_stills("run", 3.5, 5.0)
		await _gait_stills("sprint", 6.3, 99.0)
		get_tree().quit()
		return
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
	# Running and sprinting: picked by her own speed (a band, the same in both builds), on her own (no one within 1.5 m:
	# nobody in the way), going the way she faces; three stills across one stride pair, side and front.
	await _gait_stills("run", 3.5, 5.0)
	# (The sprint: past the foundation's sprint threshold, where its Sprint_F_Loop takes over from the run: 6.4 m/s for
	# a 0.85 m leg; the beta's Fast_Run is all there from 5.6.)
	await _gait_stills("sprint", 6.3, 99.0)
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


## A player running in the speed band, the way she faces, with no one within 1.5 m.
func _gait(q: Node3D, lo: float, hi: float, steady := true) -> bool:
	var v: Vector2 = q.vel
	if q.act != "run" or v.length() < lo or v.length() > hi:
		return false
	# (And keeping it up: a way still to go, at a speed in the band, so the stride's three stills stay in it.)
	var want := minf(q.want_speed, q.speed_cap())
	if q.p.distance_to(q.target) < 5.0 or want < lo or (steady and want > hi + 0.3):
		return false
	if absf(angle_difference(atan2(v.x, v.y), q.facing)) > deg_to_rad(25.0):
		return false
	for o in m.players[0] + m.players[1] + m.umpires:
		if o != q and o.global_position.distance_to(q.global_position) < 1.5:
			return false
	return true


## A runner in the band, her stride's stills; again with the next one (up to six) until all three stay in it.
func _gait_stills(name: String, lo: float, hi: float) -> void:
	for attempt in 8:
		# (Every other try also takes a runner steering for more than the band: the AI seldom holds a run's speed.)
		var q: Node3D = await _wait(func(c): return _gait(c, lo, hi, attempt % 2 == 0), 8000)
		if q == null:
			continue
		if await _stride(q, name, lo, hi):
			return
		print("%s: she left the band during the stride; the next one" % name)
		m.paused = false
		for i in 30:
			await get_tree().process_frame


## Three stills across one stride pair (by her own stride phase, which both builds keep), side and front, the camera
## going with her.
func _stride(q: Node3D, name: String, lo: float, hi: float) -> bool:
	var p0: float = q.stride_phase
	var all_in := true
	for k in 3:
		if k > 0:
			m.paused = false
			RenderingServer.render_loop_enabled = false
			var n := 0
			while fposmod(q.stride_phase - p0, 1.0) < k / 3.0 and n < 600:
				await get_tree().process_frame
				n += 1
			m.paused = true
			RenderingServer.render_loop_enabled = true
		var band := "in" if q.vel.length() >= lo and q.vel.length() <= hi else "OUT OF"
		all_in = all_in and band == "in"
		print("%s_%d: stride phase %.2f, %s the band" % [name, k + 1, fposmod(q.stride_phase - p0, 1.0), band])
		await _shoot(q, "%s_side_%d" % [name, k + 1], Vector3(0.0, 1.1, 3.6), 0.95, 32.0, true)
		await _shoot(q, "%s_front_%d" % [name, k + 1], Vector3(3.8, 1.1, 0.3), 0.95, 32.0, true)
	return all_in


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
	# Turned round her (the least way) when someone stands between the camera and her.
	var turned := 0
	for deg in [0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180]:
		var o := (f * off.x + l * off.z).rotated(Vector3.UP, deg_to_rad(deg))
		cam.global_position = at + o + Vector3.UP * off.y
		if not _blocked(q, cam.global_position, look):
			turned = deg
			break
	cam.look_at(look)
	await _still(name)
	var msg := "%s: %s act=%s speed=%.1f%s" % [name, q.get("pos") if q.get("pos") != null else "umpire", q.get("act") if q.get("act") != null else q.get("sig"), q.vel.length(),
		" (camera turned %d degrees round her for a clear view)" % turned if turned != 0 else ""]
	# Who is near her: each one's place in the game and where her drawn body's hips are.
	for o in m.players[0] + m.players[1]:
		if o != q and o.global_position.distance_to(q.global_position) < 1.2:
			var hips = o.link.body.bone_world("Hips").origin if o.get("link") != null else o.global_position
			msg += "\n    near: %s%d %.2f m from her in the game, drawn hips %.2f m from her place" % [o.pos, o.team, o.global_position.distance_to(q.global_position), Vector2(hips.x - o.global_position.x, hips.z - o.global_position.z).length()]
	var link = q.get("link")
	if link != null:
		msg += " mode=%s" % link.mode
		if link.holding:
			msg += " hands off the ball: L %.1f cm, R %.1f cm" % [float(link.last_hands.get("Left", -1.0)) * 100.0, float(link.last_hands.get("Right", -1.0)) * 100.0]
	print(msg)


## Someone (a player or an umpire other than q) within 0.4 m of the line from the camera to her.
func _blocked(q: Node3D, from: Vector3, to: Vector3) -> bool:
	for o in m.players[0] + m.players[1] + m.umpires:
		if o == q:
			continue
		var c: Vector3 = o.global_position + Vector3.UP * 1.0
		var d := to - from
		var t := clampf((c - from).dot(d) / d.length_squared(), 0.0, 1.0)
		if t > 0.05 and t < 0.97 and (from + d * t).distance_to(c) < 0.4 + 0.3:
			return true
	return false


func _still(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
