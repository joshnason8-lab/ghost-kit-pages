extends WsgOwnerNote
const NOTE := {"id": "2026-11-03-bow-legs", "game": "kabaddi", "date": "2026-11-03", "version": "0.14.1-beta",
	"words": "Some runners are still running bow legged, it looks unnatural."}


## Every locomotion clip, all through its cycle: no knee out sideways from the line hip to ankle by more than 2 cm (a
## side-shuffle 4.5), on the game's leg (hips 0.1 m out, thigh 0.44, shin 0.39).
func check() -> void:
	var n := 0
	for bf in DirAccess.get_files_at(MocapClip.DIR):
		if not (bf.begins_with("move_") and bf.ends_with(".json")):
			continue
		var bc := MocapClip.load_file(MocapClip.DIR.path_join(bf))
		var worst := 0.0
		for i in 48:
			var bp: Dictionary = bc.sample_pose(bc.length * i / 48.0, true)
			var pel: Quaternion = bp.get("pelvis", Quaternion.IDENTITY)
			for side in [["l", -1.0], ["r", 1.0]]:
				var hip := pel * Vector3(0.1 * side[1], -0.04, 0)
				var qh: Quaternion = pel * (bp.get("hip_" + side[0], Quaternion.IDENTITY) as Quaternion)
				var knee := hip + qh * Vector3(0, -0.44, 0)
				var ank := knee + (qh * (bp.get("kn_" + side[0], Quaternion.IDENTITY) as Quaternion)) * Vector3(0, -0.39, 0)
				worst = maxf(worst, (knee - (hip + ank) * 0.5).dot(pel * Vector3(side[1], 0, 0)))
		var limit := 0.045 if "shuffle" in bf else 0.02
		info("%s: knee out %.1f cm" % [bf.get_basename(), worst * 100.0])
		expect(worst <= limit, "%s runs bow-legged: a knee %.1f cm out from hip to ankle" % [bf.get_basename(), worst * 100.0])
		n += 1
	expect(n >= 8, "only %d running clips found" % n)
