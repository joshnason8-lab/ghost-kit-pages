extends Node3D
## The crowd seen from the court, to check that every spectator faces the play: in each venue, cameras on the court
## looking at the near stand, the far stand and an end, and one behind the near stand looking over it at the court
## (where the spectators should show their backs). One sheet a graphics level, a row a venue:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/crowd_view.tscn -- /out/dir [0,1,2]

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
	get_window().size = TILE
	for g in levels:
		Game.settings.graphics = g
		var sheet := Image.create_empty(TILE.x * VIEWS.size(), TILE.y * DB.VENUES.size(), false, Image.FORMAT_RGB8)
		for row in DB.VENUES.size():
			var arena := Arena.new(DB.VENUES[row][0], false, [Color("ff8a1f")])
			add_child(arena)
			var cam := Camera3D.new()
			cam.fov = 40
			add_child(cam)
			cam.current = true
			for col in VIEWS.size():
				cam.position = VIEWS[col][1]
				cam.look_at(VIEWS[col][2])
				for i in 4:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var img := get_viewport().get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				img.resize(TILE.x, TILE.y)
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, row * TILE.y))
			arena.queue_free()
			cam.queue_free()
			await get_tree().process_frame
		sheet.save_png(out.path_join("crowd_facing_%s.png" % ["low", "medium", "high"][g]))
		print("crowd sheet, graphics ", g)
	get_tree().quit()
