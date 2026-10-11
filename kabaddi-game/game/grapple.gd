class_name Grapple
extends RefCounted
## A raider in defenders' hands, from the first real contact to the end of the takedown or the escape: who
## holds him and where, what the hold does to both bodies, and the hands and feet that have to meet.
##
## Its states follow the players' own (Athlete.state) rather than duplicating them: a defender goes
## "telegraph" (winding up) -> "dive" (attempting) -> contact, checked here on the bodies as drawn ->
## "holding"; the raider goes "held". It ends in a takedown (the raider "fallen", the holders getting up
## before they celebrate) or an escape (the hold let go, the holder "recover"ing on the floor).
##
## An ankle hold: the defender's hands close round the lower leg they actually reached. That foot stays where
## it was caught, so the raider has to stretch away from it, and only when his leg is at full stretch does
## he drag the holder (and the foot) along the floor. The holder's body is brought in, no faster than a body
## slides, to keep his reach on the leg, and his arms reach the rest of the way (RiggedBody.hand_target).

const CONTACT_R := 0.3         # m: a hand this close to the raider's lower leg (ankle to mid shin) grips it
const LEG_REACH := 0.55        # m from the hips (flat) to a held foot: further and he drags it
const BODY_FOLLOW := 2.5       # m/s the holder's body may be moved, beyond the drag itself, to keep his reach
const LET_GO := 0.15           # s for the hands to come off when a hold breaks
const TRIP_HOLD := 0.7         # s the holders keep hold while a tackled raider goes down
const ARMS_OUT := 0.3          # share of a dive after which the arms are out and can grip

static var _next_id := 1

var id := 0
var raider: Athlete
var holds: Array = []          # {who, kind, side, at (world: where the held ankle joint is kept), since}
var state := "holding"         # "holding" -> "takedown" -> "done"; or "holding" -> "done" by escapes
var t := 0.0


func _init(r: Athlete) -> void:
	id = _next_id
	_next_id += 1
	raider = r
	# The held raider is posed first each frame, so holders reach for where his legs are now.
	_priority(r, -1)


## The hand of a diving defender that is on the raider's lower leg, if any: {"side", "gap"}. Only during the
## part of the dive with the arms out (or just after he lands, still reaching), only going at the raider, and
## only on a leg no one else holds. With flat (the raider is in the air), heights are left out: hands
## passing under his feet are what he has to clear, and whether he does is the lion jump's business.
static func ankle_contact(d: Athlete, r: Athlete, taken: Array, flat := false) -> Dictionary:
	var reaching := false
	if d.state == "dive":
		reaching = d.st_t / maxf(d.st_len, 0.01) >= ARMS_OUT
	elif d.state == "recover":
		reaching = d.reach_t > 0.0
	if not reaching or d.model == null or r.model == null:
		return {}
	var best := {}
	var gap := CONTACT_R
	for s in ["l", "r"]:
		if taken.has(s):
			continue
		var a: Vector3 = r.model.anchor("ankle_" + s)
		var b: Vector3 = r.model.anchor("shin_" + s)
		if flat:
			a.y = 0.0
			b.y = 0.0
		for hs in ["l", "r"]:
			var h: Vector3 = d.model.anchor("hand_" + hs)
			if flat:
				h.y = 0.0
			var e := _seg_dist(h, a, b)
			# Going at him: the leg is in front of the defender, not behind him.
			var ahead := Vector3(a.x - d.position.x, 0.0, a.z - d.position.z)
			if e < gap and ahead.dot(d.facing) > 0.0:
				gap = e
				best = {"side": s, "gap": e}
	return best


func has(d: Athlete) -> bool:
	return _find(d) >= 0


func sides_taken() -> Array:
	var out := []
	for h in holds:
		out.append(h.side)
	return out


## A hold confirmed: d has the raider's leg on side s.
func add(d: Athlete, kind: String, s: String) -> void:
	var at: Vector3 = raider.model.anchor("foot_" + s)
	holds.append({"who": d, "kind": kind, "side": s, "at": at, "since": t})
	_priority(d, 1)
	_reach(d, s, 1.0)
	_pin(s, at, 1.0)


## A hold broken (an escape, a dubki, the hold given up): the foot comes free at once, the hands open on
## the spot where the leg was over LET_GO.
func release(d: Athlete) -> void:
	var i := _find(d)
	if i < 0:
		return
	var h: Dictionary = holds[i]
	holds.remove_at(i)
	_pin(String(h.side), Vector3.ZERO, 0.0)
	_open_hands(d)
	_priority(d, 0)
	if holds.is_empty() and state == "holding":
		_end()


## The raider goes down: the holders keep hold, the held foot stays caught as he falls (a trip), then they
## let go and get up (see update).
func takedown() -> void:
	state = "takedown"
	t = 0.0


## Every frame: the held foot kept where it was caught, dragged only when he stretches past his leg; the
## holders' bodies kept within reach of it and their hands on it.
func update(dt: float) -> void:
	t += dt
	if state == "done":
		return
	for h in holds:
		var d: Athlete = h.who
		var s: String = h.side
		var at: Vector3 = h.at
		if state == "holding":
			var hip := Vector3(raider.position.x, 0.0, raider.position.z)
			var flat := Vector3(at.x, 0.0, at.z)
			if flat.distance_to(hip) > LEG_REACH:
				flat = hip + (flat - hip).normalized() * LEG_REACH
				at = Vector3(flat.x, at.y, flat.z)
				h.at = at
			_pin(s, at, 1.0)
		else:
			# Going down: the foot is let go of gradually as he falls past it.
			_pin(s, at, clampf(1.0 - t / TRIP_HOLD, 0.0, 1.0))
		# The holder's body: where his hands, as his own pose puts them, would be on the leg.
		var goal: Vector3 = raider.model.anchor("ankle_" + s)
		var rig: RiggedBody = d.model.rig if d.model else null
		var free: Vector3 = rig.hands_free if rig and rig.hands_free != Vector3.INF else d.position
		var want := d.position + Vector3(goal.x - free.x, 0.0, goal.z - free.z)
		var step := want - d.position
		var lim := (BODY_FOLLOW + raider.vel.length()) * dt
		if step.length() > lim:
			step = step.normalized() * lim
		d.position += step
		d.vel = step / maxf(dt, 0.0001)
		d.hold_offset = d.position - raider.position
		d.face_toward(goal, dt, 12.0)
	if state == "takedown" and t >= TRIP_HOLD:
		for h in holds.duplicate():
			_open_hands(h.who)
			_priority(h.who, 0)
		holds.clear()
		_end()


## Take every hand and foot target off (the raid is over or reset).
func clear() -> void:
	for h in holds:
		_open_hands(h.who, true)
		_priority(h.who, 0)
	holds.clear()
	_end()


func _end() -> void:
	state = "done"
	for s in ["l", "r"]:
		_pin(s, Vector3.ZERO, 0.0)
	_priority(raider, 0)


func _find(d: Athlete) -> int:
	for i in holds.size():
		if holds[i].who == d:
			return i
	return -1


func _pin(s: String, at: Vector3, w: float) -> void:
	var rig: RiggedBody = raider.model.rig if raider.model else null
	if rig == null:
		return
	if w <= 0.0:
		rig.foot_goal.erase(s)
	else:
		rig.foot_goal[s] = [at, w]


## Both hands round the held leg: one at the ankle, one a hand's width up the shin.
func _reach(d: Athlete, s: String, w: float) -> void:
	var rig: RiggedBody = d.model.rig if d.model else null
	if rig == null:
		return
	rig.hand_target["r"] = {"model": raider.model, "part": "ankle_" + s, "w": w, "fade": 0.0}
	rig.hand_target["l"] = {"model": raider.model, "part": "shin_" + s, "w": w, "fade": 0.0}


func _open_hands(d: Athlete, now := false) -> void:
	var rig: RiggedBody = d.model.rig if d.model else null
	if rig == null:
		return
	for hs in rig.hand_target.keys():
		if now:
			rig.hand_target.erase(hs)
		else:
			# Stay where the leg was and fade out.
			var ht: Dictionary = rig.hand_target[hs]
			if ht.get("model") != null and is_instance_valid(ht.model):
				ht["point"] = (ht.model as HumanModel).anchor(String(ht.part))
			ht["model"] = null
			ht["fade"] = 1.0 / LET_GO


static func _priority(a: Athlete, p: int) -> void:
	if a == null:
		return
	a.process_priority = p
	if a.model:
		a.model.process_priority = p


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var k := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * k)
