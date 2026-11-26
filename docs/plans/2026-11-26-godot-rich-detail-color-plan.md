# Godot 4 + Blender High-Detail & Rich-Color Upgrade Plan (2026-11-26)

## Root Cause of "Pale & Low-Detail" v1 Render
1. **Washed-out / Pale Lighting (`street_poc.tscn`, `room_poc.tscn`):**
   - `fog_enabled = true` with bright green-white `fog_light_color` + `ambient_light_sky_contribution = 0.55` + `tonemap_mode = ACES` washed out shadows and muted every albedo into chalky pastel.
   - `Environment` had `adjustment_enabled = false`, `ssao_intensity` was muted by high ambient fill, and `DirectionalLight3D` shadows lacked crisp warm/cool contrast.
2. **Low-Detail Geometry (`build_kampung_street.py`, `build_kos_room.py`):**
   - Trees used `primitive_ico_sphere_add` (smooth blobs on sticks) instead of sculpted layered leaf fronds / palm & tropical canopies with textured bark.
   - Houses lacked recognizable Indonesian neighborhood richness: *genteng* overhanging wooden *lisplank* fascia & rafters, corrugated porch awnings, wall AC units, rooftop *toren air* tank, house-number plaques, window louvers/curtains, flower pots, utility poles + overhead cables, parked neighborhood motorbike/car, and roadside trash bin.
   - Room walls looked flat and bare without wall shelves, framed art, curtains, bedside lamp (`OmniLight3D` warm glow), wardrobe, and rich ceramic/wood contrast.

## Adversarial Review Fixes Integrated
1. **Direct Pixel Adjustment for Characters (`build_characters.py`):** Blender GLTF 2.0 drops `Hue/Saturation` and `Mix` shader nodes; instead adjust `img.pixels` directly in `numpy` (warm saturation/contrast boost) and wire `Image Texture -> Principled BSDF.Base Color` directly.
2. **No `OmniLight3D` Shadow Passes:** Set `shadow_enabled = false`, `omni_range = 3.5..4.5` on all porch and room `OmniLight3D` fill lights so `llvmpipe`/mobile stays fast; keep shadows solely on `DirectionalLight3D`.
3. **Balanced Lighting & Albedo Caps (Zero Clipping):** `DirectionalLight3D.light_energy = 1.20`, `ambient_light_energy = 0.28`, `ambient_light_sky_contribution = 0.22`, `tonemap_mode = 2` (`FILMIC`), `tonemap_exposure = 0.96`, `adjustment_contrast = 1.08`, `adjustment_saturation = 1.15`, plaster sRGB `<= 0.85`.
4. **Polycount Budget (`<= 50k` scene tris):** Sculpted trees use 22–30 low-poly curved leaf blades (`<= 450` tris/tree), 6-sided catenary power cables, clean compact scooter/car meshes.
5. **Explicit Anti-Z-Fighting Clearances:** Rugs `+0.012 m` above floor, curtains/plaques/wall art `+0.02 m` off wall faces, *lisplank* & corrugated porch awnings `+0.015 m` proud.

## Upgrade Plan
1. **Rich Indonesian Color & Lighting (`street_poc.tscn`, `room_poc.tscn`):**
   - Set `fog_enabled = false` in street foreground, `ambient_light_sky_contribution = 0.24`, `ambient_light_energy = 0.30` (warm sky bounce without washing out shadows!).
   - Enable `Environment` post-adjustment: `adjustment_enabled = true`, `adjustment_brightness = 1.0`, `adjustment_contrast = 1.14`, `adjustment_saturation = 1.24`, `tonemap_mode = 2` (`FILMIC` preserves rich warm terracotta & emerald greens instead of desaturating like high-key ACES!).
   - Warm golden afternoon `DirectionalLight3D` (`#FFE4B5`, `light_energy = 1.55`, crisp `shadow_blur = 0.8`), plus warm indoor `OmniLight3D` pools inside porches and inside `room_poc.tscn`!
2. **High-Detail Textured Blender Street (`build_kampung_street.py` + `tex_utils.py`):**
   - Deepen base texture saturation & baked grime/AO: rich terracotta (`(0.68, 0.23, 0.12)`), deep emerald grass/leaves (`(0.14, 0.42, 0.13)`), dark weathered asphalt (`(0.15, 0.17, 0.21)`), warm sandstone/cream plaster (`(0.92, 0.82, 0.66)`, `(0.89, 0.72, 0.56)`, `(0.74, 0.84, 0.72)`).
   - **Replace ALL blob trees** with sculpted **multi-branch tropical trees & banana/palm plants** (curved tapered trunks with branches + layered individual diamond/curved leaf blades arranged in natural radial crowns — ZERO `ico_sphere` blobs!).
   - **Add authentic Indonesian neighborhood details:**
     - Wooden *lisplank* roof fascia + visible rafters under eaves
     - Corrugated porch canopies + porch wall lamps + ceramic flower pots on porch steps
     - Recessed multi-pane wooden windows + AC outdoor compressor units on walls + rooftop *toren air* water tank
     - Street utility poles (*tiang listrik*) with crossarms & sagging catenary power cables (`bmesh` tubes)
     - Roadside *gerobak*/trash bin, parked scooter (*skuter*) & neighborhood hatchback car cleanly sculpted in Blender!
3. **High-Detail Cozy Indoor Room (`build_kos_room.py`):**
   - Deep warm terracotta/cream ceramic floor tiles (`(0.84, 0.74, 0.60)`), rich sage/ivory plaster walls (`(0.88, 0.84, 0.73)`), walnut/teak furniture (`(0.38, 0.22, 0.12)`).
   - Add **window curtains**, **wall floating shelves with books**, **framed Indonesian wall painting**, **wooden wardrobe (*lemari*)**, **bedside nightstand + glowing warm table lamp**, **woven striped floor rug**, and **laptop + mug on desk**!
4. **Richer Character Shading (`build_characters.py`):**
   - Fix washed-out character textures (`char_art.glb`, `char_ibu.glb`, `char_budi.glb`) by applying subtle warm `Hue/Saturation` & `Mix` tinting onto image-textured characters (`sophia`, `sintel`, `jay`) so skin looks warm Indonesian (`#D89A76`) and clothes pop crisply against the sunlit street!

## TDD & Verification
- Keep `godot/tests/run_tests.gd` (add `assert` for neighborhood & economy) passing `exit 0`.
- Assert every `.glb` exports with `0` missing textures and reimports cleanly under `godot4 --headless --import --quit`.
- Render `1280×720` AND `450×800` screenshots via `xvfb-run` + `lavapipe` Vulkan and verify richness, saturation, detail density, and zero pale washout via `vision_analyze`!
