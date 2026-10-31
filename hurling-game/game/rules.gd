class_name Rules
extends RefCounted
## The playing rules of hurling, as the match uses them: a pure module (no nodes, no randomness) the match asks
## what the rules say, so each rule can be tested on its own (tests/test_runner.gd). Rule numbers are those of the
## GAA Official Guide Part 2, the edition in force from 27 March 2026; docs/RULES.md has each with its source and
## how the game plays it.

# ---------------------------------------------------------------- scores (Playing Rules, Scores)

const GOAL_VALUE := 3          # a goal: over the goal line, between the posts, under the crossbar
const POINT_VALUE := 1         # a point: over the crossbar, between the posts

## Goals and points as the score is written and called: "2-18". The total is three a goal plus the points.
static func total(goals: int, points: int) -> int:
	return goals * GOAL_VALUE + points * POINT_VALUE


static func fmt(goals: int, points: int) -> String:
	return "%d-%d" % [goals, points]


## Does a ball that crossed between the posts score, given how it was last played? A goal cannot be scored with a
## hand-pass, nor by throwing or carrying the ball over the line; a point can be hand-passed, if it is a legal hand-pass.
## kind: "goal" or "point" (where it crossed, Pitch.score_kind); how: the last play ("strike", "hand_pass", "kick",
## "throw", "carry", "deflect", "free", "65", "sideline", "penalty", "puck_out").
static func score_counts(kind: String, how: String) -> bool:
	if how in ["throw", "carry"]:
		return false
	if kind == "goal" and how == "hand_pass":
		return false
	return kind == "goal" or kind == "point"


## A shoot-out penalty counts only as a goal.
static func shootout_counts(kind: String) -> bool:
	return kind == "goal"


# ---------------------------------------------------------------- time (Rules of Control, Rule 3)

const GRADE_SENIOR := 0        # senior inter-county: 2 x 35 minutes, half-time up to 15, the black card applies
const GRADE_CLUB := 1          # club (and inter-county minor, U-20 and junior): 2 x 30, half-time up to 10

static func half_minutes(grade: int) -> int:
	return 35 if grade == GRADE_SENIOR else 30


static func half_time_minutes(grade: int) -> int:
	return 15 if grade == GRADE_SENIOR else 10


const EXTRA_HALF := 10         # extra time: two periods of 10 minutes (Rule 3.4)
const SHOOTOUT_TAKERS := 5     # then five penalties each, goals only, then sudden death


## Is the shoot-out decided after taken[k] penalties each with goals[k] scored? Five each first; once both have
## taken five, the first round that ends with one side ahead decides it. Within the five, it ends as soon as one
## side cannot be caught.
static func shootout_winner(goals: Array, taken: Array) -> int:
	var a := int(goals[0])
	var b := int(goals[1])
	var ta := int(taken[0])
	var tb := int(taken[1])
	if ta <= SHOOTOUT_TAKERS and tb <= SHOOTOUT_TAKERS:
		if a > b + (SHOOTOUT_TAKERS - tb):
			return 0
		if b > a + (SHOOTOUT_TAKERS - ta):
			return 1
		if ta < SHOOTOUT_TAKERS or tb < SHOOTOUT_TAKERS:
			return -1
	if ta == tb and a != b:
		return 0 if a > b else 1
	return -1


## Substitutes (Rules of Control, Rule 1): five in normal time, three more in extra time. Temporary substitutes for
## a blood injury, a suspected head injury or a player in the sin bin do not count. A player sent off cannot be
## replaced.
const SUBS_NORMAL := 5
const SUBS_EXTRA := 3


static func subs_allowed(extra_time: bool) -> int:
	return SUBS_NORMAL + (SUBS_EXTRA if extra_time else 0)


# ---------------------------------------------------------------- the play (Playing Rules, The Play; technical fouls)

const MAX_STEPS := 4           # steps with the sliotar in the hand
const MAX_CATCHES := 2         # times it may be caught (taken into the hand) before it is played away
## "Or held no longer than the time it takes to take four steps": four walking steps, standing still.
const MAX_HOLD_S := 2.4

## The sliotar in a player's possession, for the carrying rules. in_hand: in the hand now (else on the hurley, or
## not his); steps: steps taken with it in the hand since it was last taken into the hand; held: seconds held in
## the hand so; catches: times taken into the hand in this possession.
class Carry:
	var in_hand := false
	var steps := 0
	var held := 0.0
	var catches := 0


## He takes it into his hand (a catch, or from his hurley). The third time is a foul ("catching it more than twice
## before playing it away").
static func take_in_hand(c: Carry) -> String:
	c.catches += 1
	c.in_hand = true
	c.steps = 0
	c.held = 0.0
	return "FOUL_CATCH_3" if c.catches > MAX_CATCHES else ""


## A step taken (a foot put down while it is in his hand), and time held. Over four steps, or held longer than four
## steps would take, is a foul ("overcarrying"). Steps on the hurley are free.
static func carry_step(c: Carry, steps: int, dt: float) -> String:
	if not c.in_hand:
		return ""
	c.steps += steps
	c.held += dt
	if c.steps > MAX_STEPS:
		return "FOUL_STEPS"
	if c.held > MAX_HOLD_S:
		return "FOUL_HOLD"
	return ""


## He puts it from his hand onto his hurley (a solo or a bounce on the bas): the steps start again when it comes back.
static func to_hurley(c: Carry) -> void:
	c.in_hand = false
	c.steps = 0
	c.held = 0.0


## He plays it away (a strike, a hand-pass, a kick) or loses it: the possession is over.
static func release(c: Carry) -> void:
	c.in_hand = false
	c.steps = 0
	c.held = 0.0
	c.catches = 0


## Picking the ball off the ground with the hand is a foul; it must be lifted with the hurley (or the foot).
static func ground_lift_ok(with: String) -> bool:
	return with in ["hurley", "foot"]


## A hand-pass must be released and struck with a definite striking action of the hand; throwing it is a foul.
static func hand_pass_ok(struck: bool) -> bool:
	return struck


## Letting it go from the hand and catching it again without playing it with the hurley is a foul (no bouncing it off
## the ground and catching it, no tossing it up to himself).
static func recatch_ok(played_on_hurley_since: bool) -> bool:
	return played_on_hurley_since


# ---------------------------------------------------------------- restarts (Playing Rules, Set Play)

const FREE_DISTANCE := 13.0    # opponents at least 13 m from a free, a sideline cut or a 65
const PUCK_OUT_CLEAR := 20.0   # at a puck-out all but the taker and the goalkeeper outside the 20 m line
const PUCK_OUT_TRAVEL := 13.0  # the puck-out must travel 13 m before another defender plays it
const PENALTY_RUNUP := 7.0     # a penalty may be placed up to 7 m behind the 20 m line, within the arc
const DISSENT_ADVANCE := 30.0  # dissent: the free moves 30 m on, no nearer goal than the 20 m line (2026)
const ADVANTAGE_S := 5.0       # the referee may play advantage for up to five seconds

## What follows a ball over the end line, wide of the posts or off them: a puck-out to the defenders if an attacker
## played it last, a 65 to the attackers if a defender did, taken from the 65 m line opposite where it crossed.
## dir: the direction the attacking team plays (+1 toward +x). Returns {kind, team, spot}.
static func over_end_line(cross: Vector3, last_team: int, attacking_team: int, dir: float) -> Dictionary:
	var defending := 1 - attacking_team
	if last_team == attacking_team:
		return {"kind": "puck_out", "team": defending, "spot": Vector3((Pitch.HALF_L - Pitch.SMALL_D * 0.5) * dir, 0, 0)}
	var z := clampf(cross.z, -Pitch.HALF_W + 1.0, Pitch.HALF_W - 1.0)
	return {"kind": "65", "team": attacking_team, "spot": Vector3((Pitch.HALF_L - 65.0) * dir, 0, z)}


## After a score: a puck-out to the side scored against.
static func after_score(scored_by: int, dir: float) -> Dictionary:
	return {"kind": "puck_out", "team": 1 - scored_by, "spot": Vector3((Pitch.HALF_L - Pitch.SMALL_D * 0.5) * dir, 0, 0)}


## Over the side line: a sideline cut to the other side, where it crossed, struck from the ground.
static func over_side_line(cross: Vector3, last_team: int) -> Dictionary:
	var x := clampf(cross.x, -Pitch.HALF_L + 0.5, Pitch.HALF_L - 0.5)
	return {"kind": "sideline", "team": 1 - last_team, "spot": Vector3(x, 0, Pitch.HALF_W * signf(cross.z))}


## Fouls (Playing Rules, Fouls). Technical fouls (overcarrying, throwing, picking up, catching a third time ...) and
## aggressive fouls (pulling an opponent down, tripping, holding, pushing, charging from behind or the front, a
## careless hurley, striking a hurley, charging the goalkeeper in the small rectangle, a charge by the player in
## possession, striking an opponent ...).
const TECHNICAL := ["FOUL_STEPS", "FOUL_HOLD", "FOUL_CATCH_3", "FOUL_THROW", "FOUL_PICK_UP", "FOUL_RECATCH",
	"FOUL_PUCK_OUT", "FOUL_FREE_TWICE", "FOUL_FREE_HAND"]
const AGGRESSIVE := ["FOUL_PULL_DOWN", "FOUL_TRIP", "FOUL_HOLD_MAN", "FOUL_PUSH", "FOUL_CHARGE", "FOUL_HURLEY",
	"FOUL_HOOK_HURLEY", "FOUL_KEEPER", "FOUL_STRIKE", "FOUL_DISSENT"]
## The fouls that can deny a goal-scoring opportunity (the black card rule, 5.45): pulling down, tripping, a
## careless hurley.
const DENIAL := ["FOUL_PULL_DOWN", "FOUL_TRIP", "FOUL_HURLEY"]


static func aggressive(foul: String) -> bool:
	return foul in AGGRESSIVE


## Where the free is taken, and what it is, for a foul at pos by the team fouling against the team fouled, whose
## attacking direction is dir. In the rules: a free from where the foul was; but an aggressive foul by a defender in
## his large rectangle is a penalty from the centre of the 20 m line, a technical foul by a defender there a free from
## the centre of the 20 m line, and a foul by a defender inside his own 20 m line, outside the large rectangle, a free
## on the 20 m line opposite. A foul that denies a goal-scoring opportunity inside the 20 m line or the arc is a
## penalty (and a black card: card_for). Returns {kind ("free" | "penalty"), team, spot}.
static func free_for(foul: String, pos: Vector3, fouled_team: int, dir: float, denial := false) -> Dictionary:
	var from_line := Pitch.from_goal_line(pos, dir)   # metres from the end line the fouled team attacks
	var p := Pitch.clamp_in(pos)
	if denial and (from_line <= 20.0 or Pitch.penalty_spot(dir).distance_to(Vector3(pos.x, 0, pos.z)) <= Pitch.ARC_R):
		return {"kind": "penalty", "team": fouled_team, "spot": Pitch.penalty_spot(dir)}
	if Pitch.in_large_rect(pos, dir):
		if aggressive(foul):
			return {"kind": "penalty", "team": fouled_team, "spot": Pitch.penalty_spot(dir)}
		return {"kind": "free", "team": fouled_team, "spot": Pitch.penalty_spot(dir)}
	if from_line < 20.0:
		return {"kind": "free", "team": fouled_team, "spot": Vector3((Pitch.HALF_L - 20.0) * dir, 0, p.z)}
	return {"kind": "free", "team": fouled_team, "spot": p}


## A free moved on for dissent: 30 m nearer the goal it attacks, but no nearer than the 20 m line (2026, Motion 19).
static func dissent_spot(spot: Vector3, dir: float) -> Vector3:
	var x := spot.x + DISSENT_ADVANCE * dir
	var limit := (Pitch.HALF_L - 20.0) * dir
	if (x - limit) * dir > 0.0:
		x = limit
	return Vector3(x, 0, spot.z)


## How each restart is taken. lift: may be lifted with the hurley and struck (or struck on the ground); hand: may
## be struck from the hand; ground: must be struck off the ground.
static func restart_lift(kind: String) -> bool:
	return kind in ["free", "65", "penalty", "puck_out"]


static func restart_from_hand(kind: String) -> bool:
	return kind == "puck_out"


## Where opponents must stand at a restart: false if the player at p is too near (or inside the line he must keep
## behind). kind, the restart; spot, the ball; team_taking; p, the player; his_team; dir, the direction the taking
## team attacks.
static func position_ok(kind: String, spot: Vector3, team_taking: int, p: Vector3, his_team: int, dir: float, is_keeper := false) -> bool:
	match kind:
		"puck_out":
			# Everyone but the taker and the goalkeeper outside the 20 m line, both sides. The taking team's own end
			# is at -dir.
			if is_keeper:
				return true
			return Pitch.from_goal_line(p, -dir) >= PUCK_OUT_CLEAR
		"penalty":
			# One defender on the goal line; everyone else outside the 20 m line and the arc.
			if his_team != team_taking and is_keeper:
				return Pitch.from_goal_line(p, dir) <= 0.5 and absf(p.z) < Pitch.POST_GAP * 0.5
			var outside_line := Pitch.from_goal_line(p, dir) >= 20.0
			var outside_arc := Pitch.penalty_spot(dir).distance_to(Vector3(p.x, 0, p.z)) >= Pitch.ARC_R
			return outside_line and outside_arc
		_:
			if his_team == team_taking:
				return true
			return Vector3(p.x, 0, p.z).distance_to(Vector3(spot.x, 0, spot.z)) >= FREE_DISTANCE - 0.01


## Up to five defenders may stand on the goal line for a free from the 20 m line (and may not advance until it is
## struck); for a penalty only one.
static func line_defenders(kind: String) -> int:
	return 1 if kind == "penalty" else (5 if kind == "free20" else 0)


## A penalty or a 20 m free must be struck on or outside the 20 m line; struck inside, it is a throw-in on the 20 m line.
static func penalty_strike_ok(strike_pos: Vector3, dir: float) -> bool:
	return Pitch.from_goal_line(strike_pos, dir) >= 20.0 - 0.05


# ---------------------------------------------------------------- discipline (Rules of Control, Rule 6; 5.45)

## The card for a foul: "" none, "yellow", "red", "black" (sin bin, ten minutes). cynical: committed to stop an
## attack rather than in playing the ball; denial: it denied a goal-scoring opportunity inside the 20 m line or the
## arc, which is a black card where the rule applies (senior inter-county) and a penalty everywhere. A second
## yellow, or a black after a yellow or a black, is a red.
static func card_for(foul: String, cynical: bool, denial: bool, grade: int, yellows: int, blacks: int) -> String:
	var card := ""
	if foul == "FOUL_STRIKE":
		card = "red"
	elif denial and foul in DENIAL and black_card_applies(grade):
		card = "black"
	elif aggressive(foul) and (cynical or denial or foul in ["FOUL_HURLEY", "FOUL_KEEPER"]):
		card = "yellow"
	if card == "yellow" and yellows >= 1:
		return "red"
	if card == "black" and (yellows >= 1 or blacks >= 1):
		return "red"
	return card


static func black_card_applies(grade: int) -> bool:
	return grade == GRADE_SENIOR


const SIN_BIN_MIN := 10


## Advantage: for a technical foul the referee may wait up to five seconds to see if the fouled side gains from
## playing on; for an aggressive foul only where there is a clear goal-scoring chance or the fouled player has time
## and space (2021 wording). A player held up in a tackle gets the free.
static func may_play_advantage(foul: String, goal_chance: bool, time_and_space: bool) -> bool:
	if not aggressive(foul):
		return time_and_space or goal_chance
	return goal_chance or time_and_space


## The game starts, and each half and each period of extra time, with the referee throwing the sliotar in at the
## centre between two midfielders from each side, the rest in position. A throw-in also restarts play after
## simultaneous fouls, a stoppage with no free due, and a penalty struck inside the 20 m line.
static func throw_in_players() -> int:
	return 2
