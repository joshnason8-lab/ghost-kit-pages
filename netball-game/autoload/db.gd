extends Node
## The teams, their squads and the venues. Countries by their plain names and flags; every player's name invented
## (made from common given and family names of her country, never a real player's), docs/PROGRESS.md "Names".

## id, English name key, rating (0-100, from the World Netball ranking of March 2026 and the 2026 Commonwealth
## Games), dress colour, trim colour, skin tones (a few, mixed through the squad), name pool.
const NATIONS := [
	["AUS", "Australia", 96, "f2b705", "0b6e3a", ["e8c4a0", "d9a77e", "b07a52", "7a4a2a"], "anglo"],
	["NZL", "New Zealand", 93, "111111", "f2f2f2", ["e8c4a0", "c48f62", "a06a44", "8a5636"], "nz"],
	["ENG", "England", 91, "f4f4f4", "c8102e", ["eccaa6", "c48f62", "8a5636", "5e3a22"], "anglo"],
	["JAM", "Jamaica", 90, "f9d616", "009b3a", ["7a4a2a", "6a3e22", "5a341c", "8a5636"], "carib"],
	["RSA", "South Africa", 87, "007a4d", "ffb612", ["6a3e22", "8a5636", "d9a77e", "5a341c"], "sa"],
	["UGA", "Uganda", 82, "fcdc04", "d90000", ["5a341c", "6a3e22", "4e2c18"], "uga"],
	["MWI", "Malawi", 80, "ce1126", "111111", ["5a341c", "6a3e22", "4e2c18"], "mwi"],
	["TGA", "Tonga", 79, "c10000", "f4f4f4", ["a06a44", "8a5636", "b07a52"], "tga"],
	["ZIM", "Zimbabwe", 75, "319b42", "ffd200", ["5a341c", "6a3e22", "4e2c18"], "zim"],
	["SCO", "Scotland", 72, "1f2a6b", "f4f4f4", ["eccaa6", "e8c4a0", "c48f62"], "anglo"],
	["TTO", "Trinidad and Tobago", 72, "da1a35", "111111", ["6a3e22", "8a5636", "a06a44"], "carib"],
	["WAL", "Wales", 71, "c8102e", "00b140", ["eccaa6", "e8c4a0", "c48f62"], "wal"],
	["NIR", "Northern Ireland", 70, "0b7a3e", "f4f4f4", ["eccaa6", "e8c4a0"], "anglo"],
	["FIJ", "Fiji", 70, "68bfe5", "f4f4f4", ["7a4a2a", "8a5636", "a06a44"], "fij"],
	["ZAM", "Zambia", 70, "198a00", "ef7d00", ["5a341c", "6a3e22", "4e2c18"], "zam"],
	["BAR", "Barbados", 68, "00267f", "ffc726", ["6a3e22", "5a341c", "8a5636"], "carib"],
	["SAM", "Samoa", 66, "002b7f", "ce1126", ["a06a44", "8a5636", "b07a52"], "sam"],
	["SGP", "Singapore", 64, "ef3340", "f4f4f4", ["e8c4a0", "d9a77e", "b07a52"], "sgp"],
	["MAS", "Malaysia", 63, "010066", "ffcc00", ["d9a77e", "c48f62", "e8c4a0"], "mas"],
	["SRI", "Sri Lanka", 62, "8d153a", "ffbe29", ["a06a44", "8a5636", "b07a52"], "sri"],
	["KEN", "Kenya", 60, "006600", "bb0000", ["5a341c", "4e2c18", "6a3e22"], "ken"],
	["BOT", "Botswana", 58, "75aadb", "111111", ["5a341c", "6a3e22"], "sa"],
	["NAM", "Namibia", 57, "003580", "d21034", ["5a341c", "6a3e22", "d9a77e"], "sa"],
]

## The Club Season's clubs (League): invented, each a city and a nickname no real club uses (checked against the four countries' top
## leagues and a web search, October 2026),
## in the four countries with professional netball leagues. id, name, short (on the crest), rating, dress colour,
## trim, skin tones, name pool, country.
const CLUBS := [
	["BBR", "Brisbane Brolgas", "BB", 86, "b5452a", "f2d16b", ["e8c4a0", "d9a77e", "b07a52", "7a4a2a"], "anglo", "AUS"],
	["ADP", "Adelaide Pelicans", "AP", 82, "1d4e89", "f4f4f4", ["eccaa6", "d9a77e", "a06a44"], "anglo", "AUS"],
	["WKR", "Wellington Kārearea", "WK", 85, "3b2a4f", "e0b04a", ["e8c4a0", "c48f62", "a06a44", "8a5636"], "nz", "NZL"],
	["DHE", "Dunedin Herons", "DH", 78, "4f7f8f", "f4f4f4", ["eccaa6", "c48f62", "8a5636"], "nz", "NZL"],
	["SKF", "Sheffield Kingfishers", "SK", 84, "0a7f9e", "f28c28", ["eccaa6", "c48f62", "8a5636", "5e3a22"], "anglo", "ENG"],
	["BRO", "Bristol Otters", "BO", 79, "5a3d2b", "9fd3c7", ["eccaa6", "e8c4a0", "8a5636"], "anglo", "ENG"],
	["DST", "Durban Strelitzias", "DS", 81, "e2a400", "3a1f5d", ["6a3e22", "8a5636", "5a341c", "d9a77e"], "sa", "RSA"],
	["CTG", "Cape Town Gannets", "CG", 80, "f4f4f4", "1b365d", ["6a3e22", "d9a77e", "8a5636", "5a341c"], "sa", "RSA"],
]

## Given names and family names, common in each country (never a pairing taken from a real player).
const NAMES := {
	"anglo": [["Amy", "Beth", "Chloe", "Ella", "Grace", "Hannah", "Isla", "Jess", "Kate", "Laura", "Molly", "Phoebe",
		"Rosie", "Sophie", "Tara", "Zoe", "Lucy", "Maddie", "Georgia", "Erin"],
		["Abbott", "Barker", "Clarke", "Dawson", "Ellis", "Fletcher", "Gibson", "Harper", "Irwin", "Jennings", "Keane",
		"Lawson", "Mitchell", "Nolan", "Osborne", "Pryce", "Quinn", "Rowe", "Sutton", "Turner", "Walsh", "Yates"]],
	"nz": [["Aroha", "Mere", "Kaia", "Ngaio", "Anahera", "Hana", "Maia", "Tia", "Ella", "Sophie", "Grace", "Libby",
		"Ruby", "Kiri", "Moana", "Te Ao"],
		["Paewai", "Tamihana", "Ngata", "Walker", "Henare", "Wiremu", "Hohaia", "Pere", "Taylor", "Brown", "Rewi",
		"Kingi", "Morrison", "Tipene", "Hunt", "Moffatt"]],
	"carib": [["Shanice", "Kerry-Ann", "Tanisha", "Jodian", "Rochelle", "Kimone", "Shamera", "Latoya", "Abigail",
		"Danielle", "Monique", "Sasha", "Tiana", "Nicole", "Khadijah", "Jhanielle"],
		["Brown", "Campbell", "Grant", "Henry", "Lewis", "Morgan", "Reid", "Scott", "Thompson", "Williams", "Bailey",
		"Francis", "Gordon", "Spence", "Walters", "Bennett"]],
	"sa": [["Lerato", "Thandi", "Nomvula", "Karabo", "Zanele", "Lindiwe", "Anri", "Elmarie", "Precious", "Refilwe",
		"Ayanda", "Kgothatso", "Marike", "Nandi", "Palesa", "Busisiwe"],
		["Mokoena", "Dlamini", "Nkosi", "Botha", "Mahlangu", "van Wyk", "Ndlovu", "Molefe", "Pretorius", "Khumalo",
		"Sithole", "Venter", "Mabuza", "Coetzee", "Tshabalala", "Mthembu"]],
	"uga": [["Nakato", "Babirye", "Namubiru", "Achieng", "Nalwoga", "Prossy", "Shadia", "Mary", "Irene", "Faridah",
		"Lillian", "Juliet", "Nakimuli", "Rose"],
		["Nansubuga", "Kyomuhendo", "Atim", "Namuli", "Nakayenga", "Akello", "Nabukeera", "Auma", "Kirabo", "Ainembabazi",
		"Nalubega", "Kisakye", "Mugisha", "Nankya"]],
	"mwi": [["Chimwemwe", "Thokozani", "Mphatso", "Takondwa", "Tiyamike", "Chikondi", "Madalitso", "Towera", "Grace",
		"Lusungu", "Tamanda", "Yamikani"],
		["Banda", "Phiri", "Mwale", "Chirwa", "Kamanga", "Nyirenda", "Gondwe", "Mbewe", "Kumwenda", "Chisale", "Msiska",
		"Mhango"]],
	"zim": [["Tendai", "Rudo", "Chipo", "Nyasha", "Tatenda", "Ruvimbo", "Fadzai", "Tsitsi", "Vimbai", "Kudzai",
		"Rumbidzai", "Shamiso"],
		["Moyo", "Ncube", "Sibanda", "Chikwanha", "Mpofu", "Dube", "Mutasa", "Chinembiri", "Marufu", "Gumbo",
		"Mlambo", "Zhou"]],
	"zam": [["Mutinta", "Chilufya", "Natasha", "Mwila", "Bupe", "Chanda", "Mapalo", "Namakau", "Musonda", "Thandiwe"],
		["Banda", "Mulenga", "Phiri", "Bwalya", "Zulu", "Tembo", "Mwansa", "Lungu", "Chileshe", "Sakala"]],
	"ken": [["Wanjiru", "Achieng", "Njeri", "Atieno", "Wambui", "Chebet", "Nafula", "Akinyi", "Mumbua", "Jepchirchir"],
		["Otieno", "Mwangi", "Kamau", "Wanyama", "Kiptoo", "Onyango", "Njoroge", "Kariuki", "Mutua", "Odhiambo"]],
	"tga": [["Mele", "Sela", "Lose", "Ana", "Salote", "Losana", "Siueni", "Mafi", "Kalolaine", "Vika", "Ofa", "Lupe"],
		["Tupou", "Fifita", "Vaipulu", "Taufa", "Havili", "Moala", "Latu", "Kioa", "Fonua", "Mahe", "Pulu", "Taione"]],
	"sam": [["Leilani", "Malia", "Sina", "Fetu", "Lagi", "Mele", "Tausani", "Ioana", "Alofa", "Pua"],
		["Fa'asavalu", "Tuilagi", "Leiataua", "Sapolu", "Fiso", "Tago", "Lemalu", "Seiuli", "Matagi", "Toleafoa"]],
	"fij": [["Mere", "Litia", "Salote", "Unaisi", "Adi", "Ana", "Kelera", "Vasemaca", "Asenaca", "Losana"],
		["Naivalu", "Tuivaga", "Ratu", "Nabou", "Waqa", "Rokotuiveikau", "Nainoca", "Vuniwaqa", "Bulavou", "Delana"]],
	"wal": [["Cerys", "Ffion", "Seren", "Nia", "Elin", "Megan", "Bethan", "Catrin", "Lowri", "Mali", "Gwen", "Carys"],
		["Jones", "Davies", "Evans", "Williams", "Griffiths", "Hughes", "Morgan", "Rees", "Powell", "Pritchard",
		"Lloyd", "Howells"]],
	"sgp": [["Mei Ling", "Hui Min", "Siti", "Priya", "Jia Hui", "Nur", "Rachel", "Shu Fen", "Kavitha", "Wen Xin"],
		["Tan", "Lim", "Ng", "Rahman", "Wong", "Chua", "Pillai", "Teo", "Goh", "Ismail"]],
	"mas": [["Nurul", "Siti", "Aisyah", "Farah", "Mei Yee", "Divya", "Hani", "Liyana", "Syafiqah", "Kar Mun"],
		["Abdullah", "Hassan", "Ismail", "Lee", "Rahim", "Chong", "Ramasamy", "Yusof", "Osman", "Tan"]],
	"sri": [["Dilani", "Tharjini", "Chathurangi", "Nadeesha", "Gayani", "Hasini", "Sachini", "Ishara", "Kavindi",
		"Piumi"],
		["Perera", "Fernando", "Silva", "Jayasinghe", "Wickramasinghe", "Bandara", "Kumari", "Dissanayake",
		"Rajapaksha", "Sivakumar"]],
}

## Venues: id, English name key, kind ("arena" indoors with seating all round, "hall" a sports hall with a stand
## down one side, "outdoor" an asphalt court under the sky, as so much netball is played across Africa, the
## Caribbean and the Pacific), crowd size (seats).
const VENUES := [
	["arena", "VENUE_ARENA", "arena", 9000],
	["hall", "VENUE_HALL", "hall", 900],
	["outdoor", "VENUE_OUTDOOR", "outdoor", 400],
]

var _teams := {}
var _squads := {}


func _ready() -> void:
	for n in NATIONS:
		_teams[n[0]] = {"id": n[0], "name": n[1], "rating": int(n[2]), "c1": Color(String(n[3])), "c2": Color(String(n[4])),
			"skins": n[5], "pool": n[6], "kind": "country"}
	for c in CLUBS:
		_teams[c[0]] = {"id": c[0], "name": c[1], "short": c[2], "rating": int(c[3]), "c1": Color(String(c[4])),
			"c2": Color(String(c[5])), "skins": c[6], "pool": c[7], "country": c[8], "kind": "club"}


## The national teams (Quick Match and the Nations Cup).
func team_ids() -> Array:
	return _teams.keys().filter(func(id): return _teams[id].kind == "country")


## The Club Season's clubs.
func club_ids() -> Array:
	return _teams.keys().filter(func(id): return _teams[id].kind == "club")


func team(id: String) -> Dictionary:
	return _teams.get(id, {})


## A team's name in the language shown (countries by their plain name; the translation files carry them as
## TEAM_<ID> where the name differs).
func team_name(id: String) -> String:
	var key := "TEAM_" + id
	var t := tr(key)
	if t != key:
		return t
	return String(team(id).get("name", id))


## Three letters for the scoreboard.
func team_abbr(id: String) -> String:
	return id


func team_rating(id: String) -> float:
	return float(team(id).get("rating", 60))


## The bib colour: the dress's trim, or white on a dark dress.
func bib_colour(id: String) -> Color:
	var t := team(id)
	var c1: Color = t.get("c1", Color.WHITE)
	return Color("f4f4f4") if c1.get_luminance() < 0.5 else Color("1a1a1a")


## A team's squad of twelve: seven starters in position order (GS, GA, WA, C, WD, GD, GK), then five on the bench,
## each able to play her own position and a neighbour's. Built the same every time from the team id.
func squad(id: String) -> Array:
	if _squads.has(id):
		return _squads[id]
	var t := team(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("squad:" + id)
	var pool: Array = NAMES.get(String(t.get("pool", "anglo")), NAMES.anglo)
	var used := {}
	var out := []
	var bench_pos := ["GS", "C", "WD", "GK", "GA"]
	var alts := {"GS": ["GA"], "GA": ["GS", "WA"], "WA": ["C", "GA"], "C": ["WA", "WD"], "WD": ["C", "GD"],
		"GD": ["GK", "WD"], "GK": ["GD"]}
	for i in 12:
		var pos: String = Rules.POSITIONS[i] if i < 7 else bench_pos[i - 7]
		var name := ""
		for tries in 20:
			name = "%s %s" % [pool[0][rng.randi_range(0, pool[0].size() - 1)], pool[1][rng.randi_range(0, pool[1].size() - 1)]]
			if not used.has(name):
				break
		used[name] = true
		var base := float(t.get("rating", 60)) + rng.randf_range(-6.0, 5.0) - (4.0 if i >= 7 else 0.0)
		var tall := pos in ["GS", "GK"]
		var mid := pos in ["GA", "GD"]
		var height := rng.randf_range(1.84, 1.96) if tall else (rng.randf_range(1.76, 1.86) if mid else rng.randf_range(1.62, 1.76))
		var skins: Array = t.get("skins", ["c48f62"])
		var p := {
			"id": "%s_%d" % [id, i + 1],
			"team": id,
			"name": name,
			"num": i + 1,
			"pos": pos,
			"alt": alts[pos],
			"height": snappedf(height, 0.01),
			"shoot": clampi(int(base + (10.0 if pos == "GS" else (6.0 if pos == "GA" else -25.0)) + rng.randf_range(-4, 4)), 20, 99),
			"pass": clampi(int(base + (5.0 if pos in ["C", "WA"] else 0.0) + rng.randf_range(-4, 4)), 30, 99),
			"defend": clampi(int(base + (7.0 if pos in ["GK", "GD", "WD"] else -6.0) + rng.randf_range(-4, 4)), 30, 99),
			"speed": clampi(int(base + (6.0 if pos in ["C", "WA", "WD"] else -3.0) + rng.randf_range(-5, 5)), 30, 99),
			"skin": String(skins[rng.randi_range(0, skins.size() - 1)]),
			"hair": rng.randi_range(0, 3),
		}
		out.append(p)
	_squads[id] = out
	return out


func player_rating(p: Dictionary) -> int:
	match String(p.pos):
		"GS":
			return int((int(p.shoot) * 2 + int(p.pass) + int(p.speed)) / 4)
		"GA":
			return int((int(p.shoot) + int(p.pass) + int(p.speed)) / 3)
		"GK", "GD":
			return int((int(p.defend) * 2 + int(p.speed) + int(p.pass)) / 4)
	return int((int(p.pass) + int(p.defend) + int(p.speed) * 2) / 4)


func venue(id: String) -> Array:
	for v in VENUES:
		if v[0] == id:
			return v
	return VENUES[0]
