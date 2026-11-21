#!/usr/bin/env bash
# Runs the headless simulation tests. Usage: GODOT=/path/to/godot tests/run_all.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true   # builds the class-name cache
"$GODOT" --headless --path . -s tests/test_sim.gd
