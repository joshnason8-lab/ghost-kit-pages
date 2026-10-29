#!/bin/sh
# The foundation's fast checks (run before every push):  foundation/tools/run_tests.sh
# Without the licensed clip library (addons/wsg_foundation/data, from the private assets repo) the tests that need it
# say so and are skipped; the rig tests use the hurler in tests/character, which is the owner's own model.
set -e
cd "$(dirname "$0")/.."
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . -s tests/compile_check.gd
godot --headless --path . -s tests/rig_test.gd
godot --headless --path . --fixed-fps 30 -s tests/loco_test.gd
godot --headless --path . -s tests/crowd_test.gd
godot --headless --path . --fixed-fps 30 -s tests/officials_test.gd
