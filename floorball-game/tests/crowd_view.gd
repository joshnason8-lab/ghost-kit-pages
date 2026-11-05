extends Node
## Looks at every stand from the rink (the broadcast camera cannot see the near stand's faces): from the centre spot,
## eye height, toward the near side (+z, the camera's side), the far side and both ends, and from near a corner across
## the side stands at an angle. xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/crowd_view.tscn -- out_prefix venue gfx
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = int(a[2]) if a.size() > 2 else 0
	get_window().size = Vector2i(1280, 720)
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": a[1] if a.size() > 1 else "arena", "user_team": -1, "demo": true, "seed": 3, "period": 4.0}
	add_child(m)
	for i in 30:
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.fov = 60
	add_child(cam)
	cam.current = true
	var views := {"near": [Vector3(0, 1.6, 0), Vector3(0, 3.0, 20)], "far": [Vector3(0, 1.6, 0), Vector3(0, 3.0, -20)],
		"end_left": [Vector3(0, 1.6, 0), Vector3(-30, 3.0, 0)], "end_right": [Vector3(0, 1.6, 0), Vector3(30, 3.0, 0)],
		"angle_near": [Vector3(-12, 1.6, -4), Vector3(10, 3.0, 18)], "angle_far": [Vector3(12, 1.6, 4), Vector3(-10, 3.0, -18)],
		"behind_near": [Vector3(0, 9.0, 24.0), Vector3(0, 2.0, 12.0)], "behind_far": [Vector3(0, 9.0, -24.0), Vector3(0, 2.0, -12.0)]}
	for v in views:
		cam.global_position = views[v][0]
		cam.look_at(views[v][1])
		for i in 4:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [a[0], v])
	get_tree().quit()
