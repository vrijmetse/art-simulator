# Round 8 Plan: Visual & Logic Bugfixes, Portrait Scale, Vehicle/Lighting Polish, Skill Perks, Chore Depth & Post-Epilogue Goals

**Date:** 2026-11-28
**Goal:** Eliminate every visual, UI, and gameplay gap uncovered in the Round 8 full-stage & 2-persona deep audit so every screen, 3D prop/vehicle, story/NPC, and gameplay progression loop achieves world-class quality.

## Scope & Exact Edits

### 1. Critical Visual & Functional Fixes
- **Phone OS `Catatan Harian` (`"log"`) Renderer (`godot/src/scenes/main_game.gd:_render_phone_app`):**
  - Add `elif _phone_os_app == "log":` rendering `Settings.get_daily_log(_save)` (most recent first, color-coded `+Rp`/`-Rp` delta badge, day prefix, and clean localized empty state when `daily_log` is empty).
- **`Adik Bima` Kampung House Clearance (`godot/src/core/npc_roster.gd:158-167`):**
  - Inspect `room_kampung_house.glb` furniture AABBs and place `adik_bima` at clear floor position (e.g., `Vector3(1.15, 0.0, -1.15)` or `Vector3(-0.35, 0.0, 1.35)` — `>= 0.90m` from all hotspots and `>= 0.70m` from table/bench bounds).
- **Clear Leftover Toast on Mode Switch (`godot/src/scenes/main_game.gd:_enter_home_mode`, `_enter_street_mode`):**
  - Reset `_toast_timer = 0.0` and `_toast_panel.visible = false` on entering Home/Street so stale shift-event banners never linger over Kos interiors.
- **Portrait (`390×844`) Framing, Title Hide & Readable Scale (`godot/src/scenes/main_game.gd`):**
  - Inside `_open_onboarding()`, explicitly set `_title_wrap.visible = false`.
  - When viewport is portrait (`win.x < win.y`), switch `get_window().content_scale_size` to `Vector2i(720, clampi(int(round(720.0 * win.y / maxf(1.0, win.x))), 960, 1800))` (and `Vector2i(1280, 720)` in landscape) so portrait buttons, joystick, and Phone OS render at crisp thumb-friendly scale instead of `3.3×` tiny!
  - In portrait onboarding, dock `_ob_card` to the bottom half (`offset_top = 0, offset_bottom = -16`) and frame the camera on Sari in the upper half (`Vector3(0.0, 1.38, 2.75)` looking at `Vector3(0.0, 0.62, 0.0)`) so full head-to-shoes stay unobstructed!

### 2. Economy Exploits & Progression Depth (`progression.gd`, `chore_engine.gd`, `wishlist_story.gd`, `life_rhythm.gd`, `save_store.gd`, `main_game.gd`)
- **Weekly Rent Defer Loop Fix (`progression.gd:212-235`):**
  - On `pay_weekly_rent(save, false)` (defer), set `nxt["last_rent_day"] = day` (3-day defer grace before re-prompting) AND cap late surcharge accumulation (`pending_rent_rp <= 150000` max, i.e. 120k rent + max 30k late fee); `should_collect_weekly_rent` collects `pending_rent_rp > 0` once `(day - last_rent_day) >= 3` (update `run_tests.gd:492` to advance 3 days before asserting re-collection).
- **`fired` Forfeiture (`progression.gd:327-342`):**
  - When `is_fired == true`: set `total_payout = 0`, `xp_gained = 0`, zero skill XP gains, and reduce mood (`maxi(25, shift_mood - 15)`) so intentionally triggering a firing cannot farm cash or XP (update `run_tests.gd:289-290` to expect `0` payout and `0` XP on fired).
- **`skill_xp` Mastery Perks (`progression.gd`, `chore_engine.gd`, `main_game.gd`):**
  - `cooking >= Lv 3`: waives the `Rp 8.000` daily meal deduction (`meal_cost = 0`).
  - `sweeping >= Lv 3`: increases `max_boosts` from `3` to `4` per chore.
  - `tidiness >= Lv 3`: increases tap-boost impulse from `0.65s` to `0.85s`.
  - `laundry >= Lv 3`: adds `+10%` tip multiplier inside `get_tip_bonus_multiplier()`.
  - Surface these active mastery perks clearly in the `Karier` modal (`_open_career_modal()`).
- **Distinct Chore Sweet-Spot Timing & Flavor (`chore_engine.gd`, `main_game.gd`):**
  - For `cook_rice` and `wash_dishes`, tapping `Cepat!` during the `45%–75%` sweet-spot grants **`1.8×` time boost** + **`+Rp 2.500` perfection bonus** (`"Pas Banget! +Rp 2.500"`).
- **Post-Epilogue Future Investments (`wishlist_story.gd`, `main_game.gd`, `life_rhythm.gd`, `save_store.gd`):**
  - Keep `CORE_WISHLIST_IDS` strictly as the 4 core wishlist items (`kirim_kampung`, `hp_baru`, `tabung_kontrakan`, `motor_matic`) so `is_epilogue_unlocked()` remains compatible with `run_tests.gd:767`.
  - Add 2 post-epilogue `FUTURE_INVESTMENTS` (`invest_warung` `Rp 2.500.000` -> `+Rp 25.000/day` passive income on sleep; `invest_kos_juragan` `Rp 5.000.000` -> `+Rp 50.000/day` passive income on sleep) stored in `unlocked_investments` (sanitized in `SaveStore`).
- **Portrait Scaling Guard (`main_game.gd`):**
  - Guard `get_window().content_scale_size` mutation inside `_on_viewport_size_changed()` with `win_node != null and DisplayServer.get_name() != "headless" and win_node.content_scale_size != target_scale`.
- **Vehicles, Materials & Shadow Performance (`build_vehicles.py`, `scene_visuals.gd`, `atmosphere.gd`):**
  - Center each `Wheel_*` mesh at local `(0, 0, 0)` before parent-offsetting to axle coords so `wheel.rotation.x` spins cleanly in place; update `SceneVisuals.apply_unified_material_pass()` to preserve metallic automotive paint (`sm.metallic >= 0.20`), dark tinted glass, and `Headlight`/`Taillight` emissives; keep at most 1 shadowed `OmniLight3D` per stage (`WarmBedsideOmni` indoors, `StreetLampC` outdoors at night, `shadow_bias = 0.04`).

### 3. 3D Vehicles, Stage Props, Shaders & Lighting (`build_vehicles.py`, `tex_utils.py`, `street_traffic.gd`, `atmosphere.gd`, `hd_sharpen.gdshader`, `build_gang_kampung.py`, `build_kampung_street.py`, `build_elite_assets.py`)
- **Restyle Kenney Parked Cars (`sedan`/`van`) & Foliage (`tex_utils.py` + stage builders):**
  - Override flat white/orange parked vehicle surfaces (`sedan`/`van`) to realistic automotive metallic silver/navy paint (`roughness=0.28, metallic=0.45`), dark-tinted glossy glass (`#1A2636`, `roughness=0.10`), dark matte tires (`#1C1E22`, `roughness=0.88`), and muted license plates; soften `bush-common` matte organic roughness (`0.88`).
- **Articulated Traffic Vehicles + Night Beams (`build_vehicles.py`, `street_traffic.gd`, `main_game.gd`):**
  - Keep `Wheel_*` child meshes separate on `veh_angkot.glb` & `veh_motor.glb`; spin wheels by `delta * speed / r` in `street_traffic.gd`, toggle `Headlight` / `Taillight` emission + forward `OmniLight3D` on `malam` phase, and slow/yield if player X/Z approaches the lane edge.
- **Lighting Shadows + Reuse + Shader Ringing Guard (`atmosphere.gd`, `hd_sharpen.gdshader`):**
  - Reuse existing `OmniLight3D` nodes inside `sync_stage_lights()` instead of freeing/recreating every call; enable soft shadows (`shadow_enabled = true`, `shadow_bias = 0.04`) on `WarmBedsideOmni` and `StreetLampC`.
  - Attenuate sharpen weight in `hd_sharpen.gdshader` on high-contrast thin edges (`smoothstep`) to prevent ringing halos.

## Verification Plan
- **Stage 2:** Adversarial subagent review before editing code.
- **Stage 3 (Strict Red→Green TDD):** Add Section 45 in `godot/tests/run_tests.gd` covering ALL Round 8 behaviors (`log` renderer, `adik_bima` clear of dining table & hotspots, rent defer 3-day grace + `150k` cap, `fired` zero payout/XP, `cooking`/`sweeping`/`tidiness`/`laundry` Lv 3 perks, `cook_rice` sweet-spot bonus, post-epilogue passive income, articulated `Wheel_*` nodes in `veh_angkot.glb`/`veh_motor.glb`, portrait `content_scale_size`, toast reset on mode change). Confirm Red failure first!
- **Visual & Live Verification:** Re-export vehicles/stages (`--import`), visually inspect `r8_phone_log.png`, `r8_stage_kampung_house.png`, `r8_stage_elite_street.png`, `r8_port_onboarding.png`, `r8_port_home_hud.png`, `r8_port_phone_home.png`, run Stage 4 Diff Review, export Web (`<= 60M` `.pck`) + Android APK, commit, push `main`, deploy Coolify, verify live!
