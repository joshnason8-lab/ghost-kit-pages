extends Node
## Renders the spectators' sheet (assets/models/crowd_sheet.png) from the players' own models: men and women of a
## few skin tones, whole (from the feet up), in four rows: seated (some clapping, a hand up) from the front, the same
## from behind (what a camera behind a stand sees), then standing (arms at their sides, clapping, hands on hips, a fist
## or both arms up) from the front and from behind. The shirt is left white with its shading, and marked in the alpha
## (0.7: the shirt, 1: the rest), for Crowd's shader to dye.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/models/crowd_sheet.tscn [-- hi]
## hi: Medium's and High's bigger sheet (crowd_sheet_hi.png): 32 figures at 96 x 256 px, from the 2048 px textures;
## six skin tones, heights from 1.55 to 1.88 m, shorts in their own colours (only the shirt is dyed), more poses
## (elbows on the knees, hands in the lap, filming with a phone).

const SCALE := 4   # rendered this much larger, then shrunk, for clean edges
const SKINS := [Color("e0b48c"), Color("c98a5a"), Color("b07448"), Color("8d5a36")]
const SKINS_HI := [Color("f1cfa8"), Color("e0b48c"), Color("c98a5a"), Color("b07448"), Color("8d5a36"), Color("6b432a")]
const SHORTS_HI := [Color("1f2a44"), Color("1a1a1a"), Color("6b5a43"), Color("8a8f96"), Color("34507a"), Color("d8d8d8"),
	Color("3b4a3a")]

var _hi := false


func _ready() -> void:
	_hi = "hi" in OS.get_cmdline_user_args()
	Game.settings.graphics = Game.GFX_HIGH
	RealBody.textures = 1 if _hi else 0
	var figs := Crowd.FIGS_HI if _hi else Crowd.FIGS
	var fw := Crowd.FIG_W_HI if _hi else Crowd.FIG_W
	var fh := Crowd.FIG_H_HI if _hi else Crowd.FIG_H
	var w := fw * SCALE
	var h := fh * SCALE
	var sheet := Image.create_empty(fw * figs, fh * Crowd.ROWS, false, Image.FORMAT_RGBA8)
	for f in figs:
		var women := f % 2 == 1
		var look := {"women": women, "jersey": Color.WHITE, "shorts": Color("d8d8d8"), "skin": SKINS[(f / 2) % 4],
			"height": 1.75 if not women else 1.65}
		if _hi:
			look.skin = SKINS_HI[(f / 2 + f / 12) % SKINS_HI.size()]
			look.shorts = SHORTS_HI[(f * 3 + f / 7) % SHORTS_HI.size()]
			look.height = (1.68 + 0.2 * float((f * 5) % 9) / 8.0) if not women else (1.55 + 0.15 * float((f * 7) % 9) / 8.0)
		for row in Crowd.ROWS:
			var behind := row % 2 == 1
			var pose := _seated(f) if row < 2 else _standing(f)
			var colour := await _shot(look, pose, w, h, false, behind)
			var mask := await _shot(look, pose, w, h, true, behind)
			var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
			for y in h:
				for x in w:
					var c := colour.get_pixel(x, y)
					if c.a < 0.5:
						continue
					var shirt := mask.get_pixel(x, y).r > 0.5
					out.set_pixel(x, y, Color(c.r, c.g, c.b, 0.7 if shirt else 1.0))
			out.resize(fw, fh, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(out, Rect2i(0, 0, fw, fh), Vector2i(f * fw, row * fh))
	sheet.save_png(ProjectSettings.globalize_path(Crowd.SHEET_HI if _hi else Crowd.SHEET))
	print("crowd sheet: %d figures, %d rows%s" % [figs, Crowd.ROWS, " (hi)" if _hi else ""])
	get_tree().quit()


## Figure f seated: hands on the knees, or clapping; now and then a hand up.
func _seated(f: int) -> Dictionary:
	var pose := Moves.static_pose("sit")
	match f % 4:
		1, 2:   # clapping
			pose.upperarm_l = Vector3(-55, 0, 2)
			pose.upperarm_r = Vector3(-55, 0, -2)
			pose.forearm_l = Vector3(-62, 0, 0)
			pose.forearm_r = Vector3(-62, 0, 0)
	if _hi:
		match f % 8:
			3:   # elbows on the knees, leaning in
				pose.spine = Vector3(24, 0, 0)
				pose.upperarm_l = Vector3(-62, 0, 6)
				pose.upperarm_r = Vector3(-62, 0, -6)
				pose.forearm_l = Vector3(-75, 0, 0)
				pose.forearm_r = Vector3(-75, 0, 0)
			5:   # hands in the lap
				pose.upperarm_l = Vector3(-18, 0, -2)
				pose.upperarm_r = Vector3(-18, 0, 2)
				pose.forearm_l = Vector3(-72, 0, 0)
				pose.forearm_r = Vector3(-72, 0, 0)
			7:   # filming with a phone
				pose.upperarm_r = Vector3(-75, 0, -8)
				pose.forearm_r = Vector3(-95, 0, 0)
	if f % 7 == 3:   # a hand up
		pose.upperarm_r = Vector3(-165, 0, -12)
		pose.forearm_r = Vector3(-15, 0, 0)
	pose.head = Vector3(-6 + (f % 3) * 6, (f % 5 - 2) * 8, 0)
	return pose


## Figure f standing: arms at the sides, clapping, hands on the hips, a fist up, or both arms up; the weight on one leg.
func _standing(f: int) -> Dictionary:
	var pose := Moves.static_pose("stand")
	match f % 5:
		1, 3:   # clapping
			pose.upperarm_l = Vector3(-50, 0, 4)
			pose.upperarm_r = Vector3(-50, 0, -4)
			pose.forearm_l = Vector3(-70, 0, 0)
			pose.forearm_r = Vector3(-70, 0, 0)
		2:   # hands on the hips
			pose.upperarm_l = Vector3(8, 0, 32)
			pose.upperarm_r = Vector3(8, 0, -32)
			pose.forearm_l = Vector3(-95, 0, -20)
			pose.forearm_r = Vector3(-95, 0, 20)
		4:   # a fist up
			pose.upperarm_r = Vector3(-160, 0, -14)
			pose.forearm_r = Vector3(-35, 0, 0)
	if _hi and f % 9 == 6:   # filming with a phone
		pose.upperarm_r = Vector3(-80, 0, -10)
		pose.forearm_r = Vector3(-90, 0, 0)
	if f % 7 == 5:   # both arms up
		pose.upperarm_l = Vector3(-165, 0, 16)
		pose.upperarm_r = Vector3(-165, 0, -16)
		pose.forearm_l = Vector3(-12, 0, 0)
		pose.forearm_r = Vector3(-12, 0, 0)
	var lean := 1.0 if f % 2 == 0 else -1.0
	pose.hips = Vector3(0, 0, 2.5 * lean)
	pose.spine = Vector3(2, 0, -3.0 * lean)
	pose.thigh_l = Vector3(0, 0, 3.0 - 2.5 * lean)
	pose.thigh_r = Vector3(0, 0, -3.0 - 2.5 * lean)
	pose.head = Vector3(-4 + (f % 3) * 5, (f % 5 - 2) * 7, 0)
	return pose


## One figure, from the front (or from behind), the frame from the floor to above a hand held up; with mask, just the
## shirt in white.
func _shot(look: Dictionary, pose: Dictionary, w: int, h: int, mask: bool, behind := false) -> Image:
	var sv := SubViewport.new()
	sv.size = Vector2i(w, h)
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.msaa_3d = Viewport.MSAA_4X
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sv)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.82, 0.88)
	env.environment.ambient_light_energy = 0.75
	sv.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 20, 0)
	sun.light_energy = 1.1
	sv.add_child(sun)
	var b := RealBody.new(look)
	sv.add_child(b)
	b.apply(pose)
	if mask:
		var sh := Shader.new()
		sh.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D kit_tex : filter_linear_mipmap;
uniform float panels = 1.0;
void fragment() { vec3 k = texture(kit_tex, UV).rgb; ALBEDO = vec3(step(0.5, k.r + k.g * panels)); }
"""
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("kit_tex", load((RealBody.KITS_HI if _hi else RealBody.KITS)[bool(look.women)]))
		m.set_shader_parameter("panels", 0.0 if _hi else 1.0)   # (hi: the shorts and panels keep their own colour)
		b.mesh_instance.material_override = m
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = Crowd.FIG_H_M
	var mid := Vector3(0, Crowd.FIG_H_M * 0.5, 0)
	cam.position = mid + Vector3(0, 0.55, -4.0 if behind else 4.0)   # a little from above, as from the court
	sv.add_child(cam)
	cam.look_at(mid)
	cam.current = true
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	sv.queue_free()
	return img
