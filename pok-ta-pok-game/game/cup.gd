class_name Cup
extends RefCounted
## The town tournament: eight towns, drawn into a knock-out (quarter-finals, semi-finals, the final), on the courts of
## the rules chosen (the earth courts for ulama, the stone courts for the classic game). You play your town's games;
## the others are played out raya by raya (Sim). Saved after each game (Game.save_cup).

const STAGES := ["STAGE_QUARTER", "STAGE_SEMI", "STAGE_FINAL"]

var team := ""
var rules := Rules.ULAMA
var round := 0                # 0 quarter, 1 semi, 2 final; 3 done
var draw: Array = []          # this round's pairs: [[home, away, winner (-1 unplayed), count dict], ...]
var history: Array = []       # earlier rounds, as draw
var champion := ""
var out := false              # your town is out


static func create(p_team: String, p_rules := "") -> Cup:
	var c := Cup.new()
	c.team = p_team
	c.rules = p_rules if p_rules != "" else String(Game.settings.get("mode", Rules.ULAMA))
	var pool: Array = DB.teams_for(c.rules)
	pool.erase(p_team)
	var field := [p_team] + pool.slice(0, 7)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p_team + c.rules + str(Time.get_unix_time_from_system()))
	for i in range(field.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = field[i]
		field[i] = field[j]
		field[j] = t
	for i in 4:
		c.draw.append([field[i * 2], field[i * 2 + 1], -1, {}])
	return c


static func from_dict(d: Dictionary) -> Cup:
	var c := Cup.new()
	c.team = String(d.get("team", ""))
	c.rules = String(d.get("rules", Rules.ULAMA))
	c.round = int(d.get("round", 0))
	c.draw = d.get("draw", [])
	c.history = d.get("history", [])
	c.champion = String(d.get("champion", ""))
	c.out = bool(d.get("out", false))
	for pair in c.draw:
		pair[2] = int(pair[2])
	return c


func to_dict() -> Dictionary:
	return {"team": team, "rules": rules, "round": round, "draw": draw, "history": history, "champion": champion, "out": out}


func done() -> bool:
	return round >= STAGES.size()


func stage_key() -> String:
	return STAGES[mini(round, STAGES.size() - 1)]


## Your next game: {home, away, stage, venue}, or {} when you are out or it is over.
func next_fixture() -> Dictionary:
	if done() or out:
		return {}
	for pair in draw:
		if (pair[0] == team or pair[1] == team) and int(pair[2]) < 0:
			var venues := DB.venues_for(rules)
			return {"home": pair[0], "away": pair[1], "stage": stage_key(), "venue": venues[mini(round, venues.size() - 1) % venues.size()]}
	return {}


## Your game's result in: the rest of the round is played, and the winners drawn on.
func record_user_result(r: Dictionary) -> void:
	for pair in draw:
		if String(pair[0]) == String(r.home) and String(pair[1]) == String(r.away) and int(pair[2]) < 0:
			pair[2] = int(r.winner)
			pair[3] = r.get("count", {})
	play_others()


## Plays every unplayed game of the round that is not yours (all of them once you are out), then moves on.
func play_others() -> void:
	for pair in draw:
		if int(pair[2]) >= 0:
			continue
		if (pair[0] == team or pair[1] == team) and not out:
			continue
		var s := Sim.play(String(pair[0]), String(pair[1]), rules)
		pair[2] = int(s.winner)
		pair[3] = s.count
	_advance()


func _advance() -> void:
	for pair in draw:
		if int(pair[2]) < 0:
			return
	var winners := []
	for pair in draw:
		winners.append(pair[int(pair[2])])
	if not (team in winners):
		out = true
	history.append(draw)
	round += 1
	if winners.size() == 1:
		champion = String(winners[0])
		round = STAGES.size()
		draw = []
		return
	draw = []
	for i in winners.size() / 2:
		draw.append([winners[i * 2], winners[i * 2 + 1], -1, {}])
	if out:
		play_others()
