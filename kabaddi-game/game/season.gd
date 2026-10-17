class_name Season
extends RefCounted
## League Season: you own a Premier Raid League franchise.
##
## Each year: your retentions, the player auction (you hold the paddle), 11 league rounds, then playoffs in the
## pro format: the top six go through, 3rd v 6th and 4th v 5th in eliminators, 1st and 2nd wait in the
## semi-finals, then the final. Win it and you lift the trophy.
##
## Around the matches: you pick your seven for each one; players have form, tire and pick up knocks; the board sets
## a goal that moves next year's budget; derbies, weekly awards, records and a hall of fame; players age, the young
## improve and the old retire; and the news follows all of it (see News).

## Derbies: neighbours and old rivals, one each. The key is the two team ids in order.
const DERBIES := {
	"MUM|PUN": "DERBY_MAHARASHTRA", "CHD|DEL": "DERBY_NORTH", "BLR|CHE": "DERBY_SOUTH",
	"KOL|PAT": "DERBY_EAST", "AHM|JAI": "DERBY_WEST", "HYD|LKO": "DERBY_NAWABI",
}
const PURSE := 500.0
const RETAIN_MAX := 6
const RETAIN_MARKUP := 1.8      # a retained player costs his category's base price times this
## The board's goal, by where the squad ranks after the auction: the best two must reach the final, the next three
## the semi-finals, the next three the playoffs, the rest the top eight.
const GOALS := ["GOAL_FINAL", "GOAL_SEMI", "GOAL_PLAYOFFS", "GOAL_TOP8"]
const GOAL_REWARD := 20.0       # lakhs on next year's purse for meeting the goal (twice that for the title)
const GOAL_PENALTY := 20.0      # ... and off it for missing
const NEWS_PER_ROUND := 5       # stories a round makes, besides your team's own

var team := ""
var year := 1
var phase := "auction"          # auction, league, playoffs, done
var squads := {}                # team id -> Array of player dictionaries
var purses := {}                # lakhs left after the auction
var fixtures: Array = []        # {stage, round, home, away, played, score, tag, top}
var champion := ""
var history: Array = []         # {year, finish, champion, mvp, raider, defender, goal, goal_met}
var player_stats := {}          # pid -> {name, team, raid, tackle, matches}, this season
var last_stats := {}            # ... last season's (shown at the auction)
var awards := {}                # Awards.leaders() once the season is done
var seed_value := 0

# The news.
var news: Array = []
var news_n := [0]               # running story number (an array so News.add can count it on)
var news_seen := 0              # the newest story the player has seen as breaking news

# The squad through the season.
var form := {}                  # pid -> his last five matches' points
var fitness := {}               # pid -> 0.5 .. 1 (players start a match with this much energy)
var injuries := {}              # pid -> matches still to miss
var lineup: Array = []          # your seven for the next match (pids); empty: the best seven
var goal := {}                  # {key: GOALS[i], rank} for this season
var purse_bonus := 0.0          # on next year's purse, from the board
var week := {}                  # the last league round's awards: {round, raider, defender, team}
var streaks := {}               # team -> wins in a row (or, below zero, losses)
var meetings := {}              # "A|B" -> the last match between them: {year, stage, round, home, away, score}
var records := {}               # the record book: key -> {v, name, team, team2, year}
var career_pts := {}            # pid -> {name, team, raid, tackle, seasons}: all-time points, for the hall of fame

# The auction.
var retained: Array = []        # your retentions (pids), chosen before the auction
var retain_done := false
var shortlist := {}             # pid -> the most you will pay (lakhs)
var auto_bid := true            # your paddle goes up by itself for your shortlist, up to your price
var grades := {}                # team -> {grade, rank, note, spent, rating}, after the auction

# Bookkeeping.
var closed: Array = []          # rounds whose news is written ("league:3", "semi:13")
var leader := ""                # top of the table when the last round closed
var clinched := {}              # teams sure of the playoffs
var out := {}                   # teams who cannot reach them
var _pending: Array = []        # stories from the round being played, written when it closes
var _round_pts := {}            # pid -> {name, team, raid, tackle} this round, for the weekly awards
var _free_agents: Array = []


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
			if p.has("age"):
				p.age = int(p.age)
	s.purses = d.get("purses", {})
	s.fixtures = d.get("fixtures", [])
	for f in s.fixtures:
		f.round = int(f.round)
		f.score = [int(f.score[0]), int(f.score[1])]
	s.champion = d.get("champion", "")
	s.history = d.get("history", [])
	s.seed_value = int(d.get("seed", 0))
	s.player_stats = d.get("player_stats", {})
	s.last_stats = d.get("last_stats", {})
	s.awards = d.get("awards", {})
	if s.squads.is_empty():
		for id in DB.league_ids:
			s.squads[id] = DB.team(id).squad.duplicate(true)
	s.news = d.get("news", [])
	s.news_n = [int(d.get("news_n", News.last_id(s.news)))]
	s.news_seen = int(d.get("news_seen", s.news_n[0]))
	s.form = d.get("form", {})
	for pid in s.form:
		var ints := []
		for x in s.form[pid]:
			ints.append(int(x))
		s.form[pid] = ints
	s.fitness = d.get("fitness", {})
	s.injuries = d.get("injuries", {})
	for pid in s.injuries:
		s.injuries[pid] = int(s.injuries[pid])
	s.lineup = d.get("lineup", [])
	s.goal = d.get("goal", {})
	s.purse_bonus = float(d.get("purse_bonus", 0.0))
	s.week = d.get("week", {})
	s.streaks = d.get("streaks", {})
	for id in s.streaks:
		s.streaks[id] = int(s.streaks[id])
	s.meetings = d.get("meetings", {})
	s.records = d.get("records", {})
	for k in s.records:
		s.records[k].v = int(s.records[k].v)
	s.career_pts = d.get("career_pts", {})
	s.retained = d.get("retained", [])
	s.retain_done = bool(d.get("retain_done", false))
	s.shortlist = d.get("shortlist", {})
	s.auto_bid = bool(d.get("auto_bid", true))
	s.grades = d.get("grades", {})
	s.leader = d.get("leader", "")
	s.clinched = d.get("clinched", {})
	s.out = d.get("out", {})
	if d.has("closed"):
		s.closed = d.closed
	else:
		# A save from before the news: rounds already played are old news.
		for f in s.fixtures:
			var key := "%s:%d" % [f.stage, int(f.round)]
			if not s.closed.has(key) and s._round_done(String(f.stage), int(f.round)):
				s.closed.append(key)
	if s.phase != "auction" and s.goal.is_empty() and not s.fixtures.is_empty():
		s._set_goal(false)
	return s


func to_dict() -> Dictionary:
	return {"team": team, "year": year, "phase": phase, "squads": squads, "purses": purses,
		"fixtures": fixtures, "champion": champion, "history": history, "seed": seed_value,
		"player_stats": player_stats, "last_stats": last_stats, "awards": awards,
		"news": news, "news_n": int(news_n[0]), "news_seen": news_seen,
		"form": form, "fitness": fitness, "injuries": injuries, "lineup": lineup, "goal": goal,
		"purse_bonus": purse_bonus, "week": week, "streaks": streaks, "meetings": meetings, "records": records,
		"career_pts": career_pts, "retained": retained, "retain_done": retain_done, "shortlist": shortlist, "auto_bid": auto_bid,
		"grades": grades, "closed": closed, "leader": leader, "clinched": clinched, "out": out}


func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value + year * 100003 + salt * 7919
	return r


# ---------------------------------------------------------------- players

func find_player(pid: String) -> Dictionary:
	for id in squads:
		for p in squads[id]:
			if String(p.id) == pid:
				return p
	return {}


func fit(p: Dictionary) -> float:
	return float(fitness.get(String(p.id), 1.0))


## Matches he will still miss (0: fit to play).
func injured(p: Dictionary) -> int:
	return int(injuries.get(String(p.id), 0))


## 1 in form, 0 steady, -1 out of form.
func form_of(p: Dictionary) -> int:
	return Scout.form(form.get(String(p.id), []), String(p.role))


## What he brings to a match today: his rating, a little less when tired, a little more or less with his form.
func effective(p: Dictionary) -> float:
	return DB.overall(p) * (0.92 + 0.08 * fit(p)) + 1.5 * form_of(p)


## The seven who play a team's next match: yours as you picked them (anyone injured since replaced), others the
## best fit to play: two raiders, an all-rounder and four defenders, by what they bring today.
func seven(id: String) -> Array:
	var sq: Array = squads.get(id, [])
	if id == team and lineup.size() == 7:
		var picked := []
		for pid in lineup:
			for p in sq:
				if String(p.id) == String(pid) and injured(p) == 0:
					picked.append(p)
		if picked.size() < 7:
			for p in best_seven(id):
				if picked.size() < 7 and not picked.has(p):
					picked.append(p)
		return picked
	return best_seven(id)


func best_seven(id: String) -> Array:
	var sq: Array = squads.get(id, [])
	var by_role := {"raider": [], "allrounder": [], "defender": []}
	var hurt := []
	for p in sq:
		if injured(p) > 0:
			hurt.append(p)
		else:
			by_role[String(p.role)].append(p)
	for k in by_role:
		by_role[k].sort_custom(func(x, y): return effective(x) > effective(y))
	var out7 := []
	out7.append_array(by_role.raider.slice(0, 2))
	out7.append_array(by_role.allrounder.slice(0, 1))
	out7.append_array(by_role.defender.slice(0, 4))
	var rest := []
	for k in by_role:
		for p in by_role[k]:
			if not out7.has(p):
				rest.append(p)
	rest.sort_custom(func(x, y): return effective(x) > effective(y))
	rest.append_array(hurt)   # only if there is no one else
	while out7.size() < 7 and not rest.is_empty():
		out7.append(rest.pop_front())
	return out7


func _power(players: Array) -> float:
	if players.is_empty():
		return 50.0
	var s := 0.0
	for p in players:
		s += effective(p)
	return s / players.size()


## A team's strength for its next match, from the seven who will play it.
func rating(id: String) -> int:
	if not squads.has(id):
		return DB.team_rating(DB.team(id).squad)
	return int(round(_power(seven(id))))


func derby_of(a: String, b: String) -> String:
	var key := "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]
	return String(DERBIES.get(key, ""))


func _meeting_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


# ---------------------------------------------------------------- auction

## What keeping him costs: his category's base price times the markup, so stars cost more.
static func retain_cost(p: Dictionary) -> float:
	return float(AuctionEngine.CATEGORIES[AuctionEngine.category_for(DB.overall(p))]) * RETAIN_MARKUP


## Your purse for the auction with these players kept.
func purse_with(kept: Array) -> float:
	var cost := 0.0
	for p in kept:
		cost += retain_cost(p)
	return snappedf(PURSE + purse_bonus - cost, 0.5)


## Your best six, the retentions picked for you if you do not choose.
func default_retained() -> Array:
	var sq: Array = squads.get(team, []).duplicate()
	sq.sort_custom(func(a, b): return DB.overall(a) > DB.overall(b))
	var ids := []
	for p in sq.slice(0, RETAIN_MAX):
		ids.append(String(p.id))
	return ids


## Each franchise keeps up to six (yours as you chose); the rest of the league, plus young talent, goes under the
## hammer.
func make_auction() -> AuctionEngine:
	var eng := AuctionEngine.new()
	eng.rng.seed = seed_value + year
	eng.user_team = team
	var rng := _rng(1)
	var released := []
	for id in DB.league_ids:
		var sq: Array = squads[id].duplicate()
		sq.sort_custom(func(a, b): return DB.overall(a) > DB.overall(b))
		var kept: Array = sq.slice(0, RETAIN_MAX)
		if id == team and retain_done:
			kept = sq.filter(func(p): return retained.has(String(p.id)))
		var purse := snappedf(PURSE - _cost(kept), 0.5)
		if id == team:
			purse = purse_with(kept)
		eng.teams[id] = {"purse": purse, "squad": kept, "fbm": 1}
		for p in sq:
			if not kept.has(p):
				released.append([p, id])
	released.sort_custom(func(a, b): return DB.overall(a[0]) > DB.overall(b[0]))
	for pair in released.slice(0, 26):
		eng.add_lot(pair[0], pair[1])
	# New Young Players from the junior circuit: 18 to 20, and some of them will be stars.
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
		p.age = rng.randi_range(18, 20)
		p.pot = snappedf(rng.randf_range(0.35, 1.0), 0.01)
		eng.add_lot(p, "", true)
	eng.sort_lots()
	# Released players who don't make the auction list stay available as free agents.
	_free_agents = []
	for pair in released.slice(26):
		_free_agents.append(pair[0])
	return eng


func _cost(kept: Array) -> float:
	var c := 0.0
	for p in kept:
		c += retain_cost(p)
	return c


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
			eng.teams[id].purse = maxf(0.0, float(eng.teams[id].purse) - 6.0)
		for i in sq.size():
			sq[i].team = id
			if String(sq[i].get("id", "")) == "" or not String(sq[i].id).begins_with(id):
				var old := String(sq[i].get("id", ""))
				sq[i].id = "%s_y%d_%d" % [id, year, i]
				_carry(old, String(sq[i].id))
		squads[id] = sq
		purses[id] = float(eng.teams[id].purse)
	lineup = []
	_grade_auction(eng)
	_start_league()


## A player who changed teams takes his form and his all-time points with him under his new id.
func _carry(old: String, now: String) -> void:
	if old == "":
		return
	if last_stats.has(old):
		last_stats[now] = last_stats[old]
	if career_pts.has(old):
		career_pts[now] = career_pts[old]
		career_pts.erase(old)


## Marks for every franchise's auction: the seven it can put out now, how well it spent, and the gaps it left.
func _grade_auction(eng: AuctionEngine) -> void:
	var rows := []
	for id in DB.league_ids:
		var fair := 0.0
		var spent := 0.0
		var buys := 0
		for l in eng.lots:
			if l.status == "sold" and String(l.sold_to) == id:
				fair += AuctionEngine.worth(int(l.ovr), String(l.cat))
				spent += float(l.price)
				buys += 1
		var value := fair / maxf(spent, 1.0) if buys > 0 else 1.0
		var strength := float(DB.team_rating(squads[id]))
		var holes := 0
		var n := Scout.needs(squads[id])
		for s in Scout.SLOTS:
			holes += int(n[s])
		var score := (strength - 70.0) * 4.0 + clampf(value - 1.0, -0.6, 1.0) * 18.0 - holes * 3.0
		rows.append({"id": id, "score": score, "strength": strength, "value": value, "holes": holes, "spent": spent})
	rows.sort_custom(func(a, b): return float(a.score) > float(b.score))
	var by_strength := rows.duplicate()
	by_strength.sort_custom(func(a, b): return float(a.strength) > float(b.strength))
	var strength_rank := {}
	for i in by_strength.size():
		strength_rank[by_strength[i].id] = i
	var letters := ["A+", "A", "A", "B+", "B+", "B", "B", "C+", "C+", "C", "C", "D"]
	grades = {}
	for i in rows.size():
		var r: Dictionary = rows[i]
		var note := "GRADE_NOTE_SOLID"
		if int(strength_rank[r.id]) == 0:
			note = "GRADE_NOTE_STRONG"
		elif int(r.holes) >= 3:
			note = "GRADE_NOTE_HOLES"
		elif float(r.value) >= 1.25:
			note = "GRADE_NOTE_VALUE"
		elif float(r.value) <= 0.8:
			note = "GRADE_NOTE_OVERPAID"
		elif int(strength_rank[r.id]) < 4:
			note = "GRADE_NOTE_STRONG"
		grades[r.id] = {"grade": letters[mini(i, letters.size() - 1)], "rank": i + 1, "note": note,
			"spent": float(r.spent), "rating": int(r.strength)}
	# The auction's stories.
	var when := {"key": "AUCTION"}
	var top := {}
	var steal := {}
	for l in eng.lots:
		if l.status != "sold":
			continue
		if top.is_empty() or float(l.price) > float(top.price):
			top = l
		var v := AuctionEngine.worth(int(l.ovr), String(l.cat)) / maxf(float(l.price), 1.0)
		if int(l.ovr) >= 70 and (steal.is_empty() or v > float(steal.v)):
			steal = {"lot": l, "v": v}
	if not top.is_empty():
		_story(2, "AUC_RECORD", {"name": String(top.player.name), "team": String(top.sold_to), "price": float(top.price)}, [top.sold_to], when)
	if not steal.is_empty() and float(steal.v) >= 1.3:
		var sl: Dictionary = steal.lot
		_story(1, "AUC_STEAL", {"name": String(sl.player.name), "team": String(sl.sold_to), "price": float(sl.price)}, [sl.sold_to], when)
	var spender: Dictionary = rows[0]
	for r in rows:
		if float(r.spent) > float(spender.spent):
			spender = r
	_story(1, "AUC_BIG_SPENDER", {"team": String(spender.id), "price": float(spender.spent)}, [spender.id], when)
	_story(1, "AUC_GRADE_LOW", {"team": String(rows[-1].id), "grade": String(grades[rows[-1].id].grade)}, [rows[-1].id], when)
	_story(2 if String(rows[0].id) == team else 1, "AUC_GRADE_TOP", {"team": String(rows[0].id), "grade": String(grades[rows[0].id].grade)}, [rows[0].id], when)


# ---------------------------------------------------------------- league

func _start_league() -> void:
	phase = "league"
	champion = ""
	fixtures = []
	closed = []
	leader = ""
	clinched = {}
	out = {}
	streaks = {}
	week = {}
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
	_set_goal(true)


## The board's goal for the season, from where the squad ranks.
func _set_goal(tell: bool) -> void:
	var ids: Array = DB.league_ids.duplicate()
	ids.sort_custom(func(x, y): return rating(x) > rating(y))
	var rank := ids.find(team)
	var i := 0 if rank < 2 else (1 if rank < 5 else (2 if rank < 8 else 3))
	goal = {"key": GOALS[i], "rank": rank + 1}
	if tell:
		_story(2, "GOAL_SET", {"team": team, "goal": GOALS[i]}, [team], {"key": "PRESEASON"})


func _reached(stage: String) -> bool:
	for f in fixtures:
		if String(f.stage) == stage and (f.home == team or f.away == team):
			return true
	return false


func finish_position() -> int:
	var t := standings()
	for i in t.size():
		if t[i].id == team:
			return i + 1
	return 0


func goal_met() -> bool:
	match String(goal.get("key", "")):
		"GOAL_FINAL":
			return _reached("final")
		"GOAL_SEMI":
			return _reached("semi")
		"GOAL_PLAYOFFS":
			return finish_position() <= 6
	return finish_position() <= 8


## How the goal looks now: "GOAL_STATUS_ON" (on track), "GOAL_STATUS_RISK", or once the season is over
## "GOAL_STATUS_MET" / "GOAL_STATUS_MISSED".
func goal_status() -> String:
	if goal.is_empty():
		return ""
	if phase == "done":
		return "GOAL_STATUS_MET" if goal_met() else "GOAL_STATUS_MISSED"
	var pos := finish_position()
	if phase == "playoffs":
		if goal_met():
			return "GOAL_STATUS_MET"
		return "GOAL_STATUS_ON" if next_user_fixture() != null else "GOAL_STATUS_MISSED"
	var need := 2 if String(goal.key) in ["GOAL_FINAL", "GOAL_SEMI"] else (6 if String(goal.key) == "GOAL_PLAYOFFS" else 8)
	return "GOAL_STATUS_ON" if pos <= need else "GOAL_STATUS_RISK"


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
	var opp: String = f.away if f.home == team else f.home
	# The seven who played, as the match had them, before anything moves.
	var sevens := {team: seven(team), opp: seven(opp)}
	f.score = [int(s[0]), int(s[1])] if f.home == team else [int(s[1]), int(s[0])]
	f.played = true
	var ps: Dictionary = result.get("player_stats", {})
	Awards.add_match(player_stats, ps)
	var pts := {}
	var played := {team: [], opp: []}
	for pid in ps:
		var r: Dictionary = ps[pid]
		var tid := String(r.get("team", ""))
		if played.has(tid):
			played[tid].append(String(pid))
			pts[String(pid)] = [int(r.raid), int(r.tackle)]
	for tid in played:
		if played[tid].is_empty():
			for p in sevens[tid]:
				played[tid].append(String(p.id))
	_post_match(f, pts, played, _rng(fixtures.find(f) + 977))
	_after(f)


func simulate_user_match() -> void:
	var f = next_user_fixture()
	if f == null:
		return
	_sim(f)
	_after(f)


func _sim(f: Dictionary) -> void:
	var rng := _rng(fixtures.find(f) + 31)
	var hs := seven(f.home)
	var as_ := seven(f.away)
	f.score = DB.simulate(int(round(_power(hs))), int(round(_power(as_))), rng, f.stage != "league")
	f.played = true
	var pts := Awards.sim_team(player_stats, squads[f.home], f.home, int(f.score[0]), rng, hs)
	pts.merge(Awards.sim_team(player_stats, squads[f.away], f.away, int(f.score[1]), rng, as_))
	var played := {f.home: [], f.away: []}
	for p in hs:
		played[f.home].append(String(p.id))
	for p in as_:
		played[f.away].append(String(p.id))
	_post_match(f, pts, played, rng)


func _after(f: Dictionary) -> void:
	for o in fixtures:
		if not o.played and o.stage == f.stage and int(o.round) == int(f.round):
			_sim(o)
	_advance()


func _winner(f: Dictionary) -> String:
	return f.home if f.score[0] > f.score[1] else f.away


func _loser(f: Dictionary) -> String:
	return f.away if f.score[0] > f.score[1] else f.home


func _round_done(stage: String, rnd: int) -> bool:
	var any := false
	for f in fixtures:
		if String(f.stage) == stage and int(f.round) == rnd:
			any = true
			if not f.played:
				return false
	return any


## Moves the season on whenever a stage is complete, simulating anything the user isn't in.
func _advance() -> void:
	var guard := 0
	while guard < 12:
		guard += 1
		_close_rounds()
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
			_story(2, "PLAYOFF_SET", {"team": t[0].id, "team2": t[1].id}, [t[0].id, t[1].id], {"key": "PLAYOFFS"})
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
			_season_end()
			return


## The season is over: awards, the record book, the hall of fame and the board's verdict.
func _season_end() -> void:
	var pos := finish_position()
	awards = Awards.leaders(player_stats)
	var met := goal_met()
	history.append({"year": year, "finish": pos, "champion": champion, "mvp": awards.get("mvp", {}),
		"raider": awards.get("raider", {}), "defender": awards.get("defender", {}),
		"goal": String(goal.get("key", "")), "goal_met": met})
	var when := {"key": "FINAL"}
	for pid in player_stats:
		var r: Dictionary = player_stats[pid]
		var c: Dictionary = career_pts.get(pid, {"name": r.name, "team": r.team, "raid": 0, "tackle": 0, "seasons": 0})
		c.name = String(r.name)
		c.team = String(r.team)
		c.raid = int(c.raid) + int(r.raid)
		c.tackle = int(c.tackle) + int(r.tackle)
		c.seasons = int(c.seasons) + 1
		career_pts[pid] = c
	var raider: Dictionary = awards.get("raider", {})
	if not raider.is_empty():
		_record("raid_season", int(raider.raid), String(raider.name), String(raider.team), "", "RECORD_RAID_SEASON", when)
	var defender: Dictionary = awards.get("defender", {})
	if not defender.is_empty():
		_record("tackle_season", int(defender.tackle), String(defender.name), String(defender.team), "", "RECORD_TACKLE_SEASON", when)
	var mvp: Dictionary = awards.get("mvp", {})
	if not mvp.is_empty():
		var mine := String(mvp.team) == team
		_cand(3 if mine else 2, "ARJUNA", {"name": String(mvp.name), "team": String(mvp.team), "n": int(mvp.raid) + int(mvp.tackle)}, [mvp.team], 0)
	if not goal.is_empty():
		var bonus := (GOAL_REWARD * 2.0 if champion == team else GOAL_REWARD) if met else -GOAL_PENALTY
		purse_bonus = bonus
		_cand(3, "GOAL_MET" if met else "GOAL_MISSED", {"team": team, "goal": String(goal.key), "price": absf(bonus)}, [team], 0)
	last_stats = player_stats.duplicate(true)
	_flush(when)


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
	var out_rows := rows.values()
	out_rows.sort_custom(func(x, y): return x.pts > y.pts or (x.pts == y.pts and (x.pd > y.pd or (x.pd == y.pd and x["for"] > y["for"]))))
	return out_rows


func match_config(f: Dictionary) -> Dictionary:
	var opp: String = f.away if f.home == team else f.home
	var arenas := ["dome", "stadium", "dome", "monsoon", "village", "beach", "dome"]
	var arena: String = arenas[(int(f.round) + absi(hash(opp))) % arenas.size()] if f.stage == "league" else "stadium"
	var mine := seven(team)
	var theirs := seven(opp)
	var fit_map := {}
	for p in mine + theirs:
		fit_map[String(p.id)] = fit(p)
	return {"home": team, "away": opp, "arena": arena, "mode": "season", "control": "all",
		"length": int(Game.settings.length), "difficulty": int(Game.settings.difficulty),
		"knockout": f.stage != "league", "home_squad": squads[team], "away_squad": squads[opp],
		"home_seven": mine, "away_seven": theirs, "fitness": fit_map, "derby": derby_of(team, opp),
		"walkout": f.stage == "final", "stage": String(f.stage)}


# ---------------------------------------------------------------- a match's aftermath

## Everything a played match changes: form, fitness and knocks for both squads, the meeting, the run of results,
## the record book, and the stories it makes. pts: pid -> [raid, tackle]; played: team -> the pids who played.
func _post_match(f: Dictionary, pts: Dictionary, played: Dictionary, rng: RandomNumberGenerator) -> void:
	var h: String = f.home
	var a: String = f.away
	var hs := int(f.score[0])
	var as_ := int(f.score[1])
	var r_h := rating(h)
	var r_a := rating(a)
	var when := _when(String(f.stage), int(f.round))
	var mine := h == team or a == team
	# The players.
	var best := {}
	for tid in [h, a]:
		var on: Array = played.get(tid, [])
		for p in squads.get(tid, []):
			var pid := String(p.id)
			if on.has(pid):
				var r: Array = pts.get(pid, [0, 0])
				var fp: Array = form.get(pid, [])
				fp.append(int(r[0]) + int(r[1]))
				form[pid] = fp.slice(-5)
				var stam := float(p.attrs.stamina)
				var tired := fit(p) < 0.72
				fitness[pid] = clampf(fit(p) - 0.09 * clampf(1.4 - stam / 100.0, 0.5, 1.0) + 0.03, 0.5, 1.0)
				var rp: Dictionary = _round_pts.get(pid, {"name": String(p.name), "team": tid, "raid": 0, "tackle": 0})
				rp.raid = int(rp.raid) + int(r[0])
				rp.tackle = int(rp.tackle) + int(r[1])
				_round_pts[pid] = rp
				if best.is_empty() or int(r[0]) + int(r[1]) > int(best.pts):
					best = {"pid": pid, "name": String(p.name), "team": tid, "pts": int(r[0]) + int(r[1])}
				if int(r[0]) >= 10:
					var big := int(r[0]) >= 15
					_cand(2 if big else 1, "SUPER10", {"name": String(p.name), "team": tid, "n": int(r[0]), "team2": a if tid == h else h}, [tid], int(r[0]))
				if int(r[1]) >= 5:
					_cand(1, "HIGH5", {"name": String(p.name), "team": tid, "n": int(r[1]), "team2": a if tid == h else h}, [tid], int(r[1]))
				_record("raid_match", int(r[0]), String(p.name), tid, a if tid == h else h, "RECORD_RAID", when)
				_record("tackle_match", int(r[1]), String(p.name), tid, a if tid == h else h, "RECORD_TACKLE", when)
				# A knock: more likely when he is tired.
				if rng.randf() < 0.02 + (0.03 if tired else 0.0):
					var n := rng.randi_range(1, 3)
					injuries[pid] = n
					var star := DB.overall(p) >= 76
					if tid == team or star:
						_cand(3 if tid == team and star else (2 if tid == team else 1), "INJURY" if n > 1 else "KNOCK",
							{"name": String(p.name), "team": tid, "n": n}, [tid], DB.overall(p) - 60)
			else:
				fitness[pid] = minf(1.0, fit(p) + 0.15)
				if injuries.has(pid):
					injuries[pid] = int(injuries[pid]) - 1
					if int(injuries[pid]) <= 0:
						injuries.erase(pid)
						if tid == team:
							_cand(1, "RETURN", {"name": String(p.name), "team": tid}, [tid], 0)
	if not best.is_empty():
		f["top"] = best
	meetings[_meeting_key(h, a)] = {"year": year, "stage": String(f.stage), "round": int(f.round), "home": h, "away": a, "score": [hs, as_]}
	# The result.
	var sc := "%d–%d" % [maxi(hs, as_), mini(hs, as_)]
	var margin := absi(hs - as_)
	var derby := derby_of(h, a)
	if hs == as_:
		_cand(1, "TIE", {"team": h, "team2": a, "score": sc}, [h, a], 0)
		streaks[h] = 0
		streaks[a] = 0
	else:
		var w := h if hs > as_ else a
		var l := a if w == h else h
		var rw := r_h if w == h else r_a
		var rl := r_a if w == h else r_h
		var args := {"team": w, "team2": l, "score": sc}
		match String(f.stage):
			"eliminator":
				_cand(2, "ELIM_WIN", args, [w, l], margin)
			"semi":
				_cand(3 if mine else 2, "SEMI_WIN", args, [w, l], margin)
			"final":
				_cand(3, "CHAMPIONS", args, [w, l], 1000)   # the front page, whatever else happened
			_:
				if rl - rw >= 4:
					_cand(3 if mine else 2, "UPSET", args, [w, l], rl - rw)
				elif derby != "":
					args["derby"] = derby
					_cand(2, "DERBY", args, [w, l], margin)
				elif margin >= 15:
					_cand(2 if mine else 1, "THRASH", args, [w, l], margin)
				elif margin <= 2:
					_cand(1, "THRILLER", args, [w, l], 3 - margin)
				elif mine:
					_cand(1, "WIN", args, [w, l], margin)
		# Runs of results.
		var ended := int(streaks.get(l, 0))
		if ended >= 5:
			_cand(2, "STREAK_END", {"team": w, "team2": l, "n": ended}, [w, l], ended)
		streaks[w] = maxi(0, int(streaks.get(w, 0))) + 1
		streaks[l] = mini(0, int(streaks.get(l, 0))) - 1
		for tid in [w, l]:
			var n := absi(int(streaks[tid]))
			if n >= 4 and n % 2 == 0:
				_cand(3 if tid == team else 1, "STREAK_W" if tid == w else "STREAK_L", {"team": tid, "n": n}, [tid], n)
		_record("score", maxi(hs, as_), "", w, l, "RECORD_SCORE", when)
		_record("margin", margin, "", w, l, "RECORD_MARGIN", when)


func _when(stage: String, rnd: int) -> Dictionary:
	match stage:
		"eliminator":
			return {"key": "ELIMINATOR"}
		"semi":
			return {"key": "SEMI_FINAL"}
		"final":
			return {"key": "FINAL"}
	return {"key": "MATCHDAY", "n": rnd}


## The record book. A record falling is breaking news, once the season has had a few rounds to set the marks.
func _record(key: String, v: int, pname: String, tid: String, other: String, story: String, when: Dictionary) -> void:
	if v <= 0:
		return
	var old: Dictionary = records.get(key, {})
	if not old.is_empty() and v <= int(old.v):
		return
	records[key] = {"v": v, "name": pname, "team": tid, "team2": other, "year": year}
	var settled := year > 1 or int(when.get("n", 99)) >= 4
	if not old.is_empty() and settled:
		var a := {"team": tid, "n": v}
		if pname != "":
			a["name"] = pname
		if other != "":
			a["team2"] = other
		_cand(3, story, a, [tid], 200 + v)


func _close_rounds() -> void:
	var seen := {}
	for f in fixtures:
		var key := "%s:%d" % [f.stage, int(f.round)]
		if seen.has(key) or closed.has(key):
			continue
		seen[key] = true
		if _round_done(String(f.stage), int(f.round)):
			closed.append(key)
			_close_round(String(f.stage), int(f.round))


## A round is over: the weekly awards, the table's stories, and the round's news.
func _close_round(stage: String, rnd: int) -> void:
	var when := _when(stage, rnd)
	if stage == "league":
		var best_r := {}
		var best_d := {}
		for pid in _round_pts:
			var r: Dictionary = _round_pts[pid]
			if best_r.is_empty() or int(r.raid) > int(best_r.raid):
				best_r = r.duplicate()
				best_r["pid"] = pid
			if best_d.is_empty() or int(r.tackle) > int(best_d.tackle):
				best_d = r.duplicate()
				best_d["pid"] = pid
		var best_t := {}
		for f in fixtures:
			if f.stage == "league" and int(f.round) == rnd and f.played:
				var m := absi(int(f.score[0]) - int(f.score[1]))
				if best_t.is_empty() or m > int(best_t.margin):
					best_t = {"team": _winner(f), "team2": _loser(f), "margin": m,
						"score": "%d–%d" % [maxi(int(f.score[0]), int(f.score[1])), mini(int(f.score[0]), int(f.score[1]))]}
		week = {"round": rnd, "raider": best_r, "defender": best_d, "team": best_t}
		if not best_r.is_empty():
			_cand(1, "WEEK_RAIDER", {"name": String(best_r.name), "team": String(best_r.team), "n": int(best_r.raid)}, [best_r.team], int(best_r.raid))
		if not best_d.is_empty() and int(best_d.tackle) >= 4:
			_cand(1, "WEEK_DEFENDER", {"name": String(best_d.name), "team": String(best_d.team), "n": int(best_d.tackle)}, [best_d.team], int(best_d.tackle))
		var t := standings()
		if rnd >= 2 and String(t[0].id) != leader:
			_cand(3 if String(t[0].id) == team else 2, "TOP", {"team": String(t[0].id), "n": int(t[0].pts)}, [t[0].id], 50)
		leader = String(t[0].id)
		if rnd >= 5:
			_playoff_math(t)
		if rnd >= 9 and rnd <= 10 and int(t[5].pts) - int(t[6].pts) <= 3:
			_cand(1, "RACE", {"team": String(t[5].id), "team2": String(t[6].id)}, [t[5].id, t[6].id], 20)
	_round_pts = {}
	if stage != "final":
		_flush(when)   # the final's stories go out with the season's end (_season_end)


## Who is sure of the playoffs now, and who can no longer get there.
func _playoff_math(t: Array) -> void:
	var left := {}
	for f in fixtures:
		if f.stage == "league" and not f.played:
			left[f.home] = int(left.get(f.home, 0)) + 1
			left[f.away] = int(left.get(f.away, 0)) + 1
	for row in t:
		var id := String(row.id)
		var threats := 0
		for other in t:
			if other.id != id and int(other.pts) + 5 * int(left.get(other.id, 0)) >= int(row.pts):
				threats += 1
		if threats <= 5 and not clinched.has(id):
			clinched[id] = true
			_cand(3 if id == team else 1, "CLINCH", {"team": id}, [id], 30)
		if int(row.pts) + 5 * int(left.get(id, 0)) < int(t[5].pts) and not out.has(id):
			out[id] = true
			_cand(3 if id == team else 1, "OUT", {"team": id}, [id], 30)


## A candidate story for the round being played; the round's best are written when it closes.
func _cand(p: int, k: String, a: Dictionary, teams: Array, mag: float) -> void:
	_pending.append({"s": p * 100 + (60 if teams.has(team) else 0) + mag, "k": k, "a": a, "p": p, "t": teams})


## Writes the round's stories: the best few, and all of your team's; the most important goes in last, newest.
func _flush(when: Dictionary) -> void:
	_pending.sort_custom(func(x, y): return float(x.s) > float(y.s))
	var keep := []
	for c in _pending:
		if keep.size() < NEWS_PER_ROUND or (c.t as Array).has(team) or int(c.p) >= 3:
			keep.append(c)
	keep.reverse()
	for c in keep:
		News.add(news, news_n, String(c.k), c.a, int(c.p), when, c.t)
	_pending = []


## A story told straight away.
func _story(p: int, k: String, a: Dictionary, teams: Array, when: Dictionary) -> void:
	News.add(news, news_n, k, a, p, when, teams)


# ---------------------------------------------------------------- what the screens show

## A team's last results this season, oldest first: "W", "L" or "T".
func team_form(id: String, n := 5) -> Array:
	var res := []
	for f in fixtures:
		if f.played and (f.home == id or f.away == id):
			var mine_s := int(f.score[0]) if f.home == id else int(f.score[1])
			var their_s := int(f.score[1]) if f.home == id else int(f.score[0])
			res.append("W" if mine_s > their_s else ("T" if mine_s == their_s else "L"))
	return res.slice(-n)


## The last time two teams met (this season or before), or {}.
func last_meeting(a: String, b: String) -> Dictionary:
	return meetings.get(_meeting_key(a, b), {})


## The match's key battle: their danger raider against your best tackler, and yours against theirs.
func key_battles(opp: String) -> Array:
	var mine := seven(team)
	var theirs := seven(opp)
	return [[_best_raider(theirs), _best_tackler(mine)], [_best_raider(mine), _best_tackler(theirs)]]


func _best_raider(players: Array) -> Dictionary:
	var best := {}
	for p in players:
		if String(p.role) != "defender" and (best.is_empty() or effective(p) > effective(best)):
			best = p
	return best


func _best_tackler(players: Array) -> Dictionary:
	var best := {}
	for p in players:
		if String(p.role) != "raider" and (best.is_empty() or int(p.attrs.tackle) > int(best.attrs.tackle)):
			best = p
	return best


## All-time leading scorers (raid and tackle points together), for the hall of fame.
func all_time(n := 10) -> Array:
	var rows := []
	for pid in career_pts:
		var c: Dictionary = career_pts[pid]
		rows.append({"pid": pid, "name": String(c.name), "team": String(c.team), "raid": int(c.raid), "tackle": int(c.tackle), "seasons": int(c.seasons)})
	rows.sort_custom(func(x, y): return int(x.raid) + int(x.tackle) > int(y.raid) + int(y.tackle))
	return rows.slice(0, n)


# ---------------------------------------------------------------- a new season

## A year on: players a year older (the young improve, the old slow and some retire), and a fresh auction.
func next_year() -> void:
	var rng := _rng(9)
	var rise := {}
	var gone := {}
	for id in DB.league_ids:
		var keep := []
		for p in squads.get(id, []):
			if Scout.retires(p, rng):
				if gone.is_empty() or DB.overall(p) > DB.overall(gone.p):
					gone = {"p": p, "team": id}
				continue
			var young := Scout.age(p) <= 23
			var d := Scout.develop(p, rng)
			if young and (rise.is_empty() or d > int(rise.d)):
				rise = {"p": p, "team": id, "d": d}
			keep.append(p)
		squads[id] = keep
	year += 1
	phase = "auction"
	fixtures = []
	champion = ""
	player_stats = {}
	awards = {}
	form = {}
	fitness = {}
	injuries = {}
	lineup = []
	retained = []
	retain_done = false
	shortlist = {}
	grades = {}
	week = {}
	streaks = {}
	closed = []
	clinched = {}
	out = {}
	leader = ""
	goal = {}
	var when := {"key": "PRESEASON"}
	_story(2, "NEW_SEASON", {"n": year}, [], when)
	if not gone.is_empty() and DB.overall(gone.p) >= 72:
		_story(2, "RETIRE", {"name": String(gone.p.name), "team": String(gone.team), "n": Scout.age(gone.p)}, [gone.team], when)
	if not rise.is_empty() and int(rise.d) >= 3:
		_story(2, "BREAKTHROUGH", {"name": String(rise.p.name), "team": String(rise.team), "n": int(rise.d)}, [rise.team], when)
