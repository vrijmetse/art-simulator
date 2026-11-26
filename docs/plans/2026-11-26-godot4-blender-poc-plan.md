# Godot 4 + Blender Smooth Visual PoC Plan (2026-11-26)

## Goal
Build an isolated **Godot 4.7.2 + Blender 4.0.2 Proof-of-Concept** inside `/home/ubuntu/projects/art-simulator/godot/` (preserving the live PWA at `https://game.shr.co.id` untouched) that achieves **Warung Life Simulator**-grade smooth, sunlit, textured visual polish for our **ART (Asisten Rumah Tangga — indoor & outdoor house)** theme.

## Verified Host Environment
- **Host:** Linux `aarch64` (4 vCPU ARM64, 23 GB RAM / 14 GB avail, 27 GB free disk, no hardware GPU).
- **Tools Installed & Probed:**
  - `blender 4.0.2` (with `python3-numpy`, imports/exports uncompressed `.glb` in `0.15s`).
  - `godot4 4.7.2.stable.official` at `/home/ubuntu/.local/bin/godot4`.
  - Mesa `llvmpipe` (`opengl3`) AND `lavapipe` (`VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json` `vulkan` `Forward+` confirmed working inside `xvfb-run`).
- **Deferred Until PoC Visual Approval:** `Godot_v4.7.2-stable_export_templates.tpz` (~900 MB) and Android SDK/cmdline-tools (~1.8 GB) — we verify visual quality `>= 8.5/10` first before spending 2.7 GB disk on APK export templates.

## Architecture & Directory Layout
```
/home/ubuntu/projects/art-simulator/godot/
├── project.godot                  # Forward+ Vulkan, ACES tonemap, SSAO, 1280x720 / responsive stretch
├── blender/
│   ├── tex_utils.py               # Procedural PIL/numpy/Blender image textures (genteng, plaster+AO, asphalt, wood, tiles)
│   ├── build_kampung_street.py    # Exports assets/models/kampung_street.glb (3 detailed houses, fences, trees, street)
│   ├── build_kos_room.py          # Exports assets/models/kos_room.glb (smooth beveled cutaway house room + props)
│   └── build_characters.py        # Binds UAL1 clips onto CC0 1:6 humans (sophia/jay) + decimates -> char_art.glb, char_ibu.glb, char_budi.glb
├── assets/
│   ├── textures/                  # Generated PNG textures (terracotta tiles, plaster AO, ceramic tiles, foliage)
│   └── models/                    # Blender-exported .glb assets (uncompressed, Godot-native)
├── src/
│   ├── core/
│   │   ├── i18n.gd                # format_balance(0) -> "Rp 0", format_price(0) -> "Gratis", Indonesian/English strings
│   │   ├── economy.gd             # Pure integer Rp faucets/sinks, job payout, career XP
│   │   └── neighborhood.gd        # Family/pet NPCs, daily tip anti-farm (1x/day), patrol math
│   └── scenes/
│       ├── street_poc.gd          # Full-bleed Warung-Life HUD + 3D street controller + tap-to-walk + dialogue bar + CLI capture
│       └── room_poc.gd            # Full-bleed indoor room controller + Lap/Pel scrub/clean + CLI capture
├── scenes/
│   ├── street_poc.tscn            # Sunlit WorldEnvironment (SSAO, ACES, Sky), houses, lush trees, NPCs, floating HUD
│   └── room_poc.tscn              # Cutaway indoor house room + window sunlight + stains + homekeeper
└── tests/
    └── run_tests.gd               # Headless TDD test runner (`godot4 --headless --path godot -s res://tests/run_tests.gd`)
```

## Adversarial Review Fixes Integrated
1. **Bone Retargeting & Baking (`build_characters.py`):** Never bind `UAL1` actions directly to `sophia`/`jay` by bone name; bake `Idle_Loop`, `Walk_Loop`, `Idle_Talking_Loop`, `Celebration`, and `Interact` cleanly via `Copy Rotation` (case-insensitive map `Head->head`) + `Copy Location` on `pelvis` using `bpy.ops.nla.bake(..., visual_keying=True)`, then remove the donor `UAL1` rig before export.
2. **Safe `DECIMATE` on `SkinnedMesh`:** Clear `shape_keys` before applying `DECIMATE` (`delimit={'UV', 'SEAM'}`), keeping `ARMATURE` modifier intact.
3. **GLTF PBR Texture Export (`tex_utils.py`):** Save every generated texture PNG (`img.save()`), mark roughness/normal PNGs `'Non-Color'`, and route normal maps via `ShaderNodeNormalMap` (`Tangent Space`) into `Principled BSDF.Normal`.
4. **Reliable Capture Timing:** Wait 3 frames + `await RenderingServer.frame_post_draw` before `get_viewport().get_texture().get_image().save_png(path)`.
5. **CPU `lavapipe` Framing:** Use `PSSM_2_SPLITS` + lightweight `SSAO` defaults so `Forward+` Vulkan renders swiftly inside `xvfb-run`.
6. **Headless Test Exit Codes:** `godot/tests/run_tests.gd` `extends SceneTree` and exits via `quit(0 if failed == 0 else 1)`.
7. **Git Hygiene:** Ignore `godot/assets/raw/` in `.gitignore` so the raw `21 MB` `UAL1.glb` never enters git history.

## Key Visual & Technical Design Decisions (Addressing Every "Squarish" Gap)
1. **Smooth `1:6` Human Characters (No Cube Chibis):**
   - Use CC0 `Mesh2Motion` `sophia.glb` (`1.7 MB`, `66` UE-standard bones) & `jay.glb` (`66` bones) paired with `tilakverse-assets` CC0 `UAL1.glb` (`65` matching UE-standard bones: `root`, `pelvis`, `spine_01..03`, `clavicle_l`, `upperarm_l`, `lowerarm_l`, `hand_l`, etc.).
   - In `build_characters.py`, carefully map ONLY matching bone tracks (handling `sophia`'s `neck_01`/`Head` difference explicitly!), strip to 5 essential actions (`Idle_Loop`, `Walk_Loop`, `Idle_Talking_Loop`, `Celebration`, `Interact`), apply `DECIMATE` modifier if >12k tris for mobile smoothness, and tint outfit/skin materials cleanly.
2. **Textured & Beveled Blender Indonesian Architecture (No Untextured `BoxGeometry`):**
   - Generate crisp procedural `512×512` PNG textures in Python (`numpy` + `bpy.data.images`) — **NOT** unsupported Cycles procedural shader trees that fail to export in GLTF! — wire them through `Principled BSDF` (`Base Color`, `Roughness`, `Normal`/bump), so Godot imports exact PBR materials reliably:
     - **Terracotta *genteng* roof:** overlapping curved ridge rows + ridge caps + wooden *lisplank* overhangs (`bmesh` bevels + `shade_smooth`).
     - **Plaster walls with baked vertical AO dirt gradient:** bright cream/ivory upper wall fading softly into warm earthy shadow near the base.
     - **Wrought-iron gates, stone gate pillars, wooden louver windows, porch canopies, lush layered tropical banana/palm leaf clusters, beveled black-and-white *kanstin* curb, and textured worn asphalt.**
3. **Full-Bleed *Warung Life* HUD (Zero Boxy Top/Bottom Bars):**
   - In `street_poc.tscn` & `room_poc.tscn`, the 3D world fills **100% of the screen**.
   - Top-left floating translucent pill: Day, `Rp 0` wallet, Level badge.
   - Top-right floating translucent icon pills: `📱 HP` / `🏠 Masuk Rumah` / `📷 Putar`.
   - Floating `!` pins over neighbors; tapping opens a sleek translucent Story Dialogue Bar at the bottom with character portrait + `Sapa (+Rp 5.500)` + `Tutup`.
4. **Godot 4 `Forward+` Soft Lighting & SSAO:**
   - `WorldEnvironment` with procedural `PhysicalSkyMaterial` / `ProceduralSkyMaterial` warm afternoon horizon, `tonemap_mode = ACES`, `ssao_enabled = true` (soft corner darkening), `glow_enabled = true` subtle bloom, and `DirectionalLight3D` soft PCF shadows (`directional_shadow_mode = PSSM_4_SPLITS`).
5. **Headless Render Verification (`xvfb-run` + `lavapipe`):**
   - Run `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json xvfb-run -a -s "-screen 0 1280x720x24" godot4 --path godot --rendering-driver vulkan -- --capture=/tmp/street.png` (and `450x800` portrait too!) and inspect every screenshot via `vision_analyze`!

## TDD Plan (Red → Green → Refactor)
1. **RED:** Write `godot/tests/run_tests.gd` testing `i18n.gd` (`format_balance(0) == "Rp 0"`, `format_price(0) == "Gratis"`), `economy.gd` (integer Rp math + XP rank), and `neighborhood.gd` (daily 1× tip anti-farm + distance/spacing) — run `godot4 --headless --path godot -s res://tests/run_tests.gd` and confirm non-zero failure before writing `src/core/*.gd`.
2. **GREEN:** Implement `src/core/{i18n,economy,neighborhood}.gd` until `run_tests.gd` exits `0` with all assertions passing.
3. **Blender Asset Build + Validation:** Run `build_kampung_street.py`, `build_kos_room.py`, `build_characters.py` via `blender --background`, assert `.glb` files exist, `< 2.5 MB` each, and import cleanly under `godot4 --headless --import --quit` with zero errors.
4. **Scenes + Render QA:** Build `street_poc.tscn` & `room_poc.tscn`, render both landscape (`1280x720`) and portrait (`450x800`) frames via `xvfb-run`, inspect via `vision_analyze`, and score against *Warung Life Simulator*!
