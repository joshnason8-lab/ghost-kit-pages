extends Node
## A close look at the goalkeepers (helmet, trousers, stance). xvfb-run ... res://tools/meshy/keeper_view.tscn -- out.png
func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = 1
	get_window().size = Vector2i(1280, 720)
	var m: Node = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "arena", "user_team": -1, "demo": true, "seed": 9, "period": 4.0}
	add_child(m)
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	for i in 200:
		await get_tree().process_frame
	var gk: Player = m.keeper(0)
	var at := Vector3(gk.pos.x, 0.9, gk.pos.y)
	cam.global_position = at + Vector3(-signf(gk.pos.x) * 3.0, 0.6, 1.2)
	cam.look_at(at)
	cam.current = true
	for i in 3:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	get_tree().quit()
