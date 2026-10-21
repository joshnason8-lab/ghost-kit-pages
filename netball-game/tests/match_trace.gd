extends Node
## A match's events as they happen, with the time and phase, for finding where play stalls:
##   godot --headless --path . --fixed-fps 30 res://tests/match_trace.tscn -- SECONDS

var m: Match
var t := 0.0


func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	var secs := 120.0
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		secs = float(args[0])
	m = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "AUS", "away": "NZL", "venue": "arena", "user_team": -1, "demo": true, "seed": 13, "quarter": 15, "mode": "quick"}
	add_child(m)
	m.game_event.connect(func(k, info):
		print("%6.1f %-6s %-12s %s" % [t, m.phase, k, info]))
	var last_phase := ""
	while t < secs:
		await get_tree().process_frame
		t += 1.0 / 30.0
		if m.phase != last_phase:
			print("%6.1f phase -> %s (holder %s, ball %s)" % [t, m.phase, m.holder.pos + str(m.holder.team) if m.holder else "-", m.ball.state])
			last_phase = m.phase
	var att := 0
	for id in m.stats:
		att += int(m.stats[id].attempts)
	print("score %s, attempts %d, calls %s" % [m.score, att, m.calls])
	get_tree().quit()
