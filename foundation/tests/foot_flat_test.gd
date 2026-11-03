extends SceneTree
## WsgFootFlat: a model standing flat gets none (sole_tilt under MIN_TILT), and the modifier turns the soles down by
## its own `down` as the skeleton is drawn - measured on the skinned mesh in its final pose (the posed signal), the
## left boot's underside heel to toe - and keeps a planted heel on the ground.
##   godot --headless --path . -s tests/foot_flat_test.gd

func _initialize() -> void:
	var fails := []
	var ch := WsgBody.load_character("res://tests/character/", "hero")
	var body := WsgBody.new(ch)
	root.add_child(body)
	var tilt := WsgFootFlat.sole_tilt(body)
	print("test hurler's sole tilt at rest: %.1f deg" % tilt)
	if WsgFootFlat.attach(body) != null and tilt < WsgFootFlat.MIN_TILT:
		fails.append("a model standing flat (%.1f deg) was given a FootFlat" % tilt)
	# The light mesh in (a far body, set_detail): the tilt is still the full model's.
	body.set_detail(false)
	var on_light := WsgFootFlat.sole_tilt(body)
	body.set_detail(true)
	if absf(on_light - tilt) > 0.01:
		fails.append("sole_tilt on the light mesh %.2f deg, on the full %.2f" % [on_light, tilt])
	var before := await _sole(body)
	# Forced: 10 degrees down on this (flat) model, as a toe-up model's would be.
	var ff := WsgFootFlat.new()
	ff.down = deg_to_rad(10.0)
	body.skeleton.add_child(ff)
	var after := await _sole(body)
	print("skinned sole: tilt %+.1f deg, heel %.3f m before; tilt %+.1f deg, heel %.3f m with 10 degrees down" % [before[0], before[1], after[0], after[1]])
	if absf((before[0] - after[0]) - 10.0) > 2.5:
		fails.append("the soles turned %.1f degrees, not 10" % (before[0] - after[0]))
	if absf(after[1] - before[1]) > 0.02:
		fails.append("the planted heel moved %.3f m off where it stood" % (after[1] - before[1]))
	for f in fails:
		printerr("FAIL: ", f)
	print("FOOT FLAT TEST: ", "PASS" if fails.is_empty() else "FAIL (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


## The left boot's underside as drawn (skinned in the final pose): [heel-to-toe tilt (degrees, toe up positive), the
## heel's lowest point (m)].
func _sole(body: WsgBody) -> Array:
	body.skeleton.set_bone_pose_position(0, body.skeleton.get_bone_pose_position(0) + Vector3(0, 1e-5, 0))
	await body.posed
	var sk := body.skeleton
	var mats := []
	for i in sk.get_bone_count():
		mats.append(sk.get_bone_global_pose(i) * Transform3D(Basis.IDENTITY, -sk.get_bone_global_rest(i).origin))
	var arr := (body.mesh_instance.mesh as ArrayMesh).surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var nb := bs.size() / vs.size()
	var pts := []
	var lo := INF
	for v in vs.size():
		if vs[v].y > 0.15 or vs[v].x < 0.03 or vs[v].x > 0.25:
			continue
		var p := Vector3.ZERO
		for j in nb:
			var w := ws[v * nb + j]
			if w > 0.0:
				p += ((mats[bs[v * nb + j]] as Transform3D) * vs[v]) * w
		pts.append(p)
		lo = minf(lo, p.y)
	var bins := {}
	for p: Vector3 in pts:
		if p.y < lo + 0.12:
			var k := int(floor(p.z / 0.02))
			bins[k] = minf(float(bins.get(k, 1e9)), p.y)
	var ks := bins.keys()
	ks.sort()
	var heel := 1e9
	var toe := 1e9
	for i in 3:
		heel = minf(heel, float(bins[ks[i]]))
		toe = minf(toe, float(bins[ks[ks.size() - 1 - i]]))
	var length := (float(ks[-1]) - float(ks[0])) * 0.02
	return [rad_to_deg(atan2(toe - heel, maxf(length, 0.05))), heel]
