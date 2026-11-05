extends Node3D
## The crowd seen from the court, to check that every spectator faces the play: in each venue, cameras on the court
## looking at the near stand, the far stand and an end, and one behind the near stand looking over it at the court
## (where the spectators should show their backs). One sheet a graphics level, a row a venue:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/crowd_view.tscn -- /out/dir [0,1,2] [up|anim]
## up: the crowd on its feet, as after a home point (Crowd.set_excite(1)).
## anim: the far stand close up from the broadcast camera, in frames over time: the ball crossing the court (the
## crowd turning with it), then a home point (on their feet, cheering) and settling; Thailand's and the Philippines'
## flags. A sheet a graphics level, a row a venue.

const TILE := Vector2i(480, 270)
const VIEWS := [   # name, camera, looking at
	["near stand", Vector3(0, 1.6, 2.0), Vector3(0, 2.6, -12.0)],
	["far stand", Vector3(0, 1.6, -2.0), Vector3(0, 2.6, 12.0)],
	["end", Vector3(4.0, 1.6, 0), Vector3(15.0, 2.2, 0)],
	["behind the near stand", Vector3(0, 8.5, -18.0), Vector3(0, 0.5, -6.0)],
]


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0] if a.size() > 0 else "/tmp"
	var levels: Array = Array(a[1].split(",")).map(func(s): return int(s)) if a.size() > 1 else [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]
	var up := a.size() > 2 and a[2] == "up"
	get_window().size = TILE
	if a.size() > 2 and a[2] == "anim":
		await _anim(out, levels)
		get_tree().quit()
		return
	for g in levels:
		Game.settings.graphics = g
		var sheet := Image.create_empty(TILE.x * VIEWS.size(), TILE.y * DB.VENUES.size(), false, Image.FORMAT_RGB8)
		for row in DB.VENUES.size():
			var arena := Arena.new(DB.VENUES[row][0], false, [Color("ff8a1f")])
			add_child(arena)
			Crowd.set_excite(1.0 if up else 0.0)
			var cam := Camera3D.new()
			cam.fov = 40
			add_child(cam)
			cam.current = true
			for col in VIEWS.size():
				cam.position = VIEWS[col][1]
				cam.look_at(VIEWS[col][2])
				for i in (30 if up and col == 0 else 4):   # (time for the crowd to get up)
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				img.resize(TILE.x, TILE.y)
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, row * TILE.y))
			arena.queue_free()
			cam.queue_free()
			await get_tree().process_frame
		sheet.save_png(out.path_join("crowd_%s_%s.png" % ["up" if up else "facing", ["low", "medium", "high"][g]]))
		print("crowd sheet, graphics ", g)
	get_tree().quit()


const ANIM_FRAMES := 12


func _anim(out: String, levels: Array) -> void:
	for g in levels:
		Game.settings.graphics = g
		var venues := ["national", "beach"]
		var sheet := Image.create_empty(TILE.x * ANIM_FRAMES, TILE.y * venues.size() * 2, false, Image.FORMAT_RGB8)
		for row in venues.size():
			var arena := Arena.new(venues[row], false, [Color("ff8a1f")])
			add_child(arena)
			arena.crowd.show_teams("THA", "PHI")
			Crowd.set_excite(0.0)
			var cam := Camera3D.new()
			cam.fov = 16
			add_child(cam)
			cam.current = true
			cam.position = Vector3(6.8, 7.0, -13.2)
			cam.look_at(Vector3(-2.0, 2.5, 11.0) if venues[row] == "national" else Vector3(-2.0, 1.4, 9.0))
			# The ball from one end to the other and back, a frame every quarter of a second (the crowd's own clock).
			for col in ANIM_FRAMES:
				var t0 := Time.get_ticks_msec()
				while Time.get_ticks_msec() - t0 < 250:
					var k := float(col) + float(Time.get_ticks_msec() - t0) / 250.0
					Crowd.set_look(Vector3(6.5 * cos(k / ANIM_FRAMES * TAU), 0, 0))
					await get_tree().process_frame
				await _grab(sheet, col, row * 2)
			# A home point: up, cheering, a frame every eighth of a second.
			Crowd.set_excite(0.9)
			for col in ANIM_FRAMES:
				var t0 := Time.get_ticks_msec()
				while Time.get_ticks_msec() - t0 < (500 if col == 0 else 125):
					await get_tree().process_frame
				await _grab(sheet, col, row * 2 + 1)
			arena.queue_free()
			cam.queue_free()
			await get_tree().process_frame
		sheet.save_png(out.path_join("crowd_anim_%s.png" % ["low", "medium", "high"][g]))
		print("crowd anim, graphics ", g)


func _grab(sheet: Image, col: int, row: int) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(TILE.x, TILE.y)
	sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, row * TILE.y))
