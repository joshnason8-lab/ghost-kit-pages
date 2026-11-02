class_name FoundationLink
extends Node3D
## A takraw player, official or substitute drawn with the World Stage Games foundation (addons/wsg_foundation): the
## owner's man or woman (the Meshy models RealBody wears, baked onto the shared rig: assets/foundation/man_*,
## woman_*) in the same kit or suit material, with the game's own pose laid on it exactly (WsgLegacyPose reads a
## 17-bone copy of RealBody's pose): every takraw action - the toss, the serve and the horse kick, the sila and the
## thigh, the roll spike, the sunback, the tapak, the head spike, the block, the dig, picking the ball up, the
## celebrations - stays the game's, frame for frame, its feet where the game puts them and its kicking foot where
## the game's meets the ball. The motion capture draws only what the game walks by hand: a player walking between
## points (back to his place, to fetch the ball, with it in his hand), the officials standing and stepping out of the
## ball's way (their heads on the ball, a judge's flag in his fist, their signals the game's arms).
## The game's body (RealBody) stays the game's: Player and Officials still pose it every frame and everything the
## match measures off it (the hands holding the ball, the timing) is unchanged; only its mesh is no longer drawn.
## Medium and High only, in a match: Low draws the game's own bodies exactly as before (tests/test_runner). Without
## the licensed clip library (a fork's build, CI without the secret) nobody has a link, and the game is as it was.

const DIR := "res://assets/foundation/"
const ARMS := ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]
const R_ARM := ["RightShoulder", "RightArm", "RightForeArm", "RightHand"]
const FADE := 0.22        # s from the game's pose to the motion capture and back
const FADE_IN := 0.1      # s into one of the game's own moves (a kick, a pick-up): its timing is the game's
## RealBody's pose bones and the model's bones they follow (RealBody.bone_world's table).
const MAP := {"hips": "Hips", "spine": "Spine", "chest": "Spine2", "neck": "Neck", "head": "Head",
	"upperarm_l": "LeftArm", "forearm_l": "LeftForeArm", "hand_l": "LeftHand", "upperarm_r": "RightArm",
	"forearm_r": "RightForeArm", "hand_r": "RightHand", "thigh_l": "LeftUpLeg", "shin_l": "LeftLeg",
	"foot_l": "LeftFoot", "thigh_r": "RightUpLeg", "shin_r": "RightLeg", "foot_r": "RightFoot"}

## Set by the tests that are not about drawing (tests/test_runner.gd): their matches run as a build without the
## licensed clips would (CI's), in the time CI allows.
static var off := false
## In a match (Match sets it; not the home screen's match behind the menus).
static var in_match := false
## The replay is playing: the bodies show what WsgReplay kept, not the game.
static var frozen := false
## Microseconds every body's foundation work has taken (its update here and its skeleton's modifiers), all told
## (tests/foundation_cpu).
static var cost_usec := 0
## Of that, the skeleton's modifiers (the game's pose laid on, the drivers, the helpers).
static var cost_mods_usec := 0


## Sepak takraw is a budget game (WsgFoundation: Low by default on an ordinary phone, GL Compatibility always).
static func _static_init() -> void:
	WsgFoundation.profile = "budget"


## Whether bodies made now are drawn by the foundation: in a match, the licensed clips in this build, the baked
## bodies there, and the graphics Medium or High (Low keeps the game's own bodies).
static func enabled() -> bool:
	return not off and in_match and int(Game.settings.graphics) > Game.GFX_LOW and WsgClips.available() \
		and ResourceLoader.exists(DIR + "man_rig.json") and not OS.has_environment("WSG_OFF")


var gb: RealBody              # the game's body (posed by the game, not drawn)
var kind := "player"          # player, official, sub
## What the owner (Player, Officials) asks for this frame: "full" (the game's whole pose), "upper" (its arms over the
## capture), "move" (the capture), "carry" (the capture, the arms holding the ball where the game's are in the body).
var want := "full"
var vel := Vector3.ZERO       # where he is going (world, m/s)
var yaw := 0.0                # where he faces (world yaw)
var look := Vector3.INF       # what his head is on under the capture (INF: where he goes)
var body: WsgBody
var loco: WsgLocomotor
var legacy: Layer
var reader: WsgLegacyPose
var proxy: Skeleton3D         # the game's 17 pose bones, posed as RealBody's (WsgLegacyPose reads it)
var mode := ""
var pose_every := 1           # posed every frame, or every 2nd or 3rd (Match._rank_detail)
var flag: Node3D              # a line judge's flag: in this body's right fist
var palms := {}               # "l", "r" -> the palm's ball point as last drawn, in the body's frame
## The ball in these hands (Match sets it while he carries it): drawn where they hold it once the skeleton has its
## final pose (that comes at the skeleton's own update, after the match has placed the ball this frame).
var carry_ball: Ball = null
var carry_two := true
var _skip := 0
var _dt := 0.0
var _k := 1.0                 # the rig's metres per the game skeleton's unit
var _shift := Vector3.ZERO    # the game skeleton's space at the rig's origin
var _hips_rest := Vector3.ZERO
var _flag_rel := Transform3D.IDENTITY
var _at := Vector3.INF
var _pw := -1.0               # placed over the game's body (1) or free at his place under the capture (0)

static var _proxies := {}     # women -> [names, parents, rests] of the 17-bone copy


func _init(p_body: RealBody, p_kind := "player") -> void:
	gb = p_body
	kind = p_kind
	name = "Foundation"
	top_level = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	body = WsgBody.new(WsgBody.load_character(DIR, "woman" if gb.women else "man"), null, 0)
	add_child(body)
	body.set_manual(true)
	body.visible = false        # till its first pose
	proxy = _make_proxy(gb.women)
	add_child(proxy)
	# The game's body and this one: the same mesh; the rig's metres against the game skeleton's units (by the legs,
	# hip to ankle: the feet meet the ball), and where the rig's origin is in the game skeleton's space.
	var j := body.joints
	var rig_leg := 0.0
	var game_leg := 0.0
	for s in ["l", "r"]:
		var side := "Left" if s == "l" else "Right"
		rig_leg += (j[side + "UpLeg"] as Vector3).distance_to(j[side + "Leg"]) + (j[side + "Leg"] as Vector3).distance_to(j[side + "Foot"])
		game_leg += _rest_at("thigh_" + s).distance_to(_rest_at("shin_" + s)) + _rest_at("shin_" + s).distance_to(_rest_at("foot_" + s))
	_k = rig_leg / maxf(game_leg, 0.0001)
	_hips_rest = proxy.get_bone_rest(0).origin
	_shift = _hips_rest - (j["Hips"] as Vector3) / _k
	body.mesh_instance.material_override = gb.mesh_instance.material_override
	body.mesh_instance.cast_shadow = gb.mesh_instance.cast_shadow
	legacy = Layer.new()
	legacy.name = "Legacy"
	body.skeleton.add_child(legacy)
	body.skeleton.move_child(legacy, 0)
	reader = WsgLegacyPose.new(proxy, body.joints)
	legacy.arms = reader
	legacy.torso_r = 0.08       # the forearms kept out of the chest
	loco = WsgLocomotor.attach(body)
	legacy.lift_after = loco.planter.hips_offset
	gb.mesh_instance.visible = false
	gb.link = self
	body.posed.connect(_on_posed)


## The game's own body drawn again and this one gone (the graphics lowered to Low mid-match).
func release() -> void:
	if is_instance_valid(gb):
		gb.mesh_instance.visible = true
		gb.link = null
	queue_free()


# ---------------------------------------------------------------- the game's 17 bones

## A skeleton of RealBody's 17 pose bones (every rest turn the identity, the limbs hanging: the convention
## WsgLegacyPose reads), each at the place the model's bone it moves has when every pose bone is at rest, in the game
## skeleton's own space and units: posed with RealBody's turns, its joints are the game's.
func _make_proxy(w: bool) -> Skeleton3D:
	if not _proxies.has(w):
		var r := RealBody.rig(w)
		r.solve({"plant": 0.0})
		var names := []
		var parents := []
		var rests := []
		var at := {}
		for b in RealBody.BONES:
			at[b[0]] = (r.out_pos[r.index[MAP[b[0]]]] as Vector3) / r.unit
		for b in RealBody.BONES:
			names.append(b[0])
			var par: int = names.find(b[1])
			parents.append(par)
			rests.append((at[b[0]] as Vector3) - ((at[b[1]] as Vector3) if par >= 0 else Vector3.ZERO))
		_proxies[w] = [names, parents, rests]
	var d: Array = _proxies[w]
	var sk := Skeleton3D.new()
	sk.name = "GamePose"
	for i in (d[0] as Array).size():
		sk.add_bone(d[0][i])
		if int(d[1][i]) >= 0:
			sk.set_bone_parent(i, int(d[1][i]))
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, d[2][i]))
	sk.reset_bone_poses()
	return sk


func _rest_at(bone: String) -> Vector3:
	return proxy.get_bone_global_rest(proxy.find_bone(bone)).origin


## The 17 bones posed as the game's body is now (its pose's turns, its hips where RealBody put them).
func _read_game() -> void:
	var p: Dictionary = gb.pose
	for i in RealBody.BONES.size():
		proxy.set_bone_pose_rotation(i, RealBody.local_rot(p.get(RealBody.BONES[i][0], Vector3.ZERO)))
	var r := RealBody.rig(gb.women)
	proxy.set_bone_pose_position(0, gb.skeleton.get_bone_pose_position(r.hips))


# ---------------------------------------------------------------- each frame

## After the owner has posed the game's body this frame and set want, vel, yaw and look: drive this one. Posed every
## pose_every-th frame (its modifiers run only then: WsgBody.set_manual), carried along between.
func update(delta: float) -> void:
	if frozen or delta <= 0.0 or not is_instance_valid(gb) or not gb.is_visible_in_tree():
		return
	var t0 := Time.get_ticks_usec()
	_update(delta)
	cost_usec += Time.get_ticks_usec() - t0


func _update(delta: float) -> void:
	_dt += delta
	_skip += 1
	if _skip < pose_every and want == mode:
		_place()
		return
	_skip = 0
	var dt := minf(_dt, 0.1)
	_dt = 0.0
	var pose := {}
	var body_pose := {}
	if want != "move":
		_read_game()
		pose = reader.read()
		if want == "upper":
			var up := {}
			for b in ARMS:
				if pose.has(b):
					up[b] = pose[b]
			pose = up
		elif want == "carry":
			# The arms holding the ball as the game's hold it, in the body (the capture's chest leans otherwise).
			body_pose = reader.body_space(ARMS)
			pose = {}
		else:
			# The hips where the game's are (in this body's space): every joint then lies on the game's.
			pose["@hips"] = (proxy.get_bone_pose_position(0) - _shift) * _k - (body.joints["Hips"] as Vector3)
			_legs(pose)
	legacy.set_pose(pose)
	legacy.body_pose = body_pose
	if want != mode:
		var w := 0.0 if want == "move" else 1.0
		if mode == "":
			legacy.weight = w      # (a new body starts as it is asked: no blend in from nothing)
		legacy.fade_to(w, FADE_IN if want == "full" else FADE)
		if mode == "" or want == "move" or want == "carry":
			loco.planter.reset()
		mode = want
	body.visible = true
	# Put somewhere new (a change of ends): the feet are not held where they were.
	var here := gb.global_position
	if _at != Vector3.INF and here.distance_to(_at) > 1.5:
		loco.planter.reset()
	_at = here
	# The capture runs under the game's pose only while it shows (a body wholly the game's skips it: the CPU); its
	# planter holds the feet only under the capture, its head turns to what he watches only there.
	loco.planter.enabled = mode != "full"
	# (Wholly the game's: the planter not run at all - even let go it keeps an ankle off its floor by IK, on this
	# body's ankle height, which bent the game's legs by up to 10 cm - nor its lift, the hips exactly the game's.)
	var whole := mode == "full" and legacy.weight >= 1.0
	loco.planter.active = not whole
	legacy.lift_after = 0.0 if whole else loco.planter.hips_offset
	for m in [loco.look, loco.look_chest]:
		if m:
			m.active = mode != "full"
	if mode != "full":
		loco.look_at_point(look if look.is_finite() else null)
	if mode != "full" or legacy.weight < 1.0 or _pw < 1.0:
		loco.drive(dt, Vector3(vel.x, 0.0, vel.z), yaw)
	else:
		loco.yaw = yaw
	var to := 1.0 if mode in ["full", "upper"] else 0.0
	_pw = to if _pw < 0.0 else move_toward(_pw, to, dt / (FADE_IN if mode == "full" else FADE))
	_place()
	body.advance(dt)


## The legs laid where the game's are, each knee bending about its own hinge (the game's shin may twist and roll a
## little; the rig's knee is a hinge, and its drivers would straighten one bent off it): each thigh turned so its
## hinge is square to the plane of the game's thigh and shin, the shin bending in it, the foot turned as the game's.
const LEGS := {"Left": ["thigh_l", "shin_l", "foot_l"], "Right": ["thigh_r", "shin_r", "foot_r"]}


func _legs(pose: Dictionary) -> void:
	var g: Dictionary = reader._last_global
	if not g.has("Hips"):
		return
	for side in LEGS:
		var n: Array = LEGS[side]
		var hip := proxy.get_bone_global_pose(proxy.find_bone(n[0])).origin
		var knee := proxy.get_bone_global_pose(proxy.find_bone(n[1])).origin
		var ankle := proxy.get_bone_global_pose(proxy.find_bone(n[2])).origin
		var u := (knee - hip).normalized()
		var sd := (ankle - knee).normalized()
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
			pose[side + "ToeBase"] = Quaternion.IDENTITY


## Where the body stands: under the game's pose exactly over the game's body (the same mesh: each joint on the
## game's); under the capture at his place, turned as the capture turns him; between the two as one fades to the
## other.
func _place() -> void:
	var gx := gb.skeleton.global_transform
	var s := gx.basis.get_scale().x / _k
	var free := Transform3D(Basis(Vector3.UP, loco.yaw).scaled(Vector3.ONE * s), gb.global_position)
	var w := smoothstep(0.0, 1.0, clampf(_pw, 0.0, 1.0))
	if w <= 0.0:
		body.global_transform = free
	else:
		var exact := gx * Transform3D(Basis.from_scale(Vector3.ONE / _k), _shift)
		body.global_transform = exact if w >= 1.0 else free.interpolate_with(exact, w)
		if w >= 1.0:
			loco.yaw = exact.basis.orthonormalized().get_euler().y
	if flag:
		flag.global_transform = body.global_transform * _flag_rel


## Once the skeleton has its final pose (during the frame Godot reports the bones without the modifiers): where the
## palms are (the ball in his hands is drawn there) and the flag in his fist, in the body's frame.
func _on_posed() -> void:
	var inv := body.global_transform.affine_inverse()
	for s in ["l", "r"]:
		var side := "Left" if s == "l" else "Right"
		var hand := body.bone_world(side + "Hand").origin
		var fore := body.bone_world(side + "ForeArm").origin
		palms[s] = inv * (hand + (hand - fore).normalized() * 0.07)
	if carry_ball and is_instance_valid(carry_ball):
		carry_ball.draw_at(ball_point(carry_two))
	if flag:
		var hand := body.bone_world("RightHand").origin
		var along := (hand - body.bone_world("RightForeArm").origin).normalized()
		var out := body.global_transform.basis.x.normalized()
		out = (out - along * out.dot(along)).normalized()
		if out.is_finite() and out.length() > 0.5:
			_flag_rel = inv * Transform3D(Basis(out, along, out.cross(along)), hand + along * 0.06)
			flag.global_transform = body.global_transform * _flag_rel
	if measure:
		_measure()
	if legacy.t0 > 0:
		var c := Time.get_ticks_usec() - legacy.t0
		cost_usec += c
		cost_mods_usec += c
		legacy.t0 = 0


## Where the drawn hands hold the ball (world): between the palms, or in the right one; INF before the first pose.
func ball_point(two: bool) -> Vector3:
	if not palms.has("r") or not body.visible:
		return Vector3.INF
	var r: Vector3 = palms.r
	var p: Vector3 = (r + (palms.l as Vector3)) * 0.5 if two else r
	return body.global_transform * p


# ---------------------------------------------------------------- measured (tests, the stills tool)

## Set: each pose keeps where this body's joints were drawn (in last), measured once the skeleton has its final pose.
var measure := false
var last := {}
const MEASURED := ["Hips", "Spine2", "Head", "LeftHand", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
	"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]


func _measure() -> void:
	for b in MEASURED:
		last[b] = body.bone_world(b).origin
	for b in ["LeftFoot", "RightFoot", "Head"]:
		last[b + "@"] = body.bone_world(b)
	last["mode"] = mode
	last["w"] = legacy.weight
	last["pw"] = _pw
	last["frame"] = Engine.get_process_frames()


## Where a part that meets the ball is (tools/models/fbx_to_move.gd's: the instep 55% of the way from the ankle to
## the toe joint, the top of the head 12 cm over its joint), on the game's body now and on this one as last drawn - the
## same point of the same mesh on both (held in the bone's frame from the pose rest, the rig's rest found by the same
## turn from the game's). part: "instep_l", "instep_r", "head". [game, drawn] (world).
func contact_points(part: String) -> Array:
	var r := RealBody.rig(gb.women)
	var bone: String = {"instep_l": "LeftFoot", "instep_r": "RightFoot", "head": "Head"}[part]
	var b: int = r.index[bone]
	if not _anchors.has(part):
		r.solve({"plant": 0.0})
		var at: Vector3 = r.out_pos[b]
		var p: Vector3 = at + Vector3(0, 0.12, 0)
		if part != "head":
			p = at.lerp(r.out_pos[r.index[bone.replace("Foot", "ToeBase")]], 0.55)
		# The point in the game bone's frame at the pose rest (the skeleton's units), and on this body's rest (its
		# bone's rest turn is the identity) from that bone's joint.
		var rest := Transform3D(r.rest_put[b], at / r.unit)
		_anchors[part] = [rest.affine_inverse() * (p / r.unit), (p / r.unit - _shift) * _k - (body.joints[bone] as Vector3)]
	var a: Array = _anchors[part]
	var game: Vector3 = gb.skeleton.global_transform * (gb.skeleton.get_bone_global_pose(b) * (a[0] as Vector3))
	var x: Transform3D = last.get(bone + "@", Transform3D())
	return [game, x * (a[1] as Vector3)]


var _anchors := {}


## The game body's joint (a Mixamo name: "RightFoot") in the world against this body's as last drawn.
func joint_gap(bone: String) -> float:
	return game_joint(bone).distance_to(last.get(bone, Vector3.INF))


func game_joint(bone: String) -> Vector3:
	var r := RealBody.rig(gb.women)
	return gb.skeleton.global_transform * gb.skeleton.get_bone_global_pose(int(r.index[bone])).origin


## The game's pose over the capture (WsgPoseLayer), noting when it ran (its time counted in cost_usec).
class Layer extends WsgPoseLayer:
	var ran := -1
	var t0 := 0

	func _process_modification_with_delta(delta: float) -> void:
		ran = Engine.get_process_frames()
		t0 = Time.get_ticks_usec()
		super(delta)
