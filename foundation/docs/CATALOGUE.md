# The clip library (names only)

The motion capture the owner bought, as the foundation's builds have it: the MoCap Online Mobility pack and the
ActorCore moves baked so far. **Names only**: the animation is licensed and lives only in the private assets
repo and inside compiled APKs (addons/wsg_foundation/data/, fetched at build time). A game session that wants a
clip wired in asks the foundation session by name. Written by tools/catalogue.py.

More ActorCore takes are in the private zip than are baked here (tools/bake_actorcore.gd's CLIPS picks them):
the foundation's CI prints the zip's take names (names only) in the licensed-assets step's log.

| Set | Clip | Length (s) | Kind | What | Used by |
|---|---|---:|---|---|---|
| actorcore | `Celebrate_FistPump` | 7.47 | once | Celebrate fistpump | Hurling (scorer) |
| actorcore | `Celebrate_Jump` | 9.07 | once | Celebrate jump | Hurling (scorer) |
| actorcore | `Crowd_Cheer` | 12.13 | once | Crowd cheer | all (WsgCrowd3D) |
| actorcore | `Crowd_Sit_Clap` | 12.57 | once | Crowd sit clap | all (WsgCrowd3D) |
| actorcore | `Crowd_Sit_Idle` | 3.37 | loop | Crowd sit idle | all (WsgCrowd3D) |
| actorcore | `Crowd_Stand_Clap` | 11.27 | once | Crowd stand clap | all (WsgCrowd3D) |
| actorcore | `Crowd_Stand_To_Sit` | 10.87 | once | Crowd stand to sit | all (WsgCrowd3D) |
| actorcore | `Disappointed_HandsOnHead` | 8.37 | once | Disappointed handsonhead | Hurling |
| actorcore | `Dive_Forward` | 2.67 | once | Dive forward | Hurling |
| actorcore | `Extra_DiveCatchPass` | 6.57 | once | Extra divecatchpass |  |
| actorcore | `Extra_Shoot` | 6.60 | once | Extra shoot |  |
| actorcore | `Extra_Shoot_Fake` | 3.07 | once | Extra shoot fake |  |
| actorcore | `Pass_Throw` | 16.13 | once | Pass throw |  |
| actorcore | `Ready_Stance` | 3.13 | loop | Ready stance | Hurling |
| actorcore | `Sprint_F_Loop` | 0.53 | loop | Sprint forward | all (WsgLocomotor: sprint) |
| mobility | `Jog_BL_BkPd_Loop` | 0.80 | loop | Jog back-left backpedal | all (WsgLocomotor) |
| mobility | `Jog_BR_BkPd_Loop` | 0.80 | loop | Jog back-right backpedal | all (WsgLocomotor) |
| mobility | `Jog_B_Loop` | 0.80 | loop | Jog backward | all (WsgLocomotor) |
| mobility | `Jog_B_To_Stand_Relaxed` | 2.43 | once | Jog backward to standing | all (WsgLocomotor) |
| mobility | `Jog_B_To_Stand_Relaxed_LU` | 2.03 | once | Jog backward to standing left foot up | all (WsgLocomotor) |
| mobility | `Jog_B_To_Stand_Relaxed_RU` | 1.73 | once | Jog backward to standing right foot up | all (WsgLocomotor) |
| mobility | `Jog_FL_Loop` | 0.80 | loop | Jog forward-left | all (WsgLocomotor) |
| mobility | `Jog_FR_Loop` | 0.80 | loop | Jog forward-right | all (WsgLocomotor) |
| mobility | `Jog_F_Loop` | 0.80 | loop | Jog forward | all (WsgLocomotor) |
| mobility | `Jog_F_To_Stand_Relaxed` | 2.37 | once | Jog forward to standing | all (WsgLocomotor) |
| mobility | `Jog_F_To_Stand_Relaxed_LU` | 2.00 | once | Jog forward to standing left foot up | all (WsgLocomotor) |
| mobility | `Jog_F_To_Stand_Relaxed_RU` | 1.77 | once | Jog forward to standing right foot up | all (WsgLocomotor) |
| mobility | `Jog_L_180` | 2.57 | once | Jog left 180 | all (WsgLocomotor) |
| mobility | `Jog_L_90` | 2.40 | once | Jog left 90 | all (WsgLocomotor) |
| mobility | `Jog_L_BkPd_Loop` | 0.80 | loop | Jog left backpedal | all (WsgLocomotor) |
| mobility | `Jog_L_CIR_Loop` | 0.80 | loop | Jog left circling | all (WsgLocomotor) |
| mobility | `Jog_L_Loop` | 0.80 | loop | Jog left | all (WsgLocomotor) |
| mobility | `Jog_L_To_Stand_Relaxed` | 2.77 | once | Jog left to standing | all (WsgLocomotor) |
| mobility | `Jog_L_To_Stand_Relaxed_LU` | 2.43 | once | Jog left to standing left foot up | all (WsgLocomotor) |
| mobility | `Jog_L_To_Stand_Relaxed_RU` | 1.97 | once | Jog left to standing right foot up | all (WsgLocomotor) |
| mobility | `Jog_R_180` | 2.27 | once | Jog right 180 | all (WsgLocomotor) |
| mobility | `Jog_R_90` | 2.33 | once | Jog right 90 | all (WsgLocomotor) |
| mobility | `Jog_R_BkPd_Loop` | 0.80 | loop | Jog right backpedal | all (WsgLocomotor) |
| mobility | `Jog_R_CIR_Loop` | 0.80 | loop | Jog right circling | all (WsgLocomotor) |
| mobility | `Jog_R_Loop` | 0.80 | loop | Jog right | all (WsgLocomotor) |
| mobility | `Jog_R_To_Stand_Relaxed` | 2.07 | once | Jog right to standing | all (WsgLocomotor) |
| mobility | `Jog_R_To_Stand_Relaxed_LU` | 1.63 | once | Jog right to standing left foot up | all (WsgLocomotor) |
| mobility | `Jog_R_To_Stand_Relaxed_RU` | 1.33 | once | Jog right to standing right foot up | all (WsgLocomotor) |
| mobility | `Run_FL_Loop` | 0.57 | loop | Run forward-left | all (WsgLocomotor) |
| mobility | `Run_FR_Loop` | 0.57 | loop | Run forward-right | all (WsgLocomotor) |
| mobility | `Run_F_Loop` | 0.57 | loop | Run forward | all (WsgLocomotor) |
| mobility | `Run_F_To_Stand_Relaxed` | 2.83 | once | Run forward to standing | all (WsgLocomotor) |
| mobility | `Run_F_To_Stand_Relaxed_LU` | 2.50 | once | Run forward to standing left foot up | all (WsgLocomotor) |
| mobility | `Run_F_To_Stand_Relaxed_RU` | 2.33 | once | Run forward to standing right foot up | all (WsgLocomotor) |
| mobility | `Run_L_180` | 3.00 | once | Run left 180 | all (WsgLocomotor) |
| mobility | `Run_L_90` | 2.00 | once | Run left 90 | all (WsgLocomotor) |
| mobility | `Run_L_CIR_Loop` | 0.60 | loop | Run left circling | all (WsgLocomotor) |
| mobility | `Run_L_Loop` | 0.57 | loop | Run left | all (WsgLocomotor) |
| mobility | `Run_L_To_Stand_Relaxed` | 3.17 | once | Run left to standing | all (WsgLocomotor) |
| mobility | `Run_L_To_Stand_Relaxed_LU` | 3.03 | once | Run left to standing left foot up | all (WsgLocomotor) |
| mobility | `Run_L_To_Stand_Relaxed_RU` | 2.83 | once | Run left to standing right foot up | all (WsgLocomotor) |
| mobility | `Run_R_180` | 2.83 | once | Run right 180 | all (WsgLocomotor) |
| mobility | `Run_R_90` | 1.70 | once | Run right 90 | all (WsgLocomotor) |
| mobility | `Run_R_CIR_Loop` | 0.63 | loop | Run right circling | all (WsgLocomotor) |
| mobility | `Run_R_Loop` | 0.57 | loop | Run right | all (WsgLocomotor) |
| mobility | `Run_R_To_Stand_Relaxed` | 3.10 | once | Run right to standing | all (WsgLocomotor) |
| mobility | `Run_R_To_Stand_Relaxed_LU` | 2.67 | once | Run right to standing left foot up | all (WsgLocomotor) |
| mobility | `Run_R_To_Stand_Relaxed_RU` | 2.87 | once | Run right to standing right foot up | all (WsgLocomotor) |
| mobility | `Stand_Relaxed_Conv_v1` | 15.60 | once | Standing conversation (v1) |  |
| mobility | `Stand_Relaxed_Conv_v2` | 16.27 | once | Standing conversation (v2) |  |
| mobility | `Stand_Relaxed_Conv_v3` | 16.43 | once | Standing conversation (v3) |  |
| mobility | `Stand_Relaxed_Conv_v4` | 16.87 | once | Standing conversation (v4) |  |
| mobility | `Stand_Relaxed_Fgt_v1` | 5.03 | once | Standing fidget (v1) |  |
| mobility | `Stand_Relaxed_Fgt_v2` | 6.00 | once | Standing fidget (v2) |  |
| mobility | `Stand_Relaxed_Fgt_v3` | 4.53 | once | Standing fidget (v3) |  |
| mobility | `Stand_Relaxed_Fgt_v4` | 6.77 | once | Standing fidget (v4) |  |
| mobility | `Stand_Relaxed_Hop` | 2.80 | once | Standing hop |  |
| mobility | `Stand_Relaxed_Hop_B` | 2.23 | once | Standing hop backward |  |
| mobility | `Stand_Relaxed_Hop_F` | 2.47 | once | Standing hop forward |  |
| mobility | `Stand_Relaxed_Hop_L` | 2.10 | once | Standing hop left |  |
| mobility | `Stand_Relaxed_Hop_R` | 2.20 | once | Standing hop right |  |
| mobility | `Stand_Relaxed_Idle` | 4.10 | loop | Standing idle | all (WsgLocomotor: standing) |
| mobility | `Stand_Relaxed_Idle_v2` | 6.13 | loop | Standing idle (v2) | all (WsgLocomotor: standing) |
| mobility | `Stand_Relaxed_Jump_B` | 3.33 | once | Standing jump backward |  |
| mobility | `Stand_Relaxed_Jump_F` | 2.97 | once | Standing jump forward |  |
| mobility | `Stand_Relaxed_Jump_L` | 2.83 | once | Standing jump left |  |
| mobility | `Stand_Relaxed_Jump_R` | 3.03 | once | Standing jump right |  |
| mobility | `Stand_Relaxed_L_135` | 3.20 | once | Standing left 135 | all (WsgLocomotor: turns) |
| mobility | `Stand_Relaxed_L_180` | 3.77 | once | Standing left 180 | all (WsgLocomotor: turns) |
| mobility | `Stand_Relaxed_L_45` | 2.37 | once | Standing left 45 | all (WsgLocomotor: turns) |
| mobility | `Stand_Relaxed_L_90` | 2.80 | once | Standing left 90 | all (WsgLocomotor: turns) |
| mobility | `Stand_Relaxed_Look_Center` | 0.03 | once | Standing look center |  |
| mobility | `Stand_Relaxed_Look_D90` | 0.03 | once | Standing look down |  |
| mobility | `Stand_Relaxed_Look_L90` | 0.03 | once | Standing look l90 |  |
| mobility | `Stand_Relaxed_Look_LD45` | 0.03 | once | Standing look down-left |  |
| mobility | `Stand_Relaxed_Look_LU45` | 0.03 | once | Standing look up-left |  |
| mobility | `Stand_Relaxed_Look_R90` | 0.03 | once | Standing look r90 |  |
| mobility | `Stand_Relaxed_Look_RD45` | 0.03 | once | Standing look down-right |  |
| mobility | `Stand_Relaxed_Look_RU45` | 0.03 | once | Standing look up-right |  |
| mobility | `Stand_Relaxed_Look_U90` | 0.03 | once | Standing look up |  |
| mobility | `Stand_Relaxed_R_135` | 3.53 | once | Standing right 135 | all (WsgLocomotor: turns) |
| mobility | `Stand_Relaxed_R_180` | 3.67 | once | Standing right 180 | all (WsgLocomotor: turns) |
| mobility | `Stand_Relaxed_R_45` | 2.70 | once | Standing right 45 | all (WsgLocomotor: turns) |
| mobility | `Stand_Relaxed_R_90` | 3.17 | once | Standing right 90 | all (WsgLocomotor: turns) |
| mobility | `Stand_Relaxed_To_Crouch` | 2.47 | once | Standing to crouch | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Jog_B` | 1.53 | once | Standing to jog backward | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Jog_F` | 1.37 | once | Standing to jog forward | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Jog_L` | 1.57 | once | Standing to jog left | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Jog_L135_Fwd` | 1.67 | once | Standing to jog l135 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Jog_L180_Fwd` | 1.73 | once | Standing to jog l180 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Jog_L45_Fwd` | 1.20 | once | Standing to jog l45 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Jog_L90_Fwd` | 1.57 | once | Standing to jog l90 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Jog_R` | 1.20 | once | Standing to jog right | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Jog_R135_Fwd` | 1.20 | once | Standing to jog r135 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Jog_R180_Fwd` | 1.27 | once | Standing to jog r180 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Jog_R45_Fwd` | 1.63 | once | Standing to jog r45 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Jog_R90_Fwd` | 1.13 | once | Standing to jog r90 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Run_F` | 1.67 | once | Standing to run forward | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Run_L` | 1.37 | once | Standing to run left | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Run_L135_Fwd` | 1.27 | once | Standing to run l135 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Run_L180_Fwd` | 1.30 | once | Standing to run l180 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Run_L45_Fwd` | 1.30 | once | Standing to run l45 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Run_L90_Fwd` | 1.27 | once | Standing to run l90 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Run_R` | 1.63 | once | Standing to run right | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Run_R135_Fwd` | 1.50 | once | Standing to run r135 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Run_R180_Fwd` | 1.63 | once | Standing to run r180 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Run_R45_Fwd` | 1.47 | once | Standing to run r45 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Run_R90_Fwd` | 1.47 | once | Standing to run r90 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Walk_B` | 2.20 | once | Standing to walk backward | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Walk_F` | 1.67 | once | Standing to walk forward | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Walk_L` | 1.70 | once | Standing to walk left | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Walk_L135_Fwd` | 2.23 | once | Standing to walk l135 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Walk_L180_Fwd` | 2.33 | once | Standing to walk l180 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Walk_L45_Fwd` | 1.73 | once | Standing to walk l45 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Walk_L90_Fwd` | 1.83 | once | Standing to walk l90 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Walk_R` | 1.27 | once | Standing to walk right | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Walk_R135_Fwd` | 1.73 | once | Standing to walk r135 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Walk_R180_Fwd` | 1.73 | once | Standing to walk r180 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Walk_R45_Fwd` | 1.27 | once | Standing to walk r45 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Relaxed_To_Walk_R90_Fwd` | 2.47 | once | Standing to walk r90 fwd | all (WsgLocomotor: starts) |
| mobility | `Stand_Rlx_Turn_In_Place_L_Loop` | 0.67 | loop | Standing turn in place left | all (WsgLocomotor: turns) |
| mobility | `Stand_Rlx_Turn_In_Place_R_Loop` | 0.67 | loop | Standing turn in place right | all (WsgLocomotor: turns) |
| mobility | `Walk_BL_BkPd_Loop` | 1.20 | loop | Walk back-left backpedal | all (WsgLocomotor) |
| mobility | `Walk_BR_BkPd_Loop` | 1.20 | loop | Walk back-right backpedal | all (WsgLocomotor) |
| mobility | `Walk_B_Loop` | 1.20 | loop | Walk backward | all (WsgLocomotor) |
| mobility | `Walk_B_To_Stand_Relaxed` | 3.23 | once | Walk backward to standing | all (WsgLocomotor) |
| mobility | `Walk_B_To_Stand_Relaxed_LU` | 1.37 | once | Walk backward to standing left foot up | all (WsgLocomotor) |
| mobility | `Walk_B_To_Stand_Relaxed_RU` | 2.00 | once | Walk backward to standing right foot up | all (WsgLocomotor) |
| mobility | `Walk_FL_Loop` | 1.20 | loop | Walk forward-left | all (WsgLocomotor) |
| mobility | `Walk_FR_Loop` | 1.20 | loop | Walk forward-right | all (WsgLocomotor) |
| mobility | `Walk_F_Loop` | 1.20 | loop | Walk forward | all (WsgLocomotor) |
| mobility | `Walk_F_To_Stand_Relaxed` | 2.80 | once | Walk forward to standing | all (WsgLocomotor) |
| mobility | `Walk_F_To_Stand_Relaxed_LU` | 2.20 | once | Walk forward to standing left foot up | all (WsgLocomotor) |
| mobility | `Walk_F_To_Stand_Relaxed_RU` | 1.57 | once | Walk forward to standing right foot up | all (WsgLocomotor) |
| mobility | `Walk_L_180` | 3.03 | once | Walk left 180 | all (WsgLocomotor) |
| mobility | `Walk_L_90` | 2.50 | once | Walk left 90 | all (WsgLocomotor) |
| mobility | `Walk_L_BkPd_Loop` | 1.20 | loop | Walk left backpedal | all (WsgLocomotor) |
| mobility | `Walk_L_CIR_Loop` | 1.20 | loop | Walk left circling | all (WsgLocomotor) |
| mobility | `Walk_L_Loop` | 1.20 | loop | Walk left | all (WsgLocomotor) |
| mobility | `Walk_L_To_Stand_Relaxed` | 3.17 | once | Walk left to standing | all (WsgLocomotor) |
| mobility | `Walk_L_To_Stand_Relaxed_LU` | 1.93 | once | Walk left to standing left foot up | all (WsgLocomotor) |
| mobility | `Walk_L_To_Stand_Relaxed_RU` | 2.47 | once | Walk left to standing right foot up | all (WsgLocomotor) |
| mobility | `Walk_R_180` | 3.03 | once | Walk right 180 | all (WsgLocomotor) |
| mobility | `Walk_R_90` | 2.53 | once | Walk right 90 | all (WsgLocomotor) |
| mobility | `Walk_R_BkPd_Loop` | 1.20 | loop | Walk right backpedal | all (WsgLocomotor) |
| mobility | `Walk_R_CIR_Loop` | 1.20 | loop | Walk right circling | all (WsgLocomotor) |
| mobility | `Walk_R_Loop` | 1.20 | loop | Walk right | all (WsgLocomotor) |
| mobility | `Walk_R_To_Stand_Relaxed` | 2.97 | once | Walk right to standing | all (WsgLocomotor) |
| mobility | `Walk_R_To_Stand_Relaxed_LU` | 2.33 | once | Walk right to standing left foot up | all (WsgLocomotor) |
| mobility | `Walk_R_To_Stand_Relaxed_RU` | 1.80 | once | Walk right to standing right foot up | all (WsgLocomotor) |

165 clips.
