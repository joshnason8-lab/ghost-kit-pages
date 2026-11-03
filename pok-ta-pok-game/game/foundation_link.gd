class_name FoundationLink
extends Node3D
## A player or a judge (veedor) drawn with the World Stage Games foundation (addons/wsg_foundation): the same Meshy
## body the game draws (assets/people/: the lean, tall and stocky players, the judge), baked onto the shared rig
## (assets/foundation/), in the same textured, skin-tinted material, with the game's own gear (the faja in the team's
## colour, the chimali, the classic court's yoke, knee pad and wrist wrap, a judge's straw hat) on its bones.
##
## Every pok ta pok action stays the game's (game/moves.gd), laid on the rig exactly (WsgLegacyPose reads the game's
## own 17-bone skeleton, Body): the ready stance, the hip strike, the dive, the serve's toss, the celebrations, the
## arms raised to the copal's smoke, the judges' calls. Its legs are rebuilt to put the feet where the game's are
## (the rig's legs are a little shorter than the game's code skeleton's), its hips where the game's are. The motion
## capture draws only what the game walked or ran by hand: a player running or walking to his place, and the judges
## standing at ease, watching the ball (their calls the game's arms over it).
##
## The game's body stays the game's: Player and Officials still pose it every frame and everything the match measures
## off it (the hip that meets the ball, the hand that holds it) is unchanged; only its drawing goes. Medium and High
## only, in a match: Low draws the game's own bodies exactly as before (tests/test_runner). Without the licensed clip
## library (a fork's build, CI without the secret) nobody has a link, and the game is as it was.

const DIR := "res://assets/foundation/"
const ARMS := ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]
const FADE := 0.22        # s from the game's pose to the motion capture and back
const FADE_IN := 0.1      # s into one of the game's own moves (a strike, a dive): its timing is the game's
## The game's bones and the rig's (WsgLegacyPose.MAP).
const MAP := WsgLegacyPose.MAP

## Set by the tests that are not about drawing (tests/test_runner.gd): their matches run as a build without the
## licensed clips would (CI's), in the time CI allows.
static var off := false
## In a match (Match sets it; not the home screen's match behind the menus).
static var in_match := false
## A replay is playing: the bodies show what WsgReplay kept, not the game.
static var frozen := false
## Microseconds all the foundation's work has taken (the links' updates and their skeletons' modifiers): tests.
static var cost_usec := 0
static var cost_mods_usec := 0


static func _static_init() -> void:
	# Pok Ta Pok is a budget game (WsgFoundation: GL Compatibility, Low on an ordinary phone, full detail nearest).
	WsgFoundation.profile = "budget"


## Whether bodies made now are drawn by the foundation: in a match, the licensed clips in this build, and the
## graphics Medium or High (Low keeps the game's own bodies).
static func enabled() -> bool:
	return not off and in_match and int(Game.settings.graphics) > Game.GFX_LOW and WsgClips.available() \
		and not OS.has_environment("WSG_OFF")


## The model baked onto the rig (assets/foundation/<file>_rig.json).
static func has_model(file: String) -> bool:
	return ResourceLoader.exists(DIR + file + "_rig.json")


var gb: Body                 # the game's body (posed by the game, not drawn)
var file := ""
var kind := "player"         # player, judge
## What the owner (Player, Officials) asks for this frame: "full" (the game's whole pose), "upper" (its arms over the
## capture), "move" (the capture).
var want := "full"
var vel := Vector3.ZERO      # where he is going (world, m/s)
var want_vel := Vector3.INF  # where he is asked to go (world, m/s): a start picks its gait by it, a sharp change cuts
var yaw := 0.0               # where he faces (world yaw)
var look := Vector3.INF      # what his head is on under the capture (INF: where he goes)
var body: WsgBody
var loco: WsgLocomotor
var legacy: Layer
var reader: WsgLegacyPose
var gear: MeshInstance3D     # the game's gear, skinned to this body's bones
var mode := ""
var pose_every := 1          # posed every frame, or every 2nd or 3rd (Match._rank_detail)
## The ball in this body's right hand (the server holding it): drawn there once the skeleton has its final pose.
var hand_ball: Ball = null
var _skip := 0
var _dt := 0.0
var _hips_rest := Vector3.ZERO   # the game's hips at rest (Body.BONES)
var _at := Vector3.INF
var _pw := -1.0              # placed exactly over the game's body (1) or free at his place under the capture (0)
var _leg := {}               # side -> [thigh, shin] lengths (the rig's)
var _foot_up := 0.0          # the rig's ankle over its soles less the game's (m)
var _gear_mid := {}           # game bone index -> the middle of the gear's part on it (the game's skeleton's space)


func _init(p_body: Body, p_file: String) -> void:
	gb = p_body
	file = p_file
	kind = "judge" if String(gb.look.get("kind", "")) == "judge" else "player"
	name = "Foundation"
	top_level = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var lod := 0 if int(Game.settings.graphics) >= Game.GFX_HIGH else 1
	body = WsgBody.new(WsgBody.load_character(DIR, file), RiggedBody.make_material(file, gb.look, true), lod)
	add_child(body)
	body.set_manual(true)
	body.visible = false        # till its first pose
	body.mesh_instance.cast_shadow = gb.mesh_instance.cast_shadow
	var j := body.joints
	_hips_rest = Body.BONES[0][2]
	for side in ["Left", "Right"]:
		_leg[side] = [(j[side + "UpLeg"] as Vector3).distance_to(j[side + "Leg"]), (j[side + "Leg"] as Vector3).distance_to(j[side + "Foot"])]
	_foot_up = (j["LeftFoot"] as Vector3).y - (gb.skeleton.get_bone_global_rest(gb.bone("foot_l")).origin.y)
	legacy = Layer.new()
	legacy.name = "Legacy"
	body.skeleton.add_child(legacy)
	body.skeleton.move_child(legacy, 0)
	reader = WsgLegacyPose.new(gb.skeleton, j)
	legacy.arms = reader
	legacy.torso_r = 0.08       # the forearms kept out of the chest
	loco = WsgLocomotor.attach(body)
	# Its own dice for the idle's fidgets (the foundation's opt-in since 79b346e; this game's pilot had it built in):
	# the global ones are the game's, and a seeded match must play the same with the foundation as without it.
	loco.rng = RandomNumberGenerator.new()
	# The strides for this body's legs in the world: the locomotor reads the rig's leg, not the body node's scale (a
	# player is drawn at his own height, Body.scale: a 1.62 m man's strides were a tenth too long, his feet dragged).
	# Its hips' lift and its root motion stay in the skeleton's own space.
	loco.leg_scale *= gb.scale.x
	legacy.lift_after = loco.planter.hips_offset
	# The rig's feet flat (the foundation's WsgFootFlat, b073334): the stocky player's model rests 3.4 degrees toe-up
	# and the judge's 6.3, which showed in every move; the lean and the tall stand flat and get none. The last of the
	# skeleton's modifiers.
	WsgFootFlat.attach(body)
	_make_gear()
	gb.mesh_instance.visible = false
	body.posed.connect(_on_posed)


## The game's own body drawn again and this one gone (the graphics lowered to Low mid-match: Body.unlink).
func release() -> void:
	queue_free()


# ---------------------------------------------------------------- the gear

## The game's gear (Body's gear-only mesh, skinned to the game's 17 bones) skinned to this body's bones instead: each
## game bone's part bound to the rig bone it moves (WsgLegacyPose.MAP), where that bone lies when the game's body is
## at rest. The faja, chimali and yoke ride the drawn hips, the hat the drawn head, the knee pad the drawn knee and the
## wrist wrap the drawn wrist, under the game's pose and the motion capture alike.
func _make_gear() -> void:
	var mesh: Mesh = gb.mesh_instance.mesh
	if mesh == null or mesh.get_surface_count() == 0:
		return
	# The rig posed as the game's body is at rest (every bone's turn the identity: its body was just built).
	var rest := reader.read()
	var sk := body.skeleton
	for b in rest:
		if b.begins_with("@"):
			continue
		var i := sk.find_bone(b)
		if i >= 0:
			sk.set_bone_pose_rotation(i, rest[b])
	var skin := Skin.new()
	for g in Body.BONES:
		var gname: String = g[0]
		var rig: String = MAP[gname]
		var at := sk.get_bone_global_pose(sk.find_bone(rig))
		# A part on a limb is carried to the rig's own joint (its knee, its wrist: the rig's limbs are a little shorter
		# than the game's); the trunk's and the head's keep the place they have on the model at rest.
		var shift := Vector3.ZERO
		match gname:
			"shin_l", "shin_r":
				shift = at.origin - gb.skeleton.get_bone_global_rest(gb.bone(gname)).origin
			"forearm_l", "forearm_r":
				var hand: String = gname.replace("forearm", "hand")
				shift = sk.get_bone_global_pose(sk.find_bone(MAP[hand])).origin - gb.skeleton.get_bone_global_rest(gb.bone(hand)).origin
		skin.add_named_bind(rig, at.affine_inverse() * Transform3D(Basis.IDENTITY, shift))
	sk.reset_bone_poses()
	var arr := mesh.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var n := {}
	for i in vs.size():
		var b := bs[i * 4]
		_gear_mid[b] = (_gear_mid.get(b, Vector3.ZERO) as Vector3) + vs[i]
		n[b] = int(n.get(b, 0)) + 1
	for b in _gear_mid:
		_gear_mid[b] /= float(n[b])
	gear = MeshInstance3D.new()
	gear.name = "Gear"
	gear.mesh = mesh
	gear.material_override = gb.mesh_instance.material_override
	gear.cast_shadow = gb.mesh_instance.cast_shadow
	gear.skin = skin
	sk.add_child(gear)
	gear.skeleton = NodePath("..")


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
	if want != "move":
		pose = reader.read()
		if want == "upper":
			var up := {}
			for b in ARMS:
				if pose.has(b):
					up[b] = pose[b]
			pose = up
		else:
			# The hips where the game's are; the legs reaching the game's feet.
			pose["@hips"] = gb.skeleton.get_bone_pose_position(0) - _hips_rest
			_legs(pose)
	legacy.set_pose(pose)
	if want != mode:
		var w := 0.0 if want == "move" else 1.0
		if mode == "":
			legacy.weight = w      # (a new body starts as it is asked: no blend in from nothing)
		legacy.fade_to(w, FADE_IN if want == "full" else FADE)
		if mode == "" or want == "move":
			loco.planter.reset()
		mode = want
	body.visible = true
	# Put somewhere new: the feet are not held where they were.
	var here := gb.global_position
	if _at != Vector3.INF and here.distance_to(_at) > 1.5:
		loco.planter.reset()
	_at = here
	loco.planter.ground_y = here.y
	loco.planter.enabled = mode != "full"
	# Wholly the game's: the planter not run at all (even let go it keeps an ankle off its floor by IK, which bent the
	# game's legs: Sepak Takraw's pilot), nor its lift - the hips exactly the game's.
	var whole := mode == "full" and legacy.weight >= 1.0
	loco.planter.active = not whole
	legacy.lift_after = 0.0 if whole else loco.planter.hips_offset
	for m in [loco.look, loco.look_chest]:
		if m:
			m.active = mode != "full"
	if mode != "full":
		loco.look_at_point(look if look.is_finite() else null)
	if mode != "full" or legacy.weight < 1.0 or _pw < 1.0:
		loco.drive(dt, Vector3(vel.x, 0.0, vel.z), yaw, want_vel)
	else:
		loco.yaw = yaw
	var to := 1.0 if mode in ["full", "upper"] else 0.0
	_pw = to if _pw < 0.0 else move_toward(_pw, to, dt / (FADE_IN if mode == "full" else FADE))
	_place()
	body.advance(dt)


const LEGS := {"Left": ["thigh_l", "shin_l", "foot_l"], "Right": ["thigh_r", "shin_r", "foot_r"]}


## The legs from where the game's are: each ankle where the game's ankle is (lifted by the rig's taller ankle, turned
## with the game's foot: the soles on the same ground), the knee bent forward in the plane of the game's thigh and
## shin, about its own hinge (the rig's knee is a hinge, and its drivers would straighten one bent off it), the foot
## turned as the game's.
func _legs(pose: Dictionary) -> void:
	var g: Dictionary = reader._last_global
	if not g.has("Hips"):
		return
	var gs := gb.skeleton
	var j := body.joints
	var hips_q: Quaternion = g["Hips"]
	var hips_at: Vector3 = (j["Hips"] as Vector3) + (pose["@hips"] as Vector3)
	for side in LEGS:
		var n: Array = LEGS[side]
		var gh := gs.get_bone_global_pose(gb.bone(n[0])).origin
		var gk := gs.get_bone_global_pose(gb.bone(n[1])).origin
		var gf := gs.get_bone_global_pose(gb.bone(n[2]))
		var hip := hips_at + hips_q * ((j[side + "UpLeg"] as Vector3) - (j["Hips"] as Vector3))
		var ankle := gf.origin + gf.basis.orthonormalized() * Vector3(0, _foot_up, 0)
		var l1: float = _leg[side][0]
		var l2: float = _leg[side][1]
		var to := ankle - hip
		var d := clampf(to.length(), absf(l1 - l2) + 0.01, (l1 + l2) * 0.9995)
		var dir := to.normalized() if to.length() > 1e-5 else Vector3.DOWN
		# The way the knee goes: the game's knee off the line from its hip to its ankle, else forward.
		var ga := gf.origin - gh
		var bend := (gk - gh) - ga.normalized() * (gk - gh).dot(ga.normalized()) if ga.length() > 1e-5 else Vector3.ZERO
		if bend.length() < 0.01:
			bend = hips_q * Vector3.BACK
		bend = (bend - dir * bend.dot(dir)).normalized()
		var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var knee := hip + dir * a + bend * sqrt(maxf(0.0, l1 * l1 - a * a))
		var u := (knee - hip).normalized()
		var sd := (hip + dir * d - knee).normalized()
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
		pose[side + "UpLeg"] = (hips_q.inverse() * qt).normalized()
		pose[side + "Leg"] = (qt.inverse() * qs).normalized()
		if g.has(side + "Foot"):
			pose[side + "Foot"] = (qs.inverse() * (g[side + "Foot"] as Quaternion)).normalized()
			pose[side + "ToeBase"] = Quaternion.IDENTITY


## Where the body stands: under the game's pose exactly on the game's body (the same model, at the same size: the
## game's skeleton's space is the rig's); under the capture at his place, turned as the capture turns him; between
## the two as one fades to the other.
func _place() -> void:
	var gx := gb.skeleton.global_transform
	var s := gx.basis.get_scale().x
	var free := Transform3D(Basis(Vector3.UP, loco.yaw).scaled(Vector3.ONE * s), gb.global_position)
	var w := smoothstep(0.0, 1.0, clampf(_pw, 0.0, 1.0))
	if w <= 0.0:
		body.global_transform = free
	else:
		body.global_transform = gx if w >= 1.0 else free.interpolate_with(gx, w)
		if w >= 1.0:
			loco.yaw = gx.basis.orthonormalized().get_euler().y


## Once the skeleton has its final pose (during the frame Godot reports the bones without the modifiers): the ball
## in the drawn hand, and the measures the tests take.
func _on_posed() -> void:
	if hand_ball and is_instance_valid(hand_ball):
		hand_ball.draw_at(palm_ball())
	if measure:
		_measure()
	if legacy.t0 > 0:
		var c := Time.get_ticks_usec() - legacy.t0
		cost_usec += c
		cost_mods_usec += c
		legacy.t0 = 0


## Where the ball sits in the drawn right hand (world): on the palm (the rig's palm faces down in its rest, the hand
## along -X), a ball's radius off it.
func palm_ball() -> Vector3:
	var h := body.bone_world("RightHand")
	var s := body.global_transform.basis.get_scale().x
	return h.origin + (h.basis.orthonormalized() * Vector3(-0.075, -(Ball.RADIUS + 0.02), 0.0)) * s


# ---------------------------------------------------------------- measured (tests, the stills tool)

## Set: each pose keeps where this body's joints were drawn (in last), measured once the skeleton has its final pose.
var measure := false
var last := {}
const MEASURED := ["Hips", "Spine2", "Head", "LeftHand", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
	"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase", "RightForeArm"]


func _measure() -> void:
	for b in MEASURED:
		last[b] = body.bone_world(b).origin
	for b in ["Hips", "LeftFoot", "RightFoot", "Head", "RightLeg", "RightForeArm"]:
		last[b + "@"] = body.bone_world(b)
	# The game's body as it is at the same moment (the drawn pose is laid when the skeleton updates).
	for g in MAP:
		last["game:" + g] = gb.bone_world(g)
	for side in [1.0, -1.0]:
		last["game_hip%d" % int(side)] = gb.hip_world(side)
		last["drawn_hip%d" % int(side)] = drawn_hip(side)
	if gear:
		# Each part of the gear as drawn (its middle, skinned to this skeleton as the GPU does): "gear:hips" etc.
		var sk := body.skeleton
		for b in _gear_mid:
			var bi := sk.find_bone(gear.skin.get_bind_name(b))
			last["gear:" + String(Body.BONES[b][0])] = sk.global_transform * (sk.get_bone_global_pose(bi) * (gear.skin.get_bind_pose(b) * (_gear_mid[b] as Vector3)))
	last["mode"] = mode
	last["w"] = legacy.weight
	last["pw"] = _pw
	last["frame"] = Engine.get_process_frames()


## The outside of a hip (side 1 the left, -1 the right) on the drawn body as last drawn (world): the same point of the
## same model as Body.hip_world takes on the game's body (the game's hips' offset to it, from the model at rest).
func drawn_hip(side: float) -> Vector3:
	var x: Transform3D = last.get("Hips@", Transform3D())
	var p := _hips_rest + Vector3(0.17 * side, -0.06, -0.02) - (body.joints["Hips"] as Vector3)
	return x * p


## The game body's joint (17-bone name: "foot_r") in the world against this body's (its rig bone) as last drawn.
func joint_gap(game_bone: String) -> float:
	return (last.get("game:" + game_bone, Vector3.INF) as Vector3).distance_to(last.get(MAP[game_bone], Vector3.INF))


## The outside of the hip (side 1 left, -1 right) on the game's body and on the drawn one, as last drawn: their gap.
func hip_gap(side: float) -> float:
	return (last.get("game_hip%d" % int(side), Vector3.INF) as Vector3).distance_to(last.get("drawn_hip%d" % int(side), Vector3.INF))


## The game's pose over the capture (WsgPoseLayer), noting when it ran (its time counted in cost_usec).
class Layer extends WsgPoseLayer:
	var ran := -1
	var t0 := 0

	func _process_modification_with_delta(delta: float) -> void:
		ran = Engine.get_process_frames()
		t0 = Time.get_ticks_usec()
		super(delta)
