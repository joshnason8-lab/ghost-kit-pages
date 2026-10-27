extends Node3D
## The crowd's figures, photographed from the Meshy fans (tools/crowd/models, baked as the officials are): two fans in
## four poses each (standing, clapping, cheering with an arm up, looking along the stand), each from the front and
## from behind, head to waist, into one sheet (assets/crowd/sheet.png: the eight from the front, then the same eight
## from behind) and a mask of where their white shirts are (assets/crowd/mask.png), so Crowd can put every
## spectator in a colour of their own.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/crowd/render_fans.tscn [-- hd]
## With hd, the sheet Medium and High draw (assets/crowd/sheet_hd.png and mask_hd.png): all six fans, 24 figures at
## twice the size, the front in the top row and the back in the bottom one.

var W := 64
var H := 128
const DIR := "res://tools/crowd/models/"
const POSES := [
	{},
	{"upperarm_l": Vector3(-42, 0, -14), "forearm_l": Vector3(92, 0, 0), "upperarm_r": Vector3(-42, 0, 14), "forearm_r": Vector3(92, 0, 0), "hand_l": Vector3(0, 0, -30), "hand_r": Vector3(0, 0, 30)},
	{"upperarm_r": Vector3(-165, 0, -12), "forearm_r": Vector3(15, 0, 0), "head": Vector3(-10, 0, 0)},
	{"head": Vector3(0, 28, 0), "chest": Vector3(0, 10, 0), "upperarm_l": Vector3(-8, 0, 6), "forearm_l": Vector3(20, 0, 0)},
]


func _ready() -> void:
	var ultra := "ultra" in OS.get_cmdline_user_args()   # the HD pack's: the HD sheet at twice its size again (ultra/crowd)
	var hd := "hd" in OS.get_cmdline_user_args() or ultra
	# Low's sheet from the fans' 512 textures; the HD one from their 1024 ones (fan_hd.jpg: Game.hd).
	Game.settings.graphics = Game.GFX_HIGH if hd else Game.GFX_LOW
	var models := ["fan", "fan2", "fan3", "fan4", "fan5", "fan6"] if hd else ["fan", "fan2"]
	var figs := models.size() * POSES.size()
	if hd:
		W = 256 if ultra else 128
		H = 512 if ultra else 256
	var size := Vector2i(W * figs, H * 2) if hd else Vector2i(W * figs * 2, H)
	var sheet := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var mask := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	mask.fill(Color(0, 0, 0, 0))
	var vp := SubViewport.new()
	vp.size = Vector2i(W * 4, H * 4) if not hd else (Vector2i(W * 2, H * 2) if not ultra else Vector2i(W, H) * 2)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 1.08
	vp.add_child(cam)
	var mask_mat := ShaderMaterial.new()
	var msh := Shader.new()
	msh.code = """
shader_type spatial;
render_mode unshaded;
uniform sampler2D albedo : source_color;
void fragment() {
	vec3 c = texture(albedo, UV).rgb;
	float hi = min(c.r, min(c.g, c.b));
	float sat = max(c.r, max(c.g, c.b)) - hi;
	ALBEDO = vec3(smoothstep(0.55, 0.75, hi) * (1.0 - smoothstep(0.08, 0.2, sat)));
}
"""
	mask_mat.shader = msh
	var i := 0
	for model in models:
		for pose in POSES:
			var body := PersonBody.new({"model": model, "dir": DIR, "kind": "fan"})
			vp.add_child(body)
			await get_tree().process_frame
			body.apply(pose)
			var top := body.bone_world("head").y + 0.3
			for side in [0, 1]:
				cam.look_at_from_position(Vector3(0, top - 0.54, 4.0 if side == 0 else -4.0), Vector3(0, top - 0.54, 0))
				for pass_ in [0, 1]:
					var mm: Material = body.mesh_instance.material_override
					if pass_ == 1:
						mask_mat.set_shader_parameter("albedo", (mm as ShaderMaterial).get_shader_parameter("albedo"))
						body.mesh_instance.material_override = mask_mat
					await RenderingServer.frame_post_draw
					await RenderingServer.frame_post_draw
					var img := vp.get_texture().get_image()
					img.resize(W, H, Image.INTERPOLATE_LANCZOS)
					var dst := sheet if pass_ == 0 else mask
					var at := Vector2i(i * W, side * H) if hd else Vector2i((i + side * figs) * W, 0)
					dst.blit_rect(img, Rect2i(0, 0, W, H), at)
					body.mesh_instance.material_override = mm
			body.queue_free()
			i += 1
	# The mask keeps the figure's outline in its alpha, so the shader can tell shirt from background.
	for y in size.y:
		# (In the HD sheet nothing above the collar is shirt: grey hair is as pale as a white shirt.)
		var head := hd and (y % H) < int(H * 0.3)
		for x in size.x:
			var c := mask.get_pixel(x, y)
			var r := 0.0 if head else c.r
			mask.set_pixel(x, y, Color(r, r, r, sheet.get_pixel(x, y).a))
	DirAccess.make_dir_recursive_absolute("res://assets/crowd")
	var sfx := "_hd" if hd else ""
	var where := "res://ultra/crowd/" if ultra else "res://assets/crowd/"
	DirAccess.make_dir_recursive_absolute(where)
	sheet.save_png(where + "sheet%s.png" % ("" if ultra else sfx))
	mask.save_png(where + "mask%s.png" % ("" if ultra else sfx))
	print("wrote %ssheet and mask (%d figures)" % [where, figs])
	get_tree().quit()
