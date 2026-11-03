extends RefCounted
## This game's venues for the shared foundation's crowd audit (tools/wsg/crowd_audit.gd, ADOPTING 5.1): every fan on
## their seat or their floor, never inside a seat, a step or a rail, facing the play, in each place the game has.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/crowd_audit.gd -- res://game/crowd_venues.gd OUT_DIR


static func venues() -> Array:
	var out := []
	for id in DB.VENUE_ORDER:
		out.append({"name": id, "venue": Venue.crowd_venue(id)})
	return out
