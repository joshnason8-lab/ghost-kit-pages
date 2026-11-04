extends RefCounted
## Every ground's crowd, for the foundation's crowd audit (tools/wsg/crowd_audit.gd):
##   xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/wsg/crowd_audit.gd -- res://game/crowd_venues.gd OUT


static func venues() -> Array:
	var out: Array = []
	# The four grounds (DB.VENUES: id, the kind of crowd), written out: the audit runs without the game's autoloads.
	for pair: Array in [["maidan", "village"], ["school", "school"], ["arena", "arena"], ["floodlit", "stadium"]]:
		var id: String = pair[0]
		var kind: String = pair[1]
		var f := KhoRules.field(KhoRules.FAST if kind == "arena" else KhoRules.CLASSIC)
		for low: bool in [false, true]:
			for part: String in ["main", "near"]:
				out.append({"name": "%s %s%s" % [id, part, " (Low)" if low else ""], "venue": VenueCrowd.build(kind, f, low, part)})
	return out
