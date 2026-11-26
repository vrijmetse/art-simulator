# Vibrant Mobile Color Grading & Lighting Plan

## Goal
Eliminate the washed-out / pastel look in `ART Simulator` on WebGL2 (`gl_compatibility`), Android APK, and iOS by shifting from muted ACES + high milky ambient wash to crisp, sunny, high-chroma cozy mobile lighting (matching *Warung Life Simulator*'s colorful stylized look) without breaking `malam` / `hujan` mood or blowing out white surfaces.

## Root Causes Identified
1. **`tonemap_mode = 2` (ACES) + flat adjustment (`saturation = 1.02`, `contrast = 1.04`)** in `godot/scenes/main_game.tscn`: ACES compresses bright saturated hues into desaturated pastels in Godot 4 `gl_compatibility`.
2. **High milky ambient & upward bounce wash** in `godot/src/core/atmosphere.gd`: `ambient_light_energy` (`0.45–0.50`) + `GroundBounceLight` (`0.35–0.40`) fills shadows with light bluish-grey (`Color(0.92, 0.94, 0.98)`), flattening depth and contrast.
3. **Neutral/cool sky colors** in `ProceduralSkyMaterial` + `atmosphere.gd` under `cerah`: lacks tropical Indonesian azure-teal top sky and warm golden horizon contrast.

## Proposed Changes
1. **`godot/scenes/main_game.tscn` (`Environment` + `SunLight` + `GroundBounceLight`):**
   - Switch `tonemap_mode = 1` (**Reinhard** — preserves vibrant midtone chroma without ACES pastel desaturation in `gl_compatibility`) or `tonemap_mode = 3` (**Filmic** with tuned `tonemap_white = 1.15`, `tonemap_exposure = 1.05`). Let's use **Filmic (`tonemap_mode = 3`)** or **Reinhard (`tonemap_mode = 1`)**: Filmic (`3`) with `tonemap_exposure = 1.06`, `tonemap_white = 1.1` gives crisp highlight rolloff WITHOUT ACES greying out reds/yellows/greens!
   - Set `adjustment_enabled = true`, `adjustment_brightness = 1.02`, `adjustment_contrast = 1.11`, `adjustment_saturation = 1.24` (rich, warm, colorful without clipping skin tones or UI — UI lives on `CanvasLayer` so `WorldEnvironment` only affects 3D!).
   - Lower base `ambient_light_sky_contribution = 0.18`, `ambient_light_energy = 0.24` so directional shadows have real depth.
   - Keep `GroundBounceLight` warm & subtle (`0.16`) instead of washing out undersides.

2. **`godot/src/core/atmosphere.gd` (`apply_lighting`):**
   - **`pagi`**: Crisp warm morning sun (`Color(1.0, 0.90, 0.72)`, `energy = 1.15`), warm-tinted low ambient (`Color(0.76, 0.80, 0.92)`, `energy = 0.24`), subtle bounce (`0.16`).
   - **`siang`**: Tropical bright midday sun (`Color(1.0, 0.96, 0.86)`, `energy = 1.30`), deeper sky-blue ambient (`Color(0.68, 0.80, 0.96)`, `energy = 0.26`), subtle warm ground bounce (`0.18`).
   - **`sore`**: Rich golden-orange sunset (`Color(1.0, 0.64, 0.34)`, `energy = 1.05`), violet-amber ambient (`Color(0.72, 0.56, 0.68)`, `energy = 0.24`), bounce (`0.16`).
   - **`malam`**: Deep cozy indigo night (`Color(0.44, 0.58, 0.92)`, `energy = 0.42`), low navy ambient (`Color(0.24, 0.30, 0.52)`, `energy = 0.24`) — keeps streetlamps/windows readable without turning pitch black.
   - **`hujan`**: Cool teal-slate overcast (`sun_energy *= 0.68`, `amb_energy *= 0.85`) + keeps `adjustment_saturation` slightly tempered (`1.12` on rainy/night vs `1.24` on sunny day) so rain feels moody yet still colorful!
   - **Sky gradient (`ProceduralSkyMaterial`)**: Rich tropical blue `sky_top_color` (`Color(0.22, 0.56, 0.94)` on `siang`/`pagi`) + warm horizon glow so outdoor street views pop cleanly.

3. **`godot/tests/run_tests.gd` (TDD):**
   - Add Red assertions verifying `ArtAtmosphere.apply_lighting` outputs vibrant non-washed contrast (`siang` `sun_energy >= 1.2` and `env.ambient_light_energy <= 0.30`, `bounce.light_energy <= 0.22`, `malam` darker than `siang`, `env.adjustment_saturation >= 1.18` on `cerah`, and sky top color rich blue).

## Verification
- Run `godot4 --headless --path godot -s res://tests/run_tests.gd` (Red first, then Green), `--smoke-test`, `npx vitest run`.
- Export Web + Android APK (`scripts/export_web.sh`, `scripts/export_android.sh`).
- Deploy live to `https://game.shr.co.id/` and compare BEFORE (`check_kos.png`) vs AFTER (`after_kos.png` + `after_street.png`) via `vision_analyze` + attach screenshots to user.
