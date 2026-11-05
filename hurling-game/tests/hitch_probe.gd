extends Node
## Where a match's frames go, and its hitches: an AI match at the biggest venue at a graphics level, each frame's whole
## time on this machine's CPU (the logic, the animation, the skinning's bones, the crowd's and flags' updates), with
## parts switched off to see each one's share:
##   godot --headless --path . --fixed-fps 60 res://tests/hitch_probe.tscn -- [level] [seconds] [off...]
## off: noreplay (the replay ring's recording), nocrowd (the 3D crowd), noflags, nolink (the foundation: WSG_OFF=1
## instead). Prints the frame time's middle, its worst 5% and 1%, the worst frame, and the frames over 2.5x the
## middle with what the match was doing.

var frames := PackedFloat32Array()
var notes := []
var _t := 0
var m: Node


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	var level := int(a[0]) if a.size() > 0 else Game.GFX_HIGH
	var secs := float(a[1]) if a.size() > 1 else 60.0
	Game.main = self
	Game.settings.sound = false
	Game.settings.coach = false
	Game.settings.graphics = level
	Game.settings.auto_gfx = false
	ToonBody.material(level > Game.GFX_LOW)
	Game.start_match({"home": "KIL", "away": "TIP", "venue": "stadium", "user_team": -1, "seed": 4, "mode": "sim_test", "length": 14})
	await get_tree().process_frame
	m = Game.current
	m.set_meta("test", true)
	for i in 120:
		await get_tree().process_frame
	if "noreplay" in a and m.wsg_replay:
		m.wsg_replay.queue_free()
		m.wsg_replay = null
	if "nocrowd" in a and m.stadium.crowd3d:
		m.stadium.crowd3d.queue_free()
		m.stadium.crowd3d = null
	if "noflags" in a:
		for f in m.stadium.find_children("*", "WsgFlags", true, false):
			f.queue_free()
	await get_tree().process_frame
	_t = Time.get_ticks_usec()
	var n := int(secs * 60.0)
	for i in n:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - _t) / 1000.0
		_t = now
		frames.append(ms)
		notes.append("%s %s" % [m.P.keys()[m.phase], "replay" if m.replay and m.replay.playing else ""])
	var s := frames.duplicate()
	s.sort()
	var mid := s[s.size() / 2]
	print("hitch probe: level %d %s, %d frames: middle %.2f ms, worst 5%% %.2f, worst 1%% %.2f, worst %.2f" % [level, a.slice(2),
		s.size(), mid, s[int(s.size() * 0.95)], s[int(s.size() * 0.99)], s[-1]])
	var hitches := 0
	for i in frames.size():
		if frames[i] > mid * 2.5:
			hitches += 1
			if hitches <= 12:
				print("  frame %d: %.1f ms (%s)" % [i, frames[i], notes[i]])
	print("  %d frames over 2.5x the middle" % hitches)
	get_tree().quit()
