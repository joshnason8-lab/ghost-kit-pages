class_name RiggedBody
extends Node3D
## The owner's athletes (assets/characters/, made from their Meshy models by tools/meshy/prepare.gd): a man for the
## men's game and the referees, a woman for the women's. The game still poses its own skeleton (Body: the joint
## angles of the run, the shot, the save, the referee's signs, the arms' reach for the stick); this body follows it
## each frame, bone by bone, and then puts its own hands on the stick. One draw call for the person, one for the stick.
##
## How a bone follows: at rest the game's limbs hang straight down and its trunk stands straight up, where the
## model's arms are spread a little (an A-pose). So each of the model's bones is first turned, once, to point as the
## game's does at rest (K); after that it turns as the game's bone turns: its model-space rotation is the game
## bone's rotation times K. Feet, hands' twist, the head and the shoulders keep the model's own rest.
##
## The kit: the texture's dark blue (shirt, shorts, socks) and light blue (trim) become the team's colours, told
## apart by how high each vertex stands at rest (tools/meshy bakes it into the vertex colour); a goalkeeper's legs are
## his long trousers; the skin can take another tone.

const DIR := "res://assets/characters/"
## model bone -> [the game's bone it follows, how its rest is turned: "down" a hanging limb, "up" the trunk, "" kept]
const MAP := {
	"mixamorig_Hips": ["hips", ""],
	"mixamorig_Spine": ["spine", "up"],
	"mixamorig_Spine1": ["spine", "up"],
	"mixamorig_Spine2": ["chest", "up"],
	"mixamorig_Neck": ["neck", "up"],
	"mixamorig_Head": ["head", ""],
	"headfront": ["head", ""],
	"mixamorig_LeftShoulder": ["chest", ""],
	"mixamorig_LeftArm": ["upperarm_l", "down"],
	"mixamorig_LeftForeArm": ["forearm_l", "down"],
	"mixamorig_LeftHand": ["hand_l", "down"],
	"mixamorig_RightShoulder": ["chest", ""],
	"mixamorig_RightArm": ["upperarm_r", "down"],
	"mixamorig_RightForeArm": ["forearm_r", "down"],
	"mixamorig_RightHand": ["hand_r", "down"],
	"mixamorig_LeftUpLeg": ["thigh_l", "down"],
	"mixamorig_LeftLeg": ["shin_l", "down"],
	"mixamorig_LeftFoot": ["foot_l", ""],
	"mixamorig_LeftToeBase": ["foot_l", ""],
	"mixamorig_RightUpLeg": ["thigh_r", "down"],
	"mixamorig_RightLeg": ["shin_r", "down"],
	"mixamorig_RightFoot": ["foot_r", ""],
	"mixamorig_RightToeBase": ["foot_r", ""],
}
const SHADER := """
shader_type spatial;
render_mode cull_back;
#include "res://game/shaders/look.gdshaderinc"
uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_disable;
uniform vec3 jersey_col = vec3(0.1, 0.25, 0.65);
uniform vec3 shorts_col = vec3(0.1, 0.25, 0.65);
uniform vec3 socks_col = vec3(0.1, 0.25, 0.65);
uniform vec3 trim_col = vec3(0.6, 0.85, 0.95);
uniform vec3 skin_ratio = vec3(1.0);
uniform float keeper = 0.0;      // 1: the legs in long trousers (shorts_col)
uniform float recolour = 1.0;
varying float h;                 // standing height, 0 soles .. 1 crown
void vertex() {
	h = COLOR.r;
}
void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	float mx = max(t.r, max(t.g, t.b));
	float mn = min(t.r, min(t.g, t.b));
	float sat = (mx - mn) / max(mx, 0.001);
	// The kit's dark blue and its light-blue trim; skin is warm (red over blue), the shoes white or grey.
	float blue = step(t.r * 1.15 + 0.02, t.b) * step(t.g, t.b);
	float main = blue * smoothstep(0.35, 0.5, sat) * (1.0 - smoothstep(0.62, 0.78, mx));
	float trim = blue * smoothstep(0.62, 0.78, mx) * smoothstep(0.12, 0.25, sat) * step(0.5, t.g);
	vec3 region = h > 0.49 ? jersey_col : (h > 0.29 ? shorts_col : socks_col);
	main *= step(0.06, h);   // the shoes keep their own colours
	trim *= step(0.06, h);
	float lum = dot(t, vec3(0.3, 0.55, 0.15));
	vec3 kit = region * clamp(lum / 0.2, 0.35, 1.6);
	vec3 tr = trim_col * clamp(lum / 0.72, 0.5, 1.2);
	float skin = step(t.b * 1.05, t.r) * step(t.g, t.r) * smoothstep(0.12, 0.25, sat) * (1.0 - main - trim);
	vec3 c = mix(t, t * skin_ratio, clamp(skin, 0.0, 1.0));
	c = mix(c, kit, main * recolour);
	c = mix(c, tr, trim * recolour);
	// A goalkeeper's trousers: everything from the shoes to the waist that is not the shoes.
	float legs = keeper * step(0.07, h) * step(h, 0.49) * (1.0 - step(0.75, mn));
	c = mix(c, shorts_col * clamp(lum / 0.25, 0.4, 1.4), legs);
	ALBEDO = compat_to_scene(c);
	float cloth = clamp(main + trim + legs, 0.0, 1.0);
	ROUGHNESS = mix(0.55, 0.85, cloth);
	SPECULAR = mix(0.4, 0.25, cloth);
	RIM = 0.25;
	RIM_TINT = 0.5;
}
"""

static var _scenes := {}     # file -> PackedScene
static var _fists := {}      # file -> its mesh with the hands made into fists (players: they hold a stick)
static var _frames_cache := {}  # the open mesh's path + side -> its hand's frame (_hand_frame)
var _src_path := ""
static var _textures := {}   # file -> Texture2D
static var _shader: Shader
static var _stick_mesh: Mesh
static var _stick_mat: Material
static var _shaft_mat: Material
static var _stick_fix := Transform3D()

var character: Node3D
var skeleton: Skeleton3D
var mesh: MeshInstance3D
var material: ShaderMaterial
var stick: MeshInstance3D
var _k := 0.01               # the model's skeleton units to the game's body's (m)
var _bones := []             # per model bone: [index, parent index, game bone index, K basis, rest position]
var _hips_rest := Vector3.ZERO
var _leg_ratio := 1.0
var _arm := {}               # side -> [arm, forearm, hand indices, upper length, fore length]
var _fist := {}              # side -> [the fist's hole's axis, the grip's centre] in the hand bone's own space
var _grip_off := {}          # side -> wrist to the fist's centre, as the hand was last turned (skeleton space)


static func available() -> bool:
	return ResourceLoader.exists(DIR + "man.scn")


## Builds the body for look (Body's look: kind, colours, women) inside body, scaled to the game's 1.80 m skeleton.
func setup(body: Body, look: Dictionary) -> void:
	var gfx := int(Game.settings.graphics)
	var file := ("woman" if bool(look.get("women", false)) else "man") + ("_low" if gfx <= Game.GFX_LOW else ("_mid" if gfx == Game.GFX_MEDIUM else ""))
	if not _scenes.has(file):
		_scenes[file] = load(DIR + file + ".scn")
	character = (_scenes[file] as PackedScene).instantiate()
	add_child(character)
	skeleton = character.find_children("*", "Skeleton3D", true, false)[0]
	mesh = character.find_children("*", "MeshInstance3D", true, false)[0]
	for ap in character.find_children("*", "AnimationPlayer", true, false):
		ap.queue_free()
	# The model's size: soles to crown as the game's 1.80 m body (Body scales that to the player's height).
	var aabb := mesh.get_aabb()
	var s := 1.8 / maxf(0.5, aabb.size.y * 1.03)
	character.scale = Vector3.ONE * s
	var to_body := skeleton.global_transform if skeleton.is_inside_tree() else _chain(skeleton)
	_k = to_body.basis.get_scale().x
	_prepare(body)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	material = ShaderMaterial.new()
	material.shader = _shader
	# The texture: 1024 px on Low, 2048 px (man_2k.jpg) on Medium and High.
	var tex_file := file.replace("_low", "").replace("_mid", "") + ("" if gfx <= Game.GFX_LOW else "_2k")
	if not ResourceLoader.exists(DIR + tex_file + ".jpg"):
		tex_file = tex_file.trim_suffix("_2k")
	if not _textures.has(tex_file):
		_textures[tex_file] = load(DIR + tex_file + ".jpg")
	material.set_shader_parameter("albedo_tex", _textures[tex_file])
	mesh.material_override = material
	recolour(look)
	if String(look.get("kind", "player")) == "player":
		# Fists round the stick (the model's hands are open and have no finger bones: bent in the mesh, once a file).
		_src_path = (mesh.mesh as Resource).resource_path
		if not _fists.has(file):
			_fists[file] = _gripped(mesh.mesh as ArrayMesh, mesh.skin, skeleton)
		mesh.mesh = _fists[file]
		_grip_frames()
		_make_stick()
	elif String(look.get("kind", "")) == "keeper":
		_make_helmet(look)


## The fist: where the stick's shaft runs through each hand, from the wrist (the model's metres), and how far the
## fingers' middle is from it. As Hurling Heroes did for its hurley (hero_body.gd _gripped).
const LIE := 33.0            # degrees the blade is tipped down the shaft from square to it (stick_mesh)
const GRIP_ALONG := 0.082    # from the wrist toward the fingertips
const GRIP_R := 0.026        # from the fingers' middle to the shaft's centre line
const GRIP_MAX := 3.0        # radians: as far as a fingertip curls, into the palm


## The hand's own frame in the mesh's space (from its bind pose): [wrist, fingers' way, palm's normal, the fist's
## hole's axis (across the palm), its bind index].
static func _hand_frame(skin: Skin, sk: Skeleton3D, side: String, src: ArrayMesh = null) -> Array:
	var name := "mixamorig_%sHand" % ("Left" if side == "l" else "Right")
	var bi := -1
	for j in skin.get_bind_count():
		if skin.get_bind_name(j) == name or (skin.get_bind_name(j) == "" and skin.get_bind_bone(j) == sk.find_bone(name)):
			bi = j
	if bi < 0:
		return []
	var rest := skin.get_bind_pose(bi).affine_inverse()
	var b := rest.basis.orthonormalized()
	var fingers := b.y.normalized()
	# The model stands with its palms to its thighs: the palm faces the body's middle, square to the fingers.
	var inward := Vector3(-signf(rest.origin.x), 0, 0)
	var palm := (inward - fingers * inward.dot(fingers)).normalized()
	var ax := fingers.cross(palm).normalized()
	return [rest.origin, fingers, palm, ax, bi]


## The model's hands made into fists round a stick's shaft: each finger, from where it passes the shaft's line, wrapped
## round that line (a line across the palm, front to back, just inside it), as a bend wraps a strip round a rod. The
## thumb, on the far side of the line, stays alongside the shaft. The mesh's levels of detail kept.
static func _gripped(src: ArrayMesh, skin: Skin, sk: Skeleton3D) -> ArrayMesh:
	if src == null or skin == null:
		return src
	var a := src.surface_get_arrays(0)
	var vs: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var ns: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var bs: PackedInt32Array = a[Mesh.ARRAY_BONES]
	var ws: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	var stride := bs.size() / maxi(1, vs.size())
	for side in ["l", "r"]:
		var f := _hand_frame(skin, sk, side, src)
		if f.is_empty():
			continue
		_frames_cache[src.resource_path + side] = f
		var fingers: Vector3 = f[1]
		var palm: Vector3 = f[2]
		var ax: Vector3 = f[3]
		var bi: int = f[4]
		var a0: Vector3 = f[0] + fingers * GRIP_ALONG + palm * GRIP_R
		var turn_ax := (-palm).cross(fingers).normalized()
		for i in vs.size():
			var w := 0.0
			for j in stride:
				if bs[i * stride + j] == bi:
					w += ws[i * stride + j]
			if w <= 0.0:
				continue
			var rel := vs[i] - a0
			var along := rel.dot(ax)
			var q := rel - ax * along
			var s := q.dot(fingers)
			var n := -q.dot(palm)
			if s <= 0.0 or n <= 0.004:
				continue
			var th := minf(s / maxf(n, GRIP_R * 0.6), GRIP_MAX)
			var rot := Basis(turn_ax, th)
			var bent := a0 + ax * along + rot * (-palm * n)
			vs[i] = vs[i].lerp(bent, w)
			if ns[i].length() > 0.0:
				ns[i] = ns[i].slerp((rot * ns[i]).normalized(), w).normalized()
	a[Mesh.ARRAY_VERTEX] = vs
	a[Mesh.ARRAY_NORMAL] = ns
	a[Mesh.ARRAY_TANGENT] = null
	var lods := {}
	var sd := RenderingServer.mesh_get_surface(src.get_rid(), 0)
	var wide := vs.size() > 65535
	for l: Dictionary in sd.get("lods", []):
		var by: PackedByteArray = l.index_data
		var ix := PackedInt32Array()
		ix.resize(by.size() / (4 if wide else 2))
		for k in ix.size():
			ix[k] = by.decode_u32(k * 4) if wide else by.decode_u16(k * 2)
		lods[float(l.edge_length)] = ix
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], lods, src.surface_get_format(0) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	out.custom_aabb = src.custom_aabb
	if src.get_blend_shape_count() == 0:
		out.surface_set_material(0, src.surface_get_material(0))
	return out


## Each fist's hole (its axis) and centre (from the wrist), in its hand bone's own frame and the skeleton's units, to
## put the shaft through it.
func _grip_frames() -> void:
	for side in ["l", "r"]:
		var f: Array = _frames_cache.get(_src_path + side, [])
		if f.is_empty():
			continue
		var h: int = _arm[side][2]
		var rest := skeleton.get_bone_global_rest(h)
		var unit := rest.origin.length() / maxf(0.001, (f[0] as Vector3).length())   # skeleton units a mesh metre
		var inv := rest.basis.orthonormalized().inverse()
		var centre: Vector3 = (f[1] as Vector3) * GRIP_ALONG + (f[2] as Vector3) * GRIP_R
		_fist[side] = [(inv * (f[3] as Vector3)).normalized(), inv * (centre * unit)]


## The model's skeleton relative to this node, before it is in the tree.
func _chain(n: Node3D) -> Transform3D:
	var xf := Transform3D()
	var p: Node = n
	while p != null and p != self:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


func recolour(look: Dictionary) -> void:
	var kind := String(look.get("kind", "player"))
	# Plain vectors, as written: a Color would be decoded for Vulkan, and the shader converts once at the end.
	for k in [["jersey_col", "jersey", Color.BLUE], ["shorts_col", "shorts", Color.BLUE], ["socks_col", "socks", Color.BLUE], ["trim_col", "trim", Color.WHITE]]:
		var c: Color = look.get(k[1], k[2])
		material.set_shader_parameter(k[0], Vector3(c.r, c.g, c.b))
	material.set_shader_parameter("keeper", 1.0 if kind == "keeper" else 0.0)
	# The texture's skin as the lightest tone in the game (DB.SKIN[0]): darker tones darken it, in linear light; none
	# lightens it (brightened, a light skin washed out to grey under the hall's lights).
	var ref := Color(DB.SKIN[0]).srgb_to_linear()
	var sk: Color = (look.get("skin", Color("e3b08e")) as Color).srgb_to_linear()
	material.set_shader_parameter("skin_ratio", Vector3(sk.r / ref.r, sk.g / ref.g, sk.b / ref.b))


func _prepare(body: Body) -> void:
	var n := skeleton.get_bone_count()
	var rest_g := []
	rest_g.resize(n)
	for i in n:
		rest_g[i] = skeleton.get_bone_global_rest(i)
	for i in n:
		var bn := skeleton.get_bone_name(i)
		if not MAP.has(bn):
			continue
		var m: Array = MAP[bn]
		var r: Basis = (rest_g[i] as Transform3D).basis.orthonormalized()
		var k := r
		if String(m[1]) != "":
			var want := Vector3.DOWN if String(m[1]) == "down" else Vector3.UP
			k = Body._from_to(r.y.normalized(), want) * r
		_bones.append([i, skeleton.get_bone_parent(i), body.bone(String(m[0])), k, skeleton.get_bone_rest(i).origin])
	var hips := skeleton.find_bone("mixamorig_Hips")
	_hips_rest = (rest_g[hips] as Transform3D).origin
	var foot := skeleton.find_bone("mixamorig_LeftFoot")
	# The model's legs against the game's (hips 0.95 m over the floor at rest, feet 0.07 m).
	_leg_ratio = ((rest_g[hips] as Transform3D).origin.y - (rest_g[foot] as Transform3D).origin.y) * _k / (0.95 - 0.07)
	for side in ["l", "r"]:
		var pre := "mixamorig_Left" if side == "l" else "mixamorig_Right"
		var a := skeleton.find_bone(pre + "Arm")
		var f := skeleton.find_bone(pre + "ForeArm")
		var h := skeleton.find_bone(pre + "Hand")
		_arm[side] = [a, f, h, (rest_g[f] as Transform3D).origin.distance_to((rest_g[a] as Transform3D).origin),
			(rest_g[h] as Transform3D).origin.distance_to((rest_g[f] as Transform3D).origin)]


## The goalkeeper's helmet (Rules 403: a helmet with a face cage): a shell in his jersey's colour and a wire cage over
## the face, one mesh on the head's bone.
func _make_helmet(look: Dictionary) -> void:
	var head := skeleton.find_bone("mixamorig_Head")
	var front := skeleton.find_bone("headfront")
	var hr := skeleton.get_bone_global_rest(head)
	var face := skeleton.get_bone_global_rest(front).origin
	# The head: a sphere round its bone's root, as big as from there to the face, set a little up and forward.
	var r := (face - hr.origin).length() * 1.15
	var centre := hr.origin + Vector3(0, r * 0.95, (face.z - hr.origin.z) * 0.25)
	var att := BoneAttachment3D.new()
	att.bone_name = "mixamorig_Head"
	skeleton.add_child(att)
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = r
	sp.height = r * 2.1
	sp.radial_segments = 16
	sp.rings = 10
	mi.mesh = sp
	mi.transform = Transform3D(Basis.IDENTITY, hr.affine_inverse() * centre)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
#include "res://game/shaders/look.gdshaderinc"
uniform vec3 shell = vec3(0.1);
uniform vec3 fwd = vec3(0.0, 0.0, 1.0);
varying vec3 n;
void vertex() { n = NORMAL; }
void fragment() {
	float face = dot(normalize(n), normalize(fwd));
	if (face > 0.25) {
		// The cage: thin bars across and down the face, the face seen through them.
		vec2 g = fract(vec2(UV.x * 44.0, UV.y * 20.0));
		if (g.x > 0.22 && g.y > 0.25) discard;
		ALBEDO = compat_to_scene(vec3(0.82));
		METALLIC = 0.6;
		ROUGHNESS = 0.35;
	} else {
		ALBEDO = compat_to_scene(shell);
		ROUGHNESS = 0.4;
	}
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var jersey: Color = look.get("jersey", Color(0.1, 0.1, 0.1))
	var sc := jersey.lightened(0.15)
	m.set_shader_parameter("shell", Vector3(sc.r, sc.g, sc.b))
	m.set_shader_parameter("fwd", (hr.basis.inverse() * (face - hr.origin)).normalized())
	mi.material_override = m
	mi.cast_shadow = mesh.cast_shadow
	att.add_child(mi)


func _make_stick() -> void:
	if _stick_mesh == null:
		_stick_mesh = stick_mesh()
		var m := StandardMaterial3D.new()
		m.albedo_texture = _blade_texture()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.roughness = 0.35
		_stick_mat = m
		var sm := StandardMaterial3D.new()
		sm.vertex_color_use_as_albedo = true
		sm.roughness = 0.3
		sm.metallic_specular = 0.6
		_shaft_mat = sm
		_stick_fix = Transform3D.IDENTITY
	stick = MeshInstance3D.new()
	stick.mesh = _stick_mesh
	stick.set_surface_override_material(0, _shaft_mat)
	stick.set_surface_override_material(1, _stick_mat)
	stick.cast_shadow = mesh.cast_shadow
	add_child(stick)


## A floorball stick, as the game holds it (the grip's end at the origin, the shaft down -Y to the blade's heel,
## Body.STICK_LEN; the blade toward +Z): a round composite shaft, 25 mm across, with a white band of print under the
## grip; and a blade of perforated plastic, about 28 cm long and 8.5 cm tall, standing on its edge, its face to the
## side, set at a lie of LIE degrees to the shaft (so it lies along the floor with the shaft leaning out toward the
## ball as it is held), its toe hooked a little and its bottom edge rockered (the Material Regulations' blade).
static func stick_mesh() -> ArrayMesh:
	var out := ArrayMesh.new()
	var L := Body.STICK_LEN
	# The shaft: a tube, ten sides, from the grip's end to the heel; the print band by vertex colour.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 0.0125
	var n := 10
	var rings := [0.0, 0.16, 0.19, 0.25, L]
	for k in rings.size() - 1:
		var col := Color(0.92, 0.93, 0.94) if k == 2 else Color(0.08, 0.09, 0.1)
		for i in n:
			var a0 := TAU * i / n
			var a1 := TAU * (i + 1) / n
			var d0 := Vector3(cos(a0), 0, sin(a0))
			var d1 := Vector3(cos(a1), 0, sin(a1))
			var y0 := -float(rings[k])
			var y1 := -float(rings[k + 1])
			for q in [[d0, y0], [d1, y0], [d1, y1], [d0, y0], [d1, y1], [d0, y1]]:
				st.set_color(col)
				st.set_normal(q[0])
				st.add_vertex((q[0] as Vector3) * r + Vector3(0, q[1], 0))
	st.commit(out)
	# The blade: a plate along u (from the heel, tipped down the shaft by the lie), v up its face, X its face's normal.
	var lie := deg_to_rad(LIE)
	var heel := Vector3(0, -L, 0)
	var u := Vector3(0, -sin(lie), cos(lie))
	var v := Vector3(0, cos(lie), sin(lie))
	var sb := SurfaceTool.new()
	sb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ns := 14
	var nt := 4
	var length := 0.28
	var tall := 0.085
	var grid := []
	for i in ns + 1:
		var row := []
		var s := length * i / ns
		var k := float(i) / ns
		var hook := 0.03 * k * k                       # the toe hooked toward the face
		var rocker := 0.012 * pow(2.0 * k - 1.0, 2.0)  # the bottom edge's rocker, lowest in the middle
		var h := tall * (0.82 + 0.18 * sin(k * PI))    # taller in the middle, the heel and toe rounded off
		for j in nt + 1:
			var t := -0.012 + rocker + h * j / nt
			row.append(heel + u * (s + 0.01) + v * t + Vector3(hook, 0, 0))
		grid.append(row)
	for i in ns:
		for j in nt:
			var p00: Vector3 = grid[i][j]
			var p10: Vector3 = grid[i + 1][j]
			var p11: Vector3 = grid[i + 1][j + 1]
			var p01: Vector3 = grid[i][j + 1]
			var nrm := (p10 - p00).cross(p01 - p00).normalized()
			for q in [[p00, i, j], [p10, i + 1, j], [p11, i + 1, j + 1], [p00, i, j], [p11, i + 1, j + 1], [p01, i, j + 1]]:
				sb.set_normal(nrm)
				sb.set_uv(Vector2(float(q[1]) / ns, float(q[2]) / nt))
				sb.add_vertex(q[0])
	# The neck: from the shaft's end into the blade's heel.
	for q in [[heel + Vector3(-r, 0, 0), heel + Vector3(r, 0, 0), grid[0][nt * 3 / 4]], [heel + Vector3(r, 0, 0), grid[0][0], grid[0][nt * 3 / 4]]]:
		for p in q:
			sb.set_normal(Vector3.RIGHT)
			sb.set_uv(Vector2(0.0, 0.5))
			sb.add_vertex(p)
	sb.commit(out)
	return out


static var _blade_tex: ImageTexture


## The blade's plastic: the model's cyan, perforated (rounded slots in rows, a solid rim round the edge).
static func _blade_texture() -> ImageTexture:
	if _blade_tex:
		return _blade_tex
	var w := 256
	var h := 80
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var cyan := Color("2ec9ec")
	for y in h:
		for x in w:
			var rim := x < 8 or x > w - 8 or y < 8 or y > h - 8
			# Slots: rounded rectangles in a staggered grid.
			var cx := fposmod(float(x) + (12.0 if (y / 24) % 2 == 1 else 0.0), 24.0) - 12.0
			var cy := fposmod(float(y) - 4.0, 24.0) - 12.0
			var hole := not rim and Vector2(maxf(absf(cx) - 3.0, 0.0), maxf(absf(cy) - 5.0, 0.0)).length() < 4.0
			var shade := 1.0 - 0.15 * float(y) / h
			img.set_pixel(x, y, Color(cyan.r * shade, cyan.g * shade, cyan.b * shade, 0.0 if hole else 1.0))
	img.generate_mipmaps()
	_blade_tex = ImageTexture.create_from_image(img)
	return _blade_tex


## Follows the game's skeleton (body has posed it this frame), then the hands to the stick.
func follow(body: Body) -> void:
	var our := body.skeleton
	var g := {}   # model bone -> its model-space basis
	var pos := {} # model bone -> its model-space position
	var inv_k := 1.0 / _k
	for e in _bones:
		var i: int = e[0]
		var parent: int = e[1]
		var gb: Basis = our.get_bone_global_pose(int(e[2])).basis * (e[3] as Basis)
		g[i] = gb
		var local: Basis = gb if parent < 0 else (g[parent] as Basis).inverse() * gb
		skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())
		if parent < 0:
			var hips: Vector3 = our.get_bone_global_pose(int(e[2])).origin
			var at := _hips_rest + (hips - Vector3(0, 0.95, 0)) * _leg_ratio * inv_k
			skeleton.set_bone_pose_position(i, at)
			pos[i] = at
		else:
			pos[i] = (pos[parent] as Vector3) + (g[parent] as Basis) * (e[4] as Vector3)
	if stick == null or not body.has_stick():
		if stick:
			stick.visible = false
		return
	stick.visible = true
	var sx: Transform3D = body.stick_transform()
	stick.transform = sx * _stick_fix
	var down := -sx.basis.y.normalized()
	var hands := body.stick_hands()
	# Each hand to its place on the shaft, or the nearest place it can reach (a hand slides up or down the shaft rather
	# than let go of it); the lower hand stays a hand's width below the top one.
	var grip := sx.origin * inv_k
	var top_t := 0.0
	var sides: Array = hands.keys()
	sides.sort_custom(func(x, y): return float(hands[x]) < float(hands[y]))
	for side in sides:
		var a: Array = _arm[side]
		var off0: Vector3 = _grip_off.get(side, Vector3.ZERO)
		# The fist's centre is beyond the wrist; the shoulder's swing (_reach) gives some back.
		var reach: float = (float(a[3]) + float(a[4])) * 0.97 - off0.length() + 0.1 * inv_k
		var t := _on_shaft(pos[a[0]], grip, down, float(hands[side]) * inv_k, reach, top_t)
		top_t = t + 0.12 * inv_k
		var on_shaft := grip + down * t
		if not _fist.has(side):
			_reach(side, on_shaft, g, pos)
			continue
		# The wrist where the fist's centre is on the shaft (its offset as the hand was turned last frame), then the
		# hand turned so the shaft runs through the fist.
		var off: Vector3 = _grip_off.get(side, Vector3.ZERO)
		var r: Array = _reach(side, on_shaft - off, g, pos)
		var gf: Basis = r[0]
		var gh: Basis = r[1]
		var axis: Vector3 = gh * (_fist[side][0] as Vector3)
		var want := down if axis.dot(down) >= 0.0 else -down
		var gh2: Basis = Body._from_to(axis.normalized(), want) * gh
		skeleton.set_bone_pose_rotation(int(a[2]), (gf.inverse() * gh2).get_rotation_quaternion())
		_grip_off[side] = gh2.orthonormalized() * (_fist[side][1] as Vector3)


## How far down the shaft (from the grip's end at grip, along down) a hand at shoulder holds it: want, or the nearest
## the arm can reach (within reach of the shoulder), never above at_least.
static func _on_shaft(shoulder: Vector3, grip: Vector3, down: Vector3, want: float, reach: float, at_least: float) -> float:
	var w := grip - shoulder
	var bq := w.dot(down)
	var disc := bq * bq - (w.length_squared() - reach * reach)
	if disc < 0.0:
		return maxf(at_least, -bq)   # nowhere in reach: the nearest point
	var r := sqrt(disc)
	return maxf(at_least, clampf(want, -bq - r, -bq + r))


## Two-bone IK on the model's arm: the hand to target (the model's skeleton space), the elbow out and down.
func _reach(side: String, target: Vector3, g: Dictionary, pos: Dictionary) -> Array:
	var a: Array = _arm[side]
	var ai: int = a[0]
	var fi: int = a[1]
	var hi: int = a[2]
	var l1: float = a[3]
	var l2: float = a[4]
	var sh: Vector3 = pos[ai]
	# Out of the arm's reach: the shoulder (the collarbone) swings toward the stick first, up to 35 degrees, as a
	# player's does when he reaches down his shaft.
	var clav: int = skeleton.get_bone_parent(ai)
	if (target - sh).length() > (l1 + l2) * 0.98 and clav >= 0 and g.has(clav) and pos.has(clav):
		var cp: Vector3 = pos[clav]
		var from_v := sh - cp
		var to_v := target - cp
		var ang := minf(from_v.angle_to(to_v), deg_to_rad(35.0))
		var axis := from_v.cross(to_v)
		if axis.length() > 0.0001 and ang > 0.001:
			var rot := Basis(axis.normalized(), ang)
			var gc2: Basis = rot * (g[clav] as Basis)
			var cpar := skeleton.get_bone_parent(clav)
			var gcp: Basis = g[cpar] if g.has(cpar) else Basis.IDENTITY
			skeleton.set_bone_pose_rotation(clav, (gcp.inverse() * gc2).get_rotation_quaternion())
			g[clav] = gc2
			g[ai] = rot * (g[ai] as Basis)
			g[fi] = rot * (g[fi] as Basis)
			g[hi] = rot * (g[hi] as Basis)
			sh = cp + rot * from_v
			pos[ai] = sh
	var to := target - sh
	var d := clampf(to.length(), (l1 + l2) * 0.15, l1 + l2 - 0.01)
	var dir := to.normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var ang := acos(cos_a)
	var pole := Vector3(0.6 if side == "l" else -0.6, -0.6, -0.2).normalized()
	var bend := (pole - dir * pole.dot(dir)).normalized()
	if bend.length() < 0.01:
		bend = Vector3.DOWN
	var elbow := sh + (dir * cos(ang) + bend * sin(ang)) * l1
	var hand := sh + dir * d
	var parent: int = skeleton.get_bone_parent(ai)
	var gp: Basis = g[parent]
	var ga: Basis = g[ai]
	var ga2: Basis = Body._from_to(ga.y.normalized(), (elbow - sh).normalized()) * ga
	skeleton.set_bone_pose_rotation(ai, (gp.inverse() * ga2).get_rotation_quaternion())
	var gf: Basis = ga2 * (ga.inverse() * (g[fi] as Basis))
	var gf2: Basis = Body._from_to(gf.y.normalized(), (hand - elbow).normalized()) * gf
	skeleton.set_bone_pose_rotation(fi, (ga2.inverse() * gf2).get_rotation_quaternion())
	var gh: Basis = gf2 * (gf.inverse() * (g[hi] as Basis))
	skeleton.set_bone_pose_rotation(hi, (gf2.inverse() * gh).get_rotation_quaternion())
	return [gf2, gh]
