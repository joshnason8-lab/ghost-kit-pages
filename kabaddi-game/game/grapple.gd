class_name Grapple
extends RefCounted
## A raider in defenders' hands, from the first real contact to the end of the takedown or the escape: who
## holds him and where, what each hold does to both bodies, and the hands and feet that have to meet.
##
## Its states follow the players' own (Athlete.state) rather than duplicating them: a defender goes
## "telegraph" (winding up) -> "dive" (attempting) -> contact, checked here on the bodies as drawn ->
## "holding"; the raider goes "held". It ends in a takedown (the raider "fallen", the holders getting up
## before they celebrate) or an escape (the hold let go).
##
## Holds are made on slots of the raider's body, one defender each: a leg each ("leg_l", "leg_r"), round his
## middle from behind ("back") and from the front ("front"). How a hold is drawn (its style) follows the
## tackle: "ankle" (lying on the floor, hands round the ankle and lower shin), "thigh" (down low, arms round
## the thigh above the knee), "waist" (arms round his middle) and "block" (chest to chest, arms round him).
## A held leg's foot stays where it was caught, so the raider has to stretch away from it, and only at full
## stretch does he drag it (and the holder) along the floor. Each holder's body is brought in, no faster
## than a body is dragged, to keep his reach on his slot, and his arms reach the rest of the way
## (RiggedBody.hand_target). Team-mates coming to help claim a free slot first, so no two go for the same.
##
## A hold is worked, not just kept: each holder hauls in his own rhythm (PULL_PERIOD), each haul drawing a held
## leg back toward him and lifting it a little, his arms bending as he pulls. The raider is pulled back on
## each haul and loses his balance a little more (progress, the struggle the match keeps, raid.progress): the
## bodies show both (Athlete.balance, tug, haul; HumanModel._apply_struggle), so the takedown is where the
## struggle was going, not a fall out of a still pose.

const SLOTS := ["leg_l", "leg_r", "back", "front"]
const CONTACT_R := 0.3         # m: a hand this close to the part a dive goes for grips it
const BODY_R := 0.12           # m: the raider's middle is this thick round its centre line, for waist holds
const LEG_REACH := 0.55        # m from the hips (flat) to a held foot: further and he drags it
const BODY_FOLLOW := 2.5       # m/s the holder's body may be moved, beyond the drag itself, to keep his reach
const LET_GO := 0.15           # s for the hands to come off when a hold breaks
const TRIP_HOLD := 0.7         # s the holders keep hold while a tackled raider goes down
const ARMS_OUT := 0.3          # share of a dive after which the arms are out and can grip
const CLOSE_IN := 0.2          # s for a helper's hands to close on his slot as he takes hold
const MIN_GAP := 0.34          # m: no holder's middle (pelvis to lower back) comes closer to the raider's
const HOLDER_GAP := 0.42       # m: nor to another holder's
const CLAIM_TIME := 2.0        # s a claimed slot is kept for a helper on his way
const PULL_PERIOD := 0.9       # s from one haul to the next (each holder a little quicker or slower)
const PULL_UP := 0.3           # share of each cycle spent hauling; the rest easing off and taking a new grip
const PULL_START := 0.25       # s after taking hold before the first haul
const PULL_IN := 0.16          # m a haul draws a held leg back toward the holder, at full struggle
const PULL_LIFT := 0.09        # m a haul lifts a held foot off the floor, at full struggle
const ESTABLISH := 0.6         # s a hold needs before it can take part in bringing him down
# Where each style's hands go: [right hand part, left hand part]. Waist and block hands go round the sides.
const HANDS := {"ankle": ["ankle", "shin"], "thigh": ["thigh", "knee"], "waist": ["waist", "waist"], "block": ["waist", "waist"]}
# A helper can take hold from this far (his middle to the part, flat), facing it.
const REACH := {"ankle": 1.05, "thigh": 0.8, "waist": 0.62, "block": 0.62}
# How well each escape slips each hold (Match._raider_escape, _raider_dodge): a dubki ducks out of arms round
# his middle and can twist out of a thigh hold, but does nothing for a held ankle; a lion jump kicks free of an
# ankle hold and sometimes a thigh hold, but cannot clear arms locked round his middle; a sidestep twists out
# of a grip on his thigh or round him, not out of hands on his ankle.
const ESCAPES := {"dubki": {"waist": 1.0, "block": 1.0, "thigh": 0.35, "ankle": 0.0},
	"lion": {"ankle": 1.0, "thigh": 0.35, "waist": 0.0, "block": 0.0},
	"dodge": {"thigh": 1.0, "waist": 0.8, "block": 0.8, "ankle": 0.0}}

static var _next_id := 1

var id := 0
var raider: Athlete
var holds: Array = []          # {who, style, slot, at (world: where a held foot is kept), since, w (hands, 0..1)}
var claims := {}               # slot -> [Athlete on his way to it, seconds left]
var state := "holding"         # "holding" -> "takedown" -> "done"; or "holding" -> "done" when the last hold breaks
var chain_called := false      # "Chain tackle!" has been put up for this one
var t := 0.0
var progress := 0.0            # how far the struggle has gone, 0..1 (raid.progress, set by the match)


func _init(r: Athlete) -> void:
	id = _next_id
	_next_id += 1
	raider = r
	# The held raider is posed first each frame, so holders reach for where he is now.
	_priority(r, -1)


## The style of hold a tackle makes ("" for a tackle that does not hold, the dash).
static func style_of(kind: String) -> String:
	match kind:
		"ankle":
			return "ankle"
		"thigh", "chain":
			return "thigh"
		"waist":
			return "waist"
		"block":
			return "block"
	return ""


## A defender could take hold of the raider in this style now: his middle within that style's reach of the part
## (along the floor), plus a step (step, m), facing it. For a grab that is not a dive (grabbing back at a
## touch), whose hands have to get there from where he stands.
static func reachable(d: Athlete, r: Athlete, style: String, step := 0.0) -> bool:
	if d.model == null or r.model == null or not REACH.has(style):
		return false
	var at: Vector3
	if style in ["ankle", "thigh"]:
		var s := slot_for(style, d, r).substr(4)
		at = (r.model.anchor("thigh_" + s) + r.model.anchor("knee_" + s)) * 0.5 if style == "thigh" \
			else r.model.anchor("ankle_" + s)
	else:
		at = r.model.anchor("waist")
	var to := _flat(at - d.position)
	return to.length() < float(REACH[style]) + step and (to.length() < 0.2 or to.normalized().dot(d.facing) > 0.2)


## Of the holders, the one a move slips best, and how well: [holder, 0..1] (ESCAPES); [null, 0] for none.
func best_escape(move: String, holders: Array) -> Array:
	var fits: Dictionary = ESCAPES.get(move, {})
	var best: Athlete = null
	var fit := 0.0
	for x in holders:
		var f := float(fits.get(style_of_hold(x), 0.0))
		if best == null or f > fit:
			best = x
			fit = f
	return [best, fit]


## Which slot a defender at d's place would hold for a style: the nearer leg for leg holds; for holds round
## the middle, "front" if he is in front of the raider, else "back".
static func slot_for(style: String, d: Athlete, r: Athlete) -> String:
	if style in ["ankle", "thigh"]:
		var dl := _flat(r.model.anchor("ankle_l")).distance_to(_flat(d.position))
		var dr := _flat(r.model.anchor("ankle_r")).distance_to(_flat(d.position))
		return "leg_l" if dl < dr else "leg_r"
	var to := _flat(d.position - r.position)
	return "front" if to.dot(r.facing) > 0.0 else "back"


## A diving defender's hand on the part his tackle goes for, if any: {"slot", "gap"}. Only during the part of
## the dive with the arms out (or just after he lands, still reaching), only going at the raider, only on a
## slot no one holds, and only with the two middles within max_centre (how far a body stretches in that
## dive). Each hand is checked along its path since the last frame (prev), so a fast one cannot pass through
## a leg between frames. With flat (the raider is in the air), heights are left out: hands passing under his
## feet are what he has to clear, and whether he does is the lion jump's business.
static func contact(d: Athlete, r: Athlete, style: String, taken: Array, flat := false, max_centre := INF, prev: Array = []) -> Dictionary:
	var reaching := false
	if d.state == "dive":
		reaching = d.st_t / maxf(d.st_len, 0.01) >= ARMS_OUT
	elif d.state == "recover":
		reaching = d.reach_t > 0.0
	if not reaching or style == "" or d.model == null or r.model == null:
		return {}
	if _flat(d.position - r.position).length() > max_centre:
		return {}
	var hands: Array = [d.model.anchor("hand_l"), d.model.anchor("hand_r")]
	var from: Array = prev if prev.size() == 2 else hands
	var best := {}
	var gap := CONTACT_R
	if style in ["ankle", "thigh"]:
		for s in ["l", "r"]:
			if taken.has("leg_" + s):
				continue
			var parts: Array = HANDS[style]
			var a: Vector3 = r.model.anchor(String(parts[0]) + "_" + s)
			var b: Vector3 = r.model.anchor(String(parts[1]) + "_" + s)
			if flat:
				a.y = 0.0
				b.y = 0.0
			for k in 2:
				var hp: Vector3 = hands[k]
				var h0: Vector3 = from[k]
				if flat:
					hp.y = 0.0
					h0.y = 0.0
				var e := _seg_seg(h0, hp, a, b)
				if e < gap and _ahead(d, a):
					gap = e
					best = {"slot": "leg_" + s, "gap": e}
	else:
		var slot := slot_for(style, d, r)
		if taken.has(slot):
			return {}
		var w: Vector3 = r.model.anchor("waist")
		for k in 2:
			var e := maxf(0.0, _seg_dist(w, from[k], hands[k]) - BODY_R)
			if e < gap and _ahead(d, w):
				gap = e
				best = {"slot": slot, "gap": e}
	return best


func has(d: Athlete) -> bool:
	return _find(d) >= 0


func style_of_hold(d: Athlete) -> String:
	var i := _find(d)
	return String(holds[i].style) if i >= 0 else ""


## Slots held now.
func taken() -> Array:
	var out := []
	for h in holds:
		out.append(h.slot)
	return out


## Slots neither held nor claimed by someone else on his way.
func free_slots(for_who: Athlete = null) -> Array:
	var out := []
	var held := taken()
	for s in SLOTS:
		if held.has(s):
			continue
		if claims.has(s) and claims[s][0] != for_who:
			continue
		out.append(s)
	return out


## A team-mate coming to help: the free slot nearest him (the slot he already claimed, if it is still free),
## kept for him while he runs in. "" when there is none (he contains instead).
func claim(d: Athlete) -> String:
	for s in claims.keys():
		if claims[s][0] == d:
			if taken().has(s):
				claims.erase(s)   # someone's hands got there first (a dive): he looks for another
				break
			claims[s][1] = CLAIM_TIME
			return s
	var best := ""
	var bd := INF
	for s in free_slots(d):
		var p := approach(s, d)
		var dist := _flat(p).distance_to(_flat(d.position))
		if dist < bd:
			bd = dist
			best = s
	if best != "":
		claims[best] = [d, CLAIM_TIME]
	return best


func unclaim(d: Athlete) -> void:
	for s in claims.keys():
		if claims[s][0] == d:
			claims.erase(s)


## Where a helper goes to take a slot: just out of the raider's body, on that slot's side.
func approach(slot: String, d: Athlete) -> Vector3:
	var st := _style_for_slot(slot)
	var at := _slot_point(slot)
	var side := _flat(d.position - at)
	match slot:
		"front":
			side = raider.facing
		"back":
			side = -raider.facing
		"leg_l", "leg_r":
			# From that leg's side, a little behind (behind him is the waist hold's way in).
			var right := raider.facing.cross(Vector3.UP).normalized()
			side = -raider.facing * 0.4 + right * (0.9 if slot == "leg_r" else -0.9)
	side = side.normalized() if side.length() > 0.01 else -raider.facing
	return _flat(at) + side * (float(REACH[st]) - 0.15)


## Close enough, and facing it, to take hold of a slot (a helper piling on).
func can_reach(d: Athlete, slot: String) -> bool:
	var at := _flat(_slot_point(slot))
	var to := at - _flat(d.position)
	return to.length() < float(REACH[_style_for_slot(slot)]) and (to.length() < 0.2 or to.normalized().dot(d.facing) > 0.3)


## A hold confirmed: d holds slot in the given style. With reach (a dive that got a hand on him) the hands
## are on at once; a helper's close on it as he bends into the hold.
func add(d: Athlete, style: String, slot: String, reached := false) -> void:
	unclaim(d)
	var at := Vector3.ZERO
	if slot.begins_with("leg_"):
		var s := slot.substr(4)
		at = raider.model.anchor("foot_" + s)
		at.y = raider.model.rig.ankle_height() if raider.model.rig else 0.08   # on the floor
	# Each holder's own rhythm: a little quicker or slower, the first haul a moment after he takes hold. A
	# team-mate joining falls in with the first holder's: they heave together, his first with the next of
	# theirs that his hands are on for.
	var period := PULL_PERIOD * (0.88 + 0.24 * float(d.get_instance_id() % 97) / 96.0)
	var ph := -PULL_START / period
	if not holds.is_empty():
		var lead: Dictionary = holds[0]
		period = float(lead.period)
		var wait := (ceilf(float(lead.ph)) - float(lead.ph)) * period
		while wait < CLOSE_IN + 0.1:
			wait += period
		ph = -wait / period
	var h := {"who": d, "style": style, "slot": slot, "at": at, "since": t, "w": 1.0 if reached else 0.0,
		"period": period, "ph": ph, "pull": 0.0}
	holds.append(h)
	d.hold_style = style
	_priority(d, 1)
	_targets(h)


## A hold broken (an escape, a dubki, the hold given up): a held foot comes free at once, the hands open on
## the spot where they held over LET_GO.
func release(d: Athlete) -> void:
	var i := _find(d)
	if i < 0:
		return
	var h: Dictionary = holds[i]
	holds.remove_at(i)
	d.haul = 0.0
	if String(h.slot).begins_with("leg_"):
		_pin(String(h.slot).substr(4), Vector3.ZERO, 0.0)
	_open_hands(d)
	_priority(d, 0)
	if holds.is_empty() and state == "holding":
		_end()


## The raider goes down: the holders keep hold, a held foot stays caught as he falls (a trip), then they let
## go (see update).
func takedown() -> void:
	state = "takedown"
	t = 0.0
	claims.clear()


## How the raider goes down: tripped if anyone has a leg, taken down otherwise.
func fall_kind() -> String:
	for h in holds:
		if String(h.slot).begins_with("leg_"):
			return "trip"
	return "takedown"


## How hard he is being pulled back now, 0..1: the strongest haul on him.
func tug() -> float:
	var out := 0.0
	for h in holds:
		out = maxf(out, float(h.pull))
	return out


## The holders' hauls together: each adds his own (up to 1.6 with several heaving at once).
func tug_total() -> float:
	var sum := 0.0
	for h in holds:
		sum += float(h.pull)
	return minf(1.6, sum)


## Every hold on him has been held long enough (ESTABLISH) to take part in bringing him down.
func established() -> bool:
	for h in holds:
		if t - float(h.since) < ESTABLISH:
			return false
	return true


## The holders' hauls on average, 0..1 (over a whole cycle it is about half, however many hold him).
func tug_mean() -> float:
	if holds.is_empty():
		return 0.0
	var sum := 0.0
	for h in holds:
		sum += float(h.pull)
	return sum / holds.size()


## A haul's strength through its cycle (ph in cycles): a quick heave, then easing off to take a new grip.
static func haul(ph: float) -> float:
	if ph < 0.0:
		return 0.0
	var x := fposmod(ph, 1.0)
	if x < PULL_UP:
		var a := x / PULL_UP
		return a * a * (3.0 - 2.0 * a)
	var b := (x - PULL_UP) / (1.0 - PULL_UP)
	return 1.0 - b * b * (3.0 - 2.0 * b)


## Every frame: held feet kept where they were caught (dragged only when he stretches past his leg), each
## holder's body kept within reach of his slot and his hands on it, claims timed out.
func update(dt: float) -> void:
	t += dt
	for s in claims.keys():
		claims[s][1] = float(claims[s][1]) - dt
		var who: Athlete = claims[s][0]
		if float(claims[s][1]) <= 0.0 or not is_instance_valid(who) or who.state not in ["ready", "idle"]:
			claims.erase(s)
	if state == "done":
		return
	var right := raider.facing.cross(Vector3.UP).normalized()
	var side := 0.0        # which leg is pulled hardest: -1 left, 1 right
	var side_pull := 0.0
	for h in holds:
		var d: Athlete = h.who
		var slot: String = h.slot
		var style: String = h.style
		h.w = minf(1.0, float(h.w) + dt / CLOSE_IN)
		# The haul: in rhythm while he holds; as the raider goes down, the last one eases off.
		if state == "holding":
			h.ph = float(h.ph) + dt / float(h.period)
			h.pull = haul(float(h.ph)) * float(h.w)
		else:
			h.pull = maxf(0.0, float(h.pull) - dt * 3.0)
		d.haul = float(h.pull)
		if state == "takedown" and not slot.begins_with("leg_"):
			d.bear = clampf(t / TRIP_HOLD, 0.0, 1.0)
		if slot.begins_with("leg_") and float(h.pull) >= side_pull:
			side_pull = float(h.pull)
			side = -1.0 if slot == "leg_l" else 1.0
		if slot.begins_with("leg_") and state == "holding":
			var at: Vector3 = h.at
			var hip := _flat(raider.position)
			var flat := _flat(at)
			if flat.distance_to(hip) > LEG_REACH:
				flat = hip + (flat - hip).normalized() * LEG_REACH
				h.at = Vector3(flat.x, at.y, flat.z)
		_targets(h)
		# The holder's body: his shoulders within reach of his slot, coming at it the way he is (an arm's
		# length off it for a hold on the floor, closer when the slot is lower than his shoulders).
		var goal := _slot_point(slot)
		var sh := (d.model.anchor("shoulder_l") + d.model.anchor("shoulder_r")) * 0.5
		var arm := d.model.rig.arm_length() if d.model.rig else 0.6
		var dy := sh.y - goal.y
		var across := sqrt(maxf(0.0, pow(arm * 0.88, 2.0) - dy * dy))
		# Hauling, he draws what he holds in toward him: his arms bend, his body stays.
		across = maxf(0.15, across - _pull_in(h))
		var dir := _flat(goal - sh)
		dir = dir.normalized() if dir.length() > 0.01 else d.facing
		var step := _flat(goal - dir * across - sh)
		var lim := (BODY_FOLLOW + raider.vel.length()) * dt
		if step.length() > lim:
			step = step.normalized() * lim
		# Not inside one another: holders' middles at least HOLDER_GAP apart, each giving way half.
		var mid := _flat(d.model.anchor("waist") + step)
		for o in holds:
			if o.who == d:
				continue
			var away := mid - _flat((o.who as Athlete).model.anchor("waist"))
			if away.length() < HOLDER_GAP:
				step += (away.normalized() if away.length() > 0.01 else right) * (HOLDER_GAP - away.length()) * 0.5
		# Never inside him: the two middles (pelvis and lower back) at least MIN_GAP apart.
		var to := _flat(d.model.anchor("waist") + step - raider.model.anchor("waist"))
		if to.length() < MIN_GAP:
			step += (to.normalized() if to.length() > 0.01 else -right) * (MIN_GAP - to.length())
		d.position += step
		d.vel = step / maxf(dt, 0.0001)
		d.hold_offset = d.position - raider.position
		d.face_toward(goal, dt, 12.0)
	# The raider: how badly he is off balance, how hard he is pulled back now, and which leg it is pulled by.
	raider.balance = 1.0 if state == "takedown" else progress
	raider.tug = tug()
	raider.tug_side = side
	if state == "takedown" and t >= TRIP_HOLD:
		for h in holds.duplicate():
			_open_hands(h.who)
			_priority(h.who, 0)
		holds.clear()
		_end()


## A hold's targets: the held foot kept where it was caught (let go of gradually as a tackled raider falls
## past it), and the holder's hands on his slot, round the middle to either side of it.
func _targets(h: Dictionary) -> void:
	var d: Athlete = h.who
	var slot: String = h.slot
	if slot.begins_with("leg_"):
		var w := 1.0 if state == "holding" else clampf(1.0 - t / TRIP_HOLD, 0.0, 1.0)
		_pin(slot.substr(4), _pulled(h), w)
	var parts: Array = HANDS[h.style]
	var side := d.facing.cross(Vector3.UP).normalized()
	var suffix := "_" + slot.substr(4) if slot.begins_with("leg_") else ""
	var off_r := Vector3.ZERO if slot.begins_with("leg_") else side * BODY_R * 1.1
	_reach(d, "r", String(parts[0]) + suffix, off_r, float(h.w))
	_reach(d, "l", String(parts[1]) + suffix, -off_r, float(h.w))


## How far a hold's haul draws the part in toward the holder now (m): more as the struggle goes on.
func _pull_in(h: Dictionary) -> float:
	return PULL_IN * float(h.get("pull", 0.0)) * (0.45 + 0.55 * progress)


## Where a held foot is now: where it was caught (h.at, dragged with him), drawn back toward the holder and
## lifted off the floor by each haul.
func _pulled(h: Dictionary) -> Vector3:
	var at: Vector3 = h.at
	var pull := float(h.get("pull", 0.0))
	if pull <= 0.0:
		return at
	var d: Athlete = h.who
	var sh := (d.model.anchor("shoulder_l") + d.model.anchor("shoulder_r")) * 0.5
	var back := _flat(sh - at)
	back = back.normalized() if back.length() > 0.01 else -raider.facing
	var lift := PULL_LIFT * pull * progress * (1.0 if String(h.style) == "ankle" else 0.5)
	return at + back * _pull_in(h) + Vector3.UP * lift


## Take every hand and foot target off (the raid is over or reset).
func clear() -> void:
	for h in holds:
		_open_hands(h.who, true)
		_priority(h.who, 0)
		(h.who as Athlete).haul = 0.0
	holds.clear()
	claims.clear()
	_end()


## Where each of d's hands should be now (world), for measuring: [[side, point], ...].
func hand_goals(d: Athlete) -> Array:
	var i := _find(d)
	if i < 0 or d.model == null or d.model.rig == null:
		return []
	var out := []
	for hs in d.model.rig.hand_target:
		var ht: Dictionary = d.model.rig.hand_target[hs]
		if ht.get("model") != null and is_instance_valid(ht.model):
			out.append([hs, (ht.model as HumanModel).anchor(String(ht.part)) + (ht.get("offset", Vector3.ZERO) as Vector3)])
	return out


func _end() -> void:
	state = "done"
	raider.tug = 0.0
	for s in ["l", "r"]:
		_pin(s, Vector3.ZERO, 0.0)
	_priority(raider, 0)


func _find(d: Athlete) -> int:
	for i in holds.size():
		if holds[i].who == d:
			return i
	return -1


func _style_for_slot(slot: String) -> String:
	return "thigh" if slot.begins_with("leg_") else ("block" if slot == "front" else "waist")


## The middle of where a slot's hands go.
func _slot_point(slot: String) -> Vector3:
	match slot:
		"leg_l", "leg_r":
			var s := slot.substr(4)
			for h in holds:
				if h.slot == slot:
					var parts: Array = HANDS[h.style]
					return (raider.model.anchor(String(parts[0]) + "_" + s) + raider.model.anchor(String(parts[1]) + "_" + s)) * 0.5
			return (raider.model.anchor("thigh_" + s) + raider.model.anchor("knee_" + s)) * 0.5
	return raider.model.anchor("waist")


func _pin(s: String, at: Vector3, w: float) -> void:
	var rig: RiggedBody = raider.model.rig if raider.model else null
	if rig == null:
		return
	if w <= 0.0:
		rig.foot_goal.erase(s)
	else:
		rig.foot_goal[s] = [at, w]


func _reach(d: Athlete, hs: String, part: String, offset: Vector3, w: float) -> void:
	var rig: RiggedBody = d.model.rig if d.model else null
	if rig == null:
		return
	rig.hand_target[hs] = {"model": raider.model, "part": part, "offset": offset, "w": w, "fade": 0.0}


func _open_hands(d: Athlete, now := false) -> void:
	var rig: RiggedBody = d.model.rig if d.model else null
	if rig == null:
		return
	for hs in rig.hand_target.keys():
		if now:
			rig.hand_target.erase(hs)
		else:
			# Stay where they held and fade out.
			var ht: Dictionary = rig.hand_target[hs]
			if ht.get("model") != null and is_instance_valid(ht.model):
				ht["point"] = (ht.model as HumanModel).anchor(String(ht.part)) + (ht.get("offset", Vector3.ZERO) as Vector3)
			ht["model"] = null
			ht["offset"] = Vector3.ZERO
			ht["fade"] = 1.0 / LET_GO


static func _ahead(d: Athlete, p: Vector3) -> bool:
	return _flat(p - d.position).dot(d.facing) > 0.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func _priority(a: Athlete, p: int) -> void:
	if a == null:
		return
	a.process_priority = p
	if a.model:
		a.model.process_priority = p


## Closest distance between segments p0-p1 and q0-q1.
static func _seg_seg(p0: Vector3, p1: Vector3, q0: Vector3, q1: Vector3) -> float:
	var u := p1 - p0
	var v := q1 - q0
	var w := p0 - q0
	var a := u.dot(u)
	var b := u.dot(v)
	var c := v.dot(v)
	var d := u.dot(w)
	var e := v.dot(w)
	var den := a * c - b * b
	var s := 0.0
	var t := 0.0
	if a < 0.000001:
		return _seg_dist(p0, q0, q1)
	if c < 0.000001:
		return _seg_dist(q0, p0, p1)
	if den > 0.000001:
		s = clampf((b * e - c * d) / den, 0.0, 1.0)
	t = (b * s + e) / c
	if t < 0.0:
		t = 0.0
		s = clampf(-d / a, 0.0, 1.0)
	elif t > 1.0:
		t = 1.0
		s = clampf((b - d) / a, 0.0, 1.0)
	return (p0 + u * s).distance_to(q0 + v * t)


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * k)
