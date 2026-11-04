@tool
extends EditorPlugin
## The asset lint at import (owner-approved item 9): each texture and model the editor imports is checked
## (WsgAssetLint.texture, .lods) and what is wrong is shown at once - the Output panel, and a toast - not at the
## release gate. Project Settings > Plugins > WSG Foundation. The same checks run in CI (tools/wsg/asset_lint.gd).


func _enter_tree() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if not fs.resources_reimported.is_connected(_on_reimported):
		fs.resources_reimported.connect(_on_reimported)


func _exit_tree() -> void:
	var fs := EditorInterface.get_resource_filesystem()
	if fs.resources_reimported.is_connected(_on_reimported):
		fs.resources_reimported.disconnect(_on_reimported)


func _on_reimported(paths: PackedStringArray) -> void:
	var rules := WsgAssetLint.allow_rules()
	for p in paths:
		var cf := ConfigFile.new()
		if cf.load(p + ".import") != OK:
			continue
		var found := WsgAssetLint.texture(p + ".import", cf) + WsgAssetLint.lods(p + ".import", cf)
		for i: Dictionary in found:
			if WsgAssetLint.excused(i, rules) != "":
				continue
			var msg := "Asset lint: %s: %s" % [i.path, i.what]
			if i.fail:
				push_warning(msg)
				EditorInterface.get_editor_toaster().push_toast(msg, EditorToaster.SEVERITY_WARNING)
			else:
				print(msg)
