class_name FoundationLink
extends Node3D
## A netball player, umpire or reserve drawn with the World Stage Games foundation (addons/wsg_foundation): the owner's
## netball player (the Meshy model of assets/player, baked onto the shared rig: assets/foundation/hero_*) run by the
## motion-capture locomotion (starts, cuts, stops, side-steps and backpedals; the feet planted), with every move the
## game makes by hand laid over it from the game's own body (WsgLegacyPose): the pass, the shot, the catch, the
## landing, holding the ball, defending, the leap, the celebration, the huddle; a player marking or posting keeps
## her arms; an umpire's signals keep hers. The ball in a player's hands is held in the drawn hands (both palms on
## it, the fingers closed round it) and the ball is drawn where those hands have it (ball_at).
## The game's body (HeroBody, or the umpire's ToonBody) stays the game's: player.gd still poses it every frame and
## everything the rules measure off it is unchanged; only its mesh is no longer drawn.
## Medium and High only: Low draws the game's own bodies exactly as before (tests/test_runner _low_unchanged). Without
## the licensed clip library (a fork's build, CI) nobody has a link, and the game is as it was.

const DIR := "res://assets/foundation/"
## The rig's character is 1.80 m tall at scale 1.
const RIG_H := 1.8
## The game's own moves: the whole body is the game's pose (its legs, its facing, its hips).
const FULL := ["hold", "pass", "catch", "shoot", "defend", "defend_shot", "leap", "out_of_play", "cheer", "huddle"]
## Moves with arms of their own over the motion capture's legs.
const UPPER := ["mark", "post"]
const ARMS := ["LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand"]

var who: Node3D               # the Player or Umpire
var gb: ToonBody              # the game's body (posed by the game, not drawn)
var body: WsgBody
var loco: WsgLocomotor
var legacy: BallLayer
var reader: WsgLegacyPose
var feet: FeetLayer            # the drawn feet on the game's (players and umpires)
var material: ShaderMaterial
var mode := ""
var kind := "player"          # player, umpire, reserve
var ball_at := Vector3.INF    # where the drawn hands hold the ball (world), after the last pose; INF: not holding
var holding := false
var _hold_w := 0.0            # the hands on the ball (eased off after a release)
var _ball_v := {}             # side -> the ball's centre from the wrist, in the hand's rest (the joints' space)
var _grip := {}               # side -> [[bone index, Quaternion], ...] the fingers closed round the ball
var _at := Vector3.INF

## Set by the tests that are not about drawing (tests/test_runner.gd): their matches run as a build without the
## licensed clips would (CI's), in the time CI allows.
static var off := false


## Netball is a premium game (WsgFoundation: Medium by default, the phone decides; the GL Compatibility renderer
## stays the game's own).
static func _static_init() -> void:
	WsgFoundation.profile = OS.get_environment("WSG_PROFILE") if OS.has_environment("WSG_PROFILE") else "premium"


## Whether bodies made now are drawn by the foundation: the licensed clips are in this build, the baked hero is
## there, and the graphics are Medium or High (Low keeps the game's own bodies).
static func enabled() -> bool:
	return not off and int(Game.settings.graphics) > Game.GFX_LOW and WsgClips.available() \
		and ResourceLoader.exists(DIR + "hero_rig.json") and not OS.has_environment("WSG_OFF")


func _init(p_who: Node3D, p_body: ToonBody, p_kind := "player") -> void:
	who = p_who
	gb = p_body
	kind = p_kind
	name = "Foundation"
	top_level = true


func _ready() -> void:
	body = WsgBody.new(WsgBody.load_character(DIR, "hero"), null, 0)
	add_child(body)
	body.set_manual(true)
	body.visible = false        # till its first pose (the rig's T-pose otherwise, for a frame)
	_scale_body()
	_make_material()
	body.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind == "reserve" or not Game.shadows_enabled() \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	legacy = BallLayer.new()
	legacy.link = self
	legacy.name = "Legacy"
	body.skeleton.add_child(legacy)
	body.skeleton.move_child(legacy, 0)
	reader = WsgLegacyPose.new(gb.skeleton, body.joints)
	legacy.arms = reader
	legacy.torso_r = 0.085      # the forearms kept out of the chest (the game's poses are for its slimmer figure)
	if kind != "reserve":
		loco = WsgLocomotor.attach(body)
		legacy.lift_after = loco.planter.hips_offset
		feet = FeetLayer.new()
		feet.name = "GameFeet"
		feet.link = self
		body.add_modifier(feet)
		_feet_offset()
		# (The head's and chest's look-at: the game's own head is laid over them in its moves; none in the run.)
		for m in [loco.look, loco.look_chest]:
			if m:
				m.active = false
	for side in ["Left", "Right"]:
		# (The ball in the palm, clear of the knuckles: WsgGrip.sphere_point, as WsgBody.ball_point has it.)
		_ball_v[side] = WsgGrip.sphere_point(body.joints, side, Ball.R / _s()) - (body.joints[side + "Hand"] as Vector3)
	# The game's body stays (posed, measured), unseen.
	if gb.mesh_instance:
		gb.mesh_instance.visible = false
	body.posed.connect(_on_posed)


## This body's height: the game's (HeroBody and ToonBody scale their 1.76 m figure to her height).
func _scale_body() -> void:
	body.scale = Vector3.ONE * (gb.scale.x * 1.76 / RIG_H)


func _s() -> float:
	return body.scale.x if body else 1.0


## The game's own body drawn again and this one gone (the graphics lowered to Low mid-match).
func release() -> void:
	if gb and is_instance_valid(gb) and gb.mesh_instance:
		gb.mesh_instance.visible = true
	queue_free()


# ---------------------------------------------------------------- the kit

static var _shader: Shader
static var _mats := {}


## HeroBody's kit shader (the team's colours from the kit mask, her skin and hair, the bib with her position's
## letters), reading each point's rest position from the bake's vertex colour (tools/wsg/bake_character.gd: x, y, z
## in red, green, blue) instead of UV2; and for an umpire the same model in the umpires' kit: a teal shirt with short
## sleeves and dark trousers, her own skin and hair, no bib.
func _make_material() -> void:
	var hb := gb as HeroBody
	var look := gb.look
	var umpire := kind != "player"
	var key := "%s|%s|%s|%s|%s|%s|%s|%s" % [kind, look.get("dress"), look.get("trim"), look.get("bib"), look.get("skin"),
		look.get("hair"), look.get("pos", ""), Game.hd()]
	if _mats.has(key):
		material = _mats[key]
		body.mesh_instance.material_override = material
		return
	if _shader == null:
		_shader = Shader.new()
		# (HeroBody's, the umpires' kit in it: HeroBody.UMPIRE_KIT.)
		_shader.code = HeroBody.shader_code().replace("rp = vec3(UV2.x, UV2.y, (COLOR.b - 0.5) * 1.6);",
			"rp = vec3((COLOR.r - 0.5) * 1.6, COLOR.g * 2.0, (COLOR.b - 0.5) * 1.6);")
	var m := ShaderMaterial.new()
	m.shader = _shader
	var src: ShaderMaterial = hb._material() if hb else null
	if src:
		for k in ["albedo", "kit", "letters", "dress", "trim", "skin", "hair", "bib", "ink", "letter", "ref_dress", "ref_trim", "ref_hair", "ref_skin"]:
			m.set_shader_parameter(k, src.get_shader_parameter(k))
	else:
		# An umpire or a reserve: the player's model and textures, their own skin and hair.
		var hd := Game.hd()
		m.set_shader_parameter("albedo", Game.tex(HeroBody.DIR + "hero_albedo.jpg") if hd else load(HeroBody.DIR + "hero_albedo.jpg"))
		m.set_shader_parameter("kit", Game.tex(HeroBody.DIR + "hero_mask.png") if hd else load(HeroBody.DIR + "hero_mask.png"))
		m.set_shader_parameter("letters", load("res://assets/ui/bib_letters.png"))
		m.set_shader_parameter("skin", look.get("skin", Color("c48f62")))
		m.set_shader_parameter("hair", look.get("hair", Color("1a1410")))
		m.set_shader_parameter("dress", look.get("dress", Color("6fd6c6")))
		m.set_shader_parameter("trim", look.get("dress", Color("6fd6c6")))
		var ref: Dictionary = HeroBody.data().ref
		for k in ["dress", "trim", "hair", "skin"]:
			var c: Array = ref[k]
			m.set_shader_parameter("ref_" + k, Color(c[0], c[1], c[2]))
		m.set_shader_parameter("letter", -1)
	# The bib on this rig: HeroBody's box (against her chest joint, the torso's middle) moved onto the rig's chest.
	var j: Dictionary = body.joints
	var k := RIG_H / 1.759          # the rig's figure against the model's own
	var torso: Dictionary = HeroBody.data().torso
	var off: Dictionary = HeroBody.data().offsets
	var chest_z := float(off.spine[2]) + float(off.chest[2])
	var cy := (j["Spine2"] as Vector3).y
	var mid_z := (j["Spine2"] as Vector3).z + (float(torso.mid_z) - chest_z) * k
	if umpire:
		m.set_shader_parameter("bib_box", Vector4(0.0, 9.0, 9.0, 0.0))     # (no bib)
	else:
		m.set_shader_parameter("bib_box", Vector4(HeroBody.BIB_HALF * k, cy + HeroBody.BIB_BOTTOM * k, cy + HeroBody.BIB_TOP * k, mid_z))
	m.set_shader_parameter("umpire", 1.0 if umpire else 0.0)
	m.set_shader_parameter("shirt", look.get("dress", Color("6fd6c6")))
	m.set_shader_parameter("trousers", Color("1c1b26"))     # (an umpire's, and a reserve's tracksuit, as the game's)
	# The trousers' top (the hips) and their hem (above the socks), the shoulder's x and its height (the sleeve).
	var hip_y := (j["Hips"] as Vector3).y + 0.06
	var hem_y := (j["LeftFoot"] as Vector3).y + 0.07
	m.set_shader_parameter("limbs", Vector4(hip_y, hem_y, absf((j["LeftArm"] as Vector3).x), (j["LeftArm"] as Vector3).y))
	# The outline as the game's players have it, on Medium and High.
	m.next_pass = ToonBody.material(Game.hd()).next_pass
	ToonBody._also_outlined.append(m)
	_mats[key] = m
	material = m
	body.mesh_instance.material_override = m


## A team change or a new kit: the colours as the game's body has them now.
func recolour() -> void:
	if body:
		_scale_body()
		_make_material()


# ---------------------------------------------------------------- each frame

## Between the frames it is posed (a body far from the camera: Player.pose_every): carried along, and its
## skeleton's modifiers run again (not the capture's animation, the costly part): the planter holds a planted foot
## where it is as the body goes on, and under the game's whole pose its legs are the game's this frame, which step
## with the floor. (Carried along as last posed, its feet slid with it for a frame or two and snapped back.)
func follow(frame_dt := 0.0) -> void:
	if not body.visible:
		return
	global_transform = Transform3D(Basis.IDENTITY, who.global_position)
	if mode == "full":
		legacy.set_pose(reader.read())
		body.rotation.y = _yaw
	if frame_dt > 0.0:
		body.advance(frame_dt)
	if holding and _ball_rel != Vector3.INF:
		ball_at = body.global_transform * _ball_rel


var _ball_rel := Vector3.INF  # the ball as last held, in the body's frame (for the frames between poses)


## After the game has posed its body and placed her this frame (game seconds since the last): drive this one.
## vel, want_vel: her velocity and the one she is steering to (court x, z); yaw: where her body faces as the game draws
## it (0 faces +z; the game's legs are made for it); act: what her body does (Player.act; "signal" for an umpire's
## call); ball: the ball's centre (world) when she holds it, else INF; frame_dt: this frame's own seconds (the
## skeleton's modifiers, the layer's fades), when dt sums the frames since it was last posed.
func update(dt: float, vel: Vector2, want_vel: Vector2, yaw: float, act: String, ball: Vector3 = Vector3.INF, frame_dt := -1.0) -> void:
	if dt <= 0.0 or not is_visible_in_tree():
		return
	if frame_dt <= 0.0:
		frame_dt = dt
	global_transform = Transform3D(Basis.IDENTITY, who.global_position)
	var want := "move"
	if kind == "reserve":
		want = "full"
	elif who.has_method("anim_layer"):
		# A player or an umpire (Player.anim_layer, Umpire.anim_layer): the game's whole pose whenever she moves on
		# her own legs (the game's gait: feet planted at any pace, in any direction), the capture standing still.
		want = who.anim_layer()
	elif act in FULL or holding_ball(ball):
		want = "full"
	elif act in UPPER or (act in ["ready", "run"] and vel.length() < 0.6):
		# Marking, posting, or standing ready (her hands up at her chest to take a pass): her arms over the capture.
		want = "upper"
	var pose := reader.read() if want != "move" else {}
	match want:
		"upper":
			var up := {}
			for b in ARMS:
				if pose.has(b):
					up[b] = pose[b]
			pose = up
		"move":
			pose = {}
	legacy.set_pose(pose)
	if want != mode:
		var w := 0.0 if want == "move" else 1.0
		if mode == "":
			legacy.weight = w      # (a new body starts as the game's: no blend in from nothing)
		# The legs handed over quickly (two poses of the feet blended slide between them); the arms alone more slowly.
		legacy.fade_to(w, 0.12 if (mode == "full") != (want == "full") else 0.18)
		if mode == "full" and loco:
			# Back to the capture from the game's whole pose: the locomotor goes on from her speed and facing now (its
			# smoothing still had the speed from before: bogus cuts and starts), the planter from no held feet.
			loco.resume(Vector3(vel.x, 0, vel.y), yaw)
			loco.planter.reset()
		mode = want
	body.visible = true
	# Put somewhere new (a restart, a substitution): the feet are not held where they were.
	if _at != Vector3.INF and who.global_position.distance_to(_at) > 1.5 and loco:
		loco.planter.reset()
	_at = who.global_position
	_yaw = yaw
	if loco:
		# (Under the game's whole pose, once it is all the game's, the capture's animation is not run: nothing of it
		# would show. resume() takes the locomotor on from her speed and facing when the capture has her again.)
		if mode != "full" or legacy.weight < 0.999:
			loco.drive(dt, Vector3(vel.x, 0, vel.y), yaw, Vector3(want_vel.x, 0, want_vel.y))
		# A move of the game's own has its legs exactly as the game made them (its gait's planted feet, a landing, a
		# leap): the planter keeps the pose (only the hips' lift, so lift_after stays hips_offset); under the capture
		# it plants the clips' feet again (ADOPTING 5.10).
		loco.planter.enabled = true
		loco.planter.keep_pose = mode == "full"
		if mode == "full":
			loco.yaw = yaw
			body.rotation.y = yaw
	else:
		body.rotation.y = yaw
	# The ball in both hands, where the game's hands have it (moved into this body's frame).
	var take := holding_ball(ball)
	_hold_w = 1.0 if take else move_toward(_hold_w, 0.0, dt / 0.15)
	holding = take
	legacy.ball = body.skeleton.global_transform.affine_inverse() * ball if take else legacy.ball
	legacy.ball_w = _hold_w
	if _hold_w > 0.0 and body.full:
		_close_hands(_hold_w)
	if not take:
		ball_at = Vector3.INF
		_ball_rel = Vector3.INF
	# The skeleton's modifiers now, once (WsgBody.set_manual).
	body.advance(frame_dt)


var _yaw := 0.0              # the yaw it was last given


func holding_ball(ball: Vector3) -> bool:
	return kind == "player" and ball != Vector3.INF


## The fingers closed round the ball itself (WsgGrip.solve_sphere, as WsgBody.grip_sphere: each finger curled till
## it touches the ball, not a ball-sized handle across the palm, which left fingers inside it; solved once).
func _close_hands(w: float) -> void:
	var sk := body.skeleton
	for side in ["Left", "Right"]:
		if not _grip.has(side):
			var g := WsgGrip.solve_sphere(body.joints, side, Ball.R / _s())
			var list := []
			for b in g:
				list.append([body.bone(b), g[b]])
			_grip[side] = list
		for e in _grip[side]:
			var i: int = e[0]
			sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp(e[1], w) if w < 1.0 else e[1])


## Once the skeleton has its final pose: where its hands hold the ball (each palm's ball centre, between the two).
func _on_posed() -> void:
	if not holding:
		return
	var c := Vector3.ZERO
	for side in ["Left", "Right"]:
		c += body.bone_world(side + "Hand") * (_ball_v[side] as Vector3)
	ball_at = c * 0.5
	_ball_rel = body.global_transform.affine_inverse() * ball_at
	# The ball drawn where these hands are now: the skeleton's final pose comes at its own update, after the match has
	# placed the ball this frame (Ball.step, from last frame's hands), so it is put in them here.
	var m = who.get("match_ref")
	if m and m.phase != "replay" and m.ball and m.ball.holder == who and m.ball.state == "held":
		m.ball.pos = ball_at
		m.ball.position = ball_at
	if measure:
		_measure()


## Set (the tests, the close-up tools): each posed frame keeps how far each palm's ball centre is from the ball the
## game wanted (m), in last_hands {side: m, "gap": the two palms' centres apart, "forearm": the nearest a forearm comes
## to the drawn ball's centre}.
var measure := false
var last_hands := {}


func _measure() -> void:
	var want: Vector3 = body.skeleton.global_transform * legacy.ball
	var pts := {}
	for side in ["Left", "Right"]:
		pts[side] = body.bone_world(side + "Hand") * (_ball_v[side] as Vector3)
		last_hands[side] = (pts[side] as Vector3).distance_to(want)
	last_hands["gap"] = (pts.Left as Vector3).distance_to(pts.Right)
	# And how near either forearm comes to the ball's centre (from the elbow to the wrist): the ball held in the hands,
	# not against the forearms.
	var near := INF
	for side in ["Left", "Right"]:
		var e := body.bone_world(side + "ForeArm").origin
		var w := body.bone_world(side + "Hand").origin
		near = minf(near, ball_at.distance_to(Geometry3D.get_closest_point_to_segment(ball_at, e, w)))
	last_hands["forearm"] = near


## Both hands on the ball: each palm on its side of it, facing its centre, the fingers on along the forearm's line;
## the arm reaching there (WsgPoseLayer.hold, against the hips as they will be).
func holds(sk: Skeleton3D, hips_g: Transform3D, lift: Vector3) -> Dictionary:
	if legacy.ball_w <= 0.0:
		return {}
	var c: Vector3 = legacy.ball - lift
	var out := {}
	var gs := gb.skeleton
	var to_rig := body.skeleton.global_transform.affine_inverse() * gs.global_transform
	for side in ["Left", "Right"]:
		var s := "l" if side == "Left" else "r"
		var wrist: Vector3 = to_rig * gs.get_bone_global_pose(gs.find_bone("hand_" + s)).origin - lift
		var elbow: Vector3 = to_rig * gs.get_bone_global_pose(gs.find_bone("forearm_" + s)).origin - lift
		var n := c - wrist
		n = n.normalized() if n.length() > 0.01 else (Vector3.LEFT if side == "Left" else Vector3.RIGHT)
		var f := wrist - elbow
		f = f - n * f.dot(n)
		f = f.normalized() if f.length() > 0.01 else Vector3.UP
		var bx := f if side == "Left" else -f
		var basis := Basis(bx, -n, bx.cross(-n)).orthonormalized()
		var hand := Transform3D(basis, c - basis * (_ball_v[side] as Vector3))
		out[side] = ["Hips", hips_g.affine_inverse() * hand, legacy.ball_w]
	return out


## The game's poses over the capture (WsgPoseLayer), and the hands on the ball: the holds worked out as it runs, once
## the hips are where they will be (the game's in its own moves), against the ball in this body's space; the planter's
## lift after it allowed for.
class BallLayer extends WsgPoseLayer:
	var link: FoundationLink
	var ball := Vector3.ZERO      # skeleton space, as drawn (after the planter's lift)
	var ball_w := 0.0

	func _process_modification_with_delta(delta: float) -> void:
		var sk := get_skeleton()
		hold = {}
		if sk == null or link == null or ball_w <= 0.0 or (weight <= 0.0 and _target <= 0.0):
			super(delta)
			return
		# The layer's weight this frame (as super will ease it), and the hips laid now, once, at it: the holds are made
		# against the hips as they will be drawn (laid again by super, a lerp toward them would carry the hands off).
		var w_next := move_toward(weight, _target, _rate * delta) if _rate > 0.0 else weight
		var w := smoothstep(0.0, 1.0, w_next)
		var hi := sk.find_bone("Hips")
		var keep_pose := pose
		var keep_hips := hips
		if pose.has("Hips"):
			sk.set_bone_pose_rotation(hi, sk.get_bone_pose_rotation(hi).slerp(pose["Hips"], w))
			pose = pose.duplicate()
			pose.erase("Hips")
		if hips != Vector3.INF:
			sk.set_bone_pose_position(hi, sk.get_bone_pose_position(hi).lerp(sk.get_bone_rest(hi).origin + hips - Vector3(0, lift_after, 0), w))
			hips = Vector3.INF
		hold = link.holds(sk, sk.get_bone_global_pose(hi), Vector3(0, lift_after, 0))
		# The hands on the ball at their own weight, not the layer's (which fades the game's pose in over a catch: the
		# palms came onto the ball late, 5-18 cm off for the first few frames).
		for side in hold:
			hold[side][2] = ball_w / maxf(w, 0.001)
		super(delta)
		pose = keep_pose
		hips = keep_hips


# ---------------------------------------------------------------- the feet

## The rig's ankle against the game's, each standing at rest (m, in the game foot's frame, scaled): the two figures'
## ankles are not at the same height over their soles, nor as far back from their toes.
var _ankle_d := Vector3.ZERO


func _feet_offset() -> void:
	var gs := gb.skeleton
	var i := gs.find_bone("foot_l")
	if i < 0:
		return
	var game_ank := gs.get_bone_global_rest(i).origin * gb.scale.x
	var rig_ank := (body.joints["LeftFoot"] as Vector3) * _s()
	_ankle_d = Vector3(0.0, rig_ank.y - game_ank.y, rig_ank.z - game_ank.z) / maxf(gb.scale.x, 0.01)


## Where the game has her leg this frame (world): [the ankle, as the rig's would be on that foot; the knee; the
## foot's turn (its basis, unscaled: the rig's foot turned as the game's from their rests)].
func game_leg(i: int) -> Array:
	var gs := gb.skeleton
	var s := "l" if i == 0 else "r"
	var ft := gs.global_transform * gs.get_bone_global_pose(gs.find_bone("foot_" + s))
	var kn := gs.global_transform * gs.get_bone_global_pose(gs.find_bone("shin_" + s)).origin
	return [ft * _ankle_d, kn, ft.basis.orthonormalized()]


## The drawn feet on the game's (Gait's, which plant each foot exactly where it comes down, 0 cm of slip:
## tests/test_runner _gait_steps): each of the rig's ankles put where the game has that ankle, the leg reaching it
## (two-bone IK, the knee toward the game's knee), the foot turned as the game's. Without it the rig's legs, of other
## proportions, laid from the game's turns (WsgLegacyPose) put the feet 3 cm off and sliding with every step, and the
## capture's idle swayed its own feet about under her as the game's stood still. Runs after the planter.
class FeetLayer extends SkeletonModifier3D:
	const LEGS := [["LeftUpLeg", "LeftLeg", "LeftFoot"], ["RightUpLeg", "RightLeg", "RightFoot"]]
	var link: FoundationLink
	var weight := 1.0
	var _ix := []

	func _process_modification_with_delta(_delta: float) -> void:
		var sk := get_skeleton()
		if sk == null or link == null or weight <= 0.0 or link.gb == null or link.gb.skeleton == null:
			return
		if _ix.is_empty():
			for leg in LEGS:
				_ix.append(leg.map(func(n): return sk.find_bone(n)))
		var inv := sk.global_transform.affine_inverse()
		var sb := sk.global_transform.basis.orthonormalized().inverse()
		var legs := [link.game_leg(0), link.game_leg(1)]
		# The hips lowered as far as a leg must for its foot to reach the game's (the rig's legs reach a little less far
		# than the game's from where the game's hips put its hips: a trailing leg pushing off).
		var drop := 0.0
		for i in 2:
			var hip := sk.get_bone_global_pose(_ix[i][0]).origin
			var a := hip.distance_to(sk.get_bone_global_pose(_ix[i][1]).origin)
			var b := sk.get_bone_global_pose(_ix[i][1]).origin.distance_to(sk.get_bone_global_pose(_ix[i][2]).origin)
			var t: Vector3 = inv * (legs[i][0] as Vector3)
			var r := (a + b) * 0.995
			var flat := Vector2(t.x - hip.x, t.z - hip.z).length()
			if hip.distance_to(t) > r and flat < r:
				drop = maxf(drop, (hip.y - t.y) - sqrt(r * r - flat * flat))
		# (Not while she holds the ball: her hands are on it where the game has it, and the hips would take them off.)
		if drop > 0.0 and link.legacy.ball_w <= 0.0:
			var hi := sk.find_bone("Hips")
			var hg := sk.get_bone_global_pose(hi)
			var par := sk.get_bone_parent(hi)
			var pg := sk.get_bone_global_pose(par) if par >= 0 else Transform3D.IDENTITY
			hg.origin.y -= minf(drop, 0.12) * weight
			sk.set_bone_pose_position(hi, (pg.affine_inverse() * hg).origin)
		for i in 2:
			var g: Array = legs[i]
			# The foot turned as the game's is in the world (both feet face the way their bodies do at rest).
			var turn: Basis = sb * (g[2] as Basis) * sk.get_bone_global_rest(_ix[i][2]).basis
			_leg(sk, _ix[i], inv * (g[0] as Vector3), inv * (g[1] as Vector3), turn)

	## One leg (thigh, shin) turned so its ankle is at target (skeleton space), its knee bending toward knee_at, its
	## foot turned to foot (skeleton space).
	func _leg(sk: Skeleton3D, leg: Array, target: Vector3, knee_at: Vector3, foot: Basis) -> void:
		var th := sk.get_bone_global_pose(leg[0])
		var sh := sk.get_bone_global_pose(leg[1])
		var ft := sk.get_bone_global_pose(leg[2])
		var hip := th.origin
		var knee := sh.origin
		var a := hip.distance_to(knee)
		var b := knee.distance_to(ft.origin)
		var to := target - hip
		if to.length() < 0.001:
			return
		var d := clampf(to.length(), absf(a - b) + 0.001, (a + b) * 0.999)
		var dir := to.normalized()
		target = hip + dir * d
		if weight < 1.0:
			target = ft.origin.lerp(target, weight)
			to = target - hip
			d = clampf(to.length(), absf(a - b) + 0.001, (a + b) * 0.999)
			dir = to.normalized()
		var x := (a * a - b * b + d * d) / (2.0 * d)
		var h := sqrt(maxf(0.0, a * a - x * x))
		var pole := (knee_at - hip) - dir * (knee_at - hip).dot(dir)
		var fwd := th.basis * Vector3(0, 0, 1)
		fwd -= dir * fwd.dot(dir)
		if pole.length() < 0.01:
			pole = fwd
		var new_knee := hip + dir * x + pole.normalized() * h
		var ankle := hip + dir * d
		var parent := sk.get_bone_global_pose(sk.get_bone_parent(leg[0])).basis
		var th_b := Basis(Quaternion((knee - hip).normalized(), (new_knee - hip).normalized())) * th.basis
		# (The thigh rolled about its length so the knee's hinge is square to the leg's plane: WsgFootPlanter's way.)
		var tdir := (new_knee - hip).normalized()
		var normal := tdir.cross(ankle - new_knee)
		if normal.length() > 1e-4:
			normal = normal.normalized()
			var hx := th_b * Vector3.RIGHT
			if hx.dot(normal) < 0.0:
				normal = -normal
			var hx_flat := (hx - tdir * hx.dot(tdir)).normalized()
			th_b = Basis(Quaternion(hx_flat, normal)) * th_b
		sk.set_bone_pose_rotation(leg[0], (parent.inverse() * th_b).get_rotation_quaternion())
		var sh_now := th_b * (th.basis.inverse() * sh.basis)
		var sh_dir := sh_now * (sh.basis.inverse() * (ft.origin - knee)).normalized()
		var sh_b := Basis(Quaternion(sh_dir.normalized(), (ankle - new_knee).normalized())) * sh_now
		sk.set_bone_pose_rotation(leg[1], (th_b.inverse() * sh_b).get_rotation_quaternion())
		var fb := foot if weight >= 1.0 else Basis(ft.basis.get_rotation_quaternion().slerp(foot.get_rotation_quaternion(), weight))
		sk.set_bone_pose_rotation(leg[2], (sh_b.inverse() * fb).get_rotation_quaternion())
