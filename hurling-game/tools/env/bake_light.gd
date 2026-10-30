extends Node
## Exports each venue's built stadium (its stands, walls and roofs as Stadium builds them on Low and Medium) and its
## light for the shared foundation's Cycles bake (WsgLightBake, tools/wsg/blender/bake_light.py). Run by
## bake_light.sh, which bakes and puts the maps in assets/env/light (<kind>_<time>.json, _light.png, _ground.png).
##   godot --headless --path . res://tools/env/bake_light.tscn -- <out dir>

const GROUND_PAD := Vector2(20.0, 15.0)   # the grass beyond the field (Pitch.build's plane)


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	Game.settings.graphics = Game.GFX_MEDIUM
	var done := {}
	for venue: String in DB.VENUES:
		var st := Stadium.new(venue, [Color.RED, Color.WHITE], [Color.BLUE, Color.GOLD])
		var key := "%s_%s" % [st.kind, st.time]
		if done.has(key):
			st.free()
			continue
		done[key] = true
		add_child(st)
		await get_tree().process_frame
		var sun: DirectionalLight3D = st.find_children("*", "DirectionalLight3D", false, false)[0]
		var env: Environment = (st.find_children("*", "WorldEnvironment", false, false)[0] as WorldEnvironment).environment
		var amb := env.ambient_light_color
		var hx := Pitch.HALF_L + GROUND_PAD.x
		var hz := Pitch.HALF_W + GROUND_PAD.y
		var light := {
			"sun_dir": [st.to_sun.x, st.to_sun.y, st.to_sun.z],
			"sun_colour": [sun.light_color.r, sun.light_color.g, sun.light_color.b],
			"sun_energy": sun.light_energy,
			"sky_colour": [amb.r, amb.g, amb.b],
			"sky_energy": env.ambient_light_energy,
			"ground": [-hx, -hz, hx, hz, 0.0],
			"size": 2048,
			"scale": 2.0,
		}
		var sig := WsgLightBake.export(st.structure.mesh as ArrayMesh, light, out.path_join(key))
		print("bake_light: %s (%d vertices) signature %d" % [key, (st.structure.mesh as ArrayMesh).surface_get_array_len(0), sig])
		st.queue_free()
		await get_tree().process_frame
	get_tree().quit()
