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
## On Medium and High: the models' own textures at 2048 px (and the kit's masks at 1024), compressed for the GPU.
const SKINS_HI := {false: "res://assets/models/man_2k.jpg", true: "res://assets/models/woman_2k.jpg"}
const KITS_HI := {false: "res://assets/models/man_kit_1k.png", true: "res://assets/models/woman_kit_1k.png"}
## The officials' suit over the man's model: the jacket and trousers (red), the white shirt (green), the tie (blue),
## the shoes (alpha); made by tools/models/suit_mask.gd.
const SUIT := "res://assets/models/man_suit.png"
## Which textures: by the graphics level (-1), or the 1024 px ones (0) or the 2048 (1) whatever it is (the crowd
## sheet's tool, rendering each sheet from the textures its level's players wear).
static var textures := -1
## The models' own colours, that the kit and skin are painted over (sRGB): the shirt, the panels and shorts, skin.
const MODEL_SHIRT := Color("7cc4dd")
const MODEL_NAVY := Color("123a7a")
const MODEL_SKIN := Color("d9a283")

var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var look := {}          # jersey, shorts, skin (Colors), height (m), women (bool)
var pose := {}          # bone name -> Vector3 degrees or Quaternion; plus "hips_y", "hips_fwd", "hips_side" (m)
var women := false
var link: FoundationLink = null   # the shared foundation drawing this body (Medium and High, in a match), else null
var _rig: Rig

static var _rigs := {}
static var _shader: Shader
static var _suit_shader: Shader
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


## Drawn with the shared foundation on Medium and High, in a match (FoundationLink): this body stays, posed and
## measured, unseen. kind: "player", "official" or "sub".
func link_foundation(kind: String) -> void:
	if link == null and skeleton and FoundationLink.enabled():
		add_child(FoundationLink.new(self, kind))


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
	material_for({"suit": Color("1b2030")})


## The material for a kit: the model's texture with its shirt, panels and shorts painted in the team's colours (the
## folds and shading kept) and the skin in the player's tone.
static func material_for(l: Dictionary) -> ShaderMaterial:
	if l.has("suit"):
		return _suit_material(l)
	var w := bool(l.get("women", false))
	var jersey: Color = l.get("jersey", MODEL_SHIRT)
	var shorts: Color = l.get("shorts", MODEL_NAVY)
	var skin: Color = l.get("skin", MODEL_SKIN)
	var hi := int(Game.settings.graphics) >= Game.GFX_MEDIUM if textures < 0 else textures == 1
	var key := "%s|%s|%s|%s|%s" % [w, jersey.to_html(), shorts.to_html(), skin.to_html(), hi]
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
	m.set_shader_parameter("albedo_tex", load((SKINS_HI if hi else SKINS)[w]))
	m.set_shader_parameter("kit_tex", load((KITS_HI if hi else KITS)[w]))
	m.set_shader_parameter("shirt", jersey)
	m.set_shader_parameter("navy", shorts)
	m.set_shader_parameter("skin", skin)
	m.set_shader_parameter("ref_shirt", MODEL_SHIRT)
	m.set_shader_parameter("ref_navy", MODEL_NAVY)
	m.set_shader_parameter("ref_skin", MODEL_SKIN)
	_mats[key] = m
	return m


## An official's: the man's model in a suit (look.suit, its cloth), a white shirt and a tie (look.tie), black shoes;
## his face, neck and hands his own, in his skin tone. The cloth keeps the folds and shading the model's texture has.
static func _suit_material(l: Dictionary) -> ShaderMaterial:
	var cloth: Color = l.suit
	var tie: Color = l.get("tie", Color("7a1c26"))
	var skin: Color = l.get("skin", MODEL_SKIN)
	var hi := int(Game.settings.graphics) >= Game.GFX_MEDIUM if textures < 0 else textures == 1
	var key := "suit|%s|%s|%s|%s" % [cloth.to_html(), tie.to_html(), skin.to_html(), hi]
	if _mats.has(key):
		return _mats[key]
	if _suit_shader == null:
		_suit_shader = Shader.new()
		_suit_shader.code = """
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D kit_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D suit_tex : filter_linear_mipmap, repeat_disable;
uniform vec3 cloth : source_color;
uniform vec3 tie : source_color;
uniform vec3 skin : source_color;
uniform vec3 ref_shirt : source_color;
uniform vec3 ref_navy : source_color;
uniform vec3 ref_skin : source_color;
float lum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	vec3 k = texture(kit_tex, UV).rgb;
	vec4 m = texture(suit_tex, UV);
	// The folds and shading the model's texture has here, against the colour it was painted (its kit or skin).
	float kw = k.r + k.g + k.b;
	float ref = (k.r * lum(ref_shirt) + k.g * lum(ref_navy) + k.b * lum(ref_skin)) / max(kw, 0.001);
	float fold = kw > 0.3 ? mix(1.0, clamp(lum(c) / ref, 0.6, 1.35), 0.55) : 1.0;
	c = mix(c, c * skin / ref_skin, k.b);
	// Where he is his own (his head, neck, hands), the kit's cloth left at the neckline is the shirt's collar.
	float own = 1.0 - clamp(m.r + m.g + m.b + m.a, 0.0, 1.0);
	c = mix(c, vec3(0.82) * fold, own * clamp(k.r + k.g, 0.0, 1.0));
	c = mix(c, cloth * fold, m.r);
	c = mix(c, vec3(0.82) * fold, m.g);
	c = mix(c, tie * fold, m.b);
	c = mix(c, vec3(0.025) * fold, m.a);
	ALBEDO = c;
	ROUGHNESS = mix(mix(0.82, 0.6, k.b), 0.72, clamp(m.r + m.g + m.b, 0.0, 1.0));
	ROUGHNESS = mix(ROUGHNESS, 0.32, m.a);
	SPECULAR = 0.35 + 0.2 * m.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _suit_shader
	m.set_shader_parameter("albedo_tex", load((SKINS_HI if hi else SKINS)[false]))
	m.set_shader_parameter("kit_tex", load((KITS_HI if hi else KITS)[false]))
	m.set_shader_parameter("suit_tex", load(SUIT))
	m.set_shader_parameter("cloth", cloth)
	m.set_shader_parameter("tie", tie)
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


## Where the hips are now (world).
func game_hips() -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_pose_position(_rig.hips) if skeleton else global_position


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


## His feet as drawn on Low: [left ankle, left toe, right ankle, right toe] (world), planted (RealBody._planted sets the
## pose itself: nothing changes it after). With a link (Medium and High) this is the game's pose under the drawn body.
func feet() -> Array:
	if _wp != null and _wp.active and not _drawn_feet.is_empty():
		return _drawn_feet   # (the shared planter plants them as the skeleton is drawn: read then)
	return _feet_now()


func _feet_now() -> Array:
	if skeleton == null:
		return []
	var out := []
	for n in ["LeftFoot", "LeftToeBase", "RightFoot", "RightToeBase"]:
		out.append(skeleton.global_transform * skeleton.get_bone_global_pose(int(_rig.index[n])).origin)
	return out


## A pose bone's rotation from its parent: degrees (Vector3, pitch-twist-roll) or a Quaternion.
static func local_rot(v) -> Quaternion:
	if v is Quaternion:
		return v
	var e: Vector3 = v if v is Vector3 else Vector3.ZERO
	return Basis.from_euler(Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)), EULER_ORDER_YXZ).get_rotation_quaternion()


## Puts the model in the pose. DT: the game's step (s) since the last, for the planted feet's steps.
func apply(p: Dictionary, dt := 1.0 / 30.0) -> void:
	if plant_feet and skeleton != null and link == null:
		if foundation_planter:
			_foundation_plant(p, dt)
		else:
			p = _planted(p, dt)
	if _wp != null:
		_wp.active = plant_feet and foundation_planter and link == null
	pose = p
	if skeleton == null:
		return
	var r := _rig
	r.solve(p)
	for b in r.count:
		skeleton.set_bone_pose_rotation(b, r.out_local[b])
	skeleton.set_bone_pose_position(r.hips, r.out_hips)


## A foot on the floor stays where it was put down (0.15.3; the owner: "players still gliding a lot"). While a foot is
## down, the pose's thigh, knee and foot are turned (two-bone IK on the rig) to keep it there as he moves and turns,
## until it lifts or he has gone PLANT_REACH past it (then he steps: the foot up and over to where his stride has it,
## over STEP_TIME, a foot at a time; 0.15.13 - it was put straight down there, a jump). The strides alone left
## the standing foot sliding, a stride captured in one place being no stride at another speed or turning. Low: the
## shared foundation's own planter places the feet of the bodies it draws (Medium and High).
func _planted(p: Dictionary, dt: float) -> Dictionary:
	var r := _rig
	if _my_cal.is_empty():
		_my_cal = _leg_cal(r)
	var cal := _my_cal
	var xf := global_transform
	var air := float(p.get("y", 0.0)) > 0.05   # (off the floor; a captured move's feet, plant 0, are on it where they are)
	dt = maxf(dt, 1.0 / 240.0)
	var at := global_position
	_went = Vector3.ZERO
	if _was_at != Vector3.INF and at.distance_to(_was_at) < 0.5:
		_went = Vector3((at.x - _was_at.x) / dt, 0.0, (at.z - _was_at.z) / dt)
	elif _was_at != Vector3.INF:
		_locks = [null, null]   # (put somewhere new - a restart, a substitution: his feet go with him)
		_step = [-1.0, -1.0]
	_was_at = at
	r.solve_legs(p)   # (the legs only: what this needs, a tenth of the bones)
	var solved_for := [p]
	var out := p
	for leg in 2:
		var fb: int = cal.foot[leg]
		if not is_same(out, solved_for[0]):
			r.solve_legs(out)
			solved_for[0] = out
		var a: Vector3 = r.out_pos[fb]
		# Down within PLANT_HEIGHT of where the ankle is standing, up again past twice that (a captured foot hovers a
		# little over the floor: no letting go and putting down again every frame).
		var down := not air and a.y < float(cal.ground[leg]) + PLANT_HEIGHT * (2.0 if _locks[leg] != null else 1.0)
		var w_now := xf * a
		if not down and not air and float(_step[leg]) >= 0.0:
			# (a step the stride lifts the foot in the middle of is finished, not dropped where it was: the foot then
			# came down and slid back along the floor to the stride's)
			down = true
		if not down:
			_locks[leg] = null
			_step[leg] = -1.0
			_ease[leg] = maxf(0.0, float(_ease[leg]) - PLANT_EASE)
			if float(_ease[leg]) <= 0.0 or _last_t[leg] == null:
				continue
			# (lifting: the correction let go over a few frames, not at once - and gone by the time the foot is
			# EASE_HIGH up: turned on a leg a move raises - a blocker's, a kicker's - the IK threw it about, 0.67 m in a
			# frame, the jitter test)
			var t0: Vector3 = _last_t[leg]
			var k := smoothstep(0.0, 1.0, float(_ease[leg])) * clampf(1.0 - (a.y - float(cal.ground[leg])) / EASE_HIGH, 0.0, 1.0)
			var te := a.lerp(Vector3(t0.x, a.y, t0.z), k)
			if (te - a).length() > IK_CLOSE:
				out = _leg_ik(out, leg, te, cal, r)
			continue
		if _locks[leg] == null:
			_locks[leg] = w_now
		var lock: Vector3 = _locks[leg]
		var t := xf.affine_inverse() * Vector3(lock.x, w_now.y, lock.z)
		var off := Vector2(t.x - a.x, t.z - a.z).length()
		if off > CUT:
			# (further than any step: the foot goes with him)
			_locks[leg] = w_now
			_step[leg] = -1.0
			t = a
			off = 0.0
		# (slowly - a blocker in his crouch edging along the net, a stance under a move whose legs stand still - he
		# shuffles: shorter steps, a foot at a time; held to a full reach, both feet went at once, a hop)
		var slow := _went.length() < SHUFFLE_SPEED
		var reach := SHUFFLE_REACH if slow else PLANT_REACH
		if float(_step[leg]) < 0.0 and (not slow or float(_step[1 - leg]) < 0.0) and off > reach:
			# (stretched as far as a leg goes: he steps, the foot up and over to where the stride has it - put straight
			# down there, it jumped 32-68 cm in a frame, 456 times in five minutes of a match: WsgNoteChecks jump_cm)
			_step[leg] = 0.0
			_step_from[leg] = lock
			_step_land[leg] = null
		if float(_step[leg]) >= 0.0:
			_step[leg] = minf(1.0, float(_step[leg]) + dt / STEP_TIME)
			var s: float = _step[leg]
			# (up before across and across before down, onto his stride's foot as it is then, and never further from
			# it than STEP_REACH, about the most the IK turns a leg well: aimed where the stride had it as the step
			# began, a runner's foot came down up to 0.9 m behind him, the leg thrown back to reach it - the jitter test)
			# Then down where it got to, not following the stride's foot down (that slid over the floor).
			var from: Vector3 = _step_from[leg]
			var w: Vector3
			if s < STEP_ACROSS:
				w = Vector3(w_now.x, 0.0, w_now.z) + Vector3(from.x - w_now.x, 0.0, from.z - w_now.z).limit_length(STEP_REACH) * (1.0 - smoothstep(0.25, STEP_ACROSS, s))
			else:
				if _step_land[leg] == null:
					_step_land[leg] = w_now
				var land: Vector3 = _step_land[leg]
				w = Vector3(w_now.x, 0.0, w_now.z) + Vector3(land.x - w_now.x, 0.0, land.z - w_now.z).limit_length(LAND_REACH)
			# (as high as the stride has it if that is higher: a stride lifting the foot behind him is not held down)
			w.y = maxf(w_now.y, float(cal.ground[leg]) * xf.basis.get_scale().y + global_position.y + STEP_LIFT * sin(PI * s))
			t = xf.affine_inverse() * w
			if s >= 1.0:
				_step[leg] = -1.0
				_locks[leg] = Vector3(w.x, w_now.y, w.z)
		_ease[leg] = 1.0
		_last_t[leg] = t
		if (t - a).length() > IK_CLOSE:
			out = _leg_ik(out, leg, t, cal, r)
	return out


## The pose with leg LEG turned (thigh forward and out, knee, foot kept level) so its ankle comes to T (the body's own
## space, m), from where the pose has it; twice, the second for what the first left (the turns are not independent).
func _leg_ik(p: Dictionary, leg: int, t: Vector3, cal: Dictionary, r: Rig) -> Dictionary:
	var out := p.duplicate()
	var names: Array = [["thigh_l", "shin_l", "foot_l"], ["thigh_r", "shin_r", "foot_r"]][leg]
	var L1: float = cal.thigh[leg]
	var L2: float = cal.shin[leg]
	for it in 2:
		if it > 0:
			r.solve_legs(out)   # (the first from the pose as the caller solved it)
		var h: Vector3 = r.out_pos[cal.hip[leg]]
		var a: Vector3 = r.out_pos[cal.foot[leg]]
		if (t - a).length() < IK_CLOSE:
			break
		# (in the hips' own frame: the thigh turns on the pelvis, which a move may have twisted or tipped)
		var pelvis := Basis(r._q[0] as Quaternion).inverse()
		var v := pelvis * (a - h)
		var u := pelvis * (t - h)
		var dv := clampf(v.length(), absf(L1 - L2) + 0.01, L1 + L2 - 0.002)
		var du := clampf(u.length(), absf(L1 - L2) + 0.01, L1 + L2 - 0.002)
		var d_bend := _knee_bend(L1, L2, du) - _knee_bend(L1, L2, dv)
		var d_swing := (atan2(u.z, -u.y) + _thigh_ahead(L1, L2, du)) - (atan2(v.z, -v.y) + _thigh_ahead(L1, L2, dv))
		var d_out := atan2(u.x, -u.y) - atan2(v.x, -v.y)
		out[names[0]] = _v3(out.get(names[0], Vector3.ZERO)) + Vector3(cal.k_swing * rad_to_deg(d_swing), 0, cal.k_out[leg] * rad_to_deg(d_out))
		out[names[1]] = _v3(out.get(names[1], Vector3.ZERO)) + Vector3(cal.k_bend * rad_to_deg(d_bend), 0, 0)
		out[names[2]] = _v3(out.get(names[2], Vector3.ZERO)) + Vector3(-cal.k_foot * rad_to_deg(d_swing - d_bend), 0, 0)
	return out


static func _v3(v) -> Vector3:
	return v if v is Vector3 else Vector3.ZERO


## A leg of thigh L1 and shin L2 with its ankle D from its hip: the knee's bend (0 straight), and how far ahead of the
## hip-to-ankle line the thigh points (radians).
static func _knee_bend(L1: float, L2: float, d: float) -> float:
	return PI - acos(clampf((L1 * L1 + L2 * L2 - d * d) / (2.0 * L1 * L2), -1.0, 1.0))


static func _thigh_ahead(L1: float, L2: float, d: float) -> float:
	return acos(clampf((L1 * L1 + d * d - L2 * L2) / (2.0 * L1 * d), -1.0, 1.0))


const PLANT_HEIGHT := 0.03   # m: an ankle this close to its height standing is on the floor
const IK_CLOSE := 0.004      # m: an ankle this close to where it is kept needs no turning
const PLANT_REACH := 0.32    # m: a planted foot let go when his stride would have it this far from where it is
const PLANT_EASE := 0.2      # of a correction let go each frame (five frames)
const STEP_TIME := 0.2       # s: a foot stretched to PLANT_REACH stepping to where his stride has it
const STEP_LIFT := 0.10      # m: how high it comes up in that step
const SHUFFLE_REACH := 0.16  # m: PLANT_REACH for a body going slower than SHUFFLE_SPEED (m/s)
const SHUFFLE_SPEED := 1.0
const STEP_ACROSS := 0.7     # of a step: across by here, then straight down
const LAND_REACH := 0.16     # m: and coming down, from it (further, let go soon after it jolted - the jitter test)
const STEP_REACH := 0.45     # m: the furthest a stepping foot is from where his stride has it
const EASE_HIGH := 0.3       # m: a foot let go is all the stride's own this far over its height standing
const CUT := 1.0             # m: a planted foot this far from his stride's is not stepped from: it goes with him

## Low (no link): the shared foundation's planter (WsgFootPlanter, its bone_prefix and our contact rule) plants this
## body's feet instead of _planted - the standing officials (0.15.15). Measured on Low (a seeded regu, 2 x 150 s, the
## feet as drawn): their flat feet sliding over 2 cm in a frame 32 times -> 2, the planted step's slip (90th percentile)
## 8.3 -> 4.7 cm. The players keep _planted: under the shared planter their glide share fell (14 -> 9%) but the world
## check's feet_low failed, planted feet sliding 3-7 cm a step walking, running and stopping (ours: 1.8 at most).
var foundation_planter := false
var _wp: WsgFootPlanter = null
var _wp_at := Vector3.INF
var _drawn_feet := []


func _foundation_plant(p: Dictionary, dt: float) -> void:
	if _wp == null:
		_wp = WsgFootPlanter.new()
		_wp.bone_prefix = "mixamorig_"
		var cal := _leg_cal(_rig)
		# (Down as _planted has it: the pose's ankle within PLANT_HEIGHT of its height standing, twice that to lift.
		# The planter's own gate, a foot's speed too, let our strides' standing feet slide: 1032 flat-foot skids.)
		_wp.contact_fn = func(i: int, ank: Vector3, _toe: Vector3, was: bool) -> bool:
			return ank.y < _floor_y() + float(cal.ground[i]) * global_transform.basis.get_scale().y + PLANT_HEIGHT * (2.0 if was else 1.0)
		skeleton.add_child(_wp)
		skeleton.skeleton_updated.connect(func() -> void:
			if _wp != null and _wp.active and skeleton.is_inside_tree():   # (drawn as it leaves the tree: no place)
				_drawn_feet = _feet_now())
	dt = maxf(dt, 1.0 / 240.0)
	var at := global_position
	var speed := 0.0
	if _wp_at != Vector3.INF and at.distance_to(_wp_at) >= 0.5:
		_wp.reset()   # (put somewhere new: his feet go with him)
	elif _wp_at != Vector3.INF:
		speed = Vector2(at.x - _wp_at.x, at.z - _wp_at.z).length() / dt
	_wp_at = at
	# (Off the floor: planting off - a foot it held eased back - not the pose handed back at once, a jump of the foot.)
	_wp.enabled = float(p.get("y", 0.0)) <= 0.05
	_wp.ground_y = _floor_y()
	_wp.body_speed = speed
	_wp.tick(dt)


func _floor_y() -> float:
	var par := get_parent() as Node3D
	return par.global_position.y if par else 0.0


var plant_feet := false      # (Player, Officials) a foot on the floor stays put: _planted
var _locks: Array = [null, null]     # each foot's place on the floor while it is down (world), or null
var _last_t: Array = [null, null]    # where the last correction put each ankle (the body's space)
var _ease: Array = [0.0, 0.0]        # 1 .. 0: a correction being let go
var _step: Array = [-1.0, -1.0]      # 0 .. 1: through a step from its lock to where the stride has it; -1: none
var _step_from: Array = [Vector3.ZERO, Vector3.ZERO] # where that step left (world)
var _step_land: Array = [null, null]                 # and where it comes down, once across (world)
var _went := Vector3.ZERO            # how fast he went over the floor last frame (world, m/s)
var _was_at := Vector3.INF
var _my_cal := {}
static var _cal := {}


## The legs measured on the rig, once: hip, ankle, thigh and shin lengths, the ankles' heights standing, and which way
## (and how far) a degree of each pose angle turns the leg (the poses' angles are the bones' own, not the leg's).
static func _leg_cal(r: Rig) -> Dictionary:
	if _cal.has(r):
		return _cal[r]
	var c := {"hip": [int(r.index["LeftUpLeg"]), int(r.index["RightUpLeg"])], "knee": [int(r.index["LeftLeg"]), int(r.index["RightLeg"])],
		"foot": [int(r.index["LeftFoot"]), int(r.index["RightFoot"])], "toe": [int(r.index.get("LeftToeBase", r.index["LeftFoot"])), int(r.index.get("RightToeBase", r.index["RightFoot"]))]}
	var base := Moves.READY.duplicate()
	base["plant"] = 0.0
	r.solve(base)
	c.thigh = []
	c.shin = []
	c.ground = []
	for leg in 2:
		c.thigh.append(((r.out_pos[c.knee[leg]] as Vector3) - (r.out_pos[c.hip[leg]] as Vector3)).length())
		c.shin.append(((r.out_pos[c.foot[leg]] as Vector3) - (r.out_pos[c.knee[leg]] as Vector3)).length())
		c.ground.append(float(r.feet_rest[leg * 2]) * r.unit)
	var leg_dir := func(p: Dictionary, leg: int) -> Vector3:
		r.solve(p)
		return (r.out_pos[c.foot[leg]] as Vector3) - (r.out_pos[c.hip[leg]] as Vector3)
	var swing_of := func(v: Vector3) -> float: return rad_to_deg(atan2(v.z, -v.y))
	var out_of := func(v: Vector3) -> float: return rad_to_deg(atan2(v.x, -v.y))
	# A thigh's forward swing (the knee straight: shin 0 more), its turn out, the knee's bend, the foot's tilt.
	var p1 := base.duplicate()
	var v0: Vector3 = leg_dir.call(base, 0)
	p1["thigh_l"] = (base.thigh_l as Vector3) + Vector3(10, 0, 0)
	var v1: Vector3 = leg_dir.call(p1, 0)
	c.k_swing = 10.0 / (swing_of.call(v1) - swing_of.call(v0))
	c.k_out = []
	for leg in 2:
		var nm := "thigh_l" if leg == 0 else "thigh_r"
		var q := base.duplicate()
		q[nm] = (base[nm] as Vector3) + Vector3(0, 0, 10)
		var w0: Vector3 = leg_dir.call(base, leg)
		var w1: Vector3 = leg_dir.call(q, leg)
		c.k_out.append(10.0 / (out_of.call(w1) - out_of.call(w0)))
	var p2 := base.duplicate()
	p2["shin_l"] = (base.shin_l as Vector3) + Vector3(10, 0, 0)
	r.solve(base)
	var k0: Vector3 = (r.out_pos[c.knee[0]] as Vector3)
	var a0: Vector3 = (r.out_pos[c.foot[0]] as Vector3)
	r.solve(p2)
	var a1: Vector3 = (r.out_pos[c.foot[0]] as Vector3)
	var k1: Vector3 = (r.out_pos[c.knee[0]] as Vector3)
	var shin_pitch := func(k: Vector3, a: Vector3) -> float: return swing_of.call(a - k)
	# (the shin swinging back as the knee bends: a bend is the thigh's line less the shin's)
	c.k_bend = 10.0 / -(shin_pitch.call(k1, a1) - shin_pitch.call(k0, a0))
	var p3 := base.duplicate()
	p3["foot_l"] = (base.foot_l as Vector3) + Vector3(10, 0, 0)
	r.solve(base)
	var t0: Vector3 = (r.out_pos[c.toe[0]] as Vector3) - (r.out_pos[c.foot[0]] as Vector3)
	r.solve(p3)
	var t1: Vector3 = (r.out_pos[c.toe[0]] as Vector3) - (r.out_pos[c.foot[0]] as Vector3)
	c.k_foot = 10.0 / (swing_of.call(t1) - swing_of.call(t0)) if absf(swing_of.call(t1) - swing_of.call(t0)) > 0.5 else 1.0
	_cal[r] = c
	return c


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
	var legs := []            # the bones from the root down to the feet and toes (solve_legs), parents first
	var leg_poses := []       # the pose bones they follow, and theirs
	var _leg_pos := []

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
		_leg_pos.resize(count)
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
	## solve() for the legs alone (the hips down to the toes): out_pos for those bones, the pose bones' turns (_q);
	## the rest left as they were (RealBody._planted: the feet, many times a frame, cheaply).
	func solve_legs(p: Dictionary) -> void:
		if legs.is_empty():
			var want := {}
			for f in feet:
				var b: int = f
				while b >= 0 and not want.has(b):
					want[b] = true
					b = parent[b]
			legs = want.keys()
			legs.sort()   # (parents first: a bone's parent comes before it in the skeleton)
			var poses := {}
			for b in legs:
				for f in [follow[b], follow2[b]]:
					var i: int = f
					while i >= 0 and not poses.has(i):
						poses[i] = true
						i = pose_parent[i]
			leg_poses = poses.keys()
			leg_poses.sort()   # (a pose bone's parent comes before it in BONES)
		for i in leg_poses:
			var pp: int = pose_parent[i]
			var own := RealBody.local_rot(p.get(BONES[i][0], Vector3.ZERO))
			_q[i] = (_q[pp] as Quaternion) * own if pp >= 0 else own
		var off := Vector3(-float(p.get("hips_side", 0.0)), float(p.get("hips_y", 0.0)), float(p.get("hips_fwd", 0.0))) / unit
		for b in legs:
			var f: int = follow[b]
			var g: Basis = rest_global[b]
			if f >= 0:
				var q: Quaternion = _q[f]
				if follow2[b] >= 0:
					q = q.slerp(_q[follow2[b]], 0.5)
				g = Basis(q) * (rest_put[b] as Basis)
			_glob[b] = g
			var par: int = parent[b]
			_leg_pos[b] = (_leg_pos[par] as Vector3) + (_glob[par] as Basis) * (rest_origin[b] as Vector3) if par >= 0 \
				else (rest_origin[b] as Vector3) + off
		var dy := 0.0
		var plant := float(p.get("plant", 1.0))
		if plant > 0.0 and not feet_rest.is_empty():
			var low := INF
			var lowest_foot := INF
			for i in 4:
				var y := (_leg_pos[feet[i]] as Vector3).y
				low = minf(low, y - float(feet_rest[i]))
				lowest_foot = minf(lowest_foot, y)
			var w := plant * clampf(1.0 - float(p.get("y", 0.0)) / 0.15, 0.0, 1.0)
			w *= clampf((((_leg_pos[hips] as Vector3).y - lowest_foot) * unit - 0.08) / 0.15, 0.0, 1.0)
			dy = clampf(-low, -0.2 / unit, 0.2 / unit) * w
		for b in legs:
			out_pos[b] = ((_leg_pos[b] as Vector3) + Vector3(0, dy, 0)) * unit

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
