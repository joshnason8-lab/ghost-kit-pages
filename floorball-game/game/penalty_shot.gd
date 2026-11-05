class_name PenaltyShot
extends RefCounted
## Where a penalty shot goes: in the goal's opening, or in one of its top corners ("top shelf", worth two in the
## Penalty shots mini game). match.gd's _breakaway takes the shot itself.

const CORNER := 0.32           # within this of where the bar meets a post (m)


## Does a goalkeeper on his line at z (across) get to a shot at aim that arrives in t seconds? He sees it after a
## moment (later when he has bitten on a deke the other way), then moves across at his speed; his reach is his body,
## his pads and his arms, less over the shoulder of a kneeling goalkeeper.
static func keeper_gets_there(aim: Vector3, z: float, t: float, wrong_way: bool, reflex := 75.0) -> bool:
	var react := 0.42 if wrong_way else 0.17
	var reach := (0.36 if aim.y > 0.75 else 0.5) + (reflex - 75.0) / 400.0
	return absf(aim.z - z) < reach + 3.0 * maxf(0.0, t - react)


## A point in the goal's opening (inside the posts, under the bar, a ball's width in).
static func in_goal(p: Vector3) -> bool:
	return absf(p.z) < Rules.GOAL_W * 0.5 - Ball.R and p.y < Rules.GOAL_H - Ball.R and p.y > 0.0


## A point in one of the top corners.
static func top_corner(p: Vector3) -> bool:
	return in_goal(p) and p.y > 0.7 and absf(p.z) > Rules.GOAL_W * 0.5 - CORNER - 0.1
