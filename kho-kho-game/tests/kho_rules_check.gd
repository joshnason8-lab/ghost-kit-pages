extends RefCounted
## Kho kho's rules, checked after every simulated frame of a real match (the owner's simulation testing): what a
## match may never do, whatever the AI or a thumb does. Reads the match; changes nothing. A broken rule is kept with
## the match's seed and the moment, so it can be played again.
##   var chk := KhoRulesCheck.new(match)      then, each frame:   chk.frame(dt)      at the end:   chk.finish()

const MAX_SPEED := 13.0      # m/s: faster than any runner (a pole swing's exit is about 8)
const AGAINST_S := 0.6       # s a chaser may run against his direction before a foul must have been called

var m: Node
var fails: Array = []        # [{t, seed, rule, detail}]
var _score := [0, 0]
var _dream := 0
var _clock := INF
var _turn := -1
var _phase := ""
var _state := {}            # Athlete -> his state last frame
var _against := 0.0
var _last := {}              # Athlete -> position last frame


func _init(p_m: Node) -> void:
	m = p_m


func _fail(rule: String, detail: String) -> void:
	# The same rule broken again in the next second is the same failure (not one a frame).
	for f in fails:
		if f.rule == rule and float(m.t_match) - float(f.t) < 1.0:
			return
	fails.append({"t": snappedf(float(m.t_match), 0.01), "seed": int(m.config.get("seed", -1)), "rule": rule,
		"detail": detail, "turn": int(m.turn), "phase": String(m.phase)})


func frame(dt: float) -> void:
	if not m.built:
		return
	var phase: String = m.phase
	if not phase in ["intro", "ready", "choose", "play", "turn_end", "interval", "over"]:
		_fail("phase", "unknown phase %s" % phase)
	# The score: only ever up; the defending side scores only dream-run points.
	for s in 2:
		var sc: int = m.score[s]
		if sc < int(_score[s]):
			_fail("score down", "side %d: %d -> %d" % [s, _score[s], sc])
		if sc > int(_score[s]) and s != int(m.chasing) and int(m.dream_paid) == _dream and phase == "play":
			_fail("score for the defence", "side %d +%d with no dream-run point" % [s, sc - int(_score[s])])
		_score[s] = sc
	_dream = int(m.dream_paid)
	# A new turn: its own outs, its own clock.
	if int(m.turn) != _turn:
		_turn = int(m.turn)
		_clock = INF
		_last.clear()   # (everyone is put in his place for the turn: no speed across it)
	var clock: float = m.clock
	if phase == "play":
		if clock > _clock + 0.001 and _clock != INF:
			_fail("clock up", "%.3f -> %.3f" % [_clock, clock])
		if clock < -0.5:
			_fail("clock past zero", "%.2f" % clock)
		_clock = clock
	# The chasers: one active, of the chasing side, and the rest seated in their squares (or walking to one).
	if phase == "play":
		var a: Athlete = m.active
		if a == null:
			_fail("no active chaser", "")
		elif not (m.chase_line[m.chasing] as Array).has(a):
			_fail("active chaser not a chaser", String(a.data.get("name", "")))
		var seated := 0
		for q in m.squares:
			if q != null:
				seated += 1
		var want: int = (m.chase_line[m.chasing] as Array).size() - 1
		if seated + (m._to_square as Dictionary).size() + (0 if (m._pending_kho as Dictionary).is_empty() else 1) < want:
			_fail("chasers missing", "%d seated + %d walking, want %d" % [seated, m._to_square.size(), want])
	# The defenders: at most three in at once; one out stays out this turn. (Between turns the next turn's side is set
	# up - one out two turns ago is in again, rightly - so "out" is only remembered through a turn's play.)
	if phase != "play":
		_state.clear()
	var ins := 0
	for d in m.d_state:
		var st: String = m.d_state[d]
		if not st in ["wait", "enter", "in", "out"]:
			_fail("defender state", st)
		if st == "in":
			ins += 1
			# Back in only by being called up again with a new batch (once every batch is out, they come round
			# again in order), never straight from out.
			if String(_state.get(d, "")) == "out":
				_fail("out and back in", String(d.data.get("name", "")))
		if phase == "play":
			_state[d] = st
	if ins > 3:
		_fail("too many defenders in", "%d" % ins)
	# Every body: somewhere real, at a runner's speed at most.
	if phase != "play":
		_last.clear()   # (between turns and at the batch's walk-on, bodies are placed, not run)
	for a in m.everyone():
		var p: Vector3 = a.position
		if not (is_finite(p.x) and is_finite(p.z)):
			_fail("position not finite", String(a.name))
			continue
		if absf(p.x) > float(m.f.length) + 30.0 or absf(p.z) > float(m.f.width) + 30.0:
			_fail("body far away", "%s at %s" % [a.name, p])
		if _last.has(a) and dt > 0.0:
			var v := (p - (_last[a] as Vector3)).length() / dt
			if v > MAX_SPEED and a.act != "pole_turn":
				_fail("too fast", "%s %.1f m/s (%s)" % [String(a.data.get("name", a.name)), v, a.act])
		_last[a] = p
	# The direction rule: the active chaser (not a wazir, outside the free zones) never runs back against his
	# direction for long without the umpire calling it.
	if phase == "play" and m.active and int(m.chase.dir) != 0 and not (m.wazir_ids as Array).has(m.active.data.get("id", "")):
		var a: Athlete = m.active
		if not KhoRules.in_free_zone(m.f, a.position) and a.vel.x * float(m.chase.dir) < -2.0 and String(m.chase.foul) == "" \
				and not a.act in ["pole_turn", "dive", "pole_dive", "lie", "getup", "kho", "rise"]:
			_against += dt
			if _against > AGAINST_S:
				_fail("against the direction, no foul", "%.1f m/s for %.1f s" % [a.vel.x * float(m.chase.dir), _against])
		else:
			_against = 0.0


## At the end: a match must end, in its turns.
func finish(ended: bool, max_turns: int) -> void:
	if not ended:
		_fail("never ended", "turn %d, phase %s, %.0f s" % [m.turn, m.phase, m.t_match])
	if int(m.turn) + 1 > max_turns + 2 * int(m.extra) + 2:
		_fail("too many turns", "%d" % (int(m.turn) + 1))
