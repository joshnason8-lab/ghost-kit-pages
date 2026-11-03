extends WsgOwnerNote
## The owner, 2026-10-29 (Floorball 0.9).

const NOTE := {"id": "2026-10-29-penalty-camera-button", "game": "floorball", "date": "2026-10-29", "version": "0.9",
	"words": "remove the other camera angle button for the penalty mini game"}

const Lib := preload("res://tests/note_lib.gd")


## Penalty shots (the mini game): no camera button anywhere on its screen - its own close camera only - through a
## shot and the next.
func check() -> void:
	var m: Node = (load(Lib.MATCH) as Script).new()
	m.config = {"home": "SWE", "away": "FIN", "venue": "arena", "user_team": 0, "mode": "practice", "practice": true, "period": 20.0, "seed": 3}
	Lib.host(tree).add_child(m)
	var cam_buttons := {}
	for f in 60 * 8:
		var st := String(m._so.get("stage", ""))
		m.touch.joystick = Vector2(0, -1) if st == "run" else Vector2.ZERO
		await tree.physics_frame
		if f % 30 == 0:
			for b in m.hud.root.find_children("*", "BaseButton", true, false):
				var t := String(b.get("text")).to_lower()
				var tip := String((b as Control).tooltip_text).to_lower()
				if (b as Control).is_visible_in_tree() and (t.contains("cam") or tip.contains("cam") or String(b.name).to_lower().contains("cam")):
					cam_buttons[String(b.name)] = true
	info("camera buttons seen: %s" % [cam_buttons.keys() if not cam_buttons.is_empty() else "none"])
	expect(cam_buttons.is_empty(), "a camera button on the mini game's screen: %s" % [cam_buttons.keys()])
	await Lib.done(tree, m)
