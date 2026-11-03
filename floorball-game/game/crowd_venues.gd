extends RefCounted
## The game's venues for the shared crowd's audit (tools/wsg/crowd_audit.gd; ADOPTING 5.1): each venue's stands and
## benches as Arena declares them.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/crowd_audit.gd -- res://game/crowd_venues.gd OUT

static func venues() -> Array:
	var out := []
	for v: Array in [["City arena", "arena"], ["Sports hall", "hall"], ["School gym", "school"]]:
		out.append({"name": v[0], "venue": Arena.declare(v[1])})
	return out
