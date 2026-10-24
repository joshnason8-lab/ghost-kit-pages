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
3. The City League's own season mode: squads that change, a player draft, a season's records.
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
