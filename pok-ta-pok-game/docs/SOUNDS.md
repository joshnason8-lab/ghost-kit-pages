# Sounds

Every sound the game plays: what it is, the file, where it came from, who made it and its licence. The recorded ones
are made by `tools/sound/process.py` (trimmed, mono, 32 kHz, one-shots peaked at -1 dBFS, loops evened to -20 dBFS
RMS and cross-faded into seamless loops, Ogg Vorbis); `tests/test_runner.gd` checks every one is in the build and loads.
Only CC0 and CC-BY sources are used (kenney.nl and opengameart.org).

## Recorded

| File | In the game | Source file | Author | Licence | Source |
|---|---|---|---|---|---|
| `hip_body_1.ogg` | the hip strike's body | impactPunch_heavy_000.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| `hip_body_2.ogg` | the hip strike's body | impactPunch_heavy_002.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| `hip_body_3.ogg` | the hip strike's body | impactPunch_heavy_004.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| `thud_earth_1.ogg` | the ball down on earth | impactSoft_heavy_000.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| `thud_earth_2.ogg` | the ball down on earth | impactSoft_heavy_002.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| `thud_earth_3.ogg` | the ball down on earth | impactSoft_heavy_004.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| `step_earth_1.ogg` | a bare foot on earth | footstep00.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/rpg-audio |
| `step_earth_2.ogg` | a bare foot on earth | footstep02.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/rpg-audio |
| `step_earth_3.ogg` | a bare foot on earth | footstep04.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/rpg-audio |
| `step_earth_4.ogg` | a bare foot on earth | footstep06.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/rpg-audio |
| `step_stone_1.ogg` | a bare foot on stone | footstep_concrete_000.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| `step_stone_2.ogg` | a bare foot on stone | footstep_concrete_001.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| `step_stone_3.ogg` | a bare foot on stone | footstep_concrete_002.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| `step_stone_4.ogg` | a bare foot on stone | footstep_concrete_003.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/impact-sounds |
| `click.ogg` | a button pressed | click_002.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/interface-sounds |
| `ui_select.ogg` | a choice made (a chip, a team) | select_001.ogg | Kenney (kenney.nl) | CC0 1.0 | https://kenney.nl/assets/interface-sounds |
| `amb_crickets.ogg` | crickets: the village at dusk, the stone court by torchlight | crickets_1.mp3 | Wolfgang_ (Ted Kerr) | CC0 1.0 | https://opengameart.org/content/crickets-ambient-noise-loopable |
| `amb_fire.ogg` | the torches' fire round the stone court at night | fire.wav | PagDev | CC0 1.0 | https://opengameart.org/content/fireplace-sound-loop |
| `crowd_loop.ogg` | the crowd's murmur round the court | Gregor Quendel - Crowd Cheering Sounds - 10 - Ambience.mp3 | Gregor Quendel | CC-BY 4.0 | https://opengameart.org/content/free-crowd-cheering-sounds |
| `crowd_cheer.ogg` | the crowd going up (a raya, the ring) | Gregor Quendel - Crowd Cheering Sounds - 04 - Strong cheering - II - Short.mp3 | Gregor Quendel | CC-BY 4.0 | https://opengameart.org/content/free-crowd-cheering-sounds |
| `applause.ogg` | applause and soft cheering after a raya | Gregor Quendel - Crowd Cheering Sounds - 05 - Soft cheering - I.mp3 | Gregor Quendel | CC-BY 4.0 | https://opengameart.org/content/free-crowd-cheering-sounds |
| `dog_bark.ogg` | a dog in the village, far off | dog_barking_mono.wav | Brandon Morris (submitted by HaelDB) | CC0 1.0 (or OGA-BY 3.0) | https://opengameart.org/content/dog-barking-mono |
| `bird_1.ogg` | a bird in the forest round the stone court | Forest Birds 1.wav | pauliuw | CC0 1.0 | https://opengameart.org/content/forest-bird-sounds |
| `bird_2.ogg` | a bird in the forest round the stone court | Forest Birds 2.wav | pauliuw | CC0 1.0 | https://opengameart.org/content/forest-bird-sounds |
| `bird_3.ogg` | a bird in the forest round the stone court | Forest Birds 3.wav | pauliuw | CC0 1.0 | https://opengameart.org/content/forest-bird-sounds |
| `bird_4.ogg` | a bird in the forest round the stone court | Forest Birds 5.wav | pauliuw | CC0 1.0 | https://opengameart.org/content/forest-bird-sounds |
| `bird_5.ogg` | a bird in the forest round the stone court | Forest Birds 7.wav | pauliuw | CC0 1.0 | https://opengameart.org/content/forest-bird-sounds |
| `bird_6.ogg` | a bird in the forest round the stone court | Forest Birds 4.wav | pauliuw | CC0 1.0 | https://opengameart.org/content/forest-bird-sounds |
| `amb_village_hq.ogg` | the village at dusk (Medium, High) | AMB_Nature Pack Vol 1_Weather_Summer Evening.mp3 | JC Sounds | CC-BY 4.0 | https://opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1 |
| `amb_forest_hq.ogg` | the forest round the stone court by day (Medium, High) | AMB_Nature Pack Vol 1_Forest Enviroments_Rainforest Canopy.mp3 | JC Sounds | CC-BY 4.0 | https://opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1 |
| `amb_night_hq.ogg` | the forest at night round the torch-lit court (Medium, High) | AMB_Nature Pack Vol 1_Forest Enviroments_Forest Night.mp3 | JC Sounds | CC-BY 4.0 | https://opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1 |
| `amb_torch_hq.ogg` | the torches' flames (Medium, High) | AMB_Nature Pack Vol 1_ Fire & Elemental_Torch Flame.mp3 | JC Sounds | CC-BY 4.0 | https://opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1 |
| `crowd_loop_hq.ogg` | the crowd round the court, longer, with its chatter (Medium, High) | Gregor Quendel - Crowd Cheering Sounds - 07 - Soft cheering and chatter.mp3 | Gregor Quendel | CC-BY 4.0 | https://opengameart.org/content/free-crowd-cheering-sounds |
| `crowd_cheer_2.ogg` | the crowd going up, another (Medium, High) | Gregor Quendel - Crowd Cheering Sounds - 03 - Strong cheering - I.mp3 | Gregor Quendel | CC-BY 4.0 | https://opengameart.org/content/free-crowd-cheering-sounds |
| `crowd_cheer_3.ogg` | the crowd going up and clapping in time (Medium, High) | Gregor Quendel - Crowd Cheering Sounds - 01 - Strong cheering and strong rhythmic cheering.mp3 | Gregor Quendel | CC-BY 4.0 | https://opengameart.org/content/free-crowd-cheering-sounds |
| `applause_2.ogg` | applause, another (Medium, High) | Gregor Quendel - Crowd Cheering Sounds - 06 - Soft cheering - II.mp3 | Gregor Quendel | CC-BY 4.0 | https://opengameart.org/content/free-crowd-cheering-sounds |

Medium and High hear the long stereo beds and the extra cheers and applause (`Sfx.AMBIENCE_HQ`, `Sfx.react`); Low keeps
the short mono beds and the one cheer, exactly as in 0.3.0.

## Made for the game

| Sound | What | How |
|---|---|---|
| `hip` | the slap of the heavy rubber ball on a leather-clad hip (under `hip_body_*`) | synthesised in `autoload/sfx.gd` |
| `thud_stone` | the ball on plastered stone | synthesised in `autoload/sfx.gd` |
| `throw` | the serve leaving the hand | synthesised in `autoload/sfx.gd` |
| `call` | the judges' drum stroke for a raya | synthesised in `autoload/sfx.gd` |
| `crowd_ooh.ogg`, `crowd_groan.ogg`, `clap.ogg`, `grunt_1-3.ogg`, `hup_1-2.ogg` | the crowd's near miss and groan, a clap, the players' efforts | synthesised by Kabaddi Raid's `tools/audio/make_sounds.py` (the same maker's) |
| `menu_music.ogg` | the menus' music: cane flute, frame drum, slit drum and seed rattles | composed and synthesised by `tools/music/compose.py` |

## Where they play

- **The match**: the hip strike (synthesised slap + a recorded body thump, a grunt or a breath half the time); the ball on
  earth (recorded) or stone (synthesised); bare feet on earth or stone for your player and whoever is going for the
  ball, quieter the further from the camera; the judges' drum; the crowd's murmur, cheers, oohs, groans and applause.
- **Each court's surroundings** (`Sfx.AMBIENCE`): the village at dusk, crickets and now and then a dog far off; the
  festival, a dog now and then under the crowd; the Yucatán stone court by day, birds in the forest over faint insects;
  the stone court by night, crickets and the torches' fire.
- **The menus**: a click for buttons, a softer tick for a choice, the music.
- **Pause** holds every sound where it is and plays nothing new. Settings' Sound and Music switches turn them off.

## Not found (for the owner to source)

- A crowd's "ooh" and groan recorded, ideally a village crowd in Mexico (the ones in the game are synthesised).
- Real ulama sounds: the 3.6 kg ball off a hip and on packed earth, the judges' calls in Spanish. Nothing close is
  on the open sites; a field recording would be the thing.
- Night birds and insects of Sinaloa or Yucatán specifically (the crickets and forest birds are generic).
