# Sounds: what plays, and where each comes from

Every sound is Ogg Vorbis, mono, in `assets/audio/`, apart from a few the game makes in code (`autoload/sfx.gd`):
the referee's whistle, the buzzer, the whoosh. The recordings are cut, faded, looped and brought to one level by
`tools/audio/prepare_sounds.py` (below), from packs downloaded from the pages listed here. Their credits are on the
Licences screen.

## What plays when

| Sound | When | Where it is heard |
|---|---|---|
| `kick` (3 takes), `knee` (2), `spike`, `block` | the ball touched: a kick (sila, kuda, a serve, a set), a thigh, chest or head touch, a spike, a block | from the ball (`Sfx.play_at`: to the side of the picture it is on) |
| `bounce` (2) / `bounce_sand` | the ball on the floor: the court, or the beach's sand | from the ball |
| `net` | the ball into the net | from the ball |
| `step_court` (3) / `step_sand` (3) | a footstep each half stride while a player runs, louder the faster (none in the home screen's match) | from his feet |
| `crowd_loop` | the crowd's murmur, under every match, louder as a rally builds | all round |
| `crowd_cheer`, `applause`, `crowd_ooh`, `crowd_groan` | the crowd is the home side's: a cheer for a point after a long rally or a kill, applause after a short one; a groan when their side gives a point away (out, into the net, a fault); an "ooh" for a block and for a ball right on a line | all round |
| `amb_beach`, `amb_temple`, `amb_park`, `amb_chatter` | each outdoor venue's own sound (the sea, birds, a summer evening), a mall's and a night market's chatter | all round, under the crowd |
| `drums_loop` | the arenas' drums, louder in a long rally | all round |
| `whistle`, `whistle_long` | the serve, a fault, the end of a set (made in code) | all round |
| `hup`, `grunt` | the players' efforts | all round |
| `click` | a button | all round |
| `menu_music` | the home screen and the menus | all round |

Pausing a match holds every sound where it is (`Sfx.pause`) and carries on from there after. Settings > Sound turns
all of them off, Settings > Music the music.

## Where each comes from

| File | Source | Author | Licence | Made from |
|---|---|---|---|---|
| `kick.ogg`, `kick_2.ogg`, `kick_3.ogg` | [Wood and Metal Sound Effects: Volume 2](https://opengameart.org/content/wood-and-metal-sound-effects-volume-2) | Ogrebane | CC0 | `wood14`, `wood7`, `wood10`: a dry, hollow knock |
| `spike.ogg` | the same; [Punch, slap, n' kick](https://opengameart.org/content/punch-slap-n-kick) | Ogrebane; CGEffex (submitted by congusbongus) | CC0; CC BY 3.0 | `wood1` with the slap `11.ogg` under it (-4 dB) |
| `block.ogg` | [Impact Sounds](https://kenney.nl/assets/impact-sounds); Wood and Metal vol. 2 | Kenney; Ogrebane | CC0 | `impactPunch_heavy_000` with `wood1` under it (-8 dB) |
| `knee.ogg`, `knee_2.ogg` | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 | `impactSoft_medium_000`, `_002` |
| `bounce.ogg`, `bounce_2.ogg` | Impact Sounds | Kenney | CC0 | `impactWood_medium_000`, `_002` |
| `bounce_sand.ogg` | Impact Sounds; [Fantozzi's Footsteps](https://opengameart.org/content/fantozzis-footsteps-grasssand-stone) | Kenney; Fantozzi (submitted by qubodup) | CC0 | `impactSoft_heavy_000` with `Fantozzi-SandL1` under it (-6 dB) |
| `net.ogg` | Impact Sounds; [RPG Audio](https://kenney.nl/assets/rpg-audio) | Kenney | CC0 | `impactSoft_medium_001` and the cloth rustle `cloth1` (-3 dB) |
| `crowd_loop.ogg` | [Free Crowd Cheering Sounds](https://opengameart.org/content/free-crowd-cheering-sounds) | Gregor Quendel | CC BY 4.0 | "10 - Ambience", 3 to 27 s, looped |
| `crowd_cheer.ogg` | the same | Gregor Quendel | CC BY 4.0 | "03 - Strong cheering - I", the first 3.6 s |
| `applause.ogg` | [Applause in a large hall or church](https://opengameart.org/content/applause-in-a-large-hall-or-church) | eXpl0it3r | CC0 | 4 to 8 s |
| `amb_beach.ogg`, `amb_temple.ogg`, `amb_park.ogg` | [Nature Ambient Pack Vol 1](https://opengameart.org/content/jc-sounds-nature-ambient-pack-vol-1) | JC Sounds | CC BY 4.0 | "Ocean Waves", "Rainforest Canopy" (5 to 33 s), "Summer Evening" (40 to 68 s: before it, a car passing), looped |
| `amb_chatter.ogg` | [Free General Ambience Sounds](https://opengameart.org/content/free-general-ambience-sounds) | Gregor Quendel | CC BY-SA 4.0 (this cut of it too) | "crowd - mall ambience", 5 to 33 s, looped |
| `step_court.ogg`, `_2`, `_3` | [Footsteps on different surfaces](https://opengameart.org/content/footsteps-on-different-surfaces) | congusbongus, from recordings by swuing and ceberation (freesound.org) | CC BY 3.0 | `tile/0`, `3`, `6`: a trainer's step, some with a squeak |
| `step_sand.ogg`, `_2`, `_3` | Fantozzi's Footsteps | Fantozzi | CC0 | `SandL1`, `SandR1`, `SandL2` |
| `click.ogg` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | CC0 | `click_002` |
| `menu_music.ogg` | [Kingdom of a Million Elephants under a White Parasol](https://opengameart.org/content/kingdom-of-a-million-elephants-under-a-white-parasol) | Spring Spring (Julie Damsgaard) | CC0 | the whole piece (92 s), looped |
| `crowd_ooh.ogg`, `crowd_groan.ogg`, `clap.ogg`, `hup_*.ogg`, `grunt_*.ogg` | Kabaddi Raid | the same maker | the game's own | kept |
| `drums_loop.ogg` | `tools/audio/make_music.py` | written for the game | the game's own | kept |

## How they are made

`python3 tools/audio/prepare_sounds.py DOWNLOADS_DIR [name ...]` (ffmpeg and numpy): each pack downloaded from its page
above into one folder, under the pack's own file names (the paths are in the script's `SOUNDS` table).

- **Cut** to the stretch used, a short fade in and out; a one-shot starts at its first sound.
- **Loops** (the crowd's murmur, the venues' sounds, the music): the stretch after the loop's end crossfaded into its
  start (1.5 to 2 s, equal power), so it plays round without a seam.
- **One level for the set:** the ball's sounds by their loudest 50 ms at -12 dBFS (where the game's synthesised ones
  sat, so the game's volumes still fit), soft touches -14, footsteps -16; the crowd's reactions -18 dBFS on average, its
  murmur -26, the venues' sounds -24, the music -18; nothing over -1 dBFS.
- **Encoded** as Ogg Vorbis, mono: one-shots at 22 kHz (quality 3), the long ones at 32 kHz (quality 2).

## Size

The sounds went from 0.29 MB to 1.83 MB (the four venue loops about 200 KB each, the music 660 KB).

## Not found (to source by hand)

Nothing under a free licence on the sites the game can use (Kenney, OpenGameArt) for these; the game keeps what it had:

- **A referee's pea whistle**, a short and a long blast: only lip whistles and synthesised tones. The whistle stays the
  game's own, made in code.
- **A real takraw ball** (a hollow woven or plastic ball) being kicked: the nearest are wooden knocks.
- **A ball into a net:** made from a soft thud and a cloth's rustle.
- **A crowd's groan and "ooh":** only single voices. Kabaddi Raid's stay.
- **A Southeast Asian night market** (Thai, Malay or Indonesian voices, motorbikes, food stalls): only a European mall's
  chatter.
- **A sports hall's echoing room tone**, and **longer trainer squeaks** on a sprung floor.
- **Thai, Malay or Indonesian music** (piphat, gamelan, angklung), and players' calls in the region's languages.
