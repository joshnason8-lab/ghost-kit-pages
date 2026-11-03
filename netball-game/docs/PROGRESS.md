# Progress

The working log for Netball Unleashed: what is done, what is next, and the decisions made along the way with the
reasons. Anyone picking the work up (after a usage limit, a restart, a context summary) starts here, then reads
`git log`.

## State

- Branch `claude/netball-game`, folder `netball-game/` (self-contained Godot 4.7.2 project), pages folder
  `netball-unleashed/`, workflows `.github/workflows/netball-android.yml` and `netball-play-bundle.yml`.
- Version 0.7.0-beta. Draft PR #4 (https://github.com/joshnason8-lab/ghost-kit-pages/pull/4); beta release
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
- Motion capture (October 2026, the owner's CMU library, `shared-assets/motion/CMU.md`): each move compared with the
  library's candidates against RULES.md; real recorded movement now where it is clearly better. CMU clips used:
  **102_27** (DefensiveMoveSideToSide: the side-step, for any player going sideways to where she faces under 4 m/s,
  marking or leading with her eyes on the ball, instead of a run crabwise) and **16_08** (run/jog, sudden stop: the
  landing on a catch on the move, on the landing foot the footwork rule gave her, the other foot stepping down
  beside it, played in step with how far she goes so the landing foot stays put; the rules' landing spot is where
  that foot comes down). Retargeted by `tools/player/cmu_bvh.py` (foot locks, root motion kept apart: Player.advance
  still writes her position) into `assets/player/mocap.json` (25 KB); rebuilt by `tools/player/fetch_cmu.sh`.
  Planted feet move 0.2-0.8 cm (test limit 2 cm). Kept as they were, with the reasons in tools/player/README.md: the
  run (Mixamo), cuts, the pivot (102_29), the shot (124_03-06 are basketball shots), passes and catches (33/34),
  the leap, defending the ball. Holding the ball, her hands now meet on it (the hold pose's forearms were twisted
  outward on the owner's model). Credit in Licences.
- Sounds (October 2026): recorded sounds from Kenney (CC0) and OpenGameArt (CC0, CC-BY, CC-BY-SA), made by
  tools/audio/make_sounds.py, listed with source, author and licence in docs/SOUNDS.md and on the Licences screen.
  New: catches, bounces on a sprung timber floor and on asphalt (bounce passes, loose balls), footsteps by surface
  (hall floor, asphalt) for the players running near the ball, shoe squeaks on hard cuts indoors, the venues' beds
  as seamless loops (the arena's crowd; a hall's small crowd with echo; a park court's birds, distant traffic and a
  few people), cheers big and small, applause three ways (arena, hall, a few people in the park) at quarter time and
  full time, the umpire's whistle for a goal and a long one at the end of a quarter. Replaced: the ring, the net,
  the click, the whistle (re-made with breath and an uneven pea flutter), the cheer and the applause. Kept: the
  pass's release, the crowd's ooh and groan (Kabaddi Raid). The crowd's reactions had never played (match.gd asked
  for "crowd_crowd_ooh"): fixed. Sounds on court are 3D (eight speakers under the match, the oldest giving way); the
  pause menu holds every sound. About 0.5 MB added. Tests `_sounds` and `_sounds_in_play`.

- The size update (October 2026, the owner: "the APK may grow, to make the game look and sound better"): Medium
  and High load more, Low loads exactly what it did. Medium and High: the park court's sky at 4096 x 2048 (Poly
  Haven's 8K tone-mapped netball_court, its tones matched to the 2K one; the 2K was magnified about five times on
  screen, the clearest gain), the players' texture at 2048 and kit mask at 1024 (tools/player/make_textures.py, from
  the owner's 4096 atlas), a crowd of 32 different people (tools/art/make_crowd.py: eight skin tones, hair styles
  from cropped to afro, braids, buns and ponytails, builds, beanies, caps, sun hats, team scarves, glasses, an arm
  up; a mask so shirts take each fan's colour and scarves and hats the team's; still one draw call), the venues'
  beds as long stereo loops (65 s, 46 s, 2 min, where Low's repeat every 16-17 s) and four more big cheers, three
  smaller, three more applause takes in the arena and two in the hall, two more each of the ooh and the groan
  (tools/audio/make_sounds_hd.py, assets/audio/hd/). High also: the floor, wall and ceiling surfaces at 2K (Poly
  Haven, CC0). All through `Game.tex` / `Game.HD_TEX` and `Game.hd()`. On every level: the owner's recorded referee
  whistles (Pixabay, via the shared assets) replace the synthesised one: a short pip (three takes) for an
  infringement or restart, a long blast (three takes) for the centre pass and a quarter's end, two pips for an
  injury or a time-out, the final whistle, the gym take for long blasts in the hall; from the umpire who blows
  (3D), quieter in the home screen's match. Draw calls and triangles unchanged at every level; video memory
  (tests/perf_probe.gd now prints it; one level per process) Low unchanged (arena 29.7 MB, hall 29.5, outdoor
  36.6), Medium 53.7 / 49.3 / 62.2 MB to 62.6 / 58.2 / 75.2, High 72.0 / 67.6 / 80.5 to 82.9 / 82.5 / 97.5. The Web
  build's index.pck went from 38.9 MB to 89.5 MB (it carries each texture twice, S3TC and ETC2; the APK only ETC2,
  so it grows by about half that: roughly 51 MB to 76 MB); 12.3 MB of new files in the repository. Tests:
  `_low_unchanged` (each venue's Low textures and sizes as recorded from 0.6.0-beta, its bed; High the sharper
  copies and the 32-person crowd), the whistle and the Medium/High sounds in `_sounds`. Low's screenshots before and
  after: the play shots pixel-identical, the others differ only in the umpires' stride (driven by the wall clock),
  the players' close-ups identical.
- Watch AI (the owner's request, after 0.8.3-beta): a full AI v AI match to watch, from the home screen. The right
  goal third is now halved like the left one (How to Play above, **Watch AI** below, the same white line between;
  `CourtThird` kinds `goal_right_top`/`_bottom`). Its team sheet is Quick Match's (`ui/watch_setup.gd` extends
  `ui/quick_setup.gd` with `watch`): Home and Away by flag from the same team grid, the venue and the quarters (kept in
  their own settings, `watch_*`, so Quick Match's are untouched), a note that it counts for nothing, and Watch.
  `Game.watch_config`: `mode "watch"`, `user_team -1`, `demo` and `watch`, the team card. In the match (`Match.watch`):
  the TV camera whatever the setting, with the AI v AI close shot of the post for every shot and the replays (Medium
  and High with the clip library); the scoreboard and clock, the name tags; its sound (venue, crowd, catches, steps,
  whistles: `Match.heard()`; the home screen's match stays silent); no touch controls, no coach, no buzz; the interval
  screen after the huddles, going on by itself after 7 s (Continue skips); the result screen with the box score, Back
  home. `Game.on_match_finished` records nothing for it (no records, cup or season). The HUD has the pause button and,
  beside it, a speed chip (fast-forward mark and "1×"/"2×", lit at 2×); the pause menu has Speed 1×/2× in place of
  Move buttons. **2× is the match's own step scale**: two of its steps a frame, each exactly the step it takes at 1×
  (the same dt, cut at 0.05 s), so the AI, the players and their bodies' clips, the ball, the umpires, the clock and
  the sounds on court all run together and play as at 1× (Engine.time_scale is never touched: at 30 fps it would have
  run steps of 0.067 s, cut to 1.5×). A replay keeps its own slowed pace (a tap skips it); the bodies are kept for it
  once a frame; the auto graphics read the real frame time once a frame. Leaving the match goes home at 1×; a new one
  starts at 1×. 7 new strings in all 19 languages (346 each); the Chinese font re-cut by tools/subset_fonts.py for
  看 and 客 (the other fonts left as they were: their characters were all there). Tests: `_watch_ai` (menu entry, team sheet, AI v AI with
  no controls, scoreboard, chip; 2× doubles game time a frame and back; pause holds, Back resumes; Leave goes home;
  a 5 s-quarter match at 2× shows its interval screen and reaches the result, records untouched; the keys translated
  in every language), watch_setup in `_screens`, the input test's pages and the fit audit (`watch_setup`, `watch_card`,
  `watch_play`, `watch_play_2x`, `watch_pause`, `watch_break`, `watch_result`); screenshots part `watch`.
- 0.8.2-beta — soak test (Play Store readiness: crashes, freezes, stalls, dead ends).
  `tests/soak.gd` (soak.tscn), args `graphics inputs matches quarter_s [seed=N stall=S parts=...]`: Back (Esc and
  the phone's button) on every screen and in a match (paused, team card, moving buttons, rolling changes, interval,
  final whistle, result); the home button / screen off (APPLICATION_PAUSED, APPLICATION_FOCUS_OUT,
  WM_WINDOW_FOCUS_OUT) in a cup match, the saves checked on disk; AI v AI matches in all three venues, each run to a
  result and watched for stalls (nothing moves on for 45 s of game time); a monkey of random taps (most aimed at
  buttons), drags, two-thumb touches, clicks, Back and the home button from the home screen into matches. Any
  SCRIPT ERROR or ERROR logged fails it (an OS Logger; the no-sound-card ALSA lines aside). It never presses Back on
  the home screen (that quits on a phone; it checks MainMenu.quits_on_back) and puts the player's saves back at the
  end (and after a run that died part way). Results, xvfb + llvmpipe unless headless:
  - Low, 640x360: 3000 inputs (1496 taps, 620 drags, 258 two-thumb, 276 clicks, 329 Back, 101 home button; 23
    matches entered from the menus) and 12 AI matches of 20 s quarters: 238 checks, 0 failures, 0 log errors, 46 min.
  - High, 320x180 (High draws about two frames a second in llvmpipe): 3000 inputs (1487 taps, 615 drags, 248 two-thumb, 319 clicks,
    310 Back, 77 home button; 23 matches entered) and 2 AI matches: 145 checks, 0 failures, 0 log errors, 58 min.
  - Headless, 30 AI matches of 40 s quarters each on Low and High (4 with extra time) plus the Back and home-button
    parts: 540 checks each, 0 failures, about 5.5 min each.
  Found and fixed: Back from what the pause menu opens (Move buttons, rolling changes) resumed the match with the
  buttons still in editing mode or the changes still over the court: it now goes back to the pause menu, as Done
  does (`Hud.close_layer`, `Match.on_back`); a window losing focus (NOTIFICATION_WM_WINDOW_FOCUS_OUT: the notification
  shade, another window, a browser tab) did not pause your match: it now does, like the home button. Both checked in
  `_navigation`. No crash, freeze, stall or script error in any run. Saves were already written as they change
  (settings, cup and league after each match, records), so the home button loses nothing saved; a match itself is
  not saved mid-play: if the phone kills the game in the background the cup or league match is replayed from the
  start (it pauses on the home button, so a player who comes back finds it waiting).
- 0.8.1-beta — Settings > About in the game: Licences, Help (`ui/help_screen.gd`: the controls and the rules in
  brief from How to Play's own translated words, the graphics levels, what to do if something is wrong and how to
  report a bug) and the Privacy policy (`ui/privacy_screen.gd`: no data collected, no ads or analytics, no internet
  permission, the date and a contact) all open offline. Settings used to open two web pages
  (github.io/ghost-kit-pages/netball-unleashed/privacy.html and support.html) that return 404: GitHub Pages does not
  serve this branch; the buttons no longer leave the game. The licences now also credit Meshy (the owner's models)
  and Mixamo (the rig and clips). Test: `_about_pages` (each opens from Settings' own button, scrolls, and holds its
  words); the fit audit and input test cover both new screens.
- 0.8.0-beta — match study: venue (docs/MATCH_STUDY.md). Indoors on Medium and High: LED boards
  round the run-off in the arena and a row of portable ones on the hall's far side, running invented messages
  (assets/venue/led_atlas.png, drawn by tools/venue/led_atlas.py in the game's display face), the two teams' colours
  in sweeping bands, and "GOAL!" in the scorer's colour after a goal; the game's wordmark painted in the run-off by
  each side line; a goal light on each post that flashes for a goal. All one shader (VenueLook.led), one draw call;
  Low and the outdoor court as they were. The TV camera cuts to a close shot of the post: for every shot in an AI v
  AI match, in yours only once the ball is through the ring (never mid-play, so no setting; the stick steers by the
  wide shot through it). The team card (TeamCard: the teams' colours, crests, names, competition and stage, venue;
  at half-time the score) opens a match started from the menus and comes back at half-time; a tap skips it. The
  scoreboard already showed the quarter and the clock. Tests: `_venue_study`; fit audit `match_card`,
  `match_card_half`; venue_shots saves a goal's close-up. perf_probe (TV camera): Low unchanged in every venue (arena 89 draw calls /
  55.6k primitives, hall 90 / 74.2k, outdoor 89 / 58.6k); arena Medium 106 to 107, High 147 to 148; hall Medium 107
  to 108, High 148 to 149 (a few hundred triangles); about 0.4 MB more video memory; outdoor unchanged.

- 0.8.0-beta — match study: play (docs/MATCH_STUDY.md, the owner's video of an international). On the
  centre pass whistle the GA and WA drive flat out 2.6 m into the centre third, a stride away from their markers
  (`TeamAI.on_centre_whistle`, `drive_spot`). After a goal a beat to celebrate, then everyone jogs back at 2.8 m/s (the
  taking C hurries); the walk starts in the goal phase, so the next whistle comes no later than before (6 AI v AI
  matches: goal to whistle median 5.8 s, from 6.0; the longest about 9 s as before). With the ball in her goal third the
  GS holds 1.7 m off the post, facing out, an arm out where she wants it (`Poses.post`); the WA and C work the circle's
  edge (the pocket, the top) and slide along it for a lane; the GK and GD front the shooters while the ball is outside
  the circle and drop goal-side once it is on the edge (`mark_spot`, less on the easier levels, `front_weight`); the WD
  and C shade toward the front of the circle. As a shot goes up the GS and GA go in either side of the post, the GK and
  GD box out round them, the rest hold (`rebound_spot`). The umpires jog (3.5 m/s; 5 to catch up), stand still to
  signal, go round the corner onto the goal line when the ball is in their circle and back by the corner, and wear a
  light teal shirt. At quarter and half time each team huddles in a ring by its bench, facing in (`Poses.huddle`), the
  umpires walk to the middle, the camera looks over; the interval screen comes up once they are there (2.5-6.5 s). The
  reserves stand in front of their benches in tracksuits on Medium and High (code-built figures, no shadow: Medium +8
  draw calls and about 33k triangles); Low unchanged (89-90 draw calls, 53-72k triangles). Six 10-minute AI matches,
  before and after: shooting 74% and 74%, goals a team an hour 78 and 78.5, centre passes to goals 58% and 52%. Tests
  `_cp_drive`, `_goal_reset`, `_front_mark`, `_rebound_spots`, `_umpire_goal_line`, `_huddle`, `_reserves`.

- The run, on every graphics level (the owner on a Galaxy A16, Low: "players gliding around, not running, arms just
  stretched out when running"). Causes: the stride's phase did go on by distance, but nothing held a foot where it
  came down: the Mixamo clips' stride did not match the speed's, and with `look_on` (the AI faces every player at the
  ball, ai.gd `_play`) she ran sideways or backwards on a forward stride: a glide; above 4 m/s the slide gave way to
  that run. Arms: marking's arm out at 50 degrees and posting's out in front were laid over the run at any speed
  (player.gd `Poses.with_arms`), defending's and catching's arms-up poses (and their legs) were all of her while she
  ran, the side-step's capture held the arms out wide, and Fast_Run's forward arm reached out nearly straight; the
  umpires' run went by the wall clock (`Time.get_ticks_msec()`) as they side-stepped their line facing the ball.
  Now `game/gait.gd` (Gait) is the one place a body's locomotion is made, for players and umpires on the game's own
  bodies: each foot comes down where her hips will be over it and stays there (rolling heel, flat, ball of the foot),
  the legs reach it with two-bone IK, forwards, sideways (wider, shorter steps, feet never crossing) or backwards;
  the stride pair 1.1 m walking, 2.15 jogging, 3.5 sprinting (the figure's), its phase by distance; pulling up, the
  foot in the air comes down and the other is brought alongside (four steps from 6.8 m/s); standing she steps when
  a foot strays or she turns; the landing foot only pivots. Arms swing against the legs, elbows bent, by her sides;
  sprinting, the heel comes up behind before the knee drives through. The game's moves are laid over it (Gait.lay):
  a catch, a pass, the ball, the shot and the leap keep their arms; defending's arms up while she closes in at a
  walk, marking's, posting's and the ready hands only standing or edging; on the run her arms are the run's. Running at a jog or faster her body turns the way she runs,
  her chest and head to the ball (`body_yaw`: drawn only; `facing`, which the AI reads, is as it was). The Mixamo
  clips and the slide capture are no longer laid over the run (the landing capture is kept). FoundationLink (Medium
  and High with the licensed clips) asks the player which of her the game's pose is (`Player.anim_layer`): a move
  on the run keeps only its arms over the capture's legs, and marking's and posting's arms go with the run.
  Low: the game's own bodies' run fixed rather than the foundation's locomotion run on Low (the shared session is
  building that, "route 2"); draw calls, triangles and textures unchanged (no new mesh or material); `_low_unchanged`
  checks no animation and is unchanged. perf_probe Low (TV camera): arena 98 draw calls / 56.5k primitives, hall
  99 / 75.1k, outdoor 98 / 59.5k, the same to the draw call with the code before this change (higher than the 89-90
  noted for 0.7: that came with the beta's later changes, not this). About 20 microseconds more a player a frame on
  a desktop.
  Tests `_gait_steps` (Low and Medium): a planted foot's slip 0.0 cm (the drawn foot, limit 3 cm) running at 3.5,
  6.8 and 7.2 m/s, marking sideways at 4, defending at 3, the ball behind at 5 and backing off at 2.5, umpires at 3.5
  and 5; 0.3 cm at most over 20 s of two AI matches (arena, hall); elbows bent 77-114 degrees; hands 0-5 cm out
  from the shoulder, upper arms 9-19 degrees from her sides, and in the matches nobody running past 3 m/s with an
  upper arm more than about 21 degrees out. tests/gait_view.tscn renders it frame by frame (strip: setting off,
  jog, sprint, pulling up, an umpire; match: the TV camera; close: beside the nearest runner).
  The shared foundation's Low driver (WsgToonDriver) is to be wired after body.apply in Player._animate and
  Umpire.advance; Player.anim_layer says which of her is the game's.
- **Bodies, the owner's notes after 0.8.6** (every level; foundation synced c52af06 -> 6930061 in its own commit):
  - Floating feet (Medium/High, the foundation's body): the capture's run slid its planted feet 4-7 cm a step
    alone and up to 1-1.4 m in matches (its starts, cuts, side-steps, edging at the idle, far bodies carried along
    between poses), and under the game's whole pose the planter was only disabled. Now on the move her whole body
    is the game's (Player.anim_layer "full": Gait's planted feet, any pace and direction, the sprint too), the
    capture only standing still (its idle); planter keep_pose under the game's pose, resume() + reset() back to the
    capture, no AnimationTree run under it; FoundationLink.FeetLayer puts each drawn ankle on the game's (IK, the
    knee toward the game's, the foot turned as the game's); a far body's modifiers run between its poses (follow),
    and the summed dt is capped at 0.25 s (was 0.1). Drawn foot slip (tests/test_runner _foundation_steps, with
    the clips): 0.2 cm from 2 to 7.2 m/s, side-stepping, defending, passing and catching on the run, pulling up;
    1.6-1.7 cm at most in two AI matches (the game's own 0.3-0.4). Replays play back what was drawn (no change).
  - Shooters facing away: the shot kept her look at her last passing option. Now she faces the post from her set
    (and squares up while she holds in range, the AI's shooters), a passer the receiver; 0 degrees off over 12
    shots on Low and Medium (was up to 164).
  - The ball in the forearms: Low put it at the midpoint of the wrists (palms up to 23 cm off it). Now the arms
    are IK'd after the pose so each palm is on its side of the ball, a little behind, facing it (Player
    _hands_on_ball), the ball placed there the same frame; the foundation's grip on the ball itself
    (WsgGrip.solve_sphere/sphere_point). Palms within 0.0 cm (Low) and 1.7 cm (Medium) of the ball; forearms
    13-15 cm from its centre (radius 11.2).
  - Rigid stance: Poses.idle (breathing, weight shift, head turns, each player her own), hands up in front only
    while the ball may come to her; marking with loose arms and a brief arm out; posting's arm in pulses.
  - Block umpires: the players' model (HeroBody) in the umpires' kit (HeroBody.UMPIRE_KIT, shared with the
    foundation's shader) on every level, at ease standing. Low perf_probe (TV, seed 4): 98/99/98 draw calls as
    before, triangles 56.5k/75.1k/59.5k -> 53.4k/72.0k/56.4k; Medium and High unchanged.
  - Review renders: tests/body_view.tscn (hands, shot, idle, umpire).

- How to Play's positions (the owner: "the court graphics don't show the positions, it's just the same image over
  and over"). Cause: each card's AreaMap was a 184 x 92 court whose only difference from the next was a lime tint
  over one to three thirds (circles a 25 px semicircle), with no player on it: seven near-identical little courts,
  nothing saying where she stands or which way she goes. Now `ui/position_court.gd` (PositionCourt), drawn from
  Rules.AREAS and Rules.OPPOSITE: the court in thirds with both circles, 256 x 128 at 1280 x 720; her areas lit lime,
  the others dark; her bib (the home rail's tabard, shared as `BibButton.tabard`) with her letters at a typical spot,
  her opposite number's coral bib beside her, goal-side when she defends; the post she attacks ringed in coral and a
  gold arrow under the court the way her team attacks. No words added (the letters are the cards' own). Test
  `_howto_positions`: each court's lit areas are Rules.AREAS, both bibs onside and apart, no two alike, the page has
  the seven; in a window (`xvfb-run ... test_runner.tscn -- howto`) the pictures are rendered and each third and
  circle sampled lit or dim, and all 21 pairs differ.
- The ball, the nets and advantage (November 2026, the owner's playtest notes). **The ball flies under gravity**
  (Ball.plan): every pass and shot is a parabola at 9.81 m/s² from the hands to the catch, its speed across the
  floor constant, its time following from the distance and the kind of throw (the old flight was a straight line
  in a fixed time plus a hump, so a lob "fell" at up to 44 m/s² and a chest pass at 7). Chest 9.8 m/s over 3 m to
  13.7 over 12 (0.31-0.92 s); shoulder 13.9-17.2 m/s (11-21 m); lob up 1.9-2.5 m over the hands, 1.1-1.3 s in the
  air, half a chest pass's speed across or less, caught by the receiver at the top of her leap; bounce pass down to
  the floor 62% of the way, up off it at 80% of its speed; shot released at 48 degrees from the circle's edge, 53
  from 3 m, steeper under the post, dropping into the ring from at least 45 cm above it. A goal drops through the
  net, which holds it back; a miss comes off the rim where it hit (no jump to the ring's middle). The AI judges a
  pass's risk on the same flight, to its last moment (where a lob comes down onto the receiver), and a defender
  needs 0.3 s more to take a lob there (she has to get round the receiver going up for it). Twelve AI matches (75 s
  quarters), before and after: 161 and 172 goals, shooting 78.9% and 79.6%, intercepts 6.9 and 6.2 a hundred
  passes, turnovers 10.3 and 9.2, lobs picked off 19% and 13%; mean flight times chest 0.49/0.50 s, shoulder
  0.87/0.89, bounce 0.48/0.53, lob 0.79/1.08. **The nets are rope**: a goal swings the net it drops through the way
  the ball was going (about 8 cm at its foot), ripples it down its cords, pushes it out round the ball and drags it
  down as it passes; a ball off the rim or brushing it stirs it; it settles in two or three seconds (a damped swing
  of 1.3 a second, Arena._nets). The glow shader moves the net's faces from three uniforms a post, so it costs no
  draw call on any level: the nets are drawn in six rows now (+320 triangles a venue: Low 98/99/98 draw calls as
  before; arena 53.7k primitives, hall 72.3k, outdoor 56.7k on 0.8.9), the same in all three venues and every level, and in
  the replays (it follows the ball wherever it is drawn). The corded texture already reads as a rope net up close,
  so no rope mesh. **Advantage**: a defender whose contact or obstruction is played as advantage steps clear of the
  shooter, about 2.2 m to the side and 0.6 m back, never between her and the post (past 1.5 m in 0.7 s), until the
  ball has gone (TeamAI.give_way); the penalised player of a penalty pass stands square to the thrower's line to the
  goal, not in it. Found on the way: a knockout still level after extra time played on for ever (time_left INF,
  and nothing asked Rules.match_over), which the new flights' different random draws exposed in `_matches`' knockout;
  the goal that makes a two-goal lead now ends it. Tests `_ball_flight`, `_ball_in_play`, `_net_sway`,
  `_advantage_clear`, `_two_goal_lead` (`test_runner.tscn -- ball` runs only these); tests/ball_shots.tscn renders a goal at the post frame by frame and
  a lob and a chest pass from the side with their paths, the old ones beside them.
- **The arena's bowl is real people** (the owner: "most of the crowd is still just squares"). The lower and upper
  tiers all round were a slope with people painted on by VenueLook's stand shader; now each row is a tread and a
  riser, a plastic seat (pan, edge, back; one back a seat on Medium/High, one strip on Low) along the back of it,
  stairs every 8 m and down each corner's mitre (Arena._bowl_tier, all in the venue's lit draw call), declared as
  WsgCrowdVenue sections (CrowdVenues.bowl: a side of a tier or a band of its rows, seats 0.43 m high, 0.33 deep,
  backs 0.32; each row to its own mitre; no places on the stairs). Crowd fills them: on Medium the lower tier
  behind the courtside stands in 3D, on High also the far upper tier's front rows ("solid"), the rest as the
  foundation's cards, one draw call; Low all cards. The bowl has its own density (0.7/0.8/0.9: a full house), people
  darken going up as the stands fade into the night, the near-camera hide looks only round the camera. Nothing is
  painted any more (STAND is unused; the hall's back rows are empty tip-up seats, as at a league match). Foundation
  synced to 2cd59a7 and the licensed crowd baked again (version 3); the cards' sheets now import VRAM-compressed
  with mipmaps (our .import files: vendor.sh keeps a game's). People (TV seed 4): arena Low 4,803 cards; Medium
  5,270 (601 3D); High 5,956 (1,175 3D). perf_probe peaks, draw calls/primitives and video memory, before -> after:
  arena Low 99/53.9k 41.8 MB -> 99/68.9k 33.6 MB, Medium 128/367k 69.0 -> 132/610k 75.0, High 167/637k 89.5 ->
  171/1,111k 95.5; hall Low 100/72.4k 41.6 -> 100/72.4k 32.6 MB, Medium and High unchanged; park Low 99/56.9k 48.7
  -> 99/56.9k 39.7 MB, Medium unchanged, High 194/864k as at 0.9.0. crowd_audit passes every venue at Medium and High (the arena in three sheets: courtside,
  lower tier, upper tier). `_crowd_facing`: on High the arena now has cards (the bowl's far rows) beside its 3D
  people. Still as before: the courtside metal stands' rows 2-5 empty (knees in the chair backs); the shared cards
  have no look or clap poses, so only the 3D people turn to the ball and clap in time (Crowd calls the cards'
  watch_ball and clap, ready for art that has them). High's far upper rows in 3D cost about 200k triangles of its
  1.11M ("solid" 2 -> 0 in CrowdVenues.bowl makes them cards).

## Next

1. Native speakers' review of every translation (docs/translation_notes/), the lower-resource languages first; the
   0.2 strings are listed under "Added in 0.2" in each.
2. The non-English store listings: add the Club Season and the coach (the English ones have them).
3. A home-and-away Club Season (14 rounds) as an option, and a finals series with a second chance for the top two.
4. The after-goal tactical change (2024) on request; the without-ball obstruction signal drawn.
5. A phone test on a Mali-G52-class phone; trim crowd/render scale if Low drops under 30 fps.
6. The upload key and the closed test (store/PLAY_STORE.md). (The umpires are the players' model now, 0.8.6.)
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
- **Sounds: recordings where a free one fits, synthesis where none does.** Only Kenney and OpenGameArt are
  reachable from the build machines (freesound and pixabay block them). Neither has a referee's pea whistle, a
  basketball or netball bounce, a ball through a cord net or a shoe squeak, so the whistle and the squeaks are
  synthesised (tools/audio/make_sounds.py) and the ball's sounds layered from Kenney's generic impacts. No chants,
  horns or drums: netball's crowds (the UK, Australia, NZ, southern Africa, the Caribbean, the Pacific) cheer, clap,
  groan; the "rhythmic cheering" takes were left out. One-shots mono 22 kHz Vorbis q3, beds q2, levelled to an even
  loudness (the loudest 100 ms above 120 Hz); those the home screen's match already played (whistle, ring, net,
  applause, click) are matched to the sounds they replace, and that match asks for nothing new (no bed, steps,
  catches or reactions: a test checks), so the home screen is no louder.
- **The beta signing key** (October 2026, the owner's fix for "failure conflict" updates): with the repository
  secret BETA_KEYSTORE_B64 set, the Android workflow signs the APK with the owner's shared beta key and fails if
  its certificate's SHA-256 is not 6F:23:A9:...:7B:A3 (logged on every build). Without it, uber-apk-signer's fixed
  debug key, as before, with a warning. The first build on the owner's key does not install over earlier betas
  (a one-time uninstall); every one after it does.

- **The size update: where the bytes went, and where not.** Low is untouched (same files, draw calls, triangles,
  video memory; a test holds it). The floors and walls repeat every 2-3 m, so their 1K textures already give
  400-500 texels a metre, more than any camera shows (the broadcast camera sees about 40 pixels a metre of court,
  the courtside one about 130): the 2K copies are on High only, and side by side at 1080p the floor looks the same;
  4K was not used. What shows is the sky (magnified about five times at 2K), the crowd (32 people where there were
  8 from one template), the players up close (slightly crisper faces and kit edges) and the sound (beds that no
  longer loop audibly, a different cheer each goal). The crowd's sheet is drawn by a script (antialiased, 64 x 128
  a person) rather than painted at startup: painting 32 at that size in GDScript would take seconds on a phone.
  The beds are stereo 44.1 kHz on Medium and High (mono 22 kHz on Low); sounds are loaded only by the levels that
  play them. No 8K sky: OpenGL ES 3.0 only promises 2048, and 4096 is safe on the phones that run Medium.
- **Whistles: the owner's recordings on every level** (sound costs no frame time; about 0.1 MB). Picked by a
  generator of the sounds' own so the match's random draws (the umpires', the players') stay as they were.
- **The crowd as real people** (the owner: "the crowd isn't real people"): on Medium and High every spectator of the
  three venues (the arena's courtside sections, the hall's stand, the park's standing crowd) is a whole 3D person, the
  shared foundation's WsgCrowd3D (synced to 6930061: two thirds of the fans the two women, each fan's own skin, hair
  and trousers or skirt). Seated on the measured seats of the arena's Meshy sections (five rows; the model's rows are
  closer than knees need, so a row's shins tuck into the chair backs in front, hidden from the cameras) and on the
  hall's tip-up seats; outdoors standing on the ground, the ends' crowd now behind the low fence instead of in it.
  They face the court (their seat's way, turned toward the middle by at most 30 degrees), watch the ball (a replay's
  too), the keen ones rise as play reaches a goal circle, all up for a goal, applause at a quarter's end. One shirt a
  seat, about half in the teams' colours, shared with the cut-outs (now only the fallback, and any the budget would
  leave out: none). As the cut-outs were, people within 6 m of the camera are left out (the hall's Courtside camera).
  Low is untouched (no crowd node on Low, as before). Broadcast camera, before -> after (draw calls, triangles):
  arena Medium 126/336k -> 137/530k, High 165/556k -> 176/871k; hall Medium 127/330k -> 132/365k, High 166/549k ->
  171/601k; park Medium 125/349k -> 130/439k, High 189/710k -> 194/841k; Low 98-99 draws, unchanged. The arena's
  painted tiers stay painted (people there would need stepped seats). Test `_crowd_facing` covers the 3D people.
- **Crowd placement, every venue** (the owner via the lead: "make sure the crowd is sitting properly ... facing the
  right direction, standing properly; shared foundation"): foundation synced to b073334; each venue declares where
  its people sit or stand (`game/crowd_venues.gd`, the foundation's WsgCrowdVenue) and the foundation places, sizes
  and turns them; `Crowd` draws them as 3D fans on Medium and High and as the foundation's cards on Low (one draw
  call; Low had no crowd before). Arena: a section a courtside stand (11); Medium/High the Meshy bleacher's front
  row only (its rows are 0.46-0.8 m apart: the 2nd, 3rd and 5th rows' knees would be in the chair backs in front,
  and the 4th row's feet went 16 cm into them getting up; the empty rows' seats and backs are audit obstacles); Low
  the light bleacher's middle plank, feet on the front plank. The bowl's tiers stay painted (real people there need
  stepped seat geometry and thousands more places, for a crowd the broadcast camera reads as texture). Hall: the
  tip-up seats moved to the back of each tread (the feet had no room in front), a section a block between stairs,
  the front three rows at 60% (at full density). Park: standing; the near side either side of the benches, the far
  side behind the tall fence between the path's benches (new), the ends behind the low fence round the park bench.
  Fixed seats face one way a stand or block (toward the play, at most 15-25 degrees off square); outdoors the fans'
  shade is 0.85 (faces read). `tools/wsg/crowd_audit.gd -- res://game/crowd_venues.gd` passes every venue at Medium
  and High (tests/crowd_scene*.tscn draw the real venues). Tests: `_crowd_facing` (Low cards and High 3D: facing,
  on a seat or the ground, the near-camera hide), `_low_unchanged` (Low adds only the cards' four sheets). The
  cut-out crowd and its sheet are gone. perf_probe peaks (TV play, a goal's close-up, the other cameras), draw calls
  / triangles, before -> after (the peak is the broadcast camera's play every time): Low (before: 0.8.9) arena
  98/53.4k -> 99/53.5k, hall 99/72.0k -> 100/72.0k, park 98/56.4k -> 99/56.6k (the cards' one draw call; at most
  100); Medium (before: 0.8.8's crowd) arena 139/529k -> 130/378k, hall 134/364k -> 132/366k, park 132/438k ->
  132/443k; High arena 176/879k -> 167/637k, hall 171/609k -> 169/621k, park 194/849k -> 194/864k. Low's video
  memory +12 MB (29.8 -> 41.8 MB in the arena): the cards' four 768 x 768 sheets, imported lossless without
  mipmaps as every adopter has them (asked the foundation whether VRAM compression and mipmaps suit them). The foundation's WsgFootFlat measures the players' model at 1.85 degrees toe-up: under
  its 2, so not attached.
