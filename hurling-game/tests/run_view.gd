extends Node3D
## A player running, side-on, eight moments of one stride at each of three speeds (a jog, a run, a sprint), as a
## strip, to look at the run with the hurley (and with the ball on it, with "stick"):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/run_view.tscn -- /out/run.png [stick|back]
## back: moving backwards while facing forwards (a backpedal), at 1.5, 2.5 and 3 m/s.

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://run.png"
	var mode := a[1] if a.size() > 1 else ""
	Game.main = self
	Game.settings.graphics = Game.GFX_HIGH
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
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 7.4
	cam.position = Vector3(0, 1.0, 20)
	var speeds := [1.5, 2.5, 3.0] if mode == "back" else [3.0, 5.0, 7.5]
	var t := DB.team("KIL")
	var look := {"skin": Color("e8bc9a"), "hair": Color("4a3221"), "jersey": t.c1, "trim": t.c2, "shorts": Color("f6f6f2"),
		"socks": t.c1, "helmet": t.c2, "design": int(t.design), "height": 1.82, "kind": "player"}
	var ps := []
	for row in speeds.size():
		for i in 8:
			var p := Player.new({"num": 1, "line": 3, "speed": 70}, 0, look)
			p.position = Vector3(-6.3 + i * 1.8, 2.3 - row * 2.3, 0)
			add_child(p)
			ps.append(p)
	await get_tree().process_frame
	for row in speeds.size():
		var sp: float = speeds[row]
		for i in 8:
			var p: Player = ps[row * 8 + i]
			p.ball_stick = mode == "stick"
			# Running to the right of the picture (+x), side-on; a backpedal faces right and moves left.
			var d := -1.0 if mode == "back" else 1.0
			p.yaw = PI * 0.5
			p.face_to = p.position + Vector3(10, 0, 0) if mode == "back" else Vector3.ZERO
			p.want_vel = Vector3(sp * d, 0, 0)
			p.vel = p.want_vel
			var stride := Player.stride_at(sp)
			# Step it on to phase i/8 of a stride cycle, through integrate so the facing and the phase are its own.
			var dt := 1.0 / 60.0
			var steps := int(round((float(i) / 8.0) * (2.0 * stride / sp) / dt)) + 30
			var keep := p.position
			for k in steps:
				p.integrate(dt, k * dt)
				p.position = keep
			p.animate(1.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
