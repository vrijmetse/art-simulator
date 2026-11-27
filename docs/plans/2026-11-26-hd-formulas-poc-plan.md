# HD Character + Object/Environment Formulas POC (`D5`)

**Goal:** Prove two repeatable, game-wide production formulas in an isolated `D5` POC (`poc_exp_d5`) before overhauling all 15 characters and 10 stages:
1. **Formula 1 (`build_char_hd_poc.py` -> `poc_char_art_hd.glb`):** Unified Character & NPC pipeline using MakeHuman base + sculpted hair + **`Shrinkwrap` + `Solidify` + `Subsurf` + `DataTransfer` weight-transferred Body-Topo clothing** + `1024px` crisp textures.
2. **Formula 2 (`build_kos_room_hd_poc.py` -> `poc_kos_room_hd.glb` + `poc_kos_room_hd_lightmap.png`):** 4-Class Object & Environment pipeline (`bmesh`+`Bevel`+1K CC0 PBR, `bmesh.ops.spin` lathe appliances, sculpted cloth drape & curved tapered botanical leaves, woven rattan textures, and separated sightlines) rendered under the `D4` AgX + luma-sharpen stack.

## Strict File Isolation (Zero Touch to Live `main_game`, `char_*.glb`, or `kos_room.glb`)
- **Character POC:** `godot/blender/build_char_hd_poc.py`, `godot/assets/models/poc_char_art_hd.glb`, `build/poc_char_d5_closeup.png`
- **Room Object/Env POC:** `godot/blender/build_kos_room_hd_poc.py` (with `TEX_DIR = assets/textures/poc_hd`), `godot/assets/models/poc_kos_room_hd.glb`, `godot/assets/lightmaps/poc_kos_room_hd_lightmap.png`
- **Godot Scene:** `godot/scenes/poc_exp_d5.tscn`, `godot/src/scenes/poc_exp_d5.gd` (reusing `shaders/poc_d3_sharpen.gdshader` + `shaders/poc_c_detail.gdshader`), `build/poc_exp_d5.png`

## Formula 1 Details — `build_char_hd_poc.py` (`poc_char_art_hd.glb`)
1. Import `mh_1000.glb` (clean skeleton + face/body/shoes, `scale=(1,1,1)`), transfer `Human.elvs_katherine_hair` (`3,369` verts) from `mh_3488.glb` (or keep sculpted MakeHuman hair + sculpted bun) parented cleanly to `head` — ZERO floating `UVSphere` hair cap!
2. **Body-Topo `DasterSkirt` & `ArtApron` & `ApronPocket` (`total_verts <= 14,500` asserted!):**
   - Apply `transform_apply(location=False, rotation=True, scale=True)` on every clothing mesh before `Shrinkwrap` & `DataTransfer` so coordinates align 1:1 with `mh_1000_mocap`.
   - `DasterSkirt`: `18×5` flared skirt ring (`~90` base verts) -> `Subsurf(1)` (`~360` verts, `use_backface_culling = False` instead of `Solidify` to stay well under `14,500`) -> **`DataTransfer`** (`use_vert_data=True`, `data_types_verts={'VGROUP_WEIGHTS'}`, `vert_mapping='POLYINTERP_NEAREST'`, calling **`bpy.ops.object.datalayout_transfer(modifier=dt.name)`** BEFORE `modifier_apply`!).
   - `ArtApron`: `8×6` front waist-to-knee grid (`~48` base verts) -> `Subsurf(1)` **before** `Solidify` (`~400` verts total) -> **`Shrinkwrap`** (`NEAREST_SURFACEPOINT`, `OUTSIDE_SURFACE`, `offset=0.010 * s_u`) onto joined body+skirt -> `Solidify(0.004 * s_u, offset=1.0)` -> **`datalayout_transfer` + `DataTransfer`** weights from body+skirt!
   - `ApronPocket`: `4×3` grid (`~12` verts) -> `Shrinkwrap(offset=0.006 * s_u)` onto `ArtApron` -> `Solidify(0.004 * s_u)` -> `Bevel(segments=1)` -> **`datalayout_transfer` + `DataTransfer`** weights from `ArtApron`!
   - Total verts: `9,377 + 3,369 + ~950 ≈ 13,700 <= 14,500` (asserted in script).
3. **High-Res Character Textures:** Do NOT downscale `mh_1000` embedded textures (`max_dim = 1024 if is_body else 512`), and generate `1024×1024` woven batik/daster + cotton apron + seam stitching PNGs (`assets/textures/poc_hd/`).
4. Verify exported `poc_char_art_hd.glb` vertex count (`<= 14,500`), zero clipping in both `Idle` and `Walk` `+0.25s` Cycles close-up (`build/poc_char_d5_closeup.png`), and valid `AnimationPlayer` tracks.

## Formula 2 Details — Upgrading All 7 Weak Objects in `build_kos_room_hd_poc.py`
1. **Explicit `UVMap` (`UV0`) on every `bmesh` / `spin` / cloth / botanical mesh BEFORE `bake_cycles_lightmap`** so `UV0` textures never collapse to `(0,0)` and `UV2` (`LightmapUV`) stays distinct.
2. **Curved Tapered Corner Plant:** Replace `PlantBlade_0..9` beveled boxes with 10 sculpted curved tapered botanical blades (`bmesh` curved arch with pointed tip + V-fold midrib + `Subsurf(1)` + unwrapped `UVMap`), emerging directly from `PlantSoil`.
3. **`bmesh.ops.spin` Lathe Appliances & Containers:**
   - **19L Blue Galon Air + Table Dispenser:** Spin 12-point ridged translucent Aqua bottle inverted onto a sculpted white dispenser tower (`spin` + front recess + red/blue hot/cold push taps + cup drip tray) on a 4-legged wooden stand!
   - **Magic Com (Rice Cooker):** Spin rounded cylindrical-dome body + hinged lid + chrome steam vent + handle + status LED onto `RiceCookerStand` (move retro TV onto a corner wall bracket/shelf above `RiceCookerStand` so both read clearly!).
   - **Standing Fan:** Spin motor cowl + curved 3-blade rotor + **8 radial thin wire cage spokes** inside front/back guard rings!
   - **Kerupuk Jar:** Spin crystal-clear glass jar (`mat_glass_jar.blend_method = 'BLEND'`, `alpha=0.22`, `roughness=0.08`, excluded from `UV2` lightmap bake!) containing 5 sculpted torus *kerupuk* spirals inside!
4. **Cloth Bed Quilt & Woven Rattan Hamper:**
   - **BedQuilt:** Subdivided drape mesh wrapping smoothly **over the top AND down both left/right mattress sides** with gentle cosine cloth folds + `Solidify(0.010)` + `Subsurf(1)` + `UVMap`.
   - **LaundryBasket:** Generate `1024×1024` woven rattan albedo+normal map in `TEX_DIR` + `spin` tapered rimmed basket + 3 sculpted folded/crumpled cloth mounds inside!
5. **Cycles Bake Guard & Sightline Polish:**
   - Add `PlantBlade_`, `FanSpoke_`, `Kerupuk`, `LaundryMound_`, `GalonTap_` to `exclude_prefixes` in `bake_cycles_lightmap` (`< 45s` bake!).
   - Replace `Wainscot` `mat_cream` fabric weave with smooth matte cream plaster + vertical teak dado trim rails.
   - Fix `WallArtCanvas` UV orientation (`sunrise` at top-right) + multi-color `WallShelf` books (replacing uniform pink Kenney book tint).
   - Shift `SucculentPot` on the window sill to `x = 0.68` so it never aligns behind `DeskLampShade`.

## Verification & Self-Score Gate
- Run `build_char_hd_poc.py` (with `Idle` + `Walk` Cycles close-up `build/poc_char_d5_closeup.png`) and `build_kos_room_hd_poc.py`.
- Run `godot4 --headless --path godot --import --quit`, verify vertex cap & zero warnings, capture `build/poc_exp_d5.png` (`1280×720` `gl_compatibility`).
- Inspect `poc_char_d5_closeup.png`, `poc_exp_d5.png`, AND 100% zoom crops (`vision_analyze`) to verify all 7 object flaws + apron clipping are eliminated and score **≥ 9.7 / 10**.
