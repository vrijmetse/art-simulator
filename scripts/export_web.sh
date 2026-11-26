#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/home/ubuntu/.local/bin/godot4}"
mkdir -p "$ROOT_DIR/web-dist"
"$GODOT" --headless --path "$ROOT_DIR/godot" --import
"$GODOT" --headless --path "$ROOT_DIR/godot" -s res://tests/run_tests.gd
"$GODOT" --headless --path "$ROOT_DIR/godot" --export-release "Web" "../web-dist/index.html"
ls -lh "$ROOT_DIR/web-dist/"
