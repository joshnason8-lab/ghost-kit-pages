class_name Coach
extends RefCounted
## The coach on the sideline: short tips through your first match, each the moment it is needed (the ball coming to
## you, the ball in your hand, your first free ...), each once. On for the first match you play; Settings > Coach's
## tips turns them on again. pick() is pure (the match hands it what is happening), so tests can check each tip.

## In the order they are looked for: the first unseen one that fits is shown.
const TIPS := ["PUCK_OUT", "PENALTY", "FREE", "IN_HAND", "GOAL", "ON_STICK", "SHOOT", "LOOSE", "TACKLE", "MOVE", "SWITCH", "FOLLOW"]
const SHOW_S := 6.5          # how long a tip stays up
const GAP_S := 3.0           # and the quiet before the next

var seen := {}
var showing := ""
var _t := 0.0
var _gap := 0.0


## Which tip fits what is happening, or "" for none. s: {"taker": the restart you are taking ("" if none),
## "carrying": you have the ball, "in_hand": in your hand (else on the hurley), "buttons": the buttons showing,
## "goal_dist": metres from the goal you attack, "live_s": seconds the ball has been live this match,
## "ball_far": the sliotar is far from your player, "ball_off": it is off the screen}.
static func pick(s: Dictionary, p_seen: Dictionary) -> String:
	for id in TIPS:
		if not p_seen.has(id) and fits(id, s):
			return id
	return ""


static func fits(id: String, s: Dictionary) -> bool:
	var taker := String(s.get("taker", ""))
	var buttons: Array = s.get("buttons", [])
	var carrying := bool(s.get("carrying", false))
	match id:
		"PUCK_OUT":
			return taker == "puck_out"
		"PENALTY":
			return taker == "penalty"
		"FREE":
			return taker in ["free", "65", "sideline"]
		"IN_HAND":
			return carrying and bool(s.get("in_hand", false))
		"GOAL":
			return carrying and "GOAL" in buttons
		"ON_STICK":
			return carrying and not bool(s.get("in_hand", false))
		"SHOOT":
			return carrying and float(s.get("goal_dist", 999.0)) < 45.0
		"LOOSE":
			return "CATCH" in buttons or "LIFT" in buttons
		"TACKLE":
			return "TACKLE" in buttons
		"MOVE":
			return taker == "" and not carrying
		"SWITCH":
			return not carrying and bool(s.get("ball_far", false)) and float(s.get("live_s", 0.0)) > 20.0
		"FOLLOW":
			return bool(s.get("ball_off", false)) and float(s.get("live_s", 0.0)) > 8.0
	return false


## Each frame: the tip to show now ("" to keep what is shown, or nothing), given what is happening.
func step(dt: float, s: Dictionary) -> String:
	if showing != "":
		_t -= dt
		if _t <= 0.0:
			showing = ""
			_gap = GAP_S
		return ""
	if _gap > 0.0:
		_gap -= dt
		return ""
	var id := pick(s, seen)
	if id != "":
		show(id)
	return id


## A tip after something went wrong (too many steps): shown at once, if not seen.
func event(id: String) -> String:
	if seen.has(id):
		return ""
	show(id)
	return id


func show(id: String) -> void:
	seen[id] = true
	showing = id
	_t = SHOW_S
	_gap = 0.0


## The tip's words: COACH_<id> in the strings.
static func text_key(id: String) -> String:
	return "COACH_" + id
