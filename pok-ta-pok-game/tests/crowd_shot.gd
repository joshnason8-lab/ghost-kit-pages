extends Node
## Close views of each venue's crowd for looking at (not a test): from the court toward each spectator area.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/crowd_shot.tscn -- OUT_PREFIX GFX
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := String(args[0]) if args.size() > 0 else "/tmp/crowd"
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = int(args[1]) if args.size() > 1 else 0
	get_tree().root.size = Vector2i(1280, 720)
	await Crowd.bake(self)
	# [venue, camera place, look at, name]
	var views := {
		"village": [[Vector3(-4, 1.6, 0), Vector3(-6, 0.8, 5.5), "side"], [Vector3(8, 2.5, -1), Vector3(-2, 0.6, -5.5), "side_wide"], [Vector3(26, 1.7, 0), Vector3(34, 0.8, 0), "end"]],
		"festival": [[Vector3(-3, 1.6, 2), Vector3(-5, 2.0, -8.5), "stands"], [Vector3(2, 1.7, -1), Vector3(-3, 0.8, 4.8), "near_side"], [Vector3(28, 1.7, 0), Vector3(37, 0.8, 0), "end"]],
		"stone": [[Vector3(-3, 3.0, 0), Vector3(-6, 6.5, 8.6), "terrace"], [Vector3(5, 7.5, 2), Vector3(0, 6.0, 8.4), "terrace_top"], [Vector3(15, 2.5, 0), Vector3(26, 0.8, 3), "end"]],
		"night": [[Vector3(-3, 3.0, 0), Vector3(-6, 6.5, -8.6), "terrace"]],
	}
	for id in DB.VENUE_ORDER:
		var v := Venue.new()
		add_child(v)
		v.build(id, Court.new(String(DB.venue(id).rules)))
		var cam := Camera3D.new()
		cam.fov = 55
		add_child(cam)
		cam.current = true
		for vw in views[id]:
			cam.position = vw[0]
			cam.look_at(vw[1])
			for i in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_jpg("%s_%s_%s_g%d.jpg" % [out, id, vw[2], int(Game.settings.graphics)], 0.85)
		cam.queue_free()
		v.queue_free()
		await get_tree().process_frame
	get_tree().quit()
