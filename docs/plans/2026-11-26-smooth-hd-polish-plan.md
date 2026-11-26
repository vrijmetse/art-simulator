# Smooth & Soft-Light HD Polish Plan (Warung-Life Parity)

## Goal
Eliminate jagged edges, flat lighting, harsh shadows, "floating" characters, and snappy animation cuts in `ART Simulator` across WebGL2 (`gl_compatibility`), Android APK, and iOS using targeted, mobile-safe Godot 4.7.2 + Blender 4.0.2 upgrades identified by the 3 parallel visual analyses.

## Scope & Architecture

### 1. Edge Anti-Aliasing, Soft Shadows & Post-Processing (`godot/project.godot`, `godot/scenes/main_game.tscn`, `godot/src/scenes/main_game.gd`)
- **`godot/project.godot`:**
  - `anti_aliasing/quality/msaa_3d=2` (`4x MSAA`)
  - `anti_aliasing/quality/screen_space_aa=1` (`FXAA` for smooth diagonal edges & shaders)
  - `lights_and_shadows/directional_shadow/soft_shadow_filter_quality=3` (`PCF13` soft penumbra shadows)
- **`godot/scenes/main_game.tscn`:**
  - `SunLight`: `shadow_blur = 2.2`, `shadow_bias = 0.025`, `directional_shadow_blend_splits = true` for smooth, natural shadow edges.
  - `GameEnv`: enable subtle studio **Glow/Bloom** (`glow_enabled = true`, `glow_intensity = 0.34`, `glow_strength = 0.85`, `glow_bloom = 0.10`, `glow_hdr_threshold = 0.98`) so warm window panes, lamps, and street lanterns softly halo without blowing out UI.
- **`godot/src/scenes/main_game.gd` (`HUD` layer, child index `0` behind all HUD panels):**
  - Add a subtle edge **Vignette** `ColorRect` (`MOUSE_FILTER_IGNORE`, `PRESET_FULL_RECT`) using a tiny `gl_compatibility`-safe `CanvasItem` fragment shader (`smoothstep(0.45, 1.05, length((UV - 0.5) * vec2(1.0, 0.85))) * 0.22`).

### 2. Character Rim Light, Soft Contact Shadows & 0.20s Animation Blend (`godot/src/core/scene_visuals.gd`, `player_controller.gd`, `main_game.gd`)
- **`godot/src/core/scene_visuals.gd` (`ArtSceneVisuals`):**
  - `apply_character_polish(node: Node)`: duplicates non-shared materials on `MeshInstance3D` (preserving `albedo_texture` & `albedo_color`), sets `rim_enabled = true`, `rim = 0.22`, `rim_tint = 0.55` so character silhouettes separate crisply from dark floors/asphalt.
  - `attach_contact_shadow(target: Node3D, radius: float = 0.36)`: idempotent helper (`_ContactShadow` node) adding a horizontal `PlaneMesh` at `y = 0.028` (above `0.026` floor rugs/sajadah so it never z-fights!) with an unshaded `GradientTexture2D` (`FILL_RADIAL`, `Color(0.03, 0.04, 0.07, 0.45)` center -> transparent edge), `cast_shadow = SHADOW_CASTING_SETTING_OFF`, `no_depth_test = false`.
- **`godot/src/scenes/player_controller.gd`:**
  - Use `_anim_player.play(a_name, 0.20)` for smooth 0.20s Idle ↔ Walk ↔ Clean blending.
  - Call `ArtSceneVisuals.apply_character_polish(_model_root)` on outfit load and `ArtSceneVisuals.attach_contact_shadow(self, 0.38)` once on `_ready()`.
- **`godot/src/scenes/main_game.gd`:**
  - Call `ArtSceneVisuals.apply_character_polish` and `ArtSceneVisuals.attach_contact_shadow` on all spawned home/street/shift NPCs (`_spawn_npcs`, `_spawn_shift_npcs`).

### 3. Smoother Blender Bevels & Weighted Normals (`godot/blender/build_kos_room.py`)
- Upgrade `add_beveled_box` bevel `segments` from `2` to `3` and apply `WeightedNormal` modifier after beveling so flat surfaces stay crisp while beveled edges catch smooth highlights, keeping total `kos_room.glb` vertex budget compact.

## TDD & Verification
- **Red -> Green (`godot/tests/run_tests.gd`):** Add tests verifying `ArtSceneVisuals.apply_character_polish` sets `rim_enabled = true` (`rim >= 0.20`) while keeping textures intact, and `ArtSceneVisuals.attach_contact_shadow` attaches exactly one `_ContactShadow` mesh idempotently at `y >= 0.025`.
- Run `818+` Godot TDD, `--smoke-test`, `48` Vitest, `export_android.sh`, `export_web.sh`, Stage 4 review, deploy live, and verify new live Bedroom & Street screenshots via `vision_analyze`.
