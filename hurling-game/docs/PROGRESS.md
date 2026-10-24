# Hurling Heroes: progress

The hurling game, built overnight (21 October 2026) on `claude/hurling-game`, draft PR #6. If work stops, resume from
here and `git log`.

## Done (0.1.0-beta)

- **Research** (written up in docs/RULES.md, LANGUAGES.md, AI.md): the GAA Official Guide Part 2 (27 March 2026
  edition) and the 2026 dissent rule; how hurling is played (the 2026 Games Intelligence Unit numbers, sports
  science); markets, languages and Google Play policy; the name.
- **Rules module** (`game/rules.gd`, `game/pitch.gd`) with a headless test for each rule (test_runner: 292 checks).
- **The match** (`game/match.gd`): throw-ins, open play, the loose ball, catches and lifts, the carry rules, strikes,
  hand-passes, solos, tackles, fouls, advantage, cards (yellow, red, black and the sin bin), puck-outs, frees, 65s,
  sideline cuts, penalties, scores, wides, posts and crossbar, added time, half time, extra time, the shoot-out,
  full time and the result. The clock runs through stoppages (the referee's watch).
- **Officials** with their signals and flags; **team AI** tuned to real numbers (AI.md); your player by touch
  (floating joystick, context buttons, switch, assist levels); the broadcast camera; the HUD (score bug in
  goals-points and total, the clock, added time, calls, the sliotar's marker, your steps).
- **Bodies** built in code on a 17-bone skeleton: helmets with face guards, hurleys, four kit designs in each county's
  colours, umpires' white coats; a far LOD on Low. Close-ups: `tests/kit_view.tscn`.
- **Grounds**: the parish field at dusk, the county ground (day and under lights), the national stadium; merged
  geometry, a one-draw-call crowd.
- **Menus**: the home screen as a match programme over a live AI match (a drawn dusk field on Low); match setup as
  the team sheets; the Summer Championship and the Tier Two Cup; Settings (language, help, length, grade, graphics
  with auto, frame rate, camera, sound, music, vibration, left-handed, button size, move buttons, About with
  privacy, help, licences); How to Play (scrolls from anywhere); results as the paper's report with a box score.
- **Languages**: English and Irish (every string), Irish plurals; fit_audit clean at four screen shapes.
- **Tests**: test_runner, fit_audit, user_bot (play and idle), match_sim, input_test, perf_probe, screenshots,
  kit_view, venue_view, compile_check. All in CI except perf_probe and the picture tools.
- **CI**: the Android build (tests, 64-bit and 32-bit APKs, the `ash-and-leather-beta` release) and the Play bundle
  (unsigned; target API 36, 16 KB pages, isGame, vibrate only) both green.
- **Pages**: `ash-and-leather/` (index, privacy, support), linked from Settings > About.
- **Store**: PLAY_STORE.md with every App content answer, listings (en-GB default, en-US, en-AU, en-CA), the icon,
  the feature graphic and the screenshots (two in Irish).
- **Docs**: README, RULES, LANGUAGES, AI, MESHY_BRIEF, BETA.
- **Music**: a jig written for the game (tin whistle, harp, bodhrán), synthesised (`tools/audio/make_music.py`).

## Done (0.2.0-beta, round two, 21 October 2026)

- **Scoring at full length fixed**: the ball is live 38% of the watch, as in a real match; stoppages cost their real
  time (moved on when the players are set). Lengths 8, 14, 20 and 35 minutes; 35 is the full 70 with the ball live
  as long as in a real match, and it ends like one (about 2.5-3 goals and 43 points between the sides; real 2.75 and
  42). `tests/score_check.tscn` holds every length to the real numbers, in CI (docs/AI.md).
- **The playtest** (docs/PLAYTEST.md): the Web build played in Chromium by touch at 1280 × 720, 1600 × 720 and
  2400 × 1080, full matches in Quick Match and both competitions; what was wrong, fixed worst first, a test each.
- **The coach**: the game in three lines before your first throw-in and a tip the first time each thing comes up, in
  English and Irish (`game/coach.gd`; Settings > Coach's tips).
- **Tired players and substitutions**: tiredness by the match clock and stamina (slower, less true); five
  substitutions (three more in extra time), at a break, by the manager or by you (pause > Substitutions).
- **Tactics**: a sweeper, two inside, short, mixed or long puck-outs (pause > Tactics); the computer's side by its
  county's habits, a sweeper dropped back to hold a late lead.
- **The ball in the air**: a ring on the grass where a high ball near you comes down.
- **Sideline cuts**: backs under pressure clear it over the sideline, as real ones do.
- **Rules re-check**: still blocked (the network policy refuses every host with the Guide; docs/RULES.md says what
  would finish it).

## Done (0.3.0-beta, round three, 22 October 2026)

The owner's first round of changes, each with a test where one can say it works:

- **PULL crashed the game**: the free ball's path was read empty after a pull; fixed, and `user_bot -- pull` presses
  PULL all match in CI.
- **The players barely reacted to the joystick**: your man now reaches top speed in about half a second (twice the
  computer's men's acceleration, quicker turns) and runs flat out from two-thirds of the stick's travel.
- **Renamed Hurling Heroes** (below, under Decisions); the owner's artwork for the home screen's cover, the app icon
  (adaptive, with its own green behind) and the store's feature graphic (`tools/store/`).
- **The trees floated on nothing**: the countryside round every ground, fields and hedges out to the horizon, in the
  light of the time of day.
- **The ball over the end line**: it flies on into the goal's net or the ball-stop net behind the goal, and drops.
- **The players were too small**: drawn 15% larger than life, the camera closer (TV 25° to 19°, High 36° to 29°,
  End 46° to 40°).
- **The owner's model** (a GLB on Google Drive) for every hurler, and **the four Mixamo clips**: baked for phones by
  `tools/player/` (mesh 187,754 triangles to 5,866, texture 4096 to 1024), moved onto the game's own skeleton so
  every pose plays on it, each county's colours painted by a shader; the sprint and the three swings from the clips
  (`game/hero_body.gd`, `tools/player/README.md`). Officials stay code-built. The model's texture has the number 11
  on every back: a number per man needs the owner's model without one (or a second texture).
- **A replay of a wide** from behind the goal, a little slower than life, about four seconds; a tap skips it
  (`game/replay.gd`).
- **CI**: the root workflow runs on a push (and by hand), not on the pull request as well; the full test suite is
  run here before every push.

## Done (0.4.0-beta, the graphics update, 22-23 October 2026)

From the lead's shared assets (branch `claude/shared-assets`, `plans/hurling-heroes.md`), only what the plan uses,
copied into `assets/env/`:

- **Skies** (2K panoramas, every level): the parish field under `belfast_sunset_puresky`, the county ground by day
  under `kloofendal_overcast_puresky`, at night under `kloppenheim_07_puresky` (darkened to sit over a floodlit
  field), the national stadium under `kloofendal_48d_partly_cloudy_puresky` (a final-day sky). Each sky is turned
  so its sun is where the light comes from; the sun's place, colour and the sky's ambient colour were read once from
  the 1K HDRs (`tools/env/sky_light.py` → `assets/env/sky/skies.json`), so the HDRs are not shipped.
- **The pitch**: `grass_ground` in the game's greens, mown in bands, `sparse_grass` worn along the touchlines and
  outside the field, `withered_grass` in the goalmouths, the scan's normal map in the light (Medium and High; Low
  draws the grass and the bands, two texture reads). **The fields** round every ground: `leafy_grass` in each
  field's green, over a ground that leaves no gap for the sky.
- **Round the grounds** (one MultiMesh a kind, `game/scenery.gd`): oak and dark broadleaf trees as cut-outs;
  hedgerows of `small_broadleaf` bushes with `grass_wispy`, `fern` and `grass_clumps` along the foot and a tree now
  and then (plants within 420 m, a dark bank beyond); at the parish field the village (`thatched_cottage` ×4, a
  `terrace_row` ×2) along a road with `street_lamp_tall`s, a dry-stone wall of `mossy_rocks`, `park_bench`es by the
  clubhouse, `painted_bench`es for the subs, and a lough beyond the village (`water_normal_512`, a cheap shader with
  a ragged shore); at the county ground and the stadium the town's terraced rows round the ends and beyond the far
  stand, street lamps outside.
- **Small things**: on Low the pitch's lines are drawn 18 cm wide (at three-quarter resolution 10 cm lines broke
  into dashes in the distance); the old code-drawn hills are gone (flat grey slabs against a photographed sky).
- **Credits**: Poly Haven (CC0) and the maker's models in Settings > About > Licences.
- **APK size**: the first 0.4.0 build was 43.8 MB (11.7 MB more than 0.3.0: compressed GPU textures do not zip).
  The skies are now kept as WebP (30-65 KB each instead of 1 MB; one is in memory at a time) and the fields',
  worn and withered grass scans capped at 512 px, the same to look at.
- **Performance** (`tests/perf_probe.tscn`, the busiest frame): stadium Low 77 → 87 draw calls, 67k → 82k
  triangles; Medium 95 → 105, 149k → 164k; High 168 → 178, 306k → 320k. Parish Low 77 → 91, 64k → 81k; Medium
  95 → 109, 125k → 141k; High 148 → 167, 234k → 263k. Low stays inside its budget of about 100.
- **Tests**: every ground dressed, nothing on the field or between the gantry and the field, a real sky, the
  surrounds a dozen draws at most, no hedgerow through the village. `tests/venue_view.tscn` now adds a wide shot of each
  ground; `docs/graphics/` has every ground on Low and High (TV, end, wide) and before-and-after sheets.

Moved or skipped, and why:
- **`skies/suburban_football_field`** (the plan's first choice for the county ground by day): its horizon is a
  German town's red-tiled roofs and wooded hills; the plan's alternative, `kloofendal_overcast`, is used instead.
- **`stands/bleacher_concrete` and `bleacher_metal`**: the crowd stands on the stands' and terraces' own steps
  (built in code, each person placed on a step); a model of a stand segment would need its steps measured to seat
  the crowd, and at the camera's distance the shared segment reads as a plain slab. The code-built stands stay.
- **The full-size tree meshes** (`oak_tree`, `broadleaf_tree_dark` and their `_low`): every tree is more than 25 m
  from the match camera, so cut-outs everywhere, as the shared README advises; **the buildings' and props' High
  meshes**: the village and the towns are 100-200 m off, so the `_low` meshes on every level.
- **The owner's `Hurling.Goal`**: a soccer goal; the game's posts are built to the rules.

## Done (0.4.1-beta, 23 October 2026)

- **The crowd faced the wrong way** (the owner: "the crowd to the near side is looking the wrong direction"): every
  spectator was a cut-out turned to the camera and always drawn from the front, so the stands the camera looks over
  (the near side under the gantry, and the end terraces from the End camera and the replay) showed faces turned
  away from the play. Now each person faces the centre of the field (their instance's +Z); the cut-out still turns
  to the camera, and when the camera is behind them it is drawn from behind (the back of the head; the sheet has
  each figure from both sides). Wrong before at every ground and level; tests: every spectator faces the field,
  from the gantry the near side is seen from behind and the far side from the front. `tests/venue_view.tscn` adds
  shots from the pitch at both stands and from behind the near one (`docs/graphics/crowd_low.jpg`, `crowd_high.jpg`).

## Done (0.5.0-beta, round five, 24 October 2026)

The owner's round-five list, item by item:

- **The menu's small print** ("fifteen a side, two halves, every rule" under the cover, and the line that no real
  players or competitions are shown): both gone. The disclaimer is not needed on the home screen; it stays in
  Settings > About > Licences and in the store listing, which is where a reader looks for it.
- **The fans** ("they just look like shapes"): the crowd sheet is now rendered from two fans made with Meshy (text to
  3D, refined, rigged, then baked onto the game's bones like the referee), each in four poses (still, clapping, an
  arm up, looking along the stand), from the front and from behind (`tools/crowd/render_fans.tscn`, writing
  `assets/crowd/sheet.png` and its shirt mask). Still one quad a person and one draw call a crowd; the shirt is
  tinted per person through the mask, so a home crowd still wears its county's colours.
- **The sliotar** (Meshy's preview was egg-shaped): made in code instead, a cream leather ball with grain and the
  raised stitched rim, two small meshes. **The floodlights**: a Meshy model (sixteen lamps in a frame; the first
  try came back as a bar, the second was right) on every mast and along the stadium's roof, aimed at the field,
  the glass lit warm white at dusk and at night. The old code-built lamp boxes are gone.
- **Replays after scores**: every score is shown again from behind the goal, as a wide was. **The still white ball
  in a replay** was the HUD's ball marker, still drawn from the match camera's view while the replay camera was on;
  the marks now follow whichever camera is drawing, and are redrawn each replay frame.
- **The run with the hurley**: two Meshy hurlers were tried (a hurley in hand was asked for both times); neither had
  a hurley and both wore an American-football helmet, so the owner's model stays and the run was fixed instead: the
  hurley is carried lower and in front (the hand at -42 degrees, blended in at speed), the free arm swings with the
  stride. Checked frame by frame in a strip of the sprint: the bas clear of the legs.
- **Buttons sooner after a switch**: switched to a man standing in the gold ring where a high ball comes down, CATCH
  and PULL are up at once (before, only once the ball was within reach); the ring is worked out the moment you
  switch. Pressed early, the catch or pull is kept and done when the ball comes into reach (or forgotten if he moves
  off or it does not come), and the button flashes to say so.
- **The referee and umpires**: Meshy models (a referee in black; umpires in long white coats), rigged, retargeted
  onto the game's 17 bones (`tools/player/meshy_map.tres`) and baked like the hurlers (about 4,200 triangles each),
  with a cel-shaded texture. The brand marks Meshy painted on their chests were cleaned out of the textures
  (`tools/player/people_textures.py`). Every signal plays on them as before.
- **The bench**: each side's eleven substitutes sit in a covered dugout on the far touchline either side of halfway
  (every ground), one baked seated model per side drawn as a MultiMesh (two draw calls). A substitute's seat empties
  when he goes on; the man taken off walks to the dugout and sits down.

Meshy: nine text-to-3D tasks (referee, umpire, two fans and the second floodlight refined; the referee, umpire and
fans rigged), each kept in `tools/meshy/tasks.json` with its prompt (`tools/meshy/meshy.py` fetches or rebuilds
them; the key is the session proxy's, never in the repository). The raw GLBs are not committed, only the baked meshes.

Perf (`tests/perf_probe.tscn`, the stadium, Low / Medium / High): 90 / 90 / 138 draw calls and 119,000 / 187,000 /
325,000 triangles (0.4.0: 87 / 105 / 178, 82,000 / 164,000 / 320,000). The benches add two draw calls and about
37,000 triangles at every level (22 seated men of the lighter mesh), the officials' models about 3,000 each; the
officials lost their outline pass, so Medium and High draw fewer calls than before.

`docs/graphics/round5.jpg`: the new crowd from the front (High) and from behind (Low), the substitutes in the parish
field's dugout, the referee and umpires signalling.

## Done (0.6.0-beta, motion capture, 24 October 2026)

The owner added the CMU Graphics Lab Motion Capture Database to the shared assets and asked each game to use it where
a real recording beats what it has. What the hurlers had: the Mixamo sprint and three Mixamo swings (motion capture
already), and, below about 5 m/s, legs drawn by sine waves with a stride from a formula. Off the ball a hurler walks
and jogs for most of a match, so that is where a recording helps most.

- **Now from CMU**: the walk (clip **35_01**, subject 35 "walk") and the jog (clip **35_17**, "run/jog"), one gait
  cycle each, retargeted onto the game's 17 bones by `tools/mocap/bvh_clip.py` (every bone turned at rest onto the
  game's stance the shortest way; the travel and heading taken out so the game stays the one writer of position;
  the hips' height set so the lowest the feet reach is the ground), 30 frames a second, `assets/player/cmu.json`
  (26 KB). `tools/mocap/fetch.sh` fetches the two BVH files from the GitHub mirror and rebuilds it; the BVH files
  are not kept. `Player.gait_pose` blends walk, jog and the Mixamo sprint by speed, each in step with the stride.
- **Foot locks**: the stride's length now comes from the recordings (`Player.stride_at`, measured on the drawn
  man), so the planted foot stays put: it slides 0.19 m/s walking at 1.3 m/s and 0.26 m/s jogging at 2.6 m/s
  (before, with the drawn legs and the old stride formula, the steps were a third too long). The Mixamo sprint's
  feet could only sit still at five steps a second, a whirl of legs; it now runs at a sprinter's 4.4 steps a second,
  and its foot slides 1.6 m/s at 7 m/s, half the 3.2 m/s it slid before.
- **Decided against**: the CMU baseball (124_07) and golf (63, 64) swings: the Mixamo swings the game has are the
  same strokes, already timed to the ball's contact and checked against it; a swap would gain nothing. Runs from
  subjects 09 and 16: the Mixamo sprint is as good and already in step. The throw-and-catch clips (33, 34, 141,
  143): an American football caught two-handed at the chest; a hurler's catch is one hand overhead, often in the air
  in a crowd, which none of them is. The sudden stops (16_08, 16_57) would need a stop the game's movement does not
  have (a man slows over a few strides). No clip for the solo, the hook, the block or the shoulder.
- Tests: each gait clip loads; the planted foot at the walk's and jog's speeds slides under 0.35 m/s, the sprint's
  under 1.8 m/s. Perf: the clips are sampled as the sprint was (no extra draw calls or triangles; the stadium on Low
  stays 90 draw calls and 119,000 triangles).
- Licences: "Motion capture data from mocap.cs.cmu.edu. The database was created with funding from NSF
  EIA-0196217.", with the clip ids.

## Done (0.7.0-beta, sounds, 24 October 2026)

The owner asked every game for better sounds from Kenney (CC0) and OpenGameArt (CC0, CC-BY, CC-BY-SA only). Before:
everything made in code but the crowd's reactions, the players' grunts and the music. Now (docs/SOUNDS.md has each
file's source, author and licence; `tools/audio/sounds.py` downloads, trims, levels, loops and encodes them):

- **The crowd**: a stadium crowd recorded live by Gregor Quendel (CC-BY 4.0): its murmur as the bed under the play
  (a 20 s seamless loop, louder in a bigger crowd), its cheer for a point and its roar for a goal, in place of the
  made ones.
- **The grounds**: birdsong (Thimras, CC0) round the parish field and, quieter, the county ground, by day and at
  dusk; none at the stadium (the crowd drowns it) or at night.
- **The game's knocks** (Kenney, CC0): hurleys clashing, the ball off the aluminium upright, on the grass, into the
  hand; a shoulder charge (new: the tackle had no sound); boots on grass for the man you play, louder as he runs.
  The menu click.
- **Pause**: the crowd, the birds and every sound now hold while the game is paused (they played on before).
- **Not found** (the owner might source them): a referee's pea whistle, the crack of ash on leather, an Irish crowd's
  chants. The made whistle and strike stay.
- Size: 300 KB of audio before, 596 KB after; the APK 39.65 MB before (0.6.0), see the release for after.
- Test: every file in assets/audio loads, every sound the game plays is there, the beds loop.

## Done (0.8.1-beta, the referee's whistle, 24 October 2026)

The owner found real whistle recordings (Pixabay, credited on Licences and in docs/SOUNDS.md; trimmed and levelled
in the shared assets). `Match._ref_whistle` plays them from the referee's position (quieter with distance, -12 dB
at 60 m), a take picked at random: a short pip for a free or a stoppage, a long blast for the throw-in and the end
of a half, the final whistle (short, short, long) at full time, a double pip when a substitute comes on; quiet
behind the home screen. The made whistle is only the fallback now. Not used: the gym take (hurling is outdoors).

## Done (0.8.0-beta, the size update, 24 October 2026)

The owner allows the APK to grow (to about 150 MB) for a better look and sound, with Low exactly as it was. Every
addition is a separate, sharper file that only Medium and High load (`Game.hd(path)`: "x_1k.jpg" becomes "x_2k.jpg",
anything else "x_hd.<ext>"), VRAM-compressed (ETC2/ASTC on phones) with mipmaps:

- **The pitch and fields**: Poly Haven's 2K scans (grass_ground albedo and normal, sparse, withered and leafy
  grass; the 1K files Low loads are the same scans at half the size).
- **The players**: hero_albedo_hd.jpg at 2048 and hero_mask_hd.png at 1024, from the owner's 4096 texture
  (`tools/player/make_textures.py`); **the officials**: referee_hd.jpg and umpire_hd.jpg at 1024.
- **The crowd**: four more Meshy fans (an older man in a tweed jacket and scarf, a red-haired teenager, a blonde
  woman, a bearded man; `tools/meshy/tasks.json` fan3 to fan6, about 140 credits), all six in four poses, rendered
  at 128 x 256 a figure into sheet_hd.png (24 figures, front above and back below) and its shirt mask (nothing above
  the collar: grey hair is as pale as a white shirt). `tools/crowd/render_fans.tscn -- hd`.
- **Sound** (for every level; sound is not video memory): the crowd's murmur 32 s and the birdsong 90 s before they
  loop (were 20 s), three cheers and three roars from the same recordings, picked at random (`Sfx.VARIANTS`), Vorbis
  quality 3.
- **Measured** (`tests/perf_probe.tscn -- <venue> <level>`, one level a run; video memory as the driver reports it):

  | | draw calls | triangles | video memory before | after |
  |---|---|---|---|---|
  | stadium Low | 90 | 119,379 | 40.1 MB | 40.1 MB |
  | stadium Medium | 90 | 186,813 | 57.3 MB | 75.5 MB |
  | stadium High | 138 | 324,507 | 68.7 MB | 86.9 MB |
  | parish Low | 93 | 118,253 | 40.7 MB | 40.7 MB |
  | parish Medium | 93 | 163,899 | 57.2 MB | 75.4 MB |
  | parish High | 131 | 268,883 | 68.3 MB | 86.4 MB |

  Draw calls and triangles the same at every level; Low's video memory unchanged.
- Test: Low loads exactly the files it did; Medium and High find a texture twice as sharp for each; the crowd on
  High has its 24 figures.
- Not done, and why: 4K skies (the gantry camera sees little sky), the High meshes of the cottages and terraces (100
  to 200 m off, the Low meshes look the same there).

## Next (in order)

1. **On a real phone**: the beta on a 2-3 GB Mali-G52/G57 phone (Galaxy A0x/A1x): frame times on Low (the dev
   overlay: tap the version seven times), heat, the buttons' size and place. The logic costs about 1.1 ms a frame on a
   desktop core (off-ball players re-plan where to stand seven times a second); a low-end phone's core is maybe
   four times slower, well inside a 33 ms frame.
2. **The full Official Guide**: read the rules against it once the network allows `www.gaa.ie` (docs/RULES.md).
3. **More frees and shots**: real matches have about 26 frees and 77 shots; the game about 17 and 70.
4. **Temporary substitutes** (blood, a head injury) and injuries, and the sin-binned player's replacement rules.
5. **Umpires who now and then get a close one wrong**, and Hawk-Eye at the stadium (as the real one has).
6. **Commentary-style call-outs** and crowd songs ("Come on the ...", "[County] abú!"), and a recorded referee's
   whistle and hurley strike (none to be had from Kenney or OpenGameArt: docs/SOUNDS.md).
7. **A native Irish speaker** to read `i18n/src/ga.json` (docs/LANGUAGES.md lists the terms to check).
8. **Camogie**, with its own rules done properly (60 minutes, the 45, hand-passed goals, its contact rules).
9. **Club hurling**: invented parish clubs in a county championship, at the parish field.
10. A stand model for the stadium and the county ground (a section with its seat rows at a known rise and depth, so
    the crowd can be seated on it), if the owner wants one: the only gap the graphics update left.
11. Goalkeepers in their own jerseys, and a number per man on the back (the owner's model, without the 11 in its
    texture, or a texture of numbers).
12. A hurler model with the hurley in hand, if a later Meshy model gets it right (two tries did not).

## Shared assets

Since 22 October 2026 the owner has made the orchestrator session (session_016XKAyHkTQRNMGEgZbjNK28) the lead for
all six mobile games. Assets that suit more than one game come from it: listed in `shared-assets/README.md` on the
branch `claude/shared-assets` (large files on the `shared-assets` GitHub release), each with its source, licence and
the games it suits. When one is meant for this game, a message says what it is and how to fetch it; check its
licence there before it goes into the game.

## Needs the owner

- Google Play: the developer account, the upload key (as the three repository secrets in PLAY_STORE.md), the closed
  test with 12 testers for 14 days, the store listing pasted in.
- Confirm in Play Console that Irish is not offered as a store-listing language (the research could not open
  Google's page).
- A native Irish speaker's read of the translation.

## Decisions, and why

- **Name: Hurling Heroes** (the owner's choice, round three; first released as "Ash & Leather", the "clash of the ash"
  on leather). A store search on 22 October 2026 found no app by that name. The slug `ash-and-leather` stays where
  changing it would cost something: the package (`com.ashandleather.game`, so a new beta installs over the old one and
  keeps the saves), the release tag and the privacy and help pages' addresses (linked from the game). Before the first
  Play upload the package can still be changed at no cost (`com.hurlingheroes.game`); after it, never.
- **Counties as places.** County names are place names, so they are used plainly, in English and Irish. No crests,
  no county-board jerseys (each county wears its traditional colours in one of the game's own four kit designs, no
  crest, no sponsor), no nicknames (fans' nicknames are tied to the county boards' marketing), no real competition
  names: the game's competitions are "the Summer Championship" and "the Tier Two Cup", run in the shape of the real
  senior championship (two provincial round robins of five, then the knock-outs) without its names.
- **Players are invented**: common Irish first names and surnames combined from a seed, with a block-list of
  well-known hurlers' names that are never generated; shown in Irish form in Irish, English form in English.
- **Languages**: English and Irish (docs/LANGUAGES.md); Play has no Irish listing, so en-GB is the default.
- **The look**: the match-day programme (cream paper, black and red print, a halftone sun) and the parish field at
  dusk, rather than Kabaddi's tiles or Takraw's arena navy. Uncial lettering for the name, a condensed face (Oswald)
  for headings, as programmes print them.
- **The clock** runs faster than real time while the ball is live (Settings > Match length, 14 minutes by default),
  the play at real speed; a dead ball costs its real time on the watch. The 35-minute length is the full 70 with the
  ball live as long as in a real match; a 70-minute real-time length was dropped (it is the 35-minute match with half
  an hour of waiting at restarts).
- **Substitutions** are made at a break (as a referee waves them on), by the manager unless you take them over;
  tiredness runs on the match clock so a short match tires players as a full one does.
- **Camera**: the broadcast gantry at the halfway line, panning and zooming, and a marker on the sliotar, because
  the ball is 7 cm across on a 140 m pitch.
- **ABIs**: arm64-v8a and armeabi-v7a in the bundle (Play serves each phone its own, so 32-bit costs 64-bit users
  nothing) because some 2-3 GB Galaxy A0x and other Android Go phones run 32-bit Android; the beta release has a
  64-bit APK and a separate 32-bit one.
- **The black card** in the Senior grade only (it does not apply in club hurling); the autumn 2026 third-level
  trial rules are not played (not in force).
- **Grade and draws**: a draw stands in a challenge match; a knock-out game goes to extra time and penalties.
- **No Meshy credits** were spent. The hurlers are the owner's own model (tools/player); the officials code-built.
- **The owner's model on the game's skeleton**, not the game on the model's: its mesh is skinned into the game's rest
  stance and its weights moved onto the game's seventeen bones, and the Mixamo clips are sampled into the game's own
  poses, so every hand-made pose (the solo, the catch, the officials' signals) plays on the new players unchanged and
  the clips could play on the old ones. Neither the 36.7 MB GLB (tools/player/build.sh fetches it) nor the Mixamo
  files (their terms allow them in a game, not handed out as they are) are in this public repository; the game
  ships only what is baked from them.
