@tool
extends EditorPlugin
## Run by tools/bake_lighting/bake.sh in a copy of the project: opens each scene listed in res://bake_list.txt,
## selects its LightmapGI and presses the editor's Bake Lightmaps button (the lightmapper has no other way in),
## answers where to save the bake (next to the scene), saves the scene and quits.

func _enter_tree() -> void:
	if FileAccess.file_exists("res://bake_list.txt"):
		_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _run() -> void:
	await _frames(30)
	var failed := 0
	for path in FileAccess.get_file_as_string("res://bake_list.txt").split("\n", false):
		if not await _bake(String(path).strip_edges()):
			failed += 1
	print("bake_lighting: done, %d failed" % failed)
	get_tree().quit(1 if failed > 0 else 0)


func _bake(path: String) -> bool:
	EditorInterface.open_scene_from_path(path)
	await _frames(20)
	var root := EditorInterface.get_edited_scene_root()
	var lm: LightmapGI = root.find_child("LightmapGI", true, false) if root else null
	if lm == null:
		print("bake_lighting: no LightmapGI in ", path)
		return false
	EditorInterface.edit_node(lm)
	await _frames(10)
	var button: Button = null
	for b in EditorInterface.get_base_control().find_children("*", "Button", true, false):
		if (b as Button).text == "Bake Lightmaps" and (b as Button).is_visible_in_tree():
			button = b
	if button == null:
		print("bake_lighting: no Bake Lightmaps button for ", path)
		return false
	var t0 := Time.get_ticks_msec()
	button.pressed.emit()
	await _frames(5)
	# The editor asks where the bake goes when the scene's own path is not to hand: next to the scene.
	for d in EditorInterface.get_base_control().find_children("*", "EditorFileDialog", true, false):
		if (d as EditorFileDialog).visible:
			(d as EditorFileDialog).hide()
			(d as EditorFileDialog).file_selected.emit(path.get_basename() + ".lmbake")
	await _frames(5)
	for d in EditorInterface.get_base_control().find_children("*", "AcceptDialog", true, false):
		if (d as AcceptDialog).visible and (d as AcceptDialog).dialog_text != "":
			print("bake_lighting: ", path, ": ", (d as AcceptDialog).dialog_text)
	if lm.light_data == null:
		print("bake_lighting: ", path, " not baked")
		return false
	EditorInterface.save_scene()
	await _frames(10)
	print("bake_lighting: baked %s in %.0f s" % [path, (Time.get_ticks_msec() - t0) / 1000.0])
	return true
