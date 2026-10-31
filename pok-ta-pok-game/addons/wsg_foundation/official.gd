class_name WsgOfficial
extends Node3D
## A match official on the rig: moves with the play the way referees and umpires do (jogging, side-stepping and
## backpedalling while facing the play: the locomotor's own facing-keeping starts and 8-direction gait), stands and
## watches with head turns, and signals.
##
##   var ref := WsgOfficial.new(WsgBody.load_character(dir, "referee"), material)
##   add_child(ref)
##   ref.follow(delta, velocity, play_point)   # every frame: where he is going, what he watches (and faces)
##   ref.signal_gesture("whistle")              # "whistle", "point", "score", "foul", "both_arms_up", "arm_out"
##   ref.signal_gesture("point", toward)        # with a world point the arm points at
## The signals are poses on the rig until the ActorCore official clips arrive (they then play those: same names).
## Arms go up straight from the side with the collarbone lifting; the elbows are hinges; the hands can hold a flag
## (body.grip / body.grip_point).

const GESTURES := {
	# name: [seconds held, clip to use when the library has it]
	"whistle": [1.0, "Official_Whistle"],
	"point": [1.6, "Official_Point"],
	"score": [1.8, "Official_Score"],
	"foul": [1.6, "Official_Foul"],
	"both_arms_up": [1.8, "Official_Both_Arms_Up"],
	"arm_out": [1.6, "Official_Arm_Out"],
}

var body: WsgBody
var loco: WsgLocomotor
var layer: WsgPoseLayer
var facing := 0.0
var _gesture := ""
var _left := 0.0
var _toward := Vector3.INF


func _init(character := {}, material: Material = null) -> void:
	body = WsgBody.new(character, material)
	add_child(body)
	layer = WsgPoseLayer.new()
	layer.name = "Gesture"
	body.skeleton.add_child(layer)
	body.skeleton.move_child(layer, 0)
	loco = WsgLocomotor.attach(body)


## Every frame: velocity (world, m/s), the point he watches (he faces it), and where he is trying to go if the game
## knows (want: the velocity it is steering him to; it picks his walk or jog starts and stops).
func follow(delta: float, velocity: Vector3, play: Vector3, want := Vector3.INF) -> void:
	var to := play - global_position
	if Vector2(to.x, to.z).length() > 0.5:
		facing = atan2(to.x, to.z)
	loco.drive(delta, velocity, facing, want if want != Vector3.INF else velocity)
	loco.look_at_point(play + Vector3(0, 1.0, 0))
	# Pointing, the chest stays square (the arm is aimed from it; the head still watches).
	if _left > 0.0 and _toward != Vector3.INF:
		loco.look_chest.influence = 0.0
	if _left > 0.0:
		_left -= delta
		if _toward != Vector3.INF:
			layer.set_pose(_pose(_gesture, _toward))
		if _left <= 0.0:
			layer.fade_to(0.0, 0.3)


## A signal: held for its time, eased in and out over the jog or the stand.
func signal_gesture(name: String, toward := Vector3.INF) -> void:
	var g: Array = GESTURES.get(name, [1.5, ""])
	_gesture = name
	_left = g[0]
	_toward = toward
	if WsgClips.has(g[1]):
		loco.play(g[1])
		return
	layer.set_pose(_pose(name, toward))
	layer.fade_to(1.0, 0.22)


## The signal's pose: local turns from the canonical rest, the arms given as the way they point in the chest's frame
## (+Y up, +Z forward, +X his left).
func _pose(name: String, toward: Vector3) -> Dictionary:
	var p := {}
	var dir := Vector3(0, 0, 1)
	if toward != Vector3.INF:
		# The point, in the chest's own frame (the chest turns to watch the play), flattened: an arm points level at
		# it, a little up.
		var local := body.bone_world("Spine2").affine_inverse() * toward
		dir = Vector3(local.x, 0, local.z).normalized() + Vector3(0, 0.15, 0)
	match name:
		"whistle":
			# The right hand to the mouth: upper arm down and forward, elbow bent hard, hand turned in.
			_arm(p, "Right", Vector3(-0.25, -0.55, 0.8), Vector3(0.45, 0.85, 0.25))
			p["RightHand"] = Quaternion(Vector3.LEFT, deg_to_rad(-40))
			p["Head"] = Quaternion(Vector3.RIGHT, deg_to_rad(-4))
		"point", "arm_out", "foul":
			var side := "Left" if dir.x > 0.0 else "Right"
			_arm(p, side, dir.normalized(), dir.normalized())
			if name == "foul":
				var other := "Right" if side == "Left" else "Left"
				_arm(p, other, Vector3(-0.15 if other == "Right" else 0.15, -0.55, 0.8), Vector3(0.45 if other == "Right" else -0.45, 0.85, 0.25))
		"score":
			# One arm straight up from the side, the collarbone lifting with it (an umpire's point; the game's flag in
			# the hand).
			_arm(p, "Right", Vector3(-0.12, 0.99, 0.05), Vector3(-0.08, 0.99, 0.08))
		"both_arms_up":
			_arm(p, "Left", Vector3(0.12, 0.99, 0.05), Vector3(0.08, 0.99, 0.08))
			_arm(p, "Right", Vector3(-0.12, 0.99, 0.05), Vector3(-0.08, 0.99, 0.08))
	return p


## One arm: the upper arm and forearm pointing the given ways (chest frame); the upper arm spun so the elbow's hinge
## holds the forearm (as WsgCrowdClips does), the elbow bent about it.
static func _arm(p: Dictionary, side: String, upper: Vector3, fore: Vector3) -> void:
	var rest := Vector3.RIGHT if side == "Left" else Vector3.LEFT
	var hinge := Vector3.DOWN if side == "Left" else Vector3.UP
	var u := upper.normalized()
	var f := fore.normalized()
	var ga := Quaternion(rest, u)
	var n := u.cross(f)
	if n.length() > 0.05:
		ga = Quaternion(u, (ga * hinge).signed_angle_to(n.normalized(), u)) * ga
	# The collarbone carries part of a raised arm (it lifts as the arm goes past level).
	var lift := clampf(u.y, 0.0, 1.0) * deg_to_rad(18.0)
	var sh := Quaternion(Vector3.BACK if side == "Left" else Vector3.FORWARD, lift)
	p[side + "Shoulder"] = sh
	p[side + "Arm"] = sh.inverse() * ga
	p[side + "ForeArm"] = Quaternion(hinge, u.angle_to(f))
