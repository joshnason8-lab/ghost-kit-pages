class_name WsgBody
extends Node3D
## A character on the World Stage Games rig: its baked mesh (tools/bake_character.gd) skinned to a WsgRig skeleton,
## kept anatomically sound by two WsgRigDriver modifiers (hinges and ankles before IK; joint and twist helpers last).
##
##   var body := WsgBody.new(WsgBody.load_character("res://assets/player/", "hero"), material)
##   add_child(body)
##   body.set_turn("LeftArm", Quaternion(...))      # or let a WsgLocomotor / AnimationPlayer drive it
##
## Faces +Z, its left is +X, the soles at y = 0; 1.80 m tall at scale 1 (scale it for a player's height).

## Emitted after the skeleton's modifiers have run each frame (bone poses final).
signal posed

var character := {}
var skeleton: Skeleton3D
var mesh_instance: MeshInstance3D
var normalize: WsgRigDriver
var helpers: WsgRigDriver
var joints := {}

static var _cache := {}


## A baked character: {"joints": {bone: Vector3}, "meshes": [hi ArrayMesh, lo ArrayMesh], "height": m}.
static func load_character(dir: String, prefix: String) -> Dictionary:
	var key := dir + prefix
	if _cache.has(key):
		return _cache[key]
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(prefix + "_rig.json")))
	var j := {}
	for k in meta.joints:
		var a: Array = meta.joints[k]
		j[k] = Vector3(a[0], a[1], a[2])
	var c := {"joints": j, "height": float(meta.get("height", 1.8)), "report": meta.get("report", {}),
		"meshes": [load(dir.path_join(prefix + "_hi.res")), load(dir.path_join(prefix + "_lo.res"))]}
	_cache[key] = c
	return c


func _init(p_character := {}, material: Material = null, lod := 0) -> void:
	character = p_character
	_lod = clampi(lod, 0, 1)
	joints = character.get("joints", WsgRig.default_joints())
	skeleton = WsgRig.build_skeleton(joints)
	add_child(skeleton)
	normalize = WsgRigDriver.new()
	normalize.name = "Normalize"
	normalize.mode = WsgRigDriver.Mode.NORMALIZE
	skeleton.add_child(normalize)
	helpers = WsgRigDriver.new()
	helpers.name = "Helpers"
	helpers.mode = WsgRigDriver.Mode.HELPERS
	skeleton.add_child(helpers)
	skeleton.skeleton_updated.connect(func(): posed.emit())
	if character.has("meshes"):
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "Mesh"
		mesh_instance.mesh = character.meshes[clampi(lod, 0, 1)]
		mesh_instance.skin = WsgRig.build_skin(joints)
		skeleton.add_child(mesh_instance)
		mesh_instance.skeleton = NodePath("..")
		if material:
			mesh_instance.material_override = material


## Adds a modifier (IK, look-at...) between the two drivers, where it sees sound hinges and is followed by the
## helpers.
## Full detail (twist and joint helpers, fingers closing on what they hold, the character's full mesh), or light (the
## light mesh, plain joints, the fingers as the motion has them): a budget game draws only the bodies nearest the
## camera in full (WsgFoundation.rank_detail).
var full := true
var _lod := 0


func set_detail(p_full: bool) -> void:
	if p_full == full:
		return
	full = p_full
	helpers.active = full
	var meshes: Array = character.get("meshes", [])
	if mesh_instance and meshes.size() > 1:
		mesh_instance.mesh = meshes[maxi(_lod, 0 if full else 1)]


func add_modifier(m: SkeletonModifier3D) -> void:
	skeleton.add_child(m)
	skeleton.move_child(m, helpers.get_index())


func bone(name: String) -> int:
	return skeleton.find_bone(name)


## A bone's turn from the canonical rest, relative to its parent.
func set_turn(name: String, q: Quaternion) -> void:
	skeleton.set_bone_pose_rotation(bone(name), q)


func get_turn(name: String) -> Quaternion:
	return skeleton.get_bone_pose_rotation(bone(name))


## A bone's place and turn in the world.
func bone_world(name: String) -> Transform3D:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone(name))


func reset_pose() -> void:
	skeleton.reset_bone_poses()


## Closes a hand (side "Left" or "Right") round a handle of radius r (m); strength 0 leaves it as the clip has it.
func grip(side: String, r := 0.016, strength := 1.0, line := []) -> void:
	if not full:
		return
	var g := WsgGrip.solve(joints, side, r, line)
	for b in g:
		var i := bone(b)
		var q: Quaternion = g[b]
		skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i).slerp(q, strength) if strength < 1.0 else q)


## Where a handle of radius r held in that hand has its axis (world transform: origin on the axis, basis.z along it).
func grip_point(side: String, r := 0.016) -> Transform3D:
	var hand := bone_world(side + "Hand")
	var p := WsgGrip.axis_point(joints, side, r) - (joints[side + "Hand"] as Vector3)
	return Transform3D(hand.basis, hand * p)
