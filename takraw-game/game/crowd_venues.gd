extends RefCounted
## The game's venues for the shared crowd audit (tools/wsg/crowd_audit.gd): each one's spectators as declared
## (Arena.crowd_venue), measured fan by fan and photographed close up, section by section:
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/crowd_audit.gd -- res://game/crowd_venues.gd OUT_DIR

const NAMES := {"national": "National arena", "mall": "Mall atrium", "provincial": "Provincial hall", "park": "Park court",
	"beach": "Beach court"}


static func venues() -> Array:
	var out := []
	for v in DB.VENUES:
		out.append({"name": NAMES.get(String(v[0]), String(v[0])), "venue": Arena.crowd_venue(String(v[0]))})
	return out
