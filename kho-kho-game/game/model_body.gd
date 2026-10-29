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
	"signal_foul", "signal_end", "cheer", "seated", "clap", "dodge", "idle"]
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
var grip := Vector3.INF      # a point (world) both hands reach for and hold (the pole, in a pole turn), INF none
var grip_arms := 2           # 2 both arms (the pole), 1 his right only (a touch on the run)
var _low_bones := []
var _gripper: Grip
# The dive, made by hand over whatever the clip is doing (DivePose), as Kabaddi Raid's dive is: how much of it there
# is (0 the clip, 1 all of it), how far over he is (0 upright, PI/2 flat), how far up onto his hands and knees he has
# pushed (0 reaching, 1 on all fours) and how high his hips are (m, body space).
var dive := 0.0
var dive_pitch := 0.0
var dive_push := 0.0
var dive_h := 0.0
var dive_drawn := Vector2.INF   # as DivePose last drew him: (hips height, lowest point's height) in body space (m)


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
	var diver := DivePose.new()
	diver.body = self
	skeleton.add_child(diver)   # first: the head turn and the grip work on the pose it leaves
	_turner = HeadTurn.new()
	_turner.body = self
	skeleton.add_child(_turner)
	_gripper = Grip.new()
	_gripper.body = self
	skeleton.add_child(_gripper)
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


## The playback rate for a moving clip at spd m/s: up to the clip's own speed, the rate that keeps its stride with the
## ground. Faster than that, a runner lengthens his stride more than he quickens it, so the rate rises with the square
## root of the speed: the run (recorded at a 3.5 m/s jog) at 7 m/s is about 4 steps a second, as a fast runner's are,
## not the 5.4 that matching the ground would take (it looked like fast forward; Kabaddi Raid caps its run at 1.6).
static func rate_for(c: String, spd: float) -> float:
	var s: float = _speed.get(c, 0.0)
	if s <= 0.1:
		return 1.0
	var r := spd / s
	return clampf(sqrt(r) if r > 1.0 else r, 0.5, 1.6)


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


## How far forward the clip already leans his torso (radians, hips to head, 0 upright, + forward), in his own frame.
func torso_lean() -> float:
	if skeleton == null:
		return 0.0
	var hips := skeleton.find_bone("mixamorig_Hips")
	var head := skeleton.find_bone("mixamorig_Head")
	if hips < 0 or head < 0:
		return 0.0
	var to_body := global_transform.affine_inverse() * skeleton.global_transform
	var v := to_body * skeleton.get_bone_global_pose(head).origin - to_body * skeleton.get_bone_global_pose(hips).origin
	return atan2(v.z, v.y)


## The height of his lowest part above the ground (world y, relative to his feet's ground): his head, hands, chest,
## hips and knees, as last posed. A dive keeps it above the ground.
func lowest_point() -> float:
	if skeleton == null:
		return 0.0
	if _low_bones.is_empty():
		for n in ["Head", "HeadTop_End", "LeftHand", "RightHand", "Spine2", "Hips", "LeftLeg", "RightLeg", "LeftForeArm",
				"RightForeArm"]:
			var b := skeleton.find_bone("mixamorig_" + n)
			if b >= 0:
				_low_bones.append(b)
	var low := INF
	var xf := skeleton.global_transform
	for b in _low_bones:
		low = minf(low, (xf * skeleton.get_bone_global_pose(b).origin).y)
	var ground := (get_parent() as Node3D).global_position.y if get_parent() is Node3D else 0.0
	return low - ground - position.y if low != INF else 0.0


## After the animation: both arms out to a point and holding it (grip), the upper arm and forearm turned to point at
## it, so his hands are on the pole as he swings round it whatever the clip's arms are doing.
class Grip extends SkeletonModifier3D:
	var body
	var _bones := []   # [arm, forearm, hand] for each side

	func _process_modification_with_delta(_delta: float) -> void:
		var sk := get_skeleton()
		if sk == null or body == null or body.grip == Vector3.INF:
			return
		if _bones.is_empty():
			for side in ["Left", "Right"]:
				_bones.append([sk.find_bone("mixamorig_%sArm" % side), sk.find_bone("mixamorig_%sForeArm" % side),
					sk.find_bone("mixamorig_%sHand" % side)])
		var target: Vector3 = sk.global_transform.affine_inverse() * (body.grip as Vector3)
		for chain in (_bones if body.grip_arms == 2 else [_bones[1]]):
			for k in 2:
				var b: int = chain[k]
				var child: int = chain[k + 1]
				if b < 0 or child < 0:
					continue
				var gb := sk.get_bone_global_pose(b)
				var d := sk.get_bone_global_pose(child).origin - gb.origin
				var t := target - gb.origin
				if d.length() < 0.001 or t.length() < 0.001:
					continue
				var q := Quaternion(d.normalized(), t.normalized())
				var pg := sk.get_bone_global_pose(sk.get_bone_parent(b)).basis.orthonormalized()
				var nb := Basis(q) * gb.basis.orthonormalized()
				sk.set_bone_pose_rotation(b, Quaternion((pg.inverse() * nb).orthonormalized()))


## The dive, made by hand (the only recorded dive is a dive into water, which left him leaning on one leg in the air),
## as Kabaddi Raid's dive is: over whatever the clip is doing, by body.dive. His body tips over about his hips (not his
## feet), arms reaching out ahead and down to the ground, legs trailing, head up to see what he reaches for; pushing up
## (body.dive_push), his arms and thighs go down under him onto hands and knees. His hips are put at body.dive_h, then
## lifted by as much as anything (head, chest, hands, knees, feet) would go under the ground, in this frame's pose.
class DivePose extends SkeletonModifier3D:
	var body
	var _chain := []    # [bone, child] pairs, parents first
	var _hips := -1
	var _floor := {}    # bone -> how far above the ground it must stay (m: the body round the bone)

	func _process_modification_with_delta(_delta: float) -> void:
		var sk := get_skeleton()
		if sk == null or body == null or body.dive <= 0.001:
			if body != null:
				body.dive_drawn = Vector2.INF
			return
		if _chain.is_empty():
			_setup(sk)
		var w: float = clampf(body.dive, 0.0, 1.0)
		var p: float = body.dive_pitch
		var k: float = clampf(body.dive_push, 0.0, 1.0)
		# His long axis (hips to head) and his front, tipped over by p about his left-right axis.
		var up := Vector3(0.0, cos(p), sin(p))
		var front := Vector3(0.0, -sin(p), cos(p))
		var to_body: Transform3D = body.global_transform.affine_inverse() * sk.global_transform
		var to_sk := to_body.affine_inverse().basis
		var want := {
			"Hips": up, "Spine": up, "Spine1": up, "Spine2": (up - front * 0.15).normalized(),
			"Neck": (up - front * 0.35).normalized(), "Head": (up - front * 0.9).normalized(),
		}
		for s in [["Left", 1.0], ["Right", -1.0]]:
			var x := Vector3(s[1], 0.0, 0.0)
			# Reaching: out past his head, a little apart, angled down to the ground ahead. On all fours: straight down.
			var reach := (up * 0.95 + front * 0.28 + x * 0.12).normalized()
			var prop := (front + x * 0.08).normalized()
			want[s[0] + "Arm"] = reach.slerp(prop, k)
			want[s[0] + "ForeArm"] = reach.slerp(prop, k)
			# Legs trailing, the knees a little bent so the feet come off the ground behind; on all fours the thighs go
			# down under him and the shins lie back along the ground.
			var thigh := (-up + front * 0.06 + x * 0.07).normalized()
			want[s[0] + "UpLeg"] = thigh.slerp((front * 0.9 - up * 0.25 + x * 0.1).normalized(), k)
			want[s[0] + "Leg"] = (-up * 0.88 - front * 0.45).normalized().slerp(-up, k)
			want[s[0] + "Foot"] = (-up * 0.55 + front * 0.8).normalized()
		for pair in _chain:
			var b: int = pair[0]
			var t: Vector3 = to_sk * (want[pair[2]] as Vector3)
			var gb := sk.get_bone_global_pose(b)
			var d := sk.get_bone_global_pose(pair[1]).origin - gb.origin
			if d.length() < 0.0001:
				continue
			var q := Quaternion.IDENTITY.slerp(Quaternion(d.normalized(), t.normalized()), w)
			var parent := sk.get_bone_parent(b)
			var pg := sk.get_bone_global_pose(parent).basis.orthonormalized() if parent >= 0 else Basis()
			sk.set_bone_pose_rotation(b, Quaternion((pg.inverse() * (Basis(q) * gb.basis.orthonormalized())).orthonormalized()))
		# The hips: over his feet's point on the ground, at dive_h; then out of the ground if any part went into it.
		var hg := sk.get_bone_global_pose(_hips)
		var hb := to_body * hg.origin
		var goal := Vector3(lerpf(hb.x, 0.0, w), lerpf(hb.y, float(body.dive_h), w), lerpf(hb.z, 0.0, w))
		var under := 0.0
		for b in _floor:
			var y := (to_body * sk.get_bone_global_pose(b).origin).y - hb.y + goal.y
			under = maxf(under, float(_floor[b]) - y)
		goal.y += under
		var lowest := INF
		for b in _floor:
			lowest = minf(lowest, (to_body * sk.get_bone_global_pose(b).origin).y - hb.y + goal.y)
		body.dive_drawn = Vector2(goal.y, lowest)
		var move := to_sk * (goal - hb)
		var hp := sk.get_bone_parent(_hips)
		if hp >= 0:
			move = sk.get_bone_global_pose(hp).basis.orthonormalized().inverse() * move
		sk.set_bone_pose_position(_hips, sk.get_bone_pose_position(_hips) + move)

	func _setup(sk: Skeleton3D) -> void:
		_hips = sk.find_bone("mixamorig_Hips")
		var pairs := [["Hips", "Spine"], ["Spine", "Spine1"], ["Spine1", "Spine2"], ["Spine2", "Neck"], ["Neck", "Head"],
			["Head", "HeadTop_End"]]
		for s in ["Left", "Right"]:
			pairs += [[s + "Arm", s + "ForeArm"], [s + "ForeArm", s + "Hand"], [s + "UpLeg", s + "Leg"],
				[s + "Leg", s + "Foot"], [s + "Foot", s + "ToeBase"]]
		for pr in pairs:
			var b := sk.find_bone("mixamorig_" + pr[0])
			var c := sk.find_bone("mixamorig_" + pr[1])
			if b >= 0 and c >= 0:
				_chain.append([b, c, pr[0]])
		for n in [["Head", 0.11], ["HeadTop_End", 0.08], ["Spine2", 0.13], ["Spine1", 0.12], ["Hips", 0.1],
				["LeftHand", 0.03], ["RightHand", 0.03], ["LeftForeArm", 0.04], ["RightForeArm", 0.04], ["LeftLeg", 0.06],
				["RightLeg", 0.06], ["LeftFoot", 0.05], ["RightFoot", 0.05], ["LeftToeBase", 0.03], ["RightToeBase", 0.03]]:
			var b := sk.find_bone("mixamorig_" + n[0])
			if b >= 0:
				_floor[b] = n[1]


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


## The model's texture: the light mesh's own 512 px on Low; on Medium and High (the 3,600-triangle mesh) a 2048 px bake
## of the source's, VRAM-compressed (tools/models/bake_hd_texture.py), else the 1024 px the GLB carries.
const HD_TEXTURE := "res://assets/models/player_lod0_2k.png"


static func _texture(p_low: bool) -> Texture2D:
	if _tex.has(p_low):
		return _tex[p_low]
	if not p_low and ResourceLoader.exists(HD_TEXTURE):
		_tex[p_low] = load(HD_TEXTURE)
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
// Read raw (no source_color): the paint's sRGB values as stored, the same in every renderer; turned to linear here.
// Its alpha is the class tools/models/build_player.py baked: 0.25 shirt, 0.5 shorts and trim, 0.75 skin, 1 the rest.
uniform sampler2D albedo_tex : filter_linear_mipmap;
uniform vec3 shirt : source_color;
uniform vec3 shorts : source_color;
uniform vec3 skin : source_color;

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	float v = max(t.r, max(t.g, t.b));
	float cls = t.a;
	// The cloth's and the skin's shading: the painted brightness against each part's usual one.
	vec3 paint = pow(t.rgb, vec3(2.2)) * 1.6;   // the paint is dim (its whites are 0.77)
	vec3 kit_shirt = shirt * clamp(pow(v / 0.77, 2.2), 0.25, 1.4);
	vec3 kit_shorts = shorts * clamp(pow(v / 0.37, 2.2), 0.25, 1.8);
	vec3 skin_c = skin * clamp(pow(v / 0.735, 2.2), 0.3, 1.4);
	float w_shirt = 1.0 - smoothstep(0.32, 0.4, cls);
	float w_shorts = smoothstep(0.32, 0.4, cls) * (1.0 - smoothstep(0.58, 0.66, cls));
	float w_skin = smoothstep(0.58, 0.66, cls) * (1.0 - smoothstep(0.84, 0.92, cls));
	float w_paint = smoothstep(0.84, 0.92, cls);
	ALBEDO = kit_shirt * w_shirt + kit_shorts * w_shorts + skin_c * w_skin + paint * w_paint;
	ROUGHNESS = 0.85;
}
"""
