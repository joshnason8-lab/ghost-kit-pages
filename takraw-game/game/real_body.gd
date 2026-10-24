class_name RealBody
extends Node3D
## A player (or an official): the man's or the woman's model, in his team's colours, posed each frame from the joint
## angles in a pose (Moves).
##
## The moves are written for a simple skeleton (BONES below: the player faces +Z, his left is +X, every bone at rest
## hangs straight down, or for the spine straight up, with no rotation), each bone's angles in degrees (x: pitch,
## y: twist, z: roll) or, for moves taken from motion capture, a Quaternion. A pose turns each of those bones from its
## rest; the model's bones (Mixamo's names) take the same turn from a rest of their own put the same way: arms and
## legs straight down, feet level, the back upright. So a pose looks the same on any body, whatever its proportions
## and whatever pose it was modelled in.
##
## Local space: the soles at y = 0, the player facing +Z.

const BONES := [
	# name, parent
	["hips", ""], ["spine", "hips"], ["chest", "spine"], ["neck", "chest"], ["head", "neck"],
	["upperarm_l", "chest"], ["forearm_l", "upperarm_l"], ["hand_l", "forearm_l"],
	["upperarm_r", "chest"], ["forearm_r", "upperarm_r"], ["hand_r", "forearm_r"],
	["thigh_l", "hips"], ["shin_l", "thigh_l"], ["foot_l", "shin_l"],
	["thigh_r", "hips"], ["shin_r", "thigh_r"], ["foot_r", "shin_r"],
]

## The model's bones: which of the poses' bones each follows (two: halfway between them), and which way it points
## at rest (the bone it points to, and that direction in the rest it is put in), or the bone whose rest it shares.
const RIG := {
	"Hips": ["hips", "", "Spine", Vector3.UP],
	"Spine": ["spine", "", "Spine1", Vector3.UP],
	"Spine1": ["spine", "chest", "Spine2", Vector3.UP],
	"Spine2": ["chest", "", "Neck", Vector3.UP],
	"Neck": ["neck", "", "Head", Vector3.UP],
	"Head": ["head", "", "=Neck", Vector3.UP],
	"headfront": ["head", "", "=Neck", Vector3.UP],
	"LeftShoulder": ["chest", "", "LeftArm", Vector3.RIGHT],
	"LeftArm": ["upperarm_l", "", "LeftForeArm", Vector3.DOWN],
	"LeftForeArm": ["forearm_l", "", "LeftHand", Vector3.DOWN],
	"LeftHand": ["hand_l", "", "=LeftForeArm", Vector3.DOWN],
	"RightShoulder": ["chest", "", "RightArm", Vector3.LEFT],
	"RightArm": ["upperarm_r", "", "RightForeArm", Vector3.DOWN],
	"RightForeArm": ["forearm_r", "", "RightHand", Vector3.DOWN],
	"RightHand": ["hand_r", "", "=RightForeArm", Vector3.DOWN],
	"LeftUpLeg": ["thigh_l", "", "LeftLeg", Vector3.DOWN],
	"LeftLeg": ["shin_l", "", "LeftFoot", Vector3.DOWN],
	"LeftFoot": ["foot_l", "", "LeftToeBase", FOOT],
	"LeftToeBase": ["foot_l", "", "=LeftFoot", Vector3.BACK],
	"RightUpLeg": ["thigh_r", "", "RightLeg", Vector3.DOWN],
	"RightLeg": ["shin_r", "", "RightFoot", Vector3.DOWN],
	"RightFoot": ["foot_r", "", "RightToeBase", FOOT],
	"RightToeBase": ["foot_r", "", "=RightFoot", Vector3.BACK],
}
## A foot at rest, flat on the floor: its toe joint ahead of the ankle and as far below it.
const FOOT := Vector3(0, -0.7071, 0.7071)
## A foot is on the floor while the middle of it (Rig.sole) is lower than this (m).
const SOLE_DOWN := 0.13
const MODELS := {false: "res://assets/models/man.glb", true: "res://assets/models/woman.glb"}
const SKINS := {false: "res://assets/models/man.jpg", true: "res://assets/models/woman.jpg"}
const KITS := {false: "res://assets/models/man_kit.png", true: "res://assets/models/woman_kit.png"}
## The models' own colours, that the kit and skin are painted over (sRGB): the shirt, the panels and shorts, skin.
const MODEL_SHIRT := Color("7cc4dd")
const MODEL_NAVY := Color("123a7a")
const MODEL_SKIN := Color("d9a283")

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var look := {}          # jersey, shorts, skin (Colors), height (m), women (bool)
var pose := {}          # bone name -> Vector3 degrees or Quaternion; plus "hips_y", "hips_fwd", "hips_side" (m)
var women := false
var _rig: Rig

static var _rigs := {}
static var _shader: Shader
static var _mats := {}  # look key -> ShaderMaterial (players in the same kit share one)


func _init(p_look := {}) -> void:
	look = p_look
	women = bool(look.get("women", false))


func _ready() -> void:
	_rig = rig(women)
	var scene: Node3D = _rig.scene.instantiate()
	add_child(scene)
	skeleton = scene.find_children("*", "Skeleton3D", true, false)[0]
	mesh_instance = skeleton.find_children("*", "MeshInstance3D", true, false)[0]
	for ap in scene.find_children("*", "AnimationPlayer", true, false):
		ap.queue_free()   # posed from code; its clips are read by Moves
	scale = Vector3.ONE * (float(look.get("height", 1.76 if not women else 1.66)) / _rig.height)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.material_override = material_for(look)
	if pose.is_empty():
		apply(Moves.READY)
	else:
		apply(pose)


## The model, its bones and their rests, read once for all the players who share it.
static func rig(w: bool) -> Rig:
	if not _rigs.has(w):
		_rigs[w] = Rig.new(load(MODELS[w]))
	return _rigs[w]


## Loads both models and makes the shader before a match (the loading screen), so the first frame does not stall.
static func warm() -> void:
	for w in [false, true]:
		rig(w)
	material_for({})


## The material for a kit: the model's texture with its shirt, panels and shorts painted in the team's colours (the
## folds and shading kept) and the skin in the player's tone.
static func material_for(l: Dictionary) -> ShaderMaterial:
	var w := bool(l.get("women", false))
	var jersey: Color = l.get("jersey", MODEL_SHIRT)
	var shorts: Color = l.get("shorts", MODEL_NAVY)
	var skin: Color = l.get("skin", MODEL_SKIN)
	var key := "%s|%s|%s|%s" % [w, jersey.to_html(), shorts.to_html(), skin.to_html()]
	if _mats.has(key):
		return _mats[key]
	if _mats.size() > 64:
		_mats.clear()   # the last few matches' kits; the players holding them keep theirs
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D kit_tex : filter_linear_mipmap, repeat_disable;
uniform vec3 shirt : source_color;
uniform vec3 navy : source_color;
uniform vec3 skin : source_color;
uniform vec3 ref_shirt : source_color;
uniform vec3 ref_navy : source_color;
uniform vec3 ref_skin : source_color;
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	vec3 k = texture(kit_tex, UV).rgb;
	// Cloth: the team's colour, as light or dark as the cloth is there against the model's own colour.
	vec3 a = shirt * clamp(lum(c) / lum(ref_shirt), 0.0, 1.6);
	vec3 b = navy * clamp(lum(c) / lum(ref_navy), 0.0, 2.2);
	c = mix(c, a, k.r);
	c = mix(c, b, k.g);
	c = mix(c, c * skin / ref_skin, k.b);
	ALBEDO = c;
	ROUGHNESS = mix(0.82, 0.6, k.b);
	SPECULAR = 0.35;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("albedo_tex", load(SKINS[w]))
	m.set_shader_parameter("kit_tex", load(KITS[w]))
	m.set_shader_parameter("shirt", jersey)
	m.set_shader_parameter("navy", shorts)
	m.set_shader_parameter("skin", skin)
	m.set_shader_parameter("ref_shirt", MODEL_SHIRT)
	m.set_shader_parameter("ref_navy", MODEL_NAVY)
	m.set_shader_parameter("ref_skin", MODEL_SKIN)
	_mats[key] = m
	return m


func bone(name: String) -> int:
	for i in BONES.size():
		if BONES[i][0] == name:
			return i
	return -1


## Where a pose bone is now, in world space (a foot, the head).
func bone_world(name: String) -> Vector3:
	if skeleton == null:
		return global_position
	var m := {"hips": "Hips", "spine": "Spine", "chest": "Spine2", "neck": "Neck", "head": "Head",
		"upperarm_l": "LeftArm", "forearm_l": "LeftForeArm", "hand_l": "LeftHand", "upperarm_r": "RightArm",
		"forearm_r": "RightForeArm", "hand_r": "RightHand", "thigh_l": "LeftUpLeg", "shin_l": "LeftLeg",
		"foot_l": "LeftFoot", "thigh_r": "RightUpLeg", "shin_r": "RightLeg", "foot_r": "RightFoot"}
	var i := int(_rig.index.get(m.get(name, ""), -1))
	if i < 0:
		return global_position
	return skeleton.global_transform * skeleton.get_bone_global_pose(i).origin


## A pose bone's rotation from its parent: degrees (Vector3, pitch-twist-roll) or a Quaternion.
static func local_rot(v) -> Quaternion:
	if v is Quaternion:
		return v
	var e: Vector3 = v if v is Vector3 else Vector3.ZERO
	return Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)), EULER_ORDER_YXZ).get_rotation_quaternion()


## Puts the model in the pose.
func apply(p: Dictionary) -> void:
	pose = p
	if skeleton == null:
		return
	var r := _rig
	r.solve(p)
	for b in r.count:
		skeleton.set_bone_pose_rotation(b, r.out_local[b])
	skeleton.set_bone_pose_position(r.hips, r.out_hips)


## One model's skeleton, read once: which pose bone each of its bones follows, and each bone's rest put the way the
## poses' bones rest (so a pose bone's turn can be laid straight onto it).
class Rig:
	var scene: PackedScene
	var count := 0
	var index := {}           # short name ("LeftArm") -> bone
	var parent := []          # bone -> its parent bone, or -1
	var follow := []          # bone -> the pose bone it follows (-1: none, stays at rest)
	var follow2 := []         # bone -> a second pose bone, followed halfway (-1: none)
	var rest_global := []     # bone -> its rest rotation (skeleton space)
	var rest_put := []        # bone -> that rest turned to lie the way the pose bones rest
	var pose_parent := []     # pose bone -> its parent pose bone
	var hips := 0
	var hips_rest := Vector3.ZERO
	var unit := 0.01          # metres in a skeleton unit
	var height := 1.75        # the model's standing height (m)
	var rest_origin := []     # bone -> its place on its parent at rest (skeleton units)
	var feet := []            # LeftFoot, LeftToeBase, RightFoot, RightToeBase
	var feet_rest := []       # their heights standing straight (skeleton units)
	# What solve() leaves: each bone's rotation on its parent, the hips' place, and every bone's place (m, the body's
	# own space, the soles on y = 0 when he stands).
	var out_local := []
	var out_hips := Vector3.ZERO
	var out_pos := []
	var _q := []
	var _glob := []

	func _init(p_scene: PackedScene) -> void:
		scene = p_scene
		var root: Node3D = scene.instantiate()
		var sk: Skeleton3D = root.find_children("*", "Skeleton3D", true, false)[0]
		# The skeleton's scale (the models are in centimetres under a node scaled 0.01).
		var xf := Transform3D.IDENTITY
		var n: Node = sk
		while n != null and n != root:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		unit = xf.basis.get_scale().y
		count = sk.get_bone_count()
		var origin := []
		for b in count:
			var nm := String(sk.get_bone_name(b))
			index[nm.trim_prefix("mixamorig_").trim_prefix("mixamorig:")] = b
			parent.append(sk.get_bone_parent(b))
			var g := sk.get_bone_global_rest(b)
			rest_global.append(g.basis.orthonormalized())
			origin.append(g.origin)
			rest_origin.append(sk.get_bone_rest(b).origin)
		# Its height: the mesh's, standing as modelled (a skinned mesh's vertices are where its skin puts them at rest,
		# in the model's own space, whatever the nodes above it).
		var mi: MeshInstance3D = root.find_children("*", "MeshInstance3D", true, false)[0]
		height = mi.mesh.get_aabb().size.y
		hips = int(index.get("Hips", 0))
		hips_rest = sk.get_bone_rest(hips).origin
		var pose_index := {}
		for i in BONES.size():
			pose_index[BONES[i][0]] = i
		for i in BONES.size():
			pose_parent.append(int(pose_index.get(BONES[i][1], -1)))
		# Each bone's rest put the poses' way: turned the shortest way so it points where its pose bone points at rest.
		var turn := {}
		for b in count:
			var nm := String(sk.get_bone_name(b)).trim_prefix("mixamorig_").trim_prefix("mixamorig:")
			var spec: Array = RIG.get(nm, [])
			if spec.is_empty():
				follow.append(-1)
				follow2.append(-1)
				rest_put.append(rest_global[b])
				continue
			follow.append(int(pose_index[spec[0]]))
			follow2.append(int(pose_index[spec[1]]) if spec[1] != "" else -1)
			var to: String = spec[2]
			var q := Quaternion.IDENTITY
			if to.begins_with("="):
				q = turn.get(to.substr(1), Quaternion.IDENTITY)
			elif index.has(to):
				var d := ((origin[index[to]] as Vector3) - (origin[b] as Vector3)).normalized()
				q = Quaternion(d, spec[3])
			turn[nm] = q
			rest_put.append(Basis(q) * (rest_global[b] as Basis))
		root.free()
		out_local.resize(count)
		out_pos.resize(count)
		_glob.resize(count)
		_q.resize(BONES.size())
		for nm in ["LeftFoot", "LeftToeBase", "RightFoot", "RightToeBase"]:
			feet.append(int(index.get(nm, 0)))
		# Standing straight (every pose bone at rest), where the feet are: the floor under them.
		feet_rest = [0.0, 0.0, 0.0, 0.0]
		solve({"plant": 0.0})
		for i in 4:
			feet_rest[i] = (out_pos[feet[i]] as Vector3).y / unit

	## The middle of a foot (between its ankle and its toe) after solve(), in the body's space: about 0.09 m up when
	## it stands on the floor, and counted on it below SOLE_DOWN.
	func sole(side: String) -> Vector3:
		return ((out_pos[index[side + "Foot"]] as Vector3) + (out_pos[index[side + "ToeBase"]] as Vector3)) * 0.5

	## Poses the skeleton (without a skeleton node: the results are left in out_local, out_hips and out_pos).
	## Unless the pose says otherwise ("plant" 0: a move from motion capture, already on the floor), the body is
	## lowered or raised so its lower foot stays on the floor: the moves were written for other legs than these.
	func solve(p: Dictionary) -> void:
		for i in BONES.size():
			var pp: int = pose_parent[i]
			var own := RealBody.local_rot(p.get(BONES[i][0], Vector3.ZERO))
			_q[i] = (_q[pp] as Quaternion) * own if pp >= 0 else own
		var off := Vector3(-float(p.get("hips_side", 0.0)), float(p.get("hips_y", 0.0)), float(p.get("hips_fwd", 0.0))) / unit
		for b in count:
			var f: int = follow[b]
			var g: Basis = rest_global[b]
			if f >= 0:
				var q: Quaternion = _q[f]
				if follow2[b] >= 0:
					q = q.slerp(_q[follow2[b]], 0.5)
				g = Basis(q) * (rest_put[b] as Basis)
			_glob[b] = g
			var par: int = parent[b]
			if par >= 0:
				out_local[b] = ((_glob[par] as Basis).inverse() * g).get_rotation_quaternion()
				out_pos[b] = (out_pos[par] as Vector3) + (_glob[par] as Basis) * (rest_origin[b] as Vector3)
			else:
				out_local[b] = g.get_rotation_quaternion()
				out_pos[b] = (rest_origin[b] as Vector3) + off
		out_hips = (rest_origin[hips] as Vector3) + off
		var plant := float(p.get("plant", 1.0))
		if plant > 0.0 and not feet_rest.is_empty():
			var low := INF
			var lowest_foot := INF
			for i in 4:
				var y := (out_pos[feet[i]] as Vector3).y
				low = minf(low, y - float(feet_rest[i]))
				lowest_foot = minf(lowest_foot, y)
			# Only while he is on his feet: not in the air, not upside down (a deep crouch, the hips a short way over
			# the feet, still is: the woman's legs are shorter).
			var w := plant * clampf(1.0 - float(p.get("y", 0.0)) / 0.15, 0.0, 1.0)
			w *= clampf((((out_pos[hips] as Vector3).y - lowest_foot) * unit - 0.08) / 0.15, 0.0, 1.0)
			var dy := clampf(-low, -0.2 / unit, 0.2 / unit) * w
			out_hips.y += dy
			for b in count:
				out_pos[b] = (out_pos[b] as Vector3) + Vector3(0, dy, 0)
		for b in count:
			out_pos[b] = (out_pos[b] as Vector3) * unit
