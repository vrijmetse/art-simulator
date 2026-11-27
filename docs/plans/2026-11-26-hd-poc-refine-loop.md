# HD Visual POC Refine Loop Plan (`8.8 -> 9.5–10/10`)

**Goal:** Run a 3-way parallel refinement iteration (**D1** = Engine/Lighting/Post ceiling, **D2** = D1 + Runtime `1024px` Texture Lanczos+Sharpen Upgrade, **D3** = Polished High-Detail Objects + Indonesian Micro-Props in Blender + D1 Lighting/Post) to hit **≥ 9.5/10** *Warung Life* parity before overhauling all 10 stages.

## Gaps Identified in `poc_exp_c.png` (8.8/10)
1. **Chunky Box Objects & Sparse Micro-Props:** Wardrobe, nightstand, desk, bed, and walls in `kos_room.glb` lack architectural trim, recessed doors, cables, everyday clutter (`galon air`, `sandal jepit`, `stop kontak`, `saklar`, `pen cup`, `snack jar`, `hanging tote`, `window blinds`, sculpted multi-leaf plants).
2. **Backdrop & Mirror Regression vs Exp A:** `poc_exp_c.png` kept the dull sage-green void and pale flat mirror (`metallic=0.85` reflected sage sky) instead of Exp A's rich dark-slate backdrop and cool reflective sky-tinted mirror (`metallic=0.35`, `albedo=(0.58, 0.74, 0.88)`).
3. **Close-Up `256px`/`512px` Texture Softness:** Sari's `256×256` clothing/face swatches and `512×512` room albedos soften up close.

## Strict File Ownership (Zero Shared Writes, Zero Touch to `main_game` or `kos_room.glb`)
- **POC D1 (`poc_exp_d1` — Engine + Lighting + Material + Luma-Preserving Post-Pass):**
  - Owns: `godot/scenes/poc_exp_d1.tscn`, `godot/src/scenes/poc_exp_d1.gd`, `godot/shaders/poc_d1_sharpen.gdshader`, `build/poc_exp_d1.png`
  - Combines Exp A + Exp C: `tonemap_mode = 4` (AgX), `ssao_enabled = false`, deep warm-slate sky/ground backdrop, cool sky-tinted mirror (`metallic = 0.35`, `roughness = 0.08`), glossy ceramic floor (`roughness = 0.20`), tight orthogonal shadow (`directional_shadow_mode = 0`, `max_distance = 10.0`, `shadow_blur = 0.42`), cool-blue `WindowFill`, `0.0038` warm-sepia outline on `PlayerArt` + smooth props, `layer=0` luma-preserving 5-tap sharpen (`sharpen_amount = 0.38`, `clamp(luma_diff, -0.08, 0.08)`), camera `(3.46, 2.95, 3.46)` `fov = 32.5`.
- **POC D2 (`poc_exp_d2` — D1 + Runtime `1024px` Lanczos + High-Pass Texture Upgrade):**
  - Owns: `godot/scenes/poc_exp_d2.tscn`, `godot/src/scenes/poc_exp_d2.gd`, `godot/shaders/poc_d2_sharpen.gdshader`, `build/poc_exp_d2.png`
  - Same lighting/camera/post-pass as D1 (`layer=0`, own `poc_d2_sharpen.gdshader`), **plus** in-memory texture sharpening on duplicated `StandardMaterial3D` `albedo_texture`s (preserving `detail_albedo` `UV2` lightmap!): decompress if needed (`if img.is_compressed(): img.decompress()`), `img.resize(..., Image.INTERPOLATE_LANCZOS)` to `1024×1024` for `char_art`/`kos_room` albedos, crisp 3×3 unsharp pass + wood/fabric contrast boost in GDScript, and `rim_enabled = true` (`rim = 0.22`) on props & character.
- **POC D3 (`poc_exp_d3` — Blender High-Detail Sculpted Furniture + Indonesian Micro-Props + D1 Lighting/Post):**
  - Owns: `godot/blender/build_kos_room_hd_poc.py`, `godot/assets/models/poc_kos_room_hd.glb`, `godot/assets/lightmaps/poc_kos_room_hd_lightmap.png`, `godot/scenes/poc_exp_d3.tscn`, `godot/src/scenes/poc_exp_d3.gd`, `godot/shaders/poc_d3_sharpen.gdshader`, `build/poc_exp_d3.png`
  - Builds from `build_kos_room.py` into **isolated** `poc_kos_room_hd.glb` & `poc_kos_room_hd_lightmap.png` (passing `TEX_DIR = os.path.join(GODOT_DIR, "assets", "textures", "poc_hd")` so ZERO shared textures in `assets/textures/` or `kos_room.glb` are modified!), adding:
    - Baseboard skirting & wall trim, window casing + venetian blinds + sill pot, beveled teak mirror frame + cosmetic shelf ledge (comb & skincare bottles).
    - Recessed paneled wardrobe doors + wood trim + side hooks with hanging cloth tote bag.
    - Rich study desk clutter: pen holder with pens, stacked notebooks, mouse + mousepad, power strip + cord, Indonesian kerupuk/snack jar, ceramic mug, articulated desk lamp, wall corkboard with sticky notes.
    - Cozy bed with folded quilt/throw drape + 2 plump pillows + end-piped bolster; **19L Blue Galon Air dispenser on wooden stand** next to Magic Com; wall **stop kontak + saklar**; **sandal jepit** on woven mat; sculpted **multi-leaf indoor monstera/calathea plant**.
    - Runs `godot4 --headless --path godot --import --quit` before rendering with D1's AgX + cool mirror + slate backdrop + `0.36` luma-preserving sharpen!

## Verification & Self-Score Gate
- Zero shader/import errors in stdout/stderr; clipped white `< 0.15%`; Laplacian sharpness `>= 900`; framing check verifying head/feet and corner props are unclipped; visual audit via `vision_analyze` targeting **9.5–10/10**.
