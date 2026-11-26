# Plan: Rebuild All 7 Characters onto Realistic 6.8-Head UAL1 Human Rigs (`mannequin-female` + `base` + `UAL1`)

## Goal
Replace the 3.2-head chibi Quaternius base (`casual-2-female` / `casual-2-male`) with realistic 6.8-head human anatomy (`mannequin-female.glb` for female characters, `base.glb` for male *Pak Budi*, animated via `UAL1.glb`'s 5 core clips) so every *Mba2 ART*, *Ibu2*, *Kakak2*, and *Bapak2* looks genuinely human and proportional alongside *Warung Life* quality environments.

## Architecture & Asset Pipeline (`godot/blender/build_characters.py`)
1. **Base Meshes & Skeleton Compatibility:**
   - Female characters (`char_art`, `char_art_hijab`, `char_art_pro`, `char_art_elite`, `char_ibu`, `char_kakak`): `godot/assets/raw/mannequin-female.glb` (`Mannequin_F`, 24,037 verts, `z = 0.002 .. 1.808 m`).
   - Male character (`char_budi`): `godot/assets/raw/base.glb` (`Mannequin`, 7,399 verts, `z = 0.000 .. 1.829 m`) with `shade_smooth()` + `Subsurf(1)` (or smooth normals + auto-smooth) so shoulders/arms are silky smooth.
   - Strip `Icosphere` custom bone shapes (`pb.custom_shape = None`) and delete `Icosphere` objects so no debug meshes ship in `.glb`.
2. **Animation Transfer (`UAL1.glb`):**
   - Load 5 clips from `godot/assets/raw/UAL1.glb`:
     - `Idle_Loop_Armature` -> `Idle`
     - `Walk_Loop_Armature` -> `Walk`
     - `Interact_Armature` -> `Clean`
     - `Idle_Talking_Loop_Armature` -> `Talk`
     - `Celebration_Armature` -> `Celebrate`
   - Remap F-curve bone path `"Head"` -> `"head"` to match `mannequin-female.glb` / `base.glb` bone casing.
   - Export ONLY these 5 actions as NLA strips (strip the other 115 UAL1 actions before export to keep GLBs small).
3. **Clean Body Material Zoning (Eliminating Mannequin Joint Stripes):**
   - Replace `M_Main` / `M_Joints` across `Mannequin_F` / `Mannequin` polygons using dominant vertex-group weights + local coords:
     - `Skin`: `head`, `neck_01`, `hand_*`, finger bones, lower `lowerarm_*` (distal from mid-bicep/elbow), and lower `calf_*` / exposed knees (`z` below skirt hem and above shoe).
     - `Shirt` (or `_Batik` textured with `uv.smart_project` on shirt polys): `spine_01`, `spine_02`, `spine_03`, `clavicle_*`, and upper `upperarm_*` (short-sleeve cut!).
     - `Pants`: `pelvis`, `thigh_*`, and upper `calf_*` (or all leg down to ankle for long pants on `char_budi`, `char_art_pro`, `char_art_elite`).
     - `Shoes`: `foot_*`, `ball_*` (`z < 0.085`).
4. **Expressive Stylized Indonesian Face & Hair/Hijab (Bound-Measured):**
   - Measure `head` vertex-group bounds (`hb`) dynamically in `arm`-local space (`y` front-facing `-Y`, `z` up).
   - Add white sclera + dark brown iris + subtle catchlight eyes, arched eyebrows, soft `Nose` (`Skin`-tinted), and warm `Smile` lips.
   - Fit `cepol` (hair cap + side-swept *poni* + temple strands + raised *cepol* bun + scrunchie), `hijab_bergo` (open-face rounded hood + draped chest/shoulder cape weighted to `spine_03` / `neck_01`), `bob` (sleek shoulder-length bob + *poni*), and `bapak` (short parted hair + *kumis*).
5. **Fitted Garments Weighted to UAL1 Bones:**
   - `build_flowing_skirt`: open multi-ring `bmesh` + `Solidify` weighted to `pelvis` + `thigh_l/r` (and `calf_l/r` for ankle-length `LongSkirt`).
   - `build_fitted_curved_apron`: fitted front bib + waist skirt + shoulder straps + pocket weighted to `spine_03`/`spine_02`/`spine_01`/`pelvis`/`thigh_l/r`.
   - `build_collared_placket`: fitted collar & placket on `spine_03`.
6. **Godot Runtime & TDD (`run_tests.gd`, `player_controller.gd`, `main_game.gd`):**
   - Update `run_tests.gd` anatomy tests to query UAL1 bone names (`upperarm_l`, `lowerarm_l`, `hand_l`, `middle_04_leaf_l`, `thigh_l`, `calf_l`, `neck_01`, `head_leaf`), asserting:
     - Zero `Icosphere` nodes
     - Height `1.70 .. 1.92 m`
     - `hip / height >= 0.45`
     - `arm / height <= 0.36` (and `(hand_tip - knee) / height >= 0.08` in `Idle`, i.e., relaxed fingers end at mid-thigh, well above knee!)
     - `hand / height <= 0.13`
     - `head+neck / height <= 0.22` (realistic 6+ head human!)
   - Check `player_controller.gd` & `main_game.gd` scale (`0.72` on `1.81 m` = `1.30 m` vs room scale) and verify skin/shirt runtime tinting still preserves textured `Batik`/`Daster` and tints `Skin` + `Nose` cleanly.
