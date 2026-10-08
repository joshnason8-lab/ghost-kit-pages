extends Node
## Static game data: the fictional league, national teams, grounds, and generated squads.
## Everything is generated from fixed seeds so squads are the same on every device.

const ATTRS := ["speed", "agility", "strength", "reach", "tackle", "stamina"]

# Defensive positions, left to right from the defenders' own point of view.
const POSITIONS := ["POS_LEFT_CORNER", "POS_LEFT_COVER", "POS_LEFT_IN", "POS_CENTRE", "POS_RIGHT_IN", "POS_RIGHT_COVER", "POS_RIGHT_CORNER"]

# Fictional franchises. Names are invented; none is meant to stand for a real club.
const LEAGUE := [
	{"id": "MUM", "name": "Mumbai Monsoon", "city": "Mumbai", "state": "STATE_MAHARASHTRA", "c1": "12a4a7", "c2": "f3efe6", "base": 79},
	{"id": "DEL", "name": "Delhi Sher", "city": "Delhi", "state": "STATE_DELHI", "c1": "d62828", "c2": "ffd166", "base": 80},
	{"id": "KOL", "name": "Kolkata Thunder", "city": "Kolkata", "state": "STATE_BENGAL", "c1": "6a2c91", "c2": "ffb703", "base": 76},
	{"id": "CHE", "name": "Chennai Surge", "city": "Chennai", "state": "STATE_TAMIL_NADU", "c1": "f6c90e", "c2": "1d3557", "base": 78},
	{"id": "HYD", "name": "Hyderabad Hawks", "city": "Hyderabad", "state": "STATE_TELANGANA", "c1": "f37021", "c2": "1b1b1b", "base": 77},
	{"id": "BLR", "name": "Bengaluru Rockets", "city": "Bengaluru", "state": "STATE_KARNATAKA", "c1": "2a9d4b", "c2": "f3efe6", "base": 79},
	{"id": "JAI", "name": "Jaipur Desert Kings", "city": "Jaipur", "state": "STATE_RAJASTHAN", "c1": "c9a26b", "c2": "6a040f", "base": 78},
	{"id": "PAT", "name": "Patna Pehalwans", "city": "Patna", "state": "STATE_BIHAR", "c1": "1f5fbf", "c2": "ffd60a", "base": 77},
	{"id": "PUN", "name": "Pune Sahyadris", "city": "Pune", "state": "STATE_MAHARASHTRA", "c1": "7a1f3d", "c2": "f3efe6", "base": 78},
	{"id": "AHM", "name": "Ahmedabad Express", "city": "Ahmedabad", "state": "STATE_GUJARAT", "c1": "1b2a4a", "c2": "48cae4", "base": 75},
	{"id": "CHD", "name": "Chandigarh Chargers", "city": "Chandigarh", "state": "STATE_PUNJAB", "c1": "222222", "c2": "ffc300", "base": 80},
	{"id": "LKO", "name": "Lucknow Nawabs", "city": "Lucknow", "state": "STATE_UP", "c1": "c2185b", "c2": "ffd166", "base": 76},
]

const COUNTRIES := [
	{"id": "IND", "name": "COUNTRY_IND", "c1": "1f4fa3", "c2": "ff9933", "base": 86, "names": "in"},
	{"id": "IRN", "name": "COUNTRY_IRN", "c1": "f4f4f4", "c2": "239f40", "base": 84, "names": "ir"},
	{"id": "KOR", "name": "COUNTRY_KOR", "c1": "cd2e3a", "c2": "0047a0", "base": 78, "names": "kr"},
	{"id": "PAK", "name": "COUNTRY_PAK", "c1": "01411c", "c2": "f4f4f4", "base": 76, "names": "pk"},
	{"id": "BAN", "name": "COUNTRY_BAN", "c1": "006a4e", "c2": "f42a41", "base": 73, "names": "bd"},
	{"id": "KEN", "name": "COUNTRY_KEN", "c1": "bb0000", "c2": "006600", "base": 69, "names": "ke"},
	{"id": "JPN", "name": "COUNTRY_JPN", "c1": "bc002d", "c2": "f4f4f4", "base": 68, "names": "jp"},
	{"id": "ARG", "name": "COUNTRY_ARG", "c1": "74acdf", "c2": "f4f4f4", "base": 63, "names": "ar"},
	{"id": "NEP", "name": "COUNTRY_NEP", "c1": "dc143c", "c2": "003893", "base": 66, "names": "np"},
	{"id": "SRI", "name": "COUNTRY_SRI", "c1": "8d153a", "c2": "ffbe29", "base": 67, "names": "lk"},
	{"id": "THA", "name": "COUNTRY_THA", "c1": "2d2a4a", "c2": "a51931", "base": 64, "names": "th"},
	{"id": "POL", "name": "COUNTRY_POL", "c1": "f4f4f4", "c2": "dc143c", "base": 61, "names": "pl"},
]

const ARENAS := [
	{"id": "dome", "name": "ARENA_DOME", "desc": "ARENA_DOME_DESC"},
	{"id": "village", "name": "ARENA_VILLAGE", "desc": "ARENA_VILLAGE_DESC"},
	{"id": "stadium", "name": "ARENA_STADIUM", "desc": "ARENA_STADIUM_DESC"},
	{"id": "monsoon", "name": "ARENA_MONSOON", "desc": "ARENA_MONSOON_DESC"},
	{"id": "beach", "name": "ARENA_BEACH", "desc": "ARENA_BEACH_DESC"},
]

const STATES := ["STATE_HARYANA", "STATE_PUNJAB", "STATE_MAHARASHTRA", "STATE_TAMIL_NADU", "STATE_KARNATAKA", "STATE_TELANGANA", "STATE_ANDHRA", "STATE_BENGAL", "STATE_UP", "STATE_BIHAR", "STATE_RAJASTHAN", "STATE_KERALA", "STATE_GUJARAT", "STATE_DELHI", "STATE_HIMACHAL", "STATE_ODISHA"]

# Skin tones from light wheatish to deep brown, and hair colours.
const SKIN_TONES := ["e8b98f", "d6a07a", "c68863", "a86b4a", "8a5538", "6b3f28"]
const HAIR_COLORS := ["1a1410", "2b1d14", "3d2a1c", "5a4632"]

const FIRST_NAMES := {
	"north": ["Sandeep", "Naveen", "Ajay", "Vikas", "Ravinder", "Manjeet", "Sombir", "Ashu", "Mohit", "Vishal", "Parveen", "Jaideep", "Sachin", "Nitesh", "Amit", "Rakesh", "Sumit", "Yogesh", "Monu", "Rahul"],
	"punjab": ["Gurpreet", "Harjit", "Jaspal", "Manpreet", "Sukhwinder", "Karan", "Balwinder", "Amandeep", "Ravi", "Lovepreet"],
	"west": ["Siddhesh", "Aakash", "Omkar", "Tushar", "Shubham", "Vaibhav", "Pankaj", "Akshay", "Sagar", "Nilesh", "Rohan", "Ganesh"],
	"south": ["Selvamani", "Arun", "Prapanjan", "Karthik", "Vignesh", "Sagar", "Venkatesh", "Prashanth", "Manoj", "Harish", "Srinivas", "Darshan", "Sridhar", "Naveen"],
	"east": ["Sourav", "Arijit", "Subhankar", "Debashis", "Ranjit", "Sumanta", "Abhishek", "Bikash", "Ritam"],
	"central": ["Ashish", "Deepak", "Ankit", "Vivek", "Gaurav", "Shivam", "Pradeep", "Rajesh", "Mukesh", "Saurabh"],
}
const LAST_NAMES := {
	"north": ["Malik", "Dahiya", "Sangwan", "Rathi", "Kadian", "Hooda", "Dhull", "Nandal", "Sehgal", "Jakhar", "Lather", "Bura", "Gulia", "Rana"],
	"punjab": ["Gill", "Sandhu", "Brar", "Dhillon", "Sidhu", "Grewal", "Bajwa", "Virk"],
	"west": ["Patil", "Jadhav", "Pawar", "Shinde", "Kadam", "More", "Gaikwad", "Salunkhe", "Bhosale", "Desai", "Chavan"],
	"south": ["Selvam", "Murugan", "Arumugam", "Reddy", "Naidu", "Rao", "Gowda", "Shetty", "Hegde", "Nair", "Pillai", "Kumar"],
	"east": ["Das", "Ghosh", "Mondal", "Biswas", "Sarkar", "Pal", "Majhi", "Behera"],
	"central": ["Yadav", "Singh", "Kumar", "Tiwari", "Mishra", "Paswan", "Choudhary", "Meena", "Gurjar"],
}
const INTL_NAMES := {
	"in": [["Sandeep", "Naveen", "Arun", "Siddhesh", "Gurpreet", "Ashish", "Sourav", "Ravinder", "Karthik", "Omkar"], ["Malik", "Dahiya", "Patil", "Gill", "Reddy", "Yadav", "Ghosh", "Gowda", "Jadhav", "Rathi"]],
	"ir": [["Mohammad", "Reza", "Amir", "Hamid", "Ali", "Hossein", "Mehdi", "Saeed", "Omid", "Behnam"], ["Ahmadi", "Karimi", "Rahimi", "Hosseini", "Moradi", "Jafari", "Rostami", "Kazemi", "Sadeghi", "Farahani"]],
	"kr": [["Min-ho", "Ji-hoon", "Seung-woo", "Dong-hyun", "Jae-won", "Hyun-woo", "Sung-min", "Tae-yang"], ["Kim", "Park", "Choi", "Jung", "Kang", "Yoon", "Han", "Seo"]],
	"pk": [["Usman", "Bilal", "Hamza", "Waqas", "Imran", "Adeel", "Nasir", "Zeeshan"], ["Khan", "Butt", "Iqbal", "Raza", "Aslam", "Javed", "Shah", "Abbasi"]],
	"bd": [["Arif", "Mamun", "Rakib", "Sabbir", "Tanvir", "Jahid", "Nayeem", "Shakil"], ["Rahman", "Hossain", "Islam", "Ahmed", "Mia", "Sarker", "Uddin", "Chowdhury"]],
	"ke": [["Brian", "Kevin", "Dennis", "Collins", "Victor", "Felix", "Edwin", "Moses"], ["Otieno", "Kiprop", "Mwangi", "Wanjala", "Ochieng", "Kamau", "Mutua", "Njoroge"]],
	"jp": [["Takumi", "Haruto", "Ren", "Daiki", "Kenta", "Shota", "Yuto", "Ryo"], ["Sato", "Suzuki", "Takahashi", "Tanaka", "Ito", "Watanabe", "Yamamoto", "Kato"]],
	"ar": [["Matias", "Nicolas", "Santiago", "Joaquin", "Facundo", "Lucas", "Tomas", "Agustin"], ["Gonzalez", "Fernandez", "Lopez", "Martinez", "Romero", "Sosa", "Alvarez", "Diaz"]],
	"np": [["Bikash", "Suman", "Rajan", "Prakash", "Anil", "Dipak", "Kiran", "Sujan"], ["Thapa", "Gurung", "Shrestha", "Rai", "Magar", "Tamang", "Karki", "Adhikari"]],
	"lk": [["Kasun", "Nuwan", "Chamara", "Dinesh", "Lahiru", "Isuru", "Tharindu", "Ruwan"], ["Perera", "Fernando", "Silva", "Jayasuriya", "Bandara", "Dissanayake", "Wickrama", "Gunawardena"]],
	"th": [["Somchai", "Anan", "Krit", "Niran", "Prasert", "Chaiya", "Kittisak", "Wichai"], ["Srisuk", "Boonmee", "Chaiyaporn", "Thongdee", "Saelim", "Kaewkla", "Rattana", "Wongsa"]],
	"pl": [["Jakub", "Kacper", "Mateusz", "Piotr", "Michal", "Tomasz", "Pawel", "Szymon"], ["Nowak", "Kowalski", "Wisniewski", "Wojcik", "Kaminski", "Lewandowski", "Zielinski", "Szymanski"]],
}
# Real star players; generated names must never match these exactly.
const BLOCKED_NAMES := ["Pardeep Narwal", "Pawan Sehrawat", "Naveen Kumar", "Maninder Singh", "Rahul Chaudhari", "Anup Kumar", "Ajay Thakur", "Deepak Hooda", "Sunil Kumar", "Surjeet Singh", "Manjeet Chhillar", "Rohit Kumar", "Siddharth Desai", "Arjun Deshwal", "Vikash Kandola", "Nitin Rawal", "Aslam Inamdar", "Sachin Tanwar", "Ashu Malik", "Pardeep Kumar", "Ravinder Pahal", "Sandeep Narwal", "Rakesh Kumar", "Ajay Kumar", "Vikas Kumar"]

var teams := {}        # id -> team dictionary
var league_ids: Array[String] = []
var country_ids: Array[String] = []


func _ready() -> void:
	_generate()


func _region_for_state(state: String) -> String:
	match state:
		"STATE_HARYANA", "STATE_DELHI", "STATE_HIMACHAL":
			return "north"
		"STATE_PUNJAB":
			return "punjab"
		"STATE_MAHARASHTRA", "STATE_GUJARAT", "STATE_RAJASTHAN":
			return "west"
		"STATE_TAMIL_NADU", "STATE_KARNATAKA", "STATE_TELANGANA", "STATE_ANDHRA", "STATE_KERALA":
			return "south"
		"STATE_BENGAL", "STATE_ODISHA":
			return "east"
	return "central"


func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261007
	var used := {}
	for t in LEAGUE:
		var team := _make_team(t, "league")
		team.squad = _make_squad(rng, team, "league", t.state, used)
		teams[team.id] = team
		league_ids.append(team.id)
	for c in COUNTRIES:
		var team := _make_team(c, "country")
		team.squad = _make_squad(rng, team, c.names, "", used)
		teams[team.id] = team
		country_ids.append(team.id)


func _make_team(src: Dictionary, kind: String) -> Dictionary:
	return {
		"id": src.id,
		"name": src.name,
		"kind": kind,
		"c1": Color(src.c1),
		"c2": Color(src.c2),
		"base": int(src.base),
		"state": src.get("state", ""),
		"squad": [],
	}


func _make_name(rng: RandomNumberGenerator, pool: String, state: String, used: Dictionary) -> String:
	for attempt in 50:
		var first: String
		var last: String
		if pool == "league":
			# Two in three players come from the franchise's region; the rest from anywhere.
			var region: String = _region_for_state(state) if rng.randf() < 0.65 else FIRST_NAMES.keys()[rng.randi() % FIRST_NAMES.size()]
			var firsts: Array = FIRST_NAMES[region]
			var lasts: Array = LAST_NAMES[region]
			first = firsts[rng.randi() % firsts.size()]
			last = lasts[rng.randi() % lasts.size()]
		else:
			var lists: Array = INTL_NAMES[pool]
			first = lists[0][rng.randi() % lists[0].size()]
			last = lists[1][rng.randi() % lists[1].size()]
		var full := "%s %s" % [first, last]
		if not used.has(full) and not BLOCKED_NAMES.has(full):
			used[full] = true
			return full
	return "Player %d" % rng.randi_range(100, 999)


func _make_squad(rng: RandomNumberGenerator, team: Dictionary, pool: String, state: String, used: Dictionary) -> Array:
	var squad := []
	# 12-man squad: 4 raiders, 2 all-rounders, 6 defenders.
	var roles := ["raider", "raider", "raider", "raider", "allrounder", "allrounder", "defender", "defender", "defender", "defender", "defender", "defender"]
	var numbers := []
	for i in roles.size():
		var star := 8 if i == 0 or i == 6 else 0
		var p := make_player(rng, roles[i], team.base + star - i / 3, _make_name(rng, pool, state, used))
		var num := rng.randi_range(1, 99)
		while numbers.has(num):
			num = rng.randi_range(1, 99)
		numbers.append(num)
		p.number = num
		p.team = team.id
		p.id = "%s_%d" % [team.id, i]
		if pool != "league" and pool != "in":
			p.skin = rng.randi_range(0, 3) if pool in ["ir", "kr", "jp", "ar", "pl", "th"] else rng.randi_range(2, 5)
		squad.append(p)
	return squad


func make_player(rng: RandomNumberGenerator, role: String, level: int, pname: String) -> Dictionary:
	var a := {}
	for k in ATTRS:
		a[k] = clampi(level + rng.randi_range(-9, 7), 35, 97)
	match role:
		"raider":
			a.agility = clampi(a.agility + 7, 35, 99)
			a.reach = clampi(a.reach + 6, 35, 99)
			a.speed = clampi(a.speed + 4, 35, 99)
			a.tackle = clampi(a.tackle - 12, 30, 99)
		"defender":
			a.tackle = clampi(a.tackle + 8, 35, 99)
			a.strength = clampi(a.strength + 6, 35, 99)
			a.reach = clampi(a.reach - 8, 30, 99)
	return {
		"id": "",
		"name": pname,
		"role": role,
		"attrs": a,
		"number": 7,
		"team": "",
		"skin": rng.randi_range(0, 5),
		"hair": rng.randi_range(0, 3),
		"build": rng.randf_range(0.92, 1.1),
		"height": rng.randf_range(1.70, 1.88),
	}


# ---------------------------------------------------------------- queries

func team(id: String) -> Dictionary:
	return teams.get(id, {})


func team_name(id: String) -> String:
	var t := team(id)
	if t.is_empty():
		return id
	return tr(t.name) if t.kind == "country" else String(t.name)


static func overall(p: Dictionary) -> int:
	var a: Dictionary = p.attrs
	var raid_v: float = a.speed * 0.2 + a.agility * 0.3 + a.reach * 0.3 + a.stamina * 0.1 + a.strength * 0.1
	var def_v: float = a.tackle * 0.4 + a.strength * 0.3 + a.agility * 0.1 + a.speed * 0.1 + a.stamina * 0.1
	match String(p.role):
		"raider":
			return int(round(raid_v))
		"defender":
			return int(round(def_v))
	return int(round(maxf(raid_v, def_v) * 0.8 + minf(raid_v, def_v) * 0.2))


## The seven who start: best two raiders, best all-rounder, best four defenders.
func starting_seven(squad: Array) -> Array:
	var by_role := {"raider": [], "allrounder": [], "defender": []}
	for p in squad:
		by_role[p.role].append(p)
	for k in by_role:
		by_role[k].sort_custom(func(x, y): return overall(x) > overall(y))
	var seven := []
	seven.append_array(by_role.raider.slice(0, 2))
	seven.append_array(by_role.allrounder.slice(0, 1))
	seven.append_array(by_role.defender.slice(0, 4))
	var rest := []
	for k in by_role:
		for p in by_role[k]:
			if not seven.has(p):
				rest.append(p)
	rest.sort_custom(func(x, y): return overall(x) > overall(y))
	while seven.size() < 7 and rest.size() > 0:
		seven.append(rest.pop_front())
	return seven


func team_rating(squad: Array) -> int:
	var seven := starting_seven(squad)
	if seven.is_empty():
		return 50
	var total := 0
	for p in seven:
		total += overall(p)
	return int(round(float(total) / seven.size()))


## Quick result for matches the player does not play. PKL-style scores land in the 25-45 range.
func simulate(home_rating: int, away_rating: int, rng: RandomNumberGenerator, knockout := false) -> Array:
	var diff := float(home_rating - away_rating)
	var h := int(round(rng.randfn(33.0 + diff * 0.55, 6.0)))
	var a := int(round(rng.randfn(33.0 - diff * 0.55, 6.0)))
	h = clampi(h, 14, 62)
	a = clampi(a, 14, 62)
	if knockout and h == a:
		# Golden raid decides it.
		if rng.randf() < 0.5 + diff * 0.02:
			h += 1
		else:
			a += 1
	return [h, a]


## Kit colours for a fixture: away side switches to its second kit if the colours clash.
func kits(home_id: String, away_id: String) -> Array:
	var h := team(home_id)
	var a := team(away_id)
	var hc: Color = h.c1
	var ac: Color = a.c1
	if _close(hc, ac):
		ac = a.c2
		if _close(hc, ac):
			ac = Color("f3efe6") if hc.get_luminance() < 0.6 else Color("1b1b1b")
	return [hc, ac]


func _close(x: Color, y: Color) -> bool:
	var dh := absf(x.h - y.h)
	dh = minf(dh, 1.0 - dh)
	var dl := absf(x.get_luminance() - y.get_luminance())
	return (dh < 0.08 and dl < 0.25) or (x.s < 0.2 and y.s < 0.2 and dl < 0.3)
