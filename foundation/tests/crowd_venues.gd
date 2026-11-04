extends RefCounted
## The foundation's own test grounds for tools/crowd_audit.gd (a game's registry looks the same: one entry a venue).
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s tools/crowd_audit.gd -- res://tests/crowd_venues.gd <out dir>

static func venues() -> Array:
	var t: GDScript = load("res://tests/crowd_venue_test.gd")
	return [{"name": "Test arena", "venue": t.arena()}, {"name": "Test outdoor court", "venue": t.outdoor()}]
