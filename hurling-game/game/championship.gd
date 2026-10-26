class_name Championship
extends RefCounted
## The game's own competition, run the way the senior hurling championship is run now (docs/RULES.md, "The
## championship"), under its own name: the Summer Championship. Ten counties in two groups of five, a southern and
## an eastern; each plays the others in its group once (four games, home or away by turn), two points a win and one
## a draw. Then knock-out games, a draw going to extra time and a shoot-out: the top two of each group meet in their
## group's final; its winner goes to a semi-final; its loser meets the other group's third in a quarter-final; the
## quarter-final winners meet the group winners in the semi-finals; then the final. The ten other counties play the
## Tier Two Cup the same way to its semi-finals: two groups of five, the top two through.
## The real championships' names, cups and formats are the GAA's; this one is a plain one of the game's own.

var year := 2026
var user := ""
var tier := 1
var groups := {}          # name -> [team ids]
var fixtures: Array = []  # every fixture, group and knock-out: {id, home, away, stage, round, group, played, score,
                          # winner, knockout, et, pens}
var phase := "groups"     # "groups", "ko", "done"
var round := 0
var champion := ""
var ko_stage := ""


static func create(team_id: String) -> Championship:
	var c := Championship.new()
	c.user = team_id
	var g := String(DB.COUNTIES[team_id][4])
	if g == "":
		c.tier = 2
		var rest := DB.group_teams("")
		c.groups = {"A": [], "B": []}
		for i in rest.size():
			c.groups["A" if i % 2 == 0 else "B"].append(rest[i])
	else:
		c.tier = 1
		c.groups = {"S": DB.group_teams("S"), "E": DB.group_teams("E")}
	for gname in c.groups:
		c._round_robin(gname)
	return c


## A round robin of five: five rounds, each county playing four and resting once.
func _round_robin(gname: String) -> void:
	var teams: Array = groups[gname].duplicate()
	if teams.size() % 2 == 1:
		teams.append("")
	var n := teams.size()
	for r in n - 1:
		for i in n / 2:
			var a: String = teams[i]
			var b: String = teams[n - 1 - i]
			if a == "" or b == "":
				continue
			var home := a if (r + i) % 2 == 0 else b
			var away := b if home == a else a
			fixtures.append({"id": "%s%d%d" % [gname, r, i], "home": home, "away": away, "stage": "STAGE_GROUP", "group": gname,
				"round": r, "played": false, "score": [[0, 0], [0, 0]], "winner": -1, "knockout": false})
		# Rotate all but the first.
		var last: String = teams.pop_back()
		teams.insert(1, last)


func rounds() -> int:
	var r := 0
	for f in fixtures:
		if String(f.stage) == "STAGE_GROUP":
			r = maxi(r, int(f.round) + 1)
	return r


## The group table: [{id, p, w, d, l, sf (score for, in points' worth), sa, diff, pts}], sorted by points, then
## score difference, then scores for. (The real tie-breaker is head-to-head first; docs/RULES.md.)
func table(gname: String) -> Array:
	var rows := {}
	for id in groups[gname]:
		rows[id] = {"id": id, "p": 0, "w": 0, "d": 0, "l": 0, "sf": 0, "sa": 0, "diff": 0, "pts": 0}
	for f in fixtures:
		if String(f.get("group", "")) != gname or not bool(f.played) or String(f.stage) != "STAGE_GROUP":
			continue
		var a := Rules.total(int(f.score[0][0]), int(f.score[0][1]))
		var b := Rules.total(int(f.score[1][0]), int(f.score[1][1]))
		for k in 2:
			var r: Dictionary = rows[f.home if k == 0 else f.away]
			r.p += 1
			r.sf += a if k == 0 else b
			r.sa += b if k == 0 else a
			var mine := a if k == 0 else b
			var theirs := b if k == 0 else a
			if mine > theirs:
				r.w += 1
				r.pts += 2
			elif mine == theirs:
				r.d += 1
				r.pts += 1
			else:
				r.l += 1
	var out := rows.values()
	for r in out:
		r.diff = int(r.sf) - int(r.sa)
	out.sort_custom(func(x, y):
		if int(x.pts) != int(y.pts):
			return int(x.pts) > int(y.pts)
		if int(x.diff) != int(y.diff):
			return int(x.diff) > int(y.diff)
		return int(x.sf) > int(y.sf))
	return out


## Your next game, or {} if you have none to play in this round (or are out).
func next_fixture() -> Dictionary:
	for f in fixtures:
		if not bool(f.played) and (f.home == user or f.away == user) and _due(f):
			return f
	return {}


func _due(f: Dictionary) -> bool:
	if phase == "groups":
		return String(f.stage) == "STAGE_GROUP" and int(f.round) == round
	return String(f.stage) == ko_stage


## A round your county sits out (five in a group, so each has a bye): its other games are played and the
## championship moves on, round by round, until you have a game or are out. How many rounds went by.
func play_byes() -> int:
	var n := 0
	while phase != "done" and next_fixture().is_empty() and n < 20:
		var before := "%s%d%s" % [phase, round, ko_stage]
		play_others()
		n += 1
		if "%s%d%s" % [phase, round, ko_stage] == before:
			break
	return n


func user_out() -> bool:
	return phase == "done" or (phase == "ko" and next_fixture().is_empty() and not _user_in_later_stage())


func _user_in_later_stage() -> bool:
	for f in fixtures:
		if not bool(f.played) and (f.home == user or f.away == user):
			return true
	return false


## Your next game simulated instead of played (the championship page's Simulate): as the others are (Sim), then the
## rest of the round. The result, as {home, away, score, winner, et, pens}, or {} if there was none to play.
func sim_user(rng: RandomNumberGenerator = null) -> Dictionary:
	var f := next_fixture()
	if f.is_empty():
		return {}
	var r := Sim.play(String(f.home), String(f.away), rng, bool(f.knockout))
	_set_result(f, r.score, int(r.winner), bool(r.extra_time), r.pens)
	play_others()
	play_byes()
	return {"home": String(f.home), "away": String(f.away), "score": f.score, "winner": int(f.winner), "et": bool(f.et),
		"pens": f.pens, "stage": String(f.stage), "played": true}


## Every game left simulated, yours too, until your county is out or the championship is won (Simulate the rest).
func sim_rest(rng: RandomNumberGenerator = null) -> int:
	var n := 0
	while not user_out() and phase != "done" and n < 40:
		if sim_user(rng).is_empty():
			if play_byes() == 0:
				break
		n += 1
	return n


## Play every game of the round but yours (Sim), then move on if the round is done.
func play_others(rng: RandomNumberGenerator = null) -> void:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = hash("%s%d%d%s" % [user, year, round, ko_stage])
	for f in fixtures:
		if bool(f.played) or not _due(f) or f.home == user or f.away == user:
			continue
		var r := Sim.play(String(f.home), String(f.away), rng, bool(f.knockout))
		_set_result(f, r.score, int(r.winner), bool(r.extra_time), r.pens)
	_advance()


func record_user_result(result: Dictionary) -> void:
	var f := next_fixture()
	if f.is_empty():
		return
	var flip := String(result.home) != String(f.home)
	var sc: Array = result.score
	var score := [sc[1], sc[0]] if flip else [sc[0], sc[1]]
	var w := int(result.winner)
	if flip and w >= 0:
		w = 1 - w
	var so: Dictionary = result.get("shootout", {})
	var pens := []
	if not so.is_empty():
		pens = [so.goals[1], so.goals[0]] if flip else [so.goals[0], so.goals[1]]
	_set_result(f, score, w, bool(result.get("extra_time", false)), pens)
	play_others()


func _set_result(f: Dictionary, score: Array, winner: int, et: bool, pens: Array) -> void:
	f.played = true
	f.score = [[int(score[0][0]), int(score[0][1])], [int(score[1][0]), int(score[1][1])]]
	f.winner = winner
	f.et = et
	f.pens = pens


func _round_done() -> bool:
	for f in fixtures:
		if _due(f) and not bool(f.played):
			return false
	return true


func _advance() -> void:
	while _round_done() and phase != "done":
		if phase == "groups":
			round += 1
			if round >= rounds():
				phase = "ko"
				_next_ko("")
		else:
			_next_ko(ko_stage)


func _winner_of(id: String) -> String:
	for f in fixtures:
		if String(f.id) == id:
			return String(f.home if int(f.winner) == 0 else f.away)
	return ""


func _loser_of(id: String) -> String:
	for f in fixtures:
		if String(f.id) == id:
			return String(f.away if int(f.winner) == 0 else f.home)
	return ""


func _ko(id: String, home: String, away: String, stage: String) -> void:
	fixtures.append({"id": id, "home": home, "away": away, "stage": stage, "group": "", "round": 0, "played": false,
		"score": [[0, 0], [0, 0]], "winner": -1, "knockout": true})


func _next_ko(done: String) -> void:
	var gn: Array = groups.keys()
	var t0 := table(gn[0])
	var t1 := table(gn[1])
	if tier == 2:
		match done:
			"":
				ko_stage = "STAGE_SEMI"
				_ko("SF1", t0[0].id, t1[1].id, ko_stage)
				_ko("SF2", t1[0].id, t0[1].id, ko_stage)
			"STAGE_SEMI":
				ko_stage = "STAGE_FINAL"
				_ko("F", _winner_of("SF1"), _winner_of("SF2"), ko_stage)
			"STAGE_FINAL":
				_crown(_winner_of("F"))
		return
	match done:
		"":
			ko_stage = "STAGE_GROUP_FINAL"
			_ko("GF0", t0[0].id, t0[1].id, ko_stage)
			_ko("GF1", t1[0].id, t1[1].id, ko_stage)
		"STAGE_GROUP_FINAL":
			ko_stage = "STAGE_QUARTER"
			_ko("QF0", _loser_of("GF0"), t1[2].id, ko_stage)
			_ko("QF1", _loser_of("GF1"), t0[2].id, ko_stage)
		"STAGE_QUARTER":
			ko_stage = "STAGE_SEMI"
			_ko("SF0", _winner_of("GF0"), _winner_of("QF1"), ko_stage)
			_ko("SF1", _winner_of("GF1"), _winner_of("QF0"), ko_stage)
		"STAGE_SEMI":
			ko_stage = "STAGE_FINAL"
			_ko("F", _winner_of("SF0"), _winner_of("SF1"), ko_stage)
		"STAGE_FINAL":
			_crown(_winner_of("F"))


func _crown(id: String) -> void:
	champion = id
	phase = "done"
	ko_stage = ""
	if id == user:
		Records.add_title("CHAMP_TITLE_%d" % tier, year)


func name_key() -> String:
	return "CHAMP_NAME_1" if tier == 1 else "CHAMP_NAME_2"


func to_dict() -> Dictionary:
	return {"year": year, "user": user, "tier": tier, "groups": groups, "fixtures": fixtures, "phase": phase, "round": round,
		"champion": champion, "ko_stage": ko_stage}


static func from_dict(d: Dictionary) -> Championship:
	var c := Championship.new()
	c.year = int(d.get("year", 2026))
	c.user = String(d.get("user", ""))
	c.tier = int(d.get("tier", 1))
	c.groups = d.get("groups", {})
	c.fixtures = d.get("fixtures", [])
	for f in c.fixtures:
		f.round = int(f.get("round", 0))
		f.winner = int(f.get("winner", -1))
		for k in 2:
			f.score[k] = [int(f.score[k][0]), int(f.score[k][1])]
	c.phase = String(d.get("phase", "groups"))
	c.round = int(d.get("round", 0))
	c.champion = String(d.get("champion", ""))
	c.ko_stage = String(d.get("ko_stage", ""))
	return c
