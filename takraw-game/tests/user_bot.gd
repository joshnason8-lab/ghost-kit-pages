extends Node
## Plays a set as you would, pressing the first button of each touch at the moment (or late, or never), to check the
## controls' side of the match: every window opens and closes, every touch is made, the block button works.
##   godot --headless --path . --fixed-fps 60 res://tests/user_bot.tscn -- [perfect|late|idle] [assist]

var mode := "perfect"
var m: Node
var pressed := {}
var stats := {"windows": 0, "presses": 0, "blocks": 0}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	mode = a[0] if a.size() > 0 else "perfect"
	Game.main = self
	Game.settings.sound = false
	Game.settings.assist = int(a[1]) if a.size() > 1 else 1
	m = (load("res://game/match.gd") as Script).new()
	m.config = {"home": "MAS", "away": "THA", "venue": "national", "event": "regu", "sets": 1, "points": 15, "user_team": 0,
		"demo": true, "seed": 9, "mode": "quick", "difficulty": 1}
	add_child(m)
	m.finished.connect(_done)


func _process(_d: float) -> void:
	if m == null or not is_instance_valid(m):
		return
	var w: Dictionary = m.input_window
	if not w.is_empty():
		var key := str(w.t)
		if not pressed.has(key):
			pressed[key] = false
			stats.windows += 1
		var due: float = float(w.t) + (0.12 if mode == "late" else 0.0)
		if mode != "idle" and not bool(pressed[key]) and float(m.now) >= due - 0.008:
			pressed[key] = true
			stats.presses += 1
			m._on_action(String((w.choices as Array)[0]))
	var b: Dictionary = m.block
	if mode != "idle" and not b.is_empty() and bool(b.get("user", false)) and not b.has("jump_t"):
		if float(m.now) >= float(b.t) - Moves.contact_time("block") - 0.01:
			stats.blocks += 1
			m._on_action("BLOCK")


func _done(r: Dictionary) -> void:
	print("%s (assist %d): sets %s %s, windows %d, presses %d, block jumps %d; ended by %s" % [mode, int(Game.settings.assist), r.sets,
		r.set_scores, stats.windows, stats.presses, stats.blocks, _how(r.log)])
	get_tree().quit()


func _how(log: Array) -> Dictionary:
	var h := {}
	for x in log:
		var k := "%s:%d" % [x[1], int(x[2])]
		h[k] = int(h.get(k, 0)) + 1
	return h
