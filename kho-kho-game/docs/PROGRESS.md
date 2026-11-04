# Kho Kho Rush: progress

The kho kho game, built overnight on 21-22 October 2026 on branch `claude/kho-kho-game`. Read this and
`git log` first when resuming.

## Done

- Project skeleton from Takraw Smash's infrastructure (Game/DB/Sfx autoloads, UI helpers UI.fit/shrink/bits/
  keep_on_screen, DragScroll, LanguagePicker, licences, loading screen, fit_audit, input_test, compile_check,
  CI workflows, export presets), with kho kho's own palette (red earth, chalk, marigold, dusk indigo) and display
  face (Baloo 2, Latin and Devanagari).
- Fonts: Noto Sans + Devanagari, Bengali, Gurmukhi, Gujarati, Oriya, Tamil, Telugu, Kannada, Malayalam, Sinhala,
  and Baloo 2, cut to their scripts with `tools/subset_fonts.py`: 2.4 MB for all twelve.
- The laws: `game/rules.gd` (KhoRules), pure, with a headless test for each rule in `tests/test_runner.gd`.
- The match (`game/match.gd`): four turns, batches of three, the kho hand-off, the direction and lane rules every
  frame, outs (touch, sky dive, pole dive, out of limits, late entry), fouls whistled until put right, dream runs,
  wazir and power play, follow-on, extra innings and minimum chases; chaser AI (chase / kho / pole) and defender AI
  (a threat field from the chase's reach); umpires, referee, timekeeper, scorer with signals; your controls.
- HUD (scoreboard, batch, clock, calls, interval, follow-on question, pause with Move buttons), touch controls
  (joystick, context buttons, sizes, left-handed, drag-to-move saved).
- Screens: home (one row of buttons over an AI match; until 0.3 a kho kho lane), match setup + toss, settings, how to play, records, result
  with box score, championships (world, to fast rules; national, to classic rules), licences, move buttons.
- Venues: village ground at dusk, school ground, indoor arena on mats, floodlit stadium.
- test_runner green: 319 checks (every law; screens in every language; scrolling text passes touches; championships
  of both kinds; AI matches in both rule books with the score checked against the outs and dream runs; a motion
  audit: no snaps, smooth speed changes; your own controls).
- All fourteen languages translated (subagents, each with a notes file in docs/translation-notes/ for a native
  speaker); fit_audit clean at 16:9, 19.5:9, 20:9 with a cut-out, and 4:3, in every language.
- The AI calibrated against real finals with tests/match_sim (docs/AI.md): ~2 outs a minute between equal sides
  (real 1.3-1.6), AI fouls ~0.3 a minute.
- Docs: RULES.md (every rule, source, conflicts), LANGUAGES.md, AI.md, MESHY_BRIEF.md, BETA.md, README with the
  perf_probe numbers.
- Store: PLAY_STORE.md, listings in en-US/en-IN/en-GB and eleven Play languages, the icon, feature graphic and seven
  screenshots rendered from the game. Pages in khamba-dash/.
- Music: raag Bhupali on a bansuri over keherwa; the crowd's dhol and thali in matches.
- CI green; beta APK on the khamba-dash-beta release; the Play bundle workflow passes (unsigned).

## Round two: 0.2.0-beta (21 October 2026)

- Played first as a phone tester would: the Web build in Chromium with touch (Playwright, `tools/playtest/play.js`,
  the game's `?playtest` state in `game/playtest.gd`), at 1280 × 720, 1600 × 720 and 2400 × 1080 on Low, both rule
  books, chasing and defending. Findings and fixes, worst first, in docs/PLAYTEST.md; a test for each fix.
- Coach tips (`game/coach.gd`) in all fourteen languages; fit_audit clean.
- The City League (`game/cup.gd` kind "league"; `DB.CLUBS`): eight invented city sides, a double round robin, the
  top four to the semi-finals.
- A pole turn (`Poses.POLE_TURN`), seated chasers' heads following the play (`Athlete.watch`), the chain game for
  defenders, the armed kho, the direction arrow.
- A new icon and a feature graphic without the HUD (`tests/screenshots.gd ... clean`, `tools/store/make_feature.py`).
- The rules re-checked (docs/RULES.md, "The 0.2 re-check"): the primary sources are still blocked; the foul now
  stands until a kho or a free zone.

## Round three: 0.3.0-beta (22 October 2026, the owner's list)

- Renamed **Kho Kho Rush**; the owner's icon artwork; the package is now `com.khokhorush.game`.
- The home menu in one row; Watch a Match has the pause button (Quit match); the toss coin has faces (a lion,
  and 1 in the language's currency); DODGE is a side-step that a touch mostly slips off.
- The owner's player model and six Mixamo animations in the game (docs/MODELS.md): decimated and re-baked
  (`tools/models/build_player.py`), retargeted from the T-posed FBX rig to the A-posed model
  (`tools/models/retarget.gd`), kit colours by a class mask baked in the texture's alpha.
- The grounds: a ground shader with grain, mottle and wear; a sky dome; hills; rain trees and coconut palms; houses
  with thatched and tiled roofs; light towers, a stand roof and stars; the hall's trusses and screen; the school's
  verandahs. The crowd is drawn from the players' model at load (seated, standing, clapping; cheering at an out).
- Triangles a frame fell (Low 38-46k, Medium 56-65k) though everything looks fuller; draw calls unchanged.

## Next

1. A native speaker's pass over each translation (docs/translation-notes/), and the rule-book conflicts in
   docs/RULES.md checked against a printed KKFI rule book (the rulebook sites were blocked from here).
2. A real phone at Low (a Galaxy A0x/A1x): frame rate, warmth, and whether the coach tips teach the game in a
   minute to someone who has never played it.
3. The City League's own season mode: squads that change, a player draft (a championship's own records - your
   stars, the most outs and the longest defence - since 0.12.11).
4. Defending feel: a juke button, and the AI's chasers reading your defender's runs.
5. Meshy models when the owner chooses (docs/MESHY_BRIEF.md).

## Decisions, and why

- **Name: Kho Kho Rush** (the owner's choice, 22 October 2026; the working title was Khamba Dash, "khamba" being the
  pole in Hindi and Marathi; the release tag `khamba-dash-beta` and the pages folder `khamba-dash/` keep their names so
  their links keep working). The working title was checked against Play by search: the existing
  apps are "Kho Kho Game", "Kho Kho 3D", "Kho Kho World Cup", "Kho.Kho" (the official world cup app); "Ultimate
  Kho Kho" is the league's brand. "Khamba Dash" turned up nothing. "Kho Kho Rush" has not been checked against Play
  from here; the owner should search Play for it before publishing. In the non-English listings the local name of
  the sport follows it in the title for search ("Kho Kho Rush: खो-खो").
- **Two rule books** as the owner asked: Classic (the national federation's) and Fast (the 2025 world
  championship's and the franchise league's). Details and conflicts in docs/RULES.md.
- **The fast field's squares**: sources give 22 x 16 m with 1.5 m free zones and 40 cm cross lanes, and seven
  attackers on the field; six seated in six squares at the classic spacing (2.55 m and 2.30 m) fits the 19 m between
  the poles exactly, so the game uses that.
- **A late kho** is whistled as a foul and does not stand: the giver has passed the seated chaser and cannot turn
  back, which is the real cost of it.
- **Shorter turns** (3 and 5 minutes) for phone play, with the real length (9 classic, 7 fast) a choice. The
  follow-on's 9-point lead scales with the turn's length (never below 3).
- **Rulebooks unreachable**: the environment's network proxy blocks the federation sites and Wikipedia, so the laws
  come from search-result excerpts of the cited pages, and every conflict between sources is listed in
  docs/RULES.md for the owner to check against a printed rule book.
- **Meshy**: no credits spent. Code-built bodies (game/body.gd) on the humanoid skeleton; docs/MESHY_BRIEF.md
  for later.
- **32-bit**: the Play bundle carries armeabi-v7a and arm64-v8a (Play gives each phone one; budget phones in
  Nepal, Bangladesh and India still run 32-bit Android Go). The sideload beta APK is 64-bit only, like Takraw's.
- **Languages**: see docs/LANGUAGES.md. All fourteen in the game; store listings in the Play-supported ones (Odia
  and Assamese have no Play listing locale).

## Round four: 0.4.0-beta, the graphics update (22-23 October 2026, from the lead's shared assets)

Built venue by venue from `shared-assets/plans/kho-kho-rush.md` (the files copied are in `assets/env/`; placed by
`game/props.gd` and `game/arena.gd`, each kind of thing one MultiMesh):

- **Village ground at dusk:** `qwantani_dusk_2_puresky` sky; `red_laterite_soil_stones` ground, worn along the lane
  and round the poles; `rain_tree`, `coconut_palm`, `island_tree_a`/`_b` and `dry_grass_tall`/`grass_clumps`
  cut-outs; the houses in `clay_plaster` under `thatch_roof_angled` and `clay_roof_tiles`; `monobloc_chair` under the
  crowd's front row; `scorers_table`; `painted_bench` for the teams.
- **School ground by day:** `qwantani_noon_puresky`; `dry_ground_01` with `sparse_grass` beyond the lobby; the school
  in `yellow_plaster`; pupils on `painted_bench`; `city_apartments` behind.
- **Indoor arena on mats:** `rubber_tiles` as the mats' grain; rows of `fluorescent_light`, lit.
- **Floodlit stadium:** `kloppenheim_02_puresky` (dimmed: the panorama is bright for a lit ground at night);
  `terrain_red_01`; the terraces in a photo-scanned concrete finish (`plastered_wall`); `city_apartments` on the
  skyline.
- Also fixed on the way: High graphics was overexposed. The Compatibility renderer lights far more strongly from a
  shadowed sun (the school's field 238 against 166), so High's sun is set to 0.18 of its energy when it casts
  shadows, which matches Medium.

**Moved or skipped, and why:**

- **Trees as cut-outs on every level**, not only on Low: every tree here stands 30 m or more from the camera, where
  the cut-outs look truer than the models (the rain tree's model looked faceted and yellow under the low sun). The
  tree models themselves were left out of the APK, as were the bleachers and the folding stool (not placed).
- **`bleacher_concrete` and `bleacher_metal` not used.** Their treads are uneven (generated models) and the crowd has
  to sit exactly on rows; the game's own terraces are kept, the stadium's given a concrete finish. The arena keeps its
  painted seating.
- **No HDR lighting files** (`*_light_1k.hdr`): the game lights with a colour ambient and its sun on every level, and
  each HDR is over 1 MB in the APK. The skies are panoramas only.
- **No surface normal maps:** from the broadcast camera's height they lit the ground unevenly; the albedo photos carry
  the grain. The normal files were left out of the game (0.7 MB each in the APK); the shared-assets branch has them.
- **Hills and haystacks removed:** they were code-drawn and looked cartoon next to the photographed sky.
- **Low keeps chairs only on the far side** (the light chair is 618 triangles; a full ring of 118 came to 73,000).

**The gap, filled in 0.4.1:** a **village temple** for the village ground. Neither free library had one; the owner
approved generating it in Meshy, and the lead added `buildings/indian_village_temple` to the shared assets. It
stands at the far edge of the ground between the houses, its porch facing the field, a rain tree beside it and three
chairs in its forecourt (village on Low: 85 draw calls, 69k triangles). This game spent no Meshy credits itself.

Pictures of every ground on Low (left) and High (right), from the match camera and behind the menu:
`docs/img/grounds-0.4-low-high.jpg`, `docs/img/menu-0.4-low-high.jpg`.

Performance, Low (the phone budget is 90 draw calls and 90,000 triangles): village 73 → 85 draw calls and 40k → 69k
triangles; school 73 → 80 and 39k → 38k; arena 82 → 82 and 46k → 46k; stadium 73 → 77 and 38k → 39k. All in the
README.

**0.4.2-beta, the crowd facing the play (23 October 2026, the owner via the lead).** The crowd is billboards: every
card turned to the camera, and until 0.4.1 every card showed a person from the front. So the people between the
broadcast camera and the court (the village's and the school's near-side crowd, at the near corners) looked at the
camera, their backs to the match; and the stands at the ends, seen from the court, faced wherever the camera was
rather than the court. All four grounds, on all three graphics levels. Now each spectator has a facing, from his
seat toward the court's centre (flattened to the ground), as his instance's +Z; the sheet has two more rows, the same
eight people drawn from behind; and the shader shows the back when the camera is behind him. A test checks every
spectator's forward against the direction to the centre (dot product over 0.7) at every ground on Low, Medium and
High. Seen from a camera on the court looking at each stand, and from high behind the near side:
`docs/img/crowd-facing-0.4.2.jpg`. No change to draw calls or triangles (the same one quad per person).

## Round five: 0.5.0-beta, motion capture (24 October 2026, the owner via the lead)

The owner added the CMU motion capture library and asked each game to use real recorded movement where it beats what
it has. Here six of the players' movements were already recorded (the owner's Mixamo run, dive, reach, turn, kneel
down and kneel); what was not was the dodge (the run clip, the body swung round to the new direction) and standing
still (one held pose, frozen). Those two are now mocap, from **CMU 127_11** (a running cut, the outside foot planted;
mirrored for the other side) and **CMU 77_02** (standing at ease, looped). Everything else in the library was weighed
against the game and left out; docs/MODELS.md says what and why for each. The clips' travel over the ground is taken
out (the movement system still writes every position), planted feet are locked with two-bone IK, and the clips are
stored compressed: 22 KB between them. Credited in the Licences screen. New tools: `tools/models/bvh_to_json.py`,
`tools/models/retarget_bvh.gd`; the BVH files are not committed.

Also fixed on the way: after a mirrored act (a pole dive round the other side) a player kept running mirrored, his
shirt's number reversed; the mirror now ends with the act.

Performance (perf_probe, before and after, every ground on Low, Medium and High): draw calls and triangles unchanged
(Low: village 88 and 69k, school 83 and 38k, arena 84 and 46k, stadium 80 and 39k). The milliseconds a frame on this
machine's software renderer were lower after, by run-to-run noise, not by the change.

**0.7.1-beta, real whistles (24 October 2026, the owner via the lead).** The owner found recorded pea whistles (Pixabay;
the lead cut and matched them on the shared-assets branch). They replace the synthesised ones, used as RULES.md has the
officials use them: the timekeeper's long and short at a turn's start and long at its end (from the table), the
final whistle as the last turn's, one short pip from that half's umpire for an out, pips every 0.32 s until a foul is
put right, the gym's take for every long blast in the hall. Random takes, in 3D from the official on their own players
(a footstep cannot cut one short), silent in the menu's backdrop match. docs/SOUNDS.md has each file and its credit.

## Round ten: 0.10.0-beta, the owner's playtest list (27 October 2026)

Thirteen notes from the owner's own play: Licences, Help and Privacy as screens in the game (0.9.3, the lead's
request too); the pole turn, from a video of real chasers; dives that land; tags that slip explained, seen, and
set by difficulty; the camera button; difficulty in both menus; the crowd following the play and roaring at the big
moments; the kho's sound and quieter birds and crickets; and the home screen's "real rules" line gone. What was
measured: docs/AI.md, "The pole turn" and "Tags that slip".

## Round nine: 0.9.0-beta, the grounds dressed as at the real matches (25 October 2026, the owner's request)

The owner asked for both matches to be watched in full (tactics late in a turn) and for their surroundings to be
looked at for the outdoor grounds. The play does not change with the clock, only with how many of a batch are left;
three AI changes were tried against it and none kept (docs/AI.md, "Watched again"). The surroundings: barricades,
tents, flags, banners, a stage, temporary lights and a crowd in everyday clothes. All of it is now on the village,
school and stadium grounds, built in code with no draw call more (docs/GROUNDS.md).

## Round eleven: 0.11.0-0.11.1-beta, the foundation, a diving tag, Watch AI (2 November 2026, the owner via the lead)

- 0.11.0: the World Stage Games foundation pilot (Foundation session, PR #17) merged into the beta. To sync it later:
  `tools/wsg/sync_foundation.sh`, and set `loco.cut_from_heading = true` in the same change, or the glide returns.
- 0.11.1: the dive as a diving tag, one arm reaching for the runner's leg, the other bracing (`ModelBody.DivePose`,
  `Athlete._aim_reach`, `Match._touches` locking the hand where it touched); the get-up through hands, a knee and a
  crouch, the hips only rising (`DivePose` limits them as Kabaddi Raid's `_limit_height` does). `tests/dive_view.tscn`
  with `KK_TARGET=1` films it at a runner; test_runner checks the hand reaches the leg and the hips never dip.
- Watch AI: the home screen's entry (MENU_WATCH, "Watch AI" in 14 languages), the broadcast camera, replays,
  pause and leave, and 1x / 2x (`Match.toggle_speed`, `Engine.time_scale`, back to 1x paused and on leaving).
- The 17 clips in `assets/models/anims/` (Mixamo-derived) left the public repository: kept in the private
  `world-stage-games-assets` (`kho-kho/mixamo-anims/`), fetched by `tools/fetch_anims.sh` in all three workflows;
  without them the game builds and runs and their tests are left out. Rewriting the history to remove them from
  every commit is prepared (a dry run removes them from both Kho Kho branches) and waits on the owner's own word.

- 0.11.2 (the owner's playtest list and the lead's camera bug): the stick is read through the camera at your
  player (`Match._stick_map`, eased over 0.2 s; `stick_world` / `world_to_stick`, used by the chaser, defender,
  DODGE, the pole turn and match_sim's bot); test_runner checks up, right, down and left within 10 degrees in every
  view. TAG (`Match._tag`): a standing reach for the nearest defender, BTN_TAG / CTRL_TAG in 14 languages, the
  third button (slot 2, so saved places of KHO and DIVE stay). Your defender is never auto-played (`_user_auto`
  only with `autopilot`, which match_sim sets). Bodies are solid (`Match._separate`, `_push_apart` capped at
  6 cm a frame) and runners steer round seated chasers and the chaser (`_avoid`, a 2 m look-ahead). A reach on the
  move walks or runs from 0.5 m/s (it slid on the standing clip), and `ModelBody.rate_for` goes down to 0.3 so a
  slow walk's feet keep to the ground. Crowd: stand spots at the step's front edge (`SEAT_BACK`), the school's
  barricade children standing on the grass; a new crowd loop without the chant; school birds 4 dB quieter.

- 0.11.3: match_sim showed 0.11.2's half-each push between the chaser and a defender cut classic outs from 1.52 to
  1.18 a minute (10 matches; with only that push off, 1.62). The chaser now gives way entirely; defenders no longer
  steer round him; his give-way is at most 3 cm a frame (smooth speeds). After: classic 1.35 (real matches 1.3-1.6),
  fast 1.66.

- 0.12.0 (the owner's crowd rule, via the lead): the foundation synced to b6fdb87 (cut_from_heading kept true).
  `game/venue_crowd.gd` declares every ground's crowd as WsgCrowdVenue sections (the stands' steps, the far chairs
  or benches, standing rows behind the barricades, the scaffolds, the village stage, the near side), the same
  measures Arena builds them to; Arena draws them as WsgCrowdCards (main and near side: two draw calls, as before)
  and puts the chairs and benches under the placed seats. `game/crowd_venues.gd` registers all 16 (4 grounds x
  main/near x Low/High) for `tools/wsg/crowd_audit.gd`: all pass, and CI runs it. The game's own Crowd now only
  keeps its statics (the play it watches, its clothes).

- 0.12.1: foundation synced to 5914b7c (cut_from_heading kept true): the cards pick among every fan who fits a
  seat (`cards.fan_weights` doubles the three men), looks recolour only skin and hair; `WsgFootFlat.attach` after
  the locomotor in FoundationLink (the sole tilt printed once in the log).

- 0.12.2 (the owner's list): Athlete._finish_act ends a reach (it never did: the arm stayed out); Game.play_match
  under WsgLoading (foundation edebcd5) for every Start, the match built in steps (match.staged: build_ground,
  build_players, build_rest); touches: TOUCH_AHEAD 0.45 / TOUCH_R 0.42, a slip within CONTACT 0.62 m at
  CONTACT_SLIP 0.55, SWERVE_TOUCH 0.9 (cap 0.93), a slip played as the dodge clip (match_sim 20: classic 1.46,
  fast 1.57); pole dive: POLE_REACH 1.6, the reaching elbow bent (ModelBody.dive_bend); TouchControls ignores a
  saved place that overlaps; foul whistle FOUL_REMIND 2.5 s; no out replays; school birds -26 dB; _bench_pos in
  front of the benches.

- 0.12.3: foundation synced to 2cd59a7 (WsgLoading v2; cut_from_heading kept true): ld.warm on the match, await
  ld.done() (frames settled), then match.kick_off() starts play (match.live); the home screen prewarms the match's
  files (main_menu.PREWARM). Desktop, Low, cold: overlay up in 44-54 ms; longest frame 157 ms at the village (was
  644 ms), 106 ms at the stadium.

- 0.12.4: foundation synced to a24408b (cut_from_heading kept true). Arena.solid (WsgSolidProps) declares every prop
  where it is built (poles, the table and its canopy, benches, barricades, tent, umbrella, scoreboard and flag poles,
  the second court's poles, stands, ad boards, the stage, its truss and speakers, lamp towers, scaffolds; scenery
  beyond skipped with its reason). Athlete.integrate: push_out every frame; a body with a goal (an outed defender to
  his bench spot, free_spot) moves with solid.move. game/prop_runs.gd registers the four grounds for
  tools/wsg/prop_audit.gd (CI, 2 seeds x 120 s): 0 bodies inside a prop.

- 0.12.5: foundation synced to 877bcd9, then 7239d54 (cut_from_heading kept true). The owner's notes as tests
  (ADOPTING 5.16): tests/owner_notes/ (14 notes and INDEX.json, tests/note_kk.gd), CI runs
  tools/wsg/owner_notes_guard.sh and the strict run. Fixes the notes found: TouchControls.layout checks a saved
  place against every other button; Match.stick_map_at: up the screen at the player, right halfway between the
  screen's right and square to up; a dive that touches stops LOCK_AHEAD (0.8 m) short of the touch
  (Match.dive_touch_at, DIVE_TOUCH_R); Match._separate pushes a runner fully out of a kneeling chaser (at most his
  own frame's run). WsgSim (ADOPTING 5.17): game/sim.gd (the old numbers-only sim is game/score_sim.gd, class Sim),
  .github/workflows/kho-kho-sim.yml (smoke on push; 16 nightly shards; [sim-nightly] in a push's message runs the
  nightly until the game is on the default branch), rng_lint clean (cosmetic rolls marked), determinism (2 seeds,
  and 3 at real time) the same frame for frame. First find: a defender back on the field kept his walk-to-bench goal
  (Match: goal cleared as a batch comes on); adopted into tests/sim_cases.json. The rules check remembers an out
  only through a turn's play. Classic outs 1.50 -> 1.36 a minute after the note fixes (fast 1.74 -> 1.77): flagged
  to the lead for the owner, not retuned.

- 0.12.6: foundation synced to 888e222 (cut_from_heading kept true; one footstep per footfall 9c461ca, feet within 2 cm
  8dc70d9/d4e3107, the toe kept planted 63b8d62). The world check (game/world.gd, ADOPTING 5.18) replaces the build's
  crowd and prop audit steps; the release gate (5.19) runs before publishing. Sfx.key (WsgAudio): whistles and the kho
  slap crisp at a distance. WsgSim: pole turns' arms excused (pose_excuse); foot slip deferred to 2026-11-06 by the
  lead (planter slips under kho kho's AI, foundation fix pending). Balance runs: .github/workflows/kho-kho-balance.yml.

- 0.12.7: Match._separate pushes a runner out of a kneeling chaser by his run toward him only (the whole frame's run
  gave 13 m/s on fast seeds 279 and 298; both replayed in kho-kho-sim.yml's checks). The arena's far ad boards are three
  panels with openings (Arena.board_gaps) and Match._route walks through them; an out defender sits only at his bench
  and stopped. WsgSim bounds follow each venue's barricades (the arena's stands' front rows). Foundation synced to
  13f00e2 (cut_from_heading kept true; a flat foot planted however the clip moves it). The foot-slip deferral stays:
  the smoke still reads slips of 2.5-20 cm (sent to the foundation).

- 0.12.8: foundation synced to 80420f6 (cut_from_heading kept true; 68a16daa: no low foot jumps over 25 cm in a frame,
  a stop from a sprint 88 -> 12.6 cm). WsgSim: a touch or kho reached for on the run excused (the foundation: a designed
  move). FoundationLink notes why each frame's drive ran (trace_why, trace_dt) and its layer how often it ran, for the
  diag of the running A/T-poses (sent to the foundation).

- 0.12.9: fast format SWERVE_TOUCH_FAST 0.912 (classic SWERVE_TOUCH 0.9 unchanged), the owner's call of 2026-11-03 (about 1.6
  outs a minute from 1.74). Balance run 41685649140, 200 matches a cell, 95% CIs: classic 1.45 +- 0.05; fast 1.63 +- 0.05,
  fast without the tune 1.67 +- 0.05 (-0.04 +- 0.03 paired: the day's other fixes had brought most of the drop). WsgSim
  adapter: no body active under a replay, a replayed pose excused (the T/A-poses after a pole turn, random 29's stuck
  chaser). Foundation synced to d70ac7d (the 11-06 feet batch; no pose read under a replay; walker_low: Low's ModelBody
  measured, its feet slipping 3-14 cm - deferred to 11-08). Safe release publish (ADOPTING 5.19). No nightly schedule
  (the owner: simulations in rounds). The release gate's "newer" only on a publishing build.

- 0.12.10 (0.12.9 built but not published: the world check's pose rule caught a T/A-pose in watch AI): foundation synced to
  0387e39 (7def933a planter; WsgWorldGame.pose_excuse 8c35417b). world.gd pose_excuse: only while the pole turn plays and a
  hand is within 0.25 m of the pole (the lead's ruling), every pose asked about printed (WORLD_POSE). Low: the foundation's
  planter on ModelBody's own skeleton (bone_map, contact_fn by the model's rest ankle and toe heights), only on bodies in
  the play or within 15 m of the camera - feet_low worst slips 3-14 -> 0-2.1 cm, run skid 9.4 -> 0.2, sqrt cadence kept; its
  own cost 0.3-0.5 ms a frame for 18 bodies (tests/low_planter_bench.gd). Published in place (no -next tag: the 403s).
  The deferral: any foot slip to 11-06 12:00, then a planted slide up to 2.5 cm to 11-13.
- 0.12.11: a championship's stars (Cup.stars: your side's outs added up and longest single defence over the matches you
  play, saved with it; Cup.top_stars; the hub's "Your stars"; CUP_STARS in all 14 languages; tests in test_runner and
  the fit audit with long names). Records names a league title as the City League. Owner notes run on a fresh install
  (XDG_DATA_HOME, WSG_NOTES_FRESH). Foundation 5c2304e/a40a95e (planter: afresh after an idle, a stepping toe 3.5 cm up,
  a planter's time every tick since its last run) - Low's stop 1.7 cm. A Medium/High "planter off through the pose's
  fade" try (2c2f85a, then keep_pose) changed none of the defenders' 25-33 cm jumps (they are not in the fade) and was
  reverted (the lead): the foundation's 3b700012 fixes 7 of the 9; it waits on a Low regression fix before it is synced.
- 0.12.12: foundation 31f60da (3b700012: a released foot's catch-up rate-limited on a hard start, 7 of the 9 defender
  jumps gone; 31f60da3: not under a game's contact_fn, so Low's feet equal a40a95e's - stop 1.7, walk 1.5 cm).
- 0.12.13: Records.add_match returns the records a match broke (only a best that stood before; your side's only);
  the result screen names them under the score (REC_NEW in 14 languages; test_runner._new_records; the fit audit
  with all three broken and long names).
- 0.12.14: foundation 8c87df4 (b91fadce + fd879f98: 9ad1c8ab's touch band let a standing official's idle foot
  hover 3.8 cm unplanted and shrank on the 0.95-scaled defenders; the foundation's local smoke on 9406eac: slides >2.5
  21 -> 13). Low unchanged (feet_low stop 1.7, walk 1.5 cm).

## Round eight: 0.8.0-beta, defenders learned from real matches (24 October 2026, the owner's request)

The owner sent two real matches (full 9-minute turns, filmed from behind a pole) and asked the game to learn from
them. They were watched a second at a time; what they showed and what changed is in docs/AI.md, "Watched". In
short: defenders out of danger stand and watch rather than jog about (now 76% of their safe time standing, from
52%); classic outs came to 1.38-1.65 a minute (real close finals 1.3-1.6). A chaser with a foul now puts it right
first, and a foul's bar that stayed on screen after a long foul is fixed. The footage is not kept in the repository.

## Round seven: 0.7.0-beta, a bigger APK for Medium and High (24 October 2026, the owner via the lead)

The owner allowed the APK to grow (to about 100 MB, India first) to look and sound better, on two conditions: Low
exactly as it was, and the extra detail on Medium and High as separate, VRAM-compressed files. Spent, in the lead's
order:

1. **The ground and the players.** The four grounds' photos at 2k (Poly Haven's own, CC0; the 1k stay for Low).
   The players: the owner's source texture (4096 px) baked again at 2048 px onto `player_lod0`'s UVs
   (`tools/models/bake_hd_texture.py`; the model is not rebuilt, so Low's mesh and 512 px texture are untouched).
   Faces, lettering and the kit's folds are visibly sharper close up. The walls' and roofs' 2k photos were tried and
   dropped: they are drawn from far off, where the GPU samples small mip levels anyway, and they were 13.6 MB.
2. **The crowd.** Sixteen people in the sheet on Medium and High (Low keeps its eight, drawn as before): six skin
   tones, four colours of shorts, five heights, eight turns, standing ones clapping, still, or held at different
   moments of the recorded idle. The sheet is drawn again (or painted at once, then drawn) if the level changes.
3. **The sounds.** The crowd's murmur 13 → 23 s and the school's birds 19 → 59 s before they repeat; two takes of
   the cheer, three of the applause (docs/SOUNDS.md).
4. **The skies** at 4k on High: Poly Haven's tonemapped photographs (CC0), their colours matched to the 2k ones
   (`tools/env/make_sky_4k.py`), so the sky is the same, only sharper.

`tests/perf_probe.gd` now prints the video memory in use, and `KK_GFX=n` runs one level per process so each level's
memory is its own (the figure below is with all four grounds loaded, the most a session reaches):

| | Low | Medium | High |
|---|---|---|---|
| Video memory, before → after | 47.8 → 47.8 MB | 77.2 → 85.8 MB | 88.3 → 100.9 MB |
| Draw calls and triangles | unchanged | unchanged | unchanged |

The APK, both architectures and unsigned (local): 80.4 → 112.9 MB; the beta's (64-bit ARM): see the release. A test
checks Low still loads the 1k photos, the eight-person sheet and the 512 px texture, and Medium and High the new ones.

## Round six: 0.6.0-beta, recorded sounds (24 October 2026, the owner via the lead)

The owner asked every game for better sounds, from Kenney's packs and OpenGameArt (freesound and pixabay block cloud
servers). Before: the whistles, the kho's slap, the whoosh, the click and the crowd's murmur were synthesised (the
murmur was filtered noise); there were no footsteps, no sound of the place, and a pause left the crowd and drums
playing. Now (docs/SOUNDS.md lists every file, its source, author and licence; the Licences screen credits them):

- **Footsteps**, from each runner's feet in 3D, two to each stride as the run or walk clip plays: on earth outdoors
  (Kenney's grass), on the hall's mat (Kenney's carpet). Not in the menu's backdrop match.
- **The kho's slap** (CGEffex, CC-BY 3.0) and **a dive's landing** (Kenney), where it happens.
- **The crowd**: a real stand's murmur, looped, and a cheer (Gregor Quendel, CC-BY 4.0); applause (eXpl0it3r, CC0).
- **The place**: crickets at the village's dusk and, quieter, the stadium's night (Wolfgang_, CC0); birds at the
  school's noon (Thimras, CC0); in the hall, a little reverb on the match's own bus.
- **The menus' click** (Kenney). **A pause** holds every sound playing, and starts none on the field.

Made by `tools/audio/make_sfx.py` from the sources: cut, mono 22,050 Hz, one-shots set by peak and swells and beds by
their average, beds crossfaded into seamless loops, Ogg Vorbis. Chosen by measurement (length, loudness envelope,
brightness, low end), not by ear: this machine has no speakers, so a listen on a phone is still owed. 18 files,
`assets/audio` 380 → 752 KB; the APK +293 KB (both architectures, unsigned: 80,130,505 → 80,423,493 bytes). Draw
calls and triangles unchanged. The test (`_sounds`) checks every referenced file is there and loads, the beds loop,
every sound played by name is made, and a pause holds them.

Not found, for the owner (docs/SOUNDS.md): a real referee's pea whistle, the chaser's "Kho!" call, an Indian crowd
(chants, dhol, whistles), a recorded "ooh" and groan, an Indian city at night.

## Shared assets (from 22 October 2026)

The owner made the orchestrator session (`session_016XKAyHkTQRNMGEgZbjNK28`) the lead for all six mobile games.
Assets, or links to them, that suit more than one game come from it: each is listed in `shared-assets/README.md` on
the branch `claude/shared-assets` (large files on the `shared-assets` GitHub release) with its source, licence and the
games it suits, and a message from the orchestrator says what has arrived and how to fetch it. Check that list
before making or ordering an asset this game could share.

## Needs the owner

- Play Console account, the upload key secrets (store/PLAY_STORE.md), and a native speaker's check of each
  translation marked in docs/LANGUAGES.md.
