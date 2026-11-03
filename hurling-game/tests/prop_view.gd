extends Node
## The ground's solid props (Stadium.solid, the shared foundation's WsgSolidProps) drawn as their wire boxes over each
## ground, from a few places round the field (the dugouts, behind a goal, a corner flag, the touchline): a contact sheet
## to see that every prop a player or the ball can reach is solid, and where it is.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 res://tests/prop_view.tscn -- <out.png>

const W := 640
const H := 360


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://prop_view.png"
	Game.main = self
	Game.settings.sound = false
	var shots := []
	for v in ["parish", "county", "stadium"]:
		Game.start_match({"home": "KIL", "away": "TIP", "venue": v, "user_team": -1, "seed": 2, "mode": "test"})
		for i in 10:
			await get_tree().process_frame
		var m: Node = Game.current
		m.hud.visible = false
		m.set_process(false)
		var st: Stadium = m.stadium
		st.add_child(st.solid.debug_mesh())
		var cam := Camera3D.new()
		cam.fov = 60.0
		m.add_child(cam)
		cam.make_current()
		var hl := Pitch.HALF_L
		var hw := Pitch.HALF_W
		var views := [
			[Vector3(-4, 3.5, -hw + 6.0), Vector3(-10, 1.0, -hw - 3.5)],          # a dugout
			[Vector3(hl - 14.0, 4.0, 8.0), Vector3(hl + 2.0, 1.2, 0.0)],          # a goal, its net and what is behind
			[Vector3(hl - 8.0, 3.0, -hw + 6.0), Vector3(hl, 0.8, -hw - 2.0)],     # the corner flag and the boards
			[Vector3(-30, 6.0, 8.0), Vector3(-30, 1.0, -hw - 4.0)],               # the touchline, its flags, the stand
		]
		for vw in views:
			cam.look_at_from_position(vw[0], vw[1])
			for i in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.resize(W, H)
			shots.append(img)
		print("prop_view: %s: %d props, %d skipped" % [v, st.solid.props.size(), st.solid.skipped.size()])
	var cols := 4
	var rows := ceili(shots.size() / float(cols))
	var sheet := Image.create(W * cols, H * rows, false, (shots[0] as Image).get_format())
	for k in shots.size():
		sheet.blit_rect(shots[k], Rect2i(0, 0, W, H), Vector2i((k % cols) * W, (k / cols) * H))
	sheet.save_png(out)
	print("prop_view: ", out)
	get_tree().quit()
