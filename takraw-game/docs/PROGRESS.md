# Graphics update (0.5.0): what went where

The owner asked for every game's surroundings to be brought up to the players: skies, surfaces, water, trees, seats,
buildings and the small things, true to the region (Southeast Asia here) and realistic, never cartoon. The pieces come
from the shared assets (branch `claude/shared-assets`, `shared-assets/plans/sepak-takraw-unleashed.md`), copied into
`assets/venue/` (only what is used) and placed by `game/scenery.gd` from `game/arena.gd`.

## How it is built

- **One draw call a kind.** Every repeated piece (chairs, stools, benches, lamps, lanterns, stall roofs, trees) is a
  `MultiMeshInstance3D`, so forty chairs cost one draw call.
- **Low** uses the `_low` models, no relief (normal maps) on surfaces, no sky lighting (the panorama is only the
  background), no shadows. The bleacher's `_low` model is the exception: it came out as broken shards and saves
  little, so Low uses the full one (`Scenery.FULL_ON_LOW`).
- **Trees are always the photographed cut-outs** (`_card`, two crossed planes), at every level: from the broadcast
  seats every tree is 25 m or more away, where the cut-outs look far more real than the meshes (the meshes' leaves
  read as faceted shapes).
- **Skies:** the 2K panoramas only, as background and, on Medium and High, as the light round the place. The 1K HDR
  files weren't copied: the panorama lights the scene well enough and leaving them out saves about 6 MB in the
  download. Outdoors by day the sunlight comes from the sun in the sky (its brightest point, measured once:
  `Scenery.SUNS`); the sunset's is raised from 7° to 16°, or every shadow would cross the court. By night the light is
  the floodlights', and the ambient light the place's own colour (a night sky is too dark to light it).
- **Surfaces** are the photographed ones laid in world space by one shader (`Scenery.surface`): tinted, or painted (a
  court painted on concrete or asphalt keeps the grain), filtered anisotropically on Medium and High so the ground
  far off keeps its grain. Roughness maps weren't copied (a constant roughness).
- **Water** (the beach): the wave normal map drifting in two directions, deep blue far out, the sky's colour at a
  glancing angle, the sun's glints. No reflections.
- **Indoors** on Medium and High the glossy courts reflect a real hall's interior (`gym_01`, dimmed), not the
  background colour.

## Venue by venue

| Venue | What it has now |
|---|---|
| Temple court | The owner's Thai wat behind the court, its long side to the camera; the court painted on the compound's concrete; spectators on white plastic chairs (three rows, two on Low), more standing; coconut palms, rain trees and the island trees round about. Sky: `qwantani_noon_puresky`. |
| Park court | The court painted on clean asphalt in grass (`grass_ground`, added: the plan's park has grass round it); a chain-link fence (shader) on three sides with its posts; park benches behind it with people on them; street lamps along the path; the owner's street hoop on the next court; rain trees; past them a row of shophouses (`shophouse_row_low`, the cut-out: they're 45 m off) and apartment blocks with lit windows (`city_apartments_night`). Sky: `kloppenheim_02_puresky`. Kept: the four floodlight poles. |
| Beach | Dry sand (`coast_sand_01`), damp sand at the water's edge, the sea (`water_normal_512`); coconut palms along the beach; two stilt houses back from it (no shadows: under the low sun they'd cross the court). Sky: `qwantani_sunset_puresky`. Kept: the bunting and the umbrellas. |
| Night market | The street (`asphalt_02`) with the court painted on it; seven stalls (`long_table` and `scorers_table` under `corrugated_iron` roofs), a lantern under each; strings of lanterns over the court; people on folding stools, metal stools by the stalls, café table sets; shophouses end to end along both sides of the street (`shophouse_row`, every other one turned to show its other front, each row a little different in colour; the far ones and all on Low the cut-out), street lamps on their walls, apartment blocks with lit windows behind (`city_apartments_night`). Sky: `kloppenheim_07_puresky`. |
| Provincial gym | A maple floor (`white_maple_veneer`) with the court painted on it; painted block walls (`concrete_block_wall`); three sections of metal bleachers with the crowd on them; fluorescent battens in rows under the roof; a clock over the middle, a fire alarm and a wet-floor sign by a door; the hall's own wooden benches for the teams; clean basketball boards on the end walls (built to measure: a 1.80 × 1.05 m board, the rim 3.05 m up). Kept: the banners and the ceiling fans. |
| Shopping-mall atrium | Three sections of metal bleachers along the far side instead of the box seats. |
| National Arena, Grand Dome | The reflection of a real hall in the glossy courts. The stands stay the game's own tiers: the bleacher sections' rows don't line up with the bowl's, and the crowd sits on its rows. |

Every venue from the broadcast camera, on Low and on High: [`venues/venues_low.jpg`](venues/venues_low.jpg),
[`venues/venues_high.jpg`](venues/venues_high.jpg) (`tests/venue_view.tscn -- <dir> [venues][,low]`).

Moved or skipped, and why:

- `bleacher_metal` in the arenas' lower tiers: see above.
- `trees/coconut_palm`, `rain_tree` meshes: the cut-outs are used everywhere instead (the meshes were removed in
  0.5.1).
- The HDR skies and the roughness maps: download size.
- The concrete court at the temple: the plan offered `concrete_floor` or `clean_asphalt`; concrete, since a wat's
  forecourt is paved.

## Performance (`tests/perf_probe.tscn -- all 0,1,2`, a match in each venue)

| Venue | Low before | Low after | Medium after | High before | High after |
|---|---|---|---|---|---|
| National Arena | 72 calls, 102k tris | 72 calls, 102k tris | 74 calls, 114k tris | 88 calls, 221k tris | 88 calls, 221k tris |
| Grand Dome | 72 calls, 102k tris | 72 calls, 102k tris | 74 calls, 116k tris | 88 calls, 224k tris | 88 calls, 224k tris |
| Mall atrium | 72 calls, 100k tris | 73 calls, 124k tris | 75 calls, 135k tris | 88 calls, 218k tris | 91 calls, 290k tris |
| Provincial gym | 69 calls, 99k tris | 78 calls, 124k tris | 80 calls, 136k tris | 85 calls, 217k tris | 106 calls, 294k tris |
| Temple court | 69 calls, 100k tris | 77 calls, 140k tris | 79 calls, 126k tris | 85 calls, 217k tris | 97 calls, 264k tris |
| Park court | 69 calls, 100k tris | 81 calls, 107k tris | 83 calls, 137k tris | 84 calls, 212k tris | 102 calls, 285k tris |
| Beach | 69 calls, 100k tris | 76 calls, 102k tris | 78 calls, 116k tris | 107 calls, 388k tris | 97 calls, 271k tris |
| Night market | 69 calls, 101k tris | 86 calls, 111k tris | 88 calls, 161k tris | 87 calls, 229k tris | 122 calls, 315k tris |

(Each figure is one frame of a match, so the triangles move with the camera: the temple's Medium frame happened to
look past most of the chairs. The park and the night market are 0.5.1's, with the shophouses: one or two draw calls
more than 0.5.0's; the others are unchanged. Measured with `--fixed-fps 30`, as the README has it: without it the
match runs in real time, and on a slow machine the frame lands at another moment and Auto graphics lowers the
scale.) Low stays well inside its budget of about 100 draw calls everywhere. Most of the added triangles on Low are the
temple's plastic chairs and the bleachers.

0.6.0 (motion capture for the jumps, the kicks' feet locked) draws exactly the same: every venue and level gave the
same draw calls and triangles as 0.5.2 (docs/MOCAP.md).

## Download size (0.5.1)

0.5.0's APK was 89 MB (0.4.0's 38 MB): GPU-compressed textures are stored in the APK as they are, unzipped, and the
venue pieces came to 50 MB of them. 0.5.1 brings the venue pieces down to about 9 MB, the shophouses and the lit
apartment blocks included, with no visible change in the broadcast view (each venue compared before and after at
1920 × 1080):

- **Skies and tree cut-outs** stored as WebP at full size (`compress/mode=1`): 7 MB of skies became 0.8 MB.
- **Ground scans** stored as WebP at 512 px (the grass at 1024: its blades blur at 512); they're mipmapped now (the
  grass wasn't, and shimmered).
- **Model textures** stored as WebP too. Those never seen close capped at 512 px:
  - the stilt houses, the apartment blocks, the temple's relief and the bleachers;
  - the small things at 256 px (chairs, stools, lamps, lanterns, the café set, the light battens), which are under
    60 px tall on screen.

  The temple's colour and the shophouses' stay at 1024: at 512 the carvings smear.
- WebP costs more memory once loaded than GPU-compressed textures (a few MB a venue), well within a 4 GB phone.
- The unused palm and rain-tree meshes and the old apartment block were removed.

## The crowd faces the court (0.5.2)

The owner saw spectators in the near stand facing away from the court. Here every spectator was a cut-out turned to
the camera and always showing the figure's front, so from behind a stand they all faced the camera rather than the
court. That only happens in the National Arena's and the Grand Dome's near stands: the other venues seat everyone on
the far side, and no game camera looks at the near stands, so it never showed in play.

Now each spectator faces the court's centre (`Crowd.facing`). The cut-out still turns to the camera, but when the
camera is behind someone it shows them from behind: the crowd sheet has a second row, the same figures rendered from
the back (`tools/models/crowd_sheet.tscn`). `tests/test_runner` checks every spectator in every venue at every
graphics level (each one's forward within 45° of the way to the court's centre). `tests/crowd_view.tscn` renders
each venue from cameras on the court looking at each stand, and from behind the near stand:
[`venues/crowd_facing.jpg`](venues/crowd_facing.jpg) (before and after, close up) and
[`venues/crowd_facing_all_venues.jpg`](venues/crowd_facing_all_venues.jpg).

## Whole people, and no edge to the world (0.7.0)

The owner saw the crowd had no legs when it jumped to cheer, the beach's fans standing on stumps, white nothingness
past the ground at the beach (and the sea ending in a square), and the same at the night market from the end camera.

- **The crowd sheet** (`tools/models/crowd_sheet.tscn`) has whole people now, from their feet up (2.2 m a figure, so
  a hand held up fits): seated from the front and from behind, and standing from the front and from behind (arms at
  their sides, clapping, hands on hips, a fist or both arms up, the weight on one leg). 1152 × 768 px, lossless.
- **Seated and standing:** a seated spectator's feet are on the floor under their seat; those on the sand, behind the
  park's benches and by the stalls stand (`Arena._standing`), as people there do.
- **Cheering:** when the crowd goes up after a point, the seated get to their feet (each at their own point of the
  excitement, so they rise over half a second, not as one) and jump; as it settles they sit down one by one.
- **The far ground:** outdoors the ground now reaches the camera's far plane (300 m; it was 60 m), and the sea at the
  beach runs past it (it ended 300 m out, square). Past 140 m everything fades into the colour of the far ground in
  the haze (depth fog), and the sky takes that colour under the horizon (`Scenery.sky`'s `below`) instead of the
  photograph's empty lower half. The beach's dry sand had been laid over the first 34 m of the sea: it stops at the
  damp sand now, so the water starts at the water's edge.
- **The night market's street** is closed at both ends by two more rows of shophouses across it (the cut-outs), so
  the end camera looks down a street, not into the dark.

Performance (`perf_probe`, `--fixed-fps 30`): the same objects and triangles as 0.6.0 everywhere (the beach on High
5k more, its longer sea), and 2 draw calls more in every venue: the officials in the picture, posed afresh each frame
now that they move (their bodies are skinned again each time). Low is 74 to 88 draw calls; High 90 to 124. The fog
and the far ground cost no draw calls; the crowd's bigger cut-outs none either (still one).

`tests/venue_view.tscn -- <dir> <venues>,around` renders the outdoor venues from the end camera at each end, the side
camera and looking out from the court; `tests/crowd_view.tscn -- <dir> 2 up` the crowd on its feet.

## More detail on Medium and High (0.9.0)

The owner allows a bigger download for a game that looks and sounds better. Low loads exactly what it did; Medium and
High load their own bigger files, compressed for the GPU (ETC2 on a phone, so a 2K texture takes 2.7 MB of video
memory with its mipmaps, not the 21 MB it would as plain pixels):

- **The ground and courts:** Poly Haven's 2K scans of the same surfaces, not the 512 px ones (`Scenery.surface`): the
  colour at 2048 px, the relief (normal map) at 1024 (0.9.1: at 2048 a relief map took 5.6 MB in the download, as two
  channels compressed apart, 50 MB for the nine, for a difference hard to see). The grain of the concrete, the asphalt,
  the sand and the maple stays sharp close to the camera.
- **The skies:** the 4K panoramas (from Poly Haven's full-size ones), their colours fitted to the 2K ones Low shows
  (each channel by a curve, within 2 levels of 255), so the place looks the same on every level, only sharper.
- **The players:** their textures at 2048 px and the kits' masks at 1024 (`RealBody.SKINS_HI`), cut from the models'
  own 4096 px textures (`tools/models/kit_mask.py`).
- **The crowd:** a 32-figure sheet at 96 × 256 px a figure (`crowd_sheet_hi.png`, `crowd_sheet.tscn -- hi`): six
  skin tones, heights from 1.55 to 1.88 m, shorts in their own colours (only the shirt is dyed), and more poses
  (elbows on the knees, hands in the lap, filming on a phone). Low keeps its 16 figures.
- **The sound** (on every level; it costs the GPU nothing): the venues' loops 36 to 60 s, the crowd's murmur 30 s, two
  more cheers, two more applause takes, the crowd clapping in time at a set point (docs/SOUNDS.md).

`tests/test_runner` checks what each level loads: Low the same files as before, Medium and High the bigger ones.

### Performance and video memory

`perf_probe` with `--fixed-fps 30`, each venue and level in a process of its own (so nothing loaded for one venue or
level is counted in the next): the draw calls, triangles and video memory (all of it: textures, meshes, buffers) of
one frame of a match.

| Venue | Low (0.8.0 = 0.9.1) | Medium 0.8.0 → 0.9.1 | High 0.8.0 → 0.9.1 |
|---|---|---|---|
| National Arena | 72 calls, 102k tris, 31.4 MB | 74 calls, 114k tris, 53.2 → 54.4 MB | 88 calls, 221k tris, 72.5 → 73.6 MB |
| Grand Dome | 72 calls, 102k tris, 31.4 MB | 74 calls, 116k tris, 53.3 → 54.5 MB | 88 calls, 224k tris, 72.6 → 73.7 MB |
| Mall atrium | 73 calls, 124k tris, 33.8 MB | 75 calls, 135k tris, 55.6 → 56.7 MB | 91 calls, 290k tris, 74.8 → 76.0 MB |
| Provincial gym | 78 calls, 124k tris, 38.5 MB | 80 calls, 136k tris, 61.0 → 66.2 MB | 106 calls, 294k tris, 80.3 → 85.4 MB |
| Temple court | 77 calls, 140k tris, 52.8 MB | 79 calls, 126k tris, 70.2 → 70.7 MB | 97 calls, 264k tris, 89.4 → 89.9 MB |
| Park court | 81 calls, 107k tris, 58.7 MB | 83 calls, 137k tris, 76.1 → 75.6 MB | 102 calls, 285k tris, 95.4 → 94.9 MB |
| Beach | 76 calls, 102k tris, 49.8 MB | 78 calls, 116k tris, 63.8 → 66.3 MB | 98 calls, 276k tris, 83.0 → 85.5 MB |
| Night market | 86 calls, 111k tris, 50.6 MB | 88 calls, 161k tris, 73.4 → 75.9 MB | 122 calls, 315k tris, 92.6 → 95.1 MB |

Low is the same in every venue, to the draw call and the tenth of a megabyte. Medium and High draw the same; their
video memory is up by 1 MB in the halls (the players' 2K textures, less the crowd sheet, which is smaller compressed
than the old one is as plain pixels) and by up to 5 MB outdoors and in the gym (the 2K surfaces and 4K skies; in the
park the smaller crowd sheet outweighs them, 0.5 MB less). The most, the night market on High, is 95 MB: within a
mid-range phone's means. (0.9.0, with the relief at 2048 px, took up to 13 MB more: 103 MB at the most.)

## The venues filled in, the fans watching the game (0.10.0)

The owner found the mall atrium's surroundings blank, the beach bare on one side, the fans all looking at the camera,
the seated line judges with their arms held out, two dots in the score read as time-outs, and the United States in the
Asian Championship.

- **The mall** is an atrium now (`Arena._mall`): three floors of shops on all four sides (their fronts six pictures of
  shops made with Meshy's text-to-image, `assets/venue/mall/shopfronts.jpg`, drawn as one mesh), the upper floors'
  balconies with glass railings and people leaning on them, columns, escalators in the near corners, palms in planters
  and kiosks, a granite tile floor (Poly Haven), the roof and its skylight seen from below; metal bleachers on both
  long sides.
- **The other venues:** the beach's bare side has palms, two beach bars, sun loungers and umbrellas, a food cart and
  people watching; a lifeguards' tower and longtail boats by the water. The temple court's near side a sala with people
  on its floor, chedis, the spirit house, food carts and parked scooters. The arenas: the corners walled in, a lit
  ribbon and the suites round the top of the stands, a scoreboard over the court; their roofs (and the mall's and the
  gym's) were built facing up and so never drawn from below: they face down now. The gym: its windows faced out (never
  seen) and face in now, a scoreboard over the doors, bleachers on both sides, the near wall behind the cameras, and the
  walls the light falls on full a shade darker (on High they burned white). Carts and scooters at the park and the
  market; trees on the near sides kept 25 m back, clear of the cameras.
- **Fifteen props from Meshy** (`tools/meshy/assets.json`, kind "prop"; `tools/models/prepare_model.gd` now sizes a
  Meshy model to its real height or length): on Medium and High as made (2,000-8,000 triangles, 1024 px), on Low
  Meshy's remesh of each (300-1,500 triangles, 256 px, colour only).
- **The fans watch the game:** the crowd sheet draws each figure from five sides (front, three-quarters, side,
  three-quarters from behind, behind; `tools/models/crowd_sheet.tscn`); the shader shows each spectator from the side
  the camera sees of them, mirrored for the other side, and turns them partly toward the ball (`Crowd.set_look`), each
  at their own moment. 10 rows instead of 4; the Low sheet is compressed for the GPU now (2.9 MB of video memory with
  its mipmaps, from 3.9 MB for the four rows uncompressed).
- **The seated pose** (`Moves` "sit"): the hands rest on the thighs; the arms were held out in front. The line judges
  and the seated crowd both use it.
- **The score:** "Sets: 1" under each team's name in a best-of-three match, nothing in a one-set match; the two dots
  were the sets won.
- **Simulate to the end** (the pause menu, a season's or a tournament's match): the rest of the match played out
  rally by rally from the score as it stands, from the two sides' ratings (`Sim.rally`), then its result as if played.
- **International:** each event's entry list is its field only (`Cup.KINDS`): the World Championship open to every
  nation, the Asian Championship Asia's eighteen, the Southeast Asian Championship the region's ten.
- **The home screen:** the links sized from their own text (they were sized for 20 px text drawn at 26); the eyebrow
  line gone.

Performance on Low (`perf_probe`, `--fixed-fps 30`, each venue in its own process), 0.9.1 → 0.10.0:

| Venue | Draw calls | Triangles | Video memory |
|---|---|---|---|
| National Arena | 72 → 66 | 102k → 101k | 31.4 → 30.0 MB |
| Grand Dome | 72 → 66 | 102k → 102k | 31.4 → 30.0 MB |
| Mall atrium | 73 → 73 | 124k → 165k | 33.8 → 37.1 MB |
| Provincial gym | 78 → 74 | 124k → 149k | 38.5 → 37.1 MB |
| Temple court | 77 → 73 | 140k → 146k | 52.8 → 52.6 MB |
| Park court | 81 → 77 | 107k → 114k | 58.7 → 57.6 MB |
| Beach | 76 → 74 | 102k → 112k | 49.8 → 49.6 MB |
| Night market | 86 → 82 | 111k → 129k | 50.6 → 49.5 MB |

(The draw calls fall: the crowd's compressed sheet and the arenas' scoreboard in place of the cube's lit faces.)

## The computer plays like the top sides; the arenas dressed as for the big events (0.11.0)

The owner sent two broadcasts: the 2024 World Cup's Thailand v the Philippines and the Asian Cup's India v the
Philippines. What they showed, point by point, and what the computer copies from them: docs/AI.md.

- **The serve decides points:** the computer's tekongs serve hard and flat every time, at the receiver they pick for
  the set, and miss more often for it. A reception can spill: out off the body, dead at the receiver's feet, or back
  over the net to be put away; the likelier the harder the serve and the better its server against the receiver.
  Your serve, timed well, is the same power serve.
- **The formation:** the receiving line flat 3-4 m off the net; the pass to the setter in the middle 2.4 m off it;
  one blocker, the inside player on the spike's side; the cover behind its own spiker; a loose ball that comes over
  put away at once.
- **Shorter rallies:** spikes harder to dig, out less often; a block stuffs a spike less often (22% of the blocks it
  gets a foot to, from 45%).
- **Difficulty** scales what decided the real points: the computer's service faults and spilled receptions (x1.35 on
  Rookie to x0.85 on Legend), and the pace of its serve at you (x0.82 on Rookie to x1.04 on Legend).
- **A serve into the net** is a fault at once ("the serve didn't cross", in every language): before, the serving side
  could play it on.
- **The arenas, the dome and the mall dressed as the big events are** (`Arena._tournament_dressing`): red pads round
  the posts with a box at their feet, a ball stand by the near post, TV cameras on tripods at the corners, the game's
  name on the floor behind each back line, a courtside scoreboard that keeps the score; the jury's tables in white
  cloths behind the far boards (the arenas and the dome); flags in the home side's colours waving in the crowd (one
  spectator in thirty, `Crowd._flags`, one draw call); the props' textures compressed for the GPU.
- `tests/match_sim.tscn` reports how the points were decided in the real matches' terms, and each rally's touches
  with `SEQ=1` (`SEED=n` to run several at once, `PAIR=THA,KOR` for one match).

How the points were decided (eight AI-v-AI regu matches, the same eight each time; the real matches: 32 points):

| | Real | 0.10.0 | 0.11.0 |
|---|---|---|---|
| A kill | 40% | 59% | 46% |
| The serve (the reception failing) | 34% | 1% | 25% |
| A service fault | 19% | 4% | 17% |
| A block | 6% | 19% | 5% |
| Another error | 3% | 17% | 7% |

The stronger side wins more often now: Thailand (93) beat Korea (78) in 5 of 6 matches, from 2 of 6.

Performance on Low (`perf_probe`, `--fixed-fps 30`, each venue in its own process), 0.10.0 → 0.11.0:

| Venue | Draw calls | Triangles | Video memory |
|---|---|---|---|
| National Arena | 66 → 70 | 101k → 102k | 30.0 → 31.0 MB |
| Grand Dome | 66 → 70 | 102k → 103k | 30.0 → 31.0 MB |
| Mall atrium | 73 → 77 | 165k → 165k | 37.1 → 37.7 MB |
| Provincial gym | 74 → 75 | 149k → 149k | 37.1 → 36.8 MB |
| Temple court | 73 → 74 | 146k → 146k | 52.6 → 51.5 MB |
| Park court | 77 → 77 | 114k → 114k | 57.6 → 57.2 MB |
| Beach | 74 → 74 | 112k → 112k | 49.6 → 48.5 MB |
| Night market | 82 → 82 | 129k → 129k | 49.5 → 49.1 MB |

(The tournament venues' added draw calls: the floor's lettering, the scoreboard's lines, the flags. Video memory
falls elsewhere: the props' textures compressed for the GPU.)

## The officials in suits (0.11.1)

The referee, his assistant and the line judges wear suits, as at the World Cup and the Asian championships: a dark
jacket and trousers, a white shirt with its collar and cuffs, a red tie, black shoes. They were the players' model in
a white shirt and dark shorts.

- **The same model, dressed by a mask:** `tools/models/suit_mask.gd` classes each texel of the man's texture by where
  it is on the body in its rest pose and which bones move it (the arms, hands, legs, feet, head). It writes
  `assets/models/man_suit.png` (512 px): the cloth, the shirt, the tie and the shoes, one channel each. His face, neck
  and hands stay his own.
- **The officials' shader** (`RealBody._suit_material`) paints those in the suit's colours, keeping the folds and
  shading of the model's own texture. So the suit follows every pose: the referee in his chair, the signals, the line
  judges' weight shifts.
- **On every level, one draw call each as before;** the mask costs about 1.4 MB of video memory with its mipmaps
  (lossless, so the tie's few texels stay sharp).
- `test_runner` checks every official wears the suit, and the mask has each of its parts.
- Before and after: `docs/venues/officials_suits.jpg`.

Performance on Low (`perf_probe`, 0.11.0 → 0.11.1): the same draw calls within a frame's noise (±2), and 1.3 to
1.9 MB more video memory in each venue (the mask): the National Arena 32.7 MB, the night market 50.4 MB, the park
58.6 MB, the most.

## The owner's list: the ball in hand, the officials and the bench, the crowd, the venues (0.12.0)

**The home screen and Settings.** League Season says "A full league season in Malaysia, Thailand or Indonesia." (not
"the real leagues": the clubs are invented). Settings > About's Privacy policy and Help went to a web page that isn't
there: they open in the game now (`ui/doc_screen.gd`, no internet needed). The privacy policy says what the game
keeps (settings, saves and records, on the phone only), that it collects and sends nothing, asks for no permissions,
has no ads, accounts or tracking, and is fine for children; the help covers playing, serving, attacking, slowing the
game down, a phone that struggles, the takraw words, and an "Email us" button. Both in all thirteen languages; Help
opens How to Play. They and Licences open over Settings, so Licences from a paused match no longer ends the match.
`takraw-smash/privacy.html` says the same.

**The ball is never left in the air.** When a rally ends the ball comes down: it falls, bounces (less on sand), rolls
and stops, and bounces off the boards, walls and fences instead of going through them (`Ball.set_loose`, each venue's
`Arena.bounds`). Every bounce is heard, as loud as it was hard. Between points a player fetches it: the nearest picks
it up (bends, his right hand to the floor), carries it, and passes it with an underarm lob to the thrower (the regu)
or the server (doubles), who catches it and carries it to his place in both hands. Before, it hung in the air where
the rally ended, then jumped to the thrower.

**The serve's toss.** The thrower stands at his place facing the tekong, the ball held in both hands in front of him,
and watches him. The toss is one movement: the ball lowered, the knees bent, the swing up, the release from his
hands with his arms out to the tekong, the follow-through; then he turns back to the net (`Moves` "toss"). The
ball's flight starts from his hands, on the same arc as before.

**Alive while they wait.** Every player breathes, sways a little, shifts his weight from foot to foot now and then
and keeps his head on the ball; the receivers wait on their toes, the knees working (the servers' side less);
`Player._life_pose`, over the stance, eased out as he runs or plays. Measured over the set-up: each player's head moves
7 to 24 cm, his hips 9-10 cm up and down.

**The ball's sounds.** The kicks were wooden knocks (bright, ringing at 1.7 or 4 kHz). Now real balls: a soccer ball
kicked with a rubber ball hit by hand under it; a rubber ball hit and caught for a thigh or chest touch; a hard hit for
the spike; a slap and thump for the block; a basketball's bounce (Mixkit, docs/SOUNDS.md). The kicks play 3 dB louder.

**The officials: four, the line judges standing.** The referee in his high chair and the assistant at the other post;
a line judge at each end, standing off the far corner (in the broadcast picture, never in front of it), a red flag in
his right hand. While the ball is in play at his end he bends to his lines, his hands on his knees; when a ball comes
at him (it would pass within 85 cm below 2.1 m in the next 0.7 s) he steps 1.25 m out of its way, across its line and
away from the court, and back to his place a second or so after. His flag goes up for out, down at the court for in.
Before: six officials, the line judges sitting on chairs at all four corners. `test_runner` drives a ball at a line
judge and checks he gets out of the way and back.

**Substitutes on the benches.** Two a side in a regu (one in doubles, one on Low): the squad's players not playing,
in their team's kit, sitting on their team's bench, watching the ball; up with their arms when their side wins a big
point; they change benches with the ends.

**The score at the top** is narrower: no space between the name and the score (each panel as wide as its name and
score need, 128 px at least, from 178), 48 px high (from 66), the middle panel 84 px (from 108) and its "set point"
line shown only when there is one.

**The crowd** (`game/crowd.gd`, `tools/models/crowd_sheet.gd`):
- It turns with the ball in short steps (every 1.2 m the ball moves, over 0.7 s), each fan at his own moment with a
  quick dissolve from one drawn angle to the next, so a turn ripples through the stand. Before, the whole stand
  snapped between two angles 45° apart.
- Four cheers, mixed through the crowd: clapping (about 3 in 8), a real jump (a crouch, the spring, in the air with
  the arms up), a fist pump, both arms up swaying; three frames each, dissolved into each other, each fan at his own
  speed and phase, starting and stopping one by one. Before, everyone bounced up and down on one frame.
- At rest: arms at the sides, hands on hips, arms folded, hands together (standing); hands on the knees, in the lap,
  leaning in or back (sitting).
- Its flags are the two teams': about 65% the home side's, 35% the away side's; national flags for nations, a club's
  colours with a sash for clubs.

**Three venues gone:** the night market, the temple court and the Grand Dome (154 files, 38.7 MB of models,
textures, skies and sounds). The world championship is played at the mall, the season's finals at the National Arena,
and the clubs' and nations' home venues are among the five left.

**The provincial gym** (`Arena._gym`):
- **The basketball hoops** are the netball and floorball halls' regulation boards: a steel bracket off the wall, a
  glass board with its white border and box, an orange ring and a white net, blue wall pads under each (built in
  code, `_backboard`; the glass one see-through material, one more draw call in the gym only). Before, a flat grey
  board.
- **The walls** are painted concrete block (relief on the far wall), a teal band low down, a mustard line and cream
  above; a band of frosted windows high up in aluminium frames; steel roof trusses holding the lights and fans; doors
  with lit exit signs; the scoreboard, clock and banners on the far wall. Before, flat white walls with square windows.
- **The stands** are the floorball hall's aluminium bleachers (`assets/venue/stands/bleacher_hall*.glb`), three
  sections a side, two deep, six rows, the back ones on a raised steel deck: 576 seats (from 390). The far wall moved
  back from 12.6 m to 15.4 m to fit them; the benches, the scorers' table and the referee's chair stay where they were.

**The beach's background** (`Arena._beach_far`): more palms, umbrellas, loungers and kayaks along the sand and a
volleyball net; a fishing village (stilt houses and boats), five resort hotels with some windows lit, a jetty with a
boat tied up; longtails, yachts and trawlers out on the water; limestone islands in the bay, wooded headlands at both
ends and hills inland. The beach's haze starts at 175 m (from 140) so the islands keep their colour. None of it casts
a shadow; Low has fewer palms and boats.

**The words in 3D are in the player's language:** the game's name on the floor behind each back line, the boards'
words and the scoreboard's "SETS" (three new keys, all thirteen languages), in a bold font chain that draws every
script (`Arena._words_font`), made smaller where a language's words run longer (`_fit`). Before, always English.

**Chinese, Japanese and Korean at the right weight:** those fonts are variable with their thinnest weight (100) as
the default, and only the Latin font was set to the weights the game uses, so the menus' Chinese, Japanese and Korean
text drew at its thinnest. Each weight's fallbacks are now set to that weight too (`Game._weighted`).

Performance on Low (`perf_probe`, `--fixed-fps 30`, each venue in its own process), 0.11.0 → 0.12.0 (0.11.1 added
1.3-1.9 MB of video memory everywhere, the suits' mask):

| Venue | Draw calls | Triangles | Video memory |
|---|---|---|---|
| National Arena | 70 → 74 | 102k → 108k | 31.0 → 35.7 MB |
| Mall atrium | 77 → 81 | 165k → 171k | 37.7 → 42.4 MB |
| Provincial gym | 75 → 77 | 149k → 137k | 36.8 → 37.8 MB |
| Park court | 77 → 80 | 114k → 119k | 57.2 → 61.0 MB |
| Beach | 74 → 77 | 112k → 133k | 48.5 → 52.6 MB |

The draw calls added: the two substitutes and the line judges' flags (one each); the crowd's flags and cheers are
still a draw call each. The video memory: the crowd's sheet (three cheering frames for each of its people: 1440 x 2688
on Low, compressed, about 2.5 MB more), and the suits' mask. Two fixes on the way: each flag one mesh (from two), and
a model's copies drawn together when there are no shadows (Low and Medium): drawn apart, those that cast shadows from
those that don't, they had cost the mall five draw calls for nothing.

Tests: compile_check 52 scripts, 0 broken; test_runner 1549 checks, 0 failures (new: four officials, a line judge
stepping out of the ball's way and back, substitutes on both benches, the crowd's sheet and the teams' flags);
user_bot perfect 15-1, idle 3-15 (its points the other side's faults); input_test 10 checks, 0 failures.

## Settings > About: the licences, the help and the privacy policy in the game (0.12.1)

The three pages open over Settings, in the game itself (no internet: the app has no internet permission), scroll,
and have a back button; each in the player's language, at every graphics level and screen size.
- **Licences** (`ui/licences_screen.gd`): the game's credits (the players, ball and venues; CMU and Mixamo motion
  capture; Meshy; Poly Haven; every sound's source, author and licence: Mixkit, Gregor Quendel, JC Sounds, congusbongus,
  the Blender Foundation, the Pixabay whistles, Kenney and the other CC0 authors), the fonts' licence (OFL), the Godot
  Engine's MIT licence and every third-party part the engine names (`Engine.get_copyright_info`,
  `Engine.get_license_info`).
- **Help** (`ui/doc_screen.gd`): playing, serving, attacking; the rules in brief (three touches, scoring, faults: How
  to Play's own text); a slow phone, and what each graphics level and the battery saver do (new); the buttons; how to
  report a bug (by email, with the phone's model) and the "Email us" button.
- **Privacy policy**: no personal data, no account, server, analytics, ads or purchases; no internet permission;
  vibration the only permission; what stays on the phone; children; changes; the date and a contact.
- `test_runner` opens each page in English, Thai, Japanese and Burmese: words on it, no raw keys, a way back; the
  licences name the engine and each source; the help has the rules and the graphics levels.
- The web copies (`takraw-smash/privacy.html`, `support.html`) are served by GitHub Pages from `main`, so they return
  404 until this branch is merged. Until then the policy loads from `takraw-smash/PRIVACY.md` on GitHub (HTTP 200,
  store/PLAY_STORE.md). The game links to no web page.

## Walking, not gliding; every venue from every camera (0.12.2)

The owner: "When the player goes to get the ball he glides back for the most part instead of walking", and "park court
is missing assets on one side. Noticeable when changing camera. Might be a problem. On other maps too."

**Walking between points** (`Player.stroll`, set by the match in the set-up, after a point and at a break):
- A player always faced the net (turned a little to the ball), even walking several metres back to his place, so he
  moved backwards while his legs ran forwards: a glide. Now, between points, he turns to where he is going and walks
  there, and turns to the net again for his last half metre. He walks back to his place (about 2.2 m/s) and jogs to
  fetch the ball (2.6 m/s), slowing sooner as he arrives; before, all of it at a run (4.2 m/s).
- Stepping backwards at any time (backpedalling in a rally, the last steps into his place) plays the stride backwards,
  so his feet step back too.
- Measured over a set's set-ups: of the frames a player moves in, he faces where he goes in 76% (regu) and 85%
  (doubles), from 58%; the rest are his slow last steps (under 1 m/s) as he turns into place. A set-up still takes
  about 4 s.

**Every venue from every camera:** each was rendered from the broadcast, side and end cameras (from both ends) and
from the replay's low angle looking back at the near side, on High and Low.
- **The park's near side** (behind the broadcast camera) was bare grass out to the trees, plain from the end camera
  and the replays. It has what the far side has now: benches along it with people on them and more standing behind
  (low enough for the broadcast and side cameras to see the court over them), the path with its lamps, a food cart and
  scooters, trees, and shophouses and apartment blocks past them. The ball now bounces back off the benches' line.
- **The beach's islands, headlands and hills were inside out** (their faces wound the wrong way for the renderer, so
  only their insides showed): from the replay and end cameras the hills inland were black shapes. Turned the right way
  out, and hazed blue-green with the distance, against the low sun.
- The National Arena, the mall and the gym are dressed all round already.

Performance on Low (`perf_probe`): the park 80 → 78 draw calls, 61.0 → 61.5 MB; the beach 77 → 75 draw calls.
Tests: test_runner 1615 checks, 0 failures; user_bot perfect 15-1, idle 3-15; input_test 10 checks, 0 failures.

## Ready for Play, and a media kit (0.12.3)

For the owner's Play submission (the lead's checklist) and the owner's website, and two bugs in the game that the media
kit's captures showed.

**The build, checked** (every Play bundle checks it again, `.github/workflows/takraw-play-bundle.yml`):
- Target API 36 (Android 16), minimum 24 (Android 7.0); 64-bit ARM (arm64-v8a).
- 16 KB pages: both native libraries (`libgodot_android.so`, `libc++_shared.so`) have LOAD alignment 0x4000
  (`tools/check_pages.py`).
- The bundle: 116.3 MB (Play's limit for the base module is 200 MB, compressed), so no Play Asset Delivery needed.
- Permissions: `VIBRATE` only. No `INTERNET`. The bundle workflow now fails on any other permission (it only ruled out
  `INTERNET` before), and on a target other than API 36 or a version code other than the preset's.
- Version code 19, rising with every version; application id `com.takrawsmash.game` (the same as Obtainium's entry in
  the shared assets; it stays, since Play never lets it change, and changing it now would stop the beta updating in
  place).
- Signing: Play App Signing with an upload key the owner makes (store/PLAY_STORE.md step 2: the `keytool` command and
  the three secrets `ANDROID_UPLOAD_KEYSTORE_BASE64`, `ANDROID_UPLOAD_KEY_ALIAS`, `ANDROID_UPLOAD_KEY_PASSWORD`, which
  the bundle workflow uses when they are there). The beta key stays as it is, for the beta APKs only.

**Two bugs, found in the captures of the menus:**
- **The joystick and the match buttons showed over the pause menu and its Settings**, and, since they read touches
  before the menus do, a tap on a setting that lay under a button went to the button (ignored, the match being paused)
  and not to the setting. They are hidden while the pause menu is open (as in a replay), and a thumb held on the
  joystick as the menu opens no longer holds it after. test_runner checks both ways.
- **The language picker's "Bahasa Melayu" and "Bahasa Indonesia" ran out of their tiles** into the next ones on a 16:9
  screen. The tiles are wider and a long name shrinks to fit (to 75%, then "…"). The fit audit (`tests/fit_audit.gd`)
  now reports words that run out of their button (which does not clip them, so it missed these); every screen in the 13
  languages at the three phone shapes is clean.

**The soak test** (`tests/soak_test.gd`, run by `tools/soak.sh [events] [matches]`, on a desktop with software OpenGL):
a monkey of random input on every screen (taps on whatever buttons show, taps anywhere, drags, the phone's Back on
every screen but the home one, the app paused and resumed, which must keep a match paused and as it was), then AI-v-AI
matches played to the end, alternating Low and High, through the five venues and the four events. It reports the
slowest frames and where, memory as it goes, and any match that stops getting on with it; any script or engine error
fails it. The settings, saves and records are put back at the end.
- Memory: up from 191 MB after 500 events to 300 MB after 2,500, the climb slowing. Not a leak: the same match started
  and left fifteen times holds at 144 MB, the same objects and nodes each time and no orphans, and going through the
  five venues levels off at 155-161 MB. The rest is what the monkey loads once and keeps: the venues at each graphics
  level, and each language's fonts as it changes languages.

**The store kit** (`store/`, drafts until submission):
- The listing in all thirteen languages (`store/listing/`): the eight new ones Lao, Burmese, Khmer, Filipino, Japanese,
  Korean, Chinese and Hindi; each within Play's limits (name 22 of 30 characters, short description at most 80, full at
  most 4000), and honest (invented clubs, offline, no ads, no data).
- Eight screenshots and the feature graphic remade from the current build: `tools/store/store_shots.tscn` now finds each
  moment by playing its match on within a frame (tools/media/trailer.gd), so it takes minutes, not most of an hour;
  `tools/store/make_feature.py` crops the feature graphic (its lines now "Sepak takraw for Android" and "Five venues.
  Thirteen languages.": no "real players", which the players are not).
- `store/PLAY_CONSOLE_ANSWERS.md`: the Data safety form (no data collected or shared), the IARC questionnaire (expected
  PEGI 3 / ESRB Everyone), target audience (13+, and why not the Families programme), ads (no), purchases (none),
  category (Sports), tags, contact, the privacy policy's address (TBD: the owner's site), and the first release's notes.

**The media kit** (`tools/media/make_media_kit.sh`, and the "Sepak Takraw Unleashed · Media kit" workflow, which makes
it and publishes it as the release `sepak-takraw-unleashed-media`):
- Every menu screen (`menus/`): 25 PNGs, 1920 × 1080, in English, named by screen (the loading screen, the home screen
  and its language picker, Quick Match, League Season and International new and under way, Records, Settings, How to
  Play's three tabs, Help, the privacy policy, the licences, a match, its pause menu and Settings, a result), and for
  each that scrolls its last part too.
- The website's copy (`text/`): about, features, facts (the version and download size filled in), the sport, and a press
  blurb.
- Screenshots: ten 1920 × 1080 PNGs from the game on High: a roll spike that scores (National Arena), a serve (beach), a
  block (mall), a doubles rally (park), a kill (gym), a celebration, and the home screen, a league season, the World
  Championship and How to Play. The game is landscape only, so no portrait ones.
- Icons: 1024 and 512 px, and the feature graphic.
- The trailer, about 34 s, 1920 × 1080 at 30 fps, H.264 with AAC: a title card, six moments from real AI-v-AI matches in
  the five venues with captions over them, and an end card ("Coming soon to Google Play"). Filmed with Godot's Movie
  Maker (`tools/media/trailer.gd`) at the window size an `override.cfg` sets for the run (Movie Maker films at the
  project's 1280 × 720 otherwise, whatever `--resolution` says): each moment is found by playing its match on unseen
  within one frame, then the same match (the same seed) is played again to a little before it and filmed; the game's own
  sound, the menu music under it. The mall's chatter (CC BY-SA) is silenced in its shot so the trailer carries no
  share-alike sound. A 15-second vertical cut (1080 × 1920) from three of the moments.
- `CREDITS.txt`: every sound and piece in it, under its licence.
- The workflow checks what it made before publishing it: both videos H.264 + AAC at 30 fps, at their sizes, the trailer
  30-45 s and the cut at most 15 s, each under 60 MB, and every PNG 1920 × 1080.

Tests: test_runner 1619 checks, 0 failures (new: the controls hidden under the pause menu and its Settings, and back
after); fit_audit 0 problems (13 languages, three phone shapes, every part); user_bot perfect 15-1, idle 3-15;
input_test 10 checks, 0 failures; compile_check 53 scripts, 0 broken.

## Gaps that need the owner

For the Play Store, what only the owner can do is in `store/PLAY_STORE.md`: the developer account, the upload key and
its three secrets, the privacy policy's address on the owner's site, the closed test with 12 testers, and a last read
of the listing drafts (a native speaker's, for the twelve translations).

In the game, none. The two raised in 0.5.0 are filled in 0.5.1:
- The shophouse row, at the night market and the park.
- Apartment blocks with lit windows.

The shophouse model has a passer-by fused into its pavement: behind the stalls, or 45 m off at the park, it reads as
background life.
