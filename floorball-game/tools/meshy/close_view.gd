extends Node
## Close looks at players in a match (the grip, the limbs, the kit): xvfb-run ... res://tools/meshy/close_view.tscn -- out_prefix [women]
func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = 1
	get_window().size = Vector2i(1280, 720)
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "arena", "user_team": -1, "demo": true, "seed": 9, "period": 4.0, "women": a.size() > 1 and a[1] == "women"}
	add_child(m)
	var cam := Camera3D.new()
	cam.fov = 35
	add_child(cam)
	var t := 0.0
	var k := 0
	var picks := [[0, 1, Vector3(0, 1.3, 3.2)], [0, 3, Vector3(2.8, 1.2, 0.5)], [1, 0, Vector3(0.3, 1.4, 3.0)], [0, 2, Vector3(-2.5, 1.6, 2.5)], [1, 4, Vector3(0, 1.0, 2.6)]]
	while k < picks.size():
		await get_tree().process_frame
		t += get_process_delta_time()
		if t < 4.0 + k * 1.5:
			continue
		var pk: Array = picks[k]
		var p: Player = m.players[pk[0]][pk[1]]
		var at := Vector3(p.pos.x, 0.9, p.pos.y)
		cam.global_position = at + (pk[2] as Vector3)
		cam.look_at(at)
		cam.current = true
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [a[0], k])
		k += 1
	get_tree().quit()
