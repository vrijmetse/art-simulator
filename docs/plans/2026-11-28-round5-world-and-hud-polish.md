# Round 5 Full-Screen 3D World, Stage, Character & HUD Polish Plan

**Goal:** Resolve every visual, layout, grounding, lighting, material, and copy defect uncovered by the Round 5 full-screen adversarial audit across all 15 3D characters, 10 stages (homes, streets, shifts), weather/umbrella FX, HUD scrims, dock icons, spotlight tutorial, and dialogue bar.

---

## Root-Cause Summary (Verified from Source + Live 780x437 Screenshots)

1. **Pitch-Black Sky / Horizon Void (`main_game.tscn` + `godot/src/core/atmosphere.gd`)**
   - `Camera3D` looks downward (~30° pitch), so all background rays past the rooms/streets fall below `y=0` and sample `ProceduralSkyMaterial.ground_horizon_color` / `ground_bottom_color` (`Color(0.24, 0.22, 0.20)` → `Color(0.11, 0.10, 0.12)`).
   - Fix: In `Atmosphere.apply_lighting(...)` (pass `world_mode := "home"` optional arg, default `"home"` for backward compatibility), set vibrant tropical horizon & ground colors when `"street"` (`ground_horizon_color` soft sky/haze, `ground_bottom_color` tropical greenery/earth, updated per `pagi`/`siang`/`sore`/`malam`/`hujan`), and warm bright outdoor garden sky/lawn tones (`Color(0.66, 0.80, 0.92)` / `Color(0.38, 0.56, 0.34)`) behind yard fences in `"home"` / `"shift"`. Keep dark indoor backdrop only at `malam`.

2. **Kenney Colormap Erasure & Sidewalk Elevation (`godot/blender/build_*.py`)**
   - `rebuild_kenney_pbr_material(mat)` clears the material node tree (`nt.nodes.clear()`), destroying `ImageTexture` (`colormap.png`) on Kenney Car Kit (`sedan.glb`) and Nature Kit (`planter.glb`, `bush-common-flowers.glb`, `common-tree-1.glb`), turning cars, planters, bushes, and window-exterior trees solid white/grey.
   - Fix: In `rebuild_kenney_pbr_material(mat)` across `build_elite_assets.py`, `build_kamar_art.py`, `build_kampung_interior.py`, `build_majikan_interior.py`, `build_kos_room.py`, `build_kos_neighbor_room.py`, check if any `ShaderNodeTexImage` exists on the material BEFORE clearing; if present, preserve its `Image` in a clean `ShaderNodeTexImage -> BSDF Base Color` (roughness `0.62`, no `KHR_materials_unlit` / zero emission).
   - `build_elite_assets.py`: Lower `cluster_elite_street.glb` `Road` (`z=-0.16, h=0.16` -> top `-0.08`) and `Sidewalk` (`z=-0.08, h=0.16` -> top `0.00`), matching `y=0.0` NPC/player ground plane so NPC shoes rest cleanly on top of the sidewalk rather than sinking 10cm.
   - `build_kamar_art.py`:
     - `build_kamar_art_small`: Remove duplicate `SmallPlant` (`pottedPlant.glb` colliding inside `add_layered_broadleaf_plant` at `(-1.25, -1.12, 0.0)`).
     - `build_kamar_art_large`: Pass `center_xy=True` to all `import_kenney_glb(...)` calls (`LargeBed`, `LargeDesk`, `LargeChair`, `LargeLamp`, `LargeBooks`, `LargePlant`, `LargeTrash`); anchor `LargeLamp`, `LargeBooks`, and `LaptopBase` cleanly on `LargeDesk` (`max_z`), tuck `LargeTrash` neatly beside desk (`(1.48, 1.72, 0.0)`), shift `LargeFan` inside floor slab (`(2.08, 1.25)`), push `GardenTree1`/`GardenTree2` back (`y=4.2..4.5`) away from `WinGlass` to eliminate jagged window clipping, and assign crisp sage/cream/wood PBR colors to `LargeBed` / `LargeChair`.
   - `build_kampung_interior.py`: Add `center_xy=True` to `import_kenney_glb` props (`Sofa`, `DiningTable`, `DiningChair1/2`, `KitchenSink`, `KitchenStove`, `TrashCan`), remove duplicate `LivingPlant` colliding near sofa, tuck `TrashCan` beside sink (`(2.15, 1.45, 0.0)`), and push `GardenTree1`/`GardenBush1` to `y >= 3.45` cleanly outside `WinGlass`.
   - `build_kos_room.py`: Anchor `TvCornerShelf` with a clean wooden wall-bracket support post down to `RiceCookerStand` (`z=0.42..0.90`) so the TV shelf is physically supported, not floating.

3. **3D Character Material Glare (`godot/src/core/scene_visuals.gd`)**
   - `apply_unified_material_pass()` skips specular/roughness clamping on non-metallic meshes, causing plastic white specular glare on black hair, peci/caps, shoes, and aprons.
   - Fix: In `apply_unified_material_pass(root, is_stage, preserve_textures, ...)`, when `not is_stage` (characters), clamp `roughness = maxf(mat.roughness, 0.72)` and `metallic_specular = minf(mat.metallic_specular, 0.22)` (except eye/iris/buckle/glass materials), killing wet plastic hair and shoe glare.

4. **HUD Scrims, Dock Icon Swap, Spotlight Alignment, Dialogue Bar & Call/Toast Collision (`godot/src/scenes/main_game.gd`, `godot/src/core/wishlist_story.gd`)**
   - **Top-Left HUD & Bottom-Right Dock Scrims:** Wrap `_tl_card` and `_dock_bar` in crisp semi-transparent dark glass `PanelContainer`s (`Color(0.06, 0.08, 0.12, 0.76)`, `1px` subtle gold edge, radius `12`, pad `8/6`) so text & bars remain `>7:1` readable over bright cream tile floors and sidewalks. Brighten `Tasks` hint label (`Cara: ...`) to `Color(0.88, 0.90, 0.95)`.
   - **Street Dock Icon #1:** Dynamically set `_btn_action_icon.texture` to `Portraits.get_ui_icon("app_chat")` in `"street"` mode, `icon_door` in `"home"` mode, and `icon_broom` in `"shift"` mode inside `_refresh_hud()`.
   - **Call Banner vs Toast Collision:** Suppress non-urgent `_toast_panel` display inside `_show_toast()` when `_call_banner != null and _call_banner.visible` (and widen `_toast_lbl.custom_minimum_size.x = 280` so `"Shift Keluarga Wijaya..."` never wraps an orphan word onto line 3).
   - **Dialogue Bar (`_build_dialogue_bar`):** Move `_dlg_phone_badge` OUT of the portrait overlay into an `HBoxContainer` header row beside `_dlg_speaker` (zero overlap on Ibu's hijab), and brighten `_dlg_next` (`Color(0.99, 0.88, 0.36)`, `font_size = 12`).
   - **Dialogue Currency Formatting (`wishlist_story.gd`):** Replace `"Rp150.000"` with `"Rp 150.000"` in `get_intro_cutscene_beats` (both `"id"` and `"en"`).
   - **Spotlight Tutorial (`_refresh_spotlight` + `_position_spotlight_widgets`):** Defer `_position_spotlight_widgets()` via `call_deferred` (and re-run on `size_changed`) after layout settles so `_spotlight_ring` and `_spotlight_hand` align dead-center on the active target (`_btn_shift` / `_tasks_card` / `_btn_phone` / `_btn_kos`), and hide floor `Label3D` badges while `_spotlight_wrap.visible` so `"Mulai Shift"` never obscures `"Sholat / Doa"`.

5. **Street NPC Spacing & Rain/Umbrella (`godot/src/core/npc_roster.gd`, `godot/src/core/street_patrols.gd`, `godot/src/scenes/main_game.gd`)**
   - `npc_roster.gd`: Separate `mbak_dewi` (`Vector3(-2.0, 0.0, 1.45)`) and `anak_sekolah` (`Vector3(-4.2, 0.0, 1.75)`) in `kampung` so street nameplates never overlap.
   - `street_patrols.gd`: Offset player/NPC umbrella attachment (`Vector3(0.26, 1.66, 0.12)`, tilted `(-6, 0, -6)`) so the shaft stays cleanly in her right hand instead of clipping through her chest/apron.
   - `main_game.gd`: Widen rain streak particle quad (`Vector2(0.032, 0.44)`, alpha `0.58`) so rain reads crisply on mobile `780x437`.

---

## TDD & Verification Plan

1. **Stage 2 Adversarial Plan Review:** Dispatch `delegate_task` to challenge all edits (API compatibility on `Atmosphere.apply_lighting`, Blender `export_room_glb` / `web-dist/index.pck <= 95 MB` budget, `run_tests.gd` & headless smoke coverage, edge cases).
2. **Stage 3 RED TDD (`godot/tests/run_tests.gd` Section 42):**
   - Assert `"Rp150.000"` is absent from `wishlist_story.gd` (`"Rp 150.000"` used).
   - Assert `Atmosphere.apply_lighting(..., "street")` sets outdoor non-black `ground_bottom_color` (`> 0.18` green/blue luminance during `"siang"`).
   - Assert `npc_roster.gd` `kampung` street NPCs have `>= 1.8m` pairwise XZ separation.
   - Assert `street_patrols.gd` umbrella handle x-offset keeps pole clear of torso center (`absf(pos.x) >= 0.22`).
   - Assert `main_game.gd` uses `app_chat` icon for street `Ngobrol` dock button, places `_dlg_phone_badge` inside speaker header (not portrait overlay), suppresses toast overlap during active call, uses `call_deferred("_position_spotlight_widgets")`, and hides `Label3D` while spotlight tutorial is visible.
   - Assert `scene_visuals.gd` clamps character hair/hat/shoe roughness (`>= 0.72`) and specular (`<= 0.22`).
   - Run `run_tests.gd` RED first to confirm the new assertions fail as expected.
3. **Stage 3 GREEN:**
   - Update Blender builders (`build_elite_assets.py`, `build_kamar_art.py`, `build_kampung_interior.py`, `build_kos_room.py`, `build_majikan_interior.py`, `build_kos_neighbor_room.py`) and re-export updated `.glb` + lightmaps.
   - Update GDScript (`atmosphere.gd`, `scene_visuals.gd`, `wishlist_story.gd`, `npc_roster.gd`, `street_patrols.gd`, `main_game.gd`).
   - Run full `run_tests.gd`, `--smoke-test`, and `npm test` (Vitest).
4. **Re-Capture & Blind Visual Re-Audit:**
   - Re-run `capture_all_world.gd` (`780x437`) and `capture_chars_3d.gd` (`1280x720`), inspect key screenshots directly via `vision_analyze`, AND dispatch blind adversarial reviewer subagents on all re-captured screenshots (`world_chars_all15.png` + all world/HUD shots).
5. **Stage 4 Code Review & Stage 5 Deploy:**
   - Dispatch `delegate_task` Stage 4 code diff review (`0 Critical, 0 Important`).
   - Export Web (`index.pck <= 95 MB`) + Android APK, verify live `https://game.shr.co.id/?v=<sha>` WebGL2 + console clean + screenshot, commit & push to `main`, deploy Coolify, and verify live!
