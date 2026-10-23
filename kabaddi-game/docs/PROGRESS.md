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
- **Where `water_normal_512.png` comes from** is not written in the shared assets' README (every other piece names
  its source and licence). Until it is, Settings › About › Licences credits Poly Haven for the rest only.

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
