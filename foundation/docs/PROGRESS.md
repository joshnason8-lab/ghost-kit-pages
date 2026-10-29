# Progress (resume from here)

Branch `claude/shared-foundation` (public: code only). Private data: `joshnason8-lab/world-stage-games-assets`
(release `mocap-source` holds `FBX_Mobility_27B_Pro.zip`; download with
`gh api -H "Accept: application/octet-stream" repos/joshnason8-lab/world-stage-games-assets/releases/assets/689900709 > mobility.zip`).
Lead session: session_016XKAyHkTQRNMGEgZbjNK28. Pilot branch: `claude/hurling-foundation-pilot` (from claude/hurling-game).

## Facts found
- Mobility: 223 clips in `Animation/IPC` (in place) and `Animation/Root_Motion`, 18 aim offsets, the MotusMan mesh.
  73-bone HumanIK skeleton (Root, Hips, Spine, Spine1, Spine2, Neck, Head, fingers 1-4, `Leaf*Roll1` twist leaves,
  `hand_*_wep`). Bind pose: T-pose facing +Z. 30 fps. Clips animate ForeArmRoll and LegRoll leaves, not ArmRoll/UpLegRoll.
- Owner's hurler (`player.glb`, Google Drive id 1WDmggD62izAKyLWvZ6bbfaVwRIKf9pg8): Meshy auto-rig, 23 mixamorig bones,
  A-pose, no fingers, 106k vertices; its hands are modelled with separate, slightly curled fingers.
- Six of seven games use the same 17-bone pose dictionary (ToonBody convention); Kho-kho uses a 23-bone Mixamo
  AnimationPlayer. All have `Crowd.build(spots, density, palette, seed, ...)` and `Crowd.set_excite(k)` (not Kabaddi).
  Quality: `Game.settings.graphics` 0/1/2, `Game.crowd_density()`.
- Godot 4.7 has native TwoBoneIK3D, LookAtModifier3D, BoneTwistDisperser3D.
- Gotcha: never set bone poses from inside `skeleton_updated` (Godot restores the pre-modifier poses after it).

## Milestones
- [x] M1 rig: `rig.gd`, `rig_driver.gd`, `body.gd`, `grip.gd`, `tools/bake_character.*`, `tests/rig_test.gd` (PASS).
- [ ] M2 locomotion
- [ ] M3 crowd
- [ ] M4 officials
- [ ] Pilot in Hurling, MP4s, ADOPTING.md, CI private-asset step
