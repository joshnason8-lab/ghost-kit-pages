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

## Gaps that need the owner

None. The two raised in 0.5.0 are filled in 0.5.1:
- The shophouse row, at the night market and the park.
- Apartment blocks with lit windows.

The shophouse model has a passer-by fused into its pavement: behind the stalls, or 45 m off at the park, it reads as
background life.
