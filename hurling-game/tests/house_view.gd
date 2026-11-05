extends Node3D
## The houses (game/houses.gd) close up: three terraces and two cottages as Scenery places them, by day or at night:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/house_view.tscn -- /out/houses.png [day|dusk|night]

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://houses.png"
	var time := a[1] if a.size() > 1 else "day"
	Game.main = self
	Game.settings.graphics = Game.GFX_HIGH
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("8fa7b8") if time != "night" else Color("10151c")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.75) if time != "night" else Color(0.2, 0.22, 0.28)
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.0 if time != "night" else 0.15
	add_child(sun)
	var g := Geo.new()
	g.floor_rect(-80, -30, 80, 40, 0.0, Color("4f6b3e"))
	add_child(g.commit(Geo.material()))
	var sc := Scenery.new(time)
	for i in 3:
		sc.add("house_row", Vector3(-31.0 + i * 31.0, 0, -6.0), 0.0)
	sc.add("house_cottage", Vector3(-14.0, 0, 18.0), 0.0)
	sc.add("house_cottage", Vector3(14.0, 0, 18.0), 0.0)
	sc.commit()
	add_child(sc)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 9.0, 52.0)
	cam.look_at(Vector3(0, 3.0, 0))
	cam.fov = 55
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
