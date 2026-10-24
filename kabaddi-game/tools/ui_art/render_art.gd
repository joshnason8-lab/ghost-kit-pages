extends Node3D
## Renders the menu tile art from the game's own players: transparent PNGs of a raider
## lunging, team-mates high-fiving, a roar, a lion jump, a referee's signal.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/ui_art/render_art.tscn -- OUTDIR
## then tools/ui_art/pack_art.sh OUTDIR to make the WebP files in assets/ui/.

const SHOTS := [
	# name, [[team, squad index, state, progress, pos, facing deg, extra]], camera pos, look at
	["quick", [["MUM", 0, "touch", 0.5, Vector3(0, 0, 0), 90.0, {}]], Vector3(0.0, 1.1, 4.4), Vector3(0.3, 0.9, 0)],
	["league", [["PAT", 1, "celebrate", 0.5, Vector3(-0.42, 0, 0), 90.0, {"cele": 3}], ["PAT", 2, "celebrate", 0.5, Vector3(0.42, 0, 0), -90.0, {"cele": 3}]], Vector3(0.0, 1.2, 4.6), Vector3(0, 1.05, 0)],
	["cup", [["IND", 0, "roar", 0.5, Vector3(0, 0, 0), 15.0, {}]], Vector3(0.0, 1.1, 4.2), Vector3(0, 1.0, 0)],
	["training", [["DEL", 3, "kick", 0.5, Vector3(0, 0, 0), 90.0, {}]], Vector3(0.0, 1.0, 4.4), Vector3(0.3, 0.85, 0)],
	["howto", [["", 0, "signal", 0.5, Vector3(0, 0, 0), 25.0, {"sig": 1, "official": true}]], Vector3(0.0, 1.2, 4.2), Vector3(0, 1.1, 0)],
	["defend", [["CHD", 4, "telegraph", 0.5, Vector3(0, 0, 0), 70.0, {"kind": "ankle"}]], Vector3(0.0, 0.9, 4.2), Vector3(0.1, 0.7, 0)],
	["dubki", [["KOL", 2, "dubki", 0.5, Vector3(0, 0, 0), 90.0, {}]], Vector3(0.0, 0.9, 4.2), Vector3(0.2, 0.7, 0)],
	["auction", [["JAI", 5, "argue", 0.5, Vector3(0, 0, 0), 30.0, {}]], Vector3(0.0, 1.2, 4.2), Vector3(0, 1.05, 0)],
]


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	get_viewport().transparent_bg = true
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.62, 0.75)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-35), deg_to_rad(35), 0)
	key.light_energy = 1.6
	key.light_color = Color("fff1dc")
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation = Vector3(deg_to_rad(-10), deg_to_rad(200), 0)
	rim.light_energy = 1.3
	rim.light_color = Color("ffb35c")
	add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30
	add_child(cam)
	for shot in SHOTS:
		var actors := []
		for spec in shot[1]:
			var a := Athlete.new()
			var extra: Dictionary = spec[6]
			if extra.get("official", false):
				var data := {"id": "REF", "name": "", "role": "official", "number": 0, "skin": 3, "hair": 1, "build": 1.0, "height": 1.76,
					"attrs": {"speed": 55, "agility": 55, "strength": 55, "reach": 55, "tackle": 40, "stamina": 70}}
				a.setup(data, 2, Officials.SHIRT, Officials.SHORTS, false)
			else:
				var t := DB.team(spec[0])
				a.setup(t.squad[spec[1]], 0, t.c1, t.c2, true)
			add_child(a)
			a.position = spec[4]
			var ang := deg_to_rad(spec[5])
			a.facing = Vector3(sin(ang), 0, cos(ang))
			a.lock_facing = true
			a.cele_kind = int(extra.get("cele", 0))
			a.sig_kind = int(extra.get("sig", 0))
			a.tackle_kind = String(extra.get("kind", ""))
			a.set_state(spec[2], 1000.0)
			a.st_t = 1000.0 * float(spec[3])
			a.set_process(false)
			actors.append(a)
		for f in 40:
			for a in actors:
				a._pose(1.0 / 30.0)
				a.model._process(1.0 / 30.0)
				a.rotation.y = atan2(-a.facing.x, -a.facing.z)
		cam.position = shot[2]
		cam.look_at(shot[3])
		for f in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/art_" + shot[0] + ".png")
		for a in actors:
			a.queue_free()
		await get_tree().process_frame
	get_tree().quit()
