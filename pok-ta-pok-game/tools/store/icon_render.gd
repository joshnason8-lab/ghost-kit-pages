extends Node
## Renders the launcher icon and the feature graphic's picture from the game's own pieces: the stone ring of the
## classic court, the heavy rubber ball passing through it, in the low sun.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/store/icon_render.tscn -- OUT_DIR [icon|feature]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := String(args[0]) if args.size() > 0 else "/tmp"
	var only := String(args[1]) if args.size() > 1 else ""
	Game.settings.graphics = Game.GFX_HIGH
	await Crowd.bake(self)
	for job in [["icon", Vector2i(1024, 1024)], ["feature", Vector2i(2048, 1000)]]:
		if only != "" and job[0] != only:
			continue
		var sv := SubViewport.new()
		sv.size = job[1]
		sv.own_world_3d = true
		sv.msaa_3d = Viewport.MSAA_4X
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(sv)
		var court := Court.new(Rules.CLASSIC)
		var v := Venue.new()
		sv.add_child(v)
		v.build("stone", court)
		v.crowd.visible = job[0] == "feature"
		var ring: Vector3 = court.rings()[1]
		var ball := Ball.new()
		sv.add_child(ball)
		ball.setup(court, "stone")
		ball.pos = ring + Vector3(0.05, 0.0, 0.0)
		ball.show_at(ball.pos, 0.0)
		var cam := Camera3D.new()
		sv.add_child(cam)
		if job[0] == "icon":
			cam.fov = 24.0
			cam.position = ring + Vector3(-2.4, -0.55, -0.55)
		else:
			cam.fov = 40.0
			cam.position = ring + Vector3(-7.5, -1.6, -3.4)
		cam.look_at(ring + Vector3(0, 0.05, 0))
		cam.current = true
		for i in 8:
			await RenderingServer.frame_post_draw
		var img := sv.get_texture().get_image()
		img.save_png("%s/%s_render.png" % [out, job[0]])
		sv.queue_free()
		await get_tree().process_frame
	get_tree().quit()
