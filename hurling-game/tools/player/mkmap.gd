extends SceneTree
## The Mixamo skeleton's bones on Godot's humanoid profile.
func _init() -> void:
	var m := BoneMap.new()
	m.profile = SkeletonProfileHumanoid.new()
	var pairs := {"Hips": "Hips", "Spine": "Spine", "Chest": "Spine1", "UpperChest": "Spine2", "Neck": "Neck", "Head": "Head",
		"LeftShoulder": "LeftShoulder", "LeftUpperArm": "LeftArm", "LeftLowerArm": "LeftForeArm", "LeftHand": "LeftHand",
		"RightShoulder": "RightShoulder", "RightUpperArm": "RightArm", "RightLowerArm": "RightForeArm", "RightHand": "RightHand",
		"LeftUpperLeg": "LeftUpLeg", "LeftLowerLeg": "LeftLeg", "LeftFoot": "LeftFoot", "LeftToes": "LeftToeBase",
		"RightUpperLeg": "RightUpLeg", "RightLowerLeg": "RightLeg", "RightFoot": "RightFoot", "RightToes": "RightToeBase"}
	for k in pairs:
		m.set_skeleton_bone_name(k, "mixamorig_" + pairs[k])
	print(ResourceSaver.save(m, "res://mixamo_map.tres"))
	quit()
