extends RefCounted
## Every ground's spectators, for the shared foundation's crowd audit (tools/wsg/crowd_audit.gd): each fan on their
## seat or with their soles on the steps, nothing inside a seat, a row or a rail, everyone facing the play.
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/crowd_audit.gd -- res://game/crowd_venues.gd /out
## (The night ground is the county ground under its floodlights: the same stands.)

static func venues() -> Array:
	return [
		{"name": "Parish field", "venue": Stadium.venue_for("parish")},
		{"name": "County ground", "venue": Stadium.venue_for("county")},
		{"name": "National stadium", "venue": Stadium.venue_for("stadium")},
	]
