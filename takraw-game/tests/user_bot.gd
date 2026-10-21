extends Node
## Plays a set as you would: runs your player to the gold mark with the joystick and presses the first button of each
## touch at the moment (or late, or without running, or never), to check the controls' side of the match: nothing is
## played for you, a good player wins rallies, an idle one wins none.
##   godot --headless --path . --fixed-fps 60 res://tests/user_bot.tscn -- [perfect|late|still|idle] [assist] [speed]
## With a display and an output folder last, it also saves pictures of your touches (the mark, the ring):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tests/user_bot.tscn -- perfect 1 0 /out/dir

var mode := "perfect"
var m: Node
var pressed := {}
var stats := {"windows": 0, "presses": 0, "blocks": 0}
var out := ""
var shots := 0
var _f := 0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	mode = a[0] if a.size() > 0 else "perfect"
	Game.main = self
	Game.settings.sound = false
	Game.settings.assist = int(a[1]) if a.size() > 1 else 1
	Game.settings.game_speed = int(a[2]) if a.size() > 2 else 0
	if a.size() > 3:
		out = a[3]
		DirAccess.make_dir_recursive_absolute(out)
		Game.settings.graphics = Game.GFX_HIGH
	m = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "MAS", "away": "THA", "venue": "national", "event": "regu", "sets": 1, "points": 15, "user_team": 0,
		"demo": true, "seed": 9, "mode": "quick", "difficulty": 1}
	add_child(m)
	m.finished.connect(_done)


func _process(_d: float) -> void:
	if m == null or not is_instance_valid(m):
		return
	var p: Dictionary = m.plan
	var mine: bool = not p.is_empty() and bool(p.get("user", false))
	m.controls.joystick = Vector2.ZERO
	if mine:
		var key := "%s/%d" % [str(p.player), int(p.touch)] + str(snappedf(float(m.ball.t_launch), 0.001))
		if not pressed.has(key):
			pressed[key] = false
			stats.windows += 1
		# Run to the mark (the joystick, as seen from the camera).
		if mode in ["perfect", "late"] and not bool(p.get("auto", false)) and String(p.kind) != "serve":
			var pl: Player = p.player
			var st: Vector3 = p.stand
			var d := Vector3(st.x - pl.position.x, 0, st.z - pl.position.z)
			if d.length() > 0.2:
				var basis: Basis = m.cam.global_transform.basis
				var right := Vector3(basis.x.x, 0, basis.x.z).normalized()
				var up := Vector3(-basis.z.x, 0, -basis.z.z).normalized()
				m.controls.joystick = Vector2(d.dot(right), -d.dot(up)).normalized() * minf(1.0, d.length() / 0.4)
		var due: float = float(p.t) + (0.12 if mode == "late" else 0.0)
		if mode != "idle" and not bool(pressed[key]) and not p.has("press_t") and float(m.now) >= due - 0.008:
			pressed[key] = true
			stats.presses += 1
			m._on_action(String((m.input_window.get("choices", ["KICK"]) as Array)[0]))
	_f += 1
	if out != "" and mine and shots < 14 and _f % 9 == 0:
		shots += 1
		get_viewport().get_texture().get_image().save_png(out.path_join("touch%02d.png" % shots))
	var b: Dictionary = m.block
	if mode != "idle" and not b.is_empty() and bool(b.get("user", false)) and not b.has("jump_t"):
		if float(m.now) >= float(b.t) - Moves.contact_time("block") - 0.01:
			stats.blocks += 1
			m._on_action("BLOCK")


func _done(r: Dictionary) -> void:
	# For CI: nothing is played for you (idle wins no point and makes no touch), and a good player wins plenty.
	var mine: int = r.set_scores[0][0] if not r.set_scores.is_empty() else 0
	var ok := true
	if mode == "idle":
		ok = mine == 0 and stats.presses == 0
	elif mode == "perfect":
		ok = mine >= 8
	print("user_bot: %s" % ("ok" if ok else "FAIL (%d points)" % mine))
	print("%s (assist %d, speed %d): sets %s %s, windows %d, presses %d, block jumps %d; ended by %s" % [mode, int(Game.settings.assist), int(Game.settings.game_speed), r.sets,
		r.set_scores, stats.windows, stats.presses, stats.blocks, _how(r.log)])
	get_tree().quit(0 if ok else 1)


func _how(log: Array) -> Dictionary:
	var h := {}
	for x in log:
		var k := "%s:%d" % [x[1], int(x[2])]
		h[k] = int(h.get(k, 0)) + 1
	return h
