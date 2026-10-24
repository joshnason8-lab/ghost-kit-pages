class_name RiggedBody
extends Node3D
## A realistic body made with Meshy (assets/people/, prepared by tools/meshy/prepare.gd): three ulama players (lean,
## tall, stocky) and a judge. The game still poses its own skeleton (Body: the stance, the recorded run, the hip
## strike, the dive, the serve's toss, the judges' calls); this body follows it every frame, bone by bone. The gear
## that tells the sides apart (the faja in the team's colour, the chimali, the classic court's yoke and knee pad, a
## judge's straw hat) stays the game's own, drawn on its skeleton over this body.
##
## How a bone follows (as in the floorball game): at rest the game's limbs hang straight down and its trunk stands
## straight up, where the model's arms are spread (an A-pose). So each of the model's bones is first turned, once, to
## point as the game's does at rest (K); after that it turns as the game's bone turns: its model-space rotation is the
## game bone's rotation times K. Feet, hands' twist, the head and the shoulders keep the model's own rest.

const DIR := "res://assets/people/"
## The bodies: file, who wears it ("player" or "judge"), how heavily built (0-1, Body's look.build).
const BODIES := [["player_lean", "player", 0.2], ["player_tall", "player", 0.5], ["player_stocky", "player", 0.9],
	["judge_cap", "judge", 0.5]]
## model bone -> [the game's bone it follows, how its rest is turned: "down" a hanging limb, "up" the trunk, "" kept]
const MAP := {
	"Hips": ["hips", ""],
	"Spine02": ["spine", "up"],
	"Spine01": ["spine", "up"],
	"Spine": ["chest", "up"],
	"neck": ["neck", "up"],
	"Head": ["head", ""],
	"LeftShoulder": ["chest", ""],
	"LeftArm": ["upperarm_l", "down"],
	"LeftForeArm": ["forearm_l", "down"],
	"LeftHand": ["hand_l", "down"],
	"RightShoulder": ["chest", ""],
	"RightArm": ["upperarm_r", "down"],
	"RightForeArm": ["forearm_r", "down"],
	"RightHand": ["hand_r", "down"],
	"LeftUpLeg": ["thigh_l", "down"],
	"LeftLeg": ["shin_l", "down"],
	"LeftFoot": ["foot_l", ""],
	"LeftToeBase": ["foot_l", ""],
	"RightUpLeg": ["thigh_r", "down"],
	"RightLeg": ["shin_r", "down"],
	"RightFoot": ["foot_r", ""],
	"RightToeBase": ["foot_r", ""],
}
const SHADER := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 skin_ratio = vec3(1.0);
uniform float rim = 0.4;
varying float h;                 // standing height, 0 soles .. 1 crown (prepare.gd)
void vertex() {
	h = COLOR.r;
}
void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	// Skin is warm (red over green over blue) and not dark leather; the shorts' band of height keeps its own colour.
	float warm = step(t.b * 1.05, t.g) * step(t.g, t.r) * smoothstep(0.1, 0.22, t.r - t.b);
	float shorts = step(0.38, h) * step(h, 0.58);
	float skin = warm * (1.0 - shorts * 0.85);
	ALBEDO = mix(t, t * skin_ratio, clamp(skin, 0.0, 1.0));
	ROUGHNESS = mix(0.8, 0.55, skin);
	SPECULAR = mix(0.25, 0.4, skin);
	RIM = rim;
	RIM_TINT = 0.5;
}
"""

static var _scenes := {}     # file -> PackedScene
static var _textures := {}   # file -> Texture2D
static var _shader: Shader

var character: Node3D
var skeleton: Skeleton3D
var mesh: MeshInstance3D
var material: ShaderMaterial
var file := ""
var _k := 0.01               # the model's skeleton units to the game's body's (m)
var _bones := []             # per model bone: [index, parent index, game bone index, K basis, rest position]
var _hips_rest := Vector3.ZERO
var _leg_ratio := 1.0


static func available(kind: String) -> bool:
	return not files_for(kind).is_empty()


## The bodies in the build for a kind of person: "ulama" and "classic" players wear the players', judges the judge's.
static func files_for(kind: String) -> Array:
	var who := "judge" if kind == "judge" else ("player" if kind in ["ulama", "classic"] else "")
	var out := []
	for b in BODIES:
		if String(b[1]) == who and ResourceLoader.exists(DIR + String(b[0]) + ".scn"):
			out.append(b)
	return out


## The body for a person: the one nearest his build, with a little of the seed so team-mates are not all alike.
static func pick(kind: String, build: float, seed_: int) -> String:
	var best := ""
	var best_score := INF
	for b in files_for(kind):
		var score := absf(float(b[2]) - build) + float(absi(hash(seed_ * 31 + String(b[0]).length())) % 100) / 100.0 * 0.35
		if score < best_score:
			best_score = score
			best = String(b[0])
	return best


## Builds the body (look: Body's) inside body, scaled to the game's 1.80 m skeleton.
func setup(body: Body, p_file: String, look: Dictionary) -> void:
	file = p_file
	var gfx := int(Game.settings.graphics)
	var f := file + ("_low" if gfx <= Game.GFX_LOW else ("_mid" if gfx == Game.GFX_MEDIUM else ""))
	if not ResourceLoader.exists(DIR + f + ".scn"):
		f = file
	if not _scenes.has(f):
		_scenes[f] = load(DIR + f + ".scn")
	character = (_scenes[f] as PackedScene).instantiate()
	add_child(character)
	skeleton = character.find_children("*", "Skeleton3D", true, false)[0]
	mesh = character.find_children("*", "MeshInstance3D", true, false)[0]
	# The model's size: soles to crown as the game's 1.80 m body (Body scales that to the player's height).
	var aabb := mesh.get_aabb()
	var s := 1.8 / maxf(0.5, aabb.size.y)
	character.scale = Vector3.ONE * s
	var to_body := _chain(skeleton)
	_k = to_body.basis.get_scale().x
	_prepare(body)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	material = ShaderMaterial.new()
	material.shader = _shader
	# Low: the 1024 texture as before. Medium and High: Meshy's own 2048, VRAM-compressed with mipmaps.
	var tex := file + ("_2k" if gfx >= Game.GFX_MEDIUM and ResourceLoader.exists(DIR + file + "_2k.jpg") else "")
	if not _textures.has(tex):
		_textures[tex] = load(DIR + tex + ".jpg")
	material.set_shader_parameter("albedo_tex", _textures[tex])
	material.set_shader_parameter("rim", 0.4 if gfx >= Game.GFX_MEDIUM else 0.0)
	# The texture's skin as a middle tone; a darker or lighter player's in proportion, in linear light.
	var ref := Color("a8754f").srgb_to_linear()
	var sk: Color = (look.get("skin", Color("a8754f")) as Color).srgb_to_linear()
	material.set_shader_parameter("skin_ratio", Vector3(sk.r / ref.r, sk.g / ref.g, sk.b / ref.b) if String(look.get("kind", "")) != "judge" else Vector3.ONE)
	mesh.material_override = material


## The model's skeleton relative to this node, before it is in the tree.
func _chain(n: Node3D) -> Transform3D:
	var xf := Transform3D()
	var p: Node = n
	while p != null and p != self:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## The shortest turn taking direction a to b.
static func from_to(a: Vector3, b: Vector3) -> Basis:
	var c := a.cross(b)
	var d := a.dot(b)
	if c.length() < 1e-6:
		return Basis.IDENTITY if d > 0.0 else Basis(Vector3.RIGHT if absf(a.x) < 0.9 else Vector3.FORWARD, PI)
	return Basis(c.normalized(), atan2(c.length(), d))


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
			k = from_to(r.y.normalized(), want) * r
		_bones.append([i, skeleton.get_bone_parent(i), body.bone(String(m[0])), k, skeleton.get_bone_rest(i).origin])
	var hips := skeleton.find_bone("Hips")
	_hips_rest = (rest_g[hips] as Transform3D).origin
	var foot := skeleton.find_bone("LeftFoot")
	# The model's legs against the game's (hips 0.95 m over the floor at rest, the ankles 0.04 m).
	_leg_ratio = ((rest_g[hips] as Transform3D).origin.y - (rest_g[foot] as Transform3D).origin.y) * _k / (0.95 - 0.04)


## Follows the game's skeleton (body has posed it this frame).
func follow(body: Body) -> void:
	var our := body.skeleton
	var g := {}   # model bone -> its model-space basis
	var inv_k := 1.0 / _k
	for e in _bones:
		var i: int = e[0]
		var parent: int = e[1]
		var gb: Basis = our.get_bone_global_pose(int(e[2])).basis * (e[3] as Basis)
		g[i] = gb
		var local: Basis = gb if parent < 0 or not g.has(parent) else (g[parent] as Basis).inverse() * gb
		skeleton.set_bone_pose_rotation(i, local.get_rotation_quaternion())
		if parent < 0:
			var hp: Vector3 = our.get_bone_global_pose(int(e[2])).origin
			skeleton.set_bone_pose_position(i, _hips_rest + (hp - Vector3(0, 0.95, 0)) * _leg_ratio * inv_k)
