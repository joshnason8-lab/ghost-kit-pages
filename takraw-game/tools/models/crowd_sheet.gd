extends Node
## Renders the spectators' sheet (assets/models/crowd_sheet.png) from the players' own models: men and women of a
## few skin tones, whole (from the feet up). First each figure at rest, seated (hands on the knees or in the lap,
## leaning in) and standing (arms at the sides, hands on the hips, arms folded), each seen from five sides
## (Crowd.VIEWS: the front, three-quarters, the side, three-quarters from behind, behind; the camera on the figure's
## left, Crowd's shader mirrors them for the right), so a spectator turned to the play shows the side the camera sees
## of them. Then the same people cheering, each their own way (Crowd.CHEERS: clapping, jumping, pumping a fist, both
## arms up and swaying), Crowd.CHEER_FRAMES frames of it from each of the five sides, for the shader to play.
## Where each goes on the sheet: Crowd.cell(). The shirt is left white with its shading, and marked in the alpha (0.7:
## the shirt, 1: the rest), for Crowd's shader to dye.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/models/crowd_sheet.tscn [-- hi]
## hi: Medium's and High's bigger sheet (crowd_sheet_hi.png): 32 figures at 96 x 256 px, from the 2048 px textures;
## six skin tones, heights from 1.55 to 1.88 m, shorts in their own colours (only the shirt is dyed), more poses
## (filming with a phone).
##   ... crowd_sheet.tscn -- poses out.png [hi]: every pose of the first four people from the front, to look at.

const SCALE := 4   # rendered this much larger, then shrunk, for clean edges
const SKINS := [Color("e0b48c"), Color("c98a5a"), Color("b07448"), Color("8d5a36")]
const SKINS_HI := [Color("f1cfa8"), Color("e0b48c"), Color("c98a5a"), Color("b07448"), Color("8d5a36"), Color("6b432a")]
const SHORTS_HI := [Color("1f2a44"), Color("1a1a1a"), Color("6b5a43"), Color("8a8f96"), Color("34507a"), Color("d8d8d8"),
	Color("3b4a3a")]

var _hi := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_hi = "hi" in args
	Game.settings.graphics = Game.GFX_HIGH
	RealBody.textures = 1 if _hi else 0
	if args.size() > 1 and args[0] == "poses":
		await _poses(args[1])
		get_tree().quit()
		return
	var figs := Crowd.FIGS_HI if _hi else Crowd.FIGS
	var fw := Crowd.FIG_W_HI if _hi else Crowd.FIG_W
	var fh := Crowd.FIG_H_HI if _hi else Crowd.FIG_H
	var cols := Crowd.cols(figs)
	var sheet := Image.create_empty(fw * cols, fh * Crowd.SHEET_ROWS, false, Image.FORMAT_RGBA8)
	var n := Crowd.VIEWS.size()
	for f in figs:
		var look := _look(f % (figs / 2))
		for row in Crowd.ROWS:
			var seated := row < n
			var pose := _seated(f) if seated else _standing(f)
			# (Seated, the knees reach forward: from the side the frame is centred a little in front of them.)
			var img := await _figure(look, pose, Crowd.VIEWS[row % n], 0.16 if seated else 0.0, fw, fh)
			_put(sheet, img, Crowd.cell(row * figs + f, figs), cols, fw, fh)
	for l in figs / 2:
		var look := _look(l)
		for fr in Crowd.CHEER_FRAMES:
			var pose := _cheer(l, fr)
			for v in n:
				var img := await _figure(look, pose, Crowd.VIEWS[v], 0.0, fw, fh)
				_put(sheet, img, Crowd.cell(Crowd.cheer_cell(l, fr, v, figs), figs), cols, fw, fh)
	sheet.save_png(ProjectSettings.globalize_path(Crowd.SHEET_HI if _hi else Crowd.SHEET))
	print("crowd sheet: %d figures, %d x %d cells%s" % [figs, cols, Crowd.SHEET_ROWS, " (hi)" if _hi else ""])
	get_tree().quit()


## Person l: a man or a woman, their skin, height and shorts. (Figures l and l + half the sheet are the same person
## in another pose: the one cheering frames are drawn for.)
func _look(l: int) -> Dictionary:
	var women := l % 2 == 1
	var look := {"women": women, "jersey": Color.WHITE, "shorts": Color("d8d8d8"), "skin": SKINS[(l / 2) % 4],
		"height": 1.75 if not women else 1.65}
	if _hi:
		look.skin = SKINS_HI[(l / 2 + l / 12) % SKINS_HI.size()]
		look.shorts = SHORTS_HI[(l * 3 + l / 7) % SHORTS_HI.size()]
		look.height = (1.68 + 0.2 * float((l * 5) % 9) / 8.0) if not women else (1.55 + 0.15 * float((l * 7) % 9) / 8.0)
	return look


func _put(sheet: Image, img: Image, at: Vector2i, _cols: int, fw: int, fh: int) -> void:
	sheet.blit_rect(img, Rect2i(0, 0, fw, fh), Vector2i(at.x * fw, at.y * fh))


## Figure f seated, at rest: hands on the knees, clasped in the lap, or elbows on the knees leaning in.
func _seated(f: int) -> Dictionary:
	var pose := Moves.static_pose("sit")
	match f % 4:
		1:   # hands clasped in the lap
			pose.upperarm_l = Vector3(-18, 0, -2)
			pose.upperarm_r = Vector3(-18, 0, 2)
			pose.forearm_l = Vector3(-72, 0, 0)
			pose.forearm_r = Vector3(-72, 0, 0)
		3:   # elbows on the knees, leaning in
			pose.spine = Vector3(24, 0, 0)
			pose.upperarm_l = Vector3(-62, 0, 6)
			pose.upperarm_r = Vector3(-62, 0, -6)
			pose.forearm_l = Vector3(-75, 0, 0)
			pose.forearm_r = Vector3(-75, 0, 0)
	if _hi and f % 8 == 6:   # filming with a phone
		pose.upperarm_r = Vector3(-75, 0, -8)
		pose.forearm_r = Vector3(-95, 0, 0)
	if f % 7 == 2:   # leaning back
		pose.spine = Vector3(-8, 0, 0)
	pose.head = Vector3(-6 + (f % 3) * 6, (f % 5 - 2) * 8, 0)
	return pose


## Figure f standing, at rest: arms at the sides, hands on the hips, arms folded, hands together in front; the weight
## on one leg.
func _standing(f: int) -> Dictionary:
	var pose := Moves.static_pose("stand")
	match f % 4:
		1:   # hands on the hips
			pose.upperarm_l = Vector3(8, 0, 32)
			pose.upperarm_r = Vector3(8, 0, -32)
			pose.forearm_l = Vector3(-95, 0, -20)
			pose.forearm_r = Vector3(-95, 0, 20)
		2:   # arms folded
			pose.upperarm_l = Vector3(-22, 0, 6)
			pose.upperarm_r = Vector3(-22, 0, -6)
			pose.forearm_l = Vector3(-112, -70, 0)
			pose.forearm_r = Vector3(-104, 70, 0)
		3:   # hands together in front
			pose.upperarm_l = Vector3(-14, 0, -4)
			pose.upperarm_r = Vector3(-14, 0, 4)
			pose.forearm_l = Vector3(-58, 0, 0)
			pose.forearm_r = Vector3(-58, 0, 0)
	if _hi and f % 9 == 6:   # filming with a phone
		pose.upperarm_r = Vector3(-80, 0, -10)
		pose.forearm_r = Vector3(-90, 0, 0)
	var lean := 1.0 if f % 2 == 0 else -1.0
	pose.hips = Vector3(0, 0, 2.5 * lean)
	pose.spine = Vector3(2, 0, -3.0 * lean)
	pose.thigh_l = Vector3(0, 0, 3.0 - 2.5 * lean)
	pose.thigh_r = Vector3(0, 0, -3.0 - 2.5 * lean)
	pose.head = Vector3(-4 + (f % 3) * 5, (f % 5 - 2) * 7, 0)
	return pose


## Person l cheering, their way (Crowd.CHEERS), frame fr of three; the shader goes from one to the next (and back).
## Clapping: the hands apart, closing, together. Jumping: crouched to spring, straightening (the arms swinging up),
## in the air (arms up, knees drawn up). A fist: at the shoulder, on its way up, punched up. Swaying: both arms up,
## leaning to one side, upright, to the other.
func _cheer(l: int, fr: int) -> Dictionary:
	var p := Moves.static_pose("stand")
	var k := float(fr)
	p.head = Vector3(-12, (l % 5 - 2) * 5, 0)
	match int(Crowd.CHEERS[l % Crowd.CHEERS.size()]):
		Crowd.CHEER_CLAP:
			var s := lerpf(30.0, -18.0, k / 2.0)
			p.spine = Vector3(4 + k * 2.0, 0, 0)
			p.upperarm_l = Vector3(-58 - k * 2.0, 0, s)
			p.upperarm_r = Vector3(-58 - k * 2.0, 0, -s)
			p.forearm_l = Vector3(-52 - k * 5.0, 0, 0)
			p.forearm_r = Vector3(-52 - k * 5.0, 0, 0)
		Crowd.CHEER_JUMP:
			match fr:
				0:   # crouched, the arms back
					p.spine = Vector3(24, 0, 0)
					p.head = Vector3(-18, 0, 0)
					p.thigh_l = Vector3(-52, 0, 6)
					p.thigh_r = Vector3(-52, 0, -6)
					p.shin_l = Vector3(80, 0, 0)
					p.shin_r = Vector3(80, 0, 0)
					p.foot_l = Vector3(-26, 0, 0)
					p.foot_r = Vector3(-26, 0, 0)
					p.upperarm_l = Vector3(32, 0, 14)
					p.upperarm_r = Vector3(32, 0, -14)
					p.forearm_l = Vector3(-20, 0, 0)
					p.forearm_r = Vector3(-20, 0, 0)
				1:   # straightening, the arms swinging up
					p.spine = Vector3(6, 0, 0)
					p.thigh_l = Vector3(-14, 0, 4)
					p.thigh_r = Vector3(-14, 0, -4)
					p.shin_l = Vector3(24, 0, 0)
					p.shin_r = Vector3(24, 0, 0)
					p.foot_l = Vector3(4, 0, 0)
					p.foot_r = Vector3(4, 0, 0)
					p.upperarm_l = Vector3(-105, 0, 18)
					p.upperarm_r = Vector3(-105, 0, -18)
					p.forearm_l = Vector3(-30, 0, 0)
					p.forearm_r = Vector3(-30, 0, 0)
				2:   # in the air, arms up
					p.spine = Vector3(-4, 0, 0)
					p.head = Vector3(-24, 0, 0)
					p.thigh_l = Vector3(-30, 0, 7)
					p.thigh_r = Vector3(-30, 0, -7)
					p.shin_l = Vector3(52, 0, 0)
					p.shin_r = Vector3(52, 0, 0)
					p.foot_l = Vector3(22, 0, 0)
					p.foot_r = Vector3(22, 0, 0)
					p.upperarm_l = Vector3(-166, 0, 20)
					p.upperarm_r = Vector3(-166, 0, -20)
					p.forearm_l = Vector3(-10, 0, 0)
					p.forearm_r = Vector3(-10, 0, 0)
					p.y = 0.3   # (off the floor: the feet not planted; the shader lifts the figure itself)
		Crowd.CHEER_FIST:
			p.upperarm_l = Vector3(-18, 0, 16)
			p.forearm_l = Vector3(-80, 0, 0)
			match fr:
				0:   # the fist at the shoulder, the knees giving
					p.spine = Vector3(12, 0, 0)
					p.thigh_l = Vector3(-14, 0, 4)
					p.thigh_r = Vector3(-14, 0, -4)
					p.shin_l = Vector3(24, 0, 0)
					p.shin_r = Vector3(24, 0, 0)
					p.foot_l = Vector3(-8, 0, 0)
					p.foot_r = Vector3(-8, 0, 0)
					p.upperarm_r = Vector3(-38, 0, -30)
					p.forearm_r = Vector3(-128, 0, 0)
				1:
					p.spine = Vector3(4, 0, 0)
					p.upperarm_r = Vector3(-112, 0, -22)
					p.forearm_r = Vector3(-70, 0, 0)
				2:   # punched up, the head back
					p.spine = Vector3(-6, 0, 0)
					p.head = Vector3(-26, 0, 0)
					p.upperarm_r = Vector3(-168, 0, -12)
					p.forearm_r = Vector3(-12, 0, 0)
		Crowd.CHEER_SWAY:
			var s := k - 1.0
			p.spine = Vector3(-2, 0, 6.0 * s)
			p.head = Vector3(-18, 0, -5.0 * s)
			p.hips = Vector3(0, 0, -3.0 * s)
			p.upperarm_l = Vector3(-160, 0, 16 + 14.0 * s)
			p.upperarm_r = Vector3(-160, 0, -16 + 14.0 * s)
			p.forearm_l = Vector3(-14, 0, 0)
			p.forearm_r = Vector3(-14, 0, 0)
	return p


## One figure's cell: rendered, the shirt marked in the alpha, shrunk to the cell's size.
func _figure(look: Dictionary, pose: Dictionary, view: float, ahead: float, fw: int, fh: int) -> Image:
	var w := fw * SCALE
	var h := fh * SCALE
	var colour := await _shot(look, pose, w, h, false, view, ahead)
	var mask := await _shot(look, pose, w, h, true, view, ahead)
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := colour.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var shirt := mask.get_pixel(x, y).r > 0.5
			out.set_pixel(x, y, Color(c.r, c.g, c.b, 0.7 if shirt else 1.0))
	out.resize(fw, fh, Image.INTERPOLATE_LANCZOS)
	return out


## Every pose of the first four people from the front, a row each (at rest seated, at rest standing, the cheer's
## three frames), to look at.
func _poses(out: String) -> void:
	var fw := Crowd.FIG_W_HI if _hi else Crowd.FIG_W
	var fh := Crowd.FIG_H_HI if _hi else Crowd.FIG_H
	var figs := Crowd.FIGS_HI if _hi else Crowd.FIGS
	var per := 2 + Crowd.CHEER_FRAMES
	var people := Crowd.CHEERS.size() if _hi else Crowd.CHEERS.size() / 2
	var img := Image.create_empty(fw * per * 2, fh * people / 2, false, Image.FORMAT_RGBA8)
	img.fill(Color("2b4a6e"))
	for l in people:
		var poses := [_seated(l), _standing(l + figs / 2)]
		for fr in Crowd.CHEER_FRAMES:
			poses.append(_cheer(l, fr))
		for i in poses.size():
			var fig := await _figure(_look(l), poses[i], 20.0, 0.0, fw, fh)
			img.blend_rect(fig, Rect2i(0, 0, fw, fh), Vector2i(((l % 2) * per + i) * fw, (l / 2) * fh))
	img.save_png(out)
	print("poses: ", out)


## One figure seen from view degrees round from the front (toward their left), the frame from the floor to above a
## hand held up; with mask, just the shirt in white.
func _shot(look: Dictionary, pose: Dictionary, w: int, h: int, mask: bool, view := 0.0, ahead := 0.0) -> Image:
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
	var mid := Vector3(0, Crowd.FIG_H_M * 0.5, ahead)
	var a := deg_to_rad(view)
	cam.position = mid + Vector3(4.0 * sin(a), 0.55, 4.0 * cos(a))   # a little from above, as from the court
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
