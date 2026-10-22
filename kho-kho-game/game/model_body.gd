class_name ModelBody
extends Node3D
## A player (or an official) as the owner's model: assets/models/player.glb, light copies of a high-detail athlete
## made by tools/models/build_player.py, on its Mixamo skeleton, moved by the owner's Mixamo animations baked onto it
## by tools/models/retarget.gd (assets/models/anims/). One AnimationPlayer each, so the blending is the engine's.
##
## His kit is the model's own, recoloured in the shader: the light blue of the shirt becomes the side's shirt, the
## navy of the shorts and trim the side's second colour; his skin takes his own tone; white and his hair stay.
## Low graphics draw the lighter of the two meshes (1,400 triangles against 3,600) with a 512 px texture.
##
## Local space: he faces +Z, soles at y = 0; height from look.height (the model stands 1.75 m).

const CLIPS := ["run", "walk", "stand", "dive", "reach", "turn", "kneel_down", "kneel", "whistle", "signal_out",
	"signal_foul", "signal_end", "cheer"]
const MODEL_HEIGHT := 1.75

static var _scene: PackedScene
static var _lib: AnimationLibrary
static var _mats := {}       # look key -> ShaderMaterial
static var _shader: Shader
static var _speed := {}      # clip -> its speed over the ground at a playback rate of 1 (m/s)

var look := {}
var low := false
var anim: AnimationPlayer
var skeleton: Skeleton3D
var clip := ""
var _turner: HeadTurn
var head_yaw := 0.0          # degrees, + to his left: the head and neck turn to follow the play


func _init(p_look := {}, p_low := false) -> void:
	look = p_look
	low = p_low


## Loads the model and the clips (the loading screen does it, so the first match does not stall on it).
static func warm() -> void:
	_load()
	_texture(false)
	_texture(true)


static func _load() -> void:
	if _scene != null:
		return
	_scene = load("res://assets/models/player.glb")
	_lib = AnimationLibrary.new()
	for c in CLIPS:
		var a: Animation = load("res://assets/models/anims/%s.res" % c)
		_lib.add_animation(c, a)
		_speed[c] = float(a.get_meta("speed", 0.0)) if a.has_meta("speed") else 0.0


func _ready() -> void:
	_load()
	var m: Node3D = _scene.instantiate()
	add_child(m)
	var h := float(look.get("height", MODEL_HEIGHT))
	scale = Vector3.ONE * clampf(h / MODEL_HEIGHT, 0.85, 1.15)
	skeleton = m.find_children("*", "Skeleton3D", true, false)[0]
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var keep := (mi.name == "player_lod1") == low
		if not keep:
			mi.queue_free()
			continue
		(mi as MeshInstance3D).material_override = material(look, low)
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for ap in m.find_children("*", "AnimationPlayer", true, false):
		ap.queue_free()   # the GLB's own clips: ours replace them
	anim = AnimationPlayer.new()
	m.add_child(anim)   # its root (..) is the model's root, where the clips' tracks start
	anim.add_animation_library("", _lib)
	_turner = HeadTurn.new()
	_turner.body = self
	skeleton.add_child(_turner)
	play("stand")


## Plays a clip: blended in over blend seconds, at rate (negative: backwards), from at seconds (-1: its start). The
## same clip again only changes its rate.
func play(c: String, rate := 1.0, blend := 0.18, at := -1.0) -> void:
	if c != clip:
		clip = c
		anim.play(c, blend, -1.0 if rate < 0.0 else 1.0, rate < 0.0)
		if at >= 0.0:
			anim.seek(at, true)
	anim.speed_scale = absf(rate)


## The playback rate that makes a moving clip's stride keep up with the ground at spd m/s.
static func rate_for(c: String, spd: float) -> float:
	var s: float = _speed.get(c, 0.0)
	return clampf(spd / s, 0.5, 1.9) if s > 0.1 else 1.0


func clip_length(c: String) -> float:
	return _lib.get_animation(c).length if _lib.has_animation(c) else 1.0


## After the animation has posed him: the head and neck turned toward what he watches (a skeleton modifier, so it
## runs after the AnimationPlayer every frame).
class HeadTurn extends SkeletonModifier3D:
	var body
	var _neck := -1
	var _head := -1

	func _process_modification_with_delta(_delta: float) -> void:
		var sk := get_skeleton()
		if sk == null or body == null or absf(body.head_yaw) < 0.5:
			return
		if _neck < 0:
			_neck = sk.find_bone("mixamorig_Neck")
			_head = sk.find_bone("mixamorig_Head")
		var share := 0.4
		for b in [_neck, _head]:
			# The turn is about the world's up: put it into the frame of the bone's parent.
			var gp := sk.get_bone_global_pose(sk.get_bone_parent(b)).basis.orthonormalized()
			var turn := Basis(Vector3.UP, deg_to_rad(body.head_yaw * share))
			var local := Quaternion((gp.inverse() * turn * gp).orthonormalized())
			sk.set_bone_pose_rotation(b, local * sk.get_bone_pose_rotation(b))
			share = 0.6


static func material(lk: Dictionary, p_low: bool) -> ShaderMaterial:
	var skin: Color = lk.get("skin", Color("a86b45"))
	var shirt: Color = lk.get("jersey", Color("2a6fdb"))
	var shorts: Color = lk.get("shorts", Color("1b2a5c"))
	var key := "%s|%s|%s|%s" % [skin.to_html(false), shirt.to_html(false), shorts.to_html(false), p_low]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	_load()
	var tex := _texture(p_low)
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("shirt", shirt)
	m.set_shader_parameter("shorts", shorts)
	m.set_shader_parameter("skin", skin)
	_mats[key] = m
	return m


static var _tex := {}


static func _texture(p_low: bool) -> Texture2D:
	if _tex.has(p_low):
		return _tex[p_low]
	var m: Node = _scene.instantiate()
	var t: Texture2D = null
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		if (mi.name == "player_lod1") == p_low:
			var mat := (mi as MeshInstance3D).mesh.surface_get_material(0)
			if mat is BaseMaterial3D:
				t = (mat as BaseMaterial3D).albedo_texture
	m.free()
	_tex[p_low] = t
	return t


const SHADER := """
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 shirt : source_color;
uniform vec3 shorts : source_color;
uniform vec3 skin : source_color;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	vec3 s = pow(t, vec3(1.0 / 2.2));   // back to the painted (sRGB) values to read the colours
	vec3 hsv = rgb2hsv(s);
	// The kit is blue: light blue the shirt, navy the shorts and trim.
	float blue = smoothstep(0.47, 0.52, hsv.x) * (1.0 - smoothstep(0.70, 0.75, hsv.x)) * smoothstep(0.15, 0.25, hsv.y);
	float navy = smoothstep(0.55, 0.7, hsv.y) * (1.0 - smoothstep(0.5, 0.62, hsv.z));
	vec3 kit_shirt = shirt * clamp(hsv.z / 0.77, 0.3, 1.25);
	vec3 kit_shorts = shorts * clamp(hsv.z / 0.37, 0.3, 1.6);
	vec3 kit = mix(kit_shirt, kit_shorts, navy);
	// His skin: the painted tone (orange, middling saturation) moved to his own.
	float sk = (1.0 - smoothstep(0.1, 0.14, hsv.x)) * smoothstep(0.25, 0.35, hsv.y) * smoothstep(0.25, 0.4, hsv.z);
	vec3 skin_c = skin * clamp(hsv.z / 0.735, 0.4, 1.3);
	// The painted texture is dim (its brightest white is 0.77): lift what keeps its paint; the kit and skin take
	// their colours as given.
	vec3 c = mix(t * 1.3, kit, blue);
	c = mix(c, skin_c, sk * (1.0 - blue));
	ALBEDO = c;
	ROUGHNESS = 0.85;
}
"""
