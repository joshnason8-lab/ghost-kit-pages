extends Node
## The officials through a rally, close up: the referee in his chair, the assistant at the other post and a line
## judge, a frame every so often (each a row: their heads on the ball, the breath, a weight shift, the signals):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/officials_view.tscn -- out.png [n] [every s]

const TILE := Vector2i(320, 360)


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "/tmp/officials.png"
	var n := int(a[1]) if a.size() > 1 else 8
	var every := float(a[2]) if a.size() > 2 else 0.6
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	get_window().size = TILE
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "THA", "away": "MAS", "venue": "national", "event": "regu", "sets": 1, "points": 15, "user_team": -1,
		"demo": true, "seed": 5, "mode": "quick"}
	add_child(m)
	await get_tree().create_timer(3.0).timeout
	var who: Array = [m.officials[0], m.officials[1], m.officials[2]]
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	var sheet := Image.create_empty(TILE.x * n, TILE.y * who.size(), false, Image.FORMAT_RGB8)
	for i in n:
		for r in who.size():
			var o: Node3D = who[r]
			var front := o.global_transform.basis.z
			var head := o.global_position + Vector3(0, 1.0 if r != 1 else 1.1, 0)
			cam.global_position = head + front * 4.5 + Vector3(0, 0.6, 0) + o.global_transform.basis.x * 1.2
			cam.look_at(head)
			cam.current = true
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.resize(TILE.x, TILE.y)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, TILE), Vector2i(i * TILE.x, r * TILE.y))
		await get_tree().create_timer(every).timeout
	sheet.save_png(out)
	print("officials: %d frames" % n)
	get_tree().quit()
