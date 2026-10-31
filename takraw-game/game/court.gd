class_name Court
extends RefCounted
## The court's measurements (ISTAF Laws of the Game; docs/TAKRAW.md) and the places players stand.
## World space: the net along z at x = 0, side 0 at x < 0 and side 1 at x > 0; z across the court; y up.

const LENGTH := 13.40
const HALF := 6.70              # from the net to a back line
const WIDTH := 6.10
const HALF_W := 3.05
const LINE := 0.04              # lines are drawn inside the court and are part of it
const CENTRE_LINE := 0.02
const QUARTER_R := 0.90         # the quarter circles at the net, centred on the centre line's ends
const SERVICE_R := 0.30         # the service circle ...
const SERVICE_D := HALF - 2.45  # ... its centre 2.45 m from the back line, on the court's middle
const NET_M := 1.52             # the top of the net at the centre: men ...
const NET_W := 1.42             # ... and women
const NET_POST_EXTRA := 0.03    # 3 cm higher at the posts
const NET_DEPTH := 0.70         # top tape to bottom tape
const POST_OUT := 0.30          # the posts stand 30 cm outside the side lines
const FREE_ZONE := 3.0


## Which side of the net a point is on: 0 or 1.
static func side_of(x: float) -> int:
	return 0 if x < 0.0 else 1


## The sign of a side's half: -1 for side 0, 1 for side 1.
static func sgn(side: int) -> float:
	return -1.0 if side == 0 else 1.0


## Is a ball landing at p in a side's court? Lines are in: the ball's touch of the floor (its radius r around p) over
## any part of a line counts.
static func in_court(p: Vector3, side: int, r := 0.068) -> bool:
	var s := sgn(side)
	var d := p.x * s   # depth from the net into that side
	return d >= -r and d <= HALF + r and absf(p.z) <= HALF_W + r


## How far a landing at p is from the nearest boundary line's outer edge (negative inside), for close calls.
static func line_margin(p: Vector3, r := 0.068) -> float:
	var dx := absf(p.x) - (HALF + r)
	var dz := absf(p.z) - (HALF_W + r)
	return maxf(dx, dz)


## A point on a side, from the depth from the net d and the lateral z measured to the players' left (so a feeder's
## left is the same on both sides).
static func spot(side: int, d: float, left: float) -> Vector3:
	var s := sgn(side)
	return Vector3(s * d, 0, s * left)


## Where a side's players face: across the net.
static func facing(side: int) -> float:
	return PI * 0.5 if side == 0 else -PI * 0.5
