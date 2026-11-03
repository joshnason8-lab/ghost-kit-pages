# Graphics update 0.9.0: progress and decisions

The owner asked for every game's graphics to be upgraded (the lead session's brief: `shared-assets/plans/COMMON.md`
and `plans/kabaddi-raid.md` on branch `claude/shared-assets`). This is what Kabaddi Raid did with it, ground by
ground, what it skipped and why, and what still needs the owner.

## What is in

| Ground | Sky | Ground surfaces | Round it |
|---|---|---|---|
| **Gaon Maidan** | `qwantani_dusk_2`, turned so its low sun sits where the ground's sun is (over the far side, raised from 14 to 17 degrees) | the court in beaten earth (`brown_mud_dry`), going to red earth (`red_dirt_mud_01`) past its lines, then to worn grass (`grass_ground`) further out | rain trees, island trees and coconut palms as cut-outs; dry grass (`dry_grass_tall_card`) round the edge and against the houses; two rows of white plastic chairs (`monobloc_chair`) along the far side with the village sitting on them; folding stools (`folding_stool`) at both ends; a trestle table for the scorers (`scorers_table`) with their chairs; four houses in plastered walls (`clay_plaster`, lime-washed colours) under clay tiles or thatch (`clay_roof_tiles`, `thatch_roof_angled`); the village temple (`indian_village_temple`, added to the shared assets during this update) across the ground, facing the court, beside a rain tree |
| **Monsoon Ground** | `overcast_soil`, its colour taken down (it was brown at the horizon) | wet mud (`brown_mud`) with puddles (the water's normal map, rippling; the sky in them), grass further out | rain trees dark with the wet, palms; plastic chairs under a blue tarpaulin on bamboo poles at one end, in its shade |
| **Puri Beach** | `qwantani_sunset`, turned so its sun is over the land behind the broadcast camera (Puri faces the Bay of Bengal to the east, so the evening sun cannot be over the sea), and the ground's sun brought down to an evening 24 degrees (it was 48), its light warm | dry sand (`coast_sand_01`) going to wet sand (`damp_beach_sand`) toward the water, sloping down into it | a new sea (the water's normal map in two drifting layers, deep and shallow water, the sky in it, surf where it runs up the sand, out to the horizon); coconut palms along the shore, island trees inland; plastic chairs along the far side; the Jagannath temple's tower (`jagannath_tower`, added to the shared assets during this update) on the far shore of the bay up the coast, 850 m off in the evening haze, where the broadcast camera sees it over the sea |
| **National Stadium** | `kloppenheim_07`, a cloudy night lit by the city | grass round the stands (`grass_ground`) | the stands in photographed concrete (`concrete_floor`); a city of apartment blocks (`city_apartments`) beyond them on three sides, dark, with windows lit |
| **Mumbai Dome** | indoors (no sky) | the floor in photographed concrete (`concrete_floor`), dark and polished | the stands in photographed concrete |

Everything repeated is drawn in one go (a MultiMesh: every tree of a kind, every chair, every stool), with soft
contact shadows under the seats, also in one go. Low uses the `_low` meshes, cut-outs for every tree, the 2K
panorama for the sky's light and no HDR; Medium and High light the grounds from the HDR, use the ground's and the
walls' normal maps and the full models. Only what is drawn is in the game: not the trees' `_low` models (Low draws
every tree as a cut-out) nor the Jagannath tower's full one (it is cut down on every level, 850 m off).

The fixed parts that were many separate meshes are now one each: the stands (four boxes a tier, up to 48 meshes in
the stadium), the court's lines and benches, the dome's lamps, the floodlight towers, each house. That takes the
grounds' draw calls down by more than the new scenery adds (numbers below).

## Decisions

- **Trees are cut-outs.** The rain tree and coconut palm models (Meshy) are coarse next to their cut-outs (rendered
  from a finer model): big flat leaves, a lime green. The trees round a ground stand more than 25 m from the broadcast
  camera, so by the shared README's own rule they are cut-outs; the full models are used only for the few within
  25 m of it (behind it, seen from the third-person camera), on Medium and High. Each cut-out faces the broadcast
  camera (its other side or its mirror image for every other tree, so no two of a kind look alike), sways a little,
  and is lit partly from above as a crown is. The rain tree's picture is toned down (60 % of its colour, 82 % of its
  brightness).
- **The Jagannath tower at 850 m**, a little beyond the 400 to 800 m the plan gives: from the broadcast camera the sky
  shows only about 3.5 degrees above the horizon, so a 60 m tower any nearer has its top cut off by the top of the
  picture. It stands on a hazy headland across the bay, with palms along its shore, so it does not stand in the sea.
- **The beach's bake takes less of its sky** (45 %, `Arena.BAKE_SKY`). At the full strength the other grounds use, its
  clear evening sky lit the open sand almost as brightly as the sun did: from the broadcast camera the sand in shade
  was 72 % as bright as in the sun, the shadows hardly showed and the sand went nearly white. Now 43 %, with the sand a
  little less red and the sun's light less orange, so it is about as light as the sand before it.
- **No tree on the sun's side of the village near the court.** The sun is low there (dusk): a 14 m rain tree within
  70 m in that direction laid its shadow right across the court.
- **Bleachers not used** (`bleacher_concrete`, `bleacher_metal`). The grounds' stands are straight tiers that the
  crowd sits on, sized to each ground; the curved concrete segment does not fit a rectangular ground, and neither
  model's steps are regular enough to seat the crowd's cards on. The stadium and dome keep their own tiers, now in
  the photographed concrete. Neither model is in the game.
- **Not used either, as the plan says:** the Thai temple, stilt house, oak, terraced houses, thatched cottage,
  jacaranda.
- **Sky light** is matched to the painted skies' it replaces (measured looking up and sideways), so the grounds,
  their bake and the players keep their brightness; the scanned surfaces, darker than the generated ones before
  them, are lightened to about those.
- **Source models are not committed.** `tools/scenery/fetch.sh` fetches them from the shared assets and
  `tools/scenery/convert.tscn` makes what the game loads (each model's mesh, its textures as they came): the game
  ships only those.

## Gaps that need the owner

- None for the grounds: the village temple and the Jagannath temple's tower both came while this update was being made
  (the lead had them generated, with the owner's approval) and are in.
- None for the water either: `water_normal_512.png` was made for these games from a sum of random sine waves (the
  shared assets' README says so since `6dbd5fd`), so it is the owner's own (treat it as CC0) and needs no credit.

## Performance

`tests/perf_probe.tscn` (draw calls, primitives, objects and video memory a frame, from the broadcast camera through
the first raid of the same seeded match) before and after, on this machine (software rendering):

| Ground | Level | Draw calls, 3D | Draw calls, whole frame | Primitives | Objects | Video memory, MB |
|---|---|---|---|---|---|---|
| Mumbai Dome | Low | 144 → 100 | 262 → 217 | 634k → 634k | 360 → 315 | 149 → 150 |
|  | Medium | 154 → 101 | 272 → 218 | 635k → 635k | 370 → 316 | 164 → 164 |
|  | High | 154 → 101 | 272 → 218 | 636k → 636k | 370 → 316 | 189 → 189 |
| National Stadium | Low | 154 → 101 | 272 → 219 | 635k → 661k | 371 → 317 | 151 → 155 |
|  | Medium | 166 → 103 | 283 → 221 | 637k → 741k | 383 → 319 | 166 → 171 |
|  | High | 166 → 104 | 283 → 222 | 639k → 743k | 383 → 320 | 190 → 196* |
| Gaon Maidan | Low | 145 → 102 | 263 → 220 | 636k → 668k | 362 → 318 | 143 → 154 |
|  | Medium | 199 → 120 | 316 → 238 | 640k → 806k | 416 → 336 | 158 → 173 |
|  | High | 199 → 124 | 316 → 242 | 641k → 807k | 416 → 340 | 183 → 197 |
| Monsoon Ground | Low | 125 → 98 | 243 → 216 | 632k → 657k | 342 → 314 | 144 → 156 |
|  | Medium | 170 → 110 | 286 → 228 | 639k → 773k | 382 → 326 | 159 → 171 |
|  | High | 170 → 114 | 286 → 232 | 646k → 790k | 382 → 330 | 184 → 196 |
| Puri Beach | Low | 134 → 96 | 252 → 212 | 638k → 673k | 350 → 310 | 142 → 156 |
|  | Medium | 181 → 107 | 298 → 224 | 643k → 793k | 396 → 322 | 157 → 168* |
|  | High | 181 → 113 | 298 → 229 | 644k → 803k | 396 → 327 | 182 → 192* |

The median frame of the first raid. "Before" is 0.8.6, the last commit before this update; "after" is 0.9.0. As
before, the dome and stadium ran in one run and the village, monsoon and beach in another, so video memory includes
what earlier grounds in the same run left loaded. \* measured in a run of that ground's Medium and High alone (the
stadium's Medium gave the same 171 MB there as in the long run).

- **Draw calls**: 22 to 41 % fewer in the 3D view, on every ground and level; 11 to 25 % fewer for the whole frame (the
  HUD's do not change). The stands, court lines, benches, lamps and masts are one mesh each, and every tree, chair and
  stool of a kind is drawn in one go: that saves more than the new scenery costs. Objects drawn: 8 to 19 % fewer.
- **Primitives**: Low draws about what it did (the same in the dome, up to 5 % more elsewhere: cut-outs and cut-down
  models). Medium and High draw 16 to 26 % more on the outdoor grounds and in the stadium (the full models of the
  trees, temple, chairs and stools near the broadcast camera, and the city's blocks). The dome's are unchanged.
- **Video memory**: up to 14 MB more on Low and 15 MB more on Medium and High, from the photographed surfaces and
  skies. The dome's is unchanged.
- Frame times are not in the table. Rendered in software here, with other jobs on the machine, they say nothing about
  a phone; the developer overlay (BETA.md, *Measuring stutter*) measures them on one.

## 0.9.1: the crowd faces the court

The owner saw the crowd on the near side looking the wrong way, in more than one game, and the lead passed it on to
all of them. Here every spectator is a card turned to the camera, cut from a sheet of each person drawn from the
front, so whoever a camera saw from behind still showed it their face.

- **Where it showed**: on every ground, wherever a camera was behind a crowd. That was the slow circle round the ground
  at a match's start, half-time and full-time (15 m out, behind each stand in turn); the live match behind the home
  screen (on Puri Beach the people standing nearest it faced it); and the edges of the broadcast view, which sits
  above the near stand's front rows and so showed little of it in play. The crowds concerned: the near stand of the
  Mumbai Dome and the National Stadium, the near side of those standing round Gaon Maidan and Puri Beach, and the
  Monsoon Ground's crowd under the tarpaulin from behind it.
- **The fix**: each spectator's card has a facing, its instance's -z, pointing at the court's middle along the
  ground, and there is a second sheet of every person drawn from behind (`tools/crowd/render_crowd.gd`: the same eight
  poses; the front sheet comes out the same to the pixel). The card still turns to the camera; when the camera is on
  the far side of them from where they face, it shows their back.
- **Checked**: `test_runner` checks on Low, Medium and High that every spectator on every ground faces the court's
  middle (forward against the way to it, dot above 0.7), from 72 of 72 on the beach on Low to 3,260 of 3,260 in the
  stadium on High, and that every crowd's cards have the back sheet. Headless, as CI runs it, a MultiMesh keeps no
  transforms, so each crowd keeps its spectators' feet and facing for the test, and with a renderer the test checks
  them against the transforms themselves. Before and after, from behind each crowd and from the court:
  [img/crowd_facing_0.9.1.jpg](img/crowd_facing_0.9.1.jpg).
- **Cost**: 14.4 MB more video memory on every ground and level, for the back sheet and its shirts' mask (on Low, the
  dome 150 → 164 MB and Gaon Maidan 154 → 168 MB). The draw calls, primitives and objects are the same (on Low, the
  dome's 100 and 217, 634k, 315; Gaon Maidan's 102 and 220, 668k, 318).

## 0.12.3: ready for Google Play (soak test, safe saves, store kit)

The owner asked (through the lead) for every game to be ready to upload to Google Play by morning, with only the
owner's own steps left (`store/PLAY_STORE.md`, "What only you can do").

**Build.** Targets Android 16 (API 36, Play's minimum for new apps since 31 August 2026), runs on Android 7.0 (API 24)
and later, 64- and 32-bit ARM. Every 64-bit library is 16 KB-aligned (`tools/check_pages.py`). One permission,
`VIBRATE`; the Play bundle workflow now fails on any other, and on a target below 36. The bundle is about 104 MB and
a phone downloads about 78 MB of it (bundletool, measured on every bundle; Play's limit is 200 MB, so no Play Asset
Delivery). `com.kabaddiraid.game`, as in Obtainium's list; version code 34.

**Saves.** A save is now written beside its file and moved over it (`Game._write_json`): Android closing the game
mid-write leaves the old season, cup or settings whole instead of half a file the game could not read.

**Soak test** (`tests/soak.gd`, on a virtual screen with the software renderer):

| Run | What | Result |
|---|---|---|
| Random inputs | 2,000 taps on buttons, taps and drags anywhere, Back, trips to the background and back, through 15 screens (the home screen, Quick Match, League Season with the auction, retentions, war room, match day, awards and hall of fame, Nations Cup with its squad, matches, results, settings, How to Play); started on Low, and Settings' taps soon put it on High | 0 script or engine errors; no screen that traps the player; every match sent to the background came back paused, its clock stopped; every save read back after each trip |
| AI v AI | 10 matches on Low and 10 on High, every ground twice, each sent to the background and back partway | all 20 reached the final whistle (586 raids); 0 stalls; worst frame 457 ms |
| Memory | six rounds of seven screens and a match | nodes steady at about 1,380, no orphans, objects and memory flat |

The 12 frames over 5 s the random run counted were all on the software renderer drawing High (5 to 9 s a frame
there), on the home screen's match and one played match, not freezes: the same screens took well under a second on
Low. A dedicated High run of random inputs was cut short for the same reason (a frame every few seconds); High's
game logic had its 10 full matches, and its screens were reached in the random run once it was on High.

**Store kit.** The listing in all eight languages (`store/listing/`, checked by `tools/check_listing.py`), the
answers to every Play Console form (`store/PLAY_CONSOLE_ANSWERS.md`), the icon, feature graphic and screenshots
(`store/graphics/`, drafts the owner can make again from the build before submitting:
`tools/media_kit/make_kit.py --store`), and the media kit for the owner's website (`tools/media_kit/make_kit.py`).

## 0.12.2: Help, Privacy policy and Licences in the game

The owner found Settings links returning 404 across the games, and asked for all three pages in the game, working
offline. Kabaddi's two web links (thekabaddipulse.com's privacy and support pages) worked; the pages are now in the
game anyway.

- **Settings > About** has Privacy policy, Help and Licences; each opens a screen in the game (`ui/privacy_screen.gd`,
  `ui/help_screen.gd`, `ui/licences_screen.gd`) with Back, scrolling and the body font at a reading size
  (`UI.rich_text`). The text is in English, as the legal texts are; Help's How to play button opens the translated
  guide (and Back returns to Help). Each page but Licences has a View online button (translated in all eight languages).
- **Privacy policy** (dated 27 October 2026): nothing collected, sent or sold; no account, ads, analytics or tracking;
  settings and saves only on the phone; one permission, vibration (the APK's manifest asks for VIBRATE and Godot's
  DUMP, which Android grants only to system apps, and nothing else: no INTERNET); the browser version on Netlify; contact
  https://thekabaddipulse.com/contact/.
- **Help**: playing, raiding, defending, the rules in brief (revival, all out, do or die, bonus, the three raid
  rules), the modes, the controls, the graphics levels, saves, and how to report a problem (the contact page and the
  developer's overlay).
- **Licences**: Poly Haven's assets now listed one by one with their authors (from Poly Haven's own records), beside
  Meshy, Mixamo, the CMU database, every sound, the fonts and the Godot Engine's licence and notices.
- **Links checked** (HTTP 200, 27 October 2026): thekabaddipulse.com/kabaddi-raid/privacy/ and /support/ (the View
  online buttons; the privacy one is the Play listing's), /contact/, /kabaddi-raid/, and the old Netlify
  /privacy.html and /support.html (forwarding there).
- **Checked**: test_runner (420: each page opens from Settings' own button, has Back, scrolling and its text, and Back
  returns to Settings), fit_audit (0 problems, the three pages included), compile_check. No gameplay or graphics
  change.

## 0.12.0 and 0.12.1: sharper on Medium and High (the size update)

The owner let the APK grow toward about 100 MB to make the game look and sound better, with Low exactly as it was.
How it is done: [GRAPHICS.md](GRAPHICS.md), "Medium and High's extra detail"; the sounds: [SOUNDS.md](SOUNDS.md).

- **Players** (Medium, High): the models' own 2K/4K textures at 1536 px for every player's albedo (faces, skin, the
  kit's folds), `tools/rig/albedo_2k.py`; ETC2 in video memory.
- **Courts** (Medium, High): the mat's albedo at 2048 px, and Poly Haven's 2K albedos of the village's earth and
  Puri's sand (CC0, credited as before).
- **Crowd** (Medium, High): sixteen people instead of eight, the eight again in other colours on a second sheet
  (`tools/crowd/variants.py`): saffron and maroon turbans, magenta and mustard salwars, green and royal-blue sarees,
  yellow and sky-blue frocks.
- **Sound** (every level): the crowd's bed 18 → 30 s, the rain and birds 16 → 40 s, the sea 16 → 32 s (every wave
  twice), so they repeat less; three cheers instead of one; the crowd's rhythmic clapping and chanting as a
  do-or-die raid starts (all Gregor Quendel's, CC BY 4.0, already credited).
- **Low**: the same files as before and none of the new ones (test_runner 7d). Against 0.11.1, the same seeded match
  measures the same on Low to the triangle: dome 633,733 primitives, 317 objects, 164 MB; village 667,864, 319, 175 MB.
- **Medium and High**, the same seeded match from the broadcast camera (`tests/perf_probe.tscn`; software rendering,
  so frame times compare only with each other, run back to back):

  | Ground | Level | Draw calls (3D / frame) | Primitives | Video memory, MB | Frame, ms (llvmpipe) |
  |---|---|---|---|---|---|
  | Mumbai Dome | Medium | 101 / 219 → same | 634,867 → same | 179 → 194 | 1832 → 1897 |
  | Mumbai Dome | High | 101 / 219 → same | 636,075 → same | 204 → 218 | 2286 → 2270 |
  | Puri Beach | Medium | 107 / 225 → same | 792,621 → same | 189 → 207 | 1369 → 1216 |
  | Puri Beach | High | 113 / 230 | 802,780 | (0.11.1's run timed out) → 231 | → 1496 |

  14 to 18 MB more video memory, for the sharper players and courts and twice the crowd: the players' albedos are ETC2
  (1.6 MB each with mipmaps) where the 1K ones are uncompressed, and the crowd's second sheet adds 6 MB beside Low's.
  Frame times on this software renderer move by more than that from run to run. Before and after on Medium:
  [img/detail_0.12.0.jpg](img/detail_0.12.0.jpg) (top 0.11.1, bottom 0.12.0's first build; 0.12.1's players are
  1536 px where these were 2048).
- **Size**: Godot keeps GPU-compressed textures uncompressed in the APK. The first build (2048 px for every body,
  five 2K surfaces, a sixteen-person sheet with its masks) came to 136.4 MB, so it was cut to the players at 1536 px,
  the mat and the two court surfaces, and a second sheet of only the eight new people: about 27 MB more than 0.11.1.
  The web version leaves them out (88.8 MB as before).
- **Checked**: test_runner (412: the courts' new textures are 2048 px and the players' 1536 px, all GPU-compressed;
  Low loads none of them, Medium loads them; the crowd has eight people on Low and sixteen on Medium), compile_check;
  the web build (88.8 MB, without them) loads in Chromium with no console errors.

## 0.11.1: one beta signing key, and the referee's real whistle

- **Signing**: every Android build made a new random key (`keytool -genkeypair`), and the APK was then signed with
  uber-apk-signer's own debug key, so a new beta could refuse to install over the last ("failure conflict" in
  Obtainium). Both Android workflows (`.github/workflows/kabaddi-android.yml` and the game's own copy) now decode the
  owner's beta keystore from the `BETA_KEYSTORE_B64` secret (PKCS12, alias `androiddebugkey`, password `android`) and
  sign with it; without the secret they fall back to a throwaway key with a warning. After signing they log the
  APK's certificate SHA-256 and fail if the secret is set and it is not
  `6F:23:A9:36:9A:95:60:C5:57:1D:27:04:D2:01:5F:8D:58:3E:B2:65:2E:86:A5:F1:66:2B:E5:D6:C3:69:7B:A3`. The Play
  bundle's upload key is untouched. Going from an earlier beta to this one needs one uninstall.
- **Whistles**: the owner's real referee whistles (Pixabay, through `shared-assets/sounds/whistle/`) replace the
  synthesised one, played from the referee (`Sfx.whistle`, `Match._whistle`): a long blast as a raid starts, after a
  point and at half-time (the hall take in the dome), a short pip after an empty raid and for a card, a double for a
  time-out, the final whistle at full time; faint in the home screen's match. Credited on the Licences screen and in
  SOUNDS.md; test_runner checks each one is there and loads.

## 0.11.0: real sounds

The lead asked for realistic, non-cartoonish sounds from kenney.nl and opengameart.org (CC0, CC BY, CC BY-SA or
OGA-BY only), processed small, wired into the play and credited. Every file, source, author and licence:
[SOUNDS.md](SOUNDS.md).

- **Audit (before)**: every effect but the chants, shouts and menu music was synthesised (the crowd from layered
  espeak voices and noise); there were no footsteps and no ground had a sound of its own.
- **Recorded now** (`tools/audio/make_recorded.py`, from the downloads): the crowd's bed, cheer and roar (Gregor
  Quendel, CC BY 4.0); applause (eXpl0it3r, CC0); footsteps on the mats and the village's earth, tackles' thuds,
  touches and the click (Kenney, CC0); footsteps on sand (Fantozzi, CC0); rain, the sea, birds and crickets for the
  monsoon, beach, village and stadium grounds (Kresiek The Furry, jasinski, Thimras, Wolfgang_; CC0). Trimmed,
  mono, 22.05 kHz, peak-normalised one-shots; beds set to one loudness and crossfaded into seamless loops; Ogg
  Vorbis at low quality.
- **Wired in** (`autoload/sfx.gd`): footsteps a step a stride on the ground's surface, harder the faster a player
  goes (`Athlete._footsteps`, `Arena.step_surface`; about 4-5 a second in an AI match); footsteps, thuds and touches
  spatial (`Sfx.play_at`, 3D players: louder near the camera, panned to their side); variants picked at random
  (`Sfx.VARIED`); the ground's ambience under the crowd (`Sfx.ambience`); three buses with Effects, Crowd and Music
  sliders in Settings (`Sfx.apply_volumes`, translated in all eight languages); a paused match holds every sound and
  starts none (`Sfx.pause`), the menus' click still sounding. The synthesised thud and slap are gone.
- **Size**: `assets/audio/` 1,464,511 → 1,834,879 bytes (+370 KB), 31 new files.
- **Not found**, kept synthesised and listed in SOUNDS.md for the owner to source: a referee's pea whistle, a dhol,
  regional crowd chants, bare feet on a mat, city night and indoor hall ambiences.
- **Checked**: test_runner 7c (every recording is in assets/audio and loads, every sound the code names exists, the
  beds loop, a paused match plays nothing, the sliders reach their buses; the licences screen credits each author),
  compile_check, fit_audit, raid_audit.

## 0.10.0: recorded crouched walks (CMU)

The owner added the CMU Graphics Lab Motion Capture Database to the shared assets, and the lead asked every game to
check where real recorded movement would make its players more real, and to use it there. The full account is in
[MOTION_REALISM.md](MOTION_REALISM.md), "Recorded crouched walks".

- **Used**: two takes of CMU subject 136 ("Weird Walks"), the only ones clearly more real than what the game had.
  136_09, Walk Crouched (7.27-8.48 s), is `move_crouch_walk`; 136_11, Walk Backwards Crouched (4.80-6.28 s), is
  `move_crouch_back`. A defender creeping forward or back in his stance, the commonest way anyone moves on the mat,
  stood up and strode (or jogged backwards at half speed) on the upright walk and jog; he now stays low. Before and
  after: [img/crouch_walk_0.10.0.jpg](img/crouch_walk_0.10.0.jpg).
- **Made into clips** by `tools/mocap/fbx_to_clip.gd`, which reads BVH now: one stride each, cut where its last pose
  meets its first; 30 frames a second, the game's 13 joints, the subject turned to face forward; no root motion (the
  clip says how fast and which way it goes, measured on the game's own skeleton so the feet hold, and the rig plants
  them); laid over the hand-made pose and cross-faded like every running clip. 14 and 18 KB of JSON; the BVH takes
  (0.86 and 1.09 MB) are not in the repository.
- **Not used**, each with its reason in MOTION_REALISM.md: the basketball defensive slide (102_22-28: twice the
  speed a kabaddi defender shuffles at), the basketball feints (102_18, 102_19: running drives), the karate kicks
  (135_04, 135_07, 135_11: head high), the two-person pull (18_03, 19_03: upright), the boxer's guard and avoid
  (76_03, 76_04), the crouched walks on the toes (136_13-16: too high), the run side steps (127_13, 127_14), and
  subject 139's takes (their copies could not be told from subject 77's). No take is a kabaddi move: the holds,
  dives, chains and dubki keep their clips or the hand-made pose.
- **The code**: a clip can say it is crouched (`"low": true`, from the converter's `--low`); a crouched clip carries a
  player only as fast as its legs can be played (1.8 times its speed, by his smoothed pace, and only three quarters of
  that to change into it), so running in to tackle is still the jog.
- **Checked**: test_runner (each CMU clip loads, and at its speed a planted foot slides under 0.2 m/s on the game's
  skeleton: 0.18 and 0.17; a crouched defender is carried by them creeping and by the jog running in; the licences
  screen credits the database), compile_check, locomotion_check, motion_audit, tackle_check, raid_audit, ai_bench,
  fit_audit. In three AI matches: pops 123 → 88, sudden steps 267 → 196, the planted foot's slide 0.05 → 0.03 m/s;
  clip changes 41 → 44 a minute.
- **Credit**: the licences screen: "Motion capture data from mocap.cs.cmu.edu. The database was created with funding
  from NSF EIA-0196217."
- **Cost**: none to measure. `perf_probe` (every ground on Low, the dome on Medium and High) gives the same draw
  calls, primitives, objects and video memory as 0.9.1; the players' animation takes 4.92 ms a frame for 14 players
  against 4.90 before, within the runs' spread. The two clips are 32 KB.


## 0.13.0: the owner's list (crowd, raider, sounds, Watch)

| Asked | Done | How it was checked |
|---|---|---|
| Settings won't scroll | Every card and button inside a scroll box passes a drag on (`UI.pass_drags`) | drags at 20/50/80 % scrolled 500/477/512 px (before 0/501/0); test_runner: nothing in Settings stops a drag |
| Watch AI play | Quick Match's Watch button: `autoplay` and `watch`, only pause, camera and skip shown (`TouchControls.watch_only`) | render; test_runner |
| Quick Match sizes | team cards 130 → 80 px crests, grounds 118 → 170 px and growing, chips 110 × 70 at 24 pt | render at 1560 × 720 |
| Names and numbers over players | off by default, and off once for saves from before (`tags_v`); Settings can turn them on | test_runner |
| The raider "standing stupid" | the straight-kneed `raid_idle` clip retired; his legs are the hand-made stance (crouch 0.45), dancing foot to foot at 0.85 cycles a second, the weight over the planted foot, a toe poked out every 2.2-4.5 s (`HumanModel` TAP_RATE, POKE_LEN); the low `raid_crouch_hunt` clip keeps his trunk and arms | the owner's training video through `tools/mocap/extract_pose.py` (YOLO11s-pose, 3,009 frames): hips at a median 0.92 of the straight leg (0.72 deepest), a bounce of 1.2-2 Hz, a sway of 0.35-0.6 Hz, feet 1.3 shoulder widths apart, hands at the hips; close renders |
| Break free works every time | lower odds, and each further try in a raid has 0.4 of the last (`Match._break_tired`) | `tests/break_free.tscn` (AI matches, Break free pressed whenever it can be): 79 % of holds escaped, a try 70 % → 33 %, a try 16 % |
| Arena text in the phone's language | the boards' and the run-off's league name is a translation key, redrawn when the language changes | test_runner (Hindi and back) |
| Mumbai Dome fans without legs | a seated fan's card is drawn 0.6 m nearer the eye along its own line of sight (same place on screen): the tier no longer hides the legs | before/after renders |
| Monsoon fans "chopped", fog | fans under the roof get light of their own (`lift` 0.3: they were black); fog 0.025 → 0.009 | renders |
| Crowd watching, clapping when heard | four new frames in the crowd sheets, each person looking left and right, sitting and standing (`tools/crowd/render_crowd.gd`, the turn checked on each model's face); idle fans look to the raider's side of the screen; every crowd sound with clapping in it (`Sfx.crowd_heard`) sets how many clap and how fast (`Arena.CLAPS`: the rhythm's 2.6 claps a second together, applause at their own pace) | renders; test_runner |
| Better match sounds (freesound) | crowd gasp and sigh, grunts, oofs, hups and breaths from CC0 freesound recordings (`tools/audio/make_freesound.py`; docs/SOUNDS.md) | each candidate's waveform and spectrogram looked at (no noise floor, voiced); noisy whooshes and body falls left as they were |
| Slower music | menus: tanpura and kherwa tabla at 75 bpm (was 80); matches: tabla at 72 bpm (was a synthesised dhol at 100) (`tools/audio/make_music.py`) | tabla and tanpura tuned within 42 cents, then matched |
| High on nicer phones | 4096 sun shadow map and a softer filter on High | renders |
| Hurling Heroes' player work | read: its foot-plant IK and stride-measured gaits are the ideas worth borrowing; no code taken this time | — |

Freesound's search pages and previews are public (no API key); the session was rate-limited (HTTP 403) for some minutes after
about twenty searches.

## 0.13.1: the auction's players

The owner found the auction's player picture bad (on Medium and High, the game's own model turning on a stand; on Low, one
pictogram for everyone) and asked for a different outline silhouette for each player, from better pictures of people than
the game's players. `tools/ui_art/make_silhouettes.py` traces 22 real players from the owner's two kabaddi videos: picked
by clustering every whole, unblocked person's pose (YOLO11 pose; 1,422 frames of the first video, 612 people in the
second) and keeping the most typical of each cluster, then cut out with YOLO11's person segmentation, cleaned and drawn as
a white outline over a faint fill (`assets/ui/auction/`, 290 KB). Only the outline is kept: no face, kit or picture.
`UI.player_figure` gives each player his own from his id (raiders one of 13 reaching, lunging or kicking; defenders one of
9 crouched ready; all-rounders either), facing either way and 0.9-1.1 as broad; the auction tints it in his last team's
brighter colour. 72 players of six squads come out in 53 different looks (test_runner).

## 0.13.2: the standing raider and the seated crowd (the owner's A16 playtest)

**"Standing position awful, twitching."** Measured on the user's raider standing at the line for 5 s (no input): his
shoulder swung through 1.3 rad, elbow, spine and knees 0.6-0.9 rad, with jumps of up to 0.21 rad from one frame to
the next. Two causes: the stance clip `raid_crouch_hunt.json` (traced from match video) carried the video's tracking
noise (0.09-0.11 rad a frame at the shoulders and elbows), and 0.13.0's foot-to-foot steps and toe pokes. Both gone:
the stance is hand-made (crouch 0.55, hips flexed, leaning in, hands out in front), with a slow weight shift (0.3 Hz,
2 cm) and breathing. After: knees bent 44 degrees, worst jolt 0.004 rad (test_runner checks under 0.02). Before and
after: [img/stance_0.13.2.png](img/stance_0.13.2.png). On every graphics level (it is the pose underneath all of them).

**"Some look like they are in the seats."** On chairs and stools (Gaon Maidan, Monsoon Ground, Puri Beach) a seated
fan's card stood 0.2 m forward of the seat along the seat's own facing, and was drawn 0.6 m toward the eye (the tiers'
fix from 0.13.0): seen side-on from the broadcast camera they stood beside or through their stools. Now the card is on
the seat's middle and drawn only 0.28 m toward the eye (`Arena.CHAIR_PUSH`): hips on the seat, legs in front of it. The
seated sprites are rendered from 16 degrees above (`tools/crowd/render_crowd.gd`, SEAT_TILT), as the broadcast camera
sees a stand, so the lap shows instead of the legs hanging straight down from the body.

Version code 38: above the foundation pilot's 37, so either installs over the other.

## 0.13.3: Watch AI

A Watch AI link on the home screen (`MENU_WATCH`, 8 languages) opens Quick Match in watch mode (`quick_setup.gd`
`watch_mode`): the teams and ground picked as usual, one Watch button, and the match played by the computer
(`autoplay`, `watch`) on the broadcast camera with the score and clock, pause and camera, and a 1×/2× button
(`Match.set_watch_speed`, Engine.time_scale; back to 1× when the match is left). test_runner: three checks.
fit_audit (menus, 8 languages, 1280x720): 0 problems.

The Licences page no longer lays its texts out on worker threads (`RichTextLabel.threaded`): one of those laid out
while the page sized it (`fit_content`) crashed the engine now and then as the page opened (signal 11 in CI, twice,
right after "Back from Help"). It now shows the credits at once and adds the rest a label a frame, long licences cut
into labels of about 1500 characters (`licences_screen.gd` `_queue`, `built()`): it opens in about 0.1 s instead of
1.5 s (1 s threaded), and no frame while it fills takes more than about 60 ms (desktop, headless). test_runner: the
page is complete in 77 frames.

## 0.14.0: the foundation pilot merged; replays at 1×; bonus and return pulses

The owner OKed the pilot: PR #15 (claude/kabaddi-foundation-pilot, 0.13.1-pilot) merged into the game's branch, with
0.13.2 and 0.13.3 (conflicts only in the version and the last string in each language: MENU_WATCH and REPLAY both
kept). Medium and High draw everyone with the shared foundation (GRAPHICS.md, "The shared foundation"); Low unchanged.

- **Foundation synced** to 2df532c (tools/wsg/sync_foundation.sh; was c4b565a): its newer behaviours are opt-in.
  FoundationLink sets `loco.cut_from_heading = true`, as the foundation advises for a game that drives the locomotor
  from the body's velocity (a cut's clip measured from the way he was going, not crawling while he runs on).
- **Replays at 1×**: watching at 2× (Watch AI), a replay plays at 1× (Engine.time_scale) and the chosen speed comes
  back after it or on a skip; a speed tap during one changes the speed it comes back to (`Match.watch_speed`).
  test_runner: 1× during a replay started at 2×, and 2× after.
- **Haptics**: `bonus` (35 ms, 60 ms gap, 35 ms) when your raider wins the bonus point and `return` (50 ms, 90 ms,
  50 ms) when he gets home with points (Game.HAPTICS; not in a match the AI plays on its own). test_runner: both.

- **Web**: the web export leaves out the licensed motion-capture data (`addons/wsg_foundation/data/*` in the Web
  preset's exclude filter; the data goes no further than the APK/AAB), so the web version draws the game's own bodies
  at every level, with no replays.
- **The raider walks the cover low**: his raid crouch is 0.6 (was 0.55), past HumanModel's 0.55 for the crouched walks.
  At 0.55, once a touch (crouch 0.3) or a kick had stood his gait up (below 0.4), he never went back to the crouched
  walks, and on the upright walk both knees passed near straight at every step (the foundation's stance check caught
  it in CI: 1 frame in 298). Hips about 1 cm lower. test_runner: walking at 0.8 m/s just after a touch, the crouched
  walk and never both knees near straight.
- **The stick in every camera** (the owner's note to every game, via the lead): measured at mid-court, the stick was
  right in both cameras (within 6 degrees broadcast, 1 degree third person), but toward the screen's edges the
  camera's perspective bends the ground's directions away from its yaw, and the stick, turned by the yaw alone, was up
  to 22 degrees off (broadcast) and 24 (third person). Now (`CameraRig.stick_axes`, Floorball's method via the lead)
  the stick's axes are where the player stands on the screen: the camera's rays 24 px above, below, left and right of
  him meet the ground in the ways up and right go there. Exact across the screen (0 degrees in the sweep). Eased over
  about 0.2 s if they jump (a camera cut); the camera button glides the camera, and the axes with it. The demo tour's
  thumb uses the inverse (`world_to_input`). No aimed passes or shots; the AI does not use the stick. test_runner:
  both cameras, four directions moving the raider (within 10 degrees on screen), a sweep of the screen out to its
  edges, and the camera change mid-move.

## 0.14.2: the owner's list (ticker, crowd, tag buzz, get-up, bow legs, chant)

- **News ticker** removed from the home screen, the season hub and the cup screen (NewsTicker.make no longer called;
  the front page and breaking news stay). test_runner: no ticker on the home screen or the season hub.
- **The crowd "in the seats"**: from the front a seated fan's thighs vanished and the sitting frames read as people
  standing sunk into the tier. tools/crowd/render_crowd.gd: seated frames from 30 degrees above (was 16), thighs a
  little apart and the shins forward to the step below (SIT_LEGS); both sheets and the Medium/High sheet re-rendered.
- **Tag haptics**: `touched` is a firm double knock (45 ms, 60, 30; was 16 ms at 0.35, unfelt) and a tag on a team-mate
  as you defend is `team_touched` (30 ms). test_runner.
- **Get-up twitch** (measured: leg joint second differences through AI play, quaternions): (1) HumanModel's side-shuffle
  switched on past gait 0.25; a defender slid aside as he rose (gait scaled down while lying) crossed it for one frame,
  knees +21 and thighs +15 degrees. Now faded in (smoothstep 0.15-0.4). (2) A defender up from a dive had 0.57-1.03 s,
  so the 1.4 s get-up clip played at up to 2.4 times and the stepping leg flicked 60 degrees in 0.1 s: at least
  GETUP_MIN 1.0 s now (at most 1.4 times). (3) rise and recover ended standing straight and ready dropped him into
  his crouch: both rise into READY_CROUCH. Worst jolts: rise 0.80 to 0, rise-to-ready 0.70 to 0.23, recover 0.67 to
  0.56 (the clip's own step). test_runner: a dash dive's get-up (1.0 s, worst 0.40 rad, knees at least 35 degrees)
  and a slipped hold's rise (knees at least 56; the old code stood him to 5).
- **Bow legs**: the captured locomotion clips bowed the knees out from the line hip to ankle (run 5 cm mean, 13.6 max;
  strafe 12.6; back jog 7.8). tools/mocap/unbow.py turns each leg about its hip-ankle line until the knee is within
  1.5 cm (a shuffle 4): the feet are exactly where they were. In matches the run's mean fell from 4.5 to 2 cm.
  test_runner: every move clip within 2 cm (shuffles 4.5).
- **The chant**: tools/audio/make_chant.py, the Piper TTS Telugu voice "venkatesh" (CC BY 4.0 data), the raider's
  single words said with a comma (mid-cant), each take checked by faster-whisper and kept only if heard as "kabaddi";
  the crowd's chant 16 checked takes at their own pitches. Credited in Licences and SOUNDS.md. No CC0 recording of a real
  raider's cant was found (Commons has only CC0 pronunciation clips, rate-limited from here; Freesound blocked).


## 0.14.3: the crowd through the shared foundation (owner's directive, every game)

- **Foundation** synced to 4d6aa03 (crowd placement, Low cards with back views). The licensed crowd re-baked (FORCE=1
  tools/wsg/fetch_assets.sh): the data baked before the foundation grounded every frame had seated soles up to 6.8 cm
  under the floor.
- **Venues declared** (game/kabaddi_venues.gd, registered in game/crowd_venues.gd): the dome's and stadium's stepped
  stands (sitting on the step behind, the dome's tunnel), the monsoon's west stand and tarpaulin chairs, the village's
  chairs, stools and standing ring, the beach's chairs and ring. The chairs' seats sit at the back of their row's tread
  (with the seat 0.2 m back the foundation sat the fans back into it to keep their toes on the tread: 3 cm in);
  standing room at the village and beach is a line of its own behind the chairs (the ring's ends had cut into them).
  crowd_audit: all five PASS (inside at most 2.4 cm, facing at most 7 degrees).
- **Arena** builds every ground's crowd from KabaddiVenues.venue(id).place(): Low our people as WsgCrowdCards (use_art:
  tools/crowd/pack_cards.py repacks the render_crowd sheets a cell a pose - sit, stand, cheer - front and back, the
  shirt mask in R, each adult's sitting cell scaled to a common seat height 0.42 so the cards pick any adult for a seat,
  the children shorter); Medium and High the nearest as WsgCrowd3D (build_venue; our skin and hair; clap with the
  clapping heard, watch the raider), the rest as cards. Chairs and stools are placed under the venue's seats. The old
  card shader, the stand seat lists and the chair spots are gone (render_crowd.gd now records each person's seat).
  Lost against the old cards on Low: clapping and head-turn frames (the shared cards have sit, stand and cheer).
- **Tests**: every ground at every level audited (cards and 3D, WsgCrowdVenue.audit); the card sheets' layout.

## 0.14.4: the cards clap and look (foundation 5f9c31d)

- Foundation synced to 5f9c31d: the crowd bake carries a version the audit checks (re-baked, version 3); flat rows'
  toes no longer held on an edgeless tread; WsgCrowdCards picks at random among the fans that fit a seat, and has
  clap and look poses.
- tools/crowd/pack_cards.py packs nine poses a person: sit, stand, cheer, sit_clap, stand_clap and the looks either
  way, seated and standing (the cards' "look_l" is the fan's own left: render_crowd's "_look_r" as drawn). The adults'
  sitting cells stay scaled to a common seat height: as drawn, from above, their seats are 0.33-0.43 m, and most would
  not fit a 0.44-0.45 m seat (FIT_MAX 1.14 x 1.03) - the stands would be nearly all one man.
- Arena: the cards clap with the clapping heard (cards.clap) and look at the raider (cards.watch_ball), as the 3D fans.
- WsgFootFlat.attach on every foundation body (ADOPTING 5.10): our models' soles rise 0 to 1.9 degrees at rest (player_09
  1.9, player_03 1.8, player_08 1.2, the referee 0.1, the rest 0), under its 2 degrees: none needs turning.
- test_runner: the cards' layout has the clap and look poses; the cards clap while applause is heard.

## 0.14.5: the loading overlay on every start (owner via the lead; foundation edebcd5, ADOPTING 5.14)

- Every match start goes through Game.start_match (Play, Watch, cup, season, tutorial lessons); from a screen it puts
  up WsgLoading in the tap's own frame (the screen's buttons off, a second tap ignored), loads match.gd and the
  ground's baked shell (assets/grounds/<id>/<id>.tscn) on the loader's thread, then builds the match in slices:
  Match._ready checkpoints after the ground's sky, its shell, its dressing (Arena.build takes the overlay), each of
  the 14 players and the officials, with the tree paused between so nothing half-built runs. Then three frames of the
  match running under the overlay, so its first drawing (shaders made for the GPU) happens behind it. Not for the
  menu's backdrop matches, nor with Game.loading_overlay off (test_runner's matches built at once).
- Measured (this machine: software OpenGL under xvfb, Low; not the A16): main-thread slices at most 188 ms (the dome,
  first ground loaded), about 50 ms otherwise; the longest frame is the first drawing of the 3D match, 1.6-2.7 s here
  (5.2 s with an empty shader cache), under the overlay. Before: up to 1.5 s in the tap itself and then 1.7-3.0 s
  of a frozen menu.
- test_runner: the overlay up in the tap's frame with the buttons off, one load for two taps, the bar only forward,
  the match built under it, the tree running again after, and the match playing.

## 0.14.6: solid props, loading v2, a smaller APK (foundation 8f688ff)

- **Foundation 8f688ff** (required commits checked in CI: check_foundation.sh fails on a missing one).
- **Solid props** (WsgSolidProps, ADOPTING 5.15; the owner: nobody ever walks through a table or a bench): Arena.solid
  holds every ground's props where their builders put them - both benches (7.8 x 0.42 x 0.4 at z +-9.12), the LED
  boards (panels), the stands' first step, the monsoon's tarp posts, the beach's umbrella poles, every chair and stool
  under the venue's seats and the scorers' chairs; Officials adds the scorers' table. Athlete.drive steers every body's
  wanted velocity round them (solid.steer, before it accelerates: steering after left him crawling along a bench at
  0.45 m/s) and pushes each step out of them (push_out; one memo each, the seek target as its goal). Out players walk to
  free_spot in front of their bench place and then sit on it (sitting is not walking); revived, they come forward off
  the seat as they rise (_rise_off_seat, every frame). game/prop_runs.gd + tools/wsg/prop_audit.gd in CI: 2 Watch-AI
  matches a ground, 403,444 body frames, none inside a prop (it first found the revived players standing up inside
  the bench). test_runner: the village's props registered, a player sent at the bench goes round it.
- **Loading v2**: ld.warm draws the match's looks a batch a frame behind the overlay (no 3D drawn from the first step
  until then), await ld.done() holds until frames settle (3 under 50 ms, 3 s cap), Game.prewarm_match loads the chosen
  ground's files on a thread from the quick-match screen. On this machine's software GL each warm frame costs about
  250 ms, so tap-to-play grew to 10-18 s here (40 warm frames, settle never under 50 ms); the longest frame fell to
  0.2-2.3 s. A phone's frames are a tenth of that: the A16 numbers are still to come.
- **APK**: the sixteen-person crowd sheets drawn at 0.75 of the render (only the far stands are cards on Medium and
  High), their masks at 0.375 and without alpha (ETC2 RGB): the four textures from 27 MB to 8.6 MB.

## 0.14.7: the world check, the owner's notes as tests, the match simulator (foundation bce6f30)

- **Foundation 13f00e2** (was bce6f30, 89bb8fe) (2cd59a7, 0422175, ad83891, a24408b required; 1ef240f and 29f4829 from 12:00 UTC).
- **wsg_world_check** (ADOPTING 5.18): game/world.gd (WsgWorldGame) wires every rule to the game's own code - the four
  starts (match, Watch AI, a cup final with its walk-out, a season fixture at the village) each through
  Game.start_match as the Play tap does it, played at Medium (the shared rig draws the players there), five officials
  on their feet, the walker (player_01 on the rig, its locomotor as FoundationLink sets it), the key sounds
  (Sfx.BRIGHT: the tag's slap, a body onto the mat, the whistle - played without the -24 dB distance filter now),
  CameraRig.stick_to_world (the stick's mapping, now a static the check can call), the two match cameras, and the
  props' and crowd's registries. Each mode's match is stopped and hidden once its cameras are taken: left playing, the
  four matches were drawn under every later rule and the check ran past 50 minutes on software GL. prop_runs draws no
  3D while it plays (under a display its 60 s were seven seconds of match). Its own CI job (xvfb, with the web build
  it reads), not holding up the APK.
- **The owner's notes as tests** (ADOPTING 5.16): tests/owner_notes, eight notes from 2026-11-02 and 11-03 (stance
  twitch, the tag's buzz for the raider and the defender, the stick on both cameras, no news ticker, the crowd on
  their seats, the get-up twitch, bow legs) each a WsgOwnerNote with its own check, INDEX.json, the guard and the
  strict runner in CI.
- **WsgSim** (ADOPTING 5.17): game/sim.gd (WsgSimGame) plays whole matches with Match itself from a seed (Match.rng;
  rng_lint: the seven bare rolls left were a sound's pitch, a label's jitter and three new saves' seeds, now marked),
  shortened halves for config.short (Match reads config.half_len), the human's side through the touch stick
  (TouchControls.sim_stick) and the buttons as btn_<id> input actions, Escape pausing a match. Kabaddi's rules each
  frame: every player on the mat, out in order or suspended; revivals in the order they went out; a raid started in
  five seconds and over by its time; the next raid's wait; do-or-die after two empty raids; the raider one of the
  raiding side; no defender in the lobby before the struggle; each score its points' sum; nobody on his feet inside a
  prop. Determinism: two seeds the same frame for frame. Speed: about 2.4 times real time headless (the players' and
  officials' pose code is 12 of a frame's 14 ms), so the smoke batch runs as four parallel jobs
  (.github/workflows/kabaddi-sim.yml) and a nightly 1,200 over sixteen (2,400 once it runs faster). Its first
  batches found the winning side all put back on the mat to celebrate at full time with its out queue left full
  (Match._end_match now clears it), and human-input matches standing paused for good at full time (Back now resumes
  a paused match there too). The stance-twitch owner note, unseeded, failed on CI (0.252 rad at a defender's knee):
  a defender shuffling his place in starts and stops had his crouch follow each burst of speed (0.5 rad of knee per
  m/s). Athlete now eases the legs' speed while ready or idle; a 12-seed sweep is clean (it had 2 at 0.03 and 0.09
  rad) and the note runs on fixed seeds, the failing ones among them.
- World check fixes: each mode's match is let go (not freed) when the next starts, and the match does not lower its
  own graphics during the check (on software GL it did, freeing the shared bodies the officials rule reads).

## 0.14.8: Low under its triangle budget

- **Low's bodies a quarter of the triangles.** wsg_world_check's tiers rule measured Low at 625,000-665,000 triangles a
  frame against the budget phones' 200,000: 21 bodies of about 15,000 triangles, each drawn twice (its flattened floor
  shadow is a second pass of the same mesh). tools/rig/bake_low.gd cuts each body to about 3,800 with Godot's own mesh
  simplifier (as its importer makes LODs), the same vertices and skin, saved as assets/characters/bodies/*_low.res
  (about 22 KB each); the officials' (the referee bodies) to about 1,900, on the side lines and small on screen.
  RiggedBody draws them on Low (low_mesh), and swaps on a mid-match lowering (detail_changed, now for every official
  too). Bodies about 67,000 triangles, 134,000 with their shadows; the tiers rule measured Low at 163,000-197,000 in
  three modes and 203,000 at the beach with the officials still at 3,800 (before their cut to 1,900). Side by side from the broadcast
  and the close camera the two cannot be told apart. The tiers rule is deferred to 2026-11-04 12:00 UTC by the lead
  while this and the village's draw calls (127 at Medium against 120) are done. The village's 125 measured here: the
  players 57, the officials 20, about 41 with the sun's pass, the four houses 18 (3 parts each, drawn twice in the lit
  pass). The houses are in the lightmapped shell scene (assets/grounds/village/village.tscn): merging them into four
  draws needs the shell and its lightmap baked again - next.
(0.14.9-beta, code 49, carries the next two.)
- **The village under 120 draw calls, no rebake needed.** The houses' shadows are already in the lightmap, and they stand
  well off the court, so drawing them again into the sun's shadow map only cost draw calls. Arena turns their shadow
  casting off in the village. Season at Medium went from 126 to 114 draw calls (High 129 to 117). The tiers rule passes
  everywhere (Low 90-101 draw calls and 137-177k triangles, Medium 104-114, High 104-117), so its deferral is removed
  and every world rule is enforced (game/world.gd).
- **Side-shuffles: his own arms.** The captured side-shuffles hold the arms out straight, 35-54 degrees from the sides,
  and WsgSim's smoke counted these as A-poses in 8 matches on d5c525c, each a defender or raider shuffling at
  3.2-3.5 m/s. A shuffle now takes 80% of his own ready arms (hands in front, elbows bent), eased over the clips'
  cross-fade (HumanModel._apply_moves).

## 0.14.11: the web version retired

The owner's decision (3 November 2026, through the lead): no more web version. The Web export preset is gone from
export_presets.cfg; CI no longer builds a Web pack for the world check (its web rule now finds no Web preset, which
passes) and no longer names a browser version on the release page; tools/web/netlify.toml is deleted; the keyboard
hints no longer start shown in a browser (they still appear when a key is pressed); the in-game Privacy policy drops
its browser-version paragraph (dated 3 November 2026); README, PLAY_STORE and GRAPHICS no longer point to it. Builds up
to 0.8.6 opened the Netlify site's privacy.html and support.html: those old betas' View online buttons stop working
once the site is taken down.

## 0.14.12: foundation 1b6793c (the feet batch)

The foundation's 11-06 feet batch (required from 2026-11-06 12:00 UTC): WsgSim reads bodies posed every 2nd or 3rd
frame per frame (our officials' 2.7 cm skids and many far players' 26-52 cm "jumps" were three frames read as one),
counts a planter.reset() as a cut (our reset at every change into a planter-driven mode), counts a skid only for a foot
the planter holds, and reads no pose under a replay; the planter moves a foot's own step an even share a frame and lifts
a let-go foot from its first frame; the world check plays its modes undrawn (much faster). Still open, the foundation's:
a held foot left out of the leg's reach (extreme#16's OFFICIAL_2, 35 cm) is dragged rather than stepped.

## 0.14.13: foundation 70e571a; Low measured; publishing in place

- Foundation 70e571a (the planter's 7def933a, required from 2026-11-06 12:00 UTC): a planted foot left far behind a
  fast stop steps instead of re-planting, landings plant on the frame they are down, the planter's own step swings at
  most 10 cm a frame. Our walker's stop jump 20.7 -> 8.9 cm; skid 0.1, slips 0.4 cm at most.
- walker_low (ADOPTING 5.21) in game/world.gd: what the A16 draws at Low - our own RiggedBody, planted by
  RiggedBody._plant_feet - driven along the feet rule's path as Athlete._pose drives it. The feet_low rule (deferred
  to 2026-11-08 12:00 UTC) measures it: standing 2.3 / walk 7.5 / jog 11.2 / jog turned 11.3 / stop 16.4 / standing
  again 2.6 cm slip a step, skid up to 7.6 cm (2.0 the bound). Next: the foundation's planter on our skeleton at Low
  (WsgFootPlanter.bone_map), our own planting off.
- The beta is published in place (ADOPTING 5.19): the workflow token may no longer create tag names here, so the new
  APK goes up beside the old on the same release, the old comes off, and the notes carry a "Commit:" line.

