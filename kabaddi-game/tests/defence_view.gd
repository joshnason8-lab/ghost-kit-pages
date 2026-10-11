extends Node
## An AI match with the debug overlay on (DebugDraw: each defender's place in the team's plan, in his role's
## colour; holds' hand targets; planted feet), from the TV camera, for recording:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 960x540 --write-movie out.avi \
##       --fixed-fps 30 res://tests/defence_view.tscn -- [SECONDS]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var secs := float(args[0]) if args.size() > 0 and args[0].is_valid_float() else 40.0
	Game.settings.models = 1
	Game.settings.camera = Game.CAM_TV
	seed(5)
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "autoplay": true, "autoplay_no_report": true,
		"length": 0, "difficulty": 1, "debug_draw": true}
	add_child(m)
	m.rng.seed = 5
	for f in int(secs * 30.0):
		await get_tree().process_frame
	get_tree().quit()
