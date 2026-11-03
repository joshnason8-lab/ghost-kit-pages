class_name FetchRoute
extends RefCounted
## A walk round a ground's props to anywhere a body can stand (a ball gone behind a stand, a clubhouse, the ball-stop
## net), for the man sent to fetch it (Match.send_fetch). WsgSolidProps.path looks for corners only near the way, so a
## ball-stop net or a stand longer than that was walked into, not round; this searches the whole ground on a grid of
## CELL m (each cell clear if a body with room to spare stands there: WsgSolidProps.penetration), A* across it, then
## keeps only the turns (a straight run wherever the way between two is clear).

const CELL := 0.5
const ROOM := 0.1           # m to spare round the body (no corner cut on a diagonal step besides)

var solid: WsgSolidProps
var lo := Vector2.ZERO
var nx := 0
var nz := 0
var radius := 0.3
var height := 1.8
var _free := PackedByteArray()


func _init(s: WsgSolidProps, area: AABB, body_radius := 0.3, body_height := 1.8) -> void:
	solid = s
	radius = body_radius
	height = body_height
	lo = Vector2(area.position.x, area.position.z)
	nx = int(ceil(area.size.x / CELL)) + 1
	nz = int(ceil(area.size.z / CELL)) + 1
	_free.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			_free[iz * nx + ix] = 1 if _clear(_at(ix, iz), radius + ROOM) else 0


## The waypoints after A on the way to B, B last; [B] alone if there is no way round (or none needed).
func route(a: Vector3, b: Vector3) -> PackedVector3Array:
	b = solid.free_spot(b, radius, height)
	if _line_clear(a, b):
		return PackedVector3Array([b])
	var s := _nearest_free(_cell(a))
	var g := _nearest_free(_cell(b))
	if s < 0 or g < 0:
		return PackedVector3Array([b])
	var cells := _astar(s, g)
	if cells.is_empty():
		return PackedVector3Array([b])
	# The turns only: from each kept point, on to the furthest cell still in a clear straight line.
	var out := PackedVector3Array()
	var from := a
	var i := 0
	while i < cells.size():
		var j := cells.size() - 1
		while j > i and not _line_clear(from, _at(cells[j] % nx, cells[j] / nx)):
			j -= 1
		var p := _at(cells[j] % nx, cells[j] / nx)
		if _line_clear(p, b):
			break
		out.append(p)
		from = p
		i = j + 1
	out.append(b)
	return out


## How far the way is (m) from A along WAY.
static func length(a: Vector3, way: PackedVector3Array) -> float:
	var l := 0.0
	for w in way:
		l += Vector2(w.x - a.x, w.z - a.z).length()
		a = w
	return l


func _at(ix: int, iz: int) -> Vector3:
	return Vector3(lo.x + ix * CELL, 0.0, lo.y + iz * CELL)


func _cell(p: Vector3) -> int:
	var ix := clampi(int(round((p.x - lo.x) / CELL)), 0, nx - 1)
	var iz := clampi(int(round((p.z - lo.y) / CELL)), 0, nz - 1)
	return iz * nx + ix


func _clear(p: Vector3, r: float) -> bool:
	return float(solid.penetration(p, r, height)[0]) <= 0.0


func _line_clear(a: Vector3, b: Vector3) -> bool:
	var d := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var n := int(ceil(d.length() / 0.25))
	for k in range(1, n + 1):
		if not _clear(Vector3(a.x, 0.0, a.z) + d * (float(k) / n), radius + 0.05):
			return false
	return true


func _nearest_free(c: int) -> int:
	if _free[c] == 1:
		return c
	var cx := c % nx
	var cz := c / nx
	for ring in range(1, 6):
		for dz in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				var x := cx + dx
				var z := cz + dz
				if x >= 0 and z >= 0 and x < nx and z < nz and _free[z * nx + x] == 1:
					return z * nx + x
	return -1


func _astar(s: int, g: int) -> PackedInt32Array:
	var gx := g % nx
	var gz := g / nx
	var cost := PackedFloat32Array()
	cost.resize(nx * nz)
	cost.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(nx * nz)
	prev.fill(-1)
	var closed := PackedByteArray()
	closed.resize(nx * nz)
	# (A binary heap of [f, cell].)
	var heap: Array = [[0.0, s]]
	cost[s] = 0.0
	const STEPS := [[1, 0, 1.0], [-1, 0, 1.0], [0, 1, 1.0], [0, -1, 1.0], [1, 1, 1.4142], [1, -1, 1.4142], [-1, 1, 1.4142], [-1, -1, 1.4142]]
	while not heap.is_empty():
		var top: Array = _pop(heap)
		var c: int = top[1]
		if closed[c] == 1:
			continue
		if c == g:
			break
		closed[c] = 1
		var cx := c % nx
		var cz := c / nx
		for st: Array in STEPS:
			var x: int = cx + st[0]
			var z: int = cz + st[1]
			if x < 0 or z < 0 or x >= nx or z >= nz:
				continue
			var n := z * nx + x
			if _free[n] == 0 or closed[n] == 1:
				continue
			# (No corner cut: both sides of a diagonal step clear.)
			if st[0] != 0 and st[1] != 0 and (_free[cz * nx + x] == 0 or _free[z * nx + cx] == 0):
				continue
			var nc: float = cost[c] + float(st[2]) * CELL
			if nc < cost[n]:
				cost[n] = nc
				prev[n] = c
				_push(heap, [nc + Vector2(x - gx, z - gz).length() * CELL, n])
	if prev[g] < 0 and g != s:
		return PackedInt32Array()
	var out := PackedInt32Array()
	var at := g
	while at != s and at >= 0:
		out.append(at)
		at = prev[at]
	out.reverse()
	return out


static func _push(h: Array, e: Array) -> void:
	h.append(e)
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if float(h[p][0]) <= float(e[0]):
			break
		h[i] = h[p]
		i = p
	h[i] = e


static func _pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Array = h.pop_back()
	if h.is_empty():
		return top
	var i := 0
	var n := h.size()
	while true:
		var l := i * 2 + 1
		if l >= n:
			break
		var r := l + 1
		var c := r if r < n and float(h[r][0]) < float(h[l][0]) else l
		if float(h[c][0]) >= float(last[0]):
			break
		h[i] = h[c]
		i = c
	h[i] = last
	return top
