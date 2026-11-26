# Warung-Life HD Visuals, Warm Lighting Pools, 3D Sajadah & HUD Polish Plan

## Goal
Adapt every visual, lighting, prop, and HUD craft lesson observed in the two *Warung Life Simulator* reference screenshots (`img_a6c1fb98f995.jpg` bedroom & `img_f75d1a81932d.jpg` street) into `ART Simulator` across WebGL2 (`gl_compatibility`), Android APK, and iOS.

## Exact Lessons & Improvements

### 1. HD Crispness & Shadow Resolution (`godot/project.godot` + `godot/scenes/main_game.tscn`)
- Enable `display/window/dpi/allow_hidpi=true` in `godot/project.godot` so Retina/mobile displays render at native pixel density instead of 1x blurry upscaling.
- Set `rendering/lights_and_shadows/directional_shadow/size=4096` and tighten `SunLight` `shadow_blur = 0.85` + `shadow_bias = 0.02` for razor-sharp furniture/window shadows without peter-panning.
- Set `default_clear_color=Color(0.08, 0.11, 0.18, 1)` (deep slate-navy frame) instead of pale mint-grey so `kos_room` sits cleanly like a glowing diorama!

### 2. Warm `OmniLight3D` Pools & Rich Room Framing (`godot/src/core/atmosphere.gd` + `godot/src/scenes/main_game.gd`)
- Add a managed `_stage_lights: Array` helper in `ArtAtmosphere` / `main_game.gd` (capped at `<= 3` mobile-safe `OmniLight3D` nodes, `shadow_enabled = false` for `gl_compatibility` 60fps!):
  - **In `home` mode:**
    1. Warm bedside lamp `OmniLight3D` at `Vector3(-0.60, 0.92, -1.90)` (`Color(1.0, 0.68, 0.30)`, `omni_range = 4.6`, energy `0.75` daytime / `1.45` `sore`/`malam`).
    2. Warm window sunbeam/glow `OmniLight3D` at `Vector3(0.35, 1.55, -1.85)` (`Color(1.0, 0.80, 0.48)`, `omni_range = 4.2`).
  - **In `street` mode:**
    - 3 warm golden streetlamp/porch `OmniLight3D` pools along the sidewalk (`Vector3(-3.45, 1.75, -0.45)`, `Vector3(0.0, 1.75, -0.45)`, `Vector3(3.45, 1.75, -0.45)`, `Color(1.0, 0.72, 0.32)`, `omni_range = 4.8`, subtle `0.45` day -> `1.35` `sore`/`malam`).

### 3. `kos_room.glb` & Street *Kanstin* Props (`godot/blender/build_kos_room.py` + `build_kampung_street.py`)
- **`build_kos_room.py`:**
  - Deepen rich teak wood (`(0.35, 0.17, 0.08)`, `roughness = 0.44` for warm specular sheen), warm terracotta blanket `(0.76, 0.28, 0.14)`, darker muted garden surround (`YardGrass` `(0.14, 0.26, 0.12)`, `YardPatio` `(0.34, 0.32, 0.30)` so the exterior frames the bright cozy interior instead of blinding white/neon!).
  - Add **3D Sajadah (`PrayerMat`)** at Blender `(0.95, -0.95, 0.015)` -> Godot `Vector3(0.95, 0.0, 0.95)` (open right-front floor, clear of desk chair!): emerald-green woven base + gold mihrab arch border!
  - Add **3D Red Floral Thermos (`TermosMerah`)** on desk corner + **Wall Calendar (`KalenderDinding`)** on back wall next to the window!
- **`build_kampung_street.py`:**
  - Add alternating black-and-white **Kanstin** curb segments along the sidewalk edge (`y = -1.78`, `x = -8.5..8.5`) for crisp Warung-Life street contrast!

### 4. Bedroom Portal Placement, Sleep-on-Bed Tween & Smartphone `HP` HUD (`godot/src/scenes/main_game.gd`)
- Move `pray_mat` portal to `Vector3(0.95, 0.0, 0.95)` (centered on the new 3D Sajadah!) and `sleep_bed` portal to `Vector3(-0.95, 0.0, -0.85)` (beside the bed, clear of nightstand!).
- **Sleep-on-Bed Animation (`_is_sleeping` lock):** When triggering `sleep_bed`, smoothly move & lay `player` onto the bed (`Vector3(-1.55, 0.56, -1.20)`, rotated horizontal for `0.9s` with floating `"Zzz..."` popup, blocking duplicate portal triggers during the `0.9s` rest!) before standing back up next to the bed (`Vector3(-0.95, 0.0, -0.85)`) with `100% Energi`.
- **Smartphone `HP` Icon (`_build_hud`) & Collapsible Checklist:**
  - Replace the plain `HP` button with a sleek rounded dark-bezel **Smartphone icon** containing a colorful 3×2 mini app icon grid + crisp `"HP"` caption underneath (pure Godot `Control`/`StyleBoxFlat`/`ColorRect` — zero external image bloat, resolution-independent!).
  - Add a compact `[-]` / `[+]` collapse button on `_tasks_card` so players can fold the chore list on small mobile screens!

## Verification Plan
- **TDD (`run_tests.gd`):** Verify `ArtAtmosphere.get_room_lights_config(phase)` & `get_street_lights_config(phase)` pure helpers (warm energy ramps up in `sore`/`malam`, `<= 3` lights, valid colors) + `pray_mat` clear coordinates.
- Rebuild `kos_room.glb` & `kampung_street.glb` in Blender (`<= 14,500` verts budget check) -> re-import -> `814+` Godot TDD -> `--smoke-test` -> `48/48` Vitest -> `export_android.sh` + `export_web.sh` -> Stage 4 review -> deploy live & verify BEFORE vs AFTER screenshots (`kos_room` + `street`)!
