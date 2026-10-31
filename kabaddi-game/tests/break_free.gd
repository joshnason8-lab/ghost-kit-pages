extends Node
## godot --headless --path . --fixed-fps 30 res://tests/break_free.tscn -- [matches]
## How often mashing Break free gets a held raider out: AI matches where, while he is held, Break free is pressed as
## soon as it can be (as a player mashing it would). Counts holds that end in his escape vs his takedown.
var holds := 0
var freed := 0
var downs := 0
var presses := 0
var slips := 0

func _ready() -> void:
	Game.main = self
	Game.settings.sound = false
	var n := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 4
	for i in n:
		await _one(i)
	print("BF holds=%d freed=%d takedowns=%d presses=%d slips=%d  free-rate=%.2f per-press=%.2f" % [holds, freed, downs,
		presses, slips, float(freed) / maxf(1, freed + downs), float(slips) / maxf(1, presses)])
	get_tree().quit(0)

func _one(i: int) -> void:
	Game.start_match({"home": "MUM", "away": "PAT", "arena": "dome", "mode": "quick", "autoplay": true, "length": 0,
		"difficulty": 2, "seed": 100 + i})
	var m: Node = Game.current
	var held := [false]
	m.game_event.connect(func(kind, info):
		if kind == "hold" and not held[0]:
			held[0] = true
			holds += 1
		elif kind == "escape":
			slips += 1
			if info.get("free", false) and held[0]:
				held[0] = false
				freed += 1
		elif kind == "takedown" and held[0]:
			held[0] = false
			downs += 1
		elif kind == "raid_end":
			held[0] = false)
	var f := 0
	while f < 30 * 60 * 4 and is_instance_valid(m) and Game.current == m:
		await get_tree().process_frame
		f += 1
		if m.phase == "raid" and m.raid.holders.size() > 0 and m.raider.cooldown <= 0.0 \
				and not m.raider.state in ["touch", "kick", "backkick", "dodge", "dubki", "jump", "shoved"]:
			presses += 1
			m._break_free()
