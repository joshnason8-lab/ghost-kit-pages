extends WsgOwnerNote
## The owner (relayed by the lead), 2026-11-02, on the 0.8.2 foundation pilot (a Galaxy A16, Low).

const NOTE := {"id": "2026-11-02-gliding-arms", "game": "netball", "date": "2026-11-02", "version": "0.8.2-pilot",
	"words": "Netball is still severely broken: players gliding around, not running, arms just stretched out when running. Looks like nothing was updated."}

const Harness := preload("res://tests/owner_notes/lib/harness.gd")
const SLIP := 0.03          # m: a planted foot of the game's own body (test_runner GAIT_SLIP)
const LINK_SLIP := 0.05     # m: a drawn foot of the foundation's body (test_runner LINK_SLIP)
const ELBOW := 45.0         # degrees: a runner's elbows bent at least this much on average (the foundation's note)
const ABD := 30.0           # degrees: the upper arm out from her side, at most (arms out = the owner's "stretched out")


## On every graphics level (Low, Medium, High; Medium and High drawn by the shared foundation when the licensed clips
## are here, else by the game's own bodies as on Low), a player running at 2, 3.5, 5, 6.8 and 7.2 m/s and an umpire at
## her jog and her catch-up pace, 4 s each: her feet step (at least 1.6 steps a second at 2 m/s, 2.2 from 3 m/s, never
## more than 2.4 m a step: a glide covers ground without steps), a planted foot stays put (SLIP or LINK_SLIP over its
## stance) and her arms are a runner's (elbows bent ELBOW degrees or more on average, the upper arm within ABD of her
## side, never an A- or T-pose). Then every player and umpire in AI matches in two venues (test_runner _gait_in_match
## on Low, _foundation_match on Medium with the clips): no planted foot skates and nobody runs with her arms out.
func check() -> void:
	var h: Node = await Harness.make(tree)
	var clips := Harness.have_clips()
	var sq: Array = DB.squad("NZL")
	for g in [Game.GFX_LOW, Game.GFX_MEDIUM, Game.GFX_HIGH]:
		Game.settings.graphics = g
		FoundationLink.off = g == Game.GFX_LOW or not clips
		var lv: String = ["Low", "Medium", "High"][g]
		var runs: Array = []
		for spd in [2.0, 3.5, 5.0, 6.8, 7.2]:
			runs.append(["player", spd])
		for spd in [Umpire.JOG, Umpire.SPEED]:
			runs.append(["umpire", spd])
		for r: Array in runs:
			var who: Node3D
			if r[0] == "player":
				var pl := Player.new(0, sq[2], "WA")
				h.add_child(pl)
				who = pl
				await frame()
				pl.fenced = false
				pl.place(Vector2.ZERO, 0.0)
			else:
				var u := Umpire.new(-1)
				h.add_child(u)
				who = u
				await frame()
				u.p = Vector2.ZERO
				u.position = Vector3.ZERO
			var spd: float = r[1]
			var drawn: bool = who.link != null and who.link.body != null
			var own := {"slip": 0.0, "bend_lo": 999.0, "bend_hi": 0.0, "out": 0.0, "abd": 0.0, "steps": 0}
			var rig: Dictionary = h._rig_state()
			var elbows := 0.0
			var elbow_n := 0
			var pose := ""
			var start := Vector2.INF
			var n := 150
			# (The drawn body's arms as each pose leaves them: read anywhere else its bones are without its modifiers.)
			var arms_now := [{}, ""]
			if drawn:
				who.link.body.posed.connect(func():
					arms_now[0] = WsgNoteChecks.arms(who.link.body)
					arms_now[1] = WsgNoteChecks.t_or_a_pose(who.link.body))
			for f in n:
				if who is Player:
					who.set_act("run")
					who.target = who.p + Vector2(0, 8)
					who.want_speed = spd
					who.advance(1.0 / 30.0)
				else:
					who.pace = spd
					who.target = who.p + Vector2(4.0, 0)
					who.advance(1.0 / 30.0, who.p + Vector2(4.0, 0) * 3.0)
				if drawn:
					await frame()    # (the drawn body's modifiers run at the frame's end)
				if f == 30:
					start = who.p
					own.steps = 0
					rig.steps = 0
				h._gait_measure(who.gait, who.body, own, f >= 30, f >= 30 and not drawn)
				if drawn:
					h._rig_measure(who.link, rig, f >= 30)
					if f >= 30 and not (arms_now[0] as Dictionary).is_empty():
						var a: Dictionary = arms_now[0]
						elbows += (float(a.Left[1]) + float(a.Right[1])) * 0.5
						elbow_n += 1
						if String(arms_now[1]) != "":
							pose = arms_now[1]
			var secs := (n - 30) / 30.0
			var steps: int = int(rig.steps) if drawn else int(own.steps)
			var rate := float(steps) / secs
			var dist := start.distance_to(who.p) if start != Vector2.INF else 0.0
			var per_step := dist / maxf(1.0, float(steps))
			var slip: float = float(rig.slip) if drawn else float(own.slip)
			if drawn:
				expect(elbow_n > 60, "%s: the drawn body was posed in %d of %d frames" % [lv, elbow_n, n - 30])
			var elbow: float = elbows / maxf(1.0, elbow_n) if drawn else (float(own.bend_lo) + float(own.bend_hi)) * 0.5
			var what := "%s, %s %s at %.1f m/s" % [lv, "the foundation's" if drawn else "the game's own", r[0], spd]
			info("%s: %.1f steps a second (%.2f m a step), slip %.1f cm, elbows %.0f deg%s" % [what, rate, per_step, slip * 100.0,
				elbow, "" if drawn else ", upper arm %.0f deg out, hands %.0f cm out" % [own.abd, float(own.out) * 100.0]])
			var need_rate := 1.6 if spd < 3.0 else 2.2
			expect(rate >= need_rate and per_step <= 2.4, "%s: %.1f steps a second, %.2f m a step - gliding, not running" % [what, rate, per_step])
			expect(slip < (LINK_SLIP if drawn else SLIP), "%s: a planted foot slid %.1f cm" % [what, slip * 100.0])
			expect(elbow >= ELBOW, "%s: the arms nearly straight (elbows %.0f degrees)" % [what, elbow])
			if not drawn:
				expect(float(own.bend_lo) > ELBOW and float(own.abd) < ABD and float(own.out) < 0.12,
					"%s: arms stretched out (elbows %.0f-%.0f deg, the upper arm %.0f deg from her side, hands %.0f cm out)" % [what,
					own.bend_lo, own.bend_hi, own.abd, float(own.out) * 100.0])
			expect(pose == "", "%s: %s" % [what, pose])
			who.queue_free()
			await frame()
	if not clips:
		info("(no licensed clips here: Medium and High measured on the game's own bodies)")
	# Everyone in AI matches: Low (the game's own bodies) and Medium (the foundation's, with the clips).
	Game.settings.graphics = Game.GFX_LOW
	FoundationLink.off = true
	for mc: Array in [["arena", 6], ["hall", 9]]:
		await h._gait_in_match(mc[0], mc[1])
	if clips:
		FoundationLink.off = false
		Game.settings.graphics = Game.GFX_MEDIUM
		for mc: Array in [["arena", 6], ["hall", 9]]:
			await h._foundation_match(mc[0], mc[1])
	await Harness.into(self, h)
