extends Node
## An AI-v-AI match to record (the movie writer) or to compare with the audited one: no overlay, every game event
## printed at its time. With trace=FILE it writes every player's place and state in every frame of every raid, as
## tests/raid_audit --trace has them, so a recording can be checked against the audit's own run of the same seed,
## frame for frame (the audit's reads of the bodies do not change the match). Like the audit, it begins the match
## once the engine's frame steps are steady (tests/raid_audit, _steady).
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 --fixed-fps 30 --write-movie m.avi \
##       res://tests/match_record.tscn -- [SECONDS] [close] [seed=N] [home=MUM] [away=DEL] [trace=FILE]

var _f := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var secs := float(args[0]) if args.size() > 0 and args[0].is_valid_float() else 90.0
	var s := 1
	var home := "MUM"
	var away := "DEL"
	var trace := ""
	for a in args:
		if String(a).begins_with("seed="):
			s = int(String(a).substr(5))
		elif String(a).begins_with("home="):
			home = String(a).substr(5)
		elif String(a).begins_with("away="):
			away = String(a).substr(5)
		elif String(a).begins_with("trace="):
			trace = String(a).substr(6)
	Game.settings.models = 1
	Game.settings.camera = Game.CAM_THIRD if args.has("close") else Game.CAM_TV
	var run := 0
	for i in 60:
		await get_tree().process_frame
		run = run + 1 if is_equal_approx(get_process_delta_time(), 1.0 / 30.0) else 0
		if run >= 5:
			break
	seed(s)
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": home, "away": away, "arena": "dome", "mode": "quick", "autoplay": true, "autoplay_no_report": true,
		"length": 0, "difficulty": 1, "seed": s}
	var done := [false]
	m.finished.connect(func(_r): done[0] = true)
	add_child(m)
	m.game_event.connect(func(kind, info):
		var keep := {}
		for k in info:
			if k in ["style", "who", "by", "points", "outcome", "pts", "slot", "move"]:
				keep[k] = str(info[k])
		print("EV %.2f %s %s" % [_f / 30.0, kind, keep]))
	var rows := []
	for f in int(secs * 30.0):
		_f = f
		await get_tree().process_frame
		if trace != "" and m.phase in ["raid", "post"] and m.raider != null:
			var row := []
			for a in m.athletes:
				if a.on_mat:
					row.append("%s %.6f %.6f %s %.4f" % [a.pid(), a.position.x, a.position.z, a.state, a.st_t])
			rows.append(row)
		if done[0]:
			break
	if trace != "":
		var fa := FileAccess.open(trace, FileAccess.WRITE)
		fa.store_string(JSON.stringify(rows))
		fa.close()
	print("match_record: %d frames, %d traced, %s" % [_f + 1, rows.size(), "finished" if done[0] else "cut off"])
	get_tree().quit()
