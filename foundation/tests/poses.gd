class_name WsgTestPoses
extends RefCounted
## Extreme test poses on the canonical rig (turns from the T-pose), shared by the rig tests and the pose viewer.

static func q(axis: Vector3, deg: float) -> Quaternion:
	return Quaternion(axis.normalized(), deg_to_rad(deg))


## name -> {bone: Quaternion, "hips_y": metres down}
static func all() -> Dictionary:
	var p := {}
	p.rest = {}
	# Both arms straight up over the head, the collarbones lifting with them.
	p.arms_up = {"LeftShoulder": q(Vector3.BACK, 25), "RightShoulder": q(Vector3.FORWARD, 25),
		"LeftArm": q(Vector3.BACK, 65), "RightArm": q(Vector3.FORWARD, 65)}
	# Arms down by the sides (the most common pose in the game: running, standing).
	p.arms_down = {"LeftArm": q(Vector3.FORWARD, 80), "RightArm": q(Vector3.BACK, 80)}
	# Elbows bent hard, forearms forward.
	p.elbows_bent = {"LeftArm": q(Vector3.FORWARD, 75), "RightArm": q(Vector3.BACK, 75),
		"LeftForeArm": q(Vector3.DOWN, 140), "RightForeArm": q(Vector3.UP, 140)}
	# Forearms twisted: the palms turned up (pronation/supination by 150 degrees), arms out.
	p.wrist_twist = {"LeftHand": q(Vector3.RIGHT, 150), "RightHand": q(Vector3.LEFT, 150)}
	# The upper arm spun about its length (an overarm throw's wind-up).
	p.arm_twist = {"LeftArm": q(Vector3.RIGHT, -90), "RightArm": q(Vector3.LEFT, -90),
		"LeftForeArm": q(Vector3.DOWN, 90), "RightForeArm": q(Vector3.UP, 90)}
	# Both hands closed round a 3.2 cm handle in front of the body (a hurley's grip).
	var grip := {"LeftArm": q(Vector3.FORWARD, 70), "RightArm": q(Vector3.BACK, 70),
		"LeftForeArm": q(Vector3.DOWN, 80), "RightForeArm": q(Vector3.UP, 80)}
	for side in ["Left", "Right"]:
		var s := 1.0 if side == "Left" else -1.0
		for f in ["Index", "Middle", "Ring", "Pinky"]:
			grip[side + "Hand" + f + "1"] = q(Vector3.BACK, -55 * s)
			grip[side + "Hand" + f + "2"] = q(Vector3.BACK, -70 * s)
			grip[side + "Hand" + f + "3"] = q(Vector3.BACK, -45 * s)
		grip[side + "HandThumb1"] = q(Vector3.RIGHT, 25 * s)
		grip[side + "HandThumb2"] = q(Vector3.BACK, -30 * s)
	p.grip = grip
	# A deep crouch: thighs forward, knees bent, the body leaning forward over the feet.
	p.crouch = {"hips_y": 0.42, "Spine": q(Vector3.RIGHT, 20), "LeftUpLeg": q(Vector3.RIGHT, -105),
		"RightUpLeg": q(Vector3.RIGHT, -105), "LeftLeg": q(Vector3.RIGHT, 130), "RightLeg": q(Vector3.RIGHT, 130),
		"LeftFoot": q(Vector3.RIGHT, -25), "RightFoot": q(Vector3.RIGHT, -25),
		"LeftArm": q(Vector3.FORWARD, 60), "RightArm": q(Vector3.BACK, 60)}
	# A lunge: one leg far forward, the other back.
	p.lunge = {"hips_y": 0.25, "LeftUpLeg": q(Vector3.RIGHT, -80), "LeftLeg": q(Vector3.RIGHT, 80),
		"RightUpLeg": q(Vector3.RIGHT, 35), "RightLeg": q(Vector3.RIGHT, 30), "RightFoot": q(Vector3.RIGHT, 20),
		"LeftArm": q(Vector3.FORWARD, 80), "RightArm": q(Vector3.BACK, 80)}
	# Bad input on purpose: an elbow and a knee bent the wrong way and a foot cocked up. The drivers must refuse them.
	p.broken = {"LeftForeArm": q(Vector3.UP, 60), "LeftLeg": q(Vector3.RIGHT, -50), "LeftFoot": q(Vector3.RIGHT, -80),
		"LeftArm": q(Vector3.FORWARD, 80), "RightArm": q(Vector3.BACK, 80)}
	return p


static func apply(body: WsgBody, pose: Dictionary) -> void:
	body.reset_pose()
	for k in pose:
		if k == "hips_y":
			var h := body.bone("Hips")
			body.skeleton.set_bone_pose_position(h, body.skeleton.get_bone_rest(h).origin - Vector3(0, pose[k], 0))
		else:
			body.set_turn(k, pose[k])
