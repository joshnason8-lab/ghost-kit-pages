extends Node
## The HD pack end to end, from the real beta release: the manifest, the download in pieces, the SHA-256 check, then
## the pack mounted and a file of it found. Needs the internet, so not in CI (the pack is built there); run after a
## release:
##   godot --headless --path . res://tests/hd_download.tscn
## It removes the pack after.

var _dl: Ultra
var _t0 := 0
var _shown := 0


func _ready() -> void:
	Ultra.remove_pack()
	_dl = Ultra.new()
	add_child(_dl)
	_dl.progress.connect(_on_progress)
	_dl.finished.connect(_on_finished)
	_t0 = Time.get_ticks_msec()
	_dl.fetch_manifest()


func _on_progress(done: int, total: int) -> void:
	if not _dl.running:
		print("hd_download: manifest, %d bytes" % total)
		_dl.download()
	elif done - _shown >= 16 * 1048576 or done == total:
		_shown = done
		print("hd_download: %d / %d MB" % [done / 1048576, total / 1048576])


func _on_finished(ok: bool, why: String) -> void:
	var s := (Time.get_ticks_msec() - _t0) / 1000.0
	var mounted := ok and ProjectSettings.load_resource_pack(Ultra.pack_path(), false)
	print("hd_download: %s %s in %.0f s; whole %s; mounted %s" % ["ok" if ok else "failed", why, s, Ultra.pack_ready(), mounted])
	Ultra.remove_pack()
	get_tree().quit(0 if ok and mounted else 1)
