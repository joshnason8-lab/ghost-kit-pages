extends SceneTree
## The feet rule (WsgWorldRules.feet: every step's planted foot 2 cm at most, walking, jogging, turning, running and
## stopping) on the test hurler at five sizes, 0.85 to 1.15 - so the planter cannot pass on one lucky proportion
## (it did: at 1.0 everything held, at 0.85-1.08 steps slid 2.7-4.0 cm; Netball's hero walked at 2.2).
##   godot --headless --fixed-fps 30 --path . -s tests/feet_scale_test.gd

const SCALES := [0.85, 0.92, 1.0, 1.08, 1.15]


class Scaled:
	extends WsgWorldGame
	var sc := 1.0
	func walker(parent: Node) -> Array:
		var body := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
		body.scale = Vector3.ONE * sc
		parent.add_child(body)
		return [body, WsgLocomotor.attach(body)]


func _initialize() -> void:
	await process_frame
	if not FileAccess.file_exists("res://addons/wsg_foundation/data/mobility.res"):
		print("FEET SCALE TEST: SKIPPED (no licensed clip library)")
		quit(0)
		return
	var fails := []
	var sv := SubViewport.new()
	root.add_child(sv)
	for s in SCALES:
		var g := Scaled.new()
		g.sc = s
		var r: Dictionary = await WsgWorldRules.feet(g, sv)
		var worst := 0.0
		var parts := []
		for l: String in r.lines:
			var m := l.split("worst slip ")
			if m.size() > 1:
				var v := float(m[1].split(" ")[0])
				worst = maxf(worst, v)
				parts.append("%s %.1f" % [l.substr(0, 15).strip_edges(), v])
		print("scale %.2f: %s (worst %.1f cm)" % [s, ", ".join(parts), worst])
		for f in r.fails:
			fails.append("scale %.2f: %s" % [s, f])
	print("FEET SCALE TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)
