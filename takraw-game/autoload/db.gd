extends Node
## Teams, players and venues, built the way the real game is (docs/TAKRAW.md): national teams for the countries that
## play, rated from their recent results (men's and women's apart), and the three club leagues' real line-ups of
## states, provinces and services, under invented nicknames. Players have no names, only shirt numbers: none is a real
## person. Squads are made from each team's id, so they are the same in every game without a file of players.

const POS_TEKONG := 0   # the server, at the back
const POS_FEEDER := 1   # the left inside player, who sets (apit kiri)
const POS_STRIKER := 2  # the right inside player, who spikes (apit kanan)

## Spikes: how a striker kills the ball, and the Malay and Thai names fans know them by.
const SPIKE_ROLL := 0      # the roll spike (gulung, ฟาดลังกา): a full somersault, the foot over the shoulder
const SPIKE_SUNBACK := 1   # the sunback (kalih): a jumping horse kick, legs scissoring, side-on to the net
const SPIKE_HEADER := 2    # a header spike
const SPIKE_TAPAK := 3     # the sole spike (tapak): a sharp downward stamp of the sole over the net

## id: [strength men, strength women, kit colour 1, kit colour 2, region (the players' looks and style)]
const COUNTRIES := {
	"THA": [93, 93, "1f3fa0", "e8313d", "th"],
	"MAS": [90, 76, "ffcc00", "0b2a8c", "ms"],
	"JPN": [85, 72, "1d2a5c", "ffffff", "ja"],
	"VIE": [84, 91, "da251d", "ffcd00", "vi"],
	"INA": [83, 84, "d6132a", "ffffff", "id"],
	"MYA": [81, 81, "34b233", "fecb00", "my"],
	"KOR": [78, 69, "ffffff", "cd2e3a", "ko"],
	"IND": [79, 74, "ff9933", "138808", "hi"],
	"PHI": [73, 77, "0038a8", "fcd116", "fil"],
	"LAO": [74, 78, "ce1126", "002868", "lo"],
	"SGP": [67, 62, "ef3340", "ffffff", "ms"],
	"IRN": [67, 58, "239f40", "ffffff", "fa"],
	"CAM": [64, 63, "032ea1", "e00025", "km"],
	"BRU": [63, 58, "f7e017", "1a1a1a", "ms"],
	"CHN": [65, 71, "de2910", "ffde00", "zh"],
	"NEP": [59, 60, "dc143c", "003893", "hi"],
	"SRI": [55, 59, "8d153a", "ffbe29", "hi"],
	"PAK": [57, 50, "01411c", "ffffff", "fa"],
	"USA": [53, 52, "0a3161", "b31942", "en"],
	"FRA": [51, 52, "0055a4", "ef4135", "en"],
	"GER": [49, 48, "1a1a1a", "dd0000", "en"],
	"AUS": [49, 50, "00843d", "ffcd00", "en"],
}

## The three club leagues, run the way the real ones are run now (docs/TAKRAW.md), under plain names of our own: the
## real leagues', clubs' and competitions' names and badges are theirs, so the clubs here are the real line-ups'
## states, provinces and services under invented nicknames: [id, short, name, home, colour 1, colour 2, strength].
##  - Malaysia (the Sepak Takraw League): twelve Premier clubs (the 2026 line-up: the states, the armed forces,
##    the police and the fire service) play a circuit of seven Grand Prix, each a tournament of its own (four groups of
##    three, the quarter-finals, the semi-finals, the final and the third place) worth points to the season's
##    standings; the most points win the league, the last two go down. Division 1 is one tournament before the
##    season, its two finalists going up into that season's Premier League.
##  - Thailand (the Takraw Thailand League, as last played in 2022): eight provincial clubs, home and away; a
##    fixture is a tie of two regus, 2 points for winning both, 1 for one each; the champion is top of the table.
##  - Indonesia (Liga Sepak Takraw Indonesia, revived in 2026): five regions play a round robin each; the top two
##    of each go to the national finals in Jakarta (two groups of five, the semi-finals, the final). Men and women.
const LEAGUES := {
	"MY": {"name": "LEAGUE_MY", "country": "MAS", "pool": "ms", "format": "gp", "women": false, "year": 2026, "clubs": [
		["PRK", "PRK", "Perak Rhinos", "Ipoh", "f2c14e", "1a1a1a", 89],
		["KLC", "KLC", "KL Comets", "Kuala Lumpur", "1d2a5c", "19b3a3", 88],
		["MLK", "MLK", "Melaka Marlins", "Melaka", "8b1c3b", "f3efe6", 87],
		["NSN", "NSN", "Negeri Sembilan Stags", "Seremban", "f2c14e", "e8313d", 86],
		["JHR", "JHR", "Johor Hornbills", "Johor Bahru", "0b2a8c", "e8313d", 83],
		["KTN", "KTN", "Kelantan Kestrels", "Kota Bharu", "c8102e", "ffffff", 81],
		["PNG", "PNG", "Penang Pythons", "George Town", "2b2b2b", "4cd38a", 81],
		["ATM", "ATM", "Armed Forces Rangers", "Kuala Lumpur", "3d5229", "f2c14e", 80],
		["SLA", "SLA", "Selangor Stingrays", "Shah Alam", "e8313d", "ffcc00", 80],
		["POL", "POL", "Police Falcons", "Kuala Lumpur", "0b2a5c", "c8102e", 79],
		["KDH", "KDH", "Kedah Hawks", "Alor Setar", "f7e017", "137a3e", 78],
		["FRS", "FRS", "Fire & Rescue Blazers", "Putrajaya", "c8102e", "ff9a1f", 77],
	], "div1": [
		["TRG", "TRG", "Terengganu Tides", "Kuala Terengganu", "ffffff", "0b2a8c", 75],
		["SBH", "SBH", "Sabah Summits", "Kota Kinabalu", "0f6fb5", "ffffff", 74],
		["PHG", "PHG", "Pahang Tapirs", "Kuantan", "1a1a1a", "ffffff", 72],
		["SWK", "SWK", "Sarawak Hornets", "Kuching", "ffcc00", "c8102e", 72],
		["UNI", "UNI", "Varsity Owls", "Bangi", "4b2a8c", "f2c14e", 71],
		["PJY", "PJY", "Putrajaya Lynx", "Putrajaya", "0f6fb5", "f2c14e", 70],
		["ACD", "ACD", "Academy Cubs", "Bukit Jalil", "ff9a1f", "1d2a5c", 70],
		["PRS", "PRS", "Perlis Cobras", "Kangar", "137a3e", "f7e017", 68],
		["LBN", "LBN", "Labuan Sharks", "Labuan", "19b3a3", "1d2a5c", 67],
		["PRI", "PRI", "Prisons Ironmen", "Kajang", "5a5a5a", "ff9a1f", 66],
	]},
	"TH": {"name": "LEAGUE_TH", "country": "THA", "pool": "th", "format": "ties", "women": false, "year": 2027, "clubs": [
		["SPB", "SPB", "Tusker Suphanburi", "Suphanburi", "e8313d", "ffcc00", 88],
		["NPT", "NPT", "Red Stupa Nakhon Pathom", "Nakhon Pathom", "c8102e", "f2c14e", 87],
		["ACR", "ACR", "Monkey King Amnat Charoen", "Amnat Charoen", "f7e017", "1d2a5c", 86],
		["PRE", "PRE", "Teak Tiger Phrae", "Phrae", "8b4513", "f3efe6", 85],
		["CBI", "CBI", "Sea Eagle Chonburi", "Chonburi", "19b3a3", "1d2a5c", 83],
		["PLK", "PLK", "River Naga Phitsanulok", "Phitsanulok", "4b2a8c", "f2c14e", 82],
		["SSK", "SSK", "Lightning Sisaket", "Sisaket", "0f6fb5", "ffcc00", 81],
		["NKI", "NKI", "Mekong Dragon Nong Khai", "Nong Khai", "137a3e", "ffffff", 80],
	]},
	"ID": {"name": "LEAGUE_ID", "country": "INA", "pool": "id", "format": "zones", "women": true, "year": 2026, "zones": [
		["ZONE_SUMATRA", ["PLM", "MNG", "LPG", "ACH", "PKU", "BTM"]],
		["ZONE_JAVA", ["SOL", "SBY", "JKT", "BDG", "SRG", "DPS"]],
		["ZONE_SULAWESI", ["MKS", "PAL", "MJU", "MND"]],
		["ZONE_KALIMANTAN", ["BJM", "SMD", "PNK", "TRK"]],
		["ZONE_PAPUA", ["JYP", "AMB", "TTE", "MKW"]],
	], "clubs": [
		["PLM", "PLM", "Palembang Songket", "Palembang", "8b1c3b", "f2c14e", 78],
		["MNG", "MNG", "Minang Rangkiang", "Padang", "e8313d", "1a1a1a", 77],
		["LPG", "LPG", "Lampung Siger", "Bandar Lampung", "f7e017", "c8102e", 76],
		["ACH", "ACH", "Aceh Seulawah", "Banda Aceh", "137a3e", "ffffff", 75],
		["PKU", "PKU", "Pekanbaru Lancang", "Pekanbaru", "0f6fb5", "f7e017", 73],
		["BTM", "BTM", "Batam Segantang", "Batam", "19b3a3", "ffffff", 72],
		["SOL", "SOL", "Solo Garuda", "Surakarta", "1d2a5c", "f2c14e", 84],
		["SBY", "SBY", "Surabaya Baya", "Surabaya", "0b8a3e", "ffcc00", 82],
		["JKT", "JKT", "Jakarta Rajawali", "Jakarta", "c8102e", "ffffff", 81],
		["BDG", "BDG", "Bandung Kujang", "Bandung", "0f4c9e", "f3efe6", 80],
		["SRG", "SRG", "Serang Badak", "Serang", "1a1a1a", "f7e017", 79],
		["DPS", "DPS", "Denpasar Barong", "Denpasar", "ff8a1f", "1a1a1a", 76],
		["MKS", "MKS", "Makassar Phinisi", "Makassar", "e8313d", "0f4c9e", 80],
		["PAL", "PAL", "Palu Kaili", "Palu", "4b2a8c", "ffffff", 74],
		["MJU", "MJU", "Mamuju Sandeq", "Mamuju", "19b3a3", "f7e017", 72],
		["MND", "MND", "Manado Bunaken", "Manado", "0f6fb5", "ffffff", 70],
		["BJM", "BJM", "Banjarmasin Bekantan", "Banjarmasin", "f7e017", "137a3e", 74],
		["SMD", "SMD", "Samarinda Enggang", "Samarinda", "c8102e", "f3efe6", 73],
		["PNK", "PNK", "Pontianak Khatulistiwa", "Pontianak", "ffcc00", "1d2a5c", 71],
		["TRK", "TRK", "Tarakan Pesut", "Tarakan", "0f6fb5", "f2c14e", 70],
		["JYP", "JYP", "Jayapura Cenderawasih", "Jayapura", "19b3a3", "ffcc00", 73],
		["AMB", "AMB", "Ambon Manise", "Ambon", "e8313d", "ffffff", 70],
		["TTE", "TTE", "Ternate Kie Raha", "Ternate", "f2c14e", "137a3e", 68],
		["MKW", "MKW", "Manokwari Kasuari", "Manokwari", "1a1a1a", "e8313d", 67],
	]},
}

## The Grand Prix of the 2026 Malaysian season, in their order: [host state, city, our venue].
const STL_GPS := [
	["Perak", "Ipoh", "national"],
	["Penang", "Balik Pulau", "provincial"],
	["Melaka", "Melaka", "national"],
	["Kuala Lumpur", "Kuala Lumpur", "mall"],
	["Negeri Sembilan", "Seremban", "national"],
	["Johor", "Johor Bahru", "national"],
	["Selangor", "Serdang", "national"],
]
## The two clubs the real Division 1 of 2026 sent up (they start in the Premier League; pick a Division 1 club and
## that tournament is played again, with you in it).
const STL_PROMOTED := ["KDH", "FRS"]
## The points a Grand Prix finish is worth in the STL standings (2026).
const GP_POINTS := {"1": 32, "2": 28, "3": 24, "4": 21, "qf": 15, "g1": 8, "g0": 0}


## Venues: [id, name key, indoor, kind]. kind picks how Arena builds it.
const VENUES := [
	["national", "VENUE_NATIONAL", true, "arena"],       # the home of takraw: 3,000 seats, LED boards
	["mall", "VENUE_MALL", true, "mall"],                # a court in a shopping mall's atrium, as the world championship is
	["provincial", "VENUE_PROVINCIAL", true, "gym"],     # a provincial gymnasium: a few rows of seats, fans on the walls
	["park", "VENUE_PARK", false, "park"],               # a park court in the evening, floodlit
	["beach", "VENUE_BEACH", false, "beach"],            # a beach court at sunset
]

var _teams := {}      # id -> team dict
var _squads := {}     # id|w -> Array of players


func _ready() -> void:
	for id in COUNTRIES:
		var c: Array = COUNTRIES[id]
		_teams[id] = {"id": id, "kind": "country", "short": id, "c1": Color(c[2]), "c2": Color(c[3]), "str": c[0],
			"str_w": c[1], "pool": c[4], "home": "TEAM_" + id}
	for lid in LEAGUES:
		var lg: Dictionary = LEAGUES[lid]
		for row in lg.clubs + lg.get("div1", []):
			_teams[row[0]] = {"id": row[0], "kind": "club", "league": lid, "short": row[1], "name": row[2],
				"home": row[3], "c1": Color(row[4]), "c2": Color(row[5]), "str": row[6], "str_w": row[6] - 6,
				"pool": lg.pool}


func team(id: String) -> Dictionary:
	return _teams.get(id, {})


func team_name(id: String) -> String:
	var t := team(id)
	if t.is_empty():
		return id
	if t.kind == "country":
		return tr("TEAM_" + id)
	return String(t.name)


func countries() -> Array:
	return COUNTRIES.keys()


## Countries in order of strength (men's or women's).
func countries_ranked(women := false) -> Array:
	var ids: Array = COUNTRIES.keys()
	ids.sort_custom(func(a, b): return int(COUNTRIES[a][1 if women else 0]) > int(COUNTRIES[b][1 if women else 0]))
	return ids


## A league's clubs (Malaysia: the Premier League as it starts in the game; division 2, Division 1).
func league_clubs(lid: String, division := 1) -> Array:
	var out := []
	for row in LEAGUES[lid].get("div1" if division == 2 else "clubs", []):
		out.append(row[0])
	return out


## Indonesia: the region a club plays in (its name key), or "".
func zone_of(id: String) -> String:
	for z in LEAGUES.ID.zones:
		if id in z[1]:
			return String(z[0])
	return ""


func strength(id: String, women := false) -> int:
	var t := team(id)
	return int(t.get("str_w" if women else "str", 60))


## A team's rating (0-100) from its best regu.
func team_rating(id: String, women := false) -> float:
	var s := squad(id, women)
	var best := regu(id, women, 3)
	var total := 0.0
	for p in best:
		total += overall(p)
	return total / maxf(1.0, best.size()) if not s.is_empty() else float(strength(id, women))


## A player's overall rating, weighted by what his position needs.
static func overall(p: Dictionary) -> float:
	match int(p.pos):
		POS_TEKONG:
			return p.serve * 0.45 + p.receive * 0.3 + p.agility * 0.15 + p.block * 0.1
		POS_FEEDER:
			return p.setting * 0.45 + p.receive * 0.3 + p.agility * 0.15 + p.block * 0.1
	return p.spike * 0.45 + p.block * 0.25 + p.agility * 0.2 + p.receive * 0.1


## A team's squad: 9 players, three of each position (two regus and reserves). Made from the team's id, so the same
## every time.
func squad(id: String, women := false) -> Array:
	var key := "%s|%s" % [id, "w" if women else "m"]
	if _squads.has(key):
		return _squads[key]
	var t := team(id)
	var out := []
	if t.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var base := float(strength(id, women))
	var drawn := {}
	for i in 9:
		var pos := i % 3
		var tier: float = [3.0, 0.0, -5.0][i / 3]  # the first regu best, the second close behind, then reserves
		var q := clampf(base + tier + rng.randf_range(-4.0, 4.0), 35.0, 99.0)
		_name_draws(rng, String(t.pool), women, drawn)
		var p := {
			"id": "%s_%d" % [key, i], "pos": pos, "num": 0,
			"age": rng.randi_range(19, 33), "height": rng.randf_range(1.66, 1.84) - (0.1 if women else 0.0),
			"left": rng.randf() < 0.22,
			"serve": _r(rng, q, 12.0 if pos == POS_TEKONG else -10.0),
			"receive": _r(rng, q, 2.0),
			"setting": _r(rng, q, 12.0 if pos == POS_FEEDER else -8.0),
			"spike": _r(rng, q, 12.0 if pos == POS_STRIKER else -12.0),
			"block": _r(rng, q, 6.0 if pos == POS_STRIKER else -2.0),
			"agility": _r(rng, q, 0.0),
			"spike_kind": SPIKE_HEADER if pos != POS_STRIKER and rng.randf() < 0.5 else (
				SPIKE_ROLL if (String(t.pool) == "th" and rng.randf() < 0.7) or rng.randf() < 0.45 else (
				SPIKE_SUNBACK if rng.randf() < 0.8 else SPIKE_TAPAK)),
			"serve_kind": 1 if pos == POS_TEKONG and rng.randf() < 0.35 else 0,   # 1: the horse kick serve
			"skin": [Color("e0b48c"), Color("c98a5a"), Color("b07448"), Color("8d5a36"), Color("6b4226")][_skin(rng, String(t.pool))],
			"hair_style": rng.randi_range(0, 3) if not women else 4 + rng.randi_range(0, 1),
		}
		out.append(p)
	# Shirt numbers 1-15, the way regu squads number.
	var nums := range(1, 16)
	for p in out:
		var k := rng.randi_range(0, nums.size() - 1)
		p.num = nums[k]
		nums.remove_at(k)
	_squads[key] = out
	return out


## The best n players for a match: a tekong, a feeder and a striker (n = 3, the regu); n = 4 adds a second striker
## (the quadrant), n = 2 the tekong and the striker (doubles). skip: players who have already played (the second
## and third regus of a team event).
func regu(id: String, women := false, n := 3, skip := []) -> Array:
	var s := squad(id, women)
	var wanted := [POS_TEKONG, POS_FEEDER, POS_STRIKER]
	if n == 4:
		wanted = [POS_TEKONG, POS_FEEDER, POS_STRIKER, POS_STRIKER]
	elif n == 2:
		wanted = [POS_TEKONG, POS_STRIKER]
	var out := []
	var taken := {}
	for pos in wanted:
		var best = null
		for p in s:
			if p.pos != pos or taken.has(p.id) or p.id in skip:
				continue
			if best == null or overall(p) > overall(best):
				best = p
		if best == null:   # out of players for the position: the best left
			for p in s:
				if not taken.has(p.id) and not (p.id in skip) and (best == null or overall(p) > overall(best)):
					best = p
		if best != null:
			taken[best.id] = true
			out.append(best)
	return out


## Squads were first made with names, and the matches were balanced on the players that made. The names are gone,
## but the draws that picked them are still made (from the old lists' sizes: [given, family, women's given]), so every
## player keeps the ratings and style he was tuned with.
const _NAME_DRAWS := {"th": [18, 16, 10], "ms": [18, 16, 10], "id": [16, 14, 10], "vi": [12, 10, 10], "my": [12, 10, 10],
	"lo": [10, 8, 8], "km": [10, 10, 8], "fil": [12, 10, 8], "ja": [12, 11, 8], "ko": [10, 10, 8], "zh": [10, 10, 8],
	"hi": [12, 10, 8], "fa": [10, 10, 8], "en": [12, 12, 8]}


static func _name_draws(rng: RandomNumberGenerator, code: String, women: bool, drawn: Dictionary) -> void:
	var n: Array = _NAME_DRAWS.get(code, _NAME_DRAWS.en)
	for attempt in 20:
		var g := rng.randi_range(0, int(n[2] if women else n[0]) - 1)
		var f := rng.randi_range(0, int(n[1]) - 1)
		var k := "%d/%d" % [g, f]
		if drawn.has(k):
			continue
		drawn[k] = true
		return


static func _r(rng: RandomNumberGenerator, q: float, bias: float) -> int:
	return int(clampf(q + bias + rng.randf_range(-6.0, 6.0), 25.0, 99.0))


static func _skin(rng: RandomNumberGenerator, pool: String) -> int:
	match pool:
		"ja", "ko", "zh":
			return rng.randi_range(0, 1)
		"en":
			return [0, 0, 1, 3, 4][rng.randi_range(0, 4)]
		"hi", "fa":
			return rng.randi_range(2, 4)
	return rng.randi_range(1, 3)


func venue(id: String) -> Array:
	for v in VENUES:
		if v[0] == id:
			return v
	return VENUES[0]


## A team's home venue: clubs and the big nations have an arena; the rest a provincial gym.
func home_venue(id: String) -> String:
	var t := team(id)
	if t.get("kind", "") == "club":
		return ["national", "provincial", "mall", "provincial", "national"][hash(id) % 5]
	return "national" if strength(id) > 75 else "provincial"
