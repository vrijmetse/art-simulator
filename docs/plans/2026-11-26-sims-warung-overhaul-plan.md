# Option A — *The Sims* / *Warung Life* Visual & Cast Parity Overhaul Plan

## Objective
Close the visual gap between `ART Simulator` and *Warung Life* / *The Sims* while staying 100% real-time 3D (`gl_compatibility`, WebGL2, Android APK, iOS-ready, all 823+ tests preserved).

## Root Causes Diagnosed
1. **Duplicate Green Daster NPCs (`npc_roster.gd`):** `Mbak Dewi` loads `char_art.glb` (identical to Player Mbak Sari), and 4 other NPC pairs (`Pak Agus`/`Pak RT`, `Pak Budi`/`Bang Ojek`, `Kakak Maya`/`Anak Sekolah`, `Pak Hendra`/`Kurir Paket`) reuse the same `.glb`.
2. **Broken Character Smoothness (`build_characters.py`):** `Decimate(0.45)` destroys 55% of `Mannequin_F` (`7,222` verts) and `Mannequin` (`7,011` verts), leaving faceted triangles. Face uses protruding spheres/cubes and clothing is painted onto robotic seams instead of smooth 3D `Solidify` layers.
3. **Flat Lighting & Muddy Noise (`build_kos_room.py`, `tex_utils.py`, `atmosphere.gd`):** High-frequency PolyHaven plaster/ceramic/asphalt normal noise looks gritty, vertex-color AO has sparse detail, and real-time daylight lacks *Warung Life*'s warm-golden vs cool-indigo contrast + window light shafts + baked GI.
4. **Distant Camera & Empty Grey Yard (`main_game.gd`, `main_game.tscn`, `build_kos_room.py`, `build_kampung_street.py`):** `fov=44` + distant `cam_offset` + `OuterYard`/`YardPatio` shrink the room/characters; street has straight-on angle and harsh zebra curbs.

---

## Architecture & Workstreams

### Workstream 1 — Unique Cast & Sims-Smooth Characters (`build_characters.py`, `npc_roster.gd`, `player_controller.gd`, `main_game.gd`)
1. **Kill `Decimate` completely:** Retain full `7,222` / `7,011` base vertices (`remove_doubles` only on welded body without merging UV seams destructively — or `remove_doubles` BEFORE UV project + `shade_smooth` without sharp `auto_smooth` creases). Keep every exported character `.glb` `<= 14,500` vertices.
2. **Sims-like Smooth Face, Hair & 3D Garments:**
   - Replace blocky cube eyebrows/lips and sphere nose with contoured flush facial geometry + soft glossy sclera/iris cornea + natural brow/lip curvature.
   - Add smooth `Solidify` (`0.008m`, `bevel/subsurf` smooth) **fitted 3D shirt/blouse shell + short/long sleeves shell + collar + fitted pants/trousers shell** so clothes sit naturally over the body instead of painted-on mannequin joint lines.
   - Smooth sculpted hair/hijab/peci/cap/helmet meshes (`Subsurf 1`).
   - Natural Sims human scale `0.92` (not cartoonishly huge, balanced cleanly against furniture).
3. **100% Unique Cast (Zero Duplicate Models):**
   - Generate distinct `.glb`s: `char_art`, `char_art_hijab`, `char_art_pro`, `char_art_elite`, `char_ibu`, `char_kakak`, `char_budi`, PLUS **8 new unique NPC `.glb`s**:
     - `char_dewi.glb` (coral-terracotta blouse + dark indigo jeans + sleek ponytail, NO green daster!)
     - `char_pak_rt.glb` (gold-cream batik + black *peci* cap + dark slacks)
     - `char_ojek.glb` (emerald-black Ojek jacket + white-green helmet + denim)
     - `char_kurir.glb` (orange-navy courier polo + navy baseball cap + cargo pants)
     - `char_pelajar.glb` (SMA white shirt + grey pleated skirt + bob hair)
     - `char_hendra.glb` (slate-navy collared polo + khaki chinos + neat parted hair)
     - `char_rina.glb` (teal-lavender tunic + cream hijab + dark trousers)
     - `char_agus.glb` (warm terracotta-brown batik + dark trousers, distinct from `char_budi`)
   - Update `npc_roster.gd` so every NPC on any street or shift uses a unique `model_path`.

### Workstream 2 — Cycles-Baked GI Lightmap + Stylized Clean Room + Sims Framing (`tex_utils.py`, `build_kos_room.py`, `scene_visuals.gd`, `atmosphere.gd`, `main_game.tscn`, `main_game.gd`)
1. **Clean Stylized Textures (`tex_utils.py`):** Add `stylized_clean=True` generators (clean warm ceramic tile with crisp grout, smooth gradient plaster without noisy grain, clean warm teak wood grain, crisp *Sajadah* & *Tikar* patterns, clean dark sheen asphalt, clean sidewalk pavers) — zero muddy PolyHaven bump noise on low-poly architecture.
2. **Real Blender Cycles GI Lightmap (`build_kos_room.py` + `scene_visuals.gd`):**
   - Add a second UV map `LightmapUV` (`smart_project` across static room/furniture meshes -> exports as glTF `TEXCOORD_1` / Godot `ARRAY_TEX_UV2`).
   - Place physical Cycles lights in Blender: warm golden `SUN` angled through `WinFrame` + `WinBarV`/`WinBarH` casting window-pane light shafts onto the floor; warm bedside `POINT` lamp; cool indigo-blue `WORLD` ambient.
   - Bake Cycles `DIFFUSE` (Direct + Indirect) with neutral white base override -> apply numpy 3×3 Gaussian denoise pass (since Linux Blender lacks OpenImageDenoiser) -> save `kos_room_lightmap.png` (`1024×1024`, packed/saved to `res://assets/textures/`).
   - Add `ArtSceneVisuals.apply_lightmap(node, tex)` in `scene_visuals.gd`: binds `detail_enabled=true`, `detail_uv_layer=DETAIL_UV_2`, `detail_blend_mode=BLEND_MODE_MUL`, `detail_albedo=tex` on surfaces containing `ARRAY_FORMAT_TEX_UV2`!
3. **Cozy Diorama & Props (`build_kos_room.py`):**
   - Remove the giant grey `OuterYard` / `YardPatio` / `YardFence` concrete slab; frame open diorama edges with subtle dark twilight greenery/shrubs against `#101521` studio backdrop.
   - Add cozy lived-in bedroom storytelling: wooden TV console with glowing screen, retro radio, storage boxes atop wardrobe, hanging flannel & cap on wall hooks, crisp *Catatan* sticky notes & calendar.
4. **Two-Tone Atmosphere & Sims Camera (`atmosphere.gd`, `main_game.tscn`, `main_game.gd`):**
   - `Camera3D` `fov = 36.0` (tighter distortion-free Sims framing).
   - `cam_offset`: `Vector3(3.05, 2.95, 3.35)` in `home`, `Vector3(2.95, 2.75, 3.65)` diagonal 3/4 in `street`.
   - Two-tone lighting in `atmosphere.gd`: warm amber key light vs cool indigo ambient/shadow tint.

### Workstream 3 — Kampung Street Overhaul (`build_kampung_street.py`, `build_gang_kampung.py`, `build_cluster_elite_street.py`)
1. Clean smooth dark sheen asphalt (`roughness = 0.46`, zero noisy grit) + storm drain grates + clean pastel-terracotta/cream plaster walls without noisy normal mud.
2. Replace jagged black-and-white zebra curb blocks with clean beveled stone sidewalks + subtle natural curb edges.
3. Add warm glowing house windows, wrought-iron fences with stone pillars + warm glowing amber pillar lanterns, and denser layered tropical foliage.

## Verification & TDD
- **Red -> Green (`godot/tests/run_tests.gd`):**
  - Assert **0 duplicate `model_path` values** within any street or shift in `ArtNpcRoster` AND **Player `char_art.glb` is never duplicated by any NPC**.
  - Assert every exported `char_*.glb` loads cleanly and `ArtSceneVisuals.apply_lightmap` binds `DETAIL_UV_2` + `BLEND_MODE_MUL` ONLY on meshes with `ARRAY_FORMAT_TEX_UV2`.
- Verify all `char_*.glb` vertex counts `<= 14,500`, run `godot4 --headless` TDD + `--smoke-test` + `vitest`, export Web + Android APK, Stage 4 adversarial code review, deploy live to `https://game.shr.co.id/`, and inspect live Chromium screenshots side-by-side against *Warung Life* via `vision_analyze`.
