# Global Hit Phase 3 — Kos Decorating Sandbox, Cozy Photo Mode & Agency Endgame

**Date:** 2026-11-28
**Goal:** Turn *Kamar Kos* into a customizable spatial sandbox, add a 1-tap Cozy Photo Mode for shareable screenshots, and unlock an Agency Management endgame (`ArtAgencyOps`) post-epilogue.

## Scope & Architecture

### 1. Kos Decorating Sandbox (`godot/src/core/kos_decor.gd`, `progression.gd`, `save_store.gd`, `main_game.gd`)
- Pure GDScript `ArtKosDecor`:
  - `DECOR_ITEMS`: 4 low-poly decor props (`decor_monstera`, `decor_karpet`, `decor_lampu_tidur`, `decor_kucing`), each with `cost_rp`, `default_slot`, and ID/EN copy.
  - `SLOTS`: 4 curated floor coordinates inside `kos_room` (`x [-2.0..2.0], z [-1.8..1.7]`) clear of `sleep_bed (-0.95,-0.85)`, `exit_street (0.45,1.15)`/`(0.08,1.15)`, and `pray_mat (1.20,0.95)`/`(0.65,0.95)` (`>= 0.70m` clearance).
  - `buy_decor(save, decor_id) -> Dictionary` (idempotent duplicate guard, deducts `balance_rp`, sets default slot & `rot_deg=0`, awards `+15 XP` + `+6` mood).
  - `move_decor_next_slot(save, decor_id) -> Dictionary` (cycles `slot` `0..3` without stacking onto `sleep_bed`/`pray_mat`).
  - `rotate_decor(save, decor_id) -> Dictionary` (increments `rot_deg` by `45` mod `360`).
  - `spawn_decor_nodes(stage_root, save)`: attaches low-poly shadowless meshes under `_KosDecorRoot` (only in `home` mode!).
- `main_game.gd`: `_enter_home_mode()` calls `KosDecor.spawn_decor_nodes(stage_root, _save)`; `_open_kos_modal()` exposes Buy / `Geser Posisi` / `Putar 45°` controls.

### 2. Cozy Photo Mode (`main_game.gd`)
- Compact `📷` button (`44×44px`) in top-right HUD (`top_r_row`).
- `_set_photo_mode(enabled: bool)`:
  - When `true`: hides `_tl_card`, `_tr_vbox`, `_br_vbox`, `_hp_bottom_left`, `_toast_panel`, `_courier_toast`, `_world_prompt`, `_call_banner`, and `hotspots_root`, showing ONLY a minimal bottom-right `Keluar Foto` / `Exit Photo` button (`>= 44px`).
  - Cleanly auto-exits `_photo_mode` whenever entering a modal, Phone OS, Shift end, or pressing `ESC`/`E`/`Space`.

### 3. ART Agency Endgame (`godot/src/core/agency_ops.gd`, `life_rhythm.gd`, `save_store.gd`, `progression.gd`, `main_game.gd`)
- Pure GDScript `ArtAgencyOps`:
  - Requires `WishlistStory.is_epilogue_unlocked(save)` before hiring.
  - `ROOKIE_POOL`: 3 hireable junior ARTs (`art_nia`, `art_tono`, `art_lestari`) with `cost_rp` (`400k / 550k / 750k`) and `daily_income_rp` (`35k / 50k / 75k`).
  - `hire_rookie(save, rookie_id) -> Dictionary` (gates on epilogue unlock + balance + non-duplicate).
  - `get_agency_daily_income(save) -> int`
- `ArtLifeRhythm.sleep_in_bed(save, owned_upgrades)`: includes `ArtAgencyOps.get_agency_daily_income(nxt)` in `passive_income_rp`!
- `main_game.gd`: surfaces **AGENSI ART MANDIRI (HIRE & KELOLA TIM)** in `_open_wishlist_modal()` once epilogue is unlocked + logs hires in `daily_log`.

### 4. Save Persistence (`progression.gd`, `save_store.gd`)
- `Progression.create_player_save()` adds `"unlocked_decor": []`, `"kos_decor_layout": {}`, `"hired_agency_arts": []`.
- `SaveStore.sanitize()` validates `unlocked_decor` against `KosDecor.DECOR_ITEMS`, `kos_decor_layout` slot (`0..3`) & `rot_deg` (`0..315`), and `hired_agency_arts` against `AgencyOps.ROOKIE_POOL` across JSON round-trip.

## TDD Plan (Stage 3 Red → Green)
Add **Section 48** in `godot/tests/run_tests.gd`:
1. `ArtKosDecor`: all 4 `SLOTS` sit inside `[-2.0..2.0] x [-1.8..1.7]` and `>= 0.70m` clear of `sleep_bed`, `exit_street`, and `pray_mat` portals (both `kos_room` and `kamar_art_small`); `buy_decor` prevents duplicates/insufficient funds; `move_decor_next_slot` & `rotate_decor` update layout; `spawn_decor_nodes` creates valid child nodes.
2. `ArtAgencyOps` & `ArtLifeRhythm`: `hire_rookie` rejects before epilogue unlocked, grants `+35k..75k/day` after epilogue, rejects duplicates, and `sleep_in_bed` pays combined passive income.
3. `SaveStore.sanitize()`: preserves `unlocked_decor`, `kos_decor_layout`, and `hired_agency_arts` across serialize/deserialize round-trip and strips invalid entries.
4. `main_game.gd` compiles cleanly (`!= null`), exposes `_set_photo_mode`, and passes `-- --smoke-test` + `48/48` Vitest.
