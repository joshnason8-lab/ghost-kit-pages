extends Node
## godot --headless --path . --fixed-fps FPS res://tests/move_mix_probe.tscn -- SEED [arena]
## One AI-vs-AI quick match (as the suite's section 9), and the moves its raiders tried and landed: the same seed at
## different --fixed-fps should give about the same mix (move choice by the second, not by the frame).

var done := false
var result := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Game.main = self
	Game.settings.sound = false
	Game.loading_overlay = false
	Game.start_match({"home": "MUM", "away": "DEL", "arena": args[1] if args.size() > 1 else "village", "mode": "quick",
		"autoplay": true, "length": 0, "difficulty": 1, "knockout": true, "seed": int(args[0]) if args.size() > 0 else 9})
	var m: Node = Game.current
	m.finished.connect(func(r):
		done = true
		result = r)
	var n := 0
	while not done and n < 60 * 60 * 15:
		await get_tree().process_frame
		n += 1
	var used := {}
	var tried: Dictionary = result.get("move_tries", {})
	for r in result.get("raid_log", []):
		for mv in r.get("moves", []):
			used[mv] = used.get(mv, 0) + 1
	print("MIX fps %d seed %s raids %d landed %s tried %s" % [roundi(1.0 / get_process_delta_time()),
		args[0] if args.size() > 0 else "9", result.get("raid_log", []).size(), JSON.stringify(used), JSON.stringify(tried)])
	get_tree().quit(0)
