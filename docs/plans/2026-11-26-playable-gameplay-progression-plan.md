# ART Simulator: Playable Gameplay Loop, Leveling, Progression & Modular Asset Plan

**Date:** 2026-11-26  
**Scope:** Turn static Godot 4.7 PoCs (`room_poc.tscn`, `street_poc.tscn`) into a full playable Indonesian **ART (Asisten Rumah Tangga)** life & career game with desktop + mobile touch controls, interactive chores, live *Distraksi vs Panggilan Majikan*, persistent Save/Load, leveling, skill mastery, Kos upgrades, Outfit wardrobe + color tinting, procedural SFX, and remaining Tier 1 / Tier 4 / Elite Uniform 3D assets.

---

## 1. Data Ownership & Architecture Map

| Domain | Authoritative Owner | Persistence / Format | Notes |
| :--- | :--- | :--- | :--- |
| Player Career & Wallet (`day`, `balance_rp`, `xp`, `active_tier_id`, `active_profile_id`) | `ArtEconomy` / `ArtProgression` (`src/core/progression.gd`) | `user://save_v1.json` via `ArtSaveStore` | Canonical integer IDR (`Rp 0` for wallet, `Gratis` for zero price). |
| Housing Tiers & Outfits (`TIERS`, `OUTFIT_TIERS`) | `ArtCareerTiers` (`src/core/career_tiers.gd`) | Static config + `equipped_outfit_id`, `outfit_color_hex` in save | Live-out (`kamar_kos`..`perumahan_36`) vs live-in (`perumahan_45` small, `cluster_elite` large). |
| Skills & Kos Upgrades (`skill_xp`, `unlocked_kos_upgrades`) | `ArtProgression` (`src/core/progression.gd`) | `user://save_v1.json` | Mastery levels 1..5 reduce chore duration & raise tips; Kos upgrades boost starting stamina/mood. |
| Shift Chores & Active Tasks | `ArtChoreEngine` (`src/core/chore_engine.gd`) | Ephemeral per-shift state (`shift_state`) | Deterministic task lists per tier/room (`kamar_kos`, `kampung`, `perumahan_36`, `perumahan_45`, `cluster_elite`). |
| Majikan Personality, Distraction & Call State | `ArtMajikanProfiles` + `ArtMajikanCall` (`src/core/majikan_call.gd`) | Ephemeral per-shift (`call_state`) + settled into `balance_rp` / `fired` history | Double-answer guarded; clamped trust/mood `[0..100]`; non-negative payout. |
| 3D Scene Presentation & Input | `MainGame` (`src/scenes/main_game.gd`), `PlayerController`, `ChoreHotspot` | Ephemeral scene tree nodes | Never owns authoritative money/XP math — delegates all mutations to `src/core/*`. |

---

## 2. Phase 1 — Pure GDScript Core Logic (Strict Red-Green-Refactor TDD)

All core modules must have **zero SceneTree / Node dependencies** (extending `RefCounted`) so they run deterministically in headless `tests/run_tests.gd`.

### 2.1 `godot/src/core/chore_engine.gd` (`class_name ArtChoreEngine`)
- **Chore Catalog (`CHORES`):**
  - `sweep_floor`: skill `"sweeping"`, base duration `4.0s`, energy `12`, base pay `8000`, xp `12`, ID `"Menyapu Lantai"`, EN `"Sweep Floor"`.
  - `make_bed`: skill `"tidiness"`, base duration `3.5s`, energy `10`, base pay `7000`, xp `10`, ID `"Rapikan Tempat Tidur"`, EN `"Make the Bed"`.
  - `wash_dishes`: skill `"cooking"`, base duration `4.5s`, energy `14`, base pay `10000`, xp `15`, ID `"Cuci Piring"`, EN `"Wash Dishes"`.
  - `cook_rice`: skill `"cooking"`, base duration `5.0s`, energy `15`, base pay `12000`, xp `18`, ID `"Masak Nasi & Lauk"`, EN `"Cook Rice & Meal"`.
  - `iron_laundry`: skill `"laundry"`, base duration `5.5s`, energy `16`, base pay `13000`, xp `20`, ID `"Setrika & Lipat Baju"`, EN `"Iron & Fold Clothes"`.
  - `water_plants`: skill `"tidiness"`, base duration `3.0s`, energy `8`, base pay `6000`, xp `9`, ID `"Siram Tanaman"`, EN `"Water Plants"`.
- **Functions:**
  - `create_shift(tier_id: String, profile: Dictionary, max_energy: int) -> Dictionary` — clamps `max_energy = maxi(10, max_energy)`, builds tier-appropriate chores (e.g., `kamar_kos` = 3 chores; `kampung` = 4; `perumahan_36`/`45` = 5; `cluster_elite` = 6), `energy`, `max_energy`, `earned_rp: 0`, `xp_earned: 0`, `skill_xp_earned: {}`, `completed_ids: []`, `settled: false`.
  - `effective_duration(chore_id: String, skill_level: int) -> float` — clamps `skill_level = maxi(1, skill_level)`, returns `base_duration * max(0.55, 1.0 - (skill_level - 1) * 0.10)`.
  - `complete_chore(shift: Dictionary, chore_id: String, pay_multiplier: float, skill_level: int) -> Dictionary` — validates `CHORES.has(chore_id)` and `chore_id in shift["assigned_ids"]`, guards duplicate `chore_id` (`{"ok": false, "reason": "already_done"}`) and `energy >= chore.energy` (`{"ok": false, "reason": "low_energy"}`), clamps `skill_level = maxi(1, skill_level)` & `pay_multiplier = maxf(0.1, pay_multiplier)`, awards `round(base_pay * pay_multiplier * (1.0 + (skill_level - 1) * 0.08))` and `xp`, increments `skill_xp_earned[chore.skill] += chore.xp`, appends to `completed_ids`.
  - `is_shift_complete(shift: Dictionary) -> bool` — true when all assigned chores are completed.
  - `rest_recover(shift: Dictionary, gain: int) -> Dictionary` — clamps `energy` to `[0, max_energy]`.

### 2.2 `godot/src/core/progression.gd` (`class_name ArtProgression`)
- **Player Level & Skill Mastery:**
  - `level_from_xp(xp: int) -> int`: smooth curve `1 + floor(sqrt(max(0, xp) / 40.0))` (`0 XP -> Lv1`, `40 -> Lv2`, `160 -> Lv3`, `360 -> Lv4`, `640 -> Lv5`, `1000 -> Lv6`, `1440 -> Lv7`).
  - `skill_level_from_xp(skill_xp: int) -> int`: thresholds `[0, 30, 80, 160, 280]` -> Lv `1..5`.
- **Kamar Kos Upgrades (`KOS_UPGRADES`):**
  - `kipas_angin` (`45000` Rp, `+10` max energy, ID `"Kipas Angin Baru"`)
  - `kasur_empuk` (`120000` Rp, `+15` max energy & `+8` start mood, ID `"Kasur Busa Empuk"`)
  - `rak_sepatu` (`65000` Rp, `+5%` chore tip bonus, ID `"Rak Sepatu & Kerapian"`)
  - `magic_com_pro` (`150000` Rp, `+12` start energy & `+10` cooking skill XP/shift, ID `"Magic Com Hemat"`)
  - `ac_hemat` (`350000` Rp, `+25` max energy & `+12` start mood, ID `"AC Kamar Kos"`)
- **Operations (pure immutable dict transforms):**
  - `create_player_save() -> Dictionary`
  - `buy_kos_upgrade(save: Dictionary, upgrade_id: String) -> Dictionary` — guards duplicate purchase, negative/insufficient balance (`balance_rp >= cost`), returns `{ok, reason, save}`.
  - `equip_outfit(save: Dictionary, outfit_id: String, color_hex: String) -> Dictionary` — checks `ArtCareerTiers.can_equip_outfit(outfit_id, xp)` and validates `Color.html_is_valid(color_hex)`.
  - `select_job_tier(save: Dictionary, tier_id: String) -> Dictionary` — checks `ArtCareerTiers.can_access_tier(tier_id, xp)` and updates `active_tier_id` + default `active_profile_id` for that tier.
  - `settle_shift(save: Dictionary, shift: Dictionary, call_state: Dictionary) -> Dictionary` — rejects double-settlement (`if bool(shift.get("settled", false)): return {ok: false, reason: "already_settled"}`), computes `var contract_rp := 0 if bool(call_state.get("fired", false)) else ArtMajikanCall.final_payout_rp(call_state)`, `total_payout := maxi(0, int(shift.get("earned_rp", 0)) + contract_rp)`, halves `xp_earned` if `fired` (`int(floor(float(shift["xp_earned"]) * 0.5))`), merges `shift["skill_xp_earned"]` into `save["skill_xp"]`, adds `day += 1`, and marks `shift["settled"] = true`.

### 2.3 `godot/src/core/save_store.gd` (`class_name ArtSaveStore`)
- `serialize(save: Dictionary) -> String` / `deserialize(json_text: String) -> Dictionary` — pure JSON validation & sanitization: checks `typeof(v) in [TYPE_INT, TYPE_FLOAT]` and `is_finite(float(v))` before `int()` casts, validates `skill_xp` keys and `unlocked_kos_upgrades` IDs against `KOS_UPGRADES`, validates `Color.html_is_valid(outfit_color_hex)`, clamps negative `balance_rp`/`xp`, and ensures `active_tier_id`/`equipped_outfit_id` remain unlocked for current `xp`.
- `save_to_path(save: Dictionary, path: String) -> bool` & `load_from_path(path: String) -> Dictionary` (supports custom paths in unit tests + `user://save_v1.json` at runtime, writing `.tmp` + rename or `.bak` fallback).

### 2.4 `godot/src/core/audio_synth.gd` (`class_name ArtAudioSynth`)
- Pure procedural `AudioStreamWAV` PCM buffer builders (**explicitly setting `format = AudioStreamWAV.FORMAT_16_BITS`, `mix_rate = 22050`, `stereo = false`** — zero external files):
  - `make_coin_chime() -> AudioStreamWAV` (C5 -> E5 -> G5 soft marimba chime)
  - `make_phone_ring() -> AudioStreamWAV` (Indonesian dual-tone phone ring)
  - `make_broom_sweep() -> AudioStreamWAV` (soft filtered pink/white brush swish)
  - `make_level_up_fanfare() -> AudioStreamWAV` (warm cozy major chord arpeggio)
  - `make_warning_buzz() -> AudioStreamWAV` (gentle low double-thud)

---

## 3. Phase 2 — Playable 3D Scene, Controls, Chores & HUD

### 3.1 `PlayerController` (`src/scenes/player_controller.gd`)
- `CharacterBody3D` wrapping the equipped ART `.glb` (`char_art.glb` / `char_art_pro.glb` / `char_art_elite.glb` with safe fallback to `char_art_pro.glb` until `char_art_elite.glb` exists), dynamically swapping model on outfit change and tinting shirt/apron materials via `outfit_color_hex`.
- **Collision & Walk Bounds:** Because Blender `.glb` exports lack `-col` suffixes, `main_game.tscn` includes a procedural floor `StaticBody3D` + `WorldBoundaryShape3D`, and `PlayerController._physics_process` clamps `position` to the active room/street walkable AABB bounds.
- **Dual Desktop + Mobile Input:**
  - Desktop: `WASD` / Arrow keys + `E`/`Space` interact.
  - Mobile / Touch PWA: On-screen responsive **Virtual Joystick** (bottom-left) + **Tap-to-Walk** ground raycast + big tactile **"Kerjakan / Jawab"** action button (bottom-right).
- **Animation State Machine:** `Idle` <-> `Walk` (`velocity > 0.15`) -> `Clean` (during chore progress) -> `Celebrate` (on shift complete / promotion).

### 3.2 `MainGame` (`scenes/main_game.tscn` + `src/scenes/main_game.gd`)
- **Scene Hub & Tier Switcher:**
  - Loads current home/work environment (`kos_room.glb`, `kampung_gang.glb`, `kampung_street.glb`, `room_majikan_living.glb`, `kamar_art_small.glb`, `kamar_art_large.glb`) with `ArtSceneVisuals.apply_baked_ao(self)` and `GroundBounceLight` (`fake_gi_bounce`).
  - **Mode Toggle / Door Portal:**
    - **Di Kamar Kos / Kamar ART (`Home`):** Rest on bed (restore energy & start next day), open **Lemari Seragam**, **Upgrade Kos**, or **Papan Lowongan (Start Shift)**.
    - **Di Rumah Majikan (`Shift`):** Spawns interactive `ChoreHotspot` stations (`Sapu`, `Wastafel`, `Kompor`, `Setrika`, `Tanaman`), patrolling Majikan NPC (`Ibu Sari` / `Pak Budi`), and live **Distraksi vs Panggilan Majikan** timer!
- **Live Distraction vs Majikan Call Mechanic:**
  - Floating phone HUD pill: **[Main Game (+Mood)]** / **[Telepon Pacar (+Mood)]** — tapping engages distraction (`ArtMajikanCall.apply_distraction`), gradually boosting mood while risking a timed **Panggilan Majikan**!
  - When a call triggers (`ArtMajikanCall.start_call`), phone rings (`AudioSynth.make_phone_ring()`), screen shows urgent banner with countdown progress bar (`patience_s` from `ArtMajikanProfiles`), and tapping **"Jawab Majikan!"** runs `respond_to_call` (rewarding `+Trust` + `+Rp 5.000` tip if in time, or scold + deduction + possible firing if late!).
- **HUD Copy & Renderer Compatibility:**
  - Strict ID/EN toggle (`I18n`), adding `en` variants to `ArtMajikanProfiles.PERSONALITIES` & `ArtNeighborhood.NEIGHBORS` so zero Indonesian text leaks onto `en` HUDs; `Gratis`/`Free` for zero prices, `Rp 0`/`$0` for zero wallet balance, zero marketplace terminology.
  - Add `work_interior_scene` to `ArtCareerTiers` / `ArtMajikanProfiles` with safe fallback to existing `.glb` scenes until Phase 3 exports complete; switch renderer to `gl_compatibility` when exporting WebGL/mobile builds.

---

## 4. Phase 3 — Remaining V21 Visual Fixes + Asset Matrix Completion

Run in parallel after core gameplay TDD passes:
1. **Verify V21 fixes (`closeup_chars_v21.png`, `godot_kamar_small_v21.png`):** Slim `asset_studio.tscn` or decouple unused background GLBs in `asset_studio.gd` so headless Vulkan `llvmpipe` renders each shot in `< 20s` (fixing the timeout caused by loading all scenes simultaneously).
2. **`char_art_elite.glb` (`build_characters.py`):** Crisp Tier 3/4 housekeeper uniform + apron + neat hair bun (`career_tiers.gd:119`).
3. **`room_kampung_house.glb` (`build_kampung_interior.py`):** Cozy modest Indonesian kampung house interior for Tier 1 (`Gang Kampung` indoor chores).
4. **`cluster_elite_street.glb` + `room_elite_living.glb`:** Modern 2-story Indonesian tropical cluster exterior + luxury kitchen/living interior for Tier 4 (`Cluster Elite 120+`).
5. **Modular Mess Props (`mess_props.glb`):** Dirty dish stack, laundry basket pile, dust/leaves pile placed at `ChoreHotspot` locations and hidden upon chore completion.

---

## 5. Verification Plan

1. **Pure GDScript TDD (`tests/run_tests.gd`):**
   - Keep existing 64 assertions green + add `35+` new assertions for `ArtChoreEngine`, `ArtProgression`, `ArtSaveStore`, and `ArtAudioSynth` (goal: `>= 100 passed, 0 failed`).
2. **Playable Scene Headless Smoke Test:**
   - Instantiate `main_game.tscn` headless, simulate a full loop (start shift -> complete chores -> trigger distraction + respond to Majikan call -> settle shift -> buy Kos upgrade -> equip outfit -> persist & reload save), assert `0` script errors and valid state.
3. **Visual QA & Live Playability Render:**
   - Capture desktop (`1280x720`) & mobile-aspect screenshots of the live HUD + 3D gameplay (chore hotspot, active Majikan call banner, Wardrobe/Career modal) and review via `vision_analyze` until `>= 8.5/10`.
