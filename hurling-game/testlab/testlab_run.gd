extends Node
## Firebase Test Lab (the shared foundation's .github/workflows/wsg-testlab.yml): the build with the "testlab" feature
## (export preset "Android TestLab") opens here instead of the home screen and plays a match on its own - the
## two counties' AI, the broadcast camera, the full crowd at the national stadium - for 60 seconds at each graphics
## tier, Low, Medium and High, each after 8 seconds to settle; the foundation's WsgPerfLog prints each tier's frame
## rate and memory to the log (WSG_PERF lines), which the workflow reads back. Then it stays on a plain screen
## (a test app that quits is opened again). Input is ignored: Test Lab's robot taps the screen.
##   On a computer: godot --path . res://testlab/testlab_run.tscn [-- seconds [quit]]

const SETTLE := 8.0

var seconds := 60.0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		seconds = float(a[0])
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = false
	get_viewport().gui_disable_input = true
	get_tree().quit_on_go_back = false     # (the robot presses Back too)
	var log := WsgPerfLog.new()
	add_child(log)
	print("WSG_PERF_START ", JSON.stringify({"device": OS.get_model_name(), "gpu": RenderingServer.get_video_adapter_name(),
		"device_class": WsgFoundation.device_class(), "starting_tier": WsgFoundation.starting_tier()}))
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		WsgFoundation.tier = g
		ToonBody.material(g > Game.GFX_LOW)
		Game.start_match({"home": "KIL", "away": "TIP", "venue": "stadium", "user_team": -1, "seed": 4, "mode": "quick", "length": 14})
		await get_tree().create_timer(SETTLE).timeout
		log.begin(["low", "medium", "high"][g], {"tier": g, "venue": "stadium", "players": 30})
		await get_tree().create_timer(seconds).timeout
		log.finish()
	WsgPerfLog.done()
	if Game.current:
		Game.current.queue_free()
	if "quit" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	var l := Label.new()
	l.text = "Test Lab run complete"
	l.position = Vector2(40, 40)
	add_child(l)
