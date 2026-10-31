class_name FoundationLink
extends Node3D
## A kho kho player or official drawn with the World Stage Games shared foundation (addons/wsg_foundation): the
## owner's athlete (assets/models/player.glb's full mesh, baked onto the shared rig by tools/models/bake_foundation.sh:
## assets/foundation/player_*) in his own kit (ModelBody's shader and material, the same texture), moved by:
##   - the motion capture (WsgLocomotor: MoCap Online Mobility walks, jogs, runs, starts, stops, turns and cuts, the
##     ActorCore sprint) wherever a player or umpire is simply getting about - a chaser running his lane or round to the
##     next square, a defender running, side-stepping and backing off, an umpire walking his line, anyone standing;
##   - the game's own pose, laid exactly over the rig (every joint where ModelBody's skeleton has it, after its own
##     modifiers: the dive, the head turn, the hands on the pole), for everything kho kho does by hand or by its own
##     clips: the dive and the pole dive, lying and getting up, the pole turn, the kho, kneeling in the squares and
##     rising, the reach for a touch, the dodge, the officials' whistle and signals;
##   - the game's reaching arm over the capture's legs for a touch or a kho made on the run.
## The game's body (ModelBody) stays the game's: Athlete still poses it every frame and everything measured off it
## (the dive's lowest point, the clip playing) is unchanged; only its mesh is no longer drawn.
## Medium and High only, in a match: Low draws the game's own bodies exactly as before (tests/test_runner). Without the
## licensed clip library (a fork's build, CI without the secret) nobody has a link, and the game is as it was.

const DIR := "res://assets/foundation/"
const PREFIX := "player"
const FADE := 0.22
## Into and out of a quick act of the game's (a kho, a dodge, a reach on the run, the pole turn): the capture gives way
## faster, so the act's own timing shows.
const QUICK := 0.1
## The acts the game draws itself (its pose on the whole body); "" is the capture's.
const FULL := ["sit", "rise", "kho", "reach", "dive", "pole_dive", "lie", "getup", "whistle", "out", "foul", "end", "cheer",
	"dodge", "pole_turn"]
const QUICK_ACTS := ["kho", "reach", "dodge", "pole_turn"]
## The reaching arm (a touch or a kho on the run: ModelBody's Grip turns the right arm to it).
const ARM := ["RightShoulder", "RightArm", "RightForeArm", "RightHand"]
## The game skeleton's bones and the rig's: the same names (Mixamo's), without the prefix.
const BONES := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
	"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]

var who: Athlete
var gb: ModelBody             # the game's body (posed by the game, not drawn)
var body: WsgBody
var loco: WsgLocomotor
var layer: Layer
var mode := ""                # "full" (the game's pose), "upper" (its reaching arm over the capture), "move" (the capture)
var pose_every := 1           # posed every frame, or every 2nd or 3rd (far from the camera: Match._rank_detail)
var _skip := 0
var _dt := 0.0
var _frame := -1
var _last_pos := Vector3.INF
var _act_was := ""
var _pole_shift := Vector3.ZERO   # drawn nearer the pole in a pole turn, while his near arm could not reach it

## Set by the tests that are not about drawing (tests/test_runner.gd): their matches run as a build without the
## licensed clips would (CI's), in the time CI allows.
static var off := false
## In a match (Match sets it; not the home screen's match behind the menus, nor the menus' figures).
static var in_match := false
## The replay is playing: the bodies show what WsgReplay kept, not the game.
static var frozen := false
## The match is paused: the bodies hold still.
static var paused := false
## Microseconds every body's foundation work has taken (its update here, and its skeleton's modifiers: the game's pose
## laid on, the drivers, the helpers), all told (tests/foundation_cpu).
static var cost_usec := 0


## Kho kho is a budget game (WsgFoundation: GL Compatibility always; the game's own first-run choice puts a Galaxy
## A16 on Low).
static func _static_init() -> void:
	WsgFoundation.profile = "budget"


## Whether bodies made now are drawn by the foundation: in a match, the graphics Medium or High (Low keeps the game's
## own bodies: nothing of the foundation is even loaded), the licensed clips and the baked body in this build.
static func enabled() -> bool:
	return not off and in_match and int(Game.settings.graphics) > Game.GFX_LOW and not OS.has_environment("WSG_OFF") \
		and ResourceLoader.exists(DIR + PREFIX + "_rig.json") and WsgClips.available()


func _init(p_who: Athlete) -> void:
	who = p_who
	gb = p_who.body
	name = "Foundation"
	top_level = true
	# (The replay plays with the athletes stopped: the bodies go on being drawn.)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	body = WsgBody.new(WsgBody.load_character(DIR, PREFIX), null, 0)
	add_child(body)
	body.set_manual(true)
	body.visible = false        # till its first pose
	_map(gb.skeleton, body.character)
	# His kit: ModelBody's own material (the shirt, shorts and skin recoloured on the model's texture), on the same UVs.
	body.mesh_instance.material_override = ModelBody.material(gb.look, false)
	body.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # (the game's blob shadows)
	layer = Layer.new()
	layer.name = "GamePose"
	layer.joints = body.joints
	layer.arms = _arm_maker(body.joints)
	body.skeleton.add_child(layer)
	body.skeleton.move_child(layer, 0)
	loco = WsgLocomotor.attach(body)
	layer.lift_after = loco.planter.hips_offset
	gb.mesh.visible = false
	# The game's skeleton has its final pose (the clips, then its own dive, head turn and grip) once its update has
	# run: this body is posed from it then, in the same frame.
	gb.skeleton.skeleton_updated.connect(_on_game_posed)
	body.posed.connect(_posed)


## The game's own body drawn again and this one gone (the graphics lowered to Low mid-match).
func release() -> void:
	if is_instance_valid(gb):
		gb.mesh.visible = true
		if gb.skeleton.skeleton_updated.is_connected(_on_game_posed):
			gb.skeleton.skeleton_updated.disconnect(_on_game_posed)
	if who and is_instance_valid(who):
		who.link = null
	queue_free()


# ---------------------------------------------------------------- the game's skeleton on the rig

## Shared by every body (one model): for each rig bone, the game's bone and the turn that takes the game bone's frame
## onto the rig's (the bake's own: tools/wsg/bake_character.gd poses the model into the rig's T - arms and legs
## straightened, the feet as modelled, the hands turned palm down - so the same mesh lies on both); the bake's scale
## and offset; the game skeleton's place in ModelBody.
static var _gix := {}          # rig bone -> game bone index
static var _to_rig := {}       # rig bone -> Quaternion: game bone global turn * this = the rig bone's
static var _k := 1.0           # rig metres per skeleton unit
static var _shift := Vector3.ZERO   # the skeleton point at the rig's origin (the bake's shift)
static var _in_model := Transform3D()   # the skeleton's space in ModelBody's (the GLB's nodes)
static var _rig_to_model := Transform3D()


static func _map(gs: Skeleton3D, ch: Dictionary) -> void:
	if not _gix.is_empty():
		return
	for b in gs.get_bone_count():
		var n := gs.get_bone_name(b).trim_prefix("mixamorig_").trim_prefix("mixamorig:")
		if n in BONES and not _gix.has(n):
			_gix[n] = b
	var by := {}
	for n in _gix:
		by[_gix[n]] = n
	# The bake's stance (bake_character.gd _pose_stance): upper and lower limbs straight out along the T, the feet
	# as modelled, everything else following its parent.
	var straight := {"LeftArm": ["LeftForeArm", Vector3.RIGHT], "LeftForeArm": ["LeftHand", Vector3.RIGHT],
		"RightArm": ["RightForeArm", Vector3.LEFT], "RightForeArm": ["RightHand", Vector3.LEFT],
		"LeftUpLeg": ["LeftLeg", Vector3.DOWN], "LeftLeg": ["LeftFoot", Vector3.DOWN],
		"RightUpLeg": ["RightLeg", Vector3.DOWN], "RightLeg": ["RightFoot", Vector3.DOWN]}
	var stance := []
	for b in gs.get_bone_count():
		var par := gs.get_bone_parent(b)
		var t: Transform3D = (stance[par] * gs.get_bone_rest(b)) if par >= 0 else gs.get_bone_rest(b)
		var nm: String = by.get(b, "")
		if straight.has(nm):
			var c: int = _gix[straight[nm][0]]
			var dir := (t * gs.get_bone_rest(c).origin - t.origin).normalized()
			t.basis = Basis(Quaternion(dir, straight[nm][1])) * t.basis
		elif nm in ["LeftFoot", "RightFoot"]:
			t.basis = gs.get_bone_global_rest(b).basis
		stance.append(t)
	var report: Dictionary = ch.get("report", {})
	for n in _gix:
		var s := stance[_gix[n]] as Transform3D
		var q := s.basis.get_rotation_quaternion()
		if n in ["LeftHand", "RightHand"]:
			# The bake turned each hand about the forearm so its palm faces down (report: <side>_palm_tilt_deg).
			var ang := deg_to_rad(float(report.get(n.trim_suffix("Hand") + "_palm_tilt_deg", 0.0)))
			if absf(ang) >= deg_to_rad(4.0):
				q = Quaternion(Vector3.RIGHT, -ang) * q
		_to_rig[n] = q.inverse()
	# Scale and offset: the rig's joints are the stance's, less the shift, times k.
	var j: Dictionary = ch.joints
	var sh := (stance[_gix["Hips"]] as Transform3D).origin
	var hd := (stance[_gix["Head"]] as Transform3D).origin
	_k = (j["Hips"] as Vector3).distance_to(j["Head"]) / maxf(sh.distance_to(hd), 1e-4)
	_shift = sh - (j["Hips"] as Vector3) / _k
	# The skeleton in ModelBody's space: the GLB's nodes between them (its root, the armature's 0.01).
	var xf := Transform3D()
	var n: Node = gs
	while n and not (n is ModelBody):
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	_in_model = xf
	_rig_to_model = _in_model * Transform3D(Basis.from_scale(Vector3.ONE / _k), _shift)


## Each rig bone's turn (skeleton space) as the game's skeleton now has it, mirrored when the game plays an act
## mirrored (ModelBody's x scale): the rig's left bone takes the game's right turned through the mirror. Also the hips'
## place, in the rig's space.
func _read(bones: Array) -> Dictionary:
	var gs := gb.skeleton
	var mirrored := gb.scale.x < 0.0
	var out := {}
	for n in bones:
		var src: String = n
		if mirrored:
			src = n.replace("Left", "#").replace("Right", "Left").replace("#", "Right")
		var q := gs.get_bone_global_pose(_gix[src]).basis.get_rotation_quaternion() * (_to_rig[src] as Quaternion)
		if mirrored:
			q = Quaternion(q.x, -q.y, -q.z, q.w)
		out[n] = q.normalized()
	var hp := gs.get_bone_global_pose(_gix["Hips"]).origin
	if mirrored:
		hp.x = -hp.x
	out["@at"] = (hp - _shift) * _k
	return out


## A game joint's place in the rig's space (mirrored as _read mirrors).
func _joint(n: String) -> Vector3:
	var src := n
	var mirrored := gb.scale.x < 0.0
	if mirrored:
		src = n.replace("Left", "#").replace("Right", "Left").replace("#", "Right")
	var p := gb.skeleton.get_bone_global_pose(_gix[src]).origin
	if mirrored:
		p.x = -p.x
	return (p - _shift) * _k


## The arms and legs laid through the game's own joints, each elbow and knee bending about the rig's hinge: the
## model's A-pose puts its elbows' hinge some 20 degrees round from the rig's (its palms were turned to the rig's
## palm-down), and turns copied bone by bone bent the rig's elbow off its hinge, which the rig's driver then put back
## on it - a hand on a knee moved 20 cm, the hands of a kneeling chaser crossed. Each upper arm and thigh is turned so
## its hinge is square to the plane of the game's limb; the forearm or shin bends in it; the hand and foot keep their
## turn in the body.
const LIMBS := {"LeftArm": ["LeftForeArm", "LeftHand", Vector3.RIGHT, Vector3.DOWN],
	"RightArm": ["RightForeArm", "RightHand", Vector3.LEFT, Vector3.UP],
	"LeftUpLeg": ["LeftLeg", "LeftFoot", Vector3.DOWN, Vector3.RIGHT],
	"RightUpLeg": ["RightLeg", "RightFoot", Vector3.DOWN, Vector3.RIGHT]}


func _limbs(g: Dictionary) -> void:
	for top in LIMBS:
		var spec: Array = LIMBS[top]
		var a0: Vector3 = spec[2]      # the bone's rest direction
		var h0: Vector3 = spec[3]      # its hinge (the rig driver's)
		var s := _joint(top)
		var e := _joint(spec[0])
		var w := _joint(spec[1])
		var u := (e - s).normalized()
		var f := (w - e).normalized()
		var h := u.cross(f)
		# Nearly straight: the hinge where the game's own turn has it.
		var own: Vector3 = (g[top] as Quaternion) * h0
		if h.length() < 0.05:
			h = own - u * own.dot(u)
		elif h.dot(own) < -0.5 * h.length():
			# (Bent the wrong way for a hinge - an elbow or knee past straight: the rig's driver keeps it straight.)
			h = -h
		h = h.normalized()
		var rest := Basis(a0, h0, a0.cross(h0))
		var want := Basis(u, h, u.cross(h))
		var q_top := (want * rest.inverse()).get_rotation_quaternion()
		var bend := u.signed_angle_to(f, h)
		var q_mid := Quaternion(h, bend) * q_top
		g[top] = q_top.normalized()
		g[spec[0]] = q_mid.normalized()


## The whole body as the game has it: local turns (each from its parent's), and the hips' offset from the rest.
func _full_pose() -> Dictionary:
	var g := _read(BONES)
	_limbs(g)
	var out := {}
	for n in BONES:
		var par := WsgRig.parent_name(n)
		out[n] = ((g[par] as Quaternion).inverse() * (g[n] as Quaternion)).normalized() if par != "" else g[n]
	out["@hips"] = (g["@at"] as Vector3) - (body.joints["Hips"] as Vector3)
	return out


## Where the game's body is drawn, as this body's transform: ModelBody's (its mirror taken out: the pose carries it).
func _exact() -> Transform3D:
	var g := gb.global_transform
	if g.basis.determinant() < 0.0:
		g.basis.x = -g.basis.x
	return g * _rig_to_model


# ---------------------------------------------------------------- each frame

## What draws him now: the game's whole pose, its reaching arm over the capture, or the capture.
func want_mode() -> String:
	var act := who.act
	if act in ["kho", "reach"] and Vector2(who.vel.x, who.vel.z).length() > 1.2:
		return "upper"
	return "full" if act in FULL else "move"


## The game's skeleton is posed for this frame (its skeleton_updated): drive this one.
func _on_game_posed() -> void:
	var f := Engine.get_process_frames()
	if f == _frame:
		return
	_frame = f
	if frozen or paused or not is_inside_tree() or not who.is_visible_in_tree():
		return
	var t0 := Time.get_ticks_usec()
	_update(get_process_delta_time())
	cost_usec += Time.get_ticks_usec() - t0
	if measure:
		var gs := gb.skeleton
		for b in MEASURED:
			var src: String = b
			if gb.scale.x < 0.0:
				src = b.replace("Left", "#").replace("Right", "Left").replace("#", "Right")
			game_last[b] = (gs.global_transform * gs.get_bone_global_pose(_gix[src])).origin


func _update(delta: float) -> void:
	_dt += delta
	_skip += 1
	var want := want_mode()
	# Put somewhere else (the next batch walking on, a restart): the feet let go at once.
	var jumped := _last_pos != Vector3.INF and who.global_position.distance_to(_last_pos) > 1.2
	_last_pos = who.global_position
	if _skip < pose_every and want == mode and not jumped:
		_place()
		return
	_skip = 0
	var dt := minf(_dt, 0.1)
	_dt = 0.0
	layer.pole = Vector3.INF
	if want == "full":
		layer.set_pose(_full_pose())
		layer.body_pose = {}
		# Round the pole: his hands on it (the game's grip point, its height).
		layer.pole = gb.grip if who.act == "pole_turn" and gb.grip != Vector3.INF and gb.grip_arms == 2 else Vector3.INF
		if layer.pole != Vector3.INF:
			for side in ["Left", "Right"]:
				body.grip(side, layer.pole_r)
	elif want == "upper":
		layer.set_pose({})
		layer.body_pose = _read(ARM)
		layer.body_pose.erase("@at")
	_pole_reach(dt)
	if want != mode:
		var w := 0.0 if want == "move" else 1.0
		var secs := QUICK if who.act in QUICK_ACTS or _act_was in QUICK_ACTS else FADE
		if mode == "":
			layer.weight = w      # (a new body starts as it is: no blend in from nothing)
		layer.fade_to(w, secs)
		if mode == "" or mode == "full":
			loco.planter.reset()
			# (Back to the capture: going as he goes now, not as he went before the game's pose.)
			if mode == "full":
				loco.resume(Vector3(who.vel.x, 0.0, who.vel.z), who.yaw)
		mode = want
	_act_was = who.act
	if jumped:
		loco.planter.reset()
	body.visible = true
	# The capture runs under the game's pose only while it shows (a body wholly the game's skips it: the CPU). The
	# planter holds the feet only under the capture: under the game's pose its feet are where the game puts them.
	loco.planter.enabled = mode != "full"
	# (Its floor - no ankle lower than a standing one's - is for the capture's feet: under the game's pose a kneeling
	# chaser's ankles lie lower, and the game's feet are kept exactly.)
	loco.planter.ground_y = -10.0 if mode == "full" else 0.0
	if mode == "full":
		# (Its holds let go: a foot held where it was last planted stayed there under the game's pose - its release
		# times out only on the locomotor's steps, which do not run under the game's pose.)
		loco.planter.reset()
		loco.planter.tick(dt)
	var looking := mode != "full" and who.watch != Vector3.INF
	for m in [loco.look, loco.look_chest]:
		if m:
			m.active = looking
	if mode != "full" or layer.weight < 1.0:
		# (Not the AI's wanted velocity: a kho kho chaser often wants to go where the direction rule does not let him,
		# and a cut begun for it never came round - the cut's clip crawled while he ran on: his feet glided.)
		loco.drive(dt, Vector3(who.vel.x, 0.0, who.vel.z), who.yaw)
		loco.look_at_point(who.watch + Vector3.UP * 0.4 if looking else null)
	else:
		loco.yaw = who.yaw
	_place()
	body.advance(dt)


## The game swings his middle round the pole on a 0.55 m circle (Athlete.pole_swing), as near as the rules' pace
## allows; leaning out on his arm his shoulder is often a hand's breadth beyond reach of the pole. He is drawn up to
## 20 cm nearer it, as far as his near arm (all but straight, to the grip on the bar) needs, eased in and out.
const POLE_SHIFT_MAX := 0.2


func _pole_reach(dt: float) -> void:
	var want := Vector3.ZERO
	if layer.pole != Vector3.INF:
		var ex := _exact()
		var best := INF
		for side in ["Left", "Right"]:
			var sh := ex * _joint(side + "Arm")
			var d := Vector3(layer.pole.x - sh.x, 0.0, layer.pole.z - sh.z)
			if d.length() < best:
				best = d.length()
				var j: Dictionary = body.joints
				var arm := ((j[side + "ForeArm"] as Vector3).distance_to(j[side + "Arm"]) + (j[side + "Hand"] as Vector3).distance_to(j[side + "ForeArm"])) * ex.basis.get_scale().y
				# (The grip is a hand's length past the wrist; reached at 0.96 of the arm, swinging on it; the hand a
				# little above the game's grip height, Layer._hold_pole.)
				var reach := arm * 0.96 + 0.06
				var dy := layer.pole.y + 0.03 - sh.y
				var over := d.length() - sqrt(maxf(reach * reach - dy * dy, 0.0))
				want = d.normalized() * clampf(over, 0.0, POLE_SHIFT_MAX)
	_pole_shift = _pole_shift.lerp(want, minf(1.0, dt * 20.0))


## Where the body stands: under the capture at his place, turned as the capture turns him; under the game's pose
## exactly over the game's body (the same mesh: each joint on the game's); between the two as one fades to the other.
func _place() -> void:
	var exact := _exact()
	exact.origin += _pole_shift
	var s := exact.basis.get_scale().y
	var free := Transform3D(Basis(Vector3.UP, loco.yaw).scaled(Vector3.ONE * s), Vector3(who.global_position.x, 0.0, who.global_position.z))
	var w := smoothstep(0.0, 1.0, layer.weight) if mode != "upper" else 0.0
	if w <= 0.0:
		body.global_transform = free
		return
	body.global_transform = exact if w >= 1.0 else free.interpolate_with(exact, w)
	if w >= 1.0:
		loco.yaw = exact.basis.orthonormalized().get_euler().y


# ---------------------------------------------------------------- measuring (tests, the stills tool)

## Set: each pose keeps where this body's joints were drawn (in last), measured once the skeleton has its final pose
## (outside its update Godot reports the bones without the modifiers: the game's pose laid on, the planter).
var measure := false
var last := {}
var game_last := {}           # the game body's joints, the same frame (its final pose: read in its skeleton_updated)
const MEASURED := ["Hips", "Spine2", "Head", "LeftHand", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
	"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase", "LeftForeArm", "RightForeArm"]


func _posed() -> void:
	if layer.t0 > 0:
		cost_usec += Time.get_ticks_usec() - layer.t0
		layer.t0 = 0
	if not measure:
		return
	for b in MEASURED:
		last[b] = body.bone_world(b).origin
	last["mode"] = mode
	last["w"] = layer.weight
	last["act"] = who.act
	last["frame"] = Engine.get_process_frames()
	last["xf"] = body.global_transform
	last["low"] = _lowest()
	for side in ["Left", "Right"]:
		last[side + "Grip"] = body.grip_point(side, layer.pole_r).origin   # (where a pole in that hand has its axis)
	last["pole"] = layer.pole


## The drawn body's lowest point over the ground (head, hands, chest, hips, knees, feet: the joints, less the body
## round each - as ModelBody.lowest_point and DivePose's floor measure the game's).
const FLOOR_R := {"Head": 0.11, "Spine2": 0.13, "Hips": 0.1, "LeftHand": 0.03, "RightHand": 0.03, "LeftForeArm": 0.04,
	"RightForeArm": 0.04, "LeftLeg": 0.06, "RightLeg": 0.06, "LeftFoot": 0.05, "RightFoot": 0.05, "LeftToeBase": 0.03,
	"RightToeBase": 0.03}


func _lowest() -> float:
	var low := INF
	for b in FLOOR_R:
		low = minf(low, body.bone_world(b).origin.y - float(FLOOR_R[b]) * body.global_transform.basis.get_scale().y)
	return low


## WsgLegacyPose's arm-maker (sound_arm: an elbow bent forward in its hinge, the hand where it was put) for the
## pole hold's reach. It is made from a 17-bone skeleton, which kho kho has not: one with only the hips it asks for
## does (sound_arm needs only the rig's joints).
static func _arm_maker(joints: Dictionary) -> WsgLegacyPose:
	var hips_only := Skeleton3D.new()
	hips_only.add_bone("hips")
	hips_only.set_bone_rest(0, Transform3D(Basis(), joints["Hips"]))
	var lp := WsgLegacyPose.new(hips_only, joints)
	lp.held = {"Left": true, "Right": true}
	lp.sk = null
	hips_only.free()
	return lp


## The game body's joint in the world against this body's as last drawn (tests: they lie on each other under the
## game's pose; measure on). Mirrored, the game's left is drawn as this body's right.
func joint_gap(bone: String) -> float:
	if not game_last.has(bone) or not last.has(bone):
		return INF
	return (game_last[bone] as Vector3).distance_to(last[bone])


## The game's pose over the capture (WsgPoseLayer), noting when it ran (its time counted in cost_usec); and both
## hands on the pole in a pole turn. (The game's own Grip only points his arms at the pole's middle: the hand nearer
## it reaches it, the other stops short in the air. WsgPoseLayer.hold anchors a hand to another bone, not to a
## point in the world: this is that, for a post in the ground.)
class Layer extends WsgPoseLayer:
	var t0 := 0
	## The pole held: a point on its axis at the height the game grips it (world), INF none; its radius.
	var pole := Vector3.INF
	var pole_r := 0.0475
	var joints := {}
	var held := {}            # the hands on it, this frame ("Left", "Right" -> bool)

	func _process_modification_with_delta(delta: float) -> void:
		t0 = Time.get_ticks_usec()
		super(delta)
		if pole != Vector3.INF and weight > 0.0:
			_hold_pole(smoothstep(0.0, 1.0, weight))

	## The hand nearer the pole closed round it as a hand round an upright bar: thumb up, the palm to it, the bar
	## across the palm where the fingers close on it (WsgGrip's grip line); the arm reaching it (two bones). The other
	## hand on it too, lower, while it can reach it (swinging round, mostly it cannot: a kho kho pole turn is a
	## one-handed swing).
	func _hold_pole(w: float) -> void:
		var sk := get_skeleton()
		var inv := sk.global_transform.affine_inverse()
		# (The foot planter lifts the hips after this, by lift_after: the hand is put that much lower.)
		var a := inv * pole - Vector3(0.0, lift_after, 0.0)
		var up := (inv.basis * Vector3.UP).normalized()
		var near := ""
		var best := INF
		for side in ["Left", "Right"]:
			var sh := sk.get_bone_global_pose(sk.find_bone(side + "Arm")).origin
			var dd := (a - sh) - up * (a - sh).dot(up)
			if dd.length() < best:
				best = dd.length()
				near = side
		for side in ["Left", "Right"]:
			var sh := sk.get_bone_global_pose(sk.find_bone(side + "Arm")).origin
			var d := (a - sh) - up * (a - sh).dot(up)
			if d.length() < 0.01:
				continue
			d = d.normalized()
			var x := d if side == "Left" else -d
			var b := Basis(x, up.cross(x), up).orthonormalized()
			var g: Vector3 = WsgGrip.axis_point(joints, side, pole_r) - (joints[side + "Hand"] as Vector3)
			var at := a + up * (0.03 if side == near else -0.09)
			var t := Transform3D(b, at - b * g)
			var hw := w
			if side != near:
				var arm := (joints[side + "ForeArm"] as Vector3).distance_to(joints[side + "Arm"]) + (joints[side + "Hand"] as Vector3).distance_to(joints[side + "ForeArm"])
				hw *= 1.0 - smoothstep(0.92, 1.0, (t.origin - sh).length() / arm)
			held[side] = hw > 0.5
			if hw > 0.0:
				_reach(sk, side, t, hw, [g, up])
