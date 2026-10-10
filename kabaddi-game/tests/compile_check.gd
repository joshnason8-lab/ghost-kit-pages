extends Node
## Loads every script so parse and type errors surface. Runs as a scene so autoloads exist:
##   godot --headless --path . res://tests/compile_check.tscn

func _ready() -> void:
	var paths := []
	for dir in ["res://autoload", "res://game", "res://ui", "res://tests"]:
		_scan(dir, paths)
	var bad := 0
	for p in paths:
		var s: Script = load(p)
		if s == null or not s.can_instantiate():
			bad += 1
			print("BROKEN ", p)
	print("compile_check: %d scripts, %d broken" % [paths.size(), bad])
	get_tree().quit(1 if bad else 0)


func _scan(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
