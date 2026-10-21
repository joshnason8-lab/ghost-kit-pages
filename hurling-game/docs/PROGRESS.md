# Ash & Leather: progress

The hurling game, built overnight on `claude/hurling-game`. If work stops, resume from here and `git log`.

## Done
- Project copied from a snapshot of Takraw Smash (its infrastructure: autoloads, UI helpers, tests, CI), with the
  Takraw-specific game, leagues, art and languages taken out.
- Research (in the session's scratchpad, written up into docs/): how hurling is played (numbers), markets and
  languages, Play policy, names.
- Fonts: Noto Sans (body), Oswald (programme-style headings), Uncial Antiqua (the title), all with Irish fadas; Noto
  and Oswald subset to Latin + Latin Extended-A (312 KB in all).
- autoload/game.gd: settings, palette, frame rate, graphics; autoload/db.gd: twenty counties, invented players.

## Next
- Rules module + tests, pitch, sliotar, players, AI, officials, match, HUD, menus, tests, CI, store, pages.

## Decisions
- **Name: Ash & Leather** (slug `ash-and-leather`). The "clash of the ash" (the hurley) on leather (the sliotar).
  Web and store search (21 Oct 2026) found no app or game by that name; the hurling apps on the stores are Flick
  Hurling, the old GPA Hurling, Red Bull Strike and Hurl Clash. Rejected: "Puc Fada" (a real GAA competition),
  "Clash of the Ash" (the crowded "Clash of ..." space), "Hurl" (Hurl Clash), "Small Ball" (an existing app).
- **Counties as places.** County names are place names, so they are used plainly (in English and Irish). No crests,
  no county-board jerseys (each county wears its traditional colours in one of the game's own four kit designs, no
  crest, no sponsor), no nicknames (fans' nicknames such as a county's animal are associated with the county boards'
  marketing), no real competition names (the game's competition is "the Summer Championship").
- **Players are invented**: common Irish first names and surnames, combined from a seed, with a block-list of
  well-known hurlers' names that are never generated.
- **Languages**: English and Irish (docs/LANGUAGES.md).
