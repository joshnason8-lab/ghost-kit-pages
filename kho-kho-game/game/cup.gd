class_name Cup
extends RefCounted
## A championship: sixteen sides in four groups of four, each playing the others once (2 points a win, 1 a tie, then
## points difference), the top two of each group to the quarter-finals (A1 v B2, B1 v A2, C1 v D2, D1 v C2), then the
## semi-finals and the final. Knockout matches are played off if tied (extra innings, then minimum chases).
## "world": the nations, to the fast rules, as the 2025 world championship was played. "national": the states, to the
## classic rules, as the national championships are. The names are plain: no real competition is named.

const KINDS := ["world", "national", "league"]
const LEAGUE_ROUNDS := 14   # eight sides, home and away

var kind := "world"
var women := false
var user := ""
var teams: Array = []
var groups: Array = []        # four arrays of four ids
var results := {}             # "a|b" -> [score a, score b]
var round := 0                # 0-2 in the groups
var stage := "groups"         # groups, qf, sf, f, done, out
var ties: Array = []          # this knockout round's pairs [a, b]
var ko_results: Array = []    # [stage, a, b, score a, score b, winner]
var champion := ""
var sched: Array = []         # the league's rounds of pairs
var seed := 1


static func create(p_kind: String, p_user: String, p_women := false) -> Cup:
	var c := Cup.new()
	c.kind = p_kind
	c.women = p_women
	c.user = p_user
	c.seed = randi()
	if p_kind == "league":
		c.teams = DB.club_ids()
		c.groups = [c.teams.duplicate()]
		c.sched = league_schedule(c.teams)
		return c
	var pool: Array = DB.nation_ids() if p_kind == "world" else DB.state_ids()
	pool.sort_custom(func(a, b): return DB.team_rating(a, p_women) > DB.team_rating(b, p_women))
	var pick: Array = pool.slice(0, 16)
	if not (p_user in pick):
		pick[15] = p_user
		pick.sort_custom(func(a, b): return DB.team_rating(a, p_women) > DB.team_rating(b, p_women))
	c.teams = pick
	# Seeded in a snake: the best four head the groups.
	c.groups = [[], [], [], []]
	for i in 16:
		var row := i / 4
		var g := i % 4 if row % 2 == 0 else 3 - i % 4
		c.groups[g].append(pick[i])
	return c


## Every side plays every other at home and away: the circle method, the second half the first with home and away
## turned round.
static func league_schedule(ids: Array) -> Array:
	var n := ids.size()
	var arr := ids.duplicate()
	var first: Array = []
	for r in n - 1:
		var rnd := []
		for i in n / 2:
			var a = arr[i]
			var b = arr[n - 1 - i]
			rnd.append([a, b] if (r + i) % 2 == 0 else [b, a])
		first.append(rnd)
		arr.insert(1, arr.pop_back())
	var out: Array = first.duplicate(true)
	for rnd in first:
		var back := []
		for pr in rnd:
			back.append([pr[1], pr[0]])
		out.append(back)
	return out


func league() -> bool:
	return kind == "league"


func fmt() -> int:
	return KhoRules.CLASSIC if kind == "national" else KhoRules.FAST


func title() -> String:
	return TranslationServer.translate({"world": "CUP_WORLD", "national": "CUP_NATIONAL", "league": "CUP_LEAGUE"}.get(kind, "CUP_WORLD"))


func stage_name() -> String:
	match stage:
		"groups":
			if league():
				return TranslationServer.translate("CUP_STAGE_LEAGUE") + " · %d/%d" % [round + 1, LEAGUE_ROUNDS]
			return TranslationServer.translate("CUP_STAGE_GROUPS") + " · %d/3" % (round + 1)
		"qf":
			return TranslationServer.translate("CUP_STAGE_QF")
		"sf":
			return TranslationServer.translate("CUP_STAGE_SF")
		"f":
			return TranslationServer.translate("CUP_STAGE_F")
	return ""


## The group round's pairs: round 0 1v2 3v4, round 1 1v3 2v4, round 2 1v4 2v3.
static func group_pairs(g: Array, r: int) -> Array:
	var pr: Array = [[[0, 1], [2, 3]], [[0, 2], [1, 3]], [[0, 3], [1, 2]]][r]
	return [[g[pr[0][0]], g[pr[0][1]]], [g[pr[1][0]], g[pr[1][1]]]]


func fixtures() -> Array:
	if stage == "groups":
		if league():
			return sched[round] if round < sched.size() else []
		var out := []
		for g in groups:
			out.append_array(group_pairs(g, round))
		return out
	return ties


## Your side's match this round, [a, b], or [] (out, or done).
func user_fixture() -> Array:
	for p in fixtures():
		if user in p and not _played(p):
			return p
	return []


func _played(p: Array) -> bool:
	if stage == "groups":
		return results.has("%s|%s" % [p[0], p[1]])
	for r in ko_results:
		if r[0] == stage and r[1] == p[0] and r[2] == p[1]:
			return true
	return false


func knockout() -> bool:
	return stage != "groups"


## Record a result (yours or the AI's).
func record(a: String, b: String, sa: int, sb: int, w: int) -> void:
	if stage == "groups":
		results["%s|%s" % [a, b]] = [sa, sb]
	else:
		ko_results.append([stage, a, b, sa, sb, a if w == 0 else b])


func record_user_result(result: Dictionary) -> void:
	var p := user_fixture()
	if p.is_empty():
		return
	var cfg: Dictionary = result.config
	var home := String(cfg.home)
	var sc: Array = result.score
	var w := int(result.winner)
	if home == p[0]:
		record(p[0], p[1], int(sc[0]), int(sc[1]), w)
	else:
		record(p[0], p[1], int(sc[1]), int(sc[0]), (1 - w) if w >= 0 else -1)
	sim_round(false)


## Plays every match of the round left (including yours, if sim_user).
func sim_round(sim_user := false) -> void:
	var i := 0
	for p in fixtures():
		i += 1
		if _played(p):
			continue
		if user in p and not sim_user:
			continue
		var r := Sim.play(p[0], p[1], fmt(), KhoRules.real_turn(fmt()), women, knockout(), seed + round * 100 + i + hash(stage))
		record(p[0], p[1], int(r.score[0]), int(r.score[1]), int(r.winner))
	_finish_round()


func _finish_round() -> void:
	for p in fixtures():
		if not _played(p):
			return
	if stage == "groups" and league():
		round += 1
		if round >= LEAGUE_ROUNDS:
			var t := group_table(0)
			ties = [[t[0].id, t[3].id], [t[1].id, t[2].id]]
			stage = "sf"
		return
	if stage == "groups":
		round += 1
		if round >= 3:
			var q := []
			for g in 4:
				q.append(group_table(g))
			ties = [[q[0][0].id, q[1][1].id], [q[1][0].id, q[0][1].id], [q[2][0].id, q[3][1].id], [q[3][0].id, q[2][1].id]]
			stage = "qf"
	else:
		var winners := []
		for p in ties:
			for r in ko_results:
				if r[0] == stage and r[1] == p[0] and r[2] == p[1]:
					winners.append(r[5])
		if stage == "f":
			champion = winners[0]
			stage = "done"
			if champion == user:
				Records.add_title(kind)
			return
		ties = []
		for k in range(0, winners.size(), 2):
			ties.append([winners[k], winners[k + 1]])
		stage = "sf" if stage == "qf" else "f"
	if stage != "done" and stage != "groups" and user_fixture().is_empty() and not _user_alive():
		pass


func _user_alive() -> bool:
	for p in ties:
		if user in p:
			return true
	return stage == "groups"


## Your side is out (but the championship plays on to its champion).
func user_out() -> bool:
	return stage != "groups" and not _user_alive()


## A group's table: [{id, p, w, d, l, pf, pa, pts}], best first.
func group_table(g: int) -> Array:
	var rows := {}
	for id in groups[g]:
		rows[id] = {"id": id, "p": 0, "w": 0, "d": 0, "l": 0, "pf": 0, "pa": 0, "pts": 0}
	for key in results:
		var ab: PackedStringArray = String(key).split("|")
		if not rows.has(ab[0]) or not rows.has(ab[1]):
			continue
		var sc: Array = results[key]
		for k in 2:
			var me: Dictionary = rows[ab[k]]
			var mine := int(sc[k])
			var theirs := int(sc[1 - k])
			me.p += 1
			me.pf += mine
			me.pa += theirs
			me.pts += Sim.league_points(mine, theirs) if league() else Sim.table_points(mine, theirs)
			if mine > theirs:
				me.w += 1
			elif mine == theirs:
				me.d += 1
			else:
				me.l += 1
	var out: Array = rows.values()
	out.sort_custom(func(a, b):
		if a.pts != b.pts:
			return a.pts > b.pts
		if a.pf - a.pa != b.pf - b.pa:
			return a.pf - a.pa > b.pf - b.pa
		return a.pf > b.pf)
	return out


func user_group() -> int:
	for g in groups.size():
		if user in groups[g]:
			return g
	return 0


func to_dict() -> Dictionary:
	return {"sched": sched, "kind": kind, "women": women, "user": user, "teams": teams, "groups": groups, "results": results, "round": round,
		"stage": stage, "ties": ties, "ko": ko_results, "champion": champion, "seed": seed}


static func from_dict(d: Dictionary) -> Cup:
	var c := Cup.new()
	c.kind = String(d.get("kind", "world"))
	c.women = bool(d.get("women", false))
	c.user = String(d.get("user", ""))
	c.teams = d.get("teams", [])
	c.groups = d.get("groups", [[], [], [], []])
	c.results = d.get("results", {})
	c.round = int(d.get("round", 0))
	c.stage = String(d.get("stage", "groups"))
	c.ties = d.get("ties", [])
	c.ko_results = d.get("ko", [])
	c.champion = String(d.get("champion", ""))
	c.seed = int(d.get("seed", 1))
	c.sched = d.get("sched", [])
	return c
