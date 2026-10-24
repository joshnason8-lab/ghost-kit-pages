class_name Court
extends RefCounted
## The court as the Rules of Netball draw it (docs/RULES.md, "The court"). Metres, on the floor plane: x along the
## court's length (the goal lines at x = ±HALF_L), z across it (the side lines at z = ±HALF_W), y up. The middle of
## the centre circle is the origin.
##
## A team "attacks" one end: dir = +1 attacks the goal at x = +HALF_L, dir = -1 the one at x = -HALF_L. Ends change
## every quarter (Rules.ends_for_quarter).

const LENGTH := 30.5
const WIDTH := 15.25
const HALF_L := LENGTH * 0.5
const HALF_W := WIDTH * 0.5
const THIRD := LENGTH / 3.0          # each third, 10.17 m
const THIRD_X := THIRD * 0.5         # the transverse lines at x = ±5.083
const CIRCLE_R := 4.9                # the goal circle: a semicircle of 4.9 m radius on the goal line's middle
const CENTRE_R := 0.45               # the centre circle, 0.9 m across
const LINE_W := 0.05                 # every line 50 mm wide, part of the area it bounds
const RING_H := 3.05                 # the top of the ring above the floor
const RING_R := 0.19                 # the ring's inside diameter is 380 mm
const RING_OUT := 0.15               # the ring sticks out 150 mm from the post into the court
const POST_R := 0.05                 # the post, 65-100 mm across
const RUNOFF := 3.05                 # clear floor round the court (international: 3.05 m)
const DEFEND_DIST := 0.9             # obstruction: a defender's distance from the landing foot

## Areas (the "playing areas" a position may go into), named as the game's code uses them.
const A_DEF_THIRD := "def_third"     # the goal third the team defends (outside its circle)
const A_DEF_CIRCLE := "def_circle"   # the goal circle it defends
const A_CENTRE := "centre"           # the centre third
const A_ATT_THIRD := "att_third"     # the goal third it attacks (outside the circle)
const A_ATT_CIRCLE := "att_circle"   # the goal circle it attacks (it shoots here)
const A_OUT := "out"                 # off the court


## Where the goal a team attacks stands (its post's foot) for dir.
static func goal_post(dir: int) -> Vector2:
	return Vector2(HALF_L * dir, 0.0)


## The ring's centre, in 3D, for the goal at the dir end.
static func ring_centre(dir: int) -> Vector3:
	return Vector3((HALF_L - RING_OUT - RING_R) * dir, RING_H, 0.0)


static func on_court(p: Vector2) -> bool:
	return absf(p.x) <= HALF_L and absf(p.y) <= HALF_W


## Is p inside the goal circle at the dir end (lines included)?
static func in_circle(p: Vector2, dir: int) -> bool:
	if signf(p.x) != float(dir) and absf(p.x) > 0.0:
		return false
	if absf(p.x) > HALF_L:
		return false
	return p.distance_to(goal_post(dir)) <= CIRCLE_R + LINE_W * 0.5


## Which area p is in, for a team attacking dir. The transverse lines and the circle's line belong to the area they
## enclose, so standing on a third line is standing in both thirds (Rules.offside: on the line is fine): this returns the
## areas a foot there touches.
static func areas_at(p: Vector2, dir: int) -> Array:
	if not on_court(p):
		return [A_OUT]
	var out := []
	var hw := LINE_W * 0.5
	var ax := p.x * dir   # along the court toward the goal attacked
	if ax >= THIRD_X - hw:
		out.append(A_ATT_CIRCLE if in_circle(p, dir) else A_ATT_THIRD)
		# On the circle's line: in both the circle and the third round it.
		if in_circle(p, dir) and p.distance_to(goal_post(dir)) >= CIRCLE_R - hw:
			out.append(A_ATT_THIRD)
	if absf(p.x) <= THIRD_X + hw:
		out.append(A_CENTRE)
	if ax <= -THIRD_X + hw:
		out.append(A_DEF_CIRCLE if in_circle(p, -dir) else A_DEF_THIRD)
		if in_circle(p, -dir) and p.distance_to(goal_post(-dir)) >= CIRCLE_R - hw:
			out.append(A_DEF_THIRD)
	return out


## The single area a point is mostly in (for the AI and the camera), for a team attacking dir.
static func area_of(p: Vector2, dir: int) -> String:
	if not on_court(p):
		return A_OUT
	var ax := p.x * dir
	if ax > THIRD_X:
		return A_ATT_CIRCLE if in_circle(p, dir) else A_ATT_THIRD
	if ax < -THIRD_X:
		return A_DEF_CIRCLE if in_circle(p, -dir) else A_DEF_THIRD
	return A_CENTRE


## The third a point is in, numbered for the team attacking dir: 0 its defending third, 1 the centre, 2 its attacking.
static func third_of(x: float, dir: int) -> int:
	var ax := x * dir
	if ax > THIRD_X:
		return 2
	if ax < -THIRD_X:
		return 0
	return 1


## The third numbered 0-2 from the -x end (absolute, for the rule that the ball may not cross a whole third).
static func third_abs(x: float) -> int:
	if x < -THIRD_X:
		return 0
	if x > THIRD_X:
		return 2
	return 1


## Clamps p into the court.
static func clamp_court(p: Vector2, margin := 0.0) -> Vector2:
	return Vector2(clampf(p.x, -HALF_L + margin, HALF_L - margin), clampf(p.y, -HALF_W + margin, HALF_W - margin))
