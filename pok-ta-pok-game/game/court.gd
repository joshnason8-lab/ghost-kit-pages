class_name Court
extends RefCounted
## The courts' shapes, in metres, and what the ball meets on them: the floor, and on the classic court the sloped
## benches (talud), the walls above them, the end courts of the I and the stone rings. Pure geometry: the ball
## (game/ball.gd) asks where it hits; the venue (game/venue.gd) builds what is seen from the same numbers.
##
## Along x, the analco (centre line) at x = 0; across, z; up, y.
##
## Ulama (docs/RULES.md R7): the taste, a strip of packed earth 60 m long and 4 m wide with no walls, the analco across
## its middle and an end line (chivo) at each end. The sources give 50 x 3 m to about 69 x 4 m; Aguilar-Moreno, who
## played and filmed it, about 60 x 4.
## Classic (reconstructed, R12): an I-shaped stone court the size of the smaller Yucatán courts: a 36 m alley 9 m wide
## between two structures, each with a sloped bench (talud) 1.5 m deep rising 1.6 m, then a wall to 5 m with a stone
## ring at its middle, its hole along the alley, 4 m up; at each end an end court 6 m deep and 18 m wide, walled.

const ULAMA_HALF_L := 30.0
const ULAMA_HALF_W := 2.0

const ALLEY_HALF_L := 18.0
const ALLEY_HALF_W := 4.5
const TALUD_Z := 6.0          # where the slope meets the wall
const TALUD_H := 1.6
const WALL_H := 5.0
const END_HALF_L := 24.0
const END_HALF_W := 9.0
const END_WALL_H := 3.0
const RING_Y := 4.0
const RING_IN := 0.19         # the hole's radius: the ball (0.095) has 9.5 cm to spare
const RING_OUT := 0.48
const RING_DEPTH := 0.16      # half the ring's thickness along the alley
const RING_OFF := 0.42        # the ring's centre stands this far out from the wall's face

var rules := Rules.ULAMA


func _init(p_rules := Rules.ULAMA) -> void:
	rules = p_rules


func classic() -> bool:
	return rules == Rules.CLASSIC


## The playing length's half: to the end lines (ulama) or the end courts' back walls (classic).
func half_l() -> float:
	return END_HALF_L if classic() else ULAMA_HALF_L


## Where play is in bounds across the court at x: the taste's side lines, or the alley/end court's walls.
func half_w_at(x: float) -> float:
	if not classic():
		return ULAMA_HALF_W
	return END_HALF_W if absf(x) > ALLEY_HALF_L else ALLEY_HALF_W


## The end line a team defends (its x).
func end_x(team: int) -> float:
	return -half_l() * Rules.dir(team) if not classic() else -ALLEY_HALF_L * Rules.dir(team)


## Where the floor is at (x, z): the earth or stone floor at 0, rising up the talud on the classic court.
func floor_y(x: float, z: float) -> float:
	if classic() and absf(x) <= ALLEY_HALF_L and absf(z) > ALLEY_HALF_W:
		return minf(TALUD_H, (absf(z) - ALLEY_HALF_W) / (TALUD_Z - ALLEY_HALF_W) * TALUD_H)
	return 0.0


## The rings' centres (classic): one in each wall at the analco.
func rings() -> Array:
	if not classic():
		return []
	var out := []
	for s in [-1.0, 1.0]:
		out.append(Vector3(0.0, RING_Y, s * (TALUD_Z - RING_OFF)))
	return out


## Where players may stand: on the floor of the court (classic: the alley and the end courts, off the slopes), the
## nearest such point to p.
func clamp_feet(p: Vector3, margin := 0.3) -> Vector3:
	if not classic():
		var hl := ULAMA_HALF_L + 3.0
		# A player may step just over the side line after the ball.
		var hw := ULAMA_HALF_W + 0.6
		return Vector3(clampf(p.x, -hl + margin, hl - margin), 0.0, clampf(p.z, -hw, hw))
	# The I is the alley and two end courts: the nearest point of the three.
	var alley := Vector3(clampf(p.x, -ALLEY_HALF_L - margin, ALLEY_HALF_L + margin), 0.0, clampf(p.z, -ALLEY_HALF_W + margin, ALLEY_HALF_W - margin))
	var best := alley
	var bd := Vector2(p.x - alley.x, p.z - alley.z).length()
	for sx in [-1.0, 1.0]:
		var x0: float = minf(sx * ALLEY_HALF_L, sx * END_HALF_L)
		var x1: float = maxf(sx * ALLEY_HALF_L, sx * END_HALF_L)
		var e := Vector3(clampf(p.x, x0 + margin, x1 - margin), 0.0, clampf(p.z, -END_HALF_W + margin, END_HALF_W - margin))
		var d := Vector2(p.x - e.x, p.z - e.z).length()
		if d < bd:
			bd = d
			best = e
	return best


## The limits of the floor a player at p is on, along x and across z: [x_lo, x_hi, z_lo, z_hi] (he slows to stop at
## them, Player.update).
func bounds_at(p: Vector3, margin := 0.3) -> Array:
	if not classic():
		var hl := ULAMA_HALF_L + 3.0 - margin
		var hw := ULAMA_HALF_W + 0.6
		return [-hl, hl, -hw, hw]
	var aw := ALLEY_HALF_W - margin
	if absf(p.z) > aw + 0.01 and absf(p.x) > ALLEY_HALF_L:
		# In an end court, beside the alley's mouth: only within that end court.
		var sx := signf(p.x) if p.x != 0.0 else 1.0
		var lo := minf(sx * ALLEY_HALF_L, sx * END_HALF_L) + margin
		var hi := maxf(sx * ALLEY_HALF_L, sx * END_HALF_L) - margin
		return [lo, hi, -END_HALF_W + margin, END_HALF_W - margin]
	var w := aw if absf(p.x) <= ALLEY_HALF_L + margin else END_HALF_W - margin
	return [-END_HALF_L + margin, END_HALF_L - margin, -w, w]


## The ball (centre pos, radius r) against everything but the floor's open ground: returns [normal, depth, kind] of
## the deepest contact, or [] when none. kind: "talud", "wall", "end_wall", "ring" (the ring's stone).
func contact(pos: Vector3, r: float) -> Array:
	if not classic():
		return []
	var best := []
	var deepest := 0.0
	var ax := absf(pos.x)
	var az := absf(pos.z)
	var sz := signf(pos.z) if pos.z != 0.0 else 1.0
	var sx := signf(pos.x) if pos.x != 0.0 else 1.0
	if ax <= ALLEY_HALF_L + r:
		# The sloped bench: a plane through (z = ALLEY_HALF_W, y = 0) rising outward.
		if az > ALLEY_HALF_W - r and az < TALUD_Z + r and pos.y < TALUD_H + r:
			var n := Vector3(0.0, TALUD_Z - ALLEY_HALF_W, -sz * TALUD_H).normalized()
			var d := (pos - Vector3(pos.x, 0.0, sz * ALLEY_HALF_W)).dot(n)
			if d < r and ax <= ALLEY_HALF_L:
				var depth := r - d
				if depth > deepest:
					deepest = depth
					best = [n, depth, "talud"]
		# The wall above it.
		if pos.y > TALUD_H - r and pos.y < WALL_H and az > TALUD_Z - r and ax <= ALLEY_HALF_L:
			var depth := az + r - TALUD_Z
			if depth > deepest:
				deepest = depth
				best = [Vector3(0, 0, -sz), depth, "wall"]
	if ax > ALLEY_HALF_L - r:
		# The end court's walls: its back wall and its two side walls.
		if pos.y < END_WALL_H:
			if ax > END_HALF_L - r:
				var depth := ax + r - END_HALF_L
				if depth > deepest:
					deepest = depth
					best = [Vector3(-sx, 0, 0), depth, "end_wall"]
			if az > END_HALF_W - r and ax > ALLEY_HALF_L:
				var depth := az + r - END_HALF_W
				if depth > deepest:
					deepest = depth
					best = [Vector3(0, 0, -sz), depth, "end_wall"]
		# The ends of the two structures, facing into the end court.
		if az > ALLEY_HALF_W and ax > ALLEY_HALF_L - r and ax < ALLEY_HALF_L + 0.6 and pos.y < WALL_H:
			if az > TALUD_Z or pos.y < floor_y(ALLEY_HALF_L * sx, pos.z) + r:
				var depth := ALLEY_HALF_L + r - ax
				if depth > deepest and depth < r * 2.0:
					deepest = depth
					best = [Vector3(sx, 0, 0), depth, "end_wall"]
	# The rings' stone (the hole lets the ball through).
	for c: Vector3 in rings():
		var rel: Vector3 = pos - c
		if absf(rel.x) < RING_DEPTH + r:
			var radial := Vector2(rel.y, rel.z).length()
			if radial < RING_OUT + r and radial > RING_IN - r:
				# Nearest point of the ring's stone: a flat annulus between RING_IN and RING_OUT, RING_DEPTH thick.
				var rad_c := clampf(radial, RING_IN, RING_OUT)
				var dir2 := Vector2(rel.y, rel.z) / maxf(radial, 0.0001)
				var near := Vector3(clampf(rel.x, -RING_DEPTH, RING_DEPTH), dir2.x * rad_c, dir2.y * rad_c)
				var dv := rel - near
				var dist := dv.length()
				if dist < r:
					var depth := r - dist
					if depth > deepest:
						deepest = depth
						best = [dv / maxf(dist, 0.0001) if dist > 0.0001 else Vector3(signf(rel.x), 0, 0), depth, "ring"]
	return best


## Did the ball, moving from a to b (centres), go through a ring's hole? Returns the ring's side (-1, 1) or 0.
func through_ring(a: Vector3, b: Vector3, r: float) -> int:
	for c: Vector3 in rings():
		if (a.x - c.x) * (b.x - c.x) > 0.0 or is_equal_approx(a.x, b.x):
			continue
		var t := (c.x - a.x) / (b.x - a.x)
		var p := a.lerp(b, t)
		if Vector2(p.y - c.y, p.z - c.z).length() < RING_IN - r * 0.5:
			return int(signf(c.z))
	return 0


## Is the ball out of the court (R10, R15)? Ulama: on the ground beyond a side line. Classic: over a wall's top.
func out_side(pos: Vector3, r: float, grounded: bool) -> bool:
	if classic():
		var ax := absf(pos.x)
		if ax <= ALLEY_HALF_L:
			return absf(pos.z) > TALUD_Z + r and pos.y > WALL_H - r
		return absf(pos.z) > END_HALF_W + r
	return grounded and absf(pos.z) > ULAMA_HALF_W + r


## Has the ball gone past an end (R9: over an end line, ulama; R16: into an end court, or over its wall, classic)?
## Returns the x side (-1, 1) or 0.
func past_end(pos: Vector3, r: float, grounded: bool) -> int:
	if classic():
		if absf(pos.x) > END_HALF_L + r or (grounded and absf(pos.x) > ALLEY_HALF_L + r):
			return int(signf(pos.x))
		return 0
	if absf(pos.x) > ULAMA_HALF_L + r:
		return int(signf(pos.x))
	return 0
