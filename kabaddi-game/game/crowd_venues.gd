extends RefCounted
## Every ground's spectators, for the shared foundation's crowd audit (ADOPTING 5.1):
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/crowd_audit.gd -- res://game/crowd_venues.gd OUT


static func venues() -> Array:
	var out := []
	for id in ["dome", "stadium", "village", "monsoon", "beach"]:
		out.append({"name": id, "venue": KabaddiVenues.venue(id)})
	return out
