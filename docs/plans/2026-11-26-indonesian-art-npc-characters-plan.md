# Plan: Authentic Indonesian ART & NPC Characters (*Mba2, Ibu2, Kakak2, Bapak2*) + Live Room Presence

## Goal
Replace the Western/chibi mannequin look (`closeup_chars_v20.png`) with unmistakable, cohesive, stylized Indonesian characters matching *Warung Life Simulator* warmth across both the playable **Mba2 ART** progression and live **Ibu2 / Kakak2 / Bapak2 / Mba2** NPCs in scenes.

## Root-Cause Diagnosis (Verified via Blender & `vision_analyze`)
1. `Ibu Sari` appeared bald because `Body` head skull (`z=2.07..2.94`, `x=±0.44`) poked straight through `HijabHood` (`radius=0.435`), and raw `Hair` was shrunk to `0.30x`.
2. `Sari ART` & `Pak Budi` had dangling shin-length arms because `UpperArm`/`LowerArm` bone lengths (`0.95m` total span) were never shortened in `edit_bones` and `arm.scale.z = 1.08` stretched them downward.
3. `Skin` had `Emission Strength = 0.16`, washing Indonesian *sawo matang* tones into pale ghost-white.
4. `casual-2-female.glb` hair polygons had spiky anime dreads (`Hair`), and `char_art.glb` wore a generic T-shirt + pants rather than an Indonesian *Mba2 ART* look (*daster/tunik + celemek + sanggul/cepol*).
5. `char_ibu.glb` / `char_budi.glb` / `char_kakak.glb` were not spawned into `main_game.gd` rooms/neighborhoods.

## TDD & Asset Plan
### 1. Core Data & NPC Roster (Red -> Green TDD)
- Add `godot/src/core/npc_roster.gd` (`ArtNpcRoster`):
  - `get_shift_npcs(tier_id: String, profile: Dictionary) -> Array[Dictionary]`: returns deterministic NPC descriptors (`id`, `label_id`, `label_en`, `model_path`, `pos`, `rot_y`, `anim`) placing **Ibu2**, **Bapak2**, and **Kakak2** inside each tier's house (clamped inside walkable room interiors without blocking chores/spawn).
  - `get_home_npcs(tier_id: String) -> Array[Dictionary]`: places friendly **Mba2** / **Ibu Kos** / **Kakak2** neighbors outside/in courtyard where appropriate.
- Add tests in `godot/tests/run_tests.gd`:
  - Verify `ResourceLoader.exists("res://assets/models/char_kakak.glb")` and all `NpcRoster` model paths exist.
  - Verify `NpcRoster.get_shift_npcs` returns non-empty Indonesian archetypes (`ibu2`, `bapak2`, `kakak2`) per tier with valid `Vector3` positions clear of `player_spawn` (`>= 1.2m`).
  - Verify ID/EN label isolation (`label_id` vs `label_en`).

### 2. Blender Indonesian Character Rebuild (`godot/blender/build_characters.py`)
- **Fix Arm Proportions Cleanly:** Set `arm.scale = (0.94, 0.94, 1.01)` and shorten `UpperArm.L/R`, `LowerArm.L/R`, `Hand.L/R` vertices + bone lengths (`~0.76x` towards shoulder pivot) with matching rest-pose/FK integrity, or uniform scale on arm mesh + armature bones in `EDIT` mode (`use_connect=False` -> scale tail/head offsets consistently and preserve NLA rotations!). Wait: verify animation playback in Blender & Godot after bone length scaling so `Idle`/`Walk`/`Clean` don't distort!
- **Fix Skin Tone & Expressive Face:** Remove `Emission` from `Skin`; set warm Indonesian *sawo matang* tones `(0.66, 0.44, 0.29)`–`(0.58, 0.37, 0.25)` with clean dark eyes, brows, and subtle smile.
- **Shrink Raw Spiky `Hair` (`0.12x` inside head) & Sculpt Real Indonesian Hair/Hijab Around Measured Head Bounds:**
  - Compute exact `(min_x, max_x, min_y, max_y, min_z, max_z)` of `Body`'s `Head` vertices in `arm`-local space **after** head scaling (`0.76x`), then build headwear/hair with explicit clearance (`+0.055m`–`+0.075m`) and assert in Python at export time that headwear/hair outer bounds enclose the skull cleanly!
  - **`char_art.glb` (`Mba2 ART Starter`):** Smooth dark hair cap + neat back **Cepol/Sanggul** bun + flared **Daster Batik/Floral** tunic skirt + **Celemek Putih/Krem** + indoor **Sandal Selop**.
  - **`char_art_pro.glb` (`Mba2 ART Pro`):** Neat **Cepol** + ribbon + **Collared Teal Uniform** + **Tailored Cream Apron** + dark trousers.
  - **`char_art_elite.glb` (`Mba2 ART Elite`):** Neat **Cepol** + **Navy Collared Uniform (White Collar)** + **Tailored Cream Apron**.
  - **`char_ibu.glb` (`Ibu2 — Ibu Sari`):** Full **Kerudung Bergo Instan** (open-face sculpted hood + forehead pet visor + chest drape completely enclosing skull) + **Batik Ibu2 Blouse + Long Skirt**.
  - **`char_kakak.glb` (`Kakak2 — Kakak Maya`):** Smooth **Bob / Medium-Long Hair + Side Bangs** + **Pastel Blouse/Cardigan + Kulot/Midi Skirt + White Sneakers**.
  - **`char_budi.glb` (`Bapak2 — Pak Budi`):** Smooth **Side-Parted Hair Cap** + **Classic Bapak2 Kumis** + **Short-Sleeve Collared Batik Shirt** (with neck-hugging collar) + **Charcoal Chinos**.

### 3. Runtime NPC Spawning & Verification
- Spawn `NpcRoster` actors inside `_npcs_root` in `main_game.gd` (`Idle`/`Talk` animation + subtle floating 3D `Label3D` role tag visible when nearby, using `DejaVuSans`).
- Render `closeup_chars_v22.png` (all 6 characters side-by-side in Godot `asset_studio` under `gl_compatibility`) and verify via `vision_analyze` (`>= 9.0/10`).
- Re-export `web-dist/` (`<= 36 MB` `.pck`), run `153+` Godot TDD + `--smoke-test` + `48` Vitest, push to `main`, deploy Coolify, and verify LIVE in Chromium on `https://game.shr.co.id`.
