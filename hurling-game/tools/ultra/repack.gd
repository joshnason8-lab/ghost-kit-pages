extends SceneTree
## Rewrites an exported HD pack with Ultra's content alone: each file under res://ultra/ (its .import and the
## imported texture it points to, or the file itself), and none of what an export always adds (project.binary, the
## autoload scripts, main.tscn, translations). The game never used those (it mounts the pack without replacing its own
## files), and a download should carry content only, no code.
##   godot --headless --path . -s tools/ultra/repack.gd -- <exported.pck> <out.pck>

func _init() -> void:
	var a := OS.get_cmdline_user_args()
	if not ProjectSettings.load_resource_pack(a[0], true):
		printerr("repack: cannot mount ", a[0])
		quit(1)
		return
	var tmp := OS.get_cache_dir().path_join("hurling_repack")
	DirAccess.make_dir_recursive_absolute(tmp)
	var pk := PCKPacker.new()
	pk.pck_start(a[1])
	var n := 0
	for f in _files("res://ultra"):
		var paths: Array[String] = []
		if FileAccess.file_exists(f + ".import"):
			paths.append(f + ".import")
			var cfg := ConfigFile.new()
			cfg.parse(FileAccess.get_file_as_string(f + ".import"))
			for k in cfg.get_section_keys("remap"):
				if String(k).begins_with("path"):
					paths.append(String(cfg.get_value("remap", k)))
		else:
			paths.append(f)
		for p in paths:
			var bytes := FileAccess.get_file_as_bytes(p)
			if bytes.is_empty():
				printerr("repack: missing ", p)
				quit(1)
				return
			var src := tmp.path_join("%d.bin" % n)
			var w := FileAccess.open(src, FileAccess.WRITE)
			w.store_buffer(bytes)
			w.close()
			pk.add_file(p, src)
			n += 1
	pk.flush()
	DirAccess.remove_absolute(tmp)
	print("repack: %d files -> %s" % [n, a[1]])
	quit()


## The source files under a folder (as the project has them: not their .import, .uid or .remap).
func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		var name := f.trim_suffix(".remap").trim_suffix(".import")
		if not f.ends_with(".uid") and not out.has(dir.path_join(name)):
			out.append(dir.path_join(name))
	return out
