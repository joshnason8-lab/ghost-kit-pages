class_name Cup
extends RefCounted
## Nations Cup: eight countries, two groups of four, semi-finals and a final.
## Points table uses Pro-style scoring: win 5, tie 3, loss by 7 or fewer 1, other loss 0.
##
## You pick your twelve from your country's pool of eighteen, and a captain. Every player's points count towards
## the tournament's awards (Golden Raider, Best Defender, Player of the Tournament); before your last group match
## you are told what you need; the news follows it all; and a side rated 70 or below that wins it all takes the
## Underdog Trophy.

const FIELD := ["IND", "IRN", "KOR", "PAK", "BAN", "KEN", "JPN", "ARG"]
const SQUAD_SIZE := 12
const MIN_RAIDERS := 3      # in a squad of twelve, at least
const MIN_DEFENDERS := 4
const UNDERDOG := 75        # rated this or below (the rating shown on the country's card): an underdog

var user := "IND"
var teams: Array = []
var groups := {"A": [], "B": []}
var fixtures: Array = []   # {stage, group, round, home, away, played, score, top}
var stage := "group"       # group, semi, final, done
var champion := ""
var seed_value := 0
var squad: Array = []      # your twelve
var captain := ""          # his pid
var picked := false        # the squad is chosen: the tournament can start
var player_stats := {}     # pid -> {name, team, raid, tackle, matches}
var awards := {}           # Awards.leaders() at the end
var news: Array = []
var news_n := [0]
var news_seen := 0
var closed: Array = []     # rounds whose news is written
var _pending: Array = []


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
	c.squad = DB.team(country).squad.duplicate(true)
	c.captain = String(c.squad[0].id) if not c.squad.is_empty() else ""
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
	c.squad = d.get("squad", [])
	for p in c.squad:
		for k in DB.ATTRS:
			p.attrs[k] = int(p.attrs[k])
		for k in ["skin", "hair", "number"]:
			p[k] = int(p[k])
		if p.has("age"):
			p.age = int(p.age)
	# A save from before squads were picked: the country's own twelve, and the tournament under way.
	c.picked = bool(d.get("picked", true))
	if c.squad.is_empty():
		c.squad = DB.team(c.user).squad.duplicate(true)
	c.captain = String(d.get("captain", c.squad[0].id if not c.squad.is_empty() else ""))
	c.player_stats = d.get("player_stats", {})
	c.awards = d.get("awards", {})
	c.news = d.get("news", [])
	c.news_n = [int(d.get("news_n", News.last_id(c.news)))]
	c.news_seen = int(d.get("news_seen", c.news_n[0]))
	if d.has("closed"):
		c.closed = d.closed
	else:
		for f in c.fixtures:
			var key := "%s:%d" % [f.stage, int(f.round)]
			if not c.closed.has(key) and c._round_done(String(f.stage), int(f.round)):
				c.closed.append(key)
	return c


func to_dict() -> Dictionary:
	return {"user": user, "teams": teams, "groups": groups, "fixtures": fixtures, "stage": stage, "champion": champion,
		"seed": seed_value, "squad": squad, "captain": captain, "picked": picked, "player_stats": player_stats,
		"awards": awards, "news": news, "news_n": int(news_n[0]), "news_seen": news_seen, "closed": closed}


func _rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value + salt * 7919
	return r


## An underdog by the rating the country picker shows (its squad's), so the badge, the note's threshold and the
## Underdog Trophy agree: Kenya, Sri Lanka, Japan, Nepal, Argentina, Thailand and Poland (67-74).
static func is_underdog(id: String) -> bool:
	return DB.team_rating(DB.team(id).squad) <= UNDERDOG


# ---------------------------------------------------------------- the squad

## The country's eighteen to pick from.
func pool() -> Array:
	return DB.national_pool(user)


## Whether twelve players make a squad: twelve, with enough raiders and defenders.
static func squad_ok(players: Array) -> bool:
	if players.size() != SQUAD_SIZE:
		return false
	var raiders := 0
	var defenders := 0
	for p in players:
		if String(p.role) == "raider":
			raiders += 1
		elif String(p.role) == "defender":
			defenders += 1
	return raiders >= MIN_RAIDERS and defenders >= MIN_DEFENDERS


## The best twelve from the pool: the four best raiders, two all-rounders and six defenders.
func best_squad() -> Array:
	var by_role := {"raider": [], "allrounder": [], "defender": []}
	for p in pool():
		by_role[String(p.role)].append(p)
	for k in by_role:
		by_role[k].sort_custom(func(x, y): return DB.overall(x) > DB.overall(y))
	var out := []
	out.append_array(by_role.raider.slice(0, 4))
	out.append_array(by_role.allrounder.slice(0, 2))
	out.append_array(by_role.defender.slice(0, 6))
	return out


## The squad is chosen: twelve from the pool and a captain from among them. The tournament starts.
func confirm_squad(players: Array, cap: String) -> void:
	squad = []
	for p in players:
		squad.append(p.duplicate(true))
	captain = cap
	picked = true
	var cp := captain_player()
	if not cp.is_empty():
		_story(2, "CUP_CAPTAIN", {"name": String(cp.name), "team": user}, [user], {"key": "GROUP_STAGE"})


func captain_player() -> Dictionary:
	for p in squad:
		if String(p.id) == captain:
			return p
	return {}


func squad_of(id: String) -> Array:
	return squad if id == user and not squad.is_empty() else DB.team(id).squad


## A side's strength: its best seven, and a point for your captain's lead.
func _rating(id: String) -> int:
	return DB.team_rating(squad_of(id)) + (1 if id == user and captain != "" else 0)


# ---------------------------------------------------------------- matches

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
	var ps: Dictionary = result.get("player_stats", {})
	Awards.add_match(player_stats, ps)
	var pts := {}
	for pid in ps:
		pts[String(pid)] = [int(ps[pid].raid), int(ps[pid].tackle)]
	_post_match(f, pts, ps)
	_sim_round(f.stage, int(f.round))
	_advance()


## Simulate your own match (and the rest of its round).
func simulate_user_match() -> void:
	var f = next_user_fixture()
	if f == null:
		return
	_sim(f)
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
	var pts := Awards.sim_team(player_stats, squad_of(f.home), f.home, int(f.score[0]), r)
	pts.merge(Awards.sim_team(player_stats, squad_of(f.away), f.away, int(f.score[1]), r))
	_post_match(f, pts, {})


## A match's stories: the result (a giant-killing above all), Super 10s and High 5s.
func _post_match(f: Dictionary, pts: Dictionary, names: Dictionary) -> void:
	var h: String = f.home
	var a: String = f.away
	var hs := int(f.score[0])
	var as_ := int(f.score[1])
	var best := {}
	for pid in pts:
		var r: Array = pts[pid]
		var info := _who(String(pid), names)
		if info.is_empty():
			continue
		var tid := String(info.team)
		var opp := a if tid == h else h
		if best.is_empty() or int(r[0]) + int(r[1]) > int(best.pts):
			best = {"pid": String(pid), "name": String(info.name), "team": tid, "pts": int(r[0]) + int(r[1])}
		if int(r[0]) >= 10:
			_cand(2 if int(r[0]) >= 15 else 1, "SUPER10", {"name": String(info.name), "team": tid, "n": int(r[0]), "team2": opp}, [tid], int(r[0]))
		if int(r[1]) >= 5:
			_cand(1, "HIGH5", {"name": String(info.name), "team": tid, "n": int(r[1]), "team2": opp}, [tid], int(r[1]))
	if not best.is_empty():
		f["top"] = best
	var sc := "%d–%d" % [maxi(hs, as_), mini(hs, as_)]
	var mine := h == user or a == user
	if hs == as_:
		_cand(1, "TIE", {"team": h, "team2": a, "score": sc}, [h, a], 0)
		return
	var w := h if hs > as_ else a
	var l := a if w == h else h
	var args := {"team": w, "team2": l, "score": sc}
	var gap := int(DB.team(l).base) - int(DB.team(w).base)
	if f.stage == "final":
		_cand(3, "CUP_CHAMPIONS", args, [w, l], 1000)
	elif is_underdog(w) and gap >= 8:
		_cand(3 if mine else 2, "CUP_GIANT", args, [w, l], gap)
	elif gap >= 5:
		_cand(3 if mine else 2, "UPSET", args, [w, l], gap)
	elif absi(hs - as_) >= 15:
		_cand(2 if mine else 1, "THRASH", args, [w, l], absi(hs - as_))
	elif absi(hs - as_) <= 2:
		_cand(1, "THRILLER", args, [w, l], 3 - absi(hs - as_))
	elif mine:
		_cand(1, "WIN", args, [w, l], absi(hs - as_))


## A player's name and team, from the match's own figures or the squads.
func _who(pid: String, names: Dictionary) -> Dictionary:
	if names.has(pid):
		return {"name": String(names[pid].name), "team": String(names[pid].team)}
	for id in teams:
		for p in squad_of(id):
			if String(p.id) == pid:
				return {"name": String(p.name), "team": id}
	return {}


func _round_done(st: String, rnd: int) -> bool:
	var any := false
	for f in fixtures:
		if String(f.stage) == st and int(f.round) == rnd:
			any = true
			if not f.played:
				return false
	return any


func _advance() -> void:
	_close_rounds()
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
			var through := [a[0].id, a[1].id, b[0].id, b[1].id]
			var when := {"key": "GROUP_STAGE"}
			_story(3, "QUAL_THROUGH" if through.has(user) else "QUAL_OUT", {"team": user}, [user], when)
		"semi":
			var winners := []
			for f in fixtures:
				if f.stage == "semi":
					winners.append(f.home if f.score[0] > f.score[1] else f.away)
			fixtures.append({"stage": "final", "group": "", "round": 5, "home": winners[0], "away": winners[1], "played": false, "score": [0, 0]})
			stage = "final"
			var when := {"key": "SEMI_FINAL"}
			_story(2, "CUP_FINAL_SET", {"team": winners[0], "team2": winners[1]}, winners, when)
			if winners.has(user) and is_underdog(user):
				_story(3, "CUP_FAIRYTALE", {"team": user}, [user], when)
		"final":
			for f in fixtures:
				if f.stage == "final":
					champion = f.home if f.score[0] > f.score[1] else f.away
			stage = "done"
			awards = Awards.leaders(player_stats)
			for pair in [["raider", "GOLDEN_RAIDER", "raid"], ["defender", "CUP_BEST_DEF", "tackle"], ["mvp", "CUP_MVP", ""]]:
				var w: Dictionary = awards.get(pair[0], {})
				if w.is_empty():
					continue
				var n := int(w.raid) + int(w.tackle) if pair[2] == "" else int(w[pair[2]])
				_cand(3 if String(w.team) == user else 2, pair[1], {"name": String(w.name), "team": String(w.team), "n": n}, [w.team], 0)
			_flush({"key": "FINAL"})


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


func _close_round(st: String, rnd: int) -> void:
	if st == "final":
		return   # its stories go out with the awards (_advance)
	var when := {"key": "MATCHDAY", "n": rnd} if st == "group" else {"key": "SEMI_FINAL"}
	_flush(when)
	# One group round to go: what you need.
	if st == "group" and rnd == 2:
		var sc := scenario()
		if not sc.is_empty():
			_story(3, String(sc.k), sc.a, [user], {"key": "MATCHDAY", "n": 3})


func _cand(p: int, k: String, a: Dictionary, about: Array, mag: float) -> void:
	_pending.append({"s": p * 100 + (60 if about.has(user) else 0) + mag, "k": k, "a": a, "p": p, "t": about})


func _flush(when: Dictionary) -> void:
	_pending.sort_custom(func(x, y): return float(x.s) > float(y.s))
	var keep := []
	for c in _pending:
		if keep.size() < 4 or (c.t as Array).has(user) or int(c.p) >= 3:
			keep.append(c)
	keep.reverse()
	for c in keep:
		News.add(news, news_n, String(c.k), c.a, int(c.p), when, c.t)
	_pending = []


func _story(p: int, k: String, a: Dictionary, about: Array, when: Dictionary) -> void:
	News.add(news, news_n, k, a, p, when, about)


# ---------------------------------------------------------------- what you need

## Before your last group match: what it takes to reach the semi-finals, as a story {k, a} (and "top": the margin
## that wins the group, if it can be won), worked out by trying every margin in both of the group's last matches.
## {} at any other time.
func scenario() -> Dictionary:
	var f = next_user_fixture()
	if f == null or String(f.stage) != "group":
		return {}
	var g := String(f.group)
	var left := []
	for o in fixtures:
		if o.stage == "group" and String(o.group) == g and not o.played:
			left.append(o)
	if left.size() != 2:
		return {}
	var other: Dictionary = left[0] if left[1] == f else left[1]
	var opp: String = f.away if f.home == user else f.home
	var span := 25
	var n := span * 2 + 1
	var through := {}
	var top := {}
	var helps := {1: 0, -1: 0, 0: 0}   # best margin for you: how often each result elsewhere sees you through
	for m in range(-span, span + 1):
		var q := 0
		var tq := 0
		for o in range(-span, span + 1):
			var pos := _position_if(g, f, m, other, o)
			if pos <= 1:
				q += 1
				if m == span:
					helps[signi(o)] += 1
			if pos == 0:
				tq += 1
		through[m] = q
		top[m] = tq
	var all_in := true
	var none := true
	for m in through:
		if int(through[m]) < n:
			all_in = false
		if int(through[m]) > 0:
			none = false
	if all_in:
		return {"k": "QUAL_THROUGH", "a": {"team": user}}
	if none:
		return {"k": "QUAL_OUT", "a": {"team": user}}
	var safe := 99
	for m in range(span, -span - 1, -1):
		if int(through[m]) == n:
			safe = m
		else:
			break
	var out := {}
	if safe == 99:
		var home_wins := int(helps[1]) >= int(helps[-1])
		out = {"k": "NEED_HELP", "a": {"team": user, "team2": opp,
			"team3": String(other.home) if home_wins else String(other.away), "team4": String(other.away) if home_wins else String(other.home)}}
	elif safe < 0:
		out = {"k": "NEED_LOSS_BY", "a": {"team": user, "team2": opp, "n": -safe}}
	elif safe == 0:
		out = {"k": "NEED_TIE", "a": {"team": user, "team2": opp}}
	elif safe == 1:
		out = {"k": "NEED_WIN", "a": {"team": user, "team2": opp}}
	else:
		out = {"k": "NEED_WIN_BY", "a": {"team": user, "team2": opp, "n": safe}}
	var top_safe := 99
	for m in range(span, -span - 1, -1):
		if int(top[m]) == n:
			top_safe = m
		else:
			break
	if top_safe >= 2 and top_safe <= span:
		out["top"] = {"k": "NEED_TOP_BY", "a": {"team": user, "team2": opp, "n": top_safe}}
	return out


## Where you would finish the group (0 first) if your match ended margin m your way and the other match margin o
## the home side's way.
func _position_if(g: String, f: Dictionary, m: int, other: Dictionary, o: int) -> int:
	var keep_f: Array = f.score
	var keep_o: Array = other.score
	var mine := 30 + maxi(m, 0)
	var theirs := 30 + maxi(-m, 0)
	f.score = [mine, theirs] if f.home == user else [theirs, mine]
	other.score = [30 + maxi(o, 0), 30 + maxi(-o, 0)]
	f.played = true
	other.played = true
	var t := standings(g)
	f.score = keep_f
	other.score = keep_o
	f.played = false
	other.played = false
	for i in t.size():
		if t[i].id == user:
			return i
	return 9


# ---------------------------------------------------------------- tables

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
	if not picked:
		return tr("CUP_SQUAD_PICK")
	match stage:
		"group":
			return tr("GROUP_STAGE")
		"semi":
			return tr("SEMI_FINAL")
		"final":
			return tr("FINAL")
	return tr("KNOCKOUTS")


## The knockout bracket as it stands: the two semi-finals and the final, each {home, away, played, score}, with
## "A1"-style places for sides not known yet.
func bracket() -> Dictionary:
	var semis := []
	var fin := {}
	for f in fixtures:
		if f.stage == "semi":
			semis.append(f)
		elif f.stage == "final":
			fin = f
	if semis.is_empty():
		semis = [{"home": "A1", "away": "B2", "played": false, "score": [0, 0]}, {"home": "B1", "away": "A2", "played": false, "score": [0, 0]}]
	if fin.is_empty():
		fin = {"home": "W1", "away": "W2", "played": false, "score": [0, 0]}
	return {"semis": semis, "final": fin, "champion": champion}
