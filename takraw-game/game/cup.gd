class_name Cup
extends RefCounted
## An international tournament with your country, on the pattern of the real ones (docs/TAKRAW.md): eight nations in
## two groups of four, each playing the others once; the top two of each group into the semi-finals (A1 against B2,
## B1 against A2); both losing semi-finalists take bronze, as at the real world cup; then the final. The names are the
## game's own (the real events' names are theirs); the formats, venues and fields are the real events':
##   world: the World Championship, the strongest nations, in the big dome;
##   royal: the Royal Cup, a yearly invitational played in a shopping mall's atrium, as Thailand's is;
##   asia: the Asian Championship, the Asian nations;
##   sea: the Southeast Asian Championship, the region's nations, as at the SEA Games.
## The event is the regu, or the team event: three regus a tie, the first to win two.

const KINDS := {
	"world": {"name": "CUP_WORLD", "venue": "dome", "field": ["THA", "MAS", "JPN", "VIE", "INA", "MYA", "KOR", "IND", "PHI", "LAO", "SGP", "IRN", "CHN", "USA", "FRA", "GER"]},
	"royal": {"name": "CUP_ROYAL", "venue": "mall", "field": ["THA", "MAS", "VIE", "INA", "JPN", "KOR", "PHI", "LAO", "MYA", "IND", "SGP", "BRU"]},
	"asia": {"name": "CUP_ASIA", "venue": "national", "field": ["THA", "MAS", "JPN", "VIE", "INA", "MYA", "KOR", "IND", "PHI", "LAO", "IRN", "CHN", "SGP", "NEP"]},
	"sea": {"name": "CUP_SEA", "venue": "provincial", "field": ["THA", "MAS", "VIE", "INA", "MYA", "PHI", "LAO", "SGP", "CAM", "BRU"]},
}

var kind := "world"
var user := ""
var women := false
var event := "regu"            # "regu" or "team"
var year := 2027
var groups: Array = []         # [[ids of A], [ids of B]]
var fixtures: Array = []       # [{home, away, played, sets, set_scores, stage, group}]
var stage := "group"           # "group", "semi", "final", "done"
var medals := {}               # "gold", "silver", "bronze" (an array of two) -> ids
var tie := {}                  # a team-event tie in progress: {fixture index, regus: [[a, b]...]}
var news: Array = []


static func create(p_kind: String, country: String, p_women := false, p_event := "regu") -> Cup:
	var c := Cup.new()
	c.kind = p_kind
	c.user = country
	c.women = p_women
	c.event = p_event
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# The field: the strongest eight that enter, with your country in it whatever its rank.
	var field: Array = (KINDS[p_kind].field as Array).duplicate()
	field.sort_custom(func(a, b): return DB.strength(a, p_women) > DB.strength(b, p_women))
	var eight: Array = field.slice(0, 8)
	if not (country in eight):
		eight[7] = country
	# Seeded into two groups: 1 and 2 apart, then the rest drawn.
	eight.sort_custom(func(a, b): return DB.strength(a, p_women) > DB.strength(b, p_women))
	var a := [eight[0]]
	var b := [eight[1]]
	var rest: Array = eight.slice(2)
	rest.shuffle()
	for i in rest.size():
		(a if i % 2 == 0 else b).append(rest[i])
	c.groups = [a, b]
	for g in 2:
		var ids: Array = c.groups[g]
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				c.fixtures.append({"home": ids[i], "away": ids[j], "played": false, "sets": [0, 0], "set_scores": [], "stage": "group", "group": g})
	return c


static func from_dict(d: Dictionary) -> Cup:
	var c := Cup.new()
	for k in ["kind", "user", "women", "event", "year", "groups", "fixtures", "stage", "medals", "tie", "news"]:
		if d.has(k):
			c.set(k, d[k])
	return c


func to_dict() -> Dictionary:
	return {"kind": kind, "user": user, "women": women, "event": event, "year": year, "groups": groups,
		"fixtures": fixtures, "stage": stage, "medals": medals, "tie": tie, "news": news}


func title() -> String:
	var t := TranslationServer.translate(String(KINDS[kind].name))
	return TranslationServer.translate("WOMENS_EVENT").format({"e": t}) if women else t


func venue() -> String:
	return String(KINDS[kind].venue)


func stage_name() -> String:
	match stage:
		"group":
			return TranslationServer.translate("GROUP_STAGE")
		"semi":
			return TranslationServer.translate("SEMI_FINALS")
		"final":
			return TranslationServer.translate("FINAL")
	return TranslationServer.translate("TOURNAMENT_OVER")


## Your next match: {} once you are out or it is over.
func next_fixture() -> Dictionary:
	for f in fixtures:
		if not f.played and (f.home == user or f.away == user) and f.stage == stage:
			return f
	return {}


func record_user_result(result: Dictionary) -> void:
	var f := next_fixture()
	if f.is_empty():
		return
	_apply(f, result)
	_play_rest()
	_advance()


## Plays your match for you, and the rest of the stage.
func sim_next() -> void:
	var f := next_fixture()
	if not f.is_empty():
		_apply(f, Sim.play(f.home, f.away, women, 3, 15))
	_play_rest()
	_advance()


func _play_rest() -> void:
	if stage != "group" or next_fixture().is_empty():
		# The knockouts, or the group stage once yours is done: everything left in the stage.
		for f in fixtures:
			if not f.played and f.stage == stage and f.home != user and f.away != user:
				_apply(f, Sim.play(f.home, f.away, women, 3, 15))
		return
	# The group stage a matchday at a time: every other team up to as many matches as you have played.
	var mine := _played(user)
	var changed := true
	while changed:
		changed = false
		for f in fixtures:
			if f.played or f.stage != "group" or f.home == user or f.away == user:
				continue
			if _played(f.home) < mine and _played(f.away) < mine:
				_apply(f, Sim.play(f.home, f.away, women, 3, 15))
				changed = true


func _played(id: String) -> int:
	var n := 0
	for f in fixtures:
		if f.played and f.stage == "group" and (f.home == id or f.away == id):
			n += 1
	return n


func _apply(f: Dictionary, r: Dictionary) -> void:
	f.played = true
	f.sets = [int(r.sets[0]), int(r.sets[1])]
	f.set_scores = r.get("set_scores", [])


func _winner(f: Dictionary) -> String:
	return f.home if int(f.sets[0]) > int(f.sets[1]) else f.away


func _loser(f: Dictionary) -> String:
	return f.away if int(f.sets[0]) > int(f.sets[1]) else f.home


func _advance() -> void:
	var all_done := true
	for f in fixtures:
		if f.stage == stage and not f.played:
			all_done = false
	if not all_done:
		if next_fixture().is_empty():
			_play_rest()
			_advance()
		return
	match stage:
		"group":
			var a := group_table(0)
			var b := group_table(1)
			fixtures.append({"home": a[0].id, "away": b[1].id, "played": false, "sets": [0, 0], "set_scores": [], "stage": "semi"})
			fixtures.append({"home": b[0].id, "away": a[1].id, "played": false, "sets": [0, 0], "set_scores": [], "stage": "semi"})
			stage = "semi"
		"semi":
			var semis := []
			for f in fixtures:
				if f.stage == "semi":
					semis.append(f)
			medals.bronze = [_loser(semis[0]), _loser(semis[1])]
			fixtures.append({"home": _winner(semis[0]), "away": _winner(semis[1]), "played": false, "sets": [0, 0], "set_scores": [], "stage": "final"})
			stage = "final"
		"final":
			for f in fixtures:
				if f.stage == "final":
					medals.gold = _winner(f)
					medals.silver = _loser(f)
			stage = "done"
			if medals.gold == user:
				Records.add_title("cup_" + kind, year)
			return
	if next_fixture().is_empty():
		_play_rest()
		_advance()


## A group's table: [{id, p, w, l, sd, pd, pts}], best first.
func group_table(g: int) -> Array:
	var rows := {}
	for id in groups[g]:
		rows[id] = {"id": id, "p": 0, "w": 0, "l": 0, "sd": 0, "pd": 0, "pts": 0}
	for f in fixtures:
		if f.stage != "group" or int(f.group) != g or not f.played:
			continue
		var a: Dictionary = rows[f.home]
		var b: Dictionary = rows[f.away]
		var sa: int = f.sets[0]
		var sb: int = f.sets[1]
		a.p += 1
		b.p += 1
		if sa > sb:
			a.w += 1
			b.l += 1
		else:
			b.w += 1
			a.l += 1
		a.sd += sa - sb
		b.sd += sb - sa
		for sc in f.set_scores:
			a.pd += int(sc[0]) - int(sc[1])
			b.pd += int(sc[1]) - int(sc[0])
		a.pts += Sim.table_points(sa, sb)
		b.pts += Sim.table_points(sb, sa)
	var out := rows.values()
	out.sort_custom(func(x, y):
		if x.pts != y.pts:
			return x.pts > y.pts
		if x.w != y.w:
			return x.w > y.w
		if x.sd != y.sd:
			return x.sd > y.sd
		return x.pd > y.pd)
	return out


## Your medal, if you won one: "gold", "silver", "bronze" or "".
func user_medal() -> String:
	if medals.get("gold", "") == user:
		return "gold"
	if medals.get("silver", "") == user:
		return "silver"
	if user in medals.get("bronze", []):
		return "bronze"
	return ""
