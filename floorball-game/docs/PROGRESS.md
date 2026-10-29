# Floorball Unleashed: progress

The floorball game built overnight on 21-22 October 2026 by a Claude Code session, on branch `claude/floorball-game`.
If you are resuming (after a usage limit, a restart or a context summary): read this file and `git log`, then carry
on with "Next".

## Done

- Research: the IFF Rules of the Game, edition valid from 1 July 2026 (the full PDF could not be fetched from this
  environment; built from the 2026 text's extracts, the IFF's "What's new" and the 2022 edition, see docs/RULES.md);
  markets, languages and real local terms (docs/LANGUAGES.md); the name (Floorball Unleashed: no floorball game on Google
  Play, "Rink Rush" clashed).
- Project: Godot 4.7.2, GL Compatibility, self-contained in floorball-game/, infrastructure taken from a snapshot
  of Takraw Smash (commit 2b800d1 of claude/kind-clarke-3g5fqs): UI helpers, DragScroll, Geo, Crowd, the
  translation build, check_scripts/check_pages.
- game/rules.gd: the rules as a pure module (rink geometry and areas, restart spots, offences and sanctions, goals,
  the clock in both modes, the penalty bench with the 2026 coincidental rule, overtime, the penalty-shot competition).
- The match: rink and hall in code (game/arena.gd), the ball's physics (game/ball.gd), bodies on a humanoid
  skeleton with the stick as a bone (game/body.gd), players with one writer of position (game/player.gd), team AI
  in a 2-1-2 with flying line changes (game/team_ai.gd), the match (game/match.gd): face-offs, hit-ins, free-hits,
  advantage and delayed penalties, penalties and the bench, goalkeepers' saves, the 3-second rule, periods,
  overtime, the penalty-shot competition, two referees who signal; HUD with a floorball scoreboard and penalty
  timers; touch controls (joystick, three buttons, held SPRINT, left-handed, sizes, drag to move, saved).
- Menus: the whiteboard home screen with an AI v AI match behind it, Quick match setup, World Finals (16 teams,
  the World Championships' format), Settings (language, difficulty, game speed, auto switch, graphics + auto,
  frame rate, camera, numbers, sound, music, vibration, left-handed, button size, move buttons, About with
  privacy, help, licences and the seven-tap dev overlay), How to Play (controls, rules with numbers, the
  referees' signs drawn), result screen with a box score, loading screen.
- tests/test_runner: a check for each rule; AI matches with a motion audit (one write a frame, no jumps).
- AI calibrated with tests/ai_bench (per 60 minutes): 10.0 goals, 120 shots, 75.7% save rate, 5 penalties,
  30 face-offs (real: ~10 goals, ~95 shots, ~73% saves).

- 15 languages in the game and in store listings (AI translators with each country's federation terms; doubts in
  docs/LANGUAGES.md); fit_audit clean: 15 languages x 16:9, 19.5:9, 20:9 with a cut-out, 4:3 (Thai's space-free lines
  exempt from the whole-word check, as Japanese is).
- input_test: every scrolling page scrolls when a drag starts on its text. test_runner: 436 checks green.
- CI: floorball-android.yml (tests, fit audit, input test, APK signed with the owner's beta key since 0.7.1 (the public debug key before), release
  floorball-unleashed-beta), floorball-play-bundle.yml (passed, unsigned); standalone workflows in floorball-game/.github.
- Draft PR #7, subscribed. Pages in floorball-unleashed/. Icon, menu music. README, RULES, LANGUAGES, MESHY_BRIEF, PLAY_STORE.

- Penalty shot awarded in play for a foul on a clear chance (tested); time-outs granted at the next stoppage, the AI
  calling one a goal down late; store screenshots (7) and feature graphic; perf numbers in the README (Low: 89 draw
  calls, 49k triangles); CI green; beta APK 0.1.0-beta on the floorball-unleashed-beta release (31 MB).
- **Initial build complete** (21 October 2026, about 10:40 UTC).

### Round two: 0.2.0-beta (21 October 2026, evening)

- **Played through** in Chromium on the Web export with real touch events at 1280 x 720, 1600 x 720 and
  2400 x 1080 on Low: Quick match and World Finals matches, screenshots looked at. docs/PLAYTEST.md lists what was
  found, worst first, and what was fixed (with a test where one could be written). The worst: your free-hit could
  not be taken by touch; a penalty that ran out left the team short; a won tackle went straight back to the carrier;
  shots were deflected almost every time; a carrier behind the goal was stuck; the ball and your player were hard to
  see; Low graphics were 40% too dark.
- **A coach for the first match**: seven tips, each once, as its moment comes (Settings > Coach tips), 15 languages.
- **The club season**: ten invented clubs with crests, a single round robin, 3-2-1-0 points, no draws, semi-finals
  1 v 4 and 2 v 3 and a final (game/season.gd, ui/season_screen.gd).
- **The empty net**: a goal or two down late in the last period, the goalkeeper off for a sixth outfield player.
- **The penalty bench seen**: the penalised player walks there and sits out his time.
- **Delay of game (507.20)**: passive play warned with the arm up, then a free-hit; your restart kept waiting goes to
  the other team.
- **Rules re-checked** against extracts of the 2026 text (the PDF itself still blocked here): free-hit 3.5 m from the
  goalkeeper area; the personal penalty 2 + 10 sat by the offender; a goalkeeper sits his own major and personal
  penalties; rule numbers 603 and 508-510. docs/RULES.md ends with what is still to check.
- **AI retuned** after the tackle and deflection fixes: per 60 minutes 9.5 goals, 101 shots (real ~10 and ~95).
- tools/ci_local.sh runs CI's checks before each push; the Android build runs on push only (no double runs).
- **0.2.0-beta** (version code 2).

### 0.4.0-beta: the graphics update (23 October 2026)

From the lead's brief and shared assets (plans/floorball-unleashed.md on claude/shared-assets):
- **Sports hall:** painted block to 1.2 m, birch slats to 6 m, block above and a band of high windows (pale sky); one
  hall floor with a rubber-tile grain round the blue rink; a white acoustic ceiling, trusses and three rows of
  fluorescent battens (Poly Haven); basketball backboards folded up under the ceiling on winch frames (built in code:
  1.80 x 1.05 m glass, 45 cm orange rim, white net); doors with green exit signs, clocks, fire alarm points, a wet
  floor sign, gym benches (the owner's model). The hall is 1 m wider (the far stand's top row came through the wall).
- **School gym:** pale painted block with a darker dado, a varnished wood floor under the rink, 15 hanging lamps,
  climbing ropes in a far corner (at the end they hung in front of the behind-the-goal camera), gym benches, a glass
  board on a bracket at each end. 1 m wider, as the hall.
- **City arena:** the first five rows of every stand as steel bleachers (made in code), the rubber floor grain.
- **Low skips** the fire alarm points, the wet floor sign, the fluorescent tube models (glowing panels in the same
  housings instead) and the floors' normal maps; only the _low models are used on Low.
- **Not used, and why:** the shared metal bleacher (its Low version is broken by decimation, its rows do not match the
  game's seating, and it would cost 46-80k triangles across the stands), the shared street basketball hoop (built a
  clean glass board instead), the gym HDR (it darkened the picture on High for no gain on the players).
- perf_probe, before -> after (draw calls / triangles): arena Low 81 / 53.0k -> 81 / 53.0k, hall Low 83 / 56.4k ->
  86 / 58.5k, school Low ~83 / ~58k -> 87 / 73.7k; Medium at most 86 / 95k; High at most 129 / 428k.
- The owner then had the three gaps made in Meshy (0.4.1): an aluminium hall bleacher (8 m sections of three
  straight rows; the sports hall's stand is now eight of them, two tiers, one MultiMesh, the crowd seated on its
  planks; the arena keeps its code-built steel rows, whose 0.42 m rows do not match and whose cost would take Low near
  its cap), a red Nordic break-glass alarm point by the hall's doors (Medium and High), and a pale birch gym bench
  along the walls. perf_probe Low after: arena 82 / 49.4k, hall 86 / 77.0k, school 87 / 74.8k.

### 0.5.0-beta: motion capture (24 October 2026)

From the lead's brief (the owner added the CMU motion capture library):
- **Walk, jog and run from real people** (CMU 35_01, 35_17, 16_55): one cycle each, retargeted onto the game's
  skeleton with foot locks by tools/mocap/bvh_to_clip.py, 30 frames a second, 9-14 KB each (assets/mocap). The
  cycle moves with the ground covered, so a foot that is down stays put (the test measures 2-4 mm at 1 to 7.6 m/s,
  ahead, on a slant and backward); the cadence is a runner's (6 steps a second at a sprint, against the old code's
  9-10). The floorball stance goes on top: lower hips with the knees bent by IK (Medium, High), the trunk bent over
  the stick, the arms on it. Referees run with the captured arms. Goalkeepers, standing, the shot, the tackle stay
  the code's. docs/MOCAP.md has the clips, the method, what was looked at and left (turns, stops, side steps, dives,
  swings, throws, idles) and why.
- **Perf**: posing 14 people 1.2 -> 2.0 ms a frame on this machine (Low 1.3 -> 1.7, without the knee IK); draw calls
  and triangles unchanged.
- Credit in Licences: "Motion capture data from mocap.cs.cmu.edu. The database was created with funding from NSF
  EIA-0196217."

### 0.6.0-beta: the sound update (24 October 2026)

From the lead's brief (better sounds, from kenney.nl and opengameart.org):
- **A recorded crowd**: the bed under play (looped seamlessly, its level following the play as before), the goal's
  cheer and roar (Gregor Quendel, CC BY 4.0), and applause from a large hall at the horn ending each period
  (eXpl0it3r, CC0). They replace synthesised noise and Kabaddi Raid's cheer.
- **Footsteps** on the hall floor (Kenney, CC0): played as each foot comes down in the motion capture, for your player
  and those within 6 m of the ball, heard from where they are (3D, softer far away), never in the menu's match or a
  pause. A menu click (Kenney) for the synthesised beep.
- All cut, faded, mono 22 kHz, levelled (EBU R128) and Ogg Vorbis q2 by tools/audio/prepare_sounds.py: 210 KB added.
  APK 0.5.0: 41.60 MB.
- A test: every sound the game plays is there, every recording loads, the crowd bed loops. docs/SOUNDS.md lists every
  sound with its source, author and licence, and what could not be found (a pea whistle, the plastic ball and the
  boards, stick on stick, shoe squeaks, a hall horn, a Nordic floorball crowd's drums and chants).

### 0.7.0-beta: the size update (24 October 2026)

From the lead's brief (the APK may grow, up to about 150 MB, for looks and sound; Low exactly as it was):
- **Sharper on Medium and High only**, as separate files those levels load: the floor's scans (rubber tiles; the
  school's boards) at 2048 px with their normal maps (they were imported at 512 px, which Low keeps), the players'
  and referees' textures at 2048 px (Low keeps 1024; cut from the owner's 4096 px originals), all VRAM-compressed
  (ETC2 on Android) with mipmaps. 4096 px was tried on paper and left: at the game's camera distances 2048 already
  passes the screen's own resolution, and it would have added about 40 MB and 30 MB of video memory for nothing seen.
- **A fuller crowd on Medium and High**: a second sheet at twice the size (assets/crowd/crowd_atlas_hd.png, 2048 x 2048,
  128 x 256 cut-outs) with five spectators rather than two: a heavier man in grey trousers, a fair-haired woman in
  jeans, a man in chinos, beside the original two (tools/crowd/make_atlas.gd --hd). A scarf and a cap were made and
  left out: at this size they read as a bib and a floating hat.
- **Richer sound**: the crowd's recordings in stereo, the bed 27 s instead of 16, its rhythmic cheering rising over it
  as an attack nears the goal, three goal cheers, two roars and two applauses taken at random; everything holds in a
  pause.
- A test: Low loads exactly its old files (the 1024 px players, the 512 px floor, the two-person crowd sheet); Medium
  and High their 2048 px ones and the HD sheet.
- perf_probe, before -> after (draw calls / triangles the same at every level; video memory, this machine):
  Low arena 29.8 -> 29.8 MB, hall 30.4 -> 30.4, school 30.5 -> 30.5; Medium 44.5-45.4 -> 58.6-59.6 MB; High
  57.6-59.3 -> 71.8-73.5 MB. APK 0.6.0: 41.79 MB.

### 0.7.1-beta: whistles and the beta key (24 October 2026)

- **Real referee whistles** (the owner's, from Pixabay, via the shared assets): a short pip at a stoppage, a free-hit
  or a penalty shot; a long blast for a face-off, a goal and a penalty shot's start; two pips for a time-out; the gym
  take as a period ends; short-short-long at the end of the match. Takes at random, heard from the nearer referee
  (3D) through a touch of the hall's reverb (an audio bus of its own); not in the home screen's match. The made-in-code
  whistle stays only as a fallback.
- **The beta's signing key**: the Android workflow (and the copy in this folder) signs with the owner's key from the
  BETA_KEYSTORE_B64 secret (zipalign, apksigner), logs the certificate's SHA-256 and fails if it is not the owner's;
  without the secret (a fork) it makes a key and warns. 0.3 to 0.7.0 were signed with uber-apk-signer's public debug
  key, so 0.7.1 needs one uninstall (docs/BETA.md); from then on every beta installs over the last.

### 0.8.0-beta: what a Swedish league match showed (26 October 2026)

The owner shared a 7-minute highlights video of a Swedish league match (white against red, 7-6, shot from high on
the side). Watched as stills every 3 seconds and two goals frame by frame. What went into the game:
- **How they play** (docs/RULES.md, "How the AI plays"): the defending team's box round the slot with the ball in
  its end; the attacking centre at the edge of the goalkeeper area, screening; passes into and across the slot shot
  first time; the long pass on the counter after a turnover. AI v AI per 60 minutes: 8.3 -> 10.8 goals, 98 -> 117
  shots (real: about 10 goals).
- **A goal's celebration**: the scorer wheels away toward the boards, his team-mates run to him and pile round him.
- **The city arena as a league arena**: a light sky-blue floor with the goal creases laid in navy (the halls keep
  their deeper blue; every venue's crease is now filled darker), big floor decals (a disc in the centre circle with
  the game's name, four panels with its slogans, no real sponsor), and after a goal **a light show**: pink and blue
  spots roam the rink and the scoring goal's crease glows, for six and a half seconds.
- **Referees in black**, as in the league; in yellow when either team wears a dark shirt.
- **Fixed: the crowd facing the wrong way.** The owner noticed it: the crowd shader mirrored its side views the wrong
  way round, so every spectator seen side-on faced away from the rink (since the crowd was first made; the facing
  test checked the numbers, not the picture). Now Crowd.view() works out the view and the mirroring, a test pins it,
  and tools/crowd/facing_view.tscn shows one spectator from all round.
- Looked at and left: an emptier crowd (the league's stands were a third full; a full stand reads better on a phone),
  "GOAL" on the stands' LED ribbons (a later job).

### 0.8.1-beta: licences, help and privacy in the game (27 October 2026)

From the lead's brief (the owner found the games' links returning 404; this game's did: its privacy and help pages
live in `floorball-unleashed/`, which GitHub Pages serves only from `main`):
- Settings > About has **Licences, Help and Privacy policy**, each a page in the game (works offline, scrolls, Back
  returns to Settings), readable on Low and on a small phone. No button opens a browser any more.
- **Licences**: every source by name, author and licence (the Meshy models; Poly Haven's lamps, clock, sign and
  surfaces with their authors; the CMU motion capture line and clips; the Pixabay whistles and their authors; Gregor
  Quendel's crowd, CC BY 4.0; eXpl0it3r's applause; Kenney; the fonts under the OFL), the Godot Engine's licence and
  every notice it ships (Engine.get_copyright_info, get_license_info).
- **Help**: playing, the controls, the rules in brief, the graphics levels, what to try if something is wrong, and how
  to report a problem (with the version).
- **Privacy policy**, true to the build: no personal data, no account, no ads, no analytics, no internet permission,
  what stays on the phone, the one permission (vibration), dated, with a contact. The same text is public at
  docs/PRIVACY.md for the store listing (store/PLAY_STORE.md).
- A test opens each page from Settings and checks its words, its scrolling and its way back; the fit audit covers
  them in every language and screen shape.

### 0.8.2-beta: ready for Google Play; the media kit (27 October 2026)

From the lead's Play Store readiness brief (and its update: the store pictures and text are drafts, the privacy
address waits for the owner's own site), and the media kit brief:
- **Play's technical rules, checked on the bundle**: targetSdkVersion 36 (Play asks 35+), minSdkVersion 24; both
  ABIs in the bundle (arm64-v8a and armeabi-v7a, so 32-bit phones keep the game), the 64-bit libraries aligned to
  16 KB pages (tools/check_pages.py, on every bundle); the bundle about 78 MB, well under the 200 MB base module
  limit; one permission (VIBRATE); version code 12, only ever raised; applicationId com.floorballunleashed.game, the
  same as the Obtainium list.
- **The soak test** (tests/soak.tscn): thousands of random taps, drags, Backs and trips to the background across
  every screen, then matches you play (mashed: leaving by the pause menu or Back is allowed) and AI v AI matches
  played to the end, on Low and on High. It counts every engine or script error (a Logger), every frame over 2 s,
  any screen lost, any match not paused or not kept when the app goes to the background, and reads the saves back.
  **Soak, 27 October 2026** (`soak.tscn -- <graphics> 3000 5`, xvfb, software OpenGL): Low, 5,000 steps (3,000
  menu inputs over ten screens, 2,000 in five matches you play), five AI v AI matches to the end: 0 errors, 0 frames
  over 2 s, 0 screens or matches lost, saves read back. High: the same, 5,000 steps and five more AI v AI matches,
  0 errors, 0 stalls, 0 lost, saves ok. Ten AI v AI matches in all; Back pressed about 500 times on every screen but
  the home screen (where it closes the game), and the app sent to the background and back about 250 times, each
  time a match was on it was paused and kept. Nothing to fix.
- **Signing for Play**: Play App Signing with an upload key the owner makes (the keytool line, the three repository
  secrets, which the bundle workflow reads when they are there); the beta key stays the beta's.
- **The store kit as drafts, made again by one command**: tools/store/refresh_store_kit.sh captures the screenshots
  from the game on High, remakes the feature graphic and the 512 px icon (now 32-bit RGBA, as Play asks), and checks
  every size and every listing's lengths (the French name was 37 characters: now "Floorball Unleashed").
  store/PLAY_CONSOLE_ANSWERS.md has every Console form's true answer: Data safety (nothing collected or shared), the
  IARC questionnaire, the target audience (13+, and why not the Families programme yet), no ads, no purchases, the
  category, tags and contact; the privacy address TBD (the owner's site).
- **The media kit** (tools/media/): media_kit.tscn captures every menu clean and, for each trailer clip, finds its
  moment (a goal, a save, a penalty, the face-off) by playing the match unseen, then plays it again from the same seed
  and records it; make_trailer.py cuts a 41 s 16:9 trailer and a 15 s 9:16 cut with the game's own music, crowd and
  whistles, draws the cards in the game's fonts, and packs the zip with the website text (store/media-kit/text/) and
  CREDITS.txt. The workflow "Floorball Unleashed · media kit" builds it and puts it on the release
  floorball-unleashed-media (a prerelease, never "latest").

### 0.9.0-beta: Vulkan, new menus, Penalty shots, Watch a match, a new goalkeeper (29 October 2026)

The owner's list:
- **"The colour scheme and menu look kind of lame"**: the whiteboard is gone. Arena night: deep navy, the icon's
  flame orange (what to press) and electric blue (accents), white words; headings in Barlow Condensed leaning forward
  as a broadcast sets them; dark cards cut on a slant; the home screen the live match full screen, darkened on the
  left under the name and six tiles (Quick match, World Finals, Club season, Penalty shots, Watch a match, How to
  play), Settings and the language top right. The same theme carries every screen (game.gd's palette and theme,
  ui/backdrop.gd, UI.note).
- **"Watch an AI match like the other games"**: Watch a match (the home screen): pick two teams, the division and the
  venue; a match like any other (scoreboard, pause, camera, result screen), both teams the computer's, no buttons.
  Nothing is recorded to your results.
- **Better phones, better graphics, as Hurling did**: Vulkan at every level, GL Compatibility as the fallback
  (game/renderer.gd, docs/GRAPHICS.md); every shader's colours the same on both; High on Vulkan lit like a
  broadcast (soft 4096 shadows, light pools under the lamps, bloom, the floor reflecting the hall). Medium and High
  are picked for recent phones on the first run. Meshy: no new models were needed (the owner's models are already
  drawn whole on High); no credits spent.
- **"A mini game like Free Taking, for penalty shots, used in real games too"**: Penalty shots (the home screen):
  ten shots at a goalkeeper, aimed by timing (game/penalty_aim.gd, after Hurling's PlacedAim): a target round the
  goal mouth, SHOOT stops it; a bar below, SHOOT again in the green and the ball goes there, out of it the shot
  pulls wide. The goalkeeper kneels in the middle: the middle is his, a top corner the hardest (match.gd
  _check_shot). Shots 3, 6 and 9: the top corners lit gold, worth double. Each shot a little harder; the best kept;
  an end card with a word on it. In a match, your team's penalty shots (a clear chance fouled, and the penalty-shot
  competition) are taken the same way. Every penalty shot has a close camera, low behind the shooter, and on High
  the ball near life size with its 26 holes.
- **"Make sure the crowd is actually watching the game"**: each spectator turns from facing the rink toward the
  ball, by their own amount, up to 70 degrees, a moment behind it (crowd.gd focus, match.gd _crowd_noise).
- **"Text around the arena in the phone's language"**: the boards' slogans and the arena's floor decals are drawn in
  the phone's language (game/signage.gd; 14 languages, the sport's own word in each).
- **"Find more animations for the goalie, the worst of the movements"**: rebuilt (player.gd _keeper_pose): down in
  the butterfly on his knees when the ball is in front of his goal, up in his crouch when it is far; side-steps
  standing and knee-shuffles kneeling as he moves along his line; a low save a leg kicked out flat to the ball's
  side, a high one an arm thrown up and the body leaning after it; a catch to the chest; an overarm throw-out; every
  pose easing into the next (nothing snaps). Sources looked at for real goalkeeper capture: none free for a
  commercial game has one (CMU, Quaternius CC0, 100STYLE, and the non-commercial ones ruled out); Mixamo has
  goalkeeper clips but needs the owner's Adobe login (Needs the owner, below).
- **"Go through our new API that connects to free sounds"**: freesound.org is refused by this environment's network
  (HTTP 403 from the proxy), and there is no sound connector in the session; Pixabay's API needs a key. Nothing new
  could be fetched (Needs the owner, below).
- Tests: an aimed penalty (green where aimed, red pulls to that side, the close camera and back), ten practice shots
  through to the end card and the best, Watch a match (a match with no buttons and nobody yours), the crowd's focus
  on the ball, the signage in Swedish and Finnish; the fit audit covers the new screens.

## Next (in order)

1. Phone testing on a low-end device (Galaxy A0x/A1x class): frame rate on Low, touch feel, button reach, the coach's
   notes on a real screen.
2. The 2026 rules PDF read against docs/RULES.md's "Still to check" list.
3. Native-speaker review of the translations (docs/LANGUAGES.md), the coach's tips first.
4. Club season extras: a short 3 v 3 overtime as the Nordic leagues play it, a second season, form and streaks.
5. The penalty benches and secretariat as real models; Meshy bodies if the owner wants them (docs/MESHY_BRIEF.md).
6. The World Finals' tables in bigger type on phones.

## Decisions and why

- **Name: Floorball Unleashed** ("Floorball Unleashed" on Play, so a search for floorball finds it). No dedicated
  floorball game was found on Google Play; Rink Rush, Holeball and 26 Holes clashed with existing titles.
  A trademark search (EUIPO, USPTO) is for the owner before launch.
- **No governing body named in the game or store**: the brief rules out real governing bodies' names (Takraw had
  to remove them), so the game says "the international Rules of the Game"; docs cite the IFF.
- **National teams only**, players with invented names drawn from each country's common names.
- **Look: a coach's whiteboard in a Nordic sports hall**: light board, marker inks (Caveat), magnets as chips and
  buttons, notes pinned for the menu. Unlike Kabaddi's dark tiles and Takraw's navy panels.
- **Broadcast camera** high on the near side (the secretariat's), benches across the picture, as floorball TV does.
- **The stick is a bone of the body's skeleton**: one draw call a player with his stick.
- **Penalised players**: the rules module tracks who sits; on the rink the player's place is taken by a team-mate
  from the bench and the team plays short by hiding the wingers' places; a figure of the penalised player walks to
  the penalty bench and sits there (two a team at most, as no more than two penalties run).
- **The empty net**: only a goal or two behind, in the last minutes of regulation time (8% of the period, at least
  20 s), with the ball in the opponents' half; never short-handed. Back after a goal, at the period's end, or at a
  stoppage once level.
- **Passive play**: warned after 30 s with the ball in the team's own half or behind the opponents' goal (building
  in their half holds the count); then a shot within 8 s or a free-hit to the other team.
- **Club names**: colour or material and an animal (Copper Foxes, Glacier Wolves...), the same in every language, no
  towns, so no real club can be meant.
- **Game speed Steady (80%) by default**: 12 players at real floorball pace is hard to follow on a phone screen.
- **Penalty shot in play**: awarded when the fouled player is in the attacking half, within 12 m of goal, in front of
  it, with no defender but the offender between him and the goal (our reading of "a clear chance"); the clock stands.
- **Coach tips**: notes, not a separate tutorial: a first match is a real match, and each tip comes when its
  moment does, so nothing has to be read before playing.
- **Time-outs**: granted at the next stoppage with the referee's T; the 30 seconds are signalled, not waited out.
- **Overtime keeps the third period's ends** (2026 rule 203 text on ends was not retrieved).
- **armeabi-v7a**: the Play bundle keeps 32-bit too (older phones in Thailand, the Philippines and eastern Europe
  run 32-bit Android); the beta APK is 64-bit only to keep it small, as Kabaddi's and Takraw's.
- **German with ss, not ß; the sport called Unihockey in German, French and Italian prose**: most German, French
  and Italian speaking floorball players are Swiss.

## Shared assets

The owner (Josh) has made the orchestrator session (session_016XKAyHkTQRNMGEgZbjNK28) the lead for all six mobile
games. Assets that suit more than one game come from it: they are listed in `shared-assets/README.md` on the branch
`claude/shared-assets` (large files on a "shared-assets" GitHub release), each with its source, licence and the games
it suits, and a message says what each new one is and how to fetch it.

**Briefs from the lead need no go-ahead.** The owner, 22 October 2026: "Go, you don't need to ask permissions": a
brief the lead session relays from the owner is started straight away.

## Needs the owner

- **Mixamo goalkeeper clips** (needs an Adobe login, which this environment cannot do): download from mixamo.com, "Without Skin", FBX, 30 fps: Goalkeeper Idle, Goalkeeper Catch, Goalkeeper Diving Save, Goalkeeper Body Block, Goalkeeper Scoop, Goalkeeper Sidestep, Goalkeeper Overhand Throw (whichever exist under those names), and share them (a Google Drive folder, as for Hurling): they can be baked onto the game's skeleton like Hurling's.
- **Sounds**: the freesound connection is not reachable from these sessions (the network refuses freesound.org). Either connect it to the session, or download and share: a floorball (plastic, holed) off a composite blade, stick on stick, shoes squeaking on a sports floor, a hall's period buzzer, a floorball crowd with drums.

- Play Console account, the upload key as repository secrets (store/PLAY_STORE.md), a trademark search on the name.
- A native speaker's check of each translation (docs/LANGUAGES.md lists the doubtful strings).
- A read of the 2026 rules PDF against docs/RULES.md's "Still to check" list.
