class_name RiggedBody
extends Node3D
## A realistic body (a rigged mesh made by tools/rig) that follows the code-built placeholder
## skeleton in HumanModel. The placeholder keeps animating as before, just hidden; every frame each
## bone of this mesh is turned to match the matching limb, torso or head of the placeholder. Kit
## colours come from regions painted by the rig tool or, for a textured model, from its kit map
## (tools/rig/kit_texture.py): the texture gives the face, skin and the kit's folds, and the team's
## colours replace the kit's own.
##
## There can be several bodies (assets/characters/bodies/, listed in bodies.json): each player gets
## the one nearest his skin tone and build, and officials get the referees'. Bodies are packed
## (.krb, tools/rig/pack_body.py); the older JSON form still loads.

const LEGACY := "res://assets/characters/rigged_athlete.json"
const BODIES := "res://assets/characters/bodies/"
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
uniform sampler2D kit_tex : filter_linear_mipmap, repeat_disable;   // r main, g trim, b shading / 2, a skin
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
	vec4 k = texture(kit_tex, UV);
	// Only skin takes the player's tone: shirts, shoes and hair keep theirs.
	vec3 body = t * mix(vec3(1.0), skin_ratio, k.a * (1.0 - region.b));
	// Sharp edges: a little kit bleeding in from a neighbouring piece of the texture (or a
	// little skin into the kit) is dropped.
	float amount = smoothstep(0.3, 0.7, k.r + k.g);
	vec3 kit_col = (mix(jersey_col, shorts_col, region.g) * k.r + trim_col * k.g) / max(k.r + k.g, 0.001);
	ALBEDO = mix(body, kit_col * k.b * 2.0, amount);
	ROUGHNESS = mix(0.6, 0.85, amount);
	SPECULAR = 0.35;
}
"""

static var _bodies := {}   # path -> the loaded body (see _load)
static var _index = null

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var material: ShaderMaterial
var body := {}        # the loaded body this one wears
var _bone := {}       # name -> index
var _parent := []     # index -> parent index
var _rest_head := []  # index -> rest position of the bone head (model space)
var _hidden_head := false
var _curl := {"l": 0.7, "r": 0.7}


## The bodies on offer: [{file, kind ("player" or "referee"), build, skin}], from bodies.json, or the
## single older body.
static func bodies() -> Array:
	if _index == null:
		_index = []
		var path := BODIES + "bodies.json"
		if FileAccess.file_exists(path):
			var d = JSON.parse_string(FileAccess.get_file_as_string(path))
			if d is Array:
				for e in d:
					if FileAccess.file_exists(BODIES + String(e.file)):
						_index.append(e)
		if _index.is_empty() and FileAccess.file_exists(LEGACY):
			_index.append({"file": "", "kind": "player", "build": 1.0, "skin": [0.75, 0.55, 0.42]})
	return _index


static func available() -> bool:
	return not bodies().is_empty()


## The body for a person: the nearest in skin tone and build among those of his kind, with a little
## of the seed so team-mates alike don't all look the same. Officials fall back to players' bodies.
static func pick(kind: String, skin: Color, build: float, seed: int) -> String:
	var options := bodies().filter(func(e): return String(e.kind) == kind)
	if options.is_empty():
		options = bodies().filter(func(e): return String(e.kind) == "player")
	if options.is_empty():
		return ""
	var best := ""
	var best_score := INF
	for i in options.size():
		var e: Dictionary = options[i]
		var sk: Array = e.get("skin", [0.75, 0.55, 0.42])
		var tone := Color(float(sk[0]), float(sk[1]), float(sk[2]))
		var score := absf(tone.get_luminance() - skin.get_luminance()) * 2.0 + absf(float(e.get("build", 1.0)) - build) * 3.0
		score += float(hash(seed * 31 + i) % 1000) / 1000.0 * 0.25
		if score < best_score:
			best_score = score
			best = String(e.file)
	return best


static func _path(file: String) -> String:
	return LEGACY if file == "" else BODIES + file


## Load a body once: its mesh, textures and the rest-pose measures used to drive it.
static func _load(file: String) -> Dictionary:
	if _bodies.has(file):
		return _bodies[file]
	var path := _path(file)
	var d := _read_krb(path) if path.ends_with(".krb") else _read_json(path)
	_bodies[file] = d
	if d.is_empty():
		push_warning("rigged body: could not read " + path)
		return d
	var verts: PackedVector3Array = d.verts
	d.shader = Shader.new()
	d.shader.code = SHADER_TEXTURED if d.get("albedo") else SHADER
	var j := {}
	for b in d.bones:
		j[b.name] = [_v(b.head), _v(b.tail)]
	var rest_dirs := {}
	for name in j:
		rest_dirs[name] = (j[name][1] - j[name][0]).normalized()
	var curl_axis := {}
	for b in d.bones:
		if b.has("palm") and String(b.name).begins_with("fingers_"):
			curl_axis[String(b.name).right(1)] = (rest_dirs[b.name] as Vector3).cross(_v(b.palm)).normalized()
	var across: Vector3 = j.upperarm_r[0] - j.upperarm_l[0]
	var hips_across: Vector3 = j.thigh_r[0] - j.thigh_l[0]
	var frames := {}
	frames["hips"] = _frame(rest_dirs.hips, hips_across)
	for name in ["spine", "chest", "neck", "head"]:
		frames[name] = _frame(rest_dirs[name], across)
	var leg := 0.0
	for s in ["l", "r"]:
		leg += (j["thigh_" + s][1] - j["thigh_" + s][0]).length() + (j["shin_" + s][1] - j["shin_" + s][0]).length() + j["foot_" + s][0].y
	d.leg_len = leg * 0.5
	# How far behind the chest bone the back surface is, along the rest chest's back axis.
	var chest: Basis = frames.chest
	var back: Vector3 = chest.z
	var best := 0.0
	var head_c: Vector3 = j.chest[0]
	for v in verts:
		var dv := v - head_c
		if absf(dv.dot(chest.y)) < 0.08 and absf(dv.dot(chest.x)) < 0.08:
			best = maxf(best, dv.dot(back))
	d.back_offset = back * (best + 0.012)
	d.stand_h = d.leg_len + (j.thigh_l[0].distance_to(j.hips[0]) * 0.3) + j.hips[0].distance_to(j.neck[0]) + j.neck[0].distance_to(j.head[1])
	d.rest_dirs = rest_dirs
	d.rest_frames = frames
	d.curl_axis = curl_axis
	d.erase("verts")
	return d


static func _texture_part(d: Dictionary, tex: Dictionary) -> void:
	if ResourceLoader.exists(String(tex.get("albedo", ""))) and ResourceLoader.exists(String(tex.get("kit", ""))):
		d.albedo = load(String(tex.albedo))
		d.kit = load(String(tex.kit))
		var r: Array = tex.get("skin_ref", [1, 1, 1])
		d.skin_ref = Color(float(r[0]), float(r[1]), float(r[2]))


static func _build_mesh(d: Dictionary, verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array,
		region: PackedByteArray, bones: PackedInt32Array, weights: PackedFloat32Array, idx: PackedInt32Array) -> void:
	var cols := PackedColorArray()
	cols.resize(verts.size())
	for i in verts.size():
		var r := region[i]
		cols[i] = Color(1.0 if r == 1 else 0.0, 1.0 if r == 2 else 0.0, 1.0 if r == 3 else 0.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	if d.get("albedo") and not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	d.mesh = mesh
	d.verts = verts


## The packed form (tools/rig/pack_body.py).
static func _read_krb(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_buffer(4).get_string_from_ascii() != "KRB1":
		return {}
	var meta = JSON.parse_string(f.get_buffer(f.get_32()).get_string_from_utf8())
	if not (meta is Dictionary):
		return {}
	var n := int(meta.vertices)
	var pad := func(x: int) -> int: return x + (4 - x % 4) % 4
	var pos := f.get_buffer(pad.call(n * 6))
	var nrm := f.get_buffer(pad.call(n * 3))
	var uvb := f.get_buffer(pad.call(n * 4)) if meta.has_uv else PackedByteArray()
	var bb := f.get_buffer(pad.call(n * 4))
	var wb := f.get_buffer(pad.call(n * 4))
	var region := f.get_buffer(pad.call(n))
	var u32 := bool(meta.index_u32)
	var ib := f.get_buffer(int(meta.indices) * (4 if u32 else 2))
	var lo := _v(meta.pos_min)
	var span := _v(meta.pos_span) / 65535.0
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	verts.resize(n)
	norms.resize(n)
	if meta.has_uv:
		uvs.resize(n)
	for i in n:
		verts[i] = lo + Vector3(pos.decode_u16(i * 6), pos.decode_u16(i * 6 + 2), pos.decode_u16(i * 6 + 4)) * span
		norms[i] = Vector3(nrm.decode_s8(i * 3), nrm.decode_s8(i * 3 + 1), nrm.decode_s8(i * 3 + 2)).normalized()
		if meta.has_uv:
			uvs[i] = Vector2(uvb.decode_u16(i * 4), uvb.decode_u16(i * 4 + 2)) / 65535.0
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(n * 4)
	weights.resize(n * 4)
	for i in n * 4:
		bones[i] = bb[i]
		weights[i] = wb[i] / 255.0
	var count := int(meta.indices)
	var idx := PackedInt32Array()
	idx.resize(count)
	# glTF and trimesh wind front faces counter-clockwise; Godot wants clockwise.
	for t in count / 3:
		for c in 3:
			var k = t * 3 + [0, 2, 1][c]
			idx[t * 3 + c] = ib.decode_u32(k * 4) if u32 else ib.decode_u16(k * 2)
	var d := {"bones": meta.bones, "height": float(meta.height)}
	_texture_part(d, meta.get("texture", {}))
	_build_mesh(d, verts, norms, uvs, region.slice(0, n), bones, weights, idx)
	return d


## The older JSON form.
static func _read_json(path: String) -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (data is Dictionary):
		return {}
	var vs: Array = data.vertices
	var ns: Array = data.normals
	var n := vs.size() / 3
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(n)
	norms.resize(n)
	for i in n:
		verts[i] = Vector3(vs[i * 3], vs[i * 3 + 1], vs[i * 3 + 2])
		norms[i] = Vector3(ns[i * 3], ns[i * 3 + 1], ns[i * 3 + 2])
	var uvs := PackedVector2Array()
	if data.has("uvs"):
		var us: Array = data.uvs
		uvs.resize(n)
		for i in n:
			uvs[i] = Vector2(us[i * 2], us[i * 2 + 1])
	var region := PackedByteArray()
	for r in data.region:
		region.append(int(r))
	var src: Array = data.indices
	var idx := PackedInt32Array()
	idx.resize(src.size())
	for t in src.size() / 3:
		idx[t * 3] = int(src[t * 3])
		idx[t * 3 + 1] = int(src[t * 3 + 2])
		idx[t * 3 + 2] = int(src[t * 3 + 1])
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	for b in data.bones4:
		bones.append(int(b))
	for w in data.weights4:
		weights.append(float(w))
	var d := {"bones": data.bones, "height": float(data.height)}
	_texture_part(d, data.get("texture", {}))
	_build_mesh(d, verts, norms, uvs, region, bones, weights, idx)
	return d


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Orthonormal frame from a main axis (Y) and a sideways hint (X).
static func _frame(up: Vector3, side: Vector3) -> Basis:
	var y := up.normalized()
	var z := side.cross(y).normalized()
	var x := y.cross(z).normalized()
	return Basis(x, y, z)


func setup(skin: Color, jersey: Color, shorts: Color, hair: Color, height: float, trim := Color.WHITE, file := "") -> void:
	body = _load(file)
	if body.is_empty():
		return
	skeleton = Skeleton3D.new()
	add_child(skeleton)
	var skin_res := Skin.new()
	for b in body.bones:
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
	mesh_instance.mesh = body.mesh
	mesh_instance.skin = skin_res
	skeleton.add_child(mesh_instance)
	mesh_instance.skeleton = NodePath("..")
	material = ShaderMaterial.new()
	material.shader = body.shader
	material.set_shader_parameter("skin_col", skin)
	material.set_shader_parameter("jersey_col", jersey)
	material.set_shader_parameter("shorts_col", shorts)
	material.set_shader_parameter("hair_col", hair)
	if body.get("albedo"):
		material.set_shader_parameter("albedo_tex", body.albedo)
		material.set_shader_parameter("kit_tex", body.kit)
		material.set_shader_parameter("trim_col", trim)
		var a := skin.srgb_to_linear()
		var b: Color = (body.skin_ref as Color).srgb_to_linear()
		material.set_shader_parameter("skin_ratio", Vector3(a.r / b.r, a.g / b.g, a.b / b.b))
	mesh_instance.material_override = material
	scale = Vector3.ONE * (height / float(body.stand_h))


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
	var f: Basis = body.rest_frames.chest
	lab.transform = Transform3D(f, f * Vector3(0, 0.02, 0) + body.back_offset)
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
		if body.curl_axis.has(s):
			var axis: Vector3 = body.curl_axis[s]
			_curl[s] = lerpf(_curl[s], _finger_curl(h, s), 0.25)
			g["fingers_" + s] = g["hand_" + s] * Basis(axis, _curl[s] * (0.55 if _bone.has("fingertips_" + s) else 1.0))
			if _bone.has("fingertips_" + s):
				g["fingertips_" + s] = g["fingers_" + s] * Basis(axis, _curl[s] * 0.75)
	for name in g:
		var i: int = _bone[name]
		var p: int = _parent[i]
		var local: Basis = g[name] if p < 0 else (g[_name_of(p)].inverse() * g[name])
		skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())
	# Hips height: the placeholder's pelvis, scaled to this body's legs.
	var pel: Vector3 = inv * h.pelvis.global_position
	var k := float(body.leg_len) / maxf(0.5, h.leg_length())
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
	return target * (body.rest_frames[name] as Basis).inverse()


## Global rotation that swings a limb bone from its rest direction onto dir.
func _swing(name: String, dir: Vector3) -> Basis:
	var from: Vector3 = body.rest_dirs[name]
	var to := dir.normalized()
	if to.length_squared() < 0.5:
		return Basis()
	return Basis(Quaternion(from, to))
