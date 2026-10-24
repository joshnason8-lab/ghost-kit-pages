# Store graphics

Everything Google Play needs, rendered from the game itself.

- **`icon-512.png`** — the 512 × 512 hi-res icon. The same picture as the launcher icon
  (`assets/icon/icon_512.png`): the stone ring of the classic court with the rubber ball in its hole. Made by
  `tools/store/make_icons.py` from `tools/store/icon_render.tscn`.
- **`feature-1024x500.png`** — the feature graphic: the stone court and its ring, the game's name on a limestone
  wash. Made by `tools/store/make_feature.py`.
- **`screenshots/`** — at least four 1920 × 1080 landscape screenshots, rendered on High graphics by
  `tools/store/store_shots.tscn`: a match on each court (a hip strike, the crowd, the judge at the analco), the home
  screen's stela, match setup, How to Play and the tournament. Shown in different languages.

To rebuild:

```
xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/store/icon_render.tscn -- tools/store
python3 tools/store/make_icons.py
python3 tools/store/make_feature.py
xvfb-run -a godot --path . --rendering-driver opengl3 --fixed-fps 30 res://tools/store/store_shots.tscn -- store/graphics/screenshots
```

The icon's source render (`tools/store/icon_render_source.webp`) and the feature graphic's
(`tools/store/feature_source.webp`) are kept so the images can be remade without a GPU.
