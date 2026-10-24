extends SceneTree
## The Meshy auto-rig's bones (Mixamo's names without the prefix; its spine counted from the hips up as Spine02,
## Spine01, Spine) on Godot's humanoid profile.
func _init() -> void:
	var m := BoneMap.new()
	m.profile = SkeletonProfileHumanoid.new()
	var pairs := {"Hips": "Hips", "Spine": "Spine02", "Chest": "Spine01", "UpperChest": "Spine", "Neck": "neck", "Head": "Head",
		"LeftShoulder": "LeftShoulder", "LeftUpperArm": "LeftArm", "LeftLowerArm": "LeftForeArm", "LeftHand": "LeftHand",
		"RightShoulder": "RightShoulder", "RightUpperArm": "RightArm", "RightLowerArm": "RightForeArm", "RightHand": "RightHand",
		"LeftUpperLeg": "LeftUpLeg", "LeftLowerLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToes": "LeftToeBase",
		"RightUpperLeg": "RightUpLeg", "RightLowerLeg": "RightLeg", "RightFoot": "RightFoot", "RightToes": "RightToeBase"}
	for k in pairs:
		m.set_skeleton_bone_name(k, pairs[k])
	print(ResourceSaver.save(m, "res://meshy_map.tres"))
	quit()
