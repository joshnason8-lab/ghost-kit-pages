extends "res://ui/quick_setup.gd"
## Watch AI's team sheet (the home screen's Watch AI): Quick Match's own, with home and away in place of yours and
## theirs, the venue and the quarters, and Watch. The match is AI v AI on the broadcast camera, with the scoreboard,
## the name tags, the replays, pause and a 1x / 2x speed (game/hud.gd), and the result screen at the end; it counts in
## no records.


func _init() -> void:
	watch = true
