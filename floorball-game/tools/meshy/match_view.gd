extends Node
## Screenshots of a match with the owner's models: xvfb-run -a godot --path . --rendering-driver opengl3
##   res://tools/meshy/match_view.tscn -- out_prefix [women] [graphics 0-2] [venue]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out: String = a[0]
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = int(a[2]) if a.size() > 2 else 0
	get_window().size = Vector2i(1280, 720)
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": a[3] if a.size() > 3 else "arena", "user_team": 0, "seed": 4, "period": 4.0,
		"mode": "quick", "women": a.size() > 1 and a[1] == "women"}
	add_child(m)
	var shots := [3.0, 6.0, 9.0, 13.0]
	var t := 0.0
	var k := 0
	while k < shots.size():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t >= shots[k]:
			get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, k])
			if k == 1:
				m.cam.mode = Game.CAM_END
			k += 1
	get_tree().quit()
