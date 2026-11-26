# ART Simulator — Remaining Gaps Closure Plan (Characters, Full-Game GI, Native/CI Polish)

**Date:** 2026-11-26  
**Repo:** `/home/ubuntu/projects/art-simulator` (branch `main`, baseline `40ca3b7`)  
**Goal:** Close every remaining visual, world-lighting, and native-build gap identified after `40ca3b7`:
1. Fix skirt waist-shelf rims on `char_kakak`, `char_pelajar`, `char_rina` and dark Indonesian hair on `char_hendra`.
2. Bake Cycles `UV2` (`TEXCOORD_1`) high-contrast GI lightmaps for all 8 remaining gameplay stages (`kampung_street`, `cluster_elite_street`, `kos_neighbor_room`, `room_kampung_house`, `room_majikan_living`, `room_elite_living`, `kamar_art_small`, `kamar_art_large`) into `godot/assets/lightmaps/` and wire them automatically in `main_game.gd`.
3. Configure `config/icon="res://assets/icon.png"` in `godot/project.godot` (fixing Android APK icon warning), add `[preset.2]` `iOS` to `godot/export_presets.cfg` + `.github/workflows/ios-build.yml` for `macos-latest` CI exports, and verify *Jl. Melati* (`kampung_street.glb`) + updated cast live on `https://game.shr.co.id/`.

---

## Architecture & File Ownership

### 1. Shared Cycles UV2 Lightmap Baker (`godot/blender/tex_utils.py`)
Add `bake_scene_lightmap_uv2(...)`:
- Params: `out_png_path`, `size=1024`, `samples=16`, `exclude_substrings=()`, `lift_min=0.34`, `sun_energy=4.2`, `sun_rot_deg=(48, 0, 28)`, `ambient_strength=0.35`, `keep_existing_lights=True`.
- Behavior:
  - Filters `target_objs`: `MESH` objects not matching `exclude_substrings` (so trees, bushes, cars, glass, and people still cast shadows in Cycles without consuming `1024×1024` texels or getting UV2).
  - Unlinks shared mesh datablocks (`if o.data.users > 1: o.data = o.data.copy()`) so instanced walls/chairs never overwrite each other's lightmap UVs.
  - Creates/activates `LightmapUV` (`o.data.uv_layers`) on all `target_objs`, enters multi-object `EDIT` mode, runs `uv.smart_project(angle_limit=math.radians(66), island_margin=0.025)`.
  - Temporarily swaps `target_objs` materials to a clean white diffuse shader (`_BakeLightmapMat`), bakes Cycles `DIFFUSE` (`use_pass_direct=True`, `use_pass_indirect=True`, `use_pass_color=False`, `use_denoising=False`), lifts pixel range in NumPy to `[lift_min, 1.0]`, saves PNG to `out_png_path` (`godot/assets/lightmaps/<stage>_lightmap.png`), restores original materials, deletes temporary bake material/image/sun so `.glb` stays clean and small.
  - Note: Keep `export_apply=False` on `export_scene.gltf` only when `target_objs` have no unapplied scale, OR ensure `TEXCOORD_1` exports properly on all `target_objs` (verified by `run_tests.gd` `ARRAY_FORMAT_TEX_UV2`).

### 2. Wire All 8 Remaining Stage Builders to `bake_scene_lightmap_uv2`
- **Outdoor stages (`lift_min=0.38`, `exclude_substrings=("tree", "bush", "flower", "planter", "sedan", "van", "car", "pug", "casual", "glass", "wheel", "trunk", "leaf", "leaves")`):**
  - `godot/blender/build_kampung_street.py` -> `godot/assets/lightmaps/kampung_street_lightmap.png`
  - `godot/blender/build_elite_assets.py` (`build_elite_street`) -> `godot/assets/lightmaps/cluster_elite_street_lightmap.png`
- **Indoor stages (`lift_min=0.34`, `exclude_substrings=("glass", "window", "curtain_rod")`):**
  - `godot/blender/build_kos_neighbor_room.py` -> `godot/assets/lightmaps/kos_neighbor_room_lightmap.png`
  - `godot/blender/build_kampung_interior.py` -> `godot/assets/lightmaps/room_kampung_house_lightmap.png`
  - `godot/blender/build_majikan_interior.py` -> `godot/assets/lightmaps/room_majikan_living_lightmap.png`
  - `godot/blender/build_elite_assets.py` (`build_elite_living`) -> `godot/assets/lightmaps/room_elite_living_lightmap.png`
  - `godot/blender/build_kamar_art.py` (`build_kamar_art_small` & `build_kamar_art_large`) -> `godot/assets/lightmaps/kamar_art_small_lightmap.png` & `kamar_art_large_lightmap.png`
- Note: Keep existing `bake_cycles_ao` **after** `bake_scene_lightmap_uv2` (or remove redundant `bake_cycles_ao` on UV2-baked rooms to save build time and avoid double-darkening — wait: check `SceneVisuals.apply_baked_ao`! `apply_baked_ao` sets `vertex_color_use_as_albedo = true` on `COLOR_0` meshes! So if a mesh has BOTH `COLOR_0` AO `[0.48..1.0]` AND `UV2` lightmap `[0.34..1.0]`, multiplying both darkens corners twice! Check whether removing `bake_cycles_ao` on UV2-lightmapped meshes OR raising `ao_min=0.82` avoids double-darkening; in `kos_room` & `kampung_gang`, `kos_room` has NO `bake_cycles_ao`, whereas `kampung_gang` has `bake_cycles_ao()` too. Keeping `bake_cycles_ao` only on non-UV2 foliage/props or raising `ao_min=0.85` prevents double-darkening while preserving existing `COLOR_0` tests!).

### 3. Character Polish (`godot/blender/build_characters.py`)
- In `_build_mh_skirt`: taper the waist ring (`pelvis_z * 1.18`) smoothly inward (`0.156 * s_u, 0.128 * s_u` for standard skirts; `0.172 * s_u, 0.144 * s_u` for `long_skirt` over `mh_3488` blazer) while keeping hip (`0.240 * s_u × 0.210 * s_u`) and hem (`0.258 * s_u × 0.226 * s_u`) wide so `char_kakak`, `char_pelajar`, `char_rina`, `char_art`, and `char_ibu` all have crisp tailored waists with zero shelf overhang and zero leg poke-through.
- On `char_hendra` (`mh_3000`): strip/replace blonde hair or darken `"hair"` material base color/image to natural Indonesian dark brown-black `(0.05, 0.04, 0.04)`.

### 4. Godot Runtime Lightmap Wiring (`godot/src/scenes/main_game.gd`)
- Replace the hardcoded `if "kos_room"` / `elif "kampung_gang"` branch in `_load_stage_glb(glb_path)` with a clean `stage_basename -> res://assets/lightmaps/<stage>_lightmap.png` lookup so all 10 stages (`kos_room`, `kampung_gang`, `kampung_street`, `cluster_elite_street`, `kos_neighbor_room`, `room_kampung_house`, `room_majikan_living`, `room_elite_living`, `kamar_art_small`, `kamar_art_large`) automatically load and apply their baked lightmaps via `SceneVisuals.apply_lightmap(inst, lm_tex)`.

### 5. Native Store & iOS CI (`godot/project.godot`, `godot/export_presets.cfg`, `.github/workflows/ios-build.yml`, `godot/assets/icon.png`)
- Copy/generate crisp `512×512` `godot/assets/icon.png` (from `web-dist/index.512x512.png` or procedural emblem) and set `config/icon="res://assets/icon.png"` in `godot/project.godot` (with `icon.png` imported via `--import --quit`, outside `assets/textures/*` so it is packed cleanly into Android APK & Web PWA).
- Add `[preset.2]` `name="iOS"` (`platform="iOS"`, `bundle_identifier="id.co.shr.artsimulator"`, matching `exclude_filter`) to `godot/export_presets.cfg`.
- Add `.github/workflows/ios-build.yml` (`macos-latest`, `workflow_dispatch`, Godot `4.7.2` + export templates, runs `run_tests.gd` + `--export-release "iOS"` / Xcode archive step, uploads artifact).

### 6. TDD Verification (`godot/tests/run_tests.gd`)
Add Section 31 assertions (written RED first):
- Every one of the 10 stage `.glb`s has its matching `res://assets/lightmaps/<name>_lightmap.png` in a non-excluded path (`export_presets.cfg` does not exclude `assets/lightmaps/`).
- Every one of the 10 stage `.glb`s exports `ARRAY_FORMAT_TEX_UV2` on `>= 5` architectural surfaces.
- Every lightmap `.png` has non-flat GI contrast (`max_l - min_l >= 0.35`, `min_l >= 0.28`).
- `ProjectSettings.get_setting("application/config/icon")` is `"res://assets/icon.png"` and `ResourceLoader.exists("res://assets/icon.png")` is `true`.
- `export_presets.cfg` contains `[preset.2]` `name="iOS"`.
- Character skirt waist ring check / `mh_cast_rest.png` + `mh_cast_front.png` Cycles inspection.
- Live WebGL2 browser verification of Kos Room, Gang Kampung, and *Jl. Melati* (`kampung_street.glb` via `SaveStore` Tier 2/3 or in-game progression/teleport check).
