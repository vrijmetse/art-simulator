# Plan: Fix Character Body Proportions & Arm/Hand Ratios (`build_characters.py` + `tests/run_tests.gd`)

## Goal
Fix the stretched/ape-long arms, oversized boxing-glove fists, stumpy legs, wide boxy shoulders, and leftover `Icosphere` bone-shape mesh across all 7 exported Indonesian character GLBs (`char_art`, `char_art_hijab`, `char_art_pro`, `char_art_elite`, `char_ibu`, `char_kakak`, `char_budi`).

## Root Causes Diagnosed (Blender Inspection)
1. **Arm Shortening Never Executed (`Hand.L` vs `Fist.L`):** `shorten_arms_uniformly()` checked `arm.data.edit_bones.get(f"Hand.{side}")`, whereas Quaternius names hand bones `Fist.L` / `Fist.R`. It exited early on every character, leaving arms `0.73 m` long (`Fist.L` ending near the kneecap at `z = 0.24–0.39` vs knee `0.31`).
2. **Oversized `Fist` Mitts (`0.347` local = `19.4 cm`):** Even if shortened uniformly, Quaternius fists are thick chunky blocks relative to forearms.
3. **Stumpy Legs (`34%` of height) & Wide Shoulders:** Original `casual-2-female` / `casual-2-male` legs (`0.00 -> 1.02` local) are short vs torso + large head.
4. **Leftover `Icosphere` Mesh:** Every pose bone had `custom_shape = Icosphere`, causing glTF export to embed an invisible/extra `[-1, 1]` `Icosphere` mesh in every `.glb`.

## Target Proportions (`Body` local space, world `~0.56x`, Godot runtime `0.72x`)
1. **Legs (`UpperLeg` + `LowerLeg`, `z = 0.00 -> 1.24`):** Lengthen legs vertically by `leg_scale = 1.22` from floor (`z = 0`), slim leg X/Y thickness `0.93x`, and shift upper skeleton + torso/head/shoulder/arm vertices and edit bones up by `dz = +0.22` (`0.22` local). Legs rise from `34%` to `~41%` of total height.
2. **Torso & Shoulders (`z = 1.24 -> 2.22`):** Pull `Shoulder.L/R` inward (`0.86x` X for females, `0.94x` for male) and trim `Abdomen`/`Hips` width slightly (`0.93x` X/Y on females) for a clean silhouette.
3. **Head (`z = 2.40 -> 3.08`):** Scale `Head` vertices around `(0, 0, 2.42)` by `(0.71, 0.71, 0.72)` (`~4.6 heads tall`). Update `measure_head_bounds()` threshold dynamically (`v.co.z > 2.42`).
4. **Arms & Hands (`Shoulder` -> `UpperArm` -> `LowerArm` -> `Fist`):**
   - Fix bone name `Hand.{side}` -> `Fist.{side}`.
   - Scale `UpperArm` + `LowerArm` length along arm axis from shoulder pivot by `0.74x` (and trim arm radial thickness `0.88x` in Y/Z).
   - Scale `Fist.{side}` + `Fist.{side}_end` separately from wrist pivot (`ha.head`) by `0.58x` length and `0.64x` radial thickness (`~11.5 cm` hand).
   - Expected `Idle` pose check: Shoulder `~2.11`, Elbow `~1.69` (waist), Wrist `~1.38` (hip), Fingertip `~1.18` (upper thigh, clearly above knee `0.68`).
5. **Clothing & Props Alignment:** Shift apron, collar, placket, `HijabDrape`, and `skirt_cfg` rings/weights by `+0.22` in Z so all garments hug waist/hips cleanly with zero clipping.
6. **Strip `Icosphere`:** Clear `pb.custom_shape = None` on all pose bones and unlink/remove `Icosphere` meshes/objects before export.

## TDD Plan (`godot/tests/run_tests.gd`)
Add anatomical sanity assertions across all 7 `char_*.glb` files in `run_tests.gd` (evaluating `Skeleton3D` rest + `Idle` pose & mesh bounds):
- Zero `Icosphere` nodes in any character GLB.
- Total character height in `[1.55, 1.95]` (at native GLB scale `1.0`).
- Arm span `(UpperArm + LowerArm + Fist)` <= `0.35 * total_height`.
- In `Idle` pose, `Fist.L` tip Y is strictly above Knee (`LowerLeg.L` head Y) by `>= 0.16` (at native GLB scale `1.0`, i.e., hands end at upper thigh, NEVER at the knees!).
- Hip (`UpperLeg.L` head Y) >= `0.38 * total_height`.

## Verification
1. Write failing TDD checks in `tests/run_tests.gd` (RED).
2. Implement proportion fixes in `godot/blender/build_characters.py`, regenerate all 7 GLBs, run `--import`.
3. Run `godot4 --headless --path godot -s res://tests/run_tests.gd` (GREEN) + `--smoke-test` + `vitest`.
4. Render close-up studio sheet of all characters (`closeup_chars_v29.png`) + `main_game_onboarding_v29.png` + `main_game_shift_npcs_v29.png` and inspect via `vision_analyze`.
5. Pre-commit review, Web/PWA export, push `main`, Coolify deploy, live verify `https://game.shr.co.id/`.
