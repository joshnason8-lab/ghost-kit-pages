extends Node
## How far each tackle reaches: for each dive (ankle, thigh, waist), at start distances from 1.0 to 2.1 m in
## front of a raider standing still, whether the dive makes contact (the game's own check, Grapple.contact).
## "+" contact, "-" none. See docs/TACKLE_SYSTEM.md.
##   godot --headless --path . --fixed-fps 30 res://tests/tackle_reach.tscn


func _ready() -> void:
	Game.settings.models = 1
	for style in ["ankle", "thigh", "waist"]:
		var line: String = String(style) + ":"
		for i in range(0, 12):
			var start := 1.0 + 0.1 * i
			var hit: bool = await _try(style, start)
			line += " %.1f%s" % [start, "+" if hit else "-"]
		print(line)
	get_tree().quit()


func _try(style: String, start: float) -> bool:
	seed(11)
	var m: Node = load("res://game/match.gd").new()
	m.config = {"home": "MUM", "away": "DEL", "arena": "dome", "mode": "quick", "autoplay": true, "autoplay_no_report": true,
		"length": 0, "difficulty": 1, "players": [7, 1], "style": style, "first_raider": 0, "lab": true, "raid_rule": 0}
	add_child(m)
	m.rng.seed = 11
	while m.phase != "raid":
		await get_tree().process_frame
	var r: Athlete = m.raider
	var d: Athlete = m.defenders()[0]
	var into := Vector3(0, 0, -m.side(m.raiding))
	r.position = m.pos_in(1, 0.0, 3.9)
	r.facing = into
	d.position = m.pos_in(1, 0.0, 3.9 + start)
	d.facing = -into
	m.lab_move = Vector3.ZERO
	m.lab_force = {"hold": false}
	for k in 10:
		await get_tree().process_frame
	m._defender_tackle(d, style)
	var hit := false
	for k in 30:
		await get_tree().process_frame
		for e in m.event_log:
			if String(e[2]) == "tackle_contact":
				hit = true
	m.queue_free()
	await get_tree().process_frame
	return hit
