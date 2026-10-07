class_name Cup
extends RefCounted
## Nations Cup: eight countries, two groups of four, semi-finals and a final.
## Points table uses Pro-style scoring: win 5, tie 3, loss by 7 or fewer 1, other loss 0.

const FIELD := ["IND", "IRN", "KOR", "PAK", "BAN", "KEN", "JPN", "ARG"]

var user := "IND"
var teams: Array = []
var groups := {"A": [], "B": []}
var fixtures: Array = []   # {stage, group, round, home, away, played, score}
var stage := "group"       # group, semi, final, done
var champion := ""
var seed_value := 0


static func create(country: String) -> Cup:
	var c := Cup.new()
	c.user = country
	var field: Array = FIELD.duplicate()
	if not field.has(country):
		# Swap the user's country in for the lowest-rated entrant.
		field.sort_custom(func(a, b): return DB.team(a).base > DB.team(b).base)
		field[field.size() - 1] = country
	field.sort_custom(func(a, b): return DB.team(a).base > DB.team(b).base)
	c.teams = field
	c.groups = {"A": [field[0], field[3], field[4], field[7]], "B": [field[1], field[2], field[5], field[6]]}
	c.seed_value = randi()
	for g in ["A", "B"]:
		var t: Array = c.groups[g]
		var rounds := [[[t[0], t[3]], [t[1], t[2]]], [[t[0], t[2]], [t[3], t[1]]], [[t[0], t[1]], [t[2], t[3]]]]
		for r in rounds.size():
			for pair in rounds[r]:
				c.fixtures.append({"stage": "group", "group": g, "round": r + 1, "home": pair[0], "away": pair[1], "played": false, "score": [0, 0]})
	return c


static func from_dict(d: Dictionary) -> Cup:
	var c := Cup.new()
	c.user = d.get("user", "IND")
	c.teams = d.get("teams", [])
	c.groups = d.get("groups", {"A": [], "B": []})
	c.fixtures = d.get("fixtures", [])
	for f in c.fixtures:
		f.round = int(f.round)
		f.score = [int(f.score[0]), int(f.score[1])]
	c.stage = d.get("stage", "group")
	c.champion = d.get("champion", "")
	c.seed_value = int(d.get("seed", 0))
	return c


func to_dict() -> Dictionary:
	return {"user": user, "teams": teams, "groups": groups, "fixtures": fixtures, "stage": stage, "champion": champion, "seed": seed_value}


func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value + salt * 7919
	return r


func _rating(id: String) -> int:
	return DB.team_rating(DB.team(id).squad)


func next_user_fixture():
	for f in fixtures:
		if not f.played and (f.home == user or f.away == user):
			return f
	return null


func user_alive() -> bool:
	if stage == "done":
		return false
	if stage == "group":
		return true
	return next_user_fixture() != null


## Store the user's result, simulate the rest of that round, and move the tournament on.
func record_user_result(result: Dictionary) -> void:
	var f = next_user_fixture()
	if f == null:
		return
	var s: Array = result.score
	# Team 0 in the match is always the user's side.
	if f.home == user:
		f.score = [int(s[0]), int(s[1])]
	else:
		f.score = [int(s[1]), int(s[0])]
	f.played = true
	_sim_round(f.stage, int(f.round))
	_advance()


func sim_everything_left() -> void:
	var guard := 0
	while stage != "done" and guard < 10:
		guard += 1
		for f in fixtures:
			if not f.played and f.stage == stage:
				_sim(f)
		_advance()


func _sim_round(st: String, rnd: int) -> void:
	for f in fixtures:
		if not f.played and f.stage == st and int(f.round) == rnd:
			_sim(f)


func _sim(f: Dictionary) -> void:
	var r := _rng(fixtures.find(f) + 1)
	f.score = DB.simulate(_rating(f.home), _rating(f.away), r, f.stage != "group")
	f.played = true


func _advance() -> void:
	for f in fixtures:
		if f.stage == stage and not f.played:
			return
	match stage:
		"group":
			var a := standings("A")
			var b := standings("B")
			fixtures.append({"stage": "semi", "group": "", "round": 4, "home": a[0].id, "away": b[1].id, "played": false, "score": [0, 0]})
			fixtures.append({"stage": "semi", "group": "", "round": 4, "home": b[0].id, "away": a[1].id, "played": false, "score": [0, 0]})
			stage = "semi"
		"semi":
			var winners := []
			for f in fixtures:
				if f.stage == "semi":
					winners.append(f.home if f.score[0] > f.score[1] else f.away)
			fixtures.append({"stage": "final", "group": "", "round": 5, "home": winners[0], "away": winners[1], "played": false, "score": [0, 0]})
			stage = "final"
		"final":
			for f in fixtures:
				if f.stage == "final":
					champion = f.home if f.score[0] > f.score[1] else f.away
			stage = "done"


static func points_for(mine: int, theirs: int) -> int:
	if mine > theirs:
		return 5
	if mine == theirs:
		return 3
	return 1 if theirs - mine <= 7 else 0


func standings(group: String) -> Array:
	var rows := {}
	for id in groups[group]:
		rows[id] = {"id": id, "p": 0, "w": 0, "d": 0, "l": 0, "pd": 0, "pts": 0, "for": 0}
	for f in fixtures:
		if f.stage != "group" or f.group != group or not f.played:
			continue
		var h: Dictionary = rows[f.home]
		var a: Dictionary = rows[f.away]
		var hs: int = f.score[0]
		var as_: int = f.score[1]
		for pair in [[h, hs, as_], [a, as_, hs]]:
			var row: Dictionary = pair[0]
			row.p += 1
			row["for"] += pair[1]
			row.pd += pair[1] - pair[2]
			row.pts += points_for(pair[1], pair[2])
			if pair[1] > pair[2]:
				row.w += 1
			elif pair[1] == pair[2]:
				row.d += 1
			else:
				row.l += 1
	var out := rows.values()
	out.sort_custom(func(x, y): return x.pts > y.pts or (x.pts == y.pts and (x.pd > y.pd or (x.pd == y.pd and x["for"] > y["for"]))))
	return out


func stage_name() -> String:
	match stage:
		"group":
			return tr("GROUP_STAGE")
		"semi":
			return tr("SEMI_FINAL")
		"final":
			return tr("FINAL")
	return tr("KNOCKOUTS")
