extends Node3D
## The crowd's figures, photographed from the Meshy fans (tools/crowd/models, baked as the officials are): two fans in
## four poses each (standing, clapping, cheering with an arm up, looking along the stand), each from the front and
## from behind, head to waist, into one sheet (assets/crowd/sheet.png: the eight from the front, then the same eight
## from behind) and a mask of where their white shirts are (assets/crowd/mask.png), so Crowd can put every
## spectator in a colour of their own.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/crowd/render_fans.tscn

const W := 64
const H := 128
const DIR := "res://tools/crowd/models/"
const POSES := [
	{},
	{"upperarm_l": Vector3(-42, 0, -14), "forearm_l": Vector3(92, 0, 0), "upperarm_r": Vector3(-42, 0, 14), "forearm_r": Vector3(92, 0, 0), "hand_l": Vector3(0, 0, -30), "hand_r": Vector3(0, 0, 30)},
	{"upperarm_r": Vector3(-165, 0, -12), "forearm_r": Vector3(15, 0, 0), "head": Vector3(-10, 0, 0)},
	{"head": Vector3(0, 28, 0), "chest": Vector3(0, 10, 0), "upperarm_l": Vector3(-8, 0, 6), "forearm_l": Vector3(20, 0, 0)},
]


func _ready() -> void:
	Game.settings.graphics = Game.GFX_HIGH
	var sheet := Image.create_empty(W * 16, H, false, Image.FORMAT_RGBA8)
	var mask := Image.create_empty(W * 16, H, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	mask.fill(Color(0, 0, 0, 0))
	var vp := SubViewport.new()
	vp.size = Vector2i(W * 4, H * 4)
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
	for model in ["fan", "fan2"]:
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
					dst.blit_rect(img, Rect2i(0, 0, W, H), Vector2i((i + side * 8) * W, 0))
					body.mesh_instance.material_override = mm
			body.queue_free()
			i += 1
	# The mask keeps the figure's outline in its alpha, so the shader can tell shirt from background.
	for y in H:
		for x in W * 16:
			var c := mask.get_pixel(x, y)
			mask.set_pixel(x, y, Color(c.r, c.r, c.r, sheet.get_pixel(x, y).a))
	DirAccess.make_dir_recursive_absolute("res://assets/crowd")
	sheet.save_png("res://assets/crowd/sheet.png")
	mask.save_png("res://assets/crowd/mask.png")
	print("wrote assets/crowd/sheet.png and mask.png")
	get_tree().quit()
