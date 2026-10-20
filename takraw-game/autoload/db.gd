extends Node
## Teams, players and venues. Everything is fictional but built the way the real game is (docs/TAKRAW.md):
## national teams for the countries that play, rated from their recent results (men's and women's apart), and three
## club leagues named the way real clubs are: Malaysian clubs a state and an English mascot, Thai clubs an epithet and
## a province, Indonesian clubs a city and a nickname. Squads are made from each team's id, so they are the same in
## every game without a file of players.

const POS_TEKONG := 0   # the server, at the back
const POS_FEEDER := 1   # the left inside player, who sets (apit kiri)
const POS_STRIKER := 2  # the right inside player, who spikes (apit kanan)

## Spikes: how a striker kills the ball, and the Malay and Thai names fans know them by.
const SPIKE_ROLL := 0      # the roll spike (gulung, ฟาดลังกา): a full somersault, the foot over the shoulder
const SPIKE_SUNBACK := 1   # the sunback (kalih): a jumping horse kick, legs scissoring, side-on to the net
const SPIKE_HEADER := 2    # a header spike
const SPIKE_TAPAK := 3     # the sole spike (tapak): a sharp downward stamp of the sole over the net

## id: [strength men, strength women, kit colour 1, kit colour 2, name pool]
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

## The three club leagues: [id, short, name, home, colour 1, colour 2, strength].
const LEAGUES := {
	"MY": {"name": "LEAGUE_MY", "country": "MAS", "pool": "ms", "clubs": [
		["SLA", "SLA", "Selangor Stingrays", "Shah Alam", "e8313d", "ffcc00", 84],
		["KLC", "KLC", "KL Comets", "Kuala Lumpur", "1d2a5c", "19b3a3", 86],
		["PRK", "PRK", "Perak Rhinos", "Ipoh", "f2c14e", "1a1a1a", 85],
		["JHR", "JHR", "Johor Hornbills", "Johor Bahru", "0b2a8c", "e8313d", 82],
		["KDH", "KDH", "Kedah Hawks", "Alor Setar", "f7e017", "137a3e", 80],
		["PNG", "PNG", "Penang Pythons", "George Town", "2b2b2b", "4cd38a", 78],
		["SBH", "SBH", "Sabah Summits", "Kota Kinabalu", "0f6fb5", "ffffff", 77],
		["SWK", "SWK", "Sarawak Hornets", "Kuching", "ffcc00", "c8102e", 76],
		["TRG", "TRG", "Terengganu Tides", "Kuala Terengganu", "ffffff", "0b2a8c", 75],
		["KTN", "KTN", "Kelantan Kestrels", "Kota Bharu", "c8102e", "ffffff", 79],
		["NSN", "NSN", "Negeri Sembilan Stags", "Seremban", "f2c14e", "e8313d", 74],
		["MLK", "MLK", "Melaka Marlins", "Melaka", "8b1c3b", "f3efe6", 73],
	]},
	"TH": {"name": "LEAGUE_TH", "country": "THA", "pool": "th", "clubs": [
		["SPB", "SPB", "Thunder Elephant Suphanburi", "Suphanburi", "e8313d", "ffcc00", 88],
		["KRT", "KRT", "Iron Naga Korat", "Nakhon Ratchasima", "4b2a8c", "f2c14e", 86],
		["CNX", "CNX", "Mountain Garuda Chiang Mai", "Chiang Mai", "137a3e", "ffffff", 84],
		["UBN", "UBN", "Golden Kinnari Ubon", "Ubon Ratchathani", "f7e017", "1d2a5c", 82],
		["HDY", "HDY", "Southern Tiger Hat Yai", "Songkhla", "ff8a1f", "1a1a1a", 83],
		["KKN", "KKN", "Silk Lion Khon Kaen", "Khon Kaen", "c8102e", "f3efe6", 80],
		["BKK", "BKK", "River Dragon Bangkok", "Bangkok", "0f6fb5", "ffcc00", 85],
		["CBI", "CBI", "Sea Eagle Chonburi", "Chonburi", "19b3a3", "1d2a5c", 79],
	]},
	"ID": {"name": "LEAGUE_ID", "country": "INA", "pool": "id", "clubs": [
		["JKT", "JKT", "Jakarta Rajawali", "Jakarta", "c8102e", "ffffff", 82],
		["SBY", "SBY", "Surabaya Baya", "Surabaya", "0b8a3e", "ffcc00", 80],
		["BDG", "BDG", "Bandung Maung", "Bandung", "0f4c9e", "f3efe6", 79],
		["MDN", "MDN", "Medan Harimau", "Medan", "ff8a1f", "1a1a1a", 78],
		["MKS", "MKS", "Makassar Phinisi", "Makassar", "e8313d", "0f4c9e", 77],
		["PLM", "PLM", "Palembang Songket", "Palembang", "8b1c3b", "f2c14e", 76],
		["BJM", "BJM", "Banjarmasin Bekantan", "Banjarmasin", "f7e017", "137a3e", 74],
		["JYP", "JYP", "Jayapura Cenderawasih", "Jayapura", "19b3a3", "ffcc00", 73],
	]},
}

## Venues: [id, name key, indoor, kind]. kind picks how Arena builds it.
const VENUES := [
	["national", "VENUE_NATIONAL", true, "arena"],       # the home of takraw: 3,000 seats, LED boards
	["dome", "VENUE_DOME", true, "dome"],                # the big indoor stadium, 5,000 seats, a final's venue
	["mall", "VENUE_MALL", true, "mall"],                # a court in a shopping mall's atrium, as the world championship is
	["provincial", "VENUE_PROVINCIAL", true, "gym"],     # a provincial gymnasium: a few rows of seats, fans on the walls
	["temple", "VENUE_TEMPLE", false, "temple"],         # an outdoor court in front of a temple
	["park", "VENUE_PARK", false, "park"],               # a park court in the evening, floodlit
	["beach", "VENUE_BEACH", false, "beach"],            # a beach court at sunset
	["street", "VENUE_STREET", false, "street"],         # a street court by a night market
]

# Name pools: [given names, family names, family name first?]
const NAMES := {
	"th": [["Anan", "Kittisak", "Siriwat", "Phanuwat", "Wirot", "Jakkrit", "Thanawat", "Sarawut", "Pongsak", "Nattapong", "Somchai", "Chaiwat", "Weerapong", "Supachai", "Kritsada", "Apichart", "Teerawat", "Yutthana"],
		["Thongdee", "Kaewmanee", "Srisuk", "Chaiyaporn", "Boonmee", "Rattanakorn", "Phromma", "Inthasorn", "Wongsawat", "Saelim", "Charoensuk", "Pholsri", "Duangjai", "Kongkaew", "Sukprasert", "Nakdee"], false],
	"ms": [["Hafiz", "Syafiq", "Amirul", "Haziq", "Izzat", "Farhan", "Aiman", "Zulkifli", "Faris", "Danial", "Ikhwan", "Shahrul", "Asyraf", "Hakimi", "Naim", "Firdaus", "Azri", "Luqman"],
		["Rahim", "Zainal", "Ismail", "Hamid", "Yusof", "Osman", "Razak", "Kamal", "Salleh", "Halim", "Aziz", "Ghani", "Noor", "Latif", "Rashid", "Hassan"], false],
	"id": [["Rizky", "Dimas", "Fajar", "Andi", "Yoga", "Agus", "Bayu", "Eko", "Hendra", "Iqbal", "Wahyu", "Rendi", "Galih", "Bima", "Taufik", "Ilham"],
		["Pratama", "Saputra", "Nugroho", "Setiawan", "Kurniawan", "Hidayat", "Wibowo", "Santoso", "Gunawan", "Firmansyah", "Ramadhan", "Hakim", "Siregar", "Lubis"], false],
	"vi": [["Văn Tú", "Minh Đức", "Quốc Bảo", "Thanh Hải", "Hữu Phước", "Đức Anh", "Văn Hùng", "Tuấn Kiệt", "Minh Khoa", "Công Vinh", "Gia Huy", "Văn Lâm"],
		["Nguyễn", "Trần", "Lê", "Phạm", "Hoàng", "Vũ", "Đặng", "Bùi", "Đỗ", "Ngô"], true],
	"my": [["Aung", "Zaw", "Kyaw", "Htet", "Min", "Naing", "Thura", "Ye", "Wai", "Soe", "Pyae", "Hein"],
		["Win", "Myint", "Lin", "Oo", "Tun", "Htun", "Aung", "Zin", "Naing", "Kyaw"], false],
	"lo": [["Souksavanh", "Phonesavanh", "Khamla", "Sengphet", "Bounmy", "Vilaysak", "Somphone", "Thongsavanh", "Anousone", "Keo"],
		["Phommachanh", "Vongsa", "Sisouphanh", "Keomany", "Inthavong", "Sengsouriya", "Chanthavong", "Phanthavong"], false],
	"km": [["Sokha", "Dara", "Vuthy", "Rithy", "Sopheak", "Chann", "Piseth", "Vannak", "Kosal", "Rotha"],
		["Chea", "Sok", "Heng", "Chan", "Lim", "Kim", "Meas", "Prak", "Ouk", "Keo"], true],
	"fil": [["Jason", "Mark", "John Paul", "Rey", "Carlo", "Rodel", "Jerome", "Kenneth", "Paolo", "Vince", "Ronnel", "Jeric"],
		["Dela Cruz", "Santos", "Reyes", "Bautista", "Mendoza", "Villanueva", "Garcia", "Ramos", "Aquino", "Navarro"], false],
	"ja": [["Haruto", "Ren", "Sota", "Yuto", "Kaito", "Riku", "Daiki", "Shota", "Takumi", "Kenta", "Yuma", "Hayato"],
		["Sato", "Suzuki", "Takahashi", "Tanaka", "Watanabe", "Ito", "Yamamoto", "Nakamura", "Kobayashi", "Kato", "Yoshida"], false],
	"ko": [["Min-jun", "Seo-jun", "Ji-ho", "Hyun-woo", "Do-yun", "Ji-hoon", "Sung-min", "Tae-yang", "Jun-young", "Woo-jin"],
		["Kim", "Lee", "Park", "Choi", "Jung", "Kang", "Cho", "Yoon", "Jang", "Lim"], true],
	"zh": [["Wei", "Jun", "Hao", "Lei", "Peng", "Yu", "Chen", "Bo", "Tao", "Xiang"],
		["Wang", "Li", "Zhang", "Liu", "Chen", "Yang", "Huang", "Zhao", "Zhou", "Wu"], true],
	"hi": [["Rahul", "Amit", "Sandeep", "Vikram", "Arjun", "Rohit", "Manoj", "Deepak", "Suresh", "Nitin", "Tomba", "Ibomcha"],
		["Singh", "Sharma", "Kumar", "Yadav", "Meitei", "Devi", "Verma", "Patel", "Chauhan", "Rao"], false],
	"fa": [["Ali", "Reza", "Hamid", "Mehdi", "Saeed", "Omid", "Farhad", "Imran", "Bilal", "Usman"],
		["Ahmadi", "Hosseini", "Karimi", "Rezaei", "Moradi", "Khan", "Hussain", "Malik", "Javed", "Rahimi"], false],
	"en": [["Tom", "Lucas", "Max", "Ben", "Leo", "Sam", "Noah", "Jack", "Felix", "Hugo", "Ethan", "Jonas"],
		["Martin", "Smith", "Brown", "Wilson", "Moreau", "Becker", "Taylor", "Lee", "Weber", "Clarke", "Bernard", "Walker"], false],
}
const NAMES_W := {
	"th": ["Sirinya", "Kanokwan", "Pimchanok", "Wiphawan", "Nattaya", "Jiraporn", "Supaporn", "Ratchanee", "Kanyarat", "Thitima"],
	"ms": ["Nurul", "Siti", "Aina", "Farah", "Syazwani", "Nadia", "Aisyah", "Hani", "Izzati", "Amira"],
	"id": ["Dewi", "Putri", "Ayu", "Rina", "Lestari", "Wulan", "Sari", "Indah", "Fitri", "Nadia"],
	"vi": ["Thị Hoa", "Ngọc Trâm", "Thu Hà", "Thị Linh", "Bảo Ngọc", "Thanh Thúy", "Minh Thư", "Kim Ngân", "Thị Yến", "Hồng Nhung"],
	"my": ["Su", "Thandar", "Ei", "Hnin", "Khin", "May", "Phyu", "Nandar", "Thiri", "Yadanar"],
	"lo": ["Vanida", "Malaythong", "Souphaphone", "Chanthaly", "Ketsana", "Noy", "Dalavanh", "Phonepaseuth"],
	"km": ["Sreymom", "Chanthou", "Sophea", "Bopha", "Raksmey", "Leakhena", "Sreypov", "Kanha"],
	"fil": ["Jean", "Mary Joy", "Angeline", "Rhea", "Kristine", "Jessa", "Camille", "Princess"],
	"ja": ["Yui", "Hina", "Sakura", "Aoi", "Rin", "Mio", "Yuna", "Saki"],
	"ko": ["Ji-woo", "Seo-yeon", "Min-seo", "Ha-eun", "Yu-na", "Su-bin", "Ji-min", "Eun-ji"],
	"zh": ["Fang", "Jing", "Li", "Na", "Ying", "Xue", "Mei", "Hua"],
	"hi": ["Priya", "Anjali", "Sunita", "Pooja", "Khushbu", "Chaoba", "Leirik", "Sanjita"],
	"fa": ["Maryam", "Zahra", "Fatemeh", "Sara", "Ayesha", "Hina", "Sana", "Laleh"],
	"en": ["Emma", "Lea", "Mia", "Chloe", "Anna", "Grace", "Lena", "Sophie"],
}

var _teams := {}      # id -> team dict
var _squads := {}     # id|w -> Array of players


func _ready() -> void:
	for id in COUNTRIES:
		var c: Array = COUNTRIES[id]
		_teams[id] = {"id": id, "kind": "country", "short": id, "c1": Color(c[2]), "c2": Color(c[3]), "str": c[0],
			"str_w": c[1], "pool": c[4], "home": "TEAM_" + id}
	for lid in LEAGUES:
		var lg: Dictionary = LEAGUES[lid]
		for row in lg.clubs:
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


func league_clubs(lid: String) -> Array:
	var out := []
	for row in LEAGUES[lid].clubs:
		out.append(row[0])
	return out


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
	var pool: Array = NAMES.get(String(t.pool), NAMES.en)
	var used := {}
	for i in 9:
		var pos := i % 3
		var tier: float = [3.0, 0.0, -5.0][i / 3]  # the first regu best, the second close behind, then reserves
		var q := clampf(base + tier + rng.randf_range(-4.0, 4.0), 35.0, 99.0)
		var name := _name(rng, pool, String(t.pool), women, used)
		var p := {
			"id": "%s_%d" % [key, i], "name": name[0], "short": name[1], "pos": pos, "num": 0,
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


func _name(rng: RandomNumberGenerator, pool: Array, code: String, women: bool, used: Dictionary) -> Array:
	for attempt in 20:
		var given: String = (NAMES_W.get(code, NAMES_W.en) as Array)[rng.randi_range(0, (NAMES_W.get(code, NAMES_W.en) as Array).size() - 1)] if women else pool[0][rng.randi_range(0, pool[0].size() - 1)]
		var family: String = pool[1][rng.randi_range(0, pool[1].size() - 1)]
		var full := ("%s %s" % [family, given]) if pool[2] else ("%s %s" % [given, family])
		if used.has(full):
			continue
		used[full] = true
		# The name on the scoreboard: Thai, Malay, Lao and Filipino players go by their given name; the rest by the
		# family name, with an initial (Vietnamese by the last word of the given name, as commentators do).
		var short := given
		match code:
			"vi":
				short = given.split(" ")[-1]
			"ja", "ko", "zh", "km", "en", "fa", "id", "hi", "my":
				short = "%s. %s" % [given.left(1), family] if not pool[2] else family + " " + given.left(1) + "."
		return [full, short]
	return ["?", "?"]


func venue(id: String) -> Array:
	for v in VENUES:
		if v[0] == id:
			return v
	return VENUES[0]


## A team's home venue: clubs and the big nations have an arena; the rest a provincial gym.
func home_venue(id: String) -> String:
	var t := team(id)
	if t.get("kind", "") == "club":
		return ["national", "provincial", "dome", "provincial", "national"][hash(id) % 5]
	return "dome" if id in ["THA", "MAS"] else ("national" if strength(id) > 75 else "provincial")
