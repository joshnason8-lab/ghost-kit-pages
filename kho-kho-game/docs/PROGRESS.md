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

## Next

1. A native speaker's pass over each translation (docs/translation-notes/), and the rule-book conflicts in
   docs/RULES.md checked against a printed KKFI rule book (the rulebook sites were blocked from here).
2. A real phone at Low (a Galaxy A0x/A1x): frame rate, warmth, and whether the coach tips teach the game in a
   minute to someone who has never played it.
3. The City League's own season mode: squads that change, a player draft, a season's records.
4. Defending feel: a juke button, and the AI's chasers reading your defender's runs.
5. Meshy models when the owner chooses (docs/MESHY_BRIEF.md).

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
