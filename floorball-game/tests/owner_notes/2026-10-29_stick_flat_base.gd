extends WsgOwnerNote
## The owner, 2026-10-29 (Floorball 0.9).

const NOTE := {"id": "2026-10-29-stick-flat-base", "game": "floorball", "date": "2026-10-29", "version": "0.9",
	"words": "the stick looks like it’s flat at the base where you hit the ball "}


## The stick every player carries (RiggedBody.stick_mesh, as the game draws it at every level): its blade is a blade -
## at least 6 cm tall and 15 cm long at the bottom of the stick, with a body to it (at least 1.5 cm through), not a
## flat end on the shaft.
func check() -> void:
	var mesh: Mesh = RiggedBody.stick_mesh()
	if mesh == null:
		fail("no stick mesh")
		return
	var pts := PackedVector3Array()
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		pts.append_array(arr[Mesh.ARRAY_VERTEX])
	var lo := INF
	var hi := -INF
	for p in pts:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	# The blade: the bottom 12 cm of the stick.
	var bb := AABB()
	var first := true
	for p in pts:
		if p.y <= lo + 0.12:
			bb = AABB(p, Vector3.ZERO) if first else bb.expand(p)
			first = false
	var dims := [bb.size.x, bb.size.z]
	dims.sort()
	info("the stick %.2f m long; its blade %.3f m tall in its bottom, %.3f m long, %.3f m through" % [hi - lo, minf(bb.size.y, 0.12), dims[1], dims[0]])
	expect(dims[1] >= 0.15, "the blade is only %.3f m long" % dims[1])
	expect(dims[0] >= 0.015, "the blade is flat (%.3f m through)" % dims[0])
	expect(bb.size.y >= 0.06, "the blade is only %.3f m tall" % bb.size.y)
