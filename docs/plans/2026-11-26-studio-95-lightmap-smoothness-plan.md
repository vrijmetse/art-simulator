# ART Simulator — Studio 9.5/10 Smoothness, Baked AO & Curated CC0 Asset Plan

**Date:** 2026-11-26  
**Goal:** Push all 3D visual categories (Street/Houses `7.8 -> 9.0+`, Employer Interior `7.0 -> 9.0+`, Characters `8.5 -> 9.2+`, Kamar ART `small/large`) to commercial studio polish while keeping GLBs lightweight (`< 15 MB` each) and smooth (no jagged edges, no 99 MB bloat).  
**SOP:** Adversarial Plan Review -> Verified Probes -> Parallel Build -> Godot Import & `64/64` TDD -> Adversarial Visual Scoring.

---

## 1. Technical Upgrades for 9.5/10 Visual Fidelity

### A. Raytraced Baked Ambient Occlusion (`COLOR_0`) + Warm Bounce (Adversarial Review Hardened)
- **Why:** Real-time SSAO alone leaves under-eave porch ceilings, cabinet corners, and floor junctions slightly flat.
- **How:**
  1. Subdivide architectural floors, sidewalks, walls, and porch ceilings (`6–8` cuts) so vertex AO captures furniture/wall/eave contact shadows cleanly (never rely on 1-quad faces).
  2. In Blender 4.0.2 (`CYCLES`, `CPU`, `samples=12`, `AO distance=1.1m`), bake raytraced Ambient Occlusion into `Col` (`COLOR_0`, `BYTE_COLOR`, `CORNER`), clamped smoothly to `[0.48 .. 1.0]` so shadows stay warm/soft.
  3. Export GLTF 2.0 with `export_vertex_color='ACTIVE'` and `export_apply=False` (modifiers baked once onto shared templates BEFORE instancing so `kampung_street.glb` & `kampung_gang.glb` stay `< 16 MB`).
  4. In Godot (`src/core/scene_visuals.gd`), `apply_baked_ao(root)` inspects every `MeshInstance3D` surface: ONLY if `(mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0` AND not `Emission`-only, duplicate the material per surface and set `vertex_color_use_as_albedo = true`, `vertex_color_is_srgb = false` (matching GLTF linear `COLOR_0`).

### B. Curated CC0 Mesh Integration (`godot/assets/raw/unpacked/*.glb`) + Strip `KHR_materials_unlit`
- **All 26 unpacked CC0 Kenney assets** exist in `godot/assets/raw/unpacked/` (`kitchenFridge`, `kitchenSink`, `kitchenStove`, `kitchenCabinet`, `loungeSofa`, `cabinetTelevision`, `tableRound`, `chair`, `desk`, `chairDesk`, `bedSingle`, `bedDouble`, `pottedPlant`, `books`, `trashcan`, `planter`, `animal-cat`).
- **Strip `KHR_materials_unlit`:** Rebuild every imported Kenney material node tree (`nodes.clear()` -> fresh `Principled BSDF` PBR with PolyHaven wood / brushed steel / coral fabric) and ground `min.z = 0` at `1.85x` real Indonesian scale (`0.20x` for cat, `0.45x` for planter).
- **Character Rigging Order:** Always apply `Subsurf 1` / `convert(target='MESH')` BEFORE `attach_to_bone(...)` on `LongSkirt` / `HijabHood` / `Pak Budi`'s shirt collar so all subdivided vertices receive bone weights.

### C. Specific Visual Fixes Targeted at 9.0–9.5/10
1. **Street & Houses (`build_kampung_street.py` + `street_poc.tscn`):**
   - Move `Jl. Melati` green street sign inward (`x = 4.35 -> 3.65`) so it is 100% framed, never cropped on the right edge!
   - Refine Indonesian curb (`kanstin`) to crisp subtle-toned alternating warm-cream/charcoal concrete segments (authentic Indonesian residential curb without harsh toy contrast) + textured weathered asphalt + curb gutter grates.
   - Replace repetitive uniform foliage spheres with layered multi-tone tropical canopies (`common-tree-1/2` shared smooth mesh + `planter.glb` + dense multi-frond Banana Palms + `animal-cat.glb` lounging on House 1 porch!).
   - Bake soft `AO` onto houses, porch eaves, fences, and sidewalks so porch ceilings and recesses glow with warm depth.
2. **Employer Living Room + Kitchenette (`build_majikan_interior.py`) & Kamar ART (`build_kamar_art.py`):**
   - Replace blocky primitive fridge/sink/stove/sofa/TV/chairs with unpacked curated **CC0 Kenney Furniture Kit** GLBs (`kitchenFridge`, `kitchenSink`, `kitchenStove`, `kitchenCabinet`, `loungeSofa`, `cabinetTelevision`, `tableRound`, `chair`, `toaster`, `kitchenCoffeeMachine`, `books`, `pottedPlant`), paired with Indonesian signature details (**green 3kg LPG *tabung gas melon***, **Aqua Galon dispenser**, **Magic Com rice cooker**, **sandals at porch door**, **outdoor garden tree/fence visible through `WallBack` glass window!**).
   - Bake smooth `AO` + warm interior bounce lighting (`WindowFill` + warm `CeilingWarmLight`) so corners and tabletops look grounded.
3. **Characters (`build_characters.py`):**
   - Smooth out `Ibu Sari`'s `LongSkirt` center crease (`Subsurf 1` + cylindrical/cone skirt without center pinch) and smooth her `Hijab` forehead brow trim so zero polygonal shadow edge shows above her eyebrows!
   - Add distinct collared shirt placket/collar detail on `Pak Budi` and subtle rolled sleeve cuff/apron details so all 3 silhouettes read unmistakably distinct.

---

## 2. Verification & Quality Gates
- **Gate 1 (GLB Size & TDD):** All `.glb`s `< 18 MB` (`kampung_street.glb` shrunk from `99 MB` -> `< 18 MB`), `64/64` GDScript assertions PASS.
- **Gate 2 (Visual Score):** Adversarial critics score Street, Employer Interior, Characters, and Kamar ART `>= 8.5–9.0+/10` against *Warung Life* north star.
