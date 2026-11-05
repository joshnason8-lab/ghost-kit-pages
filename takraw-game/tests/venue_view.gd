extends Node3D
## Renders each venue from the broadcast camera with two regus on court, to look at:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/venue_view.tscn -- /out/dir [venue,...][,low][,around]
## around: also from the match's other cameras (the end camera from each end, the side camera) and looking out from
## the court along each axis, to check the far ground, the sea and the horizon.

const AROUND := [   # name, camera, looking at
	["end_a", Vector3(13.7, 4.4, 0.0), Vector3(-1.5, 1.0, 0.0)],
	["end_b", Vector3(-13.7, 4.4, 0.0), Vector3(1.5, 1.0, 0.0)],
	["side", Vector3(0, 7.2, -15.5), Vector3(0, 0.6, 0.5)],
	["out_far", Vector3(0, 3.0, -5.0), Vector3(0, 2.0, 60.0)],
	["out_end", Vector3(-6.0, 3.0, 4.0), Vector3(80.0, 2.0, 20.0)],
]

func _ready() -> void:
	print("venue view start")
	var out := "/tmp"
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		out = a[0]
	var only: Array = Array(a[1].split(",")) if a.size() > 1 else []
	# "low" in the list: on Low graphics (else High); any venue ids: just those.
	var low := "low" in only
	only.erase("low")
	var around := "around" in only
	only.erase("around")
	Game.settings.graphics = Game.GFX_HIGH if not low else Game.GFX_LOW
	for v in DB.VENUES:
		if not only.is_empty() and not (v[0] in only):
			continue
		var holder := Node3D.new()
		add_child(holder)
		print("building ", v[0])
		var arena := Arena.new(v[0], false, [Color("ff8a1f")])
		holder.add_child(arena)
		var cam := Camera3D.new()
		cam.fov = 42
		cam.position = Vector3(0, 7.2, -15.5)
		holder.add_child(cam)
		cam.look_at(Vector3(0, 0.6, 0.5))
		cam.current = true
		var spots := [[Vector3(-4.25, 0, 0), "", 0.0], [Vector3(-0.6, 0, -2.45), "", 0.0], [Vector3(-0.8, 0, 2.2), "roll", 0.48],
			[Vector3(4.0, 0, 0), "", 0.0], [Vector3(2.0, 0, -1.5), "", 0.0], [Vector3(0.6, 0, 2.0), "block", 0.45]]
		for i in spots.size():
			var s: Array = spots[i]
			var side := 0 if i < 3 else 1
			var look := {"jersey": Color("ff8a1f") if side == 0 else Color("19b3a3"), "shorts": Color("2a1a0e") if side == 0 else Color("0e3b4f"),
				"skin": [Color("c98a5a"), Color("b07448"), Color("e0b48c")][i % 3]}
			var b := RealBody.new(look)
			holder.add_child(b)
			b.position = s[0]
			b.rotation.y = Court.facing(side)
			var p: Dictionary = Moves.READY if s[1] == "" else Moves.sample(s[1], s[2])
			b.apply(p)
			b.position.y = float(p.get("y", 0.0))
		var ball := Ball.new()
		holder.add_child(ball)
		ball.hold(Vector3(-0.35, 2.55, 2.2))
		for i in 5:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("venue_%s_%s.png" % [v[0], "low" if low else "high"]))
		print("shot ", v[0], " draw calls: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		if around:
			cam.fov = 60
			for view in AROUND:
				cam.position = view[1]
				cam.look_at(view[2])
				for i in 3:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out.path_join("venue_%s_%s_%s.png" % [v[0], "low" if low else "high", view[0]]))
		holder.queue_free()
		await get_tree().process_frame
	get_tree().quit()
