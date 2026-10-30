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
	body.scale = toon.scale
	body.mesh_instance.material_override = toon.mesh_instance.material_override
	body.mesh_instance.cast_shadow = toon.mesh_instance.cast_shadow
	legacy = WsgPoseLayer.new()
	legacy.name = "Legacy"
	body.skeleton.add_child(legacy)
	body.skeleton.move_child(legacy, 0)
	loco = WsgLocomotor.attach(body)
	reader = WsgLegacyPose.new(toon.skeleton, body.joints)
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


## After player.gd has posed the game's body this frame: drive this one.
func update(now: float) -> void:
	var dt := clampf(now - _last, 0.0, 0.1) if _last >= 0.0 else 1.0 / 60.0
	_last = now
	if dt <= 0.0:
		return
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
	if mode != _mode:
		legacy.fade_to(0.0 if mode == "move" and player.role != "" else 1.0, 0.16)
		_mode = mode
	var v := player.vel
	loco.drive(dt, Vector3(v.x, 0, v.z), player.yaw, Vector3(player.want_vel.x, 0, player.want_vel.z))
	if mode == "full":
		# A move of the game's own: its facing exactly.
		loco.yaw = player.yaw
		body.rotation.y = player.yaw
	if player.role == "":
		body.grip("Right", 0.016)
		body.grip("Left", 0.016)
	if stick:
		_place_stick()


## The hurley in this body's right hand, as the game's body holds it in its own.
func _place_stick() -> void:
	var hand := body.bone_world("RightHand")
	var corr: Quaternion = reader._corr.get("RightHand", Quaternion.IDENTITY)
	var rest_hand := toon.skeleton.get_bone_global_rest(toon.bone("hand_r")).origin
	var rot := Basis(hand.basis.get_rotation_quaternion() * corr.inverse()).scaled(toon.global_transform.basis.get_scale())
	stick.global_transform = Transform3D(rot, hand.origin) * Transform3D(Basis.IDENTITY, -rest_hand)
