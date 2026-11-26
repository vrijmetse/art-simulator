#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-/home/ubuntu/.local/bin/godot4}"
mkdir -p "$ROOT_DIR/web-dist"
"$GODOT" --headless --path "$ROOT_DIR/godot" --import
"$GODOT" --headless --path "$ROOT_DIR/godot" -s res://tests/run_tests.gd
"$GODOT" --headless --path "$ROOT_DIR/godot" --export-release "Web" "../web-dist/index.html"

# Patch Godot's sticky cache-first PWA Service Worker to auto-activate & use network-first when online
python3 - << 'PY'
import os, pathlib

sw_path = pathlib.Path(os.environ.get("ROOT_DIR", ".")) / "web-dist" / "index.service.worker.js"
if not sw_path.exists():
    sw_path = pathlib.Path("web-dist/index.service.worker.js")
sw = sw_path.read_text()

# 1. Immediate skipWaiting on install
sw = sw.replace(
    "event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));",
    "self.skipWaiting();\n\tevent.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(CACHED_FILES)));",
)
# 2. Immediate clients.claim on activate
sw = sw.replace(
    "return ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();",
    "await self.clients.claim();\n\t\treturn ('navigationPreload' in self.registration) ? self.registration.navigationPreload.enable() : Promise.resolve();",
).replace(").then(function () {", ").then(async function () {")

# 3. Network-first with offline cache fallback for cacheable assets
old_block = """\t\t\t\tlet cached = await cache.match(event.request);
\t\t\t\tif (cached != null) {
\t\t\t\t\tif (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
\t\t\t\t\t\tcached = ensureCrossOriginIsolationHeaders(cached);
\t\t\t\t\t}
\t\t\t\t\treturn cached;
\t\t\t\t}
\t\t\t\t// Try network if don't have it in cache.
\t\t\t\tconst response = await fetchAndCache(event, cache, isCacheable);
\t\t\t\treturn response;"""

new_block = """\t\t\t\ttry {
\t\t\t\t\tconst response = await fetchAndCache(event, cache, isCacheable);
\t\t\t\t\tif (response && response.ok) {
\t\t\t\t\t\treturn response;
\t\t\t\t\t}
\t\t\t\t} catch (_err) {
\t\t\t\t\t// Offline fallback below
\t\t\t\t}
\t\t\t\tlet cached = await cache.match(event.request);
\t\t\t\tif (cached != null) {
\t\t\t\t\tif (ENSURE_CROSSORIGIN_ISOLATION_HEADERS) {
\t\t\t\t\t\tcached = ensureCrossOriginIsolationHeaders(cached);
\t\t\t\t\t}
\t\t\t\t\treturn cached;
\t\t\t\t}
\t\t\t\treturn caches.match(OFFLINE_URL);"""

assert old_block in sw, "Expected cache-first block in index.service.worker.js"
sw = sw.replace(old_block, new_block, 1)
sw_path.write_text(sw)
print("Patched network-first + skipWaiting into", sw_path)
PY

ls -lh "$ROOT_DIR/web-dist/"
