extends WsgOwnerNote
## The owner, 2026-10-30 (Hurling 0.18 on the A16): "Referees still look awful, their upper body looks weird, can we use the player graphics for them? And they don't look like they are actually holding the flag."

const NOTE := {"id": "2026-10-30-referees", "game": "hurling", "date": "2026-10-30", "version": "Hurling 0.18 on the A16", "words": "Referees still look awful, their upper body looks weird, can we use the player graphics for them? And they don't look like they are actually holding the flag."}

## An official is drawn from the players' own model (the same mesh), a person (not a block, not a T- or A-pose as he
## follows the play), and his hand closes on what he holds: the flag's pole runs through the closed hand (the grip
## point within 2 cm of the hand's middle).
func check() -> void:
	var ch := WsgBody.load_character("res://tests/character", "hero")
	var off := WsgOfficial.new(ch)
	tree.root.add_child(off)
	await frame()
	expect(off.body.mesh_instance.mesh == (ch.meshes as Array)[0], "the official is not drawn with the players' model")
	var pos := Vector3.ZERO
	var poses := 0
	for f in 90:
		pos += Vector3(0, 0, 2.5) / 30.0
		off.position = pos
		off.follow(1.0 / 30.0, Vector3(0, 0, 2.5), Vector3(20, 0, pos.z))
		await frame()
		if WsgNoteChecks.t_or_a_pose(off.body) != "":
			poses += 1
	expect(poses == 0, "the official stood in a T- or A-pose %d frames of 90" % poses)
	off.body.grip("Right")
	await frame()
	var hand := off.body.bone_world("RightHand").origin
	var mid := (hand + off.body.bone_world("RightHandMiddle1").origin) * 0.5
	var gp := off.body.grip_point("Right").origin
	info("the flag's grip point %.1f cm from the middle of the closed hand" % (gp.distance_to(mid) * 100.0))
	expect(gp.distance_to(mid) < 0.05, "the flag would be %.1f cm from the hand that holds it" % (gp.distance_to(mid) * 100.0))
	expect(WsgNoteChecks.block_figure(off) == "", "the official is a block figure")
	off.queue_free()
