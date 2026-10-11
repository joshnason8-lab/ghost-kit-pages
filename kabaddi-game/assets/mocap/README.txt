Animation clips the athletes play (game/mocap_clip.gd).

move_*.json: the running set, from Mixamo and Meshy animations (tools/mocap/fbx_to_clip.gd).
Others serve a move by their name's prefix (kick_, dubki_, fall_, getup_, cele_<kind>_ ...), built from
Mixamo animations by tools/mocap/mixamo_set.py. raid_idle.json and raid_crouch_hunt.json come from match footage (to_clip.py).
