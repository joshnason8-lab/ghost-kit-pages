extends Node
## The teams, the courts and the players' names. Teams are towns, by their place names only, with nicknames of the
## game's own (an animal, a tree or a bird of the place): no real club, league or body is named (docs/CULTURE.md).
## Players are invented: a given name and a family name common in the region, put together at random.

## id, town, region (country), nickname, faja colour, trim colour, home skin tone (0-3), region key for names.
const TEAMS := [
	["ESC", "Escuinapa", "Sinaloa", "Garzas", "e8e2d4", "2f6b9a", 1, "sin"],
	["LLA", "Los Llanitos", "Sinaloa", "Huizaches", "b8352b", "e9c46a", 2, "sin"],
	["SAV", "La Sávila", "Sinaloa", "Coyotes", "d98b3a", "2b2118", 1, "sin"],
	["QUE", "El Quelite", "Sinaloa", "Pitayas", "a3245a", "f1e3c8", 2, "sin"],
	["VUN", "Villa Unión", "Sinaloa", "Iguanas", "3c8f5a", "f2e6c9", 1, "sin"],
	["CHL", "El Chilillo", "Sinaloa", "Chachalacas", "6b4a2f", "e0b45a", 2, "sin"],
	["MOR", "La Mora Escarbada", "Sinaloa", "Mezquites", "2e4a7a", "d9c8a0", 1, "sin"],
	["ROS", "El Rosario", "Sinaloa", "Pelícanos", "1f7f86", "f4efe2", 1, "sin"],
	["PIS", "Pisté", "Yucatán", "K'iin", "e2a22c", "8a2b1d", 3, "may"],
	["VAL", "Valladolid", "Yucatán", "Ya'axche'", "2f7d4f", "f0e4c4", 3, "may"],
	["IZA", "Izamal", "Yucatán", "Henequeneros", "e7c34a", "f7f3e8", 2, "may"],
	["FCP", "Felipe Carrillo Puerto", "Quintana Roo", "Chicozapotes", "7a3b2a", "e6d2a8", 3, "may"],
	["PAL", "Palenque", "Chiapas", "Saraguatos", "34465e", "c9a24e", 2, "may"],
	["FLO", "Flores", "Guatemala", "Quetzales", "1e8c6e", "c8322c", 3, "gua"],
	["ORW", "Orange Walk", "Belize", "Toucans", "f0b429", "1d1d1d", 3, "bel"],
	["COP", "Copán Ruinas", "Honduras", "Guacamayas", "c0392b", "2e86c1", 2, "gua"],
]

## Courts: id, the rules played there, the sky, the time of day, the floor's surface.
const VENUES := {
	"village": {"rules": "ulama", "sky": "qwantani_dusk_2_puresky", "time": "dusk", "floor": "earth", "region": "sin"},
	"festival": {"rules": "ulama", "sky": "kloofendal_48d_partly_cloudy_puresky", "time": "day", "floor": "earth", "region": "sin"},
	"stone": {"rules": "classic", "sky": "qwantani_noon_puresky", "time": "day", "floor": "stone", "region": "may"},
	"night": {"rules": "classic", "sky": "kloppenheim_02_puresky", "time": "night", "floor": "stone", "region": "may"},
}
const VENUE_ORDER := ["village", "festival", "stone", "night"]

const GIVEN := ["Juan", "José", "Jesús", "Ramón", "Rafael", "Óscar", "Héctor", "Luis", "Miguel", "Ángel", "Eduardo",
	"Saúl", "Martín", "Julio", "Gilberto", "Fermín", "Abel", "Rubén", "Isidro", "Cruz", "Lorenzo", "Teodoro", "Efraín",
	"Manuel", "Alfredo", "Ernesto", "Rogelio", "Arturo", "Pedro", "Samuel", "Ismael", "Gerardo", "Antonio", "Felipe"]
const FAMILY := {
	"sin": ["Osuna", "Lizárraga", "Tirado", "Zamudio", "Ibarra", "Bernal", "Félix", "Sánchez", "Rodríguez", "Medina",
		"Tostado", "Valdez", "Quintero", "Loaiza", "Velarde", "Aguirre", "Crespo", "Rendón", "Gamboa", "Ontiveros"],
	"may": ["Pech", "Chan", "Canul", "May", "Uc", "Poot", "Ek", "Cocom", "Dzib", "Tun", "Couoh", "Chi", "Ku", "Balam",
		"Cauich", "Moo", "Kú", "Xool", "Pat", "Euán"],
	"gua": ["López", "Pérez", "Tzul", "Coc", "Xol", "Caal", "Choc", "Ramírez", "Sic", "Cac", "Mejía", "Orellana",
		"Ac", "Bol", "Chub", "Pop", "Tiul", "García", "Hernández", "Matul"],
	"bel": ["Cal", "Coc", "Shol", "Tzib", "Chan", "Pott", "Coy", "Bautista", "Novelo", "Ical", "Salam", "Mai", "Choco",
		"Pop", "Teck", "Reyes", "Castillo", "Itza", "Uck", "Sosa"],
}
## Skin tones, from lighter to darker, and hair (black, with a little brown).
const SKINS := [Color("b88a64"), Color("a2724e"), Color("8c603f"), Color("764e33")]
const HAIRS := [Color("120e0b"), Color("1b1410"), Color("241a13")]


func team(id: String) -> Dictionary:
	for t in TEAMS:
		if t[0] == id:
			return {"id": t[0], "town": t[1], "region": t[2], "nick": t[3], "c1": Color(t[4]), "c2": Color(t[5]),
				"skin": int(t[6]), "names": t[7], "design": 0}
	return {"id": id, "town": id, "region": "", "nick": "", "c1": Color.WHITE, "c2": Color.BLACK, "skin": 1, "names": "sin", "design": 0}


func ids() -> Array:
	return TEAMS.map(func(t): return t[0])


## "Escuinapa" (the town: what a list shows) and "Garzas de Escuinapa"-style long names are made by the UI.
func team_name(id: String) -> String:
	return String(team(id).town)


func short_name(id: String) -> String:
	return String(team(id).town)


func nick(id: String) -> String:
	return String(team(id).nick)


## A team's players: n of them, with names, looks and skills, the same every time for the same team (seeded by its
## id), the best of them a little better at a higher level.
func roster(id: String, n: int, kind := "ulama") -> Array:
	var t := team(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id + "players")
	var fam: Array = FAMILY.get(String(t.names), FAMILY.sin)
	var out := []
	var used := {}
	for i in 6:
		var g: String = GIVEN[rng.randi_range(0, GIVEN.size() - 1)]
		var f: String = fam[rng.randi_range(0, fam.size() - 1)]
		var key := g.left(1) + f
		var guard := 0
		while used.has(key) and guard < 20:
			f = fam[rng.randi_range(0, fam.size() - 1)]
			key = g.left(1) + f
			guard += 1
		used[key] = true
		var tone := clampi(int(t.skin) + rng.randi_range(-1, 1), 0, SKINS.size() - 1)
		var look := {
			"kind": kind,
			"skin": (SKINS[tone] as Color).lerp(SKINS[mini(tone + 1, 3)], rng.randf() * 0.5),
			"hair": HAIRS[rng.randi_range(0, HAIRS.size() - 1)],
			"team": t.c1, "trim": t.c2,
			"band": rng.randf() < 0.35,
			"height": rng.randf_range(1.62, 1.8),
			"build": rng.randf(),
		}
		out.append({"name": "%s. %s" % [g.left(1), f], "full": "%s %s" % [g, f], "look": look,
			"skill": rng.randf_range(0.45, 0.9), "power": rng.randf_range(0.45, 0.9), "speed": rng.randf_range(5.4, 6.6)})
	# The two best play deepest and at the front (the chivero and the malero carry a side).
	return out.slice(0, n)


## The team's strength, 0-1: what the simulated results use.
func strength(id: String) -> float:
	var s := 0.0
	for p in roster(id, 5):
		s += float(p.skill) * 0.6 + float(p.power) * 0.4
	return s / 5.0


func venue(id: String) -> Dictionary:
	return VENUES.get(id, VENUES.village)


func venues_for(rules: String) -> Array:
	return VENUE_ORDER.filter(func(v): return String(VENUES[v].rules) == rules)


## Teams that fit a court's rules first (the Sinaloa towns for ulama, the Maya towns for the stone court), then the rest.
func teams_for(rules: String) -> Array:
	var near := []
	var rest := []
	for t in TEAMS:
		if (String(t[7]) == "sin") == (rules == "ulama"):
			near.append(t[0])
		else:
			rest.append(t[0])
	return near + rest
