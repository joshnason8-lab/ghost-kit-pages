# Progress

The working log for Netball Unleashed: what is done, what is next, and the decisions made along the way with the
reasons. Anyone picking the work up (after a usage limit, a restart, a context summary) starts here, then reads
`git log`.

## State

- Branch `claude/netball-game`, folder `netball-game/` (self-contained Godot 4.7.2 project), pages folder
  `netball-unleashed/`, workflows `.github/workflows/netball-android.yml` and `netball-play-bundle.yml`.
- Version 0.4.2-beta. Draft PR #4 (https://github.com/joshnason8-lab/ghost-kit-pages/pull/4); beta release
  https://github.com/joshnason8-lab/ghost-kit-pages/releases/tag/netball-unleashed-beta.

## Done

- Research: the Rules of Netball (World Netball, 2024 edition, current in October 2026) and the leagues' variants;
  the markets and their languages. Notes behind docs/RULES.md and docs/LANGUAGES.md.
- Project scaffold from Takraw Smash's infrastructure (UI helpers, drag scrolling, fit audit, input test, perf probe,
  loading screen, licences, sound synthesis, the auto-graphics and frame-rate logic, the dev overlay from Kabaddi).
- The rules module `game/rules.gd` (pure functions) and `game/court.gd` (the court's geometry).
- The match: 14 code-built players (women's bodies, dresses, bibs with letters from one atlas), two umpires who move
  along their side lines and signal, the ball, three venues, the broadcast camera, the HUD with a netball
  scoreboard, touch controls with movable buttons, the AI for both teams, the umpires' calls, box score.
- Screens: home (court-shaped menu, bib rail), quick setup (team sheet), settings, how to play (four tabs, the
  positions with area maps), result with box score, Nations Cup, records, licences.
- Tests: test_runner with a check for each rule, the rules in play, the cup, controls and motion.
- League options: the Double Zone, time-outs (90 s, two a half, after a goal) and rolling changes.
- CI: the Android build (tests, fit audit, input test, APK, beta release) and the Play bundle (unsigned; target API
  36, min 24, only VIBRATE, isGame, 16 KB pages: all checked) pass.
- Store: PLAY_STORE.md, English listings (6 regional), icon, feature graphic, 7 screenshots; pages; README; BETA.md;
  MESHY_BRIEF.md; synthesized menu music.
- All 19 languages in, 301 strings each, fit audit clean at four screen shapes; store listings in af, zu, sw,
  ms-MY, zh-CN, si-LK, ta-IN besides the six English ones. (The usage limit stopped work at about 07:45 UTC; it
  resumed at 09:48.)
- Umpires warn and suspend (R6); injury stoppages hold time (R10).
- Round two (0.2.0-beta): the Web build played by touch in Chromium at three phone shapes (docs/PLAYTEST.md) and
  its findings fixed with tests (pause button, Back/Esc, language list, pass target, key hints, interval screen,
  name tags, home art); the coach's tips for a first match; the umpires advance, escalate and order off; the
  Umpiring setting (AI penalty rate); the Club Season (eight invented clubs); the rules re-checked (rule numbers,
  on-the-line offside, simultaneous infringement, ET interval) with what is still blocked recorded in RULES.md;
  339 strings in all 19 languages, fit audit clean.
- Round three: the players are the owner's own model (game/hero_body.gd, baked by tools/player/build.sh), running
  with the owner's Mixamo Fast_Run (shared with Hurling) and the model's own Walking and Running, locked to the
  stride; tests/player_view.tscn shows it up close.
- Round three (0.3.0-beta): renamed Netball Unleashed (package com.netballunleashed.game), the owner's artwork as
  the icon and feature graphic; the players are the owner's 3D model with the shared Fast_Run (tools/player); the
  venues relit and rebuilt (game/venue_look.gd); one white line between the home screen's competitions.
- The graphics update (October 2026, the lead's shared assets, plan `shared-assets/plans/netball-unleashed.md`):
  every venue realistic. The hall: a community sports hall by day (maple floor with the other sports' lines, block
  walls, pads, high windows, trusses and fluorescent lights, FIBA-size basketball boards built from primitives in
  place of the old back-wall hoop, doors, clock, fire alarms, exit signs, wet floor sign, gym and painted benches, a
  stepped stand of blue tip-up seats with a league crowd in its front rows). The outdoor court: a park court under
  Poly Haven's netball-court sky, green acrylic on asphalt, chain-link fence, park benches, street lamps, trees as
  cut-outs, terraced houses, the street hoop next door. The arena: a painted sprung-timber court (the maple grain
  under the paint) and, on Medium and High, sections of the owner's metal stand as courtside seating with people
  in its seats. The models are baked by tools/venue/bake.gd into one mesh and one atlas per venue (VenueProps, one
  draw call). Credits in Settings > About > Licences. Store screenshots refreshed.

## Next

1. Native speakers' review of every translation (docs/translation_notes/), the lower-resource languages first; the
   0.2 strings are listed under "Added in 0.2" in each.
2. The non-English store listings: add the Club Season and the coach (the English ones have them).
3. A home-and-away Club Season (14 rounds) as an option, and a finals series with a second chance for the top two.
4. The after-goal tactical change (2024) on request; the without-ball obstruction signal drawn.
5. A phone test on a Mali-G52-class phone; trim crowd/render scale if Low drops under 30 fps.
6. The umpires as a model too if the owner wants (docs/MESHY_BRIEF.md); the upload key and the closed test (store/PLAY_STORE.md).
7. Open the rules PDF when the network allows and settle the items in RULES.md "Still unconfirmed".

## Decisions

- **Name: Netball Unleashed** (slug `netball-unleashed`, package `com.netballunleashed.game`), the owner's choice
  (round three, October 2026); a web search found no game of that name. The game was Centre Pass Netball until 0.2;
  the rename came before any Play release, so the package could still change (0.2 beta installs do not upgrade in
  place: uninstall the old one).
- **Rules edition: World Netball Rules of Netball 2024**, in force since 1 January 2024; no 2025 or 2026 edition (a
  minor review is under way for 2027). So: no toss-up (simultaneous infringements go to the team last in
  possession), cautions replaced by warnings and suspensions, a goal counts if released before the whistle.
- **Toss-up not implemented**: it no longer exists in the 2024 rules.
- **Intervals 4, 12, 4 minutes; extra time 2 × 7 minutes with a minute between, then on to a two-goal lead**: the
  2024 rules (the "3/5 minutes" often quoted is old). The game shows the interval's real length and lets you skip.
- **Quarters default to 5 minutes** for a phone session, with 8, 10 and the real 15 on offer. The clock runs on
  through goals and restarts, as in the real game.
- **Infringement rate**: real elite teams concede 50-58 penalties a match. The AI concedes about a third of that
  rate so the game is not all whistles; the rate is in game/ai.gd `_slips`.
- **Women's netball only**: men's and mixed netball use the same rules (only line-up limits differ in mixed), but the
  owner's brief and the market are women's netball; mixed can come later.
- **League variants under invented names**: the Double Zone (a two-point zone 3.0-4.9 m from the post in the last
  five minutes of each quarter, as Australia's and England's top leagues play it).
- **Languages**: English plus 18: Afrikaans, isiZulu, isiXhosa, Sesotho, Setswana (South Africa, the biggest player
  base), Chichewa (Malawi), Luganda (Uganda), chiShona (Zimbabwe), Kiswahili (Kenya, Tanzania, Uganda), Malay and
  Chinese (Malaysia, Singapore), Sinhala and Tamil (Sri Lanka), Welsh, Te Reo Māori, Tongan, Samoan, Fijian. Most
  netball phones are set to English, so the globe button matters; Android 13+ also lets players pick the app's
  language. See docs/LANGUAGES.md, and docs/translation_notes/ for what native speakers should check.
- **Northern Ireland's flag**: no official flag exists, so the game draws a neutral green field (game uses flags
  only where they are official).
- **armeabi-v7a**: the Play bundle includes 32-bit ARM as well as 64-bit, for the older phones common in Malawi,
  Uganda, Zambia and Zimbabwe; the sideload beta APK is 64-bit only, as Kabaddi's and Takraw's are.
- **Workflow use**: round one's 18 translations were run as one multi-agent workflow, a choice made on my own for
  speed overnight. The owner has not opted in to workflows, so round two used three translator subagents instead.
- **Club names** (round two): invented city + nickname, checked by web search against the top leagues of the four
  countries; "Sunbirds" clashed with a South African league team and became the Strelitzias; Kestrels and Kāhu,
  each close to a team in the same country, became Brolgas and Kārearea.
- **Coach**: tips rather than a scripted tutorial match, so a first-timer plays a real match from the first tap; each
  tip shows once, when its moment comes, and the tips stop after the first full match.
- **Before every push** (the owner's request, round two): run locally what CI runs (check_scripts, test_runner,
  the full fit audit, the input test, the perf probe and a Web export), so a push fails CI only for what cannot be
  caught here (the Android export and signing). The Android build runs on `push` only (no `pull_request` run of the
  same commit), so one failure sends one email.
- **The players are the owner's model** (round three, the owner's request; the code-built run with its arms held
  out looked awkward). One model for all fourteen, baked as Hurling's is (tools/player/README.md): 5,840 triangles,
  1,460 on Low; the shader paints the dress's navy in the team's first colour and its light blue panels in the
  second, keeps the white socks and shoes, and gives each player her own skin tone and dark hair. **The bib is
  painted by the shader** (from each point's rest position, carried in UV2) rather than a separate panel mesh: no
  extra draw call per player (Low stays under 100), and it bends with the body. Umpires keep the code-built figure.
- **The run is the owner's Mixamo Fast_Run**, the one Hurling uses, copied as baked poses (tools/player/clips/
  fast_run.json: both games share the 17 bones, every rest rotation the identity); below a sprint the model's own
  Running, and Walking below a jog, blended by speed and locked to the stride phase (the left thigh forward at 1/4),
  so the feet keep pace with the floor. The legs and body take the clip whenever she moves; the arms only when they
  are free (running, ready), so a catch, a pass, marking or holding the ball keep the code's arms. A player with the
  ball stands (footwork), so she never runs.
- **Shared assets** (October 2026): the owner made the orchestrator session the lead for all six mobile games.
  Assets that suit more than one game come from it, listed in `shared-assets/README.md` on branch
  `claude/shared-assets` (large files on the "shared-assets" GitHub release) with each one's source, licence and the
  games it suits. When one arrives, a message says what it is and how to fetch it.
- **The graphics update: what was used, skipped or moved, and why.**
  - Used as the plan says: hall (white_maple_veneer, concrete_block_wall normal map, ceiling_interior,
    fluorescent_light, wall_clock, fire_alarm, wet_floor_sign, gym_bench, painted_bench, gym_01 HDR for reflections
    on Medium and High); outdoor (netball_court sky and HDR, clean_asphalt, asphalt_02, park_bench,
    street_lamp_tall, basketball_hoop on the neighbouring court, jacaranda, oak and small_broadleaf cut-outs,
    grass_clumps, terrace_row); arena (bleacher_metal).
  - Moved or changed: the hall's basketball boards are built from primitives to FIBA measurements, as the plan asks
    (the owner's street hoop is outdoors only); the main court's boards are winched up to the roof, the cross-court
    boards on the far wall. The oak is a cut-out even on High (the mesh reads faceted this close to the cameras).
    plastered_wall and hanging_lamp not used (painted block and slats, and the fluorescent battens, read better).
  - Arena: bleacher_metal is used only on Medium and High, as courtside seating in front of the lower tier on the far
    side and both ends (not the near side, under the cameras), with the crowd's people in its seats; the lower tier
    is not rebuilt (its painted seated crowd and the floodlit look stay). Its `_low` model is not used: the
    decimation broke its seats into shards, and on Low the painted tier is cheaper and looks better. The model is
    8,000 triangles a section (11 sections, about 88,000 triangles on Medium and High).
  - The hall's stand was a slope with seated people painted on it, which read as coloured bars from the end and
    courtside cameras; it is now stepped rows of real tip-up seats (folded up where no one sits), with people (Crowd
    cut-outs) in the front three rows on Medium and High only, so they stay out of the courtside camera's view
    except for a row of heads along its bottom edge. Low shows the empty seats.
  - Outdoors the sun's shadows reach 55 m (they used to reach 100): the trees, lamps and houses beyond cost the
    shadow pass draw calls for shadows no one sees (the courtside camera on High: 207 draw calls down to 180).
    Indoors the default stays: there the shorter reach crowded the players into more splits (+25 draw calls).
  - Gaps that would need a new model (not generated; the owner's Meshy credits are not spent): a clean low-poly
    courtside bleacher for Low (bleacher_metal_low is broken), and a proper arena seat or seated-spectator model to
    replace the painted tiers. Neither is needed to ship.
- **Crowd near the camera** (0.4): crowd figures within 6 m of the camera are not drawn (Crowd's shader): from the
  Courtside camera behind the hall's stand they read as blocky heads across the bottom of the screen.
- **Low arena stands** (0.4.1): the lead's new `stands/bleacher_hall` (the owner's Meshy model; its _low holds together)
  makes the courtside stands on Low; Medium and High keep `bleacher_metal`, which seats the crowd's people.
- **Crowd facing** (0.4.2, the owner's report via the lead: the near side's crowd looked the wrong way): the crowd's
  cut-outs turn to the camera, and the sheet had only front views, so a stand seen from behind (the hall's, from the
  Courtside camera) showed faces looking away from play. Every spectator now has a facing toward the court's middle
  (Crowd.facing) and the sheet a back view (the back of the head) that the shader draws when the camera is behind
  her. All three venues were affected wherever a camera looked over a stand; test `_crowd_facing`.

