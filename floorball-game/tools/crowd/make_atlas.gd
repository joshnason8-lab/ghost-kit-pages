extends Node
## Bakes the crowd's sheet, assets/crowd/crowd_atlas.png (1024 x 512): the owner's two athletes (the Meshy man and
## woman) posed as spectators, seated and standing, each seen from five angles round them, as 64 x 128 cut-outs.
## game/crowd.gd draws the crowd as one MultiMesh of upright quads that face the camera, picking for each person the
## cut-out of their pose seen from where the camera is (mirrored for the other side).
##
## Each cut-out's alpha says what a pixel is: 0 nothing, 0.4 hair, trousers, shoes, 0.7 skin, 1.0 the shirt. The
## shirt is baked light grey and the game tints it per person; the skin takes a tone per person. The athletes' kit
## below the waist becomes jeans or dark trousers, as spectators wear.
##
## The source GLBs are big (4096 px textures) and never ship; only the PNG does. Needs a window:
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/crowd/make_atlas.tscn -- man.glb woman.glb [preview.png]

const CELL := Vector2i(64, 128)
const SS := 4                          # supersampling: rendered at 256 x 512, boxed down
const COLS := 16
const FRAME_H := 2.2                   # metres the cell's height shows (Crowd.FRAME_H)
const PITCH := 12.0                    # degrees the view looks down, as from a broadcast camera
const VIEWS := [0.0, 45.0, 90.0, 135.0, 180.0]   # the camera's angle round the person from straight in front, to their left
## Directions in the model's space (it faces +Z, its left is +X), mirrored for the right side ("r" bones: x negated).
## thigh, shin, foot; upper arm, forearm (left side; right mirrors unless given); spine lean.
const POSES := [
	{"name": "sit", "spine": Vector3(0, 1, -0.05), "thigh": Vector3(0.12, -0.12, 1), "shin": Vector3(0.04, -1, 0.1),
		"arm": Vector3(0.2, -1, 0.3), "fore": Vector3(0.0, -0.45, 1)},
	{"name": "lean", "spine": Vector3(0, 1, 0.42), "thigh": Vector3(0.16, -0.1, 1), "shin": Vector3(0.05, -1, 0.05),
		"arm": Vector3(0.12, -1, 0.5), "fore": Vector3(-0.35, 0.05, 1)},
	{"name": "clap", "spine": Vector3(0, 1, 0.0), "thigh": Vector3(0.12, -0.12, 1), "shin": Vector3(0.04, -1, 0.1),
		"arm": Vector3(0.3, -0.75, 0.6), "fore": Vector3(-0.8, 0.45, 0.55)},
	{"name": "cheer", "spine": Vector3(0, 1, -0.05), "thigh": Vector3(0.08, -1, 0.02), "shin": Vector3(0.0, -1, 0.0),
		"arm": Vector3(0.45, 1, 0.15), "fore": Vector3(0.12, 1, 0.1)},
	{"name": "fist", "spine": Vector3(0, 1, 0.0), "thigh": Vector3(0.08, -1, 0.02), "shin": Vector3(0.0, -1, 0.0),
		"arm": Vector3(0.3, 0.8, 0.45), "fore": Vector3(0.05, 1, 0.05),
		"arm_r": Vector3(-0.25, -1, 0.15), "fore_r": Vector3(-0.1, -0.6, 1)},
]
const HEIGHTS := [1.78, 1.68]          # the man, the woman
const PANTS := [Color(0.13, 0.17, 0.27), Color(0.07, 0.07, 0.08)]

const KIT := """
	vec3 t = texture(tex, UV).rgb;
	float mx = max(t.r, max(t.g, t.b));
	float mn = min(t.r, min(t.g, t.b));
	float sat = (mx - mn) / max(mx, 0.001);
	float blue = step(t.r * 1.15 + 0.02, t.b) * step(t.g, t.b);
	float main = blue * smoothstep(0.35, 0.5, sat) * (1.0 - smoothstep(0.62, 0.78, mx));
	float trim = blue * smoothstep(0.62, 0.78, mx) * smoothstep(0.12, 0.25, sat) * step(0.5, t.g);
	float kit = clamp(main + trim, 0.0, 1.0);
	float upper = step(waist, wy);
	float shirt = step(0.5, kit) * upper;
	float lower = step(0.5, kit) * (1.0 - upper);
	float skin = step(t.b * 1.05, t.r) * step(t.g, t.r) * smoothstep(0.12, 0.25, sat) * (1.0 - step(0.5, kit));
	float lum = dot(t, vec3(0.3, 0.55, 0.15));
"""

var _vp: SubViewport
var _cam: Camera3D
var _stage: Node3D
var _colour_shader := Shader.new()
var _class_shader := Shader.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_colour_shader.code = """
shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float waist = 0.6;
uniform vec3 pants : source_color = vec3(0.1, 0.12, 0.2);
varying float wy;
void vertex() { wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() {
%s
	vec3 c = t;
	c = mix(c, vec3(0.78) * clamp(lum / 0.2, 0.6, 1.25), shirt);
	c = mix(c, pants * clamp(lum / 0.2, 0.6, 1.3), lower);
	ALBEDO = c;
	ROUGHNESS = 0.75;
	SPECULAR = 0.25;
}
""" % KIT
	_class_shader.code = """
shader_type spatial;
render_mode cull_back, unshaded;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform float waist = 0.6;
varying float wy;
void vertex() { wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y; }
void fragment() {
%s
	ALBEDO = shirt > 0.5 ? vec3(1.0, 0.0, 0.0) : (skin > 0.5 ? vec3(0.0, 1.0, 0.0) : vec3(0.0, 0.0, 1.0));
}
""" % KIT
	_vp = SubViewport.new()
	_vp.size = CELL * SS
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_stage = Node3D.new()
	_vp.add_child(_stage)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.87, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 20, 0)
	sun.light_energy = 1.1
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.size = FRAME_H
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.near = 0.1
	_cam.far = 40.0
	_vp.add_child(_cam)
	var p := deg_to_rad(PITCH)
	var basis := Basis(Vector3.RIGHT, -p)
	_cam.transform = Transform3D(basis, basis.y * FRAME_H * 0.5 + basis.z * 15.0)
	_cam.current = true

	var atlas := Image.create_empty(COLS * CELL.x, 4 * CELL.y, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var preview := Image.create_empty(VIEWS.size() * CELL.x * SS, POSES.size() * 2 * CELL.y * SS, false, Image.FORMAT_RGBA8)
	preview.fill(Color(0.3, 0.3, 0.35, 1))
	var bg := Image.create_empty(CELL.x * SS, CELL.y * SS, false, Image.FORMAT_RGBA8)
	bg.fill(Color(0.3, 0.3, 0.35, 1))
	for m in 2:
		var model := _load(args[m], HEIGHTS[m])
		for pi in POSES.size():
			var hip_y := _pose(model, POSES[pi])
			for vi in VIEWS.size():
				model.root.rotation.y = -deg_to_rad(VIEWS[vi])
				_set_material(model, false, hip_y, PANTS[m])
				var col := await _grab()
				_set_material(model, true, hip_y, PANTS[m])
				var cls := await _grab()
				var idx := (m * POSES.size() + pi) * VIEWS.size() + vi
				_down(col, cls, atlas, Vector2i((idx % COLS) * CELL.x, (idx / COLS) * CELL.y))
				preview.blit_rect(bg, Rect2i(Vector2i.ZERO, bg.get_size()), Vector2i(vi * CELL.x * SS, (m * POSES.size() + pi) * CELL.y * SS))
				preview.blend_rect(col, Rect2i(Vector2i.ZERO, col.get_size()), Vector2i(vi * CELL.x * SS, (m * POSES.size() + pi) * CELL.y * SS))
				print("cell %d: model %d %s view %d" % [idx, m, POSES[pi].name, VIEWS[vi]])
		model.root.queue_free()
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/crowd"))
	atlas.save_png(ProjectSettings.globalize_path("res://assets/crowd/crowd_atlas.png"))
	if args.size() > 2:
		preview.resize(preview.get_width() / 2, preview.get_height() / 2)
		preview.save_png(args[2])
	print("saved res://assets/crowd/crowd_atlas.png")
	get_tree().quit()


class Model:
	var root: Node3D
	var skel: Skeleton3D
	var meshes: Array = []
	var tex: Texture2D
	var bones := {}      # short name (Hips, LeftArm...) -> index


func _load(path: String, height: float) -> Model:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(path, st)
	assert(err == OK, "cannot read %s" % path)
	var scene := doc.generate_scene(st)
	var md := Model.new()
	md.root = Node3D.new()
	md.root.add_child(scene)
	_stage.add_child(md.root)
	for n in scene.find_children("*", "Skeleton3D", true, false):
		md.skel = n
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		md.meshes.append(n)
		var mat: Material = (n as MeshInstance3D).get_active_material(0)
		if mat is BaseMaterial3D and (mat as BaseMaterial3D).albedo_texture:
			md.tex = (mat as BaseMaterial3D).albedo_texture
	for n in scene.find_children("*", "AnimationPlayer", true, false):
		(n as AnimationPlayer).stop()
	for b in md.skel.get_bone_count():
		var nm := md.skel.get_bone_name(b)
		var short := nm.substr(nm.find(":") + 1) if nm.contains(":") else nm.trim_prefix("mixamorig_")
		md.bones[short] = b
	md.skel.reset_bone_poses()
	# Scale to the person's height: the head's top is about 12 cm above the head bone.
	var head_y := _world(md, md.bones.Head).y - _world(md, md.bones.LeftFoot).y
	var k := (height - 0.2) / head_y
	print("model %s: head %.3f above the foot, scaled by %.3f" % [path.get_file(), head_y, k])
	scene.scale = Vector3.ONE * k * scene.scale
	return md


## The bone's pose in the skeleton's space, from the local poses as they are set (not waiting for the skeleton).
func _global(md: Model, b: int) -> Transform3D:
	var t := md.skel.get_bone_pose(b)
	var p := md.skel.get_bone_parent(b)
	while p >= 0:
		t = md.skel.get_bone_pose(p) * t
		p = md.skel.get_bone_parent(p)
	return t


## Turns bone b so that it points (towards its child c) along dir, in the skeleton's space.
func _aim(md: Model, b: String, c: String, dir: Vector3) -> void:
	var bi: int = md.bones[b]
	var ci: int = md.bones[c]
	var gb := _global(md, bi)
	var gc := gb * md.skel.get_bone_pose(ci)
	var cur := (gc.origin - gb.origin).normalized()
	var want := (md.skel.global_transform.basis.inverse() * dir).normalized()
	var q := Quaternion(cur, want)
	var new_basis := Basis(q) * gb.basis
	var pi := md.skel.get_bone_parent(bi)
	var gp := _global(md, pi) if pi >= 0 else Transform3D.IDENTITY
	var local := gp.basis.inverse() * new_basis
	md.skel.set_bone_pose_rotation(bi, local.get_rotation_quaternion())


func _mirror(v: Vector3) -> Vector3:
	return Vector3(-v.x, v.y, v.z)


## Poses the model; returns the waist's height (where the shirt ends) in the stage's space.
func _pose(md: Model, p: Dictionary) -> float:
	md.skel.reset_bone_poses()
	md.root.position = Vector3.ZERO
	md.root.rotation = Vector3.ZERO
	(md.root.get_child(0) as Node3D).position = Vector3.ZERO
	_aim(md, "Spine", "Spine1", p.spine)
	_aim(md, "Spine1", "Spine2", p.spine)
	_aim(md, "Spine2", "Neck", p.spine)
	_aim(md, "Neck", "Head", Vector3(0, 1, 0.08))
	for side in ["Left", "Right"]:
		var l: bool = side == "Left"
		var th: Vector3 = p.thigh if l else _mirror(p.thigh)
		var sh: Vector3 = p.shin if l else _mirror(p.shin)
		_aim(md, side + "UpLeg", side + "Leg", th)
		_aim(md, side + "Leg", side + "Foot", sh)
		_aim(md, side + "Foot", side + "ToeBase", Vector3(0, -0.45, 1))
		var arm: Vector3 = p.arm if l else (p.get("arm_r", _mirror(p.arm)))
		var fore: Vector3 = p.fore if l else (p.get("fore_r", _mirror(p.fore)))
		_aim(md, side + "Arm", side + "ForeArm", arm)
		_aim(md, side + "ForeArm", side + "Hand", fore)
	# Stand the feet on the floor and the hips over the origin.
	var s: Node3D = md.skel
	var foot := minf(_world(md, md.bones.LeftFoot).y, _world(md, md.bones.RightFoot).y)
	var hips := _world(md, md.bones.Hips)
	# Seated, the body reaches from the back to the knees: centre that on the origin, round which the views turn,
	# so no view cuts the knees off (and the game's quad can stay narrow).
	var seated: bool = p.thigh.y > -0.5
	var model: Node3D = md.root.get_child(0)
	model.position += Vector3(-hips.x, -foot + 0.09, -hips.z - (0.2 if seated else 0.0))
	var spine := _world(md, md.bones.Spine1)
	return _world(md, md.bones.Hips).lerp(spine, 0.5).y if s else 0.6


func _world(md: Model, b: int) -> Vector3:
	return md.skel.global_transform * _global(md, b).origin


func _set_material(md: Model, cls: bool, hip_y: float, pants: Color) -> void:
	var m := ShaderMaterial.new()
	m.shader = _class_shader if cls else _colour_shader
	m.set_shader_parameter("tex", md.tex)
	m.set_shader_parameter("waist", hip_y)
	m.set_shader_parameter("pants", pants)
	for mi in md.meshes:
		(mi as MeshInstance3D).material_override = m


func _grab() -> Image:
	for i in 3:
		await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


## Boxes a supersampled cell down: the colour of the covered pixels, covered where half are, the class most of them have.
func _down(col: Image, cls: Image, atlas: Image, at: Vector2i) -> void:
	for y in CELL.y:
		for x in CELL.x:
			var sum := Color(0, 0, 0, 0)
			var n := 0
			var votes := [0, 0, 0]
			for j in SS:
				for i in SS:
					var c := col.get_pixel(x * SS + i, y * SS + j)
					if c.a > 0.5:
						sum += c
						n += 1
						var k := cls.get_pixel(x * SS + i, y * SS + j)
						votes[0 if k.r > 0.5 else (1 if k.g > 0.5 else 2)] += 1
			if n * 2 < SS * SS:
				continue
			var a := 0.4
			if votes[0] >= votes[1] and votes[0] >= votes[2]:
				a = 1.0
			elif votes[1] >= votes[2]:
				a = 0.7
			atlas.set_pixel(at.x + x, at.y + y, Color(sum.r / n, sum.g / n, sum.b / n, a))
