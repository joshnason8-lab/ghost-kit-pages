class_name Career
extends RefCounted
## Player career in the Premier Raid League.
##
## Each season: the player auction (you are one of the lots), a single round-robin league of
## 12 franchises (11 matches), then a top-four playoff. Matches earn skill points to spend in
## training. Your value at the next auction follows your form.

const PURSE_MIN := 140.0   # lakhs left after retentions
const PURSE_MAX := 230.0
const CATEGORIES := {"A": 30.0, "B": 20.0, "C": 13.0, "D": 9.0}

var profile := {}
var player := {}
var season := 1
var team := ""
var price := 0.0
var skill_points := 0
var phase := "auction"     # auction, season, playoffs, over
var fixtures: Array = []   # league and playoff fixtures for this season
var season_stats := {"matches": 0, "raid": 0, "tackle": 0}
var totals := {"matches": 0, "raid": 0, "tackle": 0, "titles": 0}
var history: Array = []
var seed_value := 0


static func create(p: Dictionary) -> Career:
	var c := Career.new()
	c.profile = p
	c.seed_value = randi()
	var rng := RandomNumberGenerator.new()
	rng.seed = c.seed_value
	var pl := DB.make_player(rng, String(p.role), 58, String(p.name))
	pl.id = "CAREER"
	pl.number = int(p.get("number", 10))
	pl.skin = int(p.skin)
	pl.hair = int(p.hair)
	pl.height = float(p.get("height", 1.80))
	match int(p.get("build", 1)):
		0:
			pl.build = 0.93
			pl.attrs.speed = clampi(pl.attrs.speed + 4, 30, 99)
			pl.attrs.agility = clampi(pl.attrs.agility + 3, 30, 99)
			pl.attrs.strength = clampi(pl.attrs.strength - 4, 30, 99)
		2:
			pl.build = 1.12
			pl.attrs.strength = clampi(pl.attrs.strength + 6, 30, 99)
			pl.attrs.speed = clampi(pl.attrs.speed - 3, 30, 99)
		_:
			pl.build = 1.02
	c.player = pl
	return c


static func from_dict(d: Dictionary) -> Career:
	var c := Career.new()
	c.profile = d.get("profile", {})
	c.player = d.get("player", {})
	for k in DB.ATTRS:
		c.player.attrs[k] = int(c.player.attrs[k])
	for k in ["skin", "hair", "number"]:
		c.player[k] = int(c.player[k])
	c.season = int(d.get("season", 1))
	c.team = d.get("team", "")
	c.price = float(d.get("price", 0.0))
	c.skill_points = int(d.get("skill_points", 0))
	c.phase = d.get("phase", "auction")
	c.fixtures = d.get("fixtures", [])
	for f in c.fixtures:
		f.round = int(f.round)
		f.score = [int(f.score[0]), int(f.score[1])]
	c.season_stats = d.get("season_stats", c.season_stats)
	c.totals = d.get("totals", c.totals)
	for dict in [c.season_stats, c.totals]:
		for k in dict.keys():
			dict[k] = int(dict[k])
	c.history = d.get("history", [])
	c.seed_value = int(d.get("seed", 0))
	return c


func to_dict() -> Dictionary:
	return {
		"profile": profile, "player": player, "season": season, "team": team, "price": price,
		"skill_points": skill_points, "phase": phase, "fixtures": fixtures,
		"season_stats": season_stats, "totals": totals, "history": history, "seed": seed_value,
	}


func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value + season * 100003 + salt * 7919
	return r


func overall() -> int:
	return DB.overall(player)


func category() -> String:
	var o := overall()
	if o >= 80:
		return "A"
	if o >= 72:
		return "B"
	if o >= 64:
		return "C"
	return "D"


# ---------------------------------------------------------------- auction

## Lots for this season's auction, with the user's lot somewhere in the middle.
func build_auction() -> Dictionary:
	var rng := _rng(1)
	var lots := []
	var used := {}
	for i in 23:
		var role: String = ["raider", "defender", "defender", "allrounder", "raider"][i % 5]
		var level := rng.randi_range(58, 86)
		var pname := _lot_name(rng, used)
		var p := DB.make_player(rng, role, level, pname)
		p.id = "LOT_%d_%d" % [season, i]
		lots.append(_lot(p))
	var mine := _lot(player)
	mine.mine = true
	lots.sort_custom(func(a, b): return a.base > b.base)
	lots.insert(clampi(9 + rng.randi_range(-2, 3), 0, lots.size()), mine)
	var purses := {}
	for id in DB.league_ids:
		purses[id] = snappedf(rng.randf_range(PURSE_MIN, PURSE_MAX), 0.5)
	return {"lots": lots, "purses": purses, "index": 0}


func _lot(p: Dictionary) -> Dictionary:
	var o := DB.overall(p)
	var cat := "D"
	if o >= 80:
		cat = "A"
	elif o >= 72:
		cat = "B"
	elif o >= 64:
		cat = "C"
	return {"player": p, "base": CATEGORIES[cat], "cat": cat, "ovr": o, "mine": false, "sold_to": "", "price": 0.0}


func _lot_name(rng: RandomNumberGenerator, used: Dictionary) -> String:
	var regions: Array = DB.FIRST_NAMES.keys()
	for k in 30:
		var r: String = regions[rng.randi() % regions.size()]
		var n := "%s %s" % [DB.FIRST_NAMES[r][rng.randi() % DB.FIRST_NAMES[r].size()], DB.LAST_NAMES[r][rng.randi() % DB.LAST_NAMES[r].size()]]
		if not used.has(n) and not DB.BLOCKED_NAMES.has(n):
			used[n] = true
			return n
	return "Player %d" % rng.randi_range(100, 999)


## What a franchise would pay for a player, in lakhs.
static func valuation(lot: Dictionary, team_id: String, salt: int) -> float:
	var r := RandomNumberGenerator.new()
	r.seed = hash(team_id) + salt
	var o: float = lot.ovr
	var v := pow(maxf(0.0, o - 50.0), 1.6) * 0.95
	v *= r.randf_range(0.7, 1.35)
	return clampf(v, 0.0, 260.0)


## One bidding step. Returns false when bidding has finished.
static func bid_step(lot: Dictionary, purses: Dictionary, state: Dictionary, rng: RandomNumberGenerator) -> bool:
	var price: float = state.price
	var leader: String = state.leader
	var next_price := price if leader == "" else price + (5.0 if price < 100.0 else 10.0)
	var keen := []
	for id in purses.keys():
		if id == leader:
			continue
		if float(purses[id]) >= next_price and valuation(lot, id, state.salt) >= next_price:
			keen.append(id)
	if keen.is_empty():
		return false
	state.leader = keen[rng.randi() % keen.size()]
	state.price = next_price
	return true


func finish_auction(auction: Dictionary) -> void:
	for lot in auction.lots:
		if lot.mine:
			team = lot.sold_to
			price = lot.price
			player.team = team
	if team == "":
		var r := _rng(5)
		team = DB.league_ids[r.randi() % DB.league_ids.size()]
		price = CATEGORIES[category()]
		player.team = team
	_start_season()


# ---------------------------------------------------------------- season

func _start_season() -> void:
	phase = "season"
	season_stats = {"matches": 0, "raid": 0, "tackle": 0}
	fixtures = []
	# Circle method round robin.
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


func next_user_fixture():
	for f in fixtures:
		if not f.played and (f.home == team or f.away == team):
			return f
	return null


func record_user_result(result: Dictionary) -> void:
	var f = next_user_fixture()
	if f == null:
		return
	var s: Array = result.score
	if f.home == team:
		f.score = [int(s[0]), int(s[1])]
	else:
		f.score = [int(s[1]), int(s[0])]
	f.played = true
	var cs: Dictionary = result.get("career_stats", {"raid": 0, "tackle": 0})
	_add_stats(int(cs.raid), int(cs.tackle), int(result.get("winner", -1)) == 0)
	_after_user_match(f)


## Simulated user match: the team result and your own line come from ratings.
func simulate_user_match() -> void:
	var f = next_user_fixture()
	if f == null:
		return
	var rng := _rng(fixtures.find(f) + 11)
	f.score = DB.simulate(_rating(f.home), _rating(f.away), rng, f.stage != "league")
	f.played = true
	var mine: int = f.score[0] if f.home == team else f.score[1]
	var theirs: int = f.score[1] if f.home == team else f.score[0]
	var share := 0.22 if player.role == "raider" else (0.15 if player.role == "allrounder" else 0.06)
	var raid := int(round(mine * share * rng.randf_range(0.6, 1.4) * overall() / 70.0))
	var tackle := int(round(rng.randf_range(0.0, 4.0) * (1.0 if player.role != "raider" else 0.3)))
	_add_stats(raid, tackle, mine > theirs)
	_after_user_match(f)


func _add_stats(raid: int, tackle: int, won: bool) -> void:
	season_stats.matches += 1
	season_stats.raid += raid
	season_stats.tackle += tackle
	totals.matches += 1
	totals.raid += raid
	totals.tackle += tackle
	skill_points += 2 + int((raid + tackle) / 3) + (1 if won else 0)


func _after_user_match(f: Dictionary) -> void:
	for o in fixtures:
		if not o.played and o.stage == f.stage and int(o.round) == int(f.round):
			_sim(o)
	_advance()


func _rating(id: String) -> int:
	var r := DB.team_rating(DB.team(id).squad)
	if id == team:
		r = int(round(r * 0.85 + overall() * 0.15))
	return r


func _sim(f: Dictionary) -> void:
	var rng := _rng(fixtures.find(f) + 31)
	f.score = DB.simulate(_rating(f.home), _rating(f.away), rng, f.stage != "league")
	f.played = true


func _advance() -> void:
	var stage := "league" if phase == "season" else ""
	if phase == "playoffs":
		stage = "semi" if fixtures.any(func(x): return x.stage == "semi" and not x.played) else "final"
	for f in fixtures:
		if f.stage == stage and not f.played:
			return
	if phase == "season":
		var table := standings()
		phase = "playoffs"
		fixtures.append({"stage": "semi", "round": 12, "home": table[0].id, "away": table[3].id, "played": false, "score": [0, 0]})
		fixtures.append({"stage": "semi", "round": 12, "home": table[1].id, "away": table[2].id, "played": false, "score": [0, 0]})
		if next_user_fixture() == null:
			_sim_stage("semi")
			_advance()
		return
	if phase == "playoffs":
		var has_final := fixtures.any(func(x): return x.stage == "final")
		if not has_final:
			var w := []
			for f in fixtures:
				if f.stage == "semi":
					w.append(f.home if f.score[0] > f.score[1] else f.away)
			fixtures.append({"stage": "final", "round": 13, "home": w[0], "away": w[1], "played": false, "score": [0, 0]})
			if next_user_fixture() == null:
				_sim_stage("final")
				_advance()
			return
		_end_season()


func _sim_stage(st: String) -> void:
	for f in fixtures:
		if f.stage == st and not f.played:
			_sim(f)


func champion() -> String:
	for f in fixtures:
		if f.stage == "final" and f.played:
			return f.home if f.score[0] > f.score[1] else f.away
	return ""


func _end_season() -> void:
	phase = "over"
	var champ := champion()
	if champ == team:
		totals.titles += 1
	var pos := 0
	var table := standings()
	for i in table.size():
		if table[i].id == team:
			pos = i + 1
	history.append({"season": season, "team": team, "price": price, "raid": season_stats.raid, "tackle": season_stats.tackle, "finish": pos, "champion": champ == team})


func next_season() -> void:
	season += 1
	team = ""
	price = 0.0
	player.team = ""
	fixtures = []
	phase = "auction"


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


func train(attr: String) -> bool:
	if skill_points <= 0 or int(player.attrs[attr]) >= 99:
		return false
	player.attrs[attr] = int(player.attrs[attr]) + 1
	skill_points -= 1
	return true


func match_config(f: Dictionary) -> Dictionary:
	var opp: String = f.away if f.home == team else f.home
	var arenas := ["dome", "stadium", "dome", "monsoon", "village", "beach"]
	return {
		"home": team, "away": opp, "arena": arenas[(int(f.round) + hash(opp)) % arenas.size()] if f.stage == "league" else "stadium",
		"mode": "career", "control": "career", "career_player": player,
		"knockout": f.stage != "league",
	}
