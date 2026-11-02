extends Node
## The thrower from the side through the serve's toss, a strip of moments, to see where the ball is: in his crouch
## going down before the throw (0.4 s before it: 0.14.3), then 0 (down in it), 0.3, 0.42, 0.52 (the release) and 0.7 s in
## (docs/stills/serve_toss_*.jpg). From his right, the hand that throws (side "l": from his left). level 0-2; w for
## the women:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1600x900 res://tests/toss_stills.tscn -- OUT.png [level] [w] [side]

const TIMES := [-0.4, 0.0, 0.3, 0.42, 0.52, 0.7]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp/toss.png"
	Game.main = self
	Game.reset_settings_for_tests()
	Game.settings.graphics = int(a[1]) if a.size() > 1 else 0
	var women: bool = a.size() > 2 and a[2] == "w"
	var from_left: bool = a.size() > 3 and a[3] == "l"
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "THA", "away": "MAS", "venue": "national", "event": "regu", "sets": 1, "points": 15,
		"user_team": -1, "demo": true, "seed": 4, "mode": "quick", "women": women}
	add_child(m)
	m.hud.visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 34.0
	cam.current = true
	var shots: Array = []
	for t in TIMES:
		# (Before the throw: as set-up's time is up less t, him set.)
		while not ((int(m.state) == int(m.S.TOSS) and float(m.state_t) >= t) or (t < 0.0 and int(m.state) == int(m.S.SETUP)
				and m._thrower_set() and m.get("_carrier") == m._thrower() and float(m.state_t) >= m.SETUP_TIME + t)):
			m._process(1.0 / 30.0)
			m.set("_start_replay_after", -1.0)
		var th: Node = m._thrower()
		var hips: Vector3 = th.body.bone_world("hips")
		var fwd: Vector3 = th.body.global_transform.basis.z.normalized()
		var right := Vector3.UP.cross(fwd).normalized()
		cam.global_position = hips + right * (-3.0 if from_left else 3.0) + fwd * 0.35 + Vector3(0, 0.15, 0)
		cam.look_at(hips + fwd * 0.3 + Vector3(0, -0.05, 0))
		m.process_mode = Node.PROCESS_MODE_DISABLED
		for f in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		shots.append(img)
		m.process_mode = Node.PROCESS_MODE_INHERIT
	# A strip: each moment cropped round the thrower, side by side.
	var w: int = (shots[0] as Image).get_width()
	var h: int = (shots[0] as Image).get_height()
	var cw := int(w * 0.42)
	var strip := Image.create(cw * shots.size(), h, false, Image.FORMAT_RGB8)
	for i in shots.size():
		strip.blit_rect(shots[i] as Image, Rect2i(int((w - cw) / 2), 0, cw, h), Vector2i(cw * i, 0))
	strip.save_png(out)
	print("toss_stills: ", out)
	get_tree().quit()
