#!/bin/sh
# The foundation's fast checks (run before every push):  foundation/tools/run_tests.sh
# Without the licensed clip library (addons/wsg_foundation/data, from the private assets repo) the tests that need it
# say so and are skipped; the rig tests use the hurler in tests/character, which is the owner's own model.
set -e
cd "$(dirname "$0")/.."
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . -s tests/compile_check.gd
godot --headless --path . -s tests/rig_test.gd
godot --headless --path . -s tests/foot_flat_test.gd
godot --headless --path . -s tests/loading_test.gd
godot --headless --path . -s tests/solid_props_test.gd
godot --headless --fixed-fps 30 --path . -s tests/sim_test.gd
godot --headless --fixed-fps 30 --path . -s tests/sim_pause_test.gd
godot --headless --path . --fixed-fps 30 -s res://tools/owner_notes.gd
sh tools/owner_notes_guard.sh "$PWD/tests/owner_notes"
godot --headless --path . -s res://tools/prop_audit.gd -- res://tests/prop_runs.gd "${TMPDIR:-/tmp}/wsg_prop_audit" 1 30
sh tests/world_check_test.sh
python3 tests/release_gate_test.py
godot --headless --path . -s tests/asset_pack_test.gd
godot --headless --path . -s tests/joystick_test.gd
godot --headless --path . -s tests/pose_check_test.gd
godot --headless --path . -s tests/ui_test.gd
godot --headless --path . -s tests/asset_lint_test.gd
godot --headless --fixed-fps 30 --path . -s res://tools/asset_lint.gd -- --out "${TMPDIR:-/tmp}/wsg_asset_lint" --game res://tests/world_demo/world.gd
godot --headless --path . --fixed-fps 30 -s tests/loco_test.gd
godot --headless --path . -s tests/crowd_test.gd
godot --headless --path . -s tests/crowd_venue_test.gd
godot --headless --path . --fixed-fps 30 -s tests/officials_test.gd
godot --headless --path . -s tests/profile_test.gd
godot --headless --path . -s tests/light_bake_test.gd
godot --headless --path . --fixed-fps 30 -s tests/replay_test.gd
godot --headless --path . --fixed-fps 30 -s tests/broadcast_test.gd
godot --headless --path . --fixed-fps 30 -s tests/audio_test.gd
godot --headless --path . --fixed-fps 30 -s tests/spectator_test.gd
godot --headless --path . --fixed-fps 30 -s tests/toon_driver_test.gd
