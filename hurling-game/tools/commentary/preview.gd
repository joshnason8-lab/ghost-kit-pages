extends Node
## A Watch AI match with the commentary on, to hear how it sits on the play: run with Godot's movie writer and it
## comes out as a film with the game's sound and the commentators. Needs the recordings in assets/commentary/ (or
## stand-ins: tools/commentary/README.md).
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 --fixed-fps 30 \
##     --write-movie preview.avi res://tools/commentary/preview.tscn -- [seconds] [seed] [venue]
## Every line said is printed ("said <time> <id>: <text>") to set beside the film.

var secs := 120.0


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	secs = float(a[0]) if a.size() > 0 else 120.0
	Game.main = self
	Game.settings.sound = true
	Game.settings.music = false
	Game.settings.commentary = true
	Game.settings.graphics = Game.GFX_MEDIUM
	Game.settings.dev = false
	Game.settings.coach = false
	TouchControls.key_hints = false
	Game.start_match({"home": "GAL", "away": "LIM", "venue": String(a[2]) if a.size() > 2 else "county",
		"seed": int(a[1]) if a.size() > 1 else 5, "user_team": -1, "length": 4.0, "mode": "watch", "difficulty": 2})
	var t := 0.0
	var n := 0
	while t < secs:
		await get_tree().process_frame
		t += 1.0 / 30.0
		var c: Commentary = Game.current.commentary if Game.current and "commentary" in Game.current else null
		if c and c.said.size() > n:
			for s in c.said.slice(n):
				print("said %6.1f %s: %s" % [t, s[1], Commentary._by_id[s[1]].text])
			n = c.said.size()
	get_tree().quit()
