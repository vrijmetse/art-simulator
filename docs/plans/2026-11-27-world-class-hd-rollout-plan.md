# World-Class HD Rollout Plan (Assets, Environments, Stories, Gameplay) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote the proven D5 Formula 1 (Character/NPC pipeline + casual walk), Formula 2 (4-class Environment/Prop pipeline + offline 1024px polish + UV2 lightmaps), `AgX` + `layer=0` post-sharpen runtime stack, and story/gameplay polish across all 15 characters, all 10 stages, and `main_game` at >= 9.5/10 *Warung Life* HD parity.

**Architecture:** Extract shared Formula 1 and Formula 2 Blender builders cleanly so all 15 `.glb` characters and all 10 `.glb` stages (plus vehicles) build reproducibly with offline `1024px` textures and Cycles `UV2` lightmaps, while `ArtSceneVisuals` + `main_game.tscn` execute a single RID-cached PBR/outline pass under `AgX` Filmic tonemapping and a `layer=0` luma-preserving unsharp post shader strictly beneath the `layer=1` HUD. Story chapters, neighbor reactive greetings, and tactile chore juice are verified end-to-end via headless Godot TDD, `--smoke-test`, `gl_compatibility` visual captures, and live WebGL2 deploy verification.

**Tech Stack:** Godot 4.7.2 (`gl_compatibility`, OpenGL ES 3.0), GDScript, Blender 4.0.2 (`bpy`, `bmesh`, Cycles CPU without OIDN), NumPy, Pillow, Vitest, Coolify + Cloudflare Tunnel.

**Spec:** `docs/plans/2026-11-26-hd-formulas-poc-plan.md` + D5 Adversarial Review (`deleg_456aaf6c`)

## Global Constraints
- Single Godot 4.7.2 `gl_compatibility` codebase (`env.ssao_enabled = false`, `msaa_3d = 1`, `CPUParticles3D`).
- Hero/player `.glb` `<= 14,500` glTF split verts; NPC `.glb` `<= 10,500` glTF split verts; zero `Mannequin_F` / `*Icosphere*` helpers.
- Lightmaps MUST live in `godot/assets/lightmaps/<stage_basename>_lightmap.png` (never `assets/textures/`, which `export_presets.cfg` excludes).
- Blender 4.0.2 lacks `OpenImageDenoiser` (`scene.cycles.use_denoising = False`); Blender Python lacks `PIL`.
- Strict Bahasa Indonesia / English separation (`Gratis` for zero prices, `Rp 0` only in balance headers, never mixed on the same surface).
- Strictly clean-room assets only (`MMWilliams/char-kit`, Kenney CC0, procedural `bmesh`/NumPy).
- All commits deploy from `main`; temporary `poc_*` files must be removed cleanly in Phase 6 before commit.

---

## Phase 1: Runtime HD Visual Core & Shaders (`AgX`, RID-Cached `SceneVisuals`, `layer=0` Sharpen)

### Task 1: Production Shaders & RID-Cached `ArtSceneVisuals` (`Red -> Green -> Refactor`)

**Files:**
- Create: `godot/shaders/hd_detail.gdshader` (promoted from `godot/shaders/poc_c_detail.gdshader`)
- Create: `godot/shaders/hd_sharpen.gdshader` (promoted from `godot/shaders/poc_d3_sharpen.gdshader`)
- Modify: `godot/src/core/scene_visuals.gd:1-110`
- Test: `godot/tests/run_tests.gd` (Section 32: HD Visual Stack & RID Cache Tests)

**Interfaces:**
- Produces: `ArtSceneVisuals.apply_unified_material_pass(node: Node, is_room: bool, force_outline: bool, outline_mat: ShaderMaterial, mat_cache: Dictionary, lightmap_tex: Texture2D = null, apply_ao: bool = false) -> void`
- Produces: `ArtSceneVisuals.ensure_detail_outline_material() -> ShaderMaterial`

- [ ] **Step 1: Write the failing RED tests in `godot/tests/run_tests.gd`**

```gdscript
# 32. Production HD Visual Stack (AgX, RID Cache, Layer-0 Sharpen)
var hd_detail_sh := load("res://shaders/hd_detail.gdshader") as Shader
var hd_sharp_sh := load("res://shaders/hd_sharpen.gdshader") as Shader
_assert_true(hd_detail_sh != null, "hd_detail.gdshader loads")
_assert_true(hd_sharp_sh != null, "hd_sharpen.gdshader loads")

var cache_test := {}
var shared_mat := StandardMaterial3D.new()
shared_mat.resource_name = "FloorTile"
var m1 := MeshInstance3D.new()
var m2 := MeshInstance3D.new()
var bm1 := BoxMesh.new()
bm1.material = shared_mat
m1.name = "FloorSlab"
m1.mesh = bm1
m2.name = "FloorTrim"
m2.mesh = bm1
var test_root := Node3D.new()
test_root.add_child(m1)
test_root.add_child(m2)
var ol_mat := ArtSceneVisuals.ensure_detail_outline_material()
_assert_true(ol_mat != null, "ensure_detail_outline_material returns ShaderMaterial")
ArtSceneVisuals.apply_unified_material_pass(test_root, true, false, ol_mat, cache_test)
var ov1 := m1.get_surface_override_material(0) as StandardMaterial3D
var ov2 := m2.get_surface_override_material(0) as StandardMaterial3D
_assert_true(ov1 != null and ov1 == ov2, "RID material cache reuses override across matching surfaces")
_assert_true(absf(ov1.roughness - 0.20) < 0.01, "floor tile gets crisp 0.20 roughness")
test_root.free()
```

- [ ] **Step 2: Run Godot TDD to verify RED failure**

Run: `/home/ubuntu/.local/bin/godot4 --headless --path godot --script res://tests/run_tests.gd`
Expected: FAIL because `hd_detail.gdshader`, `hd_sharpen.gdshader`, `ensure_detail_outline_material`, and `apply_unified_material_pass` do not exist yet.

- [ ] **Step 3: Promote shaders & implement `ArtSceneVisuals` RID-cached pass**

Copy `godot/shaders/poc_c_detail.gdshader` -> `godot/shaders/hd_detail.gdshader` and `godot/shaders/poc_d3_sharpen.gdshader` -> `godot/shaders/hd_sharpen.gdshader`.
Add `ensure_detail_outline_material()` and `apply_unified_material_pass(...)` to `godot/src/core/scene_visuals.gd` (preserving `apply_baked_ao`, `apply_lightmap`, `apply_character_polish`, `attach_contact_shadow` for backward compatibility, and caching duplicated `StandardMaterial3D` instances in `mat_cache` keyed by `"%d_%s_%s"` RID + outline flag + surface role: floor `roughness=0.20, metallic=0.05, metallic_specular=0.60`, mirror `metallic=0.35, roughness=0.08`, translucent galon/kerupuk `TRANSPARENCY_ALPHA`, teak darkening `0.08`, rim `0.18`, `normal_scale=1.35`, `next_pass=outline_mat` on non-transparent actors and smooth props).

- [ ] **Step 4: Run Godot TDD to verify GREEN**

Run: `/home/ubuntu/.local/bin/godot4 --headless --path godot --script res://tests/run_tests.gd`
Expected: PASS on Section 32.

---

### Task 2: Upgrade `main_game.tscn`, `main_game.gd`, and `atmosphere.gd` to `AgX` + Tight Shadows + `layer=0` Post-Sharpen

**Files:**
- Modify: `godot/scenes/main_game.tscn:15-89`
- Modify: `godot/src/scenes/main_game.gd:440-575`
- Modify: `godot/src/core/atmosphere.gd:23-98`
- Test: `godot/tests/run_tests.gd` (assert `tonemap_mode == 4`, `SharpenPost.layer == 0 < HUD.layer`, `Atmosphere.apply_lighting` preserves `AgX` contrast/saturation ranges)

- [ ] **Step 1: Write failing RED tests in `godot/tests/run_tests.gd`**
Assert `main_game.tscn` loads with `WorldEnvironment.environment.tonemap_mode == Environment.TONE_MAPPER_AGX` (`4`), `glow_bloom == 0.0`, `SunLight.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL` (`0`), `SharpenPost` `CanvasLayer` `layer == 0`, and `HUD.layer >= 1`.

- [ ] **Step 2: Run Godot TDD to verify RED failure**

Run: `/home/ubuntu/.local/bin/godot4 --headless --path godot --script res://tests/run_tests.gd`
Expected: FAIL on `tonemap_mode == 4`, `SHADOW_ORTHOGONAL`, and missing `SharpenPost`.

- [ ] **Step 3: Implement `main_game.tscn`, `main_game.gd`, and `atmosphere.gd` upgrades**
- In `main_game.tscn`: set `tonemap_mode = 4`, `tonemap_exposure = 0.94`, `tonemap_white = 1.6`, `glow_bloom = 0.0`, `glow_hdr_threshold = 1.15`, `adjustment_contrast = 1.12`, `adjustment_saturation = 1.16`; set `SunLight` `directional_shadow_mode = 0`, `directional_shadow_max_distance = 11.0`, `shadow_blur = 0.72`, `shadow_bias = 0.014`; add `[node name="SharpenPost" type="CanvasLayer" parent="."]` with `layer = 0` and full-rect `ColorRect` (`mouse_filter = 2`, `hd_sharpen.gdshader`, `sharpen_amount = 0.34`, `vignette_strength = 0.10`) strictly before `HUD` (`layer = 1`).
- In `main_game.gd`: add `_stage_mat_cache: Dictionary = {}` (cleared at the top of `_load_stage_glb`) and `_actor_mat_cache: Dictionary = {}`, `_outline_mat := ArtSceneVisuals.ensure_detail_outline_material()`, and call `ArtSceneVisuals.apply_unified_material_pass(...)` **once** inside `_load_stage_glb` (`is_room=true, force_outline=false, lightmap_tex=lm_tex, apply_ao=true` — folding AO + UV2 lightmap + PBR + outline into one single override pass so `detail_albedo` and `vertex_color_use_as_albedo` are never overwritten or un-cached), and inside `_sync_player_outfit` / `_spawn_npcs` (`is_room=false, force_outline=true`).
- In `atmosphere.gd`: tune `apply_lighting` defaults for `AgX` (`adj_con = 1.12`, `adj_sat = 1.16` day, `1.18` sore, `1.08` malam/hujan), set `shadow_blur = 0.85` on outdoor street modes vs `0.72` indoors, and update `FAN_NODES` & `RICE_COOKER_NODES` to match Formula 2 names (`FanBase`, `FanPole`, `FanMotorCowl`, `FanGuardRingFront`, `FanGuardRingBack`, `FanSpoke_0..3`, `FanHubBadge`, `FanBtn_0..2`, `FanBlade_0..2`, `RiceCookerStand`, `MagicComBody`, `MagicComLid`, `MagicComVent`, `MagicComHandle`, `MagicComLED`).

- [ ] **Step 4: Run Godot TDD + `--smoke-test` to verify GREEN**

Run:
`/home/ubuntu/.local/bin/godot4 --headless --path godot --script res://tests/run_tests.gd`
`/home/ubuntu/.local/bin/godot4 --headless --path godot res://scenes/main_game.tscn -- --smoke-test`
Expected: PASS, exit 0.

---

## Phase 2: Formula 1 Production Rollout (`build_characters.py` — All 15 Characters)

### Task 3: Promote Formula 1 into `godot/blender/build_characters.py` & Rebuild All 15 Characters

**Files:**
- Modify: `godot/blender/build_characters.py:1-758` (incorporating tested Formula 1 helpers from `godot/blender/build_char_hd_poc.py`)
- Output `.glb`s: All 15 `godot/assets/models/char_*.glb`
- Output showcase: `build/rollout_chars_showcase.png`
- Test: `godot/tests/run_tests.gd` (Section 33: Casual `Walk` Posture, Sculpted Hair, Zero-Clip Garment & Vertex Budget Gates across all 15 `.glb`s)

**Interfaces:**
- Exact 15 filenames preserved (`char_art`, `char_art_hijab`, `char_art_pro`, `char_art_elite`, `char_ibu`, `char_kakak`, `char_budi`, `char_dewi`, `char_pak_rt`, `char_ojek`, `char_kurir`, `char_pelajar`, `char_hendra`, `char_rina`, `char_agus`).
- Every `.glb` preserves `Idle`, `Walk`, `Talk`, `Turn_L`, `Jump`, `Clean`, `Celebrate` NLA clips.

- [ ] **Step 1: Write failing RED tests in `godot/tests/run_tests.gd`**
Add Section 33 checking on loaded `.glb` character instances:
1. Hero models (`char_art`, `char_art_hijab`, `char_art_pro`, `char_art_elite`) split vertex count `<= 14500`; NPC models `<= 11500` (targeting `7,500–10,000`).
2. `char_art`, `char_art_pro`, `char_art_elite`, `char_dewi`, `char_pelajar` contain NO `SphereHairCap` / `Bun` sphere-cap proxy nodes and DO contain sculpted hair geometry (`>= 600` vertices on head hair/hijab/headwear mesh).
3. Evaluating `Walk` animation at `+0.25s` inside `root` (`root.add_child(inst); ap.play("Walk"); ap.seek(0.25, true); ap.advance(0.0)`) on `char_art` `Skeleton3D`: `spine_01`/`neck_01`/`head` combined forward lean `< 8 deg` (no tactical combat hunch!) and `lowerarm_l`/`lowerarm_r` local bend `< 35 deg` (no `-90 deg` T-Rex boxer elbows!).

- [ ] **Step 2: Run Godot TDD to verify RED failure**

Run: `/home/ubuntu/.local/bin/godot4 --headless --path godot --script res://tests/run_tests.gd`
Expected: FAIL on existing `char_art.glb` (`SphereHairCap` present, `Walk` hunch `> 20 deg` & `-90 deg` elbows).

- [ ] **Step 3: Upgrade `godot/blender/build_characters.py` with Formula 1**
1. Port `_fix_mh_materials_and_textures` (`1024px` body / `512px` eyes & shoes, fast `foreach_get`/`foreach_set` warm Indonesian skin tint, `roughness = 0.56`), `_import_sculpted_hair` (compute placement dynamically from target `head` bone world Z and skull vertex bounding box `head_width`/`head_depth`/`body_top_z` across all 8 MakeHuman bases rather than hardcoded `mh_1000` constants; `roughness = 0.42`, `specular = 0.36`), and sculpted layered `hijab_bergo` / beveled `peci` / `ojek_helmet` / `cap`.
2. Port `_build_body_topo_garments`: `20×8` `DasterSkirt`/`LongSkirt` + `Subsurf(1)` (`use_backface_culling = False`, no `Solidify` to stay under `14,500` verts), softly rounded `8×6` `ArtApron` + `4×3` `ApronPocket` with counter-clockwise outward normals, `PRESERVE_CORNERS` Subsurf, `datalayout_transfer()` + `DataTransfer(VGROUP_WEIGHTS, vert_mapping='NEAREST')` lockstep cascade (`body -> skirt -> apron -> pocket`), and native `1024×1024` batik & stitched cream cotton textures.
3. Port `_replace_walk_upper_body_casual(walk_act, idle_act)` (filtering `set_bone_keys` strictly against `arm.pose.bones` so missing bones like `spine_02` are never keyed!) + upright `Idle`/`Talk` offsets (`spine_01 -4°`, `neck_01 -3°`, `head +1°`) across all 15 builds.
4. Set hero `decimate_ratio = 0.42` (`<= 14,500` verts) and NPC `decimate_ratio = 0.34` with an automatic post-build split-vert clamp (`<= 10,500` verts for NPCs).
5. Add `--showcase` option rendering a 2-pose hero close-up + 4-NPC lineup (`build/rollout_chars_showcase.png`).

- [ ] **Step 4: Run `build_characters.py`, `godot4 --import --quit`, TDD, and `vision_analyze`**

Run:
`blender --background --python godot/blender/build_characters.py`
`/home/ubuntu/.local/bin/godot4 --headless --path godot --import --quit`
`/home/ubuntu/.local/bin/godot4 --headless --path godot --script res://tests/run_tests.gd`
Inspect `build/rollout_chars_showcase.png` via `vision_analyze` (full + zoomed crops) verifying upright posture, relaxed walk arms, warm skin, sculpted hair/hijab/peci, and zero garment clipping.

---

## Phase 3: Formula 2 Wave 1 (Core Interior Stages + Vehicles)

### Task 4: Shared Formula 2 Helpers in `tex_utils.py` & `build_vehicles.py` Polish

**Files:**
- Modify: `godot/blender/tex_utils.py:121-652`
- Modify: `godot/blender/build_vehicles.py`
- Output `.glb`s: `veh_angkot.glb`, `veh_motor.glb`

- [ ] **Step 1: Write failing RED test in `godot/tests/run_tests.gd`**
Assert `veh_angkot.glb` and `veh_motor.glb` load cleanly with `<= 8000` verts and textures `>= 512px` / smooth shaded wheel rims.

- [ ] **Step 2: Implement shared Formula 2 primitives in `tex_utils.py` + vehicle polish**
Add `make_solid_mat`, `ensure_uv0`, `add_beveled_box`, `add_cylinder`, `spin_profile`, `generate_rattan_textures(tex_dir, name, size=1024)`, `polish_images_offline(min_size=1024)` (fast `foreach_get`/`foreach_set`, skipping uniform/solid swatches `px[:, :3].std() < 0.01` so solid colors don't bloat VRAM), use `export_image_format='JPEG', export_jpeg_quality=88` on opaque architectural/street room `.glb` exports (keeping `PNG` on characters), and update `bake_scene_lightmap_uv2` with `samples=14`, `max_bounces=2`, `UVMap` auto-check, and `exclude_prefixes` default covering foliage/glass/micro-props (`"WinSky"`, `"WinLouver"`, `"PlantBlade_"`, `"FanSpoke_"`, `"FanHubBadge"`, `"FanBtn_"`, `"ClockTick_"`, `"RugFringe"`, `"MagicComLED"`, `"Kerupuk"`, `"LaundryMound_"`, `"GalonTap_"`, `"GalonAquaBottle"`, `"GalonWaterFill"`, `"GalonLabelBand"`, `"GalonCap"`, `"KerupukGlass"`). Polish `build_vehicles.py` with beveled window frames, spun headlights/wheels, and offline `1024px` livery textures.

- [ ] **Step 3: Run `build_vehicles.py` + `--import` + TDD -> PASS**

---

### Task 5: Upgrade `build_kos_room.py`, `build_kos_neighbor_room.py`, and `build_kamar_art.py` via Formula 2

**Files:**
- Modify: `godot/blender/build_kos_room.py` (promote Formula 2 architecture, spun Galon w/ inner water fill + label + cap, spun Magic Com + LED, open fan w/ chrome spokes + hub + buttons, woven rattan hamper + creased laundry, curved plant blades, draped quilt, rug fringe, 12 clock ticks, smooth plaster wainscot, offline `1024px`, `UV2` lightmap; **preserve** `IndoorAC`, `IndoorACVent`, `FanBlade_0..2`, `RiceCookerStand` node names for `Atmosphere.apply_kos_upgrades_visual`)
- Modify: `godot/blender/build_kos_neighbor_room.py`
- Modify: `godot/blender/build_kamar_art.py` (`kamar_art_small.glb` & `kamar_art_large.glb`)
- Outputs: `kos_room.glb`, `kos_neighbor_room.glb`, `kamar_art_small.glb`, `kamar_art_large.glb` + `godot/assets/lightmaps/*_lightmap.png`

- [ ] **Step 1: Write failing RED test in `godot/tests/run_tests.gd`**
Assert `kos_room.glb` contains `GalonAquaBottle`, `GalonWaterFill`, `FanHubBadge`, `BedQuiltDrape`, `LaundryBasket`, `PlantBlade_0`, AND `IndoorAC`, `RiceCookerStand`, `FanBlade_0` (upgrade compatibility!), and that `kamar_art_small.glb`, `kamar_art_large.glb`, `kos_neighbor_room.glb` all contain `BedQuiltDrape` / sculpted props and valid `UV2` lightmaps.

- [ ] **Step 2: Run Godot TDD -> verify RED fail on missing HD mesh names**

- [ ] **Step 3: Upgrade the 3 interior Blender scripts & run each concurrently**
Run `build_kos_room.py`, `build_kos_neighbor_room.py`, `build_kamar_art.py` as separate concurrent `terminal` calls, then `godot4 --import --quit`.

- [ ] **Step 4: Run TDD + capture `gl_compatibility` views -> inspect via `vision_analyze` (`>= 9.5/10`)**

---

## Phase 4: Formula 2 Wave 2 (Majikan Homes & Outdoor Streets/Hubs)

### Task 6: Upgrade `build_kampung_interior.py`, `build_majikan_interior.py`, and `build_elite_assets.py` (Living + Elite Street)

**Files:**
- Modify: `godot/blender/build_kampung_interior.py` (`room_kampung_house.glb`)
- Modify: `godot/blender/build_majikan_interior.py` (`room_majikan_living.glb`)
- Modify: `godot/blender/build_elite_assets.py` (`room_elite_living.glb`, `cluster_elite_street.glb`)
- Outputs: 4 `.glb`s + 4 `_lightmap.png`s in `godot/assets/lightmaps/`

- [ ] **Step 1: Write failing RED test in `godot/tests/run_tests.gd`**
Assert all 4 GLBs contain Formula 2 spun/beveled hero props (e.g., `GalonWaterFill` / `MagicComBody` / spun lamps/vases, smooth wainscot/molding, `UV2` >= 8 surfaces) and `<= 50k` tris each for smooth WebGL2 mobile frame pacing.

- [ ] **Step 2: Run TDD -> verify RED**

- [ ] **Step 3: Upgrade the 3 builders with Formula 2 & run concurrently**
Apply smooth wainscot + dado rails, beveled shaker cabinetry, `bmesh.ops.spin` kitchenware/thermos/galon/vases/planters, draped sofa throws/cushions, curved potted plant blades, offline `1024px` textures, `include_substrings` / `exclude_prefixes` `UV2` lightmaps. Run concurrently + `godot4 --import --quit`.

- [ ] **Step 4: Run TDD + capture `gl_compatibility` renders -> inspect via `vision_analyze` (`>= 9.5/10`)**

---

### Task 7: Upgrade `build_gang_kampung.py` and `build_kampung_street.py`

**Files:**
- Modify: `godot/blender/build_gang_kampung.py` (`kampung_gang.glb`)
- Modify: `godot/blender/build_kampung_street.py` (`kampung_street.glb`)
- Outputs: 2 `.glb`s + 2 `_lightmap.png`s in `godot/assets/lightmaps/`

- [ ] **Step 1: Write failing RED test in `godot/tests/run_tests.gd`**
Assert `kampung_gang.glb` & `kampung_street.glb` include Formula 2 warung props (`KerupukGlass`, `Kerupuk_` spirals, spun `WarungThermos`/jars, beveled awnings/pagar trim, offline `1024px` asphalt/sidewalk/batu_alam textures, and architectural `UV2` lightmaps).

- [ ] **Step 2: Run TDD -> verify RED**

- [ ] **Step 3: Upgrade both outdoor hub builders & run concurrently + `--import`**

- [ ] **Step 4: Run TDD + capture `gl_compatibility` street views -> inspect via `vision_analyze` (`>= 9.5/10`)**

---

## Phase 5: Story, Dialogue & Gameplay Polish Audit

### Task 8: Story, Neighbor Reactivity & Tactile Chore Juice (`Red -> Green -> Refactor`)

**Files:**
- Modify: `godot/src/core/wishlist_story.gd` (ensure rich, evocative Chapter 1–5 + Epilog pacing, zero mixed ID/EN copy, progress summary helper)
- Modify: `godot/src/core/neighborhood.gd` (add rank/shift-aware reactive neighbor greetings so NPCs comment on Sari's actual career progress & time of day instead of repeating 1 static line forever!)
- Modify: `godot/src/scenes/main_game.gd` (wire reactive neighbor greeting, chore completion micro-camera pulse / floating `+Rp` & `+XP` feedback, and verify zero dead-end modal queues)
- Test: `godot/tests/run_tests.gd` (Section 34: Story/Dialogue Bilingual Purity & Reactive Neighbor Lines)

- [ ] **Step 1: Write failing RED tests in `godot/tests/run_tests.gd`**
1. `ArtNeighborhood.get_reactive_greeting(npc_id, tier_id, phase, locale)` returns distinct tier/phase-aware ID and EN lines for every NPC in `NEIGHBORS` (never returning empty or mixing Indonesian/English tokens).
2. `ArtWishlistStory.STORY_CHAPTERS` + `STORY_EPILOGUE` have strictly pure ID and EN fields with no mixed copy (`Gratis` / no `Rp 0` misusage).

- [ ] **Step 2: Run TDD -> verify RED**

- [ ] **Step 3: Implement minimal story, neighbor dialogue & chore juice polish**

- [ ] **Step 4: Run full `run_tests.gd` + `--smoke-test` -> verify GREEN**

---

## Phase 6: POC Cleanup, Full Verification, Adversarial Review & Live Deploy

### Task 9: Clean Up `poc_*` Artifacts, Pre-Commit Adversarial Review, Export & Live Deploy

**Files:**
- Delete (isolated untracked POC artifacts only, via targeted `git clean` or explicit file list — never `rm -rf` blindly):
  - `godot/scenes/poc_exp_*.tscn`, `godot/src/scenes/poc_exp_*.gd*`
  - `godot/shaders/poc_*.gdshader*`
  - `godot/blender/build_char_hd_poc.py`, `godot/blender/build_kos_room_hd_poc.py`
  - `godot/assets/models/poc_*`, `godot/assets/lightmaps/poc_*`, `godot/assets/textures/poc_hd/`, `godot/assets/textures/poc_hd_char/`
  - `build/poc_*.png`
- Verify: `run_tests.gd` (all sections PASS), `main_game.tscn --smoke-test` (PASS), `npm test` (Vitest 48/48 PASS), `scripts/export_web.sh`, `scripts/export_android.sh`, `apksigner verify`.

- [ ] **Step 1: Remove temporary `poc_*` files cleanly & run `--import --quit`**
- [ ] **Step 2: Run full `run_tests.gd`, `--smoke-test`, Vitest, `export_web.sh`, `export_android.sh`**
- [ ] **Step 3: Dispatch Stage 4 Adversarial Code Review (`delegate_task`) on `git diff` + live rendered screenshots of `main_game` (`kos_room`, `kampung_gang`, `room_elite_living`, `char_art` Idle/Walk)**
- [ ] **Step 4: Fix any Stage 4 findings, commit & push to `main`, trigger Coolify deploy, and verify live `https://game.shr.co.id/` WebGL2 + SW cache version + real-browser screenshot via `browser_exec` + `vision_analyze`**
