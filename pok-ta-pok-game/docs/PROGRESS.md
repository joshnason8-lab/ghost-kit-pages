# Progress

Pok Ta Pok Rivals is the seventh game in the family. Branch `claude/pok-ta-pok-game`; release tag
`pok-ta-pok-rivals-beta`; folders `pok-ta-pok-game/` (the Godot project, self-contained, with its own
`.github/workflows/android.yml` for a standalone repo) and `pok-ta-pok-rivals/` (the pages). The root workflows are
`.github/workflows/pok-ta-pok-android.yml` and `pok-ta-pok-play-bundle.yml`, path-filtered to these folders.

**If you are resuming:** read this file and `git log` first.

## Done

- **Research** (October 2026): rules, court, ball, officials and clothing from Aguilar-Moreno, CONADE, the
  Secretaría de Cultura inventory, the UNAM thesis, NPR, Penn Museum and the Met (docs/RULES.md). Markets and languages
  from StatCounter, INEGI, DataReportal, Pew and Mexican tourism figures (docs/LANGUAGES.md). Name check: nothing
  called "Pok Ta Pok Rivals" was found. The closest is "POK" on Steam (2027) and "Ulama" on Play, so the title is
  kept.
- **The rules module** (`game/rules.gd`):
  - The ulama count: one side holds it; a raya to the holder adds one; a raya to the other side takes one off.
  - Urria on 3 and 7, or 3, 5 and 7, or off. Eight wins.
  - Who wins a raya: the ball dies in a half, goes past an end, goes out at a side, or touches a player anywhere but
    the hip.
  - The serve: male abajo or male arriba.
  - The classic court's points and the ring.
  - The time limit.

  Every rule is tested in `tests/test_runner.gd`.
- **The match**:
  - A heavy ball (3.6 kg, bounces 0.42 on earth and 0.58 on stone, rolling resistance) with the classic court's talud,
    walls, end courts and rings.
  - Players with one writer of position, acceleration limits and strides matched to speed.
  - Hip strikes and dives timed to the ball.
  - Team AI that reads the ball's path, turns side-on and sends deep lobs or low skidding drives.
  - Two judges (veedores) at the analco who signal each raya.
  - A raya tally board.
  - Pause, auto graphics, haptics only for your own side.
- **Bodies**: code-built and lit (not cel-shaded), on 17 bones, wearing the documented ulama gear (gamuza, chimali,
  faja). The classic court's yoke and knee pad are reconstructed. Judges wear everyday clothes.
- **The crowd**: one draw call, rendered at load time from the same 3D bodies (front and back), everyone facing the
  court. This is tested at every venue and graphics level.
- **Four venues**:
  - A Sinaloa village court at dusk.
  - A festival court by day, with stands, awnings and papel picado.
  - A Yucatán stone court in the forest, with a pyramid on the skyline.
  - The stone court by torchlight.

  They use the shared skies and surfaces, Poly Haven limestone (CC0) and shared tree cards; the agave is built in
  code.
- **Screens**:
  - The home screen is a carved stela whose glyph blocks are the menu, read in paired columns.
  - Match setup: the court, two towns with their players by position, a court diagram, side size, urria, time,
    level.
  - The town tournament: eight towns, knock-out.
  - The result screen with a box score.
  - Settings, How to Play (four tabs, including the story), the licences, and Move buttons.
- **Six languages** (es, en, pt, fr, de, it): fit_audit is clean on every screen at four screen shapes.
- **CI**: the root and standalone workflows, both green on the PR. The beta APK (64- and 32-bit) is on the
  `pok-ta-pok-rivals-beta` release, and the Play bundle workflow passes (unsigned).
- **Store**: `store/PLAY_STORE.md`, listings in 11 Play locales (`store/listing/`), the 512 icon and the feature
  graphic rendered from the stone ring, and six 1920x1080 screenshots (`store/graphics/`).
- **Performance** (perf_probe, after the body reduction): village Low 59 draws / 53k triangles, stone Low 60 / 64k,
  both well inside the Low budget (100 draws, 90k triangles). High: village 75 / 138k, stone 74 / 131k. The crowd is
  one draw call at every level.
- **Pages**: `pok-ta-pok-rivals/` (index, privacy, support).
- **0.2.0 (October 2026)**:
  - **Motion capture** (CMU Graphics Lab library, mocap.cs.cmu.edu; credited in Licences). The run is take **09_02**
    (subject 9, "run"), the serve's underhand toss **124_12** (subject 124, "Underhand Toss", 4.4–6.0 s, release at
    5.43 s). `tools/mocap/bvh_retarget.py` retargets them to the 17 bones: one gait cycle cut between left-foot strikes,
    resampled to 30 fps, root motion dropped (the player is still the one writer of position; only the clip's speed
    and cycle length are kept), the upper arms' and thighs' twist from the elbow's and knee's plane, and foot locks:
    a small drawing-only offset of the hips holds a planted heel or toe still while the root moves on. The run blends
    in from 2 to 3.2 m/s over the hand-made one; strides are matched to the clip. The serve plays the toss at its own
    speed (SERVE_T 1.6 s, release at 0.64), abajo bowled lower by blending in the hand-made serve; the ball sits in the
    hand bone. Low plays the nearest frame. With low balls now dived for, a dive's return is a scramble (least error 0.55, 62% of the power), or the hard level kept rallies alive for a minute. Tests: each clip loads, and a planted foot slips under 3 cm (worst 2.7 cm).
  - **Meshy people**: three ulama players (lean, tall, stocky), a judge and eight townspeople, made with Meshy (560
    credits: 1,763 before, 1,203 after). The players are rigged and follow the game's skeleton bone by bone
    (`game/rigged_body.gd`); the gear (faja in the team's colour, chimali, yoke, knee pad, a judge's hat) stays code-built
    over them. The crowd's sheet is rendered from the townspeople at loading. Prepared for phones by
    `tools/meshy/prepare.gd` (9.4k triangles High, 4.7k Medium, 3–4.7k Low; 1024 textures; the fans 512).
  - **The owner's list**: menu music (an original piece for cane flute, frame drum, slit drum and seed rattles,
    `tools/music/compose.py`); the dusk court readable (brighter, rim light on the bodies, a faint pale ring round the
    ball, the ulama camera closer); the server no longer spins on the spot holding the ball (he turned to face the ball
    in his own hand: a bug); a standing hip cannot meet a ball below 34 cm (dive for it); the ring shot (see RULES);
    a slowed replay from below the ring after a ball through it; Settings: play the whole team or one player.

- **0.3.0, the sound update** (docs/SOUNDS.md): recorded sounds from kenney.nl (CC0) and opengameart.org (CC0, one
  CC-BY 4.0 crowd pack), made by `tools/sound/process.py`. A recorded body thump under the hip strike, the ball on
  earth, bare feet on earth and stone, the crowd's murmur, cheer and applause (real crowd recordings, softened), interface
  clicks, and each court's surroundings: crickets and a far dog in the village, birds in the Yucatán forest, crickets and
  the torches' fire at night. Pause holds every sound. Players grunt or breathe on half their strikes. Audio went from
  748 KB to 1.4 MB. A test checks every sound file loads and that nothing plays while paused.
- **0.4.0, the size update** (the owner allowed the APK to grow for looks and sound; Low unchanged, tested):
  - Medium and High load sharper surfaces: the six Poly Haven surfaces at 1K (Medium) and 2K (High; its normal maps at
    1K, as a 2K normal map compressed for phones is 5.6 MB and its detail does not show at a match's distance),
    VRAM-compressed (ETC2 on phones) with mipmaps. Low keeps the 512 files.
  - High's skies at 4K (Poly Haven, tone-matched to the 2K ones within 2/255); Low and Medium keep the 2K.
  - The Meshy players' and judge's own 2048 textures on Medium and High (VRAM-compressed); Low keeps the 1024.
  - Eight more Meshy townspeople (a Yucatec woman in a huipil, a Sinaloa man in a texana, an old man with a cane, a
    girl, a mother with a baby in a rebozo, a young man in a plain football shirt, a Maya man in white with a red sash,
    a woman in an apron): Medium and High bake a crowd sheet of 32 figures at 96 x 264 pixels each; Low
    keeps sixteen at 64 x 176.
  - The carved stone ring (Meshy), fitted to the ring's exact hole and size, on Medium and High.
    The stela came back looking like a classical column, so it was not used.
  - Long stereo recordings for each court's surroundings and a longer crowd bed with chatter on Medium and High (JC
    Sounds, CC-BY 4.0; Gregor Quendel), and three cheers and two applause takes in turn.
  - Meshy credits for this update: 440 (1,203 before, 763 after), for the eight townspeople, the ring and the stela.
- **0.4.1, the beta key**: both APKs are signed with the owner's beta keystore (repository secret BETA_KEYSTORE_B64)
  instead of a build tool's own debug key, so every beta from now on installs over the last. CI logs each APK's
  certificate SHA-256 and fails if it is not the beta key's. Without the secret it warns and falls back. A phone with
  an earlier beta (signed with the old key) has to uninstall it once.
- **0.5.0, from the owner's two videos of pok ta pok in Yucatán** (a night street game in Mérida with a ring on a post,
  and a court game in a park with sloped benches and wall rings):
  - The stone courts serve *de bote*: thrown up and over to come down just past the analco and played off the bounce
    (the receivers wait for it to bounce; tested). Ulama's earth courts keep their documented rolled and thrown serves.
  - The ball is livelier on stone (0.58 to 0.68 bounce; talud and walls likewise) and a rolling ball slows sooner
    (0.7 to 1.3 m/s²); earth unchanged. On stone the AI waits for a ball to come up off a bounce rather than diving,
    a dive scoops the ball up (at least 26°), and its power follows its timing: at the hard level the stone court
    had become minutes-long rallies of dives back and forth (CI caught it); now most balls are hip strikes, as in
    the videos. Ulama's dives are as they were.
  - The copal offering before games on the stone courts (game/ritual.gd; docs/CULTURE.md has what was decided and
    why): an elder in white with a smoking censer, players' arms raised to the sky, a conch; skippable; not on the
    Sinaloa courts.
  - Not changed: the many variations in the videos (the Mérida game's freestanding ring on a post, its street court,
    the park show's painted figures). The ring on a post belongs to the revival rule set still on the Next list.
- **0.5.1, the legal pages in the game**: Settings > About opens Licences, Help and the Privacy policy as the game's
  own screens (they scroll, have Back, and work offline); the game opens no web pages. Licences lists every outside
  work by what it is, who made it, its licence and where it is from (CMU motion capture, Meshy, Poly Haven, Kenney,
  Gregor Quendel, JC Sounds and the four CC0 OpenGameArt sounds), then the fonts, Godot and the engine's parts. Help
  has how to play, the controls, the rules in brief, the graphics levels and how to report a bug. Privacy says what
  this build does: no data collected, no ads or analytics, no internet permission, vibration only. Both in six
  languages; a test opens each from Settings in every language and checks it has its text and Back. The public
  privacy page (pok-ta-pok-rivals/privacy.html) says the same and is what the Play listing links to once merged.
- **0.5.2**: the fonts' notice no longer credits Uncial Antiqua (a font this game does not ship; the notice came from
  another game), and gives the Oswald project's current address beside the one its font file carries (which no longer
  exists).
- **0.5.3, ready for Google Play** (the steps only the owner can take are in store/PLAY_STORE.md):
  - The soak test (tests/soak.gd), at Low and at High:
    - 5,000 random taps, drags, Back presses and trips to the background through every screen and the matches they
      lead to;
    - twelve AI matches over the four courts, paused and resumed and Backed out of during play;
    - Back on every screen;
    - a tournament match paused and resumed, with its save checked.

    No crash, script error or lost save. One stall found and fixed: Licences laid out all the engine's licence texts
    at once (over a second on opening). Now each is listed by name and opens on a tap.
  - The bundle workflow prints the bundle's sizes and fails over Play's 200 MB base module (tools/aab_size.py). It
    also checks the per-device APKs Play would serve with zipalign -P 16.
  - The store kit:
    - the listing in eleven languages, updated for the realistic players, the stone courts' serve and offering, the
      replay and one-player mode;
    - the first release's notes (store/RELEASE_NOTES.md);
    - the 32-bit 512 icon;
    - new screenshots on High;
    - every Play Console answer with its reason (store/PLAY_CONSOLE_ANSWERS.md).
- **0.5.4**: the ring replay is no longer hidden. The big "REPLAY" banner and the call's "Through the ring!" sat over
  the ring just as the ball went through it. Now a small REPLAY tag sits in the corner, and the call clears when the
  replay starts. The store drafts are regenerated from this build (tools/store/make_store_graphics.sh), and the media
  kit's tools are in tools/media (make_media_kit.sh).

## Next

1. **The pok-ta-pok / pelota maya revival** as a third rule set on the festival court. The tournament rules are
   documented: one strike per side, end line +4 or +5, foul points, a ring that wins outright, halves of 13 minutes.
2. New store screenshots and feature graphic with the realistic bodies.
3. Yucatec Maya touches: the judges' count on the stone court (*jun, ka', óox…*). It is listed for a native speaker
   in docs/CULTURE.md.
4. Field recordings the open sites do not have (docs/SOUNDS.md, "Not found").
5. Meshy court pieces (docs/MESHY_BRIEF.md: the carved ring, the talud, the pyramid).
6. A Classic-period court variant with floor markers and no rings.

## Decisions and why

- **Ulama de cadera is the main mode.** It is the living game with the most documentation (Aguilar-Moreno played
  and filmed it). The stone court is labelled "Classic court (reconstructed)" everywhere it is offered.
- **60 × 4 m taste:** Aguilar-Moreno's figure, in the middle of the 50–69 m range the sources give.
- **The count:** a raya against the holder takes one off (Wikipedia's reading), not NPR's one-line "the lead passes
  over". Urria defaults to 3 and 7, where Aguilar-Moreno (2–3, 6–7) and CONADE (3, 5, 7) overlap.
- **Serve kind:** rolled from level, thrown once a side holds the count. The side that won the last raya serves.
  Both are reconstructed, because the sources say the serve changes with the score but not how.
- **4 or 5 a side in ulama:** the documented numbers. 2–4 on the stone court is the game's own choice.
- **Time limit:** a 2022 national meet used 30 minutes. The game offers 6, 10, 15 or none; at time, the holder wins,
  and if level the next raya wins.
- **Each side stays in its own half.** It is implied by the sources (the analco divides the sides) though not stated.
- **Meshy bodies over the game's skeleton** (0.2.0, the owner allowed credits): the realistic mesh follows the code
  skeleton, so every pose, the recorded clips and the hit points stay the game's; the team colours stay code-built gear.
  The prompts put the T-pose first and spell out "no headdress, no feathers": the first players came back flexing, in
  fringed skirts and once with horns. A second hat-wearing judge kept coming back hatless and hands in pockets, so both
  judges wear the one judge model, one with a code-built straw hat.
- **Mocap: what was not used.** The CMU dives (subjects 127/128) are forward parkour rolls, not ulama's sideways drop
  onto the hip; the soccer kicks (10, 11) would teach a foot touch, which is a fault; nothing in the library is a hip
  strike; the judges' signals are the game's own and seen from afar. Those stay hand-made. Of the runs, 09_02 has the
  smallest hip correction (±12 cm); the jogs (35_17, 35_22) ran at the same speed, so one clip serves.
- **The ring stays rare** (the chroniclers' "very seldom"), but it is a skill now, not luck: a perfect strike from a
  good spot goes in about one time in three, a good one about one in ten, an ordinary one hardly ever (tested).
- **Crowd from the bodies:** the painted cut-outs looked cartoonish, so the sheet is rendered from the 3D bodies at
  loading. Headless, a painted sheet stands in.
- **No real place copied.** The stone court is generic and modelled on the smaller ringed courts. No site or tourist
  park is named.
- **Languages:** Spanish first. English, Brazilian Portuguese, French, German and Italian cover the diaspora,
  Brazil's market and the visitors to the Maya sites. Yucatec Maya appears as touches only, because Play has no
  listing locale for it and the translation needs a native speaker.
- **armeabi-v7a kept** (a 32-bit APK beside the 64-bit one, and both in the bundle): older and Android Go phones in
  Mexico and Central America still run 32-bit Android, as Hurling found for the Galaxy A0x.
- **Assist on by default:** your player is moved to meet the ball and the timing is yours. Timing a hip strike is the
  skill, and steering a player along a 60 m court with one thumb as well was too much on a phone.
- **Android SDK in this container:** dl.google.com is blocked here, so local exports use stub SDK tools; CI uses the
  runner's real SDK.

## Needs the owner

- **Play Console:** the upload-key secrets (`ANDROID_UPLOAD_KEYSTORE_BASE64`, `ANDROID_UPLOAD_KEY_ALIAS`,
  `ANDROID_UPLOAD_KEY_PASSWORD`) for a signed bundle, and the store listing upload.
- **Meshy credits:** docs/MESHY_BRIEF.md.
- **A knowledgeable reviewer:** docs/CULTURE.md.
