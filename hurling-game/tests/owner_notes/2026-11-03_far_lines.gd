extends WsgOwnerNote
## The owner, 2026-11-03 (Hurling 0.21.0): "The far lines on the field disappear sometimes or look odd."

const NOTE := {"id": "2026-11-03-far-lines", "game": "hurling", "date": "2026-11-03", "version": "Hurling 0.21.0", "words": "The far lines on the field disappear sometimes or look odd."}
const Kit := preload("res://tests/note_kit.gd")

## The markings are painted in the grass's own shader, anti-aliased by their screen size (fwidth), on every graphics
## level: no thin strips of line geometry left to drop out of the picture far off.
func check() -> void:
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		var keep = Game.settings.graphics
		Game.settings.graphics = g
		var m: Node = await Kit.match(tree, {"mode": "quick", "user_team": 0}, 3)
		var st: Stadium = m.stadium
		var mat := st._grass.material_override as ShaderMaterial
		var code: String = mat.shader.code if mat and mat.shader else ""
		expect(code.contains("marks(") and code.contains("fwidth"), "level %d: the grass draws no markings of its own (anti-aliased)" % g)
		var strips := 0
		for n in st.find_children("*", "MeshInstance3D", true, false):
			if String(n.name).to_lower().contains("line"):
				strips += 1
		expect(strips == 0, "level %d: %d meshes of line strips over the grass" % [g, strips])
		info("level %d: markings in the grass shader %s, line meshes %d" % [g, code.contains("marks("), strips])
		await Kit.done(tree, m)
		Game.settings.graphics = keep
