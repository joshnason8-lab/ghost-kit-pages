# Meshy brief

## Made (0.2.0)

The owner allowed credits. `tools/meshy/meshy_batch.py` (from the kabaddi game) made these from
`tools/meshy/assets.json`; `tools/meshy/prepare.gd` (from the floorball game) cut them for phones into
`assets/people/`. 560 credits in 0.2.0 (1,763 before, 1,203 after) and 440 in 0.4.0 (763 left); previews first, checked, then textured and rigged.

| Model | What | Use |
|---|---|---|
| player_lean, player_tall, player_stocky | bare-chested, barefoot, tight leather shorts (the gamuza), rigged | every player; gear in code |
| judge_cap | older man, blue shirt, cotton trousers, rigged | both judges (one with a code-built straw hat) |
| fan_ranchero, fan_blouse, fan_elder, fan_tshirt, fan_rebozo, fan_boy, fan_young_woman, fan_guayabera | townspeople, standing | the crowd's sheet |
| fan_huipil, fan_texana, fan_cane, fan_girl, fan_mother, fan_jersey, fan_yucatec, fan_apron (0.4.0) | more townspeople | the 32-figure sheet on Medium and High |
| court_ring (0.4.0) | the carved stone ring, fitted to the court's ring by tools/meshy/fit_ring.gd | the stone court on Medium and High |
| court_stela (0.4.0) | a stela; it came back like a classical column | not used |

The raw downloads stay out of the repo (`assets/meshy/.gitignore`); the manifest keeps the task ids, so the script
fetches them again without spending credits.

## Still to make

These are the models that would improve it most, in order. Each entry gives the prompt to paste, its real-world size, and a triangle budget for the High model; a `_low`
model about a quarter of that should be cut as the shared assets do. Scale it to the size given, stand it on y = 0,
and centre it on x/z.

## 1. The classic court's stone ring

The rings are now plain stone washers (`game/venue.gd`, `_stone_court`). A carved ring is the game's signature image:
it appears on the icon, in the store graphics, and at every ring moment.

- **Prompt:** "A Postclassic Maya ballcourt stone ring, carved limestone, a thick disc with a round hole through its
  centre, a short square tenon at the back for setting it into a wall, shallow relief of two intertwined feathered
  serpents around the face, weathered pale limestone with lichen, realistic photogrammetry style, isolated object,
  no base"
- **Size:** 0.96 m across, hole 0.38 m across, 0.32 m thick, tenon 0.26 × 0.4 × 0.4 m.
- **Budget:** 3,000 triangles High, 800 Low. A 1024 texture, 512 on Low.
- **Where:** two per stone court, at `Court.rings()`. The hole must stay 0.38 m across: R13's rarity depends on it.

## 2. A talud-and-wall court section (the classic court's side structure)

- **Prompt:** "A 6 metre long section of a Maya ballcourt side structure, a sloped stone bench (talud) rising 1.6 m
  over 1.5 m, then a vertical cut limestone wall to 5 m, plastered in places, worn and partly restored, realistic
  archaeological site, tileable along its length, no ring"
- **Size:** 6 m long, 7 m deep (talud plus platform), 5 m tall.
- **Budget:** 4,000 triangles High, 1,000 Low. Six sections make each side (one MultiMesh, two draw calls).
- **Where:** it replaces the boxes and quads of `_stone_court`. The collision stays the code's (`Court.contact`).

## 3. A pyramid for the skyline

- **Prompt:** "A Maya stepped pyramid with a temple on top and a broad central stairway, seven terraces, partly
  restored pale limestone, some vegetation on the upper terraces, realistic, seen from 100 m"
- **Size:** 36 m square base, 30 m tall.
- **Budget:** 6,000 triangles High, 1,500 Low (it is always far away).
- **Where:** `_pyramid` in `game/venue.gd`, 85 m beyond the stone court.

## 4. Stelae

- **Prompt:** "A Maya limestone stela, tall carved slab with a standing figure in low relief and columns of glyph
  blocks on its sides, weathered, on a low round altar stone, realistic museum quality"
- **Size:** 1.3 m wide, 3.2 m tall, 0.5 m deep; the altar 1.2 m across.
- **Budget:** 2,500 triangles High, 600 Low.
- **Where:** one at each end of the stone court (`_stone_court`).

## 5. A floor marker (for a Classic-period court)

- **Prompt:** "A round flat stone ballcourt marker set into a plaster floor, carved relief of two ballplayers facing
  each other across a ball, inside a quatrefoil border, Classic Maya style, weathered limestone, top view"
- **Size:** 0.6 m across, 0.12 m thick.
- **Budget:** 800 triangles.
- **Where:** a future Classic-period court variant with three alley markers and no rings (docs/RULES.md R12).

## 6. A Sinaloa village house

The houses are code boxes with the shared plaster texture.

- **Prompt:** "A small rural house in southern Sinaloa Mexico, one storey, painted plastered brick walls in faded
  pink, a flat concrete roof with a low parapet, a metal door and a barred window, a tin awning, realistic"
- **Size:** 8 m × 6 m, 3.4 m tall.
- **Budget:** 2,000 triangles High, 500 Low.
