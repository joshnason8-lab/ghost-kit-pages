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
	# stance: {shift, scale} from bakes since the pilots ({} from older ones): rig = (stance point - shift) * scale.
	var c := {"joints": j, "height": float(meta.get("height", 1.8)), "report": meta.get("report", {}),
		"stance": meta.get("stance", {}),
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
	add_to_group("wsg_bodies")     # (WsgReplay keeps what every body draws)
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


## The skeleton's modifiers (the pose layers, the planter, the helpers) run when the game says so (advance), not
## every frame: a body the game poses only every second or third frame (far from the camera) pays for them only
## then, and between those frames shows what they last made of it. (Every frame, 38 bodies' modifiers cost a phone's
## CPU more than the rest of a match.)
var manual := false


func set_manual(on: bool) -> void:
	manual = on
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL if on \
		else Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_IDLE


## After the game has posed the body this frame (manual): its modifiers run, and posed is emitted.
func advance(delta: float) -> void:
	if manual:
		skeleton.advance(delta)


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


## Closes the hand round a ball of radius r (WsgGrip.solve_sphere): centred at ball_point(side, r) (the ball in the
## palm), or at centre (the rest, the joints' space).
func grip_sphere(side: String, r: float, strength := 1.0, centre := Vector3.INF) -> void:
	if not full:
		return
	var g := WsgGrip.solve_sphere(joints, side, r, centre)
	for b in g:
		var i := bone(b)
		var q: Quaternion = g[b]
		skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i).slerp(q, strength) if strength < 1.0 else q)


## Where the centre of a ball of radius r held in that hand is (world): put the ball there (WsgGrip.sphere_point).
func ball_point(side: String, r: float) -> Vector3:
	return bone_world(side + "Hand") * (WsgGrip.sphere_point(joints, side, r) - (joints[side + "Hand"] as Vector3))


## Where a handle of radius r held in that hand has its axis (world transform: origin on the axis, basis.z along it).
func grip_point(side: String, r := 0.016) -> Transform3D:
	var hand := bone_world(side + "Hand")
	var p := WsgGrip.axis_point(joints, side, r) - (joints[side + "Hand"] as Vector3)
	return Transform3D(hand.basis, hand * p)


## The torso as a capsule, in the world, as it is drawn now: [a: Vector3 (by the hips), b: Vector3 (by the neck),
## radius: float]. Its axis is the hips-to-neck line (the one WsgPoseLayer.torso_r keeps the forearms out of), moved
## to the middle of the chest's depth; its radius is the chest's half-depth front to back (a stick through the body
## passes front to back: Hurling's free-take, the hurley through the torso at the end of the swing). Both are measured
## once from the character's mesh (measure_torso); a body without one takes TORSO_K of its hips-to-neck length (0.13
## m on a 1.80 m body). Scaled with the body. Read it where the bones are final: in `posed`, or in a modifier after
## the layers (a game's post-layer, or its make_holds). skeleton_space: in the skeleton's space instead (inside a
## modifier, beside get_bone_global_pose). For a stick: WsgPoseLayer.clear_segment(..., body.torso_capsule()).
##   var cap := body.torso_capsule()      # [a, b, r]
func torso_capsule(skeleton_space := false) -> Array:
	var m := _torso_measure()
	var gx := Transform3D.IDENTITY if skeleton_space else skeleton.global_transform
	var chest := gx.basis * skeleton.get_bone_global_pose(bone("Spine2")).basis
	var off := chest * Vector3(0, 0, float(m[1]))
	var a := gx * skeleton.get_bone_global_pose(bone("Hips")).origin + off
	var b := gx * skeleton.get_bone_global_pose(bone("Neck")).origin + off
	var s := gx.basis.get_scale()
	return [a, b, float(m[0]) * (absf(s.x) + absf(s.z)) * 0.5]


## A body without a mesh (or one too sparse to measure): the torso's radius as a part of its hips-to-neck length.
const TORSO_K := 0.3
static var _torso_cache := {}


## [radius, offset of the axis along the chest's forward (+Z; the rest frame)] from the mesh: the points of its front
## and back between the Spine1 and Spine2 joints, near the middle (within 5 cm of the hips-to-neck line side to side;
## the arms are well out). [] if the mesh has fewer than 6 there.
static func measure_torso(p_joints: Dictionary, mesh: Mesh) -> Array:
	if mesh == null or mesh.get_surface_count() == 0 or not p_joints.has("Spine1"):
		return []
	var a: Vector3 = p_joints.Hips
	var b: Vector3 = p_joints.Neck
	var y0: float = (p_joints.Spine1 as Vector3).y
	var y1: float = (p_joints.Spine2 as Vector3).y
	var front := -INF
	var back := INF
	var n := 0
	for s in mesh.get_surface_count():
		var v: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in v:
			if p.y < y0 or p.y > y1:
				continue
			var ax := a.lerp(b, (p.y - a.y) / maxf(b.y - a.y, 1e-4))
			if absf(p.x - ax.x) < 0.05:
				front = maxf(front, p.z - ax.z)
				back = minf(back, p.z - ax.z)
				n += 1
	if n < 6 or front <= back:
		return []
	return [(front - back) * 0.5, (front + back) * 0.5]


func _torso_measure() -> Array:
	var meshes: Array = character.get("meshes", [])
	var key: int = (meshes[0] as Object).get_instance_id() if not meshes.is_empty() and meshes[0] != null else 0
	if key != 0 and _torso_cache.has(key):
		return _torso_cache[key]
	var m := measure_torso(joints, meshes[0]) if key != 0 else []
	if m.is_empty():
		m = [TORSO_K * ((joints.Neck as Vector3) - (joints.Hips as Vector3)).length(), 0.0]
	if key != 0:
		_torso_cache[key] = m
	return m


## A limb as a capsule, in the world, as it is drawn now: [a: Vector3 (upper_bone's joint), b: Vector3 (lower_bone's
## joint), radius: float]. The bone from the one joint to the next (LeftArm to LeftForeArm: the upper arm; LeftForeArm
## to LeftHand: the forearm); its radius is the limb's girth measured once from the character's mesh (measure_limb),
## else LIMB_K of its length. Scaled with the body. Read it where the bones are final, as torso_capsule. A stick past
## the arm that holds it (Hurling's free: the hurley through the lead upper arm just after contact):
##   var q := WsgPoseLayer.clear_segment(butt, tip, top_fist, body.limb_capsule("LeftArm", "LeftForeArm"), margin)
## [] if either bone is not on the rig.
func limb_capsule(upper_bone: String, lower_bone: String, skeleton_space := false) -> Array:
	var iu := bone(upper_bone)
	var il := bone(lower_bone)
	if iu < 0 or il < 0 or not joints.has(upper_bone) or not joints.has(lower_bone):
		return []
	var gx := Transform3D.IDENTITY if skeleton_space else skeleton.global_transform
	var a := gx * skeleton.get_bone_global_pose(iu).origin
	var b := gx * skeleton.get_bone_global_pose(il).origin
	var s := gx.basis.get_scale()
	return [a, b, _limb_measure(upper_bone, lower_bone) * (absf(s.x) + absf(s.y) + absf(s.z)) / 3.0]


## A body without a mesh: a limb's radius as a part of its length (an upper arm 0.26 m long: 47 mm).
const LIMB_K := 0.18
static var _limb_cache := {}


## The limb's radius from the mesh at rest (the rig's rest is the T: the arms out, clear of the body): the points
## between a fifth and four fifths of the way from upper to lower (the joints' bulges left out) and within half the
## bone's length of its line (the next limb and the torso well out), their distance from the line - the 75th
## percentile of it: most of the girth, the sleeve that hangs below the arm and the triceps included (the hurler's
## upper arm: 60 mm at the median, 74 at this, 90 at the back of the sleeve). 0 if the mesh has fewer than 12 there.
static func measure_limb(p_joints: Dictionary, mesh: Mesh, upper_bone: String, lower_bone: String) -> float:
	if mesh == null or mesh.get_surface_count() == 0 or not p_joints.has(upper_bone) or not p_joints.has(lower_bone):
		return 0.0
	var a: Vector3 = p_joints[upper_bone]
	var b: Vector3 = p_joints[lower_bone]
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 1e-6:
		return 0.0
	var reach := sqrt(len2) * 0.5
	var d := PackedFloat32Array()
	for s in mesh.get_surface_count():
		var v: PackedVector3Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		for p in v:
			var t := (p - a).dot(ab) / len2
			if t < 0.2 or t > 0.8:
				continue
			var r := p.distance_to(a + ab * t)
			if r < reach:
				d.append(r)
	if d.size() < 12:
		return 0.0
	d.sort()
	return d[mini(d.size() - 1, int(d.size() * 0.75))]


func _limb_measure(upper_bone: String, lower_bone: String) -> float:
	var meshes: Array = character.get("meshes", [])
	var mid: int = (meshes[0] as Object).get_instance_id() if not meshes.is_empty() and meshes[0] != null else 0
	var key := "%d|%s|%s" % [mid, upper_bone, lower_bone]
	if _limb_cache.has(key):
		return _limb_cache[key]
	var r := measure_limb(joints, meshes[0], upper_bone, lower_bone) if mid != 0 else 0.0
	if r <= 0.0:
		r = LIMB_K * ((joints[lower_bone] as Vector3) - (joints[upper_bone] as Vector3)).length()
	if mid != 0:
		_limb_cache[key] = r
	return r
