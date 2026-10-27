# Store graphics

Everything Google Play needs, rendered from the game itself.

- **`icon-512.png`** — the 512 × 512 hi-res icon. The same picture as the launcher icon
  (`assets/icon/icon_512.png`): the stone ring of the classic court with the rubber ball in its hole. Made by
  `tools/store/make_icons.py` from `tools/store/icon_render.tscn`.
- **`feature-1024x500.png`** — the feature graphic: the stone court and its ring, the game's name on a limestone
  wash. Made by `tools/store/make_feature.py`.
- **`screenshots/`** — eight 1920 × 1080 landscape screenshots, rendered on High graphics by
  `tools/store/store_shots.tscn`: a match on each court (two from the game's end camera), the home screen, match
  setup, How to Play and the tournament, in the listing's languages.

These are **drafts**: remake them from the current build just before submitting to Play, so they show the game as
it is then. One command does it all (it needs a display, so it runs under xvfb-run on a machine without one):

```
tools/store/make_store_graphics.sh
```

It renders the eight screenshots on High (`tools/store/store_shots.gd`, set "store"), re-renders the feature
graphic's picture of the stone court and makes the graphic (`tools/store/make_feature.py`), copies the 512 icon as a
32-bit PNG, and saves the screenshots and feature graphic as 24-bit PNGs, as Play asks. The launcher icon itself is
made by `tools/store/make_icons.py` from `tools/store/icon_render_source.webp`.
