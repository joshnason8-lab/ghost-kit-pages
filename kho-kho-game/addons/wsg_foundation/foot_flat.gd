class_name WsgFootFlat
extends SkeletonModifier3D
## A model whose boots rest toe-up (its soles rise from heel to toe as it stands at rest: the licensed hurler's by 15
## degrees) shows the toes off the ground in every move - the owner, Hurling 0.20: "the feet are pointing upward again
## everywhere". This turns each foot down by the model's own tilt (measured from its mesh: sole_tilt), and sets a foot
## on the ground down by what that turn lifted the heel, so the sole lies on the grass. It must be the LAST of the
## skeleton's modifiers (after WsgFootPlanter: its toe clamp would turn the toes back up):
##
##   WsgFootFlat.attach(body)        # once the locomotor, the layers and the game's own modifiers are in place
##
## A model that already stands flat (under 2 degrees, a boot's toe spring allowed) gets none. From Hurling's FootFlat
## (game/foundation_link.gd, 0.21.1): its match audit's ankle frames went from 86 to 7.

## A boot's own toe spring (degrees): this much rise is the boot, not the model.
const TOE_SPRING := 1.5
## Under this (degrees) the model stands flat: no modifier.
const MIN_TILT := 2.0
## The planted toe is kept in place as much as it is within this of its standing height (m).
const TOE_ON := 0.02

var down := 0.0          # radians to turn each foot toe-down
var _ix := []            # [foot, toe base] for each side
var _ankle_rest := 0.0
var _toe_rest := 0.0
static var _tilt := {}   # mesh -> degrees


## Adds the modifier as the skeleton's last if the body's model stands toe-up; returns it (or null: it stands flat).
static func attach(body: WsgBody) -> WsgFootFlat:
	var tilt := sole_tilt(body)
	if tilt < MIN_TILT:
		return null
	var ff := WsgFootFlat.new()
	ff.name = "FootFlat"
	ff.down = deg_to_rad(tilt)
	body.skeleton.add_child(ff)
	return ff


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or down == 0.0:
		return
	if _ix.is_empty():
		for side in ["Left", "Right"]:
			_ix.append([sk.find_bone(side + "Foot"), sk.find_bone(side + "ToeBase")])
		_ankle_rest = sk.get_bone_global_rest(_ix[0][0]).origin.y
		_toe_rest = sk.get_bone_global_rest(_ix[0][1]).origin.y if _ix[0][1] >= 0 else 0.0
	for pair in _ix:
		if pair[0] < 0 or pair[1] < 0:
			continue
		var fp := sk.get_bone_global_pose(pair[0])
		var tp := sk.get_bone_global_pose(pair[1])
		var fwd := tp.origin - fp.origin
		fwd.y = 0.0
		if fwd.length() < 0.0001:
			continue
		var axis := Vector3.UP.cross(fwd.normalized())
		var g := Transform3D(Basis(Quaternion(axis, down)) * fp.basis, fp.origin)
		# On the ground (the ankle within a few cm of its standing height): down by what the turn raised the heel.
		var low := clampf(1.0 - (fp.origin.y - _ankle_rest) / 0.06, 0.0, 1.0)
		g.origin.y -= _ankle_rest * (1.0 - cos(down)) * 0.6 * low
		sk.set_bone_global_pose(pair[0], g)
		# The turn is about the ankle: as a planted foot rolls heel to toe, the turned toe swung over the floor (a jog
		# step 2.3 cm, 0.2 without this modifier). Moved back by what the turn moved the toe across, as much as the toe
		# is on the ground (within TOE_ON of its standing height) - Floorball's SoleFlat. (4 cm moved a foot just landed,
		# its heel down and its toe still coming down: the heel slid 1-2 cm a frame - Hurling's walker 2.2 cm a step.)
		var toe_now := sk.get_bone_global_pose(pair[1]).origin
		var on := clampf(1.0 - (toe_now.y - _toe_rest) / TOE_ON, 0.0, 1.0)
		if on > 0.0:
			var moved := toe_now - tp.origin
			moved.y = 0.0
			g.origin -= moved * on
			sk.set_bone_global_pose(pair[0], g)


## How far the model's boots' soles rise from heel to toe as it stands at rest (degrees, TOE_SPRING taken off), from
## its mesh (a WsgBody's full one, whichever is showing): the lowest point of the left boot's underside in its back
## and in its front.
static func sole_tilt(b: Node) -> float:
	# A WsgBody's own model, always its full mesh: set_detail swaps the light one in for far bodies (simplified, its
	# boots measure otherwise: Kabaddi's player_03 3.6 degrees on the light mesh, 1.8 on the full).
	var candidates: Array = []
	if b is WsgBody:
		var ms: Array = (b as WsgBody).character.get("meshes", [])
		if not ms.is_empty():
			candidates.append(ms[0])
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		candidates.append((mi as MeshInstance3D).mesh)
	for mesh: Mesh in candidates:
		if mesh == null or mesh.get_surface_count() == 0:
			continue
		if _tilt.has(mesh):
			return float(_tilt[mesh])
		var bins := {}
		var lo := 1e9
		for s in mesh.get_surface_count():
			for q: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				lo = minf(lo, q.y)
		for s in mesh.get_surface_count():
			for q: Vector3 in mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				if q.y < lo + 0.12 and q.x > 0.03 and q.x < 0.25:
					var k := int(floor(q.z / 0.02))
					bins[k] = minf(float(bins.get(k, 1e9)), q.y)
		if bins.size() < 6:
			_tilt[mesh] = 0.0
			return 0.0
		var ks := bins.keys()
		ks.sort()
		var heel := 1e9
		var toe := 1e9
		for i in 3:
			heel = minf(heel, float(bins[ks[i]]))
			toe = minf(toe, float(bins[ks[ks.size() - 1 - i]]))
		var length := (float(ks[-1]) - float(ks[0])) * 0.02
		var t := clampf(rad_to_deg(atan2(toe - heel, maxf(length, 0.05))) - TOE_SPRING, 0.0, 25.0)
		_tilt[mesh] = t
		return t
	return 0.0
