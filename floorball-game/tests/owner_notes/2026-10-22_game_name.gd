extends WsgOwnerNote
## The owner, 2026-10-22 (Floorball 0.1).

const NOTE := {"id": "2026-10-22-game-name", "game": "floorball", "date": "2026-10-22", "version": "0.1",
	"words": "Change the game name to Floorball Unleashed"}


## The name everywhere it shows: the app's name, the Android and Play Store builds' names, the boards' own panels.
func check() -> void:
	var name := String(ProjectSettings.get_setting("application/config/name", ""))
	expect(name == "Floorball Unleashed", "the app is called '%s'" % name)
	var f := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	var names := []
	if f:
		for line in f.get_as_text().split("\n"):
			if line.begins_with("package/name="):
				names.append(line.get_slice("=", 1).strip_edges().trim_prefix("\"").trim_suffix("\""))
	info("the app: '%s'; the builds: %s; the boards: '%s'" % [name, names, Signage.text("")])
	expect(not names.is_empty(), "no build names found")
	for n in names:
		expect(n == "Floorball Unleashed", "a build is named '%s'" % n)
	expect(Signage.text("") == "FLOORBALL UNLEASHED", "the boards say '%s'" % Signage.text(""))
