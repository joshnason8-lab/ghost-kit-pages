Animation clips the athletes play (game/mocap_clip.gd).

move_*.json: the running set, from Mixamo and Meshy animations (tools/mocap/fbx_to_clip.gd). The crouched walks,
move_crouch_walk.json and move_crouch_back.json, are from the CMU Graphics Lab Motion Capture Database: takes 136_09
(Walk Crouched, 7.27-8.48 s) and 136_11 (Walk Backwards Crouched, 4.80-6.28 s). Motion capture data from
mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217.
Others serve a move by their name's prefix (kick_, dubki_, fall_, getup_, cele_<kind>_ ...), built from
Mixamo animations by tools/mocap/mixamo_set.py. raid_crouch_hunt.json comes from match footage (to_clip.py). (raid_idle.json, from a screen recording, stood the raider
nearly straight-kneed and was taken out in 0.13.0: his legs are hand-made now, HumanModel._animate.)
