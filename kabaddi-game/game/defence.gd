class_name DefenceCoach
extends RefCounted
## The defending team's shape during a raid: a role and a place for every defender, worked out together each
## frame so they cover the raider between them instead of each going after him on his own.
##
## Roles (the place each one gives):
##   "line"     his place in the line, sliding with the raider and giving ground when he comes close;
##   "mark"     the man the raider is working on: holds his ground in front of him (he is the one who goes);
##   "cover"    the two either side of the mark: in a little, near enough to tackle or to help;
##   "lane"     once the raid is on (a touch, the raider deep, the raider running home): in his way home, one
##              lane each, the two best placed;
##   "contain"  the rest once the raid is on, and anyone left over while he is held: spread round his way
##              home, further off;
##   "help"     the raider is held: to a hold of his own (Grapple.claim, approach).
## A defender is given a role by how quickly he can get to its place (and how good a tackler he is, for the
## places nearest the raider), the best placed first. No two places are closer than SPOT_GAP (linked pairs
## aside). Each defender changes role or place only after his own reaction time (REACT, quicker for agile
## players), so the shape moves like people and not like one machine.

const SPOT_GAP := 1.05         # m: no two defenders' places closer than this
const LANE_AHEAD := 1.4        # m: lanes are this far from the raider toward the midline ...
const LANE_GAP := 1.15         # ... and this far apart across
const CONTAIN_R := 2.4         # m: contain places round the raider on his way home
const HELP_R := 4.2            # m: team-mates this close come to help when he is held
const REACT := Vector2(0.12, 0.38)   # s: reaction time, agile to slow
const SPEED := {"line": 2.4, "mark": 2.0, "cover": 2.4, "lane": 4.0, "contain": 3.2, "help": 9.0}

var m   # the Match
var plan := {}                 # Athlete -> {role, at, next_role, next_at, wait}


func _init(p_match) -> void:
	m = p_match


## A fresh raid: everyone back to the line, reaction times drawn anew.
func reset() -> void:
	plan.clear()


## Where d should be going now and how fast: [place, speed, role]. Defenders the coach has no plan for (busy
## diving, holding, getting up, or the player's own) keep to the line.
func order(d: Athlete) -> Array:
	var p: Dictionary = plan.get(d, {})
	if p.is_empty():
		return [m.formation_spot(d), SPEED.line, "line"]
	var role: String = p.role
	return [p.at, float(SPEED.get(role, 2.4)) * (1.0 if role in ["help", "lane"] else 1.0), role]


func role_of(d: Athlete) -> String:
	return String(plan.get(d, {}).get("role", "line"))


## Work out every free defender's role and place for this frame.
func update(dt: float) -> void:
	var r: Athlete = m.raider
	if r == null:
		return
	var defs: Array = m.defenders()
	var free := defs.filter(func(d): return d.state in ["ready", "idle"] and d != m.controlled and not m.raid.holders.has(d))
	var held: bool = not (m.raid.holders as Array).is_empty()
	var dep: float = m.depth_in(1 - m.raiding, r.position)
	var inside: bool = m.raid.entered and dep > 0.0
	var home := Vector3(0, 0, m.side(m.raiding))
	var on: bool = bool(m.raid.alarm) or (inside and dep > Arena.BONUS + 0.3) or (inside and r.vel.dot(home) > 2.0 and not m.raid.touched.is_empty())
	var want := {}   # Athlete -> [role, place]
	var left := free.duplicate()
	if held:
		# Help: each one near enough to a hold of his own.
		for d in left.duplicate():
			if m.grapple and d.position.distance_to(r.position) < HELP_R:
				var slot: String = m.grapple.claim(d)
				if slot != "":
					want[d] = ["help", m.grapple.approach(slot, d)]
					left.erase(d)
		_assign(want, left, _contain_spots(r, home, left.size()), "contain")
	elif on and inside:
		# The raid is on. Running for home, he is cut off where he can be caught: each defender's place is where
		# he would meet him on his run, and the two who meet him soonest go there. Otherwise the best placed two
		# stand in his way home. The rest spread round it, further off.
		var going := Vector3(r.vel.x, 0, r.vel.z)
		if going.dot(home) > 1.2:
			var cuts := []
			for d in left:
				var meet := _intercept(r.position, going, d)
				if meet != Vector3.INF:
					cuts.append([meet.y, d, Vector3(meet.x, 0, meet.z)])
			cuts.sort_custom(func(a, b): return a[0] < b[0])
			for c in cuts.slice(0, 2):
				want[c[1]] = ["lane", c[2]]
				left.erase(c[1])
		if not want.values().any(func(w): return String(w[0]) == "lane"):
			var lanes := []
			for k in [-0.5, 0.5]:
				lanes.append(_inside_court(r.position + home * LANE_AHEAD + Vector3(k * LANE_GAP, 0, 0)))
			_assign(want, left, lanes, "lane")
		_assign(want, left, _contain_spots(r, home, left.size()), "contain")
	else:
		# Working the cover: the line holds its shape round the man he is working on.
		var mark: Athlete = m.raid.get("ai_mark")
		if mark == null or not left.has(mark):
			mark = _nearest(left, r.position)
		for d in left:
			var at: Vector3 = m.formation_spot(d)
			at.x += r.position.x * 0.28
			var role := "line"
			if d == mark:
				role = "mark"
			elif mark != null and absi(d.slot - mark.slot) == 1:
				role = "cover"
				# In a little toward the mark, to be in reach of the raider when he goes for him.
				at = at.lerp(mark.position, 0.18)
			# Give ground as he comes close (the footage line pulls back, then goes for him).
			var to := Vector3(r.position.x - d.position.x, 0, r.position.z - d.position.z)
			var dist := to.length()
			if inside and dist < 1.9 and dist > 0.01:
				at -= to / dist * (1.9 - dist) * 1.2
			want[d] = [role, at]
		left.clear()
	_space(want)
	# Take up the new orders after each one's reaction time.
	for d in defs:
		if not want.has(d):
			plan.erase(d)
			continue
		var w: Array = want[d]
		var p: Dictionary = plan.get(d, {})
		if p.is_empty():
			plan[d] = {"role": w[0], "at": w[1], "next_role": w[0], "next_at": w[1], "wait": 0.0}
			continue
		var changed: bool = String(w[0]) != String(p.next_role) or (w[1] as Vector3).distance_to(p.next_at) > 0.6
		p.next_at = w[1]
		if changed:
			p.next_role = w[0]
			p.wait = _react(d)
		p.wait = maxf(0.0, float(p.wait) - dt)
		if p.wait <= 0.0:
			p.role = p.next_role
			p.at = p.next_at
		elif String(p.role) == String(p.next_role):
			p.at = p.next_at   # same job, the place just moves with play


## Give out spots to the best placed of who is left, nearest (in time) first; those given one leave `left`.
func _assign(want: Dictionary, left: Array, spots: Array, role: String) -> void:
	var open := spots.duplicate()
	while not open.is_empty() and not left.is_empty():
		var best_d: Athlete = null
		var best_s := -1
		var best_c := INF
		for d in left:
			for i in open.size():
				var c := _cost(d, open[i], role)
				if c < best_c:
					best_c = c
					best_d = d
					best_s = i
		want[best_d] = [role, open[best_s]]
		left.erase(best_d)
		open.remove_at(best_s)


## How long d takes to get to a spot, worse if he has to run round the raider to get there, better for a good
## tackler when the spot is in the raider's way.
func _cost(d: Athlete, at: Vector3, role: String) -> float:
	var r: Athlete = m.raider
	var t := Vector2(at.x - d.position.x, at.z - d.position.z).length() / maxf(1.0, d.max_speed)
	# Running past the raider to get there gives him the chance he wants.
	var a := Vector2(d.position.x, d.position.z)
	var b := Vector2(at.x, at.z)
	var c := Vector2(r.position.x, r.position.z)
	var ab := b - a
	var k := clampf((c - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	if (a + ab * k).distance_to(c) < 1.0:
		t += 0.6
	if role == "lane":
		t -= 0.25 * (d.tackle - 1.0) + 0.15 * (d.energy - 1.0)
	return t


## Where d can meet a raider running from p at velocity v, before he is home: x and z the place, y the time
## it takes (INF if he cannot: the raider is home first, or too quick for him).
func _intercept(p: Vector3, v: Vector3, d: Athlete) -> Vector3:
	var to := Vector3(p.x - d.position.x, 0, p.z - d.position.z)
	var spd: float = d.max_speed * 0.95
	var a := v.dot(v) - spd * spd
	var b := 2.0 * v.dot(to)
	var c := to.dot(to)
	var t := INF
	if absf(a) < 0.0001:
		if b < 0.0:
			t = -c / b
	else:
		var disc := b * b - 4.0 * a * c
		if disc >= 0.0:
			var sq := sqrt(disc)
			for x in [(-b - sq) / (2.0 * a), (-b + sq) / (2.0 * a)]:
				if x > 0.05 and x < t:
					t = x
	if t == INF:
		return Vector3.INF
	var meet := p + v * t
	# He has to be still in our half there.
	if m.depth_in(1 - m.raiding, meet) < 0.2:
		return Vector3.INF
	return Vector3(meet.x, t, meet.z)


## Contain places: spread round the raider's way home, further off than the lanes.
func _contain_spots(r: Athlete, home: Vector3, n: int) -> Array:
	var out := []
	if n <= 0:
		return out
	for i in n:
		var a := lerpf(-1.1, 1.1, 0.5 if n == 1 else float(i) / float(n - 1))
		var dir := home.rotated(Vector3.UP, a)
		out.append(_inside_court(r.position + dir * CONTAIN_R))
	return out


## No two places too close: each pair pushed apart, half each (linked pairs keep their hold on each other).
func _space(want: Dictionary) -> void:
	var ds := want.keys()
	for it in 3:
		for i in ds.size():
			for j in range(i + 1, ds.size()):
				var a: Athlete = ds[i]
				var b: Athlete = ds[j]
				if a.chain_partner == b or String(want[a][0]) == "help" or String(want[b][0]) == "help":
					continue
				var pa: Vector3 = want[a][1]
				var pb: Vector3 = want[b][1]
				var d := Vector3(pb.x - pa.x, 0, pb.z - pa.z)
				var l := d.length()
				if l < SPOT_GAP:
					var push := (d / l if l > 0.01 else Vector3(1, 0, 0)) * (SPOT_GAP - l) * 0.5
					want[a][1] = _inside_court(pa - push)
					want[b][1] = _inside_court(pb + push)


func _inside_court(p: Vector3) -> Vector3:
	var t: int = 1 - m.raiding
	var bound := Arena.HALF_W + (Arena.LOBBY if m.raid.get("struggle", false) else 0.0) - 0.4
	p.x = clampf(p.x, -bound, bound)
	var dd: float = clampf(m.depth_in(t, p), 0.4, Arena.HALF_L - 0.4)
	p.z = dd * m.side(t)
	p.y = 0.0
	return p


func _nearest(pool: Array, p: Vector3) -> Athlete:
	var best: Athlete = null
	var bd := INF
	for d in pool:
		var g: float = d.position.distance_to(p)
		if g < bd:
			bd = g
			best = d
	return best


## A defender's reaction time: quicker for agile players, a little different every time.
func _react(d: Athlete) -> float:
	var q := clampf((d.agility - 0.7) / 0.6, 0.0, 1.0)
	return lerpf(REACT.y, REACT.x, q) * randf_range(0.8, 1.2)
