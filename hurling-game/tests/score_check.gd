extends Node
## The scoring check: AI v AI matches at every length the game offers, the scores held to real hurling's (docs/AI.md:
## about 2.75 goals, 42 points and 77 shots a 70-minute senior match, both sides, the ball live about 27 minutes of
## it). At the longest length the clock runs in real time while the ball is live, so the match must come out as a real
## one; the shorter lengths are the same game with less of it live, so they must score in proportion.
## godot --headless --path . --fixed-fps 30 res://tests/score_check.tscn -- [matches a length] [lengths, comma-separated]

const REAL := {"goals": 2.75, "points": 42.0, "shots": 77.0, "live_min": 26.6}

var n := 2
var failures := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		n = int(args[0])
	var lengths: Array = Game.LENGTHS.duplicate()
	if args.size() > 1:
		lengths = Array(String(args[1]).split(",")).map(func(x): return int(x))
	Game.main = self
	Game.settings.sound = false
	Game.settings.grade = 0
	var ids := DB.counties_ranked()
	var all := {"goals": 0.0, "points": 0.0, "shots": 0.0, "scores": 0.0, "live": 0.0}
	print("length  real min  live min   goals  points  shots   (means a match, both sides)")
	for li in lengths.size():
		var length := float(lengths[li])
		var sum := {"goals": 0.0, "points": 0.0, "shots": 0.0, "scores": 0.0, "live": 0.0, "real": 0.0, "sidelines": 0.0}
		for i in n:
			var home: String = ids[(i * 2 + li) % 6]
			var away: String = ids[(i * 2 + li + 3) % 6]
			var cfg := {"home": home, "away": away, "venue": "county", "user_team": -1, "seed": 500 + li * 10 + i, "length": length, "mode": "sim_test"}
			var m: Node = load("res://game/match.gd").new()
			m.config = cfg
			m.set_meta("test", true)
			add_child(m)
			var frames := 0
			while m.phase != m.P.OVER and frames < int(length * 60.0 * 30.0 * 2.0):
				await get_tree().process_frame
				frames += 1
			var s: Array = m.score
			print("   %s %s v %s %s" % [home, Rules.fmt(s[0][0], s[0][1]), Rules.fmt(s[1][0], s[1][1]), away])
			_check(m.phase == m.P.OVER, "%d min: the match ends" % int(length))
			sum.real += frames / 1800.0
			sum.live += float(m.live_real) / 60.0
			for k in 2:
				sum.goals += int(s[k][0])
				sum.points += int(s[k][1])
				sum.shots += int(m.tstats[k].shots)
				sum.sidelines += int(m.tstats[k].sidelines)
				sum.scores += int(m.tstats[k].scores_play) + int(m.tstats[k].scores_placed)
			m.queue_free()
			await get_tree().process_frame
		for key in sum:
			if all.has(key):
				all[key] += sum[key]
		var mean := {}
		for key in sum:
			mean[key] = sum[key] / n
		print("%4d    %6.1f   %6.1f    %5.2f  %6.1f  %5.1f" % [int(length), mean.real, mean.live, mean.goals, mean.points, mean.shots])
		# The match takes about as long as the length says, and has the ball live in proportion.
		_check(mean.real > length * 0.8 and mean.real < length * 1.3, "%d min: takes %.1f real minutes" % [int(length), mean.real])
		var share: float = mean.live / REAL.live_min
		# Its scoring: a real match's, scaled by how long the ball was live (wide bounds: two matches are few).
		var want_p: float = REAL.points * share
		_check(mean.points > want_p * 0.6 and mean.points < want_p * 1.45, "%d min: %.1f points a match (real hurling for that much play: %.1f)" % [int(length), mean.points, want_p])
		_check(mean.goals <= REAL.goals * share * 2.6 + 0.5, "%d min: %.2f goals a match (real: %.2f)" % [int(length), mean.goals, REAL.goals * share])
		if length >= Game.LENGTHS[-1]:
			_check(mean.live > 21.0 and mean.live < 32.0, "full length: the ball live %.1f minutes (real: about 27)" % mean.live)
			_check(mean.points >= 30.0 and mean.points <= 55.0, "full length: %.1f points (real: about 42)" % mean.points)
			_check(mean.goals <= 6.0, "full length: %.2f goals (real: 2.5-3)" % mean.goals)
			_check(mean.shots >= 55.0 and mean.shots <= 100.0, "full length: %.1f shots (real: about 77)" % mean.shots)
			_check(mean.sidelines >= 3.0, "full length: %.1f sideline cuts (real: a good many more)" % mean.sidelines)
	# Over every match: the rate of scoring while the ball is live, and how many shots score.
	var per := func(k: String) -> float: return all[k] / maxf(1.0, all.live)
	print("a live minute: %.2f points (real %.2f), %.3f goals (real %.3f), %.2f shots (real %.2f); %.0f%% of shots score (real 60%%)" % [
		per.call("points"), REAL.points / REAL.live_min, per.call("goals"), REAL.goals / REAL.live_min, per.call("shots"), REAL.shots / REAL.live_min,
		100.0 * all.scores / maxf(1.0, all.shots)])
	_check(per.call("points") > 1.15 and per.call("points") < 2.1, "points a live minute")
	_check(per.call("goals") < 0.22, "goals a live minute")
	_check(per.call("shots") > 2.0 and per.call("shots") < 3.8, "shots a live minute")
	_check(all.scores / maxf(1.0, all.shots) > 0.45 and all.scores / maxf(1.0, all.shots) < 0.75, "shots that score")
	print("score_check: %s" % ("PASS" if failures == 0 else "%d FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL  " + what)
