extends Node3D
## Renders the crowd's sprite sheet from Meshy's rigged people (assets/meshy/crowd_*_rigged.glb): each
## person in each crowd frame (sitting, clapping, arms up, standing to cheer), seen from the front, one
## column per person and one row per frame. The game draws every spectator as one camera-facing card
## cut from this sheet (game/arena.gd), so a stand of hundreds costs a few thousand triangles.
##
## Writes OUT/crowd_atlas.webp (colour, alpha the outline), OUT/crowd_mask.png (white on the top a fan
## wears, which the game recolours so a stand wears its teams' colours), OUT/crowd_atlas.json (the layout,
## and each top's typical brightness) and their import settings.
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 288x490 \
##       res://tools/crowd/render_crowd.tscn -- /abs/assets/meshy /abs/assets/crowd

const CELL := Vector2i(144, 245)         # pixels a person
const SS := 2                            # rendered at twice the size, then shrunk
const CELL_H := 2.312                    # metres a cell covers top to bottom (9.4 mm a pixel)
const FRAMES := ["sit", "clap_open", "clap", "stand", "stand_clap_open", "stand_clap", "stand_arms_up", "stand_pump"]
## Bones the top covers: the spine and the upper arms (sleeves); around the hips, where the hem falls,
## whatever is the top's colour.
const TOP_BONES := ["Spine02", "Spine01", "Spine", "LeftShoulder", "RightShoulder", "LeftArm", "RightArm"]
const LOWER_BONES := ["Hips"]
## Fans in shirts wear team colours; people in kurtas, salwars, sarees and frocks keep their own clothes.
const RECOLOUR := ["tshirt", "jersey", "boy"]
## Where each limb points in each frame, for the person's left side (x out from the body, y up, z forward);
## the right side mirrors it. Bones not listed keep their rest pose.
const SIT_LEGS := {"UpLeg": Vector3(0.1, -0.05, 1.0), "Leg": Vector3(0.03, -1.0, 0.12), "Foot": Vector3(0.0, -0.25, 1.0)}
const ARMS := {
	"sit": {"Arm": Vector3(0.12, -1.0, 0.3), "ForeArm": Vector3(-0.05, -0.45, 1.0)},
	"clap_open": {"Arm": Vector3(0.18, -0.85, 0.5), "ForeArm": Vector3(-0.35, 0.35, 0.85)},
	"clap": {"Arm": Vector3(0.12, -0.85, 0.5), "ForeArm": Vector3(-0.8, 0.3, 0.5)},
	"stand": {"Arm": Vector3(0.1, -1.0, 0.05), "ForeArm": Vector3(0.05, -1.0, 0.15)},
	"stand_clap_open": {"Arm": Vector3(0.18, -0.85, 0.5), "ForeArm": Vector3(-0.35, 0.35, 0.85)},
	"stand_clap": {"Arm": Vector3(0.12, -0.85, 0.5), "ForeArm": Vector3(-0.8, 0.3, 0.5)},
	"stand_arms_up": {"Arm": Vector3(0.45, 0.9, 0.1), "ForeArm": Vector3(0.2, 1.0, 0.05)},
}
const PUMP_UP := {"Arm": Vector3(0.25, 0.95, 0.1), "ForeArm": Vector3(0.05, 1.0, 0.1)}
const PUMP_DOWN := {"Arm": Vector3(0.12, -1.0, 0.1), "ForeArm": Vector3(0.05, -1.0, 0.25)}
const CHILD := {"UpLeg": "Leg", "Leg": "Foot", "Foot": "ToeBase", "Arm": "ForeArm", "ForeArm": "Hand"}

const MASK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
varying vec2 part;   // r: on the top's bones, g: below them
void vertex() {
	part = COLOR.rg;
}
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	float s = mx > 0.0 ? (mx - mn) / mx : 0.0;
	// Skin: orange-ish, moderately saturated. Hands and face are not on the top's bones anyway.
	bool skin = c.r > c.g && c.g > c.b && s > 0.15 && s < 0.7 && mx > 0.2 && (c.g - c.b) / max(c.r - c.b, 0.001) < 0.85;
	ALBEDO = skin ? vec3(0.0) : vec3(step(0.5, part.r), step(0.5, part.g), 0.0);
}
"""

var _vp: SubViewport
var _cam: Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0]
	var out: String = args[1]
	var files: Array[String] = []
	for f in DirAccess.get_files_at(src):
		if f.begins_with("crowd_") and f.ends_with("_rigged.glb"):
			files.append(f)
	files.sort()
	_vp = SubViewport.new()
	_vp.size = CELL * SS
	_vp.transparent_bg = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.75
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-20), 0)   # from the front, above, a little to one side
	key.light_energy = 0.55
	_vp.add_child(key)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = CELL_H
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.position = Vector3(0, CELL_H * 0.5 - 0.02, 6.0)
	_vp.add_child(_cam)

	var sheet := Image.create(CELL.x * files.size(), CELL.y * FRAMES.size(), false, Image.FORMAT_RGBA8)
	var mask := Image.create(CELL.x * files.size(), CELL.y * FRAMES.size(), false, Image.FORMAT_L8)
	var people := []
	for p in files.size():
		var person := await _render_person(src.path_join(files[p]), p, sheet, mask)
		person["file"] = files[p]
		people.append(person)
		print("rendered ", files[p], " ", person)
	DirAccess.make_dir_recursive_absolute(out)
	sheet.save_webp(out.path_join("crowd_atlas.webp"), true, 0.9)
	mask.save_png(out.path_join("crowd_mask.png"))
	_import_file(out.path_join("crowd_atlas.webp.import"), "crowd_atlas.webp", 1, true)
	_import_file(out.path_join("crowd_mask.png.import"), "crowd_mask.png", 0, false)
	var info := {"cell": [CELL.x, CELL.y], "cell_height_m": CELL_H, "frames": FRAMES, "people": people}
	var f := FileAccess.open(out.path_join("crowd_atlas.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(info, " "))
	f.close()
	get_tree().quit()


func _render_person(path: String, col: int, sheet: Image, mask: Image) -> Dictionary:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		push_error("can't read " + path)
		return {}
	var root: Node3D = doc.generate_scene(state)
	_vp.add_child(root)
	var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
	var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
	_mark_top(mi, sk)
	var colour_mat := mi.get_active_material(0)
	if colour_mat is StandardMaterial3D:
		(colour_mat as StandardMaterial3D).metallic = 0.0
		(colour_mat as StandardMaterial3D).roughness = 1.0
	var mask_mat := ShaderMaterial.new()
	mask_mat.shader = Shader.new()
	mask_mat.shader.code = MASK_SHADER
	if colour_mat is BaseMaterial3D:
		mask_mat.set_shader_parameter("albedo_tex", (colour_mat as BaseMaterial3D).albedo_texture)
	var ankle_rest := _ankle_y(sk, root)
	var lum_sum := 0.0
	var lum_n := 0
	for r in FRAMES.size():
		_pose(sk, FRAMES[r])
		await get_tree().process_frame
		root.position.y += ankle_rest - _ankle_y(sk, root)
		var shots := []
		for pass_mat in [null, mask_mat]:
			mi.material_override = pass_mat
			for k in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var img := _vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			if pass_mat == null:
				img.fix_alpha_edges()   # no dark fringe from the empty background when shrinking
			img.resize(CELL.x, CELL.y, Image.INTERPOLATE_LANCZOS)
			shots.append(img)
		var at := Vector2i(col * CELL.x, r * CELL.y)
		sheet.blit_rect(shots[0], Rect2i(Vector2i.ZERO, CELL), at)
		# The top's typical colour, then what below it matches it (chromaticity and brightness).
		var mean := Vector3.ZERO
		var n := 0
		for y in CELL.y:
			for x in CELL.x:
				var c: Color = shots[0].get_pixel(x, y)
				if c.a > 0.95 and shots[1].get_pixel(x, y).r > 0.5:
					mean += Vector3(c.r, c.g, c.b)
					n += 1
		mean /= maxf(1.0, float(n))
		var mean_sum := maxf(mean.x + mean.y + mean.z, 0.001)
		for y in CELL.y:
			for x in CELL.x:
				var c: Color = shots[0].get_pixel(x, y)
				var k: Color = shots[1].get_pixel(x, y)
				var m := k.r
				if k.g > 0.5 and c.a > 0.5:
					var sum := maxf(c.r + c.g + c.b, 0.001)
					var chroma := (Vector3(c.r, c.g, c.b) / sum - mean / mean_sum).length()
					if chroma < 0.045 and sum / mean_sum > 0.75 and sum / mean_sum < 1.35:
						m = 1.0
				if c.a <= 0.5:
					m = 0.0
				mask.set_pixel(at.x + x, at.y + y, Color(m, m, m))
				if r == 0 and m > 0.9 and c.a > 0.95:
					lum_sum += c.srgb_to_linear().get_luminance()
					lum_n += 1
	mi.material_override = null
	var top_lum := lum_sum / maxf(1.0, float(lum_n))
	var recolour := false
	for word in RECOLOUR:
		recolour = recolour or path.get_file().contains(word)
	if not recolour:
		top_lum = 0.0   # the game leaves this one's clothes alone
	root.queue_free()
	await get_tree().process_frame
	return {"top_luminance": snappedf(top_lum, 0.001), "top_pixels": lum_n}   # in linear light


## Vertex colour red: how much of each vertex the top's bones carry.
func _mark_top(mi: MeshInstance3D, sk: Skeleton3D) -> void:
	var skin := mi.skin
	var top := {}
	for i in skin.get_bind_count():
		var bone := String(skin.get_bind_name(i))
		if bone == "":
			bone = sk.get_bone_name(skin.get_bind_bone(i))
		top[i] = Vector2(1, 0) if bone in TOP_BONES else (Vector2(0, 1) if bone in LOWER_BONES else Vector2.ZERO)
	var src: ArrayMesh = mi.mesh
	var dst := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var n: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var per := bones.size() / n
		var cols := PackedColorArray()
		cols.resize(n)
		for v in n:
			var w := Vector2.ZERO
			for k in per:
				w += top.get(bones[v * per + k], Vector2.ZERO) * weights[v * per + k]
			cols[v] = Color(w.x, w.y, 0)
		arrays[Mesh.ARRAY_COLOR] = cols
		dst.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {},
			src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		dst.surface_set_material(s, src.surface_get_material(s))
	mi.mesh = dst


func _ankle_y(sk: Skeleton3D, root: Node3D) -> float:
	var lo := INF
	for n in ["LeftFoot", "RightFoot"]:
		var b := sk.find_bone(n)
		if b >= 0:
			lo = minf(lo, (sk.global_transform * sk.get_bone_global_pose(b)).origin.y)
	return lo


## Point the limbs where the frame wants them: each bone turns the shortest way from where it points now.
func _pose(sk: Skeleton3D, frame: String) -> void:
	sk.reset_bone_poses()
	var want := {}
	for side in ["Left", "Right"]:
		var arms: Dictionary = ARMS.get(frame, {})
		if frame == "stand_pump":
			arms = PUMP_UP if side == "Right" else PUMP_DOWN
		var limbs := arms.duplicate()
		if frame.begins_with("sit") or frame.begins_with("clap"):
			limbs.merge(SIT_LEGS)
		for part in limbs:
			want[side + part] = [limbs[part], side + CHILD[part]]
	var to_skel := sk.global_transform.basis.inverse()
	var glob := []
	glob.resize(sk.get_bone_count())
	for b in sk.get_bone_count():
		var parent := sk.get_bone_parent(b)
		var local := sk.get_bone_rest(b)
		var g: Transform3D = (glob[parent] as Transform3D) * local if parent >= 0 else local
		var name := sk.get_bone_name(b)
		if want.has(name):
			var child := sk.find_bone(want[name][1])
			if child >= 0:
				# Which way is out for this side: the side the shoulder or hip is on.
				var x := (sk.global_transform.basis * g.origin).x
				var out := signf(x) if absf(x) > 1e-4 else (1.0 if name.begins_with("Left") else -1.0)
				var d: Vector3 = want[name][0]
				var target := (to_skel * Vector3(d.x * out, d.y, d.z)).normalized()
				var now := (g.basis * sk.get_bone_rest(child).origin).normalized()
				var turn := Quaternion(now, target)
				var new_basis := Basis(turn) * g.basis
				var parent_basis: Basis = (glob[parent] as Transform3D).basis if parent >= 0 else Basis()
				sk.set_bone_pose_rotation(b, (parent_basis.inverse() * new_basis).get_rotation_quaternion())
				g = Transform3D(new_basis, g.origin)
		glob[b] = g


## Import settings: the colour sheet stored lossy (small in the APK) with its edges padded so mipmaps don't
## darken them; the mask lossless, kept one channel.
func _import_file(path: String, source: String, mode: int, fix_border: bool) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(PackedStringArray([
		"[remap]", "", "importer=\"texture\"", "type=\"CompressedTexture2D\"", "", "[deps]", "",
		"source_file=\"res://assets/crowd/%s\"" % source, "", "[params]", "",
		"compress/mode=%d" % mode, "compress/high_quality=false", "compress/lossy_quality=0.85",
		"compress/uastc_level=0", "compress/rdo_quality_loss=0.0", "compress/hdr_compression=1",
		"compress/normal_map=0", "compress/channel_pack=0", "mipmaps/generate=true", "mipmaps/limit=-1",
		"roughness/mode=0", "roughness/src_normal=\"\"", "process/channel_remap/red=0",
		"process/channel_remap/green=1", "process/channel_remap/blue=2", "process/channel_remap/alpha=3",
		"process/fix_alpha_border=%s" % ("true" if fix_border else "false"), "process/premult_alpha=false",
		"process/normal_map_invert_y=false", "process/hdr_as_srgb=false", "process/hdr_clamp_exposure=false",
		"process/size_limit=0", "detect_3d/compress_to=0", ""])))
	f.close()
