extends Node
## The props' contact sheet (not a test): each venue from above and from court-side, its solid props (Venue.solid,
## WsgSolidProps) drawn over it as yellow wire boxes, two views a venue in one picture.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/prop_shot.tscn -- OUT.jpg [GFX]
const W := 960
const H := 540


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := String(args[0]) if args.size() > 0 else "/tmp/props.jpg"
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = int(args[1]) if args.size() > 1 else 0
	get_tree().root.size = Vector2i(W, H)
	# [camera place, look at] a view: one over the whole, one from the court toward the props.
	var views := {
		"village": [[Vector3(0, 30, 34), Vector3(0, 0, 4)], [Vector3(4, 2.2, -1.5), Vector3(-4, 0.4, 6)]],
		"festival": [[Vector3(0, 26, 26), Vector3(0, 0, -4)], [Vector3(26, 2.5, 2), Vector3(37, 1.5, -2)]],
		"stone": [[Vector3(0, 34, 40), Vector3(0, 0, 0)], [Vector3(6, 2.5, -1), Vector3(0, 5.5, 8.5)]],
		"night": [[Vector3(-30, 24, 30), Vector3(-10, 3, 0)], [Vector3(14, 3, 0), Vector3(25, 3, 7)]],
	}
	var sheet := Image.create(W * 2, H * 4, false, Image.FORMAT_RGB8)
	var row := 0
	for id in ["village", "festival", "stone", "night"]:
		var v := Venue.new()
		add_child(v)
		v.build(id, Court.new(String(DB.venue(id).rules)))
		v.add_child(v.solid.debug_mesh())
		var cam := Camera3D.new()
		cam.fov = 60
		cam.far = 400
		add_child(cam)
		cam.current = true
		for k in 2:
			var vw: Array = views[id][k]
			cam.position = vw[0]
			cam.look_at(vw[1])
			for i in 6:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(W, H)
			sheet.blit_rect(img, Rect2i(0, 0, W, H), Vector2i(W * k, H * row))
		print("%s: %d solid props, %d skipped %s" % [id, v.solid.props.size(), v.solid.skipped.size(), str(v.solid.skipped.map(func(s): return s.name if s is Dictionary else s))])
		cam.queue_free()
		v.queue_free()
		await get_tree().process_frame
		row += 1
	sheet.save_jpg(out, 0.82)
	get_tree().quit()
