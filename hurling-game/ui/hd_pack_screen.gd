extends Control
## The HD pack, from Settings (on a phone that can use it: Ultra.capable): what it adds to High graphics, its size,
## its download (a progress bar, carrying on where it stopped, tried again, checked), then in use at once (no
## restart: game/ultra.gd mounts it). When it is in already: Remove, for the space.

var _dl: Ultra
var _status: Label
var _bar: ProgressBar
var _act: Button
var _box: VBoxContainer


func setup(_args: Dictionary) -> void:
	pass


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("HD_TITLE"), func(): _back(), tr("SET_DISPLAY"))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(_box))
	_box.add_child(UI.wrap(tr("HD_INTRO"), "MutedLabel", 18))
	_status = UI.wrap("", "", 20)
	_box.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 26)
	_bar.show_percentage = false
	_bar.visible = false
	_box.add_child(_bar)
	_act = UI.button("", true, func(): _on_act())
	_box.add_child(_act)
	if Ultra.pack_ready():
		_in_use()
		return
	_dl = Ultra.new()
	add_child(_dl)
	_dl.progress.connect(_on_progress)
	_dl.finished.connect(_on_finished)
	_status.text = tr("HD_CHECKING")
	_act.visible = false
	_dl.fetch_manifest()


func _on_progress(done: int, total: int) -> void:
	if not _dl.running:
		# The manifest is in: how big, and the button to fetch it.
		_status.text = tr("HD_SIZE") % ceili(total / 1048576.0)
		_act.text = tr("HD_GET")
		_act.visible = true
		return
	_bar.visible = true
	_bar.max_value = total
	_bar.value = done
	_status.text = tr("HD_GETTING") % [done / 1048576, ceili(total / 1048576.0)] if done < total else tr("HD_CHECKING_FILE")


func _on_finished(ok: bool, why: String) -> void:
	if ok:
		Ultra.mount_now()
		_in_use()
		return
	_bar.visible = false
	_status.text = tr("HD_FAIL_" + why)
	_act.text = tr("HD_RETRY")
	_act.visible = why != "manifest"
	_act.set_meta("retry", true)


func _on_act() -> void:
	if _act.has_meta("remove"):
		Ultra.remove_pack()
		_back()
		return
	if _act.has_meta("retry") and _dl.size() == 0:
		_act.remove_meta("retry")
		_status.text = tr("HD_CHECKING")
		_act.visible = false
		_dl.fetch_manifest()
		return
	_act.visible = false
	_dl.download()


## In: used on High from now on; the button removes it.
func _in_use() -> void:
	_bar.visible = false
	_status.text = tr("HD_IN") if not Ultra.removed else tr("HD_REMOVED")
	_act.text = tr("HD_REMOVE")
	_act.visible = not Ultra.removed
	_act.remove_meta("retry")
	_act.set_meta("remove", true)


func _back() -> void:
	if _dl != null:
		_dl.cancel()
	Game.show_screen("res://ui/settings_screen.gd")
