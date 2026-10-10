class_name RiggedBody
extends Node3D
## A realistic body (a rigged mesh made by tools/rig/autorig.py) that follows the code-built
## placeholder skeleton in HumanModel. The placeholder keeps animating as before, just
## hidden; every frame each bone of this mesh is turned to match the matching limb, torso or
## head of the placeholder. Kit colours come from regions painted by the rig tool or, for a
## textured model, from its kit map (tools/rig/kit_texture.py): the texture gives the face,
## skin and the kit's folds, and the team's colours replace the kit's own.

const PATH := "res://assets/characters/rigged_athlete.json"
const SHADER := """
shader_type spatial;
uniform vec3 skin_col : source_color = vec3(0.78, 0.55, 0.4);
uniform vec3 jersey_col : source_color = vec3(0.1, 0.4, 0.8);
uniform vec3 shorts_col : source_color = vec3(0.05, 0.1, 0.16);
uniform vec3 hair_col : source_color = vec3(0.08, 0.06, 0.05);
varying vec3 region;
void vertex() {
	region = COLOR.rgb;   // one channel per region: jersey, shorts, hair; none = skin
}
void fragment() {
	vec3 c = skin_col;
	float rough = 0.6;
	float m = max(region.r, max(region.g, region.b));
	if (m > 0.5) {
		if (region.r >= m) { c = jersey_col; rough = 0.85; }
		else if (region.g >= m) { c = shorts_col; rough = 0.85; }
		else { c = hair_col; rough = 0.95; }
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
"""
const SHADER_TEXTURED := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D kit_tex : filter_linear_mipmap, repeat_disable;   // r main, g trim, b shading / 2
uniform vec3 skin_ratio = vec3(1.0);   // this player's skin over the texture's, in linear light
uniform vec3 jersey_col : source_color = vec3(0.1, 0.4, 0.8);
uniform vec3 shorts_col : source_color = vec3(0.05, 0.1, 0.16);
uniform vec3 trim_col : source_color = vec3(1.0);
varying vec3 region;
void vertex() {
	region = COLOR.rgb;   // r jersey, g shorts, b hair
}
void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	vec3 k = texture(kit_tex, UV).rgb;
	vec3 body = t * mix(skin_ratio, vec3(1.0), region.b);   // hair keeps its colour
	// Sharp edges: a little kit bleeding in from a neighbouring piece of the texture (or a
	// little skin into the kit) is dropped.
	float amount = smoothstep(0.3, 0.7, k.r + k.g);
	vec3 kit_col = (mix(jersey_col, shorts_col, region.g) * k.r + trim_col * k.g) / max(k.r + k.g, 0.001);
	ALBEDO = mix(body, kit_col * k.b * 2.0, amount);
	ROUGHNESS = mix(0.6, 0.85, amount);
	SPECULAR = 0.35;
}
"""

static var _data = null
static var _mesh: ArrayMesh = null
static var _shader: Shader = null
static var _albedo: Texture2D = null
static var _kit: Texture2D = null
static var _skin_ref := Color(1, 1, 1)
static var _rest_dirs := {}
static var _rest_frames := {}
static var _leg_len := 0.9
static var _stand_h := 1.8
static var _back_offset := Vector3(0, 0, 0.14)
static var _curl_axis := {}   # "l"/"r": the axis the fingers curl about, in the rest pose (models with finger bones)

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var material: ShaderMaterial
var _bone := {}       # name -> index
var _parent := []     # index -> parent index
var _rest_head := []  # index -> rest position of the bone head (model space)
var _hidden_head := false
var _curl := {"l": 0.7, "r": 0.7}


static func available() -> bool:
	return FileAccess.file_exists(PATH)


static func _load() -> void:
	if _data != null:
		return
	_data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (_data is Dictionary):
		push_warning("rigged body: could not read " + PATH)
		_data = {}
		return
	var vs: Array = _data.vertices
	var ns: Array = _data.normals
	var n := vs.size() / 3
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n)
	norms.resize(n)
	cols.resize(n)
	var region: Array = _data.region
	# A textured model: its UVs, its cleaned texture and kit map.
	var uvs := PackedVector2Array()
	var tex: Dictionary = _data.get("texture", {})
	if _data.has("uvs") and ResourceLoader.exists(String(tex.get("albedo", ""))) and ResourceLoader.exists(String(tex.get("kit", ""))):
		_albedo = load(String(tex.albedo))
		_kit = load(String(tex.kit))
		var r: Array = tex.get("skin_ref", [1, 1, 1])
		_skin_ref = Color(float(r[0]), float(r[1]), float(r[2]))
		var us: Array = _data.uvs
		uvs.resize(n)
		for i in n:
			uvs[i] = Vector2(us[i * 2], us[i * 2 + 1])
	for i in n:
		verts[i] = Vector3(vs[i * 3], vs[i * 3 + 1], vs[i * 3 + 2])
		norms[i] = Vector3(ns[i * 3], ns[i * 3 + 1], ns[i * 3 + 2])
		var r := int(region[i])
		cols[i] = Color(1.0 if r == 1 else 0.0, 1.0 if r == 2 else 0.0, 1.0 if r == 3 else 0.0)
	var idx := PackedInt32Array()
	var src: Array = _data.indices
	idx.resize(src.size())
	# glTF and trimesh wind front faces counter-clockwise; Godot wants clockwise.
	for t in src.size() / 3:
		idx[t * 3] = int(src[t * 3])
		idx[t * 3 + 1] = int(src[t * 3 + 2])
		idx[t * 3 + 2] = int(src[t * 3 + 1])
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for b in _data.bones4:
		bones.append(int(b))
	for w in _data.weights4:
		weights.append(float(w))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = idx
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_shader = Shader.new()
	_shader.code = SHADER_TEXTURED if _albedo else SHADER

	# Rest directions and frames, for turning bones to match the placeholder.
	var j := {}
	for b in _data.bones:
		j[b.name] = [_v(b.head), _v(b.tail)]
	for name in j:
		_rest_dirs[name] = (j[name][1] - j[name][0]).normalized()
	for b in _data.bones:
		if b.has("palm") and String(b.name).begins_with("fingers_"):
			var side := String(b.name).right(1)
			_curl_axis[side] = (_rest_dirs[b.name] as Vector3).cross(_v(b.palm)).normalized()
	var across: Vector3 = j.upperarm_r[0] - j.upperarm_l[0]
	var hips_across: Vector3 = j.thigh_r[0] - j.thigh_l[0]
	_rest_frames["hips"] = _frame(_rest_dirs.hips, hips_across)
	_rest_frames["spine"] = _frame(_rest_dirs.spine, across)
	_rest_frames["chest"] = _frame(_rest_dirs.chest, across)
	_rest_frames["neck"] = _frame(_rest_dirs.neck, across)
	_rest_frames["head"] = _frame(_rest_dirs.head, across)
	var leg := 0.0
	for s in ["l", "r"]:
		leg += (j["thigh_" + s][1] - j["thigh_" + s][0]).length() + (j["shin_" + s][1] - j["shin_" + s][0]).length() + j["foot_" + s][0].y
	_leg_len = leg * 0.5
	# How far behind the chest bone the back surface is, along the rest chest's back axis.
	var back: Vector3 = (_rest_frames.chest as Basis).z
	var best := 0.0
	var head_c: Vector3 = j.chest[0]
	for i in n:
		var d := verts[i] - head_c
		if absf(d.dot((_rest_frames.chest as Basis).y)) < 0.08 and absf(d.dot((_rest_frames.chest as Basis).x)) < 0.08:
			best = maxf(best, d.dot(back))
	_back_offset = back * (best + 0.012)
	_stand_h = _leg_len + (j.thigh_l[0].distance_to(j.hips[0]) * 0.3) + j.hips[0].distance_to(j.neck[0]) + j.neck[0].distance_to(j.head[1])


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Orthonormal frame from a main axis (Y) and a sideways hint (X).
static func _frame(up: Vector3, side: Vector3) -> Basis:
	var y := up.normalized()
	var z := side.cross(y).normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


func setup(skin: Color, jersey: Color, shorts: Color, hair: Color, height: float, trim := Color.WHITE) -> void:
	_load()
	if _mesh == null:
		return
	skeleton = Skeleton3D.new()
	add_child(skeleton)
	var skin_res := Skin.new()
	for b in _data.bones:
		var i := skeleton.get_bone_count()
		skeleton.add_bone(String(b.name))
		_bone[String(b.name)] = i
		var p := int(b.parent)
		_parent.append(p)
		var head := _v(b.head)
		_rest_head.append(head)
		if p >= 0:
			skeleton.set_bone_parent(i, p)
			skeleton.set_bone_rest(i, Transform3D(Basis(), head - _rest_head[p]))
		else:
			skeleton.set_bone_rest(i, Transform3D(Basis(), head))
		skin_res.add_named_bind(String(b.name), Transform3D(Basis(), head).affine_inverse())
	skeleton.reset_bone_poses()
	mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = _mesh
	mesh_instance.skin = skin_res
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	material = ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("skin_col", skin)
	material.set_shader_parameter("jersey_col", jersey)
	material.set_shader_parameter("shorts_col", shorts)
	material.set_shader_parameter("hair_col", hair)
	if _albedo:
		material.set_shader_parameter("albedo_tex", _albedo)
		material.set_shader_parameter("kit_tex", _kit)
		material.set_shader_parameter("trim_col", trim)
		var a := skin.srgb_to_linear()
		var b := _skin_ref.srgb_to_linear()
		material.set_shader_parameter("skin_ratio", Vector3(a.r / b.r, a.g / b.g, a.b / b.b))
	mesh_instance.material_override = material
	scale = Vector3.ONE * (height / _stand_h)


## The shirt number, stuck to the back of the chest bone.
func add_number(n: int, col: Color, outline: Color) -> void:
	if skeleton == null:
		return
	var att := BoneAttachment3D.new()
	skeleton.add_child(att)
	att.bone_name = "chest"
	var lab := Label3D.new()
	lab.text = str(n)
	lab.font_size = 96
	lab.pixel_size = 0.0024
	lab.outline_size = 8
	lab.modulate = col
	lab.outline_modulate = outline
	lab.double_sided = false
	# The attachment sits at the bone head, turned with the bone; place the label on the
	# back surface in the rest pose's frame.
	var f: Basis = _rest_frames.chest
	lab.transform = Transform3D(f, f * Vector3(0, 0.02, 0) + _back_offset)
	att.add_child(lab)


func set_head_visible(v: bool) -> void:
	_hidden_head = not v


## Turn every bone to match the placeholder body h (a HumanModel).
func drive(h: Node3D) -> void:
	if skeleton == null:
		return
	var inv := h.global_transform.affine_inverse()
	var g := {}
	# Torso and head: whole frames.
	g["hips"] = _match("hips", _basis_of(h.pelvis, inv))
	g["spine"] = _match("spine", _basis_of(h.spine, inv))
	g["chest"] = _match("chest", _basis_of(h.chest, inv))
	g["neck"] = _match("neck", _basis_of(h.neck, inv))
	g["head"] = _match("head", _basis_of(h.head, inv))
	# Limbs: swing each bone onto the placeholder limb's direction.
	for s in ["l", "r"]:
		var sh: Node3D = h.sh_l if s == "l" else h.sh_r
		var el: Node3D = h.el_l if s == "l" else h.el_r
		var hip: Node3D = h.hip_l if s == "l" else h.hip_r
		var kn: Node3D = h.kn_l if s == "l" else h.kn_r
		g["upperarm_" + s] = _swing("upperarm_" + s, inv * el.global_position - inv * sh.global_position)
		var fore := _basis_of(el, inv) * Vector3.DOWN
		g["forearm_" + s] = _swing("forearm_" + s, fore)
		g["hand_" + s] = _swing("hand_" + s, fore)
		g["thigh_" + s] = _swing("thigh_" + s, inv * kn.global_position - inv * hip.global_position)
		var kb := _basis_of(kn, inv)
		g["shin_" + s] = _swing("shin_" + s, kb * Vector3.DOWN)
		g["foot_" + s] = _swing("foot_" + s, kb * Vector3(0, -0.35, -1.0))
		if _curl_axis.has(s):
			_curl[s] = lerpf(_curl[s], _finger_curl(h, s), 0.25)
			g["fingers_" + s] = g["hand_" + s] * Basis(_curl_axis[s], _curl[s] * (0.55 if _bone.has("fingertips_" + s) else 1.0))
			if _bone.has("fingertips_" + s):
				g["fingertips_" + s] = g["fingers_" + s] * Basis(_curl_axis[s], _curl[s] * 0.75)
	for name in g:
		var i: int = _bone[name]
		var p: int = _parent[i]
		var local: Basis = g[name] if p < 0 else (g[_name_of(p)].inverse() * g[name])
		skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())
	# Hips height: the placeholder's pelvis, scaled to this body's legs.
	var pel: Vector3 = inv * h.pelvis.global_position
	var k := _leg_len / maxf(0.5, h.leg_length())
	skeleton.set_bone_pose_position(0, Vector3(pel.x * k, pel.y * k, pel.z * k))
	if _hidden_head:
		skeleton.set_bone_pose_scale(_bone.head, Vector3.ONE * 0.001)
	else:
		skeleton.set_bone_pose_scale(_bone.head, Vector3.ONE)


## How far the fingers curl at the knuckles, in radians: relaxed, open to reach or signal, a grip in holds
## and tackles, a fist to celebrate.
func _finger_curl(h: Node3D, s: String) -> float:
	var ath := h.get_parent()
	var st := String(ath.get("state")) if ath != null and ath.get("state") != null else ""
	match st:
		"holding", "held", "dive", "shove", "shoved":
			return 1.4
		"roar":
			return 1.9
		"celebrate":
			match int(h.cele):
				1, 5:
					return 1.9   # fist pump, chest thump
				2:
					return 0.15  # clap
				3:
					return 0.05 if s == "r" else 0.7   # high five
			return 0.3
		"signal", "slap":
			return 0.12
	if s == "r" and h.reach > 0.15:
		return lerpf(0.7, 0.05, clampf(h.reach, 0.0, 1.0))
	if h.ref_sig != 0:
		return 0.12
	return 0.7   # relaxed: a gentle curl


func _name_of(i: int) -> String:
	return skeleton.get_bone_name(i)


func _basis_of(n: Node3D, inv: Transform3D) -> Basis:
	return (inv.basis * n.global_transform.basis).orthonormalized()


## Global rotation that takes the rest frame of a torso bone onto the placeholder's frame.
func _match(name: String, target: Basis) -> Basis:
	return target * (_rest_frames[name] as Basis).inverse()


## Global rotation that swings a limb bone from its rest direction onto dir.
func _swing(name: String, dir: Vector3) -> Basis:
	var from: Vector3 = _rest_dirs[name]
	var to := dir.normalized()
	if to.length_squared() < 0.5:
		return Basis()
	return Basis(Quaternion(from, to))
