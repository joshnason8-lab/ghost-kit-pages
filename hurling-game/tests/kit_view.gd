extends Node3D
## Close-ups of the players and officials: each county's kit, the helmet and face guard, the hurley, the poses.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tests/kit_view.tscn -- /out/dir [level]

func _ready() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://kits"
	Game.main = self
	# (A second argument picks the level: 3 for Ultra, run with --rendering-method mobile.)
	Game.settings.graphics = int(OS.get_cmdline_user_args()[1]) if OS.get_cmdline_user_args().size() > 1 else Game.GFX_HIGH
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2f5a3a")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.3, 6.5)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.fov = 40
	var ids := ["KIL", "TIP", "COR", "LIM", "CLA", "GAL", "WEX", "DUB"]
	var actions := ["", "strike", "solo_carry", "catch", "hand_pass", "lift", "tackle", "celebrate"]
	var ps := []
	for i in ids.size():
		var t := DB.team(ids[i])
		var look := {"skin": Color("e8bc9a"), "hair": Color("4a3221"), "jersey": t.c1, "trim": t.c2, "shorts": Color("f6f6f2") if t.c1.get_luminance() < 0.6 else Color("1a1a1a"),
			"socks": t.c1, "helmet": t.c2, "design": int(t.design), "height": 1.82, "kind": "player"}
		var p := Player.new({"num": i + 1, "line": 3, "speed": 70}, 0, look)
		p.position = Vector3(-3.5 + i * 1.0, 0, 0)
		add_child(p)
		ps.append(p)
	await get_tree().process_frame
	for i in ps.size():
		var p: Player = ps[i]
		p.yaw = 0.3
		p.body.rotation.y = 0.3
		var a: String = actions[i]
		if a == "solo_carry":
			p.ball_stick = true
		elif a != "":
			p.play(a)
			p.action_t = p.action_len * 0.45
		p.animate(0.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("kits.png"))
	# Officials.
	for p in ps:
		p.queue_free()
	var o := Officials.new(self)
	add_child(o)
	await get_tree().process_frame
	var sigs := ["sig_free", "sig_advantage", "sig_card", "sig_point", "sig_goal", "sig_wide", "sig_65"]
	var people: Array = [o.referee, o.referee, o.referee, o.umpires[0], o.umpires[1], o.umpires[2], o.umpires[3]]
	for i in sigs.size():
		var p: Player = people[i] if i >= 3 else (o.referee if i == 0 else (o.linesmen[0] if i == 1 else o.linesmen[1]))
		p.position = Vector3(-3.0 + i * 1.0, 0, 0)
		p.yaw = 0.0
		p.body.rotation.y = 0.0
		if i == 2:
			p.card_colour = "yellow"
		p.play(sigs[i])
		p.action_t = p.action_len * 0.7
		p.animate(1.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out.path_join("officials.png"))
	get_tree().quit()
