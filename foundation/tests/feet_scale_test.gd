extends SceneTree
## The feet rule (WsgWorldRules.feet: every step's planted foot 2 cm at most, walking, jogging, turning, running and
## stopping) on the test hurler at five sizes, 0.85 to 1.15 - so the planter cannot pass on one lucky proportion (it
## did: at 1.0 everything held, at 0.85-1.08 steps slid 2.7-4.0 cm; Netball's hero walked at 2.2) - and at two with
## WsgFootFlat.
##   godot --headless --fixed-fps 30 --path . -s tests/feet_scale_test.gd

const SCALES := [0.85, 0.92, 1.0, 1.08, 1.15]


## With WsgFootFlat too, at these scales: forced 15 degrees down on this (flat) model, as the licensed hurler's boots
## rest toe-up and Hurling and Floorball attach it. (Hurling's own walker showed FootFlat's heel jump at toe-down,
## 3.3 cm a step until 2026-11-04; this model does not - 1.6 cm before the fix, 1.5 after - so the games' own world
## checks are what catch that.)
const FLAT_SCALES := [1.0, 1.08]
const FLAT_DOWN := 15.0


class Scaled:
	extends WsgWorldGame
	var sc := 1.0
	var flat := false
	func walker(parent: Node) -> Array:
		var body := WsgBody.new(WsgBody.load_character("res://tests/character", "hero"))
		body.scale = Vector3.ONE * sc
		parent.add_child(body)
		var loco := WsgLocomotor.attach(body)
		if flat:
			var ff := WsgFootFlat.new()
			ff.name = "FootFlat"
			ff.down = deg_to_rad(FLAT_DOWN)
			body.skeleton.add_child(ff)
		return [body, loco]


func _initialize() -> void:
	await process_frame
	if not FileAccess.file_exists("res://addons/wsg_foundation/data/mobility.res"):
		print("FEET SCALE TEST: SKIPPED (no licensed clip library)")
		quit(0)
		return
	var fails := []
	var sv := SubViewport.new()
	root.add_child(sv)
	var runs := SCALES.map(func(s): return [s, false]) + FLAT_SCALES.map(func(s): return [s, true])
	for run: Array in runs:
		var s: float = run[0]
		var g := Scaled.new()
		g.sc = s
		g.flat = run[1]
		var r: Dictionary = await WsgWorldRules.feet(g, sv)
		var worst := 0.0
		var parts := []
		for l: String in r.lines:
			var m := l.split("worst slip ")
			if m.size() > 1:
				var v := float(m[1].split(" ")[0])
				worst = maxf(worst, v)
				parts.append("%s %.1f" % [l.substr(0, 15).strip_edges(), v])
		var tag := "scale %.2f%s" % [s, " + FootFlat" if g.flat else ""]
		print("%s: %s (worst %.1f cm)" % [tag, ", ".join(parts), worst])
		for f in r.fails:
			fails.append("%s: %s" % [tag, f])
	print("FEET SCALE TEST: ", "PASS" if fails.is_empty() else "FAIL %s" % [fails])
	quit(0 if fails.is_empty() else 1)
