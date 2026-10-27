# The media kit

Everything the website needs about the game, made from the game itself by one script and published by GitHub
Actions as `media-kit-netball-unleashed.zip`:

| Folder | What |
|---|---|
| `screenshots/` | 12 PNGs, 1920x1080, High graphics, as broadcast (scoreboard, no buttons, no debug overlay): a centre pass, a shot and a goal (the close shot of the post, the LED boards' "GOAL!") in the arena, play and a goal in the sports hall, play at the outdoor park court, the team card, the home screen, quick setup, the Nations Cup, How to Play, a result |
| `menus/` | Every menu screen in English, 1920x1080, named by screen (`01_home.png`...): home, quick setup (teams, venue, options), settings, How to Play's four tabs, the pause menu, the interval, the result and box score, the Nations Cup and Club Season (picking, and the hub), records, Licences, Help, Privacy. A screen that scrolls has a picture per page (`_2`, `_3`...) |
| `icons/` | `icon-1024.png`, `icon-512.png` (the owner's artwork, a full square picture, so opaque), `feature-graphic-1024x500.png` (from `store/graphics/`, made by `tools/store/make_feature.py`) |
| `trailer/` | `netball-unleashed-trailer-1080p.mp4`: about 41 s, 1920x1080, 30 fps, H.264 and AAC: the title card, five shots of real AI v AI play on High (goals in all three venues, a miss off the ring, the arena's celebration), captions "Three venues", "Play offline", "Nations Cup · Club Season", the end card "Coming soon to Google Play". `netball-unleashed-vertical-15s.mp4`: a 15 s 1080x1920 cut for social media, big captions |
| `text/` | Website copy in Markdown (`tools/media/text/`, the version filled in from `project.godot`): `about.md`, `features.md`, `facts.md`, `sport.md`, `press.md` |
| `CREDITS.txt` | The licence and credit of everything in the kit (the trailer's sounds are the game's own, CC0, Pixabay or CC-BY 4.0; none of the CC-BY-SA beds) |

## Run it

From `netball-game/`, with Godot 4.7.2 on the PATH (or `GODOT=/path/to/godot`), `xvfb-run`, `ffmpeg` and Python 3
with Pillow, after importing the project once (`godot --headless --path . --import`):

```
tools/media/make_media_kit.sh              # into build/media (ignored by git)
tools/media/make_media_kit.sh /tmp/kit     # anywhere else
SKIP_TRAILER=1 tools/media/make_media_kit.sh   # pictures, text and credits only (a minute or two)
```

On a machine without a GPU (software GL, as in CI) the pictures take about two minutes and the trailer's frames
about 15-20 minutes. The working files (scans, frames, segments, logs) stay in `OUT/work`.

How it works:

1. `tests/screenshots.tscn` with the parts `media,kitmenus` on High saves the screenshots and the menus. While it
   waits for a moment of play (a shot, a goal) nothing is drawn, so the match runs on fast.
2. `tools/media/record.tscn` plays an AI v AI match in each venue (seeded, at a fixed 30 fps) without drawing, and
   writes the frame of each goal, shot and miss (`scan`).
3. `compose.py plan` picks the trailer's moments from those; `record.tscn` plays the same matches again (same seed,
   same steps: the same play, checked by `compose.py check`) and draws and saves only those frames as JPEGs. (Godot's
   Movie Maker, `--write-movie`, would draw every frame of every match: hours on a CPU.)
4. `compose.py trailer` makes the cards and captions with the game's fonts (Barlow Condensed, OFL), cuts the shots
   with ffmpeg, and mixes the sound: the menu music, and at each goal the swish and a cheer, at the miss the ring and
   a groan.
5. `compose.py` copies the icons, the text and the credits, and zips it all.

What is in the trailer is set at the top of `compose.py` (`VENUES`: the matches and seeds; `CLIPS`: which goals,
how long before and after; the captions; `V_SHOTS`: the vertical cut).

## CI and the release

`.github/workflows/netball-media-kit.yml` runs on a push that changes `netball-game/tools/media/**` or the workflow
itself, and by hand (Actions > "Netball Unleashed · Media kit" > Run workflow). It installs Godot like the Android
build, ffmpeg, Xvfb and Pillow, runs the script, keeps the zip as a workflow artifact, and publishes it to the release
**`netball-unleashed-media`** ("Media kit: Netball Unleashed"): a prerelease, never marked latest, its zip replaced on
each run. The beta APK's release (`netball-unleashed-beta`) is not touched.

The zip's link for the website:
https://github.com/joshnason8-lab/ghost-kit-pages/releases/download/netball-unleashed-media/media-kit-netball-unleashed.zip

A push under `netball-game/tools/media/` also runs the Android build (it watches all of `netball-game/**`), which
rebuilds and republishes the beta APK.
