class_name AuctionEngine
extends RefCounted
## A player auction modelled on the real pro-league ones.
##
## - Players go under the hammer by category (A, B, C, D) with category base prices, then the
##   New Young Players (NYP).
## - Paddles go up in rising increments; "going once, going twice" resets on every new bid.
## - Each franchise holds Final Bid Match (FBM) cards: when one of its players from last season
##   is sold elsewhere, it may match the final price and keep him.
## - Unsold players return in an accelerated round at a reduced base price.
## - Purses are hard caps, squads have a maximum size, and teams bid for the roles they lack.
##
## The screen drives it: call step() regularly; it returns events to show.

const CATEGORIES := {"A": 30.0, "B": 20.0, "C": 13.0, "D": 9.0, "NYP": 6.0}
const SQUAD_MAX := 12
const HAMMER_ONCE := 1.6
const HAMMER_TWICE := 3.0
const HAMMER_SOLD := 4.2

var lots: Array = []            # {player, cat, base, ovr, former, mine, status, sold_to, price, round}
var teams := {}                 # id -> {purse, squad: Array, fbm: int}
var user_team := ""             # owner mode: the franchise you bid for ("" to watch)
var index := 0
var round_no := 1
var record := 0.0
var record_holder := ""
var rng := RandomNumberGenerator.new()

# Live lot state.
var price := 0.0
var leader := ""
var bids := 0
var idle := 0.0                 # seconds since the last bid
var last_bidders: Array = []
var stage := "open"             # open, once, twice, fbm_offer, done
var war_announced := false
var _next_ai := 0.6


static func category_for(ovr: int) -> String:
	if ovr >= 80:
		return "A"
	if ovr >= 72:
		return "B"
	if ovr >= 64:
		return "C"
	return "D"


static func increment(p: float) -> float:
	if p < 50.0:
		return 2.0
	if p < 100.0:
		return 5.0
	if p < 200.0:
		return 10.0
	return 20.0


func add_lot(player: Dictionary, former: String, nyp := false, mine := false) -> void:
	var o := DB.overall(player)
	var cat := "NYP" if nyp else category_for(o)
	lots.append({"player": player, "cat": cat, "base": CATEGORIES[cat], "ovr": o, "former": former,
		"mine": mine, "status": "waiting", "sold_to": "", "price": 0.0, "round": 1})


## Order lots like the real thing: A first, then B, C, D, and the young players last.
func sort_lots() -> void:
	var order := {"A": 0, "B": 1, "C": 2, "D": 3, "NYP": 4}
	lots.sort_custom(func(a, b): return order[a.cat] < order[b.cat] or (order[a.cat] == order[b.cat] and a.ovr > b.ovr))


func current() -> Dictionary:
	return lots[index] if index < lots.size() else {}


func finished() -> bool:
	return index >= lots.size()


func open_lot() -> Dictionary:
	var lot := current()
	if lot.is_empty():
		return {}
	lot.status = "open"
	price = float(lot.base)
	leader = ""
	bids = 0
	idle = 0.0
	stage = "open"
	last_bidders = []
	war_announced = false
	_next_ai = rng.randf_range(0.5, 1.3)
	return {"type": "open", "lot": lot}


func next_price() -> float:
	return price if leader == "" else price + increment(price)


func can_bid(team_id: String) -> bool:
	if team_id == "" or team_id == leader:
		return false
	var t: Dictionary = teams[team_id]
	return t.squad.size() < SQUAD_MAX and float(t.purse) >= next_price() and stage in ["open", "once", "twice"]


func place_bid(team_id: String) -> Dictionary:
	if not can_bid(team_id):
		return {}
	price = next_price()
	leader = team_id
	bids += 1
	idle = 0.0
	stage = "open"
	last_bidders.append(team_id)
	var ev := {"type": "bid", "team": team_id, "price": price}
	# Two franchises going back and forth is a bidding war.
	if not war_announced and last_bidders.size() >= 6:
		var tail: Array = last_bidders.slice(-6)
		var distinct := {}
		for t in tail:
			distinct[t] = true
		if distinct.size() == 2:
			war_announced = true
			ev["war"] = distinct.keys()
	return ev


## What a franchise thinks a player is worth, in lakhs.
func valuation(team_id: String, lot: Dictionary) -> float:
	var t: Dictionary = teams[team_id]
	var r := RandomNumberGenerator.new()
	r.seed = hash(team_id + String(lot.player.name)) + round_no
	var o: float = lot.ovr
	var v := pow(maxf(0.0, o - 48.0), 1.62) * 0.9
	if lot.cat == "NYP":
		v *= 0.6
	# Need: teams short of a role pay more for it.
	var have := 0
	for p in t.squad:
		if (p.role == "defender") == (lot.player.role == "defender"):
			have += 1
	v *= 1.35 if have < 5 else (1.0 if have < 7 else 0.6)
	# Former team sentiment.
	if lot.former == team_id:
		v *= 1.15
	# Keep enough purse to fill the squad.
	var slots_left = SQUAD_MAX - t.squad.size()
	var reserve := maxf(0.0, (slots_left - 1) * 8.0)
	v = minf(v, float(t.purse) - reserve)
	return v * r.randf_range(0.75, 1.3)


## Advance time. Returns a list of events for the screen to show.
func step(dt: float) -> Array:
	var out := []
	if finished() or stage in ["fbm_offer", "done"]:
		return out
	idle += dt
	_next_ai -= dt
	var lot := current()
	if _next_ai <= 0.0:
		_next_ai = rng.randf_range(0.35, 1.2)
		var keen := []
		for id in teams.keys():
			if id == user_team or not can_bid(id):
				continue
			if valuation(id, lot) >= next_price():
				keen.append(id)
		if not keen.is_empty():
			# Slightly favour the last team that was outbid, which makes for real duels.
			var pick: String = keen[rng.randi() % keen.size()]
			if last_bidders.size() >= 2 and keen.has(last_bidders[-2]) and rng.randf() < 0.55:
				pick = last_bidders[-2]
			var ev := place_bid(pick)
			if not ev.is_empty():
				out.append(ev)
				return out
	# The hammer.
	if leader == "" and idle >= HAMMER_SOLD:
		out.append(_unsold())
	elif leader != "":
		if stage == "open" and idle >= HAMMER_ONCE:
			stage = "once"
			out.append({"type": "once"})
		elif stage == "once" and idle >= HAMMER_TWICE:
			stage = "twice"
			out.append({"type": "twice"})
		elif stage == "twice" and idle >= HAMMER_SOLD:
			out.append_array(_hammer())
	return out


func _hammer() -> Array:
	var out := []
	var lot := current()
	var former: String = lot.former
	# Final Bid Match: the player's old team may match the winning price.
	if former != "" and former != leader and teams.has(former) and int(teams[former].fbm) > 0 \
			and float(teams[former].purse) >= price and teams[former].squad.size() < SQUAD_MAX:
		if former == user_team:
			stage = "fbm_offer"
			out.append({"type": "fbm_offer", "team": former, "price": price})
			return out
		if valuation(former, lot) >= price * 0.9:
			teams[former].fbm = int(teams[former].fbm) - 1
			out.append({"type": "fbm", "team": former, "price": price, "from": leader})
			leader = former
	out.append(_sell())
	return out


## The user answers an FBM offer.
func answer_fbm(use: bool) -> Array:
	var out := []
	if stage != "fbm_offer":
		return out
	if use:
		teams[user_team].fbm = int(teams[user_team].fbm) - 1
		out.append({"type": "fbm", "team": user_team, "price": price, "from": leader})
		leader = user_team
	out.append(_sell())
	return out


func _sell() -> Dictionary:
	var lot := current()
	lot.status = "sold"
	lot.sold_to = leader
	lot.price = price
	var t: Dictionary = teams[leader]
	t.purse = float(t.purse) - price
	var p: Dictionary = lot.player.duplicate(true)
	p.team = leader
	t.squad.append(p)
	var ev := {"type": "sold", "team": leader, "price": price, "lot": lot}
	if price > record:
		if record > 0.0:
			ev["record"] = true
		record = price
		record_holder = String(lot.player.name)
	stage = "done"
	return ev


func _unsold() -> Dictionary:
	var lot := current()
	lot.status = "unsold"
	stage = "done"
	return {"type": "unsold", "lot": lot}


## Move on. Starts the accelerated round once the main list is done.
func next_lot() -> Dictionary:
	index += 1
	if finished() and round_no == 1:
		var again := []
		for l in lots:
			if l.status == "unsold" and not l.mine:
				var copy: Dictionary = l.duplicate()
				copy.base = maxf(5.0, float(l.base) * 0.7)
				copy["round"] = 2
				copy.status = "waiting"
				again.append(copy)
			elif l.status == "unsold" and l.mine:
				var mine: Dictionary = l.duplicate()
				mine.base = maxf(5.0, float(l.base) * 0.7)
				mine["round"] = 2
				mine.status = "waiting"
				again.append(mine)
		if not again.is_empty():
			round_no = 2
			lots.append_array(again)
			return {"type": "accelerated", "count": again.size()}
	return {}


## Finish everything instantly (skip buttons and simulation).
func resolve_all(stop_at_mine := false) -> void:
	var guard := 0
	while not finished() and guard < 2000:
		guard += 1
		var lot := current()
		if stop_at_mine and lot.mine and lot.status == "waiting":
			return
		if lot.status == "waiting":
			open_lot()
		var inner := 0
		while stage not in ["done"] and inner < 400:
			inner += 1
			if stage == "fbm_offer":
				answer_fbm(false)
				break
			step(0.5)
		next_lot()
