#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/home/ubuntu/.local/bin/godot4}"
OUT_APK="$ROOT/build/art-simulator.apk"

mkdir -p "$ROOT/build"

# Ensure tests pass before exporting APK
"$GODOT_BIN" --headless --path "$ROOT/godot" -s res://tests/run_tests.gd

"$GODOT_BIN" --headless --path "$ROOT/godot" --export-debug "Android" "$OUT_APK"
if command -v apksigner >/dev/null 2>&1; then
  apksigner verify "$OUT_APK"
fi
ls -lh "$OUT_APK"
