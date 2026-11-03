class_name WristLimit
extends SkeletonModifier3D
## No wrist bent past MAX_DEG (the owner, 2026-11-03, a golfer's grip: "see how the wrists are straight and not
## looking almost broken?"): after the holds have laid the fists on the stick, a hand turned further than that from its
## forearm's line is turned back toward it, about the wrist. The stick is placed afterwards to run through the top fist
## (FoundationLink._place_stick), so the fist stays on it. Added before the helpers (WsgBody.add_modifier): they follow
## the hand as it ends up.

const MAX_DEG := 55.0
const SIDES := ["Left", "Right"]
var _ix := []         # [forearm, hand, middle knuckle] each side
var _for := -1
## The most a wrist was turned back this frame (degrees, for the tests).
var eased := 0.0


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _for != sk.get_instance_id():
		_for = sk.get_instance_id()
		_ix.clear()
		for side in SIDES:
			_ix.append([sk.find_bone(side + "ForeArm"), sk.find_bone(side + "Hand"), sk.find_bone(side + "HandMiddle1")])
	eased = 0.0
	for b: Array in _ix:
		if (b as Array).has(-1):
			continue
		var fore := sk.get_bone_global_pose(b[0]).origin
		var hand := sk.get_bone_global_pose(b[1])
		var knuckle := sk.get_bone_global_pose(b[2]).origin
		var f := hand.origin - fore
		var h := knuckle - hand.origin
		if f.length() < 0.01 or h.length() < 0.01:
			continue
		var ang := rad_to_deg(f.angle_to(h))
		if ang <= MAX_DEG:
			continue
		var axis := h.cross(f)
		if axis.length() < 1e-6:
			continue
		var turn := deg_to_rad(ang - MAX_DEG)
		hand.basis = Basis(axis.normalized(), turn) * hand.basis
		sk.set_bone_global_pose(b[1], hand)
		eased = maxf(eased, ang - MAX_DEG)
