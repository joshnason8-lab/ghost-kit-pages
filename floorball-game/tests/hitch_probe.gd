extends Node
## Where an AI match's frames go on this machine's CPU, with and without the shared foundation (FoundationLink): each
## frame's whole time (the logic, the posing, the foundation's locomotion, pose layers, grips and helpers, the
## skinning's bones), headless (nothing drawn):
##   godot --headless --path . --fixed-fps 60 res://tests/hitch_probe.tscn -- [level] [seconds]
##   WSG_OFF=1 godot ...      (the same match without the foundation: RiggedBody draws)
## Prints the frame time's middle, its worst 5% and 1%, the worst frame, and the frames over 2.5x the middle.

var frames := PackedFloat32Array()


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var level := int(a[0]) if a.size() > 0 else Game.GFX_MEDIUM
	var secs := float(a[1]) if a.size() > 1 else 60.0
	Game.main = self
	Game.settings.sound = false
	Game.settings.graphics = level
	Game.settings.auto_gfx = false
	Game.start_match({"home": "SWE", "away": "FIN", "venue": "arena", "user_team": -1, "watch": true, "seed": 4, "period": 20.0})
	var m: Node = Game.current
	for i in 240:
		await get_tree().process_frame
	var t := Time.get_ticks_usec()
	for i in int(secs * 60.0):
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - t) / 1000.0)
		t = now
	var s := frames.duplicate()
	s.sort()
	var mid := s[s.size() / 2]
	var mean := 0.0
	for f in frames:
		mean += f
	mean /= frames.size()
	var hitches := 0
	for f in frames:
		if f > mid * 2.5:
			hitches += 1
	var links := 0
	var rates := [0, 0, 0]
	for p in m.everyone():
		if p.link:
			links += 1
			if p.visible:
				rates[clampi(p.pose_every, 1, 3) - 1] += 1
	print("hitch probe: level %d, foundation %s (%d links), %d frames: mean %.2f ms, middle %.2f, worst 5%% %.2f, worst 1%% %.2f, worst %.2f; %d over 2.5x the middle; posed every 1/2/3 frames at the end: %s" % [
		level, "on" if FoundationLink.enabled() else "off", links, s.size(), mean, mid, s[int(s.size() * 0.95)], s[int(s.size() * 0.99)], s[-1], hitches, rates])
	get_tree().quit()
