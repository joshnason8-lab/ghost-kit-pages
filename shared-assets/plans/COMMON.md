# Common brief for the graphics update (all six games)

The owner asked for every game's graphics to be upgraded: sky lighting, court and ground surfaces, water in the
background where it belongs, what's outside the stadium, trees, benches, seats, stands, crowds, goals and the small
things. **Accurate to the region** (no temples in Ireland, no palms at an Irish parish field, no Japanese buildings
anywhere), **realistic, never cartoon**, and still fast on a 2–3 GB phone at Low.

1. **Read your plan in this folder and `../README.md`.** Copy only the files you use into your game (`git checkout
   origin/claude/shared-assets -- shared-assets/<path>`), into your own `assets/` folder.
2. **Venue by venue**, as your plan lists: sky, ground, surrounds, small details. You may move or skip items when your
   own venue layout or camera says otherwise, but record why in `docs/PROGRESS.md`.
3. **Phones first.** Low uses the `_low` meshes and cut-outs only, `*_sky_2k.jpg` as a plain panorama and no HDR
   lighting. Use `MultiMeshInstance3D` for every repeated thing. `tests/perf_probe` before and after: stay inside your
   Low budget. Put the numbers in the README.
4. **Look at it.** Screenshot every venue on Low and High from the match camera and the menu backdrop. Fix anything
   that floats, clips, sits in the wrong scale or looks out of place, and refresh the store screenshots.
5. **Keep everything green:** test_runner, fit_audit, CI, the beta release. Bump the minor version and say what
   changed in BETA and the release notes.
6. **Credit "Poly Haven (polyhaven.com), CC0"** in Settings > About > Licences.
7. **The owner's Meshy credits:** don't spend any. If your plan's "gaps" section needs a new model, say so in
   PROGRESS and in your final message, and the lead will ask the owner.
