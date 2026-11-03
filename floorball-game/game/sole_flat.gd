class_name SoleFlat
extends WsgFootFlat
## The shared foundation's WsgFootFlat (the boots turned down by the model's own toe-up tilt), with a planted foot's
## toe kept where the planter set it. The turn is about the ankle, and as a planted foot rolls from heel to toe the
## turned toe swung over the floor: 2.3 cm in a jog's step, over the world check's 2.0 (its feet rule, 2026-11-03;
## 0.2 cm without the turn). Here the foot is moved back by what the turn moved its toe across the floor, as much as
## the toe is on the ground (within 4 cm of its standing height: through the heel's lift, when the turn swings it most).
##
##   SoleFlat.attach_to(body)        # in place of WsgFootFlat.attach(body): the skeleton's last modifier


static func attach_to(body: WsgBody) -> SoleFlat:
	var tilt := WsgFootFlat.sole_tilt(body)
	if tilt < MIN_TILT:
		return null
	var ff := SoleFlat.new()
	ff.name = "FootFlat"
	ff.down = deg_to_rad(tilt)
	body.skeleton.add_child(ff)
	return ff


var _toe_rest := 0.0


func _process_modification_with_delta(delta: float) -> void:
	var sk := get_skeleton()
	if sk == null or down == 0.0:
		return
	if _ix.is_empty():
		super(delta)       # (finds the bones; this frame's turn is made here)
		if not _ix.is_empty() and _ix[0][1] >= 0:
			_toe_rest = sk.get_bone_global_rest(_ix[0][1]).origin.y
		return
	var toes := []
	for pair in _ix:
		toes.append(sk.get_bone_global_pose(pair[1]).origin if pair[0] >= 0 and pair[1] >= 0 else Vector3.INF)
	super(delta)
	for i in _ix.size():
		var pair: Array = _ix[i]
		if toes[i] == Vector3.INF:
			continue
		var fp := sk.get_bone_global_pose(pair[0])
		var toe := sk.get_bone_global_pose(pair[1]).origin
		var low := clampf(1.0 - (toe.y - _toe_rest) / 0.04, 0.0, 1.0)
		if low <= 0.0:
			continue
		var moved: Vector3 = toe - (toes[i] as Vector3)
		moved.y = 0.0
		fp.origin -= moved * low
		sk.set_bone_global_pose(pair[0], fp)
