extends SceneTree
## Fits the Meshy carved ring (assets/people/court_ring.res, from prepare.gd) to the court's ring exactly
## (Court.RING_IN, RING_OUT, RING_DEPTH): its hole is narrower than the game's, so each vertex is moved out from the
## centre in proportion (the hole's edge to RING_IN, the rim to RING_OUT), and the disc set to the ring's depth, along
## +Z. The ball's collision is the code's, so what is seen and what the ball meets are the same stone.
##   godot --headless --path . --script tools/meshy/fit_ring.gd

func _init() -> void:
	var path := "res://assets/people/court_ring.res"
	var m: ArrayMesh = load(path)
	var arr: Array = m.surface_get_arrays(0)
	var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var c := m.get_aabb().get_center()
	var r0 := INF
	var r1 := 0.0
	var z0 := INF
	var z1 := -INF
	for v in vs:
		var r := Vector2(v.x - c.x, v.y - c.y).length()
		r0 = minf(r0, r)
		r1 = maxf(r1, r)
		z0 = minf(z0, v.z)
		z1 = maxf(z1, v.z)
	for i in vs.size():
		var v := vs[i]
		var d := Vector2(v.x - c.x, v.y - c.y)
		var r := d.length()
		var nr := Court.RING_IN + (r - r0) / (r1 - r0) * (Court.RING_OUT - Court.RING_IN)
		var nd := d.normalized() * nr if r > 1e-6 else Vector2.ZERO
		var nz := ((v.z - z0) / (z1 - z0) - 0.5) * Court.RING_DEPTH * 2.0
		vs[i] = Vector3(nd.x, nd.y, nz)
	arr[Mesh.ARRAY_VERTEX] = vs
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	print("hole %.3f -> %.3f, rim %.3f -> %.3f m; ", [r0, Court.RING_IN, r1, Court.RING_OUT], out.get_aabb())
	ResourceSaver.save(out, path, ResourceSaver.FLAG_COMPRESS)
	quit()
