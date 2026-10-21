# Khamba Dash: progress

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
- Screens: home (the kho lane menu over an AI match), match setup + toss, settings, how to play, records, result
  with box score, championships (world, to fast rules; national, to classic rules), licences, move buttons.
- Venues: village ground at dusk, school ground, indoor arena on mats, floodlit stadium.
- test_runner green: 307 checks.

## Next

1. Push the skeleton, open the draft PR, CI green, beta release.
2. Translations for the 13 other languages (subagents), fit_audit clean at the four shapes.
3. docs/RULES.md, docs/LANGUAGES.md, docs/AI.md, docs/MESHY_BRIEF.md, docs/BETA.md, README.
4. Pages (khamba-dash/), store/PLAY_STORE.md, listings, icon, feature graphic, screenshots from the game.
5. Music (tools/audio/make_music.py, a dhol and harmonium loop), perf_probe numbers in the README.
6. Polish: AI tuning to the measured rates, motion check on the kho and dive, the user-chaser feel.

## Decisions, and why

- **Name: Khamba Dash** ("khamba" is the pole in Hindi and Marathi). Checked against Play by search: the existing
  apps are "Kho Kho Game", "Kho Kho 3D", "Kho Kho World Cup", "Kho.Kho" (the official world cup app); "Ultimate
  Kho Kho" is the league's brand. "Khamba Dash" turned up nothing. "Kho Kho" goes in the store title's subtitle for
  search: "Khamba Dash: Kho Kho".
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

## Needs the owner

- Play Console account, the upload key secrets (store/PLAY_STORE.md), and a native speaker's check of each
  translation marked in docs/LANGUAGES.md.
