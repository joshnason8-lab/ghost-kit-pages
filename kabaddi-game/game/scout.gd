class_name Scout
extends RefCounted
## What a franchise's staff know about a player and a squad: his place on the mat, his age and how he will grow,
## his strengths in plain words, a squad's gaps, how well a player fills them, and his form.

const SLOTS := ["raider", "allrounder", "corner", "cover"]
const SLOT_KEYS := {"raider": "SLOT_RAIDER", "allrounder": "SLOT_ALLROUNDER", "corner": "SLOT_CORNER", "cover": "SLOT_COVER"}
## A twelve-man squad as the franchises build theirs: four raiders, two all-rounders, three corners, three covers.
const SHAPE := {"raider": 4, "allrounder": 2, "corner": 3, "cover": 3}
## Points a player brings in a match, by role, for his form: raid and tackle points together.
const EXPECTED := {"raider": 7.0, "allrounder": 4.0, "defender": 2.0}


## Where he plays: raider, all-rounder, or, for a defender, corner (the ankle and thigh holds and the dash, made
## from the ends of the line) or cover (the waist hold, the block and the chain, from its middle).
static func slot(p: Dictionary) -> String:
	match String(p.get("role", "")):
		"raider":
			return "raider"
		"allrounder":
			return "allrounder"
	return "corner" if DB.def_signature(p) in ["ankle", "thigh", "dash"] else "cover"


static func slot_name(p: Dictionary) -> String:
	return TranslationServer.translate(SLOT_KEYS[slot(p)])


## His age. Players made before ages were kept get one from who they are: 21 to 31, the best of them past 23.
static func age(p: Dictionary) -> int:
	if p.has("age"):
		return int(p.age)
	var h := absi(hash("%s|%s|age" % [p.get("name", ""), p.get("id", "")]))
	var a := 21 + h % 11
	if DB.overall(p) >= 80:
		a = maxi(a, 24)
	return a


## How far he can still come, 0 to 1 (players made before it was kept get one from who they are).
static func potential(p: Dictionary) -> float:
	if p.has("pot"):
		return float(p.pot)
	return float(absi(hash("%s|%s|pot" % [p.get("name", ""), p.get("id", "")])) % 1000) / 1000.0


## A season older: his ratings move with his age and potential (young players grow, older ones slow), and the
## moves worked out from them are worked out again. Returns the change in his overall rating.
static func develop(p: Dictionary, rng: RandomNumberGenerator) -> int:
	var before := DB.overall(p)
	var a := age(p)
	var pot := potential(p)
	var lo := 0.0
	var hi := 0.0
	if a <= 20:
		lo = 2.0
		hi = 5.0
	elif a <= 23:
		lo = 1.0
		hi = 4.0
	elif a <= 27:
		lo = -1.0
		hi = 2.0
	elif a <= 30:
		lo = -2.0
		hi = 1.0
	elif a <= 32:
		lo = -3.0
		hi = 0.0
	else:
		lo = -4.0
		hi = -1.0
	var scale := 0.5 + pot if hi > 0.0 else 1.0
	for k in DB.ATTRS:
		var d := rng.randf_range(lo, hi) * (scale if hi > 0.0 else 1.0)
		p.attrs[k] = clampi(int(p.attrs[k]) + int(round(d)), 30, 99)
	p.age = a + 1
	p.pot = pot
	p.erase("moves")
	p.erase("dmoves")
	DB.moves(p)
	DB.def_moves(p)
	return DB.overall(p) - before


## Whether he calls it a day at the end of a season: from 33 on, more likely each year, always by 37.
static func retires(p: Dictionary, rng: RandomNumberGenerator) -> bool:
	var a := age(p)
	if a < 33:
		return false
	return rng.randf() < [0.15, 0.3, 0.5, 0.8, 1.0][mini(a - 33, 4)]


## What he is good at, in a few words: up to two of his strengths, and a weakness if he has a plain one.
static func strengths(p: Dictionary) -> Array:
	var out := []
	var a: Dictionary = p.attrs
	var role := String(p.get("role", ""))
	if role != "defender":
		var m := DB.moves(p)
		var best := DB.signature(p)
		if int(m[best]) >= 80:
			out.append(TranslationServer.translate("STRENGTH_ELITE_MOVE").format({"move": TranslationServer.translate(DB.MOVE_KEYS[best])}))
	if role != "raider":
		var dm := DB.def_moves(p)
		var dbest := DB.def_signature(p)
		if int(dm[dbest]) >= 78:
			out.append(TranslationServer.translate("STRENGTH_SPECIALIST").format({"move": TranslationServer.translate(DB.STYLE_KEYS[dbest])}))
	var traits := [["speed", 84, "STRENGTH_QUICK"], ["agility", 84, "STRENGTH_SLIPPERY"], ["reach", 84, "STRENGTH_REACH"],
		["strength", 84, "STRENGTH_POWER"], ["tackle", 86, "STRENGTH_TACKLER"], ["stamina", 84, "STRENGTH_TIRELESS"]]
	traits.sort_custom(func(x, y): return int(a[x[0]]) > int(a[y[0]]))
	for t in traits:
		if out.size() >= 2:
			break
		if int(a[t[0]]) >= int(t[1]) and not (role == "raider" and t[0] == "tackle"):
			out.append(TranslationServer.translate(t[2]))
	if int(a.stamina) < 55:
		out.append(TranslationServer.translate("WEAKNESS_TIRES"))
	elif age(p) >= 32:
		out.append(TranslationServer.translate("WEAKNESS_AGE"))
	return out


## How many of each slot a squad is short of its shape, and whether it lacks a star raider (none rated 80 or more).
static func needs(squad: Array) -> Dictionary:
	var have := {"raider": 0, "allrounder": 0, "corner": 0, "cover": 0}
	var star := false
	for p in squad:
		have[slot(p)] += 1
		if String(p.role) == "raider" and DB.overall(p) >= 80:
			star = true
	var out := {}
	for s in SLOTS:
		out[s] = maxi(0, int(SHAPE[s]) - int(have[s]))
	out["star"] = not star
	return out


## The needs in words ("a star raider, 1 raider, 2 corners"), the star first.
static func needs_text(n: Dictionary) -> String:
	var parts := []
	if bool(n.get("star", false)):
		parts.append(TranslationServer.translate("NEED_STAR_RAIDER"))
	for s in SLOTS:
		var c := int(n.get(s, 0))
		if c > 0:
			parts.append(TranslationServer.translate(("NEED_1_" if c == 1 else "NEED_N_") + s.to_upper()).format({"n": c}))
	if parts.is_empty():
		return TranslationServer.translate("NEED_NOTHING")
	return ", ".join(parts)


## How well a player suits a squad, 0 to 3 stars: a place it is short of, and better than who plays there now.
static func fit(p: Dictionary, squad: Array) -> int:
	var n := needs(squad)
	var s := slot(p)
	var o := DB.overall(p)
	var best_there := 0
	for q in squad:
		if slot(q) == s:
			best_there = maxi(best_there, DB.overall(q))
	var stars := 0
	if int(n.get(s, 0)) > 0:
		stars += 1
	if o > best_there:
		stars += 1
	if bool(n.get("star", false)) and s == "raider" and o >= 80:
		stars += 1
	elif o >= 78 or (age(p) <= 21 and potential(p) >= 0.6):
		stars += 1
	return mini(stars, 3)


## Form from his last matches' points (newest last): 1 hot, 0 steady, -1 cold.
static func form(points: Array, role: String) -> int:
	if points.size() < 2:
		return 0
	var last := points.slice(-3)
	var sum := 0.0
	for x in last:
		sum += float(x)
	var avg := sum / last.size()
	var exp: float = EXPECTED.get(role, 3.0)
	if avg >= exp * 1.4:
		return 1
	if avg <= exp * 0.5:
		return -1
	return 0
