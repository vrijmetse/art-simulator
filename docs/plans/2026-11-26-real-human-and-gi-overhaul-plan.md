# Real Stylized Human Cast, High-Contrast GI & Clean World Overhaul Plan (v2 — Post-Adversarial Review)

**Date:** 2026-11-26
**Status:** Revised after `deleg_c3ee274d` (resolves all 3 Critical + 2 Important findings)

---

## 1. Unified MakeHuman CC0 Character Cast (`godot/blender/build_characters.py`, `tex_utils.py`, `godot/src/scenes/main_game.gd`, `player_controller.gd`)

### Resolution of Style & Animation Cohesion (Findings 1 & 2)
- **Zero style clash:** Replace BOTH `Mannequin_F`/`Mannequin` AND avoid mixing stylized `sintel`/`sophia` with photoreal MakeHuman. Use **one unified CC0 human family (`MMWilliams/char-kit`, MakeHuman CC0)** across all 15 characters (Player + 4 shifts + 8 unique street NPCs) — real sculpted human faces, eyes, noses, lips, ears, fingers, and natural clothing folds.
- **Source caching:** Download CC0 MakeHuman `.glb` bases (`mh_1000`, `mh_3183`, `mh_3488`, `mh_1148`, `mh_3427`, `mh_3000`, `mh_1037`, `mh_3549`) into gitignored `godot/assets/raw/charkit/`.
- **Clean Indonesian Wardrobe & Hair:**
  - Strip odd raw props (`Human.fedora01`, `Human.elvs_micky_afro` on `mh_1000`) by deleting faces matching those material indices.
  - Recolor shirt/pants/skin textures in NumPy (painting over the MakeHuman chest logo on `male_casualsuit02`/`female_casualsuit02` with clean Indonesian *daster* batik, polo, kebaya, batik shirt, or SMA white/grey tones, and matching warm Indonesian skin tones `#B87A4B` / `#C68B59` / `#9E663C`).
  - Add fitted Indonesian `DasterSkirt`, `ArtApron`, `Hijab`, `Cepol`, `PakRtPeci`, `OjekHelmet` (half-face), and `KurirCap` weighted cleanly to `pelvis`/`thigh_l`/`thigh_r`/`head`.
- **Vertex, Animation & Bundle Budget (`<= 14,500` glTF verts, `<= 1.4 MB` per `.glb`):**
  - Strip the 60 combat/rifle/kick NLA tracks/actions from every MakeHuman `.glb`, keeping ONLY **4–5 life-sim clips** (`idle`, `walk`, `idle_unarmed`, `turn_left`, `jump`) plus synthesized `Fixing_Kneeling` (cleaning scrub loop from `idle` + torso lean/arm scrub) and `Celebration` (wave from `idle`) keyframes on the same 22-bone MakeHuman rig so `player_controller.gd` plays `Idle`, `Walk`, `Fixing_Kneeling`, and `Celebration` cleanly.
  - Resize embedded textures to `<= 512×512` PNG/JPEG and enforce `blend_method = 'OPAQUE'` + `Alpha = 1.0`.
  - Apply `Decimate` with `delimit={'UV'}` targeting `<= 12,800` glTF split vertices (`<= 14,500` hard cap enforced in Blender + Godot `run_tests.gd`).
  - Normalize height via `armature.scale` so female characters stand `~1.64m` and male characters stand `~1.72m`.
- **15 Unique Character Mappings (`npc_roster.gd` + `build_characters.py`):**
  - Player: `char_art` (`mh_1000` + cepol + green daster + apron), `char_art_hijab` (`mh_1000` + hijab + long daster + apron), `char_art_pro` (`mh_1000` + teal uniform + skirt), `char_art_elite` (`mh_1000` + cream/navy elite uniform)
  - Shift NPCs: `char_ibu` (`mh_3488` + burgundy kebaya/hijab + long skirt), `char_kakak` (`mh_3183` + pastel modern blouse + skirt), `char_budi` (`mh_1037` + dark collared jacket/slacks)
  - Street NPCs (0 overlap with Player): `char_dewi` (`mh_3183` + mustard blouse + ponytail), `char_pak_rt` (`mh_3549` + batik + peci), `char_ojek` (`mh_3427` + emerald jacket + half-face ojek helmet), `char_kurir` (`mh_1148` + navy courier polo + cap), `char_pelajar` (`mh_1000` + Indonesian SMA white/grey uniform + neat hair), `char_hendra` (`mh_3000` + casual tee/overalls), `char_rina` (`mh_3183` + coral-cream office blouse + skirt), `char_agus` (`mh_3427` + terracotta batik shirt + slacks)

---

## 2. High-Contrast Cycles GI Lightmaps (`kos_room.glb` + `kampung_gang.glb`)

### Resolution of Findings 3 & 4
1. **`godot/blender/build_kos_room.py`:**
   - Bake `kos_room_lightmap.png` (`1024×1024`, 32 samples, Cycles CPU) normalized to **`[0.34, 1.0]`** (rich deep contact shadows under bed, desk, wardrobe, and corners without crushing dark wood to black).
2. **`godot/blender/build_gang_kampung.py`:**
   - Add real CC0 trees & bushes (`common-tree-1.glb`, `common-tree-2.glb`, `bush-common.glb`, `bush-common-flowers.glb` from `godot/assets/raw/unpacked/`, decimated `0.45` -> `~3,800` verts/tree, `Alpha=1.0, OPAQUE`, `use_backface_culling=False`).
   - **Critical UV2 Exclusion Rule (Finding 3):** Trees/bushes remain visible (`hide_render=False`) during the Cycles bake so they cast real dappled foliage shadows onto sidewalks & walls, while **ONLY static buildings, ground, porches, fences, and benches are unwrapped & baked into `LightmapUV` (`UV2`)** -> `godot/assets/textures/kampung_gang_lightmap.png` (`1024×1024`, `[0.36, 1.0]`).
   - Replace neon-green grass `(0.24, 0.46, 0.20)` with grounded tropical lawn `(0.19, 0.32, 0.15)` + stone garden edging in both `build_gang_kampung.py` and `build_kampung_street.py`.
3. **`godot/src/core/atmosphere.gd` & `main_game.gd`:**
   - Rebalance indoor omnis (`WarmBedsideOmni = 0.48`, `WarmWindowOmni = 0.56`) and `amb_energy = 0.22` (`pagi`/`siang`) so Cycles GI lightmaps pop visibly while keeping Mbak Sari grounded.
   - Load and apply `kampung_gang_lightmap.png` via `ArtSceneVisuals.apply_lightmap(inst, lm_tex)` when `"kampung_gang"` loads.

---

## 3. Eliminate Neon Floor Rings & Overlapping 3D Labels (`chore_hotspot.gd`, `main_game.gd`)

### Resolution of Finding 5
- **`godot/src/scenes/chore_hotspot.gd`:** Replace thick glowing `TorusMesh` hoops (`outer_radius=0.36`, `emission=0.85..1.35`) with subtle flat translucent ground pads (`CylinderMesh` height `0.004`, radius `0.30`, `alpha = 0.20` idle / `0.46` near, emission `0.25`).
- **`godot/src/scenes/main_game.gd`:**
  - Replace neon `TorusMesh` portal hoops in `_spawn_portal` with subtle doormat-style flat translucent pads (`CylinderMesh` height `0.004`, `alpha = 0.22`).
  - Keep portal/NPC `Label3D` badges cleanly hidden beyond `3.2m` from the player and show them cleanly inside `3.2m` so first-time players still have clear wayfinding cues when approaching doors/NPCs without permanent floating text clutter.
  - In `_spawn_npcs` / `_play_npc_anim`, fall back `"talk"` / `"celebrate"` cleanly to `"idle_unarmed"` / `"idle"` when absent.

---

## 4. Verification & TDD Gate
- **Red TDD (`godot/tests/run_tests.gd`):**
  1. Assert `kampung_gang_lightmap.png` exists and `kampung_gang.glb` has `ARRAY_FORMAT_TEX_UV2` on `>= 10` surfaces.
  2. Assert `kos_room_lightmap.png` has real shadow depth (`min_luma <= 0.44`, `max_luma >= 0.85`).
  3. Assert all 15 `char_*.glb` exist, have unique paths, have `<= 14,500` glTF verts, and have `"idle"` + `"walk"` clips (plus `"Fixing_Kneeling"` / `"Celebration"` on `char_art*`).
  4. Assert `chore_hotspot.gd` uses subtle flat ground disc (`CylinderMesh`, not `TorusMesh`).
- **Stage 3 & 4:** Run Blender character close-up render + `godot4 --import` + `run_tests.gd` + `--smoke-test` + `npx vitest run`, export Web (`web-dist/`) & Android (`.apk`), run Stage 4 pre-commit adversarial review, deploy to `https://game.shr.co.id/`, and visually verify live Chromium screenshots with `vision_analyze`.
