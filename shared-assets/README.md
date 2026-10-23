# Shared assets for the six mobile games

The lead session (**Mobile Games Lead**) keeps this folder. Assets that suit more than one game are prepared here once,
cut down for phones and scaled to real-world size, then each game copies what it needs into its own project.

**Games:** Kabaddi Raid, Sepak Takraw Unleashed, Netball Unleashed, Kho Kho Rush, Floorball Unleashed, Hurling Heroes.
**Per-game plans:** [`plans/`](plans/) says which asset goes where in each venue, and what each game still has to build.

## How to use it

1. `git fetch origin claude/shared-assets` and copy only the files your plan names:
   `git checkout origin/claude/shared-assets -- shared-assets/<path>` then move them into your game's `assets/`.
   Don't copy the whole folder into a game: every file ends up in the APK.
2. **Scale and origin are done.** Every model is in metres, standing on y = 0, centred on x/z.
3. **Two levels, plus cut-outs for plants.** `name.glb` is for Medium and High. `name_low.glb` is for Low and for anything
   far away (about a quarter of the triangles, half-size textures). `name_card.glb` is two crossed planes with an
   alpha-cut texture rendered from the full model: use cut-outs for every tree further than about 25 m from the camera,
   and for all trees on Low. They look far more real than a cut-down mesh at that distance, at 4 triangles each.
4. **Draw calls.** Place repeated things (trees, chairs, lamps, cut-outs) with one `MultiMeshInstance3D` per asset
   type, so 40 chairs cost one draw call. Keep each venue within your game's Low budget (about 100 draw calls) and
   record before and after numbers with `tests/perf_probe`.
5. **Materials.** Textures are JPEG except where alpha is needed (cut-outs: PNG, alpha-scissor at 0.4,
   double-sided). Metal/roughness maps were dropped to save memory; set roughness about 0.8 and metallic 0, except
   lamp heads and poles (metallic 0.6).
6. **Style.** Everything here is realistic (photo-scanned Poly Haven or the owner's Meshy models). Nothing cartoon.
   Match your game's grade and fog so the new pieces sit in the same light as the players.

## Skies and lighting: `skies/`

Each sky comes in two files: `*_sky_2k.jpg`, a 2048×1024 equirectangular background (tone-mapped, for
`PanoramaSkyMaterial`, works on every level including Low), and `*_light_1k.hdr` for ambient light and reflections
on Medium and High. Previews: [`previews/skies.jpg`](previews/skies.jpg).

| Sky | Mood | Use it for |
|---|---|---|
| `belfast_sunset_puresky` | Northern Irish sunset, low sun, soft cloud | Hurling parish field at dusk |
| `suburban_football_field` | Grey overcast over a playing field | Hurling county ground by day (Irish weather) |
| `kloofendal_overcast_puresky` | Flat overcast | Any overcast day |
| `kloofendal_48d_partly_cloudy_puresky` | Bright day, cumulus | School and park grounds by day |
| `qwantani_noon_puresky` | Hot, clear midday | Indian and Thai day grounds |
| `qwantani_dusk_2_puresky` | Warm pink dusk | Indian village grounds at dusk |
| `qwantani_sunset_puresky`, `table_mountain_1_puresky` | Sunset over water | Beach venues (Puri Beach, takraw beach) |
| `overcast_soil_puresky` | Heavy grey cloud | Monsoon ground |
| `kloppenheim_02_puresky` | Clear starry night | Floodlit grounds and night markets |
| `kloppenheim_07_puresky` | Overcast night lit by a town | Floodlit stadiums in cities |
| `netball_court` | A real outdoor netball court at sunset | Netball Unleashed's outdoor court |
| `gym_01` | Inside a gym | Reflections on hall floors only (not a background) |

## Surfaces: `surfaces/`

Photo-scanned, tileable, 1024 px: `*_albedo_1k.jpg`, `*_normal_1k.jpg` (OpenGL/Godot convention) and, where useful,
`*_rough_1k.jpg`. One tile covers about 2 to 3 m. Previews: [`previews/surfaces.jpg`](previews/surfaces.jpg).

- **Grass:** `grass_ground` (mown pitch), `leafy_grass`, `sparse_grass` (worn edges), `withered_grass` (dry, worn goalmouths).
- **Earth:** `red_laterite_soil_stones`, `red_dirt_mud_01`, `terrain_red_01` (Indian red earth), `brown_mud_dry`
  (beaten village court), `brown_mud` (wet, monsoon), `dry_ground_01` (cracked dry ground).
- **Sand:** `coast_sand_01` (dry beach), `damp_beach_sand` (wet sand by the water).
- **Courts and halls:** `white_maple_veneer` (sports-hall maple floor, also birch wall slats), `wood_floor` (planked),
  `clean_asphalt` and `asphalt_02` (outdoor courts and streets), `rubber_tiles` (mat and synthetic floor grain),
  `rubberized_track`, `concrete_floor`.
- **Walls and roofs:** `concrete_block_wall` (painted block gym walls: use its normal map with a pale paint colour),
  `painted_concrete` (old painted wall), `plastered_wall`, `yellow_plaster`, `clay_plaster` (Indian and Southeast Asian
  houses), `red_brick`, `bamboo_wall`, `ceiling_interior`, `clay_roof_tiles`, `corrugated_iron`, `thatch_roof_angled`.

## Water: `water/`

`water_normal_512.png` is a seamless normal map for sea, lake or puddles. Use it in a cheap shader: scroll two copies
in different directions, mix a deep and a shallow colour by view angle (Fresnel) and reflect the sky colour. Don't use
real-time reflections on Low.

## Models

Previews of every model: [`previews/`](previews/) (`psheet*.png`).

| Asset | What it is | Region and games | Files | Source, licence |
|---|---|---|---|---|
| **rain_tree** | Wide flat crown: rain tree / monkeypod, the shade tree of Indian and Thai grounds | India, SE Asia: kabaddi, kho kho, takraw | `trees/rain_tree.glb` High: 4,903 tris, 366 KB<br>`trees/rain_tree_low.glb` Low: 1,189 tris, 77 KB<br>`trees/rain_tree_card.glb` cut-out: 4 tris, 615 KB | owner (Meshy), owner |
| **oak_tree** | Broad oak-like tree | Ireland, UK, Europe: hurling, netball outdoor | `trees/oak_tree.glb` High: 3,623 tris, 331 KB<br>`trees/oak_tree_low.glb` Low: 783 tris, 77 KB<br>`trees/oak_tree_card.glb` cut-out: 4 tris, 728 KB | owner (Meshy), owner |
| **broadleaf_tree_dark** | Dark broadleaf (sycamore/ash look) | Ireland, UK, Europe: hurling, netball outdoor | `trees/broadleaf_tree_dark.glb` High: 4,387 tris, 1,104 KB<br>`trees/broadleaf_tree_dark_low.glb` Low: 679 tris, 302 KB<br>`trees/broadleaf_tree_dark_card.glb` cut-out: 4 tris, 505 KB | owner (Meshy), owner |
| **coconut_palm** | Tall slender palm | India coast, SE Asia: kabaddi (Puri Beach), kho kho village, takraw beach/temple | `trees/coconut_palm.glb` High: 3,231 tris, 353 KB<br>`trees/coconut_palm_low.glb` Low: 945 tris, 93 KB<br>`trees/coconut_palm_card.glb` cut-out: 4 tris, 313 KB | owner (Meshy), owner |
| **island_tree_a** | Photo-real broadleaf with gnarled trunk | tropical: India, SE Asia, Australia, Fiji/Samoa | `trees/island_tree_a_card.glb` cut-out: 4 tris, 720 KB | Poly Haven, CC0 |
| **island_tree_b** | Smaller tropical tree | tropical: India, SE Asia | `trees/island_tree_b_card.glb` cut-out: 4 tris, 583 KB | Poly Haven, CC0 |
| **jacaranda** | Jacaranda (purple when flowering) | Australia, South Africa, NZ: netball outdoor; also Indian cities | `trees/jacaranda_card.glb` cut-out: 4 tris, 540 KB | Poly Haven, CC0 |
| **small_broadleaf** | Hedgerow-size broadleaf | Ireland, UK, Europe: hurling, netball outdoor | `trees/small_broadleaf_card.glb` cut-out: 4 tris, 520 KB | Poly Haven, CC0 |
| **fern** | Fern | Ireland (ditches), tropical shade | `foliage/fern_card.glb` cut-out: 4 tris, 47 KB | Poly Haven, CC0 |
| **dry_grass_tall** | Dry tall grass / kans grass clump | India, SE Asia dry season: kabaddi Gaon Maidan, kho kho village | `foliage/dry_grass_tall_card.glb` cut-out: 4 tris, 208 KB | owner (Meshy), owner |
| **grass_clumps** | Green grass clumps | any | `foliage/grass_clumps_card.glb` cut-out: 4 tris, 68 KB | owner (Meshy), owner |
| **grass_wispy** | Tall wispy grass | any | `foliage/grass_wispy_card.glb` cut-out: 4 tris, 112 KB | owner (Meshy), owner |
| **thai_temple** | Thai wat with tiered gold-trimmed roofs | Thailand: takraw temple court | `buildings/thai_temple.glb` High: 15,000 tris, 2,104 KB<br>`buildings/thai_temple_low.glb` Low: 4,000 tris, 545 KB | owner (Meshy), owner |
| **stilt_house** | Wooden house on stilts (kampung style) | Thailand, Malaysia, Indonesia villages: takraw | `buildings/stilt_house.glb` High: 6,000 tris, 1,101 KB<br>`buildings/stilt_house_low.glb` Low: 1,500 tris, 308 KB | owner (Meshy), owner |
| **city_apartments** | Painted apartment block | Indian and SE Asian cities: kabaddi Mumbai, kho kho, takraw | `buildings/city_apartments.glb` High: 4,000 tris, 552 KB<br>`buildings/city_apartments_low.glb` Low: 1,000 tris, 153 KB | owner (Meshy), owner |
| **terrace_row** | Row of terraced houses | Ireland, UK: hurling county ground, netball outdoor | `buildings/terrace_row.glb` High: 5,999 tris, 750 KB<br>`buildings/terrace_row_low.glb` Low: 1,499 tris, 198 KB | owner (Meshy), owner |
| **thatched_cottage** | Thatched cottage | Ireland: hurling parish field | `buildings/thatched_cottage.glb` High: 10,000 tris, 1,586 KB<br>`buildings/thatched_cottage_low.glb` Low: 2,500 tris, 434 KB | owner (Meshy), owner |
| **bleacher_metal** | Dark metal seating section with rail | indoor arenas: floorball, netball, takraw | `stands/bleacher_metal.glb` High: 8,000 tris, 935 KB<br>`stands/bleacher_metal_low.glb` Low: same as High (8,000 tris); this mesh breaks apart below that | owner (Meshy), owner |
| **bleacher_hall** | Indoor sports hall bleacher section: three straight stepped rows of brushed aluminium plank seats on a dark steel frame, with end rails. Each row is 0.8 m deep and rises about 0.5 m. Made for halls, where bleacher_metal doesn't fit. Generated in Meshy for Floorball Unleashed (30 credits). Butt sections end to end (the end rails then double up; hide one with the next section's) and set two sections back to back, one raised 1.5 m, for six rows. | Indoor halls and arenas: floorball, netball, takraw | `stands/bleacher_hall.glb` High: 4,328 tris, 544 KB<br>`stands/bleacher_hall_low.glb` Low: 2,200 tris, 288 KB (it breaks apart below that). 8 m long, 2.4 m deep, 1.5 m tall. Preview: `previews/floorball_hall_kit.jpg` | owner (Meshy), owner |
| **bleacher_concrete** | Curved concrete terrace segment | outdoor stadiums: hurling, kabaddi, kho kho | `stands/bleacher_concrete.glb` High: 8,000 tris, 923 KB<br>`stands/bleacher_concrete_low.glb` Low: 2,000 tris, 228 KB | owner (Meshy), owner |
| **park_bench** | Cast-iron and slat park bench | parks: hurling parish, netball outdoor, takraw park court | `seating/park_bench.glb` High: 3,000 tris, 456 KB<br>`seating/park_bench_low.glb` Low: 800 tris, 126 KB | owner (Meshy), owner |
| **gym_bench** | Low wooden gym bench | sports halls, school gyms: floorball, netball, takraw | `seating/gym_bench.glb` High: 1,000 tris, 131 KB<br>`seating/gym_bench_low.glb` Low: 300 tris, 41 KB | owner (Meshy), owner |
| **gym_bench_pale** | Swedish gymnastics bench (gymnastikbänk) in pale lacquered birch, no backrest. Generated in Meshy for Floorball Unleashed (30 credits). | Nordic and European sports halls, school gyms: floorball, netball | `seating/gym_bench_pale.glb` High: 1,635 tris, 124 KB<br>`seating/gym_bench_pale_low.glb` Low: 449 tris, 52 KB. 3 m long, 0.33 m tall, 0.27 m wide. Preview: `previews/floorball_hall_kit.jpg` | owner (Meshy), owner |
| **monobloc_chair** | White plastic chair, the spectator seat of local kabaddi, kho kho and takraw | India, SE Asia: village and local matches | `seating/monobloc_chair.glb` High: 1,500 tris, 184 KB<br>`seating/monobloc_chair_low.glb` Low: 618 tris, 74 KB | Poly Haven, CC0 |
| **folding_stool** | Folding wooden stool | markets, village grounds | `seating/folding_stool.glb` High: 673 tris, 137 KB<br>`seating/folding_stool_low.glb` Low: 314 tris, 47 KB | Poly Haven, CC0 |
| **metal_stool** | Metal stool | night markets, scorers | `seating/metal_stool.glb` High: 670 tris, 119 KB<br>`seating/metal_stool_low.glb` Low: 199 tris, 38 KB | Poly Haven, CC0 |
| **painted_bench** | Painted wooden bench | school grounds, villages | `seating/painted_bench.glb` High: 630 tris, 113 KB<br>`seating/painted_bench_low.glb` Low: 300 tris, 41 KB | Poly Haven, CC0 |
| **scorers_table** | Trestle table for scorers and stalls | village and local grounds: kabaddi, kho kho, takraw market | `props/scorers_table.glb` High: 1,499 tris, 266 KB<br>`props/scorers_table_low.glb` Low: 399 tris, 73 KB | owner (Meshy), owner |
| **long_table** | Long plank table | stalls, officials | `props/long_table.glb` High: 1,500 tris, 301 KB<br>`props/long_table_low.glb` Low: 400 tris, 88 KB | owner (Meshy), owner |
| **cafe_table_set** | Outdoor table and chairs | night markets, cafes | `props/cafe_table_set.glb` High: 4,671 tris, 395 KB<br>`props/cafe_table_set_low.glb` Low: 4,671 tris, 322 KB | Poly Haven, CC0 |
| **street_lamp_tall** | Tall street lamp | streets, parks | `props/street_lamp_tall.glb` High: 2,024 tris, 312 KB<br>`props/street_lamp_tall_low.glb` Low: 597 tris, 101 KB | Poly Haven, CC0 |
| **street_lamp_wall** | Wall-hung street lamp | walls, markets | `props/street_lamp_wall.glb` High: 1,499 tris, 310 KB<br>`props/street_lamp_wall_low.glb` Low: 497 tris, 102 KB | Poly Haven, CC0 |
| **lantern** | Lantern for stalls | night markets | `props/lantern.glb` High: 1,010 tris, 543 KB<br>`props/lantern_low.glb` Low: 868 tris, 171 KB | Poly Haven, CC0 |
| **boulder** | Boulder | field edges, hills | `props/boulder.glb` High: 1,360 tris, 216 KB<br>`props/boulder_low.glb` Low: 373 tris, 57 KB | Poly Haven, CC0 |
| **mossy_rocks** | Mossy rocks | Ireland: hurling parish, stone walls | `props/mossy_rocks.glb` High: 3,000 tris, 194 KB<br>`props/mossy_rocks_low.glb` Low: 800 tris, 57 KB | Poly Haven, CC0 |
| **basketball_hoop** | Weathered street hoop on a post. For indoor halls build a clean regulation board instead (see the hall notes) | outdoor courts and parks: netball outdoor court, takraw park court | `hall/basketball_hoop.glb` High: 6,000 tris, 707 KB<br>`hall/basketball_hoop_low.glb` Low: 1,500 tris, 183 KB | owner (Meshy), owner |
| **fluorescent_light** | Ceiling fluorescent batten (repeat in rows) | sports halls, gyms | `hall/fluorescent_light.glb` High: 1,283 tris, 148 KB<br>`hall/fluorescent_light_low.glb` Low: 1,266 tris, 102 KB | Poly Haven, CC0 |
| **hanging_lamp** | Hanging industrial lamp | older halls, school gyms | `hall/hanging_lamp.glb` High: 1,282 tris, 211 KB<br>`hall/hanging_lamp_low.glb` Low: 1,272 tris, 113 KB | Poly Haven, CC0 |
| **wall_clock** | Wall clock above the doors | sports halls, gyms | `hall/wall_clock.glb` High: 532 tris, 131 KB<br>`hall/wall_clock_low.glb` Low: 532 tris, 131 KB | Poly Haven, CC0 |
| **fire_alarm** | Fire alarm call point by the doors | sports halls | `hall/fire_alarm.glb` High: 847 tris, 83 KB<br>`hall/fire_alarm_low.glb` Low: 847 tris, 83 KB | Poly Haven, CC0 |
| **fire_alarm_nordic** | Nordic red manual call point with a white break-glass panel (the shared fire_alarm is the American kind). Generated in Meshy for Floorball Unleashed (20 credits). Its glass reads "FIRE" in a blur, so it passes for brand/palo at hall distance. | Nordic and European sports halls: floorball, netball | `hall/fire_alarm_nordic.glb` High: 395 tris, 44 KB<br>`hall/fire_alarm_nordic_low.glb` Low: same. 9 cm square, 5.5 cm deep. Preview: `previews/floorball_hall_kit.jpg` | owner (Meshy), owner |
| **wet_floor_sign** | Wet floor sign | sports halls (by the doors, never on court) | `hall/wet_floor_sign.glb` High: 228 tris, 30 KB<br>`hall/wet_floor_sign_low.glb` Low: 228 tris, 30 KB | Poly Haven, CC0 |
| **indian_village_temple** | Whitewashed South Indian village temple: saffron and red striped walls, pillared porch, stone steps, tiered domed tower. Generated in Meshy for these games (30 credits). | India: Kabaddi Raid (Gaon Maidan, and on the skyline elsewhere), Kho Kho Rush (village ground) | `buildings/indian_village_temple.glb` High: 7,999 tris<br>`buildings/indian_village_temple_low.glb` Low: 1,999 tris. 7 m tall. Preview: `previews/indian_village_temple.jpg` | owner (Meshy), owner |
| **jagannath_tower** | An Odisha (Kalinga-style) temple tower in pale sandstone, for Puri's skyline. Generated in Meshy for Kabaddi Raid (50 credits). It's a stand-in with the right silhouette, not an exact copy. | India: Kabaddi Raid, Puri Beach skyline | `buildings/jagannath_tower.glb` High: 8,000 tris<br>`buildings/jagannath_tower_low.glb` Low: 2,000 tris. 60 m tall (the real tower is about 65 m). Preview: `previews/jagannath_tower.jpg` | owner (Meshy), owner |
| **shophouse_row** | A row of five 2–3 storey Southeast Asian shophouses (Malaysia, Singapore, Bangkok): ornate gables, shuttered windows, balconies, shop fronts and a covered walkway. Generated in Meshy for Sepak Takraw Unleashed (30 credits). One modelled passer-by stands at the front; it's joined to the pavement and couldn't be removed. | Southeast Asia: Takraw night market and park skyline | `buildings/shophouse_row.glb` High: 9,000 tris<br>`buildings/shophouse_row_low.glb` Low: a 2-triangle facade panel (alpha), 12 m tall, about 19 m long. Preview: `previews/shophouse_row.jpg` | owner (Meshy), owner |
| **city_apartments_night** | `city_apartments` with night-lit windows: an emission map in which about 55% of the windows glow warm or cool at random. Made from the existing model's texture, no credits. | Night venues: Takraw night market and park, any floodlit city ground | `buildings/city_apartments_night.glb` High, `_low.glb` Low (same triangle counts as city_apartments). Preview: `previews/city_apartments_night.jpg`. Turn the emission down (0.6–1.0) to taste | owner (Meshy), owner |

## What was looked at and not used

- **From the owner's upload:** `Hurling.Goal` is a soccer goal (a box frame with no uprights above the bar), not hurling
  posts, so it isn't used. Hurling Heroes keeps its own posts built to the rules. Not used either: the
  German half-timbered houses (no game is set where they belong), the Japanese temple and house (no game is set in Japan),
  two cartoon-style palms, the cartoon tall house, the medieval carved table, the dark grass ball, and three models whose
  meshes are broken (the tower house, one large house and one temple).
- **The Chinese temple** came out with a whole wall missing in the source model. A new one would need generating.
- **Poly Haven pieces that didn't survive:** the chain-link fence (draw it with a shader instead: a diamond pattern
  from the UVs, alpha-scissored), the electricity poles (a kit of loose parts), and several scattered plant sets.
- **Kenney and Quaternius** (also allowed by the network) are cartoon-style, so none of their assets are used in
  these realistic games.

## Gaps that need the owner

- None at present: the village temple and the Jagannath tower are both done.
- **A clean indoor basketball backboard.** The owner's hoop is a weathered street hoop (good for outdoor courts).
  Halls should build a clean regulation one from simple shapes; the plans give the measurements.

## Licences

Poly Haven assets are CC0 (no attribution needed). The owner's Meshy models belong to the owner. Credit
"Poly Haven (polyhaven.com)" in each game's licences screen anyway: it's courteous and costs nothing.
