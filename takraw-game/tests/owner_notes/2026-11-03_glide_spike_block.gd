extends TakrawNote
## The owner, 2026-11-03: "Players still gliding a lot, like when getting in position to spike or block."

const NOTE := {"id": "2026-11-03-glide-spike-block", "game": "sepak-takraw", "date": "2026-11-03", "version": "0.15.1",
	"words": "Players still gliding a lot, like when getting in position to spike or block."}


## In the rally - running into position to spike, to the net to block - his planted foot stays put: running, under 30%
## of the way slid along with him (0.15.2: 87%) and half the steps slip under 2 cm; getting to a block, under 35% (99%).
func check() -> void:
	var run: Array = await glide_share(["run"])
	var blk: Array = await glide_share(["block"])
	var st: Array = await step_slip("run")
	info("running in the rally: %.0f%% of %.0f m slid, half of %d steps under %.1f cm; to a block: %.0f%% of %.0f m" % [
		100.0 * float(run[0]), run[1], st[1], 100.0 * float(st[0]), 100.0 * float(blk[0]), blk[1]])
	expect(float(run[1]) > 3.0 and float(run[0]) < 0.30, "running in the rally %.0f%% of %.0f m slid (under 30%%)" % [100.0 * float(run[0]), run[1]])
	expect(int(st[1]) > 100 and float(st[0]) < 0.02, "running, half the steps slip %.1f cm or more (under 2)" % (100.0 * float(st[0])))
	expect(float(blk[1]) > 3.0 and float(blk[0]) < 0.35, "getting to a block %.0f%% of %.0f m slid (under 35%%)" % [100.0 * float(blk[0]), blk[1]])
