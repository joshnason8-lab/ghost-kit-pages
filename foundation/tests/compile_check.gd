extends SceneTree
## Every script in the addon, the tools and the tests compiles.

func _initialize() -> void:
	var bad := 0
	for dir in ["res://addons/wsg_foundation", "res://tests"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var s: Script = load(dir.path_join(f))
				if s == null or not s.can_instantiate():
					printerr("does not compile: ", dir.path_join(f))
					bad += 1
	print("COMPILE CHECK: ", "PASS" if bad == 0 else "FAIL (%d)" % bad)
	quit(1 if bad else 0)
