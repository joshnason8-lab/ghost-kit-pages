extends WsgOwnerNote
## The owner (relayed by the lead), 2026-11-02 (Hurling 0.18.0): "no feet, sunk into the bench"

const NOTE := {"id": "2026-11-02-bench-feet", "game": "hurling", "date": "2026-11-02", "version": "Hurling 0.18.0", "words": "no feet, sunk into the bench"}
const Kit := preload("res://tests/note_kit.gd")

## The substitutes on each side's bench: their soles on the dugout's floor (within 1 cm) and their thighs on the seat
## (within 6 cm of its height), not through it.
func check() -> void:
	var m: Node = await Kit.match(tree, {"mode": "test", "seed": 5, "length": 8.0}, 8)
	var b: Bench = m.bench
	for k in 2:
		var mesh: ArrayMesh = b._mesh[k][0]
		var vs: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var lo := INF
		for v in vs:
			lo = minf(lo, v.y)
		var h: float = b.seat_h[k]
		info("side %d: lowest point %.3f m, thighs at %.2f m (the seat %.2f)" % [k, lo, h, Bench.BENCH_SEAT])
		expect(absf(lo) < 0.01, "side %d: the men's feet %.2f m off the floor" % [k, lo])
		expect(absf(h - Bench.BENCH_SEAT) < 0.06, "side %d: sat %.2f m, the seat is %.2f m" % [k, h, Bench.BENCH_SEAT])
	await Kit.done(tree, m)
