extends Node
## Close-ups of every ground's crowd, area by area (the stands' seats, the terraces, the banks, the rail), to see
## how the fans sit and stand: in their seats or through them, floating, facing the field or away. Each area from the
## front (from the field, a little to the side) and three-quarter on (along the row), at the graphics level given,
## as a match draws it (the 3D fans on the far stand, cut-outs elsewhere), and with "here" the 3D fans put on that
## area (Medium and High) to see how they fit it.
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 res://tests/crowd_view.tscn -- \
##     <out dir> [graphics 0-2] [venue] [here]
## Writes <venue>_<area>_<level>[_here]_<front|three>.png.

const H := Pitch.HALF_L
const W := Pitch.HALF_W


## Each spectator area of a ground: [name, a point among its people (their feet), the way to the field, the way along
## its rows].
static func areas(kind: String) -> Array:
	var a := []
	match kind:
		"parish":
			a.append(["stand", Vector3(6, 0.8 + 4 * 0.38, -W - 6.0 - 4 * 0.75), Vector3(0, 0, 1), Vector3(1, 0, 0)])
			a.append(["bank", Vector3(40, 0.3 + 0.55, -W - 5.0 - 1.6), Vector3(0, 0, 1), Vector3(1, 0, 0)])
			a.append(["rail", Vector3(10, 0, W + 4.75), Vector3(0, 0, -1), Vector3(1, 0, 0)])
		"county":
			a.append(["far_stand", Vector3(6, 1.4 + 8 * 0.42, -W - 6.0 - 8 * 0.8 - 0.4), Vector3(0, 0, 1), Vector3(1, 0, 0)])
			a.append(["side_terrace", Vector3(68, 0.6 + 4 * 0.32, -W - 6.0 - 4 * 0.7 - 0.35), Vector3(0, 0, 1), Vector3(1, 0, 0)])
			a.append(["end_terrace", Vector3(H + 8.0 + 6 * 0.7 + 0.35, 0.6 + 6 * 0.32, 4), Vector3(-1, 0, 0), Vector3(0, 0, 1)])
			a.append(["near_stand", Vector3(6, 0.8 + 3 * 0.42, W + 6.0 + 3 * 0.8 + 0.4), Vector3(0, 0, -1), Vector3(1, 0, 0)])
		"stadium":
			a.append(["far_lower", Vector3(6, 1.4 + 8 * 0.42, -W - 6.0 - 8 * 0.8 - 0.4), Vector3(0, 0, 1), Vector3(1, 0, 0)])
			a.append(["far_upper", Vector3(6, 14.0 + 6 * 0.6, -W - 26.0 - 6 * 0.85 - 0.42), Vector3(0, 0, 1), Vector3(1, 0, 0)])
			a.append(["end_stand", Vector3(H + 9.0 + 8 * 0.85 + 0.42, 1.4 + 8 * 0.55, 4), Vector3(-1, 0, 0), Vector3(0, 0, 1)])
			a.append(["terrace", Vector3(-H - 9.0 - 8 * 0.7 - 0.35, 0.6 + 8 * 0.32, 4), Vector3(1, 0, 0), Vector3(0, 0, 1)])
			a.append(["near_lower", Vector3(6, 1.4 + 3 * 0.42, W + 6.0 + 3 * 0.8 + 0.4), Vector3(0, 0, -1), Vector3(1, 0, 0)])
			var c := Vector3(H + 12.0, 0, -(W + 12.0))
			var toward := Vector3(-1, 0, 1).normalized()
			a.append(["corner", c - toward * (6 * 0.85 + 0.42) + Vector3(0, 1.4 + 6 * 0.6, 0), toward, Vector3(1, 0, 1).normalized()])
	return a


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://crowd"
	DirAccess.make_dir_recursive_absolute(out)
	var level := int(a[1]) if a.size() > 1 else Game.GFX_HIGH
	var only := a[2] if a.size() > 2 else ""
	var here := "here" in a
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = level
	for v in DB.VENUES:
		if only != "" and v != only:
			continue
		Game.start_match({"home": "KIL", "away": "TIP", "venue": v, "user_team": -1, "seed": 2, "mode": "test"})
		for i in 20:
			await get_tree().process_frame
		var m: Node = Game.current
		m.hud.visible = false     # (the score bug and buttons off: the crowd only)
		var st: Stadium = m.stadium
		var cam := Camera3D.new()
		m.add_child(cam)
		cam.fov = 50.0
		cam.make_current()
		for ar in areas(st.kind):
			var target: Vector3 = ar[1]
			var toward: Vector3 = ar[2]
			var along: Vector3 = ar[3]
			if here:
				st.build_crowd(target, level)
				for i in 4:
					await get_tree().process_frame
			var shots := {
				"front": [target + toward * 10.0 + along * 2.0 + Vector3(0, 2.6, 0), target + Vector3(0, 0.9, 0)],
				"three": [target + toward * 3.2 + along * 5.0 + Vector3(0, 1.3, 0), target + Vector3(0, 0.8, 0) - along * 1.0],
			}
			for s in shots:
				cam.look_at_from_position(shots[s][0], shots[s][1])
				for i in 3:
					await get_tree().process_frame
				await RenderingServer.frame_post_draw
				var name := "%s_%s_%d%s_%s.png" % [v, ar[0], level, "_here" if here else "", s]
				get_viewport().get_texture().get_image().save_png(out.path_join(name))
				print("crowd_view: ", name)
		cam.queue_free()
	get_tree().quit()
