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
##
## An ankle hold is two bodies joined at the ankle (_ankle, _footwork), not a pose carried along behind him.
## The holder lies where his dive put him (the slide dies away as his arms take it) and is moved along the
## floor only when the raider drags him. His hands hold the ankle out at arm's length and draw it in on each
## haul. The raider stands on his free foot, the held leg reaching back to the hold, and sinks on the free leg
## as low as it needs to reach (Athlete.stance). He gets about only by hopping on the free foot, never by
## sliding. A hop that would take him further than the held leg goes stops short: the leg snaps taut (jolt).
## The exception is when he drives harder than the holder holds: then the holder is dragged a little way with
## the ankle (strain). A haul that pulls the leg further back than it reaches pulls him back, and he hops back
## to stay on his feet. When he goes down it is forward, away from the hold, with the foot still held.

const SLOTS := ["leg_l", "leg_r", "back", "front"]
const CONTACT_R := 0.3         # m: a hand this close to the part a dive goes for grips it
const BODY_R := 0.12           # m: the raider's middle is this thick round its centre line, for waist holds
const LEG_REACH := 0.55        # m from the hips (flat) to a held foot: further and he drags it
const BODY_FOLLOW := 2.5       # m/s the holder's body may be moved, beyond the drag itself, to keep his reach
const LET_GO := 0.15           # s for the hands to come off when a hold breaks
const TORN_GO := 0.3           # s a holder's hands follow a leg torn out of them (a lion jump) as they come off it ...
const TORN_FREE := 0.07        # ... and the s it takes the foot to come out of them
const TRIP_HOLD := 0.7         # s the holders keep hold while a tackled raider goes down (when his fall's landing is
                               # not known); otherwise each lets go at his own moment after it (takedown, LET_AFTER)
const LET_GO_MAX := 1.6        # s after the takedown by which every holder has let go
const FOLLOW_TIME := 0.07      # s: a holder's body takes up this much of the way to his place each frame (no faster:
                               # a body that jumps all the way there each frame overshoots and shakes)
const ARMS_OUT := 0.3          # share of a dive after which the arms are out and can grip
const CLOSE_IN := 0.2          # s for a helper's hands to close on his slot as he takes hold
const MIN_GAP := 0.34          # m: no holder's middle (pelvis to lower back) comes closer to the raider's
const HOLDER_GAP := 0.42       # m: nor to another holder's
const SIDE_IN := 0.2           # m in front of (or behind) the raider a helper must be to take hold round his middle
const CLAIM_TIME := 2.0        # s a claimed slot is kept for a helper on his way
const PULL_PERIOD := 0.9       # s from one haul to the next (each holder a little quicker or slower)
const PULL_UP := 0.3           # share of each cycle spent hauling; the rest easing off and taking a new grip
const PULL_START := 0.25       # s after taking hold before the first haul
const PULL_IN := 0.16          # m a haul draws a held leg back toward the holder, at full struggle
const PULL_LIFT := 0.09        # m a haul lifts a held foot off the floor, at full struggle
const ESTABLISH := 0.6         # s a hold needs before it can take part in bringing him down
# An ankle hold (see _ankle and _footwork).
const ARM_OUT := 0.92          # share of a holder's arm length he holds an ankle out at
const ARM_HAUL := 0.45         # ... and draws it in to at the height of a haul
const ARM_MIN := 0.32          # m: his shoulders no nearer the ankle than this (his elbows take the rest)
const HAUL_SPEED := 1.3        # m/s a haul draws the ankle in
const LEG_REST := 0.22         # m behind his hip (along the floor) the raider draws a held foot back to ...
const LEG_DRAW := 0.45         # ... this fast (m/s), between hauls
const ANKLE_LIFT := 0.14       # m a haul lifts a held ankle off the floor, at full struggle
const SETTLE := 0.09           # s: how quickly a diver's slide dies away once his hands are on the ankle
const LEG_SPAN := 0.97         # share of the raider's leg (hip joint to ankle joint) a held leg stretches to
const LOW_HIP := 0.62          # share of his leg's length his hips can sink to over the free foot ...
const STAND_HIP := 0.95        # ... and stand at, one leg held
const HOP_DIST := 0.26         # m a hop on the free foot carries him, driving as hard as he can
const HOP_TIME := 0.26         # s in the air
const HOP_HEIGHT := 0.06       # m off the floor
const HOP_GAP := 0.3           # s on the free foot between hops (longer as his balance goes)
const HOP_BACK := 0.03         # m: pulled further than the held leg reaches, he hops back to stay on his feet
const GATHER_SINK := 0.2       # how much lower (share of his leg) he sinks on the free leg gathering for a lion jump
const DUCK_SINK := 0.16        # ... and ducking (a dubki) with the ankle held
const DRAG_MAX := 0.12         # m one hop can drag a holder along the floor
const TAKEDOWN_DRAG := 1.2     # m/s a falling raider's leg can pull the ankle holder after it
# How long after the raider lands each hold lets go (takedown): hands round a leg as it reaches the floor, an ankle
# a moment later, arms round his middle once they have ridden him down. Each holder a little sooner or later.
const LET_AFTER := {"thigh": 0.0, "ankle": 0.12, "block": 0.2, "waist": 0.3}
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
# The raider's footwork, held only by the ankle (_footwork). Set by the match: where he is trying to go (his
# stick or the AI, 0..1), how hard he can drive there and how hard his holders hold (Match._move_raider).
var want := Vector3.ZERO
var force := 0.0
var resist := 0.0
var hop := -1.0                # s into a hop on his free foot (-1: on the floor)
var hop_len := HOP_TIME
var hop_from := Vector3.ZERO
var hop_to := Vector3.ZERO
var hop_wait := 0.0            # s before he can hop again
var landed := -1.0             # s since he came down from a hop (-1: a while ago)
var jolt := 0.0                # a pull through the held leg he did not expect, 0..1 (fading)
var raider_vel := Vector3.ZERO # how fast his body moves over the floor now (the hops)
var turn := false              # he can turn now: in the air (turning on the spot would drag his planted foot)
var land := TRIP_HOLD          # s from the takedown to his reaching the floor (takedown)
var _yaw := INF                # which way his body faced last frame (radians), to swing his holders round with him


func _init(r: Athlete) -> void:
	id = _next_id
	_next_id += 1
	raider = r
	# The held raider is posed after the match has moved him this frame (it runs at 0), and before his holders,
	# so their hands reach for where he is now and his held foot is where the hold has it now.
	_priority(r, 1)


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


## Close enough, and facing it, to take hold of a slot (a helper piling on); for a hold round his middle, from
## that side of him (well in front for "front", well behind for "back": both are round the same middle, and
## two holding it from beside him would be on top of each other).
func can_reach(d: Athlete, slot: String) -> bool:
	var at := _flat(_slot_point(slot))
	var to := at - _flat(d.position)
	if slot in ["front", "back"]:
		var ahead := _flat(d.position - raider.position).dot(raider.facing)
		if (slot == "front" and ahead < SIDE_IN) or (slot == "back" and ahead > -SIDE_IN):
			return false
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
	var period := PULL_PERIOD * (0.88 + 0.24 * float(absi(hash(d.pid())) % 97) / 96.0)
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
	_priority(d, 2)
	if style == "ankle":
		# What is left of his dive, taken by his arms as his chest meets the floor (_ankle).
		h.slide = Vector3(d.vel.x, 0.0, d.vel.z)
		h.tension = 0.0
		h.strain = 0.0
		h.taut = false
		if d.model:
			d.model.impact = 0.0
		# The raider: his foot caught, the rest of him carries on and he lurches onto the free foot.
		jolt = maxf(jolt, 0.7)
		var v := Vector3(raider.vel.x, 0.0, raider.vel.z)
		if v.length() > 0.4 and hop < 0.0:
			_start_hop(v.normalized(), minf(0.3, v.length() * 0.12), 0.2)
	_targets(h)


## A hold broken (an escape, a dubki, the hold given up): a held foot comes free at once, the hands open on
## the spot where they held over LET_GO. A leg torn out of the hands (torn: a lion jump) takes them with it a
## little way as they lose it (TORN_GO).
func release(d: Athlete, torn := false) -> void:
	var i := _find(d)
	if i < 0:
		return
	var h: Dictionary = holds[i]
	holds.remove_at(i)
	d.haul = 0.0
	d.strain = 0.0
	if String(h.slot).begins_with("leg_"):
		_unpin(String(h.slot).substr(4), TORN_FREE if torn else LET_GO)   # the leg swings free, not in one frame
	_open_hands(d, false, torn)
	_priority(d, 0)
	if holds.is_empty() and state == "holding":
		_end()


## The raider goes down: the holders keep hold and go down with him, a held foot stays caught as he falls (a
## trip), and each lets go at his own moment once he has reached the floor (update): a hold round a leg first,
## arms round his middle last, each holder a little sooner or later than the next, so they do not all come
## off him at once.
func takedown() -> void:
	state = "takedown"
	t = 0.0
	claims.clear()
	# When he will be on the floor: the fall clip's own landing, from where it starts.
	land = TRIP_HOLD
	var m := raider.model
	if m and m.clip and m.clip.landing() >= 0.0:
		land = maxf(0.3, (m.clip.landing() - m.clip_time) / maxf(m.clip_rate, 0.01))
	for h in holds:
		var own := 0.15 * float(absi(hash((h.who as Athlete).pid())) % 100) / 100.0
		h.let_go = minf(LET_GO_MAX, land + float(LET_AFTER.get(String(h.style), 0.15)) + own)


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


## Held only by the ankle (one leg or both): he can only hop on a free foot, the holders lying where they are
## (_footwork). With any other hold on him, he is carried along by the struggle (Match._move_raider).
func footwork() -> bool:
	if state != "holding" or holds.is_empty():
		return false
	for h in holds:
		if String(h.style) != "ankle":
			return false
	return true


## Which way the ankle holds pull him over: from the held ankle to his hip, along the floor (zero for none).
## Held by the ankle he goes down forward, away from the hold.
func away_from_hold() -> Vector3:
	var sum := Vector3.ZERO
	for h in holds:
		if String(h.style) == "ankle":
			sum += _flat(raider.model.anchor("hip_" + String(h.slot).substr(4)) - (h.at as Vector3))
	return sum.normalized() if sum.length() > 0.05 else Vector3.ZERO


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
## holder's body kept within reach of his slot and his hands on it, claims timed out. An ankle hold is worked
## between the two bodies instead (_footwork, then _ankle).
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
		h.w = minf(1.0, float(h.w) + dt / CLOSE_IN)
		# The haul: in rhythm while he holds; as the raider goes down, the last one eases off.
		if state == "holding":
			h.ph = float(h.ph) + dt / float(h.period)
			h.pull = haul(float(h.ph)) * float(h.w)
		else:
			h.pull = maxf(0.0, float(h.pull) - dt * 3.0)
		d.haul = float(h.pull)
		if state == "takedown" and String(h.style) != "ankle":
			# Going down with him as he falls (a thigh holder only a little: he is down already).
			d.bear = clampf(t / land, 0.0, 1.0) * (0.6 if String(h.style) == "thigh" else 1.0)
		if String(h.slot).begins_with("leg_") and float(h.pull) >= side_pull:
			side_pull = float(h.pull)
			side = -1.0 if h.slot == "leg_l" else 1.0
	# The raider's hops on his free foot (held only by the ankle), then each hold with what they did.
	raider_vel = Vector3.ZERO
	if footwork():
		_footwork(dt)
	# Arms round his middle swing round with him as his body turns.
	var bf := raider.body_facing()
	var yaw := atan2(-bf.x, -bf.z)
	var turned := 0.0 if _yaw == INF else wrapf(yaw - _yaw, -PI, PI)
	_yaw = yaw
	for h in holds:
		var d: Athlete = h.who
		var slot: String = h.slot
		if String(h.style) == "ankle":
			_ankle(h, dt)
			_targets(h)
			continue
		if slot in ["back", "front"] and absf(turned) > 0.0001:
			var off := d.position - raider.position
			d.position = raider.position + off.rotated(Vector3.UP, turned)
			d.facing = d.facing.rotated(Vector3.UP, turned)
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
		var sh := _shoulders(d)
		var arm := d.model.rig.arm_length() if d.model.rig else 0.6
		var dy := sh.y - goal.y
		var across := sqrt(maxf(0.0, pow(arm * 0.88, 2.0) - dy * dy))
		# Hauling, he draws what he holds in toward him: his arms bend, his body stays.
		across = maxf(0.15, across - _pull_in(h))
		var dir := _flat(goal - sh)
		dir = dir.normalized() if dir.length() > 0.01 else d.facing
		var step := _flat(goal - dir * across - sh) * (1.0 - exp(-dt / FOLLOW_TIME))
		var lim := (BODY_FOLLOW + raider.vel.length()) * dt
		if step.length() > lim:
			step = step.normalized() * lim
		# Not inside one another: holders' middles at least HOLDER_GAP apart, each giving way half (all of it to an
		# ankle holder, who lies where his dive put him).
		var mid := _flat(d.model.anchor("waist") + step)
		for o in holds:
			if o.who == d:
				continue
			var away := mid - _flat((o.who as Athlete).model.anchor("waist"))
			if away.length() < HOLDER_GAP:
				var share := 1.0 if String(o.style) == "ankle" else 0.5
				step += (away.normalized() if away.length() > 0.01 else right) * (HOLDER_GAP - away.length()) * share
		# Never inside him: the two middles (pelvis and lower back) at least MIN_GAP apart.
		var to := _flat(d.model.anchor("waist") + step - raider.model.anchor("waist"))
		if to.length() < MIN_GAP:
			step += (to.normalized() if to.length() > 0.01 else -right) * (MIN_GAP - to.length())
		# Pushed out of the way no faster than a body is shoved (a falling raider coming down next to him): over a
		# few frames, not in one.
		step = step.limit_length((BODY_FOLLOW + raider.vel.length() + 1.0) * dt)
		d.position += step
		d.vel = step / maxf(dt, 0.0001)
		d.hold_offset = d.position - raider.position
		d.face_toward(goal, dt, 12.0)
	# The raider: how badly he is off balance, how hard he is pulled back now, and which leg it is pulled by;
	# on one leg, how low he sinks on the other and where he is in a hop.
	raider.balance = 1.0 if state == "takedown" else progress
	raider.tug = tug()
	raider.tug_side = side
	_footwork_pose()
	if state == "takedown":
		for h in holds.duplicate():
			if t >= float(h.get("let_go", TRIP_HOLD)):
				_let_go(h)
		if holds.is_empty():
			_end()


## A holder lets go once the raider is down (takedown): his hands open where they held, a held foot comes free.
## What he does next (getting up from where he is) is the match's (Match._get_up_from_hold).
func _let_go(h: Dictionary) -> void:
	var d: Athlete = h.who
	holds.erase(h)
	_open_hands(d)
	_priority(d, 0)
	d.strain = 0.0
	d.haul = 0.0
	if String(h.slot).begins_with("leg_"):
		_unpin(String(h.slot).substr(4))


## An ankle hold, each frame (after the raider's footwork). The holder: what is left of his dive's slide
## dying away (never past the ankle: his elbows take the rest), his body turning on the floor to keep the
## ankle in front of him, and moved along the floor only by the raider dragging him (leg_limit). The ankle:
## where his hands have it, out at arm's length; a haul draws it in and lifts it, but never further from the
## raider's hip than the leg reaches: how much further the haul pulls is the tension on the raider, which his
## footwork answers. Going down (the takedown), the ankle stays in the holder's hands until the leg pulls it
## out of them as he falls past it.
func _ankle(h: Dictionary, dt: float) -> void:
	var d: Athlete = h.who
	var s := String(h.slot).substr(4)
	var arm := d.model.rig.arm_length() if d.model.rig else 0.6
	var at: Vector3 = h.at
	var slide: Vector3 = h.get("slide", Vector3.ZERO)
	var step := slide * dt
	if step.length() > 0.0 and _flat(at - (_shoulders(d) + step)).length() < ARM_MIN:
		step = Vector3.ZERO
		slide = Vector3.ZERO
	h.slide = slide * exp(-dt / SETTLE)
	d.position += step
	d.vel = step / maxf(dt, 0.0001) + (h.get("dragged", Vector3.ZERO) as Vector3) / maxf(dt, 0.0001)
	h.dragged = Vector3.ZERO
	d.hold_offset = d.position - raider.position
	if state == "holding":
		d.face_toward(at, dt, 2.5)
	var sh := _flat(_shoulders(d))
	var hip3 := raider.model.anchor("hip_" + s)
	var hip := _flat(hip3)
	var f := _flat(at)
	var y := at.y
	if state == "holding":
		var pull := float(h.pull)
		# Between hauls the raider draws the foot back in under him, as far as the holder's arms let it go (they
		# straighten); a haul pulls it back out toward the holder as fast as arms pull, to the arm's length the
		# haul has got to (his elbows bend), and lifts it off the floor, more as the struggle goes on.
		var under := f.distance_to(hip)
		if under > LEG_REST and under > 0.001:
			f = hip + (f - hip) / under * maxf(LEG_REST, under - LEG_DRAW * (1.0 - pull) * dt)
		var reach := arm * lerpf(ARM_OUT, ARM_HAUL, pull * (0.5 + 0.5 * progress))
		var r := f.distance_to(sh)
		if r > reach and r > 0.001 and pull > 0.05:
			f = sh + (f - sh) / r * maxf(reach, r - HAUL_SPEED * pull * dt)
		var floor_y := raider.model.rig.ankle_height() if raider.model.rig else 0.08
		y = move_toward(at.y, floor_y + ANKLE_LIFT * pull * (0.35 + 0.65 * progress), dt * 0.8)
		# No further from his hip than the leg reaches (sinking as low as he can): past that the leg holds it,
		# and the rest of the haul pulls on him.
		var span := _span(y)
		var dist := f.distance_to(hip)
		h.tension = 0.0
		if dist > span:
			h.tension = dist - span
			f = hip + (f - hip) / dist * span
		# Nor further out than the holder's arms go: past that, he holds it at full stretch (and is dragged).
		var out := f.distance_to(sh)
		if out > arm * 0.97:
			f = sh + (f - sh) / out * arm * 0.97
		# How hard the raider pulls against him: the leg at full stretch, driving away from him.
		var pulling := clampf(force * want.length() / maxf(resist, 0.01), 0.0, 1.5) / 1.5
		var taut := f.distance_to(hip) > span * 0.97 and want.dot(_flat(hip - f).normalized()) > 0.2
		h.strain = move_toward(float(h.strain), pulling if taut else 0.0, dt * 4.0)
	else:
		# Going down: he keeps the ankle as the raider falls away from it, the leg stretched back to his hands;
		# if the fall takes it further than his arms reach, it pulls him a little way along the floor after it.
		var leg := (raider.model.rig.leg_reach() if raider.model.rig else 0.88) * LEG_SPAN
		var a3 := Vector3(f.x, y, f.z)
		if a3.distance_to(hip3) > leg:
			a3 = hip3 + (a3 - hip3).normalized() * leg
			f = _flat(a3)
			y = maxf(a3.y, at.y)
		var out := f.distance_to(sh)
		if out > arm * 0.97:
			var pull := minf(out - arm * 0.97, TAKEDOWN_DRAG * dt)
			var dir := (f - sh) / out
			d.position += dir * pull
			d.vel += dir * pull / maxf(dt, 0.0001)
			f = sh + dir * (out - pull)
		h.strain = move_toward(float(h.strain), 0.0, dt * 4.0)
	h.at = Vector3(f.x, y, f.z)
	d.strain = float(h.strain)


## The raider's footwork, held only by the ankle: he gets about by hopping on his free foot, never by sliding.
## On the floor, his weight over the free foot, he hops the way he is trying to go (as far as he can push off
## one leg, less as his balance goes) once he has gathered himself from the last; pulled back by a haul further
## than the held leg reaches, he hops back toward the hold to stay on his feet. In the air his body travels
## the hop (the leg checks every step of it: leg_limit). Both legs held, he cannot hop at all.
func _footwork(dt: float) -> void:
	var legs := 0
	var pulled: Dictionary = {}
	for h in holds:
		legs += 1
		if pulled.is_empty() or float(h.get("tension", 0.0)) > float(pulled.get("tension", 0.0)):
			pulled = h
		h.was_taut = bool(h.get("taut", false))
		h.taut = false
	hop_wait = maxf(0.0, hop_wait - dt)
	jolt = maxf(0.0, jolt - dt / 0.35)
	if landed >= 0.0:
		landed = landed + dt if landed + dt < 0.25 else -1.0
	var before := raider.position
	if hop >= 0.0:
		hop += dt
		var p := clampf(hop / hop_len, 0.0, 1.0)
		var e := p * p * (3.0 - 2.0 * p)
		var goal := hop_from.lerp(hop_to, e)
		raider.position += leg_limit(_flat(goal - raider.position), dt)
		if p >= 1.0:
			hop = -1.0
			hop_wait = HOP_GAP * (1.0 + 1.5 * progress)
			landed = 0.0
			# Down on the free foot: he faces the way his body has got round to; the rest of a turn waits for the
			# next hop (turning on the spot would drag the planted foot round).
			raider.facing = raider.body_facing()
	elif legs < 2 and raider.state == "held":   # in the middle of a move (a dubki, gathering to jump) he stays put
		if float(pulled.get("tension", 0.0)) > HOP_BACK:
			# Pulled back further than the held leg reaches: a quick hop back toward the hold.
			var s := String(pulled.slot).substr(4)
			var back := _flat((pulled.at as Vector3) - raider.model.anchor("hip_" + s))
			if back.length() > 0.01:
				_start_hop(back.normalized(), float(pulled.tension) + 0.04, 0.2)
				jolt = maxf(jolt, 0.5 + 0.4 * tug())
		elif hop_wait <= 0.0 and want.length() > 0.15:
			var dist := HOP_DIST * minf(1.0, want.length()) * (1.0 - 0.55 * progress) * clampf(raider.energy, 0.6, 1.0)
			_start_hop(want.normalized(), dist, HOP_TIME)
	raider_vel = _flat(raider.position - before) / maxf(dt, 0.0001)
	raider.vel = raider_vel
	turn = hop >= 0.0 or legs >= 2


func _start_hop(dir: Vector3, dist: float, length: float) -> void:
	hop = 0.0
	hop_len = length
	hop_from = raider.position
	hop_to = raider.position + _flat(dir) * dist


## One step of the raider's body against the held ankles: his hip no further from a held ankle than the leg
## reaches (sinking as low as he can). Past that the leg is taut. If he is driving harder than the holder holds
## him, and that way, the holder is dragged along the floor with the ankle (a little each hop, DRAG_MAX);
## otherwise the step stops where the leg does, and the leg snapping taut jolts him. Returns the step he makes.
func leg_limit(step: Vector3, dt: float) -> Vector3:
	for h in holds:
		if String(h.style) != "ankle":
			continue
		var s := String(h.slot).substr(4)
		var hip := _flat(raider.model.anchor("hip_" + s)) + step
		var f := _flat(h.at)
		var span := _span(float(h.at.y))
		var dist := hip.distance_to(f)
		if dist <= span or dist < 0.001:
			continue
		var out := (hip - f) / dist
		var over := dist - span
		var drive := force * minf(1.0, want.length())
		if drive > resist and want.length() > 0.1 and out.dot(want.normalized()) > 0.3:
			var drag := minf(over * (drive - resist) / drive, DRAG_MAX * dt / maxf(hop_len, 0.1))
			var d: Athlete = h.who
			d.position += out * drag
			h.at = (h.at as Vector3) + out * drag
			h.dragged = (h.get("dragged", Vector3.ZERO) as Vector3) + out * drag
			over -= drag
		if over > 0.0:
			step -= out * over
			if not bool(h.get("was_taut", false)) and hop >= 0.0:
				jolt = maxf(jolt, 0.75)   # the leg snaps taut: he is stopped short
		h.taut = true
	return step


## What the body shows of the footwork (Athlete.held_leg, stance, hop, hop_air, jolt): which leg is held (one
## leg held, at the ankle; with both held he stands on both), how low he sinks on the free leg for the held one
## to reach back to the hold, where he is in a hop.
func _footwork_pose() -> void:
	var legs := []
	for h in holds:
		if String(h.slot).begins_with("leg_"):
			legs.append(h)
	if state != "holding" or legs.size() != 1 or String(legs[0].style) != "ankle":
		raider.held_leg = 0.0
		raider.hop = -1.0
		raider.hop_air = 0.0
		raider.jolt = jolt
		return
	var h: Dictionary = legs[0]
	var s := String(h.slot).substr(4)
	raider.held_leg = -1.0 if s == "l" else 1.0
	var leg := raider.model.rig.leg_reach() if raider.model.rig else 0.88
	var floor_y := raider.model.rig.ankle_height() if raider.model.rig else 0.08
	var at: Vector3 = h.at
	var dist := _flat(raider.model.anchor("hip_" + s)).distance_to(_flat(at))
	var l := leg * LEG_SPAN
	var rise := sqrt(maxf(0.0, l * l - dist * dist)) + at.y - floor_y
	raider.stance = clampf(rise / leg, LOW_HIP, STAND_HIP)
	if raider.state == "jump" and raider.wait > 0.0:
		# Gathering himself for a lion jump out of the hold (Match._raider_escape): down on the free leg to spring.
		var g := clampf(raider.st_t / raider.wait, 0.0, 1.0)
		raider.stance = maxf(LOW_HIP, raider.stance - GATHER_SINK * g * g * (3.0 - 2.0 * g))
	elif raider.state == "dubki":
		# Ducking with the ankle held: down on the free leg and up again, the held leg staying where it is held.
		raider.stance = maxf(LOW_HIP, raider.stance - DUCK_SINK * sin(PI * clampf(raider.st_t / maxf(raider.st_len, 0.01), 0.0, 1.0)))
	if hop >= 0.0:
		var p := clampf(hop / hop_len, 0.0, 1.0)
		raider.hop = minf(p, 0.999)
		raider.hop_air = HOP_HEIGHT * sin(PI * p) * (1.0 - 0.4 * progress)
	else:
		raider.hop = 1.0 + landed / 0.25 if landed >= 0.0 else -1.0
		raider.hop_air = 0.0
	raider.jolt = jolt


## How far along the floor a held ankle at height y can be from the raider's hip joint: the leg stretched as
## far as it goes (LEG_SPAN) with his hips as low as he can sink them over the free foot (LOW_HIP).
func _span(y: float) -> float:
	var leg := raider.model.rig.leg_reach() if raider.model.rig else 0.88
	var floor_y := raider.model.rig.ankle_height() if raider.model.rig else 0.08
	var l := leg * LEG_SPAN
	var dy := floor_y + leg * LOW_HIP - y
	return sqrt(maxf(0.0, l * l - dy * dy))


func _shoulders(d: Athlete) -> Vector3:
	return (d.model.anchor("shoulder_l") + d.model.anchor("shoulder_r")) * 0.5


## A hold's targets: the held foot kept where it was caught (let go of gradually as a tackled raider falls
## past it), and the holder's hands on his slot, round the middle to either side of it.
func _targets(h: Dictionary) -> void:
	var d: Athlete = h.who
	var slot: String = h.slot
	if slot.begins_with("leg_"):
		# An ankle holder keeps the foot as the raider falls (a trip) and lets go once he is down (_end); a
		# held foot higher up comes free as he falls past it.
		var w := 1.0 if state == "holding" or String(h.style) == "ankle" else clampf(1.0 - t / float(h.get("let_go", TRIP_HOLD)), 0.0, 1.0)
		_pin(slot.substr(4), h.at if String(h.style) == "ankle" else _pulled(h), w)
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
		(h.who as Athlete).strain = 0.0
	holds.clear()
	claims.clear()
	_end(true)


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


func _end(now := false) -> void:
	state = "done"
	raider.tug = 0.0
	for s in ["l", "r"]:
		if now:
			_pin(s, Vector3.ZERO, 0.0)
		else:
			_unpin(s)
	hop = -1.0
	raider.held_leg = 0.0
	raider.hop = -1.0
	raider.hop_air = 0.0
	raider.jolt = 0.0
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


## A held foot let go of: the leg swings back from where it was held over LET_GO (or the time given), not in one
## frame.
func _unpin(s: String, time := LET_GO) -> void:
	var rig: RiggedBody = raider.model.rig if raider.model else null
	if rig == null or not rig.foot_goal.has(s):
		return
	var fg: Array = rig.foot_goal[s]
	var fade := maxf(1.0 / time, float(fg[2]) if fg.size() > 2 else 0.0)   # one coming free faster already keeps on
	rig.foot_goal[s] = [fg[0], minf(1.0, float(fg[1])), fade]


func _reach(d: Athlete, hs: String, part: String, offset: Vector3, w: float) -> void:
	var rig: RiggedBody = d.model.rig if d.model else null
	if rig == null:
		return
	rig.hand_target[hs] = {"model": raider.model, "part": part, "offset": offset, "w": w, "fade": 0.0}


func _open_hands(d: Athlete, now := false, torn := false) -> void:
	var rig: RiggedBody = d.model.rig if d.model else null
	if rig == null:
		return
	for hs in rig.hand_target.keys():
		if now:
			rig.hand_target.erase(hs)
		elif torn:
			# Still on the part as it goes, losing it.
			rig.hand_target[hs]["fade"] = 1.0 / TORN_GO
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
