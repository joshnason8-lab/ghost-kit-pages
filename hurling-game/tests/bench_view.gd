extends Node
## The substitutes on the bench, close: a match at the county ground, the camera in front of a dugout at a seated
## man's eye height and from the side (their feet on the floor, their seat under them).
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/bench_view.tscn -- /out.png

func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.graphics = Game.GFX_HIGH
	Game.start_match({"home": "KIL", "away": "TIP", "venue": "county", "user_team": -1, "seed": 4, "mode": "sim_test", "length": 14})
	for i in 30:
		await get_tree().process_frame
	var m: Node = Game.current
	m.set_process(false)
	var s0: Vector3 = Bench.seat(0, 1)
	var views := [[s0 + Vector3(0.4, 0.9, 2.6), s0 + Vector3(0, 0.5, 0)], [s0 + Vector3(1.6, 0.5, 2.2), s0 + Vector3(0, 0.35, 0)]]
	var img := Image.create(640 * 2, 480, false, Image.FORMAT_RGB8)
	for k in views.size():
		var vp := SubViewport.new()
		vp.size = Vector2i(640, 480)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.world_3d = get_viewport().world_3d
		add_child(vp)
		var cam := Camera3D.new()
		cam.fov = 45
		vp.add_child(cam)
		cam.look_at_from_position(views[k][0], views[k][1])
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var im := vp.get_texture().get_image()
		im.convert(Image.FORMAT_RGB8)
		img.blit_rect(im, Rect2i(0, 0, 640, 480), Vector2i(640 * k, 0))
		vp.queue_free()
	img.save_png(out)
	get_tree().quit()
