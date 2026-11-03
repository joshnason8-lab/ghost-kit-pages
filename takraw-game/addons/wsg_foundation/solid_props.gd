class_name WsgSolidProps
extends RefCounted
## The owner: "These games live in a world of reality. There will NEVER be a time when a player or referee should
## walk through a table or bench etc. A ball should also bounce off these items. Every asset was built to be a
## tangible object."
##
## A venue's props as simple solid shapes (boxes, upright cylinders, capsules), and the questions a game's own movement
## asks of them. The games move their bodies and balls themselves (analytic integrators, not Godot physics), so this
## is a query set, cheap enough for Low (a grid of 2 m cells; simple shapes only):
##
##   var solid := WsgSolidProps.new()
##   solid.add({"name": "officials' table", "kind": "box", "xf": Transform3D(Basis(Vector3.UP, yaw), centre),
##       "size": Vector3(1.8, 0.76, 0.8), "material": "wood"})
##   solid.add({"name": "pole", "kind": "cylinder", "position": base, "radius": 0.05, "height": 1.2, "material": "wood"})
##   solid.add({"name": "crossbar", "kind": "capsule", "a": left, "b": right, "radius": 0.04, "material": "metal"})
##   solid.register(venue_root)     # or from the scene's nodes (each mesh's own box), with opt-outs
##
##   # A body's step (players, officials, substitutes, coaches):
##   vel = solid.steer(pos, vel, RADIUS, HEIGHT, goal, memo)   # around what is in the way (memo: the body's own {})
##   pos += vel * dt
##   pos = solid.push_out(pos, RADIUS, HEIGHT)            # never inside a prop, whatever else moved it
##   target = solid.free_spot(target, RADIUS, HEIGHT)     # an AI's spot inside a prop: the nearest free one
##   var way := solid.path(pos, target, RADIUS, HEIGHT)   # an out-of-play walk around the props (waypoints)
##
##   # The ball, whatever its speed (continuous: swept along its whole step):
##   var r := solid.bounce(ball_pos, ball_vel, BALL_R, dt, func(hit): Audio.play_at(knock[hit.material], hit.pos, ...))
##   ball_pos = r.pos; ball_vel = r.vel
##
## A game on Godot physics gets the same props as StaticBody3D colliders on the props layer (make_bodies), with each
## material's bounce and friction; its ball's RigidBody3D wants continuous_cd on. prop_audit (WsgPropAudit,
## tools/prop_audit.gd) checks a match for any body inside a prop or ball through one. ADOPTING.md §5.15.

## Godot's physics layer for the props (make_bodies), 1-based as the editor shows it.
const PROPS_LAYER := 9
## A prop whose top is this little above a body's feet does not stop it (a line, a mat's edge, a cable cover).
const STEP := 0.12
## The grid's cells (m).
const CELL := 2.0

## Per material: restitution (a ball's speed into it kept, 0..1), friction (along it lost on a bounce, 0..1), the
## sound kind (WsgAudio.play_at's kind, crisp at a distance: bright_kinds).
const MATERIALS := {
	"wood": {"restitution": 0.55, "friction": 0.30, "sound": "hit"},
	"metal": {"restitution": 0.70, "friction": 0.15, "sound": "clang"},
	"plastic": {"restitution": 0.60, "friction": 0.25, "sound": "hit"},
	"padding": {"restitution": 0.25, "friction": 0.55, "sound": "bounce"},
	"net": {"restitution": 0.10, "friction": 0.80, "sound": "net"},
	"fabric": {"restitution": 0.15, "friction": 0.70, "sound": "bounce"},
	"stone": {"restitution": 0.60, "friction": 0.35, "sound": "hit"},
	"concrete": {"restitution": 0.60, "friction": 0.40, "sound": "hit"},
	"glass": {"restitution": 0.75, "friction": 0.10, "sound": "hit"},
	"plaster": {"restitution": 0.50, "friction": 0.40, "sound": "hit"},
	"earth": {"restitution": 0.35, "friction": 0.60, "sound": "bounce"},
	"chainlink": {"restitution": 0.30, "friction": 0.50, "sound": "clang"},
}

## Every prop: {name, kind ("box" | "cylinder" | "capsule"), material, ball (a ball bounces off it), walk (bodies keep
## out of it), aabb, and its shape: box {xf, half}, cylinder {a (base centre), b (top centre), radius}, capsule
## {a, b, radius}}.
var props: Array = []
## Props left out on purpose: [{name, reason}] (register's opt-outs; a game's own with skip()).
var skipped: Array = []

var _grid := {}       # Vector2i -> PackedInt32Array of prop indices
var _planes := PackedInt32Array()    # the floors (in every sweep)
# Each prop's footprint, packed for the bodies' many questions a frame: kind (0 box, 1 upright cylinder, 2 capsule,
# 3 none), centre or a, b, the box's own x and z, half x and z, radius, bottom and top, solid to bodies.
var _wk := PackedInt32Array()
var _wc := PackedVector2Array()
var _wb := PackedVector2Array()
var _wax := PackedVector2Array()
var _waz := PackedVector2Array()
var _wh := PackedVector2Array()
var _wr := PackedFloat32Array()
var _wy := PackedVector2Array()
var _ww := PackedByteArray()


## A prop. spec: name; kind "box" (also "panel": a thin box) with xf (Transform3D: the box's centre and turn) or
## position (its base's centre on the ground) and yaw, and size (Vector3, m); "cylinder" (upright) with position (its
## base's centre), radius and height; "capsule" (a rail, a crossbar, a tube) with a, b and radius. material (MATERIALS;
## default "wood"); ball and walk (default true: what is solid to what). Returns its index.
func add(spec: Dictionary) -> int:
	var kind := String(spec.get("kind", "box"))
	var p := {"name": String(spec.get("name", "prop %d" % props.size())), "material": String(spec.get("material", "wood")),
		"ball": bool(spec.get("ball", true)), "walk": bool(spec.get("walk", true))}
	if not MATERIALS.has(p.material):
		push_warning("WsgSolidProps: no material '%s' (%s): taken as wood" % [p.material, p.name])
		p.material = "wood"
	match kind:
		"box", "panel":
			var size: Vector3 = spec.get("size", Vector3.ONE)
			var xf: Transform3D
			if spec.has("xf"):
				xf = spec.xf
			else:
				var base: Vector3 = spec.get("position", Vector3.ZERO)
				xf = Transform3D(Basis(Vector3.UP, float(spec.get("yaw", 0.0))), base + Vector3.UP * size.y * 0.5)
			# (A scaled basis: its scale goes into the size.)
			var sc := xf.basis.get_scale()
			p.kind = "box"
			p.xf = Transform3D(xf.basis.orthonormalized(), xf.origin)
			p.half = (size * sc * 0.5).abs()
			p.inv = p.xf.affine_inverse()
			p.aabb = p.xf * AABB(-p.half, p.half * 2.0)
		"cylinder":
			var base: Vector3 = spec.get("position", Vector3.ZERO)
			p.kind = "cylinder"
			p.a = base
			p.b = base + Vector3.UP * float(spec.get("height", 1.0))
			p.radius = float(spec.get("radius", 0.05))
			p.aabb = AABB(base - Vector3(p.radius, 0, p.radius), Vector3(p.radius * 2.0, p.b.y - base.y, p.radius * 2.0))
		"floor":
			# The ground the ball bounces on (an endless level plane): a game's own floor clamp after bounce() can carry
			# a ball that went under a prop's base up through it; register the floor and the ball meets it in the sweep.
			p.kind = "floor"
			p.y = float(spec.get("y", 0.0))
			p.walk = false
			p.aabb = AABB(Vector3(-1e6, p.y - 1.0, -1e6), Vector3(2e6, 1.0, 2e6))
			var fi := props.size()
			props.append(p)
			_planes.append(fi)
			_pack(fi)
			return fi
		"capsule":
			p.kind = "capsule"
			p.a = spec.get("a", Vector3.ZERO)
			p.b = spec.get("b", Vector3.UP)
			p.radius = float(spec.get("radius", 0.05))
			var lo: Vector3 = (p.a as Vector3).min(p.b) - Vector3.ONE * p.radius
			var hi: Vector3 = (p.a as Vector3).max(p.b) + Vector3.ONE * p.radius
			p.aabb = AABB(lo, hi - lo)
		_:
			push_error("WsgSolidProps.add: no kind '%s' (%s)" % [kind, p.name])
			return -1
	var i := props.size()
	props.append(p)
	_index(i)
	_pack(i)
	return i


## A ring (a netball or basketball ring, a stone ring on a wall): SEGMENTS capsules round CENTRE, RADIUS out to the
## tube's middle, TUBE thick, in the plane square to AXIS (up: a level ring). A ball through its middle passes; one on
## the tube bounces off it. spec: name, centre, radius, tube, axis (Vector3.UP), segments (16), material ("metal"),
## ball (true), walk (false: overhead). Returns the capsules' indices.
func add_ring(spec: Dictionary) -> PackedInt32Array:
	var c: Vector3 = spec.get("centre", Vector3.ZERO)
	var r := float(spec.get("radius", 0.2))
	var axis: Vector3 = (spec.get("axis", Vector3.UP) as Vector3).normalized()
	var u := axis.cross(Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	var v := axis.cross(u)
	var n := int(spec.get("segments", 16))
	var out := PackedInt32Array()
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		out.append(add({"name": String(spec.get("name", "ring")), "kind": "capsule",
			"a": c + (u * cos(a0) + v * sin(a0)) * r, "b": c + (u * cos(a1) + v * sin(a1)) * r,
			"radius": float(spec.get("tube", 0.01)), "material": String(spec.get("material", "metal")),
			"ball": bool(spec.get("ball", true)), "walk": bool(spec.get("walk", false))}))
	return out


## A prop deliberately not solid, and why (a ground decal, a banner overhead): kept in `skipped` for the audit's report.
func skip(name: String, reason: String) -> void:
	skipped.append({"name": name, "reason": reason})


## Every mesh under ROOT as a solid box (its own bounds, turned as it is; a MultiMesh: each instance), unless it, or a
## node above it, opts out: meta "wsg_solid" false with "wsg_solid_reason" (kept in `skipped`), or the group
## "wsg_not_solid". Left out without asking: anything flatter than min_height (lines, decals), anything wider than
## max_size (the ground, a stadium's shell: declare its parts with add()), and names in skip_names. The material from
## the name (bench: wood; goal, post, pole, rail: metal; board, chair: plastic; net; mat, pad: padding; tent, banner:
## fabric; wall, step: concrete; glass), else options.material. options: min_height (0.05), max_size (20),
## skip_names ([ground, floor, pitch, court, grass, line, sky, crowd]), material ("wood"), ball, walk (true).
## Returns how many it added.
func register(root: Node, options: Dictionary = {}) -> int:
	var min_h := float(options.get("min_height", 0.05))
	var max_size := float(options.get("max_size", 20.0))
	var skip_names: Array = options.get("skip_names", ["ground", "floor", "pitch", "court", "grass", "line", "sky", "crowd"])
	var added := 0
	var nodes: Array = root.find_children("*", "GeometryInstance3D", true, false)
	if root is GeometryInstance3D:
		nodes.push_front(root)
	for n in nodes:
		var gi := n as GeometryInstance3D
		if not (gi is MeshInstance3D or gi is MultiMeshInstance3D):
			continue
		var why := _opted_out(gi, root)
		if why != "":
			skipped.append({"name": String(gi.name), "reason": why})
			continue
		var lname := String(gi.name).to_lower()
		var named_out := false
		for sn in skip_names:
			if lname.contains(String(sn)):
				named_out = true
		if named_out:
			continue
		var mat := _guess_material(lname, String(options.get("material", "wood")))
		var boxes := []   # [Transform3D, AABB]
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			boxes.append([gi.global_transform, (gi as MeshInstance3D).mesh.get_aabb()])
		elif gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh and (gi as MultiMeshInstance3D).multimesh.mesh:
			var mm := (gi as MultiMeshInstance3D).multimesh
			var ab := mm.mesh.get_aabb()
			for k in mm.instance_count:
				boxes.append([gi.global_transform * mm.get_instance_transform(k), ab])
		for bx in boxes:
			var xf: Transform3D = bx[0]
			var ab: AABB = bx[1]
			var size := ab.size * xf.basis.get_scale()
			if size.y < min_h or maxf(size.x, size.z) > max_size:
				continue
			add({"name": String(gi.name), "kind": "box", "xf": Transform3D(xf.basis.orthonormalized(), xf * ab.get_center()),
				"size": size, "material": mat, "ball": bool(options.get("ball", true)), "walk": bool(options.get("walk", true))})
			added += 1
	return added


# ---------------------------------------------------------------- bodies

## Where a body standing at POS (its feet) of RADIUS and HEIGHT is nearest that it touches no prop (it walks through
## none): pushed straight out of each it is in, a few passes for corners. Props with walk false, and those whose top
## is under STEP above the feet, are not in the way.
func push_out(pos: Vector3, radius: float, height := 1.8) -> Vector3:
	var p2 := Vector2(pos.x, pos.z)
	for pass_i in 4:
		var moved := false
		for i in _near2(p2, radius + 0.05):
			if not _blocks(i, pos.y, height) or _sdi(i, p2) >= radius:
				continue
			var sd: Array = _sd2(props[i], p2)
			if float(sd[0]) < radius:
				p2 += (sd[1] as Vector2) * (radius - float(sd[0]) + 0.001)
				moved = true
		if not moved:
			break
	return Vector3(p2.x, pos.y, p2.y)


## How far a body at POS goes into the props: [depth (m, 0 if clear), the prop's index or -1].
func penetration(pos: Vector3, radius: float, height := 1.8) -> Array:
	var p2 := Vector2(pos.x, pos.z)
	var worst := 0.0
	var which := -1
	for i in _near2(p2, radius):
		if not _blocks(i, pos.y, height):
			continue
		var d := radius - _sdi(i, p2)
		if d > worst:
			worst = d
			which = i
	return [worst, which]


## A body's whole step among the props (what a game's movement calls each frame, then hands the velocity to its
## WsgLocomotor, which animates what the game moves): steered round what is in the way, moved, and pushed out of
## anything it still touches. Returns [the new position, the velocity it really moved at].
func move(pos: Vector3, vel: Vector3, dt: float, radius: float, height := 1.8, goal := Vector3.INF,
		memo: Dictionary = {}) -> Array:
	var v := steer(pos, vel, radius, height, goal, memo)
	var to := push_out(pos + v * dt, radius, height)
	return [to, (to - pos) / dt if dt > 0.0 else v]


## The nearest spot to TARGET a body can stand on, clear of every prop (an AI's target inside a bench: in front of it).
func free_spot(target: Vector3, radius: float, height := 1.8) -> Vector3:
	var p := push_out(target, radius, height)
	if float(penetration(p, radius, height)[0]) <= 0.002:
		return p
	for ring in range(1, 21):
		var d := ring * 0.25
		for k in 16:
			var q := target + Vector3(cos(k * TAU / 16.0), 0, sin(k * TAU / 16.0)) * d
			if float(penetration(q, radius, height)[0]) <= 0.0:
				return q
	return p


## A body's velocity turned around what is in the way, its speed kept: of 16 directions about the one it wants, the
## one that goes most its way with nothing in reach for `look` m (or to GOAL, if nearer); none in reach: VEL as given.
## Bodies keep to the side they are already on (no dithering at a pole's middle).
## MEMO: a Dictionary the game keeps for the body (one each) - the side it chose round what is in its way, kept while
## the way stays blocked, so it goes on round a long bench instead of turning back and forth at its middle.
func steer(pos: Vector3, vel: Vector3, radius: float, height := 1.8, goal := Vector3.INF, memo: Dictionary = {},
		look := 1.6) -> Vector3:
	var flat := Vector2(vel.x, vel.z)
	var speed := flat.length()
	if speed < 0.01:
		return vel
	var p2 := Vector2(pos.x, pos.z)
	if goal != Vector3.INF:
		look = minf(look, Vector2(goal.x, goal.z).distance_to(p2) + radius)
	var near := PackedInt32Array()
	var side := 0.0
	var nearest := INF
	for i in _near2(p2, look + radius):
		if _blocks(i, pos.y, height):
			near.append(i)
			var sd := _sdi(i, p2)
			if sd < nearest:
				nearest = sd
				# The side the body is on: the prop's surface normal across the way it wants to go.
				side = signf(flat.normalized().cross(-(_sd2(props[i], p2)[1] as Vector2)))
	if near.is_empty():
		memo.erase("side")
		return vel
	var want := flat / speed
	if _ray_clear(p2, want, look, radius, near) >= look:
		memo.erase("side")
		return vel
	var keep := float(memo.get("side", 0.0))
	var best := want
	var best_score := -INF
	var best_sign := 0.0
	for pass_i in 2:
		for k in range(1, 7):
			for sgn in [1.0, -1.0]:
				if keep != 0.0 and pass_i == 0 and sgn != keep and k < 6:
					continue
				var ang: float = sgn * k * PI / 6.0
				var d := want.rotated(ang)
				var free := _ray_clear(p2, d, look, radius, near)
				if free < radius * 0.5 and k < 6:
					continue
				var score := d.dot(want) - (1.0 - free / look) * 2.0 + (0.08 if signf(ang) == -side else 0.0)
				if score > best_score:
					best_score = score
					best = d
					best_sign = sgn
		if best_score > -INF:
			break
		keep = 0.0
	memo["side"] = best_sign
	return Vector3(best.x * speed, vel.y, best.y * speed)


## A walk from A to B around the props (an out-of-play walk: a substitute to the bench, an official to their spot, a
## player fetching the ball): the waypoints after A, B last (B moved to its nearest free spot). Straight if nothing is
## in the way.
func path(a: Vector3, b: Vector3, radius: float, height := 1.8) -> PackedVector3Array:
	b = free_spot(b, radius, height)
	if _seg_clear(a, b, radius, height):
		return PackedVector3Array([b])
	# Corners round the props near the way (each pushed out past the body's radius), joined where the way is clear.
	var lo := Vector2(minf(a.x, b.x), minf(a.z, b.z)) - Vector2(8, 8)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.z, b.z)) + Vector2(8, 8)
	var nodes: Array = [a, b]
	var m := radius + 0.15
	for i in _near_rect(lo, hi):
		var pr: Dictionary = props[i]
		if not pr.walk or not _in_height(pr, a.y, height):
			continue
		for c in _corners2(pr, m):
			var q := Vector3(c.x, a.y, c.y)
			if float(penetration(q, radius, height)[0]) <= 0.0:
				nodes.append(q)
	var n := nodes.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var done := PackedByteArray()
	done.resize(n)
	dist[0] = 0.0
	# Dijkstra over the clear joins (a few dozen corners: cheap, and only for out-of-play walks).
	for it in n:
		var u := -1
		var best := INF
		for j in n:
			if done[j] == 0 and dist[j] < best:
				best = dist[j]
				u = j
		if u < 0 or u == 1:
			break
		done[u] = 1
		for v in n:
			if done[v] == 1 or v == u:
				continue
			var w: float = (nodes[u] as Vector3).distance_to(nodes[v])
			if dist[u] + w < dist[v] and _seg_clear(nodes[u], nodes[v], radius, height):
				dist[v] = dist[u] + w
				prev[v] = u
	if prev[1] < 0:
		return PackedVector3Array([b])
	var out := []
	var at := 1
	while at > 0:
		out.push_front(nodes[at])
		at = prev[at]
	return PackedVector3Array(out)


# ---------------------------------------------------------------- the ball

## The first prop a ball of RADIUS meets moving from P0 to P1 (swept along the whole way: none passed through at any
## speed): {hit: bool, t (0..1 along), pos (the ball's centre at the touch), normal, prop (index), name, material}.
## A ball starting inside one is a hit at t 0, its normal the way out.
func sweep(p0: Vector3, p1: Vector3, radius: float) -> Dictionary:
	var best := {"hit": false, "t": 1.0}
	var lo := p0.min(p1) - Vector3.ONE * radius
	var hi := p0.max(p1) + Vector3.ONE * radius
	var cand := _near_rect(Vector2(lo.x, lo.z), Vector2(hi.x, hi.z))
	cand.append_array(_planes)
	for i in cand:
		var pr: Dictionary = props[i]
		if not pr.ball:
			continue
		var ab: AABB = pr.aabb
		if pr.kind != "floor" and not ab.grow(radius).intersects(AABB(lo, hi - lo)):
			continue
		var h: Array = _sweep_one(pr, p0, p1, radius)
		if not h.is_empty() and (not best.hit or float(h[0]) < float(best.t)):
			best = {"hit": true, "t": float(h[0]), "normal": h[1], "prop": i, "name": pr.name, "material": pr.material,
				"depth": float(h[2]) if h.size() > 2 else 0.0}
	if best.hit:
		best.pos = p0.lerp(p1, float(best.t))
	return best


## A ball's step of DT: moved, and bounced off every prop it meets on the way (each material's restitution and
## friction), however fast. ON_HIT (optional) is called with each hit (sweep's, plus "speed": the speed into the prop,
## and "sound": the material's sound kind) - the knock's sound. Returns {pos, vel, hits: [...]}.
func bounce(pos: Vector3, vel: Vector3, radius: float, dt: float, on_hit: Callable = Callable()) -> Dictionary:
	var hits := []
	var left := dt
	for k in 4:
		if left <= 0.0:
			break
		var to := pos + vel * left
		var h := sweep(pos, to, radius)
		if not h.hit:
			pos = to
			left = 0.0
			break
		var n: Vector3 = h.normal
		var into := vel.dot(n)
		# (Started inside, a game having moved it in: out by as deep as it was.)
		pos = (h.pos as Vector3) + n * (float(h.depth) + 0.002)
		left *= 1.0 - float(h.t)
		if into < 0.0:
			var m: Dictionary = MATERIALS[h.material]
			var vn := n * into
			var vt := vel - vn
			vel = vt * (1.0 - float(m.friction)) - vn * float(m.restitution)
			h.speed = -into
			h.sound = m.sound
			hits.append(h)
			if on_hit.is_valid():
				on_hit.call(h)
	return {"pos": pos, "vel": vel, "hits": hits}


# ---------------------------------------------------------------- Godot physics

## The props as StaticBody3D colliders under PARENT on the props layer (PROPS_LAYER), each with its material's bounce
## and friction (a game on Godot physics: its bodies' masks take the layer; its ball's RigidBody3D wants continuous_cd).
## Only the ball-solid or walk-solid ones. Returns the bodies.
func make_bodies(parent: Node, layer := PROPS_LAYER) -> Array:
	var out := []
	for pr: Dictionary in props:
		if not pr.ball and not pr.walk:
			continue
		var body := StaticBody3D.new()
		body.name = "Solid_" + String(pr.name).validate_node_name()
		body.collision_layer = 1 << (layer - 1)
		body.collision_mask = 0
		var pm := PhysicsMaterial.new()
		pm.bounce = float(MATERIALS[pr.material].restitution)
		pm.friction = float(MATERIALS[pr.material].friction)
		body.physics_material_override = pm
		var cs := CollisionShape3D.new()
		match String(pr.kind):
			"floor":
				cs.shape = WorldBoundaryShape3D.new()
				body.position = Vector3(0, pr.y, 0)
			"box":
				var bs := BoxShape3D.new()
				bs.size = (pr.half as Vector3) * 2.0
				cs.shape = bs
				body.transform = pr.xf
			"cylinder":
				var cy := CylinderShape3D.new()
				cy.radius = pr.radius
				cy.height = (pr.b as Vector3).y - (pr.a as Vector3).y
				cs.shape = cy
				body.position = ((pr.a as Vector3) + pr.b) * 0.5
			"capsule":
				var ca := CapsuleShape3D.new()
				var ab: Vector3 = (pr.b as Vector3) - pr.a
				ca.radius = pr.radius
				ca.height = ab.length() + 2.0 * float(pr.radius)
				cs.shape = ca
				var y := ab.normalized() if ab.length() > 0.0001 else Vector3.UP
				var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
				body.transform = Transform3D(Basis(x, y, x.cross(y)), ((pr.a as Vector3) + pr.b) * 0.5)
		body.add_child(cs)
		parent.add_child(body)
		out.append(body)
	return out


## Wire boxes of every prop (an audit's close-ups; a debug view): one MeshInstance3D of lines.
func debug_mesh(color := Color(1.0, 0.85, 0.1)) -> MeshInstance3D:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for pr: Dictionary in props:
		var segs: Array = []
		if pr.kind == "floor":
			continue
		if pr.kind == "box":
			var h: Vector3 = pr.half
			var c := []
			for k in 8:
				c.append((pr.xf as Transform3D) * Vector3(h.x * (1 if k & 1 else -1), h.y * (1 if k & 2 else -1), h.z * (1 if k & 4 else -1)))
			for e in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
				segs.append([c[e[0]], c[e[1]]])
		else:
			var r: float = pr.radius
			for k in 12:
				var a0 := Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0)) * r
				var a1 := Vector3(cos((k + 1) * TAU / 12.0), 0, sin((k + 1) * TAU / 12.0)) * r
				segs.append([(pr.a as Vector3) + a0, (pr.a as Vector3) + a1])
				segs.append([(pr.b as Vector3) + a0, (pr.b as Vector3) + a1])
			segs.append([pr.a, pr.b])
		for s in segs:
			im.surface_set_color(color)
			im.surface_add_vertex(s[0])
			im.surface_set_color(color)
			im.surface_add_vertex(s[1])
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	mi.material_override = m
	return mi


# ---------------------------------------------------------------- inside

func _index(i: int) -> void:
	var ab: AABB = props[i].aabb
	for cx in range(floori(ab.position.x / CELL), floori(ab.end.x / CELL) + 1):
		for cz in range(floori(ab.position.z / CELL), floori(ab.end.z / CELL) + 1):
			var key := Vector2i(cx, cz)
			var cell: PackedInt32Array = _grid.get(key, PackedInt32Array())
			cell.append(i)
			_grid[key] = cell


func _pack(i: int) -> void:
	var pr: Dictionary = props[i]
	var k := 3
	var c := Vector2.ZERO
	var b := Vector2.ZERO
	var ax := Vector2(1, 0)
	var az := Vector2(0, 1)
	var h := Vector2.ZERO
	var r := 0.0
	var ab: AABB = pr.aabb
	match String(pr.kind):
		"box":
			k = 0
			var xf: Transform3D = pr.xf
			if absf(xf.basis.y.y) < 0.98:
				# A tilted box: its bounds' footprint.
				c = Vector2(ab.get_center().x, ab.get_center().z)
				h = Vector2(ab.size.x, ab.size.z) * 0.5
			else:
				c = Vector2(xf.origin.x, xf.origin.z)
				ax = Vector2(xf.basis.x.x, xf.basis.x.z).normalized()
				az = Vector2(xf.basis.z.x, xf.basis.z.z).normalized()
				h = Vector2((pr.half as Vector3).x, (pr.half as Vector3).z)
		"cylinder":
			k = 1
			c = Vector2((pr.a as Vector3).x, (pr.a as Vector3).z)
			r = pr.radius
		"capsule":
			k = 2
			c = Vector2((pr.a as Vector3).x, (pr.a as Vector3).z)
			b = Vector2((pr.b as Vector3).x, (pr.b as Vector3).z)
			r = pr.radius
	_wk.append(k)
	_wc.append(c)
	_wb.append(b)
	_wax.append(ax)
	_waz.append(az)
	_wh.append(h)
	_wr.append(r)
	_wy.append(Vector2(ab.position.y, ab.end.y))
	_ww.append(1 if pr.walk and k != 3 else 0)


## Whether prop I is in a body's way (solid to bodies, and in its height: a step's worth above the feet not counted).
func _blocks(i: int, y: float, height: float) -> bool:
	return _ww[i] == 1 and _wy[i].y > y + STEP and _wy[i].x < y + height


## Prop I's footprint's signed distance from P (flat, m; negative inside).
func _sdi(i: int, p: Vector2) -> float:
	match _wk[i]:
		0:
			var d := p - _wc[i]
			var q := Vector2(absf(d.dot(_wax[i])), absf(d.dot(_waz[i]))) - _wh[i]
			return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0)
		1:
			return p.distance_to(_wc[i]) - _wr[i]
		2:
			var a := _wc[i]
			var ab := _wb[i] - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
			return p.distance_to(a + ab * t) - _wr[i]
	return INF


func _near2(p: Vector2, r: float) -> PackedInt32Array:
	return _near_rect(p - Vector2(r, r), p + Vector2(r, r))


func _near_rect(lo: Vector2, hi: Vector2) -> PackedInt32Array:
	var out := PackedInt32Array()
	var seen := {}
	for cx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
		for cz in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
			var key := Vector2i(cx, cz)
			if _grid.has(key):
				for i in (_grid[key] as PackedInt32Array):
					if not seen.has(i):
						seen[i] = true
						out.append(i)
	return out


## Whether a prop reaches into a body's height (feet at Y, HEIGHT tall), a step's worth above the feet not counted.
static func _in_height(pr: Dictionary, y: float, height: float) -> bool:
	var ab: AABB = pr.aabb
	return ab.end.y > y + STEP and ab.position.y < y + height


## A prop's footprint's signed distance from P (flat, m; negative inside) and the way out: [sd, normal].
static func _sd2(pr: Dictionary, p: Vector2) -> Array:
	match String(pr.kind):
		"box":
			var xf: Transform3D = pr.xf
			var c := Vector2(xf.origin.x, xf.origin.z)
			# The box's footprint: its own x and z turned about up (a tilted box: its bounds' footprint instead).
			var ax := Vector2(xf.basis.x.x, xf.basis.x.z)
			var az := Vector2(xf.basis.z.x, xf.basis.z.z)
			var h: Vector3 = pr.half
			var hx := h.x
			var hz := h.z
			if absf(xf.basis.y.y) < 0.98:
				var ab: AABB = pr.aabb
				c = Vector2(ab.get_center().x, ab.get_center().z)
				ax = Vector2(1, 0)
				az = Vector2(0, 1)
				hx = ab.size.x * 0.5
				hz = ab.size.z * 0.5
			else:
				ax = ax.normalized()
				az = az.normalized()
			var d := p - c
			var q := Vector2(d.dot(ax), d.dot(az))
			var e := Vector2(absf(q.x) - hx, absf(q.y) - hz)
			if e.x > 0.0 or e.y > 0.0:
				var v := Vector2(maxf(e.x, 0.0) * signf(q.x), maxf(e.y, 0.0) * signf(q.y))
				var l := v.length()
				return [l, (ax * v.x + az * v.y) / l]
			if e.x > e.y:
				return [e.x, ax * (signf(q.x) if q.x != 0.0 else 1.0)]
			return [e.y, az * (signf(q.y) if q.y != 0.0 else 1.0)]
		"cylinder":
			var v := p - Vector2((pr.a as Vector3).x, (pr.a as Vector3).z)
			var l := v.length()
			return [l - float(pr.radius), v / l if l > 0.0001 else Vector2(1, 0)]
		_:
			var a := Vector2((pr.a as Vector3).x, (pr.a as Vector3).z)
			var b := Vector2((pr.b as Vector3).x, (pr.b as Vector3).z)
			var ab := b - a
			var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
			var v := p - (a + ab * t)
			var l := v.length()
			return [l - float(pr.radius), v / l if l > 0.0001 else Vector2(-ab.y, ab.x).normalized()]


## How far (m, up to LOOK) a body can go from P along D before touching one of NEAR.
func _ray_clear(p: Vector2, d: Vector2, look: float, radius: float, near: PackedInt32Array) -> float:
	var s := 0.0
	while s < look:
		var s1 := minf(s + 0.25, look)
		var q := p + d * s1
		for i in near:
			if _sdi(i, q) < radius:
				return s
		s = s1
	return look


func _seg_clear(a: Vector3, b: Vector3, radius: float, height: float) -> bool:
	var l := a.distance_to(b)
	var steps := maxi(1, ceili(l / 0.15))
	var cand := _near_rect(Vector2(minf(a.x, b.x), minf(a.z, b.z)) - Vector2.ONE * radius,
		Vector2(maxf(a.x, b.x), maxf(a.z, b.z)) + Vector2.ONE * radius)
	for k in steps + 1:
		var q := a.lerp(b, float(k) / steps)
		var q2 := Vector2(q.x, q.z)
		for i in cand:
			if _blocks(i, a.y, height) and _sdi(i, q2) < radius - 0.005:
				return false
	return true


## Points round a prop's footprint, M out from it (the corners a walk goes round).
static func _corners2(pr: Dictionary, m: float) -> Array:
	var out := []
	match String(pr.kind):
		"box":
			var xf: Transform3D = pr.xf
			var c := Vector2(xf.origin.x, xf.origin.z)
			var ax := Vector2(xf.basis.x.x, xf.basis.x.z).normalized()
			var az := Vector2(xf.basis.z.x, xf.basis.z.z).normalized()
			var h: Vector3 = pr.half
			for sx in [-1.0, 1.0]:
				for sz in [-1.0, 1.0]:
					out.append(c + ax * sx * (h.x + m) + az * sz * (h.z + m))
		"cylinder":
			var c := Vector2((pr.a as Vector3).x, (pr.a as Vector3).z)
			for k in 8:
				out.append(c + Vector2(cos(k * TAU / 8.0), sin(k * TAU / 8.0)) * (float(pr.radius) + m) / cos(PI / 8.0))
		_:
			var a := Vector2((pr.a as Vector3).x, (pr.a as Vector3).z)
			var b := Vector2((pr.b as Vector3).x, (pr.b as Vector3).z)
			var d := (b - a).normalized() if a.distance_to(b) > 0.001 else Vector2(1, 0)
			var nrm := Vector2(-d.y, d.x)
			var r := float(pr.radius) + m
			for e in [[a, -1.0], [b, 1.0]]:
				out.append((e[0] as Vector2) + d * float(e[1]) * r + nrm * r)
				out.append((e[0] as Vector2) + d * float(e[1]) * r - nrm * r)
	return out


## A ball (RADIUS) from P0 to P1 against one prop: [t, normal] at the first touch, [] if none.
static func _sweep_one(pr: Dictionary, p0: Vector3, p1: Vector3, radius: float) -> Array:
	match String(pr.kind):
		"floor":
			var top := float(pr.y) + radius
			if p0.y < top:
				return [0.0, Vector3.UP, top - p0.y]
			if p1.y < top:
				return [(p0.y - top) / (p0.y - p1.y), Vector3.UP]
			return []
		"box":
			var inv: Transform3D = pr.inv
			var a := inv * p0
			var b := inv * p1
			var h: Vector3 = (pr.half as Vector3) + Vector3.ONE * radius
			var d := b - a
			# Already inside (resting against it, or a game moved it in): out by the nearest face.
			if absf(a.x) < h.x and absf(a.y) < h.y and absf(a.z) < h.z:
				var e := h - a.abs()
				var ax := 0 if e.x <= e.y and e.x <= e.z else (1 if e.y <= e.z else 2)
				var nl := Vector3.ZERO
				nl[ax] = signf(a[ax]) if a[ax] != 0.0 else 1.0
				return [0.0, ((pr.xf as Transform3D).basis * nl).normalized(), e[ax]]
			var t0 := 0.0
			var t1 := 1.0
			var axis := -1
			var sgn := 0.0
			for k in 3:
				if absf(d[k]) < 1e-9:
					if absf(a[k]) >= h[k]:
						return []
					continue
				var ta := (-h[k] - a[k]) / d[k]
				var tb := (h[k] - a[k]) / d[k]
				var s := -1.0
				if ta > tb:
					var tmp := ta
					ta = tb
					tb = tmp
					s = 1.0
				if ta > t0:
					t0 = ta
					axis = k
					sgn = s
				t1 = minf(t1, tb)
				if t0 > t1:
					return []
			if axis < 0:
				return []
			var nl := Vector3.ZERO
			nl[axis] = sgn
			return [t0, ((pr.xf as Transform3D).basis * nl).normalized()]
		"cylinder":
			var r := float(pr.radius) + radius
			var ya := (pr.a as Vector3).y - radius
			var yb := (pr.b as Vector3).y + radius
			var c := Vector2((pr.a as Vector3).x, (pr.a as Vector3).z)
			var o := Vector2(p0.x, p0.z) - c
			var d := Vector2(p1.x - p0.x, p1.z - p0.z)
			var dy := p1.y - p0.y
			if o.length() < r and p0.y > ya and p0.y < yb:
				var side := r - o.length()
				var top := minf(yb - p0.y, p0.y - ya)
				if side < top:
					return [0.0, Vector3(o.x, 0, o.y).normalized() if o.length() > 1e-5 else Vector3.RIGHT, side]
				return [0.0, Vector3.UP if yb - p0.y < p0.y - ya else Vector3.DOWN, top]
			var best := INF
			var n := Vector3.ZERO
			var qa := d.dot(d)
			if qa > 1e-12:
				var qb := 2.0 * o.dot(d)
				var qc := o.dot(o) - r * r
				var disc := qb * qb - 4.0 * qa * qc
				if disc >= 0.0:
					var t := (-qb - sqrt(disc)) / (2.0 * qa)
					if t >= 0.0 and t <= 1.0:
						var y := p0.y + dy * t
						if y >= ya and y <= yb:
							best = t
							var hp := o + d * t
							n = Vector3(hp.x, 0, hp.y).normalized()
			if absf(dy) > 1e-9:
				for cap in [[yb, Vector3.UP], [ya, Vector3.DOWN]]:
					var t := (float(cap[0]) - p0.y) / dy
					if t >= 0.0 and t <= 1.0 and t < best and signf(dy) == -(cap[1] as Vector3).y:
						if (o + d * t).length() <= r:
							best = t
							n = cap[1]
			return [best, n] if best < INF else []
		_:
			# A capsule: the segment AB grown by its radius and the ball's (iq's ray-capsule).
			var r := float(pr.radius) + radius
			var pa: Vector3 = pr.a
			var pb: Vector3 = pr.b
			var ba := pb - pa
			var oa := p0 - pa
			var rd := p1 - p0
			var baba := ba.dot(ba)
			var bard := ba.dot(rd)
			var baoa := ba.dot(oa)
			var rdoa := rd.dot(oa)
			var oaoa := oa.dot(oa)
			# Inside already.
			var tt := clampf(baoa / maxf(baba, 1e-9), 0.0, 1.0)
			var inside_v := p0 - (pa + ba * tt)
			if inside_v.length() < r:
				return [0.0, inside_v.normalized() if inside_v.length() > 1e-6 else Vector3.UP, r - inside_v.length()]
			var a := baba * rd.dot(rd) - bard * bard
			var b := baba * rdoa - baoa * bard
			var c := baba * oaoa - baoa * baoa - r * r * baba
			var hh := b * b - a * c
			var best := INF
			if absf(a) > 1e-12 and hh >= 0.0:
				var t := (-b - sqrt(hh)) / a
				var y := baoa + t * bard
				if y > 0.0 and y < baba and t >= 0.0 and t <= 1.0:
					best = t
			if best == INF:
				# The ends' spheres.
				for e in [pa, pb]:
					var oc := p0 - (e as Vector3)
					var qa := rd.dot(rd)
					var qb := oc.dot(rd)
					var qc := oc.dot(oc) - r * r
					var disc := qb * qb - qa * qc
					if qa > 1e-12 and disc >= 0.0:
						var t := (-qb - sqrt(disc)) / qa
						if t >= 0.0 and t <= 1.0 and t < best:
							best = t
			if best == INF:
				return []
			var hp := p0 + rd * best
			var tq := clampf((hp - pa).dot(ba) / maxf(baba, 1e-9), 0.0, 1.0)
			return [best, (hp - (pa + ba * tq)).normalized()]
	return []


static func _guess_material(lname: String, fallback: String) -> String:
	for pair in [["net", "net"], ["glass", "glass"], ["plexi", "glass"], ["goal", "metal"], ["post", "metal"],
			["pole", "metal"], ["rail", "metal"], ["barri", "metal"], ["truss", "metal"], ["bin", "plastic"],
			["board", "plastic"], ["chair", "plastic"], ["mat", "padding"], ["pad", "padding"], ["tent", "fabric"],
			["banner", "fabric"], ["bag", "fabric"], ["wall", "concrete"], ["step", "concrete"], ["stone", "stone"],
			["bench", "wood"], ["table", "wood"]]:
		if lname.contains(String(pair[0])):
			return pair[1]
	return fallback


static func _opted_out(n: Node, root: Node) -> String:
	var at := n
	while at != null:
		if at.is_in_group("wsg_not_solid"):
			return "in the group wsg_not_solid"
		if at.has_meta("wsg_solid") and not bool(at.get_meta("wsg_solid")):
			return String(at.get_meta("wsg_solid_reason", "(no reason given)"))
		if at == root:
			break
		at = at.get_parent()
	return ""
