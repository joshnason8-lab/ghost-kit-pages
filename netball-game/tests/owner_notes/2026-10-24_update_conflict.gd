extends WsgOwnerNote
## The owner, 2026-10-24, on the 0.6.0 betas: a new beta would not install over the last ("failure conflict"), each
## build signed with a different throwaway key. (Back-filled from docs/PROGRESS.md, "The beta signing key".)

const NOTE := {"id": "2026-10-24-update-conflict", "game": "netball", "date": "2026-10-24", "version": "0.6.0-beta",
	"words": "failure conflict"}

const OWNER_CERT := "6F:23:A9:36:9A:95:60:C5:57:1D:27:04:D2:01:5F:8D:58:3E:B2:65:2E:86:A5:F1:66:2B:E5:D6:C3:69:7B:A3"
const FIRST_ON_KEY := 22     # the version code of 0.9.0-beta (codes only ever go up)


## Every beta installs over the last: the Android build signs the APK with the owner's beta key (the repository secret
## BETA_KEYSTORE_B64) and fails unless its certificate is the owner's (OWNER_CERT); the package name stays
## com.netballunleashed.game; the version name is the game's own; and the version code never goes down (a lower one is
## refused as an update too).
func check() -> void:
	var cfg := ConfigFile.new()
	expect(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg does not load")
	var sec := ""
	for s in cfg.get_sections():
		if String(cfg.get_value(s, "platform", "")) == "Android":
			sec = s.replace("preset.", "").replace(".options", "")
	var opts := "preset.%s.options" % sec
	var pkg := String(cfg.get_value(opts, "package/unique_name", ""))
	var code := int(cfg.get_value(opts, "version/code", 0))
	var vname := String(cfg.get_value(opts, "version/name", ""))
	var game_v := String(ProjectSettings.get_setting("application/config/version", ""))
	info("Android: %s, version %s (code %d); the game %s" % [pkg, vname, code, game_v])
	expect(pkg == "com.netballunleashed.game", "the package is %s: it would install beside the game, not over it" % pkg)
	expect(code >= FIRST_ON_KEY, "the version code went down to %d (%d at 0.9.0-beta): Android refuses it as an update" % [code, FIRST_ON_KEY])
	expect(vname == game_v, "the APK's version name %s is not the game's %s" % [vname, game_v])
	var path := ProjectSettings.globalize_path("res://").path_join("../.github/workflows/netball-android.yml").simplify_path()
	var wf := FileAccess.get_file_as_string(path)
	if wf == "":
		skip("the Android workflow (%s) is not here" % path)
		return
	expect(wf.contains("BETA_KEYSTORE_B64"), "the Android build no longer signs with the owner's beta key (BETA_KEYSTORE_B64)")
	expect(wf.contains(OWNER_CERT), "the Android build no longer checks the APK's certificate is the owner's")
	expect(wf.contains("is not signed with the owner's beta key") and wf.contains("exit 1"), "a build not on the owner's key no longer fails")
