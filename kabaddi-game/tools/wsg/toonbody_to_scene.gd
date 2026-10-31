extends SceneTree
## Turns a mesh baked for the games' 17-bone body (the ToonBody convention six of the seven games share: hips,
## spine, chest, neck, head, upperarm/forearm/hand, thigh/shin/foot, every rest rotation the identity, arms hanging)
## into an ordinary rigged scene with Mixamo names, so tools/bake_character.gd can put it on the World Stage Games rig:
##   godot --headless --path <project> -s toonbody_to_scene.gd -- <mesh.res> <offsets.json> <out.scn>
## offsets.json: {"offsets": {bone: [x, y, z]}} (each bone's offset from its parent at rest, as the games' bakes
## write it). The rig's bones the 17 do not have (Spine1, the collarbones, the toes) are added where they belong,
## with no weight of their own.

const BONES := [["hips", -1], ["spine", 0], ["chest", 1], ["neck", 2], ["head", 3], ["upperarm_l", 2],
	["forearm_l", 5], ["hand_l", 6], ["upperarm_r", 2], ["forearm_r", 8], ["hand_r", 9], ["thigh_l", 0],
	["shin_l", 11], ["foot_l", 12], ["thigh_r", 0], ["shin_r", 14], ["foot_r", 15]]
const NAMES := {"hips": "Hips", "spine": "Spine", "chest": "Spine2", "neck": "Neck", "head": "Head",
	"upperarm_l": "LeftArm", "forearm_l": "LeftForeArm", "hand_l": "LeftHand", "upperarm_r": "RightArm",
	"forearm_r": "RightForeArm", "hand_r": "RightHand", "thigh_l": "LeftUpLeg", "shin_l": "LeftLeg",
	"foot_l": "LeftFoot", "thigh_r": "RightUpLeg", "shin_r": "RightLeg", "foot_r": "RightFoot"}


func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var mesh: ArrayMesh = load(a[0])
	var off: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(a[1])).offsets
	var g := {}
	for b in BONES:
		var o: Array = off[b[0]]
		var v := Vector3(o[0], o[1], o[2])
		g[b[0]] = v if b[1] < 0 else (g[BONES[b[1]][0]] as Vector3) + v
	# The joints by rig name, with the ones the 17 lack.
	var j := {}
	for k in NAMES:
		j[NAMES[k]] = g[k]
	j["Spine1"] = (j["Spine"] as Vector3).lerp(j["Spine2"], 0.5)
	for side in ["Left", "Right"]:
		var arm: Vector3 = j[side + "Arm"]
		var chest: Vector3 = j["Spine2"]
		j[side + "Shoulder"] = Vector3(chest.x + (arm.x - chest.x) * 0.25, arm.y + 0.01, arm.z)
		var ank: Vector3 = j[side + "Foot"]
		j[side + "ToeBase"] = Vector3(ank.x, ank.y * 0.3, ank.z + 0.13)
	var order := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm",
		"LeftHand", "RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot",
		"LeftToeBase", "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]
	var parent := {"Hips": "", "Spine": "Hips", "Spine1": "Spine", "Spine2": "Spine1", "Neck": "Spine2", "Head": "Neck",
		"LeftShoulder": "Spine2", "LeftArm": "LeftShoulder", "LeftForeArm": "LeftArm", "LeftHand": "LeftForeArm",
		"RightShoulder": "Spine2", "RightArm": "RightShoulder", "RightForeArm": "RightArm", "RightHand": "RightForeArm",
		"LeftUpLeg": "Hips", "LeftLeg": "LeftUpLeg", "LeftFoot": "LeftLeg", "LeftToeBase": "LeftFoot",
		"RightUpLeg": "Hips", "RightLeg": "RightUpLeg", "RightFoot": "RightLeg", "RightToeBase": "RightFoot"}
	var root := Node3D.new()
	root.name = "Character"
	var sk := Skeleton3D.new()
	sk.name = "Skeleton3D"
	root.add_child(sk)
	sk.owner = root
	for n in order:
		sk.add_bone(n)
	for n in order:
		var i := sk.find_bone(n)
		var p: String = parent[n]
		if p != "":
			sk.set_bone_parent(i, sk.find_bone(p))
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, (j[n] as Vector3) - (j[p] as Vector3 if p != "" else Vector3.ZERO)))
	sk.reset_bone_poses()
	# The mesh's bone indices are BONES' order: bind each to its rig name.
	var skin := Skin.new()
	for b in BONES:
		skin.add_named_bind(NAMES[b[0]], Transform3D(Basis.IDENTITY, -(g[b[0]] as Vector3)))
	var mi := MeshInstance3D.new()
	mi.name = "Body"
	mi.mesh = mesh.duplicate()   # embedded: the scene stands on its own
	mi.skin = skin
	sk.add_child(mi)
	mi.owner = root
	mi.skeleton = NodePath("..")
	var ps := PackedScene.new()
	ps.pack(root)
	print(a[2], " ", error_string(ResourceSaver.save(ps, a[2])))
	quit()
