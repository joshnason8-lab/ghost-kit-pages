extends Node
## The ball and the nets, seen: a goal at the post from close by (the net swinging and settling, frame by frame) and
## a lob and a chest pass from the side (the ball's path left as a trail of markers every other frame, so its arc and
## its even speed across the floor show), saved as PNGs:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/ball_shots.tscn -- OUT_DIR [levels] [venues] [passes]
## levels: low,medium,high (medium by default); venues: arena,hall,outdoor (arena by default); "passes": only the
## passes.

var out := "/tmp/ball_shots"
var levels := ["medium"]
var venues := ["arena"]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 1 and args[1] != "":
		levels = Array(args[1].split(","))
	if args.size() > 2 and args[2] != "":
		venues = Array(args[2].split(","))
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	get_tree().root.size = Vector2i(1280, 720)
	for lv: String in levels:
		var g := ["low", "medium", "high"].find(lv)
		Game.settings.graphics = g
		ToonBody.material(g > Game.GFX_LOW)
		for v: String in venues:
			if not "passes" in OS.get_cmdline_user_args():
				await _goal(v, lv)
			await _passes(v, lv)
	get_tree().quit()


func _start(v: String) -> Match:
	Game.start_match({"home": "AUS", "away": "NZL", "venue": v, "quarter": 15, "difficulty": 1, "mode": "quick",
		"user_team": -1, "demo": true, "seed": 9, "no_injuries": true})
	await frames(3)
	var m: Match = Game.current
	if m.hud and m.hud.card:
		m.hud.card.close()
	var guard := 0
	while (m.phase != "live" or m.holder == null) and guard < 900:
		await frames(1)
		guard += 1
	return m


## A goal from 2.5 m, seen from beside the post: the net at rest, the ball dropping through, the swing and the settle.
func _goal(v: String, lv: String) -> void:
	var m := await _start(v)
	var t: int = m.holder.team
	var gs: Player = m.player_at(t, "GS")
	m.pass_info = {}
	m._release_holder()
	gs.p = Court.goal_post(gs.dir) + Vector2(-gs.dir * 2.5, 0.8)
	gs.vel = Vector2.ZERO
	gs.target = gs.p
	m._give(gs)
	m.ai._decide[gs] = 99.0
	var ring := Court.ring_centre(gs.dir)
	var cam := Camera3D.new()
	cam.fov = 30.0
	m.add_child(cam)
	# From the side, square to the shot, so the net's swing shows across the picture.
	cam.global_position = ring + Vector3(-gs.dir * 0.25, -0.45, 2.3)
	cam.look_at(ring + Vector3(0, -0.22, 0))
	cam.make_current()
	await frames(4)
	await shot("%s_%s_net_00_rest" % [v, lv])
	m.shoot()
	m.shot_info.goal = true
	var i := 1
	var arrive := -1
	for f in 200:
		await frames(1)
		cam.make_current()
		# From just before the ball reaches the ring: every frame for a second, then every sixth as it settles.
		if arrive < 0 and m.shot_info.get("released", false):
			arrive = f + int(m.ball.f_dur * 30.0) - 3
		var since := f - arrive if arrive >= 0 else -99
		if (since >= 0 and since < 30) or (since >= 30 and since % 6 == 0 and since <= 130):
			await shot("%s_%s_net_%03d_t%+.2f" % [v, lv, i, since / 30.0])
			i += 1
	cam.queue_free()
	m.queue_free()
	await frames(2)


## A lob and a chest pass, from the side line: a marker where the ball is every other frame (white); in red where the
## old flight (a straight line plus a hump, its time fixed by the distance) put it.
func _passes(v: String, lv: String) -> void:
	for kind in ["lob", "chest"]:
		var m := await _start(v)
		var t: int = m.holder.team
		var d := m.team_dir(t)
		var wa: Player = m.player_at(t, "WA")
		var gs: Player = m.player_at(t, "GS")
		m.pass_info = {}
		m._release_holder()
		var x0 := d * (Court.HALF_L - 6.5)
		wa.p = Vector2(x0, 0.0)
		gs.p = Vector2(x0 + d * (5.5 if kind == "lob" else 8.0), 0.0)
		for pl in [wa, gs]:
			pl.vel = Vector2.ZERO
			pl.target = pl.p
		# Nobody else near the line of it.
		for tt in 2:
			for pl: Player in m.players[tt]:
				if pl != wa and pl != gs:
					pl.p = Vector2(pl.p.x, 5.5 if pl.p.y >= 0 else -5.5)
					pl.target = pl.p
		m._give(wa)
		await frames(2)
		var cam := Camera3D.new()
		cam.fov = 40.0
		m.add_child(cam)
		var mid := Vector3((wa.p.x + gs.p.x) * 0.5, 2.0, 0.0)
		cam.global_position = mid + Vector3(0, 0.3, 13.0)
		cam.look_at(mid)
		cam.make_current()
		m.ai._decide[wa] = 99.0
		m.restart["cp_done"] = true   # (open play, not the centre pass)
		m.game_event.connect(func(k, info): print("  event ", k, " ", info))
		m.throw_pass(gs, kind)
		var info: Dictionary = m.pass_info.duplicate()
		var from: Vector3 = m.ball.f_from
		var to: Vector3 = m.ball.f_to
		# The old flight, for comparison.
		var dist := Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
		var spd: float = {"chest": 11.5, "lob": 8.5}[kind]
		var old_dur := clampf(dist / spd, 0.25, 2.0)
		var old_apex: float = {"chest": 0.25, "lob": 1.6 + dist * 0.06}[kind]
		var dur: float = m.ball.f_dur
		var marks: Array = []
		var f := 0
		while m.ball.state == "flight" and f < 90:
			marks.append(_mark(m, m.ball.position, Color.WHITE))
			var k := minf(1.0, (f + 1) / 30.0 / old_dur)
			if (f + 1) / 30.0 <= old_dur + 0.01:
				var q := from.lerp(to, k)
				q.y += 4.0 * old_apex * k * (1.0 - k)
				marks.append(_mark(m, q, Color(1, 0.2, 0.2)))
			await frames(1)
			f += 1
			if f == int(dur * 15.0):
				await shot("%s_%s_%s_mid" % [v, lv, kind])
			if m.ball.state == "flight" and m.ball.flight_left() < 0.4:
				await shot("%s_%s_%s_catch_%02d" % [v, lv, kind, f])
		# The catch and after, every other frame.
		for j in 8:
			await shot("%s_%s_%s_catch_%02d" % [v, lv, kind, f + j * 2])
			await frames(2)
		await shot("%s_%s_%s_trail" % [v, lv, kind])
		print("%s: %.1f m, %.2f s in the air (was %.2f s), released at %.1f m/s" % [kind, dist, dur, old_dur, m.ball.f_legs[0][2].length() if not m.ball.f_legs.is_empty() else 0.0])
		cam.queue_free()
		m.queue_free()
		await frames(2)


func _mark(m: Node, at: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.05
	s.height = 0.1
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	mi.material_override = mat
	m.add_child(mi)
	mi.global_position = at
	return mi


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join(name + ".png"))


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
