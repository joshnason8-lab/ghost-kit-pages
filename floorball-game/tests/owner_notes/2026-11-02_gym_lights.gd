extends WsgOwnerNote
## The owner, 2026-11-02 (Floorball 0.9.2-beta).

const NOTE := {"id": "2026-11-02-gym-lights", "game": "floorball", "date": "2026-11-02", "version": "0.9.2-beta",
	"words": "Lights in the gym aren't attached to anything on the ceiling, looks weird, just remove them."}

const Lib := preload("res://tests/note_lib.gd")


## The school gym and the city arena, every graphics level: no lamp hung from nothing - no lamp model drawn, the floor's
## reflection of lamps off. (The sports hall's battens hang on their lighting rail under the trusses: they stay.)
func check() -> void:
	var keep: int = Game.settings.graphics
	for gfx in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = gfx
		for venue in ["school", "arena"]:
			var a := Arena.new(venue, [Color.RED], [Color.BLUE])
			Lib.host(tree).add_child(a)
			await tree.process_frame
			var lamps := 0
			for mmi in a.find_children("*", "MultiMeshInstance3D", true, false):
				var mesh: Mesh = (mmi as MultiMeshInstance3D).multimesh.mesh if (mmi as MultiMeshInstance3D).multimesh else null
				if mesh and (mesh.resource_path.contains("lamp") or mesh.resource_name.to_lower().contains("lamp")):
					lamps += 1
			var shown: bool = bool((a.get("_lamps") as Dictionary).get("shown", true))
			info("graphics %d, %s: %d lamp models, lamps %s" % [gfx, venue, lamps, "shown" if shown else "not shown"])
			expect(lamps == 0 and not shown, "graphics %d, %s: lamps hung from nothing (%d models, shown %s)" % [gfx, venue, lamps, shown])
			a.queue_free()
			await tree.process_frame
	Game.settings.graphics = keep
