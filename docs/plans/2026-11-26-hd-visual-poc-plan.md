# HD Visual POC Plan — Closing the *Warung Life* Clarity Gap

**Goal:** Build and render 3 genuinely distinct, non-destructive HD visual POCs on top of `kos_room.glb` + `char_art.glb` in isolated `room_poc` test scenes (`poc_exp_a`, `poc_exp_b`, `poc_exp_c`), inspect every `1280×720` `gl_compatibility` render against `build/poc_baseline.png`, self-score on a 5-axis rubric, and identify which approach (or hybrid combination) reaches **≥ 8.5/10** before touching all 10 stages or `main_game`.

**Non-Destructive Isolation Rules:**
- Do **NOT** modify `godot/project.godot`, `godot/scenes/main_game.tscn`, `godot/src/scenes/main_game.gd`, `godot/assets/models/*.glb`, or `godot/scenes/room_poc.tscn`.
- Each experiment owns strictly isolated files:
  - **Exp A (Filmic PBR + Tight Shadows + Material Sheen):** `godot/scenes/poc_exp_a.tscn`, `godot/src/scenes/poc_exp_a.gd`
  - **Exp B (*Warung Life* Stylized Cel-Ramp + Warm Ink Outline Shader):** `godot/scenes/poc_exp_b.tscn`, `godot/src/scenes/poc_exp_b.gd`, `godot/shaders/poc_b_toon.gdshader`, `godot/shaders/poc_b_outline.gdshader`
  - **Exp C (Hybrid Filmic PBR + Detail Micro-Shader + Subtle Post Sharpen + Warm Depth):** `godot/scenes/poc_exp_c.tscn`, `godot/src/scenes/poc_exp_c.gd`, `godot/shaders/poc_c_detail.gdshader`, `godot/shaders/poc_c_sharpen.gdshader`

## Why `poc_baseline.png` Looks Soft / Washed Out
1. **Overexposure & Clipping:** `RoomEnv` (`tonemap_mode = 2` or `1`) + `BedLampLight` (`energy = 1.25`) + `WindowFill` (`0.55`) + `SunLight` blow out the corner walls, mirror, pillow, and center floor into pure clipped white.
2. **Low-Contrast Shadow Frustum:** `directional_shadow_mode = 1` + `shadow_blur = 3.2` spreads shadow texels too wide and blurs contact shadows into mush.
3. **Distant Camera (`4.8, 4.4, 4.8`, `fov = 44`):** Leaves huge empty green void around the room and shrinks Sari to ~23% of screen height.
4. **Flat Material Separation:** Wooden furniture, ceramic tiles, and walls lack micro-specular variation, crisp lightmap integration (`room_poc.gd` never even called `SceneVisuals.apply_lightmap`!), and edge/contour separation.

## The 3 Parallel POC Experiments

### Experiment A — High-Contrast Filmic PBR (`poc_exp_a`)
- Apply `res://assets/lightmaps/kos_room_lightmap.png` via `SceneVisuals.apply_lightmap` AND `SceneVisuals.apply_character_polish` + `attach_contact_shadow` (which `room_poc.gd` omitted!).
- Set `ssao_enabled = false`, `tonemap_mode = 4` (AgX, fallback `3` ACES if `gl_compatibility` warns/clips) with balanced `tonemap_exposure = 0.88`, `tonemap_white = 1.6`.
- Tight directional shadow frustum (`directional_shadow_mode = 0` Orthogonal, `directional_shadow_max_distance = 11.0`, `shadow_blur = 0.55`, `shadow_bias = 0.015`) for razor-sharp furniture & character shadows.
- Runtime PBR material tuning: boost wood/ceramic specular & lower floor roughness (`0.28`) for crisp window-light tile reflection, darken mirror glass to a cool sky-tinted reflective surface instead of clipped white, warm cozy background gradient.
- Closer diorama framing: camera around `(3.55, 3.05, 3.55)`, `fov = 33.0`, looking at `(0.05, 0.72, -0.05)`.

### Experiment B — *Warung Life* Stylized Soft-Cel + Warm Ink Outline (`poc_exp_b`)
- Set `ssao_enabled = false`, `tonemap_mode = 3` (ACES), `directional_shadow_mode = 0` (`max_distance = 11.0`, `shadow_blur = 0.45`), tighter camera framing `(3.55, 3.05, 3.55)`, `fov = 33.0`.
- Override room & character materials at runtime using `ShaderMaterial` (`poc_b_toon.gdshader`) that **preserves** `albedo_texture`, `albedo_color`, `vertex_color_use_as_albedo` (`COLOR_0`), `emission`, AND **manually samples `UV2` lightmap** (`uniform sampler2D lightmap_tex : hint_default_white; uniform bool use_lightmap = false;` checked via `fmt & Mesh.ARRAY_FORMAT_TEX_UV2 != 0`) so `kos_room_lightmap.png` is never lost!
- `poc_b_toon.gdshader` (`gl_compatibility` spatial shader): quantizes `DIFFUSE_LIGHT` in `void light()` with a **smooth 3-step stylized ramp** (`smoothstep`) + warm sun tint + crisp `Fresnel` rim highlight so characters & props pop cleanly.
- `poc_b_outline.gdshader` (`next_pass` inverted-hull cull-front warm-sepia outline, ~`0.007m`): restrict **ONLY** to smooth-normal meshes (`char_art` + rounded props like fan/lamp/plant/laundry basket — **never** hard-edged box furniture like wardrobe/desk/walls so 90° corners never tear open!).

### Experiment C — Hybrid HD Diorama: Filmic PBR + Micro-Detail + 1-Tap Unsharp Post (`poc_exp_c`)
- Apply `kos_room_lightmap.png` + `apply_character_polish` + `attach_contact_shadow`.
- Set `ssao_enabled = false`, `tonemap_mode = 4` (AgX, fallback `3` ACES if needed), `directional_shadow_mode = 0` (`max_distance = 11.0`, `shadow_blur = 0.60`), richer color grading.
- Apply **subtle warm outline ONLY on smooth-normal foreground actor/organic props** (`char_art` + rounded props) — keeping walls/floor/box furniture clean PBR with sharpened material roughness/normal contrast.
- Add a **`CanvasLayer` (`layer = 0`, strictly BELOW the HUD `CanvasLayer` at `layer = 1`) full-screen `ColorRect` post-pass** (`poc_c_sharpen.gdshader`, `hint_screen_texture`): lightweight 5-tap unsharp mask (`amount = 0.30`) + gentle vignette + subtle warm shadow tint so 3D edges pop without haloing HUD text.
- Closer diorama framing `(3.55, 3.05, 3.55)`, `fov = 33.0`.

## Verification & Capture Gate
Each subagent captures its own `1280×720` `gl_compatibility` frame via:
```bash
xvfb-run -a -s "-screen 0 1280x720x24" /home/ubuntu/.local/bin/godot4 --rendering-method gl_compatibility --path /home/ubuntu/projects/art-simulator/godot res://scenes/poc_exp_<x>.tscn -- --capture-room=/home/ubuntu/projects/art-simulator/build/poc_exp_<x>.png
```
Plus runs an automated Python/PIL check verifying:
- `1280×720` PNG exists, non-empty, zero shader compilation errors in Godot stdout/stderr
- Clipped-white pixel ratio (`R>250 & G>250 & B>250`) reduced drastically vs `poc_baseline.png`
- Local edge sharpness (Laplacian variance) measured quantitatively alongside our visual inspection (`vision_analyze`) + 5-axis self-score (`/10`).
