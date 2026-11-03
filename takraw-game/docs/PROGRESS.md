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
matches played to the end, alternating Low and High, through the five venues and the events. It reports the slowest
frames and where, memory as it goes, and any match that stops getting on with it; any script or engine error fails it.
The settings, saves and records are put back at the end.
- **The monkey, 5,000 events** (2,724 taps on buttons, 669 taps anywhere, 534 drags, 415 Backs, 253 pauses and
  resumes of the app, 331 waits), over every screen and into matches: no script or engine error, no match lost or
  changed by a pause.
- **Memory** went from 191 MB after 500 events to 300 MB after 2,500 and 317 MB after 5,000, levelling off. Not a leak:
  the same match started and left fifteen times holds at 144 MB, the same objects and nodes each time and no orphans,
  and going through the five venues levels off at 155-161 MB. The rest is what the monkey loads once and keeps: the
  venues at each graphics level, and each language's fonts as it changes languages.
- **Twelve AI-v-AI matches** (a set to 15 each), Low and High in turn, regu, doubles and quadrant, through the five
  venues: every one played to a legal end (15-9, 15-2, 15-9, 12-15, 15-11, 15-10, 8-15, 14-16, 12-15, 10-15, 15-10,
  13-15) in 3.3 to 6.6 match minutes, none stalled; slowest frame 272 ms. `soak: clean`. They run headless (`soak.sh 0
  12`): software OpenGL draws a match at about a frame a second, so a whole one would take hours; the monkey's
  matches are drawn.

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
- The trailer, 33.7 s, 1920 × 1080 at 30 fps, H.264 with AAC (36.5 MB): a title card, six moments from real AI-v-AI matches in
  the five venues with captions over them, and an end card ("Coming soon to Google Play"). Filmed with Godot's Movie
  Maker (`tools/media/trailer.gd`) at the window size an `override.cfg` sets for the run (Movie Maker films at the
  project's 1280 × 720 otherwise, whatever `--resolution` says): each moment is found by playing its match on unseen
  within one frame, then the same match (the same seed) is played again to a little before it and filmed; the game's own
  sound, the menu music under it. The mall's chatter (CC BY-SA) is silenced in its shot so the trailer carries no
  share-alike sound. A 15-second vertical cut (1080 × 1920, 15.5 MB) from three of the moments, its camera wide of the
  assistant referee and its captions broken by hand. Both at most 10 Mbit/s: the crowds take twice that at the same
  quality, which would have put the trailer near 100 MB.
- `CREDITS.txt`: every sound and piece in it, under its licence.
- The zip: 79.2 MB, at
  https://github.com/joshnason8-lab/ghost-kit-pages/releases/download/sepak-takraw-unleashed-media/media-kit-sepak-takraw-unleashed.zip
  (a prerelease, never marked latest).
- The workflow checks what it made before publishing it: both videos H.264 + AAC at 30 fps, at their sizes, the trailer
  30-45 s and the cut at most 15 s, each under 60 MB, and every PNG 1920 × 1080.

Tests: test_runner 1619 checks, 0 failures (new: the controls hidden under the pause menu and its Settings, and back
after); fit_audit 0 problems (13 languages, three phone shapes, every part); user_bot perfect 15-1, idle 3-15;
input_test 10 checks, 0 failures; compile_check 53 scripts, 0 broken.

## Back closes what is open first (0.12.4)

Found checking "Back on every screen" for Play: on the home screen with the language picker open, the phone's Back
closed the whole game (the home screen's Back leaves the game, and nothing caught it for the picker); with a team
picker's list open (Quick Match) or a question (League Season's "Abandon?"), it left the screen under it.
- `Game.go_back` closes an open list or question first; the home screen's `on_back` closes the picker, and leaves
  the game only with nothing open.
- test_runner presses Back on every screen: it leaves each of Quick Match, Settings, How to Play, Records, League
  Season, International, the licences and the help; it closes the picker, a team list and "Abandon?" (the season
  kept); in a match it pauses, closes the pause menu's Settings, and resumes. The soak presses Back on the home screen
  when the picker is open.

The build: 0.12.4-beta, version code 20; the bundle 116.3 MB, target API 36, `VIBRATE` only, both libraries 16 KB
aligned (the bundle workflow's checks); the APK 127.7 MB, signed with the beta key. Tests: test_runner 1633 checks,
0 failures (CI 1615, its matches ending differently); input_test 10 checks, 0 failures.

## The shared foundation, a pilot (0.12.4-pilot)

On Medium and High, in a match, with the licensed motion-capture library in the build (CI's licensed-assets step),
every player, official and substitute is drawn by the World Stage Games foundation (`addons/wsg_foundation`,
`game/foundation_link.gd`): the owner's man or woman baked onto the shared rig (`assets/foundation/`, from
`assets/models/*.glb` by `tools/wsg/bake_character.sh`), in RealBody's own kit and suit materials.
- **The game stays in charge of takraw.** RealBody is still posed and measured every frame, unseen; its 17-bone pose
  is laid exactly on the drawn body (WsgLegacyPose reading a 17-bone copy of it), for every action: the toss from both
  hands, the serve and the horse kick, the sila, the thigh, the chest, the header, the roll spike, the sunback, the
  tapak, the head spike, the block, the dig, picking the ball up, the celebrations. Measured over a match: the hips
  0.0 cm off the game's; at each contact the instep or the head within 1.7 cm of where the game's meets the ball.
  Timing is untouched: user_bot perfect 15-1 and idle 3-15 with the foundation on, the same rallies as before.
- **Motion capture only where the game walked by hand:** players walking between points (back to their places,
  fetching the ball, carrying it - the ball drawn in the drawn hands), turning and stopping on the capture's own
  clips, the feet planted (a planted foot moves at most 1.5 cm a frame); the assistant referee and the line judges
  standing, shifting and stepping out of the ball's way, their heads on the ball, the flag in the drawn fist, their
  signals the game's arms. The referee in his chair and the substitutes on the bench keep the game's poses;
  in a rally every player is the game's own.
- **Replays (Medium and High):** the game's own replay (0.4 speed, the low camera, a tap skips it) shows the
  foundation's bodies as they were drawn (WsgReplay, kept with the replay's frames). One a point at most, the best the
  point had: a horse-kick ace, a roll spike, a sunback, a head spike, a stuff block, a dig by the side that goes on to
  win the rally, an ace, a tapak dropping in, a rally of more than seven touches. The players are put back where they
  were after it.
- **Low is exactly as it was** (the Galaxy A16 starts there: `detect_graphics`): no links, no foundation replays, the
  game's replay rule; per venue the same draw calls, primitives, objects and video memory as 0.12.4 (perf_probe in a
  fresh process: 72-79 draw calls, 36.2-61.5 MB), the same picture. Dropped to Low mid-match, the game's bodies come
  back.
- **Lower the graphics by itself** is the foundation's WsgAutoTier: all match long while the ball is in play, two
  1.5 s windows in a row slow or hitching take a level off at once.
- Medium and High: the same draw calls as 0.12.4, about 42,000 fewer primitives (the baked bodies), 1.7-2.1 MB more
  video memory.
- Kept as they are: the crowd (the game's cut-outs, one draw call, watching the ball and waving both teams' flags;
  the foundation's 3D fans are Hurling's Irish crowd), and the venues' own lighting.
- CPU (`tests/foundation_cpu.tscn`, a desktop, headless, other work running): the foundation's own 1.7-2.2 ms a frame
  on Medium (its skeletons' modifiers 1.0-1.5 of it) and 2.2-2.5 on High, for 14 bodies; a frame 1.2 -> 3.8 ms on
  Medium, 1.5 -> 4.1 on High; Low 1.1 either way. Players are posed every frame within 12 m of the camera (16 on
  High) and whenever they play a move, every second frame beyond; the standing officials every second frame unless
  they step or signal; the referee and the substitutes every third.
- Size: the export grows by 11.9 MB (the licensed library 10.5, the foundation's code and the two baked bodies); the
  foundation's 3D crowd, which takraw does not use, is left out of the Android export. About 140 MB for the APK.
- Tools: `tests/foundation_view.tscn` (comparison stills, either build), `tests/foundation_cpu.tscn` (CPU a frame by
  level, with and without the foundation). test_runner checks all of the above with the licensed data (1658 checks)
  and without it (1647); user_bot perfect 15-1, idle 3-15 either way; input_test 10 checks; fit_audit 0 problems.

## The foundation, merged (0.13.0)

The pilot above, merged into the game's branch (PR #16) and published as the beta, version code 22 (above the pilot's
21, so it installs over either). The Play bundle and the media kit now bake the licensed animation as the beta does
(the same step), so the Play build is the beta's game and the trailer shows the foundation on High; the licences
screen's credit for MoCap Online and Reallusion ActorCore (the owner approved it) is checked by test_runner, and the
media kit's CREDITS.txt carries it. test_runner 1649 checks, 0 failures (without the licensed data, here).

## The serve's toss: the ball outside the thrower (0.13.1)

The owner, playing the pilot on the Galaxy A16 (Low): "When the guy is tossing the ball to start a serve, when he winds
up the ball goes into his body; it looks bad." The ball is held between the thrower's palms; in the toss's wind-up
(`Moves` "toss", the key at 0.3) both arms swung to 14 degrees behind the chest's line, and the chest leans 20 degrees
forward there, so the hands went back to his sides and the point between them passed through his belly and hips:
measured, 4-9 cm inside the torso and up to 12 cm inside a thigh, 0.2 s into the toss, men and women, regu and
doubles. Now the arms swing down in front (48 degrees ahead of the chest's line, the forearms nearly straight, the
hands together), so the ball is lowered in front of his knees and swung up and out to the server: through the whole
toss it stays at least 14 cm clear of his torso and 17 cm of his thighs, 0.38-0.55 m in front of his hips. The
release, the throw and their timing are as they were. On Medium and High the shared rig is posed from the same pose,
and the ball drawn between its hands, so the same holds there.
- test_runner (`_serve_toss_clear`): every frame the thrower holds the ball, where the match has it and where it is
  drawn, outside his torso, head, thigh and shin capsules; after the release, outside the server's torso and head;
  Low and High, men and women, regu and doubles. Against 0.13.0's pose it fails (5-8.5 cm inside); now it passes.
- Stills: `docs/stills/serve_toss_before_after_men.jpg` and `_women.jpg` (Low, from the side, 0 to 0.6 s into the
  toss), made by `tests/toss_stills.tscn`.

## Watch AI (0.14.0)

The owner's request for every game: a home-screen entry to watch a whole AI-v-AI match.
- **Watch AI** joins How to Play, Settings and Records on the home screen. It opens Quick Match's screen set up to
  watch (`quick_setup.gd`, `{"watch": true}`): its title, a line saying what it is, Team A and Team B (countries, or a
  league's clubs; men or women), the event, the length, the set's points and the venue; no difficulty (the computer
  plays both sides at Star) and no side of yours. Watch starts the match (`mode` "watch", `user_team` -1).
- The match: from the broadcast camera (the pause menu's Camera still changes it), the scoreboard, the referee's calls,
  the replays of the best moments (the game's on Low, the foundation's on Medium and High), no touch controls. A 1×/2×
  button beside the camera and pause buttons doubles the match's clock (a replay keeps its own pace); pause, or the
  phone's Back, pauses; the pause menu's Quit match goes home. At the end the result says "Match over" (no victory or
  defeat), Rematch plays it again; it does not count in the records.
- Seven new strings (`MENU_WATCH`, `WATCH`, `WATCH_NOTE`, `TEAM_A`, `TEAM_B`, `MATCH_OVER`, `WATCH_SPEED`) in all 13
  languages. The foundation's WsgSpectator (a rail camera, a director, its own replays and speed) is there to adopt
  later; this one is built from the game's own camera, replays and HUD, so Low is unchanged.
- test_runner (`_watch_ai`): the home screen's entry opens it; its setup in all 13 languages (its words, Team A and B,
  no difficulty, nothing raw); the match nobody plays, broadcast camera, score up, no controls; 2× and back; Back
  pauses and resumes; replays; played to the end; "Match over"; records untouched; Quit goes home. fit_audit has the
  setup, the match at 2× and the result; the media kit's `menus/` has its screen.

## Low's officials on the shared planter; publishing in place (0.15.15)

- **Foundation d70ac7d -> 70e571a** (REQUIRED 7def933a from 2026-11-06 12:00 UTC): the planter under game AI - a foot
  let go rising over its whole ease, plants landing on the frame they are read down, a foot left far behind a fast
  stop stepping; WsgFootPlanter.bone_prefix and contact_fn; WsgSim ending a run where a game gives no feet (our Low
  replay); ADOPTING 5.19 publishing in place.
- **Low, measured again on it** (the same seeded regu, 2 x 150 s, feet as drawn), players:

  | Low | glide share | flat skids over 2 cm | step slip p90 | jumps over 25 cm |
  |---|---|---|---|---|
  | RealBody._planted (0.15.14) | 14% | 11 | 2.3 cm | 9 |
  | WsgFootPlanter, its own gate | 17% | 1032 | 9.7 cm | 15 |
  | WsgFootPlanter, our contact rule, planting off in the air | 9% | 79 | 4.2 cm | 2 |

  The last glides least in play, but on the world check's walker (feet_low) its planted feet slid 3.2-7.5 cm a step
  walking, running and stopping (the bound 2; ours 1.8 at most): **the players keep RealBody._planted**.
- **The standing officials plant with the shared planter on Low** (RealBody._foundation_plant: WsgFootPlanter on our
  skeleton, bone_prefix "mixamorig_", _planted's own contact rule, planting off in the air; their feet read as drawn,
  in skeleton_updated). Their flat feet sliding over 2 cm in a frame 32 -> 3 (worst 40.8 -> 12.5 cm), the planted
  step's slip (90th percentile) 8.3 -> 4.7 cm, jumps over 25 cm 1; CPU the same.
- **WsgSim's deferrals, split by level** (game/sim.gd, the lead, 2026-11-03): on Low, our own bodies, every foot check
  until 2026-11-08 12:00 UTC with feet_low; on Medium and High, the foundation's bodies, every foot check until
  2026-11-06 12:00 UTC, then a planted foot's slide up to 7.5 cm only until 2026-11-13 12:00 UTC (jumps and skids
  enforced). Kabaddi's setup tried on our Low players (WsgFootPlanter, its own contact gate, our planting off) failed
  feet_low (planted slips 2.2-5.2 cm walking to stopping, skids 2.5-3.5): they stay on RealBody._planted until the
  Foundation's slide fix.
- **Publishing in place** (takraw-android.yml, ADOPTING 5.19): the workflow token is refused new tag names since
  2026-11-03 about 17:00, so the release on the beta's tag is updated where it stands - the new APK up beside the old,
  then the old off, then the title and notes, which carry "Commit: <sha>"; the release gate skips comparing a build
  with the published one when the notes name its own commit (the pull request's run and the push's race).

## The foundation's 11-06 feet batch, and Low measured (0.15.14)

- **Foundation 3b3563f -> d70ac7d** (REQUIRED 41c84347 from 2026-11-06 12:00 UTC). The 11-06 feet batch: a body
  posed every 2nd or 3rd frame read per frame, a planter reset read as a cut, the skid counted only on a held foot; the
  planter's own step crossing an even share a frame, and a foot let go lifting from its first frame (Medium and High:
  the 7.3 cm flat move as a player pulled up). And Low: WsgFootPlanter.bone_map, WsgWorldGame.walker_low() and the
  world check's feet_low rule, WsgSim's "feet" for a body the game draws itself.
- **walker_low()** (game/world.gd): a Player's own RealBody, driven a frame at a time as play poses it
  (Player.step_for_check: his stride for how he goes, his turn - Player.tick's pose is now its own _pose, and its turn
  _turn_to), its feet as drawn (RealBody.feet()). feet_low on it: every segment of the match path within the bounds
  (worst slip 1.8 cm walking - a warning, 0.2 cm from the bound; skid 0.8 cm; jump 9.7 cm).
- **WsgSim reads the Low bodies' feet** (game/sim.gd: "feet" for every player and standing official the game draws
  itself; none in the game's own replay, which puts every body back where the rally began and then where it was).
- **WsgFootPlanter on the Low bodies, measured again on this batch** against 0.15.13's own planter (the same seeded
  regu, 2 x 150 s): glide share 20% against 14%, flat-foot skids over 2 cm 1556 against 11, the planted step's slip
  (90th percentile) 9.2 cm against 2.3, jumps over 25 cm 7 against 9. Low keeps its own planter; the Foundation has
  the flat let-go.
- **The WsgSim foot-slip deferral stays** (until 2026-11-06 12:00 UTC, the lead's): with it dropped, a smoke on this
  batch still fails foot slip on Medium and High (the foundation's bodies) - officials' planted feet sliding 2.2-6.9 cm
  a step and jumping 26-47 cm in a frame, players' 3.3-6.3 cm and 25.1. Sent to the Foundation and the lead.
- **Low's officials step every frame.** Read for the first time, the standing officials' feet on Low jumped 48-79 cm
  in a frame as they stepped out of the ball's way: Low posed them every second frame, so a step moved two frames'
  worth at a time, 15 times a second. Now one stepping (or going back to his place) is posed every frame, one standing
  still every second frame as before (Officials._stepping). The same seeded regu, 2 x 150 s: officials' jumps over
  25 cm 94 -> 1 (worst 79 -> 27 cm), over 15.4 cm 163 -> 6; CPU the same. Their planted step's slip (90th percentile
  about 8 cm) is next.

## On Low, a foot steps instead of jumping (0.15.13)

The owner, playing on Low (the Galaxy A16): players still glide getting into position to spike or block, going for
the ball, and in the blocker's folded crouch. On Low the players are the game's own bodies, and their feet are kept
on the floor by RealBody's own planter (`_planted`): a foot down is held where it landed (two-bone IK) until it
lifts. But when he had moved PLANT_REACH (32 cm) past it, it was put down again where his stride had it, in a single
frame. In a seeded regu, read from the drawn feet frame by frame, that came to 456 jumps of a low foot over 25 cm
(WsgNoteChecks.foot_slip's jump_cm, up to 68 cm) in five minutes of play.

Three ways for Low were measured (2 x 150 s of a seeded regu, every player; CPU a desktop headless):

| Low | a frame | glide share | jumps over 25 cm |
|---|---|---|---|
| RealBody's planter (0.15.12) | 1.9-2.0 ms | 10% | 456 |
| the foundation's bodies on Low (FoundationLink) | 3.2-3.5 ms | 35% | 679 |
| the foundation's WsgFootPlanter on RealBody's skeleton | 1.6 ms | 19% | 6 |

(Glide share: of the distance players moved at 0.5 m/s or more with a foot on the floor in both frames, how much
with that foot sliding faster than half his speed.) The foundation's bodies are worse on Low as they run today, and
cost about +4-6 ms a frame on an A16. Its planter on our skeleton (a subclass naming our bones) costs nothing and
ends the jumps, but slides more: a foot it lets go of while still flat eases back to the stride's along the floor.
The Foundation has that, and a bone map for its planter, to take further; until then:

- **A foot stretched to PLANT_REACH steps** (STEP_TIME 0.2 s): up (STEP_LIFT 10 cm), across onto his stride's foot by
  0.7 of the step, then straight down, never further from the stride's foot than STEP_REACH (45 cm) on the way
  (further, the IK threw the leg back) or LAND_REACH (16 cm) coming down. A step the stride lifts the foot in the
  middle of is finished, as high as the stride has it.
- **Slowly** (under 1 m/s: a blocker in his crouch edging along the net, a stance under a move whose legs stand
  still), he shuffles: SHUFFLE_REACH 16 cm, a foot at a time.
- A foot let go is the stride's own by the time it is EASE_HIGH (30 cm) up: a correction still easing out on a leg a
  move raises (a blocker's) threw it 0.67 m in a frame (the jitter test).
- Put somewhere new (a restart), his feet go with him; the planter now steps on the match's own time step.

After, the same matches: **9 jumps over 25 cm** (from 456; worst 38 cm from 68), the planted step's slip the same
(90th percentile 2.3 cm), CPU the same. The glide share goes from 10% to 14% (from 51 to 63 m of 734 m moved): a
foot in the first and last frames of its step, and a foot let go, count while they are within 3 cm of the floor. The
snap itself had counted too, but only once per re-plant. test_runner pins it: on Low, a minute of a regu, at most 10
jumps over 25 cm (1 now, worst 28 cm; 129 before, worst 64 cm). The jitter test (every hand, foot and head under 0.85 m/frame^2)
passes on Low and High.

## What the first full WsgSim smoke found (0.15.9)

The first smoke batch to finish in CI (on 0.15.8, 65 matches) failed 31. Every failure was traced frame by frame:
- **The ball through the LED boards and the park's fence (Low): two real bugs, fixed in `game/ball.gd`.**
  - A loose ball that flew over a low board at an end of the hall was snapped back in front of it, through it, once it
    came down under 0.5 m (the walls' clamp). It now stays behind it and comes off the board's back.
  - A fast ball coming down at the court's edge was put on the floor where its flight would have it a frame later,
    under the floor and past the end fence (the prop sweep missed it, the way being under the floor). It now lands
    where its path meets the floor, and the sweep sees the fence first. The line calls are unchanged: they use the
    flight's own landing (`Match.land_t`, `Ball.at`).
  - (0.15.10) 0.15.9 first kept a ball that had gone over the line behind it by a rule of its own, which assumed the
    board stands on the line: at the park the fence is 10 cm past it, and a ball flying at it at 0.5 m was put into it
    and stuck there (smoke, extreme 36). The rule is now simply: a low ball past the ends' line is put back to it only
    if `WsgSolidProps.sweep` finds no prop on the way; otherwise it is behind a board or the fence, and the prop's own
    back stops it.
  - (0.15.10) The ball between the corner TV tripod and the end wall at 15 m/s bounced off the wall inside one frame:
    its four small steps stayed outside the tripod, but the straight line between the frames cut 2.3 cm into it. The
    ball now keeps its frame's path (`Ball.path`: each small step and each prop it met), and the adapter hands it to
    the audit, which sweeps every step (the Foundation's 73abc13).
- **The score went down (6 matches): the game's video review.** An overturned line call moves the point to the other
  side. The adapter now counts a line-call point only once it can no longer be challenged, so the score it reports
  only goes up (the Foundation agrees; no looser check).
- **An A-pose (9 matches): the chest trap**, arms held straight out at 44 degrees. Its elbows now bend and its arms
  draw back (`Moves`, "chest").
- **Officials' feet sliding 10-16 cm (15 matches): the slow-motion replay.** During a replay the foundation's
  WsgReplay sets every bone, but the foot planters stayed on, so a foot swinging at 0.4 times its speed read as a
  planted foot sliding. The planters are now off while a replay plays (`Match._start_replay`), and the Foundation's
  WsgSim no longer measures feet during a replay, for every game (284bef5).
- **Players' feet sliding 2.5-4.4 cm (Medium and High)**: walking briskly with the ball (2.2 m/s), mostly as they come
  out of a pick-up into the carry walk. These are the shared locomotor's and planter's feet: deferred with the lead's
  word until 2026-11-06 12:00 UTC (`game/sim.gd deferred()`), reported under Warnings until then; the frame data went
  to the Foundation.

## Thousands of simulated matches: WsgSim (ADOPTING §5.17)

`game/sim.gd` is the game's adapter to the shared simulator. Its matches are built by `Game.start_match`, as a Start
tap builds them, and played by the game's own code: the AI, the ball, the rules, the officials and the props. They run
headless at 30 frames a second, each from a seed.
- **Every random roll from the seed** (`tools/wsg/rng_lint.sh`): the players' breath and weight shifts now come from
  their own generator, seeded from the match's seed (the hand that holds the ball moves with them). So does the
  camera's shake, because the stick's way is read from the camera. Both are seeded without drawing on the match's own
  generator, so every match plays its rallies exactly as before. The tournament draw's shuffle now uses the cup's
  generator. The ball's spin is drawn only (`# wsg-rng-ok`).
- The game's own numbers-only results simulator moved from `game/sim.gd` to `game/score_sim.gd`; its class name, Sim,
  is unchanged.
- **Kinds:** random, extreme (the strongest against the weakest, best of three to 21, the hardest and easiest AI),
  and four targeted kinds:
  - scoring: close sides, a set to 15 (deuce and the cap);
  - collisions: the venues with the most props, quadrant;
  - completion: best of three to 21;
  - human: a person's side.
- A person's side, when the input fuzzer plays it, goes through the game's own controls: the touch stick, the three
  buttons (as their keys press them), and the phone's Back (the pause menu).
- **The score** is the points won over every set, so it never goes down at a new set. **The rules** checked every
  frame: three touches a side at most, a set's points never past the cap, every set won a legal score, and each side's
  players on court.
- **The ball** is in play when it flies or rolls loose, but not in a replay. A replay moves it along the rally's path
  again from the start; counting that showed as a ball through a bench and a net post (two smoke seeds, gone on
  replay).
- **Speed:** 12-14 times real time per process here (a one-set match in 25-50 s).
- **CI:** `.github/workflows/takraw-sim.yml` runs on every push: the RNG lint, determinism, and the smoke batch with
  the input fuzzer as four shards side by side. Every night it runs 2,400 matches over 16 jobs and merges them into
  one report.

## The owner's notes, kept as tests for good (ADOPTING §5.16)

The owner: "the regressions are getting worse." So every remark of theirs that can be measured is now a test in
`tests/owner_notes/`, one script each. Each carries the owner's own words, the date, and the beta they were on.
`INDEX.json` lists every note, and none may ever be removed. Each note measures the very symptom the owner saw, over its
whole range. The notes share setup in `tests/takraw_note.gd` (`TakrawNote`): a match built as the game builds it,
played at 30 frames a second, its cameras, and the venues. The gliding notes share one measurement (GlideProbe).

The 27 notes, from the transcript of the owner's messages:
- **2026-10-21** (0.1.0-0.2.0): no training, no time-outs, no player names.
- **2026-10-22** (0.3.0): no numbers over the players.
- **2026-10-24** (0.5.2): the ball turns in the air.
- **2026-10-25** (0.9.1): the fans face the play; the seated referee's arms are relaxed (at most 11-17 degrees out
  from hanging, Low and High); no dots in the score.
- **2026-10-26** (0.11.1):
  - the ball never hangs in the air, after points or ever, at every venue;
  - an ace comes back off the walls;
  - four officials (the line judges standing at the ends, stepping out of a ball's way);
  - substitutes sitting on the benches;
  - the crowd's flags are the two sides';
  - players move while they wait for the serve;
  - the removed venues are gone.
- **2026-10-27** (0.12.1): no gliding when fetching the ball.
- **2026-11-02** (0.14.1-0.14.3):
  - the serve's throw in ONE hand, outside the thrower's torso, Low and High (the foundation's
    `body.torso_capsule()`);
  - no gliding back to his place;
  - an official backing away steps back;
  - spikes slow enough to see (the fastest of 40: 20.9 m/s);
  - the joystick the camera's way on every camera, at every venue.
- **2026-11-03** (0.15.1-0.15.3):
  - no gliding into position to spike or block, or getting to the ball;
  - the blocker upright on his way along the net (hips at least 91% of standing);
  - the loading overlay up in the tap's frame on every way into a match;
  - props solid at every venue.

All 27 pass, with the licensed library, in about 8 minutes. CI runs `owner_notes_guard.sh` and then
`WSG_NOTES_STRICT=1 ... -s res://tools/wsg/owner_notes.gd`.

## The world rules, and the ball behind the bench (0.15.5)

Foundation synced to 15abaa3. It brings the world rules check's tiers rule and its screen-true joystick reference,
the prop audit's seated bodies, the release gate (§5.19), WsgAssetPack, and WsgAutoTier standing down in the sim and
the world check.

### The ball behind the bench
0.15.4 could stop a match for good. BOT_SEED 6 found it (the perfect bot: no result in 15 minutes).
- A ball came to rest behind a team bench, 0.6 m in from its end.
- The fetcher walked up and down in front of the bench and never got round it. Player.tick was steering the
  velocity he already had (`solid.move`), and his acceleration kept pulling that back toward the bench between him
  and the ball. This is the pitfall ADOPTING's solid-props notes describe.
- After 14 s the thrower was given the ball, but nothing sent him to his place, so the serve never came.

The fixes:
- Players and standing officials now steer the way they want to go round the props first (`solid.steer`, which
  keeps to one side of a long bench), then take up their pace toward it, then step and are pushed out of contact
  (`solid.push_out`).
- The 14 s fallback sends the thrower to his place with the ball.
- test_runner places a ball behind the National Arena's bench. It is picked up round the bench in 4.4 s, 0 cm into
  it, and the fallback sends the thrower home. This test fails on 0.15.4.
- The perfect bot plays seeds 1-6 to the same results as before props (points conceded 4, 3, 10, 3, 3, 7).

### The world rules (ADOPTING §5.18)
`game/world.gd` wires every rule of the shared world check (`tools/wsg/world_check.gd`) to the game's own code:
- **modes:** quick match, Watch AI, season and international, each started from its own screen's Play button, as
  the player's tap does.
- **officials:** the referee and the assistant referee, and two line judges. FoundationLink puts each official's
  drawn body in the group `wsg_official`.
- **feet:** a player as he walks between points, the foundation's man at the scale the link draws him
  (`FoundationLink.free_scale`).
- **sounds:** the kick, bounce, net and whistle.
- **joystick:** the match's own stick mapping, now `CameraRig.stick_world` (static, for any camera). Match._cam_dir
  calls it, and the world check calls it on the broadcast, side-on and end cameras.
- **props and crowd:** the existing registries.
- **tiers:** the graphics level set as the Settings screen sets it.

The joystick rule first failed the game's mapping on the diagonals (33-40 degrees). The mapping follows the screen
where the player is drawn, which was the lead's 0.14.4 change. The check's references were the camera's flat floor
diagonals, which the picture foreshortens. Measured: the game's mapping is within 0.3 degrees of the screen-true way
on all 3 cameras x 9 spots x 8 sticks. The foundation added the screen-true way as a reference (15abaa3).

CI runs the world check in place of the prop audit step, with the props at 45 s a venue (the owner's props note plays 40 s more at each). It uploads
WORLD_CHECK.md and the audits' sheets. A failing rule fails the build from 2026-11-03 12:00 UTC; the props fail it now,
as before.

The pose rule found a real fault. On Medium and High, every body the foundation draws (players, substitutes,
officials) was hidden until the match's first frame of play. So the loading overlay came down on a court with nobody
on it for one frame, and the warm-up never drew those bodies, leaving their skinned look to be made in play. Each is
now posed once as it is built, behind the overlay (Match.build_people), so all 14 are drawn on the frame the overlay
comes down.

### Loading
Starting a match on High, the Players step held the main thread 0.5 s (on this machine's software renderer). It now
yields between the teams, the officials and the bench (`ld.checkpoint`).

## Solid props, and loading v2 (0.15.4)

Foundation synced to 07864d7 (every required commit: loading v2, solid props, the warm-up fix, key hits, the
foundation's planted-feet fix 1ef240f for the bodies it draws on Medium and High; its check_foundation.sh now fails CI
without them).
- **Solid props** (the owner, for every game: "There will NEVER be a time when a player or referee should walk
  through a table or bench etc. A ball should also bounce off these items."): measured first (an AI match at each
  venue): players walked through the benches, the scorers' table, the referee's chair, the net posts and pads and the
  ball stand everywhere but the beach; the ball went through the table (at the park, coming to rest inside it), the
  benches, the tripods and the chair. Now every venue's props are the shared WsgSolidProps (`Arena.solid`),
  registered where each is built: the referee's chair, the scorers' table, the benches, the net posts (and pads,
  bases), the ball stand, the TV tripods, the scoreboard, the jury tables and chairs, the LED boards, the stands'
  first steps, the gym's wall mats, backboards and rings, the park's floodlight poles and chain-link fence, the
  beach's flag and umbrella poles, the trees' trunks, and the scenery's models within reach of the play (benches,
  bleachers, planters, loungers, carts, the bar) as boxes round them. The players and the officials on their feet
  step through `solid.move` (steered round, never in; a target in one moved beside it); the ball through
  `solid.sweep`/`bounce` (at any speed); a ball in play that hits a prop ends the rally there, out. The floor and the
  net stay the game's own (skipped, with the reason). `game/prop_runs.gd` plays a Watch-AI match at each venue for
  the shared audit (`tools/wsg/prop_audit.gd`, now in CI): every venue PASS, 32,400 body-frames each with nobody
  inside a prop, 2,700-2,850 ball steps each with none through one. test_runner: each venue's props, the wiring, a
  ball at the table coming back off it.
- Found by the suite on the way: a turn now builds up (80 rad/s^2, a move's three times as fast) instead of starting
  at full speed - a running player swinging round with both feet planted jolted a foot as it lifted; a cheer played
  as he walks between points no longer turns him to the net mid-stride (it whipped him round 30 degrees a frame); the
  lift-off release is eased over five frames. The joystick test leaves out pushes straight into a prop (the net post
  ahead of a spot on the net's line): he goes round it, as he must, which says nothing of the stick's way.
- **Loading v2**: the foundation's warm-up (`ld.warm`: the match's looks drawn a batch a frame from their own camera,
  each new shader made in a frame of its own) replaces the game's own reveal, and `ld.done()` holds the overlay till
  the frames come smoothly before the match starts. The setup screens pre-load match.gd (`WsgLoading.prewarm`).
  Measured (load_probe, Low): a later launch, the National Arena's longest frame 108 ms (the park's 201), settled in
  0.23 s; a first launch after an install or update, the longest 975 ms at the National Arena and 1.25 s at the park
  (each was a single frozen frame of 6.8 and 12.2 s before the overlay), the bar moving through 20-34 warm-up frames.

## No gliding (0.15.3)

The owner: "Players still gliding a lot, like when getting in position to spike or block. Still lots of gliding when
getting the ball too. When a player is prepping to block he is in a folded position and glides around, it's
awkward." Measured first (`tests/glide_probe.gd`: AI matches, every frame a player moves with a foot on the floor,
whether that foot slides along with him, over half his speed): in 0.15.2, of the way they went, 87% slid running in
the rally, 63% walking between points, 99% getting to a block, 96-98% getting to the ball (chest, header, sila), all
of the serve. Four causes:
- **The stride's pace** was 4 + 2.2 x speed radians a second whichever way he went. `tests/stride_probe.gd` measured
  the rig: how far the standing foot goes back under him per radian, at each speed and share sideways.
  `Moves.stride_rate` now turns the stride exactly that fast for the way he goes (scaled to his height).
- **The side-shuffle** never moved the standing foot under him at all: each leg swung out and back in turn, so going
  sideways he slid (most of a rally: facing the net, moving across it). Now a step and a close
  (`Moves._shuffle`): the leading foot lifts and steps out while the other stands, then the other closes.
- **Strides at a slant** have no foot planted (a run blended with a shuffle). Going somewhere, he now turns so the way
  he goes is straight ahead, straight back or square to his side, whichever is nearest to where he would face (at
  most 45 degrees off); far and fast he turns and runs, and squares up again as he arrives. He turns at most about
  540 degrees a second (a pivot), quicker to square up for a move.
- **Moves played on the way.** A move's legs held still while he slid to the spot (the blocker folded in his crouch).
  Now he steps or shuffles under a move until a little before it leaves the floor or meets the ball
  (`Moves.legs_from`), goes only as fast as gets him there as it starts (no sprint he brakes from in the move), and
  stays put from the touch until its follow-through is done before he runs off.
- **And a planted foot stays put** (`RealBody._planted`, Low; the shared foundation's planter places the feet of the
  bodies it draws on Medium and High): while an ankle is on the floor it is kept where it was put down, the thigh,
  knee and foot turned to it (two-bone IK on the rig, in the pelvis's own frame, on a solve of the legs alone), let
  go as it lifts. Players and the standing officials. About 0.7 ms a frame more on this machine.
- **Now** (the same probe, two matches): 18% slid running, 15% walking, 19% getting to a block, 12-14% getting to
  the ball, the serve 30%. Per step (the lead's measure: how far a planted foot slides from where it went down to
  where it lifts): half the steps under 1.1-1.4 cm running and walking (2.4 the block, 0.8-1.3 the dig, chest and
  sila), but the worst twentieth 40-55 cm: a foot that would have to stretch past PLANT_REACH (the stride's own
  stance longer than he travels) is put down again where the stride has it. That tail, the captured kicks' own steps
  (the serve, the roll, the sunback) and the header's are what is left (0.15.4). test_runner checks it: running under
  30%, walking under 25%, the block and the receiving touches under 35%; running and walking, half the steps under
  2 cm.
- Also: the thrower stayed set to crouch after his throw, his arms drawn back toward the crouch's mid-rally once it
  was done (a hand jolted 0.9 m/frame^2: the jitter test); now he is not, and the crouch is only taken standing.

## A Start tap shows it is loading (0.15.2)

The owner, for every game: "when you click start game there is a loading delay ... long enough on the slow phone
that users might think the game has frozen." Measured first (`tests/load_probe.gd`: the game booted as main.tscn
boots it, then each Start path tapped, each in a fresh process; Low, 1600x720, this machine's software GL): every
path was one frozen frame, the tap's build and the match's first draw together, the screen left on the setup screen
with the button pressed. 0.95-1.86 s with the shader caches warm (a later launch); 6.0-12.2 s on the first launch
after an install or update (no shader cache: National 6.8, the mall 8.1, the gym 8.2, the beach 9.2, the park 12.2).
Of it: 0.31 s loading match.gd (the session's first match: on Low no match runs behind the home screen to load it
earlier), 0.08-0.23 s building the match, and the rest its first draw - every material's shader made then, on the
main thread.

Now (foundation edebcd5, `WsgLoading`, ADOPTING 5.14):
- **`Game.play_match`**, used by every Start button (Quick match and Watch AI's Play, a season's and an
  international's Play, Next regu, Rematch): the shared overlay up in the tap's own frame (the screen dimmed,
  "Loading" in the player's language with the game's icon, a saffron bar and spinner, the button off; a second tap,
  or Back, does nothing). `match.gd` loads on the loader's thread; then the match is built in steps behind it, a
  frame drawn after each: Match (made and swapped in, held still), Venue (the arena's build yields between its
  parts), Players, View (the camera, the scoreboard, the controls), Drawing; then it starts. `Game.start_match`
  (all at once) is kept for the tests and tools.
- **Drawing a part at a time** (`Match.conceal`/`reveal`): everything built is hidden before the camera is made,
  then shown again over frames, each frame taking the parts whose shaders are made already and up to a budget of
  new ones (a shader of the game's own, the crowd's cards or the flags, counting four): one to begin with, twice
  as many after a quick frame (a later launch: a handful of frames), back to one after a slow one (a first launch:
  one new shader a frame). The overlay's spinner shader is made during the boot loading screen.
- **Measured the same way**: the overlay up in the tap's frame on every path, the first frame drawn 23-35 ms after
  the tap. Later launches: the longest frame 83-205 ms (it was the whole 0.95-1.86 s), the match started 0.7-2.2 s
  after the tap. First launch after an install or update: the longest frame 0.54-0.99 s (it was 6.0-12.2 s), the
  bar moving 18-23 times on the way. The longest slice of main-thread work 46-110 ms, in the Venue step (the
  foundation's limit 250 ms for the A16 at Low). Every load prints its `WSG_LOADING {...}` line (logcat).
- test_runner: a real tap on Play puts the overlay up and the button off in that frame; a second start and Back do
  nothing; the bar only goes forward, moves in most frames and reaches the end; no slice over 250 ms; drawn in
  three or more batches, none left hidden; the match then starts.

## The crowd's backs, and flat boots (0.15.1)

The foundation, synced to b073334:
- **Back views for the cards** (`crowd/cards_back.png`): a card the camera sees from behind its fan shows the fan's
  back, turned toward the camera at most 35 degrees. The near side's second card set and its hide rule (0.15.0's
  workaround) are gone: one draw call again, and the broadcast camera shows the near stands' backs. Also the cards'
  faces from the fans' full models, and the shared crowd's getting-up and chair-fit fixes. crowd_audit again: every
  venue PASS (2,623 3D fans, 3,077 cards): the seat of the trousers within 1 mm of the seat, the soles 9 mm under to
  level with the floor, nothing more than 25 mm into anything, every fan within 7 degrees of the play. To pass, the
  arena's step pads went from 2 cm to 1 cm thick and from 0.35 to 0.3 m deep (the seat 0.43 m over the step below):
  the national arena's longest-legged fans' knees were 2.7 cm into the step above.
- **WsgFootFlat** (from Hurling, whose rig's boots rested 10.6 degrees toe-up and showed it in every move):
  `FoundationLink` adds it as the body's last modifier (after the planter), and it turns the feet down only where the
  rig's boots rise 2 degrees or more heel to toe, keeping a planted heel on the floor. The tilt each character
  measures is printed in test_runner's foundation section ("the rig's boots' sole tilt", in the CI log: the rig is
  licensed data, not in the repo).
- Seen from the broadcast camera, the near stands show their fans' backs (hair and the backs of their shirts) in
  every venue; checked on renders at Low and High.

## The shared crowd: fans on their seats, facing the play (0.15.0)

The owner, for every game: the crowd sitting properly (not standing inside a seat), standing properly, watching the
game and facing the right way, and the same in every game (the shared foundation). The inventory (sent to the
Foundation session) found every fan's body pointed at the court's centre point (up to 55 degrees off square to their
row at the ends of the long stands), seated fans' feet hanging 0.45 m straight down into the step below, and the
arena's steps bare on Low. The foundation then gave every game one placement (synced: `addons/wsg_foundation`
cd6c29f; ADOPTING 5.1):
- **Each venue declared** (`Arena.crowd_venue`): its seats and standing room as `WsgCrowdVenue` sections, the same
  rows, heights and depths the arena builds. The arena: the steps on all four sides as "step" seats (sitting on a pad
  at the front of each step, 0.44 m over the step below, where the feet go; the pad now on every level), the jury on
  their chairs at the table. The provincial hall and the mall: the hall's aluminium bleachers (each plank measured on
  the model: tops 0.33, 0.77, 1.20 m, two tiers; on a 4 cm base, the upper tier 1.33 m up), each row sitting on its
  plank with its feet on the plank in front. The mall's own metal bleachers went: their model's planks are not level,
  so no seat height fits them (the mall's near side two sections, clear of the escalators). The mall's balconies: people
  standing at the glass rails. The park: three to a bench (0.44 m, its back 0.4 m over it) and a standing line behind;
  the beach: two standing lines a side.
- **Placed and faced by the foundation**: square to their row, turned toward the court's nearest part at most 50
  degrees; a seated fan's feet on the floor in front of the seat; a fan who gets up steps forward off the seat.
- **Drawn as the shared cards** (`WsgCrowdCards`) at every level: one draw call, as before (Low's budget unchanged),
  each card sized to its seat (the seat of the trousers on it) and standing just in front of it, turned to the camera
  at most 35 degrees off the way the fan faces. Low 40% of the places, Medium 70%, High all. Their looks: a Southeast
  Asian crowd (skin, hair, trousers: `Crowd.SKIN`, `HAIR`, `LEGS`), shirts in the home side's colours more than any
  other, both teams' colours as the team shirts; they get up and cheer with the play (`WsgCrowd3D.set_excite`). The
  two teams' flags are still this game's own (one fan in thirty). The cards face the play rather than follow the ball
  (the shared 3D fans' heads follow it; Medium and High can take them later if their cost fits).
- **The near side's fans** (facing the way the broadcast and side cameras look, over their heads) are a second set of
  cards, hidden while a camera looks over their backs: a card has only its front, and seen from behind it turns edge
  on, a sliver (the broadcast camera showed a row of them in its corner). The end camera, from the side, shows them.
  Asked the Foundation for back views, which would bring them back.
- **The crowd audit** (`game/crowd_venues.gd`, `tools/wsg/crowd_audit.gd`): every venue PASS, every fan measured
  in 3D and as a card: the arena 1,614 fans, the mall 740, the provincial hall 504, the park 97, the beach 122.
  The seat of the trousers on the seat within 1 mm, the soles 9 mm under to 30 mm over the floor, nothing more than
  22 mm into a seat, a seat back, a step or a rail (the limit 25), every fan within 7 degrees of the play (the limit
  35). To pass, the arena's pads went from 3 to 2 cm, the jury's chairs from 0.46 to 0.44 m, the balcony people 12 cm
  back from the rail, and the bleachers onto their base (the first plank too low for the long-legged, the upper tier's
  first too high for the short).
- `crowd_sheet.png` and `crowd_sheet_hi.png` (10.9 MB) and their tool are gone; the cards are 0.27 MB. The Android
  preset keeps the cards (`addons/wsg_foundation/crowd/*.res` left out, the 3D crowd, not used).
- test_runner: every venue at every level has its crowd, the level's share of its places filled, in one draw call,
  every card passing `WsgCrowdCards.audit`; on the sand everyone stands, in the arena everyone sits; the flags.

## The joystick is the screen's, in every camera (0.14.4)

The owner found the joystick wrong in two other games when the camera wasn't alongside the court, and asked for it to be
checked and fixed in every game. Here the stick followed the camera's heading (its right and its forward, laid flat),
which is out by the perspective: measured at the picture's middle, its edges and its corners, 24-33 degrees out at
the middle (the diagonals, foreshortened) and 50-56 degrees at the edges, in all three cameras. Now (`Match._cam_dir`,
the lead's method from Floorball) the camera's rays a little right, left, above and below where your player is drawn
are met with the floor, and the stick mixes those two floor directions, per pixel, as it is pushed: his run on the
screen is the stick's way wherever he is in the picture. The same goes for sliding your blocker along the net and for
aiming a kick or a serve across the other court (at the aim's place). The axes are eased (0.07 s, so about 0.2 s for a
cut to another camera) so he doesn't swerve as the picture changes; steady, they are the picture's own. The user bot
steers by the screen too (`Match.stick_for`); its results are the same (perfect 15-6, idle 3-15).

test_runner (`_stick_follows_screen`): each camera (broadcast, side on, end), from either end (the sides change between
sets); your player put where the picture's middle, edges and corners show the floor (6-9 places; the side and end
cameras show the stands at the top); the stick pushed 8 ways through `_user_steer` for 0.3 s: his run on the screen
within 10 degrees of the stick (worst 0.5); the aim across either court (worst 0.3); after a cut from the broadcast
camera to the end camera, the frame after it 21 degrees off his way before, and 0.3 s on 0.3 degrees off the new
picture's up.

The Web preset (no build makes one) now leaves out `addons/wsg_foundation/data/*` as well, so a Web download could
never carry the licensed motion capture (Foundation ADOPTING 5.10).

## The serve's throw from the footage, and a jitter test (0.14.3)

**The throw, one hand.** The owner: "notice it's ONE hand". The thrower in the World Cup broadcast (308.5-311.5 s,
30 fps) was traced with MediaPipe's pose landmarker (heavy model; every one of 105 frames found) and measured as the
game's poses are (`tools/footage/`, `tests/pose_probe.tscn`). The video and its frames are not in the repository,
only the angles (`tools/footage/serve_toss_world_cup.csv`). What he does, and the game's keys beside it:

| | Footage | Game |
|---|---|---|
| Holding it, standing | right hand only, arm 40 degrees forward of the trunk, elbow 50 | `HOLD`: 40, 52 |
| Down for the throw (held while the server readies) | trunk 65 degrees, knees 75-85, elbow 22-32, the wrist 0.1-0.3 m over the ankles, 0.45 m out | `LOW_HOLD`: 63, 85 and 75, 25, 0.25 m, 0.5 m |
| The swing | 0.22 s from the low point to the release, the knees 75 to 30 in 0.1 s | 0.24 s, 85 to 33 |
| Let go | trunk 26-30, arm 76-88 from the trunk, the wrist 80% of the shoulder's height | 25, 81, 79% |
| Follow-through | arm out level and straight (93, elbow 19), trunk 13 | 91, 15, 9 |

In regu the feeder, once he is set and the serve is due, goes down into the crouch over 0.8 s (`Player.toss_crouch`,
from 0.8 s before set-up's time is up) and throws from it (`toss_low`): the toss waits for him to be down, so it begins
at the same moment as before whenever everyone is in place in time. Serving himself (doubles, quadrant), and a team-mate
lobbing the ball to the thrower between points, use the same one-handed throw from standing (`toss`). The ball is in
the right hand everywhere it is carried (`carry_point()` is the right palm; the foundation draws it there too). The
release stays at 0.52 s and the kick's time is reckoned from the throw's release point (its CONTACT row) rather than
from the hands' momentary place: toss start to kick, ten serves each, regu 1.39-1.44 s before and 1.411 s now, doubles
1.23-1.34 s and 1.261 s. Stills: `docs/stills/serve_toss_one_hand_{men,women}.jpg` (from his right; 0.4 s before
set-up's time is up, the throw's start, 0.3, 0.42, 0.52 (the release) and 0.7 s in).

test_runner (`_serve_toss_clear`, Low and High, men and women, regu and doubles, 40 checks): the ball outside the
thrower's body from his crouch to the release (13 cm at the least, by the right thigh); in his right
hand, his left 0.56 m from it at the nearest; let go at 0.96-1.14 m; in regu every serve thrown from the crouch with
the ball at most 0.46 m up; the thrown ball clear of the server.

**The jitter test** (`_jitter`): the worst jolt of any joint in a frame (its second difference from frame to frame).
Each move alone on both models at 60 fps, under 0.25 m/frame^2; and a Low regu match and a High doubles one (women),
every player's hands, feet and head at 30 fps, under 0.85. It found five pops, all fixed:
- The block's raised leg and its turn came in within one frame (the toe 0.8 m in 1/60 s: 0.70 m/frame^2). The CMU
  jump under it is played 2.4 times as fast as the subject's, and the block's own part was laid over by his height.
  `tools/models/fbx_to_move.gd` now brings that part in over about seven frames as he springs and takes it out over
  five before he lands (eased at both ends, so it is gone as his feet touch and they don't slide), and eases the
  run-up toward contact (the block's `ease`); the block and the jumping header re-baked. The block's contact moment and
  height are the same; its contact point moved 2 cm back and 8 cm in (`[2.1, 0.66, -0.2]`, from
  `[2.1, 0.68, -0.28]`); its planted feet slide at most 2.7 cm a frame (under the 3 cm test). Worst now: 0.19; the
  jumping header's 0.23 now 0.18.
- A cheer cut a spiker's kick short as the point ended: in the air in his roll, he was standing the next frame (his
  head 1.66 m/frame^2). A cheer or a slump now starts once his move has played out (`Player.play_after`).
- A move that ended as he ran put him straight into his stride (a foot 0.93), and one cut short by another jumped to
  it. Either is now eased out of over 0.15 s (`MOVE_OUT`), his lift and his turn with it.
- A block cut short in the air by a header turned his body 60 degrees in a frame: the turn now follows the blended pose.
- 0.14.2's walking legs (no gliding between points) took over a kick still finishing after the point, and switched
  on and off as he left the floor and landed: the roll's foot flickered (1.1). Fixed before 0.14.2 went out: only the
  moves played between points, eased out as he leaves the floor.
Worst left: a move alone, the kuda's foot through the ball (0.19 at 60 fps); in a match, a hand taking the ball (0.70).

**The other moves.** Sila, kuda, the horse kick, the chest receive and the dig could not be traced from the two
broadcasts: the players are 60-100 px tall, the 26 replays are the same wide camera at normal speed, and a kick is over
in 0.2-0.3 s. The trunk's lean and the knees could be read, not the kicking leg's angles. Close-ups or slow motion have
been asked for (they would go in the private assets repository); those moves are still the hand-made keys. The roll
spike and the sunback were checked by the jitter test (0.08 and 0.11 alone; the roll's in-match flicker was the walking
legs above).

## Four things the owner saw (0.14.2)

- **Spikes too fast to see.** A roll spike left the foot at up to 30 m/s (108 km/h, a real one's speed) and crossed
  the court in four or five frames, so a phone showed almost none of it. Every spike (roll, sunback, tapak, head) now
  flies at `SPIKE_PACE` (0.68) of that speed: about 76 km/h, crossing in about a third of a second. The defenders'
  reckoning against a spike (`_find_touch`) is scaled by the same 0.68, so they reach the spikes they reached before.
  Nine national-level regu matches (`tests/match_sim.tscn`), before and after: kills 0.535 and 0.534 a rally, digs
  0.29 and 0.30, blocks 0.045 and 0.055, errors 0.36 and 0.35, 4.50 and 4.45 touches a rally (576 and 620 rallies).
- **Gliding back to his place.** A player walking back after fetching the ball (or lobbing it to the thrower, or after
  a cheer) still had his move playing, and the move's standing legs slid him along. While he walks with one of those
  moves playing (`STROLL_MOVES`), his legs now walk and the move keeps his arms and back (`Player.tick`); a kick he is
  still finishing as the point ends keeps its own legs. test_runner
  (`_no_glide_between_points`): Low, regu and doubles, 150 s each; of 30 or more 0.5 s walks between points, none with
  the feet still (before: 46 of 468).
- **An official backing away ran forward.** The stride was always played forward, so an official backing out of the
  ball's way (still facing the court) ran on the spot as he went backwards. Backing away, the stride now plays
  backwards, as the players' backpedal does (`Officials._pose`). test_runner (`_officials_back_away`, Low and High): his
  lower foot's speed over the floor is about his own (it was about twice).
- **The kick's sound.** The kicks were a soccer-ball kick with a rubber-ball hit 6 dB under it, 80-90% of their energy
  below 250 Hz: a thud. They are now a light, hollow plastic knock from Kenney's CC0 "Impact Sounds" (most of its energy
  at 0.8-3 kHz, a light hollow ball's "pok") with the soccer kick under it for the foot's weight, three takes. The
  spike adds the same knock to its hit. Spectral centroids: kick 308 to 526 Hz, kick_2 to 477 Hz, kick_3 to 617 Hz,
  spike 874 Hz. `docs/SOUNDS.md` and the licences page credit Kenney.

## The licences page without a worker thread (0.14.1)

0.13.0's CI build crashed (signal 11) as test_runner began, before any check; the same commit passed in the pull
request's run. The Foundation session symbolized the backtrace: Godot 4.7.2's text shaping (TextServerAdvanced) under
a RichTextLabel being drawn, on the main thread, while a worker thread laid the same label out: the licences page set
`threaded` on its long texts (about 80,000 characters of licences), and test_runner's first test opens every screen
in every language, Licences among them, three frames each, changing the theme's sizes in between. Netball crashed in
the same engine code, and Kabaddi fixed the same thing. A phone could hit it too, opening the page and going back at
once. Now nothing is threaded: the texts are cut at their paragraphs into pieces of about 1,500 characters, the first
added as the page opens and one a frame after (`built()` says when all are in), so the page opens at once and no one
layout is large. test_runner waits for the page to be built before reading it or leaving it.

## Gaps that need the owner

For the Play Store, what only the owner can do is in `store/PLAY_STORE.md`: the developer account, the upload key and
its three secrets, the privacy policy's address on the owner's site, the closed test with 12 testers, and a last read
of the listing drafts (a native speaker's, for the twelve translations).

In the game, none. The two raised in 0.5.0 are filled in 0.5.1:
- The shophouse row, at the night market and the park.
- Apartment blocks with lit windows.

The shophouse model has a passer-by fused into its pavement: behind the stalls, or 45 m off at the park, it reads as
background life.
