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
var _line_r := []           # the hurley's handle in the right hand, at rest (the rig's joints' space): [point, direction]
var _handle_toon := Vector3.ZERO   # the middle of the handle's grip tape (the game's body's rest space)
## The hurley's handle: its grip tape's radius (HeroBody._hurley).
const HANDLE_R := 0.021


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
	var lod := 1 if int(Game.settings.graphics) == Game.GFX_LOW else 0
	body = WsgBody.new(WsgBody.load_character(DIR, prefix), null, lod)
	add_child(body)
	body.visible = false        # till its first pose (a frame of the rig's T-pose with the hurley otherwise)
	body.scale = toon.scale
	body.mesh_instance.material_override = toon.mesh_instance.material_override
	body.mesh_instance.cast_shadow = toon.mesh_instance.cast_shadow
	legacy = WsgPoseLayer.new()
	legacy.name = "Legacy"
	body.skeleton.add_child(legacy)
	body.skeleton.move_child(legacy, 0)
	loco = WsgLocomotor.attach(body)
	legacy.lift_after = loco.planter.hips_offset     # the game's hips height is this body's already
	reader = WsgLegacyPose.new(toon.skeleton, body.joints)
	legacy.arms = reader
	if toon is HeroBody:
		reader.held = {"Right": true}      # the hurley: its turn is the game's, exactly
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
		stick.top_level = true
		add_child(stick)
		body.posed.connect(_place_stick)
		# Where the handle runs through the fist, as drawn (the fingers close on it there).
		var rest_hand := toon.skeleton.get_bone_global_rest(toon.bone("hand_r")).origin
		var dir := HeroBody.HURLEY_DIR.normalized()
		_handle_toon = rest_hand + (toon as HeroBody)._grip() + dir * 0.03
		var cr: Quaternion = reader._corr["RightHand"].inverse()
		_line_r = [(body.joints["RightHand"] as Vector3) + cr * (_handle_toon - rest_hand), cr * dir]


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
	loco.planter.enabled = mode != "full"
	if mode == "full":
		# A move of the game's own: its facing exactly.
		loco.yaw = player.yaw
		body.rotation.y = player.yaw
	if player.role == "":
		_two_hands()
		_grips()


## The hands closed on the hurley (and the left as _two_hands left it), every frame: a far player is posed every
## second or third frame, and between them the motion capture's open hands came back.
var _left_grip := [0.016, 1.0, []]
var _on_handle := false
var mode_since := 0.0          # when the mode last changed (the game's own move began or ended)
var _at := Vector3.INF
var _hold_w := 0.0
var _dt := 1.0 / 60.0


func _process(_delta: float) -> void:
	if body != null and player.role == "":
		_grips()


func _grips() -> void:
	body.grip("Right", HANDLE_R, 1.0, _line_r) if not _line_r.is_empty() else body.grip("Right", 0.016)
	body.grip("Left", _left_grip[0], _left_grip[1], _left_grip[2])


## The top hand on the hurley when the game's body has it there (a swing, a strike, a hook): held to the right hand
## as the game holds it, the fingers closed on the handle; else a loose fist.
func _two_hands() -> void:
	legacy.hold = {}
	_left_grip = [0.016, 1.0, []]
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
	var v := WsgGrip.axis_point(body.joints, "Left", HANDLE_R) - (body.joints["LeftHand"] as Vector3)
	var r0 := held.basis.get_rotation_quaternion()
	var across := r0 * Vector3.BACK
	var to := dr if across.dot(dr) >= 0.0 else -dr
	var rq := Quaternion(across, to) * r0
	var g := held.origin + rq * v
	var on := pt + dr * (g - pt).dot(dr)
	legacy.hold = {"Left": ["RightHand", Transform3D(Basis(rq), on - rq * v), w, dr, v]}
	_left_grip = [HANDLE_R, w * w * w, []]    # (open as it comes onto the handle and goes)


## The hurley in this body's right hand, as the game's body holds it in its own. Placed when the skeleton has its
## final pose (body.posed): during the frame a bone reads as it was before the arm's own layer and the grip.
func _place_stick() -> void:
	var hand := body.bone_world("RightHand")
	var corr: Quaternion = reader._corr.get("RightHand", Quaternion.IDENTITY)
	var rest_hand := toon.skeleton.get_bone_global_rest(toon.bone("hand_r")).origin
	var rot := Basis(hand.basis.get_rotation_quaternion() * corr.inverse()).scaled(toon.global_transform.basis.get_scale())
	stick.global_transform = Transform3D(rot, hand.origin) * Transform3D(Basis.IDENTITY, -rest_hand)
