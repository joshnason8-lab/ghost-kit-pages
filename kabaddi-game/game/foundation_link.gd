class_name FoundationLink
extends Node3D
## A kabaddi player or official drawn with the World Stage Games foundation (addons/wsg_foundation): his own Meshy body
## (the one RiggedBody wears, baked onto the shared rig: assets/foundation/<body>_*, tools/rig/bake_foundation.sh)
## with the game's own pose on it (WsgLegacyPose reads RiggedBody's skeleton: every kabaddi move the game makes - the
## raider's dancing stance, the cant's toe and hand touches, the dubki, the lion jump, the dives, ankle and thigh
## holds, chains, the struggle and the takedown, sitting out - stays exactly the game's, its feet planted and its
## hands on the holds as RiggedBody puts them), and the motion capture where it is plainly better than the hand-made
## walk: a player walking back to his half or off to the sitting block, standing about between raids, a roar of
## triumph (Celebrate_FistPump) or a slump (Disappointed_HandsOnHead); an official walking his line (his signals keep
## the game's arms over the capture's legs).
## The game's body (RiggedBody) stays the game's: HumanModel still poses it every frame and everything the rules
## measure off it (touches, holds, the midline) is unchanged; only its mesh is no longer drawn.
## Medium and High only, in a match: Low draws the game's own bodies exactly as before (tests/test_runner). Without the
## licensed clip library (a fork's build, CI without the secret) nobody has a link, and the game is as it was.

const DIR := "res://assets/foundation/"
## RiggedBody's bodies face -Z; the rig faces +Z.
const TURN := Quaternion(Vector3.UP, PI)
## Players' states the motion capture draws (the rest are the game's own moves).
const MOVE := ["walk", "idle"]
## Moments a clip of the library plays over the capture's legs and stance.
const CLIPS := {"roar": "Celebrate_FistPump", "slump": "Disappointed_HandsOnHead"}
const ARMS := ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]
const FADE := 0.22

var who: Athlete
var hm: HumanModel
var gb: RiggedBody            # the game's body (posed by the game, not drawn)
var prefix := ""
var body: WsgBody
var loco: WsgLocomotor
var legacy: Layer
var reader: WsgLegacyPose
var material: ShaderMaterial
var mode := ""                # "full" (the game's pose), "upper" (its arms), "move" (the capture), "clip"
var pose_every := 1           # posed every frame, or every 2nd or 3rd (far from the camera: Match._rank_detail)
var _skip := 0
var _dt := 0.0
var _k := 1.0                 # the rig's units per the game body's (model space)
var _shift := Vector3.ZERO    # the game body's model space (turned half round) at the rig's origin
var _number: Label3D
var _hidden_labels: Array = []

## Set by the tests that are not about drawing (tests/test_runner.gd): their matches run as a build without the
## licensed clips would (CI's), in the time CI allows.
static var off := false
## In a match (Match sets it; not the home screen's match behind the menus, nor the menus' figures).
static var in_match := false
## The replay is playing: the bodies show what WsgReplay kept, not the game.
static var frozen := false
## Microseconds every body's foundation work has taken (its update here, and its skeleton's modifiers: the game's pose
## laid on, the drivers, the helpers), all told (tests/foundation_cpu).
static var cost_usec := 0


## Kabaddi is a budget game (WsgFoundation: Low by default, the phone decides; GL Compatibility always).
static func _static_init() -> void:
	WsgFoundation.profile = "budget"


## Whether bodies made now are drawn by the foundation: in a match, the licensed clips in this build, the realistic
## bodies on, and the graphics Medium or High (Low keeps the game's own bodies).
static func enabled() -> bool:
	return not off and in_match and int(Game.settings.graphics) > Game.GFX_LOW and int(Game.settings.get("models", 1)) == 1 \
		and WsgClips.available() and not OS.has_environment("WSG_OFF")


## The baked body for a RiggedBody's file, or "" when it has none.
static func baked(file: String) -> String:
	var p := file.get_basename()
	return p if p != "" and ResourceLoader.exists(DIR + p + "_rig.json") else ""


func _init(p_model: HumanModel) -> void:
	hm = p_model
	gb = p_model.rig
	who = p_model.get_parent() as Athlete
	prefix = baked(String(gb.get_meta("file", "")))
	name = "Foundation"
	top_level = true
	# (The replay plays with the athletes stopped: the bodies go on being drawn.)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	body = WsgBody.new(WsgBody.load_character(DIR, prefix), null, 0)
	add_child(body)
	body.set_manual(true)
	body.visible = false        # till its first pose
	# The game's body and this one: the same mesh, the rig's 1.80 m against the model's own units, and where the
	# rig's origin (between the soles, the legs straightened) is in the game body's space.
	var gs := gb.skeleton
	var hips_g := TURN * gs.get_bone_global_rest(gs.find_bone("hips")).origin
	var chest_g := TURN * gs.get_bone_global_rest(gs.find_bone("chest")).origin
	var hips_r: Vector3 = body.joints["Hips"]
	_k = hips_r.distance_to(body.joints["Spine2"]) / maxf(hips_g.distance_to(chest_g), 0.01)
	_shift = hips_g - hips_r / _k
	_make_material()
	body.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if Game.shadows_enabled() \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	legacy = Layer.new()
	legacy.name = "Legacy"
	body.skeleton.add_child(legacy)
	body.skeleton.move_child(legacy, 0)
	reader = WsgLegacyPose.new(gs, body.joints, TURN)
	loco = WsgLocomotor.attach(body)
	legacy.lift_after = loco.planter.hips_offset
	for m in [loco.look, loco.look_chest]:
		if m:
			m.active = false
	gb.mesh_instance.visible = false
	gb.mirror = material
	body.posed.connect(_posed_cost)
	_move_number()


## The game's own body drawn again and this one gone (the graphics lowered to Low mid-match).
func release() -> void:
	if is_instance_valid(gb):
		gb.mesh_instance.visible = true
		gb.mirror = null
	for l in _hidden_labels:
		if is_instance_valid(l):
			l.visible = true
	if hm and is_instance_valid(hm):
		hm.link = null
	queue_free()


# ---------------------------------------------------------------- the kit

static var _shader: Shader


## RiggedBody's own textured shader (the albedo, the kit map's team colours, his skin tone, the sweat), with the kit
## regions from UV2 (the bake keeps them there; the vertex colour is the rig's rest position) - his colours and skin
## exactly as the game's body has them.
func _make_material() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = RiggedBody.SHADER_TEXTURED.replace("region = COLOR.rgb;", "region = vec3(0.0, UV2.x, UV2.y);")
	material = ShaderMaterial.new()
	material.shader = _shader
	var src: ShaderMaterial = gb.material
	for k in ["albedo_tex", "kit_tex", "skin_ratio", "skin_mask", "jersey_col", "shorts_col", "trim_col", "recolour", "sweat"]:
		var v = src.get_shader_parameter(k)
		if v != null:
			material.set_shader_parameter(k, v)
	body.mesh_instance.material_override = material


## The shirt number on this body's back (RiggedBody's own is on the game's chest bone, which this body does not
## follow under the capture).
func _move_number() -> void:
	for att in gb.skeleton.get_children():
		if att is BoneAttachment3D:
			for l in att.get_children():
				if l is Label3D and l.visible:
					_hidden_labels.append(l)
	if _hidden_labels.is_empty():
		return
	var src: Label3D = _hidden_labels[0]
	src.visible = false
	var chest: Vector3 = body.joints["Spine2"]
	# The back's surface behind the chest bone, on the full mesh.
	var verts: PackedVector3Array = (body.character.meshes[0] as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var back := chest.z
	for v in verts:
		if absf(v.x) < 0.08 and absf(v.y - chest.y - 0.02) < 0.08:
			back = minf(back, v.z)
	var att := BoneAttachment3D.new()
	att.bone_name = "Spine2"
	body.skeleton.add_child(att)
	_number = src.duplicate() as Label3D
	_number.visible = true
	_number.pixel_size = src.pixel_size * _k
	_number.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, 0.02, back - chest.z - 0.012))
	att.add_child(_number)


# ---------------------------------------------------------------- each frame

## What draws him now: the game's whole pose, its arms over the capture, the capture, or a clip of the library.
func want_mode() -> String:
	if who == null:
		return "full"
	if who.team == 2:
		if who.state == "signal":
			return "upper"
		return "move" if who.state in MOVE else "full"
	if CLIPS.has(who.state):
		# (Standing: the library's clip; still on the move - a slump while he jogs off - the game's own.)
		return "clip" if who.move_vel.length() < 0.6 or mode == "clip" and who.move_vel.length() < 1.0 else "full"
	return "move" if who.state in MOVE else "full"


## After the game has posed its body this frame (HumanModel._process): drive this one. Far from the camera, posed
## every second or third frame and carried along between (its modifiers run only when posed: WsgBody.set_manual).
func update(delta: float) -> void:
	if frozen or delta <= 0.0 or not is_instance_valid(gb) or not hm.is_visible_in_tree():
		return
	var t0 := Time.get_ticks_usec()
	_update(delta)
	cost_usec += Time.get_ticks_usec() - t0


func _update(delta: float) -> void:
	_dt += delta
	_skip += 1
	var want := want_mode()
	if _skip < pose_every and want == mode:
		_place()
		return
	_skip = 0
	var dt := minf(_dt, 0.1)
	_dt = 0.0
	var pose := {}
	if want != "move" and want != "clip":
		pose = reader.read()
		if want == "upper":
			var up := {}
			for b in ARMS:
				if pose.has(b):
					up[b] = pose[b]
			pose = up
		else:
			# The hips where the game's are (in this body's space), not scaled from the rest: every joint then lies on
			# the game's.
			pose["@hips"] = (TURN * gb.skeleton.get_bone_pose_position(0) - _shift) * _k - (body.joints["Hips"] as Vector3)
			_legs(pose)
	legacy.set_pose(pose)
	if want != mode:
		var w := 1.0 if want in ["full", "upper"] else 0.0
		if mode == "":
			legacy.weight = w      # (a new body starts as the game's: no blend in from nothing)
		legacy.fade_to(w, FADE)
		if want == "clip":
			loco.play(CLIPS[who.state])
		elif mode == "clip" and loco.state == WsgLocomotor.State.SHOT:
			loco._shot_t = maxf(loco._shot_t, loco._shot_len - WsgLocomotor.FADE)   # (the clip ends as he moves on)
		if mode == "" or want != "full":
			loco.planter.reset()
		mode = want
	body.visible = true
	var f := who.body_facing()
	var yaw := atan2(f.x, f.z)
	# The capture runs under the game's pose only while it shows (a body wholly the game's skips it: the CPU).
	# (The planter holds the feet only under the capture: under the game's pose its feet are where the game puts them.)
	loco.planter.enabled = mode != "full"
	if mode != "full" or legacy.weight < 1.0:
		loco.drive(dt, Vector3(who.move_vel.x, 0.0, who.move_vel.z), yaw)
	else:
		loco.yaw = yaw
	_place()
	body.advance(dt)


## The legs laid where the game's are, each knee bending about its own hinge: the game's bodies are rigged with the
## legs splayed (an A-pose), so its thigh's and shin's turns, each corrected from its own rest, put the rig's knee
## bend off its hinge, and the rig's drivers straightened it (the raider's stance stood half the frames straight-
## legged). Each thigh is turned so its hinge is square to the plane of the game's thigh and shin; the shin bends in
## it; the foot keeps the way the game's points.
const LEGS := {"Left": ["thigh_l", "shin_l", "foot_l"], "Right": ["thigh_r", "shin_r", "foot_r"]}


func _legs(pose: Dictionary) -> void:
	var g: Dictionary = reader._last_global
	if not g.has("Hips"):
		return
	var gs := gb.skeleton
	for side in LEGS:
		var n: Array = LEGS[side]
		var hip := TURN * gs.get_bone_global_pose(gs.find_bone(n[0])).origin
		var knee := TURN * gs.get_bone_global_pose(gs.find_bone(n[1])).origin
		var ankle := TURN * gs.get_bone_global_pose(gs.find_bone(n[2])).origin
		var u := (knee - hip).normalized()
		var sd := (ankle - knee).normalized()
		# The game's own thigh's side axis (its twist), for a leg nearly straight or a knee bent the wrong way.
		var own: Vector3 = (g[side + "UpLeg"] as Quaternion) * Vector3.RIGHT
		var h := u.cross(sd)
		if h.length() < 0.05:
			h = own - u * own.dot(u)
		elif h.dot(own) < 0.0:
			h = -h
		h = h.normalized()
		var thigh := Basis(h, -u, h.cross(-u)).orthonormalized()
		var shin := Basis(h, -sd, h.cross(-sd)).orthonormalized()
		var qt := thigh.get_rotation_quaternion()
		var qs := shin.get_rotation_quaternion()
		pose[side + "UpLeg"] = ((g["Hips"] as Quaternion).inverse() * qt).normalized()
		pose[side + "Leg"] = (qt.inverse() * qs).normalized()
		if g.has(side + "Foot"):
			pose[side + "Foot"] = (qs.inverse() * (g[side + "Foot"] as Quaternion)).normalized()


## Where the body stands: under the capture at his place, turned as the capture turns him; under the game's pose
## exactly over the game's body (the same mesh: each joint on the game's); between the two as one fades to the other.
func _place() -> void:
	var s := gb.global_transform.basis.get_scale().x / _k
	var free := Transform3D(Basis(Vector3.UP, loco.yaw).scaled(Vector3.ONE * s), who.global_position)
	var w := smoothstep(0.0, 1.0, legacy.weight)
	if w <= 0.0:
		body.global_transform = free
		return
	var exact := gb.global_transform * Transform3D(Basis(TURN)) * Transform3D(Basis.from_scale(Vector3.ONE / _k), _shift)
	body.global_transform = exact if w >= 1.0 else free.interpolate_with(exact, w)
	if w >= 1.0:
		loco.yaw = exact.basis.orthonormalized().get_euler().y


## Set (the tests, the still tool): each pose keeps where this body's joints were drawn (in last), measured once the
## skeleton has its final pose - outside its update Godot reports the bones without the modifiers (the game's pose).
var measure := false:
	set(v):
		measure = v
		if v and body and not body.posed.is_connected(_measure):
			body.posed.connect(_measure)
var last := {}
const MEASURED := ["Hips", "Spine2", "Head", "LeftHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "RightUpLeg", "RightLeg", "RightFoot"]


func _measure() -> void:
	if not measure:
		return
	for b in MEASURED:
		last[b] = body.bone_world(b).origin
	last["mode"] = mode
	last["w"] = legacy.weight


## The game body's joint in the world against this body's as last drawn (tests: they lie on each other under the
## game's pose; measure on).
func joint_gap(game_bone: String, rig_bone: String) -> float:
	var g := gb.skeleton.global_transform * gb.skeleton.get_bone_global_pose(gb.skeleton.find_bone(game_bone))
	return g.origin.distance_to(last.get(rig_bone, Vector3.INF))


## The knee's bend on this body as last drawn, in degrees off straight (tests: the raider's stance; measure on).
func knee_bend(side: String) -> float:
	if not last.has(side + "Leg"):
		return -1.0
	var hip: Vector3 = last[side + "UpLeg"]
	var knee: Vector3 = last[side + "Leg"]
	var ankle: Vector3 = last[side + "Foot"]
	return rad_to_deg((knee - hip).angle_to(ankle - knee))


## The game's pose over the capture (WsgPoseLayer), noting the frame it last ran (tests).
class Layer extends WsgPoseLayer:
	var ran := -1
	var t0 := 0

	func _process_modification_with_delta(delta: float) -> void:
		ran = Engine.get_process_frames()
		t0 = Time.get_ticks_usec()
		super(delta)


## The skeleton's modifiers done (the layer runs first among them): their time counted.
func _posed_cost() -> void:
	if legacy.t0 > 0:
		cost_usec += Time.get_ticks_usec() - legacy.t0
		legacy.t0 = 0
