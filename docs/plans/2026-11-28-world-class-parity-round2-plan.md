# ART Simulator — Round 2 World-Class Visual & UX Parity Plan

**Date:** 2026-11-28
**Target Gate:** All 3 blind adversarial visual audit batches (`Title/Onboarding/Dialogue/Portraits`, `HUD/Dock/SmartphoneOS/Mobile780x437`, `3D Streets/Interiors/Lighting`) score **>= 8.5 / 10** against the 18 benchmark screenshots, while preserving 100% original Indonesian ART (*Asisten Rumah Tangga*) identity.
**Baseline Score (Round 1 `643771a`):** `4.1 / 10` (`4.5` / `4.2` / `3.6`).

---

## Phase A — Core / Visual Config & TDD Spec (Red -> Green)
1. **Atmosphere & Material Cohesion (`godot/src/core/atmosphere.gd`, `godot/src/core/scene_visuals.gd`, `godot/scenes/main_game.tscn`):**
   - Set `ProceduralSkyMaterial` ground horizon/bottom colors to warm dark charcoal (`Color(0.24, 0.22, 0.20)` / `Color(0.11, 0.10, 0.12)`) so room edges and Title/Onboarding screens never expose raw sage-green void.
   - Warm golden-hour lighting (`SunLight` warm amber `(1.0, 0.87, 0.66)`, `shadow_opacity = 0.68`, `GroundBounceLight` warm cream `0.34`, `ambient_light_energy = 0.42`, subtle warm `glow_bloom = 0.06`, `glow_intensity = 0.30`).
   - Strip harsh black cel-outlines from characters (`apply_unified_material_pass(..., force_outline=false, ...)` skips `next_pass` outline on character actors; keep subtle `0.0018` warm-sepia outline only on smooth stylized furniture/props) and tone down character skin speculars (`roughness = 0.74`, `metallic_specular = 0.22`) so characters match the cozy stylized interiors.
   - Add `Atmosphere.should_show_virtual_joystick(viewport_size: Vector2, is_touch: bool, is_mobile_os: bool = false) -> bool` (returns `true` when `is_mobile_os` or (`is_touch` and `viewport_size.x <= 1024`) or `viewport_size.x <= 960`; returns `false` on desktop `1280x720`).
   - Add `Progression.get_phone_layout_mode(viewport_size: Vector2) -> String` (`"landscape"` when `viewport_size.y <= 500` and `viewport_size.x > viewport_size.y`, else `"portrait"`).
   - Update both character call sites in `main_game.gd` (`apply_unified_material_pass(player, false, false, ...)` and NPCs) + `player_controller.gd` polish so `next_pass` is `null` on character meshes.
   - Add `assets/portraits/_raw/*` to `export_presets.cfg` `exclude_filter` across Web/Android/iOS, and enforce a hard `web-dist/index.pck <= 95 MB` gate.

## Stage 2 Safeguards (Locked)
- **Bottom-left layout safety:** Desktop hides `_joy_base` and places `HP` at `(18, bottom - 16)` + `_courier_toast` at `offset_left = 108`; touch/mobile places `_joy_base` at `(18, bottom - 16)`, `HP` above it (`offset_bottom = -124`), and `_courier_toast` at `offset_left = 128`.
- **Blender 4.0 `ShaderNodeMix` socket indices:** Use `data_type = 'RGBA'`, `blend_type = 'MULTIPLY'`, `inputs[0]` (Factor), `inputs[6]` (Color A), `inputs[7]` (Color B), `outputs[2]` (Result), and `samples = 28` (`use_denoising = False` since host lacks OIDN).
- **Safe `OuterYard` bounds:** Decorative `OuterYard` fences/trees sit outside `PlayerController` bounds with no collision shapes.

## Phase B — 18 Unique 3D Portraits, 3D Prop Icons & 3D Extruded Plaque Logo
1. **Unique Cast Portraits (`godot/blender/render_portraits_and_icons.py`, `godot/blender/render_ui_icons.py`):**
   - Fix `_tint_materials()` to insert a `ShaderNodeMix` (`MULTIPLY` blend) over existing `Image Texture` nodes so outfit & hijab color overrides visibly differentiate every character.
   - Map all 18 speaker IDs + `player_hijab` to genuinely distinct base models, headwear (glasses, headbands, hijabs in varied colors, caps, peci, ponytails, bobs), camera yaw angles, and soft matte lighting (`Roughness = 0.72`, `Specular = 0.25`) — zero pink-hijab clones.
   - Tighten dialogue portrait asset to clean bust framing without double circle-inside-square borders (`portrait_square_*` or clean single-ring alpha mask).
2. **Cycles 3D Tactile Prop Icons & 3D Plaque Logo (`godot/blender/render_3d_ui_assets.py` -> `godot/assets/ui/*.png`):**
   - Render frameless 3D Cycles prop icons (`icon_door`, `icon_broom`, `icon_career`, `icon_wardrobe`, `icon_upgrade`, `icon_phone`, `icon_courier_box`, `star_filled`, `star_empty`, `icon_hand_pointer`) with soft white/warm rim highlights and drop shadows — NO dark circular cages around dock buttons.
   - Render 9 glossy 3D claymorphic Smartphone OS app icons (`app_bank`, `app_shop`, `app_chat`, `app_debt`, `app_dreams`, `app_story`, `app_missions`, `app_map`, `app_guide`) with recognizable miniature 3D props inside soft squircle tiles.
   - Render a multi-layered 3D Cycles wooden-and-gold beveled emblem **`logo_art_simulator.png`** featuring sculpted broom + feather duster + warm sparkles + `ART SIMULATOR` / `COZY HOMEKEEPER` banner.

## Phase C — 3D Stage Warmth, Smooth Foliage, Courtyard Backing & Micro-Clutter
1. **Home Kos & Title Diorama (`godot/blender/build_kos_room.py`):**
   - Add `OuterYard` courtyard paving + low terracotta/plaster perimeter wall + warm corner potted plants around `kos_room.glb` so Title Screen (`gap_title_v2.png`) and Character Creation (`gap_onboarding.png`) show a grounded Indonesian kos terrace rather than floating over sky void.
   - Add lived-in kos props: pair of `sandal jepit` (blue flip-flops) by doorway, extra throw pillows with beveled seams on bed, wall calendar/poster, and warm desk lamp glow.
2. **Streets (`godot/blender/build_kampung_street.py`, `godot/blender/build_gang_kampung.py`, `godot/blender/build_elite_assets.py`):**
   - Replace faceted low-poly Kenney tree canopies with smooth-shaded multi-lobe organic foliage clusters (`shade_smooth = True`, zero flat triangle facets!).
   - Brighten asphalt contrast & crisp white zebra crosswalk stripes (`ZebraStripe_*` raised `+0.006m` above road surface so zero z-fighting), ensure parked Indonesian scooters (`add_sculpted_scooter`) and utility poles + overhead cables sit cleanly within camera view, and enrich Warung Bu Tini / Musholla facade details (stacked blue water gallons, green `3kg` LPG crate, warm lantern/bulb glow).
3. **Interiors (`godot/blender/build_kamar_art.py`, `godot/blender/build_majikan_interior.py`, `godot/blender/build_elite_assets.py`, `godot/blender/build_kampung_interior.py`):**
   - Add beveled sofa cushions + throw pillows, frying pan + cooking pot on kitchen stove, dish drying rack + plates, doorway slippers, and warm exterior garden fencing outside windows.
   - Re-run Blender builds + UV2 lightmaps + `godot4 --import --quit`.

## Phase D — HUD, Dock, Responsive `780x437` Smartphone OS, Onboarding & Dialogue Polish (`godot/src/scenes/main_game.gd`)
1. **Top HUD Spread & Chunky Typography:**
   - Top-Left: Bold outlined clock (`25px`, e.g. `10.00`) + `HARI 2 · PAGI`, `Mbak Sari · Kamar Kos Harian`, 5 crisp `16x16` stars, **BOTH** `ENERGI` (green bar) **AND** `SEMANGAT` (amber-gold bar) with thick outlines (`outline_size = 5`).
   - Top-Right: Gold `Lv 2` badge + large bold `Rp 72.350` (`23px` lime-green, `outline_size = 5`) + `Peta` & `Menu ★` + Tasks dropdown (`44px+` height).
2. **Bottom-Left `HP` & Frameless Bottom-Right Prop Dock:**
   - Move `HP` smartphone icon + crisp `"HP"` label + notification badge to **bottom-left** (matching benchmark layout!).
   - Keep **bottom-right** dock (`Keluar`, `Shift`, `Karier`, `Seragam`, `Upgrade`) as frameless `64x64` 3D prop buttons with crisp outlined labels (`>= 44px` touch targets, zero circular cages!).
   - Show `_joy_base` ONLY when `Atmosphere.should_show_virtual_joystick(vp, DisplayServer.is_touchscreen_available())` is true (never cluttering desktop `1280x720`).
3. **Responsive Hardware-Bezel Smartphone OS (`1280x720` Portrait + `780x437` Landscape):**
   - Wrap Smartphone OS inside a realistic dark-titanium phone hardware frame (outer bezel, earpiece/camera pill, inner glass screen, drop shadow).
   - Switch dynamically via `Progression.get_phone_layout_mode(vp)`: on `780x437` mobile landscape, expand bezel to `640x380` landscape mode with `5-column` app grid and `44px+` touch buttons + `13px+` text!
4. **Onboarding, Title Screen, Dialogue & World Prompts:**
   - Title Screen: warm amber/gold beveled primary CTA (`MULAI BARU` / `LANJUTKAN`), subtle dark atmospheric vignette framing the kos diorama.
   - Character Creation: centered/balanced hero framing, pattern/fabric swatch chips showing daster + batik accent preview, spacious header clear of `EN` button.
   - Dialogue Bar: single clean rounded portrait frame (remove double circle-inside-square), crisp speaker hierarchy.
   - World Prompts: move `Label3D` above head height (`y + 2.05`) or hide `Label3D` on `Kasur`/`Sholat` when player is close and render standardized 2D HUD pill (`[E] ...`) so labels never clip behind the player's head.

## Phase E — Verification, Blind Re-Score (`>= 8.5`), Stage 4 Review & Deploy
1. Add Section 39 TDD tests (`run_tests.gd`) covering all new invariants (`should_show_virtual_joystick`, `get_phone_layout_mode`, zero portrait pixel-clones, warm lighting/ground colors, no character cel-outline bleed).
2. Re-capture all `gap_*` screenshots (`1280x720` & `780x437`), run **blind 3-subagent visual parity audit (`0–10`)**, iterate any batch scoring `< 8.5`.
3. Run Stage 4 Adversarial Code & Security Review, prune unused extracted textures (`ResourceLoader.get_dependencies`), rebuild Web (`./scripts/export_web.sh`) + Android APK (`./scripts/export_android.sh`), push `main`, deploy via Coolify, and verify live on `https://game.shr.co.id/`.
