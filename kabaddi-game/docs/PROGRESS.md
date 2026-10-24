# Graphics update 0.9.0: progress and decisions

The owner asked for every game's graphics to be upgraded (the lead session's brief: `shared-assets/plans/COMMON.md`
and `plans/kabaddi-raid.md` on branch `claude/shared-assets`). This is what Kabaddi Raid did with it, ground by
ground, what it skipped and why, and what still needs the owner.

## What is in

| Ground | Sky | Ground surfaces | Round it |
|---|---|---|---|
| **Gaon Maidan** | `qwantani_dusk_2`, turned so its low sun sits where the ground's sun is (over the far side, raised from 14 to 17 degrees) | the court in beaten earth (`brown_mud_dry`), going to red earth (`red_dirt_mud_01`) past its lines, then to worn grass (`grass_ground`) further out | rain trees, island trees and coconut palms as cut-outs; dry grass (`dry_grass_tall_card`) round the edge and against the houses; two rows of white plastic chairs (`monobloc_chair`) along the far side with the village sitting on them; folding stools (`folding_stool`) at both ends; a trestle table for the scorers (`scorers_table`) with their chairs; four houses in plastered walls (`clay_plaster`, lime-washed colours) under clay tiles or thatch (`clay_roof_tiles`, `thatch_roof_angled`); the village temple (`indian_village_temple`, added to the shared assets during this update) across the ground, facing the court, beside a rain tree |
| **Monsoon Ground** | `overcast_soil`, its colour taken down (it was brown at the horizon) | wet mud (`brown_mud`) with puddles (the water's normal map, rippling; the sky in them), grass further out | rain trees dark with the wet, palms; plastic chairs under a blue tarpaulin on bamboo poles at one end, in its shade |
| **Puri Beach** | `qwantani_sunset`, turned so its sun is over the land behind the broadcast camera (Puri faces the Bay of Bengal to the east, so the evening sun cannot be over the sea), and the ground's sun brought down to an evening 24 degrees (it was 48), its light warm | dry sand (`coast_sand_01`) going to wet sand (`damp_beach_sand`) toward the water, sloping down into it | a new sea (the water's normal map in two drifting layers, deep and shallow water, the sky in it, surf where it runs up the sand, out to the horizon); coconut palms along the shore, island trees inland; plastic chairs along the far side; the Jagannath temple's tower (`jagannath_tower`, added to the shared assets during this update) on the far shore of the bay up the coast, 850 m off in the evening haze, where the broadcast camera sees it over the sea |
| **National Stadium** | `kloppenheim_07`, a cloudy night lit by the city | grass round the stands (`grass_ground`) | the stands in photographed concrete (`concrete_floor`); a city of apartment blocks (`city_apartments`) beyond them on three sides, dark, with windows lit |
| **Mumbai Dome** | indoors (no sky) | the floor in photographed concrete (`concrete_floor`), dark and polished | the stands in photographed concrete |

Everything repeated is drawn in one go (a MultiMesh: every tree of a kind, every chair, every stool), with soft
contact shadows under the seats, also in one go. Low uses the `_low` meshes, cut-outs for every tree, the 2K
panorama for the sky's light and no HDR; Medium and High light the grounds from the HDR, use the ground's and the
walls' normal maps and the full models. Only what is drawn is in the game: not the trees' `_low` models (Low draws
every tree as a cut-out) nor the Jagannath tower's full one (it is cut down on every level, 850 m off).

The fixed parts that were many separate meshes are now one each: the stands (four boxes a tier, up to 48 meshes in
the stadium), the court's lines and benches, the dome's lamps, the floodlight towers, each house. That takes the
grounds' draw calls down by more than the new scenery adds (numbers below).

## Decisions

- **Trees are cut-outs.** The rain tree and coconut palm models (Meshy) are coarse next to their cut-outs (rendered
  from a finer model): big flat leaves, a lime green. The trees round a ground stand more than 25 m from the broadcast
  camera, so by the shared README's own rule they are cut-outs; the full models are used only for the few within
  25 m of it (behind it, seen from the third-person camera), on Medium and High. Each cut-out faces the broadcast
  camera (its other side or its mirror image for every other tree, so no two of a kind look alike), sways a little,
  and is lit partly from above as a crown is. The rain tree's picture is toned down (60 % of its colour, 82 % of its
  brightness).
- **The Jagannath tower at 850 m**, a little beyond the 400 to 800 m the plan gives: from the broadcast camera the sky
  shows only about 3.5 degrees above the horizon, so a 60 m tower any nearer has its top cut off by the top of the
  picture. It stands on a hazy headland across the bay, with palms along its shore, so it does not stand in the sea.
- **The beach's bake takes less of its sky** (45 %, `Arena.BAKE_SKY`). At the full strength the other grounds use, its
  clear evening sky lit the open sand almost as brightly as the sun did: from the broadcast camera the sand in shade
  was 72 % as bright as in the sun, the shadows hardly showed and the sand went nearly white. Now 43 %, with the sand a
  little less red and the sun's light less orange, so it is about as light as the sand before it.
- **No tree on the sun's side of the village near the court.** The sun is low there (dusk): a 14 m rain tree within
  70 m in that direction laid its shadow right across the court.
- **Bleachers not used** (`bleacher_concrete`, `bleacher_metal`). The grounds' stands are straight tiers that the
  crowd sits on, sized to each ground; the curved concrete segment does not fit a rectangular ground, and neither
  model's steps are regular enough to seat the crowd's cards on. The stadium and dome keep their own tiers, now in
  the photographed concrete. Neither model is in the game.
- **Not used either, as the plan says:** the Thai temple, stilt house, oak, terraced houses, thatched cottage,
  jacaranda.
- **Sky light** is matched to the painted skies' it replaces (measured looking up and sideways), so the grounds,
  their bake and the players keep their brightness; the scanned surfaces, darker than the generated ones before
  them, are lightened to about those.
- **Source models are not committed.** `tools/scenery/fetch.sh` fetches them from the shared assets and
  `tools/scenery/convert.tscn` makes what the game loads (each model's mesh, its textures as they came): the game
  ships only those.

## Gaps that need the owner

- None for the grounds: the village temple and the Jagannath temple's tower both came while this update was being made
  (the lead had them generated, with the owner's approval) and are in.
- None for the water either: `water_normal_512.png` was made for these games from a sum of random sine waves (the
  shared assets' README says so since `6dbd5fd`), so it is the owner's own (treat it as CC0) and needs no credit.

## Performance

`tests/perf_probe.tscn` (draw calls, primitives, objects and video memory a frame, from the broadcast camera through
the first raid of the same seeded match) before and after, on this machine (software rendering):

| Ground | Level | Draw calls, 3D | Draw calls, whole frame | Primitives | Objects | Video memory, MB |
|---|---|---|---|---|---|---|
| Mumbai Dome | Low | 144 → 100 | 262 → 217 | 634k → 634k | 360 → 315 | 149 → 150 |
|  | Medium | 154 → 101 | 272 → 218 | 635k → 635k | 370 → 316 | 164 → 164 |
|  | High | 154 → 101 | 272 → 218 | 636k → 636k | 370 → 316 | 189 → 189 |
| National Stadium | Low | 154 → 101 | 272 → 219 | 635k → 661k | 371 → 317 | 151 → 155 |
|  | Medium | 166 → 103 | 283 → 221 | 637k → 741k | 383 → 319 | 166 → 171 |
|  | High | 166 → 104 | 283 → 222 | 639k → 743k | 383 → 320 | 190 → 196* |
| Gaon Maidan | Low | 145 → 102 | 263 → 220 | 636k → 668k | 362 → 318 | 143 → 154 |
|  | Medium | 199 → 120 | 316 → 238 | 640k → 806k | 416 → 336 | 158 → 173 |
|  | High | 199 → 124 | 316 → 242 | 641k → 807k | 416 → 340 | 183 → 197 |
| Monsoon Ground | Low | 125 → 98 | 243 → 216 | 632k → 657k | 342 → 314 | 144 → 156 |
|  | Medium | 170 → 110 | 286 → 228 | 639k → 773k | 382 → 326 | 159 → 171 |
|  | High | 170 → 114 | 286 → 232 | 646k → 790k | 382 → 330 | 184 → 196 |
| Puri Beach | Low | 134 → 96 | 252 → 212 | 638k → 673k | 350 → 310 | 142 → 156 |
|  | Medium | 181 → 107 | 298 → 224 | 643k → 793k | 396 → 322 | 157 → 168* |
|  | High | 181 → 113 | 298 → 229 | 644k → 803k | 396 → 327 | 182 → 192* |

The median frame of the first raid. "Before" is 0.8.6, the last commit before this update; "after" is 0.9.0. As
before, the dome and stadium ran in one run and the village, monsoon and beach in another, so video memory includes
what earlier grounds in the same run left loaded. \* measured in a run of that ground's Medium and High alone (the
stadium's Medium gave the same 171 MB there as in the long run).

- **Draw calls**: 22 to 41 % fewer in the 3D view, on every ground and level; 11 to 25 % fewer for the whole frame (the
  HUD's do not change). The stands, court lines, benches, lamps and masts are one mesh each, and every tree, chair and
  stool of a kind is drawn in one go: that saves more than the new scenery costs. Objects drawn: 8 to 19 % fewer.
- **Primitives**: Low draws about what it did (the same in the dome, up to 5 % more elsewhere: cut-outs and cut-down
  models). Medium and High draw 16 to 26 % more on the outdoor grounds and in the stadium (the full models of the
  trees, temple, chairs and stools near the broadcast camera, and the city's blocks). The dome's are unchanged.
- **Video memory**: up to 14 MB more on Low and 15 MB more on Medium and High, from the photographed surfaces and
  skies. The dome's is unchanged.
- Frame times are not in the table. Rendered in software here, with other jobs on the machine, they say nothing about
  a phone; the developer overlay (BETA.md, *Measuring stutter*) measures them on one.

## 0.9.1: the crowd faces the court

The owner saw the crowd on the near side looking the wrong way, in more than one game, and the lead passed it on to
all of them. Here every spectator is a card turned to the camera, cut from a sheet of each person drawn from the
front, so whoever a camera saw from behind still showed it their face.

- **Where it showed**: on every ground, wherever a camera was behind a crowd. That was the slow circle round the ground
  at a match's start, half-time and full-time (15 m out, behind each stand in turn); the live match behind the home
  screen (on Puri Beach the people standing nearest it faced it); and the edges of the broadcast view, which sits
  above the near stand's front rows and so showed little of it in play. The crowds concerned: the near stand of the
  Mumbai Dome and the National Stadium, the near side of those standing round Gaon Maidan and Puri Beach, and the
  Monsoon Ground's crowd under the tarpaulin from behind it.
- **The fix**: each spectator's card has a facing, its instance's -z, pointing at the court's middle along the
  ground, and there is a second sheet of every person drawn from behind (`tools/crowd/render_crowd.gd`: the same eight
  poses; the front sheet comes out the same to the pixel). The card still turns to the camera; when the camera is on
  the far side of them from where they face, it shows their back.
- **Checked**: `test_runner` checks on Low, Medium and High that every spectator on every ground faces the court's
  middle (forward against the way to it, dot above 0.7), from 72 of 72 on the beach on Low to 3,260 of 3,260 in the
  stadium on High, and that every crowd's cards have the back sheet. Headless, as CI runs it, a MultiMesh keeps no
  transforms, so each crowd keeps its spectators' feet and facing for the test, and with a renderer the test checks
  them against the transforms themselves. Before and after, from behind each crowd and from the court:
  [img/crowd_facing_0.9.1.jpg](img/crowd_facing_0.9.1.jpg).
- **Cost**: 14.4 MB more video memory on every ground and level, for the back sheet and its shirts' mask (on Low, the
  dome 150 → 164 MB and Gaon Maidan 154 → 168 MB). The draw calls, primitives and objects are the same (on Low, the
  dome's 100 and 217, 634k, 315; Gaon Maidan's 102 and 220, 668k, 318).

## 0.10.0: recorded crouched walks (CMU)

The owner added the CMU Graphics Lab Motion Capture Database to the shared assets, and the lead asked every game to
check where real recorded movement would make its players more real, and to use it there. The full account is in
[MOTION_REALISM.md](MOTION_REALISM.md), "Recorded crouched walks".

- **Used**: two takes of CMU subject 136 ("Weird Walks"), the only ones clearly more real than what the game had.
  136_09, Walk Crouched (7.27-8.48 s), is `move_crouch_walk`; 136_11, Walk Backwards Crouched (4.80-6.28 s), is
  `move_crouch_back`. A defender creeping forward or back in his stance, the commonest way anyone moves on the mat,
  stood up and strode (or jogged backwards at half speed) on the upright walk and jog; he now stays low. Before and
  after: [img/crouch_walk_0.10.0.jpg](img/crouch_walk_0.10.0.jpg).
- **Made into clips** by `tools/mocap/fbx_to_clip.gd`, which reads BVH now: one stride each, cut where its last pose
  meets its first; 30 frames a second, the game's 13 joints, the subject turned to face forward; no root motion (the
  clip says how fast and which way it goes, measured on the game's own skeleton so the feet hold, and the rig plants
  them); laid over the hand-made pose and cross-faded like every running clip. 14 and 18 KB of JSON; the BVH takes
  (0.86 and 1.09 MB) are not in the repository.
- **Not used**, each with its reason in MOTION_REALISM.md: the basketball defensive slide (102_22-28: twice the
  speed a kabaddi defender shuffles at), the basketball feints (102_18, 102_19: running drives), the karate kicks
  (135_04, 135_07, 135_11: head high), the two-person pull (18_03, 19_03: upright), the boxer's guard and avoid
  (76_03, 76_04), the crouched walks on the toes (136_13-16: too high), the run side steps (127_13, 127_14), and
  subject 139's takes (their copies could not be told from subject 77's). No take is a kabaddi move: the holds,
  dives, chains and dubki keep their clips or the hand-made pose.
- **The code**: a clip can say it is crouched (`"low": true`, from the converter's `--low`); a crouched clip carries a
  player only as fast as its legs can be played (1.8 times its speed, by his smoothed pace, and only three quarters of
  that to change into it), so running in to tackle is still the jog.
- **Checked**: test_runner (each CMU clip loads, and at its speed a planted foot slides under 0.2 m/s on the game's
  skeleton: 0.18 and 0.17; a crouched defender is carried by them creeping and by the jog running in; the licences
  screen credits the database), compile_check, locomotion_check, motion_audit, tackle_check, raid_audit, ai_bench,
  fit_audit. In three AI matches: pops 123 → 88, sudden steps 267 → 196, the planted foot's slide 0.05 → 0.03 m/s;
  clip changes 41 → 44 a minute.
- **Credit**: the licences screen: "Motion capture data from mocap.cs.cmu.edu. The database was created with funding
  from NSF EIA-0196217."
- **Cost**: none to measure. `perf_probe` (every ground on Low, the dome on Medium and High) gives the same draw
  calls, primitives, objects and video memory as 0.9.1; the players' animation takes 4.92 ms a frame for 14 players
  against 4.90 before, within the runs' spread. The two clips are 32 KB.

