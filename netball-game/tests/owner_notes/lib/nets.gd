extends RefCounted
## A shot at the post in an AI match, scored or off the ring, and how the net it hits moves: the foot's swing and the
## ripple (Arena.nets, what the glow shader moves the net's faces by), in centimetres and as the viewer sees it - in
## pixels at 720 lines on the camera on screen at that moment (the broadcast camera's close shot of the post for a
## goal, or the courtside or behind-the-goal camera) - for the owner's notes on the nets.

## venue, camera (Game.CAM_*), goal (scored) or off the ring. Returns {"cm", "px", "camera", "goal_seen", "settle_mm"}.
static func shot(h: Node, venue: String, camera: int, goal: bool, seed := 37) -> Dictionary:
	var keep_cam: int = int(Game.settings.camera)
	Game.settings.camera = camera
	var m: Match = h._study_match(seed, {"venue": venue})
	await h._wait_live(m)
	var guard := 0
	while (m.holder == null or m.phase != "live") and guard < 600:
		await h.get_tree().process_frame
		guard += 1
	# The home GS shoots at the goal her team attacks: the one the behind-the-goal camera sits behind.
	var gs: Player = m.player_at(0, "GS")
	m.pass_info = {}
	m._release_holder()
	gs.p = Court.goal_post(gs.dir) + Vector2(-gs.dir * 2.5, 0.8)
	gs.vel = Vector2.ZERO
	gs.target = gs.p
	m._give(gs)
	m.ai._decide[gs] = 99.0
	m.shoot()
	m.shot_info.goal = goal
	var s := 1 if gs.dir > 0 else 0
	var ring := Court.ring_centre(gs.dir)
	var foot := ring + Vector3(0, -Ball.NET_DEPTH, 0)
	var cm := 0.0
	var px := 0.0
	var cam_name := ""
	var seen := false
	var settle := 0.0
	var hit_f := -1
	for f in 240:
		await h.get_tree().process_frame
		var n: Dictionary = m.arena.nets[s]
		var sw: Vector2 = n.sw
		var amp := float(n.amp)
		var move := sw.length() + amp
		if move > 0.002 and hit_f < 0:
			hit_f = f
		cm = maxf(cm, move * 100.0)
		if hit_f >= 0 and f > hit_f + 150:
			settle = maxf(settle, move * 1000.0)
		var cam := h.get_viewport().get_camera_3d()
		if cam == null:
			continue
		var vp := h.get_viewport().get_visible_rect().size
		var k := 720.0 / maxf(vp.y, 1.0)
		if cam.is_position_behind(foot):
			continue
		var a := cam.unproject_position(foot)
		if a.x < 0 or a.y < 0 or a.x > vp.x or a.y > vp.y:
			continue
		seen = true
		# The foot's swing and the ripple (out round its cords: the larger of the two directions on the screen).
		var d := sw.normalized() if sw.length() > 1e-5 else Vector2(1, 0)
		var b := cam.unproject_position(foot + Vector3(sw.x, 0.0, sw.y) + Vector3(d.x, 0.0, d.y) * amp)
		var p := a.distance_to(b) * k
		if p > px:
			px = p
			cam_name = "%s%s" % [["TV", "Low", "End"][camera], " (the close shot)" if m.cam.close_dir != 0 else ""]
	m.queue_free()
	await h.get_tree().process_frame
	await h.get_tree().process_frame
	Game.settings.camera = keep_cam
	return {"cm": cm, "px": px, "camera": cam_name, "seen": seen, "settle_mm": settle, "moved": hit_f >= 0}
