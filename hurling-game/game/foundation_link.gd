class_name FoundationLink
extends Node3D
## A hurler or an official drawn with the World Stage Games foundation (addons/wsg_foundation): the owner's model on
## the shared rig (fingers, twist and joint helpers), run by the motion-capture locomotion (starts, cuts, stops,
## backpedals, the sprint; feet planted), with every move the game makes by hand - the swings, the catch, the solo,
## a fall, an official's signals - laid over it from the game's own body (WsgLegacyPose), which stays the game's:
## it is still posed every frame by player.gd, and everything the game measures off it (the bas, the hands) is
## unchanged. It is only no longer drawn.
## Without the licensed clip library (a fork's build) Player does not make one, and the game is as it was.

const DIR := "res://assets/foundation/"
## Actions that are running with the hurley carried (the legs keep the locomotion; the arms the game's pose).
const CARRY := ["solo", "hop", "bounce"]

var player: Player
var toon: ToonBody
var body: WsgBody
var loco: WsgLocomotor
var legacy: WsgPoseLayer
var reader: WsgLegacyPose
var stick: MeshInstance3D
var _last := -1.0
var _mode := ""
var _upper := {}
var _clear := {}
var _line_r := []           # the hurley's handle in the right hand, at rest (the rig's joints' space): [point, direction]
var _handle_toon := Vector3.ZERO   # the middle of the handle's grip tape (the game's body's rest space)
## The hurley's handle: its grip tape's radius (HeroBody._hurley).
const HANDLE_R := 0.021
## How far the hurley's axis is kept outside this body's torso (WsgBody.torso_capsule's surface; m, the rig's
## scale): the handle's own surface 3 cm off.
const STICK_CLEAR := 0.03 + HANDLE_R
## The lead (left) arm, when the hurley goes through it, swivelled about its shoulder-to-wrist line (the hand kept
## where it holds the handle) till the upper arm and the forearm (from the elbow to STICK_FOREARM of the way to the
## wrist: the hand on the handle is meant to be at it) are this far off the hurley's axis beyond their own girth
## (WsgBody.limb_capsule): a free's swing just after contact put the hurley through the upper arm (5-6 cm; the
## torso's capsule cannot see it). Turning the hurley instead (the least turn about the top fist, as for the torso)
## turned it 40-70 degrees, pointing at the grass, between the arm and the chest.
const ARM_CLEAR := HANDLE_R + 0.01
## The forearms kept out of the chest as it is drawn (WsgPoseLayer.torso_from_body) - off: on, the striking forearm
## is clear of the chest through the follow-through (14 frames of a free 2-5 cm in, then 1), but the arm swung out of
## the deeper chest put the hurley 7 cm into it at the frame after (t 1.97), the turn that takes it out (43 degrees)
## left the top hand short of the handle (the elbow audit: a finger 15 mm into it, a frame a free).
const FOREARMS_FROM_BODY := false
const STICK_FOREARM := 0.5
const SWIVEL_MAX := 100.0    # degrees the elbow may be swivelled
var _stick_len := 0.86
var _stick_clear: SkeletonModifier3D
## The turn (degrees) the hurley was given this frame to keep it out of the body (0: it was clear).
var stick_turn := 0.0
## The lead arm's swivel (degrees) this frame to keep it off the hurley (0: it was clear).
var arm_swivel := 0.0
var _last_swivel := 0.0


## Hurling is made for the nicer phones (WsgFoundation: Medium by default, High for flagships, Vulkan); WSG_PROFILE
## measures it as a budget game would draw it (tests/perf_probe.gd).
static func _static_init() -> void:
	WsgFoundation.profile = OS.get_environment("WSG_PROFILE") if OS.has_environment("WSG_PROFILE") else "premium"


static func enabled() -> bool:
	return WsgClips.available() and ResourceLoader.exists(DIR + "hero_rig.json") and not OS.has_environment("WSG_OFF")


func _init(p_player: Player, p_toon: ToonBody) -> void:
	player = p_player
	toon = p_toon
	name = "Foundation"


func _ready() -> void:
	var prefix := "hero"
	if toon is PersonBody:
		prefix = (toon as PersonBody).who
		if ResourceLoader.exists(DIR + prefix + "_body_hd_rig.json"):
			# The hurlers' own model in the officials' kit, with the official's head (tools/player/official_body.gd):
			# the owner found the officials' own models' upper bodies wrong ("still look awful").
			prefix += "_body_hd"
		elif ResourceLoader.exists(DIR + prefix + "_hd_rig.json"):
			prefix += "_hd"     # the HD pack's remake of the official, cut for the rig, with its own normal map
	elif ResourceLoader.exists(DIR + "hero_hd_rig.json"):
		prefix = "hero_hd"      # the HD model's own cuts, its sculpt baked into a normal map (foundation tools/blender)
	var lod := 1 if int(Game.settings.graphics) == Game.GFX_LOW and not bool(toon.look.get("full_detail", false)) else 0
	body = WsgBody.new(WsgBody.load_character(DIR, prefix), null, lod)
	add_child(body)
	body.set_manual(true)
	body.visible = false        # till its first pose (a frame of the rig's T-pose with the hurley otherwise)
	body.scale = toon.scale
	body.mesh_instance.material_override = toon.mesh_instance.material_override
	if prefix == "hero_hd":
		body.mesh_instance.material_override = _hd_material(toon.mesh_instance.material_override)
	elif prefix.ends_with("_body_hd"):
		# The body in the official's colours (the hurlers' kit material), the head with its own texture.
		body.mesh_instance.material_override = null
		body.mesh_instance.set_surface_override_material(0, _hd_material(HeroBody.kit_material(_official_kit(), toon._rest)))
		body.mesh_instance.set_surface_override_material(1, _official_material((toon as PersonBody).who + "_hd"))
	elif prefix.ends_with("_hd"):
		body.mesh_instance.material_override = _official_material(prefix)
	body.mesh_instance.cast_shadow = toon.mesh_instance.cast_shadow
	legacy = WsgPoseLayer.new()
	legacy.name = "Legacy"
	body.skeleton.add_child(legacy)
	body.skeleton.move_child(legacy, 0)
	loco = WsgLocomotor.attach(body)
	legacy.lift_after = loco.planter.hips_offset     # the game's hips height is this body's already
	# The forearms kept out of this body's chest (the game's model is slimmer: a free's follow-through swept the
	# striking arm through it, the owner's screenshot).
	legacy.torso_r = 0.1
	# ... or as this body's chest is drawn (its torso_capsule: deeper than the hips-to-neck line round which torso_r
	# keeps them, which lets the striking forearm sink 2-5 cm into the chest through a free's follow-through):
	# FOREARMS_FROM_BODY.
	legacy.torso_from_body = FOREARMS_FROM_BODY
	reader = WsgLegacyPose.new(toon.skeleton, body.joints)
	legacy.arms = reader
	if toon is HeroBody:
		reader.held = {"Right": true}      # the hurley: its turn is the game's, exactly
		# HeroBody turns each foot down (foot_pitch: its own model was made with the toes up); the rig's model stands
		# flat already (bake_character), so in the game's own moves - a free's set and strike - the feet were turned
		# down twice, pointing at the grass (the owner: "the shin looks very odd" at the end of a free's swing).
		reader.undo["foot_l"] = Quaternion(Vector3.RIGHT, deg_to_rad(HeroBody.foot_pitch))
		reader.undo["foot_r"] = Quaternion(Vector3.RIGHT, deg_to_rad(HeroBody.foot_pitch))
	if toon is PersonBody:
		# PersonBody's own fixes for the Meshy officials (arm twists, feet turned down), not wanted on the rig.
		var pb := toon as PersonBody
		var tw: Array = PersonBody.TWIST.get(pb._twist_key(), [0.0, 0.0])
		reader.undo = {"upperarm_l": Quaternion(Vector3.UP, deg_to_rad(tw[0])), "forearm_l": Quaternion(Vector3.UP, deg_to_rad(tw[1])),
			"upperarm_r": Quaternion(Vector3.UP, deg_to_rad(-tw[0])), "forearm_r": Quaternion(Vector3.UP, deg_to_rad(-tw[1]))}
		var fp := float(PersonBody.foot_pitch.get(pb._twist_key(), 0.0))
		reader.undo["foot_l"] = Quaternion(Vector3.RIGHT, deg_to_rad(fp))
		reader.undo["foot_r"] = Quaternion(Vector3.RIGHT, deg_to_rad(fp))
	for b in ["Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
			"RightShoulder", "RightArm", "RightForeArm", "RightHand"]:
		_upper[b] = true
	# The game's body stays (posed, measured), unseen; its hurley is drawn here, in this body's hand.
	toon.mesh_instance.visible = false
	if toon is HeroBody and (toon as HeroBody).stick:
		var s: MeshInstance3D = (toon as HeroBody).stick
		s.visible = false
		stick = MeshInstance3D.new()
		stick.mesh = s.mesh
		stick.material_override = s.material_override
		stick.cast_shadow = s.cast_shadow
		body.add_child(stick)     # (moves with the body between the frames it is posed)
		body.posed.connect(_place_stick)
		# Where the handle runs through the fist, as drawn (the fingers close on it there).
		var rest_hand := toon.skeleton.get_bone_global_rest(toon.bone("hand_r")).origin
		var dir := HeroBody.HURLEY_DIR.normalized()
		_handle_toon = rest_hand + (toon as HeroBody)._grip() + dir * 0.03
		var cr: Quaternion = reader._corr["RightHand"].inverse()
		_line_r = [(body.joints["RightHand"] as Vector3) + cr * (_handle_toon - rest_hand), cr * dir]
		_clear = {"Left": ["RightHand", (_line_r[0] as Vector3) - (body.joints["RightHand"] as Vector3), _line_r[1], 0.12, HANDLE_R]}
		_stick_len = 0.86 if int((toon as HeroBody).look.get("hurley", 1)) == 1 else 0.9
		# The hurley kept out of this body's torso and lead arm once the layer has laid the arms and solved the holds
		# (_clear_stick), in a modifier of its own just after the layer.
		_stick_clear = StickClear.new()
		_stick_clear.name = "StickClear"
		(_stick_clear as StickClear).link = self
		body.skeleton.add_child(_stick_clear)
		body.skeleton.move_child(_stick_clear, legacy.get_index() + 1)

	# The feet set down flat, last of all (after the foot planter): this body's model stands with its boots' toes up
	# (the shared foundation's WsgFootFlat, from this game's 0.21.1).
	WsgFootFlat.attach(body)


static var _hd_mats := {}


## An official's kit on the hurlers' model: the referee and the linesmen in black, the umpires in white, the trim the
## shirt's own colour (the hurlers' number and the stripes on the shorts are trim: an official has neither); black
## shorts and socks, as GAA referees and linesmen wear them - the shorts to above the knee and the socks black to under
## it (long_kit: the owner saw bare legs and "underwear"); the skin of their own heads.
func _official_kit() -> Dictionary:
	var jersey: Color = toon.look.get("jersey", Color("1a1a1a"))
	return {"jersey": jersey, "trim": jersey, "shorts": Color("1c1c1c"), "socks": Color("1c1c1c"), "skin": OFFICIAL_SKIN,
		"design": 0, "plain": true, "long_kit": (toon as PersonBody).who != "umpire"}


## The officials' heads' skin (their textures' own, measured at the neck), for the body's arms and legs to match.
const OFFICIAL_SKIN := Color("e0ad92")


## The game's kit material for the HD model's cuts: its textures (the HD pack's, else the same scaled for the game),
## and the sculpt's relief.
static func _hd_material(m: Material) -> Material:
	var key := m.get_instance_id()
	if not _hd_mats.has(key):
		var hd := (m as ShaderMaterial).duplicate() as ShaderMaterial
		if not Ultra.active():
			hd.set_shader_parameter("albedo", load(DIR + "hero_hd_albedo.jpg"))
			hd.set_shader_parameter("kit", load(DIR + "hero_hd_mask.png"))
		hd.set_shader_parameter("nmap", load(DIR + "hero_hd_normal.png"))
		hd.set_shader_parameter("nmap_k", 1.0)
		_hd_mats[key] = hd
	return _hd_mats[key]


## An official's HD remake: lit by the scene on High (its normal and roughness maps), else cel-shaded as the game's
## officials are, with its relief.
static func _official_material(prefix: String) -> Material:
	var lit := Ultra.lit()
	var key := prefix + str(lit)
	if not _hd_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = PersonBody._ultra_shader() if lit else PersonBody._shader()
		m.set_shader_parameter("albedo", load(DIR + prefix + "_albedo.jpg"))
		if lit:
			m.set_shader_parameter("normal_map", load(DIR + prefix + "_normal.png"))
			m.set_shader_parameter("rough", load(DIR + prefix + "_rough.jpg"))
		else:
			m.set_shader_parameter("nmap", load(DIR + prefix + "_normal.png"))
			m.set_shader_parameter("nmap_k", 1.0)
		_hd_mats[key] = m
	return _hd_mats[key]


## The game's own moves that are of the arms and the trunk, made running as often as standing (the lift and the catch
## too: a man picking the ball up at a walk slid on the game's standing legs, 7.7 cm in a step - the owner's note
## "gliding/hovering", kept as tests/owner_notes/2026-11-03_gliding.gd).
const ON_THE_RUN := ["strike", "strike_stick", "hand_pass", "hook", "flick", "block", "tackle", "celebrate", "dejected",
	"lift", "catch"]
## Faster than this (m/s), a move ON_THE_RUN keeps the motion capture's legs, stepping: on the game's own legs, which
## stand, the feet would slide by as much as he moves (at 0.8, as it was, 30 cm a second).
const RUN_LEGS_FROM := 0.3


## After player.gd has posed the game's body this frame: drive this one.
func update(now: float) -> void:
	var dt := clampf(now - _last, 0.0, 0.1) if _last >= 0.0 else 1.0 / 60.0
	_last = now
	if dt <= 0.0:
		return
	_dt = dt
	var mode := "move"
	var act := player.action
	if player.down(now) or (act != "" and not act.begins_with("sig_") and not act in CARRY):
		mode = "full"
	elif act.begins_with("sig_"):
		mode = "upper"
	elif player.ball_stick or player.ball_hand or act in CARRY:
		mode = "upper"
	# A move of the arms made on the run (a strike, a hook, a hand pass...): the legs keep running on the motion
	# capture, the game's move above the hips - the game's own legs, standing in its move while the body ran on, slid
	# across the grass (the owner: "gliding/hovering some when running or strafing sideways").
	if mode == "full" and act in ON_THE_RUN and not player.down(now) and Vector2(player.vel.x, player.vel.z).length() > RUN_LEGS_FROM:
		mode = "upper"
	var pose := reader.read()
	if mode == "upper":
		var up := {}
		for k in pose:
			if _upper.has(k):
				up[k] = pose[k]
		pose = up
	elif mode == "move":
		# Running: the legs, the torso and the free arm from the motion capture; the arm with the hurley as the game
		# carries it (the mocap's runner swings an empty fist, which held the hurley out like a lance).
		var arm := {}
		if player.role == "":
			for k in ["RightShoulder", "RightArm", "RightForeArm", "RightHand"]:
				if pose.has(k):
					arm[k] = pose[k]
		pose = arm
	legacy.set_pose(pose)
	# The hurley's arm where the game's body has it, in the body: so the hand that holds the hurley is where the game
	# put it, whatever the motion capture does with the chest (turns copied onto a differently leaning chest moved
	# the hand by up to 40 cm and turned it by up to 130 degrees: the hurley stood up out of the fist).
	legacy.body_pose = reader.body_space(["RightShoulder", "RightArm", "RightForeArm", "RightHand"]) if player.role == "" else {}
	if mode != _mode:
		var want := 0.0 if mode == "move" and player.role != "" else 1.0
		if _mode == "":
			legacy.weight = want     # (a new body starts as the game's: no blend in from nothing)
		legacy.fade_to(want, 0.16)
		_mode = mode
		mode_since = now
	body.visible = true
	# Put somewhere new (the next free's spot, a substitute, a restart): the feet are not held where they were.
	if _at != Vector3.INF and player.global_position.distance_to(_at) > 1.5:
		loco.planter.reset()
	_at = player.global_position
	var v := player.vel
	loco.drive(dt, Vector3(v.x, 0, v.z), player.yaw, Vector3(player.want_vel.x, 0, player.want_vel.z))
	# A move of the game's own has its feet where the game planted them (Player._plant_feet): the foundation's planter
	# holds them only under the motion capture.
	# A move of the arms (ON_THE_RUN) made at a creep, under RUN_LEGS_FROM, keeps its feet held too: on the game's
	# standing legs, unheld, they slid by as much as he crept (a catch at 0.2 m/s: 4 cm in a step).
	loco.planter.enabled = mode != "full" or (act in ON_THE_RUN and not player.down(now))
	if mode == "full":
		# A move of the game's own: its facing exactly.
		loco.yaw = player.yaw
		body.rotation.y = player.yaw
	if player.role == "":
		_two_hands()
		_grips()
	else:
		_flag_grip()
	# The skeleton's modifiers now, once (WsgBody.set_manual): a far player posed every second or third frame pays
	# for them only then, and shows what they made of him in between.
	body.advance(dt)


## The hands closed on the hurley (and the left as _two_hands left it), each time he is posed.
var _left_grip := [0.016, 1.0, []]
var _on_handle := false
var mode_since := 0.0          # when the mode last changed (the game's own move began or ended)
var _at := Vector3.INF
var _hold_w := 0.0
var _dt := 1.0 / 60.0


## An official's flag (or card) in this body's right hand: the pole across the palm, the fingers closed round it, the
## pole out of the top of the fist (the thumb's side) and its cloth out along the arm. The game's own flag (on its
## unseen body's hand) is hidden; this one is placed when the skeleton has its final pose.
const POLE_R := 0.012
var _flag: MeshInstance3D


func _flag_grip() -> void:
	var f: MeshInstance3D = player._flag
	var on := f != null and f.visible
	if on and _flag == null:
		_flag = MeshInstance3D.new()
		_flag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(_flag)
		body.posed.connect(_place_flag)
	if f != null:
		player._flag_att.visible = false
	if _flag == null:
		return
	_flag.visible = on
	if on:
		_flag.mesh = f.mesh
		_flag.material_override = f.material_override
		_flag.scale = f.scale
		body.grip("Right", POLE_R, 1.0, [WsgGrip.clear_axis_point(body.joints, "Right", POLE_R), FLAG_POLE])
	else:
		body.grip("Right", 0.016, 0.0)


## The flag's pole (its own -Y, from its butt) across the palm as a hammer's handle lies, from the heel of the hand out
## past the thumb and on along the arm's line (the right hand's rest: +Z the thumb's side, -X the fingers'), a little of
## it out of the fist's other side; its cloth (+X) hanging from it on the palm's side (rest -Y). Straight across the
## palm, the pole stood out sideways from a raised arm instead of on up from it.
const FLAG_POLE := Vector3(-0.82, 0.0, 0.57)
static var FLAG_IN_HAND := Basis(Vector3(0, -1, 0), -FLAG_POLE, Vector3(0, -1, 0).cross(-FLAG_POLE))
const FLAG_BUTT := 0.04


func _place_flag() -> void:
	if _flag == null or not _flag.visible:
		return
	var hand := body.bone_world("RightHand")
	var c := WsgGrip.clear_axis_point(body.joints, "Right", POLE_R) - (body.joints["RightHand"] as Vector3) - FLAG_POLE * FLAG_BUTT
	var s := body.global_transform.basis.get_scale()
	_flag.global_transform = Transform3D(hand.basis.orthonormalized() * FLAG_IN_HAND * Basis.from_scale(_flag.scale * s), hand * c)


func _grips() -> void:
	body.grip("Right", HANDLE_R, 1.0, _line_r) if not _line_r.is_empty() else body.grip("Right", 0.016)
	body.grip("Left", _left_grip[0], _left_grip[1], _left_grip[2])


## The top hand on the hurley when the game's body has it there (a swing, a strike, a hook): held to the right hand
## as the game holds it, the fingers closed on the handle; else a loose fist.
func _two_hands() -> void:
	legacy.hold = {}
	_left_grip = [0.016, 1.0, []]
	# (The free fist kept off the handle: a runner's swinging fist went through it.)
	legacy.clear = _clear if stick.visible else {}
	if _line_r.is_empty() or not stick.visible:
		return
	var tk := toon.skeleton
	var tr := tk.get_bone_global_pose(toon.bone("hand_r"))
	var tl := tk.get_bone_global_pose(toon.bone("hand_l"))
	var rest_hand := tk.get_bone_global_rest(toon.bone("hand_r")).origin
	var hp := tr * (_handle_toon - rest_hand)
	var hd := (tr.basis * HeroBody.HURLEY_DIR).normalized()
	# On it: the wrist about a hand's breadth from the handle's axis (a fist round it), along the tape.
	var off := tl.origin - hp
	# Taken hold of when it comes within a hand of the handle, let go only when clearly off it, and fully on between
	# (a hand eased half way between the game's place and the handle went through the handle: in a strike the game's
	# hand is near it for a few frames only).
	var off_axis := (off - hd * off.dot(hd)).length()
	var off_along := absf(off.dot(hd))
	if off_axis < 0.15 and off_along < 0.22:
		_on_handle = true
	elif off_axis > 0.22 or off_along > 0.32:
		_on_handle = false
	# (Taken at once - from within a hand of it, at a swing's speed, unseen; let go over a moment, away from it.)
	_hold_w = 1.0 if _on_handle else move_toward(_hold_w, 0.0, _dt / 0.12)
	var w := smoothstep(0.0, 1.0, _hold_w)
	if w <= 0.0:
		return
	var trp := Transform3D(Basis(tr.basis.get_rotation_quaternion() * (reader._corr["RightHand"] as Quaternion)), tr.origin)
	var tlp := Transform3D(Basis(tl.basis.get_rotation_quaternion() * (reader._corr["LeftHand"] as Quaternion)), tl.origin)
	# The left hand where the game has it, in the right hand's frame; then turned the least way that lays its palm's
	# grip along the handle and slid onto the handle there (the rig's hand is not the game's: placed as the game's,
	# the handle went through the thumb).
	var held := trp.affine_inverse() * tlp
	var jr: Vector3 = body.joints["RightHand"]
	var pt: Vector3 = (_line_r[0] as Vector3) - jr
	var dr: Vector3 = _line_r[1]
	var c := WsgGrip.clear_axis_point(body.joints, "Left", HANDLE_R)
	var v := c - (body.joints["LeftHand"] as Vector3)
	var r0 := held.basis.get_rotation_quaternion()
	var across := r0 * Vector3.BACK
	var to := dr if across.dot(dr) >= 0.0 else -dr
	var rq := Quaternion(across, to) * r0
	var g := held.origin + rq * v
	var on := pt + dr * (g - pt).dot(dr)
	legacy.hold = {"Left": ["RightHand", Transform3D(Basis(rq), on - rq * v), w, dr, v]}
	# (Closing as it comes onto the handle; open at once when it lets go, before it moves off.)
	_left_grip = [HANDLE_R, w * w * w if _on_handle else 0.0, [c, Vector3.BACK]]


## Runs _clear_stick as the skeleton's modifiers run, just after the layer.
class StickClear extends SkeletonModifier3D:
	var link: FoundationLink

	func _process_modification_with_delta(_delta: float) -> void:
		if link != null:
			link._clear_stick(get_skeleton())


## The hurley kept out of this body as it is drawn, once the layer has laid the arms and solved the holds: turned
## about the top fist the least way that takes it clear of the torso (WsgPoseLayer.clear_segment against
## WsgBody.torso_capsule; the hurley as the right hand has it this frame, never as last frame's turn left it), the
## right arm reaching to where that puts the hand and the left hand held on the handle again (the layer's own reach);
## then the lead arm swivelled out of its way (_swivel_clear). (The game's own body keeps its hurley out of its own
## trunk - ToonBody.clear_stick - but this body is deeper in the chest, and its arms are drawn.)
func _clear_stick(sk: Skeleton3D) -> void:
	stick_turn = 0.0
	arm_swivel = 0.0
	if _line_r.is_empty() or not stick.visible or legacy.weight <= 0.0:
		return
	var ih := sk.find_bone("RightHand")
	var total := Quaternion.IDENTITY
	for pass_i in 3:
		var hand := sk.get_bone_global_pose(ih)
		var st := _stick_sk(hand)
		var butt: Vector3 = st[0]
		var tip: Vector3 = st[1]
		var fist: Vector3 = st[2]
		var tc := body.torso_capsule(true)
		# The top fist itself in the chest (the forearm kept out of it, the hand beyond it not): the hand moved straight
		# out of it first - nothing turns the stick clear about a pivot inside.
		var fc: Array = WsgPoseLayer._seg_seg(fist, fist, tc[0], tc[1])
		var fist_in := float(tc[2]) + HANDLE_R + 0.01 - float(fc[2])
		if fist_in > 0.0:
			var out: Vector3 = (fist - (fc[1] as Vector3)).normalized() if float(fc[2]) > 1e-4 else hand.basis.z.normalized()
			legacy._reach(sk, "Right", Transform3D(hand.basis, hand.origin + out * fist_in), 1.0)
			_rehold_left(sk)
			continue
		# (A fist nearer the chest than the margin: as clear as the fist allows - clear_segment turns nothing about a
		# pivot inside its margin.)
		var q := WsgPoseLayer.clear_segment(butt, tip, fist, tc, minf(STICK_CLEAR, float(fc[2]) - float(tc[2]) - 0.005))
		if q.is_equal_approx(Quaternion.IDENTITY):
			break
		total = (q * total).normalized()
		legacy._reach(sk, "Right", Transform3D(Basis(q), fist - q * fist) * hand, 1.0)
		# (The arm reaching there kept out of the chest as the layer keeps it; the next pass sees where that left the
		# stick.)
		legacy._clear_torso(sk, "Right", 1.0, 0.0)
		_rehold_left(sk)
	stick_turn = rad_to_deg(total.get_angle())
	var fin := _stick_sk(sk.get_bone_global_pose(ih))
	arm_swivel = _swivel_clear(sk, "Left", fin[0], fin[1])


## The hurley in the skeleton's space from the right hand's pose: [butt, the bas's foot, the top fist on its axis].
func _stick_sk(hand: Transform3D) -> Array:
	var rq := hand.basis.get_rotation_quaternion()
	var to_stick: Quaternion = rq * (reader._corr["RightHand"] as Quaternion).inverse()
	var g := (toon as HeroBody)._grip()
	var dir := HeroBody.HURLEY_DIR
	return [hand.origin + to_stick * (g - dir * 0.08), hand.origin + to_stick * (g + dir * _stick_len),
		hand.origin + rq * ((_line_r[0] as Vector3) - (body.joints["RightHand"] as Vector3))]


## The side's arm swivelled about its shoulder-to-wrist line - the elbow round, the wrist and the hand's turn where
## they are - the least way (within SWIVEL_MAX, never into the chest) that leaves the upper arm and the forearm
## ARM_CLEAR off the stick's axis beyond their girth; the most clear if none does. Returns the swivel (degrees).
func _swivel_clear(sk: Skeleton3D, side: String, sa: Vector3, sb: Vector3) -> float:
	var ia := sk.find_bone(side + "Arm")
	var ifo := sk.find_bone(side + "ForeArm")
	var ih := sk.find_bone(side + "Hand")
	var ga := sk.get_bone_global_pose(ia)
	var gf := sk.get_bone_global_pose(ifo)
	var gh := sk.get_bone_global_pose(ih)
	var s := ga.origin
	var e := gf.origin
	var w := gh.origin
	var axis := w - s
	if axis.length_squared() < 1e-6:
		return 0.0
	axis = axis.normalized()
	var ru: float = body.limb_capsule(side + "Arm", side + "ForeArm", true)[2]
	var rf: float = body.limb_capsule(side + "ForeArm", side + "Hand", true)[2]
	var tc := body.torso_capsule(true)
	# How clear the arm is with the elbow at e2 (m: the nearer of the two parts), and whether the elbow is in the chest.
	var clear_at := func(e2: Vector3) -> float:
		var du := float(WsgPoseLayer._seg_seg(sa, sb, s, e2)[2]) - ru
		var df := float(WsgPoseLayer._seg_seg(sa, sb, e2, e2.lerp(w, STICK_FOREARM))[2]) - rf
		return minf(du, df)
	var c0: float = clear_at.call(e)
	if c0 >= 0.0:
		return 0.0    # (not through it: an arm round a handle it holds is near it)
	# The hand keeps its turn (it holds the handle), so the forearm turns under it: no swivel that wrings the wrist past
	# what the layer allows it (WsgLegacyPose.WRIST_MAX), or more than it is wrung already.
	var f0: Vector3 = reader._arm[side][1]
	var qh := gh.basis.get_rotation_quaternion()
	var qf0 := gf.basis.get_rotation_quaternion()
	var wring := func(r: Quaternion) -> float:
		return absf(WsgRig.twist_angle(WsgRig.swing_twist(((r * qf0).inverse() * qh).normalized(), f0)[1], f0))
	var wrist_max := maxf(deg_to_rad(WsgLegacyPose.WRIST_MAX), wring.call(Quaternion.IDENTITY))
	# Nor one that points the elbow where an elbow cannot (its bend turned past the layer's TURN_MAX in the chest).
	var ci := sk.get_bone_global_pose(sk.find_bone("Spine2")).basis.get_rotation_quaternion().inverse()
	var turned := func(e2: Vector3) -> float:
		var u := (ci * (e2 - s)).normalized()
		var f := (ci * (w - e2)).normalized()
		return absf(WsgLegacyPose.elbow_turn(u, f)) if u.angle_to(f) > deg_to_rad(25.0) else 0.0
	var turn_max := maxf(deg_to_rad(WsgLegacyPose.TURN_MAX), turned.call(e))
	var best := [0.0, c0]
	# (The way it went last time first, of two as near: the elbow does not flick from one side to the other.)
	var first := -1 if _last_swivel < 0.0 else 1
	for i in range(1, int(SWIVEL_MAX / 5.0) * 2 + 1):
		var phi := deg_to_rad(5.0 * ((i + 1) / 2) * (first if i % 2 == 1 else -first))
		var e2 := s + Quaternion(axis, phi) * (e - s)
		if float(WsgPoseLayer._seg_seg(e2, e2, tc[0], tc[1])[2]) < float(tc[2]) + ru * 0.5:
			continue    # (the elbow into the chest)
		if float(wring.call(Quaternion(axis, phi))) > wrist_max or float(turned.call(e2)) > turn_max:
			continue
		var c: float = clear_at.call(e2)
		if c >= ARM_CLEAR:
			best = [phi, c]
			break
		if c > float(best[1]):
			best = [phi, c]
	var phi_b: float = best[0]
	if phi_b == 0.0:
		return 0.0
	_last_swivel = phi_b
	var r := Quaternion(axis, phi_b)
	var par := sk.get_bone_global_pose(sk.get_bone_parent(ia)).basis.get_rotation_quaternion()
	var qa := (r * ga.basis.get_rotation_quaternion()).normalized()
	var qf := (r * gf.basis.get_rotation_quaternion()).normalized()
	sk.set_bone_pose_rotation(ia, (par.inverse() * qa).normalized())
	sk.set_bone_pose_rotation(ih, (qf.inverse() * gh.basis.get_rotation_quaternion()).normalized())
	return rad_to_deg(phi_b)


## The left hand onto the handle again where the right hand now has it (the layer's hold, solved as the layer does).
func _rehold_left(sk: Skeleton3D) -> void:
	if not legacy.hold.has("Left"):
		return
	var h: Array = legacy.hold["Left"]
	var hw := float(h[2]) * smoothstep(0.0, 1.0, legacy.weight)
	var ai := sk.find_bone(h[0])
	if hw <= 0.0 or ai < 0:
		return
	var ag := sk.get_bone_global_pose(ai)
	var target := ag * (h[1] as Transform3D)
	var grip := []
	if h.size() > 4:
		target.origin += legacy._slide(sk, "Left", target.origin, ag.basis * (h[3] as Vector3))
		grip = [h[4], ag.basis * (h[3] as Vector3)]
	legacy._reach(sk, "Left", target, hw, grip)


## The hurley in this body's right hand, as the game's body holds it in its own. Placed when the skeleton has its
## final pose (body.posed): during the frame a bone reads as it was before the arm's own layer and the grip.
func _place_stick() -> void:
	var hand := body.bone_world("RightHand")
	var corr: Quaternion = reader._corr.get("RightHand", Quaternion.IDENTITY)
	var rest_hand := toon.skeleton.get_bone_global_rest(toon.bone("hand_r")).origin
	var rot := Basis(hand.basis.get_rotation_quaternion() * corr.inverse()).scaled(toon.global_transform.basis.get_scale())
	stick.global_transform = Transform3D(rot, hand.origin) * Transform3D(Basis.IDENTITY, -rest_hand)
