extends Node
## Stills of an AI match for comparing the shared foundation's bodies (FoundationLink, Medium and High) with the game's
## own: the raider's dancing stance close up (side and front), a raider at speed (picked by his speed), defenders
## linked in a chain, a hold (an ankle hold if one comes), a dubki or a lion jump, an official walking his line and
## signalling, the crowd from the broadcast camera, and the replay:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tools/player/foundation_view.tscn -- \
##       OUT_DIR [graphics 0-2] [arena] [seed] [only: tv]
## Runs on a build without the foundation too (the beta's bodies), so the same moments can be put side by side.
## Each still is taken with the match held (the players stopped) at the moment.

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
	Game.settings.models = 1
	Game.settings.camera = Game.CAM_TV
	Game.settings.graphics = int(a[1]) if a.size() > 1 else Game.GFX_MEDIUM
	var arena: String = a[2] if a.size() > 2 else "dome"
	Game.set_language(a[5] if a.size() > 5 else "en")     # (a language: its words on the screen)
	Game.start_match({"home": "MUM", "away": "DEL", "arena": arena, "mode": "quick", "autoplay": true,
		"autoplay_no_report": true, "length": 0, "difficulty": 2, "seed": int(a[3]) if a.size() > 3 else 3})
	m = Game.current
	cam = Camera3D.new()
	add_child(cam)
	for q in _people():
		if q.model.get("link") != null:
			q.model.link.measure = true
	var only: String = a[4] if a.size() > 4 else ""
	await _frames(30)
	var r = await _wait(func(q): return m.phase == "raid" and q == m.raider and m.phase_t > 1.2, 3000)
	await _broadcast("tv_" + arena)
	if only == "tv":
		get_tree().quit()
		return
	if only == "replay":
		await _replay_still()
		get_tree().quit()
		return
	await _broadcast("crowd")
	# The raider working the cover: on his feet in the dancing stance, slow, a second and more into the raid.
	r = await _wait(func(q): return q == m.raider and q.state == "raid" and q.move_vel.length() < 1.2 and q.st_t > 1.0, 6000)
	if r:
		await _shoot(r, "stance_side", Vector3(0.0, 1.0, 2.9), 0.85, 30.0)
		await _shoot(r, "stance_front", Vector3(3.0, 1.0, 0.25), 0.85, 30.0)
		print("stance: knees %s" % _knees(r))
	r = await _wait(_fast, 9000)
	if r:
		await _shoot(r, "speed_side", Vector3(0.0, 1.0, 3.6), 0.9, 32.0, true)
		await _shoot(r, "speed_front", Vector3(3.8, 1.0, 0.3), 0.9, 32.0, true)
		print("speed: %.1f m/s, state %s" % [r.move_vel.length(), r.state])
	r = await _wait(func(q): return q.chain_partner != null and q.state == "ready" and m.phase == "raid", 9000)
	if r:
		var mid: Vector3 = (r.global_position + r.chain_partner.global_position) * 0.5
		await _shoot_at(mid, r.body_facing(), "chain", Vector3(3.2, 1.2, 1.4), 0.8, 36.0)
	r = await _wait(func(q): return q.state == "holding" and q.hold_style == "ankle" and q.st_t > 0.3, 12000)
	if r == null:
		r = await _wait(func(q): return q.state == "holding" and q.st_t > 0.3, 9000)
	if r:
		await _shoot_at(m.raider.global_position, m.raider.body_facing(), "hold", Vector3(1.0, 1.3, 3.0), 0.6, 36.0)
		print("hold: %s" % r.hold_style)
	r = await _wait(func(q): return q.state in ["dubki", "jump"] and q.st_t > q.wait + (q.st_len - q.wait) * 0.45, 30000)
	if r:
		await _shoot(r, "dubki_lion", Vector3(0.6, 1.0, 3.2), 0.7, 34.0)
		print("dubki_lion: %s" % r.state)
	var u: Node3D = m.officials.umpires[0]
	r = await _wait(func(q): return q == u and q.state == "walk" and q.move_vel.length() > 0.5, 6000, true)
	await _shoot(u, "official", Vector3(3.0, 1.2, 1.0), 1.0, 30.0)
	r = await _wait(func(q): return q.state == "signal" and q.st_t > 0.5, 12000, true)
	if r:
		await _shoot(r, "official_signal", Vector3(3.2, 1.3, 0.9), 1.1, 30.0)
	await _replay_still()
	get_tree().quit()


## The next replay (with the foundation), late in it.
func _replay_still() -> void:
	if m.get("wsg_replay") == null:
		return
	var n := 0
	_hold(false)
	RenderingServer.render_loop_enabled = false
	while n < 40000 and not (m.phase == "replay" and float(m._replay.t) > float(m._replay.t1) - 1.4):
		await get_tree().process_frame
		n += 1
	RenderingServer.render_loop_enabled = true
	if m.phase == "replay":
		m.paused = true
		await _still("replay_" + TranslationServer.get_locale())
		print("replay: %s" % m._replay.kind)


func _people() -> Array:
	return m.athletes + m.officials._homes.keys()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## The match held still (its own clock and every player's).
func _hold(on: bool) -> void:
	m.paused = on
	for q in _people():
		q.process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


func _wait(cond: Callable, limit: int, officials := false) -> Node3D:
	_hold(false)
	m.cam.cam.make_current()
	# (Nothing drawn while waiting: software rendering makes each frame cost a third of a second.)
	RenderingServer.render_loop_enabled = false
	for i in limit:
		if m.phase != "replay":
			for q in (m.officials._homes.keys() if officials else m.athletes):
				if q.visible and cond.call(q):
					_hold(true)
					RenderingServer.render_loop_enabled = true
					return q
		await get_tree().process_frame
	RenderingServer.render_loop_enabled = true
	_hold(true)
	print("foundation_view: not seen in time")
	return null


## Running at speed the way he faces, on his own.
func _fast(q: Node3D) -> bool:
	var v: Vector3 = q.move_vel
	return q.on_mat and v.length() > 4.2 and v.length() < 9.0 and v.normalized().dot(q.body_facing()) > 0.9 and _clear(q, 1.4)


## No one else within r of him.
func _clear(q: Node3D, r: float) -> bool:
	for o in m.athletes:
		if o != q and o.global_position.distance_to(q.global_position) < r:
			return false
	return true


func _knees(q: Node3D) -> String:
	var link = q.model.get("link")
	if link == null:
		return "(the game's body)"
	return "L %.0f, R %.0f degrees bent" % [link.knee_bend("Left"), link.knee_bend("Right")]


func _broadcast(name: String) -> void:
	_hold(true)
	m.cam.cam.make_current()
	await _still(name)


## A still of q from off (his frame: x ahead, y up, z to his left), looking at his height y_at; moving: the camera on
## the way he runs rather than his facing.
func _shoot(q: Node3D, name: String, off: Vector3, y_at: float, fov := 32.0, moving := false) -> void:
	var f: Vector3 = q.body_facing()
	if moving and q.move_vel.length() > 0.5:
		f = q.move_vel.normalized()
	await _shoot_at(q.global_position, f, name, off, y_at, fov, q)


func _shoot_at(at: Vector3, f: Vector3, name: String, off: Vector3, y_at: float, fov := 32.0, q: Node3D = null) -> void:
	cam.fov = fov
	cam.make_current()
	m.hud.visible = false
	f = Vector3(f.x, 0, f.z).normalized()
	var l := Vector3(f.z, 0, -f.x)
	at.y = 0.0
	var look := at + Vector3.UP * y_at
	var found := false
	for dist in [1.0, 1.35, 0.75]:
		for deg in [0, 20, -20, 40, -40, 60, -60, 90, -90, 120, -120, 150, -150, 180]:
			var o: Vector3 = (f * off.x + l * off.z).rotated(Vector3.UP, deg_to_rad(deg)) * float(dist)
			cam.global_position = at + o + Vector3.UP * off.y
			if not _blocked(q, cam.global_position, look):
				found = true
				break
		if found:
			break
	cam.look_at(look)
	await _still(name)
	m.hud.visible = true
	print("%s: %s" % [name, (q.state if q else "")])


## Someone between the camera and the subject (q, or the point looked at), or the camera inside someone.
func _blocked(q: Node3D, from: Vector3, to: Vector3) -> bool:
	for o in _people():
		if o == q or (q != null and o.global_position.distance_to(q.global_position) < 0.5):
			continue
		var c: Vector3 = o.global_position + Vector3.UP * 1.0
		if Vector2(from.x - c.x, from.z - c.z).length() < 0.7:
			return true
		var d := to - from
		var t := clampf((c - from).dot(d) / d.length_squared(), 0.0, 1.0)
		if t > 0.03 and t < 0.9 and (from + d * t).distance_to(c) < 0.55:
			return true
	return false


func _still(name: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))
