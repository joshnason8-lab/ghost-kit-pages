extends Control
## Ultra graphics, from Settings: what it is, the HD pack's size, its download (a progress bar, carrying on where it
## stopped, tried again), then the switch, which needs the game opened again (the renderer is fixed at start:
## game/ultra.gd). With {"mode": "leave"} (Low, Medium or High picked while in Ultra): only the reopen, and the pack
## can be removed.

var mode := "enter"
var _dl: Ultra
var _status: Label
var _bar: ProgressBar
var _act: Button
var _close: Button
var _box: VBoxContainer


func setup(args: Dictionary) -> void:
	mode = String(args.get("mode", "enter"))


func _ready() -> void:
	UI.screen(self)
	var v := UI.page(self, tr("ULTRA_TITLE"), func(): _back(), tr("SET_DISPLAY"))
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 18)
	v.add_child(UI.scroll(_box))
	_box.add_child(UI.wrap(tr("ULTRA_INTRO"), "MutedLabel", 18))
	_status = UI.wrap("", "", 20)
	_box.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 26)
	_bar.show_percentage = false
	_bar.visible = false
	_box.add_child(_bar)
	_act = UI.button("", true, func(): _on_act())
	_box.add_child(_act)
	_close = UI.button(tr("ULTRA_CLOSE"), false, func(): _quit())
	_close.visible = false
	_box.add_child(_close)
	if mode == "leave":
		_reopen()
		_box.add_child(UI.button(tr("ULTRA_REMOVE"), false, func():
			Ultra.remove_pack()
			_back()))
		return
	_dl = Ultra.new()
	add_child(_dl)
	_dl.progress.connect(_on_progress)
	_dl.finished.connect(_on_finished)
	if Ultra.pack_ready():
		_ready_to_switch()
	else:
		_status.text = tr("ULTRA_CHECKING")
		_act.visible = false
		_dl.fetch_manifest()


func _on_progress(done: int, total: int) -> void:
	if not _dl.running:
		# The manifest is in: how big, and the button to fetch it.
		_status.text = tr("ULTRA_SIZE") % ceili(total / 1048576.0)
		_act.text = tr("ULTRA_GET")
		_act.visible = true
		return
	_bar.visible = true
	_bar.max_value = total
	_bar.value = done
	_status.text = tr("ULTRA_GETTING") % [done / 1048576, ceili(total / 1048576.0)] if done < total else tr("ULTRA_CHECKING_FILE")


func _on_finished(ok: bool, why: String) -> void:
	if ok:
		_ready_to_switch()
		return
	_bar.visible = false
	_status.text = tr("ULTRA_FAIL_" + why)
	_act.text = tr("ULTRA_RETRY")
	_act.visible = why != "manifest"
	_act.set_meta("retry", true)


func _on_act() -> void:
	if _act.has_meta("switch"):
		Game.settings.graphics = Game.GFX_ULTRA
		Game.save_settings()
		Ultra.set_renderer(true)
		_reopen()
		return
	if _act.has_meta("retry") and _dl.size() == 0:
		_act.remove_meta("retry")
		_status.text = tr("ULTRA_CHECKING")
		_act.visible = false
		_dl.fetch_manifest()
		return
	_act.visible = false
	_dl.download()


func _ready_to_switch() -> void:
	_bar.visible = false
	_status.text = tr("ULTRA_READY")
	_act.text = tr("ULTRA_SWITCH")
	_act.visible = true
	_act.set_meta("switch", true)


func _reopen() -> void:
	_status.text = tr("ULTRA_REOPEN")
	_act.visible = false
	_close.visible = true


## On a phone the player opens it again; on a computer it opens again by itself.
func _quit() -> void:
	if not OS.has_feature("mobile"):
		OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()


func _back() -> void:
	if _dl != null:
		_dl.cancel()
	Game.show_screen("res://ui/settings_screen.gd")
