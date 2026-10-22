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
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 jersey_col : source_color = vec3(0.1, 0.25, 0.65);
uniform vec3 shorts_col : source_color = vec3(0.1, 0.25, 0.65);
uniform vec3 socks_col : source_color = vec3(0.1, 0.25, 0.65);
uniform vec3 trim_col : source_color = vec3(0.6, 0.85, 0.95);
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
	ALBEDO = c;
	float cloth = clamp(main + trim + legs, 0.0, 1.0);
	ROUGHNESS = mix(0.55, 0.85, cloth);
	SPECULAR = mix(0.4, 0.25, cloth);
	RIM = 0.25;
	RIM_TINT = 0.5;
}
"""

static var _scenes := {}     # file -> PackedScene
static var _textures := {}   # file -> Texture2D
static var _shader: Shader
static var _stick_mesh: Mesh
static var _stick_mat: Material
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
	var tex_file := file.replace("_low", "").replace("_mid", "")
	if not _textures.has(tex_file):
		_textures[tex_file] = load(DIR + tex_file + ".jpg")
	material.set_shader_parameter("albedo_tex", _textures[tex_file])
	mesh.material_override = material
	recolour(look)
	if String(look.get("kind", "player")) == "player":
		_make_stick()
	elif String(look.get("kind", "")) == "keeper":
		_make_helmet(look)


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
	material.set_shader_parameter("jersey_col", look.get("jersey", Color.BLUE))
	material.set_shader_parameter("shorts_col", look.get("shorts", Color.BLUE))
	material.set_shader_parameter("socks_col", look.get("socks", Color.BLUE))
	material.set_shader_parameter("trim_col", look.get("trim", Color.WHITE))
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
uniform vec3 shell : source_color = vec3(0.1);
uniform vec3 fwd = vec3(0.0, 0.0, 1.0);
varying vec3 n;
void vertex() { n = NORMAL; }
void fragment() {
	float face = dot(normalize(n), normalize(fwd));
	if (face > 0.25) {
		// The cage: thin bars across and down the face, the face seen through them.
		vec2 g = fract(vec2(UV.x * 44.0, UV.y * 20.0));
		if (g.x > 0.22 && g.y > 0.25) discard;
		ALBEDO = vec3(0.82);
		METALLIC = 0.6;
		ROUGHNESS = 0.35;
	} else {
		ALBEDO = shell;
		ROUGHNESS = 0.4;
	}
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var jersey: Color = look.get("jersey", Color(0.1, 0.1, 0.1))
	m.set_shader_parameter("shell", jersey.lightened(0.15))
	m.set_shader_parameter("fwd", (hr.basis.inverse() * (face - hr.origin)).normalized())
	mi.material_override = m
	mi.cast_shadow = mesh.cast_shadow
	att.add_child(mi)


func _make_stick() -> void:
	if _stick_mesh == null:
		_stick_mesh = load(DIR + "stick.res")
		var m := StandardMaterial3D.new()
		m.albedo_texture = load(DIR + "stick.jpg")
		m.roughness = 0.45
		_stick_mat = m
		_stick_fix = _fit_stick(_stick_mesh)
	stick = MeshInstance3D.new()
	stick.mesh = _stick_mesh
	stick.material_override = _stick_mat
	stick.cast_shadow = mesh.cast_shadow
	add_child(stick)


## The stick model as the game holds its stick: the grip's end at the origin, the shaft down -Y, the blade toward +Z,
## its length the game's (Body.STICK_LEN from the grip to the blade's heel, ~1 m in all).
static func _fit_stick(m: Mesh) -> Transform3D:
	var vs: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var top := -INF
	var bottom := INF
	for v in vs:
		top = maxf(top, v.y)
		bottom = minf(bottom, v.y)
	var len := top - bottom
	var grip := Vector3.ZERO
	var toe := Vector3.ZERO
	var ng := 0
	var nt := 0
	for v in vs:
		if v.y > top - len * 0.05:
			grip += v
			ng += 1
		elif v.y < bottom + len * 0.06:
			toe += v
			nt += 1
	grip /= maxf(1, ng)
	toe /= maxf(1, nt)
	var blade := Vector2(toe.x - grip.x, toe.z - grip.z)
	var turn := Basis(Vector3.UP, atan2(blade.x, blade.y))   # the blade's way round to +Z
	var s := (Body.STICK_LEN + 0.05) / len
	var b := Basis.from_scale(Vector3.ONE * s) * turn.inverse()
	return Transform3D(b, -(b * Vector3(grip.x, top, grip.z)))


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
		var reach: float = (float(a[3]) + float(a[4])) * 0.97
		var t := _on_shaft(pos[a[0]], grip, down, float(hands[side]) * inv_k, reach, top_t)
		top_t = t + 0.12 * inv_k
		_reach(side, grip + down * t, g, pos)


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
func _reach(side: String, target: Vector3, g: Dictionary, pos: Dictionary) -> void:
	var a: Array = _arm[side]
	var ai: int = a[0]
	var fi: int = a[1]
	var hi: int = a[2]
	var l1: float = a[3]
	var l2: float = a[4]
	var sh: Vector3 = pos[ai]
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
