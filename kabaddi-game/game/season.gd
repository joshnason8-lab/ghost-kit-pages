class_name Season
extends RefCounted
## League Season: you own a Premier Raid League franchise.
##
## Each year: the player auction (you hold the paddle), 11 league rounds, then playoffs in the
## pro format: the top six go through, 3rd v 6th and 4th v 5th in eliminators, 1st and 2nd wait
## in the semi-finals, then the final. Win it and you lift the trophy.

var team := ""
var year := 1
var phase := "auction"          # auction, league, playoffs, done
var squads := {}                # team id -> Array of player dictionaries
var purses := {}                # lakhs left after the auction
var fixtures: Array = []        # {stage, round, home, away, played, score}
var champion := ""
var history: Array = []         # {year, finish, champion, mvp}
var player_stats := {}          # pid -> {name, team, raid, tackle, matches}, this season
var awards := {}                # Awards.leaders() once the season is done
var seed_value := 0


static func create(team_id: String) -> Season:
	var s := Season.new()
	s.team = team_id
	s.seed_value = randi()
	for id in DB.league_ids:
		s.squads[id] = DB.team(id).squad.duplicate(true)
	return s


static func from_dict(d: Dictionary) -> Season:
	var s := Season.new()
	s.team = d.get("team", "")
	s.year = int(d.get("year", 1))
	s.phase = d.get("phase", "auction")
	s.squads = d.get("squads", {})
	for id in s.squads:
		for p in s.squads[id]:
			for k in DB.ATTRS:
				p.attrs[k] = int(p.attrs[k])
			for k in ["skin", "hair", "number"]:
				p[k] = int(p[k])
	s.purses = d.get("purses", {})
	s.fixtures = d.get("fixtures", [])
	for f in s.fixtures:
		f.round = int(f.round)
		f.score = [int(f.score[0]), int(f.score[1])]
	s.champion = d.get("champion", "")
	s.history = d.get("history", [])
	s.seed_value = int(d.get("seed", 0))
	s.player_stats = d.get("player_stats", {})
	s.awards = d.get("awards", {})
	if s.squads.is_empty():
		for id in DB.league_ids:
			s.squads[id] = DB.team(id).squad.duplicate(true)
	return s


func to_dict() -> Dictionary:
	return {"team": team, "year": year, "phase": phase, "squads": squads, "purses": purses,
		"fixtures": fixtures, "champion": champion, "history": history, "seed": seed_value,
		"player_stats": player_stats, "awards": awards}


func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value + year * 100003 + salt * 7919
	return r


# ---------------------------------------------------------------- auction

## Each franchise keeps its best six; the rest of the league, plus young talent, goes under the hammer.
func make_auction() -> AuctionEngine:
	var eng := AuctionEngine.new()
	eng.rng.seed = seed_value + year
	eng.user_team = team
	var rng := _rng(1)
	var released := []
	for id in DB.league_ids:
		var sq: Array = squads[id].duplicate()
		sq.sort_custom(func(a, b): return DB.overall(a) > DB.overall(b))
		var kept: Array = sq.slice(0, 6)
		var cost := 0.0
		for p in kept:
			cost += float(AuctionEngine.CATEGORIES[AuctionEngine.category_for(DB.overall(p))]) * 1.8
		eng.teams[id] = {"purse": snappedf(500.0 - cost, 0.5), "squad": kept, "fbm": 1}
		for p in sq.slice(6):
			released.append([p, id])
	released.sort_custom(func(a, b): return DB.overall(a[0]) > DB.overall(b[0]))
	for pair in released.slice(0, 26):
		eng.add_lot(pair[0], pair[1])
	# New Young Players from the junior circuit.
	var used := {}
	for i in 8:
		var role: String = ["raider", "defender", "allrounder", "defender"][i % 4]
		var n := "%s %s" % [DB.FIRST_NAMES.values()[i % 6][rng.randi() % 6], DB.LAST_NAMES.values()[(i + 2) % 6][rng.randi() % 6]]
		if used.has(n) or DB.BLOCKED_NAMES.has(n):
			n += " Jr"
		used[n] = true
		var p := DB.make_player(rng, role, rng.randi_range(58, 70), n)
		p.id = "NYP_%d_%d" % [year, i]
		p.number = rng.randi_range(2, 99)
		eng.add_lot(p, "", true)
	eng.sort_lots()
	# Released players who don't make the auction list stay available as free agents.
	_free_agents = []
	for pair in released.slice(26):
		_free_agents.append(pair[0])
	return eng


var _free_agents: Array = []


func finish_auction(eng: AuctionEngine) -> void:
	var pool := _free_agents.duplicate()
	for l in eng.lots:
		if l.status == "unsold":
			pool.append(l.player)
	pool.sort_custom(func(a, b): return DB.overall(a) > DB.overall(b))
	for id in eng.teams:
		var sq: Array = eng.teams[id].squad
		# Fill to ten from free agents at minimum price.
		while sq.size() < 10 and not pool.is_empty():
			var p: Dictionary = pool.pop_front().duplicate(true)
			p.team = id
			sq.append(p)
			eng.teams[id].purse = float(eng.teams[id].purse) - 6.0
		for i in sq.size():
			sq[i].team = id
			if String(sq[i].get("id", "")) == "" or not String(sq[i].id).begins_with(id):
				sq[i].id = "%s_y%d_%d" % [id, year, i]
		squads[id] = sq
		purses[id] = float(eng.teams[id].purse)
	_start_league()


# ---------------------------------------------------------------- league

func _start_league() -> void:
	phase = "league"
	champion = ""
	fixtures = []
	var ids: Array = DB.league_ids.duplicate()
	var rng := _rng(2)
	for i in range(ids.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = ids[i]
		ids[i] = ids[j]
		ids[j] = tmp
	var n := ids.size()
	for r in n - 1:
		for k in n / 2:
			var a: String = ids[k]
			var b: String = ids[n - 1 - k]
			var home_first := (r + k) % 2 == 0
			fixtures.append({"stage": "league", "round": r + 1, "home": a if home_first else b, "away": b if home_first else a, "played": false, "score": [0, 0]})
		var last = ids.pop_back()
		ids.insert(1, last)


func rating(id: String) -> int:
	return DB.team_rating(squads.get(id, DB.team(id).squad))


func next_user_fixture():
	for f in fixtures:
		if not f.played and (f.home == team or f.away == team):
			return f
	return null


func current_stage() -> String:
	for f in fixtures:
		if not f.played:
			return String(f.stage)
	return "done"


func record_user_result(result: Dictionary) -> void:
	var f = next_user_fixture()
	if f == null:
		return
	var s: Array = result.score
	f.score = [int(s[0]), int(s[1])] if f.home == team else [int(s[1]), int(s[0])]
	f.played = true
	Awards.add_match(player_stats, result.get("player_stats", {}))
	_after(f)


func simulate_user_match() -> void:
	var f = next_user_fixture()
	if f == null:
		return
	_sim(f)
	_after(f)


func _sim(f: Dictionary) -> void:
	var rng := _rng(fixtures.find(f) + 31)
	f.score = DB.simulate(rating(f.home), rating(f.away), rng, f.stage != "league")
	f.played = true
	Awards.sim_team(player_stats, squads[f.home], f.home, int(f.score[0]), rng)
	Awards.sim_team(player_stats, squads[f.away], f.away, int(f.score[1]), rng)


func _after(f: Dictionary) -> void:
	for o in fixtures:
		if not o.played and o.stage == f.stage and int(o.round) == int(f.round):
			_sim(o)
	_advance()


func _winner(f: Dictionary) -> String:
	return f.home if f.score[0] > f.score[1] else f.away


func _loser(f: Dictionary) -> String:
	return f.away if f.score[0] > f.score[1] else f.home


## Moves the season on whenever a stage is complete, simulating anything the user isn't in.
func _advance() -> void:
	var guard := 0
	while guard < 10:
		guard += 1
		var st := current_stage()
		if st != "done":
			if next_user_fixture() != null and String(next_user_fixture().stage) == st:
				return
			for f in fixtures:
				if not f.played and f.stage == st:
					_sim(f)
			continue
		var stages := {}
		for f in fixtures:
			stages[f.stage] = true
		if not stages.has("eliminator"):
			phase = "playoffs"
			var t := standings()
			fixtures.append({"stage": "eliminator", "round": 12, "home": t[2].id, "away": t[5].id, "played": false, "score": [0, 0], "tag": "E1"})
			fixtures.append({"stage": "eliminator", "round": 12, "home": t[3].id, "away": t[4].id, "played": false, "score": [0, 0], "tag": "E2"})
		elif not stages.has("semi"):
			var t := standings()
			var order := {}
			for i in t.size():
				order[t[i].id] = i
			var e_winners := []
			for f in fixtures:
				if f.stage == "eliminator":
					e_winners.append(_winner(f))
			e_winners.sort_custom(func(a, b): return order[a] > order[b])   # lowest ranked first
			fixtures.append({"stage": "semi", "round": 13, "home": t[0].id, "away": e_winners[0], "played": false, "score": [0, 0], "tag": "S1"})
			fixtures.append({"stage": "semi", "round": 13, "home": t[1].id, "away": e_winners[1], "played": false, "score": [0, 0], "tag": "S2"})
		elif not stages.has("final"):
			var w := []
			for f in fixtures:
				if f.stage == "semi":
					w.append(_winner(f))
			fixtures.append({"stage": "final", "round": 14, "home": w[0], "away": w[1], "played": false, "score": [0, 0], "tag": "F"})
		else:
			for f in fixtures:
				if f.stage == "final":
					champion = _winner(f)
			phase = "done"
			var pos := 0
			var t := standings()
			for i in t.size():
				if t[i].id == team:
					pos = i + 1
			awards = Awards.leaders(player_stats)
			history.append({"year": year, "finish": pos, "champion": champion, "mvp": awards.get("mvp", {})})
			return


func standings() -> Array:
	var rows := {}
	for id in DB.league_ids:
		rows[id] = {"id": id, "p": 0, "w": 0, "d": 0, "l": 0, "pd": 0, "pts": 0, "for": 0}
	for f in fixtures:
		if f.stage != "league" or not f.played:
			continue
		var hs: int = f.score[0]
		var as_: int = f.score[1]
		for pair in [[rows[f.home], hs, as_], [rows[f.away], as_, hs]]:
			var row: Dictionary = pair[0]
			row.p += 1
			row["for"] += pair[1]
			row.pd += pair[1] - pair[2]
			row.pts += Cup.points_for(pair[1], pair[2])
			if pair[1] > pair[2]:
				row.w += 1
			elif pair[1] == pair[2]:
				row.d += 1
			else:
				row.l += 1
	var out := rows.values()
	out.sort_custom(func(x, y): return x.pts > y.pts or (x.pts == y.pts and (x.pd > y.pd or (x.pd == y.pd and x["for"] > y["for"]))))
	return out


func match_config(f: Dictionary) -> Dictionary:
	var opp: String = f.away if f.home == team else f.home
	var arenas := ["dome", "stadium", "dome", "monsoon", "village", "beach", "dome"]
	var arena: String = arenas[(int(f.round) + absi(hash(opp))) % arenas.size()] if f.stage == "league" else "stadium"
	return {"home": team, "away": opp, "arena": arena, "mode": "season", "control": "all",
		"length": int(Game.settings.length), "difficulty": int(Game.settings.difficulty),
		"knockout": f.stage != "league", "home_squad": squads[team], "away_squad": squads[opp]}


func next_year() -> void:
	year += 1
	phase = "auction"
	fixtures = []
	champion = ""
	player_stats = {}
	awards = {}
