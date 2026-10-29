extends Node
## Frames of a penalty shot in Penalty shots (the breakaway: a deke, the wind-up held, the swing): the first shot as the
## game's own close camera sees it, the second from the side:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/player/breakaway_view.tscn -- OUT_DIR [graphics]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp"
	get_tree().root.size = Vector2i(1280, 720)
	Game.main = self
	Game.settings.sound = false
	Game.settings.auto_gfx = false
	Game.settings.graphics = int(a[1]) if a.size() > 1 else Game.GFX_HIGH
	Game.start_match({"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "practice", "practice": true, "period": 20.0, "seed": 3})
	var m: Node = Game.current
	for shot in 2:
		while String(m._so.get("stage", "")) != "run" or bool(m._so.get("shot", false)) or (m._so.shooter as Player).pos.x < 3.5:
			await get_tree().physics_frame
		var sh: Player = m._so.shooter
		var cam: Camera3D = null
		if shot == 1:
			cam = Camera3D.new()
			cam.fov = 40.0
			add_child(cam)
			cam.make_current()
		var n := 0
		var t := 0
		while t < 150:
			if t == 5:
				m._on_action("DEKE")
			if t == 40:
				m.touch._key_held[0] = true
				m._on_action("SHOOT")
			if t == 72:
				m.touch._key_held[0] = false
			if cam:
				cam.global_position = Vector3(sh.pos.x + 0.6, 1.2, sh.pos.y - 3.6)
				cam.look_at(Vector3(sh.pos.x + 0.6, 0.75, sh.pos.y))
			await get_tree().physics_frame
			t += 1
			if t % 6 == 0 and t >= 30 and t <= 120:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out + "/shot%d_%02d.png" % [shot, n])
				n += 1
		if cam:
			cam.queue_free()
	get_tree().quit()
