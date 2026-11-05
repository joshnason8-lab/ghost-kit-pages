extends Node
## Teams, players and venues (docs/RULES.md, docs/LANGUAGES.md).
##
## The counties are places, so they keep their plain names. Their crests, county-board jerseys, nicknames and the
## championships they play in are not ours: each county plays here in its traditional colours, in a kit design of
## the game's own (no crest, no sponsor), and the competition is the game's own, "the Summer Championship". Players
## are invented: names made from common Irish first names and surnames, checked against a list of well-known hurlers
## so that no real player is named. Squads are made from each team's id, so they are the same in every game without
## a file of players.

## The fifteen positions, numbered as on a team sheet: 1 the goalkeeper; 2-4 the full-back line (right corner,
## full, left corner); 5-7 the half-back line (right wing, centre, left wing); 8-9 midfield; 10-12 the half-forward
## line (right wing, centre, left wing); 13-15 the full-forward line (right corner, full, left corner).
const POS_GK := 0
const POS_FB := 1   # full-back line
const POS_HB := 2   # half-back line
const POS_MF := 3   # midfield
const POS_HF := 4   # half-forward line
const POS_FF := 5   # full-forward line

## Number -> [line, lateral place (-1 right .. +1 left, looking up the pitch at the goal attacked)].
const SHIRTS := {
	1: [POS_GK, 0.0], 2: [POS_FB, -1.0], 3: [POS_FB, 0.0], 4: [POS_FB, 1.0],
	5: [POS_HB, -1.0], 6: [POS_HB, 0.0], 7: [POS_HB, 1.0], 8: [POS_MF, -0.4], 9: [POS_MF, 0.4],
	10: [POS_HF, -1.0], 11: [POS_HF, 0.0], 12: [POS_HF, 1.0], 13: [POS_FF, -1.0], 14: [POS_FF, 0.0], 15: [POS_FF, 1.0],
}

## Each county: [strength 0-100 from the 2025 and 2026 seasons' results, colour 1 (the jersey), colour 2 (trim,
## shorts), kit design, group]. Designs: 0 plain with a collar and cuffs, 1 a hoop across the chest, 2 a sash, 3
## halves (body and sleeves). group: "S" the southern group, "E" the eastern, "" the counties of the lower tiers.
const COUNTIES := {
	"TIP": [92, "1f5aa6", "f2c230", 1, "S"],
	"LIM": [91, "1f8a4c", "ffffff", 0, "S"],
	"COR": [90, "c8202f", "ffffff", 0, "S"],
	"KIL": [90, "141414", "f2b01e", 1, "E"],
	"CLA": [87, "f2b01e", "1f4fa0", 1, "S"],
	"GAL": [86, "7a1631", "ffffff", 0, "E"],
	"DUB": [83, "6cace4", "0b2240", 3, "E"],
	"WAT": [82, "ffffff", "2b6bc4", 1, "S"],
	"WEX": [80, "5a2a82", "f2c230", 3, "E"],
	"OFF": [77, "1f7a3a", "f2c230", 2, "E"],
	"ANT": [74, "f2b01e", "ffffff", 0, ""],
	"LAO": [71, "1f4fa0", "ffffff", 1, ""],
	"CAR": [70, "c8202f", "1f7a3a", 1, ""],
	"WME": [69, "7a1631", "ffffff", 2, ""],
	"KER": [68, "1f7a3a", "f2c230", 1, ""],
	"DOW": [66, "c8202f", "141414", 2, ""],
	"MEA": [64, "1f7a3a", "f2c230", 0, ""],
	"KIE": [64, "ffffff", "141414", 0, ""],
	"DER": [63, "c8202f", "ffffff", 0, ""],
	"LON": [58, "1f7a3a", "ffffff", 2, ""],
}

## The counties' names, in English and in Irish.
const NAMES := {
	"TIP": ["Tipperary", "Tiobraid Árann"], "LIM": ["Limerick", "Luimneach"], "COR": ["Cork", "Corcaigh"],
	"KIL": ["Kilkenny", "Cill Chainnigh"], "CLA": ["Clare", "An Clár"], "GAL": ["Galway", "Gaillimh"],
	"DUB": ["Dublin", "Baile Átha Cliath"], "WAT": ["Waterford", "Port Láirge"], "WEX": ["Wexford", "Loch Garman"],
	"OFF": ["Offaly", "Uíbh Fhailí"], "ANT": ["Antrim", "Aontroim"], "LAO": ["Laois", "Laois"],
	"CAR": ["Carlow", "Ceatharlach"], "WME": ["Westmeath", "An Iarmhí"], "KER": ["Kerry", "Ciarraí"],
	"DOW": ["Down", "An Dún"], "MEA": ["Meath", "An Mhí"], "KIE": ["Kildare", "Cill Dara"],
	"DER": ["Derry", "Doire"], "LON": ["London", "Londain"],
}

## Short names for the scoreboard, as broadcasters print them.
const SHORT := {
	"TIP": ["TIP", "TIO"], "LIM": ["LIM", "LUI"], "COR": ["COR", "COR"], "KIL": ["KIL", "CCH"], "CLA": ["CLA", "CLÁ"],
	"GAL": ["GAL", "GAI"], "DUB": ["DUB", "BÁC"], "WAT": ["WAT", "PL"], "WEX": ["WEX", "LG"], "OFF": ["OFF", "UÍF"],
	"ANT": ["ANT", "AON"], "LAO": ["LAO", "LAO"], "CAR": ["CAR", "CEA"], "WME": ["WMH", "IAR"], "KER": ["KER", "CIA"],
	"DOW": ["DOW", "DÚN"], "MEA": ["MEA", "MHÍ"], "KIE": ["KIL", "CD"], "DER": ["DER", "DOI"], "LON": ["LON", "LDN"],
}

## Venues, all invented: [name key, kind, capacity, time of day]. kind: "parish" a club pitch (a small covered
## stand, a grass bank, a rail round the field, ball-stop nets behind the goals, four floodlight masts), "county" a
## county ground (a big covered stand, an open terrace opposite, terraces at the ends), "stadium" the national
## stadium (stands on three sides, a terrace at one end). time: "day", "dusk", "night" (under the floodlights).
const VENUES := {
	"parish": ["VENUE_PARISH", "parish", 2500, "dusk"],
	"county": ["VENUE_COUNTY", "county", 28000, "day"],
	"stadium": ["VENUE_STADIUM", "stadium", 82000, "day"],
	"night": ["VENUE_NIGHT", "county", 28000, "night"],
}

## Common Irish first names and surnames, each in its English and its Irish form (the Irish surname as a man's).
const FIRST := [
	["Seán", "Seán"], ["Pádraig", "Pádraig"], ["Michael", "Mícheál"], ["John", "Seán"], ["Conor", "Conchúr"],
	["Darragh", "Darach"], ["Cian", "Cian"], ["Eoin", "Eoin"], ["Ciarán", "Ciarán"], ["Dónal", "Dónall"],
	["Brian", "Brian"], ["Kevin", "Caoimhín"], ["Niall", "Niall"], ["Rory", "Ruairí"], ["Shane", "Seán"],
	["Liam", "Liam"], ["Aidan", "Aodhán"], ["Colm", "Colm"], ["Diarmuid", "Diarmaid"], ["Fergal", "Fearghal"],
	["Oisín", "Oisín"], ["Tadhg", "Tadhg"], ["Cathal", "Cathal"], ["Eamon", "Éamonn"], ["Declan", "Deaglán"],
	["Paul", "Pól"], ["Ronan", "Rónán"], ["Killian", "Cillian"], ["Fionn", "Fionn"], ["Jack", "Seán"],
	["Peter", "Peadar"], ["Mark", "Marcas"], ["James", "Séamas"], ["Thomas", "Tomás"], ["David", "Daithí"],
	["Gearóid", "Gearóid"], ["Ruairí", "Ruairí"], ["Enda", "Éanna"], ["Ultan", "Ultán"], ["Barry", "Barra"],
]
const LAST := [
	["Ryan", "Ó Riain"], ["O'Brien", "Ó Briain"], ["Walsh", "Breathnach"], ["Murphy", "Ó Murchú"],
	["Kelly", "Ó Ceallaigh"], ["O'Sullivan", "Ó Súilleabháin"], ["Byrne", "Ó Broin"], ["Dwyer", "Ó Duibhir"],
	["Hayes", "Ó hAodha"], ["Quinlan", "Ó Caoindealbháin"], ["Moloney", "Ó Maoldomhnaigh"], ["Fitzgerald", "Mac Gearailt"],
	["Brennan", "Ó Braonáin"], ["Doyle", "Ó Dúill"], ["Kennedy", "Ó Cinnéide"], ["Gleeson", "Ó Gliasáin"],
	["Lynch", "Ó Loingsigh"], ["Nolan", "Ó Nualláin"], ["Shanahan", "Ó Seanacháin"], ["Kearney", "Ó Cearnaigh"],
	["Maguire", "Mag Uidhir"], ["Duggan", "Ó Dubhagáin"], ["Costello", "Mac Oisdealbhaigh"], ["Fahy", "Ó Fathaigh"],
	["Hogan", "Ó hÓgáin"], ["Carroll", "Ó Cearbhaill"], ["Daly", "Ó Dálaigh"], ["Egan", "Mac Aodhagáin"],
	["Flanagan", "Ó Flannagáin"], ["Grace", "de Grás"], ["Hennessy", "Ó hAonghusa"], ["Lenihan", "Ó Leannacháin"],
	["McGrath", "Mac Craith"], ["Meagher", "Ó Meachair"], ["Nagle", "de Nógla"], ["Phelan", "Ó Faoláin"],
	["Ruane", "Ó Ruadháin"], ["Treacy", "Ó Treasaigh"], ["Cleary", "Ó Cléirigh"], ["Delaney", "Ó Dubhshláine"],
]

## Combinations that would name a well-known hurler: never used.
const NOT_NAMES := ["Pádraig Maher", "Brian Hogan", "Seán Murphy", "Pádraig Walsh", "Michael Walsh", "John McGrath",
	"Noel McGrath", "Conor Cleary", "Darragh Egan", "Kevin Moran", "Brian Cody", "Jack Gleeson", "Seán Finn",
	"Dónal Óg Cusack", "Brian Lohan", "Liam Sheedy", "Cian Lynch", "Shane Dowling", "Eoin Cody", "Tadhg de Búrca",
	"Brian Kennedy", "Seán Kenneally", "Pádraig Hogan", "John Kelly", "Paul Ryan", "Mark Kehoe", "Rory O'Connor",
	"Conor McDonald", "Shane Ryan", "David Burke", "Conor Whelan", "Colm Galvin", "Peter Duggan", "Shane O'Donnell",
	"Tony Kelly", "David Fitzgerald", "Patrick Horgan", "Seán O'Brien", "Darragh Fitzgibbon", "James Barry",
	"Ronan Maher", "John O'Dwyer", "Jason Forde", "Cathal Barrett", "Michael Breen", "Darragh McCarthy", "Eoin Murphy",
	"Paul Murphy", "Adrian Mullen", "Pádraig Walsh", "Liam Blanchfield", "Diarmuid Byrnes", "Kyle Hayes", "Declan Hannon",
	"Aaron Gillane", "Gearóid Hegarty", "Seamus Flanagan", "Peter Casey", "Tom Morrissey", "Barry Nash", "Seán Finn"]

var _squads := {}


func team(id: String) -> Dictionary:
	var c: Array = COUNTIES.get(id, [60, "777777", "ffffff", 0, ""])
	return {"id": id, "strength": int(c[0]), "c1": Color(c[1]), "c2": Color(c[2]), "design": int(c[3]), "group": String(c[4])}


func team_name(id: String) -> String:
	var n: Array = NAMES.get(id, [id, id])
	return String(n[1] if TranslationServer.get_locale().begins_with("ga") else n[0])


func short_name(id: String) -> String:
	var n: Array = SHORT.get(id, [id, id])
	return String(n[1] if TranslationServer.get_locale().begins_with("ga") else n[0])


func counties() -> Array:
	return COUNTIES.keys()


func counties_ranked() -> Array:
	var ids := counties()
	ids.sort_custom(func(a, b): return int(COUNTIES[a][0]) > int(COUNTIES[b][0]))
	return ids


func group_teams(g: String) -> Array:
	var out := []
	for id in counties_ranked():
		if String(COUNTIES[id][4]) == g:
			out.append(id)
	return out


func strength(id: String) -> int:
	return int(COUNTIES.get(id, [60])[0])


## A player's name in the language shown: "Seán Ó Briain" or "Seán O'Brien"; short: "S. Ó Briain".
static func player_name(pd: Dictionary, short := false) -> String:
	var ga := TranslationServer.get_locale().begins_with("ga")
	var f: Array = FIRST[int(pd.first)]
	var l: Array = LAST[int(pd.last)]
	var first := String(f[1] if ga else f[0])
	var last := String(l[1] if ga else l[0])
	if short:
		return "%s. %s" % [first.left(1), last]
	return "%s %s" % [first, last]


static func overall(p: Dictionary) -> float:
	if int(p.line) == POS_GK:
		return (p.keeping * 0.5 + p.striking * 0.25 + p.catching * 0.25)
	return (p.striking + p.catching + p.speed + p.tackling + p.stamina) / 5.0


## A county's panel of 26, made the same way every time from its id: the fifteen who start (the best in each
## position) and eleven substitutes. Each player: {id, num, first, last, line, place, striking, accuracy, catching,
## speed, tackling, stamina, keeping, free (free-taking), height, skin, hair, hair_style}.
func squad(id: String) -> Array:
	if _squads.has(id):
		return _squads[id]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("hurl:" + id)
	var q := float(strength(id))
	var used := {}
	var out := []
	var free_taker := rng.randi_range(10, 15)
	for num in range(1, 27):
		var shirt: Array = SHIRTS.get(num, SHIRTS[[2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 1][(num - 16) % 15]])
		var line := int(shirt[0])
		var bench := num > 15
		var base := q - (6.0 if bench else 0.0)
		var p := {"id": "%s_%d" % [id, num], "team": id, "num": num, "line": line, "place": float(shirt[1])}
		var first := 0
		var last := 0
		for tries in 50:
			first = rng.randi_range(0, FIRST.size() - 1)
			last = rng.randi_range(0, LAST.size() - 1)
			var en := "%s %s" % [FIRST[first][0], LAST[last][0]]
			# Unique on the team sheet as printed ("S. Ó Briain"), in both languages.
			var short_en := "%s|%d" % [String(FIRST[first][0]).left(1), last]
			var short_ga := "%s|%d" % [String(FIRST[first][1]).left(1), last]
			if not used.has(short_en) and not used.has(short_ga) and not (en in NOT_NAMES):
				break
		used["%s|%d" % [String(FIRST[first][0]).left(1), last]] = true
		used["%s|%d" % [String(FIRST[first][1]).left(1), last]] = true
		p.first = first
		p.last = last
		p.striking = _r(rng, base, 4.0 if line >= POS_HF else 0.0)
		p.accuracy = _r(rng, base, 5.0 if line >= POS_HF else -2.0)
		p.catching = _r(rng, base, 4.0 if line in [POS_MF, POS_HB, POS_FB] else 0.0)
		p.speed = _r(rng, base, 3.0 if line in [POS_FF, POS_HF, POS_HB] else -2.0)
		p.tackling = _r(rng, base, 5.0 if line in [POS_FB, POS_HB] else -3.0)
		p.stamina = _r(rng, base, 4.0 if line == POS_MF else 0.0)
		p.keeping = _r(rng, base, 6.0) if line == POS_GK else 20
		p.free = _r(rng, base, 10.0) if num == free_taker else _r(rng, base - 12.0, 0.0)
		p.height = snappedf(rng.randf_range(1.74, 1.92) + (0.04 if line in [POS_MF, POS_FB] else 0.0), 0.01)
		p.skin = rng.randi_range(0, 3)
		p.hair = rng.randi_range(0, 4)
		p.hair_style = rng.randi_range(0, 2)
		out.append(p)
	_squads[id] = out
	return out


## The fifteen who start.
func starters(id: String) -> Array:
	return squad(id).slice(0, 15)


func free_taker(id: String) -> Dictionary:
	var best := {}
	for p in starters(id):
		if best.is_empty() or int(p.free) > int(best.free):
			best = p
	return best


func team_rating(id: String) -> float:
	var s := 0.0
	for p in starters(id):
		s += overall(p)
	return s / 15.0


static func _r(rng: RandomNumberGenerator, q: float, bias: float) -> int:
	return clampi(roundi(q + bias + rng.randfn(0.0, 5.0)), 25, 99)


func venue(id: String) -> Array:
	return VENUES.get(id, VENUES["county"])


## Two kits that would be hard to tell apart on the pitch: the away side changes (Rule 1.10 of the playing rules
## asks for distinctive colours; a team in a clash of colours plays in its alternative).
func colours_clash(a: String, b: String) -> bool:
	var ca: Color = team(a).c1
	var cb: Color = team(b).c1
	var d := Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length()
	return d < 0.35
