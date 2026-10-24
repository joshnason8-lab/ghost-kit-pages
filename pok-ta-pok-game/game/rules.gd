class_name Rules
extends RefCounted
## The rules of the game, as pure functions the match calls and the tests check (docs/RULES.md has each rule with its
## source, numbered as here). No scene, no physics: the match tells the rules what happened (the ball stopped here, it
## went over that line, it touched him without his hip) and the rules say who wins the raya, and what the count is.
##
## Two rule sets:
##   ULAMA   ulama de cadera, the hip game still played in southern Sinaloa: a long earth court (the taste) split by
##           the analco; the oscillating count of rayas to eight, with urria (documented, with its local variations).
##   CLASSIC the stone court with sloped walls and rings, as scholars reconstruct the old game from the chroniclers
##           (Durán): points for the ball dying in the other half, landing in or over an end court, or touching any
##           part but the hip; the ball through a ring wins outright. Reconstructed, and labelled so.
##
## Courts are laid along x: team 0 defends the end at -x and drives the ball toward +x; the analco (centre line) is
## x = 0. A team's half is the side of the analco it defends.

const ULAMA := "ulama"
const CLASSIC := "classic"

## R1. Ulama de cadera: the first side to eight rayas wins (Aguilar-Moreno; CONADE; every source agrees).
const TARGET := 8
## R12. Classic court: points to eight (reconstructed: the chroniclers give no target; eight keeps ulama's count).
const CLASSIC_TARGET := 8

## R4. Urria: standing on these rayas the side holding the count is in danger: a raya against it then wipes out its
## whole count. The sources place it differently, as the villages play it differently: Aguilar-Moreno between rayas
## 2-3 and 6-7, CONADE on 3, 5 and 7. Settings > Rules picks one (3 and 7 by default: where both agree).
const URRIA_SETS := {"3_7": [3, 7], "3_5_7": [3, 5, 7], "none": []}

## Players a side (R7): ulama 4 or 5 (CONADE, Secretaría de Cultura; 4 or 5 by agreement at a 2022 national meet).
## The classic court: 2 to 4 (reconstructed: the narrow stone alleys of the smaller courts).
const SIDE_ULAMA := [4, 5]
const SIDE_CLASSIC := [2, 3, 4]


static func target(rules: String) -> int:
	return CLASSIC_TARGET if rules == CLASSIC else TARGET


static func side_sizes(rules: String) -> Array:
	return SIDE_CLASSIC if rules == CLASSIC else SIDE_ULAMA


static func default_side(rules: String) -> int:
	return 3 if rules == CLASSIC else 5


static func other(team: int) -> int:
	return 1 - team


## Which way a team drives the ball: +1 (toward +x) for team 0, -1 for team 1.
static func dir(team: int) -> float:
	return 1.0 if team == 0 else -1.0


## The half a point on the court belongs to: the team that defends it (0 for x < 0, 1 for x > 0; on the analco
## itself, -1).
static func half_of(x: float) -> int:
	if absf(x) < 0.001:
		return -1
	return 0 if x < 0.0 else 1


# ---------------------------------------------------------------- the count

## The ulama count (R2-R5): one side holds the count at a time. A raya to the side holding it adds one; a raya to
## the other side takes one off it (the count goes up and down, the bimbalete), and from level the next raya starts
## that side's count. In urria, a raya against the holder wipes out its whole count. Eight wins.
## The classic court's points (R12) simply add up, each side its own.
class Count:
	var rules := Rules.ULAMA
	var holder := -1          # the side holding the ulama count, -1 when level
	var rayas := 0            # how many the holder has
	var urria: Array = [3, 7]
	var points := [0, 0]      # the classic court's points
	var winner := -1
	var ring := false         # won through the ring
	var history: Array = []   # every raya: [team, what happened]

	func _init(p_rules := Rules.ULAMA, urria_set := "3_7") -> void:
		rules = p_rules
		urria = Rules.URRIA_SETS.get(urria_set, [3, 7])

	## A side's rayas or points now (the side not holding the ulama count has none).
	func of(team: int) -> int:
		if rules == Rules.CLASSIC:
			return int(points[team])
		return rayas if holder == team else 0

	func in_urria() -> bool:
		return rules == Rules.ULAMA and holder >= 0 and rayas in urria

	func to_dict() -> Dictionary:
		return {"rules": rules, "holder": holder, "rayas": rayas, "points": points.duplicate(), "winner": winner,
			"ring": ring}


## A raya (or a classic point) to team. Returns what happened: "add" (the holder's count goes up; also the first raya
## from level), "cancel" (one taken off the other side's count), "urria" (the other side's whole count wiped out),
## "win" (the eighth), and the count after.
static func award(c: Count, team: int) -> Dictionary:
	var what := ""
	if c.winner >= 0:
		return {"what": "over", "team": team}
	if c.rules == CLASSIC:
		c.points[team] = int(c.points[team]) + 1
		what = "add"
		if int(c.points[team]) >= CLASSIC_TARGET:
			c.winner = team
			what = "win"
	elif c.holder == -1 or c.holder == team:
		c.holder = team
		c.rayas += 1
		what = "add"
		if c.rayas >= TARGET:
			c.winner = team
			what = "win"
	elif c.rayas in c.urria:
		# R4: caught in urria, the holder loses everything; the count is level again.
		c.rayas = 0
		c.holder = -1
		what = "urria"
	else:
		# R3: one raya off the holder's count.
		c.rayas -= 1
		what = "cancel"
		if c.rayas <= 0:
			c.rayas = 0
			c.holder = -1
	c.history.append([team, what])
	return {"what": what, "team": team, "holder": c.holder, "rayas": c.rayas}


## The ring (R13, classic court): the ball through a ring wins the game outright, whatever the count.
static func award_ring(c: Count, team: int) -> Dictionary:
	if c.winner >= 0:
		return {"what": "over", "team": team}
	c.winner = team
	c.ring = true
	c.history.append([team, "ring"])
	return {"what": "ring", "team": team}


## When the time a match may take runs out (R14, the game's own: real games run until a side reaches eight): the side
## holding the count (or ahead on points) wins; level, the next raya wins (sudden_death).
static func at_time(c: Count) -> int:
	if c.winner >= 0:
		return c.winner
	if c.rules == CLASSIC:
		if int(c.points[0]) != int(c.points[1]):
			return 0 if int(c.points[0]) > int(c.points[1]) else 1
		return -1
	return c.holder


# ---------------------------------------------------------------- what wins a raya

## R8. The ball comes to rest (or as good as: rolling too slowly to reach anyone) at x: the side whose half it dies in
## failed to return it past the analco, so the raya goes to the other side. A ball struck that dies short of the
## analco, still in the striker's own half, is the striker's failure the same way. On the analco itself, the side
## that struck it last loses the raya (it did not pass the line).
static func dead_ball(x: float, last_team: int) -> int:
	var h := half_of(x)
	if h < 0:
		return other(last_team) if last_team >= 0 else 0
	return other(h)


## R9 (ulama). The ball goes over an end line (the chivo): the side whose end it is loses the raya, whoever drove it
## there. Returns the team that wins the raya.
static func over_end(x: float) -> int:
	return 0 if x > 0.0 else 1


## R10 (ulama). The ball goes out over a side line: a fault against the side that last struck it.
## R15 (classic). Over the top of a side wall: the same (reconstructed).
static func out_side(last_team: int) -> int:
	return other(last_team)


## R6. The ball touches a player anywhere but his hip (a strike that was not a hip strike, or the ball running into
## his legs or body): a fault, the raya to the other side. Hands are allowed only to the server throwing the ball in
## (R11).
static func body_touch(team: int) -> int:
	return other(team)


## R16 (classic). The ball lands in, or flies over, an end court: the point goes to the side driving the ball that way
## (Durán: "landing in or flying over an end zone"); in the striker's own end court, to the other side.
static func end_court(x: float) -> int:
	return over_end(x)


## The legal strikes (R5): ulama de cadera, the hip only (some sources: the hip and the top of the thigh); the classic
## court the same (Durán: the hip and the upper leg). The dive is a hip strike made low, the player on the ground.
static func legal_strike(part: String) -> bool:
	return part in ["hip", "hip_low", "thigh_top"]


# ---------------------------------------------------------------- the serve

## R11. The serve (the male): the server puts the ball in play by hand, across the analco: male abajo, rolled along the
## ground; male arriba, thrown high. The kind changes with the score (Aguilar-Moreno); which score calls for which is
## not documented, so the game rolls it from level (CONADE: play starts with the low serve) and throws it high once a
## side holds the count (reconstructed).
static func serve_kind(c: Count) -> String:
	if c.rules == CLASSIC:
		return "arriba"
	return "abajo" if c.holder < 0 else "arriba"


## Who serves: the first serve to the home side, then the side that won the last raya (reconstructed: no source says).
static func server(c: Count) -> int:
	if c.history.is_empty():
		return 0
	return int(c.history[c.history.size() - 1][0])


## A serve that does not cross the analco (thrown short, rolled out of strength) gives the raya to the other side.
static func serve_short(server_team: int) -> int:
	return other(server_team)
