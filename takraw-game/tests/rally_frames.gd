extends Node
## A burst of frames from an AI match, to look at how a rally moves:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/rally_frames.tscn -- /out/dir [start s] [every s] [n]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "/tmp/rally"
	var start := float(a[1]) if a.size() > 1 else 3.0
	var every := float(a[2]) if a.size() > 2 else 0.2
	var n := int(a[3]) if a.size() > 3 else 16
	DirAccess.make_dir_recursive_absolute(out)
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = Game.GFX_HIGH
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "THA", "away": "MAS", "venue": "national", "event": "regu", "sets": 1, "points": 15, "user_team": -1,
		"demo": true, "seed": 5, "mode": "quick"}
	add_child(m)
	await get_tree().create_timer(start).timeout
	for i in n:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("f%02d.png" % i))
		await get_tree().create_timer(every).timeout
	get_tree().quit()
