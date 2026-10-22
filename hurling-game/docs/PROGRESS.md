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

## Next (in order)

1. **On a real phone**: the beta on a 2-3 GB Mali-G52/G57 phone (Galaxy A0x/A1x): frame times on Low (the dev
   overlay: tap the version seven times), heat, the buttons' size and place. The logic costs about 1.1 ms a frame on a
   desktop core (off-ball players re-plan where to stand seven times a second); a low-end phone's core is maybe
   four times slower, well inside a 33 ms frame.
2. **The full Official Guide**: read the rules against it once the network allows `www.gaa.ie` (docs/RULES.md).
3. **More frees and shots**: real matches have about 26 frees and 77 shots; the game about 17 and 70.
4. **Temporary substitutes** (blood, a head injury) and injuries, and the sin-binned player's replacement rules.
5. **Umpires who now and then get a close one wrong**, and Hawk-Eye at the stadium (as the real one has).
6. **Commentary-style call-outs** and crowd songs ("Come on the ...", "[County] abú!").
7. **A native Irish speaker** to read `i18n/src/ga.json` (docs/LANGUAGES.md lists the terms to check).
8. **Camogie**, with its own rules done properly (60 minutes, the 45, hand-passed goals, its contact rules).
9. **Club hurling**: invented parish clubs in a county championship, at the parish field.
10. A stand model for the stadium and the county ground (a section with its seat rows at a known rise and depth, so
    the crowd can be seated on it), if the owner wants one: the only gap the graphics update left.
11. Officials and goalkeepers in the owner's style, and a number per man on the back (the owner's model, without the
    11 in its texture, or a texture of numbers).

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
