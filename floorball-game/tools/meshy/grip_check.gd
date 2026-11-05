extends Node
## How far the model's hands are from the stick where the game holds it (m), in a few poses.
func _ready() -> void:
	Game.main = self
	for women in [false, true]:
		var p := Player.new({"id": "SWE%s5" % ("w" if women else "m"), "num": 5, "kit": [Color.YELLOW, Color.BLUE, Color.WHITE], "height": 1.8}, 0, "F", 1)
		add_child(p)
		for act in ["", "shoot", "tackle"]:
			if act != "":
				p.do(act, 0.5)
			for i in 12:
				p.step(1.0 / 60.0)
			var b: Body = p.body
			var r: RiggedBody = b.rig
			var sx := b.stick_transform()
			var down := -sx.basis.y.normalized()
			for side in b.stick_hands():
				var target_world: Vector3 = b.global_transform * (sx.origin + down * float(b.stick_hands()[side]))
				var hi: int = r.skeleton.find_bone("mixamorig_LeftHand" if side == "l" else "mixamorig_RightHand")
				var hand_world: Vector3 = r.skeleton.global_transform * r.skeleton.get_bone_global_pose(hi).origin
				var ai: int = r.skeleton.find_bone("mixamorig_LeftArm" if side == "l" else "mixamorig_RightArm")
				var sh_world: Vector3 = r.skeleton.global_transform * r.skeleton.get_bone_global_pose(ai).origin
				var g0: Vector3 = b.global_transform * sx.origin
				var g1: Vector3 = b.global_transform * (sx.origin + down * Body.STICK_LEN)
				var on := Geometry3D.get_closest_point_to_segment(hand_world, g0, g1)
				print("%s %-7s %s hand off the shaft %.3f m, %.2f m from its place (shoulder to place %.2f m)" % ["woman" if women else "man", act if act != "" else "stand", side,
					hand_world.distance_to(on), on.distance_to(target_world), sh_world.distance_to(target_world)])
		p.queue_free()
	get_tree().quit()
