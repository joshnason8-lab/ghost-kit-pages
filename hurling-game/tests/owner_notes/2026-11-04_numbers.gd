extends WsgOwnerNote
## The owner, 2026-11-04 (Hurling 0.24.13, through the lead): "Numbers on players' backs: YES. Fix the baked "11" in the model so each player wears their own number, on every tier, within the Low budget."

const NOTE := {"id": "2026-11-04-numbers", "game": "hurling", "date": "2026-11-04", "version": "Hurling 0.24.13", "words": "Numbers on players' backs: YES. Fix the baked \"11\" in the model so each player wears their own number, on every tier, within the Low budget."}
const Kit := preload("res://tests/note_kit.gd")


## On Low, Medium and High: every hurler's body - the game's and the shared foundation's drawn one - carries his own
## number for the kit shader (which draws it on his back in place of the texture's printed 11, game/hero_body.gd), the
## officials none; the kit's material has the digits (one 640 x 96 texture, shared).
func check() -> void:
	var keep = Game.settings.graphics
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		var m: Node = await Kit.match(tree, {"seed": 7}, 3)
		var wrong := []
		for p in m.all_players():
			var pl := p as Player
			var want := int(pl.data.get("num", 0))
			var got := int(pl.body.mesh_instance.get_instance_shader_parameter("number"))
			if got != want or want <= 0:
				wrong.append("%d wears %d" % [want, got])
			if pl.link and pl.link.body and int(pl.link.body.mesh_instance.get_instance_shader_parameter("number")) != want:
				wrong.append("%d drawn with %d" % [want, int(pl.link.body.mesh_instance.get_instance_shader_parameter("number"))])
			var mat := pl.body.mesh_instance.material_override as ShaderMaterial
			if mat and mat.get_shader_parameter("digits") == null:
				wrong.append("%d: no digits in his kit" % want)
		for o in m.officials.people:
			if int((o as Player).body.mesh_instance.get_instance_shader_parameter("number")) != 0:
				wrong.append("an official wears a number")
		info("graphics %d: %d players checked" % [g, m.all_players().size()])
		expect(wrong.is_empty(), "graphics %d: %s" % [g, ", ".join(wrong.slice(0, 6))])
		await Kit.done(tree, m)
	Game.settings.graphics = keep
